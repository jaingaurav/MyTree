//
//  LayoutUtility.swift
//  MyTree
//
//  Functional utility wrapper for layout computation in headless/testing scenarios.
//  Provides a stateless API that avoids Swift 6 runtime deallocation issues in tests.
//

import Foundation
import CoreGraphics

/// Functional utility for computing family tree layout.
///
/// This provides a stateless, function-based API suitable for testing and headless scenarios.
/// Unlike `ContactLayoutManager` (which is stateful), this utility computes layout in a single
/// function call without creating long-lived objects.
enum LayoutUtility {
    /// Computes layout for family tree members in a functional, stateless manner.
    ///
    /// - Parameters:
    ///   - members: Family members to layout
    ///   - root: Root member (typically "me")
    ///   - treeData: Precomputed relationship data
    ///   - config: Layout configuration
    ///   - language: Language for relationship labels
    /// - Returns: Array of positioned nodes
    static func computeLayout(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: LayoutConfiguration = .default,
        language: Language = .english
    ) -> [NodePosition] {
        // Convert LayoutConfiguration to ContactLayoutEngine.Config
        let engineConfig = ContactLayoutEngine.Config(
            baseSpacing: config.baseSpacing,
            spouseSpacing: config.spouseSpacing,
            verticalSpacing: config.verticalSpacing,
            minSpacing: config.minSpacing,
            expansionFactor: config.expansionFactor
        )

        // Use stateless layout engine
        return ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: root,
            treeData: treeData,
            config: engineConfig,
            language: language,
            siblingComparator: SiblingAgeComparator()
        )
    }
}
