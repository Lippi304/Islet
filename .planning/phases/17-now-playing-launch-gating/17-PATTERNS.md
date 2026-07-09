# Phase 17: Now Playing Launch Gating - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 4 (all modified, no new files)
**Analogs found:** 4 / 4 (all analogs are in the SAME files being modified — this phase extends
existing pure-seam patterns rather than introducing new file roles)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/IslandResolver.swift` (add a gate helper + thread a param through `resolve(...)`) | utility (pure reducer) | transform | `nowPlayingHealthGate(enabled:isHealthy:)` in the same file | exact |
| `Islet/Notch/NowPlayingState.swift` (add `hasPlayedSinceLaunch` flag) | model (`@Published` state) | CRUD (flag set-once) | `isHealthy: Bool` field in the same file | exact |
| `Islet/Notch/NotchWindowController.swift` — `handleNowPlaying(_:_:)` (flip flag on first `.playing`) | controller | event-driven | `nowPlayingState.isHealthy = true` line in the same method | exact |
| `Islet/Notch/NotchWindowController.swift` — `currentPresentation()` (thread the flag into `resolve(...)`) | controller | transform | the existing `npEnabled`/`healthy` gate-and-call block in the same method | exact |
| `IsletTests/IslandResolverTests.swift` (add gate + resolve regression tests) | test | transform | `testNowPlayingHealthGateForcesNeutralWhenDisabled` in the same file | exact |

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` — new gate helper + `resolve(...)` param

**Analog:** `nowPlayingHealthGate(enabled: Bool, isHealthy: Bool) -> Bool`, same file, lines 52-58.

This is the EXACT shape to copy: a small, TOTAL, pure helper that neutralizes one input to
`resolve(...)` based on a boolean condition, keeping `resolve(...)` itself simple and the
gating logic independently unit-testable.

**Existing gate helper to mirror** (lines 52-58):
```swift
// Gap-closure fix (Finding 5) — TOTAL pure helper: a disabled Now Playing must be INVISIBLE to
// the resolver, not silently degraded to "nicht verfügbar" (D-12) for a feature the user turned
// off. When disabled, forces a neutral/healthy `true` regardless of the (possibly stale) real
// flag; when enabled, passes the real flag through unchanged.
func nowPlayingHealthGate(enabled: Bool, isHealthy: Bool) -> Bool {
    enabled ? isHealthy : true
}
```

**New helper to add, same shape** (name it e.g. `nowPlayingLaunchGate` or fold directly into
`resolve`'s non-expanded branch per D-03 — planner's call):
```swift
// Phase 17 / NOW-04 — D-01/D-02: a track that hasn't actually played (isPlaying == true) since
// Islet launched must not auto-show the ambient wings glance. TOTAL pure helper mirroring
// nowPlayingHealthGate's shape: when the gate hasn't been lifted yet, force .none for the
// AMBIENT (non-expanded) presentation only; the raw presentation passes through unchanged once
// hasPlayed is true, and ALWAYS passes through unchanged for the expanded branch (D-03 — this
// gate must never touch resolve's isExpanded branch).
func nowPlayingLaunchGate(hasPlayedSinceLaunch: Bool, nowPlaying: NowPlayingPresentation) -> NowPlayingPresentation {
    hasPlayedSinceLaunch ? nowPlaying : .none
}
```

**`resolve(...)` non-expanded branch to modify** (lines 34-49, the specific line to touch is 48):
```swift
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    if nowPlaying != .none { return .nowPlayingWings(nowPlaying) }   // D-02 ambient yield (rank 3) <- LINE 48, gate here only
    return .idle
}
```

Two viable mechanisms, both consistent with the codebase's discipline (planner/researcher already
flagged this as an open discretion point — CONTEXT.md D-per "Claude's Discretion"):
1. **Gate before resolve** (mirrors `nowPlayingHealthGate` usage exactly): the controller calls
   `nowPlayingLaunchGate(...)` in `currentPresentation()` to compute a SEPARATE "ambient-only"
   `np` value, passes the RAW `np` for the expanded branch and the GATED value for the
   ambient/non-expanded branch — but `resolve(...)` only takes ONE `nowPlaying` param today, so
   this requires either a new `resolve(...)` parameter (e.g. `nowPlayingAmbientGate: Bool`) OR
   splitting into two params (`nowPlaying: NowPlayingPresentation` for expanded,
   `nowPlayingAmbient: NowPlayingPresentation` for the wings branch).
2. **Gate inside `resolve`'s non-expanded branch directly** by adding a new `hasPlayedSinceLaunch:
   Bool` parameter to `resolve(...)` itself and checking it only on line 48 — smaller diff,
   keeps the single-source-of-truth arbiter (D-05) fully self-contained, and needs no new
   top-level pure function. This is the more "boring" fit given `resolve` is already the sole
   arbiter and D-03 says only the ambient branch is affected.

---

### `Islet/Notch/NowPlayingState.swift` — new flag

**Analog:** `isHealthy: Bool` field, same file, lines 17-20.

**Existing field pattern to mirror** (lines 17-20):
```swift
    // D-12 health axis, ORTHOGONAL to presentation. false → on expand show
    // "Now Playing nicht verfügbar". Default true (assume healthy until the launch
    // probe says otherwise).
    @Published var isHealthy: Bool = true
```

**New field to add, same shape:**
```swift
    // Phase 17 / NOW-04 — D-01/D-02: has a .playing presentation been observed at least once
    // since this Islet process launched? ORTHOGONAL to presentation (mirrors isHealthy's own
    // orthogonality). Default false (gated) — set to true ONCE in handleNowPlaying on the first
    // .playing snapshot and NEVER reset (D-02: no re-arm for the rest of the process lifetime).
    @Published var hasPlayedSinceLaunch: Bool = false
```

---

### `Islet/Notch/NotchWindowController.swift` — `handleNowPlaying(_:_:)` (flip the flag)

**Analog:** the `nowPlayingState.isHealthy = true` one-line flip already in this exact method,
line 957.

**Existing one-shot-flip pattern to mirror** (lines 955-957):
```swift
        // A healthy stream callback means the bridge is alive — a successful emission after a
        // prior drop restores the D-12 flag so the next expand shows media, not "nicht verfügbar".
        nowPlayingState.isHealthy = true
```

**Where to add the new flip** — inside the `switch p { case .playing: ... }` block (lines 985-987),
since D-01 requires `isPlaying == true` (i.e. the classified `.playing` case), not merely a
non-`.none` snapshot:
```swift
        switch p {
        case .playing:
            // The glance stands while playing — cancel any pending paused/stop dismiss.
            mediaDismissWorkItem?.cancel()
            // Phase 17 / D-01/D-02: first real Play observed this Islet run — lift the launch
            // gate permanently. Never reset (no re-arm branch exists in this switch).
            nowPlayingState.hasPlayedSinceLaunch = true
        case .paused:
            ...
```
Note: assigning `true` every time `.playing` recurs is harmless (idempotent) — no `if !hasPlayedSinceLaunch` guard needed, matching the codebase's preference for simple total assignments over conditional re-checks where the assigned value is stable once true.

---

### `Islet/Notch/NotchWindowController.swift` — `currentPresentation()` (thread the flag in)

**Analog:** the existing `npEnabled` / `healthy` gate-and-call block in this exact method, lines 452-464.

**Existing pattern to mirror** (lines 452-464):
```swift
    private func currentPresentation() -> IslandPresentation {
        let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
        let np = npEnabled ? nowPlayingState.presentation : .none   // D-09 disabled NP → forced .none
        // Gap-closure fix (Finding 5): gate the health flag through the same npEnabled switch as
        // `np` above — a disabled Now Playing must be INVISIBLE to the resolver (forced neutral),
        // not silently degraded to "nicht verfügbar" from a stale `false` left over from before
        // the toggle.
        let healthy = nowPlayingHealthGate(enabled: npEnabled, isHealthy: nowPlayingState.isHealthy)
        return resolve(activeTransient: transientQueue.head,
                       nowPlaying: np,
                       nowPlayingHealthy: healthy,
                       isExpanded: interaction.isExpanded)
    }
```

**Extension point** — add `nowPlayingState.hasPlayedSinceLaunch` as a new argument threaded
through to `resolve(...)` (if planner picks mechanism 2 above) right alongside the existing
`npEnabled`/`healthy` locals — no new controller-level state needed, `hasPlayedSinceLaunch`
already lives on `nowPlayingState` per the field added above.

---

### `IsletTests/IslandResolverTests.swift` — regression coverage

**Analog:** `testNowPlayingHealthGateForcesNeutralWhenDisabled` (lines 70-77) for the gate-function
unit test shape, and `testNoTransientWhilePlayingReturnsToWings` / `testNoTransientNoMediaIsIdle`
(lines 37-54) for the `resolve(...)`-level test shape.

**Gate-function test shape to mirror** (lines 68-77):
```swift
    // MARK: nowPlayingHealthGate(...) — Finding 5 gap-closure regression coverage

    func testNowPlayingHealthGateForcesNeutralWhenDisabled() {
        // Regression: a disabled Now Playing must be forced NEUTRAL (true) regardless of a stale
        // `false` left over from before the toggle — never silently degraded to "nicht verfügbar"
        // for a feature the user turned off.
        XCTAssertTrue(nowPlayingHealthGate(enabled: false, isHealthy: false))
        // Enabled must still pass the real flag through unchanged.
        XCTAssertFalse(nowPlayingHealthGate(enabled: true, isHealthy: false))
    }
```

**`resolve(...)`-level test shape to mirror** (lines 37-54) — new tests should assert:
- gated + `.paused` + not expanded → `.idle` (no wings glance)
- gated + `.playing` + not expanded → still shows wings (D-02: already-playing-at-launch is
  unaffected — CONTEXT.md line 12)
- gated + `.paused` + `isExpanded: true` → `.nowPlayingExpanded(...)` still shows (D-03: manual
  expand always reveals real state, gate never touches the expanded branch)
- once lifted (`hasPlayedSinceLaunch: true`) + later `.paused` + not expanded → wings glance
  shows normally (D-02: no re-arm)

## Shared Patterns

### Pure-seam / total-function discipline
**Source:** `Islet/Notch/IslandResolver.swift` file header (lines 1-16) and
`Islet/Notch/NowPlayingPresentation.swift` file header (lines 1-16).
**Apply to:** the new gate helper and any `resolve(...)` signature change.
```swift
// ...these are plain values + a total function importing ONLY Foundation — no MediaRemote,
// no AppKit, no NSImage, no Process here...
```
All new logic for this phase must stay Foundation-only and total (no optionals treated as
partial, no throwing) so it stays unit-testable in milliseconds per the existing convention.

### Orthogonal-axis discipline (D-11/D-12 precedent)
**Source:** `Islet/Notch/NowPlayingPresentation.swift` lines 12-16, and
`Islet/Notch/NowPlayingState.swift` lines 17-20 (`isHealthy`).
**Apply to:** `hasPlayedSinceLaunch` field placement and the gate's interaction with
`nowPlayingPresentation`/`resolve`.
The new "has played this session" axis must stay a SEPARATE flag from the
`.playing`/`.paused`/`.none` classification enum — never add a new enum case, never fold it into
`TrackSnapshot` or `nowPlayingPresentation(from:)`. This mirrors exactly how `isHealthy` is kept
orthogonal to `presentation`.

### Settings-gate-before-resolve discipline (D-09 precedent)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 447-451, 452-464.
**Apply to:** `currentPresentation()`'s threading of the new flag.
```swift
    // COORD-01 / D-05 — compute what the island should render via the PURE resolver. Settings
    // are applied BEFORE the resolver (D-09): a disabled Now Playing forces `.none` so the
    // ambient glance disappears live...
```
The launch gate is conceptually the same shape as the D-09 settings gate: a boolean condition
applied to an input BEFORE (or via a parameter into) `resolve(...)`, never as special-cased logic
scattered elsewhere in the controller.

## No Analog Found

None — every file this phase touches already contains a directly analogous pattern in the same
file (this is a small, additive change to an established pure-seam architecture, not new
architecture).

## Metadata

**Analog search scope:** `Islet/Notch/` (IslandResolver.swift, NowPlayingPresentation.swift,
NowPlayingState.swift, NotchWindowController.swift), `IsletTests/` (IslandResolverTests.swift)
**Files scanned:** 5 (all 4 files named in CONTEXT.md canonical_refs + their paired test file)
**Pattern extraction date:** 2026-07-09
