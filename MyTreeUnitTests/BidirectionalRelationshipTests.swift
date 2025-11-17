//
//  BidirectionalRelationshipTests.swift
//  MyTreeUnitTests
//
//  Tests for bidirectional relationship detection (forward and reverse).
//  These tests verify that the system can find relationships even when
//  contacts only have one-directional relations (e.g., parent → child
//  but not child → parent).
//

import XCTest
@testable import MyTree

final class BidirectionalRelationshipTests: XCTestCase {
    // MARK: - Sidebar Ordering with One-Directional Relations

    /// Test that parents are found via REVERSE relations (parent has child→member, but member lacks parent→parent)
    func testSidebarOrdering_FindsParentsViaReverseRelations() {
        // Create family where only parent has child relation, not reverse
        let child = createMember(
            id: "child",
            givenName: "Child",
            familyName: "Test",
            birthDate: date(year: 1990)
        )

        let father = createMemberWithRelations(
            member: createMember(id: "father", givenName: "Father", familyName: "Test", birthDate: date(year: 1960)),
            parents: [],
            siblings: [],
            spouse: nil,
            children: [child]  // Father has child relation
        )

        // Child does NOT have parent relation (one-directional)
        let childWithoutParentRelation = child

        let treeData = FamilyTreeData(
            members: [childWithoutParentRelation, father],
            root: childWithoutParentRelation
        )

        // Use the sidebar sorting logic
        let config = ContactLayoutEngine.Config.default

        let result = ContactLayoutEngine.computeLayoutIncremental(
            members: [childWithoutParentRelation, father],
            root: childWithoutParentRelation,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Verify that father appears BEFORE child in placement steps
        // (First step should be child/root, second should include father)
        XCTAssertGreaterThan(result.count, 1, "Should have multiple placement steps")

        // First step: just child
        let step0Ids = Set(result[0].map { $0.member.id })
        XCTAssertEqual(step0Ids, ["child"], "First step should only have child/root")

        // Second step should add father
        if result.count > 1 {
            let step1Ids = Set(result[1].map { $0.member.id })
            XCTAssertTrue(step1Ids.contains("father"), "Second step should include father (found via reverse relation)")
        }
    }

    /// Test that children are found via REVERSE relations
    func testSidebarOrdering_FindsChildrenViaReverseRelations() {
        // Create family where only child has parent relation, not reverse
        let parent = createMember(
            id: "parent",
            givenName: "Parent",
            familyName: "Test",
            birthDate: date(year: 1960)
        )

        let child = createMemberWithRelations(
            member: createMember(id: "child", givenName: "Child", familyName: "Test", birthDate: date(year: 1990)),
            parents: [parent],  // Child has parent relation
            siblings: [],
            spouse: nil,
            children: []
        )

        // Parent does NOT have child relation (one-directional)
        let parentWithoutChildRelation = parent

        let treeData = FamilyTreeData(
            members: [parentWithoutChildRelation, child],
            root: parentWithoutChildRelation
        )

        let config = ContactLayoutEngine.Config.default

        let result = ContactLayoutEngine.computeLayoutIncremental(
            members: [parentWithoutChildRelation, child],
            root: parentWithoutChildRelation,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Verify child is found and placed
        let allPlacedIds = Set(result.last?.map { $0.member.id } ?? [])
        XCTAssertTrue(allPlacedIds.contains("child"), "Child should be found via reverse parent relation")
    }

    /// Test complete family with mixed one-directional relationships
    func testSidebarOrdering_CompleteFamily_OnlyParentHasChildRelations() {
        // Realistic scenario: VCF data where parent contact has child relations,
        // but child contact doesn't have parent relations

        let child = createMember(id: "child", givenName: "Child", familyName: "Test", birthDate: date(year: 1990))
        let sibling = createMember(id: "sibling", givenName: "Sibling", familyName: "Test", birthDate: date(year: 1985))

        let father = createMemberWithRelations(
            member: createMember(id: "father", givenName: "Father", familyName: "Test", birthDate: date(year: 1960)),
            parents: [],
            siblings: [],
            spouse: nil,
            children: [child, sibling]
        )

        let mother = createMemberWithRelations(
            member: createMember(id: "mother", givenName: "Mother", familyName: "Test", birthDate: date(year: 1965)),
            parents: [],
            siblings: [],
            spouse: father,
            children: [child, sibling]
        )

        let members = [child, father, mother, sibling]
        let treeData = FamilyTreeData(members: members, root: child)
        let config = ContactLayoutEngine.Config.default

        let result = ContactLayoutEngine.computeLayoutIncremental(
            members: members,
            root: child,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Verify ordering: child (root) → father → mother → sibling
        XCTAssertGreaterThan(result.count, 3, "Should have steps for all members")

        // Find step indices where each member first appears
        var fatherStep: Int?
        var motherStep: Int?
        var siblingStep: Int?

        for (index, step) in result.enumerated() {
            let ids = Set(step.map { $0.member.id })
            if ids.contains("father") && fatherStep == nil { fatherStep = index }
            if ids.contains("mother") && motherStep == nil { motherStep = index }
            if ids.contains("sibling") && siblingStep == nil { siblingStep = index }
        }

        XCTAssertNotNil(fatherStep, "Father should appear in placement steps")
        XCTAssertNotNil(motherStep, "Mother should appear in placement steps")
        XCTAssertNotNil(siblingStep, "Sibling should appear in placement steps")

        // Parents should appear before siblings
        if let fatherIdx = fatherStep, let siblingIdx = siblingStep {
            XCTAssertLessThan(fatherIdx, siblingIdx, "Father (parent) should appear before sibling")
        }
    }

    // MARK: - Parent Positioning with Reverse Relations

    /// Test that parent is positioned ABOVE child when only parent has child relation
    func testParentPositioning_ReverseRelation_OneRowAbove() {
        let child = createMember(id: "child", givenName: "Child", familyName: "Test", birthDate: date(year: 1990))

        let parent = createMemberWithRelations(
            member: createMember(id: "parent", givenName: "Parent", familyName: "Test", birthDate: date(year: 1960)),
            parents: [],
            siblings: [],
            spouse: nil,
            children: [child]
        )

        let members = [child, parent]
        let treeData = FamilyTreeData(members: members, root: child)
        let config = ContactLayoutEngine.Config(verticalSpacing: 200)

        let positions = ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: child,
            treeData: treeData,
            config: config,
            language: .english
        )

        guard let childPos = positions.first(where: { $0.member.id == "child" }),
              let parentPos = positions.first(where: { $0.member.id == "parent" }) else {
            XCTFail("Both child and parent should be positioned")
            return
        }

        // Parent should be ABOVE child (negative Y)
        let expectedParentY = childPos.y - 200
        XCTAssertEqual(
            parentPos.y,
            expectedParentY,
            accuracy: 0.1,
            "Parent should be positioned one row above child (found via reverse relation)"
        )

        // Parent should have lower generation
        XCTAssertEqual(
            parentPos.generation,
            childPos.generation - 1,
            "Parent generation should be one less than child"
        )
    }

    // MARK: - Helper Methods

    private func createMember(
        id: String,
        givenName: String,
        familyName: String,
        birthDate: Date?
    ) -> FamilyMember {
        FamilyMember(
            id: id,
            givenName: givenName,
            familyName: familyName,
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: [],
            birthDate: birthDate,
            marriageDate: nil
        )
    }

    private func createMemberWithRelations(
        member: FamilyMember,
        parents: [FamilyMember],
        siblings: [FamilyMember],
        spouse: FamilyMember?,
        children: [FamilyMember]
    ) -> FamilyMember {
        var relations: [FamilyMember.Relation] = []

        for parent in parents {
            relations.append(FamilyMember.Relation(label: "Parent", member: parent))
        }

        for sibling in siblings {
            relations.append(FamilyMember.Relation(label: "Sibling", member: sibling))
        }

        if let spouse = spouse {
            relations.append(FamilyMember.Relation(label: "Spouse", member: spouse))
        }

        for child in children {
            relations.append(FamilyMember.Relation(label: "Child", member: child))
        }

        return FamilyMember(
            id: member.id,
            givenName: member.givenName,
            familyName: member.familyName,
            imageData: member.imageData,
            emailAddresses: member.emailAddresses,
            phoneNumbers: member.phoneNumbers,
            relations: relations,
            birthDate: member.birthDate,
            marriageDate: member.marriageDate
        )
    }

    private func date(year: Int, month: Int = 1, day: Int = 1) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
