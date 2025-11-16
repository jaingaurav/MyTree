//
//  LayoutError.swift
//  MyTree
//
//  Error types for tree layout operations.
//

import Foundation

/// Errors that can occur during tree layout calculation.
enum LayoutError: LocalizedError, Equatable {
    case emptyMemberList
    case rootNotFound(String)
    case invalidTreeData(String)
    case placementFailed(memberId: String, reason: String)
    case infiniteLoop(description: String)

    var errorDescription: String? {
        switch self {
        case .emptyMemberList:
            return "Cannot layout tree: member list is empty"
        case .rootNotFound(let rootId):
            return "Root member '\(rootId)' not found in member list"
        case .invalidTreeData(let reason):
            return "Invalid tree data: \(reason)"
        case let .placementFailed(memberId, reason):
            return "Failed to place member '\(memberId)': \(reason)"
        case .infiniteLoop(let description):
            return "Layout algorithm detected infinite loop: \(description)"
        }
    }
}

/// Errors related to VCF parsing and contact import.
enum VCFParsingError: LocalizedError, Equatable {
    case fileNotFound(String)
    case invalidFormat(line: Int, reason: String)
    case missingRequiredField(field: String)
    case encodingError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "VCF file not found at path: \(path)"
        case let .invalidFormat(line, reason):
            return "Invalid VCF format at line \(line): \(reason)"
        case .missingRequiredField(let field):
            return "Required VCF field missing: \(field)"
        case .encodingError(let details):
            return "VCF encoding error: \(details)"
        }
    }
}
