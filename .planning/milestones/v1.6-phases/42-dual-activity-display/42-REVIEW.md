---
phase: 42-dual-activity-display
reviewed: 2026-07-19T00:20:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Notch/IslandPresentationState.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 0
  warning: 4
  info: 1
  total: 5
status: issues_found
---

# Phase 42: Code Review Report

**Reviewed:** 2026-07-19T00:20:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the dual-activity-display resolver extension (`resolveSecondary`), the `IslandPresentationState.secondary` carrier, the secondary bubble view, and the controller wiring (staggered reveal `DispatchWorkItem`, click-through hot-zone widening, and the late-added hover play/pause control). The pure-resolver layer is well-tested and its documented precedence rules (D-01/D-04/D-10) hold up under trace. No crashes, injection, or data-loss risks found. Four maintainability/robustness gaps and one test-coverage gap are worth fixing before this ships, all clustered around the parts of the brief this review was asked to scrutinize:

- `resolveSecondary` itself does not enforce the NOW-04 launch gate — it is only correct today because the single caller (`NotchWindowController.currentPresentation()`) manually re-derives the gated value a second time, duplicating a computation the codebase's own header comment warns against.
- `secondaryRevealWorkItem` is the only `DispatchWorkItem` in the controller that is never cancelled in `deinit`, breaking with every sibling work item's teardown discipline.
- The click-through hot-zone widening hardcodes the same magic `220` the view computes from three named constants, instead of deriving it — a future geometry tune in one file silently desyncs the other, the exact CR-01/CR-02 failure class this project has hit before.
- The secondary bubble's hover `@State` lives on the always-mounted `NotchPillView`, not on the conditionally-mounted bubble itself, so a stale "hovering" visual state can survive a bubble unmount/remount cycle.

## Warnings

### WR-01: `resolveSecondary` relies on caller-side gate replication instead of enforcing NOW-04 itself

**File:** `Islet/Notch/IslandResolver.swift:191-195` (contract), `Islet/Notch/NotchWindowController.swift:806-811` (caller)

**Issue:** `resolveSecondary(primary:nowPlaying:)` takes `nowPlaying` as a raw parameter and does not apply `nowPlayingLaunchGate` itself:

```swift
func resolveSecondary(primary: IslandPresentation, nowPlaying: NowPlayingPresentation) -> SecondaryActivity? {
    guard case .calendarCountdown = primary else { return nil }
    guard nowPlaying != .none else { return nil }
    return .nowPlaying(nowPlaying)
}
```

Its doc comment (lines 178-186) explains why D-10 (transient suppression) and D-04 (isExpanded suppression) "fall out for free from primary's own shape," but says nothing about the NOW-04 launch gate — even though `resolve()`'s own ambient branch (`IslandResolver.swift:171-174`) applies `nowPlayingLaunchGate` before ever reaching the `.calendarCountdown` case's sibling `.nowPlayingWings` branch. Today this only works because `NotchWindowController.currentPresentation()` separately re-derives a `gatedNp` value and passes that in:

```swift
let gatedNp = nowPlayingLaunchGate(hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch, nowPlaying: np)
let secondary = resolveSecondary(primary: presentation, nowPlaying: gatedNp)
```

This is exactly the "two independent computations of the same live fact" pattern 42-RESEARCH.md's Pitfall 1 (quoted in `resolveSecondary`'s own doc comment) warns against — it just hasn't drifted yet because both sites happen to call the same pure function with the same two inputs. Nothing in `resolveSecondary`'s signature or type prevents a future caller (or a refactor of this same call site) from passing the raw, ungated `np` instead of `gatedNp`, silently reintroducing the NOW-04 bypass for the secondary bubble only (while `nowPlayingWings` stays correctly gated) — a track that hasn't actually played since launch would then appear as a secondary bubble the moment a countdown shows.

**Fix:** Either have `resolveSecondary` take `hasPlayedSinceLaunch` and apply the gate internally (mirroring `resolve()`'s own discipline), or have `resolve()` expose the already-gated now-playing value so there is only ONE computation of the gate, not two:

```swift
func resolveSecondary(primary: IslandPresentation,
                       nowPlaying: NowPlayingPresentation,
                       hasPlayedSinceLaunch: Bool) -> SecondaryActivity? {
    guard case .calendarCountdown = primary else { return nil }
    let gated = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    guard gated != .none else { return nil }
    return .nowPlaying(gated)
}
```

### WR-02: `secondaryRevealWorkItem` is never cancelled in `deinit`

**File:** `Islet/Notch/NotchWindowController.swift:262` (declaration), `:824-844` (renderPresentation, only site that cancels it), `:2377-2445` (deinit)

**Issue:** Every other `DispatchWorkItem` owned by this controller is explicitly cancelled in `deinit` (`dismissWorkItem` at line 2402, `mediaDismissWorkItem` at 2430, `graceWorkItem` at 2391, `dragPinSafetyNetWorkItem` at 2395, `trialExpiryWorkItem` at 2438). `secondaryRevealWorkItem` is only ever cancelled from inside `renderPresentation()` (lines 828/831) — `deinit` doesn't touch it at all. The review brief specifically asked to verify "no work items can leak"; this one does not follow the file's own established teardown discipline. It won't crash (the closure guards with `[weak self]`), but it is a genuine gap relative to the pattern every sibling work item follows, and leaves a scheduled main-queue block alive for up to 150ms after the controller is torn down for no reason.

**Fix:** Add it to `deinit` alongside its siblings:

```swift
secondaryRevealWorkItem?.cancel()
```

### WR-03: Click-through hot-zone widening duplicates a magic number instead of deriving it from the shared geometry constants

**File:** `Islet/Notch/NotchWindowController.swift:1285-1294`, cf. `Islet/Notch/NotchPillView.swift:791-813`

**Issue:** `collapsedInteractiveZone()` hardcodes the same `220` the view computes from three named constants:

```swift
let bubbleFarEdge = collapsedFrame.midX + 220
    + NotchPillView.secondaryBubbleDiameter / 2 + hotZonePadding
```

`NotchPillView.swift:813` derives its `.offset(x: 220, ...)` from `Self.wingsLabelWidth / 2 (200) + secondaryBubbleGap (8) + secondaryBubbleDiameter/2 (12) = 220` (per the comment at lines 791-794), but that arithmetic isn't expressed in code — only in a comment — and the controller re-hardcodes the literal result rather than referencing `NotchPillView.wingsLabelWidth`/`secondaryBubbleGap` (both already non-private `static let`s, and the very same line already references `NotchPillView.secondaryBubbleDiameter` for the other term). A future on-device tuning pass to any of those three constants (this file's own history shows these get tuned repeatedly — `wingsLabelWidth`, `secondaryBubbleGap`, `secondaryBubbleDiameter` are all flagged as tunable) only updates the view's offset, silently desyncing the click-through hot-zone from the visually rendered bubble position — precisely the CR-01/CR-02 regression class (`28-REVIEW.md` WR-01/WR-02, `showsSwitcherRow` consolidation) this codebase has already been bitten by once and built a single-source-of-truth convention specifically to avoid.

**Fix:** Derive the offset instead of repeating the literal:

```swift
let bubbleCenterOffset = NotchPillView.wingsLabelWidth / 2 + NotchPillView.secondaryBubbleGap
let bubbleFarEdge = collapsedFrame.midX + bubbleCenterOffset
    + NotchPillView.secondaryBubbleDiameter / 2 + hotZonePadding
```
(and use the same `bubbleCenterOffset` expression in place of the `220` literal in `NotchPillView.swift:813`).

### WR-04: Stale secondary-bubble hover state survives unmount/remount

**File:** `Islet/Notch/NotchPillView.swift:2624` (declaration), `:811-815` (conditional mount), `:2657` (onHover)

**Issue:** `isSecondaryBubbleHovering` is declared as `@State` directly on `NotchPillView`:

```swift
@State private var isSecondaryBubbleHovering = false
```

but the bubble it drives is only conditionally present in the view tree:

```swift
if let secondary = presentationState.secondary {
    secondaryBubble(secondary)
        .offset(x: 220, y: ...)
        .transition(.scale.combined(with: .opacity))
}
```

Because the `@State` lives on the parent (`NotchPillView`, whose identity persists for the app's whole session) rather than on a view scoped to the bubble's own conditional lifetime, it is never reset when the bubble unmounts. Repro: hover the bubble (`isSecondaryBubbleHovering` → `true`), then let the secondary activity clear (e.g. media stops, `presentationState.secondary` → `nil`) while the pointer is still over the bubble's former screen position — the bubble's `onHover` never fires `false` because the view (and its `.onHover` modifier) is gone. When the secondary activity reappears later — potentially at a different time with the pointer elsewhere entirely — the bubble mounts already reading `isSecondaryBubbleHovering == true`: it renders pre-darkened with the play/pause glyph visible even though nothing is actually hovering it, until the next genuine hover event on that region corrects it.

**Fix:** Reset the flag when the value transitions to nil, or scope the state to a private view struct that only exists while the bubble does:

```swift
if let secondary = presentationState.secondary {
    secondaryBubble(secondary)
        .offset(...)
        .transition(.scale.combined(with: .opacity))
} else if isSecondaryBubbleHovering {
    // never rendered, but need a mount point — simplest fix: reset explicitly instead:
}
```
Simplest concrete fix — reset it in `renderPresentation()`'s nil branch (controller side) is not possible since the view owns the `@State`; instead extract the bubble into its own small `SecondaryBubbleView: View` struct holding its own `@State private var isHovering`, so SwiftUI tears the state down automatically with the conditional mount (matches this file's own precedent of giving `TransportButton` its own private View struct "to get independent per-instance hover state", per the comment at `NotchPillView.swift:2621-2623`).

## Info

### IN-01: No unit test locks `resolveSecondary`'s launch-gate dependency at the pure-function level

**File:** `IsletTests/IslandResolverTests.swift:763-833`

**Issue:** Every `resolveSecondary` test in this file passes `hasPlayedSinceLaunch: true` (a no-op gate) or drives `nowPlaying` to `.none` directly — none constructs the exact scenario WR-01 describes: a `.calendarCountdown` primary with `hasPlayedSinceLaunch: false` and a genuinely-playing `nowPlaying`, fed into `resolveSecondary` WITHOUT pre-gating, to confirm it returns non-nil (documenting today's caller-dependent behavior) or, after the WR-01 fix, that it correctly returns nil.

**Fix:** Add a regression test once WR-01 is fixed, e.g.:

```swift
func testResolveSecondaryGatedWhenNotYetPlayed() {
    let countdown = CalendarCountdownActivity(eventStart: Date().addingTimeInterval(20 * 60))
    let np = NowPlayingPresentation.playing(title: "Song", artist: "Artist")
    XCTAssertNil(resolveSecondary(primary: .calendarCountdown(countdown),
                                   nowPlaying: np,
                                   hasPlayedSinceLaunch: false))
}
```

---

_Reviewed: 2026-07-19T00:20:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
