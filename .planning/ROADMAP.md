# Roadmap: Notch — Dynamic Island for Mac

## Overview

This roadmap takes a complete-beginner programmer from an empty Xcode project to a polished, notarized v1 Dynamic-Island app for the MacBook notch. It is deliberately spine-first: prove the riskiest beginner footguns early (a working sign→notarize→staple pipeline, then the borderless overlay window and notch geometry), then bolt on activities one at a time ordered by ascending risk. The build proves the activity→island loop on the safest data source (charging, public IOKit) before touching the single architectural landmine (Now Playing via the private-MediaRemote adapter), which is quarantined behind one service with a launch-time health check. Two correctness concerns that commonly sink real notch apps — hiding for true fullscreen and landing on the correct built-in notch display — are treated as core success criteria, not polish. v1 ships when the priority resolver makes media + charging + device events coexist gracefully and the app is signed, notarized, stapled, and opens cleanly on a second Mac.

## Phases

**Phase Numbering:**
- Integer phases (0, 1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 0: Foundations & Notarization Dry Run** - Menu-bar agent skeleton + launch-at-login + a proven sign→notarize→staple pipeline on a hello-world build
- [ ] **Phase 1: The Empty Island (Window + Geometry)** - A static black pill rendered exactly on the notch, above all windows, on the correct display through monitor/clamshell changes
- [ ] **Phase 2: Hover, Expand & Fullscreen Hardening** - Spring morph expand/collapse on hover, quiet when idle, and reliable hide for true fullscreen
- [ ] **Phase 3: Charging Activity** - Plug/unplug shows a charging splash with battery %, proving the activity→island loop on the safest API
- [ ] **Phase 4: Now Playing** - Album art + title/artist + play/pause/skip via the isolated MediaRemote adapter, with a graceful "unavailable" fallback
- [ ] **Phase 5: Device-Connected Activity** - AirPods/Bluetooth connect and disconnect splashes reusing the transient pattern
- [ ] **Phase 6: Priority Resolver, Settings & v1 Ship** - Activities coexist by sensible priority; minimal settings + accent theme; production notarized release

## Phase Details

### Phase 0: Foundations & Notarization Dry Run
**Goal**: A runnable menu-bar background agent (no Dock icon) whose entire sign→notarize→staple toolchain has been proven end-to-end on a hello-world build before any feature exists.
**Depends on**: Nothing (first phase)
**Requirements**: APP-01, APP-02, APP-04
**Success Criteria** (what must be TRUE):
  1. The app runs as a menu-bar agent with no Dock icon, and its menu can open settings and quit the app
  2. The user can toggle "launch at login" and the app actually starts (or stops starting) on next login
  3. A signed → notarized → stapled build of this hello-world app opens on a *second* clean Mac with no Gatekeeper warning
  4. The whole sign/notarize/staple flow is captured as a repeatable script the user can re-run, not hand-typed commands
**Plans**: 4 plans
Plans:
- [x] 00-01-PLAN.md — App shell: Islet Xcode project + menu-bar agent (no Dock) + status menu (Settings…, Quit)
- [ ] 00-02-PLAN.md — Settings window: Launch-at-Login toggle (SMAppService) + version label
- [x] 00-03-PLAN.md — Release pipeline: commented scripts/release.sh (sign→dmg→notarize→staple) with placeholders + .gitignore + docs/RELEASE.md
- [ ] 00-04-PLAN.md — Run the pipeline → dist/Islet.dmg + local Gatekeeper block demo (no second Mac)
**UI hint**: yes

### Phase 1: The Empty Island (Window + Geometry)
**Goal**: A borderless, always-on-top overlay window paints a static black rounded pill positioned exactly over the physical notch, on the correct built-in display, surviving every screen-configuration change.
**Depends on**: Phase 0
**Requirements**: ISL-01, ISL-02, ISL-06, ISL-07
**Success Criteria** (what must be TRUE):
  1. A black, rounded pill renders over the physical notch, matching the notch's width and corner radius on this MacBook
  2. The pill stays above other windows and remains visible across all Spaces / desktops
  3. With an external monitor connected and in clamshell mode, the pill stays on the built-in notch screen (or hides when the lid is closed) and never lands on the wrong display, recovering after plug/unplug and resolution changes
  4. When nothing is happening, the collapsed pill is near-invisible and not animating
**Plans**: TBD
**UI hint**: yes

### Phase 2: Hover, Expand & Fullscreen Hardening
**Goal**: The island feels like a Dynamic Island — it expands on hover with a smooth spring morph, collapses back to a quiet pill, and correctly yields the notch region to true fullscreen apps.
**Depends on**: Phase 1
**Requirements**: ISL-03, ISL-04, ISL-05
**Success Criteria** (what must be TRUE):
  1. Hovering the notch expands the island; moving the pointer away collapses it back to the quiet pill
  2. Expand and collapse animate as a smooth spring morph (Alcove-quality) with no flicker, jump, or cross-fade
  3. When an app enters true fullscreen (native fullscreen, fullscreen video, QuickLook), the island hides and leaves no ghost control bar, then restores when fullscreen exits
  4. Clicking the desktop or menu bar *around* the island passes through, and interacting with the island never steals focus from the active app
**Plans**: TBD
**UI hint**: yes

### Phase 3: Charging Activity
**Goal**: The first real live activity — plugging in or unplugging the power cable produces a transient charging/on-battery splash, proving the full activity→island rendering loop end-to-end on the safest, public API.
**Depends on**: Phase 2
**Requirements**: CHG-01, CHG-02
**Success Criteria** (what must be TRUE):
  1. Plugging in the power cable shows a charging animation plus battery percentage in the island for a few seconds, then collapses
  2. Unplugging shows a brief "on battery" indication
  3. The splash distinguishes actively-charging from plugged-in-but-full, and behaves sanely on a Mac with no charging state to read
  4. Power state is driven by event/notification sources with no long-lived polling timer, keeping idle CPU near 0%
**Plans**: TBD

### Phase 4: Now Playing
**Goal**: The core install driver — current media from any app shows album art, title, and artist in the island with working transport controls, built entirely behind one isolated service that fails gracefully when the system API is blocked.
**Depends on**: Phase 3
**Requirements**: NOW-01, NOW-02, NOW-03
**Success Criteria** (what must be TRUE):
  1. When media plays in any app (Apple Music, Spotify, a browser), the island shows album art, title, and artist
  2. The user can play/pause, skip to next, and go to previous track from the expanded island
  3. Now Playing survives app restart; when the media source is unavailable or the system API is blocked, the island clears state and shows an explicit "unavailable" indication instead of crashing or sitting empty
  4. All MediaRemote access lives behind a single service with a launch-time health check, consuming the adapter's streamed output (not re-spawning it) and hopping callbacks to the main thread
**Plans**: TBD
**UI hint**: yes

### Phase 5: Device-Connected Activity
**Goal**: The "reacts to my life" feel is completed — connecting or disconnecting AirPods / a Bluetooth audio device shows a brief activity, reusing the proven transient pattern from charging.
**Depends on**: Phase 4
**Requirements**: DEV-01, DEV-02
**Success Criteria** (what must be TRUE):
  1. Connecting AirPods or a Bluetooth audio device shows a connect activity (device name + icon) in the island
  2. Disconnecting a device shows a brief disconnect activity
  3. Device events are event-driven (no polling) and arrive without requiring intrusive permission prompts
**Plans**: TBD

### Phase 6: Priority Resolver, Settings & v1 Ship
**Goal**: All three activity sources coexist gracefully under one priority resolver, the user can configure which activities show and pick an accent/theme, and the app ships as a production notarized release.
**Depends on**: Phase 5
**Requirements**: COORD-01, APP-03
**Success Criteria** (what must be TRUE):
  1. When several activities occur close together (e.g. charging while music plays, then a device connects), the island shows them by a sensible priority without overlapping or glitching, and transient events yield back to the ambient state
  2. A minimal settings window lets the user choose which activities are shown and set an accent/theme, with choices persisting across restarts
  3. The Now Playing launch-time health check is re-verified and the production build is signed, notarized, and stapled, opening cleanly on a second Mac
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 0 → 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Foundations & Notarization Dry Run | 0/4 | Not started | - |
| 1. The Empty Island (Window + Geometry) | 0/TBD | Not started | - |
| 2. Hover, Expand & Fullscreen Hardening | 0/TBD | Not started | - |
| 3. Charging Activity | 0/TBD | Not started | - |
| 4. Now Playing | 0/TBD | Not started | - |
| 5. Device-Connected Activity | 0/TBD | Not started | - |
| 6. Priority Resolver, Settings & v1 Ship | 0/TBD | Not started | - |
