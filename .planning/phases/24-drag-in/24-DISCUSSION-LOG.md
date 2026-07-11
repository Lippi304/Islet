# Phase 24: Drag-In - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-11
**Phase:** 24-Drag-In
**Areas discussed:** Approach sensitivity / feel, Validation strategy given 2 prior failures, Reliability bar / fallback plan, Carrying forward Phase 22's locked decisions

---

## Approach sensitivity / feel

| Option | Description | Selected |
|--------|-------------|----------|
| Wide/early | React as soon as the drag enters a generously-sized top-of-screen zone, well before reaching the pill — mirrors Phase 22's D-02b widened-zone philosophy | ✓ |
| Narrow/precise | React only once the pointer is directly over/near the collapsed pill — risks repeating Phase 22's original tiny-hot-zone problem | |
| You decide | Claude/research picks based on what the detector can reliably measure | |

**User's choice:** Wide/early (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Phase 22's geometry | expandedZone + landing margin was already carefully designed around the Mission-Control problem; zone size was never invalidated, only the AppKit delivery mechanism | ✓ |
| Redesign from scratch | New mechanism might allow a cleaner distance-based radius instead of a rect | |
| You decide | Let research propose based on the new mechanism | |

**User's choice:** Reuse Phase 22's geometry (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Single-stage, reuse as-is | Phase 22's D-03/D-06 already locked this — reuse existing hover bounce/scale spring | ✓ |
| Two-stage (approach + accept) | Adds a subtle early cue while approaching, escalating to bounce once in the accept zone | |

**User's choice:** Single-stage, reuse as-is (Recommended)
**Notes:** Confirmed "fully settled, nothing to add" when revisited during the Carrying-forward area.

---

## Validation strategy given 2 prior failures

| Option | Description | Selected |
|--------|-------------|----------|
| Isolated spike first | Mirror Phase 22-01: build a minimal spike, verify on-device before building full accept/shelf-landing logic | ✓ |
| Build full feature directly | Trust research to design it well and build in one pass | |
| You decide | Let planner/researcher choose based on remaining uncertainty | |

**User's choice:** Isolated spike first (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Up to 2 rounds | One implementation attempt + one fix-and-retry round, matching what Phase 22 actually did | ✓ |
| Keep iterating until it works | No fixed cap | |
| You decide | Claude judges based on how debugging is going | |

**User's choice:** Up to 2 rounds (Recommended)

---

## Reliability bar / fallback plan

| Option | Description | Selected |
|--------|-------------|----------|
| Reliable, graceful degrade on rare misses | Common case works consistently; occasional missed drop OK if it fails silently (no crash, no frozen state) | ✓ |
| Must be flawless | Every single attempt must succeed, no tolerance for misses | |
| You decide | Claude judges the bar once trial results are in | |

**User's choice:** Reliable, graceful degrade on rare misses (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Stop and return to discuss-phase | Same pattern as Phase 22: abort, bring findings back to the user | ✓ |
| Ship with known caveats | Land whatever works best after 2 rounds, document the caveat | |
| You decide | Claude judges based on how close the mechanism got | |

**User's choice:** Stop and return to discuss-phase (Recommended)

---

## Carrying forward Phase 22's locked decisions

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, keep collapsed-only | Matches ROADMAP Success Criteria #1 literally | |
| Reconsider — also accept while expanded | New capability beyond scope | ✓ (initial pick) |

**User's choice:** Initially picked "Reconsider — also accept while expanded." Flagged as scope creep (new capability beyond ROADMAP Success Criteria #1 / SHELF-01/02 wording) and re-asked with a scope-explicit framing.

**Follow-up scope question:**

| Option | Description | Selected |
|--------|-------------|----------|
| Keep collapsed-only for Phase 24 | Stay within locked ROADMAP/REQUIREMENTS wording; note expanded-state drops as a deferred idea | ✓ |
| Expand Phase 24 scope now | Formally add expanded-state drop acceptance to this phase's goal | |

**User's choice:** Keep collapsed-only for Phase 24 (Recommended)
**Notes:** "Accept drops while expanded" captured as a deferred idea for a future phase, not built here.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, keep auto-expand-on-approach | Consistent with the wide/early sensitivity decision | ✓ |
| Reconsider — expand only after drop completes | Contradicts wide/early sensitivity decision | |

**User's choice:** Yes, keep auto-expand-on-approach (Recommended)

**Drop ordering follow-up:**

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as Claude's discretion | Follows existing Phase 19 D-06 append-in-drop-order convention | ✓ |
| Lock it explicitly now | State a specific ordering rule here | |

**User's choice:** Keep as Claude's discretion (Recommended)

---

## Claude's Discretion

- Exact AppKit/Foundation mechanism for the `DragApproachDetector` (which `NSEvent` types, how to read the systemwide drag pasteboard without `NSDraggingDestination`)
- How "active drag session" state routes through the single `syncClickThrough()` arbiter
- Multi-file/folder drag ordering (follows Phase 19 D-06, append in drop order)
- Behavior for non-file drag content (no-drop/reject)
- Behavior when a Charging/Device splash is suppressing the shelf during a drag attempt (silent no-op precedent)
- Exact landing-margin value below the top edge

## Deferred Ideas

- Accepting drag-in while the island is already expanded (Now Playing, idle glance, open shelf) — new capability beyond Phase 24's ROADMAP scope; candidate for a future phase/requirement.
