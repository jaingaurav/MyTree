//
//  SidebarOrderingBugReproductionTest.swift
//  MyTreeUnitTests
//
//  Reproduces the EXACT bug reported: sidebar shows Dhruv first instead of parents.
//

import XCTest
@testable import MyTree

final class SidebarOrderingBugReproductionTest: XCTestCase {

    /// Reproduces the exact issue: Gaurav's family rendered in wrong order
    /// Expected: Gaurav → Arun → Meera → Dhruv → Swati → Anya → Avni
    /// Actual: Gaurav → Dhruv → Arun → Avni → Meera → Anya → Swati
    func testGauravFamilyOrdering() {
        // Create members (no relations yet)
        let gaurav = createMember(id: "gaurav", givenName: "Gaurav", familyName: "Jain", birthDate: date(year: 1990))
        let arun = createMember(id: "arun", givenName: "Arun Lal", familyName: "Jain", birthDate: date(year: 1960))
        let meera = createMember(id: "meera", givenName: "Meera", familyName: "Jain", birthDate: date(year: 1965))
        let dhruv = createMember(id: "dhruv", givenName: "Dhruv", familyName: "Jain", birthDate: date(year: 1985))
        let swati = createMember(id: "swati", givenName: "Swati Saxena", familyName: "Jain", birthDate: date(year: 1992))
        let anya = createMember(id: "anya", givenName: "Anya", familyName: "Jain", birthDate: date(year: 2015))
        let avni = createMember(id: "avni", givenName: "Avni", familyName: "Jain", birthDate: date(year: 2018))

        // CRITICAL: This simulates VCF data where ONLY parents have child relations
        // Gaurav does NOT have parent relations (one-directional VCF issue)

        // Arun has child relations to Gaurav and Dhruv
        let arunWithRelations = createMemberWithRelations(
            member: arun,
            parents: [],
            siblings: [],
            spouse: meera,
            children: [gaurav, dhruv]
        )

        // Meera has child relations to Gaurav and Dhruv, spouse to Arun
        let meeraWithRelations = createMemberWithRelations(
            member: meera,
            parents: [],
            siblings: [],
            spouse: arunWithRelations,
            children: [gaurav, dhruv]
        )

        // Gaurav has NO parent relations (VCF issue), but has spouse and children
        let gauravWithRelations = createMemberWithRelations(
            member: gaurav,
            parents: [],  // ← THIS IS THE BUG: No parent relations in VCF
            siblings: [dhruv],
            spouse: swati,
            children: [anya, avni]
        )

        // Dhruv has NO parent relations (VCF issue), sibling to Gaurav
        let dhruvWithRelations = createMemberWithRelations(
            member: dhruv,
            parents: [],  // ← VCF issue
            siblings: [gauravWithRelations],
            spouse: nil,
            children: []
        )

        // Swati has spouse to Gaurav, children
        let swatiWithRelations = createMemberWithRelations(
            member: swati,
            parents: [],
            siblings: [],
            spouse: gauravWithRelations,
            children: [anya, avni]
        )

        // Anya has parent relations to Gaurav and Swati
        let anyaWithRelations = createMemberWithRelations(
            member: anya,
            parents: [gauravWithRelations, swatiWithRelations],
            siblings: [avni],
            spouse: nil,
            children: []
        )

        // Avni has parent relations to Gaurav and Swati
        let avniWithRelations = createMemberWithRelations(
            member: avni,
            parents: [gauravWithRelations, swatiWithRelations],
            siblings: [anyaWithRelations],
            spouse: nil,
            children: []
        )

        let allMembers = [
            gauravWithRelations,
            arunWithRelations,
            meeraWithRelations,
            dhruvWithRelations,
            swatiWithRelations,
            anyaWithRelations,
            avniWithRelations
        ]

        // Create tree data
        let treeData = FamilyTreeData(members: allMembers, root: gauravWithRelations)

        // Test the sidebar ordering using computeLayoutIncremental
        let config = ContactLayoutEngine.Config.default
        let steps = ContactLayoutEngine.computeLayoutIncremental(
            members: allMembers,
            root: gauravWithRelations,
            treeData: treeData,
            config: config,
            language: .english
        )

        // Extract the order members appear in steps
        var memberOrder: [String] = []
        var seen: Set<String> = []

        for step in steps {
            for position in step {
                if !seen.contains(position.member.id) {
                    memberOrder.append(position.member.givenName)
                    seen.insert(position.member.id)
                }
            }
        }

        print("\n🔍 ACTUAL ORDER: \(memberOrder.joined(separator: " → "))")

        // Expected order: Gaurav → Arun → Meera → Dhruv → Swati → Anya → Avni
        let expectedOrder = ["Gaurav", "Arun Lal", "Meera", "Dhruv", "Swati Saxena", "Anya", "Avni"]

        XCTAssertEqual(
            memberOrder,
            expectedOrder,
            "\n❌ SIDEBAR ORDER WRONG!" +
            "\nExpected: \(expectedOrder.joined(separator: " → "))" +
            "\nActual:   \(memberOrder.joined(separator: " → "))"
        )
    }

    /// Test that parents are positioned ABOVE root (negative Y)
    func testParentsPositionedAboveRoot() {
        // Same setup as above
        let gaurav = createMember(id: "gaurav", givenName: "Gaurav", familyName: "Jain", birthDate: date(year: 1990))
        let arun = createMember(id: "arun", givenName: "Arun", familyName: "Jain", birthDate: date(year: 1960))

        let arunWithRelations = createMemberWithRelations(
            member: arun,
            parents: [],
            siblings: [],
            spouse: nil,
            children: [gaurav]  // Arun → child relation to Gaurav
        )

        let gauravWithRelations = createMemberWithRelations(
            member: gaurav,
            parents: [],  // No parent relation (VCF issue)
            siblings: [],
            spouse: nil,
            children: []
        )

        let members = [gauravWithRelations, arunWithRelations]
        let treeData = FamilyTreeData(members: members, root: gauravWithRelations)
        let config = ContactLayoutEngine.Config(verticalSpacing: 200)

        let positions = ContactLayoutEngine.computeLayoutWithRelationships(
            members: members,
            root: gauravWithRelations,
            treeData: treeData,
            config: config,
            language: .english
        )

        guard let gauravPos = positions.first(where: { $0.member.id == "gaurav" }),
              let arunPos = positions.first(where: { $0.member.id == "arun" }) else {
            XCTFail("Both members should be positioned")
            return
        }

        print("\n📍 Gaurav at: y=\(gauravPos.y), generation=\(gauravPos.generation)")
        print("📍 Arun at:   y=\(arunPos.y), generation=\(arunPos.generation)")

        // Arun should be ABOVE Gaurav (Y should be negative if Gaurav is at 0)
        XCTAssertLessThan(
            arunPos.y,
            gauravPos.y,
            "❌ Arun (parent) should be ABOVE Gaurav (child): " +
            "arun.y=\(arunPos.y) should be < gaurav.y=\(gauravPos.y)"
        )

        // Expected: Arun at y = 0 - 200 = -200
        let expectedArunY = gauravPos.y - 200
        XCTAssertEqual(
            arunPos.y,
            expectedArunY,
            accuracy: 0.1,
            "❌ Arun should be 200 units above Gaurav"
        )

        // Generation should be -1
        XCTAssertEqual(
            arunPos.generation,
            gauravPos.generation - 1,
            "❌ Arun's generation should be one less than Gaurav's"
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
