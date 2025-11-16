//
//  ContentView.swift
//  MyTree
//
//  Created by Gaurav Jain on 10/30/25.
//

import SwiftUI
import Contacts

/// Root view coordinating the app's primary states: authorization, loading, contact selection, and tree visualization.
///
/// This view acts as the state machine for the application, rendering different UI based on:
/// - Contacts authorization status (not determined, denied, authorized)
/// - Whether the "me" contact has been selected
/// - Tree data loading progress
///
/// **States:**
/// 1. **Not Determined**: Shows welcome screen with "Get Started" button
/// 2. **Denied**: Shows error message with instructions to enable in Settings
/// 3. **Authorized + Needs Selection**: Shows contact picker for user to select themselves
/// 4. **Authorized + Loading**: Shows progress indicator with stage and percentage
/// 5. **Ready**: Shows FamilyTreeView with fully loaded tree data
struct ContentView: View {
    @StateObject private var contactsManager = ContactsManager()
    @State private var hasRequestedAccess = false

    var body: some View {
        ZStack {
            if contactsManager.authorizationStatus == .authorized {
                if contactsManager.needsUserToSelectMeContact {
                    // Show contact picker
                    ContactPickerView(contacts: contactsManager.availableContacts) { selectedContact in
                        Task {
                            await contactsManager.selectMeContact(selectedContact)
                        }
                    }
                } else if let treeData = contactsManager.treeData {
                    FamilyTreeView(
                        treeData: treeData,
                        myContact: contactsManager.myContactCard
                    )
                } else {
                    // Loading screen with progress indicator
                    VStack(spacing: 24) {
                        // Spinning progress indicator
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(.circular)

                        VStack(spacing: 12) {
                            Text("Loading your family tree...")
                                .font(.headline)

                            // Current stage text
                            if !contactsManager.initializationStage.isEmpty {
                                Text(contactsManager.initializationStage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 6)

                                    // Progress fill
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor)
                                        .frame(
                                            width: geometry.size.width
                                                * CGFloat(contactsManager.initializationProgress),
                                            height: 6
                                        )
                                        .animation(
                                            .easeOut(duration: 0.3),
                                            value: contactsManager.initializationProgress
                                        )
                                }
                            }
                            .frame(height: 6)
                            .padding(.horizontal, 40)
                        }
                    }
                    .padding()
                }
            } else if contactsManager.authorizationStatus == .denied {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    Text("Contacts Access Denied")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("MyTree needs access to your contacts to display your family tree.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("Please grant access in System Settings > Privacy & Security > Contacts")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: 400)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Welcome to MyTree")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Visualize your family tree from your contacts")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Get Started") {
                        Task {
                            await contactsManager.requestAccess()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await contactsManager.checkAuthorizationStatus()
        }
    }
}
