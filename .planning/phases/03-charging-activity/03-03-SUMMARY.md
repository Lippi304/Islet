---
phase: 03-charging-activity
plan: 03
subsystem: system
tags: [iokit, power, charging, controller, event-driven, uat]

# Dependency graph
requires:
  - phase: 03-charging-activity
    plan: 01
    provides: "PowerActivity (PowerReading, ChargingActivity, powerActivity(from:), shouldTriggerSplash) + ChargingActivityState + NotchGeometry.wingsFrame"
  - phase: 03-charging-activity
    plan: 02
    provides: "NotchPillView.wings(for:) sideways layout + D-11 precedence + the placeholder ChargingActivityState seam in NotchWindowController"
provides:
  - "PowerSourceMonitor — thin IOKit glue: readCurrentPower()->PowerReading, IOPSNotificationCreateRunLoopSource, @convention(c) callback + main-thread hop, start()/stop()"
  - "NotchWindowController live charging wiring: owns the monitor + ChargingActivityState + the ~3s dismissWorkItem; connect-only splash gated through the single updateVisibility()"
  - "On-device verified live charging activity (CHG-01): plug-in shows the wings splash (bolt glyph + %) for ~3s then collapses; hidden in fullscreen; idle-CPU event-driven"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "IOKit ownership idiom: Copy/Create -> takeRetainedValue, Get -> takeUnretainedValue; @convention(c) callback recovers self via Unmanaged context pointer then DispatchQueue.main.async before any @Published/AppKit touch"
    - "Event-driven power: the ONLY wake-up is the IOPS notification source (no Timer / DispatchSourceTimer anywhere); the ~3s dismiss is a one-shot DispatchWorkItem mirroring graceWorkItem"
    - "Splash routes through the single updateVisibility() (SOLE orderFront/orderOut site) so it inherits the Phase-2 fullscreen/clamshell hide for free (Pitfall 5)"
    - "didSeedInitialPower seeds the launch reading WITHOUT firing a splash; shouldTriggerSplash gates re-display to a connect edge"

key-files:
  created:
    - Islet/Notch/PowerSourceMonitor.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/PowerActivity.swift
    - IsletTests/PowerActivityTests.swift

key-decisions:
  - "CONNECT-ONLY splash (UAT decision): shouldTriggerSplash fires only on the not-AC -> AC edge. Unplugging shows NOTHING and a within-AC top-off (charging -> full) shows nothing. This intentionally DESCOPES CHG-02's on-battery unplug indication per the user's on-device call."
  - "Wings sized to the MEASURED notch (this machine: 179x32 pt): wingsSize 305x32 — height matches the 32pt notch so the strip is flush (no downward overhang), width 305 extends ~63pt past each notch edge. Tuned live across 360->300->250->270->285->295->305."
  - "PowerSourceMonitor.stop() + runLoopSource made nonisolated so the controller's nonisolated deinit can tear down the IOPS source (T-03-06); powerMonitor is a stored optional assigned in start() (not a lazy var) so the [weak self] closure binds a fully-initialised self."

patterns-established:
  - "Live system-activity loop: IOKit/notification source -> pure mapping (PowerActivity) -> @Published model (ChargingActivityState) -> SwiftUI wings, with a one-shot auto-dismiss and a connect-edge gate. The same shape the Phase-5 Bluetooth (DEV) connect activity will reuse."

requirements-completed: [CHG-01]

# Metrics
duration: ~25min (incl. on-device UAT + tuning loop)
completed: 2026-06-27
---

# Phase 3 Plan 03: Live Charging Activity (IOKit wiring) Summary

**The system glue that makes the charging splash live: a `PowerSourceMonitor` registers an IOKit `IOPSNotificationCreateRunLoopSource`, recovers self via the context pointer and hops to main, and `NotchWindowController` maps each plug/unplug through the pure Plan-01 seam into the published `ChargingActivityState` — showing the wings splash for ~3s through the single `updateVisibility()` (so it's hidden in fullscreen) with no polling timer. On-device UAT passed after two product-tuning changes: the splash is now CONNECT-ONLY (no unplug animation) and the wings are sized to the measured notch (305×32).**

## Performance

- **Duration:** ~25 min (Tasks 1–2 build, then on-device UAT + tuning loop)
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 4 modified, 1 created

## Accomplishments
- `PowerSourceMonitor.swift` (created) — `readCurrentPower() -> PowerReading` lifts the internal-battery state from the IOPS dictionary with correct `Unmanaged` ownership (Copy/Create → retained, Get → unretained) and a defensive optional-cast-with-default for every key (T-03-05); `start()` registers the live notification source, the `@convention(c)` callback recovers self via the context pointer and `DispatchQueue.main.async` before touching anything (T-03-07); `stop()` removes the source (T-03-06). No `Timer` — event-driven only.
- `NotchWindowController` live wiring — owns the monitor + `ChargingActivityState` + a ~3s `dismissWorkItem` (mirroring `graceWorkItem`); `handlePower` maps the reading via `powerActivity(from:)`, gates the splash with `shouldTriggerSplash`, sets `.activity` inside `withAnimation(.spring(0.35/0.65))`, and routes show/hide through the single `updateVisibility()`. Hover pauses the ~3s, pointer-leave resumes it (D-10). Panel sized once to `expandedFrame.union(wings)` (Pattern 4). `deinit` tears down the source.
- **On-device UAT (Task 3) — PASSED** (Tahoe, real power events): plug-in shows the bolt-glyph wings splash + % for ~3s then collapses (CHG-01); the splash stays hidden in fullscreen; idle CPU ~0% after collapse (event-driven). Two product changes were made live from the user's feedback (below).
- Full automated suite green: **72 tests, 0 failures** (was 68; +4 lock tests for the connect-only matrix).

## Task Commits

1. **Task 1: PowerSourceMonitor — IOKit reader + live notification source** — `6abbd2d` (feat)
2. **Task 2: wire live charging activity into NotchWindowController** — `f7cae04` (feat)
3. **Task 3 (UAT-driven tuning):**
   - `7489657` (fix) — charging splash fires on **connect only**, not on unplug (+ connect-only test matrix)
   - `1e53bfd` (fix) — size charging wings to the **measured notch** (305×32; superseding the intermediate `d13b212` 300pt step)

## Files Created/Modified
- `Islet/Notch/PowerSourceMonitor.swift` (created) — the only IOKit file in the phase; thin glue, no polling, no business logic (the classification lives in the pure Plan-01 seam).
- `Islet/Notch/NotchWindowController.swift` (modified) — monitor/state/dismiss ownership, `handlePower`, `scheduleActivityDismiss`, hover pause/resume, union panel sizing, deinit teardown.
- `Islet/Notch/PowerActivity.swift` (modified, UAT) — `shouldTriggerSplash` rewritten to the connect-only edge predicate + `isOnAC` helper; the now-dead `SplashCategory`/`splashCategory` removed.
- `IsletTests/PowerActivityTests.swift` (modified, UAT) — connect-only test matrix (plug-in fires; unplug, unplug-at-full, and charging→full top-off do NOT fire).
- `Islet/Notch/NotchPillView.swift` (modified, UAT) — `wingsSize` 360→305×32 to match the measured notch.

## Decisions Made
- **Connect-only splash (PRODUCT CHANGE — descopes CHG-02):** during on-device UAT the user decided the charging activity should animate ONLY on plug-in, never on unplug. `shouldTriggerSplash` now fires solely on the not-AC → AC transition, so unplug (`charging/full → onBattery`) and within-AC top-off (`charging → full`) show nothing. CHG-01 is fully met; **CHG-02's "brief on-battery indication on unplug" is intentionally dropped** and recorded as descoped in REQUIREMENTS.md. The `.onBattery` case is kept in the model (still classified) but never triggers a splash.
- **Wings sized to the real notch:** the running app's notch was measured at **179×32 pt** (`safeAreaInsets.top` + `frame.width − auxLeftWidth − auxRightWidth`). `wingsSize` set to **305×32** — height = notch height (flush, no overhang; was 40 and hung ~8pt below), width tuned live to the user's preference (360→300→250→270→285→295→**305**). The panel stays the 360-wide expanded union, so only the visible black strip changed, never the window; the pure `wingsFrame` tests build their own size and were unaffected.

## Deviations from Plan

### Product/UAT-driven changes (user decision)
- **CHG-02 descoped → connect-only** (commit `7489657`). See Decisions above. This is a deliberate product decision made during the human-verify checkpoint, not a defect.
- **Wings retuned to the measured notch** (commit `1e53bfd`). The plan's `wingsSize` seed (360×40) overhung the notch and splayed too wide on-device.

### Auto-fixed Issues (executor, Rule 3 — blocking)
**1. `NotchPillView` parameter order → `interaction:charging:onClick:`** — the controller call `NotchPillView(interaction:charging:onClick:)` would not compile with a defaulted `onClick` ahead of the non-defaulted `charging`; reordered so `charging` precedes the defaulted `onClick`. No behavior change. (commit `f7cae04`)

**2. `PowerSourceMonitor.stop()` made `nonisolated`** (and `runLoopSource` `nonisolated(unsafe)`); `powerMonitor` changed from a `lazy var` to a stored optional assigned in `start()`, so the controller's nonisolated `deinit` can call `powerMonitor?.stop()`. The `@MainActor lazy` form failed ("main actor-isolated property can not be referenced from a nonisolated context"). Mirrors the existing `graceWorkItem` deinit discipline. (commit `f7cae04`)

### Documentation-only rewording (no behavior change)
- The no-polling comment in `PowerSourceMonitor.swift` originally spelled the literal tokens `Timer`/`DispatchSourceTimer`, which the Task-1 `grep -c ... = 0` guard counted. Reworded to "no polling clock" — same constraint, identical precedent to Plans 01/02.

## Issues Encountered
- **Checkpoint continuation without SendMessage:** the plan is `autonomous:false`; the executor correctly paused at the human-verify checkpoint and returned without writing SUMMARY. Its two task commits were merged back from the worktree, and the UAT tuning + this SUMMARY were applied inline on the feature branch (the executor's worktree had been cleaned up; SendMessage to continue it was unavailable in this runtime). No work lost — the task commits were captured before the worktree was removed.
- **Verify path divergence (executor):** the plan's hardcoded `cd /Users/.../algiers` verify path is a different worktree; the executor verified in its own worktree. Post-merge, all verification (build + 72-test suite) was re-run on the feature branch.
- **Pre-existing actor warnings:** `xcodebuild` emits two `updateVisibility()` "main actor-isolated ... in a synchronous nonisolated context" warnings in `NotchWindowController` (from the Phase-2/Wave-3 notification closures). Warnings only, not errors; not introduced by the UAT changes.

## User Setup Required
None — IOKit power-source reads need no entitlement and the app is un-sandboxed. No external service.

## Next Phase Readiness
- **Phase 4 (Now Playing):** the live-activity loop shape (system source → pure mapping → @Published model → SwiftUI → one-shot dismiss, all gated through `updateVisibility()`) is now proven end-to-end on the safe IOKit API before the fragile MediaRemote work begins.
- **Phase 5 (Device/Bluetooth):** the connect-edge gate + wings layout is directly reusable for the AirPods connect activity (DEV-01).
- **Phase 6 (COORD-01 resolver):** D-11 is still a one-line if-ordering; the general multi-activity resolver remains deferred.
- **Open:** the measured-notch geometry (179×32) is currently hard-coded as a tuned constant; if non-uniform across notch Macs, a future polish phase could derive `wingsSize` from the live `notchFrame` instead of a fixed seed.

## Self-Check: PASSED

- Files verified on disk: `Islet/Notch/PowerSourceMonitor.swift` (created), `NotchWindowController.swift`, `NotchPillView.swift`, `PowerActivity.swift`, `IsletTests/PowerActivityTests.swift`
- Commits verified in git log: `6abbd2d`, `f7cae04`, `7489657`, `1e53bfd`
- Build + full XCTest suite green on the feature branch: **72 tests, 0 failures** (`** TEST SUCCEEDED **`)
- On-device UAT recorded: plug-in splash ✓, fullscreen no-show ✓, connect-only (no unplug splash) ✓ per user decision, wings sized to measured notch ✓
- CHG-01 met; CHG-02 intentionally descoped (connect-only) and recorded in REQUIREMENTS.md

---
*Phase: 03-charging-activity*
*Completed: 2026-06-27*
