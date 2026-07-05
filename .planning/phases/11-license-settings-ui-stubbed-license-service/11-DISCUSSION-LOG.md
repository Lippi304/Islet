# Phase 11: License Settings UI (Stubbed License Service) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 11-license-settings-ui-stubbed-license-service
**Areas discussed:** State-based layout, Days-remaining display, Activate flow + fake validation, Buy Now button

---

## State-based layout

| Option | Description | Selected |
|--------|-------------|----------|
| One adaptive section | Single `License` section whose content swaps by state (trial / expired / licensed) | ✓ |
| Always show all controls | Buy Now + key field always visible; only status text changes | |

**User's choice:** One adaptive section
**Notes:** Matches Phase 10 D-07; licensed state hides Buy Now + key field.

---

## Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Top, above everything | License section first, before Launch/Activities/Accent | ✓ |
| Bottom, below Accent | License section last, near Version line | |

**User's choice:** Top, above everything
**Notes:** Most important state; first thing seen when Settings auto-opens or on lockout.

---

## Days-remaining display

| Option | Description | Selected |
|--------|-------------|----------|
| Countdown only | "2 days left in your trial." | ✓ |
| Countdown + end date | "2 days left — trial ends Jul 8." | |
| End date only (current) | Keep existing "trial started — ends Jul 8." | |

**User's choice:** Countdown only
**Notes:** Satisfies success criterion #1 literally; replaces current end-date line.

---

## Activate flow — feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Inline status line | Spinner + "Validating…" → ✓/✗ line below field; button disabled while validating | ✓ |
| Button-only | Button label morphs; no separate status line | |

**User's choice:** Inline status line
**Notes:** More explicit about why a key failed.

---

## Fake validation rule

| Option | Description | Selected |
|--------|-------------|----------|
| Magic key(s) | Known test key validates, everything else fails | ✓ |
| Any non-empty key | Any non-blank input succeeds | |
| Format-based | Keys matching a shape pass | |

**User's choice:** Magic key(s)
**Notes:** Deterministically exercises both success and failure paths on-device; suggested `ISLET-DEMO-OK`.

---

## Validating delay

| Option | Description | Selected |
|--------|-------------|----------|
| ~1 second | Visibly observable transition | ✓ |
| Instant | Resolves immediately | |

**User's choice:** ~1 second
**Notes:** Criterion #3 wants transitions observable.

---

## Buy Now button

| Option | Description | Selected |
|--------|-------------|----------|
| Future site + priced label | Opens https://getislet.app, label "Buy Islet — €7.99" | ✓ |
| example.com + plain label | Opens https://example.com, label "Buy Now" | |

**User's choice:** Future site + priced label
**Notes:** Reads real even as a placeholder; €7.99 locked in REQUIREMENTS.md. Real Polar URL is Phase 12.

---

## Claude's Discretion

- Successful stub activation flips app to entitled **in-memory for the session** and reuses Phase 10's live-unlock path (island reappears without restart). Whether via `LicenseState` extension or the new `LicenseService` stub is a planner call; the observable behavior is locked.
- `LicenseService` protocol surface (async validate, error taxonomy, threading) left to research/planning — must be a drop-in swap for Phase 12's `PolarLicenseService`.
- Exact copy, spacing, spinner styling within the inline-status pattern.

## Deferred Ideas

- License persistence across restarts / offline Keychain cache → Phase 12 (LIC-02).
- Real Polar.sh checkout URL + online validation → Phase 12 (LIC-01/LIC-02).
- Deep-link license auto-fill (`islet://license?...`) → v2 (LIC-04).
- Last-day nudge notification → v2 (TRIAL-04).
