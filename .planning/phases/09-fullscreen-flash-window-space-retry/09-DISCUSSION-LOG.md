# Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-04
**Phase:** 09-fullscreen-flash-window-space-retry
**Areas discussed:** Private-API-Risikoumfang für Candidate C, Regressions-Absicherung der Architektur-Änderung, Eskalationspfad falls C und B beide scheitern, Umfang der On-Device-Trigger-Matrix

---

## Private-API-Risikoumfang für Candidate C

| Option | Description | Selected |
|--------|-------------|----------|
| Gleicher Rahmen wie bisher | Same @_silgen_name symbol-binding tier as existing private API usage — no extra gate | ✓ |
| Erst kurz zeigen, dann freigeben | Confirm the concrete approach explicitly before code is written | |
| Nicht weiter als Candidate B falls C riskant wirkt | Switch to Candidate B directly if Space management proves fragile during research | |

**User's choice:** Gleicher Rahmen wie bisher
**Notes:** Consistent with the project's existing MediaRemote/CGS private-API risk acceptance (direct+notarized distribution, never App Store).

| Option | Description | Selected |
|--------|-------------|----------|
| Nur die 4 genannten CGS-Funktionen | CGSSpaceCreate, CGSSpaceSetAbsoluteLevel, CGSAddWindowsToSpaces, CGSRemoveWindowsToSpaces — nothing more | ✓ |
| Alles was Atoll/boring.notch auch nutzt | Anything the reference project uses is acceptable, even beyond the 4 functions | |
| Keine harte Grenze, Claude entscheidet | Left to researcher/planner judgment, mirroring D-02's "no dlopen, no binary patching" ceiling | |

**User's choice:** Nur die 4 genannten CGS-Funktionen
**Notes:** Needing additional private mechanisms beyond these 4 is treated as a stop signal — fall back to Candidate B or escalate rather than expanding the private-API surface further.

---

## Regressions-Absicherung der Architektur-Änderung

| Option | Description | Selected |
|--------|-------------|----------|
| Volle Kernverhaltens-Suite | Hover/click focus-safety, click-through, multi-Space visibility, positioning across clamshell/display changes, fullscreen hide/restore | ✓ |
| Nur Fullscreen-bezogenes | Limit to flash-elimination + hide/restore correctness only | |
| Claude entscheidet den Testumfang | Planner/executor decides scope based on the actual diff | |

**User's choice:** Volle Kernverhaltens-Suite
**Notes:** collectionBehavior is core plumbing touched by nearly every existing phase — full re-verification treated as a targeted re-run of Phase 1/2 UAT points.

| Option | Description | Selected |
|--------|-------------|----------|
| Show-Stopper — muss vollständig sauber sein | Any regression, however small, is fixed before acceptance | ✓ |
| Kleinere Regressionen als Follow-up okay | Minor imperfections may ship as documented follow-up work | |

**User's choice:** Show-Stopper — muss vollständig sauber sein
**Notes:** No known regressions accepted on this component given how many other phases depend on it.

---

## Eskalationspfad falls C und B beide scheitern

| Option | Description | Selected |
|--------|-------------|----------|
| Endgültig — nur noch accept/descope | Final investigation round; escalation limited to accept-as-debt or formal descope | ✓ |
| Tür für einen dritten Kandidaten offenlassen | Escalation could still offer a further "investigate a new candidate" option | |

**User's choice:** Endgültig — nur noch accept/descope
**Notes:** FS-01 will have been root-caused/attempted across Phase 2, 6, 8, and 9 with four distinct candidates by that point.

| Option | Description | Selected |
|--------|-------------|----------|
| Automatisch weiter zu Candidate B | C's on-device failure itself triggers B, no separate checkpoint | ✓ |
| Erst Checkpoint, dann B | Explicit user confirmation required before investing in B's SkyLight/CVDisplayLink setup | |

**User's choice:** Automatisch weiter zu Candidate B
**Notes:** ROADMAP.md already locks B as the designated fallback — no additional decision gate needed between C's failure and B's attempt.

---

## Umfang der On-Device-Trigger-Matrix

| Option | Description | Selected |
|--------|-------------|----------|
| 3 Methoden + normale Space-Wechsel-Regression | Phase 8's 3 fullscreen triggers plus an ordinary (non-fullscreen) Space switch | ✓ |
| Nur die bestehenden 3 Methoden | No addition beyond Phase 8's matrix | |
| Auch externes Display mit aufnehmen | Add an external-display scenario on top of the above | |

**User's choice:** 3 Methoden + normale Space-Wechsel-Regression
**Notes:** The added ordinary Space-switch check is what exercises the "visibility across all Spaces" / "correct positioning" parts of the regression safety net, since Candidate C changes fundamental Space membership.

---

## Claude's Discretion

- Exact implementation shape of the CGS Space wrapper (new file vs. extending `NotchPanel.swift`).
- Whether an external-display trigger scenario should be added to the trigger matrix beyond the ordinary Space-switch check.

## Deferred Ideas

None — discussion stayed within phase scope.
