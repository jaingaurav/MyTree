import Foundation

enum RelationshipCalculator {
    // Cached name lists loaded from config files
    private static var cachedMaleNames: [String]?
    private static var cachedFemaleNames: [String]?

    // Load gender names from Firebase Remote Config or local configuration files
    private static func loadGenderNames() -> (maleNames: [String], femaleNames: [String]) {
        // Return cached values if available
        if let male = cachedMaleNames, let female = cachedFemaleNames {
            return (maleNames: male, femaleNames: female)
        }

        // Load from Remote Config Manager (Firebase or local fallback)
        let maleNames = RemoteConfigManager.shared.loadStringArray(
            key: "male_names",
            localFileName: "male_names.json"
        )

        let femaleNames = RemoteConfigManager.shared.loadStringArray(
            key: "female_names",
            localFileName: "female_names.json"
        )

        // Cache loaded values
        cachedMaleNames = maleNames
        cachedFemaleNames = femaleNames
        return (maleNames: maleNames, femaleNames: femaleNames)
    }
    // Calculate relative relationship from root to target with family side information
    static func calculateRelationshipInfo(
        from root: FamilyMember,
        to target: FamilyMember,
        members: [FamilyMember]
    ) -> RelationshipInfo {
        if root.id == target.id {
            return RelationshipInfo(kind: .me, familySide: .own, path: [root])
        }

        // Find path from root to target
        // Note: Family side should be precomputed during BFS traversal for performance
        if let path = findPath(from: root, to: target, members: members) {
            // Use unknown as fallback since family side should be precomputed
            let kind = describeRelationshipKind(path: path, familySide: .unknown)
            return RelationshipInfo(kind: kind, familySide: .unknown, path: path)
        }

        return RelationshipInfo(kind: .brother, familySide: .unknown, path: [])
    }

    // Find shortest path between two members
    // Handles both forward and reverse relationships bidirectionally
    private static func findPath(
        from start: FamilyMember,
        to target: FamilyMember,
        members: [FamilyMember]
    ) -> [FamilyMember]? {
        var queue: [(member: FamilyMember, path: [FamilyMember])] = [(start, [start])]
        var visited = Set<String>()

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()

            if current.id == target.id {
                return path
            }

            if visited.contains(current.id) { continue }
            visited.insert(current.id)

            // Forward: Find members that current has relations to
            for relation in current.relations {
                let related = relation.member
                if !visited.contains(related.id) {
                    queue.append((related, path + [related]))
                }
            }

            // Reverse: Find members that have relations pointing to current
            for otherMember in members {
                if visited.contains(otherMember.id) { continue }
                for relation in otherMember.relations where relation.member.id == current.id {
                    queue.append((otherMember, path + [otherMember]))
                    break // Found a reverse relation, move to next member
                }
            }
        }

        return nil
    }

    // Describe relationship based on path
    // Map path to canonical RelationshipKind
    static func describeRelationshipKind(path: [FamilyMember], familySide: FamilySide) -> RelationshipKind {
        guard path.count >= 2 else { return .me }

        let chain = buildRelationChain(from: path)
        let targetGender = path.last?.inferredGender ?? .unknown

        guard !chain.isEmpty else { return .paternalCousinMale }

        switch chain.count {
        case 1:
            return describeOneStepRelationship(chain: chain, targetGender: targetGender)
        case 2:
            return describeTwoStepRelationship(
                chain: chain,
                targetGender: targetGender,
                familySide: familySide,
                path: path
            )
        case 3:
            return describeThreeStepRelationship(chain: chain, targetGender: targetGender, familySide: familySide)
        default:
            return targetGender == .male ? .paternalCousinMale : .paternalCousinFemale
        }
    }

    private static func buildRelationChain(from path: [FamilyMember]) -> [FamilyMember.RelationType] {
        var chain: [FamilyMember.RelationType] = []
        for i in 0..<(path.count - 1) {
            let current = path[i]
            let next = path[i + 1]
            if let relation = current.relations.first(where: { $0.member.id == next.id }) {
                chain.append(relation.relationType)
            }
        }
        return chain
    }

    private static func describeOneStepRelationship(
        chain: [FamilyMember.RelationType],
        targetGender: Gender
    ) -> RelationshipKind {
        switch chain[0] {
        case .spouse:
            return targetGender == .male ? .husband : (targetGender == .female ? .wife : .husband)
        case .parent:
            return targetGender == .male ? .father : (targetGender == .female ? .mother : .father)
        case .child:
            return targetGender == .male ? .son : (targetGender == .female ? .daughter : .son)
        case .sibling:
            return targetGender == .male ? .brother : (targetGender == .female ? .sister : .brother)
        case .other:
            return .paternalCousinMale
        }
    }

    private static func describeTwoStepRelationship(
        chain: [FamilyMember.RelationType],
        targetGender: Gender,
        familySide: FamilySide,
        path: [FamilyMember]
    ) -> RelationshipKind {
        let first = chain[0]
        let second = chain[1]

        // Grandparent: parent → parent
        if first == .parent && second == .parent {
            return describeGrandparent(targetGender: targetGender, familySide: familySide)
        }

        // Grandchild: child → child
        if first == .child && second == .child {
            return targetGender == .male ? .grandson : .granddaughter
        }

        // Uncle/Aunt: parent → sibling
        if first == .parent && second == .sibling {
            return describeUncleAunt(targetGender: targetGender, familySide: familySide)
        }

        // Nephew/Niece: sibling → child
        if first == .sibling && second == .child {
            return targetGender == .male ? .brothersSon : .brothersDaughter
        }

        // Sibling (half): parent → child
        if first == .parent && second == .child {
            return targetGender == .male ? .brother : .sister
        }

        // Parent-in-law: spouse → parent
        if first == .spouse && second == .parent {
            let spouseGender = path.count >= 2 ? path[1].inferredGender : .unknown
            return describeParentInLaw(targetGender: targetGender, spouseGender: spouseGender)
        }

        // Child-in-law: child → spouse
        if first == .child && second == .spouse {
            return targetGender == .male ? .sonInLaw : .daughterInLaw
        }

        return .paternalCousinMale
    }

    private static func describeThreeStepRelationship(
        chain: [FamilyMember.RelationType],
        targetGender: Gender,
        familySide: FamilySide
    ) -> RelationshipKind {
        let first = chain[0]
        let second = chain[1]
        let third = chain[2]

        // Great-grandparent: parent → parent → parent
        if first == .parent && second == .parent && third == .parent {
            return describeGreatGrandparent(targetGender: targetGender, familySide: familySide)
        }

        // Great-grandchild: child → child → child
        if first == .child && second == .child && third == .child {
            return targetGender == .male ? .grandson : .granddaughter
        }

        // Cousin: parent → sibling → child
        if first == .parent && second == .sibling && third == .child {
            return describeCousin(targetGender: targetGender, familySide: familySide)
        }

        return targetGender == .male ? .paternalCousinMale : .paternalCousinFemale
    }

    private static func describeGrandparent(targetGender: Gender, familySide: FamilySide) -> RelationshipKind {
        switch familySide {
        case .paternal:
            return targetGender == .male ? .paternalGrandfather : .paternalGrandmother
        case .maternal:
            return targetGender == .male ? .maternalGrandfather : .maternalGrandmother
        default:
            return targetGender == .male ? .paternalGrandfather : .paternalGrandmother
        }
    }

    private static func describeGreatGrandparent(targetGender: Gender, familySide: FamilySide) -> RelationshipKind {
        switch familySide {
        case .paternal:
            return targetGender == .male ? .paternalGreatGrandfather : .paternalGreatGrandmother
        case .maternal:
            return targetGender == .male ? .maternalGreatGrandfather : .maternalGreatGrandmother
        default:
            return targetGender == .male ? .paternalGreatGrandfather : .paternalGreatGrandmother
        }
    }

    private static func describeUncleAunt(targetGender: Gender, familySide: FamilySide) -> RelationshipKind {
        if targetGender == .male {
            return familySide == .maternal ? .maternalUncle : .paternalUncle
        }
        return familySide == .maternal ? .maternalAunt : .paternalAunt
    }

    private static func describeCousin(targetGender: Gender, familySide: FamilySide) -> RelationshipKind {
        switch familySide {
        case .paternal:
            return targetGender == .male ? .paternalCousinMale : .paternalCousinFemale
        case .maternal:
            return targetGender == .male ? .maternalCousinMale : .maternalCousinFemale
        default:
            return targetGender == .male ? .paternalCousinMale : .paternalCousinFemale
        }
    }

    private static func describeParentInLaw(targetGender: Gender, spouseGender: Gender) -> RelationshipKind {
        if targetGender == .male {
            return spouseGender == .female ? .wifesFather : .husbandsFather
        }
        return spouseGender == .female ? .wifesMother : .husbandsMother
    }

    private static func genderedTerm(male: String, female: String, neutral: String, targetGender: Gender) -> String {
        switch targetGender {
        case .male: return male
        case .female: return female
        default: return neutral
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func interpretRelationshipChain(
        _ chain: [FamilyMember.RelationType],
        targetGender: Gender
    ) -> String {
        guard !chain.isEmpty else { return "Unknown" }

        switch chain.count {
        case 1:
            switch chain[0] {
            case .spouse:
                return genderedTerm(male: "Husband", female: "Wife", neutral: "Spouse", targetGender: targetGender)
            case .parent:
                return genderedTerm(male: "Father", female: "Mother", neutral: "Parent", targetGender: targetGender)
            case .child:
                return genderedTerm(male: "Son", female: "Daughter", neutral: "Child", targetGender: targetGender)
            case .sibling:
                return genderedTerm(male: "Brother", female: "Sister", neutral: "Sibling", targetGender: targetGender)
            case .other:
                return "Relative"
            }

        case 2:
            if chain[0] == .parent && chain[1] == .parent {
                return genderedTerm(
                    male: "Grandfather",
                    female: "Grandmother",
                    neutral: "Grandparent",
                    targetGender: targetGender
                )
            }
            if chain[0] == .child && chain[1] == .child {
                return genderedTerm(
                    male: "Grandson",
                    female: "Granddaughter",
                    neutral: "Grandchild",
                    targetGender: targetGender
                )
            }
            if chain[0] == .parent && chain[1] == .sibling {
                return genderedTerm(male: "Uncle", female: "Aunt", neutral: "Uncle/Aunt", targetGender: targetGender)
            }
            if chain[0] == .sibling && chain[1] == .child {
                return genderedTerm(male: "Nephew", female: "Niece", neutral: "Nibling", targetGender: targetGender)
            }
            if chain[0] == .parent && chain[1] == .child {
                return genderedTerm(male: "Brother", female: "Sister", neutral: "Sibling", targetGender: targetGender)
            }
            if chain[0] == .spouse && chain[1] == .parent {
                return genderedTerm(
                    male: "Father-in-law",
                    female: "Mother-in-law",
                    neutral: "Parent-in-law",
                    targetGender: targetGender
                )
            }
            if chain[0] == .child && chain[1] == .spouse {
                return genderedTerm(
                    male: "Son-in-law",
                    female: "Daughter-in-law",
                    neutral: "Child-in-law",
                    targetGender: targetGender
                )
            }

        case 3:
            if chain[0] == .parent && chain[1] == .parent && chain[2] == .parent {
                return genderedTerm(
                    male: "Great-Grandfather",
                    female: "Great-Grandmother",
                    neutral: "Great-Grandparent",
                    targetGender: targetGender
                )
            }
            if chain[0] == .child && chain[1] == .child && chain[2] == .child {
                return genderedTerm(
                    male: "Great-Grandson",
                    female: "Great-Granddaughter",
                    neutral: "Great-Grandchild",
                    targetGender: targetGender
                )
            }
            if chain[0] == .parent && chain[1] == .sibling && chain[2] == .child {
                return "Cousin"
            }
            if chain[0] == .parent && chain[1] == .parent && chain[2] == .sibling {
                return genderedTerm(
                    male: "Great-Uncle",
                    female: "Great-Aunt",
                    neutral: "Great-Uncle/Aunt",
                    targetGender: targetGender
                )
            }

        default:
            break
        }

        return "Relative"
    }

    // Get localized relationship label using the localizer factory
    static func getLocalizedRelationship(info: RelationshipInfo, language: Language) -> String {
        let localizer = RelationshipLocalizerFactory.localizer(for: language)
        return localizer.localize(info: info)
    }

    // Infer gender from relationships across all members
    static func inferGenders(members: [FamilyMember]) -> [FamilyMember] {
        var genderMap: [String: Gender] = [:]

        // First pass: infer from explicit gender-specific relationships
        inferGenderFromRelationshipLabels(members: members, genderMap: &genderMap)

        // Second pass: infer from name patterns (less reliable, only if no other info)
        inferGenderFromNames(members: members, genderMap: &genderMap)

        // Update members with inferred gender
        return members.map { member in
            var updated = member
            updated.inferredGender = genderMap[member.id] ?? .unknown
            return updated
        }
    }

    private static func inferGenderFromRelationshipLabels(
        members: [FamilyMember],
        genderMap: inout [String: Gender]
    ) {
        let femaleLabels = ["mother", "wife", "daughter", "sister"]
        let maleLabels = ["father", "husband", "son", "brother"]

        for member in members {
            for relation in member.relations {
                let label = relation.label.lowercased()

                if femaleLabels.contains(where: label.contains) {
                    genderMap[relation.member.id] = .female
                } else if maleLabels.contains(where: label.contains) {
                    genderMap[relation.member.id] = .male
                }
            }
        }
    }

    private static func inferGenderFromNames(
        members: [FamilyMember],
        genderMap: inout [String: Gender]
    ) {
        for member in members where genderMap[member.id] == nil {
            genderMap[member.id] = inferGenderFromName(member.givenName)
        }
    }

    // Infer gender from first name
    // cspell:disable
    private static func inferGenderFromName(_ name: String) -> Gender {
        let lowercased = name.lowercased()

        // Load names from configuration file
        let names = loadGenderNames()
        let maleNames = names.maleNames
        let femaleNames = names.femaleNames
    // cspell:enable

        if maleNames.contains(lowercased) {
            return .male
        }

        if femaleNames.contains(lowercased) {
            return .female
        }

        // Check common endings
        if lowercased.hasSuffix("a") || lowercased.hasSuffix("i") {
            return .female
        }

        return .unknown
    }
}
