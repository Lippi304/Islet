# Phase 2: Hover, Expand & Fullscreen Hardening - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 makes the static Phase-1 pill **feel like a Dynamic Island**: a click-driven
expand/collapse with a **snappy spring morph**, a focus-safe hover affordance (haptic +
bounce), and a clean **hide for true fullscreen**. Covers **ISL-03** (open/close interaction),
**ISL-04** (spring morph), **ISL-05** (fullscreen yield).

In scope: the expand/collapse interaction model + the morph animation + a compact expanded
placeholder + fullscreen detection & hide/restore. The pill from Phase 1 (geometry, panel,
display targeting, clamshell) is reused unchanged.

**Explicitly NOT in this phase:** real activity content (now-playing, charging, devices) inside
the expanded island → Phase 3+. A user-facing settings UI (incl. the fullscreen toggle) →
Phase 6 (APP-03). Multi-display / external-monitor showing → still out of scope for v1.
</domain>

<decisions>
## Implementation Decisions

### Interaction model (ISL-03) — Alcove-style click-to-open
- **D-01:** **Hover affordance, not hover-to-open.** When the pointer enters the island's
  hot-zone, fire **trackpad haptic feedback** (`NSHapticFeedbackManager`) **+ a subtle
  bounce/scale** of the pill as a "you're in" signal. Hover alone **does NOT expand**.
- **D-02:** **Expand on CLICK only.** A click on the pill expands it with the spring morph.
  ⚠️ **This intentionally supersedes the literal ISL-03 wording "hovering the notch expands the
  island."** The chosen model is **click-to-open** (Alcove reference). Downstream planner/verifier
  must test **click-to-open + hover-haptic-bounce**, NOT hover-expand. (See `<deferred>` re:
  reconciling the ROADMAP/REQUIREMENTS wording — user chose to proceed without editing them.)
- **D-03:** **Collapse when the pointer leaves** the island, with a **~0.3–0.5s grace delay** so a
  brief rollout doesn't snap it shut.
- **D-04:** **Focus-safe is non-negotiable** (carries Phase-1 **D-07**): clicking to expand must
  **never activate Islet or steal focus** from the active app, and clicks **outside** the pill must
  still pass through. The panel stays `.nonactivatingPanel`, `canBecomeKey/Main = false`.

### Expanded state (Phase-2 placeholder)
- **D-05:** Expanded content = a **small date/time readout** as a temporary Phase-2 filler (real
  activity content arrives Phase 3+). It exists so the morph has a visible target and the panel
  doesn't look broken/empty.
- **D-06:** Expanded size = **compact** — only modestly larger than the notch, NOT a big
  Dynamic-Island panel.

### Animation (ISL-04)
- **D-07:** **Snappy & playful spring with a slight bounce** (iPhone-DI / Alcove feel — pairs with
  the hover bounce in D-01). Real **geometric form-morph** via `matchedGeometryEffect` + a shared
  `@Namespace` (corner radius + frame animate). **No cross-fade** (ISL-04).
- **D-08:** **Idle/collapsed pill stays static & invisible** (carries Phase-1 **D-01/D-03**). The
  ONLY motion in Phase 2 is the click-driven expand/collapse and the hover bounce — no idle pulsing.

### Fullscreen yield (ISL-05)
- **D-09:** In **true fullscreen** (native fullscreen, fullscreen video, QuickLook) the island
  **hides completely by default** — no ghost control bar — and **auto-restores** when fullscreen
  exits. **Regular maximized / zoomed windows do NOT count** (island stays visible).
- **D-10:** The fullscreen-hide is **gated behind a single flag** (default = hidden) so a future
  "show island in fullscreen" toggle is a one-line wire-up. The toggle's **settings UI is Phase 6
  (APP-03)** — do NOT build it here, only keep the seam.

### Claude's Discretion
- Exact hover **hot-zone** bounds (pill bounds, possibly slightly padded for easy targeting).
- **The focus-safe hover/click mechanism** — the key research item. The panel is currently
  `ignoresMouseEvents = true` *unconditionally* (Phase 1, D-07). Phase 2 must let the pill region
  receive hover + click while staying click-through elsewhere and never activating. Likely a global
  `NSEvent` mouse-move/-down monitor, or a tracking area + conditional `ignoresMouseEvents`.
- Exact spring `response`/`dampingFraction`, bounce magnitude, and the grace-delay value within
  0.3–0.5s.
- **Fullscreen detection mechanism** (e.g. active-Space/presentation-options inspection, the active
  app's fullscreen state, or `screen.frame` vs `visibleFrame` / menu-bar presence). Must interop
  cleanly with the existing `didChangeScreenParametersNotification` + clamshell logic (Phase 1
  D-04/D-05).
- Haptic feedback pattern type, and whether subtle haptics also fire on expand/collapse (not only
  hover-enter).
- Where the `isExpanded` state + date/time view live (likely an `@Published` on
  `NotchWindowController` driving `NotchPillView`).

### Folded Todos
(None — no pending todos matched this phase.)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Animation / interaction how-to (primary for Phase 2)
- `CLAUDE.md` → **"Animation approach (the Dynamic-Island feel)"** — drive expand/collapse from one
  `isExpanded` state in `withAnimation(.spring(response:dampingFraction:))`; use
  `matchedGeometryEffect` + a shared `@Namespace` so the black blob *morphs* (corner radius + frame)
  rather than cross-fades. This is D-07 verbatim.
- `CLAUDE.md` → **"What NOT to Use"** — avoid Core Animation / hand-rolled `CALayer`; SwiftUI spring
  gives the morph for free. Swift-5 language mode, macOS-14 floor still apply.

### Phase-1 carry-forward (the code Phase 2 modifies)
- `.planning/phases/01-the-empty-island-window-geometry/01-CONTEXT.md` — D-01/D-03 (idle static +
  invisible), D-04 (built-in only / clamshell hide), D-06 (custom NSPanel), **D-07 (non-activating +
  click-through foundation — Phase 2 makes click-through *conditional*)**.
- `Islet/Notch/NotchPanel.swift` — `ignoresMouseEvents = true` (must become conditional),
  `.nonactivatingPanel`, `level = .statusBar`, `collectionBehavior` (all-Spaces + fullScreenAuxiliary).
- `Islet/Notch/NotchPillView.swift` — the static fill + DEBUG tint/offset; gets the expand/collapse
  states + date/time placeholder.
- `Islet/Notch/NotchShape.swift` — the pill shape whose corner radius/frame animate in the morph.
- `Islet/Notch/NotchWindowController.swift` — owns the panel; resolve/position + screen-change
  observer; gets the `isExpanded` state, hover/click handling, and the fullscreen observer.
- `Islet/Notch/NotchGeometry.swift` — pure geometry seam; expanded-frame math extends it.
- `.planning/phases/01-the-empty-island-window-geometry/01-03-SUMMARY.md` — on-device A2 outcome
  (ships `level = .statusBar`) and A3 (clamshell) — relevant to how fullscreen-hide interacts with
  window level and the menu bar.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 2"** (goal + 4 success criteria). NOTE the ISL-03 wording
  divergence captured in D-02.
- `.planning/REQUIREMENTS.md` — **ISL-03** (open/close), **ISL-04** (spring morph), **ISL-05**
  (fullscreen hide); **APP-03** (Phase-6 settings — anchors the deferred fullscreen toggle).
- `.planning/PROJECT.md` — vision (as polished as Alcove), Key Decisions, out-of-scope.

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchWindowController.swift` — already owns the panel, resolves/positions it, and
  observes `didChangeScreenParametersNotification`. Natural home for the new `isExpanded` state,
  the hover/click handling, and a parallel **fullscreen/active-space observer**.
- `Islet/Notch/NotchPillView.swift` + `NotchShape.swift` — the SwiftUI pill + shape; extend with the
  collapsed↔expanded layouts driven by `matchedGeometryEffect` + a shared `@Namespace`.
- `Islet/Notch/NotchPanel.swift` — the non-activating panel; the `ignoresMouseEvents` flag is the
  single lever that must become conditional for click/hover without focus theft.
- `Islet/Notch/NotchGeometry.swift` — pure, unit-tested seam; add an expanded-frame computation so
  the panel can resize for the expanded state and stay testable.

### Established Patterns
- Small AppKit surface + SwiftUI content via `NSHostingView`; `@Published`/`ObservableObject` for
  state into SwiftUI; Swift-5 mode; un-sandboxed; macOS-14 floor.
- `project.yml` (XcodeGen) auto-discovers new `.swift` files under `Islet/` — `xcodegen generate`
  after adding sources; no manual project edits.
- TDD seam pattern from Phase 1: pure logic (geometry, fullscreen-detection predicate) is unit-test
  friendly; AppKit/SwiftUI wiring is verified on-device.

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` already creates + retains the controller — no change
  to ownership; the new observers/monitors are added inside the controller.
- The existing clamshell/display logic (Phase-1 D-04/D-05) and the new fullscreen-hide must
  coexist: both are "should the panel be visible right now?" inputs to the same show/hide path.
</code_context>

<specifics>
## Specific Ideas

- **Alcove reference (explicit):** moving onto the island gives a **trackpad haptic** + a **slight
  bounce** ("you're in"), and it **opens on click** — not on hover. The tactile "you're in" feel is
  the point; reproduce that, not a hover-expand.
- Snappy, playful spring with a little overshoot — the same personality as the hover bounce.
- Fullscreen: be invisible and leave **no ghost bar**; come back instantly when fullscreen exits.
</specifics>

<deferred>
## Deferred Ideas

- **"Show island in fullscreen" toggle** (user request): make the fullscreen behavior user-
  configurable, **default OFF (hidden)**. The behavior ships in Phase 2 behind a flag (D-10); the
  **settings UI is Phase 6 (APP-03)**. Keep the flag seam clean now; do not build the UI.
- **Activity content** inside the expanded island (now-playing, charging, devices) → **Phase 3+**.
  Phase 2's expanded state is a date/time placeholder only (D-05).
- **ISL-03 wording reconciliation:** ROADMAP § Phase 2 and REQUIREMENTS ISL-03 still say "hovering
  expands"; the agreed model is **click-to-open + hover haptic/bounce** (D-01/D-02). User chose to
  proceed without editing those docs. **Planner/verifier: treat click-to-open as authoritative.**
  (Offer stands to update the ROADMAP/REQUIREMENTS wording later for consistency.)

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)
</deferred>

---

*Phase: 02-hover-expand-fullscreen-hardening*
*Context gathered: 2026-06-27*
