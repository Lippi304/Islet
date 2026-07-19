# Phase 44: Tray & Quick Action Width Alignment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 44-Tray & Quick Action Width Alignment
**Areas discussed:** Tray squeeze reproduction, Picker fix mechanism, Verification rigor, Something else

---

## Tray squeeze reproduction

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, with many files | Icons squeeze/overlap rather than scrolling off | |
| No, Tray itself looks fine | The 650pt Tray with scrolling has looked fine | (redirected) |
| Not sure / haven't tested | Haven't specifically stress-tested with many files | |

**User's choice (free text):** "Nein es geht darum wenn man eine File droppen will auf die 3 Buttons mit drop/airdrop/mail die 3 buttons sind nicht richtig in der File Tray. Mein Gedanke ist diese Tray beim Drop genauso breit und tief zu machen wie die normale File Tray wenn man seine gedroppten files sieht."
**Notes:** Redirected the question — no active Tray-itself squeeze observed. The real complaint is the Quick Action picker box being smaller than the real Tray, making the 3 buttons look misplaced within it. This became the anchor for the entire Picker fix mechanism area below.

| Option | Description | Selected |
|--------|-------------|----------|
| You decide | Pick whatever width comfortably fits a typical file count | ✓ |
| Keep 650pt, just verify | Don't think it needs to grow further | |
| I'll give a specific number | Specific target width/file count in mind | |

**User's choice:** You decide
**Notes:** No locked target width for a hypothetical further Tray widening — deferred to Claude/planner if research finds an actual squeeze case.

---

## Picker fix mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Full Tray footprint (content + switcher row space) | Picker box pixel-identical to landed Tray's total frame | ✓ |
| Content height only | Match content height (145pt) but skip switcher-row space | |
| You decide | Trust Claude/planner | |

**User's choice:** Full Tray footprint (content + switcher row space)
**Notes:** Height target is `trayContentHeight + switcherRowHeight`, matching `trayFullView`'s actual computed height — even though the picker still doesn't show switcher-row content (`showSwitcher: false` unchanged).

| Option | Description | Selected |
|--------|-------------|----------|
| Keep buttons as-is, more surrounding space | Same 3-button row, centered in the larger box | ✓ |
| Scale buttons up to fill the space | Bigger buttons/spacing | |
| You decide | Trust Claude/planner | |

**User's choice:** Keep buttons as-is, more surrounding space

---

## Verification rigor

| Option | Description | Selected |
|--------|-------------|----------|
| Quick manual check | Same as Phase 43 D-04 — click/hover, real drag, hover→expand→move-down trace once | ✓ |
| More thorough checklist | Written multi-scenario UAT plan | |
| You decide | Trust Claude/planner | |

**User's choice:** Quick manual check

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, explicitly re-verify | Button tap zones must still land correctly at the new bigger box | ✓ |
| Not necessary | Trust computeQuickActionButtonFrames to just work | |

**User's choice:** Yes, explicitly re-verify

---

## Something else

| Option | Description | Selected |
|--------|-------------|----------|
| Nothing else | The Tray-squeeze / picker-size / verification decisions cover it | ✓ |
| Let me describe something | Another concern to add | |

**User's choice:** Nothing else

---

## Claude's Discretion

- Exact width if an actual Tray squeeze case is found during research/planning — no locked number given.
- Whether `quickActionPickerContentHeight` is deleted/replaced or kept as a named constant with a new value.
- Any animation/transition detail for the picker's size change when a drag starts on a non-Tray tab — not raised as a concern, treat as a normal parameter change.

## Deferred Ideas

None — discussion stayed within phase scope.
