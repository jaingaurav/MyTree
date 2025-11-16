//
//  SpouseConnectionRenderer.swift
//  MyTree
//
//  Renders spouse connections (horizontal lines between married couples).
//

import SwiftUI

/// Renders connections between spouses in family tree.
enum SpouseConnectionRenderer {
    /// Renders all spouse connections for visible nodes.
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - geometry: Connection geometry configuration
    ///   - visiblePositions: All visible node positions
    ///   - highlightedPath: Set of highlighted member IDs (for path highlighting)
    ///   - processedFamilies: Set tracking already-processed spouse pairs (to avoid duplicates)
    static func drawSpouseConnections(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        visiblePositions: [NodePosition],
        highlightedPath: Set<String>,
        processedFamilies: inout Set<String>
    ) {
        for position in visiblePositions {
            let spouse = position.member.relations.first { $0.relationType == .spouse }?.member
            guard let spouseContact = spouse,
                  visiblePositions.contains(where: { $0.member.id == spouseContact.id })
            else { continue }

            // Use canonical family ID to avoid drawing connection twice
            let familyId = canonicalFamilyId(position.member.id, spouseContact.id)
            guard !processedFamilies.contains(familyId) else { continue }

            renderSpousePair(
                context: &context,
                geometry: geometry,
                position1: position,
                spouseId: spouseContact.id,
                visiblePositions: visiblePositions
            )

            processedFamilies.insert(familyId)
        }
    }

    /// Creates canonical family ID from two member IDs (order-independent).
    private static func canonicalFamilyId(_ id1: String, _ id2: String) -> String {
        id1 < id2 ? "\(id1)-\(id2)" : "\(id2)-\(id1)"
    }

    /// Renders connection between a spouse pair.
    private static func renderSpousePair(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        position1: NodePosition,
        spouseId: String,
        visiblePositions: [NodePosition]
    ) {
        guard let position2 = visiblePositions.first(where: { $0.member.id == spouseId }) else {
            return
        }

        let pair = orderSpousePair(position1: position1, position2: position2)

        // Check if couple has visible children (determines if split line needed)
        let hasVisibleChildren = hasVisibleChildren(
            for: pair.left.member,
            spouse: pair.right.member,
            in: visiblePositions
        )

        drawNormalSpouseLine(
            context: &context,
            geometry: geometry,
            leftPos: pair.left,
            rightPos: pair.right,
            hasChildren: hasVisibleChildren
        )
    }

    /// Orders spouse pair by X position (left to right).
    private static func orderSpousePair(
        position1: NodePosition,
        position2: NodePosition
    ) -> (left: NodePosition, right: NodePosition) {
        position1.x <= position2.x ? (position1, position2) : (position2, position1)
    }

    /// Checks if couple has any visible children.
    private static func hasVisibleChildren(
        for member: FamilyMember,
        spouse: FamilyMember,
        in visiblePositions: [NodePosition]
    ) -> Bool {
        // Check member's children
        for relation in member.relations where relation.relationType == .child {
            if visiblePositions.contains(where: { $0.member.id == relation.member.id }) {
                return true
            }
        }

        // Check spouse's children
        for relation in spouse.relations where relation.relationType == .child {
            if visiblePositions.contains(where: { $0.member.id == relation.member.id }) {
                return true
            }
        }

        return false
    }

    /// Draws normal spouse connection (gray, standard width).
    private static func drawNormalSpouseLine(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        leftPos: NodePosition,
        rightPos: NodePosition,
        hasChildren: Bool
    ) {
        let leftCircle = geometry.circleCenter(for: leftPos)
        let rightCircle = geometry.circleCenter(for: rightPos)

        if hasChildren {
            // Draw split line with vertical segment for children
            drawSpouseSplitLine(
                context: &context,
                leftCircle: leftCircle,
                rightCircle: rightCircle,
                radius: geometry.radius
            )
        } else {
            // Simple horizontal line
            let path = Path { pathBuilder in
                pathBuilder.move(to: CGPoint(x: leftCircle.x + geometry.radius, y: leftCircle.y))
                pathBuilder.addLine(to: CGPoint(x: rightCircle.x - geometry.radius, y: rightCircle.y))
            }
            context.stroke(path, with: .color(Color.primary.opacity(0.6)), lineWidth: 2)
        }

        // Draw marriage date annotation if available
        drawMarriageDateAnnotation(
            context: &context,
            leftPos: leftPos,
            rightPos: rightPos,
            leftCircle: leftCircle,
            rightCircle: rightCircle
        )
    }

    /// Draws marriage date annotation above the spouse connection line.
    private static func drawMarriageDateAnnotation(
        context: inout GraphicsContext,
        leftPos: NodePosition,
        rightPos: NodePosition,
        leftCircle: CGPoint,
        rightCircle: CGPoint
    ) {
        // Try to get marriage date from either spouse
        let marriageDate = leftPos.member.marriageDate ?? rightPos.member.marriageDate
        guard let date = marriageDate else { return }

        // Format the date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: date)

        // Calculate midpoint of the connection line
        let midX = (leftCircle.x + rightCircle.x) / 2
        let midY = leftCircle.y

        // Position text above the line
        let textPosition = CGPoint(x: midX, y: midY - 15)

        // Draw the text
        let text = Text(dateString)
            .font(.system(size: 10))
            .foregroundColor(Color.secondary)

        context.draw(text, at: textPosition)
    }

    /// Draws spouse line with vertical segment (T-shape for connecting children).
    ///
    /// Shape:
    /// ```
    /// O----------+----------O
    ///            |
    ///            (children below)
    /// ```
    private static func drawSpouseSplitLine(
        context: inout GraphicsContext,
        leftCircle: CGPoint,
        rightCircle: CGPoint,
        radius: CGFloat
    ) {
        let midX = (leftCircle.x + rightCircle.x) / 2
        let path = Path { pathBuilder in
            // Left horizontal segment
            pathBuilder.move(to: CGPoint(x: leftCircle.x + radius, y: leftCircle.y))
            pathBuilder.addLine(to: CGPoint(x: midX, y: leftCircle.y))

            // Vertical segment down
            pathBuilder.move(to: CGPoint(x: midX, y: leftCircle.y))
            pathBuilder.addLine(to: CGPoint(x: midX, y: leftCircle.y + 30))

            // Right horizontal segment
            pathBuilder.move(to: CGPoint(x: midX, y: rightCircle.y))
            pathBuilder.addLine(to: CGPoint(x: rightCircle.x - radius, y: rightCircle.y))
        }
        context.stroke(path, with: .color(Color.primary.opacity(0.6)), lineWidth: 2)
    }
}
