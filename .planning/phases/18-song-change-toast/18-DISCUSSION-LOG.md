# Phase 18: Song-Change Toast - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 18-song-change-toast
**Areas discussed:** Toast content, Priority vs Charging/Device, Rapid track skips, Manual-expand interaction

---

## Toast content

| Option | Description | Selected |
|--------|-------------|----------|
| Title only | Just the new track's title, matches ROADMAP wording, minimal | |
| Title + artist | Two-field content, e.g. "Blinding Lights — The Weeknd", more informative | ✓ |

**User's choice:** Title + artist
**Notes:** Exact layout (one line vs two, styling) left to the UI phase.

---

## Priority vs Charging/Device

| Option | Description | Selected |
|--------|-------------|----------|
| Skip it | Toast is dropped if charging/device splash is active, no new queueing logic | ✓ |
| Queue it | Toast joins TransientQueue, shows after current splash finishes | |
| Show immediately, interrupt | Toast preempts the active splash | |

**User's choice:** Skip it
**Notes:** Charging/device already outrank Now Playing ambient in `resolve(...)` — skip-it is the natural behavior if the toast stays outside `ActiveTransient`/`TransientQueue`.

---

## Rapid track skips

| Option | Description | Selected |
|--------|-------------|----------|
| Restart timer, show latest | Each new change replaces content and restarts the ~3s timer | ✓ |
| Queue each change | Every skip gets its own full ~3s toast, shown in sequence | |

**User's choice:** Restart timer, show latest
**Notes:** Mirrors `TransientQueue.updateHead()`'s in-place-refresh precedent.

---

## Manual-expand interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress it | Toast doesn't play if notch is already expanded — expanded card already shows the new track | ✓ |
| Show it anyway | Toast plays regardless of expand state | |

**User's choice:** Suppress it
**Notes:** Mirrors Phase 17's D-03 ambient-only gate surface precedent.

---

## Claude's Discretion

- Exact mechanism for detecting a "genuine" change (likely `isSameTrack(_:_:)` reuse).
- Whether the toast is a new `IslandPresentation` case, a sub-state, or a separate `@Published` flag.
- Exact timer/dismiss mechanism (Timer vs scheduled dispatch, following existing `scheduleMediaDismiss` precedent).
- Settings toggle default value and wording — defaulted to "on" (matches existing `nowPlayingKey` default) absent discussion.

## Deferred Ideas

None — discussion stayed within phase scope.
