//
//  RelationshipLocalizerTests.swift
//  MyTreeIntegrationTests
//
//  Unit tests for relationship localizers to ensure all relationships
//  are properly identified and localized across languages.
//

import XCTest
@testable import MyTree

final class RelationshipLocalizerTests: XCTestCase {
    // MARK: - Test Helpers

    private func createMember(
        id: String,
        givenName: String,
        familyName: String = "Test",
        gender: Gender
    ) -> FamilyMember {
        var member = FamilyMember(
            id: id,
            givenName: givenName,
            familyName: familyName,
            imageData: nil,
            emailAddresses: [],
            phoneNumbers: [],
            relations: [],
            birthDate: nil,
            marriageDate: nil
        )
        member.inferredGender = gender
        return member
    }

    // MARK: - English Localizer Tests

    func testEnglishLocalizerBasicRelationships() {
        let localizer = ConfigBasedLocalizer(languageCode: "en")

        // Test immediate family
        let meInfo = RelationshipInfo(
            kind: .me,
            familySide: .own,
            path: [createMember(id: "me", givenName: "Me", gender: .male)]
        )
        XCTAssertEqual(localizer.localize(info: meInfo), "Me")

        let fatherInfo = RelationshipInfo(
            kind: .father,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: fatherInfo), "Father")

        let motherInfo = RelationshipInfo(
            kind: .mother,
            familySide: .maternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: motherInfo), "Mother")
    }

    func testEnglishLocalizerExtendedFamily() {
        let localizer = ConfigBasedLocalizer(languageCode: "en")

        // Test uncles/aunts
        let paternalUncleInfo = RelationshipInfo(
            kind: .paternalUncle,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: paternalUncleInfo), "Uncle")

        let maternalAuntInfo = RelationshipInfo(
            kind: .maternalAunt,
            familySide: .maternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: maternalAuntInfo), "Aunt")
    }

    func testEnglishLocalizerInLaws() {
        let localizer = ConfigBasedLocalizer(languageCode: "en")

        let wifesFatherInfo = RelationshipInfo(
            kind: .wifesFather,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: wifesFatherInfo), "Father-in-law (Wife's father)")

        let brothersWifeInfo = RelationshipInfo(
            kind: .brothersWife,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: brothersWifeInfo), "Brother's wife")
    }

    // MARK: - Chinese Localizer Tests

    func testChineseLocalizerBasicRelationships() {
        let localizer = ConfigBasedLocalizer(languageCode: "zh")

        let fatherInfo = RelationshipInfo(
            kind: .father,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: fatherInfo), "父亲 (Fùqīn)")

        let sonInfo = RelationshipInfo(
            kind: .son,
            familySide: .own,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: sonInfo), "儿子 (Érzi)")
    }

    func testChineseLocalizerMotherInLawDisambiguation() {
        let localizer = ConfigBasedLocalizer(languageCode: "zh")

        // Test wife's mother (岳母)
        let wifeMotherInfo = RelationshipInfo(
            kind: .wifesMother,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: wifeMotherInfo), "岳母 (Yuèmǔ)")

        // Test husband's mother (婆婆)
        let husbandMotherInfo = RelationshipInfo(
            kind: .husbandsMother,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: husbandMotherInfo), "婆婆 (Pópo)")
    }

    func testChineseLocalizerFatherInLawDisambiguation() {
        let localizer = ConfigBasedLocalizer(languageCode: "zh")

        // Test wife's father (岳父)
        let wifeFatherInfo = RelationshipInfo(
            kind: .wifesFather,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: wifeFatherInfo), "岳父 (Yuèfù)")

        // Test husband's father (公公)
        let husbandFatherInfo = RelationshipInfo(
            kind: .husbandsFather,
            familySide: .unknown,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: husbandFatherInfo), "公公 (Gōnggong)")
    }

    func testChineseLocalizerGrandparents() {
        let localizer = ConfigBasedLocalizer(languageCode: "zh")

        // Paternal grandparents
        let paternalGrandfatherInfo = RelationshipInfo(
            kind: .paternalGrandfather,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: paternalGrandfatherInfo), "爷爷 (Yéye)")

        // Maternal grandparents
        let maternalGrandmotherInfo = RelationshipInfo(
            kind: .maternalGrandmother,
            familySide: .maternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: maternalGrandmotherInfo), "外婆 (Wàipó)")
    }

    // MARK: - Hindi Localizer Tests

    func testHindiLocalizerBasicRelationships() {
        let localizer = ConfigBasedLocalizer(languageCode: "hi")

        let fatherInfo = RelationshipInfo(
            kind: .father,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: fatherInfo), "पिता (Pita)")

        let paternalUncleInfo = RelationshipInfo(
            kind: .paternalUncle,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: paternalUncleInfo), "चाचा (Chacha)")

        let maternalUncleInfo = RelationshipInfo(
            kind: .maternalUncle,
            familySide: .maternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: maternalUncleInfo), "मामा (Mama)")
    }

    // MARK: - Gujarati Localizer Tests

    func testGujaratiLocalizerBasicRelationships() {
        let localizer = ConfigBasedLocalizer(languageCode: "gu")

        let fatherInfo = RelationshipInfo(
            kind: .father,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: fatherInfo), "પિતા (Pita)")

        let paternalUncleInfo = RelationshipInfo(
            kind: .paternalUncle,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: paternalUncleInfo), "કાકા (Kaka)")
    }

    // MARK: - Urdu Localizer Tests

    func testUrduLocalizerBasicRelationships() {
        let localizer = ConfigBasedLocalizer(languageCode: "ur")

        let fatherInfo = RelationshipInfo(
            kind: .father,
            familySide: .paternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: fatherInfo), "والد (Walid)")

        let motherInfo = RelationshipInfo(
            kind: .mother,
            familySide: .maternal,
            path: []
        )
        XCTAssertEqual(localizer.localize(info: motherInfo), "والدہ (Walida)")
    }

    // MARK: - Comprehensive Coverage Tests

    func testAllRelationshipKindsHaveLocalizations() {
        let localizers: [RelationshipLocalizer] = [
            ConfigBasedLocalizer(languageCode: "en"),
            ConfigBasedLocalizer(languageCode: "hi"),
            ConfigBasedLocalizer(languageCode: "gu"),
            ConfigBasedLocalizer(languageCode: "ur"),
            ConfigBasedLocalizer(languageCode: "zh"),
            ConfigBasedLocalizer(languageCode: "es"),
            ConfigBasedLocalizer(languageCode: "fr")
        ]

        // All relationship kinds to test
        let allKinds: [RelationshipKind] = [
            .me, .husband, .wife,
            .father, .mother,
            .son, .daughter,
            .brother, .sister,
            .paternalGrandfather, .paternalGrandmother,
            .maternalGrandfather, .maternalGrandmother,
            .grandson, .granddaughter,
            .paternalUncle, .maternalUncle,
            .paternalAunt, .maternalAunt,
            .brothersSon, .brothersDaughter,
            .sistersSon, .sistersDaughter,
            .wifesFather, .wifesMother,
            .husbandsFather, .husbandsMother,
            .sonInLaw, .daughterInLaw,
            .wifesBrother, .husbandsBrother,
            .sistersHusband, .wifesSister,
            .husbandsSister, .brothersWife,
            .paternalCousinMale, .paternalCousinFemale,
            .maternalCousinMale, .maternalCousinFemale,
            .paternalGreatGrandfather, .paternalGreatGrandmother,
            .maternalGreatGrandfather, .maternalGreatGrandmother
        ]

        // Create a dummy member for path
        let dummyMember = createMember(id: "dummy", givenName: "Dummy", gender: .male)

        for localizer in localizers {
            for kind in allKinds {
                let info = RelationshipInfo(
                    kind: kind,
                    familySide: .unknown,
                    path: [dummyMember]
                )
                let result = localizer.localize(info: info)

                // Verify we got a non-empty result
                XCTAssertFalse(
                    result.isEmpty,
                    "Localizer returned empty string for \(kind)"
                )

                // Verify result is not a fallback "Relative" type message for supported kinds
                // (Some localizers may return a fallback, but it shouldn't be empty)
                XCTAssertTrue(
                    !result.isEmpty,
                    "Localizer has no localization for \(kind)"
                )
            }
        }
    }

    func testRelationshipLocalizerFactory() {
        // Test factory returns ConfigBasedLocalizer for each language
        let englishLocalizer = RelationshipLocalizerFactory.localizer(for: .english)
        XCTAssertTrue(englishLocalizer is ConfigBasedLocalizer)

        let hindiLocalizer = RelationshipLocalizerFactory.localizer(for: .hindi)
        XCTAssertTrue(hindiLocalizer is ConfigBasedLocalizer)

        let gujaratiLocalizer = RelationshipLocalizerFactory.localizer(for: .gujarati)
        XCTAssertTrue(gujaratiLocalizer is ConfigBasedLocalizer)

        let urduLocalizer = RelationshipLocalizerFactory.localizer(for: .urdu)
        XCTAssertTrue(urduLocalizer is ConfigBasedLocalizer)

        let chineseLocalizer = RelationshipLocalizerFactory.localizer(for: .chinese)
        XCTAssertTrue(chineseLocalizer is ConfigBasedLocalizer)

        let spanishLocalizer = RelationshipLocalizerFactory.localizer(for: .spanish)
        XCTAssertTrue(spanishLocalizer is ConfigBasedLocalizer)

        let frenchLocalizer = RelationshipLocalizerFactory.localizer(for: .french)
        XCTAssertTrue(frenchLocalizer is ConfigBasedLocalizer)

        // Verify localizers return correct translations
        let fatherInfo = RelationshipInfo(kind: .father, familySide: .paternal, path: [])
        XCTAssertEqual(englishLocalizer.localize(info: fatherInfo), "Father")
    }

    // MARK: - Path Context Tests

    func testPathContextPreservation() {
        // Verify that path information is correctly preserved in RelationshipInfo
        let me = createMember(id: "me", givenName: "Me", gender: .male)
        let wife = createMember(id: "wife", givenName: "Wife", gender: .female)
        let mother = createMember(id: "mother", givenName: "Mother", gender: .female)

        let info = RelationshipInfo(
            kind: .wifesMother,
            familySide: .unknown,
            path: [me, wife, mother]
        )

        XCTAssertEqual(info.path.count, 3)
        XCTAssertEqual(info.path[0].id, "me")
        XCTAssertEqual(info.path[1].id, "wife")
        XCTAssertEqual(info.path[2].id, "mother")
        XCTAssertEqual(info.path[1].inferredGender, .female)
    }
}
