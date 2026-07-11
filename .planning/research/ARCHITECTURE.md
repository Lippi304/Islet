# Architecture Research: NotchPanel/NotchWindowController Redesign (v1.4)

**Domain:** macOS overlay-window shell + AppKit↔SwiftUI drag/hover bridge for a persistent notch "Dynamic Island" clone
**Researched:** 2026-07-11
**Confidence:** MEDIUM-HIGH (grounded in real reference-repo source reads + this project's own confirmed on-device debugging trail, not speculation)

> Supersedes the prior `ARCHITECTURE.md` (2026-07-09, v1.3 shelf-integration research) for the purposes of the v1.4 milestone. That doc's findings (shelf is a plain `@Published` axis, not an `ActivityCoordinator`; Islet is unsandboxed; session-only temp-copy data model) remain true and are preserved as "survives untouched" facts below — see `.planning/phases/19-shelf-data-model/` through `21-drag-out/` for the full original detail if needed.

## Standard Architecture

### System Overview — current Islet shell (what exists today)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ NotchPanel (NSPanel) — 62 lines, window shell ONLY                        │
│  .borderless + .nonactivatingPanel, .statusBar level, .canJoinAllSpaces   │
│  + a SECOND dedicated max-level private CGS Space (Phase 9, additive)     │
│  ignoresMouseEvents: true↔false, flipped ONLY by syncClickThrough()       │
│  contentView = NSHostingView(NotchPillView)                               │
│  [residual, unmerged-production] registerForDraggedTypes([.fileURL]) +    │
│  4 NSDraggingDestination stub overrides (Phase 22 spike, still on disk,   │
│  NOT wired to real logic — see "Current Blocker" below)                   │
└──────────────────────────┬─────────────────────────────────────────────┘
                            │ NSHostingView
┌──────────────────────────▼─────────────────────────────────────────────┐
│ NotchWindowController (AppKit/SwiftUI bridge, 1378 lines, single owner)   │
│  • Global NSEvent.mouseMoved monitor → handlePointer() → pointerInZone/   │
│    expandedZone/hotZone hit-test → syncClickThrough() [ONE arbiter]      │
│  • nextState(_:_:) pure state machine (NotchInteractionState.swift) —    │
│    hover/click/grace-collapse/(now) dragEntered → matchedGeometryEffect  │
│  • Owns + constructs: NowPlayingMonitor, PowerSourceMonitor,             │
│    BluetoothMonitor (behind DeviceCoordinator/ActivityCoordinator),      │
│    ShelfCoordinator                                                      │
│  • resolve(...) (IslandResolver.swift, pure) + TransientQueue = the      │
│    ONE priority arbiter (Charging > Device > Now Playing)                │
│  • renderPresentation()/makeRootView() → hosts NotchPillView (1017 ln)   │
└──────────────────────────┬─────────────────────────────────────────────┘
                            │
        ┌───────────────────┼────────────────────┬─────────────────────┐
        ▼                   ▼                    ▼                     ▼
 PowerSourceMonitor  DeviceCoordinator/    NowPlayingMonitor      ShelfCoordinator
 (IOKit, 112 ln)     BluetoothMonitor      (MediaRemote           (ShelfLogic +
                     (262+157 ln, behind    adapter, 113 ln)      ShelfFileStore,
                     ActivityCoordinator                          72 ln, zero
                     protocol)                                    coupling to
                                                                   IslandResolver)
```

### Component Responsibilities (current → post-redesign)

| Component | Responsibility | Survives a shell rewrite? |
|-----------|----------------|----------------------------|
| `NotchPanel` | Window shell ONLY — styleMask/level/collectionBehavior/`ignoresMouseEvents` toggle point; zero business logic | **Rewritten** — this is the actual target of the redesign |
| `NotchWindowController` | Single AppKit↔SwiftUI arbiter: hover hit-test, click-through, state machine drive, owns all monitors/coordinators, calls `resolve()` | **Rewritten at the AppKit-glue edges, preserved at the core** — monitor ownership and `resolve()`-calling move to the new shell verbatim; only geometry/hit-test/drag-registration internals change |
| `NotchInteractionState.swift` (`nextState`, pure) | Hover/click/grace/drag-enter transitions | **Untouched** — pure Foundation-only reducer, zero AppKit surface, already has `.dragEntered` (built in Phase 22-02) |
| `IslandResolver.swift` (`resolve`, pure) + `TransientQueue` | Charging > Device > Now Playing priority arbitration | **Untouched** — pure, zero AppKit surface, zero coupling to window mechanics |
| `DeviceCoordinator` / `ActivityCoordinator` protocol | Bluetooth/device splash bookkeeping | **Untouched** — already an independently-testable seam (Phase 16), constructed by whichever controller replaces `NotchWindowController` |
| `ShelfCoordinator` / `ShelfLogic` / `ShelfFileStore` | Shelf data model, session-only storage, dedup | **Untouched** — zero coupling to `IslandResolver`/window mechanics by design (Phase 19 D-01); the shelf is a plain `@Published` axis the view renders underneath whatever `resolve()` decided, never a competing `ActivityCoordinator` |
| `NotchGeometry.swift` | `topPinnedFrame()`, notch/wings/expanded frame math | **Untouched** — pure geometry, no window-object dependency |
| `CGSSpace.swift` (Phase 9, FS-01) | Dedicated max-level private CGS Space the panel joins once, additive to `.canJoinAllSpaces`, fixes fullscreen-enter flash | **Preserved as a decision, re-attached to whatever new panel object exists** — this is a hard-won, on-device-verified fix; the rewrite must re-join this same Space, not re-derive the fix |
| `NotchPillView.swift` (SwiftUI, 1017 ln) | All visible rendering | **Mostly untouched** — theming/onboarding/calendar work happens here, layered on top of whatever shell exists |
| `DragDropSupport.swift` (Phase 22-02) | `fileURLs(from:)` / `shouldAcceptDrop(isExpanded:urls:)` pure seams | **Untouched** — already unit-tested, reused verbatim by the new drag pattern below |

## The Current Blocker, Diagnosed

### What is actually different between the WORKING spike and the FAILING production wiring

This is the single most load-bearing fact for this redesign, and it was sitting in this project's own git history, not previously synthesized. Comparing the three real commits:

1. **`7571001`** (22-01 spike, Task 2 verdict: `draggingEntered` CONFIRMED firing on-device) — `NotchPanel` implements exactly 4 protocol methods directly with logic inline: `draggingEntered` (NSLog + `.copy`), `draggingUpdated` (`.copy`), `draggingExited` (NSLog), `performDragOperation` (NSLog + `true`). No `draggingEnded`. No stored closures — bodies do real work.
2. **`326804d`** (22-03 Task 1, first production wiring) — replaced the 4 inline bodies with **thin closure-forwarding stubs** (`onDraggingEntered`/`onDraggingExited`/`onDraggingEnded`/`onPerformDragOperation` closures set later by the controller) and **dropped `draggingUpdated` entirely**, based on a documented-but-wrong reading of `NSDragging.h` ("AppKit reuses `draggingEntered`'s returned operation for the whole hover session when a destination implements `draggingEntered` but not `draggingUpdated`"). On-device: `draggingEntered` never fired at all.
3. **`d1245e8`** (restore `draggingUpdated`) — root-cause debugging (confirmed via a diagnostic `print` placed as the literal first line of `draggingEntered`, before any closure dereference) found that re-adding `draggingUpdated` was necessary but **still not sufficient** — a second on-device UAT still showed **zero delivery**, with the probe never printing even once. This is recorded in `22-03-PLAN.md`'s interfaces section and `STATE.md`'s Blockers/Concerns as genuinely unresolved.

So there are two distinct empirical findings, not one:

- **Confirmed sub-cause (fixed, insufficient alone):** omitting `draggingUpdated(_:)` breaks `draggingEntered` delivery on this OS build, contradicting the documented Objective-C contract. This is real and reproducible (A→B: present in the working spike, absent in the first failing build, restoring it was the first fix attempt).
- **Unresolved second failure:** even with `draggingUpdated` restored, delivery still failed on a second on-device run, with a probe planted directly inside the AppKit override (not the controller-side closure) still silent. The team's own commit message calls this "true cause still unknown," and that is an accurate characterization — do not treat it as solved.

### Ranked hypotheses for the residual failure (grounded, not speculative)

| # | Hypothesis | Grounding | Confidence |
|---|------------|-----------|------------|
| H1 | **Window-level `NSDraggingDestination` registration on an oversized, `ignoresMouseEvents`-toggling, never-key `NSPanel` is inherently fragile/non-reproducible on this OS build**, independent of any one code bug — i.e. the architecture itself (not a specific line) is the risk. | Neither reference implementation researched below uses this technique at all (see next section) — a strong absence-of-precedent signal. Islet's own 22-RESEARCH.md flagged this exact combination (`.nonactivatingPanel` + `.statusBar` + never-key + toggling `ignoresMouseEvents`) as "not found addressed in any source" (Assumption A3, MEDIUM confidence) before the phase even started. Two independent on-device failures against the identical architecture, with the second surviving the one documented fix attempt, is consistent with an unstable rather than a single-bug-fixable pattern. | MEDIUM-HIGH |
| H2 | **A window-frame/geometry mismatch** — the drag literally never crossed the panel's real on-screen rect at the moment of the second test (stale `panelFrame`, a `setFrame` race against `positionAndShow`, or the Phase 20/21 shelf-height growth changing the reserved footprint's actual Y-origin in a way the accept-region math didn't account for) — meaning `draggingEntered` correctly never fired because the drag genuinely missed the window, not because delivery is broken. | The project's own commit `8fb5517` explicitly separates this from H1 by design ("distinguishes 'AppKit never calls this at all' ... from 'it fires but the isWithinDragAcceptRegion gate rejects every location'") — but the probe that would prove/disprove this (placed at the very top of `draggingEntered`, before any gate logic) never fired either. This does NOT rule out H2 — a probe at the top of an AppKit override still requires AppKit to have decided to call the override at all, so a geometry miss and a delivery failure look identical from that probe's vantage point. Not disproven, not proven. | MEDIUM |
| H3 | **A second, competing drag-destination claim shadows the window-level one** — e.g. `NSHostingView`'s internal SwiftUI runtime silently registers its own drag-destination handling on the content view once any SwiftUI view in the tree uses drag-related modifiers elsewhere in the app (Phase 21's `.onDrag` for drag-OUT lives in the same view tree), and the Window Server picks the deepest/topmost registered destination at a given point, not necessarily the window itself. | Not directly evidenced in the debugging trail (no one tested this in isolation), but it is the exact "Anti-Pattern" 22-RESEARCH.md itself warned about ("Registering drag types on both the `NSHostingView` AND the `NotchPanel` window... choose ONE") — worth auditing for accidental double-registration in the rewrite even though Phase 22's plan deliberately avoided this pattern on paper. | LOW-MEDIUM |
| H4 | **Swift `@objc` dynamic-dispatch resolution differs between a `final class` with only-protocol-satisfying (non-`override`) methods compiled as part of the full app target vs. an isolated spike** — some interaction with whole-module optimization, dead-code stripping, or the fact that 22-03 added extra methods (`draggingEnded`) and extra stored closure properties that the spike never had. | Weakest hypothesis — Swift/ObjC bridging for `@objc optional` protocol conformance does not typically depend on unrelated stored properties or additional protocol methods being present. Included only because it was the kind of surprising thing 22-01 already tripped once (the `override` vs. plain-conformance compile error) — i.e. this codebase has ALREADY hit one non-obvious Swift/AppKit interop gotcha in this exact file, raising the prior for a second, more elusive one. | LOW |

**Recommendation:** treat this as an architecture question, not a bug-hunt. Don't re-attempt H2/H3/H4 diagnosis in isolation — the reference-implementation research below gives a concrete alternative that sidesteps H1 entirely, which is the highest-leverage move regardless of which hypothesis is actually true.

## Reference Implementation Findings (real source, fetched and read 2026-07-11)

### TheBoringNotch (`TheBoredTeam/boring.notch`) — HIGH confidence, primary reference

Cloned and read directly (not summarized from memory). Three concrete, load-bearing findings:

**1. Zero use of `NSDraggingDestination`/`registerForDraggedTypes` anywhere in the codebase.** Confirmed by an exhaustive repo-wide grep — the string does not appear once. Their window class (`BoringNotchWindow`/`BoringNotchSkyLightWindow`, both `NSPanel` subclasses) is structurally very close to Islet's `NotchPanel` (`.borderless`/`.nonactivatingPanel`-equivalent styleMask via `.utilityWindow`/`.hudWindow`, `canBecomeKey`/`canBecomeMain` both `false`, `.canJoinAllSpaces`/`.stationary`/`.fullScreenAuxiliary` collection behavior, `isReleasedWhenClosed = false`) — **but it never sets `ignoresMouseEvents` at all**, and never registers as an AppKit drag destination.

**2. Drag-in is a two-stage pipeline that never touches AppKit's native drag-destination API for the "detect approach" stage:**
   - `DragDetector` (`boringNotch/observers/DragDetector.swift`) uses **global `NSEvent` monitors** for `.leftMouseDown`/`.leftMouseDragged`/`.leftMouseUp` (not `.mouseMoved`) plus **polling `NSPasteboard(name: .drag).changeCount`** after mouse-down to distinguish "an ordinary click-drag" from "an actual OS content-drag session in progress." Once a content-drag is confirmed AND `NSEvent.mouseLocation` (sampled on every `.leftMouseDragged` tick) enters a purely-geometric `notchRegion` rect derived straight from `screen.frame` — no window/registration involvement at all — it fires `onDragEntersNotchRegion`, which calls `viewModel.open()` to auto-expand.
   - Only THEN, once the window is expanded and its content view genuinely occupies that screen real estate, does a SwiftUI `.onDrop(of:isTargeted:perform:)` modifier (`ContentView.swift`'s `dragDetector` computed view, a `Color.clear.contentShape(Rectangle())` background, conditionally present only `if vm.notchState == .closed`) receive the actual payload via `NSItemProvider`.
   - This is architecturally the **opposite order** from what Islet's Phase 22 attempted: Islet tried to make the AppKit window itself the drag-destination FIRST (while collapsed/click-through), and derive auto-expand from that. TheBoringNotch detects approach via global mouse+pasteboard polling FIRST (bypassing AppKit drag-destination registration entirely for that stage), and only asks AppKit/SwiftUI's native drag machinery to do anything once the window is already expanded and non-click-through.
   - Global `.leftMouseDragged` monitors DO fire during an active OS drag session (confirmed by this codebase working in production) — this is a useful, concrete data point for Islet's own Pitfall 3 finding that `.mouseMoved` freezes during a drag: `.mouseMoved` and `.leftMouseDragged` are different event types with different delivery guarantees during a modal drag-tracking loop; `.leftMouseDragged` survives, `.mouseMoved` does not.

**3. Window frame is NOT click-through at all — SwiftUI's own hit-testing does the job `ignoresMouseEvents` does in Islet.** `windowSize` (`sizing/matters.swift`) equals the FULL open/expanded notch size (not just the small collapsed pill) — the NSPanel's frame is large and persistent, same idea as Islet's always-reserved footprint — yet zero `ignoresMouseEvents` toggling exists anywhere. This works because SwiftUI's `NSHostingView` hit-testing naturally passes clicks through transparent, non-interactive regions of the view tree down to whatever window is beneath (a `Color.clear` view WITHOUT an explicit `.contentShape`+gesture attached does not intercept ordinary clicks); only the specific `dragDetector` background view opts INTO hit-testing (via `.contentShape(Rectangle())` + `.onDrop`), and even that appears not to block ordinary mouse clicks, because `.onDrop`'s registration is (per Apple's own drag/mouse-dispatch separation, cited in Islet's own 22-RESEARCH.md) a distinct pathway from ordinary click hit-testing.

### DynamicNotchKit (`MrKai77/DynamicNotchKit`) — HIGH confidence on existence, confirms it's the wrong tool for this

Cloned and read directly. **Zero drag-and-drop code anywhere in the package** (confirmed by the same exhaustive grep). `DynamicNotchPanel` is a minimal `NSPanel` subclass (27 lines) with `level = .screenSaver`, `.canJoinAllSpaces`/`.stationary`, and — critically — **`canBecomeKey: true`** (the opposite of both Islet's and TheBoringNotch's `false`). The whole package (`DynamicNotch.swift`) is an imperative `async` API (`await notch.expand()` / `.compact()` / `.hide()`) built for transient, activatable popovers, not a permanently-present, always-click-through-except-when-hovered island. This reconfirms the project's own original stack research verdict: DynamicNotchKit is not a candidate base for the persistent island shell, and it offers **no pattern at all** for the drag-in problem — it cannot be "borrowed from" here, only ruled out as noise.

### What to actually take from this research

The single concrete, evidence-grounded architectural recommendation: **stop registering `NSDraggingDestination` on the AppKit window (`NotchPanel`) entirely.** Replace it with the two-stage pattern TheBoringNotch actually ships in production:
1. A global-event-monitor-based `DragApproachDetector` (new, small, ~100 lines, pure `NSEvent`/`NSPasteboard` — no `NSDraggingDestination` conformance anywhere) that detects an in-flight OS content-drag and its entry into a geometric region computed from existing `NotchGeometry.swift`/`expandedZone` math — this ELIMINATES both H1 (no window-level drag-destination registration to be fragile in the first place) and the original Mission-Control hot-zone problem (22-01's Open Question 4) for free, since detection never depends on the drag actually reaching a registered AppKit destination — only on `NSEvent.mouseLocation` crossing a rect, which is exactly the same global-coordinate math `handlePointer`/`pointerInZone` already do today.
2. SwiftUI `.onDrop(of:isTargeted:perform:)` (Pattern 2 from Islet's own 22-RESEARCH.md, written but never attempted since the AppKit-direct path's spike falsely appeared to confirm A1) attached directly to the collapsed-pill/shelf content view, which only needs to actually receive events once the island is already expanded and interactive (i.e., after `syncClickThrough()` has already flipped `ignoresMouseEvents` false through the EXISTING, proven arbitration path) — removing any need to reason about whether AppKit drag delivery survives a click-through, never-key, dual-Space `NSPanel`, because by the time `.onDrop` needs to fire, the panel is already fully interactive by the pre-existing, shipped mechanism.

This is a genuinely different, lower-risk architecture than either "debug the AppKit path more" or "blindly rewrite everything" — it is a **targeted replacement of exactly the one AppKit mechanism that twice failed on-device**, reusing (not rewriting) `NotchGeometry.swift`, `handlePointer`'s global-coordinate conventions, `syncClickThrough()`, and every downstream `ShelfCoordinator`/`DragDropSupport.swift` seam Phase 22 already built and unit-tested.

## Recommended Project Structure (post-redesign)

```
Islet/Notch/
├── NotchPanel.swift              # UNCHANGED SHAPE: window shell only. Drops the
│                                  #   NSDraggingDestination conformance + registerForDraggedTypes
│                                  #   entirely (H1 elimination) — reverts to the pre-Phase-22 62-line
│                                  #   shell plus whatever the redesign's other goals need (see below)
├── NotchWindowController.swift   # Split candidate (see Sequencing) — hover/click-through/state-
│                                  #   machine glue stays; monitor ownership stays; the NEW
│                                  #   DragApproachDetector is owned here exactly like
│                                  #   PowerSourceMonitor/BluetoothMonitor are today
├── DragApproachDetector.swift    # NEW — global NSEvent .leftMouseDown/.leftMouseDragged/.leftMouseUp
│                                  #   monitors + NSPasteboard(name: .drag) changeCount polling +
│                                  #   region-entry callback, modeled directly on TheBoringNotch's
│                                  #   DragDetector.swift (pattern reuse, not a copy)
├── DragDropSupport.swift         # UNCHANGED — Phase 22-02's fileURLs(from:)/shouldAcceptDrop(...)
│                                  #   pure seams already exist and are unit-tested; the new .onDrop
│                                  #   closure calls these exactly as 22-03's handleDragPerform would
│                                  #   have
├── NotchInteractionState.swift   # UNCHANGED — .dragEntered event already exists (22-02)
├── NotchGeometry.swift           # UNCHANGED — topPinnedFrame()/expandedZone math reused by the
│                                  #   new DragApproachDetector's region computation
├── IslandResolver.swift          # UNTOUCHED
├── DeviceCoordinator.swift /
│   ActivityCoordinator.swift     # UNTOUCHED
└── CGSSpace.swift                # UNTOUCHED — re-attached to whatever NotchPanel instance exists
                                   #   post-redesign; the Phase 9 fix is a decision, not code coupled
                                   #   to any specific window-shell internals

Islet/Shelf/                      # UNTOUCHED IN FULL — ShelfCoordinator/ShelfLogic/ShelfFileStore/
                                   #   ShelfViewState have zero coupling to window mechanics by design
                                   #   (Phase 19 D-01) and need no changes for this redesign
```

## Architectural Patterns

### Pattern 1: Global-monitor drag detection, AppKit drag-destination only once already-interactive

**What:** Detect an in-flight OS drag and its approach toward the notch via `NSEvent.addGlobalMonitorForEvents` (`.leftMouseDown`/`.leftMouseDragged`/`.leftMouseUp`) plus `NSPasteboard(name: .drag).changeCount` polling — never via `NSDraggingDestination`/`registerForDraggedTypes` on the window. Only attach `.onDrop` (SwiftUI) to receive the actual payload, and only once the island state machine has already transitioned to expanded/interactive through the existing, proven `syncClickThrough()` path.

**When to use:** Any time a click-through/`ignoresMouseEvents`-toggling overlay window needs to react to an approaching OS drag before the pointer/drag has "earned" interactivity through the normal hover/click path.

**Trade-offs:** Slightly more code than a single AppKit registration (a whole new small class) — but it is a DIRECTLY PROVEN, shipped pattern (TheBoringNotch), whereas the AppKit-direct alternative has now failed twice on-device in this exact codebase with root cause still open. Given the milestone's own stated goal ("resolve the Phase 22 drag-in blocker"), proven-elsewhere beats unresolved-here.

**Example (shape, not literal file):**
```swift
// DragApproachDetector.swift — mirrors TheBoringNotch's DragDetector.swift structurally
final class DragApproachDetector {
    var onDragEntersRegion: (() -> Void)?
    var onDragExitsRegion: (() -> Void)?
    private var region: CGRect   // supplied by NotchGeometry / expandedZone math, updated on resolve
    private let dragPasteboard = NSPasteboard(name: .drag)
    // .leftMouseDown → snapshot pasteboard.changeCount, arm
    // .leftMouseDragged → if changeCount changed (real content-drag) AND mouseLocation.inside(region)
    //                     → fire onDragEntersRegion exactly once (edge-detected, mirrors pointerInZone)
    // .leftMouseUp → disarm
}
```

### Pattern 2: Coordinator-split continuation (this project's own established convention)

**What:** `NotchWindowController` has already been mid-split since Phase 16 (`DeviceCoordinator` behind `ActivityCoordinator`) — the roadmap itself anticipated Charging/NowPlaying/Shelf coordinator extractions as "planned... series." A window-shell rewrite is the natural forcing function to finish that split rather than doing it as separate future phases.

**When to use:** Any time the rewrite touches `NotchWindowController`'s 1378 lines anyway — extracting a `HoverInteractionController` (owns `pointerInZone`/`hotZone`/`expandedZone`/`syncClickThrough`/the mouseMoved monitor) as its own testable unit, separate from a slimmer `NotchWindowController` that just wires monitors → `resolve()` → `renderPresentation()`, reduces the blast radius of the ACTUAL risky part (window/hover mechanics) from the safe part (activity plumbing).

**Trade-offs:** More files, more indirection — but this project has already proven the pattern works cleanly once (Phase 16, zero product-behavior change, verified both by tests and on-device UAT) and explicitly said it intended to repeat it. Doing it now, forced by the drag fix, is lower-risk than doing it as an unplanned side effect of unrelated future phases.

### Anti-Pattern to avoid: registering the SAME drag types on both the panel AND a SwiftUI view

Islet's own 22-RESEARCH.md already flagged this ("Registering drag types on both the `NSHostingView` AND the `NotchPanel` window... pick ONE"). The redesign must actively DELETE the residual `registerForDraggedTypes([.fileURL])` + 4 stub overrides currently still sitting in `NotchPanel.swift` on disk (Phase 22-01's merged spike scaffold, confirmed present as of this research) before adding the new SwiftUI `.onDrop` — leaving both would recreate exactly the shadowing risk (Hypothesis H3) flagged above.

## De-Risking Sequencing (answers: how to rewrite without regressing 4 shipped milestones)

The 4 already-shipped, on-device-verified pillars this must not regress: **(a)** island positioning/fullscreen-hiding (Phases 1/2/9 — CGS Space, hot-zone, click-through), **(b)** activity priority arbitration (Phase 6 — `IslandResolver`/`TransientQueue`), **(c)** the shelf (Phases 19-21 — data model/view/drag-out), **(d)** licensing/trial (Phases 10-13 — entirely orthogonal to the window shell, zero touch expected).

This project's own established convention — proven twice already (Phase 6/9's fullscreen work, and explicitly cited in the v1.3 roadmap-evolution note for Phase 19-22) — is: **isolate the single highest-uncertainty integration point in its own phase, sequenced so its failure doesn't block or corrupt everything else.** Phase 22 isolated the RIGHT kind of risk (drag-in) but at the WRONG layer (it assumed the existing window shell was sound and tried to bolt drag onto it). This time, the isolation needs to happen one layer down: isolate the **shell rewrite's foundational geometry/click-through/CGS-Space behavior FIRST** (the thing every other feature depends on), prove it regression-free against the 3 shippable pillars that touch the window (a/b/c) BEFORE attempting drag-in again — because drag-in's own research already exists and is unit-tested (22-02); what's missing is a sound shell to attach it to.

**Recommended phase order:**

1. **Shell parity phase** — rebuild `NotchPanel`/the AppKit-facing slice of `NotchWindowController` to the SAME external behavior as today (position/hide/hover/click/CGS-Space/click-through), with the residual Phase-22 `NSDraggingDestination` scaffold DELETED (not carried forward) and — if the coordinator-split (Pattern 2) is taken — `HoverInteractionController` extracted. Success criterion: byte-for-byte-equivalent on-device UAT re-run of Phase 2/6/9's existing checklists (hover/click-expand, click-through, multi-Space, fullscreen hide/restore, activity priority ordering unaffected). This phase touches (a) and (b) directly — it must not touch `IslandResolver.swift`, `DeviceCoordinator.swift`, or `Islet/Shelf/` at all (they have zero window-mechanics coupling by design, so a correct rewrite is provably a no-op for them). **This is the phase to isolate — it is the actual "unproven integration point" now, not drag-in.**
2. **Drag-in via the new pattern** — add `DragApproachDetector` + the SwiftUI `.onDrop` wiring on top of the now-reproven shell, reusing 22-02's already-built-and-tested `DragDropSupport.swift`/`.dragEntered` seams verbatim. Because the pure seams already exist and are tested, this phase is materially smaller than Phase 22 was — it's wiring, not invention. This closes SHELF-01/02.
3. **Theming/visual redesign (frosted pill, slower springs, sidebar Settings)** — layered entirely inside `NotchPillView.swift`/`SettingsView.swift`; no shell dependency once (1) is done. **Can run in parallel with (2)**, or even before it, since it never touches `NotchPanel`/`NotchWindowController` internals — only the SwiftUI content the panel hosts.
4. **Onboarding flow** — a new first-launch view + a state flag gating it; touches `AppDelegate`/app-launch sequencing and Settings, not the notch shell's hover/click/drag mechanics at all. **Independent of (1)-(2), can run any time**, though sequencing it before "resume normal use" flows matters for UX polish (deciding trial/license/permissions before the user ever sees an island).
5. **Calendar full view (third view alongside Home/Tray)** — this is the one item genuinely downstream of the shell work IF it needs its own interaction affordance to switch views (e.g., a swipe or tab control inside the expanded island) — but the milestone context explicitly **defers gesture-based navigation**, so the initial calendar view can likely be a plain state/tab addition inside the existing click-driven expand/collapse model (no new window-mechanics dependency). Confirm this against whatever UI-SPEC the calendar phase produces; if it turns out to need a NEW interaction affordance beyond click/hover, that affordance should be built on TOP of the reproven shell from (1), not before it.

**Dependency summary:**
- (1) is a hard prerequisite for (2) only — not for (3)/(4)/(5).
- (3) and (4) can proceed in parallel with (1)/(2) — different files, zero shared surface.
- (5) is soft-dependent on (1) only if it needs new interaction affordances; otherwise independent.
- This means the milestone's phase ORDER does not need to be a strict single chain — (1) should go first because everything else nominally sits on top of "the shell still works," but (3)/(4) are legitimately parallelizable with (1)/(2) if the user wants throughput over strict sequencing. The one thing that must NOT happen is attempting (2) before (1) is proven — that is a re-run of exactly what just failed twice.

## Scaling / Regression-Proofing Considerations

| Concern | Mitigation |
|---------|------------|
| CGS Space re-attachment forgotten in the rewrite | Explicitly re-verify Phase 9's full on-device checklist (fullscreen-enter across all 3 trigger methods) as part of the Shell Parity phase's own UAT — do not assume "if it compiles it's fine," this fix was proven ONLY on-device originally too |
| `IslandResolver`/`TransientQueue` accidentally touched during the split | Keep them untouched literally — the Shell Parity phase's task list should have an explicit "0 diff to IslandResolver.swift/DeviceCoordinator.swift" acceptance criterion, mirroring how Phase 22-03 itself enforced "0 diff to syncClickThrough()" for the CR-01 gotcha |
| Shelf regressing during the shell rewrite | `ShelfCoordinator`/`ShelfLogic`/`ShelfFileStore` have zero window-mechanics coupling (Phase 19 D-01) — the Shell Parity phase should NOT need to touch `Islet/Shelf/` at all; if a diff shows up there, that's a signal the split boundary was drawn wrong |
| A second "root cause unknown" outcome on the NEW drag pattern | Because Pattern 1 (global monitor + SwiftUI `.onDrop`) never depends on AppKit's window-level drag-destination candidacy at all, the specific unresolved H1/H2/H3/H4 failure modes from Phase 22 categorically cannot recur in the same shape — worth stating explicitly in the phase's own risk register so a future debugging session doesn't re-litigate the same dead end |

## Anti-Patterns to Avoid (carried + new)

### Anti-Pattern 1: A second `ignoresMouseEvents`/click-through writer
Unchanged from Phase 22's own CR-01 lesson (project memory `cr01-clickthrough-or-defeat-gotcha`): any new state (drag-in-progress, view-switch-in-progress for the future calendar view, etc.) must route THROUGH `syncClickThrough()` as an additional input, never bypass it with a second direct `panel?.ignoresMouseEvents = ...` write.

### Anti-Pattern 2: Rebuilding the shell and the drag feature in the same phase
Exactly what made Phase 22 hard to diagnose — when the shell and the feature change together, an on-device failure can't tell you which layer broke. Sequencing (see above) deliberately proves the shell alone first.

### Anti-Pattern 3: Adopting DynamicNotchKit or TheBoringNotch wholesale as a dependency
Both were already correctly ruled out as base frameworks in the project's original stack research and remain ruled out here — DynamicNotchKit's transient/activatable model doesn't fit a persistent island, and TheBoringNotch is not designed to be imported as a library at all (it's an app, not a package). The correct move is **pattern reuse** (the `DragDetector` shape), not adoption.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `NotchPanel` ↔ `NotchWindowController` | Thin closures (`onDraggingEntered`-style forwarding is REMOVED; replaced by `DragApproachDetector`'s own callback closures, owned by the controller exactly like `PowerSourceMonitor`'s callback) | `NotchPanel` keeps its existing "zero business logic, everything visible is SwiftUI hosted inside it" convention — the redesign does not change this contract, only what crosses it |
| `NotchWindowController` ↔ `IslandResolver`/`TransientQueue` | Direct pure-function calls (`resolve(...)`), no protocol | Unchanged — the resolver has no knowledge of the window shell at all today and should continue to have none |
| `NotchWindowController` ↔ `ShelfCoordinator` | Direct method calls (`append`, `resyncShelfViewState()`) | Unchanged — the new `DragApproachDetector`'s payload extraction ends at "I have `[URL]`," then hands off to the exact same `DragDropSupport.fileURLs(from:)` → `ShelfFileStore.makeSessionCopy` → `ShelfCoordinator.append` chain Phase 22-02/22-03 already built and tested |
| `NotchWindowController` ↔ `CGSSpace` | Direct call at panel-creation time (`notchSpace.windows.insert(panel)`) | Unchanged — re-attach identically in the new shell |

## Sources

- **This project's own git history** (`gsd-new-project-setup` branch, commits `7571001`, `326804d`, `8fb5517`, `8af3e77`, `d1245e8`, `8dbd064`) — HIGH confidence, primary evidence for the H1-H4 hypothesis ranking; read directly via `git show`, not summarized from planning docs alone
- `.planning/phases/22-drag-in/22-RESEARCH.md`, `22-CONTEXT.md`, `22-01-SUMMARY.md`, `22-02-SUMMARY.md`, `22-03-PLAN.md`, `22-VALIDATION.md`, `22-DISCUSSION-LOG.md` — HIGH confidence, full phase history including Apple-doc citations already gathered by prior research (`developer.apple.com/documentation/appkit/nswindow/registerfordraggedtypes(_:)`, `.../nsdraggingdestination`, `.../nsdragginginfo`, `.../swiftui/view/ondrop(of:istargeted:perform:)`)
- `TheBoredTeam/boring.notch` (github.com, cloned + read directly 2026-07-11: `BoringNotchWindow.swift`, `BoringNotchSkyLightWindow.swift`, `DragDetector.swift`, `ContentView.swift`, `boringNotchApp.swift`, `sizing/matters.swift`) — HIGH confidence, primary reference implementation already credited by this project's own tech-stack research
- `MrKai77/DynamicNotchKit` (github.com, cloned + read directly 2026-07-11: `DynamicNotchPanel.swift`, `DynamicNotch.swift`) — HIGH confidence on what exists (nothing relevant to drag), confirms prior "not suited as a base" verdict
- `.planning/PROJECT.md` Key Decisions table — HIGH confidence, source for the CGS Space (Phase 9)/coordinator-split (Phase 16)/shelf-independence (Phase 19 D-01) decisions this redesign must preserve
- `.planning/STATE.md` Blockers/Concerns — HIGH confidence, the authoritative failure timeline
- Live read of `Islet/Notch/*.swift`, `Islet/Shelf/*.swift` (2026-07-11) — confirms current on-disk state, including the still-present, unwired Phase 22-01 spike scaffold in `NotchPanel.swift`

---
*Architecture research for: Islet v1.4 NotchPanel/NotchWindowController redesign*
*Researched: 2026-07-11*
