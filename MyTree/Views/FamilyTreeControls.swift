import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Namespace

/// Namespace for family tree UI controls and popovers
enum FamilyTreeControls {}

// MARK: - Platform Color Extension

extension Color {
    /// Adaptive background color that maps to the platform's window/system background.
    static var adaptiveBackground: Color {
        #if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Contact Popover

/// Contact information popover with emails, phones, and relations shown.
struct ContactPopover: View {
    let member: FamilyMember
    let position: CGPoint
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Close button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !member.emailAddresses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Email", systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(member.emailAddresses, id: \.self) { email in
                        Text(email)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }

            if !member.phoneNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Phone", systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(member.phoneNumbers, id: \.self) { phone in
                        Text(phone)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }

            if !member.relations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Relations", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(member.relations, id: \.member.id) { relation in
                        HStack {
                            Text(relation.displayLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(relation.member.fullName)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveBackground)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .position(x: position.x, y: position.y + 120)
    }
}

// MARK: - Degree of Separation Control

/// Control for adjusting the maximum degrees of separation to render.
struct DegreeOfSeparationControl: View {
    @Binding var degree: Int
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Degrees of Separation")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Text("\(degree)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { Double(degree) },
                        set: { degree = Int($0) }
                    ),
                    in: 0...5,
                    step: 1
                )
                .frame(width: 120)
                .onChange(of: degree) { _ in
                    onChanged()
                }

                Text("5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(degreeDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveBackground)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }

    private var degreeDescription: String {
        switch degree {
        case 0:
            return "Only me"
        case 1:
            return "Immediate family (spouse, parents, children)"
        case 2:
            return "Extended family (grandparents, siblings, grandchildren)"
        case 3:
            return "Cousins, aunts, uncles"
        case 4:
            return "Second cousins, great-grandparents"
        default:
            return "Distant relatives"
        }
    }
}

// MARK: - Spacing Control

/// Controls for spouse and general spacing used by the layout manager.
struct SpacingControl: View {
    @Binding var spouseSpacing: CGFloat
    @Binding var generalSpacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spacing")
                .font(.headline)
                .foregroundColor(.primary)

            // Spouse spacing slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Spouse Distance: \(Int(spouseSpacing))px")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $spouseSpacing, in: 100...400, step: 20)
                    .frame(width: 200)
            }

            // General spacing slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum Distance: \(Int(generalSpacing))px")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $generalSpacing, in: 100...400, step: 20)
                    .frame(width: 200)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveBackground)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Animation Speed Control

/// Control for animation pacing in milliseconds per contact.
struct AnimationSpeedControl: View {
    @Binding var animationSpeedMs: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Animation Speed")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Delay per contact: \(Int(animationSpeedMs))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $animationSpeedMs, in: 0...2000, step: 50)
                    .frame(width: 200)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveBackground)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Language Control

/// Control to select the language used for relationship labels.
struct LanguageControl: View {
    @Binding var selectedLanguage: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relationship Labels")
                .font(.headline)
                .foregroundColor(.primary)

            Picker("Language", selection: $selectedLanguage) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.rawValue).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveBackground)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Debug Control

/// Debug panel showing incremental layout steps and summaries.
struct DebugControl: View {
    @Binding var debugMode: Bool
    let currentStep: Int
    let totalSteps: Int
    let stepDescription: String
    let changesSummary: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Toggle("", isOn: $debugMode)
                    .labelsHidden()
                    .controlSize(.small)
            }

            if debugMode {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(currentStep)/\(totalSteps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer()

                        if currentStep < totalSteps {
                            HStack(spacing: 3) {
                                Image(systemName: "keyboard")
                                    .font(.caption2)
                                Text("SPACE")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                        } else {
                            Text("Done")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    if !stepDescription.isEmpty {
                        Text(stepDescription)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .padding(.vertical, 2)
                    }

                    if !changesSummary.isEmpty {
                        Divider()

                        Text("Changes:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(changesSummary.prefix(3), id: \.self) { change in
                                    HStack(alignment: .top, spacing: 3) {
                                        Text("•")
                                            .font(.caption2)
                                        Text(change)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                if changesSummary.count > 3 {
                                    Text("+\(changesSummary.count - 3) more")
                                        .font(.system(.caption2).italic())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 60)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(width: 220)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(debugMode ? Color.blue.opacity(0.1) : Color.adaptiveBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            debugMode ? Color.blue.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
}
