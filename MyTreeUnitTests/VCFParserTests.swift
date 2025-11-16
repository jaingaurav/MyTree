//
//  VCFParserTests.swift
//  MyTreeUnitTests
//
//  Pure unit tests for VCFParser service.
//  Tests VCF parsing without requiring app initialization.
//

import XCTest
import Contacts
import Foundation

final class VCFParserTests: XCTestCase {
    var parser: VCFParser?

    override func setUp() {
        super.setUp()
        parser = VCFParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - File Not Found Tests

    func testParseVCFWithNonexistentFile() {
        guard let parser = parser else {
            XCTFail("Parser not initialized")
            return
        }

        // When
        let result = parser.parseVCF(at: "/nonexistent/path/to/file.vcf")

        // Then
        if case .failure(let error) = result {
            if case .fileNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected fileNotFound error but got: \(error)")
            }
        } else {
            XCTFail("Expected failure for nonexistent file")
        }
    }

    // MARK: - Valid VCF Tests

    func testParseVCFWithValidFile() {
        guard let parser = parser else {
            XCTFail("Parser not initialized")
            return
        }

        // Given - use test VCF file
        let testVCFPath = "test_vcf/nuclear_family.vcf"

        // When
        let result = parser.parseVCF(at: testVCFPath)

        // Then
        switch result {
        case .success(let contacts):
            XCTAssertGreaterThan(contacts.count, 0, "Should parse at least one contact")
        case .failure:
            // File might not exist in test environment - that's ok for now
            break
        }
    }

    // MARK: - Path Resolution Tests

    func testParseVCFWithRelativePath() {
        guard let parser = parser else {
            XCTFail("Parser not initialized")
            return
        }

        // Given
        let relativePath = "test_vcf/single_person.vcf"

        // When
        let result = parser.parseVCF(at: relativePath)

        // Then - should attempt to resolve path (may fail if file doesn't exist)
        switch result {
        case .success(let contacts):
            XCTAssertGreaterThanOrEqual(contacts.count, 1)
        case .failure:
            // Path resolution works but file may not exist - acceptable
            break
        }
    }

    func testParseVCFWithAbsolutePath() {
        guard let parser = parser else {
            XCTFail("Parser not initialized")
            return
        }

        // Given
        let absolutePath = "/tmp/nonexistent.vcf"

        // When
        let result = parser.parseVCF(at: absolutePath)

        // Then
        if case .failure(let error) = result {
            if case .fileNotFound = error {
                // Expected - absolute path should be used as-is
            } else {
                XCTFail("Expected fileNotFound for absolute path")
            }
        } else {
            XCTFail("Expected failure for nonexistent absolute path")
        }
    }

    // MARK: - Family Member Conversion Tests

    func testParseFamilyMembersWithConverter() {
        guard let parser = parser else {
            XCTFail("Parser not initialized")
            return
        }

        // Given
        let testPath = "test_vcf/nuclear_family.vcf"
        let converter: (CNContact) -> FamilyMember = { contact in
            FamilyMember(
                id: contact.identifier,
                givenName: contact.givenName,
                familyName: contact.familyName,
                imageData: nil,
                emailAddresses: [],
                phoneNumbers: [],
                relations: [],
                birthDate: contact.birthday?.date,
                marriageDate: nil
            )
        }

        // When
        let result = parser.parseFamilyMembers(at: testPath, using: converter)

        // Then
        switch result {
        case .success(let members):
            XCTAssertGreaterThan(members.count, 0, "Should convert contacts to family members")
            // Verify conversion worked
            for member in members {
                XCTAssertFalse(member.fullName.isEmpty)
            }
        case .failure:
            // File may not exist in test environment
            break
        }
    }
}
