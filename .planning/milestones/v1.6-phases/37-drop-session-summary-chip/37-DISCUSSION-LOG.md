# Phase 37: Drop-Session Summary Chip - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-16
**Phase:** 37-drop-session-summary-chip
**Areas discussed:** Session boundary definition, File count semantics, Chip visual design, Suppression & interaction rules

---

## Session boundary definition

| Option | Description | Selected |
|--------|-------------|----------|
| Island fully collapses | Whole expanded island collapses back to idle pill while Tray was selected | ✓ |
| Switching tabs away from Tray | Selecting another tab while island stays expanded already counts as closing | |
| Either one, whichever first | Both trigger surfaces wired | |

**User's choice:** Island fully collapses (Recommended)
**Notes:** Matches the literal ROADMAP wording — Tray visually disappears along with everything else.

| Option | Description | Selected |
|--------|-------------|----------|
| Right when the island collapses | Session boundary resets immediately at the collapse moment | ✓ |
| On the next file drop after a close | Counter doesn't reset until a new drop actually occurs | |

**User's choice:** Right when the island collapses (Recommended)
**Notes:** Any file dropped after the collapse belongs to a fresh session regardless of whether the chip is still showing.

---

## File count semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Gross — total ever appended | Counts every successful append() during the session | ✓ |
| Net — what's left in the shelf now | Counts current item count at close time | |

**User's choice:** Gross — total ever appended (Recommended)
**Notes:** "N files saved" reflects what actually got dropped in, independent of mid-session deletes/clears.

---

## Chip visual design

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Phase 18's toast verbatim | Same fading text row, same mechanics | ✓ |
| Same mechanics, own text/icon treatment | Reuse infrastructure, distinct visual (e.g. icon) | |

**User's choice:** Reuse Phase 18's toast verbatim (Recommended)
**Notes:** ROADMAP explicitly calls for reusing the Phase-18 pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Proper grammar: "1 file saved" / "N files saved" | Standard English pluralization | ✓ |
| Always plural: "N files saved" even for N=1 | Simpler string, no branching | |

**User's choice:** Proper grammar (Recommended)

---

## Suppression & interaction rules

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, identical rules to Phase 18 | Reuses songChangeToastGate's exact logic | ✓ |
| Different rule: always show once collapsed, even mid-transient | Chip queues/shows even during a Charging/Device splash | |

**User's choice:** Yes, identical rules (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Chip dismisses immediately on re-expand | Same as today's D-02 Charging/Device-interrupts-toast precedent | ✓ |
| Chip keeps playing over the re-expanded island | Independent timer keeps running regardless | |

**User's choice:** Chip dismisses immediately, island expands normally (Recommended)

---

## Claude's Discretion

- Where the new session-boundary state lives in code (field on `ShelfCoordinator`, new struct, or folded into `ShelfViewState`).
- Exact mechanism for tracking the gross append count per session (running counter vs. session-start snapshot diff).
- Naming of the new state/field and the chip's own `@Published` type.

## Deferred Ideas

None — discussion stayed entirely within phase scope.
