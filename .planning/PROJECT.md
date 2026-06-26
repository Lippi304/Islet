# Notch — Dynamic Island for Mac

> Working title. Final product name is TBD (see Key Decisions).

## What This Is

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities: now-playing media controls, a charging/device-connected animation, a drag-and-drop file shelf, system HUDs, and a timer.

It is for Mac users who love the iPhone Dynamic Island and want it on their MacBook without paying for the existing closed-source apps (Alcove, DynamicLake). Built by a first-time programmer with the goal of a polished, possibly sellable product down the line.

## Core Value

The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island. If everything else is cut, that core island experience must work.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

**Foundation (Phase 0 — APP-01, APP-02, APP-04):**

- [x] Menu-bar background agent shell — Islet runs as an LSUIElement agent (no Dock icon) with a status-item menu (Settings…, Quit Islet) and a Settings window. (Phase 0)
- [x] Launch-at-login — SMAppService.mainApp toggle in Settings, driven by the live system state. (Phase 0)
- [x] Release/notarization toolchain proven end-to-end as a re-runnable `scripts/release.sh` (ad-hoc dry run; the real Developer-ID notarize/staple + clean-Mac open is the documented Phase-6 carry-over). (Phase 0)

**The Empty Island (Phase 1 — ISL-01, ISL-02, ISL-06, ISL-07):**

- [x] Static black pill rendered exactly over the physical notch (matching width + corner radius) by a borderless, non-activating, click-through `NSPanel` hosting a SwiftUI pill — `.statusBar` level confirmed to win over the macOS 26 menu bar; verified on-device. (Phase 1)
- [x] Stays above all windows and across all Spaces; never steals focus; clicks pass through. (Phase 1)
- [x] Positions on the correct built-in display through external-monitor / resolution / clamshell changes — hides in clamshell, recovers on lid-open. (Phase 1)
- [x] Idle pill is near-invisible and completely static in release config. (Phase 1)

_The remaining v1 core feature hypotheses below ship in Phases 2–6 (hover/expand interaction, now-playing, charging, devices)._

### Active

<!-- Current scope. Building toward these. All are hypotheses until shipped. -->

**v1 — Focused core (first milestone):**

- [ ] Notch island interaction: hover/click expands the already-shipped static notch overlay and collapses it when idle with a smooth spring morph, plus correct hide/yield in true fullscreen (Phase 2 — ISL-03/04/05)
- [ ] Now Playing: detect current media (Apple Music, Spotify, browser, etc.), show album art + title/artist in the island, and control play/pause/skip from it
- [ ] Charging activity: when the power cable is connected, show a charging animation + battery-level notification in the island
- [ ] Device-connected activity: when a Bluetooth device / AirPods connects or disconnects, show a brief notification in the island
- [ ] Polished, native look — animations and visual quality on par with Alcove

**Later phases (still in scope, after the core lands):**

- [ ] File shelf: drag-and-drop tray at the notch to temporarily hold files, then drag them back out / share / AirDrop
- [ ] System HUDs: replace the default volume / brightness / battery overlays with notch-based HUDs
- [ ] Timer: start and watch a countdown timer as a live activity in the island

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Macs without a physical notch / simulated island on external displays — keeps v1 simpler; only notch Macs targeted for now
- Mac App Store distribution — Now Playing relies on Apple's private MediaRemote API, which is not allowed on the App Store; distribution will be direct + notarized (the same path Alcove/DynamicLake use)
- Messaging/notification mirroring (iMessage, WhatsApp, Slack), calendar/weather glance, FaceTime/phone-call integration — DynamicLake-style extras deferred until the core island is solid
- Cross-platform (Windows/Linux) — this is a macOS-native product

## Context

- **Builder experience:** The user is a complete beginner at programming. In the GSD workflow, Claude writes the implementation code and explains the important parts; the user steers, runs/tests, and handles setup steps. Approach favors a working result the user can later maintain and extend.
- **Reference apps (the bar to match/beat):**
  - **Alcove** (tryalcove.com) — visual/Dynamic-Island-focused: now-playing with album art + waveform + seek bar + volume via hover/gesture, volume/brightness/battery HUDs, live activities, heavy customization. Polished animations.
  - **DynamicLake Pro** (dynamiclake.com, ~$16.90) — function/workflow-focused: DynaMusic (media), DynaGlance (calendar+weather), DynaCall (calls), notifications (iMessage/WhatsApp/Slack), DynaClip (file shelf w/ AirDrop), DynaDrop (drag-drop actions), timer, AirPods/Bluetooth connect, also runs on non-notch Macs.
  - **Free/open-source references to study:** TheBoringNotch (open source, theboring.name) and Notchy (notchy.dev) — useful for seeing how the notch overlay + MediaRemote integration is done.
- **Design north star:** A mix of both — as polished as Alcove, as functional/tidy as DynamicLake.
- **Setup status:** MacBook with notch + Xcode already installed. No Apple Developer account yet (only needed later for notarization/selling).

## Constraints

- **Tech stack**: Native macOS — Swift + SwiftUI/AppKit — Web/Electron can't cleanly do a borderless notch overlay, MediaRemote integration, or HUD replacement; both reference apps are native
- **Platform**: macOS on Apple-silicon notch MacBooks only (v1) — narrows scope and avoids non-notch edge cases
- **API**: Now Playing depends on the private MediaRemote framework — works but blocks Mac App Store; plan for direct notarized distribution
- **Builder skill**: First-time programmer — phases must include a setup/foundations ramp; explanations accompany the important code; avoid unnecessary complexity
- **Distribution**: Direct download, code-signed + notarized — requires an Apple Developer account ($99/yr) before any public release (not needed for local development)
- **Budget**: Hobby/personal budget — no paid services assumed beyond the eventual Developer account

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native Swift (SwiftUI/AppKit), not Electron/web | Only native can render a borderless notch overlay + use MediaRemote + replace HUDs; both reference apps are native | — Pending |
| Target only notch Macs in v1 | Removes simulated-island/non-notch complexity; user has a notch MacBook | — Pending |
| Focused v1 (island + Now Playing + charging/device activity) before shelf/HUDs/timer | Beginner project — get something polished and working early, then expand | — Pending |
| Direct notarized distribution, not Mac App Store | MediaRemote is a private API → App Store rejection; direct sale is the proven path (Alcove/DynamicLake) | — Pending |
| Design = polished (Alcove) + functional (DynamicLake) blend | User likes both and wants to match their quality | — Pending |
| Product name TBD | "Notch" is a working title only; real name decided closer to release | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-26 — Phase 1 (The Empty Island) complete: a static black pill renders exactly on the notch, above all windows, on the correct display through monitor/clamshell changes (ISL-01, ISL-02, ISL-06, ISL-07), verified on-device.*
