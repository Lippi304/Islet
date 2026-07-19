---
phase: 43-drag-detection-hardening
reviewed: 2026-07-19T01:36:33Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Notch/DragDropSupport.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/NotchInteractionState.swift
  - IsletTests/DragApproachGeometryTests.swift
  - IsletTests/InteractionStateTests.swift
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: clean
fixed:
  - "WR-01: dismissExpandedImmediately() now resyncs via handlePointer(at: NSEvent.mouseLocation)
     instead of a raw pointerInZone=false + syncClickThrough(), covering the previously-unresynced
     async AirDrop/Mail completion path (commit follows this review)."
---

# Phase 43: Code Review Report

**Reviewed:** 2026-07-19T01:36:33Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the full diff introduced across Plan 43-01 (the `isGenuineFileDrag` pasteboard-content
gate) and Plan 43-02 (the on-device UAT that led to the `.dismissed` state-machine event and the
`dismissExpandedImmediately()` consolidation), against the pre-phase baseline (`0fbc92a..HEAD`),
not just the final file state, so intermediate/superseded logic from UAT rounds 1-3 could be ruled
out explicitly.

`isGenuineFileDrag` itself is correct and matches its spec exactly (`currentChangeCount !=
gestureBaselineChangeCount && !urls.isEmpty`), the baseline-refresh relocation into
`handleDragApproachEnd()` (before its `guard`) genuinely closes the self-referential-compare bug,
and the new `.dismissed` transition correctly short-circuits the `IslandResolver` "flash" the round-4
fix describes — I traced this through `IslandResolver.swift`'s `resolve(...)` to confirm the ordering
claim in the code comments (`pendingDrop = nil` / `interaction.phase = nextState(...)` both run
before `renderPresentation()` inside the same `withAnimation` closure) is accurate, not just
asserted. The 4 new `isGenuineFileDrag` unit tests and 3 new `.dismissed` state-machine tests all
correctly exercise the documented behavior matrix.

One real robustness gap survives the consolidation: the new shared `dismissExpandedImmediately()`
helper forces `pointerInZone = false` as a side effect, but only 2 of its 4 call sites are followed
by a resync (`handleDragApproachEnd()`'s own trailing `handlePointer(at:)` call, and geometry that
makes the other drag-exit call site safe by construction). The remaining call site —
`finishQuickActionSharing()`, reached from the AirDrop/Mail *async* completion callback — has no
such resync, and the on-device UAT log for this phase documents testing only the Drop-button and
discard variants, never AirDrop/Mail. See WR-01 below.

## Warnings

### WR-01: `dismissExpandedImmediately()`'s `pointerInZone` reset is not resynced for the async AirDrop/Mail completion path

**File:** `Islet/Notch/NotchWindowController.swift:1206-1216` (`dismissExpandedImmediately`), called from `1237-1243` (`finishQuickActionSharing`), reached asynchronously via `1247-1260` (`handleQuickActionAirDrop`/`handleQuickActionMail`)

**Issue:** `dismissExpandedImmediately()` unconditionally sets `pointerInZone = false` then calls
`syncClickThrough()`, which (once collapsed) derives `panel?.ignoresMouseEvents` purely from
`pointerInZone` (see `syncClickThrough()` at line ~1449-1463). For the two paths reached
synchronously inside `handleDragApproachEnd()` (Drop, and the D-13 discard-without-a-button-hit
branch), this is safe because `handleDragApproachEnd()`'s own trailing line —
`handlePointer(at: NSEvent.mouseLocation)` (line 1193) — re-syncs `pointerInZone` against the real
cursor position immediately afterward. The drag-exit branch in `recheckDragAcceptRegion` (line
1137-1145) is also safe, but only because `geometryInside` was already false there (the point is
outside `expandedZone`, which — per the file's own documentation of `expandedZone` as "the WHOLE
expanded island" — is a superset of the collapsed `hotZone`), so forcing `pointerInZone = false` is
provably correct in that case.

`finishQuickActionSharing()`, however, is invoked from `quickActionSharingService.share(...)`'s
completion closure — i.e., whenever the user finishes (or cancels) the system AirDrop/Mail sharing
UI, which can be an arbitrary amount of time later and is not on the same synchronous call stack as
any pointer resync. If the real cursor is still resting over the collapsed pill's hot-zone at that
moment (plausible — the user just interacted with a system panel and may not have moved the mouse
since), `pointerInZone` is force-reset to `false` with nothing to correct it until the next real
`.mouseMoved` event fires. Until then, `panel?.ignoresMouseEvents` stays `true`, i.e., the collapsed
island silently stops accepting clicks/hover even though the pointer is sitting on it.

This is also, concretely, the one call site among the 4 that the 4 rounds of on-device UAT
documented in `43-02-SUMMARY.md` do not appear to have exercised — every round's fix/verification
description mentions only the Drop button and the discard variants ("real Finder drag, discard
variant", "both the Drop button and discard variants"), never clicking AirDrop or Mail.

**Fix:** Move the resync into the shared helper itself so all 4 call sites get it uniformly (the
other 3 call sites already tolerate a redundant `handlePointer` call — `handleDragApproachEnd()`
already does one on every invocation regardless of branch taken):

```swift
private func dismissExpandedImmediately() {
    graceWorkItem?.cancel()
    graceWorkItem = nil
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .dismissed)
        renderPresentation()
    }
    pointerInZone = false
    updateVisibility()
    handlePointer(at: NSEvent.mouseLocation)  // resync pointerInZone + syncClickThrough() together
}
```
(`handlePointer(at:)` already calls `syncClickThrough()` itself while expanded, and derives the
correct `pointerInZone` edge for the collapsed case — this makes the trailing `syncClickThrough()`
call redundant and it can be dropped.)

## Info

### IN-01: `handleQuickActionDrop()`'s tray-selection mutation moved outside its `withAnimation` scope

**File:** `Islet/Notch/NotchWindowController.swift:1220-1231`

**Issue:** Before this phase, `viewSwitcherState.selectedView = .tray`, `pendingDrop = nil`, and
`renderPresentation()` were grouped inside one `withAnimation` block. After the refactor,
`viewSwitcherState.selectedView = .tray` and `pendingDrop = nil` are now set *before* calling
`dismissExpandedImmediately()`, which opens its own separate `withAnimation` scope for just
`interaction.phase`/`renderPresentation()`. Practically this is very likely benign here — the
immediate collapse means the Tray tab is never visibly shown mid-transition (that's the whole point
of the round-4 fix, and I confirmed the resolver ordering holds) — but if `viewSwitcherState`
drives any other observed UI (e.g., a switcher-pill selection indicator) that relies on an implicit
SwiftUI animation transaction from this assignment, that particular visual would now snap instead
of animate. Worth a comment noting this is intentional, or folding the assignment into
`dismissExpandedImmediately()`'s existing `withAnimation` block via a parameter, if it turns out to
matter on-device.

**Fix:** No action required unless an on-device regression in the switcher-pill's visual transition
is observed; if so, pass the pre-collapse mutation into the animated closure instead of running it
before `dismissExpandedImmediately()`.

### IN-02: Per-gesture drag baseline is a single global, not per-input-device

**File:** `Islet/Notch/NotchWindowController.swift:323` (`dragPasteboardChangeCount`), `1152-1160` (`handleDragApproachEnd`)

**Issue:** `dragPasteboardChangeCount`/`isDragApproaching` are single instance properties shared
across the whole system-wide `.leftMouseUp`/`.leftMouseDragged` global monitors. On a MacBook this
is a non-issue (one pointing device at a time in practice), but if two physical pointing devices
(e.g., trackpad + external mouse) produced overlapping mouse-down states, a `.leftMouseUp` from one
device could refresh the shared baseline out from under an in-progress gesture from the other. This
is an inherent limitation of modeling "per-gesture" state with global, non-scoped booleans/counters
rather than a per-session token, not something this phase regresses — flagging only as a known
architectural sharp edge worth a one-line comment if it's ever revisited.

**Fix:** No action needed for v1 (single built-in trackpad target per CLAUDE.md's platform
constraints); note it if multi-device support is ever a goal.

---

_Reviewed: 2026-07-19T01:36:33Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
