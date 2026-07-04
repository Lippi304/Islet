# Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry - Context

**Gathered:** 2026-07-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Retry FS-01 (still open after Phase 8's escalation) with a structural window/Space
architecture change: **Candidate C** replaces the panel's `.canJoinAllSpaces`
`NSWindow` collection behavior with a dedicated private CGS Space created at the
maximum absolute level (`CGSSpaceCreate` + `CGSSpaceSetAbsoluteLevel(level:
Int32.max)`, membership managed via `CGSAddWindowsToSpaces`/
`CGSRemoveWindowsFromSpaces`), mirroring the technique found in
`Ebullioscopic/Atoll`'s `NotchSpaceManager`/`CGSSpace.swift`. **Candidate B**
(`SLSManagedDisplayIsAnimating` poll + fullscreen-vs-ordinary-Space-switch
disambiguator, full design in `08-ESCALATION.md`) is the documented fallback if C
doesn't close the gap. This is a v1.0.1 polish-debt retry, not new functionality —
the island already hides/restores correctly around fullscreen (Phase 2, ISL-05);
only the enter-transition compositor flash remains. Per REQUIREMENTS.md, the
phase must produce either (a) genuine root-cause elimination or (b) a documented
escalation — a partial/best-effort reduction is not a valid shipped outcome.

</domain>

<decisions>
## Implementation Decisions

### Private-API risk tolerance for Candidate C
- **D-01:** Creating/managing a dedicated CGS Space (`CGSSpaceCreate`,
  `CGSSpaceSetAbsoluteLevel`, `CGSAddWindowsToSpaces`,
  `CGSRemoveWindowsFromSpaces`) is in the **same accepted risk tier** as the
  project's existing private-API usage (MediaRemote adapter,
  `CGSCopyManagedDisplaySpaces` in `FullscreenSpaceProbe.swift`) — same
  `@_silgen_name` symbol-binding technique, just more call surface. No
  additional pre-approval gate is needed before writing code.
- **D-02:** The ceiling is **exactly those 4 CGS functions**. If research finds
  Candidate C needs additional private mechanisms beyond them (extra Space
  attributes, a private Space-ownership flag, etc.), that is a stop signal —
  fall back to Candidate B or escalate. Do not keep expanding the private-API
  surface to make Candidate C work.
  - **Amendment (2026-07-04, post-research re-adjudication):** 09-RESEARCH.md
    found the only two known shipping reference implementations
    (`Ebullioscopic/Atoll`, `TheBoredTeam/boring.notch`) require 7 private
    symbols, not 4: `CGSSpaceCreate`, `CGSSpaceSetAbsoluteLevel`,
    `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces` (the original 4) plus
    `CGSSpaceDestroy`, `CGSHideSpaces`, `CGSShowSpaces`, and a separate
    connection-lookup symbol (`_CGSDefaultConnection`, kept independent from
    the existing `CGSMainConnectionID` binding in `FullscreenSpaceProbe.swift`
    per the research's Pitfall 2 ABI-mismatch warning). User re-adjudicated
    and **raised the ceiling to this full 7-symbol set** — it is the only
    combination with real shipping precedent, and `CGSShowSpaces`/`CGSHideSpaces`
    are load-bearing (a Space that's never shown may not composite; skipping
    teardown risks a leaked system Space resource). The ceiling is now **these
    7 named functions plus the connection lookup — not open-ended** expansion;
    any further private mechanism beyond this set still triggers the original
    D-02 stop signal.

### Regression safety net for the architecture change
- **D-03:** `NotchPanel.collectionBehavior` is core plumbing touched by nearly
  every existing phase. Before accepting Candidate C, the **full core-behavior
  suite** must be re-verified on-device: hover/click-expand without focus
  steal, click-through outside the pill, visibility across all Spaces (not
  just one), correct positioning through clamshell/external-display changes,
  and continued correct hide-during-fullscreen/restore-on-exit. Treat this as
  a targeted re-run of the existing Phase 1/2 UAT points, scoped to the new
  Space architecture.
- **D-04:** Any regression found during that suite — however small (e.g.
  click-through working only most of the time, a one-frame-late reposition
  after a display change) — is a **show-stopper**, not a "fix later" item.
  Candidate C is not accepted with known regressions on this component; fix
  before acceptance, don't defer as follow-up debt.

### Escalation path if Candidate C and Candidate B both fail
- **D-05:** If neither Candidate C nor Candidate B closes the flash (or either
  causes an unfixable regression), this is the **final investigation round**.
  FS-01 has now been root-caused across Phase 2, Phase 6, Phase 8, and Phase 9,
  with four distinct candidate approaches attempted. The resulting escalation
  report is limited to two options: accept as permanent technical debt, or
  formally descope FS-01 from REQUIREMENTS.md. No further "investigate a new
  candidate" loop.
- **D-06:** If Candidate C fails on-device (flash persists, or an unfixable
  regression per D-04), the plan **automatically proceeds to Candidate B** in
  the same phase — no separate user checkpoint/decision gate is needed before
  attempting B. ROADMAP.md already locks B as the designated fallback; C's
  failure is itself the trigger.

### On-device trigger-matrix scope
- **D-07:** In addition to Phase 8's 3-method fullscreen trigger matrix
  (green-button click, menu-bar "Enter Full Screen", a fullscreen video app),
  this phase adds an **ordinary (non-fullscreen) Space switch** (trackpad
  swipe / Mission Control) as a regression check — because Candidate C changes
  the panel's fundamental Space membership, not just adding a new detection
  signal. This is the concrete on-device scenario that exercises the D-03 full
  core-behavior suite's "visibility across all Spaces" and "correct
  positioning" checks.

### Claude's Discretion
- Exact implementation shape of the CGS Space wrapper (how membership is
  synced on show/hide, whether it's a new file mirroring
  `FullscreenSpaceProbe.swift`'s pattern or added to `NotchPanel.swift`) — research/planning work.
- Whether an external-display trigger scenario is worth adding to the D-07
  matrix beyond the ordinary Space-switch check — left to the planner's
  judgment based on what Candidate C's actual Space-management design implies
  for multi-display setups.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Root-cause history and escalation (mandatory reading before researching)
- `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` —
  full root-cause chain across Phase 2/6/8, the ruled-out `CGSClientEnterFullscreen`/
  `CGSClientExitFullscreen` (106/107) candidate, and the untried Candidate B
  (`SLSManagedDisplayIsAnimating`) design this phase falls back to.
- `.planning/phases/08-fullscreen-enter-flash-elimination/08-CONTEXT.md` — Phase
  8's D-01/D-02 (private-API risk ceiling precedent), D-03/D-04
  (elimination-only, no partial mitigation), D-05 (3-method trigger matrix this
  phase extends).
- `.planning/debug/resolved/fullscreen-enter-flash.md` — Phase 6
  re-confirmation debug session.
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-04-SUMMARY.md` —
  original Phase 2 root-cause analysis and the reverted show-debounce attempt.
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-CONTEXT.md` — D-09
  (hide completely in true fullscreen) and D-10 (hide gated behind
  `hideInFullscreen`) — unchanged constraints this phase must preserve.

### Requirements & scope
- `.planning/REQUIREMENTS.md` — FS-01 requirement text and the "Out of Scope"
  row excluding best-effort/partial mitigation as a shipped outcome.
- `.planning/ROADMAP.md` (Phase 9 section) — success criteria, Candidate
  C/B definitions and priority order.

### Current implementation (the plumbing Candidate C replaces / must preserve)
- `Islet/Notch/NotchPanel.swift:32` — `collectionBehavior` (`.canJoinAllSpaces`,
  `.fullScreenAuxiliary`, `.stationary`) — the exact line Candidate C replaces.
- `Islet/Notch/NotchPanel.swift:34-36` — `canBecomeKey`/`canBecomeMain` both
  `false` — the focus-safety invariant (D-04, Phase 2) that must not regress.
- `Islet/Notch/NotchWindowController.swift:414-441` — `updateVisibility()`, the
  single show/hide arbiter (Pattern 7); must remain the SOLE show/hide call
  site — Candidate C's Space membership changes integrate through this, not a
  parallel path.
- `Islet/Notch/NotchWindowController.swift:44` — `hideInFullscreen` (hardcoded
  `let true`) — unrelated to this bug, do not touch.
- `Islet/Notch/FullscreenSpaceProbe.swift` — `isBuiltinDisplayInFullscreenSpace`,
  the existing `@_silgen_name` private-symbol-binding pattern to mirror for the
  4 new CGS Space functions (D-01/D-02).
- `Islet/Notch/NotchWindowController.swift:556-559` — `syncClickThrough()`, the
  single place `ignoresMouseEvents` is toggled — part of the D-03 regression
  suite (click-through outside the pill).

No external specs beyond REQUIREMENTS.md/ROADMAP.md and the Phase 2/6/8 history
above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FullscreenSpaceProbe.swift`'s `@_silgen_name` private-symbol-binding pattern
  — the template for binding `CGSSpaceCreate`, `CGSSpaceSetAbsoluteLevel`,
  `CGSAddWindowsToSpaces`, `CGSRemoveWindowsFromSpaces`.
- `NotchWindowController`'s existing `NSWorkspace.shared.notificationCenter`
  observer pattern — reference for how any Space-membership sync hooks into
  the show/hide lifecycle without creating a second arbiter.

### Established Patterns
- Pattern 7 (single `updateVisibility()` arbiter, `NotchWindowController.swift:414`)
  — every show/hide decision funnels through one function; Candidate C's
  Space-join/leave calls must happen inside this same call site's
  `positionAndShow`/`orderOut` branches, not a separate path.
- Fail-safe-to-visible design in `FullscreenSpaceProbe.isBuiltinDisplayInFullscreenSpace`
  — any parse failure/ambiguity returns `false` (show, don't wrongly hide).
  Candidate C's Space-membership logic should follow the same philosophy.
- D-04 focus-safety invariant (`NotchPanel.swift:34-36`,
  `.nonactivatingPanel` + never-key/never-main) — Candidate C changes Space
  membership, not activation behavior; this invariant must be independently
  re-verified, not assumed unaffected.

### Integration Points
- `Islet/Notch/NotchPanel.swift:32` — where `.canJoinAllSpaces` is removed and
  the new max-level CGS Space is created/assigned instead.
- `Islet/Notch/NotchWindowController.swift` `positionAndShow`/`updateVisibility`
  (lines ~414-485) — where Space add/remove calls are wired in alongside the
  existing `orderFrontRegardless()`/`orderOut(nil)` calls.

</code_context>

<specifics>
## Specific Ideas

The window/Space architecture direction (Candidate C) itself was not invented
in this discussion — it's a specific technique the user found by researching
comparable open-source projects on GitHub (`Ebullioscopic/Atoll`'s
`NotchSpaceManager`/`CGSSpace.swift`) between Phase 8 and Phase 9, and is
already locked into ROADMAP.md as the prioritized approach. This discussion
focused on the risk ceiling, regression bar, and escalation shape around
executing that already-chosen direction.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. No scope creep occurred; all four
discussed areas (private-API risk ceiling, regression safety net, escalation
path, trigger-matrix scope) directly govern how Phase 9 investigates and
delivers the already-locked Candidate C/B retry.

</deferred>

---

*Phase: 09-fullscreen-flash-window-space-retry*
*Context gathered: 2026-07-04*
