//
//  LayoutDeterminismTests.swift
//  MyTreeUnitTests
//
//  Tests that verify layout determinism - the property that the final layout
//  is identical regardless of the input order of family members.
//

import XCTest
@testable import MyTree

final class LayoutDeterminismTests: XCTestCase {

    // MARK: - Tests

    /// Test that layout is deterministic for a single member
    func testSingleMember_LayoutDeterminism() {
        let root = createMember(id: "root", name: "Root")
        let members = [root]

        verifyLayoutDeterminism(
            members: members,
            root: root,
            shuffleCount: 3,
            description: "Single member"
        )
    }

    /// Test that layout is deterministic for three members
    func testThreeMembers_LayoutDeterminism() {
        let root = createMember(id: "root", name: "Root")
        let member2 = createMember(id: "m2", name: "Member2")
        let member3 = createMember(id: "m3", name: "Member3")
        let members = [root, member2, member3]

        verifyLayoutDeterminism(
            members: members,
            root: root,
            shuffleCount: 5,
            description: "Three members"
        )
    }

    /// Test that layout is deterministic for five members
    func testFiveMembers_LayoutDeterminism() {
        let root = createMember(id: "root", name: "Root")
        let member2 = createMember(id: "m2", name: "Member2")
        let member3 = createMember(id: "m3", name: "Member3")
        let member4 = createMember(id: "m4", name: "Member4")
        let member5 = createMember(id: "m5", name: "Member5")
        let members = [root, member2, member3, member4, member5]

        verifyLayoutDeterminism(
            members: members,
            root: root,
            shuffleCount: 5,
            description: "Five members"
        )
    }

    // MARK: - Core Verification Logic

    /// Verifies that layout is deterministic across different input orderings.
    private func verifyLayoutDeterminism(
        members: [FamilyMember],
        root: FamilyMember,
        shuffleCount: Int,
        description: String
    ) {
        print("\n🧪 Testing layout determinism for \(description)")
        print("   Members: \(members.count)")

        XCTAssertGreaterThan(members.count, 0, "Should have at least one member")

        // Compute layout with ORIGINAL order
        guard let originalPositions = computeLayoutInHeadlessMode(
            members: members,
            root: root,
            label: "original order"
        ) else {
            XCTFail("Failed to compute original layout")
            return
        }

        XCTAssertEqual(originalPositions.count, members.count,
                      "Should have position for every member")

        // Compute layout with SHUFFLED orders and verify all match
        for shuffleIndex in 1...shuffleCount {
            let shuffledMembers = members.shuffled()

            guard let shuffledPositions = computeLayoutInHeadlessMode(
                members: shuffledMembers,
                root: root,
                label: "shuffle #\(shuffleIndex)"
            ) else {
                XCTFail("Shuffle #\(shuffleIndex): Failed to compute layout")
                continue
            }

            // Verify same number of positions
            XCTAssertEqual(shuffledPositions.count, originalPositions.count,
                          "Shuffle #\(shuffleIndex): Should have same number of positions")

            // Verify each member has identical position
            for (memberId, originalPos) in originalPositions {
                guard let shuffledPos = shuffledPositions[memberId] else {
                    XCTFail("Shuffle #\(shuffleIndex): Missing position for member \(memberId)")
                    continue
                }

                // Positions must be EXACTLY identical (not just "close")
                let xDiff = abs(shuffledPos.x - originalPos.x)
                let yDiff = abs(shuffledPos.y - originalPos.y)

                XCTAssertEqual(shuffledPos.x, originalPos.x, accuracy: 0.001,
                             "Shuffle #\(shuffleIndex): X differs by \(xDiff) for \(originalPos.member.fullName)")
                XCTAssertEqual(shuffledPos.y, originalPos.y, accuracy: 0.001,
                             "Shuffle #\(shuffleIndex): Y differs by \(yDiff) for \(originalPos.member.fullName)")
                XCTAssertEqual(shuffledPos.generation, originalPos.generation,
                             "Shuffle #\(shuffleIndex): Generation differs for \(originalPos.member.fullName)")
            }
        }

        print("   ✅ Layout is deterministic across \(shuffleCount) shuffles")
    }

    /// Computes layout using the stateless ContactLayoutEngine.
    /// This is a pure function - no mutable state, no deallocation issues.
    private func computeLayoutInHeadlessMode(
        members: [FamilyMember],
        root: FamilyMember,
        label: String
    ) -> [String: NodePosition]? {
        // Create tree data
        let treeData = FamilyTreeData(members: members, root: root)

        // Use stateless layout engine
        let config = ContactLayoutEngine.Config(
            baseSpacing: 200,
            spouseSpacing: 150,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        // Compute layout (pure function call)
        let positions = ContactLayoutEngine.computeLayout(
            members: members,
            root: root,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Convert to dictionary for easy lookup
        var positionMap: [String: NodePosition] = [:]
        for pos in positions {
            positionMap[pos.member.id] = pos
        }

        print("      [\(label)] Computed \(positions.count) positions")

        return positionMap
    }

    /// Creates a test FamilyMember
    private func createMember(
        id: String,
        name: String
    ) -> FamilyMember {
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
}

