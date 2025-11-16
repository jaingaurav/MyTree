//
//  ConnectionGeometry.swift
//  MyTree
//
//  Geometry calculations for family tree connection rendering.
//  Handles coordinate transformations between tree space and canvas space.
//

import SwiftUI

/// Geometry configuration for connection rendering in canvas space.
struct ConnectionGeometry {
    /// Canvas size (may be different from full window if sidebar visible).
    let size: CGSize

    /// Pan offset for viewport.
    let offset: CGSize

    /// Zoom scale for viewport.
    let scale: CGFloat

    /// Node circle radius (typically 40px for 80px diameter circles).
    let radius: CGFloat

    /// Horizontal offset to account for sidebar in canvas coordinate space.
    let sidebarOffset: CGFloat

    /// Vertical offset to account for toolbar in canvas coordinate space.
    let toolbarOffset: CGFloat

    /// Converts node position (tree space) to canvas point (screen space).
    /// - Parameter position: Node position in tree layout coordinates
    /// - Returns: Point in canvas coordinate space
    func point(for position: NodePosition) -> CGPoint {
        // Canvas coordinate space (ZStack size) for accurate positioning
        // Must match renderNode positioning: posX = nodePos.x * scale + offset.width + zStackWidth / 2
        // and posY = nodePos.y * scale + offset.height + zStackHeight / 2 + toolbarHeight
        // Both Canvas and nodes are inside the ZStack, so they share the same coordinate system
        // The sidebar offset is NOT needed because the ZStack is already positioned after the sidebar
        CGPoint(
            x: position.x * scale + offset.width + size.width / 2,
            y: position.y * scale + offset.height + size.height / 2 + toolbarOffset
        )
    }

    /// Returns circle center point accounting for VStack layout offset.
    ///
    /// ContactNodeView uses VStack with circle at top:
    /// - Circle: 80px diameter (radius 40px)
    /// - Spacing: 8px
    /// - Text VStack: ~45-50px (name + relationship label)
    /// - Total height: ~133-138px
    ///
    /// Circle center is offset upward from VStack center by ~26.5-29px.
    ///
    /// - Parameters:
    ///   - position: Node position in tree coordinates
    ///   - shouldLog: Whether to log detailed calculation (for debugging)
    /// - Returns: Circle center point in canvas coordinates
    func circleCenter(for position: NodePosition, shouldLog: Bool = false) -> CGPoint {
        let nodeCenter = point(for: position)

        // VStack layout calculations
        let spacing: CGFloat = 8
        let estimatedTextHeight: CGFloat = 48 // Name (2 lines) + label + spacing
        let circleOffsetY = (estimatedTextHeight + spacing) / 2
        let circleCenter = CGPoint(x: nodeCenter.x, y: nodeCenter.y - circleOffsetY)

        if shouldLog {
            AppLog.tree.debug("🔵 [CircleCenter] \(position.member.fullName):")
            AppLog.tree.debug("   NodePosition: x=\(position.x), y=\(position.y)")
            let vstackMsg = "VStack center: x=\(String(format: "%.2f", nodeCenter.x))"
            AppLog.tree.debug("   \(vstackMsg), y=\(String(format: "%.2f", nodeCenter.y))")
            AppLog.tree.debug("   Circle offset Y: \(String(format: "%.2f", circleOffsetY))")
            let circleCtrMsg = "Circle center: x=\(String(format: "%.2f", circleCenter.x))"
            AppLog.tree.debug("   \(circleCtrMsg), y=\(String(format: "%.2f", circleCenter.y))")
        }

        return circleCenter
    }
}

/// Parent lookup result with filtering information.
struct ParentLookup {
    /// Parent node positions (if placed and visible).
    let parents: [NodePosition]

    /// Whether some parents exist but are filtered out (not visible).
    let hasFilteredParents: Bool
}
