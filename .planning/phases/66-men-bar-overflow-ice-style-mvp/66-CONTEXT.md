# Phase 66: Menübar-Overflow (Spacer-Technique MVP) - Context

**Gathered:** 2026-07-27 (revised — supersedes the Ice-private-API version below after Plan 01's on-device NO-GO)
**Status:** Ready for re-planning

<domain>
## Phase Boundary

A chevron icon in the menu bar separates a "visible" section from a "hidden" section of OTHER apps' menu-bar icons. The user Cmd-drags an icon across the chevron to move it into the hidden section; clicking the chevron reveals or hides that section. Icons stay in the menu bar itself — they never move into the notch/island.

**Mechanism pivot (2026-07-27):** Plan 66-01's on-device spike returned a **NO-GO** on the original Ice-style mechanism — the private `CGSGetProcessMenuBarWindowList` API fails to enumerate real menu-bar-item windows on this hardware/macOS version (macOS 27.0 beta, build 26A5388g — newer than Tahoe, where Ice's own GitHub issues #679/#711 already documented the same private-API breakage upstream). Full findings: `66-01-SUMMARY.md`, `66-RESEARCH.md` Pitfall 3.

The phase now targets a **different reference implementation and mechanism**: Hidden Bar (github.com/dwarvesf/hidden, MIT) — a separator `NSStatusItem` whose width is toggled between ~1pt and a large bounded value (e.g. 2000pt, clamped to screen width). Widening it pushes every icon positioned to its left off the visible menu bar entirely — macOS's own layout engine removes them from view since there's no room, genuinely reclaiming space. Narrowing it reveals them again. This uses **only public `NSStatusBar`/`NSStatusItem` API** — no private CGS symbols, no synthetic `CGEvent` injection, no window enumeration, no Accessibility permission. Cmd-drag to reposition icons across the chevron is unaffected — that's native macOS behavior, independent of which technique owns the separator, confirmed in both Ice's and Hidden Bar's source.

**Requirements (locked via REQUIREMENTS.md, revised by this discussion):**
- **MENUBAR-01:** A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons. *(unchanged, mechanism-agnostic)*
- **MENUBAR-02:** The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section. *(unchanged, native OS behavior either way)*
- **MENUBAR-03:** Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden, not just repositioned off-screen while occupying visual space. *(unchanged wording — the spacer technique satisfies this more directly than Ice's occlusion-only mechanism did, per Pitfall 2 in 66-RESEARCH.md)*
- **MENUBAR-04:** ~~This feature requires a new Accessibility permission grant...~~ **DROPPED** — see D-04 below. The spacer technique needs no permission at all. Downstream agents: do not build any permission-gating, request flow, or "Permission required" Settings state for this feature. `REQUIREMENTS.md` still shows the original wording; treat this CONTEXT.md as the authority that supersedes it for this phase.

**Explicitly out of scope (locked in PROJECT.md's v1.10 milestone scope, not re-discussed here):** One hide tier only — no "always-hidden"/hotkey tier, no menu-bar theming, no hotkeys (unlike full Ice or full Hidden Bar, both of which have these extras).

</domain>

<decisions>
## Implementation Decisions

### Mechanism (revised 2026-07-27)
- **D-06 (NEW):** Build the hide/reveal mechanism using the spacer-`NSStatusItem` technique (Hidden Bar reference, public API only), NOT Ice's private-CGS-API/synthetic-CGEvent technique. This is the direct outcome of Plan 66-01's on-device NO-GO. `Islet/Notch/MenuBarOverflowBridging.swift` and `IsletTests/MenuBarOverflowManualSpike.swift` (the Ice-mechanism spike artifacts) are superseded — Claude's discretion whether to delete or repurpose them when the new plans are written; they must not be relied upon as-is.

### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — truly-hidden icons sit further left (off the visible strip, behind the widened spacer) and always-visible icons stay to the right, closer to the system clock. *(unchanged)*
- **D-02 (REVISED):** The feature activates automatically on app launch — there is no separate Settings on/off toggle for the mechanism itself, and (per the mechanism pivot) no permission gate of any kind to wait on either. This deliberately diverges from the v1.10 "new activities default OFF" convention, because Menübar-Overflow is not an `IslandResolver`/notch activity — it's a standalone menu-bar mechanism, same category as Quick Notes (Phase 64 D-13, menu-bar-only, zero resolver participation).

### Persistence
- **D-03:** The hidden/visible icon assignment persists across app relaunch — Islet remembers which other apps' icons were hidden and restores that grouping the next time those icons are (re)created by their owning apps. **Open question for research/planning:** under the spacer technique, "hidden" is really just "positioned left of the spacer" — whether macOS's own system-level status-item-ordering persistence is sufficient on its own, or whether Islet still needs active re-apply logic on relaunch (the same class of risk as the original research's Pitfall 1, but the concrete mechanism differs now that no per-icon private-API repositioning is involved), is a technical question for the phase's research step, not decided here.

### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons **inline in the menu bar itself** (they slide/appear directly in the strip as the spacer narrows), not in a separate dropdown/popover. Clicking again re-hides them (spacer widens again). *(unchanged in spirit; mechanically it's now a width animation, not a per-icon move)*

### Permission requirement — DROPPED (was MENUBAR-04 / old D-04)
- **D-04 (SUPERSEDED, kept for history):** ~~If Accessibility permission is denied, the chevron does not appear... Settings shows a "Permission required" state...~~ No longer applicable — the spacer technique requires no Accessibility permission. Do not implement any part of this.

### Claude's Discretion
- Exact persistence storage mechanism/format for D-03, informed by the research step's answer to the open question above.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide width transition (D-05).
- Bounded max width for the spacer's "collapsed" state (Hidden Bar clamps to screen width to avoid pathological layout on newer macOS — mirror that discipline).
- Whether to delete or repurpose the now-superseded `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` spike artifacts (D-06).
- Whether Islet's **own** status item(s) (the main status item, and the debug-only status item) can also be dragged behind the chevron, or are exempt from hiding — default assumption remains **exempt** (Islet's own icon stays always visible) unless research finds a strong reason otherwise.
- All remaining technical mechanism details (exact spacer-width values, sleep/wake and Dock-relaunch behavior under the new technique) — research/planning work, not a discussion decision. Given the new mechanism is public-API-only and far less exotic than Ice's, a full on-device spike-gate may no longer be strictly necessary before production code — but that call belongs to research/planning, not this discussion.

### Folded Todos
None — no todos matched this phase's revised scope (see Reviewed Todos below).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### This phase's own history (read first — explains why the mechanism changed)
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-01-SUMMARY.md` — the NO-GO verdict and its three on-device diagnostic rounds
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-RESEARCH.md` — original Ice-mechanism research; Pitfall 3 (version fragility) and Pitfall 2 (space-reclamation question) are the two sections most relevant to why the pivot happened and why the new technique resolves both more cleanly

### New mechanism reference (supersedes Ice for the actual hide/reveal implementation)
- Hidden Bar (open-source, MIT-licensed) — github.com/dwarvesf/hidden — `hidden/Features/StatusBar/StatusBarController.swift` is the file to read directly: `btnExpandCollapse` (visible chevron control, `NSStatusItem.variableLength`), `btnSeparate` (the actual spacer, toggled between `btnHiddenLength` (~20pt) and `btnHiddenCollapseLength` (~2000pt, bounded by `NSScreen.main?.visibleFrame.width`)), and the `isBtnSeparateValidPosition`/`isBtnAlwaysHiddenValidPosition` position-sanity checks. This app also has an "always hidden" tier and a global hotkey (`HotKey` package) — both explicitly out of scope for this phase's MVP; only the two-status-item spacer technique itself should be adopted.

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 66: Menübar-Overflow (Ice-Style MVP)" — goal, success criteria, requirements. **Note:** the ROADMAP's own phase title and SC#1's "read Ice's actual source" mandate are now historical — the mandate was honored (Plan 01 did read and transcribe Ice's real source) and the spike it required is exactly what surfaced the NO-GO driving this pivot.
- `.planning/REQUIREMENTS.md` lines 130-136 — MENUBAR-01/02/03/04 original wording; MENUBAR-04 is dropped per this CONTEXT.md (see `<domain>` above)
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.10" (Menübar-Overflow bullet) — the MVP scope bound: icons stay in the menu bar, never move into the notch; one hide tier only, no theming, no hotkeys

### Superseded reference (kept for context, do not re-implement)
- Ice (open-source, MIT-licensed) — `MenuBarItemManager.swift`/`Bridging.swift` — the original mandated reference; its private-CGS-API mechanism is confirmed NO-GO on this hardware/macOS version (see 66-01-SUMMARY.md). Do not port or retry this approach without a new discussion.

### Prior phase precedent
- `.planning/phases/64-quick-notes-obsidian-export/64-CONTEXT.md` D-13 — precedent for a v1.10 feature living entirely outside `IslandResolver`/the notch UI (same category as this phase: menu-bar-only, zero resolver participation).
- `.planning/phases/65-quick-actions-bar/65-CONTEXT.md` — Settings-grid card pattern; **no longer applicable to this phase** — per the revised D-02/D-04, this feature now has no Settings surface at all (no toggle, no permission card).

### Codebase (exact integration points, verified by reading the live file)
- `Islet/AppDelegate.swift:107` (`statusItem = NSStatusBar.system.statusItem(...)`) — existing pattern for creating a status item; both the new chevron control item AND the new spacer item follow this same construction as additional `NSStatusItem` instances.
- `Islet/AppDelegate.swift:490` (`debugStatusItem`) — Islet already runs multiple simultaneous `NSStatusItem` instances (debug builds), confirming no structural conflict with adding two more (chevron + spacer) for this feature.
- `Islet/Notch/MenuBarOverflowBridging.swift`, `IsletTests/MenuBarOverflowManualSpike.swift` — superseded spike artifacts from the abandoned Ice-mechanism approach (D-06); do not build on these.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NSStatusBar.system.statusItem(withLength:)` construction pattern (`AppDelegate.swift:107`) — directly reusable for both the chevron and spacer `NSStatusItem`s.

### Established Patterns
- Menu-bar-only features stay out of `IslandResolver` entirely (reaffirmed by D-02) — same rule Phase 64 (Quick Notes) already applied.
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `MicMuteController`, `MeetingMonitor` precedent) — less critical now than under the Ice mechanism (the new technique is public-API-only, not an undocumented private surface), but still good practice for the new `MenuBarOverflowController`-equivalent type.

### Integration Points
- New chevron `NSStatusItem` (visible control, leftmost per D-01) + new spacer `NSStatusItem` (invisible, width-toggled) — two status items, not one.
- New persistence store for hidden-icon assignment (D-03) — mechanism and format now an open research question (see D-03 above), not yet decided.
- **No longer needed:** any Accessibility-permission request/status flow, any Settings permission-status card (both dropped per D-04/MENUBAR-04).

</code_context>

<specifics>
## Specific Ideas

No screenshot or mockup was supplied for the chevron's visual design. Hidden Bar (github, MIT-licensed) is now the direct behavioral/mechanism reference for the hide/reveal technique; the user still wants the Ice-style *interaction* (chevron separating visible/hidden, Cmd-drag to assign) — only the underlying *mechanism* changed, not the UX vision.

</specifics>

<deferred>
## Deferred Ideas

- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md), reaffirmed here, not re-opened for discussion. (Both Ice and Hidden Bar have these extras; neither is in scope.)
- **Hiding Islet's own status item(s) behind the chevron** — not decided; left to Claude's discretion, default assumption is that Islet's own icon(s) stay exempt/always-visible (see Claude's Discretion above).
- **Retrying Ice's private-API mechanism / porting Ice's own Tahoe-compatibility fix** — considered and explicitly rejected during this discussion in favor of the spacer technique, given this hardware runs an even newer macOS beta (27.0) than Tahoe and the private-API approach was assessed as inherently fragile long-term.

### Reviewed Todos (not folded)
All 3 todos matched Phase 66 on the scoring heuristic (re-checked 2026-07-27); all were reviewed and rejected as unrelated to Menübar-Overflow (false-positive keyword matches on generic project terms like "notch"/"swift"/"phase"):
- `2026-07-19-calendar-month-grid-polish.md` — calendar month-grid UI; unrelated.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — notch click-through behavior; this phase touches no notch surface at all.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — belongs to Phase 65 (Quick Actions bar), not this phase.

</deferred>

---

*Phase: 66-Menübar-Overflow (Spacer-Technique MVP)*
*Context gathered: 2026-07-27 (revised)*
