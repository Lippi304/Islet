# Notch — Dynamic Island for Mac

> Working title. Final product name is TBD (see Key Decisions).

## What This Is

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities. **Shipped in v1.0/v1.0.1:** now-playing media controls with working transport and a progress bar, a charging activity, a Bluetooth/AirPods device-connected activity, and a minimal settings window with three activity toggles + accent theming — all arbitrated by a single priority resolver so activities coexist gracefully. **Shipped in v1.1:** Islet is now a real, sellable product — a tamper-resistant 3-day free trial with hard lockout, a one-time €7.99 purchase via Polar.sh (live checkout, online validation, offline-capable Keychain cache), and a genuinely Developer-ID-notarized release pipeline. **Also shipped (ahead of formal milestone scope):** a weather + calendar + date glance in the expanded idle view. **Shipped in v1.2:** the Now Playing glance no longer appears at launch for an already-paused track (only a real Play does it), and genuine song changes show a brief fading title+artist toast with its own Settings toggle. A drag-and-drop file shelf, system HUD replacement, and a countdown timer remain planned for a future milestone, not yet built.

It is for Mac users who love the iPhone Dynamic Island and want it on their MacBook without paying for the existing closed-source apps (Alcove, DynamicLake). Built by a first-time programmer with the goal of a polished, possibly sellable product down the line.

## Core Value

The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island. If everything else is cut, that core island experience must work. Still the right priority after v1.1 — the paywall and notarization work protects and monetizes the core experience without changing it.

## Current State

**v1.2 Now Playing Polish shipped 2026-07-09** (Phases 17-18, see `.planning/milestones/v1.2-ROADMAP.md`). All 3 v1.2 requirements (NOW-04, NOW-05, NOW-06) shipped and on-device verified. The Now Playing glance no longer fires at launch for a merely-paused track, and genuine song changes surface a brief title+artist toast (independent 2s dismiss, its own Settings toggle) — both refined through on-device iteration.

**v1.1 Trial & Paid Release shipped 2026-07-08** (Phases 10-13, see `.planning/milestones/v1.1-ROADMAP.md`). All 7 v1.1 requirements (TRIAL-01/02/03, LIC-01/02/03, DIST-01) shipped and verified on-device. Islet is now a genuinely distributable, sellable product: real Developer-ID signing/notarization, a Keychain-backed tamper-resistant trial with hard lockout, and live Polar.sh purchase + offline-capable validation.

**Also shipped ahead of formal milestone scope (Phase 14, weather/calendar/date; Phase 15/16, architecture refactor):** the `expandedIdle` glance shows live weather (WeatherKit), the next calendar event (EventKit), and the date alongside the time readout, in a 3-column layout that degrades silently on permission denial — still needs its own requirement IDs (WEATHER-01, CAL-01, OUTFIT-01) captured whenever a milestone formally covers it. Phase 15/16 were pure architecture cleanup (DI seams, DeviceCoordinator extraction), zero product-behavior change.

## Next Milestone Goals

Not yet started — candidates remaining after v1.3 is scoped: capture WEATHER-01/CAL-01/OUTFIT-01 as formal requirements, system HUD replacement, or a countdown timer (all still Out of Scope below until picked up).

## Current Milestone: v1.3 Notch Shelf

**Goal:** Add a drag-and-drop file shelf to the island — a temporary, session-only staging area for files, matching the polish of the existing activities.

**Status: Phase 19 (Shelf Data Model) shipped 2026-07-09. Phases 20-22 (view, drag-out, drag-in) remaining.**

**Target features:**
- Drag a file onto the collapsed pill → island auto-expands, file lands in a shelf strip below the normal expanded view
- Shelf strip is appended below whatever else is showing expanded (Now Playing, idle glance, etc.) whenever it has content
- Files can be dragged back out to Finder or any other app
- Each file shows an icon/thumbnail with its own small trash icon for individual removal
- A "delete all" trash icon on the far right of the strip
- Unbounded capacity — strip scrolls horizontally
- Purely session-temporary — cleared on manual delete, app restart, or Mac restart; never persisted to disk
- Standard `NSItemProvider` drag & drop in both directions — no private API needed

(Prior context, retained: Phase 15 (Architecture Refactor — Mechanical Fixes & DI Seams) and Phase 16 (NotchWindowController Device Coordinator Extraction) both completed 2026-07-08 ahead of any formal milestone — see Validated Requirements below for details.)

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

**Now Playing Progress Bar (Phase 7 — PBAR-01):**

- [x] Display-only playback progress bar in the expanded Now Playing view — elapsed/total m:ss labels flanking an accent-filled capsule track, gliding continuously while playing and frozen while paused, zero tap-to-seek. On-device UAT caught and fixed a pause-transition backward-flash bug (stale MediaRemote sample corrected via a drift-extrapolated freeze); a post-execution code review then closed a NaN/Infinity crash risk in the same view. 141/141 tests green, on-device re-verified and approved. (Phase 7 — PBAR-01)

**Fullscreen-Enter Flash — Window/Space Architecture Retry (Phase 9 — FS-01):**

- [x] Fullscreen-enter island flash eliminated as a genuine root-cause fix — a dedicated, max-level private CGS Space (`CGSSpace.swift`) that the notch panel joins once at creation, additive alongside the existing `.canJoinAllSpaces` collection behavior (no per-Space auto-join race left to fire). On-device verified across all 3 trigger methods (green-button, menu bar, fullscreen video) with zero regressions across the full checklist (hover/click-expand, click-through, multi-Space visibility, display/clamshell repositioning, fullscreen hide/restore, lock-screen/sleep-wake). Closed Phase 8's escalation on the first wave of a 5-wave conditional chain — Candidate B (`SLSManagedDisplayIsAnimating` poll) and the terminal escalation report were never needed. (Phase 9 — FS-01)
  - **Known follow-up (non-blocking):** code review found the dedicated CGS Space leaks on app quit — `AppDelegate.quit()` calls `NSApp.terminate(nil)` without tearing down `NotchWindowController`, so its `deinit` (and the Space's `CGSHideSpaces`/`CGSSpaceDestroy` teardown) never runs. Doesn't affect the flash fix or fullscreen behavior; recommended fix via `/gsd-quick` before shipping.

**Trial & Lockout Gate (Phase 10 — TRIAL-01, TRIAL-02, LIC-03):**

- [x] Tamper-resistant 3-day trial — start timestamp persisted to the Keychain, survives `defaults delete` and reinstall; a one-time first-launch notice tells the user the trial has started; hard lockout (no pill, no activities) when expired and unlicensed, unlocking at the next natural UI transition rather than an abrupt yank. On-device verified. (Phase 10)

**License Settings UI (Phase 11 — TRIAL-03):**

- [x] Settings shows trial days remaining, a Buy Now button, and a key-entry field with idle/validating/success/failure states, proven against a stubbed `LicenseService` before any live network call existed. (Phase 11)

**Real Polar.sh License Integration (Phase 12 — LIC-01, LIC-02):**

- [x] Live Polar.sh checkout from Buy Now; real online key validation with a strict HTTP→verdict mapping that distinguishes a transient network error from an actually-invalid key (never hard-locks a key just paid for); validated state cached in the Keychain so the app keeps working fully offline afterward. On-device verified. (Phase 12)

**Real Notarization & Release (Phase 13 — DIST-01):**

- [x] `scripts/release.sh` produces a real Developer-ID signed, notarized, and stapled `.dmg` — no ad-hoc/placeholder signing remains; `spctl --assess` reports accepted, no Gatekeeper warning on first launch. Two real bugs fixed along the way: embedded frameworks need explicit re-signing before the outer `.app` (`codesign` doesn't recurse), and `notarytool` requires a zip/pkg/dmg, not a raw `.app`. (Phase 13)

_v1.1 (Trial & Paid Release) is code-complete and fully human-verified — all 7 requirements shipped and on-device tested. Milestone shipped 2026-07-08._

**Basic Outfit: Weather + Calendar + Date (Phase 14 — pending formal requirement IDs):**

- [x] `expandedIdle` glance shows live weather (icon + temperature via WeatherKit), the next relevant calendar event (EventKit), and the date in a 3-column layout alongside the existing time readout; only the weather icon animates per condition category; any column degrades silently to absent on permission denial. On-device verified (WeatherKit end-to-end, permission-denial omission, live event advancement, idle-CPU check). Executed ahead of formal milestone scope — capture as WEATHER-01/CAL-01/OUTFIT-01 in the next milestone's REQUIREMENTS.md. (Phase 14)

**NotchWindowController Device Coordinator Extraction (Phase 16 — D-01, D-02, D-03, informal IDs sourced from 16-CONTEXT.md):**

- [x] The 9-field device-splash bookkeeping and its 3 stateful methods extracted out of `NotchWindowController` into an independently-testable `DeviceCoordinator`, behind a narrow 2-method `ActivityCoordinator` protocol; `BluetoothMonitor`'s own construction/start/stop/deinit lifecycle stays untouched and directly owned by the controller (D-01/D-02). Zero product behavior change proven both by 9 new unit tests covering Pitfalls 1-8 and by a mandatory on-device Bluetooth verification checklist — all 4 D-03 scenarios (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion) passed on real hardware. First proof of the coordinator-extraction shape, ahead of repeating it for Charging/NowPlaying/Outfit. (Phase 16)

**Now Playing Launch Gating (Phase 17 — NOW-04):**

- [x] Islet stays idle at launch when an allowlisted player reports a paused/loaded track — only a transition into actively-playing triggers the Now Playing glance. On-device verified. (Phase 17)

**Song-Change Toast (Phase 18 — NOW-05, NOW-06):**

- [x] On a genuine track change (not the first track after launch), the island briefly grows a small fading text row under the existing collapsed wings glance showing the new title and artist for ~2s, then collapses back — suppressed during charging/device activities and while manually expanded, rapid skips replace content in place rather than re-triggering. Design iterated on-device across 5 rounds (initial full-blob render → shrink → structural redesign to a minimal fade-in row under the unchanged wings → centered text → independent 2s duration) before user approval; final shape deviates from the phase's original UI-SPEC.md draft, which was updated to match. (Phase 18)
- [x] Settings toggle for the song-change toast, Activities tab next to the existing Now Playing toggle, default on. (Phase 18)

_v1.2 (Now Playing Polish) is code-complete and on-device verified — both phases (17, 18) shipped 2026-07-09._

**Shelf Data Model (Phase 19 — SHELF-08):**

- [x] The shelf's core data and lifecycle contracts (`ShelfItem`, `ShelfLogic`, `ShelfFileStore`, `ShelfCoordinator`) exist as pure, Foundation-only, unit-tested logic with no persistence path whatsoever — a cleared or relaunched shelf is provably empty by construction. Zero coupling to `IslandResolver`/`TransientQueue`; the shelf is its own independent axis. Post-review hardening: `deleteSessionCopy` now validates its delete target lives under the shelf's own temp root (was an unvalidated recursive parent-directory delete), and a rejected duplicate append no longer orphans its just-made session-temp copy. (Phase 19)

### Active

<!-- Current scope. Building toward these. All are hypotheses until shipped. -->

_v1.3 Notch Shelf — SHELF-01, SHELF-03 through SHELF-07, SHELF-09 remain, see REQUIREMENTS.md (Phases 20-22)._

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Macs without a physical notch / simulated island on external displays — keeps v1 simpler; only notch Macs targeted for now
- Mac App Store distribution — Now Playing relies on Apple's private MediaRemote API, which is not allowed on the App Store; distribution will be direct + notarized (the same path Alcove/DynamicLake use)
- Messaging/notification mirroring (iMessage, WhatsApp, Slack), FaceTime/phone-call integration — DynamicLake-style extras deferred until the core island is solid. (Calendar/weather glance shipped in Phase 14 — no longer out of scope.)
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
- **v1.0.1 codebase state (shipped 2026-07-04):** +2 phases, 141 passing unit tests (`IsletTests`, up from 131). The fullscreen-enter island flash — previously accepted as permanent window-server-timing debt — is now genuinely fixed via a dedicated CGS Space (Phase 9).
- **v1.1 codebase state (shipped 2026-07-08, includes Phase 14):** ~6,900 LOC Swift, 185 passing unit tests (`IsletTests`, up from 141). Added Keychain-backed trial/license persistence, `PolarLicenseService`, a real Developer-ID notarization pipeline, and WeatherKit/EventKit services behind their own protocol seams. A real Apple Developer account and paid Polar.sh integration are now live (no more placeholders).
- **Known technical debt carried into next milestone planning:**
  - Four non-blocking code-review findings from `06-REVIEW.md`: inconsistent charging/device wing accent-tinting (WR-01), accent-change view-tree rehost breaking `matchedGeometryEffect` continuity (WR-02), a missing `withAnimation` wrapper on the Now-Playing health-check callback (WR-03), and a low-probability `BluetoothMonitor` data race (WR-04).
  - WR-01/WR-02 (Phase 9, info): `CGSSpace.swift` has no validation of CGS private-API return values, and assumes an `Int`/`Int32` width fits `CGSSpaceSetAbsoluteLevel`'s one passed value. Low severity.
  - Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised — pre-existing, unrelated to v1.0/v1.0.1/v1.1 close; tracked in `STATE.md` Deferred Items.
  - Pre-existing (v1.0-era): `xcodebuild test` hangs in non-interactive/sandboxed environments due to a Bluetooth TCC-authorization wait in `BluetoothMonitor` (also affects the full `Islet.app`'s WeatherKit/MediaRemote/IOBluetooth boot as of Phase 14 — gate on `xcodebuild build`, route test runs to manual Cmd-U). Logged in `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`.
  - Two non-blocking code-review findings from `15-REVIEW.md` (pre-existing behavior, not new regressions): `KeychainLicenseStore`/`SettingsView` can show "License activated" while silently swallowing a Keychain write failure (WR-01); `LocationProvider.requestOnce` would silently drop a first caller's completion under a hypothetical concurrent second call, currently unreachable (WR-02).
  - Two non-blocking code-review findings from `16-REVIEW.md` (pre-existing behavior, carried through the extraction verbatim): `DeviceCoordinator`'s post-connect battery-refresh retry checks device *shape*, not identity, and silently depends on two independently-maintained magic-number caps (`TransientQueue.maxDepth` and a hardcoded `> 2`) staying in lockstep — benign today, but could misattribute a battery reading to the wrong device if either cap changes independently later (WR-1); `deviceSuppressedAtLaunch` is a dead parameter, always an empty `Set` pending a deferred A2 on-device seed (WR-2).

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
| FS-01 scoped as a full root-cause elimination, not a best-effort/partial reduction | v1.0's reactive `orderOut` approach was already confirmed insufficient; a partial mitigation would just re-accumulate the same polish debt | ✓ Phase 9 — Phase 8's candidate disproven and honestly escalated rather than shipping a partial fix; Phase 9 achieved a genuine fix |
| Phase 9's Candidate C (dedicated max-level CGS Space) implemented as ADDITIVE, not a replacement of `.canJoinAllSpaces` | The only variant with real shipping precedent in researched reference apps (`Ebullioscopic/Atoll`, `TheBoredTeam/boring.notch`); removing `.canJoinAllSpaces` deferred as a separate, never-combined follow-up | ✓ Phase 9 — resolved FS-01 on the first wave, zero regressions on-device |
| v1.0.1 (not v1.1) for the progress-bar + flash-fix milestone | App not yet publicly released — continuing under the v1.0 line rather than bumping to v1.1 until an actual release happens | ✓ Shipped 2026-07-04 — next milestone now free to become v1.1 |
| v1.1 bundled the paywall with real notarization in one milestone, not split | Shipping a paywall without real notarization means every paying customer's first launch is a Gatekeeper warning — a broken first impression for something just paid for; explicit user call | ✓ v1.1 shipped 2026-07-08 |
| Phase order within v1.1: Trial/lockout (10) → Settings UI on a stub (11) → real Polar.sh (12) → notarization (13) | De-risked the single-arbiter `shouldShow(...)` and the UI state machine before live network flakiness was introduced; notarization is functionally independent, sequenced last for release-readiness only | ✓ v1.1 shipped — no rework needed when the stub was swapped for the real service |
| Trial-start and license state stored in the Keychain, not UserDefaults/plist | UserDefaults-only trial storage is trivially reset via `defaults delete` — research pitfall | ✓ Phase 10 — verified on-device (survives `defaults delete` + reinstall) |
| License validation distinguishes "invalid key" (4xx) from "couldn't reach the server" (network/5xx) | Highest-consequence pitfall identified in research — a hard lock on a key someone just paid for would hit customers at peak purchase-regret risk | ✓ Phase 12 — strict HTTP→verdict split + Retry, verified on-device |
| Phase 14 (weather/calendar/date) executed inside the v1.1 working window but excluded from the v1.1 milestone close | Its requirements (WEATHER-01/CAL-01/OUTFIT-01) were never part of v1.1's Milestone Goal or REQUIREMENTS.md — closing v1.1 as Phases 10-13 keeps the archive accurate to what was actually scoped | Phase 14 stays on the live ROADMAP as completed, unarchived work — formal requirement capture deferred to next milestone |
| Song-change toast: skip (not queue/interrupt) when Charging/Device splash is active; suppress entirely while manually expanded; rapid skips restart the timer in place rather than queueing each one | Mirrors existing `resolve()` precedence and `TransientQueue.updateHead()`/Phase 17 D-03 gate precedents rather than inventing new queueing logic | ✓ Phase 18 — all three rules verified on-device |
| Toast design iterated on-device across 5 rounds to a minimal fading text row under the unchanged wings capsule, with its own independent ~2s dismiss (not the shared 3.0s `activityDuration`) | User's on-device feedback overrode the pre-execution 18-UI-SPEC.md draft each round; final shape ships shorter and simpler than originally speced | ✓ Phase 18 — approved after round 5, UI-SPEC updated to match |

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
*Last updated: 2026-07-09 — Phase 19 (Shelf Data Model, SHELF-08) shipped.*
