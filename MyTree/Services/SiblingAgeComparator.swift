import Foundation

/// Protocol for comparing sibling ages to enable testing
protocol SiblingAgeComparatorProtocol {
    /// Determines if a sibling is older than the root
    /// - Parameters:
    ///   - sibling: The sibling to check
    ///   - root: The root person
    /// - Returns: true if sibling is older, false if younger
    func isSiblingOlder(_ sibling: FamilyMember, relativeTo root: FamilyMember) -> Bool
}

/// Service for determining sibling age relationships
/// This is extracted for testability and can be mocked in unit tests
struct SiblingAgeComparator: SiblingAgeComparatorProtocol {
    /// Determines if a sibling is older than the root
    /// Uses multiple heuristics in order of preference:
    /// 1. Birthdate comparison (MOST RELIABLE - uses actual birth dates from contacts)
    /// 2. Explicit age indicators in relation labels ("older", "younger", "elder", "little", etc.)
    /// 3. Birth order indicators in labels ("big", "small")
    /// 4. RelationshipKind-based inference (if available via RelationshipInfo)
    /// 5. Alphabetical name comparison as fallback (imperfect but deterministic)
    ///
    /// - Parameters:
    ///   - sibling: The sibling to check
    ///   - root: The root person
    /// - Returns: true if sibling is older, false if younger
    func isSiblingOlder(_ sibling: FamilyMember, relativeTo root: FamilyMember) -> Bool {
        // Strategy 1: Use birthdate comparison (MOST RELIABLE)
        if let siblingBirthDate = sibling.birthDate, let rootBirthDate = root.birthDate {
            let isOlder = siblingBirthDate < rootBirthDate
            AppLog.tree.debug("""
            Age detection (birthdate):
              Sibling birthdate: \(siblingBirthDate)
              Root birthdate: \(rootBirthDate)
              Sibling is older: \(isOlder)
            """)
            return isOlder
        } else if sibling.birthDate != nil && root.birthDate == nil {
            // If sibling has birthdate but root doesn't, we can't determine
            AppLog.tree.debug("Age detection: sibling has birthdate but root does not; unable to compare")
        } else if sibling.birthDate == nil && root.birthDate != nil {
            // If root has birthdate but sibling doesn't, we can't determine
            AppLog.tree.debug("Age detection: root has birthdate but sibling does not; unable to compare")
        }

        // Strategy 2: Check if root has a relation to this sibling that indicates age
        if let relation = root.relations.first(where: {
            $0.member.id == sibling.id && $0.relationType == .sibling
        }) {
            AppLog.tree.debug("Age detection: evaluating root relation label '\(relation.label)'")
            if let ageDetermination = determineAgeFromLabel(relation.label, perspective: .fromRoot) {
                AppLog.tree.debug("Age detection result from root relation: \(ageDetermination ? "older" : "younger")")
                return ageDetermination
            }
        }

        // Strategy 2: Check if sibling has a relation to root that indicates age
        if let relation = sibling.relations.first(where: {
            $0.member.id == root.id && $0.relationType == .sibling
        }) {
            AppLog.tree.debug("Age detection: evaluating sibling relation '\(relation.label)'")
            if let ageDetermination = determineAgeFromLabel(relation.label, perspective: .fromSibling) {
                let result = ageDetermination ? "older" : "younger"
                AppLog.tree.debug("Age detection sibling relation result: \(result)")
                return ageDetermination
            }
        }

        // Strategy 3: Try to infer from relationship labels more broadly
        // Check for common patterns like "Big Brother", "Little Sister", etc.
        if let rootRelation = root.relations.first(where: {
            $0.member.id == sibling.id
        }) {
            AppLog.tree.debug("Age detection: evaluating root relation '\(rootRelation.label)'")
            if let ageDetermination = inferAgeFromBroaderLabel(rootRelation.label, perspective: .fromRoot) {
                let result = ageDetermination ? "older" : "younger"
                AppLog.tree.debug("Age detection broader root relation result: \(result)")
                return ageDetermination
            }
        }

        if let siblingRelation = sibling.relations.first(where: {
            $0.member.id == root.id
        }) {
            AppLog.tree.debug("Age detection: evaluating sibling relation '\(siblingRelation.label)'")
            if let ageDetermination = inferAgeFromBroaderLabel(siblingRelation.label, perspective: .fromSibling) {
                let result = ageDetermination ? "older" : "younger"
                AppLog.tree.debug("Age detection broader sibling relation result: \(result)")
                return ageDetermination
            }
        }

        // Strategy 4: Fallback to alphabetical order of given names
        // This is imperfect but provides deterministic ordering
        // Convention: if sibling's name comes before root's name alphabetically, treat as "older"
        let alphabeticalResult = sibling.givenName < root.givenName
        let fallbackResult = alphabeticalResult ? "older" : "younger"
        AppLog.tree.debug("Age detection fallback result: \(fallbackResult)")
        return alphabeticalResult
    }

    // MARK: - Private Helpers

    private enum Perspective {
        case fromRoot
        case fromSibling
    }

    /// Determines age from explicit age indicators in the label
    private func determineAgeFromLabel(_ label: String, perspective: Perspective) -> Bool? {
        let lowercased = label.lowercased()

        // Explicit age indicators
        if lowercased.contains("older") || lowercased.contains("elder") {
            // If root says "older brother/sister", the sibling IS older
            // If sibling says root is "older", then sibling is younger
            return perspective == .fromRoot ? true : false
        }

        if lowercased.contains("younger") || lowercased.contains("little") {
            // If root says "younger brother/sister", the sibling IS younger
            // If sibling says root is "younger", then sibling is older
            return perspective == .fromRoot ? false : true
        }

        // Birth order indicators
        if lowercased.contains("big") || lowercased.contains("bigger") || lowercased.contains("large") {
            // "Big brother/sister" typically means older
            return perspective == .fromRoot ? true : false
        }

        if lowercased.contains("small") || lowercased.contains("smaller") {
            // "Small brother/sister" typically means younger
            return perspective == .fromRoot ? false : true
        }

        return nil
    }

    /// Infers age from broader relationship labels that might contain age information
    private func inferAgeFromBroaderLabel(_ label: String, perspective: Perspective) -> Bool? {
        let lowercased = label.lowercased()

        // Check for ordinal indicators (first, second, third, etc.)
        // In many cultures, the firstborn is referred to differently
        if lowercased.contains("first") || lowercased.contains("1st") || lowercased.contains("eldest") {
            return perspective == .fromRoot ? true : false
        }

        // Check for numeric age indicators
        let numberPatterns = ["second", "third", "fourth", "fifth", "2nd", "3rd", "4th", "5th"]
        for pattern in numberPatterns where lowercased.contains(pattern) {
            // If we see "second", "third", etc., it's ambiguous - skip this heuristic
            // We can't reliably determine if it's referring to birth order without more context
            break
        }

        return nil
    }
}
