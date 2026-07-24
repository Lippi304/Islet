# Phase 62: Timer/Pomodoro - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-24
**Phase:** 62-Timer/Pomodoro
**Areas discussed:** Start flow & duration picker, Pomodoro session structure, Expanded controls layout, Completion & segment transitions

---

## Start Flow & Duration Picker

### Entry point

| Option | Description | Selected |
|--------|-------------|----------|
| Settings card options sheet | Tap the Timer card's options button in Settings to open a picker | |
| Home view button | Dedicated "Start Timer" button/card in the expanded Home tab | ✓ |
| Both — Settings for setup, Home for quick start | Config in Settings, quick re-start from Home | |

**User's choice:** Home view button (D-01)

### Duration UI

| Option | Description | Selected |
|--------|-------------|----------|
| Preset chips only | 5/15/25/45 min fixed chips | |
| Preset chips + custom entry | Chips plus a "Custom" stepper/wheel option | ✓ |
| Stepper/wheel only | Always dial in exact duration | |

**User's choice:** Preset chips + custom entry (D-02)

### Mode switch (Countdown vs. Pomodoro)

| Option | Description | Selected |
|--------|-------------|----------|
| Segmented toggle above the picker | Switch swaps chips between countdown and work/break presets | ✓ |
| Two separate buttons on Home | "Start Timer" / "Start Pomodoro" as distinct flows | |
| Pomodoro as just a duration preset | "Pomodoro (25/5)" is one chip among others | |

**User's choice:** Segmented toggle above the picker (D-03)

### Preset durations

| Option | Description | Selected |
|--------|-------------|----------|
| 5 / 15 / 25 / 45 min | Quick break to near-hour focus block | |
| 5 / 10 / 20 / 30 min | Skews shorter | ✓ |
| Let Claude decide | No strong preference | |

**User's choice:** 5 / 10 / 20 / 30 min (D-02)

---

## Pomodoro Session Structure

### Work/break durations

| Option | Description | Selected |
|--------|-------------|----------|
| Classic 25/5 | Standard Pomodoro split | ✓ |
| 25/5 with a long break | Full technique, 3 cycles + long break on 4th | |
| Let Claude decide | No strong preference | |

**User's choice:** Classic 25/5 (D-04)

### Customizable?

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed 25/5, not customizable | Simplest to build | |
| Customizable via the same chip/custom-entry picker | Reuses countdown picker pattern per segment | ✓ |

**User's choice:** Customizable via the same chip/custom-entry picker (D-05)

### Session length

| Option | Description | Selected |
|--------|-------------|----------|
| Runs until manually stopped | Cycles indefinitely, counter increments | ✓ |
| Fixed 4 cycles then done | Classic "set", stops automatically | |
| User picks cycle count at start | Configurable target cycle count | |

**User's choice:** Runs until manually stopped (D-06)

### Collapsed pill counter

| Option | Description | Selected |
|--------|-------------|----------|
| "Cycle N" + current segment label | e.g. "Work · Cycle 3" alongside mm:ss | ✓ |
| Segment label only, no cycle count | Just "Work"/"Break" + countdown | |
| Let Claude decide | No strong preference | |

**User's choice:** "Cycle N" + current segment label (D-07)

---

## Expanded Controls Layout

### Button style

| Option | Description | Selected |
|--------|-------------|----------|
| Circular icon buttons (navCircleButton style) | Matches onboarding carousel nav buttons | ✓ |
| Text chips (chipButton style) | Matches Grant/Buy-license chip style | |
| Let Claude decide | No strong preference | |

**User's choice:** Circular icon buttons (navCircleButton style) (D-08)

### Add-time increment

| Option | Description | Selected |
|--------|-------------|----------|
| +1 min, tappable repeatedly | Small, precise increments | ✓ |
| +5 min, tappable repeatedly | Bigger jump per tap | |
| Let Claude decide | No strong preference | |

**User's choice:** +1 min, tappable repeatedly (D-09)

### Stop/cancel affordance

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, a 4th button (stop/cancel) | Distinct button ends session, returns to idle | ✓ |
| No — pause + reset covers it | No dedicated stop button | |

**User's choice:** Yes, a 4th button (stop/cancel) (D-10)

---

## Completion & Segment Transitions

### Auto-advance

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-advances immediately | Work→break→work with no user action | ✓ |
| Pauses, waits for user to start next segment | Gives the user a moment before the break/work starts | |

**User's choice:** Auto-advances immediately (D-11)

### Completion sound

| Option | Description | Selected |
|--------|-------------|----------|
| Standard system notification sound | Uses macOS default alert sound | ✓ |
| A distinct custom "timer done" chime | Bundled custom audio asset | |
| Let Claude decide | No strong preference | |

**User's choice:** Standard system notification sound (D-12)

### Segment-transition sound scope

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, every transition | Full sound+splash at every work↔break switch | ✓ |
| No — subtler cue, full splash only on session stop | Lighter signal for mid-session transitions | |

**User's choice:** Yes, every transition (D-13)

---

## Claude's Discretion

- Exact SF Symbol icons for pause/reset/add-time/stop and their color treatment.
- Splash visual content/copy and its on-screen display duration.
- Internal `TimerActivityState`/monitor class naming and file layout.
- Mechanism for generalizing `ActiveTransient.isPersistent` beyond `.focus` (new case vs. shared protocol/flag) — technical implementation detail for research/planning.
- Whether timer state survives an app quit/relaunch or system sleep — not raised during discussion; flagged in CONTEXT.md as an open question for research to surface explicitly.

## Deferred Ideas

None — discussion stayed within phase scope. Three keyword-matched todos (calendar grid polish, click-through disappearing, quick-action disabled state) were reviewed and confirmed not relevant, same as in Phases 60/61.
