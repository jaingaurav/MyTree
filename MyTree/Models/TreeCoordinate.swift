//
//  TreeCoordinate.swift
//  MyTree
//
//  Type-safe coordinate system for tree layout.
//  Prevents mixing tree space and screen space coordinates.
//

import CoreGraphics

/// Position in tree layout space (independent of viewport transform).
/// Tree space uses the layout algorithm's coordinate system where nodes are placed.
struct TreeCoordinate: Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat

    static let zero = TreeCoordinate(x: 0, y: 0)

    /// Transforms this tree coordinate to screen space using viewport parameters.
    /// - Parameters:
    ///   - scale: Zoom level
    ///   - offset: Pan offset
    ///   - viewportCenter: Center point of viewport
    /// - Returns: Screen coordinate
    func toScreen(scale: CGFloat, offset: CGSize, viewportCenter: CGPoint) -> ScreenCoordinate {
        let screenX = x * scale + offset.width + viewportCenter.x
        let screenY = y * scale + offset.height + viewportCenter.y
        return ScreenCoordinate(x: screenX, y: screenY)
    }
}

/// Position in screen/viewport space (after applying zoom/pan transforms).
/// Screen space is what the user sees on their display.
struct ScreenCoordinate: Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat

    static let zero = ScreenCoordinate(x: 0, y: 0)

    /// Converts to CGPoint for SwiftUI compatibility.
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}
