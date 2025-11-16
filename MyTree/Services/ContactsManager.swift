import Foundation
import Contacts
import Combine
#if os(macOS)
import AppKit
#endif

/// Manages the complete lifecycle of loading, processing, and building family tree data from Contacts.
///
/// This class is the primary service layer between the Contacts framework and the app's data models.
/// It handles authorization, fetching contacts, traversing relationships, and building the tree data structure.
///
/// **Responsibilities:**
/// - Request and manage Contacts authorization
/// - Locate or let user select the "me" contact
/// - Traverse family relationships to build the tree
/// - Convert CNContacts to FamilyMember models
/// - Create FamilyTreeData with precomputed relationships
/// - Track initialization progress for UI feedback
///
/// **Usage Example:**
/// ```swift
/// @StateObject private var contactsManager = ContactsManager()
///
/// // In view:
/// .task {
///     await contactsManager.checkAuthorizationStatus()
/// }
/// ```
///
/// **State Flow:**
/// 1. Not determined → Request access
/// 2. Authorized → Load contacts → Find/select "me" → Build tree
/// 3. Ready → Provide `treeData` for visualization
@MainActor
class ContactsManager: ObservableObject { // swiftlint:disable:this type_body_length
    // MARK: - Published State

    /// All family members loaded from contacts (after tree traversal)
    @Published var familyMembers: [FamilyMember] = []

    /// The root "me" contact card
    @Published var myContactCard: FamilyMember?

    /// Current Contacts authorization status
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined

    /// Whether the user needs to manually select their contact
    @Published var needsUserToSelectMeContact = false

    /// Available contacts for user selection (when "me" can't be auto-detected)
    @Published var availableContacts: [FamilyMember] = []

    /// Final computed tree data ready for visualization
    @Published var treeData: FamilyTreeData?

    /// Human-readable description of current initialization stage
    @Published var initializationStage: String = ""

    /// Initialization progress from 0.0 to 1.0
    @Published var initializationProgress: Double = 0.0

    // MARK: - Private Properties

    private let contactStore = CNContactStore()
    let log = AppLog.contacts
    private let imageLog = AppLog.image

    // MARK: - Helpers

    /// Formats milliseconds value for logging.
    private func ms(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Updates initialization progress with logging.
    private func updateProgress(stage: String, progress: Double) {
        initializationStage = stage
        initializationProgress = progress
        let progressPercent = Int(progress * 100)
        log.debug("Progress update '\(stage)' - \(progressPercent)%")
    }

    // MARK: - Public API

    /// Requests Contacts access from the user.
    ///
    /// Presents the system authorization dialog and updates `authorizationStatus`.
    /// If granted, automatically begins loading contacts.
    func requestAccess() async {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            authorizationStatus = granted ? .authorized : .denied

            if granted {
                await loadContacts()
            }
        } catch {
            log.error("Requesting contacts access failed: \(error.localizedDescription)")
            authorizationStatus = .denied
        }
    }

    /// Checks the current Contacts authorization status.
    ///
    /// This should be called on app launch to determine the initial state.
    /// If already authorized, automatically begins loading contacts.
    func checkAuthorizationStatus() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        log.debug("checkAuthorizationStatus() started")

        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        log.debug("Current authorization status: \(authorizationStatus.rawValue)")

        // If already authorized, load contacts
        if authorizationStatus == .authorized {
            await loadContacts()
        }

        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        log.debug("checkAuthorizationStatus() completed in \(String(format: "%.2f", totalTime))ms")
    }

    /// Handles user selection of their "Me" contact from the picker.
    ///
    /// Stores the selection in UserDefaults and begins building the family tree.
    ///
    /// - Parameter member: The selected family member
    func selectMeContact(_ member: FamilyMember) async {
        updateProgress(stage: "Loading selected contact...", progress: 0.1)

        // Store the selected contact identifier for future launches
        UserDefaults.standard.set(member.id, forKey: "myContactIdentifier")
        log.debug("Stored me contact identifier: \(member.id)")

        // Find the CNContact corresponding to this FamilyMember
        let keysToFetch = contactKeysToFetch()

        do {
            let contact = try contactStore.unifiedContact(withIdentifier: member.id, keysToFetch: keysToFetch)
            myContactCard = member
            needsUserToSelectMeContact = false
            updateProgress(stage: "Preparing selected contact...", progress: 0.2)
            await buildFamilyTree(startingFrom: contact)
        } catch {
            log.error("Fetching selected contact failed: \(error.localizedDescription)")
            updateProgress(stage: "Error loading contact", progress: 0.0)
        }
    }

    // MARK: - Private Methods

    /// Loads contacts from the Contacts database.
    ///
    /// Attempts to automatically find the "me" contact. If not found, fetches all contacts
    /// for manual selection by the user.
    func loadContacts() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        log.debug("loadContacts() started")

        updateProgress(stage: "Finding your contact...", progress: 0.1)

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
            CNContactTypeKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,  // Add birthdate for age comparison
            CNContactDatesKey as CNKeyDescriptor  // Add dates for anniversary/marriage date
        ]

        do {
            log.debug("Attempting to locate Me contact")

            // Attempt to locate "Me" contact
            let meContact = tryLoadMeContact(keysToFetch: keysToFetch)

            if let meContact = meContact {
                // Successfully found or loaded the "me" contact
                log.debug("Using me contact: \(meContact.givenName) \(meContact.familyName)")
                updateProgress(stage: "Loading your family tree...", progress: 0.2)
                let meMember = convertToFamilyMember(meContact)
                myContactCard = meMember
                needsUserToSelectMeContact = false

                // Store the identifier for future use
                UserDefaults.standard.set(meContact.identifier, forKey: "myContactIdentifier")

                await buildFamilyTree(startingFrom: meContact)
            } else {
                // No "me" contact found - fetch all contacts for user selection
                try await loadAllContactsForSelection(keysToFetch: keysToFetch)
            }

            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            log.debug("loadContacts() completed in \(ms(totalTime))ms")
        } catch {
            log.error("loadContacts() failed: \(error.localizedDescription)")
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            log.debug("loadContacts() failed after \(ms(totalTime))ms")
            updateProgress(stage: "Error loading contacts", progress: 0.0)
        }
    }

    /// Builds the complete family tree starting from the "me" contact.
    ///
    /// This performs the core tree-building algorithm:
    /// 1. Traverse relationships using BFS to discover all family members
    /// 2. Infer genders from relationship labels
    /// 3. Create FamilyTreeData with precomputed relationships
    ///
    /// - Parameter meContact: The root CNContact to start traversal from
    private func buildFamilyTree(startingFrom meContact: CNContact) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        log.debug("buildFamilyTree() started")

        updateProgress(stage: "Building family tree...", progress: 0.3)

        let keysToFetch = contactKeysToFetch()
        let meMember = convertToFamilyMember(meContact)

        let traversal = traverseContacts(
            rootContact: meContact,
            rootMember: meMember,
            totalRelations: meContact.contactRelations.count,
            keysToFetch: keysToFetch
        ) { stage, progress in
            self.updateProgress(stage: stage, progress: progress)
        }

        logTraversalMetrics(traversal.metrics)
        updateProgress(stage: "Building relationships...", progress: 0.55)

        // Build relations with FamilyMember references and create virtual members
        let membersWithRelations = buildRelations(from: traversal)

        updateProgress(stage: "Analyzing relationships...", progress: 0.6)
        let inferStart = CFAbsoluteTimeGetCurrent()
        familyMembers = RelationshipCalculator.inferGenders(members: Array(membersWithRelations.values))
        let inferTime = (CFAbsoluteTimeGetCurrent() - inferStart) * 1000
        log.debug("inferGenders() in \(ms(inferTime))ms")

        if let myCard = myContactCard {
            updateProgress(stage: "Computing family tree structure...", progress: 0.7)
            log.debug("Precomputing family tree data with cached paths")
            let treeDataStart = CFAbsoluteTimeGetCurrent()
            treeData = FamilyTreeData(
                members: familyMembers,
                root: myCard,
                precomputedPaths: traversal.memberPaths,
                precomputedFamilySides: traversal.memberFamilySides
            ) { progress in
                let computedProgress = 0.7 + progress * 0.25
                self.initializationProgress = computedProgress
                if Int(progress * 100) % 10 == 0 {
                    let percent = Int(computedProgress * 100)
                    self.log.debug("Family tree structure computation progress \(percent)%")
                }
            }
            let treeDataTime = (CFAbsoluteTimeGetCurrent() - treeDataStart) * 1000
            log.debug("FamilyTreeData init in \(ms(treeDataTime))ms")
        }

        updateProgress(stage: "Ready!", progress: 1.0)

        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        log.debug("buildFamilyTree() in \(ms(totalTime))ms")
    }

    /// Traverses the contact graph using BFS to discover all connected family members.
    ///
    /// Uses a queue-based approach to find all contacts reachable through relationship links.
    /// Tracks paths from root to each discovered member for later relationship calculation.
    ///
    /// - Parameters:
    ///   - rootContact: The starting contact (typically "me")
    ///   - rootMember: The FamilyMember version of the root
    ///   - totalRelations: Total number of relations (for progress estimation)
    ///   - keysToFetch: Contact keys to fetch for each discovered contact
    ///   - progressUpdate: Callback for updating progress UI
    /// - Returns: Traversal result with discovered members, paths, and performance metrics
    private func traverseContacts(
        rootContact: CNContact,
        rootMember: FamilyMember,
        totalRelations: Int,
        keysToFetch: [CNKeyDescriptor],
        progressUpdate: (String, Double) -> Void
    ) -> TreeTraversalResult {
        var members: [String: FamilyMember] = [rootMember.id: rootMember]
        var processedIDs: Set<String> = [rootMember.id]
        var memberPaths: [String: [String]] = [rootMember.id: [rootMember.id]]
        var memberFamilySides: [String: FamilySide] = [rootMember.id: .own]
        var relationInfos: [RelationInfo] = []  // Collect all relations during traversal
        var queue: [(contact: CNContact, path: [String], familySide: FamilySide)] = [
            (rootContact, [rootMember.id], .own)
        ]

        var metrics = TraversalMetrics()
        let treeBuildStart = CFAbsoluteTimeGetCurrent()

        log.debug("🌳 [traverseContacts] Starting BFS traversal")
        log.debug("   Root member: \(rootMember.fullName)")
        log.debug("   Root contact relations: \(rootContact.contactRelations.count)")

        while !queue.isEmpty {
            let (currentContact, currentPath, currentFamilySide) = queue.removeFirst()
            let currentMemberId = currentPath.last ?? rootMember.id

            for relation in currentContact.contactRelations {
                let relationName = relation.value.name.trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip invalid relation names
                if relationName.hasSuffix(".") || relationName.hasSuffix("..") {
                    log.debug("Skipping relation '\(relationName)' due to trailing periods")
                    continue
                }

                // Collect all relation info for later processing
                let relationInfo = RelationInfo(
                    ownerContactId: currentContact.identifier,
                    label: relation.label ?? "Unknown",
                    relationName: relationName
                )
                relationInfos.append(relationInfo)

                let findStart = CFAbsoluteTimeGetCurrent()
                if let relatedContact = findContact(byName: relationName, keysToFetch: keysToFetch) {
                    metrics.recordFindContact(duration: CFAbsoluteTimeGetCurrent() - findStart)

                    if processedIDs.insert(relatedContact.identifier).inserted {
                        let convertStart = CFAbsoluteTimeGetCurrent()
                        let member = convertToFamilyMember(relatedContact)
                        metrics.recordConversion(duration: CFAbsoluteTimeGetCurrent() - convertStart)

                        members[member.id] = member
                        let newPath = currentPath + [member.id]
                        memberPaths[member.id] = newPath

                        // Determine family side for this member
                        let newFamilySide = determineFamilySideForMember(
                            currentPath: currentPath,
                            currentFamilySide: currentFamilySide,
                            relationLabel: relation.label,
                            isRoot: currentMemberId == rootMember.id
                        )
                        memberFamilySides[member.id] = newFamilySide

                        queue.append((relatedContact, newPath, newFamilySide))

                        metrics.memberCount = members.count
                        if members.count % 5 == 0 {
                            let denominator = Double(max(totalRelations * 2, 50))
                            let treeProgress = 0.3 + (Double(members.count) / denominator) * 0.3
                            let stage = "Building family tree... (\(members.count) members found)"
                            progressUpdate(stage, treeProgress)
                        }
                    }
                } else {
                    metrics.recordFindContact(duration: CFAbsoluteTimeGetCurrent() - findStart)
                }
            }
        }

        metrics.buildDurationMs = (CFAbsoluteTimeGetCurrent() - treeBuildStart) * 1000
        metrics.memberCount = members.count

        return TreeTraversalResult(
            members: members,
            memberPaths: memberPaths,
            memberFamilySides: memberFamilySides,
            relationInfos: relationInfos,
            metrics: metrics
        )
    }

    /// Builds relations with FamilyMember references and creates virtual members for missing relations.
    ///
    /// Takes the traversal result and:
    /// 1. Identifies all relation names that don't have corresponding contact cards
    /// 2. Creates virtual FamilyMember objects for those missing relations
    /// 3. Rebuilds all FamilyMembers with relations pointing to actual FamilyMember objects
    ///
    /// - Parameter traversal: The result of BFS traversal
    /// - Returns: Dictionary of FamilyMembers with fully resolved relations
    private func buildRelations(from traversal: TreeTraversalResult) -> [String: FamilyMember] {
        let buildStart = CFAbsoluteTimeGetCurrent()
        var members = traversal.members

        // Build a map of relation names to member IDs for quick lookup
        var nameToMemberId = buildNameToMemberIdMap(from: members)

        // Identify missing relations and create virtual members
        createVirtualMembersForMissingRelations(
            relationInfos: traversal.relationInfos,
            members: &members,
            nameToMemberId: &nameToMemberId
        )

        // Now rebuild all members with actual relations
        let updatedMembers = rebuildMembersWithRelations(
            members: members,
            relationInfos: traversal.relationInfos,
            nameToMemberId: &nameToMemberId
        )

        let buildDuration = (CFAbsoluteTimeGetCurrent() - buildStart) * 1000
        log.debug("buildRelations() in \(ms(buildDuration))ms")

        return updatedMembers
    }

    /// Determines family side during BFS traversal
    private func determineFamilySideForMember(
        currentPath: [String],
        currentFamilySide: FamilySide,
        relationLabel: String?,
        isRoot: Bool
    ) -> FamilySide {
        // If not at root, inherit the family side from the current branch
        guard isRoot else {
            return currentFamilySide
        }

        // At root, determine side based on relation label
        let label = relationLabel?.lowercased() ?? ""

        if label.contains("father") || label.contains("dad") {
            return .paternal
        }

        if label.contains("mother") || label.contains("mom") {
            return .maternal
        }

        if label.contains("spouse") || label.contains("wife") || label.contains("husband") {
            return .own
        }

        return .unknown
    }

    /// Logs detailed traversal performance metrics.
    private func logTraversalMetrics(_ metrics: TraversalMetrics) {
        log.debug("Traversal members: \(metrics.memberCount)")
        log.debug("Tree build: \(ms(metrics.buildDurationMs))ms")
        log.debug("findContact calls: \(metrics.findContactCount)")
        log.debug("  total: \(ms(metrics.findContactTotalMs))ms avg: \(ms(metrics.averageFindContactMs))ms")
        log.debug("Conversion calls: \(metrics.convertMemberCount)")
        log.debug("  total: \(ms(metrics.convertMemberTotalMs))ms avg: \(ms(metrics.averageConversionMs))ms")
    }

    /// Returns the list of CNContact keys needed for tree building.
    private func contactKeysToFetch() -> [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactDatesKey as CNKeyDescriptor
        ]
    }

    // MARK: - Helper Types

    /// Information about a relation discovered during traversal.
    struct RelationInfo {
        let ownerContactId: String  // ID of the contact that has this relation
        let label: String  // Relation label (e.g., "Mother", "Spouse")
        let relationName: String  // Name of the related person
    }

    /// Result of tree traversal containing discovered members and metrics.
    private struct TreeTraversalResult {
        let members: [String: FamilyMember]
        let memberPaths: [String: [String]]
        let memberFamilySides: [String: FamilySide]
        let relationInfos: [RelationInfo]  // All relations discovered during traversal
        let metrics: TraversalMetrics
    }

    /// Performance metrics tracked during tree traversal.
    private struct TraversalMetrics {
        var memberCount: Int = 1
        private(set) var findContactTotalMs: Double = 0
        private(set) var findContactCount: Int = 0
        private(set) var convertMemberTotalMs: Double = 0
        private(set) var convertMemberCount: Int = 0
        var buildDurationMs: Double = 0

        mutating func recordFindContact(duration: Double) {
            findContactTotalMs += duration * 1000
            findContactCount += 1
        }

        mutating func recordConversion(duration: Double) {
            convertMemberTotalMs += duration * 1000
            convertMemberCount += 1
        }

        var averageFindContactMs: Double {
            guard findContactCount > 0 else { return 0 }
            return findContactTotalMs / Double(findContactCount)
        }

        var averageConversionMs: Double {
            guard convertMemberCount > 0 else { return 0 }
            return convertMemberTotalMs / Double(convertMemberCount)
        }
    }

    /// Finds a contact by name from the Contacts database.
    ///
    /// Filters out invalid contacts (e.g., those with trailing periods).
    ///
    /// - Parameters:
    ///   - name: Full name to search for
    ///   - keysToFetch: Contact keys to fetch
    /// - Returns: Matched CNContact, or nil if not found
    private func findContact(byName name: String, keysToFetch: [CNKeyDescriptor]) -> CNContact? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't search for contacts with trailing periods
        guard !cleanedName.hasSuffix(".") && !cleanedName.hasSuffix("..") else {
            return nil
        }

        let predicate = CNContact.predicateForContacts(matchingName: cleanedName)

        do {
            let searchStart = CFAbsoluteTimeGetCurrent()
            let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            let searchTime = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000

            // Only log slow searches (>10ms) to avoid spam
            if searchTime > 10.0 {
                let duration = ms(searchTime)
                log.debug("Slow findContact '\(cleanedName)' \(duration)ms matches: \(contacts.count)")
            }

            // Filter out any results with trailing periods
            return contacts.first { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !fullName.hasSuffix(".") && !fullName.hasSuffix("..")
            }
        } catch {
            log.error("findContact('\(cleanedName)') failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Converts a CNContact to a FamilyMember model (without relations).
    ///
    /// Extracts image data, birth date, and basic contact information.
    /// Relations are built separately after all members are discovered.
    ///
    /// - Parameter contact: The CNContact to convert
    /// - Returns: FamilyMember model with empty relations
    func convertToFamilyMember(_ contact: CNContact) -> FamilyMember {
        let emails = contact.emailAddresses.map { $0.value as String }
        let phones = contact.phoneNumbers.map { $0.value.stringValue }

        // Use imageData if available, otherwise fall back to thumbnailImageData
        let imageData = contact.imageData ?? contact.thumbnailImageData

        // Convert CNContact birthday to Date
        // CNContact.birthday is a DateComponents, we need to convert it to Date
        let birthDate: Date?
        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            birthDate = date
        } else {
            birthDate = nil
        }

        // Extract marriage/anniversary date from dates
        let marriageDate: Date?
        if let anniversaryDate = contact.dates.first(where: { labeledValue in
            let label = labeledValue.label?.lowercased() ?? ""
            return label.contains("anniversary") || label.contains("marriage")
        }) {
            marriageDate = Calendar.current.date(from: anniversaryDate.value as DateComponents)
        } else {
            marriageDate = nil
        }

        // Include middle name in given name to match how relations reference people
        // e.g., "Anil Kumar Lal" has givenName="Anil", middleName="Kumar", familyName="Lal"
        // We need to store as givenName="Anil Kumar" so fullName="Anil Kumar Lal"
        let effectiveGivenName: String
        if !contact.middleName.isEmpty {
            effectiveGivenName = "\(contact.givenName) \(contact.middleName)".trimmingCharacters(in: .whitespaces)
        } else {
            effectiveGivenName = contact.givenName
        }

        return FamilyMember(
            id: contact.identifier,
            givenName: effectiveGivenName,
            familyName: contact.familyName,
            imageData: imageData,
            emailAddresses: emails,
            phoneNumbers: phones,
            relations: [],  // Relations will be built after all members are discovered
            birthDate: birthDate,
            marriageDate: marriageDate
        )
    }

    // MARK: - Helper Methods for Loading Me Contact

    /// Tries to load the "Me" contact from various sources
    private func tryLoadMeContact(keysToFetch: [CNKeyDescriptor]) -> CNContact? {
        // On macOS, use the unifiedMeContactWithKeys API
        #if os(macOS)
        if let contact = tryLoadMeContactFromMacOSAPI(keysToFetch: keysToFetch) {
            return contact
        }
        #endif

        // On iOS or if macOS API failed, check stored identifier
        return tryLoadMeContactFromUserDefaults(keysToFetch: keysToFetch)
    }

    #if os(macOS)
    private func tryLoadMeContactFromMacOSAPI(keysToFetch: [CNKeyDescriptor]) -> CNContact? {
        do {
            let contact = try contactStore.unifiedMeContactWithKeys(toFetch: keysToFetch)
            let name = "\(contact.givenName) \(contact.familyName)"
            log.debug("Found Me contact via unifiedMeContactWithKeys: \(name)")
            return contact
        } catch {
            log.debug("unifiedMeContactWithKeys failed: \(error.localizedDescription)")
            return nil
        }
    }
    #endif

    private func tryLoadMeContactFromUserDefaults(keysToFetch: [CNKeyDescriptor]) -> CNContact? {
        guard let storedId = UserDefaults.standard.string(forKey: "myContactIdentifier") else {
            return nil
        }

        log.debug("Trying stored me contact identifier: \(storedId)")

        do {
            let contact = try contactStore.unifiedContact(
                withIdentifier: storedId,
                keysToFetch: keysToFetch
            )
            log.debug("Successfully loaded stored me contact")
            return contact
        } catch {
            log.debug("Could not fetch stored me contact: \(error.localizedDescription)")
            // Clear invalid stored ID
            UserDefaults.standard.removeObject(forKey: "myContactIdentifier")
            return nil
        }
    }

    private func loadAllContactsForSelection(keysToFetch: [CNKeyDescriptor]) async throws {
        log.debug("No me contact found, fetching all contacts for user selection")
        updateProgress(stage: "Loading contacts...", progress: 0.15)

        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        var allContacts: [CNContact] = []

        try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
            allContacts.append(contact)
        }

        familyMembers = allContacts.map(convertToFamilyMember)
        needsUserToSelectMeContact = true
        updateProgress(stage: "Please select your contact", progress: 0.2)
        log.debug("Loaded \(allContacts.count) contacts for user selection")
    }
}
