# Phase 30: Home Music-Only - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 30-Home Music-Only
**Areas discussed:** Paused-state behavior, Last-played visual treatment, Empty-state design (HOME-03), Last-played track scope

---

## Paused-state behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Pause = last-played (no controls) | Literal HOME-02 reading: .paused immediately drops to cover+title only. | |
| Pause = still live (controls stay) | .paused keeps showing full Now-Playing controls; only .none (session ended) drops to last-played. | ✓ |
| You decide | Claude picks based on Droppy/iOS widget precedent. | |

**User's choice:** Pause = still live (controls stay)
**Notes:** This decision was subsequently superseded by the Last-played visual treatment discussion below — controls ended up staying visible in the last-played state too, making the .paused/.none distinction mostly moot except for what Play does.

---

## Last-played visual treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Same layout, buttons hidden | Live layout minus the transport row. | |
| Dimmed/muted version | Live layout, reduced opacity to signal inactive. | |
| Distinct minimal layout | Smaller centered art + title, no artist line. | |
| (free-text override) | User described wanting controls visible in both live and last-played states, plus a new rounded-rectangle hover background on transport buttons. | ✓ |

**User's choice (free text, German):** "Es wird genau der zuletzt gespielte track angezeigt und normal alle buttons sichtbar aber mit Hintergrund das man sieht das man rüber hovert das war bisher nicht s[o]" → clarified: "Wenn live played un nicht mehr live soll es beides Controls und diese soll einen 4 aberundetes viereck haben als hover background!"
**Notes:** Confirmed explicitly this REVISES HOME-02's original "without live transport controls" wording — controls now stay visible in both live and last-played states, with a new rounded-rectangle (4-corner rounded square) hover background on the buttons in both states. `REQUIREMENTS.md` and `ROADMAP.md` were both edited in this session to reflect the revision (see CONTEXT.md D-04).

Follow-up question — what Play should do in last-played state:

| Option | Description | Selected |
|--------|-------------|----------|
| Try to resume/replay | Sends the transport command as normal; resumes if source app reachable. | ✓ |
| Visually present, functionally inert | Buttons render but are effectively disabled/no-op. | |
| You decide | Claude picks the simplest technically sound behavior. | |

**User's choice:** Try to resume/replay

---

## Empty-state design (HOME-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Icon + heading + body (Tray-style) | Music-note icon above heading + body, mirrors trayEmptyState. | ✓ |
| Heading + body only (Calendar-style) | No icon, mirrors calendarEmptyState. | |
| You decide | Claude picks copy + icon presence. | |

**User's choice:** Icon + heading + body (Tray-style)

Follow-up — exact copy:

| Option | Description | Selected |
|--------|-------------|----------|
| "Nothing Playing" / "Start something in Spotify or Music." | Names the two allowlisted apps directly. | ✓ |
| "No Music Yet" / "Play something to see it here." | Generic, app-agnostic. | |
| You decide | Claude picks final wording. | |

**User's choice:** "Nothing Playing" / "Start something in Spotify or Music."

---

## Last-played track scope

| Option | Description | Selected |
|--------|-------------|----------|
| Yes to both (recommended) | Session-only (cleared on relaunch) + always reflects the most-recently-playing track. | ✓ |
| Persist across relaunches | lastKnownTrack survives app quit/relaunch. | |

**User's choice:** Yes to both (recommended)
**Notes:** Confirms `NowPlayingState.lastKnownTrack` is in-memory only, matching HOME-03's "this session" wording, and is overwritten on every new track start (not captured once).

---

## Claude's Discretion

- Exact SF Symbol for the empty-state icon.
- Exact hover-background shape parameters (corner radius, size, color/opacity) — "rounded rectangle" locked, values tuned on-device.
- Whether `lastKnownTrack` stores additional fields (e.g. source app identifier) beyond title/artist/artwork, to support the resume-on-Play behavior.
- Exact naming/shape of the new `IslandResolver` branch(es) routing `.none` between last-played and empty-state.

## Deferred Ideas

None — discussion stayed within phase scope. The one requirement-wording change (controls staying visible in last-played state) was explicitly confirmed with the user as an intentional revision of HOME-02, not scope creep.
