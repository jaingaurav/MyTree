//
//  LayoutConfiguration.swift
//  MyTree
//
//  Configuration parameters for tree layout algorithm.
//  Consolidates spacing and layout parameters into a single, testable struct.
//

import CoreGraphics

/// Configuration for tree layout spacing and positioning.
struct LayoutConfiguration: Equatable, Sendable {
    /// Horizontal distance between unrelated contacts (general spacing).
    var baseSpacing: CGFloat

    /// Horizontal distance between married couples (should be less than baseSpacing).
    var spouseSpacing: CGFloat

    /// Vertical distance between generations (parent-child spacing).
    var verticalSpacing: CGFloat

    /// Minimum allowed spacing between any two nodes to prevent overlap.
    var minSpacing: CGFloat

    /// Factor for dynamic spacing expansion when detecting overlaps (>1.0).
    var expansionFactor: CGFloat

    /// Default layout configuration with recommended values.
    static let `default` = LayoutConfiguration(
        baseSpacing: 180,
        spouseSpacing: 180,
        verticalSpacing: 200,
        minSpacing: 80,
        expansionFactor: 1.15
    )

    /// Compact layout with reduced spacing.
    static let compact = LayoutConfiguration(
        baseSpacing: 120,
        spouseSpacing: 100,
        verticalSpacing: 150,
        minSpacing: 60,
        expansionFactor: 1.1
    )

    /// Spacious layout with increased spacing for large displays.
    static let spacious = LayoutConfiguration(
        baseSpacing: 240,
        spouseSpacing: 200,
        verticalSpacing: 250,
        minSpacing: 100,
        expansionFactor: 1.2
    )
}
