import XCTest
@testable import Islet

// Phase 64 (D-05) — asserts QuickNotesFormatter produces the EXACT locked
// CONTEXT.md string shape (XCTAssertEqual, not substring/contains checks). Pure
// function tests, no FileHandle/disk I/O, no setUp/tearDown needed.
final class QuickNotesFormatterTests: XCTestCase {

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents(year: 2026, month: 7, day: 25, hour: hour, minute: minute)
        components.timeZone = Calendar.current.timeZone
        return Calendar.current.date(from: components)!
    }

    func testIsoDateReturnsExactYYYYMMDD() {
        let fixedDate = date(hour: 0, minute: 0)
        XCTAssertEqual(QuickNotesFormatter.isoDate(fixedDate), "2026-07-25")
    }

    func testFormatEntrySingleLine() {
        let entry = QuickNotesFormatter.formatEntry(text: "Erste Notiz, kurz.", at: date(hour: 14, minute: 32))
        XCTAssertEqual(entry, "- 14:32 Erste Notiz, kurz.\n")
    }

    func testFormatEntryTwoLinesIndentsSecondLineWithTwoSpaces() {
        let entry = QuickNotesFormatter.formatEntry(
            text: "Längere Notiz mit\nzweiter Zeile eingerückt.",
            at: date(hour: 14, minute: 47)
        )
        XCTAssertEqual(entry, "- 14:47 Längere Notiz mit\n  zweiter Zeile eingerückt.\n")
    }

    func testFormatEntryThreeLinesIndentsEveryLineAfterFirst() {
        let entry = QuickNotesFormatter.formatEntry(
            text: "Erste Zeile\nzweite Zeile\ndritte Zeile",
            at: date(hour: 9, minute: 5)
        )
        XCTAssertEqual(entry, "- 09:05 Erste Zeile\n  zweite Zeile\n  dritte Zeile\n")
    }
}
