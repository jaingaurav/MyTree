//
//  ContactPickerView.swift
//  MyTree
//
//  Contact picker for selecting "Me" contact
//

import SwiftUI

/// Contact picker used to select the user's own card.
struct ContactPickerView: View {
    let contacts: [FamilyMember]
    let onSelect: (FamilyMember) -> Void

    @State private var searchText = ""

    /// Contacts filtered by search and sorted by name.
    var filteredContacts: [FamilyMember] {
        if searchText.isEmpty {
            return contacts.sorted { $0.fullName < $1.fullName }
        } else {
            return contacts
                .filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.fullName < $1.fullName }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(
                        .system(size: 60)
                    )
                    .foregroundStyle(.blue)

                Text("Select Your Contact")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Choose which contact represents you to build your family tree")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search contacts", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(
                        action: { searchText = "" },
                        label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                Color.secondary.opacity(0.1)
            )
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Contact list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredContacts) { contact in
                        ContactPickerRow(contact: contact)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(contact)
                            }
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(Color.windowBackground)
    }
}

/// Single row displaying a contact avatar and name.
struct ContactPickerRow: View {
    let contact: FamilyMember

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            if let imageData = contact.imageData,
               let image = Image(platformImageData: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                ContactImageHelper.monogramView(
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    size: 50
                )
            }

            // Name and info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName)
                    .font(.body)
                    .fontWeight(.medium)

                if !contact.relations.isEmpty {
                    Text(
                        "\(contact.relations.count) relationship\(contact.relations.count == 1 ? "" : "s")"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.windowBackground)
    }
}
