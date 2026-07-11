# Phase 26: Onboarding Flow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-11
**Phase:** 26-Onboarding Flow
**Areas discussed:** Permission-request sequencing, Trial/license/buy screen semantics, Onboarding host window & post-flow routing, Skip/dismiss granularity + inline Launch-at-Login

---

## Permission-request sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| Gate on first launch only | Defer startBluetoothMonitor()/startOutfitRefresh() until onboarding's permissions step on a fresh install; later launches stay eager | ✓ |
| Leave eager, screen purely informational | Keep today's automatic launch-time requests untouched | |
| Gate permanently, always driven by onboarding replay | Every launch routes through onboarding-owned trigger, not just first launch | |

**User's choice:** Gate on first launch only.
**Notes:** None beyond the recommended rationale.

| Option | Description | Selected |
|--------|-------------|----------|
| Per-row buttons, user-paced | Each of the 3 permission rows has its own Continue/Grant button | ✓ |
| Single Continue, auto-sequenced | One tap fires all 3 system prompts back-to-back | |

**User's choice:** Per-row buttons, user-paced.

| Option | Description | Selected |
|--------|-------------|----------|
| Row shows a quiet "not granted" state, flow continues | Matches existing silent-degrade convention | ✓ |
| Nudge with a re-ask affordance | Denied row gets a "Grant in Settings" link | |

**User's choice:** Row shows a quiet "not granted" state, flow continues.

---

## Trial/license/buy screen semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Inform + offer alternates | "Trial started" messaging + Enter Key / Buy Now buttons | ✓ |
| Let the user actively choose upfront | 3 real choices before trial auto-starts, requires changing TrialManager's auto-start | |

**User's choice:** Inform + offer alternates.

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing LicenseState/Settings UI | Same key-entry field + Buy Now button already built | ✓ |
| New simplified onboarding-only view | Trimmed-down variant just for onboarding | |

**User's choice:** Reuse existing LicenseState/Settings UI.

---

## Onboarding host window & post-flow routing

| Option | Description | Selected |
|--------|-------------|----------|
| New dedicated onboarding window | Separate SwiftUI Window(id: "onboarding") | |
| Hosted inside existing Settings window | Reuses Settings shell as full-bleed onboarding view | |

**User's choice:** Neither (free text) — Droppy renders onboarding inside the expanded notch itself, with Next/Back navigation at the bottom corners and permissions explanations directly in the expanded island. User referenced screenshots taken during an earlier session (not accessible in this session; textual description in `.planning/research/inspiration/notes.md` used instead).
**Notes:** Claude flagged that `NotchPanel.canBecomeKey`/`canBecomeMain` are hard-locked `false` (Phase 1/2/23 invariant), so a real text field (license key) cannot receive keyboard focus inside the actual notch panel — this constraint shaped the next question.

| Option | Description | Selected |
|--------|-------------|----------|
| Carousel lives in a focusable window styled to look like the expanded notch | Fake notch-shaped but real focusable window | |
| Split: visual steps in the real notch panel, license entry pops to Settings | Hero/permissions render in the real panel; license entry and any actual permission grant route to Settings | ✓ |
| Simple separate onboarding window, no notch mimicry | Plain dedicated window, least new architecture | |

**User's choice:** Split — visual steps in the real notch panel, license entry (and permission re-grant) routes to Settings.
**Notes:** User clarified (German, paraphrased): permissions that need a real Grant/System Settings toggle also route through Settings, same as license entry — "you'd need to go into Settings anyway to flip that switch on for Islet." Also introduced the forced-completion constraint (see next section).

| Option | Description | Selected |
|--------|-------------|----------|
| Close straight to menu-bar idle | No Settings auto-open after Done | ✓ |
| Auto-open Settings right after | Mirrors today's exact post-launch behavior | |

**User's choice:** Close straight to menu-bar idle.

---

## Skip/dismiss granularity + inline Launch-at-Login

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — per-step skip only, flow always finishes | Each step has its own skip path, but no early-exit from the carousel as a whole | ✓ |
| No — there should be a true early-exit too | Add a visible "Skip onboarding" affordance that jumps to Done from anywhere | |

**User's choice:** Per-step skip only, flow always finishes.
**Notes:** User detailed the exact step order and skip behavior (German, paraphrased): Welcome screen has nothing to decide (inherently "skippable" — just Next). 2nd screen (trial/license/buy) matches Droppy's screenshots exactly (3-day trial / license key / Buy button). Permissions step can be skipped per-row and activated later in Settings. Confirmed flow order: Welcome → Trial/License/Buy → Permissions → Done.

| Option | Description | Selected |
|--------|-------------|----------|
| Leave it to Settings only | No new UI in onboarding | |
| Add an inline Launch-at-Login toggle on Done | One extra toggle mirroring Droppy's 4th screen | ✓ |

**User's choice:** Add an inline Launch-at-Login toggle on Done.

---

## Claude's Discretion

- Exact visual layout of notch-hosted onboarding steps (content placement, Next/Back button styling) inside the expanded island shape.
- Exact mechanism for routing between the notch-hosted flow and the Settings window (and resuming afterward) — likely via the existing `.openIsletSettings` NotificationCenter bridge.
- Exact persisted-flag mechanism/key name for "onboarding shown once."
- Whether any onboarding-adjacent UI needs to reflect permissions granted later via Settings (likely nothing needed).

## Deferred Ideas

None — discussion stayed within phase scope. Gesture/feature tutorial screens remain explicitly out of scope project-wide (not just this phase).
