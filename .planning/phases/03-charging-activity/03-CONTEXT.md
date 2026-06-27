# Phase 3: Charging Activity - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 ships the **first real live activity**: plugging in or unplugging the power
cable produces a **transient charging / on-battery splash** in the island that auto-collapses
after a few seconds. It proves the full **activity → island rendering loop** end-to-end on the
**safest, public API** (IOKit power sources — no private framework). Covers **CHG-01** (charging
animation + battery %) and **CHG-02** (brief "on battery" on unplug).

**In scope:** the charging/on-battery splash visual, its appear/collapse animation, the
power-event source that drives it, and how it coexists with the Phase-2 user interaction.

**Explicitly NOT in this phase:**
- Now-Playing / device activities → Phases 4 / 5.
- The **general multi-activity priority resolver** (charging + media + device coexistence) →
  **Phase 6 (COORD-01)**. Phase 3 only handles charging-vs-user-interaction.
- Time-to-full / adapter wattage in the splash → deferred (v2).
- A click-to-open battery detail panel → not v1 (click is informational, D-10).
- Low-battery warning / battery HUD → out of scope (HUDs are a later milestone).
- Settings to toggle the charging activity on/off → Phase 6 (APP-03).
</domain>

<decisions>
## Implementation Decisions

### Presentation form & layout (CHG-01)
- **D-01:** **Wings / Alcove layout.** The charging activity renders **beside the physical
  notch** — content flanks the camera bridge **left + right** — NOT as the Phase-2 downward
  morph. The pill grows **wider and stays flat**. This is a **new layout/geometry direction**
  and it **sets the skeleton for Phase 4** (Now Playing: album art left, controls/title right).
- **D-02:** **Programmatic, transient presentation.** The splash appears **by itself** on the
  plug/unplug event — independent of the Phase-2 click-to-expand (Phase-2 D-02). It is a **new
  presentation type ("activity")** alongside the user-driven hover/expand. (The exact mechanism
  for how this relates to the `InteractionPhase` state machine is Claude's discretion — see
  code_context / Claude's Discretion.)

### Visual & states (CHG-01, CHG-02)
- **D-03:** **Right side = a filling battery glyph + numeric %.** A battery icon that fills to
  match the current level, with the percentage number alongside.
- **D-04:** **One consistent battery glyph encodes the state**, switching between: **bolt =
  actively charging** → **full / green at 100%** → **plain battery (no bolt) on unplug ("on
  battery")**. A single glyph that changes — **not** three separate per-state mini-scenes. This
  is how the splash satisfies "distinguish actively-charging from plugged-in-but-full" and
  CHG-02's "on battery".
- **D-05:** **Charging/status symbol on the left** of the notch as the **starting layout**
  (status symbol left, battery + % right). Exact wing placement / sizing is Claude's discretion
  + on-device tuning.
- **D-06:** **Info shown = percentage only.** **No** time-to-full, **no** adapter wattage in v1
  (→ deferred / v2).

### Animation (CHG-01)
- **D-07:** **Lively appearance** — the wings **slide out** sideways from the notch, the battery
  **fills once**, with a **brief glow/pulse** at the bolt (Alcove feel). Exact springs/durations
  are on-device tuning, but start from the **Phase-2 spring vocabulary** (response ≈ 0.35,
  dampingFraction ≈ 0.65).
- **D-08:** **One-shot appear + one-shot collapse — no looping/pulsing while the splash is
  standing.** Carries Phase-1 D-08 (idle-static) and the Phase-3 success criterion (idle CPU
  ~0%). The only motion is the entrance, the optional one-time fill/glow, and the exit.

### Timing & interaction (CHG-01)
- **D-09:** **Auto-dismiss after ~3 seconds**, then collapse. Implemented as a **single
  scheduled collapse** (a `DispatchWorkItem`, mirroring the existing `graceWorkItem`), **not** a
  recurring timer — keeps the no-polling / idle-CPU guarantee.
- **D-10:** **Hover pauses the auto-dismiss**; once the pointer leaves, the ~3s (grace) resumes.
  **Click is informational only** — it does **not** trigger a special expansion or a detail
  panel in v1.
- **D-11:** **Charging splash takes brief precedence** if the user has the island open
  (user-expanded) when they plug in — the user just physically plugged in, so the island shows
  that feedback, then returns to the ambient state. (NB: the general multi-activity resolver is
  Phase 6 / COORD-01; this is only charging-vs-user-interaction.)

### Locked by ROADMAP success criteria (not negotiated here)
- **Event-driven** via `IOPSNotificationCreateRunLoopSource` (the live plug/unplug hook); **no
  long-lived polling timer**; idle CPU ~0%.
- **Distinguishes** actively-charging from plugged-in-but-full (D-04 carries this visually) and
  behaves **sanely on a Mac with no readable charging state** (e.g. desktop / no battery →
  graceful no-op, no splash / no crash).
- **Hidden in true fullscreen** — Phase-2 **D-09** still applies; the splash must **not** pop up
  while a fullscreen app owns the notch region. Route visibility through the single
  `updateVisibility()` path so it inherits the fullscreen + clamshell hide.

### Claude's Discretion
- **The "activity" abstraction / mechanism** — how a programmatic transient state lives alongside
  the `InteractionPhase` state machine (a new activity case/state vs a separate `@Published`
  activity model on the controller). **Recommendation: charging-specific with a clean seam, NOT a
  general resolver** (that is Phase 6). No speculative abstraction (per CLAUDE.md).
- **IOKit wiring** — `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList`, `kIOPSIsChargingKey`
  / `kIOPSCurrentCapacityKey` / `kIOPSMaxCapacityKey`, `IOPSCopyExternalPowerAdapterDetails`,
  run-loop-source setup, and hopping the callback to the main thread (research/planner).
- **Exact wings geometry** (per-side width, gap to the camera bridge, how the panel frame spans
  across the notch), exact SF Symbols, and colors (e.g. green at full).
- **Spring/duration tuning**, glow intensity, and whether 100% shows a subtle checkmark.
- **A pure-logic seam** (TDD like Phase 1/2): e.g. a pure function mapping power-state →
  activity-presentation (`charging` / `full` / `onBattery` + `%`), unit-testable, with the
  IOKit/AppKit wiring verified on-device.

### Folded Todos
(None — no pending todos matched this phase.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Power / charging (primary for Phase 3)
- `CLAUDE.md` → **"Power / charging detection"** — the API map: quick plug check via
  `IOPSCopyExternalPowerAdapterDetails()`; full state via `IOPSCopyPowerSourcesInfo()` +
  `IOPSCopyPowerSourcesList()` reading `kIOPSIsChargingKey` / `kIOPSCurrentCapacityKey` /
  `kIOPSMaxCapacityKey`; **live updates via `IOPSNotificationCreateRunLoopSource`** (the
  event hook the splash is built on — satisfies the no-polling criterion). This is D-04/D-09 verbatim.
- `CLAUDE.md` → **Apple frameworks table** — IOKit (IOPowerSources / IOPSKeys), HIGH confidence.

### Animation / interaction (carry-forward feel)
- `CLAUDE.md` → **"Animation approach (the Dynamic-Island feel)"** — spring +
  `matchedGeometryEffect` vocabulary (D-07 reuses the Phase-2 spring seeds).

### Phase-2 carry-forward (the code Phase 3 modifies + the decisions it inherits)
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-CONTEXT.md` — **D-02** (click-to-open;
  charging is programmatic, runs *alongside* it), **D-05/D-06** (the date/time expanded
  placeholder — Phase 3 adds the first real activity content), **D-08** (idle-static), **D-09/D-10**
  (fullscreen hide + single gating flag — the splash inherits this).
- `Islet/Notch/NotchWindowController.swift` — owns the panel, the **single `updateVisibility()`
  show/hide site**, the **`graceWorkItem` one-shot collapse** (template for the ~3s auto-dismiss),
  the fullscreen-hide gating, and the screen-change/space observers. The IOPS run-loop-source
  observer + the activity state plug in here.
- `Islet/Notch/NotchPillView.swift` — the SwiftUI pill + `matchedGeometryEffect` morph; extend
  with the **wings/charging layout**. NOTE: the current expanded morph grows **downward** (the
  date/time blob); wings grow **sideways** — a new layout branch.
- `Islet/Notch/NotchInteractionState.swift` — the `InteractionPhase` state machine (collapsed /
  hovering / expanded). The charging activity is a new presentation dimension that relates to /
  extends this (mechanism = discretion).
- `Islet/Notch/NotchGeometry.swift` — the pure, unit-tested geometry seam; **wings-frame math
  extends it** (keep it testable per the Phase-1/2 TDD seam).
- `Islet/Notch/NotchShape.swift` — the pill shape; the wings layout may reuse/extend it.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 3: Charging Activity"** (goal + 4 success criteria).
- `.planning/REQUIREMENTS.md` — **CHG-01** (charging animation + %), **CHG-02** (on-battery on
  unplug); **COORD-01** (Phase-6 resolver — anchors the deferred multi-activity coexistence).
- `.planning/PROJECT.md` — vision (as polished as Alcove), Key Decisions, out-of-scope.

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`NotchWindowController.swift`** — owns the panel; the **single `updateVisibility()`** decides
  show/hide (clamshell + fullscreen already converge there → the charging splash must route
  through it to inherit the fullscreen-hide). The **`graceWorkItem` one-shot `DispatchWorkItem`
  collapse** is the exact template for the ~3s auto-dismiss (D-09). Natural home for the IOPS
  run-loop-source observer and the activity state.
- **`NotchInteractionState.swift` / `InteractionPhase`** — the user-interaction state machine; the
  charging activity is a NEW presentation type. Decide whether to add an activity case/parallel
  `@Published` vs a separate model (discretion; keep it charging-specific, no general resolver).
- **`NotchPillView.swift` + `NotchShape.swift`** — the SwiftUI pill + `matchedGeometryEffect`
  morph. The wings/charging layout is a **new sideways layout branch** (the existing expanded
  state grows downward).
- **`NotchGeometry.swift`** — pure, unit-tested seam; add wings-frame math + a pure
  power-state→presentation mapping so the most logic-heavy parts stay testable.

### Established Patterns
- Small AppKit surface + SwiftUI via `NSHostingView`; `@Published` / `ObservableObject` for state
  into SwiftUI; **Swift-5 language mode**; un-sandboxed; **macOS-14 floor**.
- `project.yml` (XcodeGen) auto-discovers new `.swift` files under `Islet/` — run
  `xcodegen generate` after adding sources; no manual `.xcodeproj` edits.
- **TDD seam** (Phase 1/2): pure logic (geometry, the power-state→presentation predicate) is
  unit-tested; the IOKit + AppKit/SwiftUI wiring is verified on-device.
- **One-shot `DispatchWorkItem` collapse** (`graceWorkItem`) — reuse this for the auto-dismiss; do
  NOT introduce a repeating timer (no-polling criterion).
- **Single `updateVisibility()`** is the sole show/hide site — keep the charging visibility going
  through it so fullscreen + clamshell hide for free (Pitfall: a second show/hide site races them).

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` creates + retains the controller — no ownership
  change; the IOPS observer is added inside the controller's `start()`.
- The power-event run-loop-source callback must **hop to the main thread** before touching
  `@Published` / AppKit.
- The fullscreen-hide (Phase-2 D-09) and the splash must coexist: the splash must not appear in
  fullscreen → gate through `updateVisibility()`.

</code_context>

<specifics>
## Specific Ideas

- **Alcove reference (explicit):** the charging splash **flanks the notch** (wings) — a status
  symbol on one side, a **filling battery + %** on the other — with a **brief glow/pulse** on the
  bolt, then **collapses after ~3s**. The point is the "you just plugged in, here's instant
  feedback" moment.
- **One consistent battery glyph** encodes all three states (bolt = charging, full/green = 100%,
  plain = on battery) — not three separate animated scenes.
- The wings extend **sideways** from the notch — different from the Phase-2 **downward** expand —
  and this is the **same skeleton Phase 4 Now Playing will reuse** (art left, controls right).

</specifics>

<deferred>
## Deferred Ideas

- **Time-to-full / adapter wattage** in the splash → v2 / later (D-06).
- **Click-to-open battery detail panel** (more battery info on click) → not v1; click stays
  informational (D-10).
- **General multi-activity priority resolver** (charging + media + device coexistence) →
  **Phase 6 (COORD-01)**. Phase 3 handles only charging-vs-user-interaction (D-11).
- **Per-state mini-scenes** (more expressive, separate animations per state) → dropped in favor
  of the single consistent glyph (D-04); could revisit later.
- **Low-battery warning / battery HUD** → out of scope (HUDs are a later milestone; a battery HUD
  isn't even in the v2 HUD list).
- **Settings toggle** to enable/disable the charging activity + accent/theme → Phase 6 (APP-03).

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)

</deferred>

---

*Phase: 03-charging-activity*
*Context gathered: 2026-06-27*
