---
phase: 18-song-change-toast
verified: 2026-07-09T17:15:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
---

# Phase 18: Song-Change Toast Verification Report

**Phase Goal:** Users get a brief, glanceable cue whenever playback switches to a genuinely different song, and can turn that cue off if they don't want it — without affecting the underlying Now Playing glance itself.
**Verified:** 2026-07-09T17:15:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Note on scope of this verification

Phase 18's Task 3 (18-02-PLAN.md) was a `checkpoint:human-verify` gate that ran 5 rounds of
on-device iteration during execution, ending in explicit user approval ("approved") of a
redesigned toast (a fading text row grown under the existing wings capsule, not the original
plan's standalone `blobShape`). Per the verification brief, the UPDATED `18-UI-SPEC.md` and the
user's final approval are treated as the source of truth for "correct," not the plan's original
pre-checkpoint design. This report verifies the codebase matches that final, approved design —
it does not re-litigate the abandoned round-1/round-2 blob approach.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A genuine song change (ambient, no transient, not expanded, toggle on) triggers a brief toast showing the new title+artist, then returns to the compact glance | ✓ VERIFIED | `songChangeToastContent(...)` (NowPlayingPresentation.swift:95-103) + `songChangeToastGate(...)` (IslandResolver.swift:87-89) both evaluated in `handleNowPlaying` (NotchWindowController.swift:1036-1041) before setting `nowPlayingState.songChangeToast` and calling `scheduleToastDismiss()`. Rendered by `mediaWingsOrToast`/`toastTextRow` (NotchPillView.swift:315-369) as row 2 fading in under the unchanged wings row, auto-cleared after `songToastDuration` (2.0s, NotchWindowController.swift:171,1095-1105). The 2.0s value (vs ROADMAP's "~3s") is a user-directed, on-device-approved deviation from round 5 of the Task 3 checkpoint (18-02-SUMMARY.md Deviations #5) — accepted per this verification's scope note above. |
| 2 | The toast does not fire for the first track after launch, or for pause/resume/scrub of the same track | ✓ VERIFIED | `songChangeToastContent` guards `hasPlayedSinceLaunch` (Pitfall 2) then `isSameTrack(previous, current)` reused verbatim (Pitfall 1/D-01) — no new string comparison. `hadPlayedSinceLaunch` is captured PRE-mutation at NotchWindowController.swift:997, before the launch-gate flag flips at line 1005. Covered by 5 unit tests in `NowPlayingPresentationTests.swift` (testSongChangeToastContentNilWhenNotYetPlayedSinceLaunch, testSongChangeToastContentNilForSameTrackPlayPause, etc.), test-build-verified (`TEST BUILD SUCCEEDED`). |
| 3 | Settings' Activities tab has a toggle for the song-change toast, positioned next to the existing Now Playing toggle | ✓ VERIFIED | `ActivitySettings.songChangeToastKey` (ActivitySettings.swift:17) + `@AppStorage(...) private var songChangeToastEnabled = true` (SettingsView.swift:32) + `Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)` (SettingsView.swift:137), positioned directly after `Toggle("Now Playing", ...)` per the plan's exact insertion point. |
| 4 | Turning the toggle off suppresses the toast on subsequent changes, and live-clears an in-flight toast, while the Now Playing glance keeps working normally | ✓ VERIFIED | `songChangeToastGate`'s `toastEnabled` param reads `activityEnabled(ActivitySettings.songChangeToastKey)` (NotchWindowController.swift:1037) gating future triggers; `handleSettingsChanged()` has a dedicated branch (lines 908-913) that cancels `toastDismissWorkItem` and clears `nowPlayingState.songChangeToast` live when the toggle flips off, mirroring but fully separate from the pre-existing `nowPlayingKey` disable branch (lines 896-904) — `presentation`/`artwork`/`position` (the ambient Now Playing glance) are untouched by this branch. |
| 5 | D-02: an active charging/device transient suppresses the toast entirely (never queued, never shown after) | ✓ VERIFIED | `songChangeToastGate(activeTransient: transientQueue.head, ...)` returns `false` whenever `activeTransient != nil`, and the toast field is a separate `@Published` property never entering `ActiveTransient`/`TransientQueue` — no queueing path exists. Covered by testSongChangeToastGateSuppressedByChargingTransient / ...DeviceTransient. |
| 6 | Interruption live-clear: a toast already showing clears immediately when a new transient starts or the user manually expands, and never reappears afterward (RESEARCH.md Pitfall 5) | ✓ VERIFIED | `presentTransientChange()` (NotchWindowController.swift:486-499) clears the toast as the first statement inside its spring block, fired only on the `nil`→non-nil transient-head transition. `handleClick()` (lines 744-759) captures `wasExpanded` and clears the toast only on the `false`→`true` expand transition. Both are the single correct choke points per the plan's own call-site analysis (verified by reading `TransientQueue.enqueue`'s contract and confirming `handleClick` is the only `isExpanded` `false→true` setter). |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NowPlayingPresentation.swift` | `TrackToast` + `songChangeToastContent(...)` | ✓ VERIFIED | Lines 82-103, reuses `isSameTrack` verbatim |
| `Islet/Notch/NowPlayingState.swift` | `songChangeToast: TrackToast?` published field | ✓ VERIFIED | Line 33, default nil, separate from `presentation` |
| `Islet/Notch/IslandResolver.swift` | `songChangeToastGate(...)` pure gate | ✓ VERIFIED | Lines 87-89, standalone, never called by `resolve(...)` |
| `Islet/ActivitySettings.swift` | `songChangeToastKey` | ✓ VERIFIED | Line 17 |
| `Islet/SettingsView.swift` | `songChangeToastEnabled` + Toggle | ✓ VERIFIED | Lines 32, 137 |
| `Islet/Notch/NotchWindowController.swift` | Controller wiring: detection, dismiss timer, toggle-off + interruption live-clear | ✓ VERIFIED | `toastDismissWorkItem` (164), `songToastDuration` (171), trigger (1036-1041), `scheduleToastDismiss` (1095-1105), toggle-off clear (908-913), `presentTransientChange` clear (493-496), `handleClick` clear (752-755) |
| `Islet/Notch/NotchPillView.swift` | Toast render, final round-3 design | ✓ VERIFIED | `mediaWingsOrToast` (315-334), `mediaWingsRow` (340-350), `toastTextRow` (359-369), `toastExtraHeight` constant (128) |
| `IsletTests/NowPlayingPresentationTests.swift` | 5 new regression tests | ✓ VERIFIED | Lines 116-152, all 5 named tests present |
| `IsletTests/IslandResolverTests.swift` | 5 new regression tests | ✓ VERIFIED | Lines 131-155, all 5 named tests present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `songChangeToastContent(...)` | `isSameTrack(_:_:)` | direct call | ✓ WIRED | `guard !isSameTrack(previous, current)` at NowPlayingPresentation.swift:98 |
| `SettingsView Toggle` | `ActivitySettings.songChangeToastKey` | `@AppStorage` | ✓ WIRED | SettingsView.swift:32 |
| `handleNowPlaying` | `songChangeToastContent` + `songChangeToastGate` | both evaluated pre-mutation | ✓ WIRED | NotchWindowController.swift:1036-1041, both conditions in one `if` before any `songChangeToast` assignment (Pitfall 3 respected) |
| `scheduleToastDismiss` | `NowPlayingState.songChangeToast` | one-shot `DispatchWorkItem` | ✓ WIRED | Lines 1095-1105, touches only `songChangeToast`, never `presentation`/`artwork`/`position` |
| `NotchPillView.mediaWingsOrToast` | `NowPlayingState.songChangeToast` | direct read | ✓ WIRED | NotchPillView.swift:316, `.nowPlayingWings(let p):` case calls `mediaWingsOrToast(p)` (line 150) |
| `handleSettingsChanged` | `toastDismissWorkItem` / `songChangeToast` | live-clear branch | ✓ WIRED | Lines 908-913 |
| `presentTransientChange` / `handleClick` | `NowPlayingState.songChangeToast` | live-clear on interruption | ✓ WIRED | Lines 493-496, 752-755 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `toastTextRow` (NotchPillView) | `nowPlaying.songChangeToast` | `handleNowPlaying` → `songChangeToastContent(previous:current:hasPlayedSinceLaunch:)`, fed by the real MediaRemote adapter snapshot (`TrackSnapshot` → `nowPlayingPresentation(from:)`) | Yes — same classified `NowPlayingPresentation` pipeline the existing ambient glance already renders, no static/hardcoded fallback | ✓ FLOWING |

### Behavioral Spot-Checks

Not run as automated commands — this is a native macOS GUI app with no headless entry point
(`xcodebuild test` is documented as hanging headless per project memory
`xcodebuild-test-headless-hang`). Instead:
- `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → **BUILD SUCCEEDED** (re-run by this verifier).
- `xcodebuild build-for-testing -scheme Islet -destination 'platform=macOS' -configuration Debug` → **TEST BUILD SUCCEEDED** (re-run by this verifier, confirms all 10 new regression tests compile).
- The on-device behavioral checkpoint (Task 3, 18-02-PLAN.md) was already run by the human during execution across 5 iteration rounds and explicitly approved — see scope note above. Not re-run here (would require live playback hardware/session).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| NOW-05 | 18-01-PLAN.md, 18-02-PLAN.md | Brief toast on genuine song change, not on first track after launch | ✓ SATISFIED | Truths 1, 2, 5, 6 above |
| NOW-06 | 18-01-PLAN.md, 18-02-PLAN.md | Settings toggle for the toast | ✓ SATISFIED | Truths 3, 4 above |

No orphaned requirements — REQUIREMENTS.md maps only NOW-05/NOW-06 to Phase 18, both declared in both plans' frontmatter.

**Bookkeeping note (non-blocking):** `.planning/REQUIREMENTS.md`'s checkboxes for NOW-05/NOW-06
are still `[ ]` unchecked and the Traceability table still reads "Pending", even though
ROADMAP.md's Phase 18 entry and Progress table are correctly marked complete. This is the
known `gsd phase-complete` bookkeeping gap (does not update REQUIREMENTS.md) documented in this
project's own memory — it does not affect the code-level goal achievement verified above, but
should be hand-corrected for traceability hygiene.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`HACK`/`PLACEHOLDER` markers, no empty stub implementations, no
hardcoded-empty data paths in any of the 7 files this phase modified.

### Human Verification Required

None outstanding. The phase's one `checkpoint:human-verify` gate (Task 3, 18-02-PLAN.md) was
already executed and approved by the user during phase execution (5 iteration rounds,
documented in 18-02-SUMMARY.md's Deviations section and reflected in the final
`18-UI-SPEC.md`). Per this verification's scope note, that approval is treated as the completed
human-verification evidence for this phase's visual/interactive behavior — no further human
check is requested.

### Gaps Summary

None. All 6 derived truths (covering ROADMAP's 4 Success Criteria plus D-02/D-03/D-04/Pitfall
5 nuances from CONTEXT.md/RESEARCH.md) are verified against the actual codebase, all artifacts
exist and are wired end-to-end (not orphaned, not stubs), the build and test-build both succeed,
and no debt markers are present. The only non-code discrepancy found — stale REQUIREMENTS.md
checkboxes — is a documentation bookkeeping gap, not a goal-achievement gap.

---

*Verified: 2026-07-09T17:15:00Z*
*Verifier: Claude (gsd-verifier)*
