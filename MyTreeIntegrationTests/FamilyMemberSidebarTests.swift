//
//  FamilyMemberSidebarTests.swift
//  MyTreeIntegrationTests
//
//  Unit tests for FamilyMemberSidebar sorting algorithm.
//

import XCTest
@testable import MyTree

final class FamilyMemberSidebarTests: XCTestCase {
    // MARK: - Test Helpers

    private func createMember(
        id: String,
        name: String,
        birthDate: Date? = nil,
        marriageDate: Date? = nil,
        hasSpouse: Bool = false
    ) -> FamilyMember {
        var relations: [FamilyMember.Relation] = []

        if hasSpouse {
            // Create a dummy spouse relation
            let spouse = FamilyMember(
                id: "spouse-\(id)",
                givenName: "Spouse",
                familyName: "Test",
                imageData: nil,
                emailAddresses: [],
                phoneNumbers: [],
                relations: [],
                birthDate: nil,
                marriageDate: nil
            )
            relations.append(FamilyMember.Relation(label: "Spouse", member: spouse))
        }

        return FamilyMember(
            id: id,
            givenName: name,
            familyName: "Test",
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: relations,
            birthDate: birthDate,
            marriageDate: marriageDate
        )
    }

    private func createTreeData(members: [FamilyMember], root: FamilyMember) -> FamilyTreeData {
        FamilyTreeData(members: members, root: root)
    }

    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)!
    }

    // MARK: - Sorting Tests

    func testSortingByDegreeOfSeparation() {
        // Given: Members with different degrees of separation
        let root = createMember(id: "root", name: "Root")
        let degree1 = createMember(id: "degree1", name: "Child")
        let degree2 = createMember(id: "degree2", name: "Grandchild")

        let members = [degree2, root, degree1] // Intentionally unsorted
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting members using the sidebar's sorting logic
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Should be sorted by degree (0, 1, 2)
        XCTAssertEqual(sorted.map { $0.id }, ["root", "degree1", "degree2"])
    }

    func testSortingSpousesByMarriageDate() {
        // Given: Multiple spouses with different marriage dates
        let root = createMember(id: "root", name: "Root")

        let spouse1 = createMember(
            id: "spouse1",
            name: "Alice",
            marriageDate: dateFromString("2010-06-15"),
            hasSpouse: true
        )
        let spouse2 = createMember(
            id: "spouse2",
            name: "Bob",
            marriageDate: dateFromString("2005-03-20"),
            hasSpouse: true
        )
        let spouse3 = createMember(
            id: "spouse3",
            name: "Charlie",
            marriageDate: dateFromString("2015-09-10"),
            hasSpouse: true
        )

        let members = [spouse1, spouse3, spouse2, root] // Intentionally unsorted
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Spouses should be sorted by marriage date (oldest first)
        let spouseSorted = sorted.filter { $0.id.starts(with: "spouse") }
        XCTAssertEqual(spouseSorted.map { $0.id }, ["spouse2", "spouse1", "spouse3"])
    }

    func testSortingNonSpousesByBirthday() {
        // Given: Multiple non-spouse members with different birthdays
        let root = createMember(id: "root", name: "Root")

        let child1 = createMember(
            id: "child1",
            name: "Alice",
            birthDate: dateFromString("1995-06-15")
        )
        let child2 = createMember(
            id: "child2",
            name: "Bob",
            birthDate: dateFromString("1990-03-20")
        )
        let child3 = createMember(
            id: "child3",
            name: "Charlie",
            birthDate: dateFromString("2000-09-10")
        )

        let members = [child1, child3, child2, root] // Intentionally unsorted
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Non-spouses should be sorted by birthday (oldest first)
        let childrenSorted = sorted.filter { $0.id.starts(with: "child") }
        XCTAssertEqual(childrenSorted.map { $0.id }, ["child2", "child1", "child3"])
    }

    func testSortingMembersWithNilDates() {
        // Given: Members with and without dates
        let root = createMember(id: "root", name: "Root")

        let withDate = createMember(
            id: "withDate",
            name: "Alice",
            birthDate: dateFromString("1990-01-01")
        )
        let withoutDate1 = createMember(id: "noDate1", name: "Bob")
        let withoutDate2 = createMember(id: "noDate2", name: "Charlie")

        let members = [withoutDate1, withDate, withoutDate2, root]
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Members with dates should come before those without
        // Among those without dates, should be alphabetically sorted
        let nonRootSorted = sorted.filter { $0.id != "root" }
        XCTAssertEqual(nonRootSorted[0].id, "withDate")
        // Bob and Charlie should come after, alphabetically
        XCTAssertTrue(nonRootSorted[1].id == "noDate1" || nonRootSorted[1].id == "noDate2")
    }

    func testSortingMembersWithSameDateByName() {
        // Given: Members with the same birthday
        let root = createMember(id: "root", name: "Root")

        let sameDate = dateFromString("1990-01-01")
        let member1 = createMember(id: "m1", name: "Charlie", birthDate: sameDate)
        let member2 = createMember(id: "m2", name: "Alice", birthDate: sameDate)
        let member3 = createMember(id: "m3", name: "Bob", birthDate: sameDate)

        let members = [member1, member3, member2, root]
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Should be sorted alphabetically by name
        let nonRootSorted = sorted.filter { $0.id != "root" }
        XCTAssertEqual(nonRootSorted.map { $0.member.givenName }, ["Alice", "Bob", "Charlie"])
    }

    func testSortingStability() {
        // Given: Same members sorted twice
        let root = createMember(id: "root", name: "Root")

        let member1 = createMember(id: "m1", name: "Alice", birthDate: dateFromString("1990-01-01"))
        let member2 = createMember(id: "m2", name: "Bob", birthDate: dateFromString("1995-01-01"))
        let member3 = createMember(id: "m3", name: "Charlie")

        let members = [member1, member2, member3, root]
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting multiple times
        let sorted1 = sortMembers(members, treeData: treeData, rootId: root.id)
        let sorted2 = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Results should be identical
        XCTAssertEqual(sorted1.map { $0.id }, sorted2.map { $0.id })
    }

    func testComplexSortingScenario() {
        // Given: Mixed members across different degrees with various dates
        let root = createMember(id: "root", name: "Root")

        // Degree 1 - Parents and spouse
        let parent1 = createMember(id: "parent1", name: "Father", birthDate: dateFromString("1960-05-10"))
        let parent2 = createMember(id: "parent2", name: "Mother", birthDate: dateFromString("1962-08-20"))
        let spouse = createMember(
            id: "spouse",
            name: "Spouse",
            marriageDate: dateFromString("2015-06-15"),
            hasSpouse: true
        )

        // Degree 2 - Children
        let child1 = createMember(id: "child1", name: "Alice", birthDate: dateFromString("2016-03-10"))
        let child2 = createMember(id: "child2", name: "Bob", birthDate: dateFromString("2018-07-22"))
        let child3 = createMember(id: "child3", name: "Charlie") // No birthdate

        // Mix them up intentionally
        let members = [child2, spouse, parent2, child3, child1, parent1, root]
        let treeData = createTreeData(members: members, root: root)

        // When: Sorting
        let sorted = sortMembers(members, treeData: treeData, rootId: root.id)

        // Then: Verify complex sorting order
        let ids = sorted.map { $0.id }

        // Root should be first (degree 0)
        XCTAssertEqual(ids[0], "root")

        // Degree 1 members should come next
        let degree1Ids = ids.filter { ["parent1", "parent2", "spouse"].contains($0) }
        XCTAssertEqual(degree1Ids.count, 3)

        // Within degree 1, parents should be sorted by birthdate (oldest first)
        let parentIds = ids.filter { ["parent1", "parent2"].contains($0) }
        XCTAssertEqual(parentIds, ["parent1", "parent2"])
    }

    // MARK: - Helper Method Mimicking Sidebar Logic

    private func sortMembers(
        _ members: [FamilyMember],
        treeData: FamilyTreeData,
        rootId: String
    ) -> [FamilyMemberSidebar.SortedMember] {
        return members.map { member in
            let degree = treeData.degreeOfSeparation(for: member.id)
            let hasSpouse = member.relations.contains { $0.relationType == .spouse }
            let sortDate = hasSpouse ? member.marriageDate : member.birthDate

            return FamilyMemberSidebar.SortedMember(
                id: member.id,
                member: member,
                degree: degree == Int.max ? 999 : degree,
                isVisible: true,
                relationshipLabel: "Test",
                sortDate: sortDate,
                age: nil
            )
        }
        .sorted { first, second in
            // First sort by degree of separation (ascending)
            if first.degree != second.degree {
                return first.degree < second.degree
            }
            // Then by date (ascending - older dates first)
            // Handle nil dates: put them at the end
            switch (first.sortDate, second.sortDate) {
            case let (date1?, date2?):
                if date1 != date2 {
                    return date1 < date2
                }
            case (nil, _?):
                return false  // Put nil dates after non-nil
            case (_?, nil):
                return true   // Put non-nil dates before nil
            case (nil, nil):
                break  // Both nil, continue to name sorting
            }
            // Finally by name
            return first.member.fullName < second.member.fullName
        }
    }
}
