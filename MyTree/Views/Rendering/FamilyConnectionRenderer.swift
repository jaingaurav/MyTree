//
//  FamilyConnectionRenderer.swift
//  MyTree
//
//  Renders parent-child connections in family tree.
//  Handles direct connections, filtered parent connections, and complex family structures.
//

import SwiftUI

/// Renders parent-child family connections.
enum FamilyConnectionRenderer {
    /// Callback to lookup parent positions for a child node.
    typealias ParentLookupFn = (NodePosition, [NodePosition]) -> ParentLookup

    /// Renders all parent-child connections for visible nodes.
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - geometry: Connection geometry configuration
    ///   - visiblePositions: All visible node positions
    ///   - highlightedPath: Set of highlighted member IDs
    ///   - parentPositions: Function to lookup parent positions
    static func drawParentChildConnections(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        visiblePositions: [NodePosition],
        highlightedPath: Set<String>,
        parentPositions: @escaping ParentLookupFn
    ) {
        for position in visiblePositions {
            let lookup = parentPositions(position, visiblePositions)

            // Try direct parent-child connection first
            if !lookup.parents.isEmpty {
                drawDirectConnection(
                    context: &context,
                    geometry: geometry,
                    child: position,
                    parents: lookup.parents,
                    highlightedPath: highlightedPath
                )
            } else if lookup.hasFilteredParents {
                // Draw connection to filtered (invisible) parents
                drawFilteredParentConnection(
                    context: &context,
                    geometry: geometry,
                    child: position
                )
            }
        }
    }

    /// Draws direct connection from child to visible parents.
    private static func drawDirectConnection(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        child: NodePosition,
        parents: [NodePosition],
        highlightedPath: Set<String>
    ) {
        let childCircle = geometry.circleCenter(for: child)

        // Calculate parent midpoint
        let parentPoints = parents.map { geometry.circleCenter(for: $0) }
        let parentMidX = parentPoints.map { $0.x }.reduce(0, +) / CGFloat(parentPoints.count)
        let parentMidY = parentPoints.map { $0.y }.reduce(0, +) / CGFloat(parentPoints.count)
        let parentMid = CGPoint(x: parentMidX, y: parentMidY)

        let isHighlighted = highlightedPath.contains(child.member.id) ||
                            parents.contains { highlightedPath.contains($0.member.id) }

        drawFamilyLine(
            context: &context,
            geometry: geometry,
            from: parentMid,
            to: childCircle,
            isHighlighted: isHighlighted
        )
    }

    /// Draws connection to filtered (not visible) parents.
    /// Shows dashed line upward to indicate hidden parents.
    private static func drawFilteredParentConnection(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        child: NodePosition
    ) {
        let childCircle = geometry.circleCenter(for: child)
        let upwardPoint = CGPoint(x: childCircle.x, y: childCircle.y - 50)

        let path = Path { pathBuilder in
            pathBuilder.move(to: CGPoint(x: childCircle.x, y: childCircle.y - geometry.radius))
            pathBuilder.addLine(to: upwardPoint)
        }

        context.stroke(
            path,
            with: .color(Color.gray.opacity(0.4)),
            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
        )
    }

    /// Draws family connection line (vertical then horizontal to avoid overlaps).
    ///
    /// Shape:
    /// ```
    ///     Parent(s)
    ///         |
    ///         +---- Child
    /// ```
    private static func drawFamilyLine(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        from parentPoint: CGPoint,
        to childCenter: CGPoint,
        isHighlighted: Bool
    ) {
        // Vertical segment from parent down
        let verticalEnd = CGPoint(
            x: parentPoint.x,
            y: parentPoint.y + 30  // Extend downward
        )

        // Horizontal segment to child
        let childTop = CGPoint(
            x: childCenter.x,
            y: childCenter.y - geometry.radius
        )

        let path = Path { pathBuilder in
            // Vertical from parent
            pathBuilder.move(to: CGPoint(x: parentPoint.x, y: parentPoint.y + geometry.radius))
            pathBuilder.addLine(to: verticalEnd)

            // Horizontal to child X
            pathBuilder.addLine(to: CGPoint(x: childTop.x, y: verticalEnd.y))

            // Vertical down to child circle
            pathBuilder.addLine(to: childTop)
        }

        if isHighlighted {
            context.stroke(path, with: .color(Color.blue), lineWidth: 3)
        } else {
            context.stroke(path, with: .color(Color.primary.opacity(0.6)), lineWidth: 2)
        }
    }
}
