# Phase 39: Volume & Brightness HUD - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 39-Volume & Brightness HUD
**Areas discussed:** Level-indicator visual style, Accessibility permission UX, Scrubbing / auto-dismiss timing, Volume↔Brightness↔Focus priority

---

## Level-Indicator Visual Style

| Option | Description | Selected |
|--------|-------------|----------|
| Droppy-style filled bar | Icon left, horizontal filled progress bar right, no numeric % — matches the user's own reference screenshot | ✓ |
| Phase 36 icon+label convention | Icon+text left, value indicator right — consistent with Charging/Device/Focus | |
| Icon + numeric percentage | Icon left, "73%" text right — simplest to implement | |

**User's choice:** Droppy-style filled bar (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed colors, matching reference | Volume=green, Brightness=orange/yellow, never accent-tinted | ✓ |
| Accent-tinted | Both bars use the chosen accent color | |
| Icon fixed, bar accent-tinted | Middle ground | |

**User's choice:** Fixed colors, matching reference (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Icon swaps to speaker.slash + empty bar | Matches native macOS OSD's muted treatment | ✓ |
| Just an empty bar, icon unchanged | Simpler, less clear | |

**User's choice:** Icon swaps to speaker.slash + empty bar (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Smooth spring animation | Matches the project's "liquid island" feel | ✓ |
| Instant snap, no animation | Simpler, more "responsive"-feeling | |

**User's choice:** Smooth spring animation (recommended).

---

## Accessibility Permission UX

| Option | Description | Selected |
|--------|-------------|----------|
| Opt-in Settings toggle | Mirrors Focus Mode's D-01, OFF by default | ✓ |
| Silent automatic request | DropInterceptTap-style, no toggle | |

**User's choice:** Opt-in Settings toggle (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| HUD still shows, alongside native OSD | Only suppression is gated by the permission | ✓ |
| Feature goes fully inert until granted | Mirrors Focus's D-04 exactly | |

**User's choice:** HUD still shows, alongside native OSD (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Detect and start automatically | Reuse DropInterceptTap's 5s health-check-timer pattern | ✓ |
| Require toggling off/on again | Simpler, no polling loop | |

**User's choice:** Detect and start automatically (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same pattern as Focus | Explanation + deep-link via x-apple.systempreferences: | ✓ |
| No, just call AXIsProcessTrustedWithOptions | Simpler, relies on system prompt | |

**User's choice:** Yes, same pattern as Focus (recommended).

---

## Scrubbing / Auto-Dismiss Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Reset the 3s timer on every press | Matches native OSD's stay-up-while-pressing feel | ✓ |
| Keep today's behavior (no re-arm) | Matches Charging's existing updateHead() contract | |

**User's choice:** Reset the timer on every press (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the shared 3s duration | Consistent with every other HUD | |
| Shorter, ~1-1.5s | Matches native OSD's snappier feel | ✓ |

**User's choice:** Shorter duration (recommended, contrary to the initial "keep 3s" recommendation — user preferred matching native OSD feel).

| Option | Description | Selected |
|--------|-------------|----------|
| 1.0 second | Closest to native OSD | |
| 1.5 seconds | Slightly more forgiving | ✓ |
| You decide | Leave to Claude's judgment | |

**User's choice:** 1.5 seconds (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed-pill-only, like Focus | Expanding the island isn't blocked | ✓ |
| Full takeover, like Charging/Device | Simpler resolver rule, blocks expanded view | |

**User's choice:** Collapsed-pill-only, like Focus (recommended).

---

## Volume↔Brightness↔Focus Priority

| Option | Description | Selected |
|--------|-------------|----------|
| Brightness replaces Volume immediately | Cross-category instant replace, mirrors native OSD | ✓ |
| Queue behind it, like Charging/Device | Never overlapping, but laggy when alternating keys | |

**User's choice:** Brightness replaces Volume immediately (recommended).

| Option | Description | Selected |
|--------|-------------|----------|
| New rank 4, below Focus | Charging/Device (1/2) → Focus (3) → Volume/Brightness (4) | ✓ |
| New rank 3, above Focus | Volume/Brightness interrupt Focus like Charging/Device do | |

**User's choice:** New rank 4, below Focus (recommended).

**Follow-up flagged by Claude:** Because Focus is `isPersistent` (never self-elapses) and `TransientQueue.advance()` only promotes a queued item when the head elapses, a plain `enqueue()` behind Focus would mean Volume/Brightness never display while Focus is active (queued indefinitely). Surfaced as a clarifying question rather than silently locking in a broken-feeling behavior.

| Option | Description | Selected |
|--------|-------------|----------|
| Briefly preempt Focus too, then restore it | Reuse Phase 38's TransientQueue.preempt() mechanism | ✓ |
| Accept the queue-forever behavior as scoped | Simpler, but no HUD feedback during a Focus session | |

**User's choice:** Briefly preempt Focus too, then restore it (recommended).

---

## Claude's Discretion

- Whether Volume and Brightness are modeled as one shared `ActiveTransient` case (e.g. `.osd(OSDActivity)`) or two separate cases — affects how cleanly D-12's instant-mutual-replace requirement is satisfied.
- Exact mechanism for reading live system volume/brightness levels (no existing code in this project to reuse; brightness reading in particular is under-researched for Apple Silicon internal displays).
- Naming of new Monitor/interceptor/Activity types.
- Whether the new Settings toggle gets its own row or joins Focus's existing toggle area.

## Deferred Ideas

None — discussion stayed within phase scope throughout.
