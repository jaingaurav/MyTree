import SwiftUI

/// Namespace for graph state and transition types
enum GraphStateTransition {}

/// Represents a connection (edge) between two nodes in the graph
struct GraphConnection: Hashable, Identifiable {
    enum ConnectionType: String {
        case spouse = "Spouse"
        case parentChild = "Parent-Child"
    }

    var id: String {
        "\(type.rawValue)-\(fromNodeId)-\(toNodeId)"
    }

    let type: ConnectionType
    let fromNodeId: String
    let toNodeId: String
    let fromNodeName: String
    let toNodeName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GraphConnection, rhs: GraphConnection) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the state of the family tree graph at a point in time
struct GraphState {
    let nodePositions: [NodePosition]
    let visibleNodeIds: Set<String>
    let connections: Set<GraphConnection>

    var positionMap: [String: NodePosition] {
        // Deduplicate by member ID, keeping the last occurrence
        var map: [String: NodePosition] = [:]
        for position in nodePositions {
            map[position.member.id] = position
        }
        return map
    }

    /// Extracts connections from the current node positions
    static func extractConnections(from positions: [NodePosition]) -> Set<GraphConnection> {
        var connections = Set<GraphConnection>()
        // Deduplicate by member ID, keeping the last occurrence
        var positionMap: [String: NodePosition] = [:]
        for position in positions {
            positionMap[position.member.id] = position
        }

        // Iterate over deduplicated positions to avoid processing duplicates
        let uniquePositions = Array(positionMap.values)
        for position in uniquePositions {
            // Extract spouse connections
            for relation in position.member.relations where relation.relationType == .spouse {
                // Check if the related member is in the visible positions
                if positionMap[relation.member.id] != nil {
                    // Only add if we haven't added the reverse direction
                    let sortedIds = [position.member.id, relation.member.id].sorted()
                    let connection = GraphConnection(
                        type: .spouse,
                        fromNodeId: sortedIds[0],
                        toNodeId: sortedIds[1],
                        fromNodeName: positionMap[sortedIds[0]]?.member.fullName ?? "",
                        toNodeName: positionMap[sortedIds[1]]?.member.fullName ?? ""
                    )
                    connections.insert(connection)
                }
            }

            // Extract parent-child connections (from child's perspective)
            for relation in position.member.relations where relation.relationType == .parent {
                // Check if the related member is in the visible positions
                if positionMap[relation.member.id] != nil {
                    let connection = GraphConnection(
                        type: .parentChild,
                        fromNodeId: relation.member.id,
                        toNodeId: position.member.id,
                        fromNodeName: relation.member.fullName,
                        toNodeName: position.member.fullName
                    )
                    connections.insert(connection)
                }
            }

            // Extract parent-child connections (from parent's perspective)
            for relation in position.member.relations where relation.relationType == .child {
                // Check if the related member is in the visible positions
                if positionMap[relation.member.id] != nil {
                    let connection = GraphConnection(
                        type: .parentChild,
                        fromNodeId: position.member.id,
                        toNodeId: relation.member.id,
                        fromNodeName: position.member.fullName,
                        toNodeName: relation.member.fullName
                    )
                    connections.insert(connection)
                }
            }
        }

        return connections
    }
}

/// Represents a transition between two graph states
struct GraphTransition {
    let nodesToAppear: [NodePosition]      // New nodes that should fade in
    let nodesToDisappear: [NodePosition]   // Existing nodes that should fade out
    let nodesToMove: [NodeMovement]        // Nodes that change position
    let connectionsToAppear: [GraphConnection]    // New connections to draw
    let connectionsToDisappear: [GraphConnection] // Connections to remove

    struct NodeMovement {
        let node: NodePosition
        let fromPosition: CGPoint
        let toPosition: CGPoint

        var delta: CGFloat {
            let dx = toPosition.x - fromPosition.x
            let dy = toPosition.y - fromPosition.y
            return sqrt(dx * dx + dy * dy)
        }
    }

    var hasChanges: Bool {
        !nodesToAppear.isEmpty || !nodesToDisappear.isEmpty || !nodesToMove.isEmpty ||
        !connectionsToAppear.isEmpty || !connectionsToDisappear.isEmpty
    }

    /// Logs all transition changes with animation types
    func logTransition() {
        AppLog.tree.debug("\n🎬 [Graph Transition] Computing state changes:")
        let nodeSummary = "\(nodesToAppear.count) nodes appear, "
            + "\(nodesToDisappear.count) disappear, \(nodesToMove.count) move"
        let connSummary = "\(connectionsToAppear.count) connections appear, "
            + "\(connectionsToDisappear.count) disappear"
        AppLog.tree.debug("   📊 Node Summary: \(nodeSummary)")
        AppLog.tree.debug("   📊 Connection Summary: \(connSummary)")

        if !nodesToAppear.isEmpty {
            AppLog.tree.debug("\n   ✨ NODES APPEAR (\(nodesToAppear.count)):")
            for node in nodesToAppear {
                let pos = formatPosition(node)
                AppLog.tree.debug("      ➕ \(node.member.fullName) at \(pos)")
            }
        }

        if !nodesToDisappear.isEmpty {
            AppLog.tree.debug("\n   💨 NODES DISAPPEAR (\(nodesToDisappear.count)):")
            for node in nodesToDisappear {
                let pos = formatPosition(node)
                AppLog.tree.debug("      ➖ \(node.member.fullName) from \(pos)")
            }
        }

        if !nodesToMove.isEmpty {
            AppLog.tree.debug("\n   🔄 NODES MOVE (\(nodesToMove.count)):")
            for movement in nodesToMove {
                let fromPos = "(\(Int(movement.fromPosition.x)), \(Int(movement.fromPosition.y)))"
                let toPos = "(\(Int(movement.toPosition.x)), \(Int(movement.toPosition.y)))"
                let delta = Int(movement.delta)
                let msg = "      🔄 \(movement.node.member.fullName): \(fromPos) → \(toPos) [Δ\(delta)]"
                AppLog.tree.debug(msg)
            }
        }

        if !connectionsToAppear.isEmpty {
            AppLog.tree.debug("\n   ✨ CONNECTIONS APPEAR (\(connectionsToAppear.count)):")
            for connection in connectionsToAppear.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIcon(for: connection.type)
                let msg = "      \(icon) [\(connection.type.rawValue)] "
                    + "\(connection.fromNodeName) ↔ \(connection.toNodeName)"
                AppLog.tree.debug(msg)
            }
        }

        if !connectionsToDisappear.isEmpty {
            AppLog.tree.debug("\n   💨 CONNECTIONS DISAPPEAR (\(connectionsToDisappear.count)):")
            for connection in connectionsToDisappear.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIcon(for: connection.type)
                let msg = "      \(icon) [\(connection.type.rawValue)] "
                    + "\(connection.fromNodeName) ↔ \(connection.toNodeName)"
                AppLog.tree.debug(msg)
            }
        }

        if !hasChanges {
            AppLog.tree.debug("   ℹ️  No changes detected")
        }
    }

    private func connectionIcon(for type: GraphConnection.ConnectionType) -> String {
        switch type {
        case .spouse: return "💑"
        case .parentChild: return "👨‍👧"
        }
    }

    private func formatPosition(_ node: NodePosition) -> String {
        "(\(Int(node.x)), \(Int(node.y)))"
    }
}

/// Computes the transition between two graph states
enum GraphTransitionCalculator {
    /// Computes the transition from current state to destination state
    /// - Parameters:
    ///   - current: The current graph state
    ///   - destination: The desired destination graph state
    ///   - movementThreshold: Minimum distance to consider a node as "moved" (default: 5.0)
    /// - Returns: A GraphTransition describing all changes
    static func computeTransition(
        from current: GraphState,
        to destination: GraphState,
        movementThreshold: CGFloat = 5.0
    ) -> GraphTransition {
        let currentMap = current.positionMap
        let destMap = destination.positionMap

        let currentIds = Set(currentMap.keys)
        let destIds = Set(destMap.keys)

        // Nodes that appear (in destination but not in current)
        let appearingIds = destIds.subtracting(currentIds)
        let nodesToAppear = appearingIds.compactMap { destMap[$0] }

        // Nodes that disappear (in current but not in destination)
        let disappearingIds = currentIds.subtracting(destIds)
        let nodesToDisappear = disappearingIds.compactMap { currentMap[$0] }

        // Nodes that exist in both - check if they moved
        let persistingIds = currentIds.intersection(destIds)
        var nodesToMove: [GraphTransition.NodeMovement] = []

        for id in persistingIds {
            guard let currentNode = currentMap[id],
                  let destNode = destMap[id] else { continue }

            let dx = abs(destNode.x - currentNode.x)
            let dy = abs(destNode.y - currentNode.y)

            // Only consider it a move if the distance exceeds threshold
            if dx > movementThreshold || dy > movementThreshold {
                let movement = GraphTransition.NodeMovement(
                    node: destNode,
                    fromPosition: CGPoint(x: currentNode.x, y: currentNode.y),
                    toPosition: CGPoint(x: destNode.x, y: destNode.y)
                )
                nodesToMove.append(movement)
            }
        }

        // Connections that appear (in destination but not in current)
        let connectionsToAppear = Array(destination.connections.subtracting(current.connections))

        // Connections that disappear (in current but not in destination)
        let connectionsToDisappear = Array(current.connections.subtracting(destination.connections))

        return GraphTransition(
            nodesToAppear: nodesToAppear,
            nodesToDisappear: nodesToDisappear,
            nodesToMove: nodesToMove,
            connectionsToAppear: connectionsToAppear,
            connectionsToDisappear: connectionsToDisappear
        )
    }
}
