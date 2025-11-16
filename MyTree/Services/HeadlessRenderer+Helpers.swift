//
//  HeadlessRenderer+Helpers.swift
//  MyTree
//
//  Helper functions for HeadlessRenderer to reduce complexity
//

import Foundation
import SwiftUI
import Contacts

#if os(macOS)

extension HeadlessRenderer {
    func selectRootByID(_ rootId: String, from manager: ContactsManager) throws -> FamilyMember {
        guard let root = manager.familyMembers.first(where: { $0.id == rootId }) else {
            throw HeadlessError.rootContactNotFound(rootId)
        }
        manager.myContactCard = root
        self.log("Using root contact by ID: \(root.fullName)")
        return root
    }

    func selectRootByName(_ rootName: String, from manager: ContactsManager) throws -> FamilyMember {
        let normalizedName = rootName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = normalizedName.split(separator: " ").map(String.init)

        // Try exact match
        if let root = findExactMatch(normalizedName, in: manager.familyMembers) {
            manager.myContactCard = root
            self.log("Using root contact by name: \(root.fullName) (searched for: \(rootName))")
            return root
        }

        // Try flexible match (first word of given name + family name)
        if let root = findFlexibleMatch(nameParts, in: manager.familyMembers) {
            manager.myContactCard = root
            self.log("Using root contact by name: \(root.fullName) (searched for: \(rootName))")
            return root
        }

        // Try partial match
        if let root = findPartialMatch(nameParts, normalizedName, in: manager.familyMembers) {
            manager.myContactCard = root
            self.log("Using root contact by name: \(root.fullName) (searched for: \(rootName))")
            return root
        }

        // Not found - log debug info and throw
        logAvailableContacts(in: manager, searchName: normalizedName)
        throw HeadlessError.rootContactNotFound(rootName)
    }

    func selectDefaultRoot(from manager: ContactsManager) throws -> FamilyMember {
        guard manager.myContactCard == nil else {
            return manager.myContactCard!
        }

        let defaultNames = ["John Doe", "Jane Smith"]
        for name in defaultNames {
            if let root = try? selectRootByName(name, from: manager) {
                self.log("Using default root contact for testing: \(root.fullName)")
                return root
            }
        }

        // Fallback to first contact
        guard let first = manager.familyMembers.first else {
            throw HeadlessError.noContactsFound
        }
        manager.myContactCard = first
        self.log("Using first contact as root: \(first.fullName)")
        return first
    }

    private func findExactMatch(_ normalizedName: String, in members: [FamilyMember]) -> FamilyMember? {
        return members.first { member in
            let fullName = member.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return fullName == normalizedName
        }
    }

    private func findFlexibleMatch(_ nameParts: [String], in members: [FamilyMember]) -> FamilyMember? {
        guard nameParts.count == 2 else { return nil }

        return members.first { member in
            let givenNameWords = member.givenName.lowercased().split(separator: " ")
            let firstGivenName = givenNameWords.first.map(String.init) ?? ""
            let familyName = member.familyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            return firstGivenName == nameParts[0] && familyName == nameParts[1]
        }
    }

    private func findPartialMatch(
        _ nameParts: [String],
        _ normalizedName: String,
        in members: [FamilyMember]
    ) -> FamilyMember? {
        return members.first { member in
            let fullName = member.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let givenName = member.givenName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let familyName = member.familyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if nameParts.count > 1 {
                return nameParts.allSatisfy { part in
                    fullName.contains(part) || givenName.contains(part) || familyName.contains(part)
                }
            } else {
                return givenName == normalizedName ||
                       familyName == normalizedName ||
                       fullName.contains(normalizedName) ||
                       normalizedName.contains(fullName)
            }
        }
    }

    private func logAvailableContacts(in manager: ContactsManager, searchName: String) {
        self.log("Available contacts (\(manager.familyMembers.count) total, showing first 20):")
        for (index, member) in manager.familyMembers.prefix(20).enumerated() {
            let memberInfo = "given: '\(member.givenName)', family: '\(member.familyName)'"
            self.log("  \(index + 1). \(member.fullName) (\(memberInfo))")
        }

        logSimilarContacts(in: manager, searchName: searchName)
    }

    private func logSimilarContacts(in manager: ContactsManager, searchName: String) {
        self.log("Searching for similar names...")
        let searchParts = searchName.split(separator: " ").map(String.init)
        var similar: [FamilyMember] = []

        for member in manager.familyMembers {
            let fullName = "\(member.givenName) \(member.familyName)".lowercased()
            let givenName = member.givenName.lowercased()
            let familyName = member.familyName.lowercased()

            let matches = searchParts.contains { part in
                fullName.contains(part) || givenName.contains(part) || familyName.contains(part)
            }
            if matches {
                similar.append(member)
            }
        }

        if !similar.isEmpty {
            self.log("Found similar contacts:")
            for member in similar.prefix(10) {
                self.log("  - \(member.fullName) (given: '\(member.givenName)', family: '\(member.familyName)')")
            }
        }
    }

    func buildFamilyTree(contactsManager: ContactsManager, rootContact: FamilyMember) throws -> FamilyTreeData {
        self.log("Step 3: Building family tree...")

        guard !contactsManager.familyMembers.isEmpty else {
            throw HeadlessError.noContactsFound
        }

        self.log("Creating tree data from loaded members with root: \(rootContact.fullName)...")
        let treeData = FamilyTreeData(
            members: contactsManager.familyMembers,
            root: rootContact,
            precomputedPaths: [:],
            precomputedFamilySides: [:]
        ) { _ in }

        contactsManager.treeData = treeData
        contactsManager.myContactCard = rootContact

        // Verify the root is reachable
        let rootDegree = treeData.degreeOfSeparation(for: rootContact.id)
        if rootDegree == Int.max {
            self.log("ERROR: Root contact is unreachable in tree data!")
        } else {
            self.log("Tree data created successfully. Root degree: \(rootDegree)")
        }

        return treeData
    }

    func filterContacts(treeData: FamilyTreeData, config: Config) -> [FamilyMember] {
        if let contactIds = config.contactIds {
            return filterByIDs(contactIds, in: treeData)
        } else if let contactNames = config.contactNames {
            return filterByNames(contactNames, in: treeData, degree: config.degreeOfSeparation)
        } else {
            return filterByDegree(config.degreeOfSeparation, in: treeData)
        }
    }

    private func filterByIDs(_ contactIds: [String], in treeData: FamilyTreeData) -> [FamilyMember] {
        let idSet = Set(contactIds)
        let filtered = treeData.members.filter { idSet.contains($0.id) }
        self.log("Filtered to \(filtered.count) contacts by ID from \(treeData.members.count) total")
        return filtered
    }

    private func filterByNames(_ names: [String], in treeData: FamilyTreeData, degree: Int) -> [FamilyMember] {
        let normalizedNames = Set(names.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })

        let nameMatchedMembers = treeData.members.filter { member in
            let fullName = "\(member.givenName) \(member.familyName)"
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let givenName = member.givenName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            return normalizedNames.contains(fullName) || normalizedNames.contains(givenName) ||
                normalizedNames.contains { name in
                    fullName.contains(name) || name.contains(fullName) ||
                    givenName.contains(name) || name.contains(givenName)
                }
        }

        self.log("Found \(nameMatchedMembers.count) contacts matching names: \(names.joined(separator: ", "))")

        // Include all members within degree of separation from matched members
        var membersWithinDegree: Set<String> = Set(nameMatchedMembers.map { $0.id })
        for matchedMember in nameMatchedMembers {
            let withinDegree = membersWithinDegreeFrom(
                memberId: matchedMember.id,
                maxDegree: degree,
                in: treeData
            )
            membersWithinDegree.formUnion(withinDegree)
        }

        let filtered = treeData.members.filter { membersWithinDegree.contains($0.id) }
        self.log("Including \(filtered.count) contacts within degree \(degree) from matched names")
        return filtered
    }

    private func filterByDegree(_ degree: Int, in treeData: FamilyTreeData) -> [FamilyMember] {
        let filtered = treeData.members(withinDegree: degree)
        self.log("Filtered to \(filtered.count) contacts within degree \(degree) from root")
        return filtered
    }

    func renderAndSave(
        treeData: FamilyTreeData,
        rootContact: FamilyMember,
        members: [FamilyMember],
        config: Config
    ) async throws {
        self.log("Step 4: Rendering tree to image...")
        let image = try await renderTreeView(
            treeData: treeData,
            rootContact: rootContact,
            membersToRender: members,
            config: config
        )

        self.log("Step 5: Saving image to \(config.outputImagePath)...")
        try saveImage(image, to: config.outputImagePath)

        self.log("Step 6: Saving logs to \(config.outputLogPath)...")
        try saveLogs(to: config.outputLogPath, logBuffer: logBuffer)
    }

    // MARK: - VCF Relation Building Helpers

    /// Context for building VCF relations with lookup tables
    struct RelationBuildingContext {
        var memberLookup: [String: FamilyMember]
        var virtualMembers: [String: FamilyMember]
        var nameToMemberId: [String: String]
    }

    func createMemberLookup(from members: [FamilyMember]) -> [String: FamilyMember] {
        var lookup: [String: FamilyMember] = [:]
        for member in members {
            lookup[member.id] = member
        }
        return lookup
    }

    func createNameLookup(from members: [FamilyMember]) -> [String: String] {
        var lookup: [String: String] = [:]
        for member in members {
            let normalizedName = "\(member.givenName) \(member.familyName)"
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lookup[normalizedName] = member.id
        }
        return lookup
    }

    func processContactRelations(
        _ contactRelations: [CNLabeledValue<CNContactRelation>],
        manager: ContactsManager,
        context: inout RelationBuildingContext
    ) -> [FamilyMember.Relation] {
        var relations: [FamilyMember.Relation] = []

        for relation in contactRelations {
            let label = relation.label ?? ""
            let name = relation.value.name
            let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            let relatedMember = findOrCreateRelatedMember(
                name: name,
                normalizedName: normalizedName,
                label: label,
                manager: manager,
                context: &context
            )

            relations.append(FamilyMember.Relation(
                label: label.isEmpty ? "Unknown" : label,
                member: relatedMember
            ))
        }

        return relations
    }

    func findOrCreateRelatedMember(
        name: String,
        normalizedName: String,
        label: String,
        manager: ContactsManager,
        context: inout RelationBuildingContext
    ) -> FamilyMember {
        // Try exact match
        if let memberId = context.nameToMemberId[normalizedName],
           let member = context.memberLookup[memberId] ?? context.virtualMembers[memberId] {
            return member
        }

        // Try flexible matching
        if let flexibleMatch = findFlexibleNameMatch(normalizedName, in: manager.familyMembers) {
            context.nameToMemberId[normalizedName] = flexibleMatch.id
            return flexibleMatch
        }

        // Create virtual member
        return createVirtualMember(
            name: name,
            normalizedName: normalizedName,
            label: label,
            virtualMembers: &context.virtualMembers,
            nameToMemberId: &context.nameToMemberId
        )
    }

    func findFlexibleNameMatch(_ normalizedName: String, in members: [FamilyMember]) -> FamilyMember? {
        let searchParts = normalizedName.split(separator: " ").map(String.init)
        guard searchParts.count == 2 else { return nil }

        return members.first { member in
            let givenNameWords = member.givenName.lowercased().split(separator: " ")
            let firstGivenName = givenNameWords.first.map(String.init) ?? ""
            let familyName = member.familyName.lowercased()
            return firstGivenName == searchParts[0] && familyName == searchParts[1]
        }
    }

    func createVirtualMember(
        name: String,
        normalizedName: String,
        label: String,
        virtualMembers: inout [String: FamilyMember],
        nameToMemberId: inout [String: String]
    ) -> FamilyMember {
        self.log("Creating virtual contact for relation: \(name) (label: \(label))")

        let nameParts = name.components(separatedBy: " ")
        let givenName = nameParts.first ?? name
        let familyName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""

        let virtualId = "virtual-\(UUID().uuidString)"
        let virtualMember = FamilyMember(
            id: virtualId,
            givenName: givenName,
            familyName: familyName,
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: [],
            birthDate: nil,
            marriageDate: nil,
            isVirtual: true
        )

        virtualMembers[virtualId] = virtualMember
        nameToMemberId[normalizedName] = virtualId

        return virtualMember
    }

    func updateMemberWithRelations(
        _ member: FamilyMember,
        relations: [FamilyMember.Relation]
    ) -> FamilyMember {
        return FamilyMember(
            id: member.id,
            givenName: member.givenName,
            familyName: member.familyName,
            imageData: member.imageData,
            emailAddresses: member.emailAddresses,
            phoneNumbers: member.phoneNumbers,
            relations: relations,
            birthDate: member.birthDate,
            marriageDate: member.marriageDate
        )
    }

    // MARK: - VCF Loading

    func loadContactsFromVCF(vcfPath: String, into manager: ContactsManager) async throws -> [CNContact] {
        // Resolve relative paths to absolute paths
        // Check multiple locations: absolute path, current directory, project directory (via environment)
        let resolvedPath: String
        if (vcfPath as NSString).isAbsolutePath {
            resolvedPath = vcfPath
        } else {
            // Try multiple locations
            let currentDir = FileManager.default.currentDirectoryPath
            let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ?? ""

            var candidates: [String] = []

            // 1. Current working directory
            candidates.append((currentDir as NSString).appendingPathComponent(vcfPath))

            // 2. Project root (if set via environment variable)
            if !projectRoot.isEmpty {
                candidates.append((projectRoot as NSString).appendingPathComponent(vcfPath))
            }

            // 3. Try to find project root by looking for common markers
            if let projectRoot = findProjectRoot() {
                candidates.append((projectRoot as NSString).appendingPathComponent(vcfPath))
            }

            // Find the first existing path
            resolvedPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        }

        let vcfURL = URL(fileURLWithPath: resolvedPath)
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw HeadlessError.vcfFileNotFound(resolvedPath)
        }

        self.log("Loading VCF from: \(resolvedPath)")

        // Use CNContactVCardSerialization to parse VCF
        let vcfData = try Data(contentsOf: vcfURL)
        let loadedContacts = try CNContactVCardSerialization.contacts(with: vcfData)

        self.log("Loaded \(loadedContacts.count) contacts from VCF")

        // Convert to FamilyMembers using ContactsManager's conversion method
        manager.familyMembers = loadedContacts.map { contact in
            manager.convertToFamilyMember(contact)
        }

        // Try to find "me" contact (usually the first one or one marked as such)
        if let first = manager.familyMembers.first {
            manager.myContactCard = first
            self.log("Set root contact: \(first.fullName)")
        }

        return loadedContacts
    }

    func findMemberByName(_ name: String, in members: [FamilyMember]) -> FamilyMember? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return members.first { member in
            let memberName = "\(member.givenName) \(member.familyName)"
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return memberName == normalizedName || member.givenName.lowercased() == normalizedName
        }
    }

    /// Attempts to find the project root directory by looking for common markers.
    func findProjectRoot() -> String? {
        let fileManager = FileManager.default
        var currentPath = fileManager.currentDirectoryPath

        // Walk up the directory tree looking for project markers
        for _ in 0..<10 { // Limit to 10 levels up
            let xcodeprojPath = (currentPath as NSString).appendingPathComponent("MyTree.xcodeproj")
            let makefilePath = (currentPath as NSString).appendingPathComponent("Makefile")
            let contactsVcfPath = (currentPath as NSString).appendingPathComponent("contacts.vcf")

            // Check if this looks like the project root
            let hasProjectMarker = fileManager.fileExists(atPath: xcodeprojPath) ||
                                   fileManager.fileExists(atPath: makefilePath)
            let hasContactsVcf = fileManager.fileExists(atPath: contactsVcfPath)

            // If we find project markers, this is likely the project root
            // (contacts.vcf is optional but preferred)
            if hasProjectMarker {
                return currentPath
            }

            // Also check if contacts.vcf exists here (might be project root even without markers)
            if hasContactsVcf {
                // Verify it's not just a random contacts.vcf by checking for other project files nearby
                let readmePath = (currentPath as NSString).appendingPathComponent("README.md")
                if fileManager.fileExists(atPath: readmePath) {
                    return currentPath
                }
            }

            // Move up one directory
            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath == currentPath {
                break // Reached root
            }
            currentPath = parentPath
        }

        return nil
    }

    // MARK: - BFS Utilities

    /// Computes all member IDs within a specified degree of separation from a given member using BFS.
    func membersWithinDegreeFrom(memberId: String, maxDegree: Int, in treeData: FamilyTreeData) -> Set<String> {
        guard maxDegree >= 0 else { return [] }

        var result: Set<String> = [memberId]
        var currentLevel: Set<String> = [memberId]
        var visited: Set<String> = [memberId]

        for _ in 1...maxDegree {
            var nextLevel: Set<String> = []
            for currentId in currentLevel {
                let neighbors = treeData.neighbors(of: currentId)
                for neighborId in neighbors where !visited.contains(neighborId) {
                    visited.insert(neighborId)
                    nextLevel.insert(neighborId)
                    result.insert(neighborId)
                }
            }
            currentLevel = nextLevel
            if currentLevel.isEmpty {
                break
            }
        }

        return result
    }
}

#endif
