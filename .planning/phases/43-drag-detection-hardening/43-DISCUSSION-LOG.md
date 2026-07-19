# Phase 43: Drag Detection Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 43-Drag Detection Hardening
**Areas discussed:** False-trigger scenarios, Verification strictness, Latency trade-off

---

## Area selection

| Option | Description | Selected |
|--------|-------------|----------|
| Weitere False-Trigger-Szenarien | Other situations besides plain click where the picker false-opens | ✓ |
| Verifikations-Strenge | How rigorous the on-device confirmation should be | ✓ |
| Latenz-Trade-off beim echten Drag | Whether a barely-perceptible delay on the real-drag path is acceptable | ✓ |
| Keine davon — direkt planen lassen | Skip discussion, go straight to research/planning | ✓ (selected alongside the above — interpreted as "keep it lean", not "skip entirely") |

---

## Weitere False-Trigger-Szenarien

| Option | Description | Selected |
|--------|-------------|----------|
| Nur einfacher Klick | Only observed on plain click | |
| Fenster/Drag über den Notch ziehen | Also happens when dragging a window or non-file drag over the notch | ✓ |
| Trackpad-Gesten in Notch-Nähe | Trackpad gestures near the notch trigger it | |
| Unsicher / noch nie bewusst getestet | Only noticed via click, never systematically tested other triggers | |

**User's choice:** Any drag near the notch (window or file) expands the island. Free-text addition: the false-trigger shows the standard expanded view, NOT the 3 Quick Action buttons — and the island stops auto-collapsing on its own afterward (only closes on a manual click).
**Notes:** This surfaced a second symptom (no auto-collapse) not originally listed in the ROADMAP success criteria.

**Follow-up — Scope of the auto-collapse symptom:**

| Option | Description | Selected |
|--------|-------------|----------|
| Gleicher Bug, gleicher Fix | Same bug, expected to resolve once the false-trigger arm condition is fixed | ✓ |
| Separates Problem, aber trotzdem in Phase 43 fixen | Possibly a separate grace-collapse bug, but still fix in this phase | |
| Nur der False-Trigger jetzt, Auto-Close separat | Defer auto-collapse fix to a later phase/quick-fix | |

**User's choice:** Gleicher Bug, gleicher Fix.

---

## Verifikations-Strenge

| Option | Description | Selected |
|--------|-------------|----------|
| Kurzer manueller Check | Simple pass: click, hover, real Finder drag | ✓ |
| Explizite UAT-Checkliste im Plan | Structured multi-scenario on-device UAT task, mirroring the CR-01 hot-zone fix | |

**User's choice:** Kurzer manueller Check.

---

## Latenz-Trade-off beim echten Drag

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, unmerkliche Verzögerung ist okay | An imperceptible delay on the real-drag trigger is fine | ✓ |
| Muss exakt so instant bleiben wie heute | Real-drag trigger must stay exactly as instant as today | |

**User's choice:** Ja, unmerkliche Verzögerung ist okay.

---

## Claude's Discretion

- Exact mechanism for gating `.dragEntered` on genuine drag content (e.g. requiring `dragPasteboardChangeCount` to actually change for this gesture) — left to research/planning.
- Whether the auto-collapse regression needs an explicit separate code change or resolves as a side effect of the false-trigger gate — left to research/planning.

## Deferred Ideas

None — discussion stayed within phase scope.
