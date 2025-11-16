import SwiftUI

/// Renders a single family member as a circular node with photo/monogram, name, and relationship label.
///
/// This is the fundamental visual unit of the family tree. Each node displays:
/// - Circular avatar (photo or monogram if no photo available)
/// - Member's full name below the circle
/// - Localized relationship label (e.g., "Father", "Sister")
/// - Visual feedback for selection and highlighting states
///
/// **Visual States:**
/// - Normal: Blue gradient with white border
/// - Highlighted: Enhanced blue glow (when in path to selected member)
/// - Selected: Yellow border (when clicked)
///
/// **Usage:**
/// ```swift
/// ContactNodeView(
///     member: familyMember,
///     isSelected: false,
///     isHighlighted: true,
///     relationshipInfo: info,
///     language: .english
/// )
/// ```
struct ContactNodeView: View {
    let member: FamilyMember
    let isSelected: Bool
    let isHighlighted: Bool
    let relationshipInfo: RelationshipInfo
    let language: Language

    var localizedLabel: String {
        RelationshipCalculator.getLocalizedRelationship(info: relationshipInfo, language: language)
    }

    private var gradientColors: [Color] {
        if isHighlighted {
            return [.blue.opacity(0.8), .cyan.opacity(0.8)]
        }
        return [.blue.opacity(0.6), .purple.opacity(0.6)]
    }

    private var borderColor: Color {
        if isSelected { return .yellow }
        return isHighlighted ? .blue : .white
    }

    private var borderWidth: CGFloat {
        if isSelected { return 4 }
        return isHighlighted ? 3 : 2
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: isHighlighted ? .blue : .clear, radius: 12)

                if let imageData = member.imageData,
                   let image = Image(platformImageData: imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                } else {
                    ContactImageHelper.monogramView(
                        givenName: member.givenName,
                        familyName: member.familyName,
                        size: 76,
                        isHighlighted: isHighlighted
                    )
                }

                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 2) {
                Text(member.fullName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 120)

                if !localizedLabel.isEmpty {
                    Text(localizedLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
            }
        }
    }
}
