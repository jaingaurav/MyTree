//
//  VCFParser.swift
//  MyTree
//
//  Utility class for parsing VCF (vCard) files into CNContact objects.
//

import Foundation
import Contacts

/// Utility class for parsing VCF files.
final class VCFParser {

    /// Parses a VCF file and returns the contacts.
    /// - Parameter path: Path to the VCF file (can be relative or absolute)
    /// - Returns: Result containing either an array of CNContact objects or a VCFParsingError
    func parseVCF(at path: String) -> Result<[CNContact], VCFParsingError> {
        // Resolve relative paths to absolute paths
        let resolvedPath: String
        if (path as NSString).isAbsolutePath {
            resolvedPath = path
        } else {
            // Try multiple locations for relative paths
            let currentDir = FileManager.default.currentDirectoryPath
            let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ?? ""

            var candidates: [String] = []

            // 1. Current working directory
            candidates.append((currentDir as NSString).appendingPathComponent(path))

            // 2. Project root (if set via environment variable)
            if !projectRoot.isEmpty {
                candidates.append((projectRoot as NSString).appendingPathComponent(path))
            }

            // 3. Try to find project root by looking for common markers
            if let projectRoot = findProjectRoot() {
                candidates.append((projectRoot as NSString).appendingPathComponent(path))
            }

            // Find the first existing path, or use the first candidate if none exist
            resolvedPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            return .failure(.fileNotFound(resolvedPath))
        }

        // Parse the VCF file
        let vcfURL = URL(fileURLWithPath: resolvedPath)

        do {
            let vcfData = try Data(contentsOf: vcfURL)
            let contacts = try CNContactVCardSerialization.contacts(with: vcfData)
            return .success(contacts)
        } catch {
            // Convert common errors to VCFParsingError
            if let nsError = error as NSError? {
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
                    return .failure(.fileNotFound(resolvedPath))
                }
                return .failure(.encodingError(nsError.localizedDescription))
            }
            return .failure(.encodingError(error.localizedDescription))
        }
    }

    /// Parses a VCF file and converts contacts to FamilyMember objects using a converter closure.
    /// - Parameters:
    ///   - path: Path to the VCF file (can be relative or absolute)
    ///   - converter: Closure that converts a CNContact to a FamilyMember
    /// - Returns: Result containing either an array of FamilyMember objects or a VCFParsingError
    func parseFamilyMembers(
        at path: String,
        using converter: (CNContact) -> FamilyMember
    ) -> Result<[FamilyMember], VCFParsingError> {
        switch parseVCF(at: path) {
        case .success(let contacts):
            let members = contacts.map(converter)
            return .success(members)
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Private Helpers

    /// Attempts to find the project root directory by looking for common markers.
    private func findProjectRoot() -> String? {
        let fileManager = FileManager.default
        var currentPath = fileManager.currentDirectoryPath

        // Walk up the directory tree looking for project markers
        for _ in 0..<10 { // Limit to 10 levels up
            let xcodeprojPath = (currentPath as NSString).appendingPathComponent("MyTree.xcodeproj")
            let makefilePath = (currentPath as NSString).appendingPathComponent("Makefile")
            let contactsVcfPath = (currentPath as NSString).appendingPathComponent("contacts.vcf")

            // Check if this looks like the project root
            let hasProjectMarker = fileManager.fileExists(atPath: xcodeprojPath) ||
                                   fileManager.fileExists(atPath: makefilePath)
            let hasContactsVcf = fileManager.fileExists(atPath: contactsVcfPath)

            // If we find project markers, this is likely the project root
            if hasProjectMarker {
                return currentPath
            }

            // Also check if contacts.vcf exists here (might be project root even without markers)
            if hasContactsVcf {
                // Verify it's not just a random contacts.vcf by checking for other project files nearby
                let readmePath = (currentPath as NSString).appendingPathComponent("README.md")
                if fileManager.fileExists(atPath: readmePath) {
                    return currentPath
                }
            }

            // Move up one directory
            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath == currentPath {
                break // Reached root
            }
            currentPath = parentPath
        }

        return nil
    }
}
