# Phase 38: Focus Mode HUD - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 38-Focus Mode HUD
**Areas discussed:** Full Disk Access UX, HUD persistence & duration, Visual design & priority rank, Descope fallback

---

## Full Disk Access UX

| Option | Description | Selected |
|--------|-------------|----------|
| Settings opt-in only | Feature ships OFF by default as a Settings toggle; only enabling it triggers the explanation. | ✓ |
| Onboarding step | Added to first-launch onboarding flow, explained upfront before the user has seen the feature. | |
| Lazy, first-trigger | Feature on by default; explanation appears the first time the user actually toggles Focus/DND. | |

**User's choice:** Settings opt-in only.
**Notes:** Nobody who doesn't care about this feature ever sees a scary permission ask.

| Option | Description | Selected |
|--------|-------------|----------|
| Explain + deep link | In-app explanation text plus a button opening System Settings > Privacy & Security > Full Disk Access directly. | ✓ |
| Explain only, no deep link | Same explanation, user navigates to the pane themselves. | |

**User's choice:** Explain + deep link.

| Option | Description | Selected |
|--------|-------------|----------|
| Accept silently | Mirrors the project's existing degrade convention (Calendar/Weather: silent, no retry/nag). | ✓ |
| Re-check periodically | Islet re-checks permission status and shows the explanation again if still not granted. | |

**User's choice:** Accept silently.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, show status | A subtitle/badge under the toggle reflects real permission state. | ✓ |
| No, just a toggle | Plain on/off toggle with no live status. | |

**User's choice:** Yes, show status.

---

## HUD persistence & duration

| Option | Description | Selected |
|--------|-------------|----------|
| Persistent, like Charging/Device | Behaves as a real ActiveTransient state, shows "Focus On" the whole time Focus is active. | ✓ |
| Brief toast, like song-change | Shows for ~2s on the on/off transition, then fades regardless of Focus duration. | |

**User's choice:** Persistent, like Charging/Device.
**Notes:** Matches ROADMAP wording literally and gives the new ActiveTransient case real state to arbitrate — the point of this pipeline-proving phase.

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed-only takeover | Focus only shows in the collapsed pill/wings; expanding still works normally. | ✓ |
| Full takeover, like Charging/Device | Same rule as Charging/Device — expanding blocks everything else. | |

**User's choice:** Collapsed-only takeover.
**Notes:** Focus sessions can run for hours; blocking the entire expanded island for that duration is a real UX cost Charging/Device don't have.

| Option | Description | Selected |
|--------|-------------|----------|
| Charging/Device outrank Focus | A fresh Charging/Device event interrupts; Focus's pill reappears once it clears. | ✓ |
| Focus outranks Charging/Device | Focus takes priority while active. | |

**User's choice:** Charging/Device outrank Focus.
**Notes:** Mirrors how Now-Playing already yields to Charging/Device.

---

## Visual design & priority rank

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same Droppy-pill language | LEFT = icon + "Focus" label. RIGHT = on/off status indicator. Consistent with Phase 36 restyle suite. | ✓ |
| Something distinct | A different visual treatment to make Focus stand out. | |

**User's choice:** Yes, same Droppy-pill language.

| Option | Description | Selected |
|--------|-------------|----------|
| Silent disappear | "Focus On" pill just goes away the instant Focus turns off, same as Charging's wing on unplug. | ✓ |
| Brief "Focus Off" flash | A short, separate visible moment showing "Focus Off" text before dismissing. | |

**User's choice:** Silent disappear.

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed color, not accent-tinted | Focus On is a universal system-level state, reads consistently regardless of accent. | ✓ |
| Accent-tinted | Icon and label pick up the user's chosen accent color. | |

**User's choice:** Fixed color, not accent-tinted.

---

## Descope fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Descope cleanly | Drop the feature from v1.6 entirely, same clean-abandonment precedent as Phase 37. | ✓ |
| Ship with the FDA path anyway | Ship regardless, accepting the Full Disk Access UX cost. | |

**User's choice:** Descope cleanly.
**Notes:** The pipeline-proving goal is still validated using whichever detection path worked enough to build against during the spike, even if the shipped feature is pulled.

| Option | Description | Selected |
|--------|-------------|----------|
| Same Settings opt-in gating | The feature stays behind one Settings toggle regardless of which detection path won the spike. | ✓ |
| Request proactively during onboarding | Request INFocusStatusCenter's lighter prompt upfront if that path wins. | |

**User's choice:** Same Settings opt-in gating.
**Notes:** One consistent mental model for the user, regardless of which technical path the spike selects.

---

## Claude's Discretion

- Exact poll interval for the `Assertions.json` fallback path, if used (must stay well above Droppy's 0.1-0.5s range).
- Exact SwiftUI/resolver mechanism for the new "collapsed-only, not expanded" transient behavior.
- Naming of the new `FocusActivity`/`FocusModeMonitor` types and the new `ActiveTransient` case.
- Whether the Settings toggle lives in the existing Theming/Activity-toggles section or gets its own row.

## Deferred Ideas

- Named/labeled Focus Mode detection ("Work Focus", "Sleep", etc.) — already out of scope per REQUIREMENTS.md.
- Periodic re-prompting for permission — explicitly rejected in favor of silent degrade.
