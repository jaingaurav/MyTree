//
//  LayoutOrchestrator.swift
//  MyTree
//
//  Orchestrates tree layout operations, coordinating between layout manager,
//  tree data, and caching. Moves business logic out of view layer.
//

import Foundation
import CoreGraphics

/// Orchestrates family tree layout operations.
/// Coordinates layout manager, caching, and incremental placement logic.
final class LayoutOrchestrator {
    // MARK: - Dependencies

    private let siblingComparator: SiblingAgeComparator

    // MARK: - Initialization

    init(siblingComparator: SiblingAgeComparator = SiblingAgeComparator()) {
        self.siblingComparator = siblingComparator
    }

    // MARK: - Layout Operations

    /// Performs complete layout of visible tree members.
    /// - Parameters:
    ///   - members: Members to layout
    ///   - root: Root contact (typically "me")
    ///   - treeData: Precomputed tree relationships
    ///   - config: Layout spacing configuration
    ///   - language: Language for relationship labels
    /// - Returns: Result containing array of positioned nodes or error
    func layoutTree(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: LayoutConfiguration,
        language: Language
    ) -> Result<[NodePosition], LayoutError> {
        // Validation
        guard !members.isEmpty else {
            return .failure(.emptyMemberList)
        }

        guard members.contains(where: { $0.id == root.id }) else {
            return .failure(.rootNotFound(root.id))
        }

        // Convert LayoutConfiguration to ContactLayoutEngine.Config
        let engineConfig = ContactLayoutEngine.Config(
            baseSpacing: config.baseSpacing,
            spouseSpacing: config.spouseSpacing,
            verticalSpacing: config.verticalSpacing,
            minSpacing: config.minSpacing,
            expansionFactor: config.expansionFactor
        )

        // Use stateless layout engine with relationship-based placement
        let positions = ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: root,
            treeData: treeData,
            config: engineConfig,
            language: language,
            siblingComparator: siblingComparator
        )

        return .success(positions)
    }

    /// Performs incremental layout for animation.
    /// - Parameters:
    ///   - members: Members to layout
    ///   - root: Root contact
    ///   - treeData: Precomputed tree relationships
    ///   - config: Layout spacing configuration
    ///   - language: Language for relationship labels
    /// - Returns: Result containing array of placement steps or error
    func layoutTreeIncremental(
        members: [FamilyMember],
        root: FamilyMember,
        treeData: FamilyTreeData,
        config: LayoutConfiguration,
        language: Language
    ) -> Result<[[NodePosition]], LayoutError> {
        // Validation
        guard !members.isEmpty else {
            return .failure(.emptyMemberList)
        }

        guard members.contains(where: { $0.id == root.id }) else {
            return .failure(.rootNotFound(root.id))
        }

        // Convert LayoutConfiguration to ContactLayoutEngine.Config
        let engineConfig = ContactLayoutEngine.Config(
            baseSpacing: config.baseSpacing,
            spouseSpacing: config.spouseSpacing,
            verticalSpacing: config.verticalSpacing,
            minSpacing: config.minSpacing,
            expansionFactor: config.expansionFactor
        )

        // Use stateless layout engine for incremental layout
        let steps = ContactLayoutEngine.computeLayoutIncremental(
            members: members,
            root: root,
            treeData: treeData,
            config: engineConfig,
            language: language,
            siblingComparator: siblingComparator
        )

        return .success(steps)
    }

    /// Precomputes relationship degrees for efficient filtering.
    /// - Parameters:
    ///   - root: Root contact
    ///   - members: All family members
    @MainActor
    func precomputeDegrees(from root: FamilyMember, members: [FamilyMember]) {
        RelationshipCacheManager.shared.precomputeAllDegrees(
            from: root,
            members: members
        )
    }

    /// Clears relationship cache.
    @MainActor
    func clearCache() {
        RelationshipCacheManager.shared.clear()
    }
}
