# Phase 54: Permissions Overview & Onboarding Replay - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-21
**Phase:** 54-permissions-overview-onboarding-replay
**Areas discussed:** Which permissions in the rollup, Re-request behavior when denied, Replay-onboarding behavior, Placement & presentation

---

## Which permissions in the rollup

| Option | Description | Selected |
|--------|-------------|----------|
| Hide Automation/Apple Events | Paused Favorite/Like feature never shipped; showing its permission would confuse users | ✓ |
| Show Automation/Apple Events anyway | Technically already entitled/configured | |

| Option | Description | Selected |
|--------|-------------|----------|
| Include Input Monitoring, best-effort status | No official read API, but best-effort beats omitting | ✓ |
| Omit Input Monitoring | Avoid a potentially unreliable/misleading status | |

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm 5-permission scope, Calendar+Reminders combined into 1 row | Location, Calendar+Reminders, Bluetooth, Focus, Input Monitoring | ✓ |
| Split Calendar/Reminders into 2 rows | They're 2 separate TCC entries technically | |

| Option | Description | Selected |
|--------|-------------|----------|
| 3-state status (granted/denied/not-yet-asked) | More accurate, drives different tap behaviors | ✓ |
| 2-state status (granted/not granted) | Simpler, less precise | |

**User's choice:** Exclude Automation; include Input Monitoring best-effort; exactly 5 permissions with Calendar+Reminders combined; 3-state status model.
**Notes:** All 4 sub-decisions followed the recommended option.

---

## Re-request behavior when denied

| Option | Description | Selected |
|--------|-------------|----------|
| Deep-link to the specific System Settings privacy pane | One tap lands on the right page directly | ✓ |
| Popover with text instructions | Matches existing Focus/OSD pattern but requires manual navigation | |

| Option | Description | Selected |
|--------|-------------|----------|
| Trigger native requestAuthorization dialog for not-yet-asked | Uses the real system prompt where one is actually available | ✓ |
| Also deep-link to System Settings for not-yet-asked | More consistent behavior across all taps, but an unnecessary detour | |

**User's choice:** Deep-link for denied permissions; native dialog trigger for never-asked permissions.
**Notes:** Both followed the recommended option.

---

## Replay-onboarding behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Full onboarding carousel (Welcome → Trial/License → Permissions → Done) | Reuses Phase 26's OnboardingFlow verbatim | ✓ |
| Permissions-step only | More direct but needs a new partial-onboarding mode | |

| Option | Description | Selected |
|--------|-------------|----------|
| Pure display replay, no persisted-state change | Backing out mid-replay leaves no broken half-onboarded state | ✓ |
| Resets hasCompletedOnboarding/isFirstLaunch like a true first launch | Riskier — could affect trial/license display unexpectedly | |

**User's choice:** Full carousel replay; no persisted-state change.
**Notes:** Both followed the recommended option. A follow-up question confirmed the button itself stays in About (per ARCH-P2's original scoping), not moved into the new Permissions section.

---

## Placement & presentation

| Option | Description | Selected |
|--------|-------------|----------|
| New dedicated "Permissions" sidebar section | Consistent with Phase 51's 7-section pattern | ✓ |
| Fold into existing "About" section | Less visible, no new sidebar entry | |

| Option | Description | Selected |
|--------|-------------|----------|
| Row-per-permission list with status icon | Always-visible, tappable, standard macOS settings-list feel | ✓ |
| Compact "X of Y granted" text summary, expand for details | Saves space but adds a click before reaching individual permissions | |

**User's choice:** New dedicated sidebar section; always-visible per-row list (with an "X of Y" summary line still shown above it, per ARCH-P2's literal wording).
**Notes:** Both followed the recommended option.

---

## Claude's Discretion

- Exact SF Symbol/glyph choices for granted/denied/not-yet-asked status indicators
- Whether a granted-permission row is tappable (no-op) or fully inert
- Exact per-permission System Settings deep-link URL constants (verify at planning/research time, don't hardcode blind)
- Best-effort Input Monitoring status-check technique and its documented limitations

## Deferred Ideas

- `2026-07-19-calendar-month-grid-polish.md` — unrelated UI polish, reviewed but not folded
- `2026-07-19-island-briefly-disappears-during-click-through.md` — unrelated click-through bug, reviewed but not folded
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — unrelated gating gap, reviewed but not folded
