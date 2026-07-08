# Phase 16: NotchWindowController Device Coordinator Extraction - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract the device-splash bookkeeping currently living directly on `NotchWindowController` —
9 fields (`deviceLastShown`, `deviceSuppressedAtLaunch`, `deviceDebounce`,
`connectedDeviceAddresses`, `bluetoothStartedAt`, `deviceLaunchGrace`, `deviceBatteryWork`,
`pollingAddress`, `pendingDeviceBatteryPolls`) plus `handleDevice`, `scheduleDeviceBatteryRefresh`,
and `triggerDeviceBatteryRefreshIfPromoted` — into a dedicated `DeviceCoordinator` behind a new
`ActivityCoordinator` protocol, with its own test surface (`DeviceCoordinatorTests.swift`).

This is a deliberate first slice proving the coordinator pattern on the highest-risk, most
race-documented activity type (11+ inline "gap-closure"/"Finding N" comments in
`NotchWindowController.swift` recording bugs found after the fact — reconnect-flap debounce,
launch-grace suppression, addressless-reading fallthrough, battery-poll identity matching).
Charging/NowPlaying/Outfit coordinators are explicitly NOT part of this phase (Phase 15 D-04,
carried forward).

**Zero product-behavior change is the contract.** Identical `TransientQueue`/dismiss timing,
identical debounce/launch-grace/battery-poll behavior — this is a structural move, not a rewrite.

Out of scope: `BluetoothMonitor`'s own lifecycle/ownership (stays on `NotchWindowController` —
see D-01 below), any other activity coordinator, any change to `TransientQueue`,
`presentTransientChange()`, `renderPresentation()`, or `updateVisibility()` beyond what's needed
to call into them from the extracted coordinator.

</domain>

<decisions>
## Implementation Decisions

### Extraction boundary
- **D-01:** `NotchWindowController` keeps owning `BluetoothMonitor` (start/stop/lifecycle) —
  matches the ROADMAP's literal field/method list (no `BluetoothMonitor` mentioned) and the
  established "controller owns monitors, injects readings into logic" pattern already used for
  `PowerSourceMonitor`/`NowPlayingMonitor`. `DeviceCoordinator` receives `DeviceReading` values
  handed to it by the controller — it does not touch `BluetoothMonitor` directly. Smallest safe
  diff for a first coordinator slice.

### Protocol foresight
- **D-02:** Design `ActivityCoordinator` narrowly, fitted to what `DeviceCoordinator` actually
  needs — do NOT pre-sketch Charging/NowPlaying/Outfit shapes in this phase. Explicit ROADMAP
  framing: "a deliberate first slice, not the full controller split." Guessing at the other three
  coordinators' shapes before they're extracted risks a wrong abstraction that gets reworked
  anyway once their real needs are known.

### Verification rigor
- **D-03:** Full on-device Bluetooth checklist is REQUIRED before this phase is considered done,
  not just unit tests + spot-check. Given this is the single most race-prone code path in the
  app by the audit's own account (11+ after-the-fact fixes), a pure structural move can still
  silently break timing-sensitive edge cases unit tests can't exercise (real IOBluetooth
  callbacks arrive off-main and get hopped to main — see `BluetoothMonitor.swift` header).
  Checklist must cover, at minimum: reconnect-flap debounce (same device connects twice within
  the ~3s window), launch-grace suppression (device already connected when the monitor starts),
  a genuine disconnect edge, and battery-poll promotion (a device enqueued behind the current
  head later gets promoted and still receives its deferred battery refresh).

### Claude's Discretion
- Exact protocol method signatures for `ActivityCoordinator` (e.g., `handle(reading:)` vs.
  `process(_:)`, how it reports "did the queue change" back to the controller — return value vs.
  callback) — pick whichever keeps `NotchWindowController`'s call sites (`handleDevice`,
  `triggerDeviceBatteryRefreshIfPromoted`, the `deinit` cancellation of `deviceBatteryWork`)
  simplest to swap in.
- Whether `DeviceCoordinator` needs a reference to the shared `TransientQueue`/
  `presentTransientChange()`/`renderPresentation()` passed in as closures, a delegate, or a
  narrow protocol — `handleDevice` currently calls all three directly; the extraction must
  preserve identical enqueue/render/dismiss timing (D-03's zero-behavior-change contract), the
  connecting mechanism is an implementation detail.
- Structure of `DeviceCoordinatorTests.swift` (isolated unit tests against fakes for
  `TransientQueue`/`BluetoothMonitor`/clock, mirroring `LicenseStateTests.swift`'s DI-seam test
  pattern from Phase 15) — Claude's call at planning time.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source code (the extraction target)
- `Islet/Notch/NotchWindowController.swift:105-154` — the 9 device-splash fields to extract.
- `Islet/Notch/NotchWindowController.swift:859-925` — `handleDevice(_:)`, full logic with inline
  "gap-closure"/"Finding N" comments documenting the races already found and fixed here.
- `Islet/Notch/NotchWindowController.swift:927-976` — `triggerDeviceBatteryRefreshIfPromoted()`
  and `scheduleDeviceBatteryRefresh(address:attempt:)`.
- `Islet/Notch/NotchWindowController.swift:1219-1229` — `deinit` teardown that cancels
  `deviceBatteryWork` (must be preserved by whatever now owns that field).
- `Islet/Notch/BluetoothMonitor.swift` — the monitor that stays on the controller (D-01);
  its header comments document the off-main→main hop discipline the coordinator must not break.

### Project-level
- `.planning/PROJECT.md` — Context section, "Known technical debt carried into next milestone
  planning" (background on the audit that produced this phase).
- `.planning/phases/15-architecture-refactor-notchwindowcontroller-notchpillview-de/15-CONTEXT.md`
  — Phase 15's D-04 (Phase 16 scope: Device-only, first slice) and D-05 (new extractions get a
  new test file proving the seam) both carry forward into this phase.
- `.planning/STATE.md` — Roadmap Evolution section, Phase 16 entry.

No external specs/ADRs apply — this is an internal refactor with no product requirement doc
(ROADMAP.md's own Phase 16 entry is the closest thing to a spec).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LicenseStateTests.swift` (Phase 15) — the most recent precedent for testing a
  newly-DI-seamed class in this codebase; a reasonable shape to mirror for
  `DeviceCoordinatorTests.swift`.
- `DeviceActivity.swift` (Phase 5/6) — the PURE, already-unit-tested seam
  (`shouldShowDeviceSplash`, `deviceActivity(from:)`, `matchPendingBatteryPoll`) that
  `handleDevice` calls into. This extraction moves the STATEFUL orchestration around these pure
  functions, not the pure functions themselves — they stay where they are.

### Established Patterns
- Shared activity-presentation triplet (`presentTransientChange()` → render + `updateVisibility()`
  + arm dismiss timer) is used by both Charging and Device today (`NotchWindowController.swift:502`
  region) — `DeviceCoordinator` must keep calling into this shared triplet, not fork its own copy.
- `TransientQueue` is shared state across activity types (`transientQueue.enqueue(.device(...))`
  sits alongside `.charging(...)` calls) — extracting `DeviceCoordinator` must not give Device its
  own queue; it still enqueues into the one shared `TransientQueue` the controller owns.

### Integration Points
- `NotchWindowController`'s `handleDevice(_:)` is currently the sole entry point for
  `BluetoothMonitor`'s `onReading` closure (main-thread callback) — after extraction, the
  controller still receives the callback and forwards the reading into `DeviceCoordinator`.
- `deinit` (`NotchWindowController.swift:1219-1229`) currently cancels `deviceBatteryWork`
  directly — after extraction this becomes a call into the coordinator's own teardown.

</code_context>

<specifics>
## Specific Ideas

No specific UI/behavior references — this is a pure internal architecture phase with a
zero-product-behavior-change contract (except nothing here; unlike Phase 15, this phase has no
called-out behavior-change exceptions).

</specifics>

<deferred>
## Deferred Ideas

- **Charging/NowPlaying/Outfit coordinators** — explicitly out of scope (D-02, Phase 15 D-04).
  A future phase, gated on this phase's on-device verification landing clean, and informed by
  whatever `ActivityCoordinator` shape actually falls out of this Device-only extraction (not
  pre-guessed here).
- **`BluetoothMonitor` ownership move into the coordinator** — considered and explicitly rejected
  for this phase (D-01); revisit only if a future coordinator generalization pass finds the
  current split awkward.

### Reviewed Todos (not folded)
None — no pending todos existed for this phase (`todo.match-phase 16` returned zero matches).

</deferred>

---

*Phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th*
*Context gathered: 2026-07-08*
