# Phase 66: Menübar-Overflow (Ice-Style MVP) - Context

**Gathered:** 2026-07-27
**Status:** Ready for planning

<domain>
## Phase Boundary

A chevron icon in the menu bar separates a "visible" section from a "hidden" section of OTHER apps' menu-bar icons. The user Cmd-drags an icon across the chevron to move it into the hidden section; clicking the chevron reveals or hides that section. Icons stay in the menu bar itself — they never move into the notch/island. This is the milestone's highest-novelty, zero-reuse feature, and the ROADMAP itself mandates an on-device spike reading Ice's actual source (`MenuBarItemManager.swift`/`Bridging.swift`) before any production mechanism is committed.

**Requirements (locked via REQUIREMENTS.md, not re-discussed here):**
- **MENUBAR-01:** A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons, mirroring Ice's MVP mechanic.
- **MENUBAR-02:** The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section.
- **MENUBAR-03:** Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden, not just repositioned off-screen while occupying visual space.
- **MENUBAR-04:** This feature requires a new Accessibility permission grant, requested with a clear one-time explanation — distinct from Islet's existing WeatherKit/EventKit/Bluetooth permission prompts.

**Explicitly out of scope (locked in PROJECT.md's v1.10 milestone scope, not re-discussed here):** One hide tier only — no "always-hidden"/hotkey tier, no menu-bar theming, no hotkeys (unlike full Ice).

</domain>

<decisions>
## Implementation Decisions

### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — mirroring Ice's actual mechanic, where truly-hidden icons sit further left (off the visible strip) and always-visible icons stay to the right, closer to the system clock.
- **D-02:** The feature activates automatically as soon as Accessibility permission is granted — there is no separate Settings on/off toggle for the mechanism itself. This deliberately diverges from the v1.10 "new activities default OFF" convention (research Pitfall 5), because Menübar-Overflow is not an `IslandResolver`/notch activity — it's a standalone menu-bar mechanism, same category as Quick Notes (Phase 64 D-13, menu-bar-only, zero resolver participation).

### Persistence
- **D-03:** The hidden/visible icon assignment persists across app relaunch — Islet remembers which other apps' icons were hidden (keyed by bundle identifier, mirroring Ice's own persistence approach) and restores that grouping the next time those icons are (re)created by their owning apps.

### Permission-denied degradation (MENUBAR-04)
- **D-04:** If Accessibility permission is denied, the chevron does not appear in the menu bar at all — no broken/dead icon sitting there. Settings shows a clear "Permission required" state with a button that opens System Settings → Privacy & Security → Accessibility directly.

### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons **inline in the menu bar itself** (Ice-style — they slide/appear directly in the strip), not in a separate dropdown/popover. Clicking again re-hides them.

### Claude's Discretion
- Exact persistence storage mechanism/format (UserDefaults keyed by bundle ID vs. plist, etc.) for D-03.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide transition (D-05).
- Exact one-time permission-explanation copy/wording (D-04/MENUBAR-04).
- Whether Islet's **own** status item(s) (the main status item, and the debug-only status item) can also be dragged behind the chevron, or are exempt from hiding — not discussed; default assumption is **exempt** (Islet's own icon stays always visible) unless the phase's own spike/research finds a strong reason otherwise.
- All technical mechanism details the ROADMAP's own Success Criteria #1 already assigns to an on-device spike (the private `NSStatusItem`-repositioning technique, sleep/wake and Dock-relaunch edge cases) — this is research/spike work, not a discussion decision.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 66: Menübar-Overflow (Ice-Style MVP)" — goal, 5 success criteria (incl. the mandatory on-device spike), requirements
- `.planning/REQUIREMENTS.md` lines 130-136 — MENUBAR-01/02/03/04 exact wording
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.10" (Menübar-Overflow bullet) — the MVP scope bound: icons stay in the menu bar, never move into the notch; one hide tier only, no theming, no hotkeys

### External reference (the actual mechanism source)
- Ice (open-source, MIT-licensed menu-bar-icon-hiding tool) — `MenuBarItemManager.swift`/`Bridging.swift` are explicitly named in the ROADMAP as what the phase's own spike must read directly, not a general description of the technique.

### Prior phase precedent
- `.planning/phases/64-quick-notes-obsidian-export/64-CONTEXT.md` D-13 — precedent for a v1.10 feature living entirely outside `IslandResolver`/the notch UI (same category as this phase: menu-bar-only, zero resolver participation).
- `.planning/phases/65-quick-actions-bar/65-CONTEXT.md` — Settings-grid card pattern; note Menübar-Overflow's own Settings surface is only a permission-status display (D-04), not a feature on/off toggle (per D-02).

### Codebase (exact integration points, verified by reading the live file)
- `Islet/AppDelegate.swift:107` (`statusItem = NSStatusBar.system.statusItem(...)`) — existing pattern for creating a status item; the new chevron control item follows this same construction as an additional `NSStatusItem` instance.
- `Islet/AppDelegate.swift:490` (`debugStatusItem`) — Islet already runs multiple simultaneous `NSStatusItem` instances (debug builds), confirming no structural conflict with adding one more for the chevron.
- No existing Accessibility-permission code anywhere in the codebase today — this is the first feature requiring `AXIsProcessTrusted()`/the Accessibility API, a genuinely new permission class alongside the existing WeatherKit/EventKit/Bluetooth prompts (MENUBAR-04).

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NSStatusBar.system.statusItem(withLength:)` construction pattern (`AppDelegate.swift:107`) — directly reusable for the new chevron `NSStatusItem`.

### Established Patterns
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `MicMuteController`, `MeetingMonitor` precedent) — the private, undocumented `NSStatusItem`-repositioning mechanism this phase's own spike must validate should get its own isolated manager type, mirroring that discipline. Especially important here since Success Criteria #1 explicitly requires spiking the mechanism (including permission-denied, sleep/wake, and Dock-relaunch edge cases) before the production version is built.
- Menu-bar-only features stay out of `IslandResolver` entirely (Pitfall 6 category (c), reaffirmed by D-02) — same rule Phase 64 (Quick Notes) already applied.

### Integration Points
- New chevron `NSStatusItem`, positioned leftmost among Islet's own items (D-01).
- New Accessibility-permission request/status flow — first of its kind in this codebase, needs its own isolated check (mirrors how `BluetoothMonitor`/`WeatherKit`/`EventKit` each isolate their own permission flow).
- Settings — a new permission-status card (D-04), distinct from a feature-toggle card since the mechanism itself has no on/off switch (D-02).
- New persistence store for hidden-icon bundle-identifier assignments (D-03) — no existing subsystem to reuse; likely a small, isolated store similar in spirit to `ActivitySettings`'s `@AppStorage` namespace but keyed by arbitrary bundle IDs rather than fixed feature keys.

</code_context>

<specifics>
## Specific Ideas

No screenshot or mockup was supplied for the chevron's visual design. Ice itself (github, MIT-licensed, explicitly named in the ROADMAP) is the direct behavioral reference — the user wants Ice's core "hide behind a chevron" mechanic only, not its full feature set (no theming, no hotkeys, no always-hidden tier).

</specifics>

<deferred>
## Deferred Ideas

- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md), reaffirmed here, not re-opened for discussion.
- **Hiding Islet's own status item(s) behind the chevron** — not decided; left to Claude's discretion, default assumption is that Islet's own icon(s) stay exempt/always-visible (see Claude's Discretion above).

### Reviewed Todos (not folded)
All 3 todos matched Phase 66 on the scoring heuristic; all were reviewed and rejected as unrelated to Menübar-Overflow (false-positive keyword matches on generic project terms like "notch"/"swift"/"phase"):
- `2026-07-19-calendar-month-grid-polish.md` — calendar month-grid UI; unrelated.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — notch click-through behavior; this phase touches no notch surface at all.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — belongs to Phase 65 (Quick Actions bar), not this phase.

</deferred>

---

*Phase: 66-Menübar-Overflow (Ice-Style MVP)*
*Context gathered: 2026-07-27*
