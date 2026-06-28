---
phase: 06-priority-resolver-settings-v1-ship
plan: 01
subsystem: coordination
tags: [swift, resolver, priority, queue, tdd, pure-seam, xctest]

# Dependency graph
requires:
  - phase: 03-charging-activity
    provides: "ChargingActivity enum (the rank-1 transient input)"
  - phase: 04-now-playing
    provides: "NowPlayingPresentation enum (the rank-3 ambient input) + the D-12 health axis"
  - phase: 05-device-connected-activity
    provides: "DeviceActivity enum (the rank-2 transient input)"
provides:
  - "IslandResolver.swift: pure IslandPresentation enum + resolve(...) ranked reducer (the single arbiter, D-05)"
  - "ActiveTransient enum (charging | device) — the queue's element + resolver's transient input"
  - "TransientQueue value: bounded (depth 2), de-duped vs head+pending, sequential advance-to-ambient"
  - "IsletResolverTests.swift: 14 fast unit tests covering rank ordering, ambient yield, expanded health axis, queue ordering/dedup/bound (the Wave-0 test dependency for Plan 04)"
affects: [06-04-controller-wiring, priority-resolver, settings-toggles]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure Foundation-only logic seam (Pattern 1): plain enums + total functions, no AppKit/SwiftUI/IOBluetooth/Timer, unit-tested in milliseconds — mirrors PowerActivity/DeviceActivity/NowPlayingPresentation"
    - "Single arbiter (D-05): one resolve(...) reducer replaces scattered per-pair if-ordering"
    - "Timestamp/clock-free queue: advance() is caller-driven, no Timer inside — keeps the queue deterministically testable (no-polling guarantee)"

key-files:
  created:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Settings toggles are applied BEFORE the resolver, never inside it — the resolver stays a pure ranking function with no policy/config knowledge"
  - "D-12 expanded health rides on nowPlayingExpanded's healthy: flag (orthogonal to the .none-vs-playing snapshot), so D-11 (nothing playing) never collapses into D-12 (API blocked)"
  - "TransientQueue exposes a read-only pendingCount accessor so tests assert the bound/dedup without making pending internal"
  - "Queue bound drops the OLDEST pending on overflow (removeFirst), never the head — a flapping device can never back the queue up (T-06-01)"

patterns-established:
  - "Pattern 1 (pure seam): framework-free enums + total functions tested by hand-built values with XCTAssertEqual"
  - "Pattern 2 (caller-driven queue): mutating enqueue/advance value type with no clock, advanced externally when a splash's ~3s elapses"

requirements-completed: [COORD-01]

# Metrics
duration: 3min
completed: 2026-06-28
---

# Phase 6 Plan 01: Priority Resolver & Transient Queue Summary

**Pure Foundation-only IslandResolver — a single ranked reduce(...) reducer (Charging > Device > Now Playing) plus a bounded, de-duped, sequential TransientQueue — the single arbiter (D-05) for COORD-01, covered by 14 fast TDD unit tests.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-28T01:38:43Z
- **Completed:** 2026-06-28T01:41:15Z
- **Tasks:** 3
- **Files modified:** 3 (2 created, 1 regenerated)

## Accomplishments
- `resolve(...)` ranked reducer: D-02 rank Charging > Device > Now Playing, D-04 transient wins even over a user-expanded island then yields to the highest-priority ambient state, D-12 expanded health axis (healthy media controls vs "nicht verfügbar"), ambient yield to now-playing wings vs the static idle pill.
- `TransientQueue` value: bounded depth 2, de-duped against both head and pending, sequential `advance()` back to the ambient state — overlapping events never overlap/glitch (D-03), and a flapping device can never back the queue up (T-06-01).
- 14 deterministic unit tests (7 rank/ambient/expanded + 7 queue ordering/dedup/bound) — the Wave-0 test dependency Plan 04 needs before controller wiring can be verified. Full suite 116/116, no regressions (was 102).
- The seam imports ONLY Foundation — no AppKit/SwiftUI/IOBluetooth/Timer — so it runs in milliseconds and Apple-API churn can never touch the ranking logic.

## Task Commits

Each task was committed atomically (TDD RED→GREEN):

1. **Task 1: RED — failing IslandResolver rank tests** - `7728bef` (test)
2. **Task 2: GREEN — implement IslandResolver ranked reducer** - `ace6d19` (feat)
3. **Task 3: GREEN — bounded de-duped TransientQueue + tests** - `725ce56` (feat)

## Files Created/Modified
- `Islet/Notch/IslandResolver.swift` - The pure arbiter: `IslandPresentation` enum, `ActiveTransient` enum, `resolve(...)` ranked reducer, and the `TransientQueue` value (bounded/de-duped/sequential). Foundation only.
- `IsletTests/IslandResolverTests.swift` - 14 unit tests: rank ordering, ambient yield (wings vs idle), D-12 expanded health axis, queue enqueue/dedup/advance/bound.
- `Islet.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` to pick up the two new files (directory-glob targets).

## Decisions Made
- Settings toggles applied BEFORE the resolver, never inside it — keeps `resolve(...)` a pure ranking function with no config knowledge (so Plan 04 can gate inputs without editing the arbiter).
- D-12 expanded health rides on the `nowPlayingExpanded(_, healthy:)` flag, orthogonal to the `.none`-vs-playing snapshot, preventing D-11 (nothing playing) from collapsing into D-12 (API blocked).
- Queue overflow drops the OLDEST pending entry (`removeFirst`), never the head — the active splash is never interrupted, and the depth is hard-capped at `maxDepth = 2`.
- Added a read-only `pendingCount` accessor so tests assert the bound/dedup without exposing the private `pending` array.

## Deviations from Plan

None - plan executed exactly as written. The `resolve(...)` and `TransientQueue` bodies match the plan's verbatim specifications; all acceptance criteria (file existence, pure-seam import discipline, ≥14 `func test`, no Timer/UI import, `TEST SUCCEEDED`) pass.

## Issues Encountered
- The parallel-executor instruction to commit with `--no-verify` is blocked by a repo `block-no-verify` pre-commit hook. Committed normally with hooks enabled instead; all three commits succeeded and the hooks passed.

## Known Stubs
None. `IslandResolver.swift` is pure in-process logic over existing enum values — no UI rendering, no data source, no placeholder/TODO paths. The controller/view wiring that consumes this seam is explicitly Plan 04 (Wave 2), not a stub in this plan.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The Wave-0 test dependency (`IslandResolverTests.swift`, 14 GREEN) is satisfied — Plan 04 (controller wiring, Wave 2) can now feed the live `@Published` charging/device/now-playing activities through `resolve(...)` and drive `TransientQueue` from the existing event-driven splash timers.
- Threat T-06-01 (queue back-up under a connect/disconnect storm) is mitigated and unit-tested (`testQueueBoundedDropsOldestPending`); T-06-02 (untrusted `device.name`) is accepted — the String is already clamped by the existing `deviceLabel(...)` seam before it becomes an `ActiveTransient`. No new trust boundary crossed.
- No blockers.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-06-28*
