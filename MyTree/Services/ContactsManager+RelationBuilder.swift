import Foundation
import Contacts

/// Extension for ContactsManager containing relation-building logic.
///
/// This extension handles the process of:
/// - Building name-to-ID lookup maps
/// - Creating virtual members for missing relations
/// - Rebuilding members with resolved relations
extension ContactsManager {
    /// Builds a map from normalized names to member IDs for quick lookup.
    func buildNameToMemberIdMap(from members: [String: FamilyMember]) -> [String: String] {
        var nameToMemberId: [String: String] = [:]
        for member in members.values {
            let normalizedName = member.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            nameToMemberId[normalizedName] = member.id
            // Also index by first name only
            let firstName = member.givenName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !firstName.isEmpty {
                nameToMemberId[firstName] = member.id
            }
        }
        return nameToMemberId
    }

    /// Creates virtual members for relations that don't have corresponding contact cards.
    func createVirtualMembersForMissingRelations(
        relationInfos: [RelationInfo],
        members: inout [String: FamilyMember],
        nameToMemberId: inout [String: String]
    ) {
        var virtualMemberCount = 0
        for relationInfo in relationInfos where findMemberByFuzzyName(
            relationName: relationInfo.relationName,
            members: members,
            nameToMemberId: nameToMemberId
        ) == nil {
            // No match found - create virtual member
            let nameParts = relationInfo.relationName.components(separatedBy: " ")
            let givenName = nameParts.first ?? relationInfo.relationName
            let familyName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""

            let virtualId = "virtual-\(relationInfo.relationName.replacingOccurrences(of: " ", with: "-"))"

            // Only create if not already created
            if members[virtualId] == nil {
                let virtualMember = FamilyMember(
                    id: virtualId,
                    givenName: givenName,
                    familyName: familyName,
                    imageData: nil,
                    emailAddresses: [],
                    phoneNumbers: [],
                    relations: [],
                    birthDate: nil,
                    marriageDate: nil,
                    isVirtual: true
                )
                members[virtualId] = virtualMember

                let normalizedName = relationInfo.relationName.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                nameToMemberId[normalizedName] = virtualId
                virtualMemberCount += 1
                log.debug("Created virtual member: \(relationInfo.relationName)")
            }
        }
        log.debug("Created \(virtualMemberCount) virtual members")
    }

    /// Rebuilds all members with relations pointing to actual FamilyMember objects.
    func rebuildMembersWithRelations(
        members: [String: FamilyMember],
        relationInfos: [RelationInfo],
        nameToMemberId: inout [String: String]
    ) -> [String: FamilyMember] {
        var virtualMembers: [String: FamilyMember] = [:]
        var updatedMembers: [String: FamilyMember] = [:]

        log.debug("🔨 [rebuildMembersWithRelations] Starting")
        log.debug("   Total members: \(members.count)")
        log.debug("   Total relationInfos: \(relationInfos.count)")

        for (memberId, member) in members {
            let memberRelations = relationInfos.filter { $0.ownerContactId == memberId }

            let relations = buildRelationsForMember(
                memberRelations: memberRelations,
                members: members,
                nameToMemberId: &nameToMemberId,
                virtualMembers: &virtualMembers
            )

            let updatedMember = FamilyMember(
                id: member.id,
                givenName: member.givenName,
                familyName: member.familyName,
                imageData: member.imageData,
                emailAddresses: member.emailAddresses,
                phoneNumbers: member.phoneNumbers,
                relations: relations,
                birthDate: member.birthDate,
                marriageDate: member.marriageDate,
                isVirtual: member.isVirtual
            )
            updatedMembers[memberId] = updatedMember
        }

        // Merge virtual members into the main member list
        for (virtualId, virtualMember) in virtualMembers {
            updatedMembers[virtualId] = virtualMember
        }

        return updatedMembers
    }

    /// Finds a member by fuzzy name matching.
    /// Tries multiple strategies:
    /// 1. Exact normalized match
    /// 2. Check if relation name is contained in any member's full name
    /// 3. Match by first + last name components
    func findMemberByFuzzyName(
        relationName: String,
        members: [String: FamilyMember],
        nameToMemberId: [String: String]
    ) -> String? {
        let normalizedRelationName = relationName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strategy 1: Exact match
        if let memberId = nameToMemberId[normalizedRelationName] {
            return memberId
        }

        // Strategy 2: Check if relation name is a subset of any member's full name
        // e.g., "John Doe" should match "John Michael Doe"
        let relationComponents = normalizedRelationName.components(separatedBy: " ").filter { !$0.isEmpty }

        for (memberId, member) in members {
            let memberFullName = member.fullName.lowercased()
            let memberComponents = memberFullName.components(separatedBy: " ").filter { !$0.isEmpty }

            // Check if all relation name components are present in member name
            let allComponentsMatch = relationComponents.allSatisfy { relationComp in
                memberComponents.contains(relationComp)
            }

            if allComponentsMatch && relationComponents.count >= 2 {
                // Require at least first + last name to match (not just first name)
                log.debug("Fuzzy matched '\(relationName)' to '\(member.fullName)'")
                return memberId
            }
        }

        return nil
    }

    /// Builds relations for a single member.
    func buildRelationsForMember(
        memberRelations: [RelationInfo],
        members: [String: FamilyMember],
        nameToMemberId: inout [String: String],
        virtualMembers: inout [String: FamilyMember]
    ) -> [FamilyMember.Relation] {
        var relations: [FamilyMember.Relation] = []

        for relationInfo in memberRelations {
            // Try fuzzy matching first
            if let relatedMemberId = findMemberByFuzzyName(
                relationName: relationInfo.relationName,
                members: members,
                nameToMemberId: nameToMemberId
            ),
               let relatedMember = members[relatedMemberId] {
                let relation = FamilyMember.Relation(
                    label: relationInfo.label,
                    member: relatedMember
                )
                relations.append(relation)
            } else {
                let relation = createVirtualRelation(
                    relationInfo: relationInfo,
                    nameToMemberId: &nameToMemberId,
                    virtualMembers: &virtualMembers
                )
                relations.append(relation)
            }
        }

        return relations
    }

    /// Creates a virtual relation for a missing contact.
    func createVirtualRelation(
        relationInfo: RelationInfo,
        nameToMemberId: inout [String: String],
        virtualMembers: inout [String: FamilyMember]
    ) -> FamilyMember.Relation {
        let msg = "Creating virtual contact for relation: \(relationInfo.relationName)"
        log.debug("\(msg) (label: \(relationInfo.label))")

        // Parse name into given and family names
        let nameParts = relationInfo.relationName.components(separatedBy: " ")
        let givenName = nameParts.first ?? relationInfo.relationName
        let familyName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""

        // Create virtual member with a unique ID
        let virtualId = "virtual-\(UUID().uuidString)"
        let virtualMember = FamilyMember(
            id: virtualId,
            givenName: givenName,
            familyName: familyName,
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: [],  // Virtual members start with no relations
            birthDate: nil,
            marriageDate: nil,
            isVirtual: true
        )

        // Store the virtual member
        virtualMembers[virtualId] = virtualMember

        // Add to lookup so future relations can find it
        let normalizedName = relationInfo.relationName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        nameToMemberId[normalizedName] = virtualId

        // Create the relation
        return FamilyMember.Relation(
            label: relationInfo.label,
            member: virtualMember
        )
    }
}
