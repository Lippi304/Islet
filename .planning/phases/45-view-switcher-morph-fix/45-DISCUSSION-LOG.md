# Phase 45: View Switcher Morph Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 45-view-switcher-morph-fix
**Areas discussed:** Interrupted mid-morph tapping, Transition feel, 12-pairwise verification rigor

---

## Todo cross-reference (pre-discussion)

| Todo | Score | Outcome |
|------|-------|---------|
| Island briefly disappears during click-through | 0.9 | Reviewed, not folded — different code path (click-through hot-zone vs. tab-morph); stays deferred for its own `/gsd-debug` session |
| Quick Action disabled state has no controller gate | 0.7 | Reviewed, not folded — out of domain (button enablement gating) |

---

## Interrupted mid-morph tapping

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect immediately | Spring retargets on the fly toward the new tab — standard SwiftUI spring behavior, most responsive | ✓ |
| Ignore until settled | Taps during an in-flight morph are dropped | |
| Queue the tap | Current morph finishes, then queued tap's transition starts | |

**User's choice:** Redirect immediately
**Notes:** No follow-up — resolved in one question.

---

## Transition feel

| Option | Description | Selected |
|--------|-------------|----------|
| Same spring as expand/collapse | Reuses existing `.spring(response:dampingFraction:)` parameters — consistent feel app-wide | ✓ |
| Snappier for tab switches | Distinct faster/tighter spring specifically for tab-to-tab morphs | |
| You decide | No strong preference | |

**User's choice:** Same spring as expand/collapse
**Notes:** No follow-up — resolved in one question.

---

## 12-pairwise verification rigor

| Option | Description | Selected |
|--------|-------------|----------|
| All 12 pairs, explicitly | Walk every Home↔Tray↔Calendar↔Weather combination — matches ROADMAP wording literally | ✓ |
| Representative sample | Check size-direction extremes + one adjacent/non-adjacent pair, same style as Phase 43/44 | |

**User's choice:** All 12 pairs, explicitly
**Notes:** Diverges from Phase 43/44's lighter-touch verification precedent — user explicitly wants full pairwise coverage for this phase.

---

## Claude's Discretion

- Exact mechanism for making `presentationSwitch`'s tab cases participate in one continuous morph (restructuring approach) — left to research/planning.
- Whether the interrupted-mid-morph retarget (D-01) needs explicit animation-cancellation code or falls out of the structural fix — left to research/planning.

## Deferred Ideas

None — discussion stayed within phase scope. Both matched todos (click-through disappearing bug, Quick Action disabled-state gate) were reviewed and confirmed out of domain rather than folded in.
