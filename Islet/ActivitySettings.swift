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
    // Phase 33 / WEATHER-02 — plain Bool key, default false. No UserDefaults.register default
    // is needed: both UserDefaults.bool(forKey:) and @AppStorage(...) = false already default
    // an absent key to false, matching this project's other plain-Bool-toggle keys.
    static let weatherExtendedKey = "weather.extended"

    // Phase 27 / VISUAL-03: the island's material look — a flat black fill
    // ("solidBlack") or the Phase 25 vertical gradient ("gradient", the
    // existing shipped default). Corrupted/unknown UserDefaults values parse
    // to nil; every read site applies `?? .gradient` (T-27-01).
    enum MaterialStyle: String, CaseIterable {
        case gradient, solidBlack
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

private struct IslandMaterialStyleKey: EnvironmentKey {
    static let defaultValue: MaterialStyle = .gradient
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
