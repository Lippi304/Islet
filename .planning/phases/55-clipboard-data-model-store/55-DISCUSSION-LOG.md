# Phase 55: Clipboard Data Model + Store - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 55-Clipboard Data Model + Store
**Areas discussed:** Cap-Zahl (20-30), Duplikat-Verhalten, Übergroße Inhalte

---

## Cap-Zahl (20-30)

| Option | Description | Selected |
|--------|-------------|----------|
| 20 | Lower bound of the "~20-30" range from PROJECT.md/ROADMAP.md — leaner history, less memory/encryption overhead in Phase 56 | |
| 30 | Upper bound of the range — more visible history, closer to typical clipboard managers | ✓ |
| 25 | Midpoint, if neither bound mattered | |

**User's choice:** 30
**Notes:** No further questions — moved directly to next area.

---

## Duplikat-Verhalten

| Option | Description | Selected |
|--------|-------------|----------|
| Move to top | Existing entry found and moved to the top with a fresh timestamp, no duplicate — typical clipboard-manager behavior (Maccy) | ✓ |
| Add as new entry | Every copy creates a new entry even if content is identical — simplest append logic, no equality check needed | |
| Ignore (no-op) | Matches Shelf's current `append()` behavior — duplicate silently dropped, existing entry stays in place | |

**User's choice:** Move to top
**Notes:** Explicitly diverges from Shelf's existing no-op dedupe behavior — Shelf's pattern was surfaced as the "closest existing precedent" but the user chose different, more clipboard-manager-idiomatic behavior instead.

---

## Übergroße Inhalte

| Option | Description | Selected |
|--------|-------------|----------|
| Store unconstrained | No size limit in Phase 55 — simplest logic, no existing precedent for per-item size limits in the codebase; Phase 56 encrypts/persists everything regardless of size | ✓ |
| Hard per-item limit | Items over a fixed byte threshold rejected outright (`Store.append` returns false/nil) — prevents a single giant screenshot from blowing up memory/disk | |

**User's choice:** Store unconstrained
**Notes:** User treated this as a hypothetical not worth designing around now; revisit only if it becomes a real problem in practice.

---

## Claude's Discretion

- `ClipboardItem`'s text/image `Kind` enum shape (associated-value design) — no existing precedent in the codebase to defer to; Claude designs during planning.
- Internal list ordering direction (append-at-end vs prepend-at-front) — only the observable newest-first/oldest-evicted-first contract matters.
- Equality-check mechanics for duplicate detection (exact string match for text, byte match for image `Data`).

## Deferred Ideas

None raised during discussion. Three keyword-matched todos (Quick Action controller gate, Calendar month-grid polish, Island click-through disappearance) were reviewed against phase scope and judged unrelated (UI-domain issues, not clipboard data model) — not presented to the user, noted in CONTEXT.md's Deferred section for the record.
