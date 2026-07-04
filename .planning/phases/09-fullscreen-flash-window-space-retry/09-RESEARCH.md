# Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry - Research

**Researched:** 2026-07-04
**Domain:** Private CGS (CoreGraphics Services) window/Space management APIs on macOS
**Confidence:** MEDIUM (Candidate C mechanism verified against two independent shipping reference implementations; several concrete facts diverge from what CONTEXT.md assumed)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Creating/managing a dedicated CGS Space (`CGSSpaceCreate`, `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`) is in the same accepted risk tier as the project's existing private-API usage (MediaRemote adapter, `CGSCopyManagedDisplaySpaces` in `FullscreenSpaceProbe.swift`) — same `@_silgen_name` symbol-binding technique, just more call surface. No additional pre-approval gate is needed before writing code.
- **D-02:** The ceiling is exactly those 4 CGS functions. If research finds Candidate C needs additional private mechanisms beyond them (extra Space attributes, a private Space-ownership flag, etc.), that is a stop signal — fall back to Candidate B or escalate. Do not keep expanding the private-API surface to make Candidate C work. **(See Open Question 1 — this research found the reference implementation needs 7-8 symbols, not 4. This is a live tension with the locked decision that must be re-adjudicated, not silently resolved by this research.)**
- **D-03:** `NotchPanel.collectionBehavior` is core plumbing touched by nearly every existing phase. Before accepting Candidate C, the full core-behavior suite must be re-verified on-device: hover/click-expand without focus steal, click-through outside the pill, visibility across all Spaces (not just one), correct positioning through clamshell/external-display changes, and continued correct hide-during-fullscreen/restore-on-exit. Treat this as a targeted re-run of the existing Phase 1/2 UAT points, scoped to the new Space architecture.
- **D-04:** Any regression found during that suite — however small (e.g. click-through working only most of the time, a one-frame-late reposition after a display change) — is a show-stopper, not a "fix later" item. Candidate C is not accepted with known regressions on this component; fix before acceptance, don't defer as follow-up debt.
- **D-05:** If neither Candidate C nor Candidate B closes the flash (or either causes an unfixable regression), this is the final investigation round. FS-01 has now been root-caused across Phase 2, Phase 6, Phase 8, and Phase 9, with four distinct candidate approaches attempted. The resulting escalation report is limited to two options: accept as permanent technical debt, or formally descope FS-01 from REQUIREMENTS.md. No further "investigate a new candidate" loop.
- **D-06:** If Candidate C fails on-device (flash persists, or an unfixable regression per D-04), the plan automatically proceeds to Candidate B in the same phase — no separate user checkpoint/decision gate is needed before attempting B. ROADMAP.md already locks B as the designated fallback; C's failure is itself the trigger.
- **D-07:** In addition to Phase 8's 3-method fullscreen trigger matrix (green-button click, menu-bar "Enter Full Screen", a fullscreen video app), this phase adds an ordinary (non-fullscreen) Space switch (trackpad swipe / Mission Control) as a regression check — because Candidate C changes the panel's fundamental Space membership, not just adding a new detection signal.

### Claude's Discretion
- Exact implementation shape of the CGS Space wrapper (how membership is synced on show/hide, whether it's a new file mirroring `FullscreenSpaceProbe.swift`'s pattern or added to `NotchPanel.swift`) — research/planning work. **(This research recommends a new `CGSSpace.swift` + optional `NotchSpaceManager`, mirroring the reference implementations — see Recommended Project Structure.)**
- Whether an external-display trigger scenario is worth adding to the D-07 matrix beyond the ordinary Space-switch check — left to the planner's judgment based on what Candidate C's actual Space-management design implies for multi-display setups. **(This research additionally surfaces a lock-screen/sleep-wake scenario as worth considering — see Pitfall 3.)**

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. No scope creep occurred; all four discussed areas (private-API risk ceiling, regression safety net, escalation path, trigger-matrix scope) directly govern how Phase 9 investigates and delivers the already-locked Candidate C/B retry.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FS-01 | Entering true fullscreen shows no visible island flash at any point during or after the transition | Candidate C's mechanism (dedicated max-level CGS Space) is documented end-to-end below (Architecture Patterns 1-3, Code Examples) with two verified shipping references. Candidate B's design is unchanged from `08-ESCALATION.md`. The Open Questions section flags the one blocking issue (D-02 ceiling gap) the planner must resolve with the user before implementation tasks can be written for Candidate C. |
</phase_requirements>

## Summary

Candidate C's exact source (`Ebullioscopic/Atoll`'s `NotchSpaceManager`/`CGSSpace.swift`) was located and fetched directly from GitHub, along with its upstream original (`TheBoredTeam/boring.notch`, which Atoll explicitly forked this file from — itself sourced from `avaidyam/Parrot`). Both shipping implementations were read in full. This resolves most of the planner's open questions with HIGH confidence on the *mechanism*, but surfaces two findings that materially change the phase's risk picture and must be surfaced before planning proceeds:

1. **D-02's "exactly 4 functions" ceiling is already exceeded by the reference implementation.** The minimum working `CGSSpace` wrapper in both Atoll and boring.notch binds **7 private symbols**, not 4: `_CGSDefaultConnection` (connection lookup — a different symbol than the codebase's existing `CGSMainConnectionID`, though functionally equivalent), `CGSSpaceCreate`, `CGSSpaceDestroy`, `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`, `CGSHideSpaces`, `CGSShowSpaces` (that's 8 including the connection lookup). Per D-02's own text ("If research finds Candidate C needs additional private mechanisms beyond them... that is a stop signal — fall back to Candidate B or escalate"), this is a **stop signal** the planner and user must explicitly re-adjudicate before writing code — see Open Questions.
2. **Neither reference implementation actually "replaces" `.canJoinAllSpaces`.** Both Atoll's `DynamicIslandWindow` and boring.notch's `BoringNotchWindow` keep the full standard `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]` **unchanged**, and additively insert the window into the dedicated max-level `CGSSpace` (`NotchSpaceManager.shared.notchSpace.windows.insert(window)`) right after `orderFrontRegardless()`. This is a **layered/additive** pattern, not the **replacement** pattern CONTEXT.md describes ("replaces the panel's `.canJoinAllSpaces`... collection behavior"). No reference project was found that removes `.canJoinAllSpaces` while relying on CGSSpace membership alone — that specific combination is untested by any known prior art.

**Primary recommendation:** Prototype Candidate C as an **additive** layer (keep `NotchPanel.collectionBehavior` exactly as-is; add CGSSpace membership alongside it, mirroring the reference implementations exactly) rather than a replacement, since that is the only combination with real shipping precedent — and treat the 7-vs-4-symbol gap as a checkpoint requiring an explicit user/planner decision before writing any Candidate C code, per D-02.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Window Space membership / persistent overlay level | AppKit window shell (`NotchPanel`) | WindowServer/CGS (private, out-of-process) | The app only issues CGS calls; the actual compositing decision (what renders above what, across Space switches) is owned entirely by WindowServer — a system process this app cannot see into or debug directly. |
| Fullscreen-transition detection (Candidate B fallback) | AppKit window shell (`NotchWindowController`) | SkyLight (private, out-of-process) | Same split: a `CVDisplayLink`-driven poll of `SLSManagedDisplayIsAnimating` lives in app code; the animating-flag state itself is owned by the compositor. |
| Show/hide arbitration | `NotchWindowController.updateVisibility()` | — | Must remain the SOLE arbiter (Pattern 7) regardless of which candidate ships — Space membership changes integrate as an *input* to this function's branches, not a parallel call site. |
| Regression suite (D-03) | Local XCTest (`IsletTests`) + on-device manual UAT | — | Space/collectionBehavior changes are structural; some invariants (click-through, focus-safety) are unit-testable, others (visible flash, Space-switch smoothness) are only observable on real notch hardware. |

## Standard Stack

### Core
No third-party libraries are involved in either candidate — both are direct private-framework symbol bindings via `@_silgen_name` (Candidate C) or a linker-level framework link (Candidate B). There is nothing to `npm install`/SPM-add for this phase.

| Mechanism | Source | Purpose | Why this approach |
|-----------|--------|---------|--------------------|
| `@_silgen_name`-bound CGS Space symbols | Private `CoreGraphics`/`SkyLight` (system, not a package) | Create/manage a dedicated always-on-top Space and control the panel's membership in it | Same technique the codebase already ships in `FullscreenSpaceProbe.swift`; no dlopen, no new dependency, resolved at link time against the OS's existing dyld shared cache. |
| `SLSManagedDisplayIsAnimating` (Candidate B, fallback) | Private `SkyLight.framework` | Poll whether the display is mid-animation (Space switch / fullscreen transition) | Documented in `08-ESCALATION.md`; requires an explicit `SkyLight.framework` linker setting since (unlike the `CGS*` symbols used today) it is not re-exported through `CoreGraphics`. |

### Supporting
None beyond what's already in `project.yml` (`MediaRemoteAdapter` — unrelated to this phase).

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled `@_silgen_name` CGS bindings (Candidate C) | `Lakr233/SkyLightWindow` SPM package + `SLSRemoveWindowsFromSpaces`/`delegateWindow` (boring.notch's newer, October-2025 `BoringNotchSkyLightWindow`) | boring.notch itself has a THIRD, more recently added window class using an external package and `dlopen`+`unsafeBitCast` instead of the CGSSpace approach. This is informational only — it is **not** one of the two candidates this phase is scoped to (Candidate C vs B per CONTEXT.md/ROADMAP.md), and D-05 explicitly forecloses "investigate a new candidate" loops. Noted here only so the planner/user has visibility into it as a possible future avenue if both C and B are exhausted. See Open Questions. |

**Installation:** N/A — no packages to install for either candidate.

**Version verification:** N/A — these are OS-private symbols, not versioned packages. Symbol availability was cross-checked against three independent codebases (Atoll, boring.notch, and the NUIKit/CGSInternal reverse-engineered header collection) rather than a package registry.

## Package Legitimacy Audit

**Not applicable to this phase.** Neither Candidate C nor Candidate B installs an external package (npm/SPM/CocoaPods/etc.) — both are private-symbol bindings against OS frameworks already present on every macOS install. The Package Legitimacy Gate (slopcheck, registry verification) has no target here; skipping is correct, not a gap.

## Architecture Patterns

### System Architecture Diagram

```
                     ┌─────────────────────────────────────────┐
                     │              WindowServer (SkyLight)     │
                     │  ┌───────────────┐   ┌─────────────────┐│
   Real user Space A │  │  Space A       │   │  Space B (fs)   ││ Real user Space B
   (desktop)         │  │  (level: user) │   │  (level: user)  ││ (a fullscreen app)
                     │  └───────────────┘   └─────────────────┘│
                     │  ┌───────────────────────────────────┐  │
                     │  │  Dedicated "notch" Space           │  │  ← created ONCE at
                     │  │  (level: Int32.max, ALWAYS shown)   │  │    app launch by
                     │  │  member windows: [NotchPanel]      │  │    NotchSpaceManager
                     │  └───────────────────────────────────┘  │
                     └─────────────────────────────────────────┘
                                     ▲
                                     │ CGSAddWindowsToSpaces / CGSRemoveWindowsFromSpaces
                                     │ (membership sync — happens ONCE per panel lifetime,
                                     │  NOT per Space-switch, unlike .canJoinAllSpaces)
                     ┌───────────────┴─────────────────────────┐
                     │  Islet (app process)                     │
                     │  ┌─────────────────┐   ┌───────────────┐│
                     │  │ NotchSpaceManager│──▶│  CGSSpace     ││  new files, mirror
                     │  │ (singleton)      │   │  (silgen_name  ││  FullscreenSpaceProbe's
                     │  └─────────────────┘   │   bindings)    ││  binding pattern
                     │           │              └───────────────┘│
                     │           ▼                                │
                     │  ┌─────────────────────────────────────┐  │
                     │  │ NotchWindowController.updateVisibility│ │  ← SOLE arbiter (Pattern 7)
                     │  │  - selectTargetScreen (Phase 1)        │  │     unchanged; Space
                     │  │  - isBuiltinDisplayInFullscreenSpace   │  │     membership set once at
                     │  │    (Phase 2, still used as the         │  │     panel creation, not on
                     │  │    show/hide gate — UNCHANGED)          │  │     every visibility re-eval
                     │  └─────────────────────────────────────┘  │
                     │           │                                │
                     │           ▼                                │
                     │  ┌─────────────────┐                       │
                     │  │  NotchPanel      │  collectionBehavior   │
                     │  │  (NSPanel)       │  UNCHANGED (layer,    │
                     │  │                  │  not replace — see    │
                     │  │                  │  Summary finding #2)  │
                     │  └─────────────────┘                       │
                     └───────────────────────────────────────────┘
```

Key structural difference from today's mechanism: `.canJoinAllSpaces` requires WindowServer to **dynamically re-parent** the panel onto whichever Space just became active, *at the moment of the Space transition* — this re-parenting is the compositor operation racing our reactive `orderOut` call and producing the flash. A dedicated max-level Space is instead **always composited**, regardless of which real user Space is currently active — its membership is set once and never needs to change on a Space switch, removing the per-transition race entirely (this is also literally boring.notch's own commit message for introducing this: "Put the notch window in a space that sits at the highest level, allowing it to ignore most of macos window management and overlay on top of everything" — `970f875`, 2024-10-28).

### Recommended Project Structure
```
Islet/Notch/
├── NotchPanel.swift              # UNCHANGED collectionBehavior (per the "layer" finding)
├── NotchWindowController.swift   # updateVisibility() unchanged; new one-time Space-join call
├── FullscreenSpaceProbe.swift    # UNCHANGED — still the fullscreen show/hide gate signal
└── CGSSpace.swift                # NEW — mirrors FullscreenSpaceProbe's @_silgen_name pattern;
                                   #   wraps CGSSpaceCreate/SetAbsoluteLevel/Add/RemoveWindowsToSpaces
                                   #   (+ Destroy/Hide/Show — see Open Questions on the D-02 gap)
```
A separate `NotchSpaceManager` singleton (mirroring both reference implementations) is optional — for this app's single-panel case, the `CGSSpace` wrapper could be owned directly by `NotchWindowController` instead of a second singleton type. Left to planner/Claude's Discretion per 09-CONTEXT.md.

### Pattern 1: `CGSSpace` wrapper (verified against two shipping implementations)
**What:** A small class wrapping space creation, level-setting, and window membership, with `didSet` on a `windows: Set<NSWindow>` property driving `CGSAddWindowsToSpaces`/`CGSRemoveWindowsFromSpaces` diffs.
**When to use:** Exactly this app's case — a single persistent overlay panel that must render above every real Space including fullscreen ones.
**Example (verbatim from `Ebullioscopic/Atoll/DynamicIsland/private/CGSSpace.swift`, identical in `TheBoredTeam/boring.notch/boringNotch/private/CGSSpace.swift` except the latter has no `createdByInit` guard):**
```swift
// Source: https://github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/private/CGSSpace.swift
import AppKit

public final class CGSSpace {
    private let identifier: CGSSpaceID
    private let createdByInit: Bool

    public var windows: Set<NSWindow> = [] {
        didSet {
            let remove = oldValue.subtracting(self.windows)
            let add = self.windows.subtracting(oldValue)
            CGSRemoveWindowsFromSpaces(_CGSDefaultConnection(),
                                       remove.map { $0.windowNumber } as NSArray,
                                       [self.identifier])
            CGSAddWindowsToSpaces(_CGSDefaultConnection(),
                                  add.map { $0.windowNumber } as NSArray,
                                  [self.identifier])
        }
    }

    /// Initialized `CGSSpace`s *MUST* be de-initialized upon app exit!
    public init(level: Int = 0) {
        let flag = 0x1 // this value MUST be 1, otherwise Finder decides to draw desktop icons
        self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), self.identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
        self.createdByInit = true
    }

    deinit {
        CGSHideSpaces(_CGSDefaultConnection(), [self.identifier])
        if createdByInit { CGSSpaceDestroy(_CGSDefaultConnection(), self.identifier) }
    }
}

// CGS private symbol bindings — @_silgen_name, no dlopen (mirrors FullscreenSpaceProbe.swift)
fileprivate typealias CGSConnectionID = UInt      // NOTE: UInt, not Int32 — see Common Pitfalls
fileprivate typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
fileprivate func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
fileprivate func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
fileprivate func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
fileprivate func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSRemoveWindowsFromSpaces")
fileprivate func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
fileprivate func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
fileprivate func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
```
`[CITED: github.com/Ebullioscopic/Atoll, github.com/TheBoredTeam/boring.notch]` — fetched directly, byte-identical logic in both (Atoll adds a `createdByInit` guard so an `init(id:)` variant, unused by the notch case, doesn't destroy a space it didn't create).

### Pattern 2: Singleton max-level Space, created once at launch
**What:** `NotchSpaceManager` is a process-lifetime singleton owning exactly one `CGSSpace(level: 2147483647)` (i.e. `Int32.max`, confirming CONTEXT.md's assumption).
**Example (verbatim, both repos identical):**
```swift
// Source: github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/managers/NotchSpaceManager.swift
class NotchSpaceManager {
    static let shared = NotchSpaceManager()
    let notchSpace: CGSSpace
    private init() {
        notchSpace = CGSSpace(level: 2147483647) // Max level
    }
}
```
Usage site (`DynamicIslandApp.swift`, both when creating and tearing down the panel):
```swift
window.orderFrontRegardless()
NotchSpaceManager.shared.notchSpace.windows.insert(window)
// ... on teardown:
window.close()
NotchSpaceManager.shared.notchSpace.windows.remove(window)
```
`[VERIFIED: direct GitHub fetch of both shipping repos]`

### Pattern 3: The panel's own `collectionBehavior` is left untouched (contradicts CONTEXT.md's "replaces" wording)
**What:** Both `Atoll`'s `DynamicIslandWindow` and `boring.notch`'s `BoringNotchWindow` set `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]` in `init`, identical in shape to this project's `NotchPanel.swift:32`, and never remove `.canJoinAllSpaces` anywhere in either codebase.
**When to use:** This is the ONLY combination with real shipping precedent. Removing `.canJoinAllSpaces` while relying solely on CGSSpace membership is an untested combination — no reference project does this.
`[VERIFIED: github.com/Ebullioscopic/Atoll/.../DynamicIslandWindow.swift, github.com/TheBoredTeam/boring.notch/.../BoringNotchWindow.swift]`

### Anti-Patterns to Avoid
- **Removing `.canJoinAllSpaces` as the FIRST attempt:** No prior art validates this. If the planner wants the risk-minimal path, ship the CGSSpace addition FIRST with `collectionBehavior` unchanged (matches reference precedent, and the existing `NotchPanelTests.testPanelJoinsAllSpacesAboveFullscreenAux` unit test stays green with zero changes) — evaluate flash elimination in that configuration before ever touching `collectionBehavior`. Only remove `.canJoinAllSpaces` as a distinct, separately-tested follow-up experiment if the layered version alone doesn't close the gap, since removing it changes a second variable at once and would confound which change actually fixed (or broke) something.
- **Re-syncing Space membership on every `updateVisibility()` call:** Both reference implementations insert/remove the window from the dedicated Space exactly ONCE per panel lifetime (at creation/teardown), not on every show/hide cycle. `positionAndShow()`/`updateVisibility()`'s existing `orderFrontRegardless()`/`orderOut(nil)` calls are unrelated to Space membership and should stay exactly as they are; only the one-time creation of the panel needs the additional `.windows.insert(panel)` call.
- **Treating the CGSSpaceCreate "options" dict as meaningful:** Neither reference implementation passes a "type" (`CGSSpaceType`) via the options dictionary — both pass `nil` for the third parameter and use a plain positional `Int` flag (`0x1`) for the second parameter instead. Do not try to set `kCGSSpaceFullscreen`/`kCGSSpaceUser` types on the CREATED space — that's not how any known implementation does it, and the absolute level alone is what does the work.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Space create/level/membership private symbol bindings | A from-scratch reverse-engineering of the CGS Space API surface | The exact 7-symbol set + magic-flag pattern verified in `CGSSpace.swift` above | The `flag = 0x1` "MUST be 1, otherwise Finder decides to draw desktop icons" comment documents a real, previously-hit system-wide regression (Finder desktop icon rendering) that would be very expensive to rediscover independently. |

**Key insight:** This specific private API surface has a documented history of a subtle, easy-to-miss parameter value (`flag=1`, not `0`/`nil`) that broke system-level desktop-icon rendering when gotten wrong. Copy the reference bindings verbatim rather than re-deriving them from the (differently-shaped, partially-inaccurate) "documented" `NUIKit/CGSInternal/CGSSpace.h` header, which shows a 3-arg signature (`cid, void *null, CFDictionaryRef options`) that superficially matches but is used completely differently in practice (the "null" middle arg is actually a required magic flag, not null).

## Common Pitfalls

### Pitfall 1: The D-02 ceiling is already broken by the proven-working reference
**What goes wrong:** Implementing "just the 4 named functions" (`CGSSpaceCreate`, `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`) without `CGSShowSpaces` produces a space that may never actually get composited — both reference implementations call `CGSShowSpaces` immediately after `CGSSpaceCreate`, and no known implementation skips it.
**Why it happens:** CONTEXT.md's 4-function list was written before the actual source was read; it named the functions the user could see/infer from the technique description, not the full symbol list the real implementation needs.
**How to avoid:** Surface this explicitly to the user/planner (see Open Questions) before writing code — do not silently expand the private-API surface past what D-01/D-02 pre-approved. `CGSShowSpaces` appears functionally required (not skippable); `CGSHideSpaces`/`CGSSpaceDestroy` are the *teardown* half and are more plausibly deferrable to "rely on process-exit connection cleanup" (UNVERIFIED — flagged as Assumption A2), but skipping them deviates from every known shipping implementation and risks an accumulating Space resource leak across app relaunches during development.
**Warning signs:** A space created without ever being shown; on-device testing shows the panel visually behaving exactly as it does today (no change) — that would indicate the created Space isn't actually compositing.

### Pitfall 2: `CGSConnectionID` type mismatch risk between the existing codebase binding and the reference's binding
**What goes wrong:** `FullscreenSpaceProbe.swift` already binds `CGSMainConnectionID() -> Int32` (confirmed working on-device). Both reference `CGSSpace.swift` implementations instead bind a *different* symbol, `_CGSDefaultConnection() -> UInt` (64-bit on Apple Silicon). These are documented as functionally equivalent connection-ID accessors (`[CITED via WebSearch cross-reference, MEDIUM confidence]`), but they are bound with **different return types** (`Int32` vs 64-bit `UInt`). Mixing them (e.g., reusing the existing `Int32`-typed `CGSMainConnectionID` binding as an input to the new Space functions, which expect the wider `CGSConnectionID` type from the reference) risks a silent ABI/truncation bug.
**Why it happens:** Two different projects independently reverse-engineered the same underlying C `int`-sized connection handle and typed their Swift bindings differently.
**How to avoid:** Do NOT try to unify/share a single connection-ID binding across `FullscreenSpaceProbe.swift` and the new `CGSSpace.swift`. Mirror the reference's own type choices exactly (`_CGSDefaultConnection() -> UInt`, i.e. keep `CGSSpace.swift` self-contained with its own `fileprivate` connection binding, as both reference implementations do) rather than passing `FullscreenSpaceProbe`'s `Int32` connection ID into the new functions.
**Warning signs:** Crashes or garbage `CGSSpaceID` values immediately on `CGSSpaceCreate` — a classic symptom of an ABI-mismatched integer-width binding.

### Pitfall 3: Lock-screen/sleep-wake transitions previously caused a "critical bug" with this exact mechanism upstream
**What goes wrong:** boring.notch's original PR introducing this mechanism (`#171`, "Fix notch window management") explicitly attempted a second feature — keeping the notch visible on the lock screen — and had to **revert it** ("Removed in order to fix a critical bug, this will be added in a future update"). The PR does not document what the critical bug was, but its presence is a direct, on-record regression precedent tied to this exact Space/level mechanism.
**Why it happens:** Unknown from available sources (no PR review comments were found) — but the timing (immediately after adding the max-level Space) and the phrasing ("critical bug") suggest an interaction between the always-on-top Space and screen-lock/sleep transitions.
**How to avoid:** Add lock-screen sleep/wake as an explicit on-device regression scenario in the D-03 core-behavior suite, even though it's not named in D-07's trigger matrix — this is exactly the kind of "Claude's Discretion" item CONTEXT.md leaves open ("whether an external-display trigger scenario is worth adding... left to the planner's judgment"); this finding argues lock/sleep is at least as important as an external-display check.
**Warning signs:** Panel becomes unresponsive, duplicated, or fails to reappear correctly after a lock/unlock or sleep/wake cycle.

### Pitfall 4: The "type" field read by `FullscreenSpaceProbe.swift` and the "type" concept in `CGSSpaceCreate`'s options are NOT the same thing
**What goes wrong:** It's tempting to assume the `kCGSSpaceFullscreen = 4` constant already confirmed on-device in `FullscreenSpaceProbe.swift` (the *runtime-observed* `"Current Space"."type"` field from `CGSCopyManagedDisplaySpaces`) is the same enum as whatever "type" a *newly created* Space could be given via `CGSSpaceCreate`'s options dictionary. Two independently reverse-engineered "documented" headers disagree with each other on `CGSSpaceType`'s raw values (`user=0/fullscreen=1/system=2` in one header vs. `user=0/system=2/fullscreen=4` in another), and neither matches how the actual create call is used in practice.
**Why it happens:** Multiple generations of reverse-engineering over ~15 years (the `puffnfresh` gists date to 2012; `NUIKit/CGSInternal` is from ~2013-2017) have produced inconsistent documentation of an API surface Apple has never published.
**How to avoid:** Don't try to set a "type" on the created Space at all — mirror the reference exactly (`options: nil`, magic `flag=1`). The absolute level, not the type, is what does the compositing work for this use case.
**Warning signs:** N/A for this app if the reference pattern is followed verbatim — this is a "don't go looking for a knob that isn't needed" pitfall.

## Code Examples

Already provided in full under Architecture Patterns 1 and 2 (the complete `CGSSpace.swift` and `NotchSpaceManager.swift` verbatim from two independent shipping projects).

### Candidate B minimal addendum (no new research beyond `08-ESCALATION.md`)
No new findings beyond what's already documented in `08-ESCALATION.md`'s "Untried Fallback" section were surfaced this session — the `SLSManagedDisplayIsAnimating` + `CVDisplayLink` poll + `CGSCopyManagedDisplaySpaces`-based disambiguator design there remains the full extent of Candidate B's design. One addition: `project.yml`'s existing `settings.base` block (shown in Environment Availability below) has no `FRAMEWORK_SEARCH_PATHS`/`OTHER_LDFLAGS` overrides today, so the linker changes `08-ESCALATION.md` specifies would be a clean addition, not a merge into existing conflicting settings.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `.canJoinAllSpaces` collection behavior alone (this codebase's current, Phase-1/2-era mechanism) | `.canJoinAllSpaces` **+** a dedicated max-level CGS Space (Candidate C) | boring.notch introduced this 2024-10-28 (`970f875`); stable/unmaintained-but-unbroken through 2025-06-14 (last touch was a license-header-only change) | Decouples the window's always-visible property from the compositor's per-Space-switch re-parenting, which is the operation racing the current reactive hide call. |
| `@_silgen_name` CGS bindings for Space overlay control | boring.notch has since (2025-10-20) ALSO added a third, separate `BoringNotchSkyLightWindow` using the external `Lakr233/SkyLightWindow` SPM package + `dlopen`/`unsafeBitCast` instead of the CGSSpace symbols | 2025-10-20, commit introducing `BoringNotchSkyLightWindow.swift` | Informational only — not in this phase's scope (see Alternatives Considered). Signals the upstream project itself is still actively iterating on this exact problem space, suggesting neither Candidate C nor a SkyLightWindow-style approach is considered fully "solved" upstream either. |

**Deprecated/outdated:**
- The `NUIKit/CGSInternal` documented `CGSSpace.h` header's 3-argument `CGSSpaceCreate(cid, void *null, CFDictionaryRef options)` signature is technically accurate in argument COUNT but misleading in argument MEANING — no living implementation passes a real options dictionary; the middle "null" arg is actually a required non-null magic flag.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_CGSDefaultConnection` and `CGSMainConnectionID` return the same underlying connection ID and are safely interchangeable in concept (though NOT in Swift binding type) | Pitfall 2 | If they diverge (e.g. per-thread vs per-process connection semantics), a subtle Space-membership bug could occur that's hard to reproduce; mitigated by NOT actually sharing the binding (recommendation is to keep them separate anyway). |
| A2 | `CGSHideSpaces`/`CGSSpaceDestroy` are safely skippable for a single app-lifetime-scoped Space, relying on connection-scoped OS cleanup at process exit | Pitfall 1 | If wrong, skipping teardown could leak an orphaned system-level Space resource across repeated app launches during development (accumulating over many debug-build relaunches) — a real but likely-low-severity risk, not user-visible in a single running session. |
| A3 | No additional entitlement/codesigning requirement exists for `CGSSpaceCreate`/`CGSAddWindowsToSpaces`/etc. beyond what `CGSCopyManagedDisplaySpaces` already requires (i.e., none, since the app already calls a private CGS symbol successfully unsandboxed) | Environment Availability / D-01 precedent | If wrong, Candidate C could crash or silently no-op the first time it's run on-device, discovered only during the D-05 on-device trigger matrix, not before. |
| A4 | boring.notch's undocumented lock-screen "critical bug" (Pitfall 3) was actually caused by the CGSSpace/max-level mechanism itself, not an unrelated concurrent change in the same PR | Pitfall 3 | If the bug was unrelated, the recommendation to add lock/sleep as an extra on-device regression scenario is lower-priority than stated (though still cheap insurance). |

## Open Questions

1. **D-02's private-API ceiling is exceeded by the only known working reference — does the user want to re-adjudicate before Candidate C code is written?**
   - What we know: The minimum viable `CGSSpace` wrapper needs 7 private symbols (`_CGSDefaultConnection`, `CGSSpaceCreate`, `CGSSpaceDestroy`, `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`, `CGSHideSpaces`, `CGSShowSpaces`), not the 4 named in D-02 (`CGSSpaceCreate`, `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`).
   - What's unclear: Whether the user, seeing this concrete list (verified against two shipping open-source apps, not speculative), would still consider this "the same risk tier" as D-01 intends, or whether this specific expansion (3 extra Space lifecycle functions + a second connection-lookup symbol) crosses the line D-02 was drawing.
   - Recommendation: The planner should treat this as a required checkpoint before Candidate C implementation begins — present this exact 7-symbol list to the user for an explicit go/no-go, rather than silently proceeding or silently falling back to Candidate B. This is squarely what D-02 anticipated ("that is a stop signal — fall back to Candidate B or escalate") and should not be decided unilaterally by the plan.

2. **"Replace" vs "layer" — CONTEXT.md's premise vs. the only tested pattern.**
   - What we know: No reference implementation removes `.canJoinAllSpaces` while using CGSSpace membership; both keep it. CONTEXT.md's phase-boundary text says Candidate C "replaces" it.
   - What's unclear: Whether the user's original research (which is where the "replaces" framing came from) found a different source describing a true replacement, or whether "replaces" was really shorthand for "solves the same problem `.canJoinAllSpaces` was trying to solve" without literally meaning "delete the flag."
   - Recommendation: Plan the layered/additive version FIRST (zero risk to the existing `NotchPanelTests.testPanelJoinsAllSpacesAboveFullscreenAux` unit test, matches all known precedent). Only attempt removing `.canJoinAllSpaces` as a distinct, separately on-device-tested follow-up if the layered version alone doesn't close the flash — never both changes at once, to keep the regression suite (D-03/D-04) able to attribute cause correctly.

3. **The `Lakr233/SkyLightWindow`-style third approach (boring.notch's newer `BoringNotchSkyLightWindow`) — out of scope now, but worth knowing about for D-05's "final round."**
   - What we know: It exists, is actively maintained (Oct 2025), and represents the upstream project's own move beyond the plain CGSSpace approach.
   - What's unclear: Whether it actually fixes anything the CGSSpace approach doesn't, or is motivated by something else entirely (e.g. screen-recording visibility control, given `BoringNotchSkyLightWindow`'s own `Defaults[.hideFromScreenRecording]`/`sharingType` logic).
   - Recommendation: Do not investigate this now — D-05 caps this phase to Candidate C then B, full stop. Only worth surfacing to the user if D-05's "final investigation round" outcome is being decided (i.e., if both C and B fail) as background context for that decision, not as a third candidate to attempt within this phase.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Private `CGS*` symbols (CoreGraphics re-exports) | Candidate C | Assumed ✓ (same tier as already-shipping `CGSCopyManagedDisplaySpaces`/`CGSMainConnectionID`) | N/A — OS-private, no version | None needed; not yet directly on-device tested for THESE specific symbols (only inferred from `FullscreenSpaceProbe.swift` precedent) |
| `SkyLight.framework` link path | Candidate B | Not yet added to `project.yml` | N/A | Requires the `FRAMEWORK_SEARCH_PATHS`/`OTHER_LDFLAGS` addition documented in `08-ESCALATION.md`; `project.yml`'s current `settings.base` has no conflicting entries, so this is a clean addition |
| Xcode 16+ / `xcodegen` | Both | ✓ (already in active use for this project) | — | — |
| On-device notch Mac running Tahoe (macOS 26) | D-05/D-07 trigger matrix, both candidates | ✓ (build machine confirmed Tahoe per project memory) | Tahoe / Xcode 26.6 / Swift 6.3.3 | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** `SkyLight.framework` linker setting (Candidate B only) — straightforward addition per `08-ESCALATION.md`, only needed if Candidate C fails.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (via `xcodebuild test -scheme Islet`) |
| Config file | `project.yml` (XcodeGen) — `IsletTests` bundle, hosted in `Islet.app` for `@testable import` |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FS-01 (flash elimination) | Zero visible flash on fullscreen-enter across trigger matrix | manual-only | N/A — a one-frame compositor-timing artifact cannot be asserted from XCTest; this has always been an on-device visual verification across all 3 phases that investigated it (2, 6, 8) | N/A — no automatable signal exists; documented, not a gap |
| FS-01 (regression: collectionBehavior invariants, D-03) | `.canJoinAllSpaces`/`.fullScreenAuxiliary` presence (if the layered approach is used, this test needs NO change) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests/testPanelJoinsAllSpacesAboveFullscreenAux` | ✅ exists today |
| FS-01 (regression: focus-safety, D-04) | `canBecomeKey`/`canBecomeMain` both false | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests/testPanelNeverBecomesKeyOrMain` | ✅ exists today |
| FS-01 (regression: fullscreen hide/restore, D-03) | `shouldShow` predicate unaffected by the Space change | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ✅ exists today |
| FS-01 (regression: click-through, D-03) | `syncClickThrough`/`ignoresMouseEvents` toggling unaffected | manual-only | On-device only — no existing automated test targets `syncClickThrough` directly (it's exercised indirectly via `NotchWindowController`, which isn't unit-tested for this behavior today) | ❌ — pre-existing gap, not introduced by this phase; noted for awareness, not required to close for FS-01 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests -only-testing:IsletTests/FullscreenDetectorTests`
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite, 141 tests as of Phase 8)
- **Phase gate:** Full suite green + the D-03 on-device UAT matrix (hover/click, click-through, all-Spaces visibility, positioning through clamshell/display changes, fullscreen hide/restore, D-07's ordinary Space-switch check) before `/gsd:verify-work`.

### Wave 0 Gaps
None required to START — all the unit tests this phase's regression suite needs already exist (`NotchPanelTests`, `VisibilityDecisionTests`, `FullscreenDetectorTests`). If the "replace, not layer" variant is ever attempted (Open Question 2), `testPanelJoinsAllSpacesAboveFullscreenAux` would need to be rewritten at that time — not a Wave 0 gap for the recommended (layered) path.

## Security Domain

This phase touches only local, single-user, non-networked window/Space management on macOS — not a web application. Most ASVS web categories do not apply; the relevant local-system equivalents are assessed instead.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Single-user local app, no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — no multi-user/privilege boundary crossed by these calls |
| V5 Input Validation | Partial | The only "input" is this app's own hardcoded window/level values (`Int32.max`, `flag=1`) — no untrusted external input reaches these calls |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Orphaned/leaked system-level CGS Space resource across repeated app relaunches (Pitfall 1 / A2) | Denial of Service (local resource exhaustion, low severity) | Call `CGSHideSpaces`/`CGSSpaceDestroy` on clean app termination (mirror the reference implementations' `deinit`), even though this is a `class`-level singleton whose `deinit` may not reliably run on abrupt termination (SIGKILL/force-quit) — accept residual risk, same class of risk the app already carries with the persistent MediaRemote-adapter perl child process (T-04-12 in existing project threat notes). |
| ABI type mismatch on the private connection-ID binding (Pitfall 2) causing undefined behavior/crash | Tampering (of the app's own memory-safety, not a security boundary) | Mirror the reference's exact Swift types (`UInt` for `CGSConnectionID`) rather than reusing the existing `Int32` binding; do not hand-roll a "unified" binding across the two files. |

## Sources

### Primary (HIGH confidence)
- `github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/private/CGSSpace.swift` — full source fetched directly
- `github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/managers/NotchSpaceManager.swift` — full source fetched directly
- `github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/components/Notch/DynamicIslandWindow.swift` — full source fetched directly (confirms collectionBehavior unchanged)
- `github.com/Ebullioscopic/Atoll/blob/main/DynamicIsland/DynamicIslandApp.swift` — full source fetched directly (confirms `.windows.insert`/`.remove` usage sites)
- `github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/private/CGSSpace.swift` — full source fetched directly (upstream original)
- `github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/NotchSpaceManager.swift` — full source fetched directly
- `github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchWindow.swift` — full source fetched directly
- `github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift` — full source fetched directly (informational, out of scope)
- `github.com/TheBoredTeam/boring.notch/pull/171` and referenced `#82`/`#92` — PR description + linked issues, fetched via `gh api`
- `github.com/TheBoredTeam/boring.notch` commit history for `NotchSpaceManager.swift` (`gh api repos/.../commits?path=...`) — confirms introduction date (2024-10-28, `970f875`) and last-touched date (2025-06-14, license-only)
- This repository's own `Islet/Notch/NotchPanel.swift`, `NotchWindowController.swift`, `FullscreenSpaceProbe.swift`, `IsletTests/NotchPanelTests.swift` — read directly

### Secondary (MEDIUM confidence)
- `github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h` — documented (but demonstrably imprecise on `CGSSpaceCreate`'s actual argument semantics) reverse-engineered header
- `github.com/NUIKit/CGSInternal/issues/3` — "missing symbols" list confirming `CGSSpaceSetAbsoluteLevel`/`CGSSpaceGetAbsoluteLevel` are known real symbols, and that CGS symbols were superseded by SLS equivalents as of macOS 10.13
- WebSearch cross-reference on `_CGSDefaultConnection` vs `CGSMainConnectionID` equivalence — no single authoritative source, but consistent across multiple independent community explanations

### Tertiary (LOW confidence)
- `gist.github.com/puffnfresh/4053980` and `/4054059` — 2012-era reverse-engineered Spaces API headers/demos; useful for corroborating symbol existence but NOT used as the basis for any code recommendation (superseded by the directly-fetched, currently-shipping reference implementations above)

## Metadata

**Confidence breakdown:**
- Standard stack (Candidate C mechanism): HIGH — verified against two independent, currently-shipping open-source codebases fetched directly, not summarized secondhand
- Architecture (layer vs. replace finding): HIGH — directly observed in both reference implementations' actual window-init code
- Private-API ceiling gap (D-02 stop signal): HIGH — directly counted from the fetched source; this is a factual, not speculative, finding
- Pitfalls (lock-screen regression precedent): MEDIUM — the revert is documented fact, but its root cause within that PR is not (no review comments found)
- Candidate B: unchanged from `08-ESCALATION.md` — no new research performed this session beyond confirming `project.yml` has no conflicting linker settings today

**Research date:** 2026-07-04
**Valid until:** 30 days — private-API risk means a macOS point release could change symbol behavior at any time; re-verify on-device before relying on any finding here if significant time has passed or the OS has been updated.
