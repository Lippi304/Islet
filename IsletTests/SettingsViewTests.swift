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
}
