import XCTest
@testable import Islet

// Phase 27 / VISUAL-03 — pure-logic coverage for the Theming data-model
// foundation: MaterialStyle clamp-to-default parsing, the existing accent
// clamp (now load-bearing for 3 more call sites), the new key names, and the
// one-time legacy-accent migration (D-08). All pure value transforms, no
// fakes needed — mirrors LicenseStateTests.swift's plain-XCTest style.
final class ActivitySettingsTests: XCTestCase {

    // MARK: - Task 1: MaterialStyle + new keys

    func testMaterialStyleParsesGradient() {
        XCTAssertEqual(ActivitySettings.MaterialStyle(rawValue: "gradient"), .gradient)
    }

    func testMaterialStyleParsesSolidBlack() {
        XCTAssertEqual(ActivitySettings.MaterialStyle(rawValue: "solidBlack"), .solidBlack)
    }

    func testMaterialStyleParsesCorruptedValueToNil() {
        XCTAssertNil(ActivitySettings.MaterialStyle(rawValue: "corrupted-value"))
    }

    func testAccentClampsOutOfRangeIndexToDefault() {
        XCTAssertEqual(
            ActivitySettings.accent(for: 999),
            ActivitySettings.palette[ActivitySettings.defaultAccentIndex]
        )
    }

    func testNewKeyNames() {
        XCTAssertEqual(ActivitySettings.materialStyleKey, "theming.materialStyle")
        XCTAssertEqual(ActivitySettings.nowPlayingAccentKey, "accent.nowPlaying")
        XCTAssertEqual(ActivitySettings.chargingAccentKey, "accent.charging")
        XCTAssertEqual(ActivitySettings.deviceAccentKey, "accent.device")
    }

    // MARK: - Task 2: migrateLegacyAccentIfNeeded

    func testMigrationOnFreshInstallWritesNothing() {
        let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!

        ActivitySettings.migrateLegacyAccentIfNeeded(defaults: defaults)

        XCTAssertNil(defaults.object(forKey: ActivitySettings.nowPlayingAccentKey))
        XCTAssertNil(defaults.object(forKey: ActivitySettings.chargingAccentKey))
        XCTAssertNil(defaults.object(forKey: ActivitySettings.deviceAccentKey))
    }

    func testMigrationSeedsAllThreeKeysFromLegacyAccentIndex() {
        let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!
        defaults.set(3, forKey: ActivitySettings.accentIndexKey)

        ActivitySettings.migrateLegacyAccentIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: ActivitySettings.nowPlayingAccentKey), 3)
        XCTAssertEqual(defaults.integer(forKey: ActivitySettings.chargingAccentKey), 3)
        XCTAssertEqual(defaults.integer(forKey: ActivitySettings.deviceAccentKey), 3)
    }

    func testMigrationIsIdempotentAndNeverClobbersAnAlreadySetKey() {
        let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!
        defaults.set(3, forKey: ActivitySettings.accentIndexKey)
        defaults.set(5, forKey: ActivitySettings.nowPlayingAccentKey)

        ActivitySettings.migrateLegacyAccentIfNeeded(defaults: defaults)

        // Already-migrated (or user-changed) keys must never be overwritten.
        XCTAssertEqual(defaults.integer(forKey: ActivitySettings.nowPlayingAccentKey), 5)
        XCTAssertNil(defaults.object(forKey: ActivitySettings.chargingAccentKey))
        XCTAssertNil(defaults.object(forKey: ActivitySettings.deviceAccentKey))
    }

    // MARK: Phase 38 / HUD-05 — focusKey + permission status hint

    func testFocusKeyName() {
        XCTAssertEqual(ActivitySettings.focusKey, "activity.focus")
    }

    func testFocusPermissionHintNilWhenToggleOff() {
        XCTAssertNil(ActivitySettings.focusPermissionStatusHint(toggleOn: false, granted: false))
    }

    func testFocusPermissionHintNeedsGrant() {
        XCTAssertEqual(
            ActivitySettings.focusPermissionStatusHint(toggleOn: true, granted: false),
            "Permission needed — tap to grant"
        )
    }

    func testFocusPermissionHintActive() {
        XCTAssertEqual(
            ActivitySettings.focusPermissionStatusHint(toggleOn: true, granted: true),
            "Active"
        )
    }

    // MARK: Phase 52 / SWITCH-03/04 — SwitcherLayout + switcher keys

    func testSwitcherLayoutParsesPillAndTopEdge() {
        XCTAssertEqual(ActivitySettings.SwitcherLayout(rawValue: "pill"), .pill)
        XCTAssertEqual(ActivitySettings.SwitcherLayout(rawValue: "topEdge"), .topEdge)
    }

    func testSwitcherLayoutParsesCorruptedValueToNil() {
        XCTAssertNil(ActivitySettings.SwitcherLayout(rawValue: "corrupted"))
    }

    func testSwitcherKeyNames() {
        XCTAssertEqual(ActivitySettings.switcherLayoutKey, "switcher.layout")
        XCTAssertEqual(ActivitySettings.switcherSlotLeftOuterKey, "switcher.slot.leftOuter")
        XCTAssertEqual(ActivitySettings.switcherSlotLeftInnerKey, "switcher.slot.leftInner")
        XCTAssertEqual(ActivitySettings.switcherSlotRightInnerKey, "switcher.slot.rightInner")
        XCTAssertEqual(ActivitySettings.switcherSlotRightOuterKey, "switcher.slot.rightOuter")
    }
}
