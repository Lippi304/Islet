# Phase 57: Pasteboard Monitor — Spike - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 57-Pasteboard Monitor — Spike
**Areas discussed:** Pasteboard-access prompt UX, Concealed-type test source, On-device verification approach

---

## Pasteboard-access prompt UX

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal placeholder | A simple NSAlert/console message proving the accessBehavior check + one-time gate mechanism works; Phase 58 replaces it with final polished copy. | ✓ |
| Full final copy now | Write real user-facing explanation text/UI in this phase since SC#4 says "handled gracefully." | |
| You decide | Claude picks based on what fits the spike scope. | |

**User's choice:** Minimal placeholder (recommended)
**Notes:** Mirrors Phase 56's spike-first precedent — this phase proves the mechanism, not the final UX.

---

## Concealed-type test source

| Option | Description | Selected |
|--------|-------------|----------|
| Real password manager on this Mac | Test against whatever's actually installed (1Password, Bitwarden, LastPass, etc.). | |
| Simulated via debug spike-hook | A DEBUG-only hook manually writes an NSPasteboardItem tagged org.nspasteboard.ConcealedType — guaranteed reproducible. | ✓ |
| Both | Spike-hook for guaranteed coverage, plus a real app as a bonus check if installed. | |

**User's choice:** Simulated via debug spike-hook (recommended)
**Notes:** Doesn't depend on what password manager (if any) is installed on the test Mac; mirrors Phase 56's spike-hook pattern.

---

## On-device verification approach

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same pattern | DEBUG-only spike hooks in the existing debug menu, feeding a throwaway/in-memory sink, not the real persisted store. | ✓ |
| Wire into the real ClipboardStore now | Test copies would persist into real history, needing manual clearing before Phase 58 ships. | |
| You decide | Claude picks the verification wiring approach during planning. | |

**User's choice:** Yes, same pattern (recommended)
**Notes:** Matches Phase 56's proven DEBUG-hook + human-checkpoint precedent; zero Release-build footprint.

---

## Claude's Discretion

- Self-capture guard mechanism (marker pasteboard type vs. boolean flag) — research recommends Maccy's marker-type approach as more robust; Claude implements per that recommendation.
- Exact spike-hook naming/wiring shape in the debug menu — mirrors Phase 56-02's naming convention.

## Deferred Ideas

None — discussion stayed within phase scope.
