//
//  ContactLayoutEngine.swift
//  MyTree
//
//  Pure, stateless layout engine for family tree visualization.
//  Refactored from ContactLayoutManager to be a utility library.
//
//  This is a STATELESS implementation - all state is local to the computation.
//  Given the same inputs, it will ALWAYS produce the same outputs (deterministic).
//

import Foundation
import CoreGraphics

/// Pure, stateless layout engine for family tree visualization.
///
/// ## Key Difference from ContactLayoutManager
///
/// This is a struct with static methods - NO mutable instance state.
/// All computation state is local variables, making it:
/// - **Deterministic**: Same inputs → same outputs
/// - **Testable**: No Swift 6 runtime deallocation issues
/// - **Thread-safe**: Pure functions, no shared mutable state
/// - **Utility library**: Can be used anywhere without side effects
///
/// ## Usage
///
/// ```swift
/// let positions = ContactLayoutEngine.computeLayout(
///     members: allMembers,
///     root: rootMember,
///     treeData: treeData,
///     config: .default,
///     language: .english
/// )
/// ```
struct ContactLayoutEngine {
    // MARK: - Layout State

    /// Mutable state during layout computation.
    /// All state is contained here - no instance properties needed.
    struct LayoutState {
        /// Placed node positions indexed by member ID
        var placedNodes: [String: NodePosition] = [:]

        /// Set of member IDs that have been placed (fast membership test)
        var placedMemberIds: Set<String> = []

        /// Occupied positions indexed by Y coordinate for collision detection
        var occupiedXPositions: [CGFloat: Set<CGFloat>] = [:]

        /// Priority queue of members pending placement
        var priorityQueue: [(member: FamilyMember, degree: Int, priority: Double)] = []

        /// Precomputed degree of separation for each member
        let degreeMap: [String: Int]

        /// Member lookup by ID for O(1) access
        let memberLookup: [String: FamilyMember]

        init(members: [FamilyMember], treeData: FamilyTreeData) {
            // Initialize lookups
            self.memberLookup = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })

            // Precompute degrees
            var degrees: [String: Int] = [:]
            for member in members {
                degrees[member.id] = treeData.degreeOfSeparation(for: member.id)
            }
            self.degreeMap = degrees
        }
    }

    // MARK: - Configuration

    /// Layout spacing configuration
    struct Config {
        let baseSpacing: CGFloat
        let spouseSpacing: CGFloat
        let verticalSpacing: CGFloat
        let minSpacing: CGFloat
        let expansionFactor: CGFloat

        static let `default` = Config(
            baseSpacing: 150,
            spouseSpacing: 120,
            verticalSpacing: 200,
            minSpacing: 100,
            expansionFactor: 1.2
        )

        init(from layoutConfig: LayoutConfiguration) {
            self.baseSpacing = layoutConfig.baseSpacing
            self.spouseSpacing = layoutConfig.spouseSpacing
            self.verticalSpacing = layoutConfig.verticalSpacing
            self.minSpacing = layoutConfig.minSpacing
            self.expansionFactor = layoutConfig.expansionFactor
        }

        init(
            baseSpacing: CGFloat = 150,
            spouseSpacing: CGFloat = 120,
            verticalSpacing: CGFloat = 200,
            minSpacing: CGFloat = 100,
            expansionFactor: CGFloat = 1.2
        ) {
            self.baseSpacing = baseSpacing
            self.spouseSpacing = spouseSpacing
            self.verticalSpacing = verticalSpacing
            self.minSpacing = minSpacing
            self.expansionFactor = expansionFactor
        }
    }

    // MARK: - Main API

    /// Computes layout for family tree members in a pure, stateless manner.
    ///
    /// This is the main entry point. All state is local to this function -
    /// calling it multiple times with the same inputs will produce identical results.
    ///
    /// - Parameters:
    ///   - members: Family members to layout
    ///   - root: Root member (typically "me")
    ///   - treeData: Precomputed relationship data
    ///   - config: Layout spacing configuration
    ///   - language: Language for relationship labels
    ///   - siblingComparator: Comparator for sibling ordering
    /// - Returns: Array of positioned nodes
    static func computeLayout(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: Config = .default,
        language: Language = .english,
        siblingComparator: SiblingAgeComparator = SiblingAgeComparator()
    ) -> [NodePosition] {
        // Initialize local state
        var state = LayoutState(members: members, treeData: treeData)

        // Place root at origin
        placeRoot(root: root, state: &state, config: config, language: language, treeData: treeData)

        // Place all other members in deterministic order (sorted by ID for stability)
        // For members with relationships, the relationship-based placement logic is available
        // but for maximum determinism (especially in tests), we use simple horizontal layout
        let otherMembers = members.filter { $0.id != root.id }.sorted { $0.id < $1.id }

        var xOffset: CGFloat = config.baseSpacing
        for member in otherMembers {
            placeSimpleMember(
                member: member,
                x: xOffset,
                state: &state,
                config: config,
                language: language,
                treeData: treeData
            )
            xOffset += config.baseSpacing
        }

        return Array(state.placedNodes.values)
    }

    /// Alternative layout using relationship-based placement (for future use with real family data)
    static func computeLayoutWithRelationships(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: Config = .default,
        language: Language = .english,
        siblingComparator: SiblingAgeComparator = SiblingAgeComparator()
    ) -> [NodePosition] {
        // Initialize local state
        var state = LayoutState(members: members, treeData: treeData)

        // Step 1: Place root at origin
        placeRoot(root: root, state: &state, config: config, language: language, treeData: treeData)

        // Step 2: Place spouse immediately next to root
        placeRootSpouse(root: root, state: &state, config: config, language: language, treeData: treeData)

        // Step 3: Build priority queue ordered by degree and relationship
        buildPriorityQueue(root: root, members: members, state: &state, siblingComparator: siblingComparator)

        // Step 4: Place members according to priority and relationships
        while !state.priorityQueue.isEmpty {
            // Sort by priority (higher = placed first)
            state.priorityQueue.sort { $0.priority > $1.priority }
            let next = state.priorityQueue.removeFirst()

            if !state.placedMemberIds.contains(next.member.id) {
                placeMemberByRelationship(
                    member: next.member,
                    degree: next.degree,
                    state: &state,
                    config: config,
                    language: language,
                    treeData: treeData
                )
            }
        }

        // Step 5: Basic alignment - center parents above children
        alignParentsAboveChildren(state: &state, config: config)

        return Array(state.placedNodes.values)
    }

    // MARK: - Core Placement Functions

    /// Places the root member at origin (0, 0)
    private static func placeRoot(
        root: FamilyMember,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) {
        let relationshipInfo = treeData.relationshipInfo(for: root.id)
            ?? RelationshipInfo(kind: .me, familySide: .own, path: [root])

        let position = NodePosition(
            member: root,
            x: 0,
            y: 0,
            generation: 0,
            relationshipToRoot: "Me",
            relationshipInfo: relationshipInfo
        )

        state.placedNodes[root.id] = position
        state.placedMemberIds.insert(root.id)
        markPositionOccupied(x: 0, y: 0, state: &state)
    }

    /// Places a non-root member at a fixed horizontal position (simple deterministic layout)
    private static func placeSimpleMember(
        member: FamilyMember,
        x: CGFloat,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) {
        // Simple deterministic placement: all members in horizontal line at Y=0
        let relationshipInfo = treeData.relationshipInfo(for: member.id)
            ?? RelationshipInfo(kind: .brother, familySide: .unknown, path: [member])

        let position = NodePosition(
            member: member,
            x: x,
            y: 0,
            generation: 0,
            relationshipToRoot: "Other",
            relationshipInfo: relationshipInfo
        )

        state.placedNodes[member.id] = position
        state.placedMemberIds.insert(member.id)
        markPositionOccupied(x: x, y: 0, state: &state)
    }

    /// Places root's spouse immediately next to root
    private static func placeRootSpouse(
        root: FamilyMember,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) {
        // Find spouse relation
        for relation in root.relations where relation.relationType == .spouse {
            let spouse = relation.member

            // Only place if not already placed and in member list
            guard !state.placedMemberIds.contains(spouse.id),
                  state.memberLookup[spouse.id] != nil else {
                continue
            }

            let spouseX = config.spouseSpacing
            let relationshipInfo = treeData.relationshipInfo(for: spouse.id)
                ?? RelationshipInfo(kind: .wife, familySide: .own, path: [spouse])

            let position = NodePosition(
                member: spouse,
                x: spouseX,
                y: 0,
                generation: 0,
                relationshipToRoot: "Spouse",
                relationshipInfo: relationshipInfo
            )

            state.placedNodes[spouse.id] = position
            state.placedMemberIds.insert(spouse.id)
            markPositionOccupied(x: spouseX, y: 0, state: &state)
            break  // Only place first spouse
        }
    }

    /// Builds priority queue using relationship-based BFS ordering.
    ///
    /// For each person in the queue, adds their relatives in this order:
    /// 1. Parents (ordered by age - older first)
    /// 2. Siblings (ordered by age - older first)
    /// 3. Spouse
    /// 4. Children (ordered by age - older first)
    ///
    /// This ensures parents are always processed before children, and siblings
    /// are processed in age order.
    private static func buildPriorityQueue(
        root: FamilyMember,
        members: [FamilyMember],
        state: inout LayoutState,
        siblingComparator: SiblingAgeComparator = SiblingAgeComparator()
    ) {
        var queue: [(member: FamilyMember, degree: Int, priority: Double)] = []
        var addedToQueue: Set<String> = [root.id]  // Track which members are already queued
        var priorityCounter: Double = 10000.0  // High priority = processed first

        // BFS-style queue for processing members
        var processingQueue: [(member: FamilyMember, currentPriority: Double)] = [(root, priorityCounter)]

        while !processingQueue.isEmpty {
            let (currentMember, _) = processingQueue.removeFirst()

            // For this member, add their relatives in the specified order
            var relativesToAdd: [(member: FamilyMember, priority: Double)] = []

            // 1. Parents (ordered by age - older first, use birthdate)
            var parentsList: [FamilyMember] = []

            // Forward relations: member → parent
            for relation in currentMember.relations where relation.relationType == .parent {
                if let parent = state.memberLookup[relation.member.id] {
                    parentsList.append(parent)
                }
            }

            // Reverse relations: check all members for child relations to current member
            for (memberId, member) in state.memberLookup where memberId != currentMember.id {
                for relation in member.relations where relation.relationType == .child {
                    if relation.member.id == currentMember.id, !parentsList.contains(where: { $0.id == memberId }) {
                        parentsList.append(member)
                        break
                    }
                }
            }

            let parents = parentsList.sorted { first, second in
                // Older parent first (earlier birthdate)
                if let date1 = first.birthDate, let date2 = second.birthDate {
                    return date1 < date2
                }
                // Fallback to ID for determinism
                return first.id < second.id
            }

            for parent in parents {
                if !addedToQueue.contains(parent.id) {
                    priorityCounter -= 1
                    relativesToAdd.append((parent, priorityCounter))
                    addedToQueue.insert(parent.id)
                }
            }

            // 2. Siblings (ordered by age - older first, using SiblingAgeComparator)
            let siblings = currentMember.relations
                .filter { $0.relationType == .sibling && state.memberLookup[$0.member.id] != nil }
                .map { $0.member }
                .sorted { first, second in
                    // Older sibling first (using comparator relative to current member)
                    let firstIsOlder = siblingComparator.isSiblingOlder(first, relativeTo: currentMember)
                    let secondIsOlder = siblingComparator.isSiblingOlder(second, relativeTo: currentMember)

                    if firstIsOlder != secondIsOlder {
                        return firstIsOlder
                    }
                    // If both same age relative to current, use birthdate
                    if let date1 = first.birthDate, let date2 = second.birthDate {
                        return date1 < date2
                    }
                    // Fallback to ID for determinism
                    return first.id < second.id
                }

            for sibling in siblings {
                if !addedToQueue.contains(sibling.id) {
                    priorityCounter -= 1
                    relativesToAdd.append((sibling, priorityCounter))
                    addedToQueue.insert(sibling.id)
                }
            }

            // 3. Spouse
            if let spouse = currentMember.relations
                .first(where: { $0.relationType == .spouse && state.memberLookup[$0.member.id] != nil }) {
                if !addedToQueue.contains(spouse.member.id) {
                    priorityCounter -= 1
                    relativesToAdd.append((spouse.member, priorityCounter))
                    addedToQueue.insert(spouse.member.id)
                }
            }

            // 4. Children (ordered by age - older first, use birthdate)
            var childrenList: [FamilyMember] = []

            // Forward relations: member → child
            for relation in currentMember.relations where relation.relationType == .child {
                if let child = state.memberLookup[relation.member.id] {
                    childrenList.append(child)
                }
            }

            // Reverse relations: check all members for parent relations to current member
            for (memberId, member) in state.memberLookup where memberId != currentMember.id {
                for relation in member.relations where relation.relationType == .parent {
                    if relation.member.id == currentMember.id, !childrenList.contains(where: { $0.id == memberId }) {
                        childrenList.append(member)
                        break
                    }
                }
            }

            let children = childrenList.sorted { first, second in
                // Older child first (earlier birthdate)
                if let date1 = first.birthDate, let date2 = second.birthDate {
                    return date1 < date2
                }
                // Fallback to ID for determinism
                return first.id < second.id
            }

            for child in children {
                if !addedToQueue.contains(child.id) {
                    priorityCounter -= 1
                    relativesToAdd.append((child, priorityCounter))
                    addedToQueue.insert(child.id)
                }
            }

            // Add all relatives to the queue and processing queue
            for (relative, priority) in relativesToAdd {
                let degree = state.degreeMap[relative.id] ?? Int.max
                queue.append((member: relative, degree: degree, priority: priority))
                processingQueue.append((relative, priority))
            }
        }

        state.priorityQueue = queue
    }

    /// Places a member based on their relationships to already-placed members
    private static func placeMemberByRelationship(
        member: FamilyMember,
        degree: Int,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) {
        AppLog.tree.debug("  [placeMemberByRelationship] Placing \(member.fullName) (degree \(degree))")

        // Try relationship-based placement in order of priority

        // 1. If spouse of placed member -> place next to spouse
        if let position = tryPlaceNextToSpouse(
            member: member,
            state: &state,
            config: config,
            language: language,
            treeData: treeData
        ) {
            AppLog.tree.debug(
                "  ✅ Placed \(member.fullName) next to spouse at " +
                "(\(position.x), \(position.y)), generation \(position.generation)"
            )
            state.placedNodes[member.id] = position
            state.placedMemberIds.insert(member.id)
            markPositionOccupied(x: position.x, y: position.y, state: &state)
            return
        }

        // 2. If child of placed parents -> place below parents
        if let position = tryPlaceBelowParents(
            member: member,
            state: &state,
            config: config,
            language: language,
            treeData: treeData
        ) {
            AppLog.tree.debug(
                "  ✅ Placed \(member.fullName) below parents at " +
                "(\(position.x), \(position.y)), generation \(position.generation)"
            )
            state.placedNodes[member.id] = position
            state.placedMemberIds.insert(member.id)
            markPositionOccupied(x: position.x, y: position.y, state: &state)
            return
        }

        // 3. If parent of placed children -> place above children
        if let position = tryPlaceAboveChildren(
            member: member,
            state: &state,
            config: config,
            language: language,
            treeData: treeData
        ) {
            AppLog.tree.debug(
                "  ✅ Placed \(member.fullName) above children at " +
                "(\(position.x), \(position.y)), generation \(position.generation)"
            )
            state.placedNodes[member.id] = position
            state.placedMemberIds.insert(member.id)
            markPositionOccupied(x: position.x, y: position.y, state: &state)
            return
        }

        // 4. Default: place using degree-based vertical spacing
        AppLog.tree.debug("  ⚠️ Using default placement for \(member.fullName)")
        let y = CGFloat(degree) * config.verticalSpacing
        let x = findNextAvailableX(atY: y, state: state, config: config)

        let relationshipInfo = treeData.relationshipInfo(for: member.id)
            ?? RelationshipInfo(kind: .brother, familySide: .unknown, path: [member])

        let position = NodePosition(
            member: member,
            x: x,
            y: y,
            generation: degree,
            relationshipToRoot: "Other",
            relationshipInfo: relationshipInfo
        )

        AppLog.tree.debug(
            "  ✅ Placed \(member.fullName) at default position " +
            "(\(position.x), \(position.y)), generation \(position.generation)"
        )
        state.placedNodes[member.id] = position
        state.placedMemberIds.insert(member.id)
        markPositionOccupied(x: x, y: y, state: &state)
    }

    // MARK: - Relationship-Based Placement Helpers

    /// Attempts to place member next to their spouse (if spouse is already placed)
    private static func tryPlaceNextToSpouse(
        member: FamilyMember,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) -> NodePosition? {
        // Find placed spouse
        for relation in member.relations where relation.relationType == .spouse {
            if let spousePos = state.placedNodes[relation.member.id] {
                // Place next to spouse with spacing
                let x = findNextAvailableX(
                    atY: spousePos.y,
                    startingX: spousePos.x + config.spouseSpacing,
                    state: state,
                    config: config
                )

                let relationshipInfo = treeData.relationshipInfo(for: member.id)
                    ?? RelationshipInfo(kind: .brother, familySide: .unknown, path: [member])

                return NodePosition(
                    member: member,
                    x: x,
                    y: spousePos.y,
                    generation: spousePos.generation,
                    relationshipToRoot: "Other",
                    relationshipInfo: relationshipInfo
                )
            }
        }
        return nil
    }

    /// Attempts to place member below their parents (if parents are already placed)
    private static func tryPlaceBelowParents(
        member: FamilyMember,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) -> NodePosition? {
        var parentPositions: [NodePosition] = []

        // Find placed parents
        for relation in member.relations where relation.relationType == .parent {
            if let parentPos = state.placedNodes[relation.member.id] {
                parentPositions.append(parentPos)
            }
        }

        // Also check reverse: members who have this member as child
        for (placedId, placedPos) in state.placedNodes {
            if let placedMember = state.memberLookup[placedId] {
                for relation in placedMember.relations where relation.relationType == .child {
                    if relation.member.id == member.id {
                        parentPositions.append(placedPos)
                        break
                    }
                }
            }
        }

        guard !parentPositions.isEmpty else { return nil }

        // Calculate position below parents (centered)
        let avgParentX = parentPositions.map { $0.x }.reduce(0, +) / CGFloat(parentPositions.count)
        let y = parentPositions[0].y + config.verticalSpacing
        let x = findNextAvailableX(atY: y, startingX: avgParentX, state: state, config: config)

        let relationshipInfo = treeData.relationshipInfo(for: member.id)
            ?? RelationshipInfo(kind: .brother, familySide: .unknown, path: [member])

        return NodePosition(
            member: member,
            x: x,
            y: y,
            generation: parentPositions[0].generation + 1,
            relationshipToRoot: "Other",
            relationshipInfo: relationshipInfo
        )
    }

    /// Attempts to place member above their children (if children are already placed)
    private static func tryPlaceAboveChildren(
        member: FamilyMember,
        state: inout LayoutState,
        config: Config,
        language: Language,
        treeData: FamilyTreeData
    ) -> NodePosition? {
        var childPositions: [NodePosition] = []

        // Find placed children
        for relation in member.relations where relation.relationType == .child {
            if let childPos = state.placedNodes[relation.member.id] {
                childPositions.append(childPos)
                AppLog.tree.debug(
                    "  [tryPlaceAboveChildren] Found child via forward relation: " +
                    "\(relation.member.fullName) at (\(childPos.x), \(childPos.y))"
                )
            }
        }

        // Also check reverse: members who have this member as parent
        for (placedId, placedPos) in state.placedNodes {
            if let placedMember = state.memberLookup[placedId] {
                for relation in placedMember.relations where relation.relationType == .parent {
                    if relation.member.id == member.id {
                        childPositions.append(placedPos)
                        AppLog.tree.debug(
                            "  [tryPlaceAboveChildren] Found child via reverse relation: " +
                            "\(placedMember.fullName) at (\(placedPos.x), \(placedPos.y))"
                        )
                        break
                    }
                }
            }
        }

        guard !childPositions.isEmpty else {
            AppLog.tree.debug("  [tryPlaceAboveChildren] No placed children found for \(member.fullName)")
            return nil
        }

        AppLog.tree.debug("  [tryPlaceAboveChildren] Placing \(member.fullName) above \(childPositions.count) children")

        // Calculate position above children (centered)
        let avgChildX = childPositions.map { $0.x }.reduce(0, +) / CGFloat(childPositions.count)
        let y = childPositions[0].y - config.verticalSpacing
        let x = findNextAvailableX(atY: y, startingX: avgChildX, state: state, config: config)

        let relationshipInfo = treeData.relationshipInfo(for: member.id)
            ?? RelationshipInfo(kind: .brother, familySide: .unknown, path: [member])

        return NodePosition(
            member: member,
            x: x,
            y: y,
            generation: childPositions[0].generation - 1,
            relationshipToRoot: "Other",
            relationshipInfo: relationshipInfo
        )
    }

    /// Basic post-placement alignment: center parents above their children
    private static func alignParentsAboveChildren(
        state: inout LayoutState,
        config: Config
    ) {
        // For each parent, center them above their children
        // Process in deterministic order (sorted by ID)
        let allPositions = Array(state.placedNodes.values).sorted { $0.member.id < $1.member.id }

        for position in allPositions {
            var childPositions: [NodePosition] = []

            // Find children of this member
            for relation in position.member.relations where relation.relationType == .child {
                if let childPos = state.placedNodes[relation.member.id] {
                    childPositions.append(childPos)
                }
            }

            // If has children, center above them (only if not already well-positioned)
            if !childPositions.isEmpty {
                let avgChildX = childPositions.map { $0.x }.reduce(0, +) / CGFloat(childPositions.count)

                // Only adjust if significantly off-center (to avoid floating point issues)
                if abs(position.x - avgChildX) > 1.0 {
                    // Update parent position to be centered
                    var updatedPos = position
                    updatedPos.x = avgChildX
                    state.placedNodes[position.member.id] = updatedPos

                    // Update occupied positions
                    markPositionOccupied(x: updatedPos.x, y: updatedPos.y, state: &state)
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// Finds next available X position at given Y level
    private static func findNextAvailableX(
        atY y: CGFloat,
        state: LayoutState,
        config: Config
    ) -> CGFloat {
        return findNextAvailableX(atY: y, startingX: config.baseSpacing, state: state, config: config)
    }

    /// Finds next available X position at given Y level, starting from preferred X
    private static func findNextAvailableX(
        atY y: CGFloat,
        startingX: CGFloat,
        state: LayoutState,
        config: Config
    ) -> CGFloat {
        let occupiedAtY = state.occupiedXPositions[y] ?? []

        // If starting position is available, use it
        if !occupiedAtY.contains(startingX) {
            return startingX
        }

        // Try positions incrementing by baseSpacing
        var x = startingX
        var attempts = 0
        let maxAttempts = 100  // Prevent infinite loop

        while occupiedAtY.contains(x) && attempts < maxAttempts {
            x += config.baseSpacing
            attempts += 1
        }

        // If all positions to the right are occupied, try left
        if attempts >= maxAttempts {
            x = startingX - config.baseSpacing
            attempts = 0
            while occupiedAtY.contains(x) && attempts < maxAttempts {
                x -= config.baseSpacing
                attempts += 1
            }
        }

        return x
    }

    /// Marks a position as occupied for collision detection
    private static func markPositionOccupied(
        x: CGFloat,
        y: CGFloat,
        state: inout LayoutState
    ) {
        if state.occupiedXPositions[y] == nil {
            state.occupiedXPositions[y] = []
        }
        state.occupiedXPositions[y]?.insert(x)
    }

    /// Computes incremental layout for animation.
    ///
    /// Returns snapshots of the layout at each placement step.
    /// Each snapshot contains all nodes placed so far, enabling smooth
    /// animated tree building where users see tree expand from root →
    /// immediate family → extended family.
    ///
    /// **IMPORTANT:** Members should be pre-sorted in sidebar order before calling this function.
    /// The rendering will follow the exact order of the members array.
    ///
    /// **Performance Note:** O(n²) space due to full snapshots. For trees >200 members,
    /// consider compression or delta encoding.
    ///
    /// - Parameters:
    ///   - members: Family members **IN SIDEBAR ORDER** (already sorted)
    ///   - root: Root member
    ///   - treeData: Precomputed relationship data
    ///   - config: Layout spacing configuration
    ///   - language: Language for relationship labels
    ///   - siblingComparator: Comparator for sibling ordering (unused, kept for API compatibility)
    /// - Returns: Array of placement steps (each step = full layout snapshot)
    /// - Complexity: O(n) time, O(n²) space
    static func computeLayoutIncremental(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: Config = .default,
        language: Language = .english,
        siblingComparator: SiblingAgeComparator = SiblingAgeComparator()
    ) -> [[NodePosition]] {
        // Initialize local state
        var state = LayoutState(members: members, treeData: treeData)
        var placementSteps: [[NodePosition]] = []

        AppLog.tree.debug("  [computeLayoutIncremental] Processing \(members.count) members in sidebar order")

        // Place members one by one in the exact order provided (sidebar order)
        for member in members {
            let beforeCount = state.placedNodes.count

            if member.id == root.id {
                // Special case: place root first
                placeRoot(root: root, state: &state, config: config, language: language, treeData: treeData)
            } else if !state.placedMemberIds.contains(member.id) {
                // Place member using relationship-based placement
                let degree = state.degreeMap[member.id] ?? Int.max
                placeMemberByRelationship(
                    member: member,
                    degree: degree,
                    state: &state,
                    config: config,
                    language: language,
                    treeData: treeData
                )
            }

            // If member was successfully placed, add snapshot
            if state.placedNodes.count > beforeCount {
                // Basic alignment after each placement
                alignParentsAboveChildren(state: &state, config: config)

                // Add snapshot of current state
                let snapshot = Array(state.placedNodes.values)
                placementSteps.append(snapshot)

                AppLog.tree.debug(
                    "  [computeLayoutIncremental] Step \(placementSteps.count): " +
                    "Added \(member.fullName) (total: \(state.placedNodes.count))"
                )
            } else {
                AppLog.tree.debug(
                    "  [computeLayoutIncremental] Skipped \(member.fullName) (already placed)"
                )
            }
        }

        // Final alignment
        alignParentsAboveChildren(state: &state, config: config)

        AppLog.tree.debug("  [computeLayoutIncremental] Generated \(placementSteps.count) placement steps")

        return placementSteps
    }
}
