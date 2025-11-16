import SwiftUI
import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Helper utilities for displaying contact images and monograms.
///
/// Provides functions to generate attractive monogram views when contact photos are unavailable.
/// Uses a deterministic color palette similar to the macOS/iOS Contacts app.
///
/// **Features:**
/// - Deterministic color assignment (same name always gets same color)
/// - 12-color curated palette matching Contacts app aesthetics
/// - Automatic initial generation from names
/// - Customizable size and highlight states
enum ContactImageHelper {
    /// Generates a deterministic color for a contact based on their name.
    ///
    /// Uses a hash of the name to select from a curated 12-color palette,
    /// ensuring the same name always produces the same color.
    ///
    /// - Parameter name: Full name of the contact
    /// - Returns: Color from the palette
    static func colorForContact(_ name: String) -> Color {
        // Use the name to generate a consistent color
        // Contacts app uses a specific palette of colors
        var hash = 0
        for char in name.lowercased() {
            hash = Int(char.unicodeScalars.first?.value ?? 0) &+ (hash << 5) &- hash
        }

        // Use a curated palette similar to Contacts app (12 colors)
        // These are based on common contact avatar colors
        let colors: [(hue: Double, saturation: Double, brightness: Double)] = [
            (0.0, 0.75, 0.80),   // Red
            (0.05, 0.80, 0.85),  // Orange
            (0.13, 0.75, 0.80),  // Yellow
            (0.25, 0.70, 0.75),  // Green
            (0.50, 0.75, 0.80),  // Cyan
            (0.55, 0.70, 0.75),  // Blue
            (0.65, 0.75, 0.80),  // Indigo
            (0.75, 0.70, 0.75),  // Purple
            (0.85, 0.75, 0.80),  // Magenta
            (0.92, 0.75, 0.80),  // Pink
            (0.02, 0.60, 0.70),  // Brown
            (0.60, 0.65, 0.70)  // Teal
        ]

        let index = abs(hash) % colors.count
        let color = colors[index]

        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// Generates initials from a contact's name.
    ///
    /// Creates up to 2-letter initials from the given and family names.
    /// Falls back to "?" if both names are empty.
    ///
    /// - Parameters:
    ///   - givenName: First name
    ///   - familyName: Last name
    /// - Returns: Uppercased initials (e.g., "JS" for "John Smith")
    static func initials(for givenName: String, familyName: String) -> String {
        let givenInitial = givenName.isEmpty ? "" : String(givenName.prefix(1)).uppercased()
        let familyInitial = familyName.isEmpty ? "" : String(familyName.prefix(1)).uppercased()

        // If we have both, use both initials
        if !givenInitial.isEmpty && !familyInitial.isEmpty {
            return givenInitial + familyInitial
        }
        // If only one, use that
        else if !givenInitial.isEmpty {
            return givenInitial
        } else if !familyInitial.isEmpty {
            return familyInitial
        }
        // Fallback to question mark
        else {
            return "?"
        }
    }

    /// Creates a system-style circular monogram view.
    ///
    /// Generates a circular view with:
    /// - Deterministic background color based on the name
    /// - White initials text
    /// - Rounded font design
    ///
    /// - Parameters:
    ///   - givenName: Contact's first name
    ///   - familyName: Contact's last name
    ///   - size: Diameter of the circle in points
    ///   - isHighlighted: Whether to apply highlight styling (currently unused)
    /// - Returns: SwiftUI view displaying the monogram
    static func monogramView(
        givenName: String,
        familyName: String,
        size: CGFloat,
        isHighlighted: Bool = false
    ) -> some View {
        let fullName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        let initials = Self.initials(for: givenName, familyName: familyName)
        let color = Self.colorForContact(fullName)

        return ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
