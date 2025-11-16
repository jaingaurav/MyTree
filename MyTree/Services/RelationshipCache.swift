import Foundation

/// Thread-safe caches for relationship degrees and info.
actor RelationshipCache {
    private var degreeCache: [CacheKey: Int] = [:]
    private var relationshipInfoCache: [CacheKey: RelationshipInfo] = [:]
    private var allDegreesCache: [String: [String: Int]] = [:] // rootId -> [memberId: degree]
    private let log = AppLog.cache

    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    struct CacheKey: Hashable {
        let fromId: String
        let toId: String

        init(_ fromId: String, _ toId: String) {
            self.fromId = fromId
            self.toId = toId
        }
    }

    // MARK: - Degree of Separation Cache

    /// Get cached degree of separation between two members.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    /// - Returns: The cached degree if available, otherwise nil.
    func getDegree(from fromId: String, to toId: String) -> Int? {
        let key = CacheKey(fromId, toId)
        if let degree = degreeCache[key] {
            cacheHits += 1
            return degree
        }
        cacheMisses += 1
        return nil
    }

    /// Cache a degree of separation between two members.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    ///   - degree: The degree of separation to cache.
    func cacheDegree(from fromId: String, to toId: String, degree: Int) {
        let key = CacheKey(fromId, toId)
        degreeCache[key] = degree

        // Also cache in reverse (degree is symmetric)
        let reverseKey = CacheKey(toId, fromId)
        degreeCache[reverseKey] = degree
    }

    /// Get all cached degrees of separation from a specific root.
    /// - Parameter rootId: The ID of the root member.
    /// - Returns: A dictionary mapping member IDs to degrees from the root if cached.
    func getAllDegrees(from rootId: String) -> [String: Int]? {
        return allDegreesCache[rootId]
    }

    /// Cache all degrees of separation from a root at once.
    /// - Parameters:
    ///   - rootId: The ID of the root member.
    ///   - degrees: A dictionary mapping member IDs to degrees from the root.
    func cacheAllDegrees(from rootId: String, degrees: [String: Int]) {
        allDegreesCache[rootId] = degrees

        // Also populate individual cache
        for (memberId, degree) in degrees {
            cacheDegree(from: rootId, to: memberId, degree: degree)
        }
    }

    // MARK: - Relationship Info Cache

    /// Get cached relationship info between two members.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    /// - Returns: The cached relationship info if available, otherwise nil.
    func getRelationshipInfo(from fromId: String, to toId: String) -> RelationshipInfo? {
        let key = CacheKey(fromId, toId)
        if let info = relationshipInfoCache[key] {
            cacheHits += 1
            return info
        }
        cacheMisses += 1
        return nil
    }

    /// Cache relationship info between two members.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    ///   - info: The relationship info to cache.
    func cacheRelationshipInfo(from fromId: String, to toId: String, info: RelationshipInfo) {
        let key = CacheKey(fromId, toId)
        relationshipInfoCache[key] = info
    }

    // MARK: - Cache Management

    /// Clear all caches and reset cache statistics.
    func clear() {
        degreeCache.removeAll()
        relationshipInfoCache.removeAll()
        allDegreesCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }

    /// Clear caches related to a specific root member.
    /// - Parameter rootId: The ID of the root member to clear caches for.
    func clearForRoot(_ rootId: String) {
        allDegreesCache.removeValue(forKey: rootId)

        // Remove individual entries for this root
        let keysToRemove = degreeCache.keys.filter { $0.fromId == rootId || $0.toId == rootId }
        for key in keysToRemove {
            degreeCache.removeValue(forKey: key)
        }

        let infoKeysToRemove = relationshipInfoCache.keys.filter { $0.fromId == rootId || $0.toId == rootId }
        for key in infoKeysToRemove {
            relationshipInfoCache.removeValue(forKey: key)
        }
    }

    /// Get current cache statistics snapshot.
    /// - Returns: A `CacheStats` instance representing current cache metrics.
    func getStats() -> CacheStats {
        let totalLookups = cacheHits + cacheMisses
        let hitRate = totalLookups > 0
            ? Double(cacheHits) / Double(totalLookups)
            : 1.0

        return CacheStats(
            degreesCached: degreeCache.count,
            relationshipsCached: relationshipInfoCache.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate
        )
    }

    /// Log cache statistics.
    func logStats() {
        let stats = getStats()
        let summary = """
        Relationship cache stats:
          Degrees Cached: \(stats.degreesCached)
          Relationships Cached: \(stats.relationshipsCached)
          Cache Hits: \(stats.cacheHits)
          Cache Misses: \(stats.cacheMisses)
          Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%
        """
        log.info(summary)
    }
}

/// Snapshot of cache statistics.
struct CacheStats {
    let degreesCached: Int
    let relationshipsCached: Int
    let cacheHits: Int
    let cacheMisses: Int
    let hitRate: Double
}

/// Manages the relationship cache with synchronous APIs suitable for main thread use.
@MainActor
class RelationshipCacheManager {
    static let shared = RelationshipCacheManager()

    private let cache = RelationshipCache()
    private let log = AppLog.cache

    private init() {}

    /// Calculate and cache all degrees of separation from a root member.
    /// This is a one-time expensive operation that traverses relationships bidirectionally.
    /// - Parameters:
    ///   - root: The root FamilyMember to start from.
    ///   - members: All family members to consider.
    func precomputeAllDegrees(from root: FamilyMember, members: [FamilyMember]) {
        var degrees: [String: Int] = [:]

        // BFS from root to all members (bidirectional)
        var queue: [(member: FamilyMember, distance: Int)] = [(root, 0)]
        var visited = Set<String>()

        while !queue.isEmpty {
            let (current, distance) = queue.removeFirst()

            if visited.contains(current.id) { continue }
            visited.insert(current.id)

            degrees[current.id] = distance

            // Forward: Find members that current has relations to
            for relation in current.relations {
                let related = relation.member
                if !visited.contains(related.id) {
                    queue.append((related, distance + 1))
                }
            }

            // Reverse: Find members that have relations pointing to current
            for otherMember in members {
                if visited.contains(otherMember.id) { continue }
                for relation in otherMember.relations where relation.member.id == current.id {
                    queue.append((otherMember, distance + 1))
                    break // Found a reverse relation, move to next member
                }
            }
        }

        // Cache all at once
        Task {
            await cache.cacheAllDegrees(from: root.id, degrees: degrees)
        }

        log.debug("Precomputed degrees for \(degrees.count) members from root \(root.fullName)")
    }

    /// Get cached degree of separation between two members asynchronously.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    /// - Returns: The cached degree if available, otherwise nil.
    func getDegree(from fromId: String, to toId: String) async -> Int? {
        return await cache.getDegree(from: fromId, to: toId)
    }

    /// Cache a degree of separation asynchronously.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    ///   - degree: The degree of separation to cache.
    func cacheDegree(from fromId: String, to toId: String, degree: Int) {
        Task {
            await cache.cacheDegree(from: fromId, to: toId, degree: degree)
        }
    }

    /// Get all cached degrees from a root asynchronously.
    /// - Parameter rootId: The ID of the root member.
    /// - Returns: A dictionary mapping member IDs to degrees if cached, otherwise nil.
    func getAllDegrees(from rootId: String) async -> [String: Int]? {
        return await cache.getAllDegrees(from: rootId)
    }

    /// Get cached relationship info between two members asynchronously.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    /// - Returns: The cached relationship info if available, otherwise nil.
    func getRelationshipInfo(from fromId: String, to toId: String) async -> RelationshipInfo? {
        return await cache.getRelationshipInfo(from: fromId, to: toId)
    }

    /// Cache relationship info asynchronously.
    /// - Parameters:
    ///   - fromId: The ID of the starting member.
    ///   - toId: The ID of the target member.
    ///   - info: The relationship info to cache.
    func cacheRelationshipInfo(from fromId: String, to toId: String, info: RelationshipInfo) {
        Task {
            await cache.cacheRelationshipInfo(from: fromId, to: toId, info: info)
        }
    }

    /// Clear all caches asynchronously.
    func clear() {
        Task {
            await cache.clear()
        }
    }

    /// Log cache statistics asynchronously.
    func logStats() {
        Task {
            await cache.logStats()
        }
    }
}
