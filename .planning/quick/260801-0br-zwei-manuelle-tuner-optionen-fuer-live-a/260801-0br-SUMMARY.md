---
phase: quick-260801-0br
plan: 01
subsystem: notch-ui
tags: [wings, wing-tuner, debug-tooling, resolution-scaling]
requires: []
provides: [resumePreviewWings-shared-formula, wingHeightNudge]
affects: [Islet/Notch/NotchPillView.swift, Islet/AppDelegate.swift, Islet/ActivitySettings.swift]
tech-stack:
  added: []
  patterns: [wingsShape(leftWidth:rightWidth:depthScale:onTap:), AppStorage-DEBUG-nudge-mirror]
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/AppDelegate.swift
    - Islet/ActivitySettings.swift
decisions: []
metrics:
  duration: ~15min (Task 1 + Task 2) + 3 on-device tuning rounds
  completed: 2026-08-01 — all 3 tasks complete, on-device checkpoint approved
---

# Quick Task 260801-0br: Zwei manuelle Tuner-Optionen für Live-Activity-Wings Summary

Root-cause fix for the collapsed-island "resume last track" preview never scaling with
resolution, plus a new additive Wing Tuner "Height" nudge axis covering every Live Activity wing.
On-device checkpoint approved after 3 tuning rounds (4 commits total).

## What Was Done

**Task 1 (commit `e8a4cbe`):** `resumePreviewWings(_ track:)` in
`Islet/Notch/NotchPillView.swift` was rewritten from a hardcoded `Self.wingsSize`
(290x32pt)/`Spacer()`-based `HStack` to the shared camera-safe, resolution-aware
`wingsShape(leftWidth:rightWidth:depthScale:onTap:)` formula every sibling wing (charging,
device, focus, osd, capsLock, meeting, mediaWingsOrToast) already uses. Modeled directly on
`deviceWings(for:)`'s structure; reuses `mediaWingContentWidth()`'s `margin: CGFloat = 5 +
wingMarginNudge` (same "Now Playing" wing family). `leadingPad`/`trailingPad`/`artSide` now
scale with `resolvedWingWidthScale`/`resolvedWingDepthScale`. `onResumeTap` is passed through
`wingsShape`'s existing `onTap:` override parameter instead of a separate `.onTapGesture`. A new
`rightContentWidth: CGFloat = 160` starting estimate holds the play-glyph/failure-text `Group`
(sized for "Wiedergabe nicht möglich"), flagged in-code for on-device Wing Tuner re-tuning like
every other wing's own "starting value" comments.

**Task 2 (commit `d27f9ac`):** New DEBUG-only Wing Tuner axis, `heightNudge`:
- `ActivitySettings.debugWingHeightNudgeKey = "debug.wingTuner.heightNudge"` (new key, mirrors
  `debugWingCornerRadiusNudgeKey`'s placement/pattern).
- `NotchPillView.swift`: new `@AppStorage` + always-compiled `wingHeightNudge: CGFloat` computed
  property (returns `CGFloat(debugWingHeightNudge)` in DEBUG, `0` in Release — zero Release
  behavior change).
- Wired into the two shared height choke points: `wingsShape`'s own `size.height` line and
  `mediaWingsOrToast`'s own separate inline `height` calc — covers all `wingsShape()`-based
  wings (now including the fixed `resumePreviewWings` from Task 1) plus the live media wing in
  one shot.
- `AppDelegate.swift`: 4 new menu items ("Height -5"/"-1"/"+1"/"+5") mirroring the Corner Radius
  group's exact step pattern, wired to 4 new `@objc` selectors reusing the existing
  `adjustWingNudge(_:by:)` helper. `debugWingTunerReset()` and `debugWingTunerPrint()` both
  extended to include the new key/value.

Both tasks verified via `xcodebuild build -scheme Islet -configuration Debug` -> BUILD SUCCEEDED,
plus Task 2's grep-based structural checks (`debugWingHeightNudgeKey` in ActivitySettings.swift,
`wingHeightNudge` in NotchPillView.swift, `debugWingHeightMinus5` in AppDelegate.swift) — all
passed.

**Round 2 fix (commit `aba87e8`):** first on-device UAT pass on Task 1 found two real problems,
fixed per coordinator instruction (not a self-discovered deviation — user-reported from live
hardware):
1. **Wing too wide, play icon hidden.** `rightContentWidth` was unconditionally `160` (sized for
   the rare failure-text case) even for the common play-icon case. Now
   `rightContentWidth = nowPlaying.resumePreviewFailed ? 160 : eqBarsWidth` where `eqBarsWidth =
   21` mirrors `mediaWingContentWidth()`'s own `eqBarsWidth` — keeps the wing's margins
   pixel-identical to the live Now Playing wing when showing the play icon.
2. **Tap target.** Whole-wing tap previously resumed playback (`onTap: onResumeTap` passed to
   `wingsShape`) — user wants the whole wing to behave like every other collapsed glance
   (`onClick()` -> expand to Home), with resume-playback scoped ONLY to the play-icon/failure-text
   slot. Removed the `onTap:` override from the `wingsShape(...)` call (falls back to its own
   default `onClick()`); added `.contentShape(Rectangle()).onTapGesture { onResumeTap() }` to
   just the icon/text `Group`. This supersedes the plan's original D-01 assumption — the doc
   comment above `resumePreviewWings` was updated to reflect the new contract.

Rebuilt (`xcodebuild build -scheme Islet -configuration Debug` -> BUILD SUCCEEDED) and committed.

**Round 3 bake (commit `1b85139`):** user live-tuned `resumePreviewWings` further via Wing
Tuner and confirmed (via "Print Wing Tuner Values") the correct value is `trailingNudge=-8.0`
with every other nudge at 0. Baked into the wing's own local `trailingPad` base literal:
`34 -> 26` (34 - 8 = 26), with `wingTrailingNudge` left in the formula for future live-tuning
rounds — comment follows this file's existing "baked delta" convention
(`// -8 baked in from on-device tuning, resume-preview wing only, quick task 260801-0br round 3
(was 34)`). Scoped to this wing only; `leadingPad`, `mediaWingContentWidth()`, and every other
wing's own trailingPad were left untouched. The live `debug.wingTuner.trailingNudge` UserDefaults
value was reset to `0.0` outside this session (by the coordinator, matching "Reset Wing Tuner")
so it does not double-stack with the newly baked `-8`. Rebuilt
(`xcodebuild build -scheme Islet -configuration Debug` -> BUILD SUCCEEDED) and committed.

**Unrelated finding (no code change, for the record):** between round 2 and round 3, the user
saw an apparent "everything got smaller/clipped" regression. Root cause was a stale, unrelated
leftover `debug.wingTuner.marginNudge=-60` UserDefaults value from a much older tuning session —
NOT caused by any commit in this plan. Already reset to `0` directly via `defaults write` outside
this session; no action needed here.

## Deviations from Plan

**1. [Round 2, user-reported on-device] Resume-preview width/tap-target correction** — see
"Round 2 fix" above. Not a Rule 1-4 auto-fix; applied directly per explicit coordinator
instruction relaying live UAT findings. Files: `Islet/Notch/NotchPillView.swift`. Commit:
`aba87e8`.

**2. [Round 3, user-confirmed on-device] Baked -8 trailingPad delta** — see "Round 3 bake"
above. Applied directly per explicit coordinator instruction relaying a live-tuned, confirmed
value. Files: `Islet/Notch/NotchPillView.swift`. Commit: `1b85139`.

Otherwise: plan executed exactly as written for Task 1 and Task 2. No auto-fixes, no blockers, no
package installs, no architectural changes needed beyond the above.

## Task 3 — DONE (on-device checkpoint APPROVED)

Task 3 (`type="checkpoint:human-verify"`, gate=blocking) ran across 3 on-device rounds against
the how-to-verify checklist below (resume-preview sizing/tap-target, Settings Width/Depth
sliders, Wing Tuner Leading/Trailing/Margin nudges, the new Height axis, Reset/Print, and
regression-checking every other wing). Round 1 surfaced the two problems fixed in the round 2
fix (`aba87e8`); round 2 surfaced the trailing-delta tuning baked in round 3 (`1b85139`). Final
re-test after both fixes: user confirmed **"Gut passt" (approved)**, no further issues reported.

<details>
<summary>Original how-to-verify checklist (for reference)</summary>

Open `Islet.xcodeproj` in Xcode and run the app on this Mac (Cmd-R, Debug scheme), then:

1. Play something in Spotify/Music, then pause/stop and let the island collapse. Hover the
   collapsed island and confirm the "resume preview" wing (album art + play glyph) renders
   correctly proportioned — no clipped/misaligned edges, no longer too wide, play icon visible —
   at your current screen resolution. Tap anywhere on the wing EXCEPT the play icon and confirm
   it expands to Home like every other wing; tap ONLY the play icon and confirm it resumes
   playback.
2. While the resume preview is showing, open Settings > Island Size and drag the Width and Depth
   sliders. Confirm the resume preview wing visibly resizes live along with every other wing
   (e.g. compare against the OSD/volume wing by pressing a volume key).
3. Open the debug menu > Wing Tuner. Trigger the resume preview again (hover after a
   pause/stop) and click Leading/Trailing/Margin nudges — confirm they now affect the resume
   preview wing exactly like they already affect the Charging/Device wings.
4. Trigger any Live Activity wing (e.g. press a volume/brightness key for the OSD wing, or play
   music for the media wing). In Wing Tuner, click "Height +5" a few times and confirm the
   wing's black shape visibly extends further downward, live, no rebuild. Click "Height -5" a
   few times past 0 and confirm it shrinks. Click "Reset Wing Tuner" and confirm it snaps back.
5. Click "Print Wing Tuner Values" and confirm the Xcode console output now includes
   `heightNudge=...` alongside the existing 5 values.
6. With all nudges at 0 (Reset), confirm every other wing (Charging, Focus, Caps Lock, Device,
   Update, Download, Timer, Meeting) still looks exactly as before this plan.

</details>

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift` — FOUND, modified (Task 1 + Task 2)
- `Islet/AppDelegate.swift` — FOUND, modified (Task 2)
- `Islet/ActivitySettings.swift` — FOUND, modified (Task 2)
- Commit `e8a4cbe` — FOUND (`git log --oneline` confirms)
- Commit `d27f9ac` — FOUND (`git log --oneline` confirms)
- Commit `aba87e8` — FOUND (`git log --oneline` confirms)
- Commit `1b85139` — FOUND (`git log --oneline` confirms)
