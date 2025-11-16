import Foundation
import Contacts
import SwiftUI

// MARK: - Gender

/// Gender classification for family members.
enum Gender {
    case male
    case female
    case unknown
}

// MARK: - Language

/// Supported languages for relationship localization.
///
/// The app supports multiple languages for displaying family relationship labels.
/// Each language provides culturally appropriate terms for different relationship types.
/// Languages are loaded from `Resources/languages.json` configuration file.
enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case hindi = "हिन्दी (Hindi)"
    case gujarati = "ગુજરાતી (Gujarati)"
    case urdu = "اردو (Urdu)"
    case chinese = "中文 (Chinese)"
    case spanish = "Español (Spanish)"
    case french = "Français (French)"

    /// ISO 639-1 language code used for config file lookup
    var configCode: String {
        switch self {
        case .english: return "en"
        case .hindi: return "hi"
        case .gujarati: return "gu"
        case .urdu: return "ur"
        case .chinese: return "zh"
        case .spanish: return "es"
        case .french: return "fr"
        }
    }

    var id: String { rawValue }

    /// Load supported languages from configuration file
    /// Falls back to hardcoded list if config file is missing
    static func loadFromConfig() -> [Language] {
        guard let url = Bundle.main.url(forResource: "languages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let languages = try? JSONDecoder().decode([LanguageConfig].self, from: data) else {
            // Fallback to hardcoded enum cases
            return Language.allCases
        }

        // Map config to Language enum cases
        return languages.compactMap { config in
            Language.allCases.first { $0.configCode == config.code }
        }
    }

    /// Configuration structure for languages.json
    private struct LanguageConfig: Codable {
        let code: String
        let displayName: String
        let configFile: String
    }
}

// MARK: - Family Side

/// Logical side of the family tree for layout and relationship determination.
///
/// Used to distinguish between paternal (father's) and maternal (mother's) family branches,
/// which is particularly important for languages with side-specific relationship terms.
enum FamilySide {
    case paternal
    case maternal

    // TODO: Remove?
    /// Root person or their spouse
    case own

    /// Family side could not be determined
    case unknown
}

// MARK: - Family Member

/// Core model representing a family member from the Contacts database.
///
/// This struct serves as the primary data model for all family members displayed in the tree.
/// It contains contact information, relationships to other members, and metadata used for
/// layout calculations and relationship inference.
///
/// **Key Responsibilities:**
/// - Store contact information (name, photo, contact details)
/// - Maintain relationships to other family members
/// - Support gender inference for relationship calculations
/// - Provide identity and equality for tree algorithms
///
/// **Usage Example:**
/// ```swift
/// let spouse = FamilyMember(id: "contact-456", givenName: "Jane", familyName: "Smith", ...)
/// let son = FamilyMember(id: "contact-789", givenName: "Tom", familyName: "Smith", ...)
/// let member = FamilyMember(
///     id: "contact-123",
///     givenName: "John",
///     familyName: "Smith",
///     imageData: photoData,
///     emailAddresses: ["john@example.com"],
///     phoneNumbers: ["+1234567890"],
///     relations: [
///         Relation(label: "Spouse", member: spouse),
///         Relation(label: "Son", member: son)
///     ],
///     birthDate: someDate
/// )
/// ```
struct FamilyMember: Identifiable, Hashable {
    /// Unique identifier from Contacts database
    let id: String

    /// First/given name
    let givenName: String

    /// Last/family name
    let familyName: String

    /// Profile photo data (JPEG/PNG), if available
    let imageData: Data?

    /// Email addresses associated with this contact
    let emailAddresses: [String]

    /// Phone numbers associated with this contact
    let phoneNumbers: [String]

    /// List of relationships to other family members
    let relations: [Relation]

    /// Gender inferred from relationship labels (e.g., "brother" → male)
    var inferredGender: Gender = .unknown

    /// Birth date for age-based sibling ordering
    let birthDate: Date?

    /// Marriage/anniversary date for spouse ordering
    let marriageDate: Date?

    /// Whether this is a virtual member (created for relations without contact cards)
    var isVirtual: Bool = false

    /// Full name combining given and family names.
    var fullName: String {
        "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Relation

    /// A labeled relationship from this member to another family member.
    ///
    /// Relations are stored as they appear in the Contacts app (e.g., "Mother", "Brother", "Spouse").
    /// The label is analyzed to determine the relationship type and display format.
    struct Relation: Hashable {
        /// Raw label from Contacts (e.g., "_$!<Mother>!$_", "Spouse", "Brother")
        let label: String

        /// The related family member (may be a real contact or a virtual member)
        let member: FamilyMember

        /// Keywords used to identify relationship types from labels.
        private enum RelationKeywords {
            static let spouse = ["spouse", "partner", "wife", "husband"]
            static let child = ["child", "son", "daughter"]
            static let parent = ["parent", "mother", "father"]
            static let sibling = ["sibling", "brother", "sister"]
        }

        /// Checks if any keyword appears in the given text.
        private func containsAny(_ keywords: [String], in text: String) -> Bool {
            keywords.contains { keyword in
                text.contains(keyword)
            }
        }

        /// Categorized relationship type parsed from the label.
        ///
        /// Analyzes the label string to determine the high-level relationship category.
        /// Used for tree traversal and layout algorithms.
        var relationType: RelationType {
            let lowercased = label.lowercased()
            if containsAny(RelationKeywords.spouse, in: lowercased) {
                return .spouse
            } else if containsAny(RelationKeywords.child, in: lowercased) {
                return .child
            } else if containsAny(RelationKeywords.parent, in: lowercased) {
                return .parent
            } else if containsAny(RelationKeywords.sibling, in: lowercased) {
                return .sibling
            }
            return .other
        }

        /// Human-readable display label cleaned from Contacts format.
        ///
        /// Converts raw Contacts labels (which may include special formatting) into
        /// clean, capitalized relationship names suitable for display.
        var displayLabel: String {
            let lowercased = label.lowercased()
            if lowercased.contains("wife") { return "Wife" }
            if lowercased.contains("husband") { return "Husband" }
            if lowercased.contains("partner") { return "Partner" }
            if lowercased.contains("spouse") { return "Spouse" }
            if lowercased.contains("mother") { return "Mother" }
            if lowercased.contains("father") { return "Father" }
            if lowercased.contains("daughter") { return "Daughter" }
            if lowercased.contains("son") { return "Son" }
            if lowercased.contains("sister") { return "Sister" }
            if lowercased.contains("brother") { return "Brother" }
            if lowercased.contains("parent") { return "Parent" }
            if lowercased.contains("child") { return "Child" }
            return label
        }
    }

    // MARK: - Relation Type

    /// High-level categories of family relationships.
    ///
    /// Used for tree traversal, layout algorithms, and determining visual connections.
    /// These categories abstract away gender-specific labels into functional types.
    enum RelationType {
        /// Parent relationship (mother, father)
        case parent

        /// Child relationship (son, daughter)
        case child

        /// Spouse/partner relationship
        case spouse

        /// Sibling relationship (brother, sister)
        case sibling

        /// Other or unrecognized relationships
        case other
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FamilyMember, rhs: FamilyMember) -> Bool {
        lhs.id == rhs.id
    }
}
