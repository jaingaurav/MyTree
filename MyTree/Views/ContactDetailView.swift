import SwiftUI

struct ContactDetailView: View {
    let member: FamilyMember
    @Environment(\.dismiss)
    var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(
                    action: { dismiss() },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                )
            }
            .padding(.horizontal)

            if let imageData = member.imageData,
               let image = Image(platformImageData: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                ContactImageHelper.monogramView(
                    givenName: member.givenName,
                    familyName: member.familyName,
                    size: 120
                )
            }

            Text(member.fullName)
                .font(.title)
                .fontWeight(.bold)

            Divider()
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !member.emailAddresses.isEmpty {
                        InfoSection(title: "Email", icon: "envelope.fill") {
                            ForEach(member.emailAddresses, id: \.self) { email in
                                Text(email)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    if !member.phoneNumbers.isEmpty {
                        InfoSection(title: "Phone", icon: "phone.fill") {
                            ForEach(member.phoneNumbers, id: \.self) { phone in
                                Text(phone)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    if !member.relations.isEmpty {
                        InfoSection(title: "Relations", icon: "person.2.fill") {
                            ForEach(member.relations, id: \.member.id) { relation in
                                HStack {
                                    Text(relation.label)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(relation.member.fullName)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Spacer()
        }
        .frame(width: 400, height: 600)
        .background(Color.windowBackground)
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
