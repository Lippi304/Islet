# Phase 61: Download-Progress - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-23
**Phase:** 61-Download-Progress
**Areas discussed:** Queue placement & persistence, Concurrent downloads, HUD content & visuals, Done-state timing

---

## Queue placement & persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Rank 5, above CapsLock/Update (below OSD) | An active download feels more like real ongoing work than a lightweight caps-lock toggle or update ping — pushes CapsLock/Update down to rank 6/7 | ✓ |
| Rank 7, lowest of all | Follows Phase 60's own "newest feature = lowest rank" rationale verbatim | |
| You decide | Claude picks based on codebase convention | |

**User's choice:** Rank 5, above CapsLock/Update (below OSD)

| Option | Description | Selected |
|--------|-------------|----------|
| Full duration, no cap | Matches the "presence + completion signal only" requirement | ✓ |
| Cap visible time (e.g. ~10s) even mid-download | Avoids one long download hogging the island indefinitely | |
| You decide | Claude picks based on precedent and simplicity | |

**User's choice:** Full duration, no cap

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed-only | Matches Focus/OSD/CapsLock/Update precedent exactly | ✓ |
| Also shown in expanded Home view | New precedent — more visible, needs new UI work | |
| You decide | Claude picks based on precedent | |

**User's choice:** Collapsed-only

| Option | Description | Selected |
|--------|-------------|----------|
| User gesture cuts it short | Matches the existing Charging/Device precedent (D-11) | ✓ |
| Keeps running in background | Done-state timer keeps counting even while expanded | |
| You decide | Claude picks based on precedent | |

**User's choice:** User gesture cuts it short

---

## Concurrent downloads

| Option | Description | Selected |
|--------|-------------|----------|
| Show only the most recent one | Simplest — newest download replaces the display of any still-in-progress older one | ✓ |
| Aggregate count ("2 downloads") | Shows a generic count once more than one is active | |
| Queue them one after another | Reuses the existing TransientQueue pending/FIFO mechanism | |

**User's choice:** Show only the most recent one

| Option | Description | Selected |
|--------|-------------|----------|
| Per-file tracking | Needed for SC3's "each detected as one logical download apiece" | ✓ |
| Single global flag | Simpler, but one long download could mask a second one's completion | |
| You decide | Claude picks the simplest approach that still satisfies SC3 | |

**User's choice:** Per-file tracking

| Option | Description | Selected |
|--------|-------------|----------|
| ~/Downloads only | Matches ROADMAP.md's exact wording and DL-01/DL-02 | ✓ |
| User-configurable folder in Settings | New scope beyond what's written | |

**User's choice:** ~/Downloads only

| Option | Description | Selected |
|--------|-------------|----------|
| Temp-suffix matching is enough | Matches SC3's wording exactly | ✓ |
| Add extra filtering (hidden files, size thresholds, etc.) | More defensive, adds complexity not requested | |

**User's choice:** Temp-suffix matching is enough

---

## HUD content & visuals

| Option | Description | Selected |
|--------|-------------|----------|
| Show the filename (truncated to fit) | More informative | |
| Generic "Downloading…" label | Simpler, avoids truncation/overflow edge cases | ✓ |

**User's choice:** Generic "Downloading…" label

| Option | Description | Selected |
|--------|-------------|----------|
| Indeterminate/pulsing bar | Closest to Droppy's reference look | |
| Simple spinner icon | Reuses a standard system spinner, less custom UI | ✓ |
| You decide | Claude picks based on the UI-SPEC phase's design pass | |

**User's choice:** Simple spinner icon

| Option | Description | Selected |
|--------|-------------|----------|
| No tap action (purely informational) | Matches Charging/Device/Focus/OSD/CapsLock | ✓ |
| Tap reveals the file in Finder | New interactive behavior | |

**User's choice:** No tap action (purely informational)

| Option | Description | Selected |
|--------|-------------|----------|
| Same filename + checkmark/done icon | Consistent with in-progress state, shows which file finished | ✓ |
| Generic "Download complete" message | Simpler, doesn't need to keep the filename | |
| You decide | Claude picks based on what the in-progress label decision implies | |

**User's choice:** Same filename + checkmark/done icon
**Notes:** Deliberately asymmetric with the in-progress label — generic while downloading, real filename once renamed at completion.

---

## Done-state timing

| Option | Description | Selected |
|--------|-------------|----------|
| ~3s (Charging/Device convention) | Matches the shared uniform auto-dismiss timer most transients already use | ✓ |
| ~1.5s (OSD convention) | Matches OSD's own shorter self-elapsing timer | |
| You decide | Claude picks based on precedent and what reads best | |

**User's choice:** ~3s (Charging/Device convention)

| Option | Description | Selected |
|--------|-------------|----------|
| Silently skip if missed | Simplest — FSEvents only reports events while running | ✓ |
| Show done state on catch-up | More complete, adds complexity for a low-value edge case | |

**User's choice:** Silently skip if missed

| Option | Description | Selected |
|--------|-------------|----------|
| Silently disappear, no done state | Matches DL-02's exact wording | ✓ |
| Show a distinct "cancelled" state | New scope beyond DL-01/DL-02 | |

**User's choice:** Silently disappear, no done state

---

## Claude's Discretion

- Exact spinner styling/animation timing (SwiftUI system spinner vs. a small custom one).
- Internal `DownloadActivityState`/monitor class naming and file layout.

## Deferred Ideas

None raised during this discussion. Three todo matches were reviewed (`2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) but were keyword-only false positives, not folded into scope.
