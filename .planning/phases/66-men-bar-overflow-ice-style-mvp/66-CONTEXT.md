# Phase 66: Menübar-Overflow (Debug-the-CGS-Spike MVP) - Context

**Gathered:** 2026-07-28 (third revision — supersedes the second revision below after Plan 66-05's on-device NO-GO disproved its central premise)
**Status:** PAUSED by user — no active plan, feature still wanted for a future milestone

<domain>
## Phase Boundary

A chevron icon in the menu bar separates a "visible" section from a "hidden" section of OTHER apps' menu-bar icons. The user Cmd-drags an icon across the chevron to move it into the hidden section; clicking the chevron reveals or hides that section. Icons stay in the menu bar itself — they never move into the notch/island.

**Third consecutive NO-GO (2026-07-28, Plan 66-05):** The on-device checkpoint failed at Step 1 — before Islet's own restored/gated CGS mechanism was ever reached. The live comparison reference itself, real currently-installed Ice.app, no longer hides/reveals a menu-bar icon via Cmd-drag on this machine. This directly disproves the second revision's central premise below ("the user confirmed real Ice ... currently works on this exact machine"). Root cause remains **unknown**: neither the permission-gate hypothesis nor the launch-context hypothesis was tested (Step 1 failed before either could be exercised), and a third possibility — the private-CGS menu-bar-item mechanism class no longer functioning on this macOS version for *any* app — was never independently confirmed either. Full detail: `66-05-SUMMARY.md`.

**Diagnosis considered and rejected (this discussion, 2026-07-28):** The user's own hypothesis (macOS 27 "Golden Gate" update and/or this machine's Developer Mode setting) could in principle be tested by disabling Developer Mode and re-testing Ice — but on this machine that requires a full downgrade back to macOS 26, which the user judged disproportionate to the value of one diagnostic data point. **Declined.** The hypothesis stays unconfirmed and is not being pursued further.

**Decision: PAUSE, not descope/drop.** The user still wants this feature — Cmd-drag menu-bar overflow hiding remains valuable — but does not want to keep sinking further attempts into it right now, after three consecutive NO-GOs across two structurally different mechanisms (private CGS, public spacer) plus an unconfirmed and expensive-to-test root cause for the third. **No revisit trigger** — this is an open-ended pause, not conditional on "macOS 27 going stable" or any other event. Revisit whenever there's appetite, via a fresh `/gsd-discuss-phase 66`.

**Second mechanism pivot (2026-07-28, now moot):** Plan 66-04's on-device UAT returned a second consecutive NO-GO on the pivoted public-`NSStatusItem`-spacer technique (Hidden Bar's mechanism, built in 66-02): the chevron's click handler and glyph-swap work, but Cmd-drag does not engage with the spacer at all, and the spacer's `.length` toggle produces zero observable reclaim/hide effect on real menu-bar layout. Full findings: `66-04-SUMMARY.md`.

**Requirements (locked via REQUIREMENTS.md, unchanged in wording — status now PAUSED not dropped):**
- **MENUBAR-01:** A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons.
- **MENUBAR-02:** The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section.
- **MENUBAR-03:** Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden — real space reclaimed.
- **MENUBAR-04:** Accessibility permission requirement — still open per the second revision, now moot until this phase resumes.

**Explicitly out of scope (locked in PROJECT.md's v1.10 milestone scope, not re-discussed here):** One hide tier only — no "always-hidden"/hotkey tier, no menu-bar theming, no hotkeys (unlike full Ice or full Hidden Bar, both of which have these extras).

</domain>

<decisions>
## Implementation Decisions

### Status (2026-07-28, third revision — supersedes D-07)
- **D-08 (NEW):** Phase 66 is **PAUSED**, not descoped/dropped. Plans 66-06/66-07/66-08 do not proceed. No further diagnostic or implementation work is planned for v1.10. The chevron-UI/glyph-swap code from Plan 66-02 (confirmed working in 66-04's UAT) and the restored, Accessibility-gated CGS spike from Plan 66-05 are left in place as reusable historical artifacts, not active code paths.
- Diagnosing the Golden-Gate/Developer-Mode hypothesis was explicitly considered and rejected — it would require a full macOS 26 downgrade on the user's real machine, disproportionate to one diagnostic data point.
- No revisit trigger set. This is an open-ended pause; resume via a fresh `/gsd-discuss-phase 66` whenever there's appetite, with no precondition.

### Mechanism history (D-01 through D-07 — kept for history, now moot until resumed)
- **D-07 (superseded by D-08):** Debug Plan 66-01's private-CGS spike against real, currently-running Ice as a live reference. **Invalidated 2026-07-28** — the live reference itself stopped working; there is currently no known-working example of this mechanism class on this hardware to debug against.
- **D-06 (superseded by D-07 in the second revision):** Build the hide/reveal mechanism using the spacer-`NSStatusItem` technique (Hidden Bar reference, public API only) — NO-GO'd on-device in Plan 66-04.
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items. *(moot until resumed, but still the intended design)*
- **D-02:** The feature activates automatically on app launch — no separate Settings toggle for the mechanism itself. *(moot until resumed)*
- **D-03:** The hidden/visible icon assignment persists across app relaunch. *(moot until resumed)*
- **D-05:** Clicking the chevron reveals hidden icons inline in the menu bar itself, not in a separate dropdown/popover. *(moot until resumed — this part was confirmed working in 66-04's UAT independent of the underlying hide mechanism)*

### Claude's Discretion (moot until resumed, kept for whenever this restarts)
- Whether to restore/repurpose the existing `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` files, or start fresh with lessons learned.
- Whether Islet's own status item(s) can also be dragged behind the chevron, or are exempt — default assumption remains **exempt**.
- Exact persistence storage mechanism/format for D-03.
- Chevron icon glyph/SF Symbol choice and reveal/hide animation style.

### Folded Todos
None — no todos matched this phase's scope (re-checked in the second revision; still holds).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing — i.e., whenever this phase is resumed.**

### This phase's own history (read first — explains all three pivots and the pause)
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-01-SUMMARY.md` — original private-CGS NO-GO, three on-device diagnostic rounds, one CGS symbol redeclaration collision (later exonerated).
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-04-SUMMARY.md` — second NO-GO (public spacer technique).
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-05-SUMMARY.md` — third NO-GO: the live Ice.app reference itself is broken on this machine, root cause unknown. This is the most important read for whoever resumes this phase — it's the reason the pause happened.
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-RESEARCH.md` — original Ice-mechanism research; Pitfall 3 (version fragility) and Pitfall 1 (relaunch persistence) sections most relevant.
- Project memory `phase66_menubar_overflow_second_nogo` — full history across all three NO-GOs and this pause decision.

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 66: Menübar-Overflow (Debug-the-CGS-Spike MVP)" — goal, success criteria, requirements, PAUSED status.
- `.planning/REQUIREMENTS.md` — MENUBAR-01/02/03/04 wording; still `- [ ]` Pending, not Dropped — this phase is paused, not abandoned.
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.10" — MVP scope bound.

### Superseded reference (kept for context, do not re-implement as-is)
- Hidden Bar (open-source, MIT-licensed) — github.com/dwarvesf/hidden — the spacer-`NSStatusItem` technique; confirmed NO-GO in 66-04.
- Real Ice.app / Ice's own source (`MenuBarItemManager.swift`/`Bridging.swift`) — was the live debugging reference for D-07; no longer usable as a working comparison target as of 66-05.

### Prior phase precedent
- `.planning/ROADMAP.md` Phase 49/50 — precedent for how a PAUSED (not dropped) phase is represented in ROADMAP.md/STATE.md; this phase's pause follows the same convention.

### Codebase (exact integration points, unchanged, verified by reading the live file)
- `Islet/AppDelegate.swift:107` (`statusItem = NSStatusBar.system.statusItem(...)`) — existing pattern for creating a status item.
- `Islet/Notch/MenuBarOverflowBridging.swift`, `IsletTests/MenuBarOverflowManualSpike.swift` — restored, Accessibility-gated CGS spike from Plan 66-05 (commit `7e8fadd`); left in place as a historical artifact.
- `Islet/Notch/MenuBarOverflowController.swift` (from Plan 66-02) — spacer-technique implementation; chevron-UI/glyph-swap logic confirmed working in 66-04's UAT independent of the underlying mechanism, likely reusable if this phase resumes.

No other external specs — requirements fully captured above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NSStatusBar.system.statusItem(withLength:)` construction pattern (`AppDelegate.swift:107`).
- Chevron click-handler and glyph-swap logic from Plan 66-02 (`chevron.left`/`chevron.right` toggle) — confirmed working in 66-04's on-device UAT even though the underlying spacer mechanism failed.
- Restored, Accessibility-gated CGS spike from Plan 66-05 (`MenuBarOverflowBridging.swift`, commit `7e8fadd`) — build-clean, but its live comparison reference (Ice.app) is currently non-functional, so its own correctness was never actually verified on-device.

### Established Patterns
- Menu-bar-only features stay out of `IslandResolver` entirely (reaffirmed by D-02).
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `MicMuteController`, `MeetingMonitor` precedent) — especially relevant given the mechanism sits on an undocumented private CGS surface.

### Integration Points
- Debugging target (whenever resumed): `Islet/Notch/MenuBarOverflowBridging.swift` vs. a working live reference — note that "real Ice.app" can no longer serve as that reference as of this pause; a fresh reference (or a fresh diagnostic approach) will be needed.
- Persistence store for hidden-icon assignment (D-03) — mechanism/format still an open research question, unresolved.

</code_context>

<specifics>
## Specific Ideas

The user still wants this feature — it's not being dropped, just paused. The blocker isn't lack of interest or a wrong implementation choice; it's that even the reference implementation (real Ice.app) stopped working on this exact machine, and the leading hypothesis for why (macOS 27 "Golden Gate" / Developer Mode) can't be cheaply tested — it would require a full OS downgrade. No screenshot/mockup was supplied; the existing chevron UI/glyph-swap from Plan 66-02 is already validated on-device and can likely be kept as-is whenever this resumes.

</specifics>

<deferred>
## Deferred Ideas

- **Menü-Bar-Overflow itself** — paused indefinitely, not dropped. Resume via a fresh `/gsd-discuss-phase 66` whenever there's appetite — no specific trigger (not "when macOS 27 is stable", not "when Developer Mode can be tested cheaply" — just unscheduled).
- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md); moot while paused, still out of scope if resumed.
- **Hiding Islet's own status item(s) behind the chevron** — not decided; default assumption is that Islet's own icon(s) stay exempt/always-visible; moot while paused.
- **Descoping Menübar-Overflow from v1.10 entirely** — considered again in this discussion and again NOT chosen; the user wants a pause, not a drop. Revisit this specific question too if the pause is ever formally converted to a drop.
- **Testing the Golden-Gate/Developer-Mode hypothesis via a full macOS 26 downgrade** — considered and explicitly rejected as disproportionate; not being pursued. If the user's machine is ever downgraded for unrelated reasons, this would be a cheap opportunistic re-test, but it is not a planned trigger.

### Reviewed Todos (not folded)
Unchanged from the second revision — all 3 todos matched Phase 66 on the scoring heuristic but were reviewed and rejected as unrelated (false-positive keyword matches):
- `2026-07-19-calendar-month-grid-polish.md` — calendar month-grid UI; unrelated.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — notch click-through behavior; this phase touches no notch surface at all.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — belongs to Phase 65 (Quick Actions bar), not this phase.

</deferred>

---

*Phase: 66-Menübar-Overflow (Debug-the-CGS-Spike MVP)*
*Context gathered: 2026-07-28 (third revision — PAUSED)*
