import CoreGraphics

// ISL-05 — PURE fullscreen detection (Pattern 6). AppKit observers (NSWorkspace
// activeSpaceDidChange / didActivateApplication) + AX corroboration are wired in
// Plan 02-04; this file is the testable predicate they feed.
//
// Signal: on a notched built-in display, a TRUE-fullscreen app reclaims the
// menu-bar/notch band, so the built-in stops reporting its notch safe area while
// the display is STILL present. A merely maximized window leaves the safe area
// intact (the D-09 maximized-vs-fullscreen discriminator). An ABSENT built-in is
// clamshell, NOT fullscreen — selectTargetScreen returns nil for that case, so we
// map nil → false here and let the visibility AND handle the no-target path.
func isTrueFullscreen(builtin: ScreenDescriptor?) -> Bool {
    guard let builtin = builtin else { return false } // absent = clamshell, not fullscreen
    return !builtin.hasNotch                            // present but safe area collapsed = fullscreen
}

// ISL-05 / Pattern 7 — the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2) converges here. hideInFullscreen is the single gating flag (D-10):
// default true ships the hide; a future Phase-6 settings toggle flips it.
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && isFullscreen)
}
