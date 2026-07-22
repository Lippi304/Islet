# Phase 41: Calendar Countdown HUD - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-18
**Phase:** 41-calendar-countdown-hud
**Areas discussed:** Countdown vs Now-Playing priority, Visual format & urgency, Tap/click behavior, Back-to-back events

---

## Countdown vs Now-Playing priority

| Option | Description | Selected |
|--------|-------------|----------|
| Countdown always wins | Calendar events are commitments, more urgent than a media glance. Now-Playing ambient is simply suppressed while a countdown is active. | ✓ |
| Now-Playing always wins | Zero behavior change for the existing Now-Playing ambient glance. | |
| Countdown wins only near the end | e.g. last 5–10 minutes, otherwise Now-Playing wins. | |

**User's choice:** Countdown always wins.
**Notes:** No time-based nuance requested — a hard, simple override.

| Option | Description | Selected |
|--------|-------------|----------|
| Toast still fires (unchanged) | Song-change toast is orthogonal, already can appear over the idle glance today. | ✓ |
| Suppress toast during Countdown | Avoid two competing attention-grabbers at once. | |

**User's choice:** Toast still fires (unchanged).

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, on by default | Matches Focus/OSD/Charging/Device convention (opt-out, not opt-in). | ✓ |
| Yes, off by default | New/unproven feature, opt-in. | |
| No toggle needed | Always on if Calendar permission granted. | |

**User's choice:** Yes, on by default.

---

## Visual format & urgency

| Option | Description | Selected |
|--------|-------------|----------|
| Minutes only ("23m") | Matches ROADMAP wording, matches Pitfall 7's per-minute timer cadence exactly. | |
| mm:ss ("23:14") | More precise; requires resolving a live per-second display without reopening Pitfall 7's timer-hygiene research. | ✓ |

**User's choice:** mm:ss ("23:14").
**Notes:** Flagged in CONTEXT.md (D-04) as an implementation detail requiring a tightly-gated per-second UI refresh, not a second always-on timer — left to research/planning to resolve the mechanism.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — turns urgent color near the end | Escalating visual treatment in the final ~5 min. | (custom) |
| No — stays consistent the whole hour | One flat visual treatment. | |

**User's choice (free text):** "Ja die letzte Minute soll es rot werden sonst vorher wie auf dem iPhone normal Farbe Orange." (Yes — the last minute it should turn red, otherwise before that, like on the iPhone, normal color orange.)
**Notes:** Explicit reference to the iPhone Dynamic Island Live Activity countdown color convention (orange → red in the final minute). Captured as D-05.

| Option | Description | Selected |
|--------|-------------|----------|
| Icon + time only (per ROADMAP) | Matches ROADMAP wording exactly; title only visible via the Calendar tab. | ✓ |
| Title appears on hover | New hover-reveal interaction, no existing precedent. | |

**User's choice:** Icon + time only (per ROADMAP).

---

## Tap/click behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Expand to Home (default behavior) | Matches Now-Playing's existing ambient click behavior exactly. | ✓ |
| Expand to Calendar tab | Deep-links to the event; new special-case, no other ambient state does this. | |

**User's choice:** Expand to Home (default behavior).

| Option | Description | Selected |
|--------|-------------|----------|
| No hover-reveal | Consistent with icon+time-only decision (D-06). | ✓ |
| Hover reveals event title | New tooltip interaction, no existing precedent. | |

**User's choice:** No hover-reveal.

---

## Back-to-back events

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately re-arm for the next event | Monitor re-checks on every dismiss, never leaves a gap for an imminent next meeting. | ✓ |
| Go idle first, re-check next minute boundary | Simpler — up to ~1 min gap where nothing shows, matches the pure "recompute on minute boundary" design with zero extra logic. | |

**User's choice:** Immediately re-arm for the next event.

---

## Claude's Discretion

- Exact SF Symbol choice for the calendar icon.
- Concrete mechanism for the mm:ss live-refresh (D-04) — must stay consistent with Pitfall 7's minute-boundary scheduling timer while providing a live per-second display, likely via a visibility-gated `TimelineView` (mirrors `EqualizerBars`' existing pattern) rather than a second always-running `Timer`.
- Precise selection function for "next NOT-YET-STARTED event within the 1-hour lookahead" — whether to adapt `nextRelevantEvent()` or add a new pure function (noted in CONTEXT.md canonical_refs).

## Deferred Ideas

None — discussion stayed within phase scope.
