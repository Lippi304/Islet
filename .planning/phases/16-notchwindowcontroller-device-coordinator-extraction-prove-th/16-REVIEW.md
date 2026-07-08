---
phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th
reviewed: 2026-07-08T21:30:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Notch/ActivityCoordinator.swift
  - Islet/Notch/DeviceCoordinator.swift
  - IsletTests/DeviceCoordinatorTests.swift
  - Islet.xcodeproj/project.pbxproj
  - Islet/Notch/NotchWindowController.swift
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-07-08T21:30:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the DeviceCoordinator extraction (`ActivityCoordinator.swift`, `DeviceCoordinator.swift`,
its test suite, the `.pbxproj` wiring, and the call-site integration in
`NotchWindowController.swift`). `xcodebuild build` and `xcodebuild build-for-testing` both succeed
against the current tree, and target membership in `project.pbxproj` is correct (main files under
the `Islet` target's Sources phase, `DeviceCoordinatorTests.swift` under `IsletTests`'s).

No BLOCKER-level defects were found — the "handle → shouldShowDeviceSplash → enqueue →
scheduleDeviceBatteryRefresh/activityPromoted" flow was traced against the 8 unit-tested pitfalls
plus the 3 documented-but-not-unit-tested ones, and it holds up under manual tracing including a
constructed 3-device connect/disconnect interleaving.

The most substantive finding (WR-1) is a fragile, undefended coupling between two independently
maintained magic-number caps (`TransientQueue.maxDepth == 2` and the hardcoded `> 2` cap in
`DeviceCoordinator.handle`) that the post-connect battery-refresh identity check silently depends
on; under today's values the failure mode is benign (a stale, unreachable bookkeeping entry), but
nothing stops that from flipping into a real cross-device battery misattribution if either cap is
tuned independently in the future. The rest are smaller robustness/quality notes.

## Warnings

### WR-1: Battery-refresh identity check trusts shape, not identity — silently depends on two magic-number caps staying equal

**File:** `Islet/Notch/DeviceCoordinator.swift:222-227` (activityPromoted), `Islet/Notch/DeviceCoordinator.swift:236-260` (scheduleDeviceBatteryRefresh's retry closure), `Islet/Notch/DeviceCoordinator.swift:208-209` (the `> 2` cap)

**Issue:**
`activityPromoted()` only re-arms/cancels the standing `deviceBatteryWork` poll when
`matchPendingBatteryPoll` finds a match for the newly-promoted head (line 225: `guard let match
else { return }`). If no match is found, the *old* poll (still scheduled for the previously-head
device's address, captured in `pollingAddress`/`deviceBatteryWork`) is left running untouched.

The retry closure's only safety net against applying that stale poll's result to a different,
newly-promoted device is a *shape* check:
```swift
guard case .device(.connected(let name, let glyph, let old))? = self.queueHead() else { return }
if let fresh = self.batteryForAddress(address), fresh != old {
    let updated = DeviceActivity.connected(name: name, glyph: glyph, battery: fresh)
    self.updateHead(.device(updated))
```
`DeviceActivity.connected` (see `DeviceActivity.swift:46`) carries no address — so this guard only
confirms "the head is *some* connected device," never that it's the *same* device the poll was
started for. If a **different** connected device is ever promoted to head without a matching
`pendingDeviceBatteryPolls` entry, the stale poll will silently paint that device's splash with
`address`'s (wrong) battery value under the new device's name/glyph.

Whether that "no match" case can occur today depends entirely on `TransientQueue.pending`'s cap
(`maxDepth == 2`, in `IslandResolver.swift`) and `pendingDeviceBatteryPolls`'s cap (hardcoded
`> 2` at `DeviceCoordinator.swift:209`) staying in lockstep. They currently *can* desync — a
disconnect activity occupies a `TransientQueue.pending` slot without ever occupying a
`pendingDeviceBatteryPolls` slot (disconnects are explicitly excluded, per the Finding 4 comment at
line 205-206), so `TransientQueue.pending` can evict entries strictly faster than
`pendingDeviceBatteryPolls` does. Tracing through this concretely, the direction of desync under
today's `2`/`2` values only produces a harmless outcome (a stale `pendingDeviceBatteryPolls` entry
that's already unreachable in the queue, so `matchPendingBatteryPoll` simply never finds it again).
But nothing in the code asserts or documents that this direction is guaranteed — a future change
that bumps one cap without the other (e.g. raising `TransientQueue.maxDepth` to 3 without touching
the `> 2` here, or vice versa) can flip the desync direction and produce exactly the
cross-device-misattribution case described above, with no compiler or test signal.

**Fix:** Either (a) derive the `DeviceCoordinator.handle` cap from `TransientQueue.maxDepth` instead
of a second hardcoded `2`/`> 2` literal, or (b) make the retry closure's guard check identity, not
just shape — e.g. have `scheduleDeviceBatteryRefresh` capture the expected `DeviceActivity` (or at
minimum the device `name`) it was scheduled for, and compare it against the live head's payload
before applying `fresh`, instead of trusting `pollingAddress` + the queue-head's *shape* alone:
```swift
guard case .device(.connected(let name, let glyph, let old))? = self.queueHead(),
      name == expectedName   // expectedName captured when this poll chain started
else { return }
```

### WR-2: `deviceSuppressedAtLaunch` is a dead parameter — always an empty `Set`

**File:** `Islet/Notch/DeviceCoordinator.swift:28`, `Islet/Notch/DeviceCoordinator.swift:182-188`

**Issue:** `deviceSuppressedAtLaunch: Set<String> = []` is passed into
`shouldShowDeviceSplash(...)` on every call but is never inserted into anywhere in this file (the
header comment at lines 24-26 acknowledges this: "left empty for v1 — the on-device A2 verdict
that would seed it is a deferred carry-over"). The parameter and the `suppressedAtLaunch.contains`
branch inside the pure `shouldShowDeviceSplash` predicate (`DeviceActivity.swift:101`) are
therefore unreachable code paths in production today — a maintainer reading `handle(_:now:)` in
isolation would reasonably assume this gate is live.

**Fix:** No functional change needed if this is truly deferred, but consider either removing the
parameter until the A2 seed lands, or adding a `// ponytail`-style one-line marker at the call site
(not just the class header) so a future reader scanning `handle(_:now:)` doesn't have to
cross-reference the class-level comment to learn this branch is inert.

## Info

### IN-1: `ActivityCoordinator` protocol has no polymorphic consumer

**File:** `Islet/Notch/ActivityCoordinator.swift:18-28`, `Islet/Notch/DeviceCoordinator.swift:19`, `Islet/Notch/NotchWindowController.swift:117`

**Issue:** `DeviceCoordinator` is the sole conformer of `ActivityCoordinator`, and
`NotchWindowController` holds it as the concrete type (`private var deviceCoordinator:
DeviceCoordinator!`), never as `any ActivityCoordinator` or through a generic constraint. The
protocol is not used polymorphically anywhere in the codebase. (The project's own 16-RESEARCH.md
explicitly acknowledges and accepts this as "scaffolding for the future," so this is a documented
tradeoff, not an oversight — flagging for visibility only.)

**Fix:** No action required if the team intends to add a second coordinator (Charging/NowPlaying)
soon; otherwise this is a small YAGNI abstraction to keep an eye on.

### IN-2: `deviceCoordinator` is an implicitly-unwrapped optional (`!`), the only force-unwrap-risk property in these 5 files

**File:** `Islet/Notch/NotchWindowController.swift:117`, used non-optionally at e.g. lines 392-393, 804, 861-862, 916, 921

**Issue:** `private var deviceCoordinator: DeviceCoordinator!` is force-unwrapped implicitly at
every call site except `deinit` (`deviceCoordinator?.cancelPendingWork()`, line 1065). If any
future code path calls `handleSettingsChanged()`, `scheduleActivityDismiss()`, or `flushTransients`
before `start()` has run (e.g. a future test harness that exercises the controller without calling
`start()`), this crashes instead of failing gracefully. The deviation from a plain `Optional` is
explained and deliberate (comment at lines 110-116, needed for the nonisolated `deinit` to call
`cancelPendingWork()` synchronously), so this is intentional risk, not an oversight — flagging so
it's visible to a future reviewer touching this property.

**Fix:** None required given the documented constraint; if `NotchWindowController` ever grows a
test suite that doesn't call `start()`, this will need revisiting.

### IN-3: `handle(_:now:)` is a long, deeply-nested method (~65 lines, 4+ branch points)

**File:** `Islet/Notch/DeviceCoordinator.swift:148-212`

**Issue:** The method mixes edge-detection (Set-based dedup), launch-grace suppression, debounce
gating, activity construction, enqueue, and pending-battery-poll bookkeeping in one function body.
It is heavily and usefully commented, and the 8 associated unit tests give good behavioral
coverage, so this is not a correctness risk — but the branching (three early-return sites before
the shared gate, plus the `if changed / else if reading.connected` fork afterward) pushes
cyclomatic complexity high enough that a future edit (e.g. adding a third device state) is likely
to require re-deriving the interaction between the Set-dedup and the debounce-map from scratch.

**Fix:** Optional refactor: split the edge-detection block (lines 160-177) into a small pure
helper (e.g. `deviceConnectionEdge(...)`) mirroring the existing `shouldShowDeviceSplash`/
`deviceActivity(from:)` seam pattern already used elsewhere in this file, so it can be unit-tested
directly instead of only indirectly through `handle`.

---

_Reviewed: 2026-07-08T21:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
