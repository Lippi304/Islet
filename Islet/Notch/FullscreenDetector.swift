import CoreGraphics

// ISL-05 — SUPERSEDED safe-area heuristic, kept ONLY as a pure predicate (+ its
// FullscreenDetectorTests) to document the original idea and keep the suite green.
//
// IT IS NO LONGER THE RUNTIME SIGNAL. The live fullscreen signal is now
// `isBuiltinDisplayInFullscreenSpace(builtinUUID:)` in FullscreenSpaceProbe.swift
// (CGS managed display spaces). Reason this heuristic failed on-device (RESEARCH
// Open Question Q3): it infers fullscreen from the built-in's safe area / notch band,
// but the safe area is a PHYSICAL-DISPLAY property that does NOT change when ANOTHER
// app enters fullscreen. Islet is a background agent (LSUIElement) that never goes
// fullscreen itself, so from its process the safe area is constant → this predicate
// is always false at runtime and the island never hid. The CGS probe observes the
// built-in's CURRENT space type instead, which DOES reflect another app's fullscreen.
//
// Original heuristic (for reference): on a notched built-in, a TRUE-fullscreen app
// reclaims the menu-bar/notch band, so the built-in would stop reporting its notch
// safe area while still present; a merely maximized window leaves the safe area
// intact; an ABSENT built-in is clamshell (nil → false).
func isTrueFullscreen(builtin: ScreenDescriptor?) -> Bool {
    guard let builtin = builtin else { return false } // absent = clamshell, not fullscreen
    return !builtin.hasNotch                            // present but safe area collapsed = fullscreen
}

// ISL-05 / Pattern 7 — the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2, license entitlement from Phase 10) converges here. hideInFullscreen
// is the single gating flag (D-10): default true ships the hide; a future
// Phase-6 settings toggle flips it. isLicensed (D-11, LIC-03) is a new dominant
// AND-term: an unlicensed/expired-trial state always hides, overriding every
// other input.
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool, isLicensed: Bool) -> Bool {
    isLicensed && hasTarget && !(hideInFullscreen && isFullscreen)
}
