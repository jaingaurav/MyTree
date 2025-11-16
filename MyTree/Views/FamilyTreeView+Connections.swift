//
//  FamilyTreeView+Connections.swift
//  MyTree
//
//  Main coordinator for rendering family tree connections.
//  Delegates to focused renderers for spouse and family connections.
//

import SwiftUI

extension FamilyTreeView {
    /// Main entry point for drawing all family tree connections.
    ///
    /// Renders all connections using first-class Connection entities:
    /// - Spouse connections (horizontal lines between couples)
    /// - Parent-child connections (vertical/angled lines between generations)
    /// - Filtered parent indicators (dashed lines for hidden parents)
    ///
    /// Connections are managed by ConnectionManager and have persistent identity,
    /// enabling smooth animations for appearance, disappearance, and state changes.
    ///
    /// - Parameters:
    ///   - context: Graphics context for Canvas drawing
    ///   - size: Canvas size (may differ from window size if sidebar visible)
    func drawConnections(context: GraphicsContext, size: CGSize) {
        guard !viewModel.nodePositions.isEmpty else { return }

        var ctx = context

        // Create geometry configuration
        // size parameter is the Canvas view size, which is the ZStack size
        // The ZStack is already positioned after the sidebar in the HStack,
        // so its width is already (fullWidth - sidebarWidth - settingsWidth)
        // The ZStack height is (fullHeight - toolbarHeight)
        // We need to account for sidebar and toolbar offsets to match node positioning
        let sidebarWidth: CGFloat = viewModel.showSidebar ? 480 : 0
        let toolbarHeight: CGFloat = 44
        // Canvas size is already the ZStack size (reduced by sidebar/settings)
        // But nodes are positioned with offsets, so we need to match that
        let geometry = ConnectionGeometry(
            size: size, // Canvas size is already the ZStack size
            offset: viewModel.offset,
            scale: viewModel.scale,
            radius: circleRadius,
            sidebarOffset: sidebarWidth,
            toolbarOffset: toolbarHeight
        )

        // Draw all connections using unified renderer
        ConnectionRenderer.drawConnections(
            context: &ctx,
            geometry: geometry,
            connections: viewModel.connections,
            nodePositions: viewModel.nodePositions,
            visibleNodeIds: viewModel.visibleNodeIds
        )
    }

    // MARK: - Lookup Helpers

    /// Looks up parent positions for a child node.
    ///
    /// Returns both visible parents and flag indicating if some parents are filtered out.
    ///
    /// - Parameters:
    ///   - childNode: Child node to find parents for
    ///   - visiblePositions: All currently visible node positions
    /// - Returns: Parent lookup result
    func parentPositions(
        for childNode: NodePosition,
        visiblePositions: [NodePosition]
    ) -> ParentLookup {
        var parents: [NodePosition] = []
        var hasFilteredParents = false

        // Find all parent relationships
        let parentRelations = childNode.member.relations.filter { $0.relationType == .parent }

        for relation in parentRelations {
            if let parentPos = visiblePositions.first(where: { $0.member.id == relation.member.id }) {
                parents.append(parentPos)
            } else {
                hasFilteredParents = true
            }
        }

        // Check reverse relationships (parents who list this member as child)
        for position in visiblePositions {
            let hasChildRelation = position.member.relations.contains { rel in
                rel.relationType == .child && rel.member.id == childNode.member.id
            }

            if hasChildRelation && !parents.contains(where: { $0.member.id == position.member.id }) {
                parents.append(position)
            }
        }

        return ParentLookup(parents: parents, hasFilteredParents: hasFilteredParents)
    }

    /// Draws other relationship connections (siblings, extended family).
    ///
    /// Currently placeholder for future expansion.
    ///
    /// - Parameters:
    ///   - context: Graphics context
    ///   - geometry: Connection geometry
    ///   - visiblePositions: Visible node positions
    private func drawOtherConnections(
        context: inout GraphicsContext,
        geometry: ConnectionGeometry,
        visiblePositions: [NodePosition]
    ) {
        // Future: Add sibling connections, cousin connections, etc.
        // For now, spouse and parent-child connections cover primary relationships
    }

    // MARK: - Additional Helpers

    /// Finds visible children for a member.
    private func visibleChildren(
        for member: FamilyMember,
        in visiblePositions: [NodePosition]
    ) -> [NodePosition] {
        member.relations
            .filter { $0.relationType == .child }
            .compactMap { relation in
                visiblePositions.first { $0.member.id == relation.member.id }
            }
    }

    /// Finds spouse position if spouse is visible.
    private func spousePosition(
        for member: FamilyMember,
        in visiblePositions: [NodePosition]
    ) -> NodePosition? {
        guard let spouseRelation = member.relations.first(where: { $0.relationType == .spouse }) else {
            return nil
        }
        return visiblePositions.first { $0.member.id == spouseRelation.member.id }
    }

    /// Finds visible siblings for a member.
    private func visibleSiblings(
        for member: FamilyMember,
        in visiblePositions: [NodePosition]
    ) -> [NodePosition] {
        member.relations
            .filter { $0.relationType == .sibling }
            .compactMap { relation in
                visiblePositions.first { $0.member.id == relation.member.id }
            }
    }
}
