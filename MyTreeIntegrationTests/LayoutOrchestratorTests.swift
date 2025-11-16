//
//  LayoutOrchestratorTests.swift
//  MyTreeIntegrationTests
//
//  Unit tests for LayoutOrchestrator service.
//

import XCTest
@testable import MyTree

final class LayoutOrchestratorTests: XCTestCase {
    var orchestrator: LayoutOrchestrator?

    override func setUp() {
        super.setUp()
        orchestrator = LayoutOrchestrator()
    }

    override func tearDown() {
        orchestrator = nil
        super.tearDown()
    }

    // MARK: - Error Handling Tests

    func testLayoutTreeWithEmptyMembers() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given
        let root = createTestMember(id: "root", name: "Root")
        let treeData = createTestTreeData(members: [root], root: root)

        // When
        let result = orchestrator.layoutTree(
            members: [],  // Empty!
            root: root,
            treeData: treeData,
            config: .default,
            language: .english
        )

        // Then
        if case .failure(let error) = result {
            XCTAssertEqual(error, .emptyMemberList)
        } else {
            XCTFail("Expected failure with emptyMemberList error")
        }
    }

    func testLayoutTreeWithMissingRoot() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given
        let root = createTestMember(id: "root", name: "Root")
        let otherMember = createTestMember(id: "other", name: "Other")
        let treeData = createTestTreeData(members: [otherMember], root: root)

        // When
        let result = orchestrator.layoutTree(
            members: [otherMember],  // Root not in members!
            root: root,
            treeData: treeData,
            config: .default,
            language: .english
        )

        // Then
        if case .failure(let error) = result {
            XCTAssertEqual(error, .rootNotFound("root"))
        } else {
            XCTFail("Expected failure with rootNotFound error")
        }
    }

    // DISABLED: Crashes due to Swift 6 runtime bug in TaskLocal/MainActor deallocation during test teardown.
    // Issue: ContactLayoutManager.__deallocating_deinit triggers memory corruption in XCTest environment.
    // See: ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
    /*
    func testLayoutTreeWithValidData() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given
        let root = createTestMember(id: "root", name: "Root")
        let child = createTestMember(id: "child", name: "Child")
        let members = [root, child]
        let treeData = createTestTreeData(members: members, root: root)

        // When
        let result = orchestrator.layoutTree(
            members: members,
            root: root,
            treeData: treeData,
            config: .default,
            language: .english
        )

        // Then
        switch result {
        case .success(let positions):
            XCTAssertEqual(positions.count, 2, "Should layout both members")
            XCTAssertTrue(positions.contains { $0.member.id == "root" })
            XCTAssertTrue(positions.contains { $0.member.id == "child" })
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    */

    // MARK: - Incremental Layout Tests

    // DISABLED: Crashes due to Swift 6 runtime bug in TaskLocal/MainActor deallocation during test teardown.
    // Issue: ContactLayoutManager.__deallocating_deinit triggers memory corruption in XCTest environment.
    // See: ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
    /*
    func testLayoutTreeIncremental() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given
        let root = createTestMember(id: "root", name: "Root")
        let child = createTestMember(id: "child", name: "Child")
        let members = [root, child]
        let treeData = createTestTreeData(members: members, root: root)

        // When
        let result = orchestrator.layoutTreeIncremental(
            members: members,
            root: root,
            treeData: treeData,
            config: .default,
            language: .english
        )

        // Then
        switch result {
        case .success(let steps):
            XCTAssertGreaterThan(steps.count, 0, "Should have at least one step")
            XCTAssertEqual(steps.last?.count, 2, "Final step should have both members")
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    */

    // MARK: - Root Positioning Tests

    // DISABLED: Crashes due to Swift 6 runtime bug in TaskLocal/MainActor deallocation during test teardown.
    // Issue: ContactLayoutManager.__deallocating_deinit triggers memory corruption in XCTest environment.
    // See: ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
    /*
    /// Tests that root node stays at (0, 0) when children are added incrementally.
    /// Regression test for bug where root would shift when second child was added.
    func testRootStaysFixedWhenChildrenAdded() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given: Family with root, spouse, 2 children, and parents
        let spouse = createTestMember(id: "spouse", name: "Jane Smith")
        let child1 = createTestMember(id: "child1", name: "Alice Smith")
        let child2 = createTestMember(id: "child2", name: "Bob Smith")
        let parent1 = createTestMember(id: "parent1", name: "John Michael Smith")
        let parent2 = createTestMember(id: "parent2", name: "Mary Smith")

        // Setup root with relationships
        let root = createTestMember(
            id: "root",
            name: "John Smith",
            relations: [
                FamilyMember.Relation(label: "Spouse", member: spouse),
                FamilyMember.Relation(label: "Child", member: child1),
                FamilyMember.Relation(label: "Child", member: child2),
                FamilyMember.Relation(label: "Parent", member: parent1),
                FamilyMember.Relation(label: "Parent", member: parent2)
            ]
        )

        let members = [root, spouse, child1, child2, parent1, parent2]
        let treeData = createTestTreeData(members: members, root: root)

        // When: Layout incrementally
        let result = orchestrator.layoutTreeIncremental(
            members: members,
            root: root,
            treeData: treeData,
            config: .default,
            language: .english
        )

        // Then: Verify root stays at (0, 0) in all steps
        switch result {
        case .success(let steps):
            for (index, step) in steps.enumerated() {
                if let rootPosition = step.first(where: { $0.member.id == "root" }) {
                    XCTAssertEqual(
                        rootPosition.x,
                        0,
                        accuracy: 0.1,
                        "Root X should be 0 in step \(index + 1)"
                    )
                    XCTAssertEqual(
                        rootPosition.y,
                        0,
                        accuracy: 0.1,
                        "Root Y should be 0 in step \(index + 1)"
                    )
                }
            }

            // Verify parents stay centered above root (at x=0 or equidistant)
            if let finalStep = steps.last {
                let parent1Pos = finalStep.first { $0.member.id == "parent1" }
                let parent2Pos = finalStep.first { $0.member.id == "parent2" }

                if let p1 = parent1Pos, let p2 = parent2Pos {
                    // Parents should be equidistant from x=0
                    let parent1Distance = abs(p1.x - 0)
                    let parent2Distance = abs(p2.x - 0)
                    XCTAssertEqual(
                        parent1Distance,
                        parent2Distance,
                        accuracy: 1.0,
                        "Parents should be equidistant from root"
                    )
                }
            }

        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    */

    // MARK: - Age Ordering Preservation Tests

    // NOTE: Pure unit tests for ChildAgeSorter have been moved to MyTreeUnitTests target.
    // This test target (MyTreeIntegrationTests) is for integration tests that require app initialization.

    // MARK: - Layout Stability Tests

    // DISABLED: Crashes due to Swift 6 runtime bug in TaskLocal/MainActor deallocation during test teardown.
    // Issue: ContactLayoutManager.__deallocating_deinit triggers memory corruption in XCTest environment.
    // See: ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
    /*
    // swiftlint:disable function_body_length
    /// Tests that parent-child centering is preserved when siblings are removed and re-added.
    /// This is a regression test for the bug where parents would shift incorrectly when siblings
    /// were removed, breaking the centering above children.
    func testParentChildCenteringStabilityWhenSiblingRemoved() {
        // Given: Family with root, two parents, and two siblings
        let root = createTestMember(
            id: "root",
            name: "Root",
            birthDate: Date(timeIntervalSince1970: 0) // 1970-01-01
        )
        let parent1 = createTestMember(
            id: "parent1",
            name: "Parent 1",
            relations: [FamilyMember.Relation(label: "Child", member: root)]
        )
        let parent2 = createTestMember(
            id: "parent2",
            name: "Parent 2",
            relations: [FamilyMember.Relation(label: "Child", member: root)]
        )
        let sibling1 = createTestMember(
            id: "sibling1",
            name: "Sibling 1",
            relations: [
                FamilyMember.Relation(label: "Parent", member: parent1),
                FamilyMember.Relation(label: "Parent", member: parent2)
            ],
            birthDate: Date(timeIntervalSince1970: -86400) // One day older than root
        )
        let sibling2 = createTestMember(
            id: "sibling2",
            name: "Sibling 2",
            relations: [
                FamilyMember.Relation(label: "Parent", member: parent1),
                FamilyMember.Relation(label: "Parent", member: parent2)
            ],
            birthDate: Date(timeIntervalSince1970: 86400) // One day younger than root
        )

        // Update root to have parents and siblings
        let rootWithRelations = createTestMember(
            id: "root",
            name: "Root",
            relations: [
                FamilyMember.Relation(label: "Parent", member: parent1),
                FamilyMember.Relation(label: "Parent", member: parent2),
                FamilyMember.Relation(label: "Sibling", member: sibling1),
                FamilyMember.Relation(label: "Sibling", member: sibling2)
            ],
            birthDate: Date(timeIntervalSince1970: 0)
        )

        let allMembers = [rootWithRelations, parent1, parent2, sibling1, sibling2]
        let treeData = createTestTreeData(members: allMembers, root: rootWithRelations)

        // Create layout manager
        let layoutManager = ContactLayoutManager(
            members: allMembers,
            root: rootWithRelations,
            treeData: treeData,
            baseSpacing: 200,
            spouseSpacing: 150,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        // When: Layout with all siblings
        let positionsWithAll = layoutManager.layoutNodes(language: Language.english)

        // Find parent and child positions
        let parent1Pos = positionsWithAll.first { $0.member.id == "parent1" }
        let parent2Pos = positionsWithAll.first { $0.member.id == "parent2" }
        let sibling1Pos = positionsWithAll.first { $0.member.id == "sibling1" }
        let sibling2Pos = positionsWithAll.first { $0.member.id == "sibling2" }

        XCTAssertNotNil(parent1Pos, "Parent 1 should be positioned")
        XCTAssertNotNil(parent2Pos, "Parent 2 should be positioned")
        XCTAssertNotNil(sibling1Pos, "Sibling 1 should be positioned")
        XCTAssertNotNil(sibling2Pos, "Sibling 2 should be positioned")

        // Calculate parents center and children center
        let parentsCenterX = ((parent1Pos!.x + parent2Pos!.x) / 2)
        let childrenCenterX = ((sibling1Pos!.x + sibling2Pos!.x) / 2)

        // Parents should be centered above children (within tolerance)
        let centeringError: CGFloat = abs(parentsCenterX - childrenCenterX)
        XCTAssertLessThan(centeringError, 50, "Parents should be centered above children (error: \(centeringError))")

        // When: Remove sibling2 and re-layout
        let membersWithoutSibling2 = allMembers.filter { $0.id != "sibling2" }
        let treeDataWithoutSibling2 = createTestTreeData(members: membersWithoutSibling2, root: rootWithRelations)
        let layoutManagerWithoutSibling2 = ContactLayoutManager(
            members: membersWithoutSibling2,
            root: rootWithRelations,
            treeData: treeDataWithoutSibling2,
            baseSpacing: 200,
            spouseSpacing: 150,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        let positionsWithoutSibling2 = layoutManagerWithoutSibling2.layoutNodes(language: Language.english)

        // Find updated positions
        let parent1PosAfter = positionsWithoutSibling2.first { $0.member.id == "parent1" }
        let parent2PosAfter = positionsWithoutSibling2.first { $0.member.id == "parent2" }
        let sibling1PosAfter = positionsWithoutSibling2.first { $0.member.id == "sibling1" }

        XCTAssertNotNil(parent1PosAfter, "Parent 1 should still be positioned")
        XCTAssertNotNil(parent2PosAfter, "Parent 2 should still be positioned")
        XCTAssertNotNil(sibling1PosAfter, "Sibling 1 should still be positioned")

        // Calculate new centers
        let parentsCenterXAfter = ((parent1PosAfter!.x + parent2PosAfter!.x) / 2)
        let childCenterXAfter = sibling1PosAfter!.x

        // Parents should still be centered above the remaining child
        let centeringErrorAfter: CGFloat = abs(parentsCenterXAfter - childCenterXAfter)
        let errorMsg = "Parents should be centered above remaining child after removal (error: \(centeringErrorAfter))"
        XCTAssertLessThan(centeringErrorAfter, 50, errorMsg)
    }
    // swiftlint:enable function_body_length
    */

    // MARK: - Cache Management Tests

    @MainActor
    func testPrecomputeDegrees() {
        guard let orchestrator = orchestrator else {
            XCTFail("Orchestrator not initialized")
            return
        }

        // Given
        let root = createTestMember(id: "root", name: "Root")
        let members = [root]

        // When/Then - should not crash
        orchestrator.precomputeDegrees(from: root, members: members)
        orchestrator.clearCache()
    }

    // MARK: - Test Helpers

    private func createTestMember(
        id: String,
        name: String,
        relations: [FamilyMember.Relation] = [],
        birthDate: Date? = nil
    ) -> FamilyMember {
        FamilyMember(
            id: id,
            givenName: name,
            familyName: "Test",
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: relations,
            birthDate: birthDate,
            marriageDate: nil
        )
    }

    private func createTestTreeData(members: [FamilyMember], root: FamilyMember) -> FamilyTreeData {
        FamilyTreeData(members: members, root: root)
    }
}
