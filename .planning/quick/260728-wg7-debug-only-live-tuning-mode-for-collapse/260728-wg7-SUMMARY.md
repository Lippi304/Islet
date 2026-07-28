---
task: 260728-wg7
title: DEBUG-only live-tuning mode for collapsed-state HUD wings
one-liner: 4 generic live nudge axes (Leading/Trailing/Margin/Gap) wired into all 12 tunable wing functions via @AppStorage, driven from a new "Wing Tuner" submenu in the existing 🐞 debug menu
status: tasks 1-3 complete and committed; Task 4 (on-device checkpoint) pending user
completed: 2026-07-28
---

# Quick Task 260728-wg7 Summary

## What was built

A DEBUG-only "Wing Tuner" live-tuning mechanism for the collapsed-state HUD wings
(Now Playing, OSD, DND/Focus, Caps Lock, Charging, Device, Update, Download, Timer,
Countdown, Meeting), mirroring the existing `islandWidthScaleOffset`/`islandDepthScaleOffset`
live-tuning precedent and the existing `setupDebugMenu()` debug-menu precedent — no new
mechanism invented.

### Task 1 — Nudge storage (`9045558`)

- `Islet/ActivitySettings.swift`: 4 new `#if DEBUG`-gated key constants
  (`debugWingLeadingNudgeKey`, `debugWingTrailingNudgeKey`, `debugWingMarginNudgeKey`,
  `debugWingGapNudgeKey`).
- `Islet/Notch/NotchPillView.swift`: 4 new `#if DEBUG`-gated `@AppStorage` properties
  (default 0) + 4 new always-compiled `wingLeadingNudge`/`wingTrailingNudge`/
  `wingMarginNudge`/`wingGapNudge` computed `CGFloat` properties (Release branch always
  returns 0, so every `+ wing*Nudge` site is a no-op `+ 0` literal in Release builds).

### Task 2 — Wiring (`eb9b34c`)

Appended `+ wingLeadingNudge` / `+ wingTrailingNudge` / `+ wingMarginNudge` /
`+ wingGapNudge` to the matching constant/padding site in all 12 wing functions listed in
the plan's `<interfaces>` constant map: `wings(for: ChargingActivity)`,
`mediaWingContentWidth()` + `mediaWingsRow(...)`'s 2 duplicate literals,
`resumePreviewWings(_:)` (both branches), `deviceWings(for:)`, `focusWings(for:)`,
`countdownWings(for:)`, `osdWings(for:)`, `capsLockWings(for:)`, `updateWings(for:)`,
`downloadWings(for:)`, `timerWings(for:)` (gap only in the `.running`/`.paused` branch).

`meetingWings(for:)` — leading/trailing wired; `margin` (`Self.meetingWingMargin`) and
`iconGap` deliberately **excluded** per the plan's documented exclusion (both are
load-bearing for the click-through-zone `assert(muteIconWidth == Self.meetingMuteIconWidth, ...)`
— nudging either would desync the tappable mute-icon region from the rendered glyph).

Verified 43 total `wing*Nudge` references in `NotchPillView.swift` (plan required ≥30).

### Task 3 — Debug menu (`29bc339`)

`Islet/AppDelegate.swift`'s `setupDebugMenu()`: new "Wing Tuner" submenu under the
existing 🐞 status item —

- Leading -2/+2, Trailing -2/+2, Margin -5/+5, Gap -1/+1 (each a plain
  `UserDefaults.standard.set(current + delta, ...)` via a shared `adjustWingNudge` helper)
- Reset Wing Tuner (sets all 4 keys back to `0.0`)
- Print Wing Tuner Values (prints all 4 current deltas in copy-pasteable form)

All submenu items get `item.target = self`, mirroring the existing flat-item construction
style exactly.

## Build verification (both configurations, per Task 3's verify step)

- **Debug**: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → **BUILD SUCCEEDED**
- **Release**: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Release` → **BUILD SUCCEEDED**
- Confirmed the built Release binary contains **zero** occurrences of the string
  "Wing Tuner" (`grep -c "Wing Tuner" .../Release/Islet.app/Contents/MacOS/Islet` → no match,
  exit 1) — the whole `setupDebugMenu()` body, including the new submenu, is absent from
  Release, matching this project's existing `#if DEBUG` convention.

## Deviations from Plan

None — plan executed exactly as written. Line numbers in the plan's `<interfaces>` section
shifted by the amount Task 1's own insertions added (expected or trivial to trace via grep),
but every named function/constant/axis mapping in the plan was found and wired exactly as
specified.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 | `9045558` | `Islet/ActivitySettings.swift`, `Islet/Notch/NotchPillView.swift` |
| 2 | `eb9b34c` | `Islet/Notch/NotchPillView.swift` |
| 3 | `29bc339` | `Islet/AppDelegate.swift` |

## Task 4 — NOT executed (requires real hardware)

The final `checkpoint:human-verify` task (gate="blocking") requires the user to run the
Debug build on their own Mac and confirm, live:

1. The 🐞 debug menu now has a "Wing Tuner" submenu with all 8 nudge actions + Reset + Print.
2. Nudging Leading/Trailing on the Now Playing wing visibly shifts album art/equalizer bars,
   with no rebuild.
3. Nudging Margin on the OSD wing visibly widens/narrows the camera-clearance gap.
4. "Print Wing Tuner Values" dumps all 4 current values to the Xcode console in
   copy-pasteable form.
5. "Reset Wing Tuner" snaps the currently-visible wing back to its original layout.
6. With all 4 nudges at 0 (Reset), every other collapsed wing (Charging, Focus, Caps Lock,
   Device) looks unchanged from before this task.

**This step was intentionally not executed by the agent** — it requires the actual user on
real notch hardware and is out of scope for autonomous execution. Run the app (Cmd-R, Debug
scheme, in Xcode) and report the checkpoint's 6-step verification result to resume/close this
quick task.

## Self-Check: PASSED

- `Islet/ActivitySettings.swift` contains the 4 new key constants — confirmed via commit diff.
- `Islet/Notch/NotchPillView.swift` contains the 4 `@AppStorage` properties + 4 computed
  properties + all wired call sites (43 total references) — confirmed via grep.
- `Islet/AppDelegate.swift` contains the "Wing Tuner" submenu + 12 new `@objc`/private
  functions — confirmed via commit diff.
- Commits `9045558`, `eb9b34c`, `29bc339` all present in `git log --oneline`.
- Debug build: BUILD SUCCEEDED. Release build: BUILD SUCCEEDED, zero "Wing Tuner" string
  in the compiled binary.
