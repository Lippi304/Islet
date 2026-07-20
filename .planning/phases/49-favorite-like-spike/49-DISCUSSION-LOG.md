# Phase 49: Favorite/Like — Spike - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-20
**Phase:** 49-Favorite/Like — Spike
**Areas discussed:** Spotify Developer account readiness, Spotify fallback if quota wall is real, Apple Music test-library coverage, Automation (TCC) bug repro depth

---

## Spotify Developer account readiness

| Option | Description | Selected |
|--------|-------------|----------|
| Already have one | Registered Spotify app/Client ID ready to test against | |
| Need to register one | Spike's first step is creating a Spotify Developer app, setting redirect URI | ✓ |
| Not sure / haven't checked | Claude checks and flags as a spike prerequisite | |

**User's choice:** Need to register one
**Notes:** No existing Spotify Developer app — registration is a spike prerequisite (D-01).

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, ready to test | Usable Spotify account for the round-trip test | ✓ |
| Need to set one up | Note as a spike prerequisite | |

**User's choice:** Yes, ready to test
**Notes:** Account with Premium/regular access is ready (D-02).

---

## Spotify fallback if quota wall is real

| Option | Description | Selected |
|--------|-------------|----------|
| Ship for small allowlist (Recommended) | Matches FAV-02 as already written | ✓ |
| Apple-Music-only for this milestone | Drop Spotify write-back entirely from v1.7 | |
| Bring-your-own-Client-ID | Each user registers their own app | |

**User's choice:** Ship for small allowlist (Recommended)
**Notes:** Confirms FAV-02's existing framing is the user's genuine intent, not an assumption to revisit (D-03).

| Option | Description | Selected |
|--------|-------------|----------|
| Good enough as-is | Small personal/friends allowlist is fine | |
| Only worth it if it can scale later | Want implementation shaped so Extended Quota/BYO-Client-ID can be added later without a rewrite | ✓ |

**User's choice:** Only worth it if it can scale later
**Notes:** Forward-compatibility constraint for Phase 50's design (D-04) — not a Phase 49 deliverable itself.

---

## Apple Music test-library coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both available | Library and streaming-only tracks both testable | ✓ |
| Only library tracks readily available | May need to play a streaming track during spike | |
| Not sure what counts as streaming-only | Claude clarifies | |

**User's choice:** Yes, both available
**Notes:** Success Criterion #2's full library/streaming-only/play-pause matrix is testable on real hardware, no gaps (D-05).

---

## Automation (TCC) bug repro depth

| Option | Description | Selected |
|--------|-------------|----------|
| Quick single-app check (Recommended) | Music.app only | ✓ |
| Full matrix | Music.app + Spotify + idle/backgrounded states | |

**User's choice:** Quick single-app check (Recommended)
**Notes:** Music.app-only repro is enough to inform Phase 50's FAV-03 error handling; Spotify's own unknowns are already the bigger risk (D-06).

---

## Claude's Discretion

- Exact spike execution order across the three unknowns (Apple Music, Spotify OAuth, TCC repro).
- Where the go/no-go decision gets documented (dedicated findings doc vs. CONTEXT.md) — follow project convention at planning time.

## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- Calendar month-grid polish — unrelated to this spike.
- Quick Action disabled state has no controller gate — unrelated to this phase's scope.
- Island briefly disappears during click-through — unrelated to this phase's scope.
