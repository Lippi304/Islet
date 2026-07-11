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
    static let accentIndexKey = "accentIndex"
    // Quick task 260709-glz — NOT an "activity" toggle (it gates fullscreen visibility,
    // not a live-activity source), but lives in this same enum because this file is the
    // shared key namespace between SettingsView and the controller.
    static let hideInFullscreenKey = "notch.hideInFullscreen"
    // Phase 26 / T-26-03 — the onboarding-shown gate (shouldShowOnboarding(...)). Deliberately
    // plain UserDefaults, NOT Keychain: this is an app-owned UX flag, not a security/anti-tampering
    // boundary (unlike TRIAL-*/LIC-* state, which lives in a completely separate, unmodified store).
    static let onboardingCompletedKey = "onboarding.completed"

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
}

// 06-RESEARCH §Pattern 4 — the single accent source the three lively leaf views
// read. Plan 04 sets this once on the hosting view (from the persisted
// accentIndex) and the glyph / equalizer bars / device icon read it via
// `@Environment(\.activityAccent)`. Defaults to neutral white so views render
// correctly even before the controller wires it.
private struct ActivityAccentKey: EnvironmentKey { static let defaultValue: Color = .white }
extension EnvironmentValues {
    var activityAccent: Color {
        get { self[ActivityAccentKey.self] }
        set { self[ActivityAccentKey.self] = newValue }
    }
}
