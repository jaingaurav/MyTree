//
//  FamilyTreeData.swift
//  MyTree
//
//  Precomputed family tree data for efficient UI interactions
//

import Foundation

/// Precomputed relationship data optimized for efficient UI operations.
///
/// This struct acts as a performance optimization layer, precomputing expensive calculations
/// once during initialization rather than repeatedly during UI interactions.
///
/// **What is Precomputed:**
/// - Degree of separation from root to each member (for filtering)
/// - Full relationship information for each member (for labels)
/// - Adjacency maps for fast neighbor lookups (for path highlighting)
///
/// **Performance Benefits:**
/// - O(1) degree lookups instead of O(n) BFS
/// - O(1) relationship lookups instead of O(n) path finding
/// - Efficient filtering by degree of separation
///
/// **Usage Example:**
/// ```swift
/// let treeData = FamilyTreeData(
///     members: allMembers,
///     root: meContact,
///     precomputedPaths: cachedPaths
/// )
///
/// // Fast lookups
/// let degree = treeData.degreeOfSeparation(for: memberID)
/// let closeFamily = treeData.members(withinDegree: 2)
/// let info = treeData.relationshipInfo(for: memberID)
/// ```
struct FamilyTreeData {
    /// All family members in the tree
    let members: [FamilyMember]

    /// The root member (typically "me")
    let root: FamilyMember

    /// Precomputed degree of separation from root to each member.
    /// Key: member ID, Value: degree (0 for root, 1 for immediate family, etc.)
    private let degreeMap: [String: Int]

    /// Precomputed relationship information from root to each member.
    /// Key: member ID, Value: relationship info (kind, side, path)
    private let relationshipMap: [String: RelationshipInfo]

    /// Forward adjacency: member ID → set of IDs they have relations to.
    private let adjacencyMap: [String: Set<String>]

    /// Reverse adjacency: member ID → set of IDs that have relations to them.
    private let reverseAdjacencyMap: [String: Set<String>]

    // MARK: - Initialization

    /// Creates precomputed family tree data from a list of members.
    ///
    /// This initialization performs three main computations:
    /// 1. Build adjacency maps for fast neighbor lookups
    /// 2. Calculate degrees of separation using BFS
    /// 3. Compute relationship information for all members
    ///
    /// - Parameters:
    ///   - members: All family members to include in the tree
    ///   - root: The root person (typically "me")
    ///   - precomputedPaths: Optional pre-calculated paths from tree traversal (performance optimization)
    ///   - precomputedFamilySides: Optional pre-calculated family sides from tree traversal (performance optimization)
    ///   - progressCallback: Optional callback for tracking initialization progress (0.0 to 1.0)
    init(
        members: [FamilyMember],
        root: FamilyMember,
        precomputedPaths: [String: [String]]? = nil,
        precomputedFamilySides: [String: FamilySide]? = nil,
        progressCallback: ((Double) -> Void)? = nil
    ) {
        let initStart = CFAbsoluteTimeGetCurrent()
        AppLog.tree.debug("FamilyTreeData.init start – members: \(members.count)")
        if precomputedPaths != nil {
            AppLog.tree.debug("Using precomputed relationship paths")
        }
        func ms(_ value: Double) -> String {
            String(format: "%.2f", value)
        }

        self.members = members
        self.root = root

        let adjacencyResult = Self.buildAdjacency(for: members)
        self.adjacencyMap = adjacencyResult.adjacency
        self.reverseAdjacencyMap = adjacencyResult.reverse
        AppLog.tree.debug("Adjacency build: \(ms(adjacencyResult.duration))ms")

        let degreeResult = Self.computeDegrees(
            from: root,
            members: members,
            adjacency: adjacencyResult.adjacency,
            reverseAdjacency: adjacencyResult.reverse
        )
        self.degreeMap = degreeResult.degrees
        AppLog.tree.debug("Degree BFS: \(ms(degreeResult.duration))ms")

        let relationshipResult = Self.computeRelationships(
            members: members,
            root: root,
            precomputedPaths: precomputedPaths,
            precomputedFamilySides: precomputedFamilySides,
            progressCallback: progressCallback
        )
        self.relationshipMap = relationshipResult.map
        AppLog.tree.debug("Relationship build: \(ms(relationshipResult.duration))ms")
        if !members.isEmpty {
            let perMember = ms(relationshipResult.duration / Double(members.count))
            AppLog.tree.debug("Average relationship cost: \(perMember)ms")
        }

        let totalTime = (CFAbsoluteTimeGetCurrent() - initStart) * 1000
        let summary = [
            "FamilyTreeData summary",
            "members: \(members.count)",
            "degrees: \(degreeResult.degrees.count)",
            "relationships: \(relationshipResult.map.count)",
            "total: \(ms(totalTime))ms"
        ].joined(separator: " | ")
        AppLog.tree.debug(summary)
    }

    // MARK: - Private Builders

    /// Builds forward and reverse adjacency maps from member relationships.
    ///
    /// - Parameter members: All family members
    /// - Returns: Tuple of (forward adjacency, reverse adjacency, duration in ms)
    private static func buildAdjacency(for members: [FamilyMember]) -> (
        adjacency: [String: Set<String>],
        reverse: [String: Set<String>],
        duration: Double
    ) {
        let start = CFAbsoluteTimeGetCurrent()
        var adjacency: [String: Set<String>] = [:]
        var reverse: [String: Set<String>] = [:]

        for member in members {
            var neighbors = Set<String>()

            for relation in member.relations {
                neighbors.insert(relation.member.id)
                reverse[relation.member.id, default: []].insert(member.id)
            }

            adjacency[member.id] = neighbors
        }

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (adjacency, reverse, duration)
    }

    /// Computes degree of separation from root to all reachable members using BFS.
    ///
    /// - Parameters:
    ///   - root: The root family member
    ///   - members: All family members
    ///   - adjacency: Forward adjacency map
    ///   - reverseAdjacency: Reverse adjacency map
    /// - Returns: Tuple of (degree map, duration in ms)
    private static func computeDegrees(
        from root: FamilyMember,
        members: [FamilyMember],
        adjacency: [String: Set<String>],
        reverseAdjacency: [String: Set<String>]
    ) -> (degrees: [String: Int], duration: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        var degrees: [String: Int] = [:]
        var queue: [(id: String, distance: Int)] = [(root.id, 0)]
        var visited = Set<String>()

        while !queue.isEmpty {
            let (currentId, distance) = queue.removeFirst()

            guard !visited.contains(currentId) else { continue }
            visited.insert(currentId)
            degrees[currentId] = distance

            if let neighbors = adjacency[currentId] {
                for neighbor in neighbors where !visited.contains(neighbor) {
                    queue.append((neighbor, distance + 1))
                }
            }

            if let reverseNeighbors = reverseAdjacency[currentId] {
                for neighbor in reverseNeighbors where !visited.contains(neighbor) {
                    queue.append((neighbor, distance + 1))
                }
            }
        }

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (degrees, duration)
    }

    /// Computes relationship information for all members relative to root.
    ///
    /// Uses precomputed paths if available for better performance, otherwise calculates paths.
    ///
    /// - Parameters:
    ///   - members: All family members
    ///   - root: The root person
    ///   - precomputedPaths: Optional cached paths from traversal
    ///   - precomputedFamilySides: Optional cached family sides from traversal
    ///   - progressCallback: Optional progress tracking callback
    /// - Returns: Tuple of (relationship map, duration in ms)
    private static func computeRelationships(
        members: [FamilyMember],
        root: FamilyMember,
        precomputedPaths: [String: [String]]?,
        precomputedFamilySides: [String: FamilySide]?,
        progressCallback: ((Double) -> Void)?
    ) -> (map: [String: RelationshipInfo], duration: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        var result: [String: RelationshipInfo] = [:]
        let memberById = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })

        for (index, member) in members.enumerated() {
            let info: RelationshipInfo

            if let precomputedPaths,
               let pathIds = precomputedPaths[member.id] {
                let path = pathIds.compactMap { memberById[$0] }
                if path.isEmpty || path.first?.id != root.id {
                    info = RelationshipCalculator.calculateRelationshipInfo(from: root, to: member, members: members)
                } else {
                    // Use precomputed family side (should always be available from BFS traversal)
                    let familySide = precomputedFamilySides?[member.id] ?? .unknown
                    let kind = RelationshipCalculator.describeRelationshipKind(path: path, familySide: familySide)
                    info = RelationshipInfo(kind: kind, familySide: familySide, path: path)
                }
            } else {
                info = RelationshipCalculator.calculateRelationshipInfo(from: root, to: member, members: members)
            }

            result[member.id] = info

            let progress = Double(index + 1) / Double(members.count)
            progressCallback?(progress)

            if members.count > 50 && (index + 1) % 25 == 0 {
                let percent = String(format: "%.1f", progress * 100)
                let message = "Relationship calc: \(percent)% (\(index + 1)/\(members.count))"
                AppLog.tree.debug(message)
            }
        }

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (result, duration)
    }

    // MARK: - Public Query API

    /// Returns the degree of separation from root to the specified member.
    ///
    /// - Parameter memberId: The member's unique identifier
    /// - Returns: Degree of separation (0 for root, 1 for immediate family, etc.), or Int.max if unreachable
    func degreeOfSeparation(for memberId: String) -> Int {
        return degreeMap[memberId] ?? Int.max
    }

    /// Returns precomputed relationship information for a member.
    ///
    /// - Parameter memberId: The member's unique identifier
    /// - Returns: Relationship info including kind, side, and path, or nil if not found
    func relationshipInfo(for memberId: String) -> RelationshipInfo? {
        return relationshipMap[memberId]
    }

    /// Filters members to only those within a maximum degree of separation from root.
    ///
    /// This is used for the degree-of-separation UI control to progressively reveal the tree.
    ///
    /// - Parameter maxDegree: Maximum degree (inclusive)
    /// - Returns: Array of members within the specified degree
    func members(withinDegree maxDegree: Int) -> [FamilyMember] {
        return members.filter { member in
            degreeOfSeparation(for: member.id) <= maxDegree
        }
    }

    /// Returns all neighbors of a member (both forward and reverse relationships).
    ///
    /// - Parameter memberId: The member's unique identifier
    /// - Returns: Set of member IDs that are connected to this member
    func neighbors(of memberId: String) -> Set<String> {
        var allNeighbors = Set<String>()

        if let forward = adjacencyMap[memberId] {
            allNeighbors.formUnion(forward)
        }

        if let reverse = reverseAdjacencyMap[memberId] {
            allNeighbors.formUnion(reverse)
        }

        return allNeighbors
    }
}
