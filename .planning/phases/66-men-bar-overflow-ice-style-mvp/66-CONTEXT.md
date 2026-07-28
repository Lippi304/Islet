# Phase 66: Menübar-Overflow (Debug-the-CGS-Spike MVP) - Context

**Gathered:** 2026-07-28 (second revision — supersedes the spacer-technique version below after Plan 66-04's on-device NO-GO)
**Status:** Ready for re-planning

<domain>
## Phase Boundary

A chevron icon in the menu bar separates a "visible" section from a "hidden" section of OTHER apps' menu-bar icons. The user Cmd-drags an icon across the chevron to move it into the hidden section; clicking the chevron reveals or hides that section. Icons stay in the menu bar itself — they never move into the notch/island.

**Second mechanism pivot (2026-07-28):** Plan 66-04's on-device UAT returned a **second consecutive NO-GO** — this time on the pivoted public-`NSStatusItem`-spacer technique (Hidden Bar's mechanism, built in 66-02): the chevron's click handler and glyph-swap work, but Cmd-drag does not engage with the spacer at all, and the spacer's `.length` toggle produces zero observable reclaim/hide effect on real menu-bar layout. Full findings: `66-04-SUMMARY.md`.

**Critical new diagnostic fact, established in this discussion:** the user confirmed that **real Ice (the actual open-source app, private-CGS-API mechanism) currently works on this exact machine** — they have used it as their daily driver. This directly contradicts the "macOS 27 Tahoe beta regression" hypothesis that both prior NO-GOs pointed toward (see `[[phase66_menubar_overflow_second_nogo]]` project memory, written before this fact was known). If Ice's own private-CGS technique demonstrably works on this hardware/OS right now, then Plan 66-01's NO-GO (private CGS enumeration failing to find real menu-bar windows) was almost certainly a **bug in Islet's own port of Ice's mechanism**, not a broken/removed OS API. Ice is installed on the machine but not currently running — it needs to be launched to serve as a live comparison reference.

**Mechanism decision (2026-07-28, second pivot):** Abandon the Hidden Bar public-spacer technique (D-06, now superseded a second time) and the "OS regression, wait it out" theory. Instead: **debug Plan 66-01's original private-CGS spike against real, currently-running Ice** on this same machine, to find the concrete divergence between what Islet's spike code did and what Ice's actual (working) code does. This is a targeted debugging task, not a third blind mechanism guess.

**Requirements (locked via REQUIREMENTS.md, unchanged by this revision):**
- **MENUBAR-01:** A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons. *(unchanged, mechanism-agnostic)*
- **MENUBAR-02:** The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section. *(unchanged, native OS behavior — now confirmed working via Ice on this hardware, so achievable)*
- **MENUBAR-03:** Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden — real space reclaimed. *(unchanged; Ice's real private-CGS mechanism is now believed capable of this on this hardware, since Ice itself does it daily for the user)*
- **MENUBAR-04:** ~~Accessibility permission requirement~~ **Reopened as an open question** — the original Ice mechanism (private CGS) requires Accessibility permission in Ice's own implementation. Since we're reverting to the CGS-based approach, this requirement may need to be un-dropped. Research/planning must re-check whether Islet's CGS usage requires the same permission Ice's does, and if so, restore the permission-gate requirement dropped in the prior (now-superseded) revision.

**Explicitly out of scope (locked in PROJECT.md's v1.10 milestone scope, not re-discussed here):** One hide tier only — no "always-hidden"/hotkey tier, no menu-bar theming, no hotkeys (unlike full Ice or full Hidden Bar, both of which have these extras).

</domain>

<decisions>
## Implementation Decisions

### Mechanism (revised 2026-07-28 — second pivot)
- **D-07 (NEW, supersedes D-06):** Do NOT build a third blind mechanism variant. Instead, debug Plan 66-01's private-CGS spike (`MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift`, currently superseded/half-deleted per D-06/66-03) against **real, currently-running Ice** on this machine as a live reference — find where Islet's CGS enumeration diverges from Ice's actual working behavior, fix it, and re-verify on-device. Only if this debugging genuinely dead-ends (e.g., Ice turns out to use a materially different code path than its public source suggests) should a different mechanism be considered — and that would need a return to this discussion.
- **D-06 (SUPERSEDED, kept for history):** ~~Build the hide/reveal mechanism using the spacer-`NSStatusItem` technique (Hidden Bar reference, public API only)~~ — NO-GO'd on-device in Plan 66-04 (Cmd-drag doesn't engage, `.length` toggle has no reclaim effect). Superseded by D-07.
- **Live reference setup:** Ice is installed on the machine but not currently running. The debugging plan must start with launching Ice so it can serve as a running comparison target (e.g., diffing CGS enumeration output between Islet's spike and Ice's real process, or instrumenting/observing Ice's behavior directly) before touching Islet's own code.
- **Diagnostic hypothesis to test first:** Islet's spike (66-01) likely differs from Ice's real source in some concrete, fixable way — wrong CGS symbol signature, wrong process/window filtering, timing/permission-state assumption, or a redeclaration collision (66-01-SUMMARY.md already recorded one CGS symbol redeclaration collision that was "resolved" during that plan — this is a prime suspect for where a subtle divergence from Ice's real behavior could have been introduced).

### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — truly-hidden icons sit further left (behind/via the CGS mechanism) and always-visible icons stay to the right, closer to the system clock. *(unchanged)*
- **D-02:** The feature activates automatically on app launch — there is no separate Settings on/off toggle for the mechanism itself. *(unchanged — still not an `IslandResolver`/notch activity, same category as Quick Notes Phase 64 D-13)*
- **Permission gate — reopened:** Per MENUBAR-04 above, whether Islet's CGS usage needs an Accessibility permission gate (same as Ice's real app requires) is now an open research question again, reversing the prior "DROPPED" decision (old D-04). Research must check what permission Ice's actual app prompts for and whether Islet's CGS calls trigger the same requirement.

### Persistence
- **D-03:** The hidden/visible icon assignment persists across app relaunch. *(unchanged)* Given the mechanism reverts to CGS-based repositioning (not spacer-position), the original Pitfall-1-class question from `66-RESEARCH.md` (does Islet need active re-apply logic on relaunch, or is OS-level ordering persistence enough) is back in play as the CGS mechanism's actual behavior, not the spacer's — research/planning to resolve.

### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons inline in the menu bar itself, not in a separate dropdown/popover. Clicking again re-hides them. *(unchanged in spirit — now via genuine CGS-level repositioning rather than a spacer-width animation)*

### Claude's Discretion
- Exact persistence storage mechanism/format for D-03, informed by research's re-examination under the CGS mechanism.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide transition (D-05).
- Whether to restore/repurpose the existing (partially superseded) `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` files as the base for the debugging work, or start the CGS spike fresh with lessons learned — Claude's call once the actual divergence from Ice is found.
- Whether Islet's own status item(s) can also be dragged behind the chevron, or are exempt — default assumption remains **exempt** unless research finds a strong reason otherwise.
- Exact debugging technique (e.g., logging both processes' CGS calls, using `lsappinfo`/private tooling to inspect Ice's live window list, or reading Ice's source even more literally line-by-line against the 66-01 port) — research/debugging discretion, not a discussion decision.

### Folded Todos
None — no todos matched this phase's revised scope (re-checked, see Reviewed Todos below).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### This phase's own history (read first — explains the two pivots)
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-01-SUMMARY.md` — original private-CGS NO-GO and its three on-device diagnostic rounds, including the CGS symbol redeclaration collision — prime suspect for the real bug now that Ice itself is confirmed working
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-04-SUMMARY.md` — second NO-GO (public spacer technique); documents why that path is now abandoned
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-RESEARCH.md` — original Ice-mechanism research; Pitfall 3 (version fragility, now believed to be a false lead) and Pitfall 1 (relaunch persistence) sections most relevant
- Project memory `phase66_menubar_overflow_second_nogo` — written before the "Ice actually works here" fact was established; its "OS regression" hypothesis is superseded by this discussion for the CGS-specific mechanism (the spacer-technique failure's cause remains genuinely unexplained but is no longer this phase's active path)

### Live debugging reference
- Real Ice.app, installed on this machine (currently not running — must be launched by the debugging plan) — the mechanism-of-record to diff Islet's CGS spike against. No source download needed beyond what 66-01 already read; the point now is behavioral comparison on THIS hardware, not reading more of Ice's GitHub source.
- Ice (open-source, MIT-licensed) — `MenuBarItemManager.swift`/`Bridging.swift` — already read once during Plan 66-01; re-read with fresh eyes for the specific divergence, informed by live comparison.

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 66: Menübar-Overflow (Ice-Style MVP)" — goal, success criteria, requirements.
- `.planning/REQUIREMENTS.md` lines 130-136 — MENUBAR-01/02/03/04 original wording; MENUBAR-04 (permission gate) is reopened per this CONTEXT.md, reversing the prior revision's "DROPPED" call.
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.10" (Menübar-Overflow bullet) — MVP scope bound: icons stay in the menu bar, one hide tier only, no theming, no hotkeys. Confirms this feature does not block any other v1.10 phase if it were ever descoped (it wasn't — user chose to keep trying).

### Superseded reference (kept for context, do not re-implement as-is)
- Hidden Bar (open-source, MIT-licensed) — github.com/dwarvesf/hidden — the spacer-`NSStatusItem` technique from the first pivot; confirmed NO-GO on-device in 66-04. Do not retry this technique without a new discussion.

### Prior phase precedent
- `.planning/phases/64-quick-notes-obsidian-export/64-CONTEXT.md` D-13 — precedent for a v1.10 feature living entirely outside `IslandResolver`/the notch UI (same category as this phase).

### Codebase (exact integration points, verified by reading the live file)
- `Islet/AppDelegate.swift:107` (`statusItem = NSStatusBar.system.statusItem(...)`) — existing pattern for creating a status item.
- `Islet/Notch/MenuBarOverflowBridging.swift`, `IsletTests/MenuBarOverflowManualSpike.swift` — original CGS spike artifacts (partially removed/superseded per 66-03); the debugging plan should check current on-disk state before assuming these still exist as originally written.
- `Islet/Notch/MenuBarOverflowController.swift` (from Plan 66-02) — the now-abandoned spacer-technique implementation; not the base for the new debugging work, but check for any reusable chevron-UI/glyph-swap code (D-05's inline reveal glyph logic worked correctly per 66-04, may be reusable regardless of underlying mechanism).

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NSStatusBar.system.statusItem(withLength:)` construction pattern (`AppDelegate.swift:107`).
- Chevron click-handler and glyph-swap logic from Plan 66-02 (`chevron.left`/`chevron.right` toggle) — confirmed working in 66-04's on-device UAT even though the underlying spacer mechanism failed; likely reusable regardless of which mechanism ultimately drives the actual hide/reveal.

### Established Patterns
- Menu-bar-only features stay out of `IslandResolver` entirely (reaffirmed by D-02).
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `MicMuteController`, `MeetingMonitor` precedent) — especially relevant again now that the mechanism is back to an undocumented private CGS surface.

### Integration Points
- Debugging target: `Islet/Notch/MenuBarOverflowBridging.swift` (or its current remnants) vs. real Ice's `Bridging.swift`/`MenuBarItemManager.swift` behavior, observed live.
- Persistence store for hidden-icon assignment (D-03) — mechanism/format still an open research question, now under the CGS-mechanism's actual semantics rather than the spacer's.

</code_context>

<specifics>
## Specific Ideas

The user has used real Ice as their daily menu-bar-hiding tool on this exact machine and confirmed it currently works — this is the single most important fact driving this revision's direction. No screenshot/mockup was supplied for the chevron's visual design; the existing chevron UI/glyph-swap from Plan 66-02 is already validated on-device and can likely be kept as-is.

</specifics>

<deferred>
## Deferred Ideas

- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md), reaffirmed here, not re-opened for discussion.
- **Hiding Islet's own status item(s) behind the chevron** — not decided; left to Claude's discretion, default assumption is that Islet's own icon(s) stay exempt/always-visible.
- **Descoping Menübar-Overflow from v1.10 entirely** — considered and explicitly rejected during this discussion; user chose to keep pursuing the feature given the new diagnostic evidence that Ice's mechanism genuinely works on this hardware.
- **"Wait for stable macOS release" theory** — considered and rejected for the CGS-specific mechanism now that Ice is confirmed working on this exact Tahoe-beta build; the public-spacer technique's failure cause remains unexplained but is no longer being pursued, so it's moot for this phase.
- **Hidden Bar's public-spacer technique as a fallback if CGS debugging dead-ends** — not decided; if the debugging effort genuinely cannot find the divergence, return to `/gsd:discuss-phase 66` rather than silently falling back.

### Reviewed Todos (not folded)
All 3 todos matched Phase 66 on the scoring heuristic (re-checked 2026-07-28); all were reviewed and rejected as unrelated to Menübar-Overflow (false-positive keyword matches on generic project terms like "notch"/"swift"/"phase"):
- `2026-07-19-calendar-month-grid-polish.md` — calendar month-grid UI; unrelated.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — notch click-through behavior; this phase touches no notch surface at all.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — belongs to Phase 65 (Quick Actions bar), not this phase.

</deferred>

---

*Phase: 66-Menübar-Overflow (Debug-the-CGS-Spike MVP)*
*Context gathered: 2026-07-28 (second revision)*
