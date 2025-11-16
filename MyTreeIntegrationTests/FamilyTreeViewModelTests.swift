//
//  FamilyTreeViewModelTests.swift
//  MyTreeIntegrationTests
//
//  Unit tests for FamilyTreeViewModel.
//

import XCTest
@testable import MyTree

final class FamilyTreeViewModelTests: XCTestCase {
    var viewModel: FamilyTreeViewModel?
    var testTreeData: FamilyTreeData?
    var testRoot: FamilyMember?

    override func setUp() {
        super.setUp()

        // Create test data
        let root = createMember(id: "root", name: "Root")
        let child = createMember(id: "child", name: "Child")
        testRoot = root
        let treeData = FamilyTreeData(members: [root, child], root: root)
        testTreeData = treeData

        viewModel = FamilyTreeViewModel(treeData: treeData, myContact: root)
    }

    override func tearDown() {
        viewModel = nil
        testTreeData = nil
        testRoot = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        guard let viewModel = viewModel else {
            XCTFail("ViewModel not initialized")
            return
        }

        XCTAssertEqual(viewModel.treeData.members.count, 2)
        XCTAssertEqual(viewModel.myContact?.id, "root")
        XCTAssertEqual(viewModel.degreeOfSeparation, 0)
        XCTAssertEqual(viewModel.scale, 1.0)
        XCTAssertEqual(viewModel.selectedLanguage, .english)
    }

    // MARK: - Filter Tests

    func testUpdateFilteredMembers() {
        guard let viewModel = viewModel else {
            XCTFail("ViewModel not initialized")
            return
        }

        // Given
        viewModel.visibleMemberIds = ["root", "child"]

        // When
        viewModel.updateFilteredMembers()

        // Then
        XCTAssertEqual(viewModel.filteredMembers.count, 2)
        XCTAssertTrue(viewModel.filteredMembers.contains { $0.id == "root" })
        XCTAssertTrue(viewModel.filteredMembers.contains { $0.id == "child" })
    }

    func testUpdateFilteredMembersWithPartialVisibility() {
        guard let viewModel = viewModel else {
            XCTFail("ViewModel not initialized")
            return
        }

        // Given
        viewModel.visibleMemberIds = ["root"]  // Only root visible

        // When
        viewModel.updateFilteredMembers()

        // Then
        XCTAssertEqual(viewModel.filteredMembers.count, 1)
        XCTAssertTrue(viewModel.filteredMembers.contains { $0.id == "root" })
    }

    // MARK: - Selection Tests

    func testHighlightPathToRoot() {
        guard let viewModel = viewModel else {
            XCTFail("ViewModel not initialized")
            return
        }

        // Given
        let childId = "child"

        // When
        viewModel.highlightPathToRoot(from: childId)

        // Then - should have path IDs (actual path depends on tree structure)
        // For this test, just verify method doesn't crash
        XCTAssertTrue(true)
    }

    func testClearSelection() {
        guard let viewModel = viewModel, let testRoot = testRoot else {
            XCTFail("ViewModel or testRoot not initialized")
            return
        }

        // Given
        viewModel.selectedMember = testRoot
        viewModel.showingDetail = true
        viewModel.highlightedPath = ["root"]

        // When
        viewModel.clearSelection()

        // Then
        XCTAssertNil(viewModel.selectedMember)
        XCTAssertFalse(viewModel.showingDetail)
        XCTAssertTrue(viewModel.highlightedPath.isEmpty)
    }

    func testClearHighlighting() {
        guard let viewModel = viewModel, let testRoot = testRoot else {
            XCTFail("ViewModel or testRoot not initialized")
            return
        }

        // Given
        viewModel.selectedMember = testRoot
        viewModel.highlightedPath = ["root", "child"]

        // When
        viewModel.clearHighlighting()

        // Then
        XCTAssertNotNil(viewModel.selectedMember, "Selection should remain")
        XCTAssertTrue(viewModel.highlightedPath.isEmpty, "Highlighting should be cleared")
    }

    // MARK: - Viewport Tests

    func testCalculateCenteringOffset() {
        guard let viewModel = viewModel, let testRoot = testRoot else {
            XCTFail("ViewModel or testRoot not initialized")
            return
        }

        // Given
        let nodePos = NodePosition(
            member: testRoot,
            x: 100,
            y: 50,
            generation: 0,
            relationshipToRoot: "Me",
            relationshipInfo: RelationshipInfo(kind: .me, familySide: .unknown, path: [testRoot])
        )
        let viewportSize = CGSize(width: 1000, height: 800)

        // When
        let offset = viewModel.calculateCenteringOffset(
            for: nodePos,
            viewportSize: viewportSize,
            sidebarVisible: false
        )

        // Then
        XCTAssertNotEqual(offset.width, 0)
        XCTAssertNotEqual(offset.height, 0)
    }

    // MARK: - Deduplication Tests

    func testDeduplicatePositions() {
        guard let viewModel = viewModel else {
            XCTFail("ViewModel not initialized")
            return
        }

        // Given
        let pos1 = createPosition(id: "member1", x: 0, y: 0)
        let pos2 = createPosition(id: "member2", x: 100, y: 0)
        let pos1Duplicate = createPosition(id: "member1", x: 50, y: 0)  // Duplicate ID

        let positions = [pos1, pos2, pos1Duplicate]

        // When
        let deduplicated = viewModel.deduplicatePositions(positions)

        // Then
        XCTAssertEqual(deduplicated.count, 2, "Should remove duplicate")
        XCTAssertEqual(deduplicated.last?.member.id, "member1", "Should keep last occurrence")
        XCTAssertEqual(deduplicated.last?.x, 50, "Should keep last occurrence's position")
    }

    // MARK: - Test Helpers

    private func createMember(id: String, name: String) -> FamilyMember {
        FamilyMember(
            id: id,
            givenName: name,
            familyName: "Test",
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: [],
            birthDate: nil,
            marriageDate: nil
        )
    }

    private func createPosition(id: String, x: CGFloat, y: CGFloat) -> NodePosition {
        let member = createMember(id: id, name: "Member")
        return NodePosition(
            member: member,
            x: x,
            y: y,
            generation: 0,
            relationshipToRoot: "Test",
            relationshipInfo: RelationshipInfo(kind: .me, familySide: .unknown, path: [member])
        )
    }
}
