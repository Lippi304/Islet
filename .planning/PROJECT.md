# Notch — Dynamic Island for Mac

> Working title. Final product name is TBD (see Key Decisions).

## What This Is

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities. **Shipped in v1.0/v1.0.1:** now-playing media controls with working transport and a progress bar, a charging activity, a Bluetooth/AirPods device-connected activity, and a minimal settings window with three activity toggles + accent theming — all arbitrated by a single priority resolver so activities coexist gracefully. **Shipped in v1.1:** Islet is now a real, sellable product — a tamper-resistant 3-day free trial with hard lockout, a one-time €7.99 purchase via Polar.sh (live checkout, online validation, offline-capable Keychain cache), and a genuinely Developer-ID-notarized release pipeline. **Also shipped (ahead of formal milestone scope):** a weather + calendar + date glance in the expanded idle view. **Shipped in v1.2:** the Now Playing glance no longer appears at launch for an already-paused track (only a real Play does it), and genuine song changes show a brief fading title+artist toast with its own Settings toggle. **Shipped in v1.3:** a session-only drag-and-drop file shelf — files can be staged in a horizontally-scrolling strip below the expanded island and dragged back out to Finder/other apps — though dragging files *in* by dropping them onto the collapsed island is not yet working (blocked, carried into v1.4). **Shipped in v1.4:** a rebuilt panel architecture that resolved the drag-in blocker, a first-launch onboarding flow, a frosted/glossy visual redesign with per-element accent theming and a sidebar-based Settings window, and a 4-view switcher pill (Home/Tray/Calendar/Weather) below the expanded island — Home now shows Now Playing controls whenever something is playing (falling back to the idle glance otherwise), Tray is a dedicated full-files view, Calendar is a month-grid + day-list view with quick-add, and Weather shows enlarged current conditions. System HUD replacement and a countdown timer remain planned for a future milestone, not yet built.

It is for Mac users who love the iPhone Dynamic Island and want it on their MacBook without paying for the existing closed-source apps (Alcove, DynamicLake). Built by a first-time programmer with the goal of a polished, possibly sellable product down the line.

## Core Value

The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island. If everything else is cut, that core island experience must work. Still the right priority after v1.1 — the paywall and notarization work protects and monetizes the core experience without changing it.

## Current State

**v1.6 Liquid Glass & System HUD Suite shipped 2026-07-19** (Phases 35-42, see `.planning/milestones/v1.6-ROADMAP.md`). 11 of 12 v1.6 requirements shipped and on-device verified — HUD-07 (Drop-session summary chip) was abandoned after on-device UAT found its Tray-close trigger essentially never fires under normal use, and dropped from scope. Islet now has a shader-based "Liquid Glass" background material (with a native macOS 26 `.glassEffect()` fast path), five new/restyled collapsed-state system HUDs (Bluetooth/Charging restyles, Focus Mode, Volume/Brightness with genuine native-OSD suppression, Update-available via real Sparkle 2 integration, Calendar Countdown), a redesigned equalizer + onboarding signature heading, and a new dual-activity display concept (a secondary bubble alongside the main pill when two top-priority activities are live at once — e.g. Calendar Countdown + Now Playing). See Requirements → Validated below for the full per-phase breakdown.

**v1.3 Notch Shelf shipped 2026-07-11 with a known gap** (Phases 19-21, see `.planning/milestones/v1.3-ROADMAP.md`). 7 of 9 v1.3 requirements shipped and on-device verified: the shelf data model, the full shelf view (icons, per-item/delete-all trash, click-to-open, correct gating), and drag-out to Finder/other apps. **SHELF-01/02 (drag-in) did not ship** — Phase 22 spiked successfully (AppKit drag delivery does reach a click-through `NSPanel`) but then failed on-device twice for an unidentified reason (`draggingEntered` never fired despite a working spike using the same technique). Rather than keep debugging incrementally, the user chose to redesign the underlying `NotchPanel`/`NotchWindowController` architecture — this becomes the anchor of v1.4, alongside new scope inspired by a competitor app ("Droppy," found on Reddit): a first-launch onboarding flow, a visual/material redesign, and a full-screen calendar view. See `.planning/research/inspiration/notes.md` for the reference material. SHELF-01/02 carry forward as requirements into v1.4.

**v1.2 Now Playing Polish shipped 2026-07-09** (Phases 17-18, see `.planning/milestones/v1.2-ROADMAP.md`). All 3 v1.2 requirements (NOW-04, NOW-05, NOW-06) shipped and on-device verified. The Now Playing glance no longer fires at launch for a merely-paused track, and genuine song changes surface a brief title+artist toast (independent 2s dismiss, its own Settings toggle) — both refined through on-device iteration.

**v1.1 Trial & Paid Release shipped 2026-07-08** (Phases 10-13, see `.planning/milestones/v1.1-ROADMAP.md`). All 7 v1.1 requirements (TRIAL-01/02/03, LIC-01/02/03, DIST-01) shipped and verified on-device. Islet is now a genuinely distributable, sellable product: real Developer-ID signing/notarization, a Keychain-backed tamper-resistant trial with hard lockout, and live Polar.sh purchase + offline-capable validation.

**Also shipped ahead of formal milestone scope (Phase 14, weather/calendar/date; Phase 15/16, architecture refactor):** the `expandedIdle` glance shows live weather (WeatherKit), the next calendar event (EventKit), and the date alongside the time readout, in a 3-column layout that degrades silently on permission denial — still needs its own requirement IDs (WEATHER-01, CAL-01, OUTFIT-01) captured whenever a milestone formally covers it. Phase 15/16 were pure architecture cleanup (DI seams, DeviceCoordinator extraction), zero product-behavior change.

## Next Milestone Goals

v1.8 (Settings Redesign & Island Navigation) started 2026-07-21 — see "Current Milestone: v1.8" below. v1.4 (Architecture Redesign), v1.5 (Home Focus & Widget Redesign), and v1.7 (Interaction & Calendar Polish) all remain open in parallel — v1.5 only needs Phase 33's on-device UAT to close, v1.7 is paused mid-milestone (Phase 49 Favorite/Like spike aborted after weak on-device results, Phase 50 undecided). Other standing candidates for a future milestone: a countdown timer, gesture-based swipe navigation, Animation Speed presets (ARCH-P1), a Permissions Overview rollup (ARCH-P2), alternate app icon variants (still Out of Scope below until picked up), and Phase 49/50's Favorite/Like feature decision.

## Milestone In Progress (Parallel): v1.5 (Home Focus & Widget Redesign)

**Goal:** Declutter Home to music-only, consolidate all file-drop behavior into Tray (with a Droppy-style Drop/AirDrop/Mail destination choice), redesign Weather as an iOS-widget-style card, widen/enlarge the Tray file layout, and give the expanded-state notch silhouette an outward-flaring top edge.

**Status:** Not formally closed — left open in parallel while v1.6 planning begins (explicit user decision, 2026-07-15). 5/6 phases complete: Phase 29 (SHAPE-01, NotchShape flare), Phase 30 (HOME-01/02/03, Home music-only), Phase 31 (TRAY-01, shelf consolidation to Tray-only), Phase 32 (TRAY-05, Tray Widening) shipped 2026-07-14; Phase 34 (TRAY-02/03/04, Quick Action Destination Picker) shipped 2026-07-15 after a post-UAT drag-target redesign. Phase 33 (WEATHER-01/02, Weather widget redesign) code-complete, on-device UAT (Task 4) pending. Resume with `/gsd-verify-work 33` once UAT passes to formally close v1.5.

**Target features:**
- Home shows ONLY Now Playing — live controls while something plays, cover+title (no live controls) for the last-played track while paused/stopped; the time/weather/calendar glance is fully removed from Home (Weather and Calendar already have their own switcher tabs).
- File shelf/Tray becomes the sole home for file drops — the additive shelf-strip-reveal on other tabs (Home/Calendar/Weather) is removed. Dropping a file from any tab opens a Droppy-style Quick Action picker with destination choices: Drop (stage into Tray, existing behavior), AirDrop, Mail — reference: Droppy's "Quick Action Layout" screenshot.
- Tray view widened with larger file icons so more files are visible side-by-side, matching Droppy's file-forward layout.
- Weather redesigned as an iOS-widget-style card (location, condition icon, current temp, H/L) — a compact widget is the default; a Settings toggle switches to an extended widget adding a multi-day forecast strip (requires a new WeatherKit forecast call, previously deferred in Phase 28 — now explicitly requested). Reference screenshot captured showing target layout (Local / 16° Cloudy H:24 L:15 / 6-day forecast row).
- NotchShape gains an outward flare transition into the top screen edge, applied ONLY to the expanded state — the idle/collapsed pill silhouette is explicitly unchanged (stays flush/straight into the edge as today).

See `.planning/research/inspiration/notes.md` for the Droppy reference material (additional Quick-Action and widget reference screenshots captured during v1.5 discussion — see discussion log once written).

<details>
<summary>v1.6 Liquid Glass & System HUD Suite — original scope (shipped 2026-07-19)</summary>

**Goal:** Give Islet an edgier "Liquid Glass" material look and a suite of new Droppy-style collapsed-state system HUDs, plus a new dual-activity display concept for when two top-priority activities are live at once.

**Target features:**
- **Liquid Glass material** — glossier, blurred/frosted (not glass-clear) background material replacing the current gradient material, across expanded + collapsed island. User supplies reference implementation code during the relevant phase.
- **Music equalizer bars redesign** — new visual design for the Now Playing bars. User supplies reference implementation code during the relevant phase.
- **Onboarding signature heading** — the first onboarding page's "Welcome to Islet" text is replaced by a static rainbow-gradient signature-style script heading (originally a live reveal animation, descoped per D-14 — see Phase 36 below); scoped to that one page only, the app's regular font is untouched.
- **New collapsed-state system HUDs (Droppy-style):**
  - Volume HUD — replaces (suppresses) the native macOS volume OSD
  - Brightness HUD — replaces (suppresses) the native macOS brightness OSD
  - Focus Mode HUD — shows when the user toggles Focus/Do Not Disturb
  - Update-available HUD — paired with a real Sparkle auto-update integration (net-new to the project)
  - Bluetooth/AirPods HUD — restyle of the existing Device-Connected activity in the Droppy look
  - Charging HUD — restyle of the existing Charging activity in the Droppy look
  - Drop-session summary chip — after closing the Shelf/Tray following a drop session, briefly shows "N files saved"
  - Calendar countdown HUD — starting 1 hour before a calendar event, the collapsed pill shows a live minutes-countdown (calendar icon left, event time right)
- **Dual-activity display (new resolver concept)** — when two top-priority activities are live simultaneously (e.g. calendar countdown + now playing), the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning; generalizes beyond just Calendar+Music to any two competing top-priority activities. Extends today's single-winner `IslandResolver`.

**Key context:**
- Volume/Brightness OSD suppression and Focus Mode detection are technical unknowns similar in kind to the MediaRemote precedent (undocumented/private-API territory) — good candidates for a research phase before planning.
- User will supply custom reference code for the Liquid Glass material and the equalizer bars redesign during their respective phases.

**Outcome:** 11/12 requirements shipped (HUD-07 dropped — Phase 37 abandoned after on-device UAT found its Tray-close trigger essentially never fires in normal use). Volume/Brightness OSD suppression, initially found unreliable in Phase 39's spike, was later proven working via a gap-closure plan using `.cghidEventTap`. See Requirements → Validated above for the full per-phase breakdown and `.planning/milestones/v1.6-ROADMAP.md` for the archived roadmap.

</details>

## Milestone In Progress (Parallel): v1.7 (Interaction & Calendar Polish)

**Goal:** Fix a set of real-usage interaction and layout bugs surfaced since v1.4-v1.6 shipped — no new features, pure polish. Started 2026-07-19 while v1.4 and v1.5 both remain open in parallel (explicit user decision).

**Status:** Paused, not shipped. 5/8 phases complete (43-47); Phase 48 (Audio Output Switcher — UI Wiring) is code-complete and on-device approved, awaiting formal verification/close. Phase 49 (Favorite/Like Spike) was explicitly paused by the user after Plans 01-02 showed weak results (SC#1 like-effect-not-observed; SC#2 Apple Music `loved` broken via AppleScript in all 4 states tested) — Plan 03 (Spotify PKCE) left incomplete, Plan 04 (go/no-go synthesis) never started. Phase 50 (Favorite/Like Implementation) is undecided pending a user call on whether/how to revisit the feature. Resume with `/gsd:verify-work 48` then a decision on Phase 49/50.

**Target features:**
- **Drag-detection hardening** — the `DragApproachDetector`/Quick Action picker auto-expand currently false-triggers on an ordinary click on the island, not just a real external file drag approaching it; must only fire on a genuine inbound file drag. The Quick Action picker (the during-drag view) should render at the exact same width as the real Tray view.
- **Tray/Island width** — the island widens so all file icons in the Tray fit without visual squeeze; per-file icon/button sizes stay unchanged.
- **View-switcher transition fix** — switching tabs (Home/Tray/Calendar/Weather) currently makes the island briefly disappear and rebuild instead of morphing fluidly straight to the new content's size; includes the glitch where a large→small transition (Calendar → Tray) briefly renders behind the switcher pill buttons.
- **Calendar quick-add improvements:**
  - A date+time picker: Events get a start/end time range, Reminders get a single time.
  - Default date = the calendar day the user tapped. Default time = the next full hour if that day is today, otherwise 00:00.
  - The add-event button moves from the right edge (currently visually clipped) to the left, next to the day-list divider.
  - More padding/margin around calendar event rows; the island grows a few pt wider and gains extra height to accommodate.

**Key context:**
- All 4 items are regressions/rough edges in already-shipped features (Phase 24/34 drag-in + Quick Action picker, Phase 28 calendar view + Phase 32 Tray widening, Phase 28's view switcher) — no new domain research needed, scoped directly from user report.
- The view-switcher "disappear and rebuild" symptom suggests the tab-switch is doing a hard content swap rather than a continuous `matchedGeometryEffect` morph — worth investigating the switcher's presentation-state wiring at plan time.

## Current Milestone: v1.8 (Settings Redesign & Island Navigation)

**Goal:** Fix the crowded, non-scrollable Settings window and add two new interaction options for how the app is navigated — a compact top-edge switcher placement and a hover-to-resume affordance on the idle island. Started 2026-07-21 while v1.4, v1.5, and v1.7 all remain open in parallel (explicit user decision).

**Target features:**
- **Settings scroll fix + reorganization** — the Settings window's General tab currently overflows with no way to scroll to the cut-off content (Weather/Diagnostics sections below the fold are unreachable); fix the scrolling bug and split General's crowded content into new dedicated sidebar sections (e.g. Activities, Appearance, Fullscreen, Weather, Diagnostics) instead of one long list.
- **Configurable switcher placement** — in addition to today's switcher-pill-below-the-expanded-island (the default), add an alternate compact layout: 4 small icons at the very top edge of the expanded island, 2 to the left of the camera/notch and 2 to the right. Default split is Home+Tray left, Calendar+Weather right, but which icon goes on which side is user-configurable in Settings, not fixed.
- **Hover-to-resume on the idle island** — hovering the collapsed island when nothing is currently playing expands it the same way it does for an active Now Playing session (album art left, equalizer bars right), showing the last track played this app session; clicking it resumes that track if still possible. Reuses the hover-reveals-affordance / tap-toggles-playback interaction pattern already shipped for the Phase 42 dual-activity secondary bubble.

**Key context:**
- All 3 items are UI/UX polish and new interaction affordances on top of already-shipped subsystems (Settings sidebar from Phase 27, the view switcher from Phase 28/45, the secondary-bubble pattern from Phase 42) — no new external API or domain research expected.
- "Last played this session" is scoped to not persist across app relaunch (explicit user decision) — nothing shown if nothing has played yet since Islet launched.
- Resuming a past track depends on what MediaRemote/the adapter actually supports outside an active session — worth a quick technical check during phase planning rather than assumed.

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

**Shelf View (Phase 20 — SHELF-03, SHELF-04, SHELF-05, SHELF-07, SHELF-09):**

- [x] The expanded island renders a horizontally-scrolling shelf strip below whatever else is showing (Now Playing, idle glance, etc.) whenever it has content — each item shows a file-type icon with its own trash icon, a single "delete all" trash clears everything at once, clicking an item opens it in its default app, and the strip is suppressed while a Charging or Device wings splash is actively showing. On-device UAT closed a click-through regression (CR-01: an invisible 56pt band under an empty shelf was silently swallowing clicks) by scoping `syncClickThrough()`'s hit-test to the actual visible blob rect instead of the full static panel. (Phase 20)

**Drag-Out (Phase 21 — SHELF-06):**

- [x] A shelf item can be dragged out of the expanded island onto Finder or any other app via `.onDrag` + `NSItemProvider(contentsOf:)` (copy semantics — the item stays in the shelf, default system drag preview, silent no-op on a vanished backing file). The island pins open for the duration of the drag (best-effort `.leftMouseUp` release monitor + a 20s safety-net fallback) and resumes normal hover/grace-collapse promptly once the drag ends. On-device UAT surfaced and fixed two gaps beyond the original plan: the shelf strip was invisible because `NotchPillView.body`'s outer container frame hadn't grown to match `blobShape`'s Phase-20 shelf-height addition (commit `3b38f33`), and — added at explicit user request during UAT, beyond the original D-02 scope — a shelf item whose backing file is deleted externally is now auto-pruned on expand instead of sitting inert until manually trashed (commit `dfbde2d`). (Phase 21)

**Shell Parity Rewrite (Phase 23 — ARCH-01):**

- [x] `NotchPanel`/`NotchWindowController` reconstructed in place with zero behavioral regression — the Phase-22 `NSDraggingDestination` drag scaffold is fully removed (with a `testPanelHasNoDraggingDestinationResidue` regression guard), and every other line (positioning, hover/click/grace-collapse, fullscreen hiding, the CR-01 click-through fix, multi-Space visibility) was re-verified against the pre-rewrite implementation and found to already match byte-for-byte — 2 files touched project-wide, `IslandResolver.swift`/`DeviceCoordinator.swift`/`Islet/Shelf/` show zero diff. Closed out via a blocking human on-device UAT checkpoint (20 items incl. the CR-01 hover→expand→move-down trace) the user explicitly approved. Clears the architectural prerequisite for Phase 24 (Drag-In). (Phase 23)

**Visual/Material Theming Redesign (Phase 25 — VISUAL-01, VISUAL-02):**

- [x] Shared black-to-transparent vertical gradient material (`islandMaterial`) replaces flat black fills across the collapsed pill, expanded island, and all activity wings; expanded-blob bottom corner radius raised 20→32pt for a rounder, more Dynamic-Island-like silhouette. Pure rendering-value change confined to `NotchPillView.swift`/`NotchWindowController.swift` — no new files/types, individual activity content untouched. (Phase 25 — VISUAL-01)
- [x] Spring animation retuned (response 0.35→0.6, damping 0.65→0.62) for a slower, single-overshoot morph matching the iPhone Dynamic Island's characteristic bounce, applied uniformly through the existing shared spring constants. (Phase 25 — VISUAL-02)
- On-device UAT (7-point checklist: gradient depth, pure black, corner roundness, spring feel, no morph artifacts, rapid hover-enter/exit, activity-content regression) passed on first attempt on real notch hardware — the documented `NotchShape.swift` `animatableData` contingency was not needed. VISUAL-03 (Settings theming section) intentionally out of this phase, carried to Phase 27.

**Settings Sidebar Redesign + Theming (Phase 27 — SETTINGS-01, VISUAL-03):**

- [x] `SettingsView` restructured from a 3-tab `TabView` into a `NavigationSplitView` sidebar (General/Workspace/System/About), every existing control relocated verbatim, no section-switch state staleness. (Phase 27 — SETTINGS-01)
- [x] New System (Theming) section: a Gradient/Solid Black material-style picker plus 3 independent per-element accent pickers (Now Playing/Charging/Device), replacing the single shared accent index; live-applies to the pill/expanded island/wings via the existing UserDefaults-observer re-host pipeline. A one-time migration seeds the 3 new keys from the legacy single accent so existing users' accent choice carries forward. (Phase 27 — VISUAL-03)
- On-device UAT checkpoint found and fixed 2 real regressions that no automated build/grep check could catch: Settings not opening at all via the menu bar icon (`.defaultLaunchBehavior(.suppressed)` silently prevented the Settings `Window(id:)` scene from ever being created), and the sidebar navigation being completely unresponsive to clicks (`List(selection:)` never registered a click regardless of 3 fix attempts; replaced with a plain `Button`-based row implementation). Both root-caused via targeted diagnostic instrumentation rather than static reasoning alone. Full 10-step on-device walkthrough approved. (Phase 27)

**Calendar Full View (Phase 28 — CALVIEW-01, CALVIEW-02, CALVIEW-03, CALVIEW-04):**

- [x] Month-grid + selected-day event list calendar view (EventKit), quick-add for both Events and Reminders (Reminders permission requested lazily on first use) without leaving the island; a switcher pill below the expanded island for navigating between views. (Phase 28 — CALVIEW-01/02/03/04)
- [x] **User-amended beyond the original locked design, confirmed on-device during the checkpoint:** the switcher grew from the originally-planned 3 icons (Home/Tray/Calendar) to 4 (Home/Tray/Calendar/Weather); "Home" now conditionally shows Now-Playing controls when something is playing and the idle date/time glance otherwise (previously the idle glance was unconditional — a deliberate reversal of the "don't copy Droppy's music-default" research note, re-decided by the user live on-device); Tray became its own dedicated files-only resolver case (`.trayExpanded`) rather than the originally-planned additive shelf-strip-under-Home approach, to match the Droppy reference exactly. All three amendments are recorded with rationale in `28-CONTEXT.md`/`28-UI-SPEC.md`, not silent drift. (Phase 28)
- [x] Weather tab shows enlarged current conditions only (category + temperature, reusing the existing `WeatherGlance` data) — no forecast/hourly data was added; a real multi-day forecast would need a new WeatherKit call and data model, deliberately left as an open follow-up rather than built without asking. (Phase 28)
- Shipped after 6 rounds of on-device UAT (camera-notch clipping, switcher hidden during media playback, resolver precedence blocking Calendar/Weather during playback, calendar grid density vs. the Droppy reference, a switcher-pill position-jump causing misclicks, and a SwiftUI `.buttonStyle(.plain)` hit-test gap on the switcher icons) plus a post-approval code-review-and-fix pass that closed 2 further critical bugs (a click-through phantom band reintroduced by the dedicated Tray view; quick-add silently targeting a stale month after navigation) and 4 quality warnings. (Phase 28)

_v1.4 (Architecture Redesign) is code-complete — all 6 phases shipped 2026-07-11 through 2026-07-13. 2 items remain in `28-HUMAN-UAT.md` (status: partial) pending final on-device re-confirmation of the two code-review fixes; run `/gsd:verify-work` once confirmed._

**Shelf Consolidation to Tray-Only (Phase 31 — TRAY-01):**

- [x] The additive shelf-strip-reveal on Home/Calendar/Weather is removed; file-shelf content is visible only on the Tray tab — `shelfStripVisible` is a shared hardcoded-`false` gate wired into all 5 non-Tray `blobShape` call sites, `visibleContentZone()`'s click-through geometry simplified to match, and `trayFullView`'s own `shelfRow(_:)` path is unaffected. (Phase 31)
- Implementation shipped ahead of formal planning via quick task 260714-3k6; this phase added a regression test (initially insufficient — code review caught it testing an empty shelf, unable to distinguish a hard-coded `false` from empty-shelf `false`; fixed to seed a non-empty shelf) and ran the on-device CR-01-class hover→expand→move-down click-through trace, user-approved with zero regressions. Clears `visibleContentZone()` to be touched only once by Phase 32 (Tray Widening). (Phase 31)

_Phase 29 (SHAPE-01, NotchShape flare) and Phase 30 (HOME-01/02/03, Home music-only) shipped 2026-07-14 but are not yet individually itemized here — see `.planning/ROADMAP.md` Phase 29/30 detail sections and their SUMMARY.md files for what shipped._

**Quick Action Destination Picker (Phase 34 — TRAY-02, TRAY-03, TRAY-04):**

- [x] Dragging a file into the island's accept region shows a Drop/AirDrop/Mail picker DURING the drag (dragEntered edge), with live per-button hover highlighting and release-on-target selection — replaces the click-based picker rejected during on-device UAT. `computeQuickActionButtonFrames(card:)` (pure geometry, unit-tested) plus controller-side hit-testing in `NotchWindowController` drive the whole interaction; no `Button(action:)` taps involved. (Phase 34)
- [x] Choosing Drop stages the file(s) into Tray (TRAY-03); choosing AirDrop/Mail invokes `NSSharingService` directly with zero window-activation code, re-confirmed on real hardware (TRAY-04). Dragging back out before releasing discards the pending file(s) with no orphaned session copy (D-13b/Pitfall 6 fix). (Phase 34)
- Shipped after a full replan: the original click-based implementation (Wave 1 of the original 34-01/34-02) passed code but was rejected in on-device UAT, then rebuilt as the drag-target model described above and re-verified on-device (7/7 checkpoint checks passed). Code review flagged one carried-forward critical issue (CR-01: synchronous main-thread file copy on drag-enter, no debounce) as a non-blocking fast-follow — see `34-REVIEW.md`. (Phase 34)

**Liquid Glass Material (Phase 35 — GLASS-01):**

- [x] The shared background material (collapsed pill, expanded island, all 3 activity wings) replaced by a dark, frosted "Liquid Glass" look — a solid dark frost layer masks a warped `.ultraThinMaterial` backdrop, revealed only as a narrow, chromatic-fringed rim-light right at the rounded edge (`liquidGlassEffectLayer` in `NotchPillView.swift`, `LiquidGlassShader.metal`/`.swift`). Applied as a modifier on the existing shape node at all 4 fill sites, preserving `matchedGeometryEffect` morph continuity. Settings' Theming picker gained a 3rd "Liquid Glass" segment as the new default (D-06); the Settings window itself gets a calmer, non-distorted variant of the same look, gated on that same style choice. (Phase 35)
- Shipped after 4 rounds of on-device UAT rejection/remediation — round 1 (opaque base, no visible transparency), round 2 (raw vibrancy material read as uniformly bright, no dark tint), round 3 (unmasked chromatic-fringe/white-wash screen-blending washed the dark frost center back toward grey), round 4 (masked those layers to the same rim falloff the frost layer already uses — approved). Post-approval code review found and fixed one carried-forward critical issue (Settings window background wasn't gated on the user's material choice) plus two maintainability warnings — see `35-REVIEW.md`. (Phase 35)

**Cosmetic Restyles & Signature Animation (Phase 36 — HUD-01, HUD-02, EQ-01, ONBOARD-04):**

- [x] Bluetooth/AirPods (HUD-01) and Charging (HUD-02) collapsed wing HUDs restyled to the Droppy-pill look — a left-wing icon+label shown only in the positive state, independent left/right wing-flank sizing so a wide label never stretches the opposite flank; `DeviceCoordinator`/`BluetoothMonitor`/IOKit power monitor unchanged. Charging's trigger condition was corrected from the raw IOKit `isCharging` flag to `isOnAC && !isCharged`, since macOS "Optimized Battery Charging" routinely leaves the literal flag false while genuinely charging. (Phase 36)
- [x] Now Playing equalizer bars (EQ-01) redesigned to the Skiper25 reference — thinner bars, wider gaps, fixed white color, periodic-reroll-and-spring motion replacing the old continuous sine wave, idle-CPU gate preserved; mandatory Skiper UI attribution added to Settings. (Phase 36)
- [x] Onboarding signature heading (ONBOARD-04) — scope-pivoted mid-execution (D-14): the originally planned live stroke-reveal animation was replaced with a static, non-animated "Meet Islet" heading in Dancing Script Bold, "Meet" in a blue→purple→pink gradient and "Islet" in an orange→yellow→green gradient, mirroring Droppy's own static rainbow-gradient onboarding heading. The pivot followed real font-licensing risk (the reference's original font, Lastoria Bold, is all-rights-reserved, not legally shippable in a paid product) plus repeated stroke-weight/clipping friction with the animated approach; body subtext below it untouched. (Phase 36)
- Code review found no blockers; one open, non-blocking warning carried forward: the widened Charging/Connected wing labels may extend past the existing tap hot-zone (on-device tap test confirmed no regression — see `36-REVIEW.md` WR-02). (Phase 36)

**Focus Mode HUD (Phase 38 — HUD-05):**

- [x] A generic on/off Focus/Do Not Disturb HUD — `FocusModeMonitor` polls `INFocusStatusCenter.focusStatus.isFocused` every 2.5s (Path A, confirmed reachable via an on-device spike over the research-predicted Assertions.json/FDA fallback), driving a collapsed-pill wing (icon-only left flank, dot+"On"-label right flank, redesigned live on-device from the original icon+label/bare-dot spec). Opt-in Settings toggle, default OFF, with a manual permission-status hint popover. (Phase 38)
- On-device UAT found and fixed two hidden-requirement gaps beyond `authorizationStatus == .authorized`: a missing `NSFocusStatusUsageDescription` Info.plist key that hard-crashed at first `INFocusStatusCenter` access, and a missing Communication Notifications entitlement without which `isFocused` silently resolves to `false` forever (not nil) — both undetected until 38-09's actual functional read against live state, not just an authorization check. All 4 ROADMAP Success Criteria confirmed; 9/9 plans shipped including gap-closure. (Phase 38)

**Volume & Brightness HUD (Phase 39 — HUD-03, HUD-04):**

- [x] Volume and Brightness key presses show a Droppy-pill HUD (icon + fill-bar wing) via a pure `OSDActivity` model ranked into a dedicated collapsed-only `IslandResolver` tier, reading live levels from CoreAudio/DisplayServices. (Phase 39 — HUD-03/HUD-04)
- [x] Native system OSD suppression — reversed from 39-01's initial "unreliable" spike finding: a `.cgSessionEventTap` failed to suppress the notch-integrated OSD, but gap-closure plan 39-08 found `.cghidEventTap` (HID-level, before the Window Server session layer) works, matching `dannystewart/volumeHUD`'s proven technique. Islet now self-drives real system volume/brightness/mute via `AudioObjectSetPropertyData`/`DisplayServicesSetBrightness` whenever a press is swallowed, with a per-type kill switch that falls back to passthrough if a self-drive write ever fails — the Settings suppression toggle is now a real control, not the originally-shipped no-op. Zero transport-key regressions across all 4 media keys on-device. (Phase 39)
- A genuinely reusable lesson from a 16-round on-device layout debugging saga: `.offset()`/`.position()` both silently misbehave for content placed inside `wingsShape`'s content `ZStack`; the fix was a plain `HStack(spacing: 0)` with fixed-width `Color.clear` spacers for excluded regions — the same pattern every other wing already used. See STATE.md decision log (39-07) for the full diagnostic record. (Phase 39)

**Update-Available HUD & Sparkle Integration (Phase 40 — HUD-06):**

- [x] Real Sparkle 2.9.4 auto-update integration (`SPUStandardUpdaterController`, generated EdDSA keypair) — tapping an available update triggers Sparkle's own standard install/progress dialog, not a custom in-notch flow. (Phase 40 — HUD-06)
- [x] The update-available indicator was redesigned mid-phase from a collapsed-pill corner badge to a small red dot on the menu-bar status-item icon, after on-device UAT root-caused the badge's tap-dispatch bug to a click-through hot-zone gap in `NotchWindowController` (the same fragility class later re-found and fixed in Phase 42's own hot-zone work) — the status-item dot sidesteps the whole click-through-zone bug class by construction. `UpdateAvailableState.swift` and the pill badge overlay were deleted. Release-archive launch confirmed crash-free under Hardened Runtime with the embedded Sparkle.framework. (Phase 40)

**Calendar Countdown HUD (Phase 41 — HUD-08):**

- [x] Starting 1 hour before a calendar event, the collapsed pill shows a live minute-countdown (calendar icon left, mm:ss right, recoloring orange→red together from one shared per-tick `TimelineView` value) via a dedicated, event-driven `CalendarCountdownMonitor` with its own one-shot-deadline timer — ambient only, never touches `TransientQueue`. Ranked ahead of Now-Playing wings in `IslandPresentation`. Default-ON Settings toggle, no permission surface (reads through the existing EventKit service layer). (Phase 41 — HUD-08)
- On-device UAT found and fixed a real-hardware-only bug: the countdown text's leading digit rendered under the physical camera housing until the wing's right flank was widened from `wingsSize.width/2` to `wingsLabelWidth/2`, reusing the existing label-clearing constant `deviceWings` already established rather than a new magic number. (Phase 41)

**Dual-Activity Display (Phase 42 — DUAL-01):**

- [x] When Calendar Countdown and Now Playing are both live, the collapsed island shows the countdown pill plus a small round secondary bubble (real album art) instead of one activity strictly winning — additive `IslandResolver.resolveSecondary()` extension, `IslandPresentation`/`resolve()` untouched. Primary/secondary pairing is expressed as a genuine small ordered table (per locked decision D-03), scoped to today's 2 activity kinds. (Phase 42)
- [x] Tapping/hovering the bubble was redesigned live during on-device UAT: hovering darkens the bubble and reveals a play/pause glyph matching current playback state; tapping toggles play/pause directly via the existing `NowPlayingMonitor.togglePlayPause()` — this supersedes the original plan's tap-to-expand/no-hover design (D-12/D-13), by explicit user decision, not scope drift. (Phase 42)
- Code review found no blockers; one warning (hardcoded hot-zone offset) was fixed post-review since it duplicated the exact fragility class that caused the Phase 40-03 badge-tap regression — see `42-REVIEW.md`/`42-VERIFICATION.md`. Three smaller warnings (duplicated launch-gate derivation, a missing `deinit` cancel, hover-state view scoping) remain as non-blocking backlog. (Phase 42)

**Drag Detection Hardening (Phase 43 — DRAG-01):**

- [x] The island's auto-expand / Quick Action destination picker only fires on a genuine external file drag approaching it — an ordinary click or hover on the collapsed/expanded island never triggers it. Fixed via `isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:)`, a pasteboard-change-count gate wired into `recheckDragAcceptRegion`'s auto-expand arm branch. (Phase 43 — DRAG-01)
- On-device UAT of the fix took 4 rounds and found 2 further real regressions no build/unit-test gate could see: the island got permanently stuck expanded after discarding a drag (the auto-collapse grace-timer only fires from `.mouseMoved`-driven hover-exit, which never occurs during an active OS drag session), and even after that was fixed, resolving the Quick Action picker still briefly flashed the underlying Home/Now-Playing/Tray content before collapsing. Both closed by adding a dedicated `.dismissed` state-machine event (immediate `expanded → collapsed`, no grace defer) and a shared `dismissExpandedImmediately()` helper consolidating all 4 picker-resolution paths (Drop, AirDrop, Mail, discard). See `43-02-SUMMARY.md` for the full round-by-round record. (Phase 43)

**View Switcher Morph Fix (Phase 45 — SWITCH-01, SWITCH-02):**

- [x] Tab switches (Home/Tray/Calendar/Weather) morph continuously with no disappear/rebuild flicker and no large→small behind-buttons z-order glitch. Root cause was `presentationSwitch` calling `blobShape` from 6 textually-distinct case branches — SwiftUI's structural-identity model treats a case change as remove+insert, not update. Fixed by collapsing all 6 switcher-row cases into one shared `tabContentView` call site (`tabWidth`/`tabHeight` computed properties, content-only inner switch), giving every case one continuous view identity for `matchedGeometryEffect` to morph across. On-device 12-pairwise-transition sweep (both directions) plus an interrupted-mid-morph-tap retarget check confirmed the fix with zero regressions. (Phase 45 — SWITCH-01, SWITCH-02)

### Active

<!-- Current scope. Building toward these. All are hypotheses until shipped. -->

_v1.5 (Home Focus & Widget Redesign) — see `.planning/ROADMAP.md`/`.planning/REQUIREMENTS.md` for the full 11-requirement traceability table (not yet archived — still open in parallel). Remaining: Phase 33 on-device UAT (WEATHER-01/02)._
_v1.7 (Interaction & Calendar Polish) — see "Current Milestone: v1.7" above. Phases 43-45 (Drag Detection Hardening, Tray & Quick Action Width Alignment, View Switcher Morph Fix) shipped. Remaining: Phase 46 (Calendar Quick-Add Improvements) onward._

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
- **v1.3 codebase state (shipped 2026-07-11, includes Phases 15/16 architecture refactor + Phase 17/18 v1.2 + Phase 19-21 shelf):** ~9,200 LOC Swift, 261 passing unit tests (up from 185 at v1.1 close). Added the session-only shelf stack (`ShelfItem`/`ShelfLogic`/`ShelfFileStore`/`ShelfCoordinator`), its full view (icons, trash, click-to-open, gating), and outbound drag-to-Finder — all with zero persistence and zero coupling to `IslandResolver`/`TransientQueue`. Phase 22 (drag-in) code remains on disk but unshipped: 22-01 (spike) and 22-02 (pure seams) are merged; 22-03's `NotchPanel`/`NotchWindowController` wiring is not, and the debugging worktree with the failed attempts is preserved separately for reference (see STATE.md).
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
| v1.3 phase order 19→20→21→22 (model → view → drag-out → drag-in) with the drag-in risk isolated in the final phase | Pure-seam-first is this project's established convention; isolating the one genuinely uncertain integration point (drag delivery through the click-through `NSPanel`) meant a spike/iteration there wouldn't block the rest of the feature | ✓ Phases 19-21 shipped clean; Phase 22 isolation worked exactly as intended — the failure stayed contained to Phase 22 |
| v1.3 closed as shipped-with-a-known-gap rather than left permanently open | SHELF-01/02 (drag-in) blocked twice on-device with an unidentified root cause; leaving v1.3 open indefinitely while pursuing a broader architecture redesign would misrepresent what actually shipped (data model, view, drag-out are real, verified, and independently valuable) | ✓ v1.3 shipped 2026-07-11 — SHELF-01/02 carried forward as requirements into v1.4 |
| Phase 22 drag-in abandoned in favor of a NotchPanel/NotchWindowController architecture redesign, rather than continuing incremental debugging | Two on-device UAT failures with `draggingEntered` never firing, root cause unidentified even after restoring the 22-01 spike's exact working technique — explicit user call to stop debugging blind and reconsider the window/panel architecture more broadly (referencing TheBoringNotch/DynamicNotchKit) | ✓ Phase 23 shipped 2026-07-11 — shell rebuilt with zero behavioral regression, on-device UAT approved; Phase 24 can now retry drag-in on the reproven shell |
| v1.4 scope expanded beyond the architecture redesign to include Droppy-inspired onboarding, visual redesign, and a calendar view — but explicitly NOT gesture-based swipe navigation | User found a competitor app ("Droppy") on Reddit during v1.3's blocked window; gestures would touch the same event-delivery layer that just failed and was deliberately kept out of scope until the architecture redesign proves itself first | Pending — v1.4 scoping in progress |
| Phase 25 (Visual/Material Theming) executed ahead of Phase 24 (Drag-In) in numeric order | Pure rendering-value change with no dependency on the architecture redesign's drag-in outcome — could ship independently without blocking or being blocked | ✓ Phase 25 shipped 2026-07-11 — gradient material + spring retune, on-device UAT approved |
| Minimum macOS deployment target raised 14.0 → 15.0 (revises Phase 0's original D-06 "macOS 14.0 floor") | Phase 26 on-device UAT found Settings re-opening at launch via AppKit's own window-state restoration (independent of app logic, surfaced by repeated Xcode Stop/Cmd-R cycles during testing); the fix is `.defaultLaunchBehavior(.suppressed)` (macOS 15+ only), and SwiftUI's `SceneBuilder` has no `if #available`/type-eraser path to keep it optional — pre-release project, dev hardware is already macOS 26, explicit user approval | ✓ Phase 26 — `project.yml` updated (all 5 deploymentTarget/MACOSX_DEPLOYMENT_TARGET entries), clean rebuild verified |
| "Home" shows Now-Playing controls when something is playing, idle glance otherwise — reverses the original v1.4 research note ("keep the idle default, don't copy Droppy's music-default") | User re-decided live on-device during Phase 28's checkpoint, after finding the original design made Now-Playing an unreachable, switcher-blocking override rather than a selectable state; explicitly confirmed via an orchestrator clarifying question before implementation, not a silent drift | ✓ Phase 28 — resolver precedence rewritten so explicit Tray/Calendar/Weather selection always wins, Now-Playing only wins on Home |
| Switcher pill expanded from the originally-locked 3 icons (Home/Tray/Calendar, D-01) to 4 (adds Weather) | User's own on-device request mid-checkpoint, after the 3-icon design already shipped through 3 rounds of UAT; Weather reuses existing current-conditions data only — no new WeatherKit forecast call was added without asking first | ✓ Phase 28 — `SelectedView`/`IslandPresentation` both gained a `.weather`/`.weatherExpanded` case |
| Tray became its own dedicated files-only resolver case (`.trayExpanded`) instead of the originally-planned additive shelf-strip-under-Home approach | User's on-device comparison against Droppy's actual Tray page, which shows only files, never glance content underneath; the original additive design (Phase 20/28 D-02) was kept for auto-reveal-on-drop from OTHER tabs, which stays unbroken | ✓ Phase 28 — `forcedByTray` removed as dead code once Tray had its own presentation case |
| Liquid Glass material pivoted to SwiftUI's native `.glassEffect()` on macOS 26+, with the custom Metal shader stack (D-01–D-19) kept as the <26 fallback | A round-5 post-completion regression (flat grey rim) surfaced after 4 rounds of shader-based on-device UAT remediation already got GLASS-01 approved; native `.glassEffect()` matched the target look with far less shader-tuning risk going forward | ✓ Phase 35 — D-20, both paths shipped |
| Phase 37 (Drop-Session Summary Chip) abandoned rather than redesigned | The chip's Tray-close trigger requires an explicit close action, but in real usage the Island stays open showing dropped files and isn't closed right away — the trigger essentially never fires under normal use; user decided the feature isn't worth keeping | ✓ All 3 implementation plans reverted via `git revert`, HUD-07 dropped from the v1.6 requirement set |
| Focus Mode detection uses `INFocusStatusCenter` Path A (polled `isFocused`), not the Assertions.json/FDA fallback (Path B) | An on-device spike confirmed Path A reaches `.authorized`; Path B needs a manual, unprompted Full Disk Access grant with zero automatic TCC prompt — worse UX for the same generic on/off signal | ✓ Phase 38 — shipped, though `isFocused` also silently required the undocumented Communication Notifications entitlement beyond authorization, found only via 38-09's actual functional read |
| Volume/Brightness native OSD suppression re-attempted and shipped via `.cghidEventTap`, reversing Phase 39's own initial "unreliable" spike finding | `.cgSessionEventTap` (session-level) didn't suppress the notch-integrated OSD on this hardware, but `.cghidEventTap` (HID-level, before the Window Server session layer) does, confirmed via `dannystewart/volumeHUD`'s (MIT) proven technique | ✓ Phase 39 gap-closure (39-08) — zero transport-key regressions across all 4 media keys on real hardware |
| Update-available indicator redesigned from a collapsed-pill corner badge to a menu-bar status-item dot | On-device UAT root-caused the badge's tap-dispatch bug to a click-through hot-zone gap in `NotchWindowController` — the status-item dot is always fully clickable by construction, sidestepping the whole click-through-zone bug class rather than patching the geometry | ✓ Phase 40 — `UpdateAvailableState.swift` and the pill badge overlay deleted |
| Dual-activity secondary bubble's interaction redesigned live from tap-to-expand/no-hover (locked D-12/D-13) to hover-reveal play/pause | User's explicit on-device UAT round-3 decision, not scope drift — hovering darkens the bubble and reveals a play/pause glyph, tapping toggles playback directly via the existing `NowPlayingMonitor` | ✓ Phase 42 — see `42-04-SUMMARY.md`/`42-CONTEXT.md` supersession notes |

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
*Last updated: 2026-07-21 — Milestone v1.8 (Settings Redesign & Island Navigation) started: Settings scroll/reorganization fix, a user-configurable top-edge switcher layout, and hover-to-resume on the idle island. v1.4 (Architecture Redesign), v1.5 (Home Focus & Widget Redesign), and v1.7 (Interaction & Calendar Polish) all remain open in parallel (explicit user decision) — v1.5 only needs Phase 33's on-device UAT to close, v1.4 has 2 items in `28-HUMAN-UAT.md` pending final on-device re-confirmation, v1.7 is paused at Phase 49 (Favorite/Like spike aborted, Phase 50 undecided) with Phase 48 code-complete/on-device approved but awaiting formal verification. v1.6 (Liquid Glass & System HUD Suite) shipped 2026-07-19, archived to `.planning/milestones/v1.6-ROADMAP.md`/`.planning/milestones/v1.6-REQUIREMENTS.md`.*
