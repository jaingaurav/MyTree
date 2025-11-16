//
//  ContactLayoutManager.swift
//  MyTree
//
//  Priority-based graph layout algorithm for family tree visualization.
//  O(n log n) complexity via sorted priority queue and precomputed relationships.
//

import Foundation
import SwiftUI

/// Manages spatial layout of family tree nodes using relationship-aware positioning.
///
/// ## Algorithm Overview
///
/// **Phase 1:** Build priority queue (O(n log n))
/// - Sort by degree of separation + relationship bonus
/// - Closer relatives placed first (spouse=+50, parent=+30, child=+20)
///
/// **Phase 2:** Iterative placement (O(n))
/// - Pop highest priority member
/// - Calculate position based on relationship (spouse adjacent, child below parent, etc.)
/// - Apply collision avoidance if position occupied
/// - Perform local realignment (parent-child centering)
///
/// **Phase 3:** Global realignment + dynamic spacing (O(n))
/// - Adjust spacing if tree is crowded
/// - Center parent couples above their children
/// - Align generations horizontally
///
/// ## Configuration
///
/// Spacing parameters control layout density:
/// - `baseSpacing`: Horizontal gap between unrelated nodes (default: 150px)
/// - `spouseSpacing`: Horizontal gap between married couples (default: 120px)
/// - `verticalSpacing`: Vertical gap between generations (default: 200px)
/// - `minSpacing`: Minimum allowed gap to prevent overlap (default: 100px)
/// - `expansionFactor`: Growth rate for dynamic spacing (default: 1.2)
///
/// ## Coordinate System
///
/// - X-axis: Horizontal position (left-right)
/// - Y-axis: Vertical position (generation-based)
///   - Positive Y: Parents, grandparents (upward)
///   - Zero Y: Root and siblings
///   - Negative Y: Children, grandchildren (downward)
///
/// ## Thread Safety
///
/// Not thread-safe. Use from single thread only (typically main thread).
///
/// ## See Also
///
/// - `LayoutOrchestrator`: High-level orchestration with error handling
/// - `LAYOUT_ALGORITHM.md`: Detailed algorithm documentation
final class ContactLayoutManager {
    // MARK: - Configuration

    /// Horizontal distance between unrelated contacts.
    var baseSpacing: CGFloat

    /// Horizontal distance between married couples (typically less than baseSpacing).
    var spouseSpacing: CGFloat

    /// Vertical distance between generations (parent-child).
    var verticalSpacing: CGFloat

    /// Minimum spacing to prevent overlap (hard constraint).
    var minSpacing: CGFloat

    /// Factor for dynamic spacing expansion (>1.0). Spacing grows logarithmically with tree size.
    var expansionFactor: CGFloat

    // MARK: - Dependencies

    /// All family members to layout (filtered subset of full tree).
    let members: [FamilyMember]

    /// Root contact (typically "me"). Placed at origin (0, 0).
    let root: FamilyMember

    /// Precomputed relationship data for O(1) degree/relationship lookups.
    let treeData: FamilyTreeData

    /// Comparator for age-based sibling ordering (older left, younger right).
    let siblingAgeComparator: SiblingAgeComparator

    // MARK: - State

    /// Precomputed degree of separation for each member (cached for performance).
    var degreeMap: [String: Int] = [:]

    /// Placed node positions indexed by member ID.
    var placedNodes: [String: NodePosition] = [:]

    /// Set of member IDs that have been placed (fast membership test).
    var placedMemberIds: Set<String> = []

    /// Occupied positions indexed by Y coordinate for collision detection.
    /// Maps Y → Set of X coordinates occupied at that Y level.
    var occupiedXPositions: [CGFloat: Set<CGFloat>] = [:]

    /// Priority queue of members pending placement, sorted by closeness to root.
    var priorityQueue: [(member: FamilyMember, degree: Int, priority: Double)] = []

    /// Member lookup by ID for O(1) access.
    let memberLookup: [String: FamilyMember]

    // MARK: - Initialization

    init(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        baseSpacing: CGFloat = 150,
        spouseSpacing: CGFloat = 120,
        verticalSpacing: CGFloat = 200,
        minSpacing: CGFloat = 100,
        expansionFactor: CGFloat = 1.2,
        siblingAgeComparator: SiblingAgeComparator = SiblingAgeComparator()
    ) {
        self.members = members
        self.root = root
        self.treeData = treeData
        self.baseSpacing = baseSpacing
        self.spouseSpacing = spouseSpacing
        self.verticalSpacing = verticalSpacing
        self.minSpacing = minSpacing
        self.expansionFactor = expansionFactor
        self.siblingAgeComparator = siblingAgeComparator

        // Initialize member lookup dictionary
        self.memberLookup = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })

        for member in members {
            degreeMap[member.id] = treeData.degreeOfSeparation(for: member.id)
        }
    }

    // MARK: - State Management

    /// Resets internal state for fresh layout calculation.
    func resetState() {
        placedNodes.removeAll()
        placedMemberIds.removeAll()
        occupiedXPositions.removeAll()
        priorityQueue.removeAll()
    }

    /// Updates internal state with new positions and recalculates parent-child centering.
    /// Used after anchoring the root to restore proper parent-child alignment.
    func updateStateAndRealignGroups(with positions: [NodePosition]) -> [NodePosition] {
        // Update placedNodes with new positions
        placedNodes.removeAll()
        for position in positions {
            placedNodes[position.member.id] = position
            placedMemberIds.insert(position.member.id)
        }

        // Update occupied positions
        occupiedXPositions.removeAll()
        for position in positions {
            markPositionOccupied(x: position.x, y: position.y)
        }

        // Recalculate parent-child centering
        realignGroups()

        return Array(placedNodes.values)
    }

    // MARK: - Public API

    /// Generates complete layout in single pass.
    ///
    /// Use when immediate final layout is needed (e.g., static rendering, exports).
    /// For animated rendering, use `layoutNodesIncremental()` instead.
    ///
    /// - Parameter language: Language for relationship labels (e.g., "Father" vs "Padre")
    /// - Returns: Array of all node positions
    /// - Complexity: O(n log n) where n = member count
    func layoutNodes(language: Language) -> [NodePosition] {
        resetState()
        buildPriorityQueue()
        placeRoot(language: language)
        placeSpouseImmediately(language: language)

        while !priorityQueue.isEmpty {
            priorityQueue.sort { $0.priority > $1.priority }
            let next = priorityQueue.removeFirst()

            if !placedMemberIds.contains(next.member.id) {
                placeMember(next.member, language: language)
                realignGroups()
            }
        }

        realignGroups()
        adjustDynamicSpacing()

        return Array(placedNodes.values)
    }

    /// Generates layout incrementally for progressive rendering/animation.
    ///
    /// Returns array of snapshots, one per placed node. Each snapshot contains
    /// all nodes placed so far. Enables smooth animated tree building where users
    /// see tree expand from root → immediate family → extended family.
    ///
    /// **Performance Note:** O(n²) space due to full snapshots. For trees >200 members,
    /// consider compression or delta encoding.
    ///
    /// - Parameter language: Language for relationship labels
    /// - Returns: Array of placement steps (each step = full layout snapshot)
    /// - Complexity: O(n log n) time, O(n²) space
    func layoutNodesIncremental(language: Language) -> [[NodePosition]] {
        resetState()
        var placementSteps: [[NodePosition]] = []

        buildPriorityQueue()

        placeRoot(language: language)
        guard let rootPosition = placedNodes[root.id] else {
            AppLog.tree.error("Failed to place root node during incremental layout")
            return []
        }
        placementSteps.append([rootPosition])

        let beforeSpouse = placedNodes.count
        placeSpouseImmediately(language: language)
        if placedNodes.count > beforeSpouse {
            placementSteps.append(Array(placedNodes.values))
        }

        while !priorityQueue.isEmpty {
            priorityQueue.sort { $0.priority > $1.priority }
            let next = priorityQueue.removeFirst()

            if !placedMemberIds.contains(next.member.id) {
                let beforeCount = placedNodes.count
                placeMember(next.member, language: language)

                if placedNodes.count > beforeCount {
                    // Realign parents if the newly placed member is a child
                    realignLocalParentsOnly(forNewlyPlaced: next.member.id)

                    // Realign if the newly placed member is a parent (spouse) with children
                    realignParentCoupleAboveChildren(forNewlyPlaced: next.member.id)

                    // Realign siblings if the newly placed member is a child
                    realignSiblingsUnderParents(forNewlyPlaced: next.member.id)

                    placementSteps.append(Array(placedNodes.values))
                }
            }
        }

        realignGroups()
        adjustDynamicSpacing()

        return placementSteps
    }

    // MARK: - Priority Queue

    /// Builds priority queue using hierarchical ordering by degree.
    ///
    /// **Ordering Algorithm:**
    /// - Degree 0: Root (handled separately, not in queue)
    /// - Degree 1 (from root): Parents (by age, or father before mother) → Siblings (by birth date) → Spouse → Children (by age)
    /// - Degree 2+: For each degree N-1 member, apply degree 1 ordering relative to that member
    ///
    /// This ensures that when processing degree 2, all relatives of degree 1 members are added
    /// before moving to the next degree 1 member (e.g., root's grandparents/uncles before spouse's parents).
    func buildPriorityQueue() {
        var queue: [(member: FamilyMember, degree: Int, priority: Double)] = []

        // Get all members except root, grouped by degree
        let membersByDegree = Dictionary(grouping: members.filter { $0.id != root.id }) { member in
            degreeMap[member.id] ?? Int.max
        }

        // Process degrees in order (1, 2, 3, ...)
        let sortedDegrees = membersByDegree.keys.sorted()

        for degree in sortedDegrees {
            guard let degreeMembers = membersByDegree[degree] else { continue }

            if degree == 1 {
                // Degree 1: Order relative to root
                let ordered = orderMembersForDegree1(degreeMembers, relativeTo: root)
                for (index, member) in ordered.enumerated() {
                    // Higher priority = lower index (placed earlier)
                    // Use large base priority to ensure degree 1 comes before degree 2
                    let priority = Double(10000 - index)
                    queue.append((member: member, degree: degree, priority: priority))
                }
            } else {
                // Degree 2+: For each member of degree (N-1), add their degree N relatives
                let previousDegree = degree - 1
                guard let previousDegreeMembers = membersByDegree[previousDegree] else { continue }

                // Sort previous degree members by their order in the priority queue
                // This ensures we process them in the same order they will be placed
                // Create a map of member ID to their order in degree 1 queue
                let degree1Queue = queue.filter { $0.degree == 1 }
                var degree1Order: [String: Int] = [:]
                for (index, item) in degree1Queue.enumerated() {
                    degree1Order[item.member.id] = index
                }

                // Sort by their order in degree 1 queue, or by ID for deterministic ordering
                let sortedPreviousDegree = previousDegreeMembers.sorted { member1, member2 in
                    if let order1 = degree1Order[member1.id], let order2 = degree1Order[member2.id] {
                        return order1 < order2
                    }
                    // If not in degree 1 queue (shouldn't happen), use ID for stable ordering
                    return member1.id < member2.id
                }

                var priorityOffset = Double(10000 - degree * 1000)

                // For each previous degree member, add their relatives of current degree
                for previousMember in sortedPreviousDegree {
                    // Find relatives of current degree that are related to this previous degree member
                    let relatedMembers = degreeMembers.filter { member in
                        hasRelationship(from: previousMember, to: member) ||
                        hasRelationship(from: member, to: previousMember)
                    }

                    if !relatedMembers.isEmpty {
                        // Order these relatives using degree 1 ordering relative to previousMember
                        let ordered = orderMembersForDegree1(relatedMembers, relativeTo: previousMember)
                        for (index, member) in ordered.enumerated() {
                            let priority = priorityOffset + Double(ordered.count - index)
                            queue.append((member: member, degree: degree, priority: priority))
                        }
                        priorityOffset -= Double(ordered.count + 100) // Ensure next group has lower priority
                    }
                }

                // Add any remaining degree members that weren't related to previous degree members
                let processedIds = Set(queue.filter { $0.degree == degree }.map { $0.member.id })
                let remaining = degreeMembers.filter { !processedIds.contains($0.id) }
                for (index, member) in remaining.enumerated() {
                    let priority = priorityOffset - Double(index)
                    queue.append((member: member, degree: degree, priority: priority))
                }
            }
        }

        priorityQueue = queue
    }

    /// Orders members for degree 1 placement relative to a focus member.
    /// Order: Parents (by age, or father before mother) → Siblings (by birth date) → Spouse → Children (by age)
    private func orderMembersForDegree1(_ members: [FamilyMember], relativeTo focus: FamilyMember) -> [FamilyMember] {
        var parents: [FamilyMember] = []
        var siblings: [FamilyMember] = []
        var spouse: FamilyMember?
        var children: [FamilyMember] = []

        // Categorize members by relationship to focus (checking both forward and reverse relationships)
        for member in members {
            // Check if member is a parent of focus (forward: focus has member as parent, reverse: member has focus as child)
            if hasRelationshipType(from: focus, to: member, type: .parent) ||
               hasRelationshipType(from: member, to: focus, type: .child) {
                parents.append(member)
            }
            // Check if member is a sibling of focus (bidirectional)
            else if hasRelationshipType(from: focus, to: member, type: .sibling) ||
                    hasRelationshipType(from: member, to: focus, type: .sibling) {
                siblings.append(member)
            }
            // Check if member is spouse of focus (bidirectional)
            else if hasRelationshipType(from: focus, to: member, type: .spouse) ||
                    hasRelationshipType(from: member, to: focus, type: .spouse) {
                spouse = member
            }
            // Check if member is a child of focus (forward: focus has member as child, reverse: member has focus as parent)
            else if hasRelationshipType(from: focus, to: member, type: .child) ||
                    hasRelationshipType(from: member, to: focus, type: .parent) {
                children.append(member)
            }
        }

        // Sort parents: by age (oldest first), or father before mother if no age
        let sortedParents = parents.sorted { parent1, parent2 in
            if let date1 = parent1.birthDate, let date2 = parent2.birthDate {
                return date1 < date2 // Older (earlier date) comes first
            }
            // If no birth dates, prefer father (male) before mother (female)
            if parent1.inferredGender == .male && parent2.inferredGender == .female {
                return true
            }
            if parent1.inferredGender == .female && parent2.inferredGender == .male {
                return false
            }
            // If same gender or both unknown, maintain stable order
            return parent1.id < parent2.id
        }

        // Sort siblings: by birth date (oldest first)
        let sortedSiblings = siblings.sorted { sibling1, sibling2 in
            if let date1 = sibling1.birthDate, let date2 = sibling2.birthDate {
                return date1 < date2 // Older comes first
            }
            // If no birth dates, maintain stable order
            return sibling1.id < sibling2.id
        }

        // Sort children: by age (oldest first)
        let sortedChildren = children.sorted { child1, child2 in
            if let date1 = child1.birthDate, let date2 = child2.birthDate {
                return date1 < date2 // Older comes first
            }
            // If no birth dates, maintain stable order
            return child1.id < child2.id
        }

        // Combine in order: Parents → Siblings → Spouse → Children
        var result: [FamilyMember] = []
        result.append(contentsOf: sortedParents)
        result.append(contentsOf: sortedSiblings)
        if let spouse = spouse {
            result.append(spouse)
        }
        result.append(contentsOf: sortedChildren)

        return result
    }

    /// Checks if there's a relationship from member1 to member2
    private func hasRelationship(from member1: FamilyMember, to member2: FamilyMember) -> Bool {
        return member1.relations.contains { $0.member.id == member2.id }
    }

    /// Checks if there's a specific relationship type from member1 to member2
    private func hasRelationshipType(
        from member1: FamilyMember,
        to member2: FamilyMember,
        type: FamilyMember.RelationType
    ) -> Bool {
        return member1.relations.contains { relation in
            relation.member.id == member2.id && relation.relationType == type
        }
    }

    /// Gets relationship info for a member, with fallback to default.
    func info(for memberId: String) -> RelationshipInfo {
        treeData.relationshipInfo(for: memberId)
            ?? RelationshipInfo(kind: .me, familySide: .unknown, path: [])
    }

    /// Localizes relationship info using language-specific localizer.
    func localizedRelationship(for info: RelationshipInfo, language: Language) -> String {
        RelationshipLocalizerFactory.localizer(for: language).localize(info: info)
    }

    // MARK: - Relationship Lookups

    /// Finds position of member's spouse if already placed.
    func findSpousePosition(for member: FamilyMember) -> NodePosition? {
        for relation in member.relations where relation.relationType == .spouse {
            if let spousePos = placedNodes[relation.member.id] {
                return spousePos
            }
        }
        return nil
    }

    /// Finds positions of member's parents if already placed.
    /// Includes parent's spouse if only one parent is direct relation.
    func findParentPositions(for member: FamilyMember) -> [NodePosition]? {
        var parents: [NodePosition] = []
        var parentIds = Set<String>()

        // Direct parent relations
        for relation in member.relations where relation.relationType == .parent {
            if let parentPos = placedNodes[relation.member.id],
               !parentIds.contains(relation.member.id) {
                parents.append(parentPos)
                parentIds.insert(relation.member.id)
            }
        }

        // Reverse lookup: find placed members who have this member as child
        for (placedId, placedPos) in placedNodes {
            if parentIds.contains(placedId) { continue }
            if let potentialParent = members.first(where: { $0.id == placedId }) {
                for relation in potentialParent.relations where relation.relationType == .child {
                    if relation.member.id == member.id && !parentIds.contains(placedId) {
                        parents.append(placedPos)
                        parentIds.insert(placedId)
                        break
                    }
                }
            }
        }

        // If only one parent found, try to add their spouse
        if parents.count == 1 {
            let singleParent = parents[0]
            for relation in singleParent.member.relations where relation.relationType == .spouse {
                if let spousePos = placedNodes[relation.member.id],
                   !parentIds.contains(relation.member.id) {
                    parents.append(spousePos)
                    parentIds.insert(relation.member.id)
                    break
                }
            }
        }

        return parents.isEmpty ? nil : parents
    }

    /// Finds positions of member's children if already placed.
    func findChildPositions(for member: FamilyMember) -> [NodePosition]? {
        var children: [NodePosition] = []
        var childIds = Set<String>()

        // Direct child relations
        for relation in member.relations where relation.relationType == .child {
            if let childPos = placedNodes[relation.member.id],
               !childIds.contains(relation.member.id) {
                children.append(childPos)
                childIds.insert(relation.member.id)
            }
        }

        // Reverse lookup: find placed members who have this member as parent
        for (placedId, placedPos) in placedNodes {
            if childIds.contains(placedId) { continue }
            if let child = members.first(where: { $0.id == placedId }) {
                for relation in child.relations where relation.relationType == .parent {
                    if relation.member.id == member.id {
                        children.append(placedPos)
                        childIds.insert(placedId)
                        break
                    }
                }
            }
        }

        return children.isEmpty ? nil : children
    }

    /// Finds positions of member's siblings if already placed.
    func findSiblingPositions(for member: FamilyMember) -> [NodePosition]? {
        var siblings: [NodePosition] = []

        // Direct sibling relations
        for relation in member.relations where relation.relationType == .sibling {
            if relation.member.id != member.id,
               let siblingPos = placedNodes[relation.member.id] {
                siblings.append(siblingPos)
            }
        }

        // Check if member is sibling of root
        if member.id != root.id {
            for relation in root.relations where relation.relationType == .sibling {
                if relation.member.id == member.id,
                   let rootPos = placedNodes[root.id] {
                    siblings.append(rootPos)
                }
            }
        }

        // Deduplicate siblings
        var uniqueSiblings: [NodePosition] = []
        var seenIds = Set<String>()
        for sibling in siblings where !seenIds.contains(sibling.member.id) {
            uniqueSiblings.append(sibling)
            seenIds.insert(sibling.member.id)
        }

        return uniqueSiblings.isEmpty ? nil : uniqueSiblings
    }

    /// Finds relationship from member to another member by ID.
    func findRelationship(from member: FamilyMember, to otherId: String) -> FamilyMember.Relation? {
        member.relations.first { $0.member.id == otherId }
    }
}
