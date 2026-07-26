---
phase: 65-quick-actions-bar
plan: 08
subsystem: ui
tags: [swiftui, debug-spike, quick-actions, on-device-verification, focus-mode]

requires:
  - phase: 65-02
    provides: DisplaySleepAction.sleepNow() / ScreenLockAction.lockNow() / CaffeinateToggleAction.toggle()
  - phase: 65-03
    provides: DarkModeToggleAction.toggle(completion:) / EmptyTrashAction.empty(completion:) / LaunchAction.launch(target:)
  - phase: 65-04
    provides: FocusToggleAction.toggle(onResult:)
  - phase: 65-07
    provides: NotchWindowController.handleQuickActionTap(_:slotIndex:) — full controller wiring for all 9 catalog actions
provides:
  - "QuickActionsBarManualSpike — a #if DEBUG-only enum with one NSLog-marked static function per catalog action, for fast on-device iteration"
  - "FocusToggleAction now self-requests INFocusStatusCenter authorization and dispatches to one of two fixed one-way Shortcuts (Islet Focus On / Islet Focus Off) instead of a single non-functional toggling Shortcut"
  - "All 8 Quick Actions confirmed working end-to-end on real hardware, including Screen Lock (RESEARCH.md A2) and DND in both directions"
affects: []

tech-stack:
  added: []
  patterns:
    - "Mirrors NowPlayingMonitor.swift's spikeLikeCurrentTrack/spikeTriggerAutomationPrompt convention: NSLog-marked, #if DEBUG-gated, throwaway"
    - "One-way Shortcut pair (On/Off) selected at call time from an already-read 'before' state, used where Shortcuts has no native toggle action for a given system feature"

key-files:
  created:
    - Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift
  modified:
    - Islet.xcodeproj/project.pbxproj
    - Islet/Notch/QuickActionsBar/FocusToggleAction.swift
    - Islet/SettingsView.swift
    - IsletTests/FocusToggleActionTests.swift

key-decisions:
  - "QuickActionsBarManualSpike enum marked @MainActor (not per-function) to satisfy FocusToggleAction.toggle's own MainActor isolation — same actor context every other spike call already runs in anyway"
  - "FocusToggleAction.toggle now calls FocusModeMonitor.requestAuthorization itself rather than only reading isAuthorized — Focus authorization is no longer implicitly dependent on the user having touched the unrelated Phase-38 Focus HUD Settings toggle first"
  - "DND uses two fixed one-way Shortcuts (Islet Focus On / Islet Focus Off), selected at runtime from the already-read 'before' state, because Shortcuts' Set Focus action has no native toggle mode"

requirements-completed: [QACTION-01, QACTION-02, QACTION-03]

duration: ~45min (Task 1 + 2 on-device UAT rounds)
completed: 2026-07-26
---

# Phase 65 Plan 08: On-Device Verification Summary

**All 8 Quick Actions confirmed working end-to-end on real hardware (mic mute, display sleep, dark/light mode, Screen Lock, DND, keep-awake, empty Trash, launch app/URL) after two real on-device bugs in Focus/DND authorization and Shortcut selection were found and fixed during UAT — closing out QACTION-01/02/03 and Phase 65.**

## Performance

- **Duration:** ~45 min (Task 1 build/verify + on-device UAT rounds that surfaced the two DND fixes)
- **Tasks:** 2 of 2 completed
- **Files modified:** 5 (1 created, 4 modified across Task 1 and the two UAT gap-closure commits)

## Accomplishments
- `Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift` created — `enum QuickActionsBarManualSpike` entirely inside a single `#if DEBUG ... #endif` block, `@MainActor`-isolated, with 8 static functions (`spikeMicMute`, `spikeDisplaySleep`, `spikeDarkMode`, `spikeScreenLock`, `spikeFocusToggle`, `spikeCaffeinate`, `spikeEmptyTrash`, `spikeLaunch`) each calling straight into the real Plan 65-02/65-03/65-04 helper, NSLog-marked per the `NowPlayingMonitor.swift` convention
- Debug build: `BUILD SUCCEEDED`. Release build: `BUILD SUCCEEDED`. Object-file symbol check (`nm`) confirmed 19 spike-related symbols in Debug vs. 0 in Release — the `#if DEBUG` gate genuinely excludes the file from the shipped binary, closing threat T-65-14
- On-device UAT (Task 2) exercised all 8 tiles: mic mute, display sleep, dark/light mode, Screen Lock (RESEARCH.md A2's previously-unconfirmed claim — **confirmed working** on the current macOS version), keep-awake, empty Trash (no confirmation dialog), and launch-app/URL all passed on the first pass ("Klappt soweit alles")
- DND failed on first pass (silent failure flash regardless of Shortcut setup, then a working "on" but never "off") — root-caused and fixed live during UAT via two follow-up commits (see Deviations below); user re-tested after both fixes and confirmed DND now toggles correctly in both directions
- Mic-mute state parity between the Quick Actions bar and Meeting-HUD, and the Quick Actions Settings-toggle-OFF fallback-to-Home behavior, both confirmed as part of the same UAT pass

## Task Commits

Each task was committed atomically:

1. **Task 1: QuickActionsBarManualSpike.swift** - `a76afef` (feat)
2. **Task 2: On-device checkpoint** - approved by user; 2 gap-closure fixes committed during UAT: `ae16b9a` (fix), `d542785` (fix)

**Plan metadata:** partial-state doc commit `cfdfdb6` (docs, superseded by this final summary)

## Files Created/Modified
- `Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift` - new `#if DEBUG`-only spike enum, one function per catalog action
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new source file in the build target
- `Islet/Notch/QuickActionsBar/FocusToggleAction.swift` - `toggle()` now self-requests `INFocusStatusCenter` authorization (`ae16b9a`) and picks between `focusOnShortcutName`/`focusOffShortcutName` one-way Shortcuts based on the already-read `before` state (`d542785`)
- `Islet/SettingsView.swift` - DND config-popover hint text updated to name both required Shortcuts instead of one (`d542785`)
- `IsletTests/FocusToggleActionTests.swift` - stale comment updated to match the new authorization-request behavior (`ae16b9a`)

## Decisions Made
- The spike enum is marked `@MainActor` at the enum level (not per-function) because `FocusToggleAction.toggle(onResult:)` is itself `@MainActor`-isolated — matching that file's own documented rationale rather than isolating just the one function that needed it.
- DND's one-Shortcut design (locked at Plan 65-04) is superseded by a two-Shortcut one-way design, discovered necessary only once tested against the real Shortcuts app: Apple's "Set Focus" action has no native toggle mode, so a single Shortcut could only ever turn Focus on, never off.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `@MainActor` isolation error on `spikeFocusToggle()`**
- **Found during:** Task 1 (initial Debug build)
- **Issue:** `FocusToggleAction.toggle(onResult:)` is `@MainActor`-isolated; calling it from a non-isolated static function failed to compile
- **Fix:** Added `@MainActor` to the `QuickActionsBarManualSpike` enum declaration
- **Files modified:** `Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift`
- **Verification:** Debug and Release builds both succeeded after the fix
- **Committed in:** `a76afef` (Task 1 commit — caught before any commit was made)

**2. [Rule 1 - Bug] DND tap silently failed for users who never opened the Focus HUD Settings toggle**
- **Found during:** Task 2 on-device UAT
- **Issue:** `FocusToggleAction.toggle()` only read `FocusModeMonitor.isAuthorized`, which was previously set true only via the unrelated Phase-38 Focus HUD Settings toggle. A user who never touched that toggle got a silent, unexplained failure flash on every DND tap regardless of Shortcut setup.
- **Fix:** `toggle()` now calls `FocusModeMonitor.requestAuthorization` itself before running the shortcut, mirroring `SettingsView`'s own call site (same main-thread re-dispatch). `IsletTests/FocusToggleActionTests.swift`'s stale comment updated to match.
- **Files modified:** `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`, `IsletTests/FocusToggleActionTests.swift`
- **Verification:** User re-tested on-device after the fix (still surfaced the second bug below before DND fully worked)
- **Committed in:** `ae16b9a` (fix, applied directly by the orchestrator during the live UAT session)

**3. [Rule 1 - Bug] Single "Islet Toggle Focus" Shortcut could only ever turn DND on, never off**
- **Found during:** Task 2 on-device UAT (second-tap-doesn't-turn-off report, after fix #2 above)
- **Issue:** Apple's "Set Focus" Shortcuts action has no native toggle mode — it must be built as a fixed "Turn On" or "Turn Off". The plan's originally-documented single "Islet Toggle Focus" Shortcut name could therefore only ever turn Focus on.
- **Fix:** `FocusToggleAction` now exposes `focusOnShortcutName = "Islet Focus On"` and `focusOffShortcutName = "Islet Focus Off"`, and `toggle()` picks between them at runtime using the `before` state it already reads — no conditional logic needed inside the Shortcut itself. `SettingsView.swift`'s config-popover hint text updated to name both required Shortcuts.
- **Files modified:** `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`, `Islet/SettingsView.swift`
- **Verification:** User created both Shortcuts and confirmed DND toggles correctly in both directions on-device
- **Committed in:** `d542785` (fix, applied directly by the orchestrator during the live UAT session)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - bugs)
**Impact on plan:** All three necessary for the feature to actually work as specified — none is scope creep. Deviations #2 and #3 are exactly the kind of real, on-device-only bug this plan's checkpoint exists to catch (the RESEARCH.md Open Question 1 area was already flagged as the phase's single riskiest unknown).

## Issues Encountered

Initial `grep -c "#if DEBUG"` returned 2 instead of the plan's required 1 during Task 1, because the file's own header comment used the literal string "#if DEBUG" in prose. Reworded the comment to "Debug-only" — trivial wording fix, not tracked as a formal deviation.

## User Setup Required

The user must create two Shortcuts named exactly `Islet Focus On` (a single "Set Focus" action, Turn On) and `Islet Focus Off` (a single "Set Focus" action, Turn Off) for the DND Quick Action to function — documented in-app via `SettingsView`'s config-popover hint text when a slot is configured as Do Not Disturb. User has already created both and confirmed on-device.

## Next Phase Readiness

Phase 65 (Quick Actions Bar) is fully code-complete and on-device verified. QACTION-01/02/03 all confirmed end-to-end, including the one previously-unconfirmed technical claim (Screen Lock, RESEARCH.md A2) and the one genuinely uncertain integration point (DND/Focus, RESEARCH.md Open Question 1) — both closed with real findings rather than assumptions. No blockers for phase close.

## Self-Check: PASSED

- `Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift`: FOUND
- `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`: FOUND, contains `requestAuthorization` and `focusOnShortcutName`/`focusOffShortcutName`
- Commit `a76afef`: FOUND in `git log --oneline --all`
- Commit `ae16b9a`: FOUND in `git log --oneline --all`
- Commit `d542785`: FOUND in `git log --oneline --all`
- `grep -c "#if DEBUG"` returns 1, `grep -c "#endif"` returns 1 on the spike file: CONFIRMED
- Debug build (post-fixes, `xcodegen generate` re-run): BUILD SUCCEEDED
- No unexpected file deletions in any of the three commits

---
*Phase: 65-quick-actions-bar*
*Completed: 2026-07-26*
