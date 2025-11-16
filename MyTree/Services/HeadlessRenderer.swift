import Foundation
import SwiftUI
import Contacts
#if os(macOS)
import AppKit

/// Renders FamilyTreeView to an image file in headless mode.
///
/// This class handles the complete rendering pipeline:
/// 1. Loads contacts from VCF or uses provided contacts
/// 2. Builds the family tree
/// 3. Renders the tree view to an image
/// 4. Saves the image and debug logs to files
@MainActor
class HeadlessRenderer {
    private let log = AppLog.general
    var logBuffer: [String] = []

    /// Appearance mode for the rendered image
    enum AppearanceMode: String {
        case light
        case dark
        case system
    }

    /// Configuration for headless rendering
    struct Config {
        var vcfPath: String?
        var contactIds: [String]?
        var contactNames: [String]?
        var rootContactId: String?
        var rootContactName: String?
        var outputImagePath: String
        var outputLogPath: String
        var imageWidth: CGFloat
        var imageHeight: CGFloat
        var degreeOfSeparation: Int
        var showSidebar: Bool
        var debugMode: Bool
        var showDebugOverlay: Bool
        var appearanceMode: AppearanceMode
        var saveIntermediateRenders: Bool  // Save PNG for each incremental step

        static let `default` = Config(
            vcfPath: nil,
            contactIds: nil,
            contactNames: nil,
            rootContactId: nil,
            rootContactName: nil,
            outputImagePath: "family_tree.png",
            outputLogPath: "family_tree.log",
            imageWidth: 2000,
            imageHeight: 1500,
            degreeOfSeparation: 2,
            showSidebar: false,
            debugMode: true,
            showDebugOverlay: false,
            appearanceMode: .system,
            saveIntermediateRenders: false
        )
    }

    /// Renders the family tree to an image file
    func render(config: Config) async throws {
        logBuffer.removeAll()
        log("Starting headless rendering...")
        log("Config: \(config)")

        let contactsManager = try await loadContacts(config: config)
        let rootContact = try selectRootContact(from: contactsManager, config: config)
        let treeData = try buildFamilyTree(contactsManager: contactsManager, rootContact: rootContact)
        let membersToRender = filterContacts(treeData: treeData, config: config)
        try await renderAndSave(treeData: treeData, rootContact: rootContact, members: membersToRender, config: config)

        log("Headless rendering completed successfully!")
    }

    private func loadContacts(config: Config) async throws -> ContactsManager {
        log("Step 1: Loading contacts...")
        let contactsManager = ContactsManager()

        if let vcfPath = config.vcfPath {
            log("Loading from VCF file: \(vcfPath)")
            vcfContacts = try await loadContactsFromVCF(vcfPath: vcfPath, into: contactsManager)
            log("Building relationships from VCF contacts...")
            try await buildRelationsFromVCF(into: contactsManager)
            log("Built relationships for \(contactsManager.familyMembers.count) members")
        } else {
            log("Using system contacts...")
            await contactsManager.checkAuthorizationStatus()
            if contactsManager.authorizationStatus != .authorized {
                throw HeadlessError.contactsNotAuthorized
            }
            await contactsManager.loadContacts()
        }

        return contactsManager
    }

    private func selectRootContact(from contactsManager: ContactsManager, config: Config) throws -> FamilyMember {
        log("Step 2: Selecting root contact...")

        if let rootId = config.rootContactId {
            return try selectRootByID(rootId, from: contactsManager)
        } else if let rootName = config.rootContactName {
            return try selectRootByName(rootName, from: contactsManager)
        } else {
            return try selectDefaultRoot(from: contactsManager)
        }
    }

    // MARK: - Private Methods

    func log(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        logBuffer.append(logMessage)
        // Use os.Logger which outputs to stdout in CLI mode
        AppLog.headless.info(logMessage)
    }

    private var vcfContacts: [CNContact] = []

    private func buildRelationsFromVCF(into manager: ContactsManager) async throws {
        log("Building relationships from VCF contact relations...")

        var context = RelationBuildingContext(
            memberLookup: createMemberLookup(from: manager.familyMembers),
            virtualMembers: [:],
            nameToMemberId: createNameLookup(from: manager.familyMembers)
        )
        var membersWithRelations: [FamilyMember] = []

        for (index, cnContact) in vcfContacts.enumerated() {
            guard var member = context.memberLookup[cnContact.identifier] else { continue }

            let relations = processContactRelations(
                cnContact.contactRelations,
                manager: manager,
                context: &context
            )

            member = updateMemberWithRelations(member, relations: relations)
            membersWithRelations.append(member)

            if (index + 1) % 10 == 0 {
                log("Processed \(index + 1)/\(vcfContacts.count) contacts...")
            }
        }

        membersWithRelations.append(contentsOf: context.virtualMembers.values)
        manager.familyMembers = membersWithRelations
        log("Built relationships for \(membersWithRelations.count) members (\(context.virtualMembers.count) virtual)")
    }
}

// MARK: - Errors

enum HeadlessError: LocalizedError {
    case contactsNotAuthorized
    case vcfFileNotFound(String)
    case rootContactNotFound(String)
    case noContactsFound
    case noRootContact
    case treeNotBuilt
    case renderingFailed(String)
    case imageSaveFailed(String)
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case .contactsNotAuthorized:
            return "Contacts access not authorized"
        case .vcfFileNotFound(let path):
            return "VCF file not found: \(path)"
        case .rootContactNotFound(let id):
            return "Root contact not found: \(id)"
        case .noContactsFound:
            return "No contacts found"
        case .noRootContact:
            return "No root contact specified or found"
        case .treeNotBuilt:
            return "Family tree was not built"
        case .renderingFailed(let reason):
            return "Rendering failed: \(reason)"
        case .imageSaveFailed(let path):
            return "Failed to save image to: \(path)"
        case .platformNotSupported:
            return "Headless mode is only supported on macOS"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

extension HeadlessRenderer.Config: CustomStringConvertible {
    var description: String {
        """
        HeadlessRenderer.Config(
            vcfPath: \(vcfPath ?? "nil"),
            contactIds: \(contactIds?.joined(separator: ", ") ?? "nil"),
            contactNames: \(contactNames?.joined(separator: ", ") ?? "nil"),
            rootContactId: \(rootContactId ?? "nil"),
            rootContactName: \(rootContactName ?? "nil"),
            outputImagePath: \(outputImagePath),
            outputLogPath: \(outputLogPath),
            imageSize: \(imageWidth)x\(imageHeight),
            degreeOfSeparation: \(degreeOfSeparation),
            showSidebar: \(showSidebar),
            debugMode: \(debugMode),
            showDebugOverlay: \(showDebugOverlay),
            saveIntermediateRenders: \(saveIntermediateRenders)
        )
        """
    }
}

#endif
