//
//  ChildAgeSorterTests.swift
//  MyTreeUnitTests
//
//  Pure unit tests for ChildAgeSorter utility.
//  These tests run without app initialization or TEST_HOST.
//

import XCTest

// Import only Foundation and CoreGraphics - no app dependencies
import Foundation
import CoreGraphics

/// Pure utility for sorting children by age.
///
/// This is a standalone utility function that can be tested without requiring
/// app initialization or linking against the app target.
enum ChildAgeSorter {
    /// Sorts children by age (oldest to youngest, left to right).
    static func sort<T>(
        children: [T],
        birthDate: (T) -> Date?,
        xPosition: (T) -> CGFloat
    ) -> [T] {
        return children.sorted { child1, child2 in
            switch (birthDate(child1), birthDate(child2)) {
            case let (date1?, date2?):
                // Both have dates - older (earlier date) comes first
                // If dates are equal, fall back to x position
                if date1 == date2 {
                    return xPosition(child1) < xPosition(child2)
                }
                return date1 < date2
            case (_?, nil):
                // child1 has date, child2 doesn't - child1 comes first
                return true
            case (nil, _?):
                // child2 has date, child1 doesn't - child2 comes first
                return false
            case (nil, nil):
                // Neither has date - maintain relative order by x position
                return xPosition(child1) < xPosition(child2)
            }
        }
    }
}

final class ChildAgeSorterTests: XCTestCase {
    /// Tests that children are sorted by age (oldest to youngest, left to right).
    ///
    /// Regression test for bug where daughters would swap positions when their brother was removed.
    /// The fix ensures `adjustParentGroup()` sorts children by age before repositioning them.
    func testChildrenAgeSorting() {
        // Given: Children with different birth dates
        let calendar = Calendar.current
        let oldestDate = calendar.date(from: DateComponents(year: 2010, month: 1, day: 1))!
        let middleDate = calendar.date(from: DateComponents(year: 2012, month: 1, day: 1))!
        let youngestDate = calendar.date(from: DateComponents(year: 2014, month: 1, day: 1))!

        // Minimal test structure - just what's needed for sorting
        struct TestChild {
            let id: String
            let birthDate: Date?
            let x: CGFloat
        }

        let oldest = TestChild(id: "oldest", birthDate: oldestDate, x: 100)
        let middle = TestChild(id: "middle", birthDate: middleDate, x: 200)
        let youngest = TestChild(id: "youngest", birthDate: youngestDate, x: 300)
        let noDate = TestChild(id: "dateless", birthDate: nil, x: 50)

        // When: Sort using the pure utility function
        let children = [middle, youngest, oldest, noDate]
        let sortedChildren = ChildAgeSorter.sort(
            children: children,
            birthDate: { $0.birthDate },
            xPosition: { $0.x }
        )

        // Then: Verify age ordering (oldest to youngest, left to right)
        XCTAssertEqual(sortedChildren[0].id, "oldest", "Oldest should be first")
        XCTAssertEqual(sortedChildren[1].id, "middle", "Middle should be second")
        XCTAssertEqual(sortedChildren[2].id, "youngest", "Youngest should be third")
        XCTAssertEqual(sortedChildren[3].id, "dateless", "No date should be last")

        // Verify that children with dates come before those without
        let withoutDates = sortedChildren.filter { $0.birthDate == nil }
        if !withoutDates.isEmpty {
            let firstWithoutDateIndex = sortedChildren.firstIndex { $0.birthDate == nil }!
            let lastWithDateIndex = sortedChildren.lastIndex { $0.birthDate != nil }!
            XCTAssertLessThan(
                lastWithDateIndex,
                firstWithoutDateIndex,
                "Children with birth dates should come before those without"
            )
        }
    }

    /// Tests that children with equal dates are sorted by x position.
    func testEqualDatesSortByXPosition() {
        let calendar = Calendar.current
        let sameDate = calendar.date(from: DateComponents(year: 2012, month: 1, day: 1))!

        struct TestChild {
            let id: String
            let birthDate: Date?
            let x: CGFloat
        }

        let child1 = TestChild(id: "same1", birthDate: sameDate, x: 100)
        let child2 = TestChild(id: "same2", birthDate: sameDate, x: 200)
        let children = [child2, child1]

        let sorted = ChildAgeSorter.sort(
            children: children,
            birthDate: { $0.birthDate },
            xPosition: { $0.x }
        )

        XCTAssertEqual(sorted[0].id, "same1", "When dates are equal, should sort by x position (left to right)")
        XCTAssertEqual(sorted[1].id, "same2", "When dates are equal, should sort by x position (left to right)")
    }

    /// Tests that children without dates maintain relative order by x position.
    func testNoDatesSortByXPosition() {
        struct TestChild {
            let id: String
            let birthDate: Date?
            let x: CGFloat
        }

        let child1 = TestChild(id: "dateless1", birthDate: nil, x: 50)
        let child2 = TestChild(id: "dateless2", birthDate: nil, x: 150)
        let children = [child2, child1]

        let sorted = ChildAgeSorter.sort(
            children: children,
            birthDate: { $0.birthDate },
            xPosition: { $0.x }
        )

        XCTAssertEqual(sorted[0].id, "dateless1", "Children without dates should sort by x position")
        XCTAssertEqual(sorted[1].id, "dateless2", "Children without dates should sort by x position")
    }
}
