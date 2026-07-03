# Phase 8: Fullscreen-Enter Flash Elimination - Context

**Gathered:** 2026-07-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Root-cause investigation and fix for the ~1-frame island flash that appears at the END of the native-fullscreen-enter transition. This is a v1.0 polish-debt item, not new functionality: the island already hides correctly for the duration of fullscreen and restores correctly on exit (Phase 2, ISL-05) — only the enter-transition compositor flash remains. The phase must produce either (a) a genuine root-cause elimination using a proactive detection/timing signal, distinct from the existing reactive `orderOut` approach, or (b) a documented escalation with root-cause evidence if elimination is confirmed genuinely impossible at the application layer. A partial/best-effort reduction is explicitly out of scope as a *shipped* outcome (REQUIREMENTS.md).

</domain>

<decisions>
## Implementation Decisions

### Private-API risk tolerance
- **D-01:** The researcher may use undocumented/private APIs at the **same risk tier already shipped** in this codebase — e.g. private CGS/SkyLight symbols bound via `@_silgen_name` (as `FullscreenSpaceProbe.swift` already does with `CGSCopyManagedDisplaySpaces`), or subscribing to a private distributed/CGS notification for Space-transition-start. This is consistent with the project's existing acceptance of private-API risk (MediaRemote via `mediaremote-adapter`, CGS Spaces probe) given the app ships direct+notarized, never App Store.
- **D-02:** Do NOT go further than that tier — no `dlopen`'ing arbitrary/unrelated frameworks, no patching system binaries, no other exotic techniques beyond private symbol binding / private notification subscription.

### Escalation fallback if truly unfixable
- **D-03:** If the researcher (again) confirms no proactive pre-transition signal exists at the application layer: ship **no code change**. Revert/discard any exploratory code from the investigation, leave the current v1.0 reactive `updateVisibility()` / `orderOut` behavior exactly as it is today, and produce a written root-cause escalation report.
- **D-04:** The escalation report is surfaced to the user for an explicit scope decision (accept as permanent technical debt vs. formally descope FS-01) — do NOT silently ship a "good enough" partial mitigation instead.

### On-device trigger-method coverage
- **D-05:** The on-device UAT matrix is the **minimum set** from ROADMAP.md: (1) green-button click, (2) menu bar "View > Enter Full Screen", (3) a fullscreen video app (e.g. QuickTime or Safari video fullscreen). No expansion to keyboard shortcuts, video-call apps (Zoom/Slack), Keynote presenter mode, or external-display setups for this phase.

### Investigation depth before declaring escalation
- **D-06:** This flash was already deep-dived twice with the same conclusion — Phase 2 (`02-04-SUMMARY.md`, original root-cause) and a Phase 6 debug session (`.planning/debug/resolved/fullscreen-enter-flash.md`, re-confirmation). Both concluded no proactive signal exists using public APIs, and a show-debounce was tried and reverted (there's no on-side blip to debounce).
- **D-07:** Given the private-API ceiling (D-01), the researcher **must identify and on-device test at least one concrete NEW candidate signal not already ruled out in the prior debug history** (e.g. a CGS/SkyLight distributed notification firing on Space-transition-*start*, before the compositor pass — as opposed to the existing reactive `activeSpaceDidChangeNotification`/`didActivateApplicationNotification`, which fire after). Escalation (D-03/D-04) is only valid after that new avenue has actually been tried on-device and failed — not a re-statement of the prior conclusion without new investigation.

### Claude's Discretion
- Exact private-API candidate(s) to try (e.g. which CGS/SkyLight notification name, if one exists) — this is research work, not a user decision.
- Whether to consult prior-art from reference apps (e.g. boring.notch) on how they handle this, if at all — left to the researcher's judgment per the "same tier as existing" ceiling.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Root-cause history (mandatory reading before researching)
- `.planning/debug/resolved/fullscreen-enter-flash.md` — Phase 6 re-confirmation debug session: full root-cause chain, what was ruled out (Phase 6 resolver, toggle races, collectionBehavior), why it's deferred, and the explicit hint that a proactive (non-reactive) hide signal — not another debounce — is what would be required.
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-04-SUMMARY.md` — original Phase 2 root-cause analysis, the show-debounce attempt (`cc7f3c1`) and its revert (`f706f66`).
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-RESEARCH.md` — original ISL-05 fullscreen-detection research (Q3), context for why CGS Spaces was chosen over NSScreen safe-area.
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-CONTEXT.md` — D-09 (hide completely in true fullscreen, no ghost bar) and D-10 (hide gated behind `hideInFullscreen` flag) — unchanged constraints this phase must preserve.

### Requirements & scope
- `.planning/REQUIREMENTS.md` — FS-01 requirement text and the "Out of Scope" table row explicitly excluding best-effort/partial mitigation as a shipped outcome.
- `.planning/ROADMAP.md` (Phase 8 section) — success criteria, the "Investigation note" escalation clause, dependency on Phase 2.

### Current implementation (the single show/hide arbiter to preserve)
- `Islet/Notch/NotchWindowController.swift:365-433` — `updateVisibility()`, the single show/hide arbiter; must remain the SOLE show/hide call site (Pattern 7) — do not introduce a second show/hide path.
- `Islet/Notch/NotchWindowController.swift:44` — `hideInFullscreen` (hardcoded `let true`, no live toggle — unrelated to this bug, do not wire a settings toggle here).
- `Islet/Notch/FullscreenSpaceProbe.swift` — `isBuiltinDisplayInFullscreenSpace`, the existing reactive CGS Spaces probe (`type == 4`); the reference for how private CGS symbols are already bound via `@_silgen_name` in this codebase.
- `Islet/Notch/FullscreenDetector.swift` — `shouldShow(...)` pure gate predicate; untouched since Phase 2, must stay untouched unless the fix genuinely requires a new predicate input.
- `Islet/Notch/NotchPanel.swift:32` — `collectionBehavior` (`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`) — the panel kind the compositor draws onto the activating fullscreen Space; already investigated once (removing `.fullScreenAuxiliary` didn't help).

No external specs beyond REQUIREMENTS.md/ROADMAP.md and the debug history above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FullscreenSpaceProbe.swift`'s `@_silgen_name` private-symbol-binding pattern — the template for binding any new private CGS/SkyLight symbol a proactive signal might need.
- `NotchWindowController`'s existing `NSWorkspace.shared.notificationCenter` observer registration pattern (`activeSpaceDidChangeNotification`, `didActivateApplicationNotification`) — the template for wiring up any additional observer, should a new proactive notification be found.

### Established Patterns
- Pattern 7 (single `updateVisibility()` arbiter) — every show/hide decision in the entire app funnels through one function. A proactive fix must feed its new signal INTO this same arbiter (e.g. as an additional observer that calls `updateVisibility()` earlier), not create a parallel show/hide path.
- Fail-safe-to-visible design in `FullscreenSpaceProbe.isBuiltinDisplayInFullscreenSpace` — any parse failure/ambiguity returns `false` (show, don't wrongly hide). Any new proactive signal should follow the same fail-safe philosophy (prefer a rare visible flash over wrongly hiding the island when not actually entering fullscreen).

### Integration Points
- Any new proactive signal integrates as an additional `NSWorkspace`/private-notification observer in `NotchWindowController`'s setup (near lines 239-263), calling `updateVisibility()` — mirroring the existing observer wiring exactly.

</code_context>

<specifics>
## Specific Ideas

No specific implementation approach was prescribed by the user — the technical "how" (which private notification, if any, fires before the compositor pass) is explicitly research work, bounded by the private-API risk ceiling (D-01/D-02) and the investigation-depth requirement (D-07).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. No scope creep occurred; all four discussed areas (private-API risk, escalation fallback, trigger coverage, investigation depth) directly govern how Phase 8 is investigated and delivered.

</deferred>

---

*Phase: 08-fullscreen-enter-flash-elimination*
*Context gathered: 2026-07-04*
