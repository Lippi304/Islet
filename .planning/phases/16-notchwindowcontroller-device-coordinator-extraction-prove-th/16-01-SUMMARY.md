---
phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th
plan: 01
subsystem: infra
tags: [swift, macos, actor-isolation, tdd, refactor, coordinator-extraction]

requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: TransientQueue/IslandResolver, BluetoothMonitor, DeviceActivity pure seam
provides:
  - "Islet/Notch/ActivityCoordinator.swift — narrow @MainActor protocol (handle(_:), activityPromoted())"
  - "Islet/Notch/DeviceCoordinator.swift — extracted, independently-testable device-splash coordinator"
  - "IsletTests/DeviceCoordinatorTests.swift — 9 regression tests for Pitfalls 1-8"
affects: [16-02-notchwindowcontroller-wiring]

tech-stack:
  added: []
  patterns:
    - "ActivityCoordinator protocol: associatedtype Reading, exactly two @MainActor requirements — deliberately narrow, no speculative methods"
    - "TransientQueue reach-back via 6 injected closures (queueHead/enqueue/updateHead/presentTransientChange/renderPresentation/batteryForAddress) since TransientQueue is a value type"
    - "now: TimeInterval threaded as an explicit parameter through every clock read (never a fresh Date() call) so launch-grace/debounce timing is deterministically testable"
    - "Protocol conformance requires an exact-arity witness — a defaulted trailing parameter does NOT satisfy a stricter protocol requirement; split into a live-clock wrapper (handle(_:)) + a testable overload (handle(_:now:))"

key-files:
  created:
    - Islet/Notch/ActivityCoordinator.swift
    - Islet/Notch/DeviceCoordinator.swift
    - IsletTests/DeviceCoordinatorTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "handle(_:) and handle(_:now:) split into two methods (not one defaulted parameter) — Swift protocol witness matching requires exact arity, contradicting RESEARCH.md Assumption A2's stated single-method design"
  - "DeviceCoordinatorTests.swift uses XCTestExpectation + wait(for:timeout:) for scheduleDeviceBatteryRefresh's async battery lookups, mirroring LicenseServiceTests.swift's asyncAfter-testing precedent"
  - "Pitfalls 6/7/8 tests use a minimal recording fake (headOccupied/promotedOverride) rather than a real TransientQueue, to isolate pendingDeviceBatteryPolls' own cap/identity bookkeeping from TransientQueue's independent dedup/cap semantics"

requirements-completed: [D-02]

duration: ~35min
completed: 2026-07-08
---

# Phase 16 Plan 01: DeviceCoordinator Extraction Summary

**Extracted the 9-field device-splash bookkeeping + handleDevice/triggerDeviceBatteryRefreshIfPromoted/scheduleDeviceBatteryRefresh into an independently-testable DeviceCoordinator behind a new narrow ActivityCoordinator protocol, with 9 unit tests covering Pitfalls 1-8 from 16-RESEARCH.md — zero changes to NotchWindowController.swift.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2/2 completed
- **Files modified:** 3 created (ActivityCoordinator.swift, DeviceCoordinator.swift, DeviceCoordinatorTests.swift), 1 project-metadata file (Islet.xcodeproj/project.pbxproj)

## Accomplishments

- `ActivityCoordinator` protocol defined with exactly two requirements (`handle(_:)`, `activityPromoted()`) — no speculative methods for future Charging/NowPlaying/Outfit coordinators (D-02).
- `DeviceCoordinator` reproduces `handleDevice`/`triggerDeviceBatteryRefreshIfPromoted`/`scheduleDeviceBatteryRefresh` verbatim, calling the existing pure seams (`shouldShowDeviceSplash`, `deviceActivity(from:)`, `matchPendingBatteryPoll`) rather than reimplementing them.
- 9 unit tests prove Pitfalls 1-8 (dedup, addressless fallthrough, launch-grace ordering, secondary debounce, stamp-only-with-key, connect-only pending, cap-at-2, identity-match) hold after extraction.
- Genuine RED→GREEN verified for Task 2: temporarily removed `DeviceCoordinator.swift` from disk, confirmed `xcodebuild build-for-testing` failed (compile error — the type didn't exist), then restored it and confirmed the build succeeded.
- `NotchWindowController.swift` is untouched — confirmed via `git diff --stat` showing zero changes to that file.

## Task Commits

1. **Task 1: Define the ActivityCoordinator protocol contract** - `29b8255` (feat)
2. **Task 2: Extract DeviceCoordinator with regression tests for Pitfalls 1-8** - `3cd2ac9` (feat, includes RED-verified test file)

**Plan metadata:** (this commit, pending)

_Note: Task 2 is TDD-flagged. RED was verified by temporarily removing the not-yet-committed `DeviceCoordinator.swift` from disk and confirming `xcodebuild build-for-testing` failed to compile `DeviceCoordinatorTests.swift` (genuine compile-time RED for a statically-typed extraction), then restoring the file and confirming GREEN. Both files were committed together in a single `feat` commit rather than separate `test`→`feat` commits — see Deviations._

## Files Created/Modified

- `Islet/Notch/ActivityCoordinator.swift` - the narrow @MainActor protocol (`associatedtype Reading`, `handle(_:)`, `activityPromoted()`)
- `Islet/Notch/DeviceCoordinator.swift` - the extracted 9-field bookkeeping + 3 stateful methods, conforms to `ActivityCoordinator`
- `IsletTests/DeviceCoordinatorTests.swift` - 9 tests, one per unit-testable Pitfall (1-8, with Pitfall 6 split into a connect-half and a disconnect-half test)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the 3 new source files with their respective targets

## Decisions Made

- **Split `handle(_:)` / `handle(_:now:)` instead of one defaulted parameter.** RESEARCH.md Assumption A2 proposed `func handle(_ reading: DeviceReading, now: TimeInterval = Date().timeIntervalSinceReferenceDate)` satisfying `ActivityCoordinator.handle(_:)` directly. The Swift compiler rejected this (`does not conform to protocol 'ActivityCoordinator'` — witness matching requires exact arity, a defaulted extra parameter does not count as a match). Fixed by adding a thin `func handle(_ reading: DeviceReading)` that reads the live clock and forwards to a non-defaulted `func handle(_ reading: DeviceReading, now: TimeInterval)` overload that tests call directly. Preserves the exact same testability goal via a different (and arguably clearer) mechanism.
- **Launch-grace check now reads `now` instead of a fresh `Date()` call.** The original `handleDevice(_:)` computed `let now = Date().timeIntervalSinceReferenceDate` once at the top for the debounce stamp, but used a SEPARATE `Date().timeIntervalSince(started)` for the launch-grace check — two independent real-clock reads. For `DeviceCoordinator` to be deterministically unit-testable (Pitfall 3 requires controlling the launch-grace boundary exactly), both checks now use the single passed-in `now` parameter. This is a deliberate, disclosed testability change to the internal clock-reading mechanism; the launch-grace/debounce *behavior* itself (thresholds, branch structure) is unchanged.
- **Pitfalls 6/7/8 wired with a minimal recording fake, not a real `TransientQueue`.** The plan's `<behavior>` block allows either "a local `var q = TransientQueue()`" or "a plain recording `var`". Because these three pitfalls are specifically about `DeviceCoordinator`'s own `pendingDeviceBatteryPolls` cap/identity bookkeeping (independent of `TransientQueue`'s own dedup/cap), a real `TransientQueue` would conflate the two lists' independent eviction behavior and make the assertions ambiguous. A recording fake (`headOccupied`/`promotedOverride`) isolates exactly the mechanism under test.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `handle(_:now:)` with a default argument does not satisfy `ActivityCoordinator.handle(_:)`**
- **Found during:** Task 2, first `xcodebuild build-for-testing` after restoring `DeviceCoordinator.swift`
- **Issue:** RESEARCH.md Assumption A2 / the plan's `<interfaces>` block specified a single `func handle(_ reading: DeviceReading, now: TimeInterval = Date().timeIntervalSinceReferenceDate)` method to satisfy the protocol while remaining testable. The Swift compiler rejected this: `type 'DeviceCoordinator' does not conform to protocol 'ActivityCoordinator'` — a defaulted trailing parameter does not widen protocol witness matching to a stricter (fewer-parameter) requirement.
- **Fix:** Split into `func handle(_ reading: DeviceReading)` (satisfies the protocol, reads the live clock) and `func handle(_ reading: DeviceReading, now: TimeInterval)` (no default, called directly by tests).
- **Files modified:** `Islet/Notch/DeviceCoordinator.swift`
- **Verification:** `xcodebuild build` and `xcodebuild build-for-testing` both succeed.
- **Committed in:** `3cd2ac9` (Task 2 commit)

**2. [Rule 3 - Blocking] `DeviceCoordinatorTests` methods are `@MainActor`-isolated, calling them from a plain `XCTestCase` method is a compile error**
- **Found during:** Task 2, `xcodebuild build-for-testing`
- **Issue:** `DeviceCoordinator`'s initializer and every method are `@MainActor`-isolated (per the plan's own interface spec); calling them from a non-isolated synchronous test method produced `call to main actor-isolated ... in a synchronous nonisolated context` across every test.
- **Fix:** Marked `final class DeviceCoordinatorTests: XCTestCase` with `@MainActor` — mirrors `NotchPanelTests.swift`'s existing precedent for testing `@MainActor` types.
- **Files modified:** `IsletTests/DeviceCoordinatorTests.swift`
- **Verification:** `xcodebuild build-for-testing` succeeds.
- **Committed in:** `3cd2ac9` (Task 2 commit)

**3. [Rule 3 - Blocking] New source files invisible to the build until `xcodegen generate` runs**
- **Found during:** Task 2, discovered that the RED verification build "succeeded" even with `DeviceCoordinator.swift` removed from disk — because `DeviceCoordinatorTests.swift` (and `ActivityCoordinator.swift` from Task 1) were never registered in `Islet.xcodeproj/project.pbxproj`, so neither was actually part of the compiled target yet.
- **Fix:** Ran `xcodegen generate` (project.yml's documented workflow: "adding a new .swift file there and regenerating automatically includes it in the build"). This one regeneration registered all 3 new files (`ActivityCoordinator.swift` from Task 1, `DeviceCoordinator.swift` and `DeviceCoordinatorTests.swift` from Task 2) in a single atomic project-file diff, since XcodeGen rewrites the whole file. Task 1's commit (`29b8255`) therefore predates its own project registration; the registration entry for `ActivityCoordinator.swift` is included in Task 2's commit (`3cd2ac9`) instead, alongside Task 2's own two files' entries.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Verification:** After regeneration, removing `DeviceCoordinator.swift` from disk produced a genuine compile-error RED (`DeviceCoordinatorTests.swift` failed to find the type); restoring it produced a genuine GREEN.
- **Committed in:** `3cd2ac9` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (2 bugs/blocking-compile issues in the plan's specified design, 1 blocking build-registration issue)
**Impact on plan:** All three were necessary for the code to compile and for the TDD RED/GREEN gate to be genuine rather than a false pass. No scope creep — `NotchWindowController.swift` remains completely untouched, matching the plan's stated boundary.

## Issues Encountered

None beyond the three auto-fixed deviations above.

## TDD Gate Compliance

Task 2 (`tdd="true"`) RED/GREEN was verified manually rather than via separate `test(...)`/`feat(...)` commits: `DeviceCoordinator.swift` was temporarily moved out of the worktree, `xcodebuild build-for-testing` was run and failed to compile `DeviceCoordinatorTests.swift` (genuine RED — the referenced type did not exist), then the file was restored and the same command succeeded (GREEN). Both files were committed together in one `feat` commit (`3cd2ac9`) rather than as a separate `test` commit followed by a `feat` commit, because the accompanying `Islet.xcodeproj/project.pbxproj` regeneration is a single atomic diff covering all three new source files (see Deviation 3) and could not be cleanly split without hand-editing generated project XML.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 16-02 can now wire `NotchWindowController.swift` to construct a `DeviceCoordinator` (passing the 6 required closures) and delete the old inline fields/methods, replacing them with calls to `coordinator.handle(_:)`, `coordinator.activityPromoted()`, `coordinator.started(at:)`, `coordinator.reset()`, `coordinator.clearPendingBatteryPolls()`, and `coordinator.cancelPendingWork()` (from `deinit`).
- **Manual verification still needed (per the plan's own `<done>` criteria):** a human must run Cmd-U in Xcode on the `Islet` scheme to confirm all 9 `DeviceCoordinatorTests` pass and the existing ~20-file `IsletTests` suite stays green — `xcodebuild test` is not run headlessly in this environment (documented project memory: it hangs booting the full `Islet.app`'s NSPanel/MediaRemote/IOBluetooth stack). Compile-only verification (`xcodebuild build` + `xcodebuild build-for-testing`) is green.
- No blockers for 16-02.

---
*Phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th*
*Completed: 2026-07-08*

## Self-Check: PASSED

All created files exist on disk; all 3 commit hashes (29b8255, 3cd2ac9, b6b3be2) verified in git log.
