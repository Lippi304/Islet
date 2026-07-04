---
phase: 09-fullscreen-flash-window-space-retry
plan: 01
subsystem: ui
tags: [macos, appkit, cgs, private-api, notch, fullscreen, window-management]

requires:
  - phase: 08-fullscreen-enter-flash-elimination
    provides: "the ruled-out CGSClientEnterFullscreen/CGSClientExitFullscreen candidate + the escalation report that surfaced Candidate C (CGS Space) as the prioritized retry"
provides:
  - "Islet/Notch/CGSSpace.swift — a dedicated max-level private CGS Space wrapper (7 silgen_name-bound symbols + connection lookup, D-02 amendment ceiling)"
  - "NotchWindowController wired to join/leave that Space exactly once per panel lifetime, additive to the existing .canJoinAllSpaces collectionBehavior"
affects: []

tech-stack:
  added: []
  patterns:
    - "CGSSpace wrapper: didSet on windows: Set<NSWindow> diffs old/new membership into CGSRemoveWindowsFromSpaces/CGSAddWindowsToSpaces calls"
    - "One-time Space-join at panel construction (inside positionAndShow's `if self.panel == nil` guard), never re-synced per show/hide cycle"

key-files:
  created:
    - Islet/Notch/CGSSpace.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Implemented the ADDITIVE/layered Candidate C variant only (NotchPanel.collectionBehavior untouched) — the only combination with real shipping precedent per 09-RESEARCH.md; removing .canJoinAllSpaces is deliberately deferred to a separate follow-up, never combined with this attempt"

patterns-established:
  - "Private CGS Space symbol bindings mirror FullscreenSpaceProbe.swift's @_silgen_name convention but keep a fully self-contained (UInt-typed) connection-ID binding to avoid an ABI mismatch with the existing Int32-typed CGSMainConnectionID"

requirements-completed: [FS-01]

duration: ~45min (Tasks 1-2) + on-device verification (Task 3, user-run)
completed: 2026-07-04
---

# Phase 9 Plan 1: Additive CGS Space (Candidate C) — FS-01 resolved, option-accept

**Added a dedicated max-level private CGS Space (`Islet/Notch/CGSSpace.swift`) that the notch panel now joins once at creation, layered alongside its unchanged `.canJoinAllSpaces` collection behavior — the structural fix targeting the fullscreen-enter flash's root cause (per-Space auto-join race). On-device verification (Task 3) confirms the flash is completely eliminated across all 3 trigger methods with zero regressions across the full 8-item checklist. Decision: option-accept — FS-01 is resolved by this plan alone; plans 09-02 through 09-05 do not execute.**

## Performance

- **Duration:** ~45 min (Tasks 1-2) + on-device verification session (Task 3, user-run on real notch hardware)
- **Started:** 2026-07-04T13:23:00Z (approx, worktree agent spawn)
- **Completed:** 2026-07-04 (Task 3 decision recorded)
- **Tasks:** 3 of 3 completed (Task 3 is an on-device checkpoint:decision, `autonomous: false` — executed by the user, decision relayed to and recorded by this continuation agent)
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `Islet/Notch/CGSSpace.swift` — the verbatim, verified-against-two-shipping-implementations CGS Space wrapper (7 named private symbols + `_CGSDefaultConnection`, the D-02 amendment's exact ceiling)
- `NotchWindowController` joins the panel to a dedicated `Int32.max`-level Space exactly once, at panel construction — `NotchPanel.collectionBehavior` (`.canJoinAllSpaces`/`.fullScreenAuxiliary`/`.stationary`) is byte-for-byte unchanged
- `xcodebuild build -scheme Islet` succeeds with zero errors after both tasks
- **On-device verification (Task 3) confirms the fullscreen-enter flash is completely gone** across all 3 D-07 trigger methods, with zero regressions across the full 8-item checklist — FS-01 is resolved by this plan alone (option-accept)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the CGSSpace private-symbol wrapper** - `f61c212` (feat)
2. **Task 2: Wire the additive CGSSpace into NotchWindowController** - `b3abac5` (feat)
3. **(docs) Log pre-existing test-hang as out of scope** - `e8670b4` (docs)
4. **(docs) Add partial SUMMARY, Tasks 1-2 complete, Task 3 checkpoint pending** - `bf39457` (docs)

**Task 3 (checkpoint:decision, on-device):** Executed by the user on real notch hardware; decision **option-accept** — see "Task 3: On-Device Verification" below.

## Files Created/Modified
- `Islet/Notch/CGSSpace.swift` - new; the 7-symbol + connection-lookup CGS Space wrapper (create/destroy/level/show/hide/add-to-space/remove-from-space)
- `Islet/Notch/NotchWindowController.swift` - added `private let notchSpace = CGSSpace(level: 2147483647)`, `notchSpace.windows.insert(panel)` in `positionAndShow()`'s panel-creation branch, `notchSpace.windows.remove(panel)` in `deinit`
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` so `CGSSpace.swift` is actually included in the `Islet` target's build sources

## Decisions Made
- Followed 09-RESEARCH.md's primary recommendation exactly: implement Candidate C as an ADDITIVE layer (keep `collectionBehavior` unchanged), not a replacement — the only pattern with real shipping precedent (Atoll, boring.notch). Removing `.canJoinAllSpaces` remains deferred to a separate, later-only follow-up (09-02), never combined with this attempt, per RESEARCH.md's Anti-Patterns guidance and Open Question 2's recommendation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] CGSSpace.swift was not in the Xcode target's source list after Task 1**
- **Found during:** Task 2 (wiring `CGSSpace` into `NotchWindowController`)
- **Issue:** `xcodebuild build` in Task 1 reported `** BUILD SUCCEEDED **` even though `CGSSpace.swift` was never actually compiled — nothing referenced it yet, so its absence from `Islet.xcodeproj/project.pbxproj` (an XcodeGen-managed project; new files require `xcodegen generate` to be picked up) went unnoticed. Task 2's `notchSpace = CGSSpace(level: 2147483647)` then failed with `cannot find 'CGSSpace' in scope`.
- **Fix:** Ran `xcodegen generate` to regenerate `Islet.xcodeproj/project.pbxproj` from `project.yml`, which added `CGSSpace.swift` to both the `PBXFileReference`/group listing and the `Sources` build phase.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Verification:** `xcodebuild build -scheme Islet` succeeds with zero errors; `CGSSpace.swift in Sources` now present in the pbxproj diff.
- **Committed in:** `b3abac5` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for the build to actually include the new file; no scope creep — same file, same content, only the project-file registration was missing.

## Issues Encountered

**`xcodebuild test` hangs indefinitely in this worktree-agent sandbox (pre-existing, NOT caused by this plan).** Task 2's acceptance criterion calls for `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests -only-testing:IsletTests/FullscreenDetectorTests` to pass. Running it hung the host `Islet.app` process (0% CPU, no progress) until XCTest itself gave up after ~5-6 minutes with "The test runner hung before establishing connection." A `sample` of the hung process showed the main thread stuck in `AppDelegate.applicationDidFinishLaunching` → `NotchWindowController.start()` → `startBluetoothMonitor()` → `+[IOBluetoothCoreBluetoothCoordinator sharedInstance]` → `semaphore_wait_trap` (a Bluetooth TCC-authorization wait that never resolves in this non-interactive sandboxed session). **Confirmed pre-existing and unrelated to this plan:** reproduced the identical hang after temporarily reverting `NotchWindowController.swift` to its pre-Task-2 state (CGSSpace wiring completely absent) — the hang is 100% Phase-6 `BluetoothMonitor` code, out of this plan's scope per the Scope Boundary rule. Logged to `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md` (commit `e8670b4`) rather than fixed. `xcodebuild build -scheme Islet` (not `test`) succeeds cleanly and was used as the available automated verification signal instead.

## User Setup Required

None - no external service configuration required.

## Task 3: On-Device Verification — Decision: option-accept

Task 3 (`checkpoint:decision`, `autonomous: false`) required real notch hardware and was run by
the user directly, outside this agent session. Results were reported to the orchestrator and
relayed here for the record.

**Flash check (D-07 trigger matrix, 3 methods x 3 trials each):** PASS for all three —
green-button click, menu-bar "Enter Full Screen", and a fullscreen video app. The user reported
the flash is "komplett weg" (completely gone) across every method tested, with repeated trials
per method.

**Full on-device regression checklist (8 items, D-03 core-behavior suite + D-07 trigger matrix +
Pitfall 3):** PASS — confirmed by user, no issues reported. The user explicitly confirmed all
items were tested ("ja alles mitgetestet") and, when asked directly whether anything was
unremarkable/fine, confirmed no problems were found. Per the plan's evidence granularity, this is
recorded as "confirmed by user, no regressions reported" for each item rather than fabricated
per-item pass/fail detail beyond what was actually reported:

1. Flash check (3 trigger methods x repeated trials) — PASS, flash completely eliminated
2. Hover/click-expand without focus steal — PASS, no issues reported
3. Click-through outside the pill while collapsed — PASS, no issues reported
4. Visibility across multiple (2+) ordinary Spaces — PASS, no issues reported
5. Positioning through display/clamshell changes — PASS, no issues reported
6. Fullscreen hide-during/restore-on-exit (all 3 trigger methods) — PASS, no issues reported
7. Ordinary (non-fullscreen) Space switch — PASS, no issues reported
8. Lock-screen / sleep-wake (Pitfall 3) — PASS, no issues reported

**Zero regressions found.** Per D-04, this clears the bar for option-accept without requiring any
further code changes in this plan.

**Decision: option-accept.** The additive/layered Candidate C (dedicated max-level CGSSpace,
`collectionBehavior` unchanged) eliminates the fullscreen-enter island flash with zero
regressions. **FS-01 is resolved by this plan (Wave 1) alone.** Plans 09-02 through 09-05 —
the `.canJoinAllSpaces`-removal variant and further escalation candidates — do NOT execute; the
phase's conditional chain terminates here. (Their own Task-0 guards would have no-op'd them
regardless, since they are gated on option-continue.)

## Next Phase Readiness
- FS-01 is CLOSED. Tasks 1-3 are all complete: the additive CGSSpace code is committed and
  build-clean, and the on-device decision (option-accept) is recorded with full checklist
  evidence above.
- Phase 09's conditional chain (09-02 through 09-05) does not execute — no further plans in this
  phase are needed.
- The pre-existing `BluetoothMonitor` test-hang (deferred-items.md) is unrelated to FS-01 and
  remains a separately-tracked issue, worth surfacing at `/gsd:verify-work 9` since it currently
  makes `xcodebuild test` unusable from any non-interactive/sandboxed environment.

---
*Phase: 09-fullscreen-flash-window-space-retry*
*Completed: 2026-07-04*

## Self-Check: PASSED
- FOUND: Islet/Notch/CGSSpace.swift
- FOUND commit f61c212 (Task 1)
- FOUND commit b3abac5 (Task 2)
- FOUND commit e8670b4 (docs: deferred-items)
- FOUND commit bf39457 (docs: partial summary)
- FOUND Task 3 decision: option-accept, recorded with full 8-item checklist evidence and 3-method flash-check evidence per plan's resume-signal requirement
