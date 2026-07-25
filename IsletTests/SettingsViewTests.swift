import XCTest
@testable import Islet

// Phase 52 / SWITCH-03/SWITCH-04 (D-08) — regression-locks SidebarSection.visibleSections(
// hasNotch:), the pure filter that hides the entire "Switcher" sidebar section on a display
// without a physical camera notch. Plain XCTestCase (no @MainActor needed — the function
// under test is a pure static func with no view state).
final class SettingsViewTests: XCTestCase {

    func testVisibleSectionsIncludesSwitcherWhenHasNotchIsTrue() {
        let sections = SettingsView.SidebarSection.visibleSections(hasNotch: true)
        XCTAssertEqual(sections.count, SettingsView.SidebarSection.allCases.count)
        XCTAssertTrue(sections.contains(.switcher))
    }

    func testVisibleSectionsExcludesSwitcherWhenHasNotchIsFalse() {
        let sections = SettingsView.SidebarSection.visibleSections(hasNotch: false)
        XCTAssertEqual(sections.count, SettingsView.SidebarSection.allCases.count - 1)
        XCTAssertFalse(sections.contains(.switcher))
    }

    // Phase 54 / D-10 — unlike .switcher, .permissions must survive both filter states
    // (it has no hasNotch dependency at all).
    func testVisibleSectionsIncludesPermissionsWhenHasNotchIsTrue() {
        let sections = SettingsView.SidebarSection.visibleSections(hasNotch: true)
        XCTAssertTrue(sections.contains(.permissions))
    }

    func testVisibleSectionsIncludesPermissionsWhenHasNotchIsFalse() {
        let sections = SettingsView.SidebarSection.visibleSections(hasNotch: false)
        XCTAssertTrue(sections.contains(.permissions))
    }

    // MARK: Phase 59 / SETTINGS-04 — card-array count/order/isNew assertions.
    // SettingsView() has an implicit zero-arg init since every stored property carries a
    // default (mirrors this file's existing bare-instantiation-free style).

    func testSystemHUDCardsCount() {
        XCTAssertEqual(SettingsView().systemHUDCards.count, 9)
    }

    func testMediaCardsCount() {
        XCTAssertEqual(SettingsView().mediaCards.count, 2)
    }

    func testProductivityCardsCount() {
        XCTAssertEqual(SettingsView().productivityCards.count, 5)
    }

    // D-03: existing activities ordered before new v1.10 activities within each category.
    func testSystemHUDCardsExistingBeforeNew() {
        let cards = SettingsView().systemHUDCards
        for card in cards.prefix(5) {
            XCTAssertFalse(card.isNew, "\(card.id) should not be isNew")
        }
        for card in cards.suffix(4) {
            XCTAssertTrue(card.isNew, "\(card.id) should be isNew")
        }
    }

    // D-07: Produktivität is 100% new this phase.
    func testProductivityCardsAllNew() {
        XCTAssertTrue(SettingsView().productivityCards.allSatisfy { $0.isNew })
    }

    func testMediaCardsNoneNew() {
        XCTAssertTrue(SettingsView().mediaCards.allSatisfy { !$0.isNew })
    }
}
