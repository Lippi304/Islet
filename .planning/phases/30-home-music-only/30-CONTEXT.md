# Phase 30: Home Music-Only - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Home becomes exclusively a music surface, driven entirely by `NowPlayingState`. Three states, always live-controls-capable:

1. **Playing** — live Now-Playing transport controls (play/pause/next/prev), unchanged from today (HOME-01).
2. **Not currently playing but something played this session** ("last-played") — the last-played track's cover+title, WITH the same transport controls as the live state (REVISED HOME-02 — see Decisions below).
3. **Nothing played this session** — an explicit empty state; the old idle time/weather/calendar fallback glance is removed entirely from Home (HOME-03). Weather and Calendar keep their own switcher tabs — this phase does not touch those views.

Out of scope: Tray/Calendar/Weather content or layout, the switcher pill itself, the NotchShape flare (Phase 29, separate), file-shelf behavior (Phase 31/32), any change to `mediaWingsOrToast` (the collapsed glance/toast — untouched by this phase, only the expanded Home presentation changes).

</domain>

<decisions>
## Implementation Decisions

### Paused vs. stopped vs. never-played
- **D-01:** `.paused` still shows full live Now-Playing controls (same as `.playing`) — pausing does NOT visually demote Home. Today's codebase has no distinct "stopped" signal; `NowPlayingPresentation` only has `.playing`/`.paused`/`.none` (a nil MediaRemote payload maps straight to `.none`, per existing D-11 in `NowPlayingMonitor.swift`).
- **D-02:** The "last-played" state (HOME-02) is reached via `.none` + `hasPlayedSinceLaunch == true` (the existing sticky bool in `NowPlayingState.swift:21-25` already tracks exactly this — no new flag needed for the never-vs-ended distinction).
- **D-03:** The empty state (HOME-03) is reached via `.none` + `hasPlayedSinceLaunch == false`.

### Last-played visual treatment (REVISES HOME-02's original wording)
- **D-04 (REVISED, supersedes original REQUIREMENTS.md HOME-02):** Transport controls (play/pause/next/prev) stay visible in BOTH the live state and the last-played state — they are NOT hidden in last-played as originally specified. `REQUIREMENTS.md` HOME-02 and `ROADMAP.md` Phase 30 Success Criteria #2 have been updated in this session to reflect this (both files edited directly during this discussion — see diffs).
- **D-05:** New visual addition (applies to both live and last-played states, did not exist before): transport buttons get a rounded-rectangle (4-corner rounded square) hover background.
- **D-06:** In the last-played state, tapping Play sends the transport command as normal, attempting to resume/replay via the source app — no separate disabled/inert button state is built. If the source app is unreachable, nothing visibly happens (no error UI required).

### Last-played track sticky state
- **D-07:** A new `NowPlayingState.lastKnownTrack` field (per ROADMAP.md's own phrasing) is session-only — cleared on app relaunch, never persisted to disk/UserDefaults. Matches HOME-03's literal "this session" wording.
- **D-08:** `lastKnownTrack` always reflects the MOST RECENTLY playing track — overwritten every time a new track starts playing, not captured once and frozen.

### Empty state (HOME-03)
- **D-09 (LOCKED):** Icon + heading + body style, mirroring `trayEmptyState` (`NotchPillView.swift:745-760`) rather than `calendarEmptyState`'s heading-only style — a music-note SF Symbol above the heading.
- **D-10 (LOCKED):** Copy: heading **"Nothing Playing"**, body **"Start something in Spotify or Music."** — names the two allowlisted apps directly, consistent with how the existing `mediaUnavailable` string names sources.

### Claude's Discretion
- Exact SF Symbol for the empty-state icon (e.g. `music.note`) — not specified, pick one consistent with the existing icon weight/style used by `trayEmptyState`'s `Image(systemName: "tray")`.
- Exact hover-background shape parameters (corner radius, size, color/opacity) for D-05 — "rounded rectangle" is locked, exact values are implementation/UI-phase judgment, tuned on-device per this project's established iterative-tuning convention (Phase 7, 18, 20/21/23, 25, 26, 28, 29 precedent).
- Whether `lastKnownTrack` stores just title/artist/artwork, or additionally something like the source app identifier (for D-06's resume attempt) — implementation detail, follow whatever `NowPlayingMonitor`/adapter needs to reissue a play command.
- Exact naming/shape of the new `IslandResolver` branch(es) that route `.none` between last-played and empty-state based on `hasPlayedSinceLaunch` — implementation detail for planner/executor.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` §"Home" — HOME-01, HOME-02 (REVISED 2026-07-14 in this session — read the current wording, not any cached/prior version), HOME-03
- `.planning/ROADMAP.md` §"Phase 30: Home Music-Only" — Goal, Depends on (none), 4 Success Criteria (Success Criteria #2 REVISED 2026-07-14), "UI hint: yes"

### Prior-phase decisions this phase builds on / reverses
- `.planning/phases/28-calendar-full-view/28-CONTEXT.md` §Addendum round 4, point 2 ("Smart Home") — established that Home shows Now-Playing when something plays and falls back to idle glance otherwise. This phase REMOVES the idle-glance fallback half of that decision entirely (HOME-03) and extends the Now-Playing half to the new last-played sticky state (D-02/D-04).
- `.planning/phases/29-notchshape-flare/29-CONTEXT.md` D-03 — confirms `mediaWingsOrToast` (the collapsed glance/toast) is a SEPARATE code path from Home's expanded `blobShape()`-based view; this phase touches only the expanded Home presentation, not the collapsed wings/toast.

### Existing code this phase modifies/extends
- `Islet/Notch/IslandResolver.swift` (resolve() reducer, ~lines 73-111) — Home branch currently returns `.expandedIdle` when `nowPlaying == .none` (lines 102-104); needs new branching on `hasPlayedSinceLaunch` to choose last-played vs. empty state instead.
- `Islet/Notch/IslandPresentationState.swift` — the `IslandPresentation` enum; `.expandedIdle` case likely removed/replaced for the Home path (confirm it isn't used elsewhere before deleting — Weather/Calendar have their own dedicated cases per Phase 28 D-02 amendment).
- `Islet/Notch/NowPlayingState.swift` (lines 11-38) — add the new `lastKnownTrack` sticky field alongside the existing `hasPlayedSinceLaunch` bool (lines 21-25).
- `Islet/Notch/NotchPillView.swift`:
  - `expandedIsland` (lines 436-459) — the current `.expandedIdle` renderer (weather/date/calendar HStack) — removed for Home's purposes.
  - `calendarEmptyState` (lines 594-605) and `trayEmptyState` (lines 745-760) — the two existing empty-state precedents; D-09 follows the `trayEmptyState` icon+heading+body pattern.
  - The Now-Playing expanded view's transport-controls row — needs the new rounded-rectangle hover background (D-05) and needs to render identically in both live and last-played states (D-04).
- `Islet/Notch/NowPlayingMonitor.swift` (line 73, nil payload → `.none`; lines 100-112 health check) — D-11/D-12/D-13 conventions (healthy vs. `.none`) are orthogonal to this phase's last-played/empty-state split and must not be disturbed.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `trayEmptyState` (`NotchPillView.swift:745-760`) — icon + heading + body pattern, direct template for the new Home empty state (D-09).
- `hasPlayedSinceLaunch` (`NowPlayingState.swift:21-25`) — already exactly the boolean HOME-03 needs ("has anything played this session"), no new tracking required for that half of the decision.

### Established Patterns
- **Single-arbiter presentation state** (`IslandResolver.resolve()`) — the last-played/empty-state split must be decided inside this one reducer, not a parallel flag in the view layer (same discipline flagged in Phase 26/28 contexts).
- **On-device iterative tuning is normal in this project** — exact hover-background shape values (D-05) and icon choice are expected to be tuned after first implementation, per repeated precedent (Phase 7, 18, 20/21/23, 25, 26, 28, 29).
- **`NowPlayingPresentation`'s 3-state model has no "stopped" case** — `.paused` and `.none` are the only non-playing states; distinguishing "ended" from "never played" already relies on the separate `hasPlayedSinceLaunch` bool rather than a 4th presentation case. This phase's design (D-01/D-02/D-03) follows that existing shape rather than adding a new enum case.

### Integration Points
- `IslandResolver.resolve()` — the sole integration point for the new last-played/empty-state branching logic.
- `NowPlayingState` — the sole integration point for the new `lastKnownTrack` sticky field.
- `NotchPillView.swift`'s transport-controls view — the sole integration point for the new hover-background style (D-05), shared between live and last-played rendering per D-04.

</code_context>

<specifics>
## Specific Ideas

- User specifically described (in free text) wanting controls visible in both live and last-played states, with a "4-cornered rounded rectangle" (abgerundetes Viereck) as the new hover background on transport buttons — this is D-04/D-05, a deliberate, confirmed revision of the phase's originally-scoped HOME-02 wording.
- Empty-state copy explicitly locked to naming the two allowlisted apps: "Start something in Spotify or Music." (D-10).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The one requirement-wording change (D-04) was explicitly confirmed with the user as an intentional revision, not scope creep, and both `REQUIREMENTS.md` and `ROADMAP.md` were updated in this session to match.

### Reviewed Todos (not folded)
None — `todo.match-phase` query for Phase 30 returned zero matches.

</deferred>

---

*Phase: 30-Home-Music-Only*
*Context gathered: 2026-07-14*
