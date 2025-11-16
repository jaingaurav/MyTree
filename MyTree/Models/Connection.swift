//
//  Connection.swift
//  MyTree
//
//  First-class connection entity with persistent identity and animation state.
//  Represents edges between nodes in the family tree graph.
//

import Foundation

/// Represents a connection (edge) between two nodes in the family tree.
/// Connections have persistent identity and manage their own animation state.
struct Connection: Identifiable, Hashable {
    /// Connection type determines rendering style and behavior
    enum ConnectionType: String, Hashable {
        case spouse = "Spouse"
        case parentChild = "Parent-Child"

        /// Visual line style for this connection type
        var lineStyle: LineStyle {
            switch self {
            case .spouse: return .solid
            case .parentChild: return .solid
            }
        }

        enum LineStyle {
            case solid
            case dashed
        }
    }

    // MARK: - Identity

    /// Unique identifier for this connection
    /// Format: "{type}-{fromId}-{toId}"
    let id: String

    /// Connection type (spouse, parent-child, etc.)
    let type: ConnectionType

    /// Source node ID
    let fromNodeId: String

    /// Destination node ID
    let toNodeId: String

    /// Source node name (for debugging/logging)
    let fromNodeName: String

    /// Destination node name (for debugging/logging)
    let toNodeName: String

    // MARK: - Animation State

    /// Animation progress: 0.0 (invisible) → 1.0 (fully visible)
    /// Used for draw-in animations when connection appears
    var drawProgress: Double

    /// Opacity: 0.0 (transparent) → 1.0 (opaque)
    /// Used for fade-in/fade-out animations
    var opacity: Double

    /// Whether this connection is being removed (fade-out in progress)
    var isDisappearing: Bool

    // MARK: - Visual State

    /// Whether this connection is part of highlighted path to root
    var isHighlighted: Bool

    // MARK: - Initialization

    /// Creates a new connection with default animation state
    init(
        type: ConnectionType,
        fromNodeId: String,
        toNodeId: String,
        fromNodeName: String,
        toNodeName: String,
        drawProgress: Double = 0.0,
        opacity: Double = 0.0,
        isDisappearing: Bool = false,
        isHighlighted: Bool = false
    ) {
        // Generate stable ID based on type and node IDs
        // For spouse connections, sort IDs to ensure bidirectional consistency
        if type == .spouse {
            let sortedIds = [fromNodeId, toNodeId].sorted()
            self.id = "\(type.rawValue)-\(sortedIds[0])-\(sortedIds[1])"
        } else {
            self.id = "\(type.rawValue)-\(fromNodeId)-\(toNodeId)"
        }

        self.type = type
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.fromNodeName = fromNodeName
        self.toNodeName = toNodeName
        self.drawProgress = drawProgress
        self.opacity = opacity
        self.isDisappearing = isDisappearing
        self.isHighlighted = isHighlighted
    }

    // MARK: - State Queries

    /// Whether this connection is fully visible (completed draw-in animation)
    var isFullyVisible: Bool {
        drawProgress >= 0.999 && opacity >= 0.999 && !isDisappearing
    }

    /// Whether this connection needs animation (still animating in or out)
    var needsAnimation: Bool {
        drawProgress < 0.999 || opacity < 0.999 || isDisappearing
    }

    /// Whether this connection involves a specific node
    func involves(nodeId: String) -> Bool {
        fromNodeId == nodeId || toNodeId == nodeId
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Connection, rhs: Connection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Animation Helpers

extension Connection {
    /// Creates a new connection ready to animate in
    static func appearing(
        type: ConnectionType,
        fromNodeId: String,
        toNodeId: String,
        fromNodeName: String,
        toNodeName: String,
        isHighlighted: Bool = false
    ) -> Connection {
        Connection(
            type: type,
            fromNodeId: fromNodeId,
            toNodeId: toNodeId,
            fromNodeName: fromNodeName,
            toNodeName: toNodeName,
            drawProgress: 0.0,
            opacity: 0.0,
            isDisappearing: false,
            isHighlighted: isHighlighted
        )
    }

    /// Creates a copy marked for disappearing
    func markingForDisappearance() -> Connection {
        var copy = self
        copy.isDisappearing = true
        return copy
    }

    /// Updates highlighting state
    func withHighlight(_ highlighted: Bool) -> Connection {
        var copy = self
        copy.isHighlighted = highlighted
        return copy
    }
}

// MARK: - Debugging

extension Connection: CustomStringConvertible {
    var description: String {
        let state = isDisappearing ? "disappearing" : "visible"
        let animation = needsAnimation ? "animating" : "static"
        return "Connection(\(type.rawValue): \(fromNodeName) → \(toNodeName), \(state), \(animation))"
    }
}
