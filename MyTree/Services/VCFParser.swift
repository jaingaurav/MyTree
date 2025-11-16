//
//  VCFParser.swift
//  MyTree
//
//  Parses VCF (vCard) files and converts contacts to FamilyMember objects.
//  Extracted from HeadlessRenderer to improve separation of concerns.
//

import Foundation
import Contacts

/// Service for parsing VCF files and converting them to family members.
final class VCFParser {
    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Parsing

    /// Parses a VCF file and returns CNContacts.
    /// - Parameter path: Path to VCF file (absolute or relative)
    /// - Returns: Result containing array of CNContacts or parsing error
    func parseVCF(at path: String) -> Result<[CNContact], VCFParsingError> {
        // Resolve path
        let resolvedPath: String
        do {
            resolvedPath = try resolvePath(path)
        } catch let error as VCFParsingError {
            return .failure(error)
        } catch {
            return .failure(.fileNotFound(path))
        }

        // Verify file exists
        guard fileManager.fileExists(atPath: resolvedPath) else {
            return .failure(.fileNotFound(resolvedPath))
        }

        // Load and parse VCF data
        do {
            let vcfURL = URL(fileURLWithPath: resolvedPath)
            let vcfData = try Data(contentsOf: vcfURL)
            let contacts = try CNContactVCardSerialization.contacts(with: vcfData)
            return .success(contacts)
        } catch {
            return .failure(.encodingError(error.localizedDescription))
        }
    }

    // MARK: - Path Resolution

    /// Resolves a VCF file path, checking multiple candidate locations.
    /// - Parameter path: Path to resolve (absolute or relative)
    /// - Returns: Resolved absolute path
    /// - Throws: VCFParsingError if path cannot be resolved
    private func resolvePath(_ path: String) throws -> String {
        // If absolute path, use as-is
        guard !path.hasPrefix("/") else {
            return path
        }

        // Build and check candidate paths
        let candidates = buildCandidatePaths(for: path)

        // Find first existing path
        if let found = candidates.first(where: { fileManager.fileExists(atPath: $0) }) {
            return found
        }

        // Not found - return first candidate (error will be caught by caller)
        return candidates.first ?? path
    }

    /// Builds list of candidate paths to search for a relative path
    private func buildCandidatePaths(for relativePath: String) -> [String] {
        var candidates: [String] = []

        // 1. Current working directory
        let currentDir = fileManager.currentDirectoryPath
        candidates.append((currentDir as NSString).appendingPathComponent(relativePath))

        // 2. Project root (from environment variable)
        if let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] {
            candidates.append((projectRoot as NSString).appendingPathComponent(relativePath))
        }

        // 3. Project root (by searching for markers)
        if let projectRoot = findProjectRoot() {
            candidates.append((projectRoot as NSString).appendingPathComponent(relativePath))
        }

        return candidates
    }

    /// Finds project root by searching up directory tree for markers.
    /// - Returns: Absolute path to project root, or nil if not found
    private func findProjectRoot() -> String? {
        var currentPath = fileManager.currentDirectoryPath

        // Walk up directory tree (max 10 levels)
        for _ in 0..<10 {
            if let projectPath = checkForProjectMarkers(at: currentPath) {
                return projectPath
            }

            // Move up one directory
            let parentPath = (currentPath as NSString).deletingLastPathComponent
            guard parentPath != currentPath else {
                break // Reached filesystem root
            }
            currentPath = parentPath
        }

        return nil
    }

    /// Checks if a directory contains project markers
    private func checkForProjectMarkers(at path: String) -> String? {
        let xcodeprojPath = (path as NSString).appendingPathComponent("MyTree.xcodeproj")
        let makefilePath = (path as NSString).appendingPathComponent("Makefile")
        let contactsVcfPath = (path as NSString).appendingPathComponent("contacts.vcf")

        // Check standard project markers
        if fileManager.fileExists(atPath: xcodeprojPath) || fileManager.fileExists(atPath: makefilePath) {
            return path
        }

        // Check for contacts.vcf + README.md combination
        if fileManager.fileExists(atPath: contactsVcfPath) {
            let readmePath = (path as NSString).appendingPathComponent("README.md")
            if fileManager.fileExists(atPath: readmePath) {
                return path
            }
        }

        return nil
    }
}

// MARK: - Convenience Extensions

extension VCFParser {
    /// Parses VCF file and converts to FamilyMember array.
    /// - Parameters:
    ///   - path: Path to VCF file
    ///   - converter: Function to convert CNContact to FamilyMember
    /// - Returns: Result containing family members or error
    func parseFamilyMembers(
        at path: String,
        using converter: (CNContact) -> FamilyMember
    ) -> Result<[FamilyMember], VCFParsingError> {
        parseVCF(at: path).map { contacts in
            contacts.map(converter)
        }
    }
}
