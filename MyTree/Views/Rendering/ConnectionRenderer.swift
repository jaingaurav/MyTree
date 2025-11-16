//
//  ConnectionRenderer.swift
//  MyTree
//
//  Renders connection entities with animation support.
//  Uses Connection first-class entities for lifecycle and animation management.
//

import SwiftUI

/// Configuration for drawing animated lines
private struct AnimatedLineConfig {
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
    let progress: Double
    let opacity: Double
}

/// Renders connections between nodes with animation support
enum ConnectionRenderer {
    /// Draws all connections with animation states
    ///
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - geometry: Connection geometry configuration
    ///   - connections: List of connection entities to render
    ///   - nodePositions: Current node positions for coordinate lookup
    ///   - visibleNodeIds: Set of visible node IDs
    static func drawConnections(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        connections: [Connection],
        nodePositions: [NodePosition],
        visibleNodeIds: Set<String>
    ) {
        // Build position map for quick lookups
        let positionMap = Dictionary(uniqueKeysWithValues: nodePositions.map { ($0.member.id, $0) })

        // Render each connection
        for connection in connections {
            // Skip if nodes aren't visible
            guard visibleNodeIds.contains(connection.fromNodeId),
                  visibleNodeIds.contains(connection.toNodeId),
                  let fromNode = positionMap[connection.fromNodeId],
                  let toNode = positionMap[connection.toNodeId] else {
                continue
            }

            // Draw connection based on type
            switch connection.type {
            case .spouse:
                let spouseContext = SpouseConnectionContext(
                    fromNode: fromNode,
                    toNode: toNode,
                    allPositions: nodePositions
                )
                drawSpouseConnection(
                    context: &context,
                    geometry: geometry,
                    connection: connection,
                    spouseContext: spouseContext
                )

            case .parentChild:
                let parentChildContext = ParentChildConnectionContext(
                    fromNode: fromNode,
                    toNode: toNode,
                    allPositions: nodePositions
                )
                drawParentChildConnection(
                    context: &context,
                    geometry: geometry,
                    connection: connection,
                    parentChildContext: parentChildContext
                )
            }
        }
    }

    // MARK: - Spouse Connections

    /// Context for rendering spouse connections
    private struct SpouseConnectionContext {
        let fromNode: NodePosition
        let toNode: NodePosition
        let allPositions: [NodePosition]
    }

    /// Draws a horizontal line between spouses
    private static func drawSpouseConnection(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        connection: Connection,
        spouseContext: SpouseConnectionContext
    ) {
        let fromNode = spouseContext.fromNode
        let toNode = spouseContext.toNode
        let allPositions = spouseContext.allPositions
        let fromCenter = geometry.circleCenter(for: fromNode)
        let toCenter = geometry.circleCenter(for: toNode)

        // Determine if couple has children (draw T-shape or simple line)
        // Check both directions: children listing parents AND parents listing children
        let hasChildren = allPositions.contains { node in
            // Forward: child lists this couple as parents
            node.member.relations.contains { rel in
                rel.relationType == .parent && (rel.member.id == fromNode.member.id || rel.member.id == toNode.member.id)
            } ||
            // Reverse: either spouse lists this node as a child
            fromNode.member.relations.contains { rel in
                rel.relationType == .child && rel.member.id == node.member.id
            } ||
            toNode.member.relations.contains { rel in
                rel.relationType == .child && rel.member.id == node.member.id
            }
        }

        let color = connection.isHighlighted
            ? Color.blue
            : Color.primary.opacity(0.6)

        if !hasChildren {
            // Simple horizontal line
            let config = AnimatedLineConfig(
                start: fromCenter,
                end: toCenter,
                color: color,
                lineWidth: 2,
                progress: connection.drawProgress,
                opacity: connection.opacity
            )
            drawAnimatedLine(context: &context, config: config)
        } else {
            // T-shape with split line downward
            let midX = (fromCenter.x + toCenter.x) / 2
            let splitY = fromCenter.y + 30

            // Horizontal line between spouses
            let horizontalConfig = AnimatedLineConfig(
                start: fromCenter,
                end: toCenter,
                color: color,
                lineWidth: 2,
                progress: connection.drawProgress,
                opacity: connection.opacity
            )
            drawAnimatedLine(context: &context, config: horizontalConfig)

            // Vertical split line downward
            let splitStart = CGPoint(x: midX, y: fromCenter.y)
            let splitEnd = CGPoint(x: midX, y: splitY)
            let verticalConfig = AnimatedLineConfig(
                start: splitStart,
                end: splitEnd,
                color: color,
                lineWidth: 2,
                progress: connection.drawProgress,
                opacity: connection.opacity
            )
            drawAnimatedLine(context: &context, config: verticalConfig)
        }
    }

    // MARK: - Parent-Child Connections

    /// Context for rendering parent-child connections
    private struct ParentChildConnectionContext {
        let fromNode: NodePosition
        let toNode: NodePosition
        let allPositions: [NodePosition]
    }

    /// Draws connection from parent to child
    private static func drawParentChildConnection(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        connection: Connection,
        parentChildContext: ParentChildConnectionContext
    ) {
        let fromNode = parentChildContext.fromNode
        let toNode = parentChildContext.toNode
        let allPositions = parentChildContext.allPositions
        let parentCenter = geometry.circleCenter(for: fromNode)
        let childCenter = geometry.circleCenter(for: toNode)

        let color = connection.isHighlighted
            ? Color.blue
            : Color.primary.opacity(0.6)

        // Determine start point: parent center OR T-junction if parent is in spouse pair with children
        var startPoint = parentCenter

        // Find parent's spouse (if any)
        if let spouseId = fromNode.member.relations.first(where: { $0.relationType == .spouse })?.member.id,
           let spouseNode = allPositions.first(where: { $0.member.id == spouseId }) {
            let spouseCenter = geometry.circleCenter(for: spouseNode)

            // Check if this spouse pair has children (which means there's a T-junction)
            let hasChildren = allPositions.contains { node in
                // Forward: child lists this couple as parents
                node.member.relations.contains { rel in
                    rel.relationType == .parent && (rel.member.id == fromNode.member.id || rel.member.id == spouseId)
                } ||
                // Reverse: either spouse lists this node as a child
                fromNode.member.relations.contains { rel in
                    rel.relationType == .child && rel.member.id == node.member.id
                } ||
                spouseNode.member.relations.contains { rel in
                    rel.relationType == .child && rel.member.id == node.member.id
                }
            }

            if hasChildren {
                // Calculate T-junction point (bottom of the vertical stub at y + 30)
                let midX = (parentCenter.x + spouseCenter.x) / 2
                let splitY = parentCenter.y + 30
                startPoint = CGPoint(x: midX, y: splitY)
            }
        }

        // Draw L-shaped or vertical line from start point to child
        let verticalMidpoint = (startPoint.y + childCenter.y) / 2

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: CGPoint(x: startPoint.x, y: verticalMidpoint))
        path.addLine(to: CGPoint(x: childCenter.x, y: verticalMidpoint))
        path.addLine(to: childCenter)

        // Apply animation progress to path drawing
        let animatedPath = path.trimmedPath(from: 0, to: connection.drawProgress)

        context.stroke(
            animatedPath,
            with: .color(color.opacity(connection.opacity)),
            lineWidth: 2
        )
    }

    // MARK: - Drawing Helpers

    /// Draws an animated line with progress and opacity
    private static func drawAnimatedLine(
        context: inout GraphicsContext,
        config: AnimatedLineConfig
    ) {
        // Calculate animated endpoint based on progress
        let animatedEnd = CGPoint(
            x: config.start.x + (config.end.x - config.start.x) * config.progress,
            y: config.start.y + (config.end.y - config.start.y) * config.progress
        )

        var path = Path()
        path.move(to: config.start)
        path.addLine(to: animatedEnd)

        context.stroke(
            path,
            with: .color(config.color.opacity(config.opacity)),
            lineWidth: config.lineWidth
        )
    }
}
