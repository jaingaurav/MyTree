import Foundation

// MARK: - Relationship Kind

/// Canonical set of uniquely describable relationship kinds used for localization.
///
/// This enum represents all possible family relationships that can be calculated and displayed.
/// Each case maps to culturally appropriate terms in multiple languages.
///
/// **Organization:**
/// - Self, spouse, immediate family (parents, children, siblings)
/// - Extended family by generation (grandparents, grandchildren)
/// - Side-specific relatives (paternal/maternal uncles, aunts, cousins)
/// - In-laws (direct and through siblings/spouse)
///
/// **Localization:**
/// Each case is localized using language-specific `RelationshipLocalizer` implementations.
/// Some languages (like Hindi) have distinct terms for paternal vs. maternal relatives.
enum RelationshipKind: Hashable, Sendable {
    // Self
    case me

    // Spouse
    case husband
    case wife

    // Parents
    case father
    case mother

    // Children
    case son
    case daughter

    // Siblings
    case brother
    case sister

    // Grandparents (side-specific)
    case paternalGrandfather
    case paternalGrandmother
    case maternalGrandfather
    case maternalGrandmother

    // Grandchildren
    case grandson
    case granddaughter

    // Aunts/Uncles (side-specific)
    case paternalUncle   // Chacha
    case maternalUncle   // Mama
    case paternalAunt    // Bua
    case maternalAunt    // Mausi

    // Niece/Nephew (through brother or sister)
    case brothersSon     // Bhatija
    case brothersDaughter// Bhatiji
    case sistersSon      // Bhanja
    case sistersDaughter // Bhanji

    // In-laws (direct) - spouse's parents
    case wifesFather      // 岳父 (Yuèfù) in Chinese
    case wifesMother      // 岳母 (Yuèmǔ) in Chinese
    case husbandsFather   // 公公 (Gōnggong) in Chinese
    case husbandsMother   // 婆婆 (Pópo) in Chinese
    case sonInLaw
    case daughterInLaw

    // In-laws (siblings-in-law) distinguished by route
    case wifesBrother    // Sala
    case husbandsBrother // Devar/Jeth (generic mapping will handle language specifics)
    case sistersHusband  // Jija
    case wifesSister     // Saali
    case husbandsSister  // Nanad
    case brothersWife    // Bhabhi

    // Cousins (side + gender)
    case paternalCousinMale
    case paternalCousinFemale
    case maternalCousinMale
    case maternalCousinFemale

    // Great-grandparents (side-specific)
    case paternalGreatGrandfather
    case paternalGreatGrandmother
    case maternalGreatGrandfather
    case maternalGreatGrandmother

    // swiftlint:disable cyclomatic_complexity
    /// Convert string representation to RelationshipKind
    static func fromString(_ string: String) -> RelationshipKind? {
        switch string {
        case "me": return .me
        case "husband": return .husband
        case "wife": return .wife
        case "father": return .father
        case "mother": return .mother
        case "son": return .son
        case "daughter": return .daughter
        case "brother": return .brother
        case "sister": return .sister
        case "paternalGrandfather": return .paternalGrandfather
        case "paternalGrandmother": return .paternalGrandmother
        case "maternalGrandfather": return .maternalGrandfather
        case "maternalGrandmother": return .maternalGrandmother
        case "grandson": return .grandson
        case "granddaughter": return .granddaughter
        case "paternalUncle": return .paternalUncle
        case "maternalUncle": return .maternalUncle
        case "paternalAunt": return .paternalAunt
        case "maternalAunt": return .maternalAunt
        case "brothersSon": return .brothersSon
        case "brothersDaughter": return .brothersDaughter
        case "sistersSon": return .sistersSon
        case "sistersDaughter": return .sistersDaughter
        case "wifesFather": return .wifesFather
        case "wifesMother": return .wifesMother
        case "husbandsFather": return .husbandsFather
        case "husbandsMother": return .husbandsMother
        case "sonInLaw": return .sonInLaw
        case "daughterInLaw": return .daughterInLaw
        case "wifesBrother": return .wifesBrother
        case "husbandsBrother": return .husbandsBrother
        case "sistersHusband": return .sistersHusband
        case "wifesSister": return .wifesSister
        case "husbandsSister": return .husbandsSister
        case "brothersWife": return .brothersWife
        case "paternalCousinMale": return .paternalCousinMale
        case "paternalCousinFemale": return .paternalCousinFemale
        case "maternalCousinMale": return .maternalCousinMale
        case "maternalCousinFemale": return .maternalCousinFemale
        case "paternalGreatGrandfather": return .paternalGreatGrandfather
        case "paternalGreatGrandmother": return .paternalGreatGrandmother
        case "maternalGreatGrandfather": return .maternalGreatGrandfather
        case "maternalGreatGrandmother": return .maternalGreatGrandmother
        default: return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

// MARK: - Relationship Info

/// Complete relationship information from the root person to a target family member.
///
/// This struct encapsulates all data needed to describe and display a relationship,
/// including the specific relationship type, which side of the family, and the
/// path through the family tree.
///
/// **Components:**
/// - `kind`: The canonical relationship type (e.g., `.father`, `.maternalUncle`)
/// - `familySide`: Whether this person is on the paternal, maternal, or own side
/// - `path`: Ordered list of family members from root to target
///
/// **Usage Example:**
/// ```swift
/// let info = RelationshipInfo(
///     kind: .maternalUncle,
///     familySide: .maternal,
///     path: [me, mother, mothersBrother]
/// )
/// // Can be localized: "Mama" (Hindi) or "Uncle" (English)
/// ```
struct RelationshipInfo {
    /// The canonical relationship type
    let kind: RelationshipKind

    /// Which side of the family this person belongs to
    let familySide: FamilySide

    /// Ordered path from root to this member through the family tree
    let path: [FamilyMember]
}
