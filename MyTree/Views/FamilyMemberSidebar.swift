import SwiftUI

struct FamilyMemberSidebar: View {
    let allMembers: [FamilyMember]
    let filteredMembers: [FamilyMember]
    let rootMember: FamilyMember
    let treeData: FamilyTreeData
    let renderingPriorities: [String: Double]
    @Binding var visibleMemberIds: Set<String>
    let language: Language

    @State private var sortedMembers: [SortedMember] = []

    struct SortedMember: Identifiable {
        let id: String
        let member: FamilyMember
        let degree: Int
        let isVisible: Bool
        let relationshipLabel: String
        let sortDate: Date?  // Birthday or marriage date for sorting
        let age: Int?  // Age calculated from birth date
    }

    /// Calculates age from birth date
    private func calculateAge(from birthDate: Date?) -> Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Family Members")
                .font(.headline)
                .padding()

            Divider()

            // Column headers
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .frame(width: 20)
                    .foregroundColor(.clear)

                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Relation")
                    .frame(width: 100, alignment: .leading)

                Text("Age")
                    .frame(width: 50, alignment: .center)

                Text("Degree")
                    .frame(width: 50, alignment: .center)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            Divider()

            // Member list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedMembers) { sortedMember in
                        FamilyMemberRow(sortedMember: sortedMember) {
                            toggleMemberVisibility(sortedMember.id)
                        }

                        Divider()
                    }
                }
            }
        }
        .frame(width: 480)
        .background(Color.controlBackground)
        .onAppear {
            updateSortedMembers()
        }
        .onChange(of: allMembers) { _ in
            updateSortedMembers()
        }
        .onChange(of: filteredMembers) { _ in
            updateSortedMembers()
        }
        .onChange(of: visibleMemberIds) { _ in
            updateSortedMembers()
        }
    }

    private func updateSortedMembers() {
        sortedMembers = allMembers.map { member in
            let degree = treeData.degreeOfSeparation(for: member.id)
            let isVisible = visibleMemberIds.contains(member.id)
            let defaultInfo = RelationshipInfo(kind: .me, familySide: .unknown, path: [])
            let relationshipInfo = treeData.relationshipInfo(for: member.id) ?? defaultInfo
            let relationshipLabel = RelationshipCalculator.getLocalizedRelationship(
                info: relationshipInfo,
                language: language
            )

            // Determine sort date: use marriage date for spouses, birthday for others
            let hasSpouse = member.relations.contains { $0.relationType == .spouse }
            let sortDate = hasSpouse ? member.marriageDate : member.birthDate
            let age = calculateAge(from: member.birthDate)

            return SortedMember(
                id: member.id,
                member: member,
                degree: degree == Int.max ? 999 : degree,
                isVisible: isVisible,
                relationshipLabel: relationshipLabel,
                sortDate: sortDate,
                age: age
            )
        }
        .sorted { first, second in
            // First sort by degree of separation (ascending)
            if first.degree != second.degree {
                return first.degree < second.degree
            }
            // Then by date (ascending - older dates first)
            // Handle nil dates: put them at the end
            switch (first.sortDate, second.sortDate) {
            case let (date1?, date2?):
                if date1 != date2 {
                    return date1 < date2
                }
            case (nil, _?):
                return false  // Put nil dates after non-nil
            case (_?, nil):
                return true   // Put non-nil dates before nil
            case (nil, nil):
                break  // Both nil, continue to name sorting
            }
            // Finally by name
            return first.member.fullName < second.member.fullName
        }
    }

    private func toggleMemberVisibility(_ memberId: String) {
        if visibleMemberIds.contains(memberId) {
            visibleMemberIds.remove(memberId)
        } else {
            visibleMemberIds.insert(memberId)
        }
    }
}

struct FamilyMemberRow: View {
    let sortedMember: FamilyMemberSidebar.SortedMember
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: sortedMember.isVisible ? "checkmark.square.fill" : "square")
                    .foregroundColor(sortedMember.isVisible ? .blue : .secondary)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            // Member name with avatar
            HStack(spacing: 8) {
                if let imageData = sortedMember.member.imageData,
                   let image = Image(platformImageData: imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } else {
                    let initials = ContactImageHelper.initials(
                        for: sortedMember.member.givenName,
                        familyName: sortedMember.member.familyName
                    )
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)

                        Text(initials)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                Text(sortedMember.member.fullName)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(sortedMember.isVisible ? 1.0 : 0.5)

            // Relationship
            Text(sortedMember.relationshipLabel)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)

            // Age
            if let age = sortedMember.age {
                Text("\(age)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .center)
            } else {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 50, alignment: .center)
            }

            // Degree badge
            Text("\(sortedMember.degree)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 20)
                .background(degreeColor(sortedMember.degree))
                .cornerRadius(4)
                .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(sortedMember.isVisible ? Color.clear : Color.gray.opacity(0.05))
    }

    private func degreeColor(_ degree: Int) -> Color {
        switch degree {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        case 3: return .purple
        default: return .gray
        }
    }
}
