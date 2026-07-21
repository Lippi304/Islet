import SwiftUI

// Single source of truth for the activity settings the user controls (APP-03):
// which live activities show (three independent on/off prefs) and the accent
// color that tints the three lively leaf elements (D-11) — the island itself
// always stays black (D-10).
//
// For a first-time programmer: these are APP-OWNED preferences, so unlike
// LaunchAtLogin (where the SYSTEM is the source of truth), here @AppStorage /
// UserDefaults IS the source of truth. The keys below are shared verbatim with
// the controller (Plan 04) so it reads the SAME values to start/stop monitors
// and apply the accent — never redefine these strings elsewhere.
enum ActivitySettings {
    // @AppStorage / UserDefaults keys — used by BOTH SettingsView and the controller (Plan 04).
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let songChangeToastKey = "activity.songChangeToast"
    static let deviceKey     = "activity.device"
    // Phase 41 / HUD-08 (D-03) — default ON, matches Charging/Device/Now-Playing's opt-out
    // convention, not Focus/OSD's permission-gated opt-in one.
    static let calendarCountdownKey = "activity.calendarCountdown"
    // Phase 38 / HUD-05: the ONE activity toggle in this codebase that defaults OFF
    // (@AppStorage default wired in SettingsView.swift, Plan 38-06) — every sibling
    // toggle above defaults true. This key string only; the default lives with the toggle.
    static let focusKey = "activity.focus"
    // Phase 39 / HUD-03/HUD-04 (D-05) — gates ONLY native-OSD suppression, never the HUD's own
    // visibility (D-06) — see NotchWindowController's unconditional `startOSDInterceptor()`
    // call, which does NOT read this key.
    static let osdSuppressionKey = "activity.osdSuppression"
    // Phase 40 / HUD-06 (D-11) — gates Sparkle's automaticallyChecksForUpdates only; default
    // ON (D-12, wired in SettingsView.swift) since it gates no system permission, just a
    // background network check.
    static let autoUpdateCheckKey = "activity.autoUpdateCheck"
    // Phase 27 / VISUAL-03 / D-08: this key is now read ONLY as the legacy
    // migration source (see migrateLegacyAccentIfNeeded below) — never as a
    // live rendering key. The 3 per-element accent keys below replace it.
    static let accentIndexKey = "accentIndex"
    // Quick task 260709-glz — NOT an "activity" toggle (it gates fullscreen visibility,
    // not a live-activity source), but lives in this same enum because this file is the
    // shared key namespace between SettingsView and the controller.
    static let hideInFullscreenKey = "notch.hideInFullscreen"
    // Phase 26 / T-26-03 — the onboarding-shown gate (shouldShowOnboarding(...)). Deliberately
    // plain UserDefaults, NOT Keychain: this is an app-owned UX flag, not a security/anti-tampering
    // boundary (unlike TRIAL-*/LIC-* state, which lives in a completely separate, unmodified store).
    static let onboardingCompletedKey = "onboarding.completed"
    // Phase 33 / WEATHER-01/02 — String-backed enum key (replaces the removed
    // weatherExtendedKey Bool). Corrupted/unknown UserDefaults values parse to nil; every
    // read site applies `?? .medium` (D-04) so Medium is always the safe floor.
    enum WeatherStyle: String, CaseIterable {
        case medium, large
    }
    static let weatherStyleKey = "weather.style"

    // Phase 52 / SWITCH-03/04 — the view switcher's layout: today's pill-below-the-island
    // (default) or the alternate compact top-edge row. Corrupted/unknown UserDefaults values
    // parse to nil; every read site applies `?? .pill` (mirrors WeatherStyle's convention).
    enum SwitcherLayout: String, CaseIterable {
        case pill, topEdge
    }
    static let switcherLayoutKey = "switcher.layout"

    // Phase 52 / SWITCH-04 — one independent @AppStorage key per top-edge slot (never a single
    // encoded array), so each of the 4 positions (2 left of the camera cutout, 2 right) can be
    // configured independently. Default split: Home+Tray left, Calendar+Weather right.
    static let switcherSlotLeftOuterKey = "switcher.slot.leftOuter"
    static let switcherSlotLeftInnerKey = "switcher.slot.leftInner"
    static let switcherSlotRightInnerKey = "switcher.slot.rightInner"
    static let switcherSlotRightOuterKey = "switcher.slot.rightOuter"

    // Phase 27 / VISUAL-03: the island's material look — a flat black fill
    // ("solidBlack") or the Phase 25 vertical gradient ("gradient"). Phase 35 /
    // GLASS-01 (D-05) adds a third case, "liquidGlass" — the distorted-shader
    // material that becomes the new default (D-06). Corrupted/unknown
    // UserDefaults values parse to nil; every read site applies `?? .gradient`
    // (T-27-01).
    enum MaterialStyle: String, CaseIterable {
        case gradient, solidBlack, liquidGlass
    }
    static let materialStyleKey = "theming.materialStyle"

    // Phase 27 / VISUAL-03: per-element accent keys, one per lively leaf
    // element, replacing the single accentIndexKey as the live rendering
    // source. Seeded once from accentIndexKey by migrateLegacyAccentIfNeeded.
    static let nowPlayingAccentKey = "accent.nowPlaying"
    static let chargingAccentKey = "accent.charging"
    static let deviceAccentKey = "accent.device"

    // D-12 curated palette (~5-6 swatches), NOT a free ColorPicker.
    // Index 0 = neutral default (D-12) — preserves today's white look.
    static let palette: [Color] = [.white, .blue, .green, .orange, .pink, .purple]
    static let defaultAccentIndex = 0

    // Map a persisted index → the concrete accent Color. Any out-of-range value
    // (e.g. a tampered/corrupted UserDefaults entry, T-06-07) is clamped back to
    // the neutral default so it can never index out of bounds or crash.
    static func accent(for index: Int) -> Color {
        palette.indices.contains(index) ? palette[index] : palette[defaultAccentIndex]
    }

    // Phase 38 / HUD-05 / D-05: pure mapping from (toggle-on, permission-granted) to the
    // Settings status hint text — the two locked strings from 38-UI-SPEC.md's Settings
    // Permission Contract, verbatim. No hint while the toggle itself is off (D-02: nothing
    // is requested/shown until the user flips it on).
    static func focusPermissionStatusHint(toggleOn: Bool, granted: Bool) -> String? {
        guard toggleOn else { return nil }
        return granted ? "Active" : "Permission needed — tap to grant"
    }

    // Phase 39 / HUD-03/HUD-04 (D-05): identical shape to focusPermissionStatusHint above —
    // 39-UI-SPEC.md's Settings Permission Contract locks these exact two strings verbatim,
    // reused rather than reinvented.
    static func osdPermissionStatusHint(toggleOn: Bool, granted: Bool) -> String? {
        guard toggleOn else { return nil }
        return granted ? "Active" : "Permission needed — tap to grant"
    }

    // Phase 27 / D-08: seeds the 3 new per-element accent keys from the
    // existing single accentIndexKey exactly once, so an existing user's
    // accent look is preserved across the upgrade instead of silently
    // resetting to the default swatch. Idempotent — a no-op once any of the
    // 3 new keys has a value (already migrated, or the user already changed
    // one in the new Theming section) and a no-op on a fresh install (no
    // legacy value to seed from).
    static func migrateLegacyAccentIfNeeded(defaults: UserDefaults = .standard) {
        let alreadyMigrated = defaults.object(forKey: nowPlayingAccentKey) != nil
            || defaults.object(forKey: chargingAccentKey) != nil
            || defaults.object(forKey: deviceAccentKey) != nil
        guard !alreadyMigrated else { return }

        // T-27-03: `as? Int` guard — silently no-ops on a corrupted/missing
        // legacy value rather than force-casting/crashing.
        guard let legacy = defaults.object(forKey: accentIndexKey) as? Int else { return }

        defaults.set(legacy, forKey: nowPlayingAccentKey)
        defaults.set(legacy, forKey: chargingAccentKey)
        defaults.set(legacy, forKey: deviceAccentKey)
    }
}

// Phase 27 / VISUAL-03: the 4 new EnvironmentKeys — one per lively leaf
// element (now-playing glyph/equalizer, charging wings, device icon) plus the
// island material style, so each element can carry its own accent
// independently. Plan 02 wires these on the hosting view; the leaf views read
// them directly (the old single shared accent key was removed once the
// migration landed). Each accent defaults to neutral white (today's look);
// the material style defaults to .gradient (the Phase 25 shipped default) so
// views render correctly even before the controller wires them.
private struct NowPlayingAccentKey: EnvironmentKey { static let defaultValue: Color = .white }
private struct ChargingAccentKey: EnvironmentKey { static let defaultValue: Color = .white }
private struct DeviceAccentKey: EnvironmentKey { static let defaultValue: Color = .white }
// Bare alias so read sites (and this file's own EnvironmentKey plumbing) can
// say `MaterialStyle` instead of the fully-qualified `ActivitySettings.MaterialStyle`.
typealias MaterialStyle = ActivitySettings.MaterialStyle
// Bare alias so read sites can say `WeatherStyle.medium`/`.large` instead of the
// fully-qualified `ActivitySettings.WeatherStyle` (mirrors MaterialStyle above verbatim).
typealias WeatherStyle = ActivitySettings.WeatherStyle
// Bare alias so read sites can say `SwitcherLayout.pill`/`.topEdge` instead of the
// fully-qualified `ActivitySettings.SwitcherLayout` (mirrors WeatherStyle above verbatim).
typealias SwitcherLayout = ActivitySettings.SwitcherLayout

// Phase 35 / GLASS-01 (D-06): defaultValue flipped .gradient -> .liquidGlass —
// the EnvironmentKey fallback used before the controller wires the real
// @AppStorage value. SettingsView.swift's own @AppStorage default is a
// separate location, flipped independently (both must end up .liquidGlass).
private struct IslandMaterialStyleKey: EnvironmentKey {
    static let defaultValue: MaterialStyle = .liquidGlass
}

extension EnvironmentValues {
    var nowPlayingAccent: Color {
        get { self[NowPlayingAccentKey.self] }
        set { self[NowPlayingAccentKey.self] = newValue }
    }
    var chargingAccent: Color {
        get { self[ChargingAccentKey.self] }
        set { self[ChargingAccentKey.self] = newValue }
    }
    var deviceAccent: Color {
        get { self[DeviceAccentKey.self] }
        set { self[DeviceAccentKey.self] = newValue }
    }
    var islandMaterialStyle: MaterialStyle {
        get { self[IslandMaterialStyleKey.self] }
        set { self[IslandMaterialStyleKey.self] = newValue }
    }
}
