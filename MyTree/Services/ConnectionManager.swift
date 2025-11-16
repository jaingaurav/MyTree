//
//  ConnectionManager.swift
//  MyTree
//
//  Manages the lifecycle of connection entities in the family tree graph.
//  Handles creation, updates, and removal with smooth animations.
//

import Foundation

/// Manages connection lifecycle: creation, animation, and removal
enum ConnectionManager {
    /// Calculates which connections should exist based on current node state
    ///
    /// This is the source of truth for what connections exist in the graph.
    /// Compares with existing connections to determine adds/removes/updates.
    ///
    /// - Parameters:
    ///   - nodes: All node positions in the tree
    ///   - visibleNodeIds: Set of currently visible node IDs
    /// - Returns: Set of connection IDs that should exist
    static func calculateDesiredConnections(
        from nodes: [NodePosition],
        visibleNodeIds: Set<String>
    ) -> [ConnectionDescriptor] {
        var descriptors: [ConnectionDescriptor] = []

        // Build position map for efficient lookups
        var positionMap: [String: NodePosition] = [:]
        for position in nodes where visibleNodeIds.contains(position.member.id) {
            positionMap[position.member.id] = position
        }

        let visiblePositions = Array(positionMap.values)

        // Extract spouse connections
        var processedSpousePairs = Set<String>()
        for position in visiblePositions {
            for relation in position.member.relations where relation.relationType == .spouse {
                guard let spouse = positionMap[relation.member.id] else { continue }

                // Create stable pair ID to avoid duplicates
                let pairId = [position.member.id, spouse.member.id].sorted().joined(separator: "-")
                guard processedSpousePairs.insert(pairId).inserted else { continue }

                descriptors.append(ConnectionDescriptor(
                    type: .spouse,
                    fromNodeId: position.member.id,
                    toNodeId: spouse.member.id,
                    fromNodeName: position.member.fullName,
                    toNodeName: spouse.member.fullName
                ))
            }
        }

        // Extract parent-child connections (from child's perspective)
        for position in visiblePositions {
            let visibleParents = findVisibleParents(
                for: position,
                positionMap: positionMap,
                visiblePositions: visiblePositions
            )

            // Create parent-child connections
            for parent in visibleParents {
                descriptors.append(ConnectionDescriptor(
                    type: .parentChild,
                    fromNodeId: parent.member.id,
                    toNodeId: position.member.id,
                    fromNodeName: parent.member.fullName,
                    toNodeName: position.member.fullName
                ))
            }
        }

        return descriptors
    }

    /// Updates connection list to match desired state with animations
    ///
    /// - Parameters:
    ///   - currentConnections: Existing connections
    ///   - desired: Desired connection descriptors
    ///   - highlightedPath: Set of node IDs in highlighted path
    /// - Returns: Updated connection list with animation states
    static func updateConnections(
        current currentConnections: [Connection],
        desired: [ConnectionDescriptor],
        highlightedPath: Set<String>
    ) -> ConnectionUpdateResult {
        let desiredIds = Set(desired.map { $0.id })
        let currentIds = Set(currentConnections.map { $0.id })

        var updatedConnections: [Connection] = []
        var newConnectionIds: Set<String> = []
        var removedConnectionIds: Set<String> = []

        // Process existing connections
        for connection in currentConnections {
            if desiredIds.contains(connection.id) {
                // Connection still exists - update highlighting
                let shouldHighlight = shouldBeHighlighted(
                    connection: connection,
                    highlightedPath: highlightedPath
                )
                updatedConnections.append(connection.withHighlight(shouldHighlight))
                continue
            }

            if !connection.isDisappearing {
                // Connection should be removed - mark for disappearance
                removedConnectionIds.insert(connection.id)
                updatedConnections.append(connection.markingForDisappearance())
            } else {
                // Already disappearing - keep it
                updatedConnections.append(connection)
            }
        }

        // Add new connections
        for descriptor in desired where !currentIds.contains(descriptor.id) {
            let shouldHighlight = shouldBeHighlighted(
                fromId: descriptor.fromNodeId,
                toId: descriptor.toNodeId,
                highlightedPath: highlightedPath
            )

            newConnectionIds.insert(descriptor.id)
            updatedConnections.append(Connection.appearing(
                type: descriptor.type,
                fromNodeId: descriptor.fromNodeId,
                toNodeId: descriptor.toNodeId,
                fromNodeName: descriptor.fromNodeName,
                toNodeName: descriptor.toNodeName,
                isHighlighted: shouldHighlight
            ))
        }

        return ConnectionUpdateResult(
            connections: updatedConnections,
            newConnectionIds: newConnectionIds,
            removedConnectionIds: removedConnectionIds
        )
    }

    /// Removes connections that have completed their disappearance animation
    ///
    /// - Parameter connections: Current connection list
    /// - Returns: Filtered connection list with fully disappeared connections removed
    static func pruneDisappearedConnections(_ connections: [Connection]) -> [Connection] {
        connections.filter { connection in
            !connection.isDisappearing || connection.opacity > 0.001
        }
    }

    /// Checks if a connection should be highlighted
    private static func shouldBeHighlighted(
        connection: Connection,
        highlightedPath: Set<String>
    ) -> Bool {
        shouldBeHighlighted(
            fromId: connection.fromNodeId,
            toId: connection.toNodeId,
            highlightedPath: highlightedPath
        )
    }

    /// Checks if a connection between two nodes should be highlighted
    private static func shouldBeHighlighted(
        fromId: String,
        toId: String,
        highlightedPath: Set<String>
    ) -> Bool {
        highlightedPath.contains(fromId) && highlightedPath.contains(toId)
    }

    /// Finds visible parents for a given position
    private static func findVisibleParents(
        for position: NodePosition,
        positionMap: [String: NodePosition],
        visiblePositions: [NodePosition]
    ) -> [NodePosition] {
        let parentRelations = position.member.relations.filter { $0.relationType == .parent }

        var visibleParents: [NodePosition] = []

        // Check direct parent relations
        for relation in parentRelations {
            if let parent = positionMap[relation.member.id] {
                visibleParents.append(parent)
            }
        }

        // Check reverse relationships (parents who list this member as child)
        for candidate in visiblePositions {
            let hasChildRelation = candidate.member.relations.contains { rel in
                rel.relationType == .child && rel.member.id == position.member.id
            }

            if hasChildRelation && !visibleParents.contains(where: { $0.member.id == candidate.member.id }) {
                visibleParents.append(candidate)
            }
        }

        return visibleParents
    }
}

// MARK: - Supporting Types

/// Describes a connection that should exist (without animation state)
struct ConnectionDescriptor {
    let type: Connection.ConnectionType
    let fromNodeId: String
    let toNodeId: String
    let fromNodeName: String
    let toNodeName: String

    /// Stable ID matching Connection.id generation
    var id: String {
        if type == .spouse {
            let sortedIds = [fromNodeId, toNodeId].sorted()
            return "\(type.rawValue)-\(sortedIds[0])-\(sortedIds[1])"
        } else {
            return "\(type.rawValue)-\(fromNodeId)-\(toNodeId)"
        }
    }
}

/// Result of updating connections
struct ConnectionUpdateResult {
    let connections: [Connection]
    let newConnectionIds: Set<String>
    let removedConnectionIds: Set<String>

    var hasChanges: Bool {
        !newConnectionIds.isEmpty || !removedConnectionIds.isEmpty
    }
}
