# Phase 1: The Empty Island (Window + Geometry) - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers a **borderless, always-on-top overlay window** that paints a **static**,
black, rounded pill **exactly over the physical notch**, on the **correct built-in display**,
and survives every screen-configuration change (plug/unplug, resolution change, clamshell).

In scope: the overlay window shell + notch geometry + correct-display logic + a static pill
that is unobtrusive when idle. Covers **ISL-01, ISL-02, ISL-06, ISL-07**.

**Explicitly NOT in this phase:** hover/expand, spring morph animation, click-through
interaction logic, fullscreen-yield, and any activity content — those are Phase 2+. The pill
here is a static render only.
</domain>

<decisions>
## Implementation Decisions

### Idle Appearance & Notch Fit (ISL-01, ISL-07)
- **D-01:** The collapsed/idle pill **exactly hugs the physical notch** — same width and same
  corner radius — so it **visually merges with the hardware notch and is effectively invisible
  when idle** (Alcove look; satisfies ISL-07 "near-invisible, not animating"). Pure black.
- **D-02:** Because an exact-hug black pill is invisible against the real notch, the build must
  render it **temporarily tinted / visibly offset DURING DEVELOPMENT** (a debug flag) so the user
  can verify position, width, and corner radius — then ship idle-invisible. This dev-visibility
  affordance is required for a first-time programmer to confirm the phase works.
- **D-03:** Idle pill is **static — no animation, no pulsing** (ISL-07).

### Display Targeting & Screen Changes (ISL-06)
- **D-04:** The island lives **only on the built-in notch display**. With an external monitor
  connected (lid open), it stays on the built-in screen. In **clamshell mode (lid closed) the
  island hides entirely** — never relocates to an external display.
- **D-05:** The window **re-evaluates and re-positions on every screen-configuration change**
  (`NSApplication.didChangeScreenParametersNotification`): external plug/unplug, resolution
  change, and lid open/close. It must recover to the correct state automatically — never get
  stuck on the wrong display or orphaned off-screen.

### Window Technique
- **D-06:** Build a **custom `NSPanel`** (borderless, non-activating, status-bar-level / above
  normal windows, all-Spaces `collectionBehavior`) hosting the SwiftUI pill via `NSHostingView`.
  **No DynamicNotchKit dependency** — per CLAUDE.md it is oriented at transient toasts, not a
  persistent always-visible compact pill. Full control, zero third-party surface.

### Phase Scope / Interactivity
- **D-07:** Phase 1 is a **static, non-interactive pill**. No hover, no expand/collapse, no
  click-through gating logic (all Phase 2). **However**, the window is built from the start as
  **non-activating + click-through**: it must **never steal focus** from the active app and must
  **never block clicks** to the menu bar / desktop around it. This is the foundation for ISL-02
  and Phase 2, not new behavior.

### Claude's Discretion
- The exact notch-geometry API (e.g. `NSScreen.safeAreaInsets` /
  `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`), and the method for approximating the notch
  **corner radius** (macOS does not expose it directly — reference apps approximate/measure).
- The `NSPanel` style mask, exact window `level`, and `collectionBehavior` flag set for
  all-Spaces + above-fullscreen-aux behavior.
- How the dev-time tint (D-02) is toggled (build flag / `#if DEBUG` / a constant).
- Where the overlay controller lives in code (e.g. a `NotchWindowController` created and
  retained by `AppDelegate.applicationDidFinishLaunching`, alongside the existing status item).
- The screen-reconfiguration observer wiring and any debounce.

### Folded Todos
(None — no pending todos matched this phase.)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Window + geometry how-to (primary for Phase 1)
- `CLAUDE.md` — specifically the sections:
  - **"The borderless notch-overlay window (the hard part, made concrete)"** — the `NSPanel`
    recipe (borderless, non-activating, `.statusBar` level, all-Spaces).
  - **"Stack Patterns by Variant"** — the rationale for a **custom `NSPanel`** over DynamicNotchKit
    for a persistent compact pill (D-06).
  - **"Animation approach"** — the pill is a `RoundedRectangle`/`Capsule` whose corner radius +
    frame match the real notch (relevant for D-01 exact-hug; animation itself is Phase 2).
  - **"What NOT to Use"** — DynamicNotchKit caveat (transient, not persistent) and the macOS-14
    floor / Swift-5-mode constraints.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 1"** (goal + 4 success criteria) and **§ "Phase 2"**
  (where hover/expand/fullscreen-yield live — keep them OUT of Phase 1).
- `.planning/REQUIREMENTS.md` — **ISL-01** (notch fit), **ISL-02** (above all windows, all Spaces),
  **ISL-06** (correct display / clamshell), **ISL-07** (unobtrusive when idle); and the
  **Out-of-Scope** row "Non-notch Macs / external-display floating pill" (anchors D-04 + the
  deferred configurability below).
- `.planning/PROJECT.md` — vision, Key Decisions, out-of-scope (notch Macs only, v1).
- `.planning/phases/00-foundations-notarization-dry-run/00-CONTEXT.md` — carried-forward
  constraints: **D-06 macOS 14.0 floor**, **Swift 5 language mode**, **un-sandboxed**, app identity
  (`com.lippi304.islet`).

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/AppDelegate.swift` — already owns the app lifecycle and the menu-bar `NSStatusItem`,
  and already sets `applicationShouldTerminateAfterLastWindowClosed → false` (the agent survives
  window closes). This is the natural home to **create and retain the overlay `NSPanel`/controller**
  in `applicationDidFinishLaunching`, parallel to the existing status item.
- `Islet/IsletApp.swift` — establishes the pattern: small AppKit surface + SwiftUI content, with a
  `Notification.Name` bridge between AppKit and SwiftUI. The pill's SwiftUI view hosted via
  `NSHostingView` follows the same "AppKit owns the window, SwiftUI fills it" split.

### Established Patterns
- Small AppKit surface, SwiftUI content (`NSHostingView`); `NSApplicationDelegateAdaptor`.
- Swift 5 language mode; un-sandboxed; macOS 14.0 deployment floor.
- `project.yml` (XcodeGen) **auto-discovers any new `.swift` file under `Islet/`** — adding the
  overlay window source(s) + `xcodegen generate` includes them; no manual project edits.

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` — where the overlay panel is built and shown.
- The status item and the existing settings `Window(id:"settings")` are independent of the overlay
  and must keep working unchanged.
</code_context>

<specifics>
## Specific Ideas

- Idle = **exact-notch-hug, pure black, invisible** (Alcove reference). The seamlessness with the
  physical notch IS the point.
- During development, make the pill **temporarily visible/tinted** (D-02) so the user can confirm
  width, height, corner radius, and that it tracks the right display — then ship invisible.
- Robust recovery is a **core success criterion, not polish**: re-position on every screen change;
  hide cleanly in clamshell; never land on the wrong display.
</specifics>

<deferred>
## Deferred Ideas

- **Configurable display behavior** (user request during discussion): a setting to also show the
  island **on external monitors** and to configure its **behavior in fullscreen**.
  - "External-display pill" is currently **out-of-scope for v1** in REQUIREMENTS (it doubles the
    hardest part before the core works).
  - Fullscreen-yield behavior is **Phase 2** (ISL-05).
  - Making either user-configurable would be a **Phase 6** Settings extension (APP-03).
  - **Forward note for the planner:** keep the display-selection logic open enough that a future
    "also show on external monitor" option is not architecturally blocked — but do **not** build it
    in Phase 1.
- **Hover, spring-morph expand/collapse, click-through gating, fullscreen-yield** → Phase 2.

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)
</deferred>

---

*Phase: 01-the-empty-island-window-geometry*
*Context gathered: 2026-06-26*
