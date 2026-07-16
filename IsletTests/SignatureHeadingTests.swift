import XCTest
@testable import Islet

// ONBOARD-04 (D-09/D-10) — SignatureHeading.glyphPaths(for:font:) is the Core Text glyph
// extraction contract Plan 36-04 will animate with .trim(from:to:). This is the least-precedented
// piece of the phase (no prior analog in this codebase) — these tests sanity-check the extracted
// shape (one entry per character, including the space, per D-10) before any animation is layered
// on top. Mirrors EqualizerBarsTests.swift's shape (plain XCTestCase, @testable import).
final class SignatureHeadingTests: XCTestCase {

    private let testFont = SignatureHeading.loadSignatureFont(size: 28)

    func testGlyphPathsReturnsOneEntryPerCharacterIncludingSpace() {
        let glyphs = SignatureHeading.glyphPaths(for: "Meet Islet", font: testFont)
        XCTAssertEqual(glyphs.count, 10, "glyphPaths(for:font:) must return exactly one entry per character of \"Meet Islet\" (10 chars incl. space, D-10).")
    }

    func testNonSpaceCharactersHaveNonEmptyOutlines() {
        let text = "Meet Islet"
        let glyphs = SignatureHeading.glyphPaths(for: text, font: testFont)
        for (index, character) in text.enumerated() {
            guard character != " " else { continue }   // the space glyph may legitimately be empty
            XCTAssertFalse(glyphs[index].path.isEmpty, "Character '\(character)' at index \(index) must have a non-empty extracted outline.")
        }
    }

    func testTotalWidthIsPositiveFiniteAndGreaterThanAnySingleAdvance() {
        let glyphs = SignatureHeading.glyphPaths(for: "Meet Islet", font: testFont)
        let total = SignatureHeading.totalWidth(for: glyphs)

        XCTAssertTrue(total.isFinite, "totalWidth(for:) must be finite.")
        XCTAssertGreaterThan(total, 0, "totalWidth(for:) must be positive for non-empty text.")

        let maxSingleAdvance = glyphs.map(\.advance).max() ?? 0
        XCTAssertGreaterThan(total, maxSingleAdvance, "totalWidth(for:) must accumulate across glyphs, not just reflect the largest single advance.")
    }
}
