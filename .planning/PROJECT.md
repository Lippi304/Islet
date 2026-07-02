# Notch — Dynamic Island for Mac

> Working title. Final product name is TBD (see Key Decisions).

## What This Is

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities. **Shipped in v1.0:** now-playing media controls with working transport, a charging activity, a Bluetooth/AirPods device-connected activity, and a minimal settings window with three activity toggles + accent theming — all arbitrated by a single priority resolver so activities coexist gracefully. A drag-and-drop file shelf, system HUD replacement, and a countdown timer are planned for a future milestone, not yet built.

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

**Hover, Expand & Fullscreen Hardening (Phase 2 — ISL-03, ISL-04, ISL-05):**

- [x] The pill morphs collapsed↔expanded via a single `matchedGeometryEffect` spring (Alcove-quality, no cross-fade); the idle pill drives no animation. (Phase 2 — ISL-04)
- [x] Focus-safe interaction: a CLICK expands the island, hovering gives a haptic + bounce affordance without expanding (D-02 Alcove model), and pointer-away collapses after a ~0.4s grace; the non-activating panel never steals focus. (Phase 2 — ISL-03)
- [x] Hides/yields in true fullscreen via the private CGS managed-display-spaces signal — the NSScreen safe-area heuristic proved unusable from a background agent; native fullscreen verified on-device (8 further on-device UAT items tracked in 02-HUMAN-UAT.md; a 1-frame enter-transition flash is a deferred polish item). (Phase 2 — ISL-05)

**Charging Activity (Phase 3 — CHG-01):**

- [x] Live charging splash — plugging in the power cable shows the Alcove-style "wings" splash (a filling battery glyph + %) beside the notch for ~3s then collapses, driven by an event-driven IOKit power-source notification (no polling clock); routed through the single visibility gate so it stays hidden in true fullscreen; on-device verified. (Phase 3 — CHG-01)
  - **Connect-only (CHG-02 descoped):** by on-device decision the activity fires only on plug-in; unplugging deliberately shows nothing. CHG-02's original "brief on-battery indication on unplug" is intentionally dropped. (Phase 3)

**Now Playing (Phase 4 — NOW-01, NOW-02, NOW-03):**

- [x] Live media in the island — album art, title, and artist for the playing app (Spotify / Apple Music allowlist) as a collapsed glance (art + animated equalizer wings) and an expanded view; on-device verified. (Phase 4 — NOW-01)
- [x] Working transport from the expanded island — play/pause, next, previous act on the live session via the persistent adapter child, focus-safe (non-activating panel, no re-spawn). (Phase 4 — NOW-02)
- [x] Survives restart and degrades gracefully — launch-time health check; when the MediaRemote API is blocked or the source drops, the island clears state and shows "Now Playing nicht verfügbar" instead of crashing or sitting empty. All MediaRemote access is isolated behind a single `NowPlayingMonitor` (one-file swap if Apple breaks it), consuming the streamed output (not re-spawning) with main-thread callbacks. (Phase 4 — NOW-03)
  - **On-device UAT polish:** expanded layout reserves a 32pt notch/camera top-clearance; 5 random center-out equalizer bars (idle-CPU-gated); media glance wings 290pt (narrower than the 305pt charging wings); the expanded island stays open while the pointer is on the transport controls. (Phase 4)

**Priority Resolver, Settings & v1 Ship (Phase 6 — COORD-01, DEV-01, DEV-02, APP-03, APP-04):**

- [x] Single priority arbiter — a pure `IslandResolver` ranks Charging > Device > Now Playing through a bounded, de-duped `TransientQueue`; activities enqueue and play sequentially without overlap or glitching (WR-1/WR-2 identity-match and dismiss-timer defects closed in gap-closure plan 06-13, confirmed by code read + 131/131 tests + independent code review). (Phase 6 — COORD-01)
- [x] Device-connected activity — Bluetooth device / AirPods connect/disconnect splash with battery %, event-driven via a thin `BluetoothMonitor`; folded in from Phase 5's blocked device quartet (Phase 5 formally marked superseded by Phase 6 at v1.0 close). (Phase 6 — DEV-01, DEV-02)
- [x] Settings window — three independent activity toggles (Charging/Device/Now Playing, default ON) + curated accent palette, persisted via `@AppStorage`, survives restart. (Phase 6 — APP-03)
- [x] Release pipeline dry run — `scripts/release.sh` archive→sign→dmg→notarize→staple proven end-to-end in dry-run mode; real notarize/staple gated behind a paid Apple Developer account (not yet purchased, documented override). (Phase 6 — APP-04)

_v1.0 core feature set is code-complete and fully human-verified — all 4 on-device checks in `06-HUMAN-UAT.md` passed 2026-07-02, no issues. Milestone shipped._

### Active

<!-- Current scope. Building toward these. All are hypotheses until shipped. -->

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
- **v1.0 codebase state (shipped 2026-07-02):** ~4,500 LOC Swift across 7 phases (176 files touched total), 131 passing unit tests (`IsletTests`). Every threat register across the project's plans is dispositioned (mitigate/accept), verified in `06-SECURITY.md`.
- **Known technical debt carried into v1.1 planning:**
  - Four non-blocking code-review findings from `06-REVIEW.md`: inconsistent charging/device wing accent-tinting (WR-01), accent-change view-tree rehost breaking `matchedGeometryEffect` continuity (WR-02), a missing `withAnimation` wrapper on the Now-Playing health-check callback (WR-03), and a low-probability `BluetoothMonitor` data race (WR-04).
  - A ~1-frame island flash at the end of the fullscreen-ENTER transition — root-caused since Phase 2, confirmed not fixable at the application layer (window-server compositor timing), accepted as permanent polish debt.
  - Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised — pre-existing, unrelated to v1.0's Phase 6 close; tracked in `STATE.md` Deferred Items.

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
| Native Swift (SwiftUI/AppKit), not Electron/web | Only native can render a borderless notch overlay + use MediaRemote + replace HUDs; both reference apps are native | ✓ v1.0 shipped — validated, no framework wall hit |
| Target only notch Macs in v1 | Removes simulated-island/non-notch complexity; user has a notch MacBook | ✓ v1.0 shipped |
| Focused v1 (island + Now Playing + charging/device activity) before shelf/HUDs/timer | Beginner project — get something polished and working early, then expand | ✓ v1.0 shipped — scope held, file shelf/HUDs/timer correctly deferred to v1.1+ |
| Direct notarized distribution, not Mac App Store | MediaRemote is a private API → App Store rejection; direct sale is the proven path (Alcove/DynamicLake) | ✓ Pipeline proven (dry-run) — real notarization blocked on Apple Developer account purchase |
| Design = polished (Alcove) + functional (DynamicLake) blend | User likes both and wants to match their quality | ✓ v1.0 shipped — spring morph + accent theming delivered |
| Product name TBD | "Notch" is a working title only; real name decided closer to release | — Still pending — decide before public release |
| Island opens on CLICK; hover only gives a haptic + bounce affordance (D-02) | Alcove model — prevents accidental expansion when the pointer merely passes over the notch | ✓ Phase 2 |
| Fullscreen detected via private CGS managed-display-spaces (current-space type==4), not NSScreen safe-area | A background agent's safe area never reflects another app's fullscreen; CGS Spaces is permission-free and reference-app-proven | ✓ Phase 2 |
| Charging activity is connect-only (plug-in animates; unplug shows nothing) | On-device UAT call — only the connect moment should animate; an unplug cue felt unnecessary | ✓ Phase 3 (CHG-02 descoped) |
| Charging "wings" sized to the measured notch (179×32 pt → wings 305×32, flush height) | Notch measured live via NSScreen safeAreaInsets + auxiliary top areas; matching the height avoids overhang, width tuned on-device | ✓ Phase 3 |
| All MediaRemote access isolated behind one `NowPlayingMonitor`/`NowPlayingService` protocol, with a launch-time health check | The private-API bridge (`mediaremote-adapter`) is the single most likely thing Apple disrupts; isolation makes a future break a one-file swap | ✓ Phase 4, hardened in Phase 6 (06-11 protocol extraction) |
| Phase 5 (device-connected activity) scope folded into Phase 6 rather than executed standalone | Phase 6's priority-resolver work needed the device input anyway; building it once inside Phase 6 avoided rework | ✓ v1.0 shipped — DEV-01/DEV-02 delivered via 06-02/06-04; Phase 5 formally marked superseded |
| Single pure `IslandResolver` (ranked reduce) + bounded `TransientQueue` as the ONE arbiter for all activity priority | Prevents scattered if-chains across the view/controller layer; keeps priority logic testable in isolation | ✓ Phase 6 — 14+ unit tests, WR-1/WR-2 defects found and closed in gap-closure |
| Real Developer-ID notarization deferred until a paid Apple Developer account exists ($99/yr) | Explicit budget constraint (CLAUDE.md); dry-run pipeline proves the mechanics without the cost | Accepted, formally overridden in `06-VERIFICATION.md` — revisit before any public v1.0 release |

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
*Last updated: 2026-07-02 — v1.0 milestone shipped and archived. All 7 phases complete (Phase 5 superseded by Phase 6), all 19 v1 requirements satisfied and verified, all 4 on-device human-verification items passed, security threat register closed (0 open). See `.planning/milestones/v1.0-ROADMAP.md` for full history. Next: define v1.1 scope via `/gsd:new-milestone`.*
