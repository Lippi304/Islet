---
phase: 09-fullscreen-flash-window-space-retry
reviewed: 2026-07-04T16:05:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - Islet/Notch/CGSSpace.swift
  - Islet/Notch/NotchWindowController.swift
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-07-04T16:05:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the two files touched by Plan 09-01: `CGSSpace.swift` (a new thin wrapper around 8
private SkyLight/CGS Space symbols) and the small additive hook in `NotchWindowController.swift`
that joins the app's single `NSPanel` to a dedicated, max-level CGS Space once at panel creation.

The mechanism itself is implemented consistently with the two shipping references cited in the
code's own comments (symbol set, Set-diffing join/leave, hide-before-destroy teardown order), and
the "join once, never re-sync per show/hide" discipline is correctly followed — no double-insert,
no stray hide/show call outside `updateVisibility()`.

The most important finding is that the file's own stated invariant — "Initialized `CGSSpace`s
*MUST* be de-initialized upon app exit!" — is not actually honored by the surrounding app: the
only exit path in the codebase (`AppDelegate.quit()`) calls `NSApp.terminate(nil)` directly with
no `applicationWillTerminate` and no explicit teardown of `notchController`, so
`NotchWindowController.deinit` (and therefore `CGSSpace.deinit`'s `CGSHideSpaces` /
`CGSSpaceDestroy`) does not run on a normal quit. This means the max-level, always-composited CGS
Space this phase introduces leaks in WindowServer on every ordinary app quit. The remaining
findings are lower-severity robustness/quality issues around the private-symbol boundary
(unchecked return values, an Int/Int32 width assumption that currently only works because the
literal happens to equal `Int32.max`) and some minor dead code / magic-literal cleanup.

## Critical Issues

### CR-01: CGS Space teardown relies solely on `deinit`, which never runs on a normal app quit — leaks the max-level Space every time

**File:** `Islet/Notch/NotchWindowController.swift:1081-1083` (root cause visible via `Islet/Notch/CGSSpace.swift:60-63` and `Islet/AppDelegate.swift:82-84`)

**Issue:** `CGSSpace.swift:51` documents an explicit invariant: "Initialized `CGSSpace`s *MUST* be
de-initialized upon app exit!" The only teardown of the dedicated max-level Space is
`NotchWindowController.deinit` (lines 1081-1083), which removes the panel from `notchSpace.windows`
and lets `CGSSpace.deinit` (`CGSHideSpaces` + `CGSSpaceDestroy`) run afterward.

However, `AppDelegate.quit()` (`Islet/AppDelegate.swift:82-84`) calls `NSApp.terminate(nil)`
directly, `AppDelegate` implements no `applicationWillTerminate`, and `notchController` is never
set to `nil` before termination. Cocoa's normal termination flow calls
`applicationShouldTerminate` (not overridden here, so it defaults to `.terminateNow`) and then ends
the process — it does not walk the live object graph and run `deinit` for objects a still-running
delegate references. In practice this means every ordinary "Quit Islet" (menu item or Cmd+Q) skips
`NotchWindowController.deinit` entirely, so `CGSHideSpaces`/`CGSSpaceDestroy` are never called: the
max-level (`Int32.max`), always-visible CGS Space created by this phase leaks in WindowServer and
persists until the user logs out or restarts. Over repeated quit/relaunch cycles (routine during
development, and plausible in normal use — e.g. after a macOS update, crash-recovery relaunch,
etc.) this accumulates orphaned max-level Spaces with no way for the app itself to reclaim them.

**Fix:** Explicitly tear the controller down before calling `NSApp.terminate`, e.g. in
`AppDelegate.swift`:
```swift
@objc private func quit() {
    notchController = nil   // forces deinit now, while the process is still alive,
                             // so CGSHideSpaces/CGSSpaceDestroy actually run
    NSApp.terminate(nil)
}
```
or implement `applicationWillTerminate(_:)` and call an explicit `notchController?.teardown()`
there. Either way, the Space's destruction must be driven by an explicit call on the terminate path
rather than relying on ARC `deinit` timing that Cocoa's termination flow does not guarantee.

## Warnings

### WR-01: Private CGS symbols bound with unverified/inconsistent integer widths

**File:** `Islet/Notch/CGSSpace.swift:52,55,69,74,77-78`; `Islet/Notch/NotchWindowController.swift:38`

**Issue:** `CGSSpaceSetAbsoluteLevel`'s `level` parameter (line 78) is declared as Swift `Int`
(64-bit on Apple silicon), but the private native symbol almost certainly takes a 32-bit C `int` —
the caller passes exactly the literal `2147483647` (`Int32.max`), and the file's own comment at
line 69 explicitly warns that `_CGSDefaultConnection`'s ABI "differs from `CGSMainConnectionID`"
used elsewhere (`FullscreenSpaceProbe.swift` binds the connection id as `Int32`, this file binds it
as `UInt`). Crossing a `@_silgen_name` boundary with a wider Swift integer type than the callee's
actual parameter width is only safe today because the one value ever passed happens to fit in 32
bits with no meaningful high bits. There is no compiler diagnostic that would catch a future call
site passing a different `Int` (negative, or `> Int32.max`) — it would silently misbehave.

**Fix:** Bind width-sensitive parameters with explicit fixed-width types to make mismatches a
compile error instead of a silent runtime hazard:
```swift
@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int32)
```
and pass `Int32(2147483647)` / `Int32.max` from `NotchWindowController.swift:38`.

### WR-02: No validation of CGS private-API return values — failures are silent

**File:** `Islet/Notch/CGSSpace.swift:52-58`

**Issue:** `init` never checks that `CGSSpaceCreate` returned a valid, non-zero space id before
calling `CGSSpaceSetAbsoluteLevel`/`CGSShowSpaces` on it, and there is no logging anywhere in this
file. This project has direct precedent for exactly this failure mode: CLAUDE.md documents that
Apple broke direct `MRMediaRemoteGetNowPlayingInfo` access on macOS 15.4 for non-Apple processes.
If a future macOS similarly restricts these SkyLight symbols (or simply changes their failure
signature), `CGSSpaceCreate` could start returning `0`/garbage, and this code would silently
continue calling `CGSSpaceSetAbsoluteLevel`/`CGSShowSpaces`/`CGSAddWindowsToSpaces` against an
invalid space id — the fullscreen-flash fix this file exists to deliver would silently regress
(the flash returns) with zero diagnostic signal to explain why.

**Fix:** At minimum, assert/log in DEBUG builds when creation fails, mirroring
`FullscreenSpaceProbe.swift`'s fail-safe-but-observable convention:
```swift
self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
#if DEBUG
if self.identifier == 0 {
    print("[CGSSpace] CGSSpaceCreate returned 0 — private CGS Space API may have changed")
}
#endif
```

## Info

### IN-01: `createdByInit` is dead code — always `true`

**File:** `Islet/Notch/CGSSpace.swift:36,57,62`

**Issue:** There is exactly one initializer and it unconditionally sets `createdByInit = true`
(line 57), so the `if createdByInit { CGSSpaceDestroy(...) }` guard in `deinit` (line 62) can never
evaluate `false`. It reads as scaffolding for a second "attach to an existing space I don't own"
initializer that does not exist in this file, which will confuse a future maintainer about the
actual teardown contract.

**Fix:** Either drop the flag and call `CGSSpaceDestroy` unconditionally, or add a one-line comment
noting it is reserved for a not-yet-implemented non-owning initializer.

### IN-02: Magic literal instead of `Int32.max`

**File:** `Islet/Notch/NotchWindowController.swift:38`

**Issue:** `CGSSpace(level: 2147483647)` spells out the ten-digit literal instead of using
`Int32.max`; the adjacent comment (lines 35-36) has to explain "2147483647 == Int32.max" because
the code itself doesn't say so. A transcription typo in this literal would silently change the
Space's priority with no compiler diagnostic.

**Fix:** `private let notchSpace = CGSSpace(level: Int(Int32.max))`.

### IN-03: `notchSpace` is constructed eagerly, before `start()` or any notch/screen check

**File:** `Islet/Notch/NotchWindowController.swift:38`

**Issue:** Because `notchSpace` is a stored property with a default-value initializer,
`CGSSpaceCreate`/`CGSSpaceSetAbsoluteLevel`/`CGSShowSpaces` run as soon as
`NotchWindowController()` is instantiated in `AppDelegate.applicationDidFinishLaunching` — before
`start()`, before any screen/notch detection, and even on hardware where the panel would never be
shown. This is likely harmless in practice (an empty Space with no window members composites
nothing visible), but it contradicts the framing of the comment at lines 33-37 ("join the dedicated
max-level Space exactly ONCE, here at panel creation") — only the *join* is deferred to panel
creation; the Space itself is created unconditionally at controller-construction time.

**Fix:** No functional change required, but if the intent is "nothing CGS-related happens until we
know we're going to show a panel," construct `notchSpace` lazily (e.g. inside `start()` or the
panel-creation branch of `positionAndShow`) instead of as an eager stored-property default.

---

_Reviewed: 2026-07-04T16:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
