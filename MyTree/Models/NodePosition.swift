import SwiftUI

/// Represents the spatial position and metadata for a family member node in the tree visualization.
///
/// This struct combines a family member with their calculated position in the tree layout.
/// It serves as the primary data structure passed to SwiftUI views for rendering.
///
/// **Coordinate System:**
/// - `x`: Horizontal position in tree space (can be negative or positive)
/// - `y`: Vertical position in tree space (typically negative for ancestors, positive for descendants)
/// - Origin (0, 0) is typically the root person ("me")
///
/// **Usage Example:**
/// ```swift
/// let position = NodePosition(
///     member: johnSmith,
///     x: 150.0,
///     y: -200.0,  // Parent generation (above root)
///     generation: -1,
///     relationshipToRoot: "Father",
///     relationshipInfo: relationshipInfo
/// )
/// ```
struct NodePosition: Hashable, Identifiable {
    /// Unique identifier derived from the member's ID
    var id: String { member.id }

    /// The family member at this position
    let member: FamilyMember

    /// Horizontal position in tree coordinate space
    var x: CGFloat

    /// Vertical position in tree coordinate space
    var y: CGFloat

    /// Generation relative to root (-1 for parents, 0 for root, 1 for children, etc.)
    let generation: Int

    /// Localized relationship description to root (e.g., "Father", "Brother", "Niece")
    let relationshipToRoot: String

    /// Structured relationship information including kind, side, and path
    let relationshipInfo: RelationshipInfo

    func hash(into hasher: inout Hasher) {
        hasher.combine(member.id)
    }

    static func == (lhs: NodePosition, rhs: NodePosition) -> Bool {
        lhs.member.id == rhs.member.id
    }
}
