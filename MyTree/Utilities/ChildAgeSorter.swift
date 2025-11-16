import Foundation
import CoreGraphics

/// Pure utility for sorting children by age.
///
/// This is a standalone utility function that can be tested without requiring
/// app initialization or linking against the app target.
///
/// **Sorting Rules:**
/// 1. Children with birth dates are sorted oldest to youngest (left to right)
/// 2. Children with dates come before children without dates
/// 3. Children without dates maintain relative order by x position
///
/// **Usage:**
/// ```swift
/// let sorted = ChildAgeSorter.sort(children: positions) { $0.member.birthDate }
/// ```
enum ChildAgeSorter {
    /// Sorts children by age (oldest to youngest, left to right).
    ///
    /// - Parameters:
    ///   - children: Array of child positions to sort
    ///   - birthDate: Closure to extract birth date from each child
    ///   - xPosition: Closure to extract x position from each child (used as fallback for children without dates)
    /// - Returns: Sorted array with oldest children first
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
