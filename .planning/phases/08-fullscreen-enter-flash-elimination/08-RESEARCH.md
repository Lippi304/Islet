# Phase 8: Fullscreen-Enter Flash Elimination - Research

**Researched:** 2026-07-04
**Domain:** Private CoreGraphics/SkyLight (CGS) window-server notifications — proactive (pre-compositor) fullscreen-transition detection on macOS, as a background `LSUIElement` agent
**Confidence:** MEDIUM — a genuinely new, previously-untried candidate signal was identified and PARTIALLY on-device verified (symbol resolution + registration succeed on the exact ship OS build); the decisive test (does it fire *before* the compositor flash, on a real fullscreen-enter) could not be completed in this research session due to an environment restriction (see "What Was/Wasn't Tested On-Device"), not because the signal was found to fail.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Private-API risk tolerance**
- **D-01:** The researcher may use undocumented/private APIs at the **same risk tier already shipped** in this codebase — e.g. private CGS/SkyLight symbols bound via `@_silgen_name` (as `FullscreenSpaceProbe.swift` already does with `CGSCopyManagedDisplaySpaces`), or subscribing to a private distributed/CGS notification for Space-transition-start. This is consistent with the project's existing acceptance of private-API risk (MediaRemote via `mediaremote-adapter`, CGS Spaces probe) given the app ships direct+notarized, never App Store.
- **D-02:** Do NOT go further than that tier — no `dlopen`'ing arbitrary/unrelated frameworks, no patching system binaries, no other exotic techniques beyond private symbol binding / private notification subscription.

**Escalation fallback if truly unfixable**
- **D-03:** If the researcher (again) confirms no proactive pre-transition signal exists at the application layer: ship **no code change**. Revert/discard any exploratory code from the investigation, leave the current v1.0 reactive `updateVisibility()` / `orderOut` behavior exactly as it is today, and produce a written root-cause escalation report.
- **D-04:** The escalation report is surfaced to the user for an explicit scope decision (accept as permanent technical debt vs. formally descope FS-01) — do NOT silently ship a "good enough" partial mitigation instead.

**On-device trigger-method coverage**
- **D-05:** The on-device UAT matrix is the **minimum set** from ROADMAP.md: (1) green-button click, (2) menu bar "View > Enter Full Screen", (3) a fullscreen video app (e.g. QuickTime or Safari video fullscreen). No expansion to keyboard shortcuts, video-call apps (Zoom/Slack), Keynote presenter mode, or external-display setups for this phase.

**Investigation depth before declaring escalation**
- **D-06:** This flash was already deep-dived twice with the same conclusion — Phase 2 (`02-04-SUMMARY.md`, original root-cause) and a Phase 6 debug session (`.planning/debug/resolved/fullscreen-enter-flash.md`, re-confirmation). Both concluded no proactive signal exists using public APIs, and a show-debounce was tried and reverted (there's no on-side blip to debounce).
- **D-07:** Given the private-API ceiling (D-01), the researcher **must identify and on-device test at least one concrete NEW candidate signal not already ruled out in the prior debug history** (e.g. a CGS/SkyLight distributed notification firing on Space-transition-*start*, before the compositor pass — as opposed to the existing reactive `activeSpaceDidChangeNotification`/`didActivateApplicationNotification`, which fire after). Escalation (D-03/D-04) is only valid after that new avenue has actually been tried on-device and failed — not a re-statement of the prior conclusion without new investigation.

### Claude's Discretion
- Exact private-API candidate(s) to try (e.g. which CGS/SkyLight notification name, if one exists) — this is research work, not a user decision.
- Whether to consult prior-art from reference apps (e.g. boring.notch) on how they handle this, if at all — left to the researcher's judgment per the "same tier as existing" ceiling.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope (per 08-CONTEXT.md).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **FS-01** | Entering true fullscreen shows no visible island flash at any point during or after the transition | Candidate A (`CGSClientEnterFullscreen`/`CGSClientExitFullscreen`, event codes 106/107, via `CGSRegisterNotifyProc`) as the primary proactive pre-transition signal; Candidate B (`SLSManagedDisplayIsAnimating` poll + new-fullscreen-space detection) as corroboration/fallback — see "Candidate Signal Investigation" |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are authoritative directives — plans MUST NOT contradict them:

- **Swift 5 language mode** — `project.yml` pins `SWIFT_VERSION: "5.0"`. Any new binding code must compile under Swift 5 mode. `[VERIFIED: project.yml]`
- **macOS 14.0 deployment floor** — but this phase's private CGS/SkyLight symbols are OS-*runtime* surface, not SDK/deployment-target gated; their presence must be reconfirmed at execution time on whatever macOS the build machine runs (currently Tahoe/26, see below), independent of the 14.0 floor. `[VERIFIED: project.yml]`
- **Un-sandboxed** (`ENABLE_APP_SANDBOX: NO`) — required for any of this phase's private CGS/SkyLight calls to work at all; already the case. `[VERIFIED: project.yml]`
- **XcodeGen auto-discovery** — no manual `.xcodeproj` edits; run `xcodegen generate` after adding source files. `[VERIFIED: project.yml comments]`
- **No second show/hide path (Pattern 7)** — `updateVisibility()` in `NotchWindowController.swift` must remain the SOLE show/hide arbiter; any new signal feeds it, never bypasses it. `[CITED: 08-CONTEXT.md canonical_refs]`
- **`FullscreenDetector.shouldShow(...)` stays untouched unless the fix genuinely requires a new predicate input** — see "Candidate Signal Investigation" below; this research concludes it likely DOES require one new `Bool` input (a bounded "pending transition" override), which is an explicitly permitted exception per canonical_refs. `[CITED: 08-CONTEXT.md canonical_refs]`

> **Toolchain reality (confirmed live in this research session, 2026-07-04):** build machine is `macOS 27.0` (build `26A5368g`, i.e. Tahoe) / **Xcode 26.6**. All on-device findings below were captured on this exact build. `[VERIFIED: sw_vers + xcodebuild -version, this session]`

## Summary

The fullscreen-enter flash has been root-caused twice (Phase 2, Phase 6) as: the window-server compositor draws the panel's `.canJoinAllSpaces` overlay onto the activating fullscreen Space for ~1 frame, and the app's ONLY hide mechanism (`updateVisibility()` → `panel?.orderOut(nil)`) is wired to two **reactive** signals — `NSWorkspace.activeSpaceDidChangeNotification` and `didActivateApplicationNotification` — both of which fire **after** that compositor pass has already happened. There is nothing wrong in the app's own state machine to debounce (confirmed twice); the gap is a **missing proactive (pre-transition) signal**.

This research identifies a genuinely new, previously-untried candidate: the private CGS notification pair **`CGSClientEnterFullscreen` (event 106)** / **`CGSClientExitFullscreen` (event 107)**, registered via the private `CGSRegisterNotifyProc`/`SLSRegisterNotifyProc` global (all-connections) notification mechanism — the same mechanism macOS's own Dock.app uses to know when *any* client enters/exits fullscreen (needed so the Dock can hide/reclaim itself in sync with the transition, not after it). This is a different **kind** of signal than what was tried before: it is a raw WindowServer client-lifecycle event pushed by the OS, not a Cocoa-level Space/app-activation notification, and by its semantics (a *client entering* fullscreen, not *the Space having changed*) it is a strong candidate to fire at or near the **start**, not the end, of the transition.

**On-device, in this research session:** the private symbols resolve and are callable on the exact Tahoe build machine (`CGSMainConnectionID` returns a valid non-zero connection; `CGSRegisterNotifyProc` returns success (`0`) when registering for events 106, 107, and four other candidate codes). This directly refutes a blanket "CGS notification registration is dead on modern macOS" concern for at least this API surface. **What could NOT be completed on-device:** actually triggering a real native-fullscreen transition to observe the *firing order and timestamp* of event 106 relative to the visible flash — every attempt to synthesize a real fullscreen-enter from this automated shell was blocked by TCC (no Accessibility/Input-Monitoring grant for synthetic keystrokes; a UI-scripting `AXFullScreen` attribute set silently no-op'd without a real Space transition). This is an environment limitation of this research session, not a finding that the signal doesn't work — it is the single remaining unknown and must be the first Wave-0 task of the execution phase, with exact wiring and a DEBUG-log verification protocol provided below.

A secondary candidate, **`SLSManagedDisplayIsAnimating`** (a poll, not a notification — "returns true if the current screen is animating; useful to detect Spaces transitions, windows going fullscreen, etc", used by the actively-maintained `alt-tab-macos` project), was also verified callable on-device, but **only after explicitly linking `SkyLight.framework`** (it is NOT re-exported through CoreGraphics the way `CGSCopyManagedDisplaySpaces` is — a new project-config requirement if this path is used). It is weaker as a *primary* mechanism because it is a boolean poll (needs a driving clock) and fires for ANY display animation (ordinary Space switches too), so it would need to be combined with a "did a new fullscreen-type Space just appear" check to avoid a regression risk (spuriously hiding the island during a normal, non-fullscreen Space switch). It is documented here as a corroboration/fallback, not the recommended primary.

**Primary recommendation:** Wire `CGSRegisterNotifyProc` for events 106 (`CGSClientEnterFullscreen`) and 107 (`CGSClientExitFullscreen`) as two new observers in `NotchWindowController`, feeding a bounded, fail-safe-timeout `pendingFullscreenTransition` flag OR'd into the existing pure `shouldShow(...)` predicate (a scoped, justified extension of `FullscreenDetector.swift`) — NOT a bypass of `updateVisibility()`. Execution's Wave 0 must first run the exact on-device DEBUG-timing probe below (Task 0) to confirm event 106 actually fires, and fires meaningfully before the flash, before building the full feature. If it does not fire, or fires no earlier than the existing signals, the SkyLight-poll fallback (Candidate B) is the next thing to try — only after BOTH candidates are on-device-disproven does D-03/D-04 escalation become valid.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen-transition-start detection (raw signal) | WindowServer / OS (private CGS notification) | — | Only the WindowServer itself knows a client is entering fullscreen before the Space-switch animation completes; no app-level heuristic can originate this |
| Signal→state translation (pending-transition flag, bounded timeout) | AppKit Controller (`NotchWindowController`) | Pure Domain Logic (`FullscreenDetector.shouldShow`) | The controller owns all live observers/timers (Pattern 6); the flag itself should be threaded into the existing pure predicate so `shouldShow` stays the single testable decision point |
| Show/hide execution (the actual `orderOut`/`orderFrontRegardless`) | AppKit Controller (`updateVisibility()`) | — | Pattern 7 — must remain the SOLE show/hide call site; the new signal is an additional trigger to re-run this function, never a parallel hide path |
| Visual presentation (pill/wings SwiftUI) | SwiftUI Presentation (`NotchPillView`) | — | Entirely unaffected by this phase — the fix is invisible to the render layer |

## Standard Stack

No new third-party packages or SPM dependencies. This phase adds:
- Two `@_silgen_name`-bound private CGS functions (Candidate A) — already the codebase's established pattern for private API access, no new risk tier.
- Optionally, an explicit link against the private `SkyLight.framework` (Candidate B only) — a NEW linker requirement not currently in `project.yml`.

### Core (existing, reused)
| Symbol | Purpose | Confidence |
|--------|---------|------------|
| `CGSMainConnectionID()` | Already bound in `FullscreenSpaceProbe.swift`; reused as-is for the new registration calls | HIGH — confirmed on-device this session |
| `CGSCopyManagedDisplaySpaces(_:)` | Already bound; still the confirming/steady-state fullscreen signal (`isBuiltinDisplayInFullscreenSpace`) — UNCHANGED by this phase | HIGH — shipped since Phase 2 |

### New for this phase (Candidate A — primary, recommended)
| Symbol | Purpose | Confidence |
|--------|---------|------------|
| `CGSRegisterNotifyProc(_:_:_:)` | Register a C callback for a raw WindowServer connection-notify event, GLOBAL (all connections, not just self) | MEDIUM-HIGH — [VERIFIED: this session — symbol resolves via the existing `CoreGraphics` import (no extra linker flag needed), registration for events 106/107 returns success (`0`) on the Tahoe build machine]. Whether it actually FIRES for another app's fullscreen, and the exact timing, is UNCONFIRMED — see "What Was/Wasn't Tested". |
| `CGSRemoveNotifyProc(_:_:_:)` | Unregister the same callback/type/userData triple — required in `deinit`, mirroring every other observer teardown in the file | MEDIUM — same symbol family, not itself invoked in this session (registration only); assumed to exist per the same header (`ForceQuitUnresponsiveApps/CGSInternal/CGSNotifications.h`) `[CITED]` |
| Event code `106` (`CGSClientEnterFullscreen`) | The candidate proactive enter-fullscreen signal | MEDIUM — name+code documented across three independent community-maintained CGS headers (see Sources); NOT Apple-documented; firing semantics for *other* processes unconfirmed on-device this session `[ASSUMED — needs on-device firing/timing confirmation]` |
| Event code `107` (`CGSClientExitFullscreen`) | The mirror exit signal, for symmetry/restore | MEDIUM — same provenance as 106 |

### Candidate B — secondary/fallback (needs new linker setting)
| Symbol | Purpose | Confidence |
|--------|---------|------------|
| `SLSManagedDisplayIsAnimating(_:_:)` | Poll: is this display CURRENTLY mid-animation (Space switch OR window→fullscreen)? | MEDIUM — [VERIFIED: this session — resolves and returns `false` at rest, but ONLY when explicitly linking `-framework SkyLight` from `/System/Library/PrivateFrameworks`; **fails to link** via the codebase's current default `import CoreGraphics` alone (undefined symbol at link time) — a NEW `project.yml` requirement if this path is chosen]. Requires a driving poll clock (no push notification); over-triggers on ordinary Space switches unless paired with a "new fullscreen-type Space appeared" disambiguator (untested). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CGSRegisterNotifyProc` events 106/107 (push, Candidate A) | `SLSManagedDisplayIsAnimating` poll (Candidate B) | Poll requires a driving clock (CVDisplayLink/timer — CPU cost, complexity) and a disambiguator against ordinary Space switches (regression risk of over-hiding); a push notification is strictly simpler if it fires early enough. Use B only if A is on-device disproven. |
| Either candidate above | Accessibility (`AXUIElement`/`kAXFullscreenAttribute`) polling of the frontmost app | Already explicitly rejected in Phase 2 research (would require an Accessibility/TCC prompt the project has deliberately avoided so far) and is reactive/poll-based, not proactive — does not solve the timing problem either. |
| Either candidate above | Another show-debounce | Already tried and reverted twice (Phase 2, `cc7f3c1`/`f706f66`) — there is no on-side blip to debounce; a delay only adds restore latency without fixing the root timing gap. |

**Installation:** no SPM/package changes.
- Candidate A: zero build-config changes (resolves through the existing `import CoreGraphics`, same as `FullscreenSpaceProbe.swift` today).
- Candidate B (if pursued): add to `project.yml` → `targets.Islet.settings.base`:
  ```yaml
  FRAMEWORK_SEARCH_PATHS: "$(inherited) /System/Library/PrivateFrameworks"
  OTHER_LDFLAGS: "$(inherited) -framework SkyLight"
  ```
  then `xcodegen generate`.

## Package Legitimacy Audit

N/A — no external/third-party packages are installed by this phase. Both candidates are Apple-private system-framework symbols (CoreGraphics/SkyLight), accessed via `@_silgen_name`/linker flags, not package-manager dependencies. slopcheck / registry verification do not apply.

## Candidate Signal Investigation (the crux of this phase)

### What was identified

**Candidate A (primary): `CGSClientEnterFullscreen` / `CGSClientExitFullscreen`**

Historical CGS private headers (see Sources) document a `CGSNotificationType`-style enum used with the GLOBAL (all-connections) registration function `CGSRegisterNotifyProc(proc, type, userData)` / its SkyLight-era equivalent `SLSRegisterNotifyProc`. Two entries are directly on-point:

```
CGSClientEnterFullscreen = 106
CGSClientExitFullscreen  = 107
```

This is DIFFERENT IN KIND from both signals already ruled out:
- `NSWorkspace.activeSpaceDidChangeNotification` / `didActivateApplicationNotification` are Cocoa-level, coarse, and — per the twice-confirmed root-cause — fire only AFTER the Space transition (and its compositor pass) completes.
- Event 106/107 are raw WindowServer connection-notify events describing a *client's* fullscreen state transition specifically. The registration API used (`CGSRegisterNotifyProc`, no `cid` parameter — global for all connections, the SAME mechanism `kCGSNotificationWorkspaceChanged`=1401 uses to feed the system-wide `activeSpaceDidChangeNotification`) is consistent with being observable cross-process, without any Accessibility/TCC prompt.
- Semantically, "a client is entering fullscreen" is the *trigger* for the Space transition, not a report of its *outcome* — Dock.app itself must know this early (it starts hiding/reclaiming its strip in visual sync with the slide animation, not after). This makes it plausible (not yet confirmed) that 106 fires at or very near the **start** of the transition, before the compositor pass that currently produces the flash.

**Candidate B (secondary/fallback): `SLSManagedDisplayIsAnimating` + new-fullscreen-Space detection**

From the actively-maintained `alt-tab-macos` project's private-API bindings:
```swift
// returns true if the current screen is animating
// useful to detect Spaces transitions, windows going fullscreen, etc
@_silgen_name("SLSManagedDisplayIsAnimating")
func SLSManagedDisplayIsAnimating(_ cid: CGSConnectionID, _ displayUuid: ScreenUuid) -> Bool
```
This is a poll (no push notification), so it would need a driving clock (e.g. a `CVDisplayLink` callback firing every vsync, ~16.7ms) to catch the animating-flag flip as early as possible. Because it returns `true` for ANY display animation (ordinary virtual-desktop Space switches included, not just fullscreen), using it alone would risk a REGRESSION: hiding the island during a normal Space switch where it should stay visible. The research-time design mitigation is to combine it with a check of whether the built-in display's per-display "Spaces" list (already read by `CGSCopyManagedDisplaySpaces` in `FullscreenSpaceProbe.swift`) has just gained a NEW `type == 4` (fullscreen) entry that wasn't present on the previous poll — i.e., only treat "isAnimating" as fullscreen-relevant if a fullscreen-type Space is newly appearing. This combined design is UNTESTED (research-time reasoning only, not on-device verified) and is documented as the fallback, not the recommendation.

### What was tested on-device vs. what must be tested during execution

**Tested on-device in this research session** (real machine: macOS 27.0/26A5368g, Xcode 26.6 — the actual ship/dev machine, confirmed via `sw_vers`/`xcodebuild -version`):

1. **Symbol resolution / linkage** — wrote and compiled a standalone Swift command-line probe (`swiftc`) binding `CGSMainConnectionID`, `CGSRegisterNotifyProc`, and separately `SLSManagedDisplayIsAnimating` via `@_silgen_name`, exactly mirroring `FullscreenSpaceProbe.swift`'s existing pattern.
   - `CGSMainConnectionID()` → returned a valid non-zero connection ID (e.g. `804419`, `402039` across runs) — confirms this shell has genuine WindowServer/GUI-session access (also confirmed via `NSScreen.screens` correctly reporting the real built-in display, `1470×956`, `safeAreaTop=32.0` — matching the project's known notch geometry from prior-phase memory).
   - `CGSRegisterNotifyProc(callback, UInt32(106), nil)`, `...(107)`, and four other candidate codes (`1401`, `1204`, `1508`, `1700`) — **all returned `0` (success)** with NO extra linker flags (resolves purely through the codebase's existing `import CoreGraphics`). This directly refutes, for this specific API, a WebSearch-surfaced claim that "`CGSRegisterNotifyProc` doesn't work anymore" (that claim was about a different specific use — app-unresponsive notifications — not a blanket dead-API finding; registration itself is clearly still live on Tahoe).
   - `SLSManagedDisplayIsAnimating(cid, builtinUUID)` — **failed to link** (`Undefined symbols for architecture arm64: _SLSManagedDisplayIsAnimating`) when relying on the same default `import CoreGraphics`/`import Cocoa` the codebase already uses — it is genuinely NOT re-exported through CoreGraphics the way `CGSCopyManagedDisplaySpaces` is. It **resolved and ran successfully** (`= false`, correct at-rest value) only after explicitly adding `-F/System/Library/PrivateFrameworks -framework SkyLight` to the link line. **This is a real, actionable finding: Candidate B requires a new `project.yml` linker setting; Candidate A does not.**

2. **Attempted real fullscreen-transition trigger** (to observe actual firing + timing) — multiple approaches were attempted from this automated shell:
   - `osascript`/System Events synthetic keystroke (`Ctrl+Cmd+F`) → **blocked**: `osascript ist nicht berechtigt, Tastatureingaben zu senden (1002)` — no Accessibility/Input-Monitoring TCC grant for this shell's controlling process.
   - `osascript`/System Events setting the `AXFullScreen` attribute directly (UI-scripting, not a keystroke) on a TextEdit window → command completed with no error, but **no** `activeSpaceDidChangeNotification` fired afterward (only baseline `didActivateApplicationNotification` from app launch/quit) — strong evidence this silently no-op'd rather than genuinely entering fullscreen (a real native-fullscreen-enter always creates a new Space, which the existing reactive baseline observer would have caught).
   - Confirmed via `who`/`ps` that this IS an interactive console session (`lippi304 console`, `WindowServer` running) — the blocker is a TCC permission gap for THIS specific automation path, not a headless/non-GUI environment.

**Could NOT be tested on-device in this session (must be Wave 0 of execution):**
- Whether `CGSClientEnterFullscreen` (106) / `CGSClientExitFullscreen` (107) actually **fire** for another app's real native-fullscreen transition.
- If they fire, their **timing** relative to (a) the existing `activeSpaceDidChangeNotification`, and (b) the visible compositor flash itself, across all three D-05 trigger methods (green-button, menu-bar Enter Full Screen, fullscreen video).
- Whether, at the moment 106 fires, `isBuiltinDisplayInFullscreenSpace()` (the existing CGS current-space-type==4 read) has already flipped to `true`, or is still `false` (i.e. whether a simple "re-run `updateVisibility()` on 106" is sufficient, or whether a bounded `pendingFullscreenTransition` override flag is genuinely required — see "Integration Point" below).

This is a genuine capability gap of this research session (TCC-restricted automated shell, not a physical human at the keyboard) — not a finding that the candidate fails. **Escalation (D-03/D-04) is NOT warranted yet**: a concrete new avenue was identified, partially verified as viable at the API-surface level, and the one remaining question (does it fire early enough) is a bounded, cheap, well-specified on-device task, not an open-ended re-investigation.

### Recommended Wave-0 on-device task (exact protocol for the plan)

Add this DEBUG-only instrumentation (temporary, or gated `#if DEBUG`) to `NotchWindowController.start()`, alongside the existing `spaceObserver`/`appActivateObserver` registration (near line 255-263):

```swift
// Wave 0 probe ONLY — confirm firing + relative timing before building the real feature.
#if DEBUG
private let cgsProbeCallback: CGSNotifyProc = { type, data, dataLength, userData in
    print("[FS-01 probe] CGS event \(type) fired at \(Date())")
}
#endif
```
and register/unregister it for 106 and 107 exactly like the code in "Code Examples" below, PLUS keep the two existing `NSWorkspace` observers logging their own fire time. Then, on-device, a human runs the D-05 trigger matrix (green-button, menu-bar, fullscreen video) while watching Console.app / stdout, and records:
1. Does event 106 fire at all? (if NOT → Candidate A is disproven, move to Candidate B or escalate)
2. Its timestamp vs. `activeSpaceDidChangeNotification`'s timestamp (is 106 earlier?)
3. Whether the visible flash is now gone if `updateVisibility()` is called immediately inside the 106 handler (a quick spike/prototype, before building the full bounded-flag design)

If 106 fires meaningfully before the existing signals AND a same-instant `isBuiltinDisplayInFullscreenSpace()` read already reports `true`, the fix is as simple as adding two more observers that call `updateVisibility()` (no new predicate input needed — a smaller change than anticipated). If it fires early but the CGS space-type hasn't flipped yet, build the bounded `pendingFullscreenTransition` override described below.

### Integration point into `NotchWindowController`

Mirrors the EXACT existing observer-registration pattern (canonical_refs: "the template for wiring up any additional observer"):

```swift
// near the existing spaceObserver/appActivateObserver registration (NotchWindowController.swift ~255-263)
private var enterFullscreenToken: CGSNotifyProc?  // see Code Examples — C function pointers can't capture context

// in start(), alongside the existing NSWorkspace observers:
CGSRegisterNotifyProc(cgsFullscreenCallback, UInt32(kCGSClientEnterFullscreen), selfContext)
CGSRegisterNotifyProc(cgsFullscreenCallback, UInt32(kCGSClientExitFullscreen), selfContext)

// in deinit, alongside the existing observer teardown:
CGSRemoveNotifyProc(cgsFullscreenCallback, UInt32(kCGSClientEnterFullscreen), selfContext)
CGSRemoveNotifyProc(cgsFullscreenCallback, UInt32(kCGSClientExitFullscreen), selfContext)
```

If the Wave-0 probe shows the CGS space-type has NOT yet flipped when 106 fires, thread a new bounded input into the pure predicate (the one explicitly-permitted exception to "`FullscreenDetector.swift` stays untouched"):

```swift
// FullscreenDetector.swift — ONE new parameter, still a pure function, still fully unit-testable
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool, pendingFullscreenTransition: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && (isFullscreen || pendingFullscreenTransition))
}
```
`pendingFullscreenTransition` is set `true` the instant the 106 callback fires, and cleared either (a) on the NEXT `updateVisibility()` call where `isBuiltinDisplayInFullscreenSpace()` genuinely reads `true` (the real signal has caught up — steady-state takes over), (b) on the 107 exit callback (transition aborted/completed the other way), or (c) a short bounded safety timeout (e.g. 1s — mirroring the fail-safe-to-visible philosophy: if neither (a) nor (b) ever arrives, assume 106 was spurious/unrelated and stop overriding, rather than permanently hiding the island). This keeps `updateVisibility()` the sole show/hide site (Pattern 7) and keeps the override bounded and self-healing rather than a new independent hide path.

## Architecture Patterns

### System Architecture Diagram

```
 Another app requests fullscreen (green-button / menu / video)
              │
              ▼
   WindowServer / SkyLight (private, OS-owned)
              │
   ┌──────────┴───────────────────────────────┐
   │ (existing, reactive — fires AFTER)        │ (NEW candidate — CGSClientEnterFullscreen
   │                                            │  event 106, hypothesized to fire near/at
   ▼                                            ▼  transition START)
 activeSpaceDidChangeNotification      CGSRegisterNotifyProc callback (106/107)
 didActivateApplicationNotification            │
   │                                            │
   └──────────────┬─────────────────────────────┘
                   ▼
         NotchWindowController.updateVisibility()   ◄── Pattern 7: SOLE show/hide arbiter
                   │
        reads: selectTargetScreen (Phase 1)
               isBuiltinDisplayInFullscreenSpace (Phase 2, steady-state)
               pendingFullscreenTransition (NEW, bounded/self-healing — only if Wave 0 shows it's needed)
                   │
                   ▼
         shouldShow(...) — pure predicate (FullscreenDetector.swift)
                   │
          ┌────────┴────────┐
          ▼                 ▼
   panel.orderOut(nil)   positionAndShow(on:) → panel.orderFrontRegardless()
   (the ONE hide call)    (the ONE show call)
```

### Recommended file changes (no new files)
```
Islet/Notch/
├── FullscreenSpaceProbe.swift    # + CGSRegisterNotifyProc/CGSRemoveNotifyProc @_silgen_name bindings,
│                                 #   event constants (106/107), alongside the existing CGS bindings —
│                                 #   same file, same "thin system-call wrapper" role, no new file needed
├── FullscreenDetector.swift      # possibly + one new Bool param to shouldShow (ONLY if Wave 0 shows the
│                                 #   CGS space-type hasn't flipped yet when 106 fires — see above)
└── NotchWindowController.swift   # + 2 CGSRegisterNotifyProc observers near the existing spaceObserver/
                                  #   appActivateObserver registration (~line 255-263); + teardown in
                                  #   deinit (~line 1039-1069); + (if needed) pendingFullscreenTransition
                                  #   state + its bounded-timeout clear, mirroring graceWorkItem's
                                  #   DispatchWorkItem-cancel-on-supersede idiom already used elsewhere
                                  #   in this file (e.g. deviceBatteryWork)
```

### Pattern: Global CGS notify registration with a context pointer (C callback, no closures)
**What:** `CGSNotifyProc`-style callbacks are plain C function pointers (`@convention(c)`) — they CANNOT capture Swift context (no `self` closure capture). The established idiom (used throughout AppKit/Core Foundation C-callback APIs) is to pass an opaque `Unmanaged<T>` pointer as the `userData`/`context` parameter and unwrap it inside the (necessarily static/global) callback function.
**Why it's the same risk tier as what's shipped:** identical `@_silgen_name` private-symbol-binding technique as `FullscreenSpaceProbe.swift`'s `CGSMainConnectionID`/`CGSCopyManagedDisplaySpaces` — no `dlopen`, no new framework beyond CGS/SkyLight (already the accepted tier per D-01).

```swift
// Source: composed from ForceQuitUnresponsiveApps/CGSInternal/CGSNotifications.h (event enum + proc
// typedef) + this session's on-device linkage confirmation. NOT Apple-documented — community-reverse-
// engineered header used by multiple long-standing macOS utilities (see Sources).
private let kCGSClientEnterFullscreen: UInt32 = 106
private let kCGSClientExitFullscreen: UInt32 = 107

typealias CGSNotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

@_silgen_name("CGSRegisterNotifyProc") @discardableResult
func CGSRegisterNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("CGSRemoveNotifyProc") @discardableResult
func CGSRemoveNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

// The callback itself MUST be a global/static function (no captures) — pass `self` via userData.
private let fullscreenTransitionCallback: CGSNotifyProc = { type, _, _, userData in
    guard let userData else { return }
    let controller = Unmanaged<NotchWindowController>.fromOpaque(userData).takeUnretainedValue()
    // CGS raw callbacks give NO main-thread guarantee (unlike NSWorkspace's `queue: .main`) —
    // ALWAYS hop before touching AppKit/@Published, mirroring every other controller entry point.
    DispatchQueue.main.async {
        controller.handleFullscreenTransitionEvent(type: type)
    }
}
```

### Anti-Patterns to Avoid
- **Calling `orderOut`/`orderFrontRegardless` directly from the CGS callback:** creates a second show/hide path, violating Pattern 7. Route through `updateVisibility()` (or the new bounded flag it reads) exactly like every other observer in the file.
- **Trusting `SLSManagedDisplayIsAnimating` alone as a fullscreen signal:** it is `true` for ANY display animation (ordinary Space switches included) — using it unguarded would regress ISL-05's "maximized/ordinary Space switch stays visible" behavior. Must be paired with a fullscreen-Space-appeared check (Candidate B, untested).
- **An unbounded `pendingFullscreenTransition` flag with no timeout/clear path:** if 106 fires but the transition is aborted or a corresponding confirming signal never arrives (app crash mid-transition, spurious event), an unbounded override would permanently hide the island — violates the established fail-safe-to-visible philosophy. Always pair with a bounded timeout clear.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting a raw WindowServer client-fullscreen event | A CGWindowList polling loop diffing window styleMasks | `CGSRegisterNotifyProc` for events 106/107 | The WindowServer already pushes this exact event; polling window lists is the same class of unreliable heuristic Phase 2 already rejected (can't reliably distinguish maximized from fullscreen either) |
| Bounding a speculative proactive-hide flag | A recurring timer that keeps re-checking forever | A single `DispatchWorkItem` timeout, mirroring the existing `graceWorkItem`/`dismissWorkItem` one-shot-then-idle idiom already used 4+ times in this exact file | Consistent with the file's established "one wake-up, then idle — no recurring timer, ~0% idle CPU" convention |

**Key insight:** Every other "hard part" in this codebase (fullscreen steady-state, hover focus-safety, media bridging) already had a first-party-or-private primitive; the pattern holds here too — the missing piece was never a debounce, it was a missing **push** signal, and the WindowServer already emits one (106/107) for exactly this client-lifecycle transition. The work is wiring + bounded-fallback design, not new mechanism invention.

## Common Pitfalls

### Pitfall 1: CGS raw callback fires off the main thread
**What goes wrong:** touching `@Published`/AppKit directly inside the callback crashes or corrupts state.
**Why it happens:** unlike `NSWorkspace.shared.notificationCenter` (registered with `queue: .main`), raw `CGSRegisterNotifyProc` callbacks give no threading guarantee.
**How to avoid:** ALWAYS `DispatchQueue.main.async` inside the callback before calling into the controller (see Code Examples). Verify with a DEBUG thread-assertion during Wave 0.

### Pitfall 2: Event 106/107 turn out to be self-scoped (only fire for this process's own fullscreen)
**What goes wrong:** Islet never goes fullscreen itself (it's an `LSUIElement` agent), so if 106/107 are actually scoped to the registering connection's OWN transitions (like the header's noted 729-731 "only for this process" caveat for a *different* event range), they would never fire for another app — mirroring the exact Q3 failure mode that killed the original safe-area heuristic in Phase 2.
**Why it happens:** not every CGS notify event is global; some are explicitly self-only per the historical header's own comments.
**How to avoid:** this is exactly what the Wave-0 on-device test (D-05 trigger matrix with a real other app, e.g. TextEdit/Safari/QuickTime) determines. If 106/107 never fire while a DIFFERENT app enters fullscreen, treat Candidate A as disproven and move to Candidate B.

### Pitfall 3: `pendingFullscreenTransition` never clears (permanently hides the island)
**What goes wrong:** if the bounded design is built but the clear conditions are wired wrong (e.g. the timeout `DispatchWorkItem` isn't scheduled, or 107/steady-state-confirm never reach it), the island could stay hidden forever after any 106 event, including a false one.
**Why it happens:** exactly the class of bug the existing `graceWorkItem`/`dismissWorkItem` one-shot-then-idle pattern is designed to prevent — a scheduled clear must always be armed the instant the flag is set `true`.
**How to avoid:** mirror the existing `deviceBatteryWork`-style "cancel previous, schedule fresh" idiom exactly; add a unit test on the pure `shouldShow(..., pendingFullscreenTransition:)` predicate (trivial — it's still a pure function) plus a manual on-device check that toggling airplane-mode-style abort scenarios (start fullscreen, immediately Cmd-Tab away) still restores the island.

### Pitfall 4: `SLSManagedDisplayIsAnimating` link failure if Candidate B is attempted without the project.yml change
**What goes wrong:** `Undefined symbols for architecture arm64: _SLSManagedDisplayIsAnimating` at build time.
**Why it happens:** confirmed on-device this session — the symbol is NOT re-exported through `CoreGraphics` (unlike `CGSCopyManagedDisplaySpaces`); it lives directly in `SkyLight.framework` and needs an explicit link.
**How to avoid:** add `FRAMEWORK_SEARCH_PATHS`/`OTHER_LDFLAGS` to `project.yml` as shown in "Standard Stack" BEFORE attempting to use this symbol. Only relevant if Candidate A is disproven and Candidate B is pursued.

## Code Examples

### Full candidate-A wiring sketch (illustrative — exact form to be finalized after the Wave-0 timing probe)
```swift
// Source: composed this session from CGSNotifications.h (ForceQuitUnresponsiveApps) + the existing
// FullscreenSpaceProbe.swift binding convention. On-device confirmed: symbols resolve + register
// successfully on macOS 27.0/26A5368g via the codebase's existing `import CoreGraphics` (no new
// linker flags). NOT confirmed on-device: actual cross-process firing + relative timing (Wave 0).

// FullscreenSpaceProbe.swift — additions alongside the existing CGS bindings:
private let kCGSClientEnterFullscreen: UInt32 = 106
private let kCGSClientExitFullscreen: UInt32 = 107

typealias CGSNotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

@_silgen_name("CGSRegisterNotifyProc") @discardableResult
func CGSRegisterNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("CGSRemoveNotifyProc") @discardableResult
func CGSRemoveNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

// NotchWindowController.swift — near the existing spaceObserver/appActivateObserver (start(), ~L255):
private let fullscreenTransitionCallback: CGSNotifyProc = { type, _, _, userData in
    guard let userData else { return }
    let controller = Unmanaged<NotchWindowController>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { controller.handleFullscreenTransitionEvent(type: type) }
}
private lazy var selfContext = Unmanaged.passUnretained(self).toOpaque()

// in start():
CGSRegisterNotifyProc(fullscreenTransitionCallback, kCGSClientEnterFullscreen, selfContext)
CGSRegisterNotifyProc(fullscreenTransitionCallback, kCGSClientExitFullscreen, selfContext)

// in deinit (alongside the existing observer teardown):
CGSRemoveNotifyProc(fullscreenTransitionCallback, kCGSClientEnterFullscreen, selfContext)
CGSRemoveNotifyProc(fullscreenTransitionCallback, kCGSClientExitFullscreen, selfContext)
```

### On-device verification snippet used THIS session (confirms linkage/registration, not firing)
```swift
// Standalone probe (not shipped code) — compiled + run on the actual dev machine this session.
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
let cid = CGSMainConnectionID()   // => non-zero, e.g. 804419 — confirms live WindowServer connection
// CGSRegisterNotifyProc(callback, 106, nil) => returned 0 (success) for events 106,107,1401,1204,1508,1700
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Reactive `activeSpaceDidChangeNotification`/`didActivateApplicationNotification` only (v1.0/Phase 2/Phase 6) | + proactive `CGSClientEnterFullscreen`/`ExitFullscreen` push notification (this phase, pending on-device confirmation) | This phase | If confirmed, closes the timing gap that caused the flash; if disproven, the fallback is `SLSManagedDisplayIsAnimating` polling, not another debounce |

**Deprecated/outdated to avoid:**
- Show-debounce as a fix — proven twice (Phase 2, Phase 6) that there is no on-side blip to debounce; do not retry.
- Treating "no perfect public API" (true) as "no viable private signal" (not yet established) — this research shows there IS an untried private candidate matching the exact semantic needed.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `CGSClientEnterFullscreen`/`CGSClientExitFullscreen` (event codes 106/107) actually fire for a DIFFERENT process's fullscreen transition (not self-scoped) | Candidate Signal Investigation | HIGH if wrong — Candidate A is entirely dead (mirrors the exact Q3 failure mode from Phase 2's safe-area heuristic); must be the FIRST thing confirmed in Wave 0 |
| A2 | Event 106 fires meaningfully BEFORE the compositor pass that produces the flash (not simultaneously with, or after, the existing reactive signals) | Candidate Signal Investigation | HIGH if wrong — if it fires at the same time or later, it provides no timing advantage over what's already shipped, and the phase falls to Candidate B or escalation |
| A3 | At the moment 106 fires, `isBuiltinDisplayInFullscreenSpace()`'s CGS current-space-type read may still show the OLD (non-fullscreen) type, requiring the bounded `pendingFullscreenTransition` override rather than a bare `updateVisibility()` re-run | Integration Point | MEDIUM — if wrong (the type has already flipped by the time 106 fires), the fix is simpler than designed (just 2 more observers, no new predicate input) — a pleasant surprise, not a risk, but the plan should probe this explicitly rather than assume either way |
| A4 | `SLSManagedDisplayIsAnimating` + a "new fullscreen-Space appeared" check would reliably disambiguate fullscreen-enter animations from ordinary Space-switch animations | Candidate B | MEDIUM — untested reasoning; if wrong, Candidate B would either miss cases or over-trigger (regression risk); only relevant if Candidate A is disproven |
| A5 | The community-sourced CGS notification header (event enum, `CGSNotifyProc` typedef) is accurate for the CURRENT (Tahoe/macOS 27) WindowServer, not just historically (headers date to 2007-2008 originally, cross-referenced against a 2015-2016 update and the actively-maintained 2024-2026 `alt-tab-macos` project) | Standard Stack / Candidate Signal Investigation | MEDIUM — the numeric codes and registration function SIGNATURE were confirmed callable on-device this session (returns success), but the SEMANTIC meaning of "106" specifically (vs. just "some event number that happens to register without erroring") is cross-referenced across 3 independent sources, not Apple-confirmed |

## Open Questions

1. **Does `CGSClientEnterFullscreen` (106) fire for another process's fullscreen transition, and if so, how early relative to the compositor flash?**
   - What we know: the symbol/registration mechanism is live and callable on the exact ship OS build; the semantic name and event code are corroborated across 3 independent community CGS headers spanning ~2007-2026.
   - What's unclear: actual on-device firing behavior for a cross-process trigger — blocked in this research session by a TCC restriction on synthetic input in the automation shell used.
   - Recommendation: Wave-0 execution task, exact protocol specified above (DEBUG print + a human running the D-05 trigger matrix). This is a ~15-30 minute manual verification, not a re-investigation.

2. **If Candidate A is confirmed but the CGS space-type hasn't flipped yet at 106-fire-time, is a 1s bounded timeout on `pendingFullscreenTransition` the right value, or does it need tuning per trigger method (video apps may take a different duration to complete their Space transition than green-button)?**
   - What we know: the existing codebase's established one-shot-timer idiom (`graceWorkItem`, `dismissWorkItem`, `deviceBatteryWork`) uses seed constants tuned during execution/on-device checkpoints, not fixed at research time.
   - What's unclear: the actual Space-transition duration across all three D-05 trigger methods on this exact machine/OS.
   - Recommendation: treat as a Plan-level tuning seed (like `graceDelay`/`springResponse` already are), confirmed at the on-device human-verify checkpoint, not hard-coded from research.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Private CGS `CGSRegisterNotifyProc`/`CGSMainConnectionID` (via `CoreGraphics` re-export) | Candidate A | ✓ | confirmed live on macOS 27.0/26A5368g this session | Candidate B if firing/timing disproven |
| Private `SkyLight.framework` direct link (`SLSManagedDisplayIsAnimating`) | Candidate B only | ✓ (requires explicit linker flags not yet in project.yml) | confirmed live this session, AFTER adding `-framework SkyLight` | N/A — only needed if Candidate A fails |
| Un-sandboxed build (`ENABLE_APP_SANDBOX: NO`) | both candidates | ✓ (already set) | — | — |
| A physical human at the keyboard to trigger real fullscreen transitions (green-button/menu/video) for on-device timing confirmation | Wave-0 verification of A1/A2 (Open Questions) | ✗ in THIS research session (TCC-blocked automation) | — | Required as an execution-phase manual checkpoint; no automatable fallback found (synthetic keystrokes and AX-attribute UI-scripting both failed to produce a real transition in this session) |

**Missing dependencies with no fallback:**
- None blocking the PLAN itself — the one missing piece (live on-device timing confirmation) is explicitly scoped as the plan's first Wave-0 task, not a research blocker.

**Missing dependencies with fallback:**
- Candidate A firing/timing unconfirmed → Candidate B (`SLSManagedDisplayIsAnimating`, needs the new linker setting) is the documented fallback if A is disproven on-device.

## Validation Architecture

> `nyquist_validation` is enabled (`.planning/config.json` → `workflow.nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, hosted unit-test bundle `IsletTests` (`@testable import Islet`) |
| Config file | `project.yml` (XcodeGen) → `IsletTests` target |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FS-01 | `shouldShow(...)` correctly ANDs the new `pendingFullscreenTransition` input (if the bounded-flag design is needed) — pure logic, fully unit-testable | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` | ✅ exists, extend with new cases (only if the flag design is built) |
| FS-01 | The bounded timeout actually clears `pendingFullscreenTransition` (no permanent hide) | unit (if the pure state-transition is extracted, mirroring `nextState` in `InteractionStateTests`) or manual | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` (extend) | ❌ Wave 0 — extend existing suite if the flag lands |
| FS-01 | No visible flash across all 3 D-05 trigger methods, repeated trials; existing hide-during/restore-after-fullscreen behavior unregressed | **manual on-device** | n/a (visual — this is the actual success criterion) | — |

### Sampling Rate
- **Per task commit:** `-only-testing:IsletTests/FullscreenDetectorTests` (and `VisibilityDecisionTests` if extended) — pure logic, < 30s.
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite).
- **Phase gate:** full suite green + the on-device D-05 trigger matrix (repeated trials, all 3 methods) signed off before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] **The DEBUG-timing probe itself** (this research's "Recommended Wave-0 on-device task") — not a test file, but a required manual on-device step BEFORE the feature is built past a spike, to decide between "just 2 observers" vs. "bounded pending-flag" designs.
- [ ] Extend `IsletTests/FullscreenDetectorTests.swift` and/or `VisibilityDecisionTests.swift` — only once the Wave-0 probe determines which design is needed.
- Framework install: none — XCTest infra already exists.

## Security Domain

> `security_enforcement` not set to `false` in config → included.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V4 Access Control | partial | This phase deliberately AVOIDS any new TCC/Accessibility prompt — both candidates (CGS notify registration, SkyLight symbol) work un-sandboxed with no permission dialog, consistent with the project's existing no-AX-prompt discipline (Phase 2 Q3) |
| V5 Input Validation | minimal | The CGS callback's `data`/`dataLength` parameters are not parsed by the recommended design (only `type` is read to decide which event fired) — no untrusted payload parsing introduced |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| C callback registered against a raw OS API outlives its owner (dangling `Unmanaged` context pointer) | Memory safety / use-after-free | `CGSRemoveNotifyProc` MUST be called in `deinit` with the exact same proc/type/userData triple used at registration — mirror the existing `mouseMonitor`/`powerMonitor`/`nowPlayingMonitor` teardown discipline already in `deinit` |
| An unbounded proactive-hide override becomes an availability bug (island permanently hidden) | DoS (self-inflicted) | Bounded timeout + multiple clear paths (steady-state confirm, exit event, timeout) — see Pitfall 3 |

## Sources

### Primary (HIGH confidence — this session's own on-device verification)
- This session's `swiftc`-compiled standalone probes, run on the actual project dev machine (macOS 27.0, build 26A5368g, Xcode 26.6) — confirmed `CGSMainConnectionID`/`CGSRegisterNotifyProc` linkage + registration success for events 106/107/1401/1204/1508/1700 via the existing `CoreGraphics` import; confirmed `SLSManagedDisplayIsAnimating` requires an explicit `-framework SkyLight` link (fails otherwise).
- `Islet/Notch/FullscreenSpaceProbe.swift`, `FullscreenDetector.swift`, `NotchWindowController.swift`, `NotchPanel.swift` — read in full this session; the exact integration points and existing conventions cited above are drawn directly from this code, not summarized/assumed.
- `.planning/debug/resolved/fullscreen-enter-flash.md`, `.planning/phases/02-hover-expand-fullscreen-hardening/02-04-SUMMARY.md`, `02-RESEARCH.md`, `02-CONTEXT.md` — the twice-confirmed root-cause history this research builds on.

### Secondary (MEDIUM confidence — community-maintained, cross-referenced)
- `rentzsch/ForceQuitUnresponsiveApps` — `CGSInternal/CGSNotifications.h` (2007-2008 origin; zlib license) — the `CGSNotificationType` enum, `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc` signatures, `CGSNotifyProcPtr` typedef. https://github.com/rentzsch/ForceQuitUnresponsiveApps/blob/master/CGSInternal/CGSNotifications.h
- `NUIKit/CGSInternal` — `CGSConnection.h` (updated 2015-2016 by Robert Widmann/CodaFi) — `CGSMainConnectionID`, connection-lifecycle functions, corroborates the same notification data structs. https://github.com/NUIKit/CGSInternal/blob/master/CGSConnection.h
- `lwouis/alt-tab-macos` — `src/experimentations/PrivateApis.swift` (actively maintained 2024-2026 project targeting current macOS) — `SLSManagedDisplayIsAnimating`, `CGSSpaceGetType`, `SLSRegisterConnectionNotifyProc`/`SLSRegisterNotifyProc`, and the full valid-event-code list including 106/107, with the explicit comment "most interesting events for Mission Control seem to be [1204, 1401, 1508]". https://github.com/lwouis/alt-tab-macos/blob/master/src/experimentations/PrivateApis.swift
- `shabble/osx-space-id` — `CGSPrivate.h` — independently corroborates `CGSClientEnterFullscreen = 106` / `CGSClientExitFullscreen = 107` and `CGSWorkspaceChangedEvent = 1401`. https://github.com/shabble/osx-space-id/blob/master/CGSPrivate.h

### Tertiary (LOW confidence — general web search, not independently verified)
- General WebSearch results on `CGSRegisterNotifyProc`/yabai/AeroSpace ecosystem context (Spaces internals, SIP requirements for more invasive window-moving APIs — NOT used by this phase's recommended design, which stays read-only/observational).

## Metadata

**Confidence breakdown:**
- Candidate identification (a genuinely new, previously-untried signal exists): HIGH — corroborated across 3 independent community sources spanning ~18 years, plus this session's own on-device linkage confirmation.
- Candidate viability (does it actually solve the timing problem): MEDIUM — the one decisive test (real cross-process firing + timing) could not be completed in this research session (TCC-restricted automation) and is scoped as the plan's first Wave-0 task.
- Escalation risk: LOW at this time — D-03/D-04 escalation is NOT yet warranted; a concrete, plausible, partially-verified new avenue exists and has not been on-device disproven.

**Research date:** 2026-07-04
**Valid until:** ~2026-07-18 (short window — this research's central finding depends on an OS-version-specific private API; any macOS point update to the Tahoe build machine should re-trigger a quick re-check of `CGSRegisterNotifyProc` registration success before the plan proceeds).
