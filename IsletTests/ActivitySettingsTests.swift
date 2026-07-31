import SwiftUI
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

    // MARK: Phase 59 / SETTINGS-04/05

    func testNewV110KeyNames() {
        XCTAssertEqual(ActivitySettings.capsLockKey, "activity.capsLock")
        XCTAssertEqual(ActivitySettings.downloadProgressKey, "activity.downloadProgress")
        XCTAssertEqual(ActivitySettings.timerKey, "activity.timer")
        XCTAssertEqual(ActivitySettings.meetingHUDKey, "activity.meetingHUD")
        XCTAssertEqual(ActivitySettings.quickNotesKey, "activity.quickNotes")
        XCTAssertEqual(ActivitySettings.quickActionsKey, "activity.quickActions")
        XCTAssertEqual(ActivitySettings.codingProgressKey, "activity.codingProgress")
    }

    func testWingCornerRadiusNudgeKeyName() {
        XCTAssertEqual(ActivitySettings.debugWingCornerRadiusNudgeKey, "debug.wingTuner.cornerRadiusNudge")
    }

    func testOSDOpacityMinNudgeKeyName() {
        XCTAssertEqual(ActivitySettings.debugOSDOpacityMinNudgeKey, "debug.wingTuner.osdOpacityMinNudge")
    }

    func testOSDOpacityMaxNudgeKeyName() {
        XCTAssertEqual(ActivitySettings.debugOSDOpacityMaxNudgeKey, "debug.wingTuner.osdOpacityMaxNudge")
    }

    func testOSDRollSpeedNudgeKeyName() {
        XCTAssertEqual(ActivitySettings.debugOSDRollSpeedNudgeKey, "debug.wingTuner.osdRollSpeedNudge")
    }

    func testExistingActivityKeyNamesUnchanged() {
        XCTAssertEqual(ActivitySettings.chargingKey, "activity.charging")
        XCTAssertEqual(ActivitySettings.nowPlayingKey, "activity.nowPlaying")
        XCTAssertEqual(ActivitySettings.songChangeToastKey, "activity.songChangeToast")
        XCTAssertEqual(ActivitySettings.deviceKey, "activity.device")
        XCTAssertEqual(ActivitySettings.calendarCountdownKey, "activity.calendarCountdown")
        XCTAssertEqual(ActivitySettings.focusKey, "activity.focus")
        XCTAssertEqual(ActivitySettings.osdSuppressionKey, "activity.osdSuppression")
    }

    func testChargingAppStorageReadsSeededValueNotCompiledDefault() {
        let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!
        // Simulate a pre-upgrade user who turned Charging off, BEFORE the wrapper is declared.
        defaults.set(false, forKey: ActivitySettings.chargingKey)

        // Mirrors the production `@AppStorage(ActivitySettings.chargingKey) private var
        // chargingEnabled = true` declaration in SettingsView.swift — same key, same compiled
        // `true` default literal, but backed by the isolated pre-seeded suite instead of .standard.
        @AppStorage(ActivitySettings.chargingKey, store: defaults) var chargingEnabled = true

        XCTAssertEqual(chargingEnabled, false)
    }

    // MARK: Phase 60 / CAPS-01/UPDATE-01 (RESEARCH.md Pitfall 1, SETTINGS-05)

    func testUpdateHudKeyName() {
        XCTAssertEqual(ActivitySettings.updateHudKey, "activity.updateHud")
    }

    func testDefaultsToFalseKeysCoversAllFalseDefaultActivities() {
        XCTAssertEqual(ActivitySettings.defaultsToFalseKeys, Set([
            ActivitySettings.focusKey,
            ActivitySettings.osdSuppressionKey,
            ActivitySettings.capsLockKey,
            ActivitySettings.downloadProgressKey,
            ActivitySettings.timerKey,
            ActivitySettings.meetingHUDKey,
            ActivitySettings.quickNotesKey,
            ActivitySettings.quickActionsKey,
            ActivitySettings.codingProgressKey,
            ActivitySettings.updateHudKey,
        ]))
    }

    // MARK: Phase 66 / MENUBAR-01/02/03

    func testMenuBarOverflowRevealedKeyName() {
        XCTAssertEqual(ActivitySettings.menuBarOverflowRevealedKey, "menuBarOverflow.revealed")
    }
}
