---
status: resolved
phase: 06-priority-resolver-settings-v1-ship
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md, 06-05-SUMMARY.md]
started: 2026-07-01T00:41:22Z
updated: 2026-07-02T04:40:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Priority Resolver — Charging Beats Ambient, Then Yields Back
expected: Play music (Now Playing wings showing). Plug in the charger. A charging splash briefly wins (~3s), then the island returns to the media wings — not the bare black pill.
result: issue
reported: "Die Beiden breiten passen nicht also es ist nicht so schön das quasi beide Musik Symbole verschwinden und das dann halt die notch breiter wird und dann tauchen da die Symbole auf also kein smoother übergang."
severity: minor

### 2. Device Connect/Disconnect Splash + Battery
expected: Connect a Bluetooth audio device (e.g. headphones). A transient splash shows the device connecting, including its battery percentage if reported. Disconnecting shows a corresponding disconnect splash.
result: pass

### 3. Settings — Live Toggle + Persistence
expected: Open Settings, turn OFF "Charging". Plug/unplug the charger — no splash appears. Turn it back ON — splash returns. Quit and relaunch the app — your toggle choices are remembered.
result: pass

### 4. Accent Color — Tints Only Lively Elements
expected: In Settings, pick a different accent swatch. The charging battery glyph and the Now-Playing equalizer bars pick up the new color. The black island shape itself and the expanded transport buttons stay untinted.
result: issue
reported: "equalizer bars pass aber beim Akku nix geändert an Farbe."
severity: major

### 5. Fullscreen Gate Still Holds
expected: Enter true fullscreen (e.g. a fullscreen video) while an activity would normally splash. The island stays hidden — it does not pop over the fullscreen app.
result: issue
reported: "immernoch der kleien mini flash wenn man mit der Slide animaiton zum Fullscreen kommt das dann der kurze nochmal flash kommt."
severity: cosmetic
note: Matches the previously known Phase-2 (02-04) root cause — a ~1-frame island flash at the END of the fullscreen-ENTER transition, caused by the window server compositing the all-Spaces panel onto the activating fullscreen Space. Product-deferred at the time; a show-debounce fix was tried and reverted (nothing to debounce). Still present, not a new Phase-6 regression.

### 6. v1 Ship — Now Playing Health Check (D-16)
expected: On the current macOS build, Now Playing shows title/artist/art and the transport controls (play/pause/skip) work — confirming the launch-time health check passed, not the "nicht verfügbar" fallback.
result: pass
note: Confirmed earlier in this session — healthy on macOS 27.0 (26A5368g), Now Playing info displayed and transport controls worked.

## Summary

total: 6
passed: 3
issues: 3
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "After a charging splash yields back to the Now-Playing wings, the transition should be a smooth width morph (matchedGeometryEffect), not an abrupt resize with the media symbols popping in afterward"
  status: failed
  reason: "User reported: Die Beiden breiten passen nicht also es ist nicht so schön das quasi beide Musik Symbole verschwinden und das dann halt die notch breiter wird und dann tauchen da die Symbole auf also kein smoother übergang."
  severity: minor
  test: 1
  root_cause: "In NotchWindowController.scheduleActivityDismiss(), syncActivityModels() sets chargingState.activity = nil BEFORE entering the withAnimation(.spring) block that animates renderPresentation(). This un-animated mutation forces an un-animated intermediate SwiftUI commit sandwiched between the last .charging(...) render and the animated switch to .nowPlayingWings(...), breaking matchedGeometryEffect frame interpolation. Only the yield-back/dismiss path is affected (not entrance), since syncActivityModels() is only called there. A secondary factor: updateVisibility()'s panel.setFrame(_, display: true) runs synchronously outside the SwiftUI animation on every transition."
  artifacts:
    - path: "Islet/Notch/NotchWindowController.swift"
      issue: "scheduleActivityDismiss() clears chargingState.activity outside the withAnimation(.spring) block"
  missing:
    - "Move the chargingState.activity = nil (and device equivalent) mutation inside the withAnimation(.spring) block in scheduleActivityDismiss() so the state change and the render transition commit as one animated transaction"
    - "Verify panel.setFrame's synchronous call in updateVisibility() doesn't need to be coordinated with the SwiftUI animation for both directions"
  debug_session: ".planning/debug/resolved/charging-yield-width-jump.md"
  resolved_by: "06-06-PLAN.md (moved syncActivityModels()+renderPresentation() into one withAnimation(.spring) transaction)"

- truth: "Picking a different accent swatch in Settings should tint the charging battery indicator's color, same as it tints the Now-Playing equalizer bars"
  status: failed
  reason: "User reported: equalizer bars pass aber beim Akku nix geändert an Farbe."
  severity: major
  test: 4
  root_cause: "BatteryIndicator (Islet/Notch/BatteryIndicator.swift:16-26) has a working accent: Color = .green parameter, but neither call site in NotchPillView.swift passes it — line 216 (charging wings) and line 295 (device wings) both omit the accent argument, so they always fall back to the hardcoded default. Contrast with EqualizerBars(isPlaying:tint: accent) at line 241, which correctly forwards the environment-read accent. The environment injection point itself is correct (.environment(\\.activityAccent, ...) wraps NotchPillView in NotchWindowController.swift:743)."
  artifacts:
    - path: "Islet/Notch/NotchPillView.swift"
      issue: "BatteryIndicator(level: percent) at line 216 (charging) and BatteryIndicator(level: battery) at line 295 (device) both omit the accent: argument"
  missing:
    - "Pass accent: accent to BatteryIndicator at NotchPillView.swift:216 (charging wings) — plain oversight from when BatteryIndicator was wired up post-checkpoint in 06-04, after the 06-03 accent work"
    - "DECIDED (user, 2026-07-01): do NOT change the device wings indicator (line 295) — its green/amber/red-regardless-of-accent behavior at NotchPillView.swift:288-291 is an intentional design decision, out of scope for this fix. Only the charging indicator (line 216) is a bug."
  debug_session: ".planning/debug/resolved/battery-indicator-accent-not-tinted.md"
  resolved_by: "06-06-PLAN.md (charging BatteryIndicator now forwards accent: accent; device wing stays untinted by design)"

- truth: "Entering true fullscreen while an activity would splash should hide the island with no visible flash"
  status: failed
  reason: "User reported: immernoch der kleien mini flash wenn man mit der Slide animaiton zum Fullscreen kommt das dann der kurze nochmal flash kommt."
  severity: cosmetic
  test: 5
  root_cause: "Confirmed identical to the pre-existing Phase-2 (02-04) root cause, not a new Phase-6 regression. NotchPanel carries .canJoinAllSpaces in its collectionBehavior (NotchPanel.swift:32). When another app enters true fullscreen, the window server composites this all-Spaces panel onto the activating fullscreen Space during the transition itself, before any app-level notification fires — the app's reactive orderOut(nil) in updateVisibility() cannot pre-empt an already-rendered compositor frame. A 0.2s show-debounce was tried (cc7f3c1) and reverted (f706f66) since there's no blip on our side to debounce. Verified via git history that Phase 6 touched none of FullscreenSpaceProbe.swift, FullscreenDetector.swift, NotchPanel.swift, or the updateVisibility() fullscreen-gate logic."
  artifacts:
    - path: "Islet/Notch/NotchPanel.swift"
      issue: ".canJoinAllSpaces collectionBehavior causes the window server to composite the panel onto an activating fullscreen Space before any app-level notification can hide it"
  missing:
    - "No fix currently known at the application layer — would require a proactive (non-reactive) pre-transition hide signal that doesn't currently exist on macOS. Product-deferred, same verdict as Phase 2."
  debug_session: ".planning/debug/resolved/fullscreen-enter-flash.md"
  resolved_by: "accepted as deferred technical debt — no application-layer fix exists (pre-existing Phase-2 issue, not a regression)"
