# Phase 8: Fullscreen-Enter Flash Elimination - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-04
**Phase:** 8-fullscreen-enter-flash-elimination
**Areas discussed:** Private-API risk tolerance, Escalation fallback if truly unfixable, On-device trigger-method coverage, Investigation depth before declaring escalation

---

## Private-API risk tolerance

| Option | Description | Selected |
|--------|-------------|----------|
| Same tier as existing | Undocumented but stable-looking CGS/SkyLight symbols and private distributed notifications are fine — same risk class as what's already shipped (CGSCopyManagedDisplaySpaces, mediaremote-adapter). No dlopen'ing random frameworks or patching system binaries. | ✓ |
| Conservative — public APIs only | Only use official NSWorkspace/AppKit notifications and existing detection; go straight to escalation if no public signal exists. | |
| No ceiling — whatever it takes | Try anything, including more exotic private hooks, even if riskier or more fragile across macOS versions. | |

**User's choice:** Same tier as existing
**Notes:** Consistent with the project's existing acceptance of private-API risk (MediaRemote via mediaremote-adapter, CGS Spaces probe) — the app ships direct+notarized, never App Store, so this isn't a new risk category.

---

## Escalation fallback if truly unfixable

| Option | Description | Selected |
|--------|-------------|----------|
| No code change + report | Revert/discard exploratory code, leave today's v1.0 reactive behavior as-is, and produce a written root-cause escalation report for the user to make the call. | ✓ |
| Ship best mitigation + report | Ship whatever measurably reduces the flash (clearly labeled as a mitigation, not a fix) alongside the escalation report, as long as it doesn't regress existing hide/restore behavior. | |

**User's choice:** No code change + report
**Notes:** Matches REQUIREMENTS.md's explicit exclusion of "best-effort/partial mitigation" as a shipped outcome — the phase either eliminates the flash for real, or ships nothing plus an escalation report.

---

## On-device trigger-method coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Minimum set only | Green-button click, View > Enter Full Screen menu, and a fullscreen video app (QuickTime/Safari). | ✓ |
| Expanded matrix | Also test Cmd+Ctrl+F, Zoom/Slack call fullscreen, and Keynote presenter mode. | |

**User's choice:** Minimum set only
**Notes:** Matches ROADMAP.md's "at minimum" wording — no expansion for this polish phase.

---

## Investigation depth before declaring escalation

| Option | Description | Selected |
|--------|-------------|----------|
| Must find ≥1 genuinely new private-API candidate before escalating | The researcher must identify and on-device test at least one concrete NEW private/low-level signal not already ruled out in the debug history — not just re-confirm the old finding. Only escalate after that specific avenue is tried and fails. | ✓ |
| Open-ended — researcher's judgment | Let the researcher decide when confident nothing new exists, no fixed minimum. | |

**User's choice:** Must find ≥1 genuinely new private-API candidate before escalating
**Notes:** This flash was already deep-dived twice (Phase 2 root-cause, Phase 6 re-confirmation) with the same conclusion using public APIs. Given the private-API ceiling just set, escalation is only valid after a genuinely new avenue (e.g. a CGS/SkyLight Space-transition-start notification) has actually been tried on-device and failed — not a restatement of the prior conclusion.

---

## Claude's Discretion

- Exact private-API candidate(s) to try (e.g. which CGS/SkyLight notification name, if one exists) — research work, not a user decision.
- Whether to consult prior-art from reference apps (e.g. boring.notch) on how they handle this — left to the researcher's judgment within the "same tier as existing" ceiling.

## Deferred Ideas

None — discussion stayed entirely within phase scope.
