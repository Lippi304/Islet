# Phase 53: Hover-to-Resume Idle Preview - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-21
**Phase:** 53-hover-to-resume-idle-preview
**Areas discussed:** Resume click scope, Preview visual motion, Resume-failure feedback, Dismiss timing

---

## Resume click scope

| Option | Description | Selected |
|--------|-------------|----------|
| Resume in place | togglePlayPause() only, pill stays in wings-preview shape — matches Phase 42 bubble precedent | ✓ |
| Resume + full expand | Resumes AND opens full Home transport view in one click | |

**User's choice:** Resume in place
**Notes:** None.

---

## Preview visual motion

| Option | Description | Selected |
|--------|-------------|----------|
| Static/frozen bars | Fixed, non-animating — signals "preview, not live" | |
| Same animated wobble | Identical to live-playing state, simplest to implement | ✓ |

**User's choice:** Same animated wobble
**Notes:** None.

---

## Resume-failure feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Brief inline text | e.g. "Can't resume", mirrors Phase 4/NOW-03's "Now Playing nicht verfügbar" pattern | ✓ |
| Shake/flash animation | Quick shake/flash on failed tap, no text | |

**User's choice:** Brief inline text
**Notes:** ROADMAP Success Criterion #4 already mandates *that* feedback must exist — this question was only about its shape.

---

## Dismiss timing

| Option | Description | Selected |
|--------|-------------|----------|
| Same 0.4s grace (recommended) | Reuses existing pointer-away grace-collapse timer verbatim | ✓ |
| Something else | Custom timing | |

**User's choice:** Same 0.4s grace
**Notes:** None.

---

## Claude's Discretion

- Exact SwiftUI mechanics for the idle→hover-preview transition (new state branch vs. reusing `nowPlayingWings` conditionally).
- Whether resuming a fully-stopped session is technically achievable via `NowPlayingMonitor`/MediaRemote — flagged as an open technical question to verify early in research/planning (per PROJECT.md v1.8 Key Context and ROADMAP SC#4), not a user decision.

## Deferred Ideas

None — discussion stayed within phase scope.
