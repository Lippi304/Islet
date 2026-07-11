# Phase 23: Shell Parity Rewrite - Research

**Researched:** 2026-07-11
**Domain:** AppKit window-shell architecture (NSPanel/NSWindowController), private CGS Spaces API, focus-safe click-through hit-testing
**Confidence:** HIGH (this phase rewrites existing, already-verified-on-device code with no new library/API surface)

## Summary

This phase is a **behavior-preserving rewrite**, not new-feature work. The two files in scope —
`Islet/Notch/NotchPanel.swift` (62 lines) and `Islet/Notch/NotchWindowController.swift` (1,378
lines) — already implement every behavior Success Criteria #1-3 require, and every pattern is
already documented in-file with decision-ID comments (D-01, D-07, CR-01, FS-01, etc.). The
research task here is therefore not "what library should we use" but "what exactly must be
byte-for-byte preserved, what is the one piece that must be deleted (D-01, the Phase-22 drag
scaffold), and what landmines does this codebase's own history show are easy to reintroduce
during a rewrite."

The codebase's own history answers most of that last question directly: **Phase 20's CR-01
regression** (OR-ing `pointerInZone` into the expanded-state click-through check swallowed empty-
shelf clicks) and **Phase 22's unresolved drag-delivery failure** (`draggingEntered` stopped
firing on-device for reasons that were never conclusively identified, even after matching the
confirmed-working spike's code exactly) are both concrete, previously-lived case studies of this
exact file being rewritten/extended and silently breaking. This research reconstructs both
incidents in detail below so the planner can build explicit regression gates against them.

A second research thread — external validation of why Phase 22's raw `NSDraggingDestination`
approach was fragile — confirms via TheBoringNotch's own shipping architecture that a **global
Accessibility-API drag monitor**, not `NSDraggingDestination` registration on the click-through
panel itself, is the standard pattern reference apps use for notch-drag-detection. This doesn't
change anything Phase 23 builds (ARCH-01/D-01 forbid adding any drag code back), but it validates
STATE.md's plan for Phase 24 (`DragApproachDetector`, a global-monitor pattern) as the
architecturally sound direction, and means Phase 23 does **not** need to "fix" drag delivery —
it only needs to leave a clean panel with zero Phase-22 residue.

**Primary recommendation:** Rewrite `NotchWindowController.swift` **in place**, in small,
independently buildable/committable chunks that mirror the file's own existing `// MARK:`
section boundaries (one section = one commit), rather than a parallel-build-then-swap. The file
is a single long-lived AppKit singleton with multiple OS-level registrations (global `.mouseMoved`
monitor, `NSWorkspace` observers, a `CGSSpace`, IOKit/IOBluetooth monitors) — running two live
instances side-by-side during a swap is itself a correctness risk (double-registered monitors,
double CGSSpace membership) that in-place refactor avoids entirely. This also matches the
project's own established convention (every phase to date, including the riskiest AppKit surgery
— Phase 8/9's fullscreen-flash escalation and Phase 20's CR-01 click-through fix — was done
in-place).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Notch positioning / frame math | Browser-equivalent: local pure Swift (`NotchGeometry.swift`) | — | Already extracted as fixture-tested pure functions; ARCH-01 does not touch this file |
| Overlay window construction (`NotchPanel`) | OS/AppKit window-shell | — | The one-and-only `NSWindow` subclass in the app; must stay a thin, zero-business-logic shell |
| Hover/click/grace state machine | AppKit glue (`NotchWindowController`) | Pure seam (`NotchInteractionState.nextState`) | Controller owns timers/monitors (impure); the transition table itself is already a pure, unit-tested function — unaffected by this rewrite |
| Fullscreen detection | OS/private-API glue (`FullscreenSpaceProbe.swift`) | AppKit glue (`updateVisibility()`) | CGS Spaces read is a synchronous system call; the controller is just the caller. `FullscreenSpaceProbe.swift`/`FullscreenDetector.swift` are NOT in the phase's file scope and must show zero diff (same discipline as `IslandResolver`/`DeviceCoordinator`) |
| Click-through hit-testing | AppKit glue (`syncClickThrough()`) | — | The single arbiter; must never gain a second writer of `ignoresMouseEvents` |
| Multi-Space/fullscreen-aux visibility | OS-level (`NSPanel.collectionBehavior` + `CGSSpace`) | AppKit glue (`positionAndShow()`) | Two additive mechanisms (documented in `CGSSpace.swift`) that together eliminated the Phase 2/6/8 fullscreen-enter flash — removing either one reopens that regression |
| Device/Now-Playing/Charging/Shelf business logic | Out of scope | — | `DeviceCoordinator`, `IslandResolver`, `Islet/Shelf/` are locked zero-diff (Success Criterion #5); the rewritten controller only re-wires references to them, never their internals |

## Project Constraints (from CLAUDE.md)

- Swift 5 **language mode** (not Swift 6 strict concurrency) — `project.yml` confirms `SWIFT_VERSION: "5.0"`, deployment target `macOS 14.0`. The rewrite must not silently flip either.
- `LSUIElement`/background-agent posture, un-sandboxed, direct+notarized distribution — unchanged by this phase; the un-sandboxed posture is exactly what makes the un-entitled CGS private-API calls and the IOBluetooth/IOKit direct access work without extra prompts.
- "First-time programmer" ramp: the existing file's dense decision-ID comment convention (`// D-07`, `// CR-01`, `// Pattern 6`) is itself a project convention worth preserving verbatim during the rewrite — it is how a first-time programmer (and future Claude sessions) re-derive *why* each line exists.
- GSD workflow enforcement (project + global CLAUDE.md): this phase must go through `/gsd:plan-phase 23` → `/gsd:execute-phase` → `/gsd:verify-work`; no direct edits outside that flow.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 (LOCKED):** Go fully clean — delete `registerForDraggedTypes` and all 4
`NSDraggingDestination` stub methods from `NotchPanel.swift` entirely, matching Success Criteria
#4 literally. Do NOT leave a named extension seam/hook for Phase 24's `DragApproachDetector`.
Phase 24 builds its detection mechanism from scratch against the reproven shell — no scaffolding
to maintain or reconcile in the meantime.

### Claude's Discretion

- **Rewrite strategy** — in-place refactor (matches every prior phase's convention) vs.
  parallel-build-then-swap. Researcher/planner picks based on the actual diff shape. **Research
  recommendation: in-place**, see Summary/Pattern 7 below for the reasoning (live OS-registration
  duplication risk during a parallel-build window).
- **Refactor scope boundary** — whether the inline license/trial-gating logic
  (`pendingLockoutHide`, D-11/D-12/D-13 in `updateVisibility()`/`handleClick()`) gets extracted
  into its own coordinator (mirroring Phase 16's `DeviceCoordinator`) or moves verbatim. Judge
  based on how cleanly it separates during the actual rewrite; do not force it.
- **Verification rigor** — one consolidated on-device UAT pass merging Phase 2's 8 scenarios +
  Phase 9's 3-trigger fullscreen matrix + the CR-01 hover→expand→move-down trace, vs. a lighter
  spot-check. Research reconstructed the full content of both historical checklists below (their
  source files were cleared from the working tree at milestone archival, but are recoverable from
  git history) — see **Validation Architecture** for the assembled consolidated checklist.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ARCH-01 | The notch window shell (`NotchPanel`/`NotchWindowController`) is rebuilt with behavior identical to today — position on the built-in notch, hover/click/grace-collapse state machine, true-fullscreen hiding, click-through hit-testing, and multi-Space visibility all verified regression-free on-device — with the residual `NSDraggingDestination` scaffold from Phase 22 removed. Prerequisite for SHELF-01/02. | Full current-implementation extraction below (Architecture Patterns, Code Examples), the CR-01/fullscreen-flash/drag-delivery incident reconstructions (Common Pitfalls), and the consolidated on-device UAT checklist (Validation Architecture) give the planner everything needed to scope tasks that touch every ARCH-01 clause without regressing any of them. |
</phase_requirements>

## Standard Stack

No new libraries, packages, or frameworks are introduced by this phase — it is a rewrite of
existing first-party AppKit/SwiftUI/CoreGraphics code already linked into the `Islet` target.

### Core (unchanged, already linked)
| Framework | Version | Purpose | Provenance |
|-----------|---------|---------|------------|
| AppKit | macOS 14.0+ SDK (Xcode 16+; build machine is Tahoe/Xcode 26.6 per project memory) | `NSPanel`, `NSWorkspace` observers, `NSEvent` global monitor, `NSHostingView` | `[VERIFIED: project.yml deploymentTarget/SWIFT_VERSION]` |
| SwiftUI | ships with macOS SDK | Hosted content view (`NotchPillView` etc.) — untouched by this phase | `[VERIFIED: existing codebase]` |
| CoreGraphics / private CGS (SkyLight) symbols | undocumented, silgen-name-bound | `CGSSpace` (Phase 9 fullscreen-flash fix), `CGSCopyManagedDisplaySpaces` (fullscreen detection) | `[VERIFIED: existing codebase, on-device confirmed Phase 2/6/9]` — private API, no version guarantee across macOS releases; already flagged in-file as a "re-verify after each major macOS update" risk (project CLAUDE.md Sources section) |

### Package Legitimacy Audit

**Not applicable — this phase installs zero new external packages.** No `slopcheck`/registry
verification is needed; every symbol used (AppKit, private CGS silgen bindings) is already
present and audited in the existing codebase (`CGSSpace.swift`'s own header names the "7-symbol
ceiling," verified in Phase 9 against two independent shipping reference implementations).

## Architecture Patterns

### System Architecture Diagram

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ OS-level event sources                                               │
 │  • NSEvent.addGlobalMonitorForEvents(.mouseMoved)  (copies, no       │
 │    consumption — never activates Islet)                              │
 │  • NSWorkspace: activeSpaceDidChangeNotification,                    │
 │    didActivateApplicationNotification                                │
 │  • NSApplication.didChangeScreenParametersNotification               │
 │  • IOPS power-source callback, IOBluetooth connect/disconnect,       │
 │    MediaRemote adapter stream (untouched — DeviceCoordinator/        │
 │    NowPlaying monitors, locked zero-diff)                            │
 └───────────────┬────────────────────────────────────────────────────┘
                  ▼
        ┌───────────────────────┐
        │ NotchWindowController │   <- THE controller this phase rewrites
        │ (AppKit glue, @MainActor) │
        └──────────┬─────────────┘
                    │ hit-test / geometry (pure)
                    ▼
        ┌────────────────────────────┐        ┌───────────────────────┐
        │ NotchGeometry.swift (pure) │        │ NotchInteractionState  │
        │ notchFrame/expandedNotch-  │        │ (pure state machine,  │
        │ Frame/wingsFrame           │        │ nextState())          │
        └────────────┬───────────────┘        └───────────┬────────────┘
                      │ CGRect                              │ @Published phase
                      ▼                                     ▼
              ┌──────────────────────────────────────────────────┐
              │ positionAndShow(on:) → NotchPanel (NSPanel)       │
              │  • sets frame, orderFrontRegardless (focus-safe)  │
              │  • joins notchSpace: CGSSpace(level: Int32.max)   │
              │    (Phase 9 FS-01, additive to collectionBehavior)│
              └──────────────────┬─────────────────────────────────┘
                                 │ ignoresMouseEvents (ONE flag,
                                 │ syncClickThrough() is the ONLY writer)
                                 ▼
              ┌──────────────────────────────────────────────────┐
              │ NSHostingView(rootView: makeRootView(...))        │
              │  SwiftUI: NotchPillView + wings/expanded/shelf     │
              │  (Islet/Shelf/*, untouched — locked zero-diff)     │
              └──────────────────────────────────────────────────┘

  Fullscreen gate (parallel input, ANDed into updateVisibility()):
  FullscreenSpaceProbe.isBuiltinDisplayInFullscreenSpace() — synchronous
  CGSCopyManagedDisplaySpaces read, NOT derived from NSScreen safe-area
  (fails from a background agent watching ANOTHER app's fullscreen).
```

### Recommended Project Structure

No new files/directories are required — the phase's own D-01 lock and Success Criterion #5
confirm the rewrite fits entirely inside the two existing files:

```
Islet/Notch/
├── NotchPanel.swift              # rewritten: drop D-01 drag scaffold, keep everything else
├── NotchWindowController.swift   # rewritten: behavior-identical, in-place
├── NotchGeometry.swift           # UNTOUCHED (pure frame math, zero-diff expected)
├── NotchInteractionState.swift   # UNTOUCHED (pure state machine; .dragEntered case stays —
│                                  #   it's an inert, Phase-24-reusable seam per STATE.md, not
│                                  #   part of the D-01 scaffold-removal scope)
├── DragDropSupport.swift         # UNTOUCHED (Phase 22-02 pure seams, explicitly flagged in
│                                  #   STATE.md as "reusable by Phase 24" — NOT scaffold to delete)
├── FullscreenSpaceProbe.swift    # UNTOUCHED (CGS fullscreen-space probe)
├── FullscreenDetector.swift      # UNTOUCHED (pure shouldShow gate)
├── CGSSpace.swift                # UNTOUCHED (Phase 9 private-symbol wrapper)
└── ...                           # NotchPillView.swift etc. — SwiftUI content, untouched
```

**Scope clarification for the planner (resolves an ambiguity CONTEXT.md leaves implicit):**
Success Criterion #4 and D-01 both name `NotchPanel.swift` specifically as where the
`NSDraggingDestination` scaffold lives and must be deleted. `DragDropSupport.swift` (pure
`fileURLs(from:)`/`shouldAcceptDrop(...)`) and the `.dragEntered` case in
`NotchInteractionState.swift` are **not** "scaffold" — STATE.md's Phase 22 abort record explicitly
says these Phase 22-02 pure seams "ARE merged and reusable by Phase 24." They should be left
exactly as-is (dead/unused until Phase 24 revives them), not deleted. Only `NotchPanel.swift`'s
`registerForDraggedTypes` call and its 4 `NSDraggingDestination` stub methods are in scope for
deletion.

### Pattern 1: Non-activating, click-through overlay panel (`NotchPanel`)
**What:** A borderless `NSPanel` subclass with `[.borderless, .nonactivatingPanel]` style mask,
`canBecomeKey`/`canBecomeMain` hardcoded `false`, `.statusBar` level,
`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, and
`ignoresMouseEvents` toggled by exactly one external caller.
**When to use:** Any persistent, always-on-top, never-activating overlay that must never steal
focus from the foreground app.
**Example (current implementation — preserve verbatim except deleting the D-01 drag lines):**
```swift
// Source: Islet/Notch/NotchPanel.swift (existing codebase, on-device verified since Phase 1/2)
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel], // D-07
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false      // keep the object alive across show/hide
        ignoresMouseEvents = true         // starts click-through; NotchWindowController flips it
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // NO registerForDraggedTypes / NSDraggingDestination in Phase 23 (D-01)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```
**Anti-pattern already flagged in-file:** `.nonactivatingPanel` is set once in `init` and never
toggled later — "AppKit does not fully re-apply activation behavior post-init." Do not move this
into a runtime-mutable property during the rewrite.

### Pattern 2: Single-arbiter click-through hit-test (`syncClickThrough()`)
**What:** Exactly one function decides `panel?.ignoresMouseEvents`. Every phase/pointer mutation
site (hover-enter, hover-exit, click, drag events in a future phase) calls this function; nothing
else writes to `ignoresMouseEvents` directly.
**When to use:** Any time interactivity depends on more than one input (pointer location AND
interaction phase) — prevents exactly the class of regression CR-01 was.
**Example (current, must carry over with zero logical diff):**
```swift
// Source: Islet/Notch/NotchWindowController.swift:770-784 (existing codebase, CR-01-hardened)
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        // CR-01: must stay a PURE visibleContentZone() check. Never OR pointerInZone in here —
        // pointerInZone tracks the broader expandedZone (padded panel union used for the
        // keep-open grace decision), which also covers the reserved-but-invisible empty-shelf
        // band. ORing it defeats visibleContentZone()'s narrowing and swallows clicks meant for
        // whatever app is under the notch when the shelf is empty (the exact CR-01 regression).
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```

### Pattern 3: Additive CGS Space for flicker-free multi-Space visibility (FS-01)
**What:** A dedicated, max-level (`Int32.max`) private CGS Space the panel joins ONCE at panel
creation, ADDITIVE to (never replacing) `collectionBehavior`'s `.canJoinAllSpaces`. Removes the
per-Space-transition re-parenting race that caused the Phase 2/6/8 fullscreen-enter flash.
**When to use:** Any overlay window that must render correctly through a Space transition without
a 1-frame compositor artifact.
**Example:**
```swift
// Source: Islet/Notch/CGSSpace.swift + NotchWindowController.swift:39,658-661
private let notchSpace = CGSSpace(level: 2147483647)   // Int32.max, matches 2 verified reference impls
// ... at panel creation (once, inside `if self.panel == nil`):
notchSpace.windows.insert(panel)
// ... in deinit:
if let panel { notchSpace.windows.remove(panel) }
```
**Anti-pattern (explicitly documented in-file, confirmed by Phase 9's own research):** Do NOT
remove `.canJoinAllSpaces` from `collectionBehavior` while relying on `CGSSpace` membership alone
— "no known shipping reference project" does this; it was deliberately deferred and never
combined. The two mechanisms are additive, not substitutable.

### Pattern 4: Runtime fullscreen detection via private CGS Spaces (NOT NSScreen safe-area)
**What:** `isBuiltinDisplayInFullscreenSpace(builtinUUID:)` reads `CGSCopyManagedDisplaySpaces`
and checks the built-in display's *current* Space `type == 4`. This is a background-agent-safe
signal for **another app's** fullscreen state (NSScreen's safe-area/auxiliary-area properties are
constant from Islet's own process and can never observe a foreign app going fullscreen).
**When to use:** Any background/LSUIElement app that must react to system-wide fullscreen state
changes it doesn't itself trigger.
**Fail-safe discipline to preserve:** any nil/parse-failure/ambiguous-match returns `false`
(prefer showing the island over wrongly hiding it) — see `FullscreenSpaceProbe.swift` full source,
already read this session, must carry over unchanged (file itself is out of phase scope — zero
diff expected, but the controller's call site (`updateVisibility()`) must keep calling it the
same way).

### Pattern 5: Single show/hide arbiter (`updateVisibility()`)
**What:** Exactly one function calls `panel?.orderOut(nil)` (hide) or `positionAndShow(on:)`
(show). Every observer (screen-parameters change, Space change, app-activate, license-expiry
timer, every activity handler) calls ONLY this function — never a second show/hide path.
**Why it matters for this rewrite:** the documented Pitfall in-file is explicit: "a double
show/hide site would race the clamshell and fullscreen observers into flicker / stuck state."
This is the same class of regression as CR-01 but for visibility instead of click-through — the
rewrite must preserve exactly one call site for each of `orderOut`/`positionAndShow`/
`orderFrontRegardless`.

### Pattern 6: Idle-state guard for license-driven hide (D-11/D-12/D-13)
**What:** `pendingLockoutHide` defers a license-expiry-driven hide when the pointer is mid-hover
or the island is mid-expansion, applying it only at the next natural transition
(`handleHoverExit`'s grace-elapsed collapse, or `handleClick`'s toggle-shut). This is the
Claude's-Discretion "refactor scope boundary" item — CONTEXT.md leaves extracting this into its
own coordinator (mirroring Phase 16's `DeviceCoordinator`) as optional.
**Extraction precedent to follow IF taken:** `DeviceCoordinator` (Phase 16) — constructed at
`start()` time (not declaration time) with `[weak self]`-capturing closures, exposed behind a
narrow protocol (`ActivityCoordinator`). If the license-gating logic separates cleanly from the
hover/click state machine during the actual line-by-line rewrite, this is the template; if it
doesn't separate cleanly, leave it inline — CONTEXT.md explicitly says "do not force an extraction
that adds risk to a zero-regression phase."

### Pattern 7: One-shot `DispatchWorkItem`, never a recurring timer
**What:** `graceWorkItem`, `dismissWorkItem`, `mediaDismissWorkItem`, `trialExpiryWorkItem` (and
Phase 21's `dragPinSafetyNetWorkItem`) all follow: cancel-if-pending → create new `DispatchWorkItem`
→ `DispatchQueue.main.asyncAfter`. Never a `Timer.scheduledTimer` recurring poll.
**Why:** idle-CPU-friendly (no tick when nothing is pending) and trivially cancelable on
re-entry (the grace-delay-cancel-on-quick-re-entry UX depends on this exact idiom).

### Anti-Patterns to Avoid

- **Toggling `.nonactivatingPanel` at runtime:** must stay a one-time `init`-only style-mask flag
  (Pattern 1's in-file comment is explicit that AppKit does not fully re-apply activation
  behavior post-init).
- **A second writer of `ignoresMouseEvents`:** breaks Pattern 2's single-arbiter guarantee — this
  is literally what CR-01 was (see Common Pitfalls below for the full incident).
- **A second show/hide call site:** breaks Pattern 5 (Pitfall 5 in-file: "double show/hide site
  would race... into flicker / stuck state").
- **Removing `.canJoinAllSpaces` while relying on `CGSSpace` alone:** breaks Pattern 3 (no known
  shipping app does this combination; deliberately untested).
- **Re-adding any `NSDraggingDestination` surface in Phase 23:** explicitly locked out by D-01 —
  Phase 24 builds its (different, Accessibility-API-style) detection mechanism from scratch.
- **Parallel-build-then-swap for THIS specific controller:** unlike a typical stateless
  service-layer rewrite, `NotchWindowController` holds live OS registrations (a global
  `.mouseMoved` monitor, `NSWorkspace` observers, IOKit/IOBluetooth monitors, a `CGSSpace`). Two
  live instances during a swap window risk double-registration side effects (e.g., two competing
  `CGSSpace`s both claiming max level, two global mouse monitors double-firing haptics). In-place,
  incremental, buildable-at-every-commit refactor avoids this category of risk entirely.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fullscreen detection from a background agent | A polling loop over `NSScreen` properties, or Accessibility-API window enumeration | The existing `CGSCopyManagedDisplaySpaces`-based `FullscreenSpaceProbe.swift` (out of scope, zero-diff) | Already solved, on-device verified across 3 trigger methods (Phase 9); re-solving it risks reintroducing the exact flash Phase 2→6→8→9 spent 4 phases eliminating |
| Multi-Space overlay visibility without flicker | A reactive `orderFrontRegardless()`-on-notification approach (Phase 2's original, which had the flash) | The additive `CGSSpace(level: Int32.max)` (Pattern 3) | Reactive approaches structurally cannot pre-empt a compositor pass that already rendered before the notification arrives — this is a window-server timing constraint, not a code bug (see `fullscreen-enter-flash.md` debug record, now closed as accepted/deferred) |
| Click-through hit-testing with more than one input variable | A second boolean flag OR'd into the interactivity check | `syncClickThrough()` as the sole arbiter, reading `pointerInZone` OR `visibleContentZone()` depending on `interaction.isExpanded` — never both | CR-01 is the concrete, already-shipped proof of what goes wrong (see Common Pitfalls) |

**Key insight:** every "hard problem" in this domain (fullscreen detection, flicker-free
multi-Space, focus-safe click-through) has already been solved, on-device verified, and had at
least one regression already found and fixed in this exact codebase. The rewrite's job is
preservation with full understanding of *why* each line exists, not re-derivation.

## Runtime State Inventory

This phase is a code rewrite of `NotchPanel.swift`/`NotchWindowController.swift`; the class names,
file names, and all `UserDefaults`/Keychain keys they read (`ActivitySettings.*`,
`LicenseState.shared`, etc.) are **unchanged** — this is not a rename/migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no renamed keys, no data-model changes | None |
| Live service config | None — no external service configuration touched | None |
| OS-registered state | The `CGSSpace(level: 2147483647)` is destroyed in `deinit` and recreated at next launch; the global `.mouseMoved` monitor and `NSWorkspace` observers are similarly recreated each launch via `start()`. Since the rewrite keeps the same lifecycle (constructed once in `AppDelegate.swift:68`, `start()` called once), no cross-launch state persists to migrate. | None — verified by reading `deinit` (lines 1328-1377) and `start()` (lines 277-373): every registration is launch-scoped, not persisted |
| Secrets/env vars | None referenced by these two files | None |
| Build artifacts | File names (`NotchPanel.swift`, `NotchWindowController.swift`) and the class names inside them are unchanged per CONTEXT.md's own framing ("rebuilt," not renamed) — no stale `.egg-info`-style artifact risk applies to a Swift/Xcode target | None — confirm the planner does not introduce new file names unless the rewrite strategy requires it (an in-place rewrite, the research recommendation, does not) |

## Common Pitfalls

### Pitfall 1: CR-01 — OR-ing a second flag into the click-through arbiter silently swallows clicks
**What goes wrong:** `syncClickThrough()`'s expanded-state branch is narrowed to
`visibleContentZone()` (the actual visible blob rect) specifically so an empty, reserved-but-
invisible shelf band doesn't swallow clicks meant for the app underneath the notch. A prior
in-flight version of this code ORed in the broader `pointerInZone` (tracking the padded
`expandedZone`, used for the separate "should we keep the island open" grace decision) — which
silently re-widened the hit-test back over the invisible band, regressing exactly the bug the
narrowing was meant to fix.
**Why it happens:** `pointerInZone` and `visibleContentZone()` look interchangeable ("is the
pointer near the panel") but answer two different questions (keep-open vs. actually-visible-and-
clickable). A refactor that touches this function and reaches for "the obvious broader check" —
or that merges two similar-looking conditionals during a rewrite — reintroduces this class of bug.
**How to avoid:** Any rewrite of `syncClickThrough()` must diff its final body against the exact
current implementation (Pattern 2's Code Example above) line-for-line, not just re-derive it from
the surrounding comments' intent.
**Warning signs:** grep/build gates do NOT catch this (confirmed by the CR-01 incident itself,
per project memory `cr01-clickthrough-or-defeat-gotcha`) — it requires an explicit **on-device
hover→expand→move-pointer-down-with-empty-shelf** interaction trace. This exact trace must be a
named step in Phase 23's on-device UAT (see Validation Architecture below), not merely implied by
"click-through hit-testing... verified regression-free" in the phase's own success criteria text.

### Pitfall 2: Phase 22's unresolved AppKit drag-delivery failure (relevant context, not a Phase-23 deliverable)
**What goes wrong (historical, for planner awareness — Phase 23 adds no drag code):** Phase 22's
`22-01` spike confirmed `draggingEntered` fires reliably on a click-through, non-activating
`NotchPanel` (`ignoresMouseEvents == true`) when the throwaway stub scaffold also implemented
`draggingUpdated(_:)`. Phase 22-03's real implementation deliberately omitted `draggingUpdated`
(citing Apple's own `NSDragging.h` header comment that `draggingEntered`'s returned operation is
reused for the whole hover session when `draggingUpdated` isn't implemented) — and on-device, this
omission caused `draggingEntered` to **never fire at all**, contradicting the documented contract.
Restoring `draggingUpdated` (matching the spike exactly, confirmed via `git show d1245e8`) was
believed to be the fix — but on a **second** on-device UAT round, `draggingEntered` still never
fired, with the exact same symptom, even with code now byte-identical in relevant part to the
confirmed-working spike. **The true root cause was never identified**; the user aborted Phase 22
and pivoted to this broader shell rewrite specifically because of this unresolved mystery
(`STATE.md` Blockers/Concerns, commit `8dbd064`).
**Why this matters for Phase 23 even though it adds no drag code:** the mystery means something
about *this specific panel's lifecycle or registration state* — not merely a missing override —
may be implicated (candidate hypotheses, unverified: panel re-creation/re-registration timing
relative to `orderFrontRegardless()`; interaction between the dedicated max-level `CGSSpace`
membership and the window-server's drag-destination hit-testing; some other AppKit-runtime-
specific quirk on this machine's Tahoe/Xcode 26.6 toolchain that differs from documented behavior).
Phase 23's rewrite is an opportunity to produce a **clean, minimal, well-understood** panel
lifecycle so that whatever Phase 24 does next (an Accessibility-API-based global monitor per
STATE.md, NOT `NSDraggingDestination` — see State of the Art below) starts from a shell with no
inherited, unexplained AppKit quirks.
**How to avoid regressing this further:** do not re-add any drag registration in Phase 23 (D-01
is explicit). If the planner wants extra insurance, task the on-device UAT with confirming the
panel's `orderFrontRegardless()`/frame-set/`CGSSpace`-join sequence in `positionAndShow()` is
unchanged in relative order from today — since that sequence is one of the few remaining
uninvestigated variables in the Phase-22 mystery.
**Warning signs:** none directly observable in Phase 23 (no drag code exists to fail) — this is
forward-looking context for Phase 24's planner/researcher, captured here because Phase 23 is where
the panel's construction is next touched.

### Pitfall 3: Fullscreen-enter 1-frame compositor flash (accepted, do not attempt to "fix" during rewrite)
**What goes wrong:** A single-frame flash of the island at the very end of a fullscreen-ENTER
transition. Root-caused (Phase 2, re-confirmed Phase 6) as the window server compositing the
`.canJoinAllSpaces` panel onto the activating fullscreen Space during the Space-switch animation
itself — this happens *before* any of Islet's reactive notifications
(`activeSpaceDidChangeNotification`, the CGS space-type probe) can fire.
**Why it happens:** every available signal is reactive; there is no proactive/pre-transition hook
available to a background LSUIElement app. A 0.2s show-debounce was tried and reverted (it added
latency while fixing nothing, since the blip is never on the app's own side to pre-empt).
**How to avoid:** do not attempt to fix this during the Phase 23 rewrite — it is explicitly
**accepted, product-deferred technical debt** (`.planning/debug/resolved/fullscreen-enter-flash.md`).
The rewrite's job is to reproduce the exact same (already-accepted) behavior, not improve on it.
Success Criterion #2 ("hides in true fullscreen... with no dead-zone regressions") does not
require eliminating this pre-existing, known, deferred flash.
**Warning signs:** if on-device UAT reports the flash is now WORSE, MORE frequent, or has a NEW
trigger method not in the original 3 (green-button, menu-bar, fullscreen-video), that would be a
genuine regression worth investigating; the flash's mere continued existence at its current
severity is not.

### Pitfall 4: Coordinate-space mismatches (global vs. window-base vs. flipped)
**What goes wrong:** `NSEvent.mouseLocation` is already global, bottom-left, unflipped — the
existing `handlePointer(at:)` explicitly does NO coordinate conversion when comparing against
`hotZone`/`expandedZone` (both computed in the same global space via `notchFrame`'s
`screenFrame.maxY`-based math). A rewrite that introduces ANY new geometry comparison must
preserve this "everything is global bottom-left, no conversion" invariant, or silently break
hit-testing on multi-display setups.
**Why it happens:** AppKit mixes coordinate conventions across APIs (`NSDraggingInfo
.draggingLocation` — window-base, needs `convertToScreen` — is a documented example the Phase-22
plan encountered, even though that specific code path is not in Phase 23's scope).
**How to avoid:** any new geometry helper added during the rewrite should follow `NotchGeometry
.swift`'s existing "AppKit windows use bottom-left origin, y increasing upward... the TOP edge is
`frame.maxY`" documented convention (already comment-flagged as "Pitfall 1" in that file).
**Warning signs:** hit-zone behaves correctly on the built-in display but drifts/misfires when an
external display is connected or when displays are arranged non-default (built-in not at origin).

### Pitfall 5: Device-specific notch geometry — do not hardcode measured constants
**What goes wrong:** The collapsed pill measures 179×32pt on the current dev machine
(`NotchPillView.collapsedSize` fallback is 200×38, distinct from the *live-measured* size
published via `interaction.collapsedNotchSize`), with wings at 305×32 (per project memory
`charging-connect-only-notch-size`). These are OUTPUTS of the live `notchSize(...)` measurement
(`NotchGeometry.swift`, out of scope), not values to hardcode anywhere in the rewritten
controller/panel.
**Why it happens:** a rewrite that "simplifies" by inlining an observed constant instead of
calling through to the live measurement would work perfectly on the dev machine and silently
break on any other notch-Mac model (different notch width) or a non-notch fallback path.
**How to avoid:** confirm the rewritten `positionAndShow()` still calls `notchSize`/`notchFrame`
live on every resolve (as today), never a cached/hardcoded fallback beyond the existing intentional
200×38 SwiftUI-side static seed.

## Code Examples

All examples below are the **current, on-device-verified production implementation** — the
rewrite's contract is to reproduce this behavior, not improve on it. Source: existing codebase
(`Islet/Notch/NotchPanel.swift`, `Islet/Notch/NotchWindowController.swift`), already read in full
this research session.

### Full current `updateVisibility()` (the single show/hide arbiter, Pattern 5)
```swift
// Source: Islet/Notch/NotchWindowController.swift:542-597
private func updateVisibility() {
    let wasVisible = isCurrentlyVisible
    let midInteraction = pointerInZone || interaction.isExpanded
    if !licenseState.isEntitled && midInteraction {
        pendingLockoutHide = true
        return
    }
    if pendingLockoutHide { pendingLockoutHide = false }

    let descriptors = NSScreen.screens.map { $0.descriptor }
    let target = selectTargetScreen(from: descriptors)
    let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

    if shouldShow(hasTarget: target != nil, hideInFullscreen: hideInFullscreen,
                  isFullscreen: fullscreen, isLicensed: licenseState.isEntitled),
       let target {
        isCurrentlyVisible = true
        positionAndShow(on: target)
        if !wasVisible { refreshWeather(); refreshCalendar() }
    } else {
        panel?.orderOut(nil)                 // THE only hide call in the file
        hotZone = nil
        expandedZone = nil
        pointerInZone = false
        isCurrentlyVisible = false
    }
}
```

### Full current `handlePointer(at:)` (global monitor hit-test, no coordinate conversion)
```swift
// Source: Islet/Notch/NotchWindowController.swift:671-702
private func handlePointer(at point: CGPoint) {
    lastPointerLocation = point
    let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
    if interaction.isExpanded { syncClickThrough() }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Reactive `orderFrontRegardless()` on Space-change notification for multi-Space visibility | Additive `CGSSpace(level: Int32.max)` joined once at panel creation | Phase 9 (this codebase, 2026-07-04) | Eliminated the fullscreen-enter flash structurally instead of debouncing it |
| Safe-area/auxiliary-area (`NSScreen`) as the fullscreen signal | `CGSCopyManagedDisplaySpaces` current-Space-type probe | Phase 2 (this codebase) | Only the CGS approach can observe ANOTHER app's fullscreen from a background LSUIElement process |
| `NSDraggingDestination` registered directly on the click-through panel (raw AppKit drag delegate) | Global Accessibility-API drag-position monitoring (TheBoringNotch's `DragDetector`, cited as the reference architecture Phase 24 plans to follow) | Discovered via Phase 22's failure + this session's external verification | `[CITED: deepwiki.com/TheBoredTeam/boring.notch/3.6-shelf-system]` — confirms the direction STATE.md already committed to (`DragApproachDetector`, global-monitor pattern) is the established reference-app pattern, not a novel workaround; also explains structurally why Phase 22's raw-registration approach may have been fighting the platform rather than using it as intended |

**Deprecated/outdated for THIS app specifically:** the Phase-22 `NSDraggingDestination`-on-panel
approach is not "deprecated" by Apple, but is now understood (via the reference-app comparison
above) to not be the pattern real shipping notch apps use for this exact use case — Phase 24
should not re-attempt it without first re-reading this finding.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | TheBoringNotch's `DragDetector` uses the Accessibility API (not `NSDraggingDestination`) for system-wide drag monitoring | State of the Art, Pitfall 2 | `[CITED: deepwiki.com — a third-party summarization of the boring.notch source, not the raw source file itself]`. If DeepWiki's summary is inaccurate, Phase 24's planner should re-verify directly against `github.com/TheBoredTeam/boring.notch` source before committing to an Accessibility-API design. Does not affect Phase 23's own deliverables (no drag code is added here). |
| A2 | The true root cause of Phase 22's `draggingEntered` non-delivery (surviving even after matching the confirmed-working spike) remains genuinely unidentified, not merely "missing draggingUpdated" | Pitfall 2 | Low risk to Phase 23 itself (adds no drag code); flagged so the planner doesn't assume this mystery is "solved" and doesn't need re-investigation before Phase 24 begins its own research. |

**All other claims in this research are `[VERIFIED: existing codebase]`** (read directly from
`Islet/Notch/*.swift` and `.planning/` phase history this session) or `[VERIFIED: git history]`
(reconstructed UAT checklists, abort commit messages) — no user confirmation is needed for those.

## Open Questions

1. **Rewrite strategy: in-place vs. parallel-build-then-swap**
   - What we know: CONTEXT.md leaves this to Claude's discretion; project convention is 100%
     in-place across every prior phase, including risky AppKit surgery.
   - What's unclear: whether the actual diff, once scoped by the planner, turns out small enough
     that either approach is equally safe.
   - Recommendation: **in-place**, in small `// MARK:`-section-sized commits, each independently
     buildable (`xcodebuild build -scheme Islet -configuration Debug`) — see Summary and the
     Anti-Patterns entry on live OS-registration duplication risk for the specific reasoning
     against a parallel-build window for this file.

2. **License-gating extraction (D-11/D-12/D-13) into its own coordinator**
   - What we know: Phase 16 already proved this codebase can cleanly extract bookkeeping behind a
     narrow protocol (`DeviceCoordinator`/`ActivityCoordinator`).
   - What's unclear: whether `pendingLockoutHide`'s two call sites (inside `updateVisibility()`
     and read at `handleHoverExit`/`handleClick`'s natural-transition rechecks) separate as
     cleanly as `DeviceCoordinator`'s original extraction did — this can only be judged once the
     planner is looking at the actual rewritten `updateVisibility()` body.
   - Recommendation: leave as a judgment call during execution, exactly as CONTEXT.md frames it;
     do not pre-commit to extraction in the plan if it adds risk.

3. **Whether to add a regression-specific on-device UAT step for the Phase-22 drag-delivery
   mystery (Pitfall 2), even though Phase 23 adds no drag code**
   - What we know: the mystery's true cause is unidentified; Phase 23 is the last touchpoint on
     `positionAndShow()`'s panel-creation sequence before Phase 24 needs it.
   - What's unclear: whether preserving the exact current ordering (frame-set →
     `NSHostingView` assignment → `CGSSpace` join → `orderFrontRegardless`) is sufficient insurance,
     or whether Phase 24's own research should independently re-verify AppKit drag delivery on
     the rewritten shell before building `DragApproachDetector` on top of it.
   - Recommendation: Phase 23's planner should NOT attempt to solve this (out of scope, no drag
     code exists to test); Phase 24's researcher should treat "does the rewritten shell change
     anything about drag-event routing" as its own open question, informed by this section.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / `xcodebuild` | Build gate after every task | ✓ | 26.6 (project memory: build machine is Tahoe/Xcode 26.6/Swift 6.3.3) | — |
| `xcodegen` | Regenerating `Islet.xcodeproj` from `project.yml` after file changes | ✓ (used throughout Phase 19-22 plans) | — | — |
| Physical notch MacBook (on-device UAT) | Every Success Criterion — this phase is not verifiable via `xcodebuild test` (project memory: hangs headlessly hosting the full app boot) | ✓ (per project memory / CLAUDE.md: "for manual verification steps, give exact Finder/Xcode instructions, never terminal commands" — user runs Cmd-R + Cmd-U manually) | — | — |
| macOS Tahoe (26.x) | CGS private-symbol behavior (`CGSCopyManagedDisplaySpaces`, `CGSSpace*`) is only verified on this OS version | ✓ | Tahoe | If Apple changes these symbols in a future macOS release, `FullscreenSpaceProbe.swift`'s in-file DEBUG log ("`[ISL-05] builtin current-space type = ...`") already exists to re-confirm the `type == 4` constant — but that file is out of this phase's scope (zero-diff expected) |

**Missing dependencies with no fallback:** none identified.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, `IsletTests/` target) — `NotchPanelTests.swift` already covers panel construction properties (`.nonactivatingPanel`, `canBecomeKey/Main == false`, `.statusBar` level, `collectionBehavior`, starts-click-through, transparent/no-shadow); `InteractionStateTests.swift` covers the pure state machine; `FullscreenDetectorTests.swift`/`VisibilityDecisionTests.swift` cover the pure gates. **No `NotchWindowControllerTests.swift` exists** — confirmed via directory listing; the 1,378-line AppKit glue controller itself has never had direct unit tests (it is integration-heavy AppKit code, same as every prior phase's convention). |
| Config file | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (compile-only gate — `xcodebuild test` hangs headlessly hosting the full app boot, project memory `xcodebuild-test-headless-hang`) |
| Full suite command | Manual **Cmd-U in Xcode** (existing project-wide convention since Phase 20/21/22) |
| Estimated runtime | ~30-60s build gate per commit; manual Cmd-U + on-device UAT pass is untimed |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCH-01 (panel construction properties) | Borderless, non-activating, never-key/main, `.statusBar`, correct `collectionBehavior`, starts click-through, transparent, zero `NSDraggingDestination` residue | unit | Cmd-U `NotchPanelTests` (update `testPanelStartsClickThrough`-style assertions; ADD an assertion that `NotchPanel` no longer registers dragged types / conforms to `NSDraggingDestination` — e.g. via a `!(panel is NSDraggingDestination)` cast check) | ✅ existing file, needs one new assertion |
| ARCH-01 (pure state machine, unaffected) | `nextState(...)` transitions incl. `.dragEntered` (inert, Phase-24-reusable) | unit | Cmd-U `InteractionStateTests` | ✅ (zero-diff expected) |
| ARCH-01 (fullscreen gate, unaffected) | `shouldShow(...)` pure predicate | unit | Cmd-U `VisibilityDecisionTests`/`FullscreenDetectorTests` | ✅ (zero-diff expected, files out of phase scope) |
| ARCH-01 (position/hover/click/grace-collapse/fullscreen-hide/click-through/multi-Space, Success Criteria #1-4) | Live AppKit integration behavior — NOT unit-testable, requires real Window Server / real pointer / real Space transitions | manual (on-device) | N/A — see consolidated UAT below | N/A — same "not unit-testable" caveat every prior phase touching this controller has documented |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (build gate only)
- **Per wave merge:** manual Cmd-U for `NotchPanelTests`/`InteractionStateTests`/`VisibilityDecisionTests`/`FullscreenDetectorTests` + a manual on-device spot-check
- **Phase gate (before `/gsd:verify-work`):** the full consolidated on-device UAT below, PLUS Cmd-U green

### Consolidated On-Device UAT (reconstructed from git history — source files were cleared at
milestone archival but content is recoverable; assembled here so the planner doesn't need to
re-derive it)

**From Phase 2's `02-HUMAN-UAT.md` (8 items, git-recovered from commit `3a38aec~1`):**
1. Hover/click feel — hover fires haptic + bounce WITHOUT expanding (D-01); click expands with
   spring morph (D-02); pointer-leave collapses after ~0.4s grace; quick re-entry cancels collapse.
2. Morph quality — full expand→collapse cycle is one continuous shape morph, no cross-fade/flicker/jump.
3. Fullscreen VIDEO yield (Safari YouTube / QuickTime) — island hides completely, no ghost bar;
   exiting restores it.
4. QuickLook yield (Finder → select → Space → QuickLook fullscreen) — island hides while
   QuickLook is fullscreen; closing restores it.
5. Maximized (zoomed, NOT fullscreen) window — island STAYS visible (a zoom is not a fullscreen
   Space).
6. Clamshell + external-display coexistence — no flicker/stuck-hidden/stuck-shown; island only
   ever shows on the built-in notched display.
7. Focus-safety of auto-restore — restoring the island after fullscreen-exit does NOT steal focus
   from the foreground app.
8. Click-through around the island — clicks outside the pill (idle AND expanded) pass through;
   interacting with the island never activates Islet.

**From Phase 9's fullscreen-flash verification (git-recovered from `37bc5b9` `09-01-SUMMARY.md`),
the D-07 trigger matrix + 8-item regression checklist:**
- **3-trigger flash check** (3 methods × repeated trials each): green-button click,
  menu-bar "Enter Full Screen", and a fullscreen video app — confirm ZERO flash at fullscreen-
  ENTER across all three (NOTE: the separate, already-accepted 1-frame flash is a DIFFERENT,
  deferred issue — see Pitfall 3 — this check is specifically about the flash Phase 9 eliminated,
  not the still-open Pitfall 3 one).
- Hover/click-expand without focus steal.
- Click-through outside the pill while collapsed.
- Visibility across 2+ ordinary (non-fullscreen) Spaces.
- Positioning through display/clamshell changes.
- Fullscreen hide-during/restore-on-exit (all 3 trigger methods).
- Ordinary (non-fullscreen) Space switch.
- Lock-screen / sleep-wake.

**CR-01-specific trace (project memory `cr01-clickthrough-or-defeat-gotcha` — explicitly does NOT
reduce to a grep/build gate):**
- With the shelf EMPTY: hover the pill → click to expand → move the pointer DOWN into the
  reserved-but-invisible empty shelf band (below the visible blob) → confirm a click THERE passes
  through to the app underneath (does NOT get swallowed) → move back up into the visible blob →
  confirm a click THERE is captured by Islet. This exact hover→expand→move-down→click sequence is
  the only verification that has ever caught this regression class.

**Recommendation (per CONTEXT.md's discretion framing):** run this fully consolidated ~20-item
checklist as ONE phase-gate pass, given ARCH-01's explicit "zero behavioral regression" framing
and that this is the most safety-critical code in the app (focus-safety, click-through,
fullscreen). Only fall back to a lighter spot-check if the actual rewrite diff turns out
small/mechanical (e.g., pure syntactic reorganization with no logic touched) — the planner should
make that call once the diff shape is known, per CONTEXT.md.

### Wave 0 Gaps
- [ ] `NotchPanelTests.swift` — add one assertion confirming `NotchPanel` no longer conforms to
      `NSDraggingDestination` / registers dragged types (covers Success Criterion #4 at the unit
      level, supplementing the on-device confirmation)
- [ ] No new test framework/config needed — `IsletTests` target already exists and builds
- [ ] No `NotchWindowControllerTests.swift` gap to fill — this is consistent with every prior
      phase's convention (the controller is integration-only, not unit-testable), not a new gap
      introduced by this phase

## Security Domain

`security_enforcement` is not explicitly disabled in `.planning/config.json` (absent = enabled),
so this section is included per protocol — but this phase has an unusually small new attack
surface: it is a rewrite of existing, already-threat-modeled window-shell code with **zero new
user input, zero new network/IPC surface, and zero new external dependencies**.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | Not touched — `LicenseState`/trial logic is read, not modified, by this phase (only its call sites in `updateVisibility()`/`handleClick()` are potentially refactored, never its internals) |
| V3 Session Management | No | N/A — no session concept in this window-shell code |
| V4 Access Control | No | N/A |
| V5 Input Validation | No new surface | No new user-controlled input is introduced; the only "input" is OS pointer/window/Space-change events, already validated by the existing fail-safe patterns (Pattern 4's nil-propagating fullscreen probe) |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Un-entitled private CGS API calls failing silently on a future macOS update | Denial of Service (self, availability) | Already mitigated by the existing fail-safe design (`FullscreenSpaceProbe.swift` returns `false`/"not fullscreen" on any parse failure, preferring to show the island over wrongly hiding it) — the rewrite must preserve this fail-safe discipline at every CGS call site it touches |
| Focus-stealing via a rewritten show/hide or click path | Elevation of Privilege (of the app's own attention over the user's foreground app) | D-04/D-07's `.nonactivatingPanel` + `canBecomeKey/Main == false` + `orderFrontRegardless`-only (never `makeKeyAndOrderFront`) discipline — the rewrite must not introduce ANY focus-stealing call, verified by UAT item 7 above |
| Double-registration of OS-level monitors/observers during a botched swap | Denial of Service (duplicate haptics, duplicate CGSSpace claims, resource leak) | Addressed structurally by this research's in-place-rewrite recommendation (see Anti-Patterns) rather than a runtime mitigation — avoiding a parallel-instance window removes the threat rather than defending against it |
| Supply chain (new packages) | Tampering | Not applicable — zero new dependencies (Package Legitimacy Audit above) |

## Sources

### Primary (HIGH confidence — existing codebase, read in full this session)
- `Islet/Notch/NotchPanel.swift` (62 lines, full file)
- `Islet/Notch/NotchWindowController.swift` (1,378 lines — read in full: lines 1-100, 277-406,
  536-876, 1326-1378, plus targeted greps for every `func`/property declaration)
- `Islet/Notch/NotchGeometry.swift`, `Islet/Notch/NotchInteractionState.swift`,
  `Islet/Notch/DragDropSupport.swift`, `Islet/Notch/CGSSpace.swift`,
  `Islet/Notch/FullscreenSpaceProbe.swift` (all full files)
- `IsletTests/NotchPanelTests.swift` (full file) + directory listing of `IsletTests/`
- `.planning/phases/23-shell-parity-rewrite/23-CONTEXT.md`, `.planning/REQUIREMENTS.md`,
  `.planning/STATE.md`, `project.yml`, `.planning/config.json`

### Secondary (MEDIUM confidence — git history reconstruction of cleared files + external
verification of a third-party reference app)
- `.planning/phases/22-drag-in/22-CONTEXT.md`, `22-01-SUMMARY.md`, `22-03-PLAN.md`,
  `22-VALIDATION.md`, `22-PATTERNS.md` (full files)
- `git log`/`git show` on branch `worktree-agent-a9e6341bfc04601a5` (commits `326804d`, `35c3026`,
  `8fb5517`, `8af3e77`, `d1245e8`) and commit `8dbd064` (the Phase 22 abort record) on `main`
- `git show 3a38aec~1:.planning/phases/02-hover-expand-fullscreen-hardening/02-HUMAN-UAT.md` (the
  8-item checklist, recovered from before the phase-directory clear)
- `git show 37bc5b9:.planning/phases/09-fullscreen-flash-window-space-retry/09-01-SUMMARY.md` (the
  3-trigger matrix + 8-item regression checklist)
- `.planning/debug/resolved/fullscreen-enter-flash.md` (full file — the accepted/deferred Pitfall 3)
- [Shelf System | TheBoredTeam/boring.notch | DeepWiki](https://deepwiki.com/TheBoredTeam/boring.notch/3.6-shelf-system) — confirms the reference app's `DragDetector` uses Accessibility-API global monitoring, not `NSDraggingDestination` on the panel (informs State of the Art / Pitfall 2; tagged `[CITED]`, not independently re-verified against raw source)

### Tertiary (LOW confidence — general WebSearch, not independently verified)
- General WebSearch results on `ignoresMouseEvents` vs. drag delivery produced a plausible-sounding
  but **incorrect** summary (claiming `ignoresMouseEvents=true` would prevent
  `NSDraggingDestination` delivery) that directly contradicts this project's own on-device-
  confirmed finding (22-01-SUMMARY.md: `draggingEntered` DID fire with `ignoresMouseEvents ==
  true`). Documented here explicitly as a caution: this project's own empirical on-device test
  result is the higher-confidence source and should be trusted over generic AI-search-summarized
  claims about AppKit internals.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, everything already linked and verified on-device across 9+ prior phases
- Architecture: HIGH — every pattern is read directly from the existing, already-shipped, already-UAT'd source
- Pitfalls: HIGH for CR-01/fullscreen-flash (both fully root-caused and documented in this codebase's own history); MEDIUM for the Phase-22 drag-delivery mystery (root cause itself is honestly unresolved — flagged as such, not papered over)

**Research date:** 2026-07-11
**Valid until:** Effectively indefinite for the AppKit/CGS patterns (stable since Phase 2/9, no
Apple API changes expected to affect this narrow surface) — but re-verify the private CGS symbol
behavior (Pattern 3/4) after any macOS Tahoe point-release or major-version update, per the
project's own existing risk note.
