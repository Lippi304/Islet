import Foundation

// Phase 39 / HUD-03/HUD-04 — the PURE volume/brightness→presentation seam (Pattern 1).
//
// Like FocusActivity and PowerActivity, this is a plain value + total mapping functions
// importing ONLY Foundation — no CGEventTap, no CoreAudio, no DisplayServices. Plan 39-03's
// VolumeReader and Plan 39-04's BrightnessReader (system glue) are the ONLY callers; they own
// the real hardware reads and lift raw values in here.
//
// A SINGLE shared type with an inner case split (CONTEXT.md's discretion note / RESEARCH's
// Primary Recommendation) — not two separate types — so IslandResolver.swift's
// TransientQueue.updateHead's same-category match covers both D-09 (same-activity scrub
// refresh) and D-12 (Volume<->Brightness instant replace) with one switch arm.
enum OSDActivity: Equatable {
    case volume(percent: Int, hardwareMuted: Bool)
    case brightness(percent: Int)

    // D-03 / RESEARCH Open Question 3 — the SINGLE source of truth for the muted check.
    // Two independent trigger paths: an explicit hardware mute, OR the level itself reading
    // zero. Plan 39-04's view layer reads this property, never re-derives the OR itself.
    // Brightness has no muted state (39-UI-SPEC.md).
    var isMuted: Bool {
        switch self {
        case .volume(let percent, let hardwareMuted):
            return hardwareMuted || percent == 0
        case .brightness:
            return false
        }
    }
}

// TOTAL pure mapping functions. Both unconditionally clamp `percent` to 0...100 (V5 input
// validation, mirrors PowerSourceMonitor.readCurrentPower()'s defensive-cast discipline)
// before constructing the case — a malformed/out-of-range read from the glue layer can never
// propagate an invalid percent into the resolver or view layer.
func osdVolumeActivity(percent: Int, hardwareMuted: Bool) -> OSDActivity {
    .volume(percent: min(100, max(0, percent)), hardwareMuted: hardwareMuted)
}

func osdBrightnessActivity(percent: Int) -> OSDActivity {
    .brightness(percent: min(100, max(0, percent)))
}
