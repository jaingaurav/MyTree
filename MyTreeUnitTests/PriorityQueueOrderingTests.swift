//
//  PriorityQueueOrderingTests.swift
//  MyTreeUnitTests
//
//  Tests that verify the priority queue ordering algorithm and parent positioning.
//

import XCTest
@testable import MyTree

final class PriorityQueueOrderingTests: XCTestCase {
    // MARK: - Priority Queue Ordering Tests

    /// Test that priority queue processes members in correct order: parents → siblings → spouse → children
    func testPriorityQueueOrdering_ParentsSiblingSpouseChildren() {
        // Create a family structure:
        // Root (Gaurav) with:
        //   - Parents: Arun (older), Meera (younger)
        //   - Sibling: Dhruv
        //   - Spouse: Swati
        //   - Children: Anya (older), Avni (younger)

        let gaurav = createMember(id: "gaurav", givenName: "Gaurav", familyName: "Jain", birthDate: date(year: 1990))
        let arun = createMember(id: "arun", givenName: "Arun", familyName: "Jain", birthDate: date(year: 1960))
        let meera = createMember(id: "meera", givenName: "Meera", familyName: "Jain", birthDate: date(year: 1965))
        let dhruv = createMember(id: "dhruv", givenName: "Dhruv", familyName: "Jain", birthDate: date(year: 1985))
        let swati = createMember(id: "swati", givenName: "Swati", familyName: "Jain", birthDate: date(year: 1992))
        let anya = createMember(id: "anya", givenName: "Anya", familyName: "Jain", birthDate: date(year: 2015))
        let avni = createMember(id: "avni", givenName: "Avni", familyName: "Jain", birthDate: date(year: 2018))

        // Build relationships
        let gauravWithRelations = createMemberWithRelations(
            member: gaurav,
            parents: [arun, meera],
            siblings: [dhruv],
            spouse: swati,
            children: [anya, avni]
        )

        let arunWithRelations = createMemberWithRelations(
            member: arun,
            parents: [],
            siblings: [],
            spouse: meera,
            children: [gauravWithRelations, dhruv]
        )

        let meeraWithRelations = createMemberWithRelations(
            member: meera,
            parents: [],
            siblings: [],
            spouse: arunWithRelations,
            children: [gauravWithRelations, dhruv]
        )

        let dhruvWithRelations = createMemberWithRelations(
            member: dhruv,
            parents: [arunWithRelations, meeraWithRelations],
            siblings: [gauravWithRelations],
            spouse: nil,
            children: []
        )

        let swatiWithRelations = createMemberWithRelations(
            member: swati,
            parents: [],
            siblings: [],
            spouse: gauravWithRelations,
            children: [anya, avni]
        )

        let anyaWithRelations = createMemberWithRelations(
            member: anya,
            parents: [gauravWithRelations, swatiWithRelations],
            siblings: [avni],
            spouse: nil,
            children: []
        )

        let avniWithRelations = createMemberWithRelations(
            member: avni,
            parents: [gauravWithRelations, swatiWithRelations],
            siblings: [anyaWithRelations],
            spouse: nil,
            children: []
        )

        let members = [
            gauravWithRelations,
            arunWithRelations,
            meeraWithRelations,
            dhruvWithRelations,
            swatiWithRelations,
            anyaWithRelations,
            avniWithRelations
        ]

        // Compute layout using incremental algorithm (which reveals the priority queue order)
        let treeData = FamilyTreeData(members: members, root: gauravWithRelations)
        let config = ContactLayoutEngine.Config.default

        let steps = ContactLayoutEngine.computeLayoutIncremental(
            members: members,
            root: gauravWithRelations,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Verify the order of appearance in steps
        // Step 0: Just Gaurav (root)
        // Step 1: Gaurav + Swati (spouse placed next to root)
        // Step 2: Previous + first parent (Arun - older)
        // Step 3: Previous + second parent (Meera - younger)
        // Step 4: Previous + sibling (Dhruv)
        // Step 5: Previous + first child (Anya - older)
        // Step 6: Previous + second child (Avni - younger)

        XCTAssertFalse(steps.isEmpty, "Should have placement steps")

        // Step 0: Root only
        if !steps.isEmpty {
            let step0Ids = Set(steps[0].map { $0.member.id })
            XCTAssertEqual(step0Ids, ["gaurav"], "Step 0 should only have root")
        }

        // Step 1: Root + Spouse
        if steps.count > 1 {
            let step1Ids = Set(steps[1].map { $0.member.id })
            XCTAssertTrue(step1Ids.contains("gaurav"), "Step 1 should have root")
            XCTAssertTrue(step1Ids.contains("swati"), "Step 1 should have spouse")
        }

        // Verify parents are added before children
        var arunStepIndex: Int?
        var meeraStepIndex: Int?
        var anyaStepIndex: Int?
        var avniStepIndex: Int?

        for (index, step) in steps.enumerated() {
            let ids = Set(step.map { $0.member.id })
            if ids.contains("arun") && arunStepIndex == nil { arunStepIndex = index }
            if ids.contains("meera") && meeraStepIndex == nil { meeraStepIndex = index }
            if ids.contains("anya") && anyaStepIndex == nil { anyaStepIndex = index }
            if ids.contains("avni") && avniStepIndex == nil { avniStepIndex = index }
        }

        XCTAssertNotNil(arunStepIndex, "Arun should appear in steps")
        XCTAssertNotNil(meeraStepIndex, "Meera should appear in steps")
        XCTAssertNotNil(anyaStepIndex, "Anya should appear in steps")
        XCTAssertNotNil(avniStepIndex, "Avni should appear in steps")

        if let arunIdx = arunStepIndex, let anyaIdx = anyaStepIndex {
            XCTAssertLessThan(arunIdx, anyaIdx, "Parent (Arun) should be placed before child (Anya)")
        }

        if let meeraIdx = meeraStepIndex, let avniIdx = avniStepIndex {
            XCTAssertLessThan(meeraIdx, avniIdx, "Parent (Meera) should be placed before child (Avni)")
        }

        // Verify older parent appears before younger parent
        if let arunIdx = arunStepIndex, let meeraIdx = meeraStepIndex {
            XCTAssertLessThan(arunIdx, meeraIdx, "Older parent (Arun) should appear before younger parent (Meera)")
        }
    }

    // MARK: - Parent Positioning Tests

    /// Test that parents are positioned one row above children (negative Y / lower generation)
    func testParentPositioning_OneRowAboveChildren() {
        // Create simple parent-child relationship
        let parent = createMember(id: "parent", givenName: "Parent", familyName: "Test", birthDate: date(year: 1960))
        let child = createMember(id: "child", givenName: "Child", familyName: "Test", birthDate: date(year: 1990))

        let childWithRelations = createMemberWithRelations(
            member: child,
            parents: [parent],
            siblings: [],
            spouse: nil,
            children: []
        )

        let parentWithRelations = createMemberWithRelations(
            member: parent,
            parents: [],
            siblings: [],
            spouse: nil,
            children: [childWithRelations]
        )

        let members = [childWithRelations, parentWithRelations]

        // Compute layout with child as root
        let treeData = FamilyTreeData(members: members, root: childWithRelations)
        let config = ContactLayoutEngine.Config(
            baseSpacing: 150,
            spouseSpacing: 120,
            verticalSpacing: 200,
            minSpacing: 100,
            expansionFactor: 1.2
        )

        let positions = ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: childWithRelations,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Find positions
        guard let childPos = positions.first(where: { $0.member.id == "child" }) else {
            XCTFail("Child position not found")
            return
        }

        guard let parentPos = positions.first(where: { $0.member.id == "parent" }) else {
            XCTFail("Parent position not found")
            return
        }

        // Parent should be one row above (Y should be lower by verticalSpacing)
        let expectedParentY = childPos.y - config.verticalSpacing
        XCTAssertEqual(parentPos.y, expectedParentY, accuracy: 0.1,
                      "Parent should be positioned one row above child (Y = \(childPos.y) - \(config.verticalSpacing) = \(expectedParentY))")

        // Parent should have lower generation number
        XCTAssertEqual(parentPos.generation, childPos.generation - 1,
                      "Parent generation should be one less than child generation")
    }

    /// Test that both parents are positioned at the same Y level (same row)
    func testParentPositioning_BothParentsOnSameRow() {
        // Create family with two parents and one child
        let father = createMember(id: "father", givenName: "Father", familyName: "Test", birthDate: date(year: 1960))
        let mother = createMember(id: "mother", givenName: "Mother", familyName: "Test", birthDate: date(year: 1965))
        let child = createMember(id: "child", givenName: "Child", familyName: "Test", birthDate: date(year: 1990))

        let childWithRelations = createMemberWithRelations(
            member: child,
            parents: [father, mother],
            siblings: [],
            spouse: nil,
            children: []
        )

        let fatherWithRelations = createMemberWithRelations(
            member: father,
            parents: [],
            siblings: [],
            spouse: mother,
            children: [childWithRelations]
        )

        let motherWithRelations = createMemberWithRelations(
            member: mother,
            parents: [],
            siblings: [],
            spouse: fatherWithRelations,
            children: [childWithRelations]
        )

        let members = [childWithRelations, fatherWithRelations, motherWithRelations]

        // Compute layout
        let treeData = FamilyTreeData(members: members, root: childWithRelations)
        let config = ContactLayoutEngine.Config.default

        let positions = ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: childWithRelations,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Find positions
        guard let fatherPos = positions.first(where: { $0.member.id == "father" }),
              let motherPos = positions.first(where: { $0.member.id == "mother" }) else {
            XCTFail("Parent positions not found")
            return
        }

        // Both parents should be at same Y level
        XCTAssertEqual(fatherPos.y, motherPos.y, accuracy: 0.1,
                      "Both parents should be at the same Y level (same row)")

        // Both parents should have same generation
        XCTAssertEqual(fatherPos.generation, motherPos.generation,
                      "Both parents should have the same generation")
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

        // Add parent relations
        for parent in parents {
            relations.append(FamilyMember.Relation(label: "Parent", member: parent))
        }

        // Add sibling relations
        for sibling in siblings {
            relations.append(FamilyMember.Relation(label: "Sibling", member: sibling))
        }

        // Add spouse relation
        if let spouse = spouse {
            relations.append(FamilyMember.Relation(label: "Spouse", member: spouse))
        }

        // Add child relations
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
