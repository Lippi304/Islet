# Requirements: Notch — Dynamic Island for Mac

**Defined:** 2026-06-26
**Core Value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.

## v1 Requirements

Focused core. Match Alcove's polish on a small, solid feature set. Each maps to a roadmap phase.

### Island (ISL)

- [x] **ISL-01**: A black, rounded island renders over the physical notch on the built-in display, matching the notch's width and corner radius
- [x] **ISL-02**: The island stays above other windows and is visible across all Spaces / desktops
- [x] **ISL-03**: Clicking the notch expands the island; hovering gives a haptic + subtle bounce affordance without expanding (D-02 Alcove model); moving the pointer away collapses it back to a quiet pill
- [x] **ISL-04**: Expanding and collapsing animate with a smooth spring morph (Alcove-quality), with no flicker or jump
- [x] **ISL-05**: The island hides/yields correctly when an app enters true fullscreen (video playback, native fullscreen)
- [x] **ISL-06**: The island positions on the correct screen when external displays are connected and in clamshell mode (never lands on the wrong display)
- [x] **ISL-07**: When no activity is happening, the collapsed island is unobtrusive (near-invisible, not animating)

### Now Playing (NOW)

- [ ] **NOW-01**: When media plays in any app (Apple Music, Spotify, a browser, etc.), the island shows the album art, title, and artist
- [ ] **NOW-02**: User can play/pause, skip to next, and go to previous track from the expanded island
- [ ] **NOW-03**: Now Playing survives app restart and degrades gracefully (clears state, no crash) when the media source is unavailable or the system API is blocked

### Charging Activity (CHG)

- [x] **CHG-01**: Plugging in the power cable shows a charging animation plus battery percentage in the island for a few seconds, then collapses
- [x] **CHG-02** *(descoped → connect-only)*: ~~Unplugging shows a brief "on battery" indication~~ — by user decision during Phase 3 on-device UAT (2026-06-27) the charging activity is **connect-only**: plugging in animates, unplugging deliberately shows nothing. The `.onBattery` state is still classified in the model but never triggers a splash.

### Device Activity (DEV)

- [ ] **DEV-01**: Connecting AirPods or a Bluetooth audio device shows a connect activity (device name + icon) in the island
- [ ] **DEV-02**: Disconnecting a device shows a brief disconnect activity

### Activity Coordination (COORD)

- [ ] **COORD-01**: When several activities occur close together (e.g. charging + track change), the island shows them by a sensible priority without overlapping or glitching

### App & Distribution (APP)

- [ ] **APP-01**: The app runs as a menu-bar / background agent with no Dock icon, with a menu to open settings and quit
- [ ] **APP-02**: User can enable "launch at login" from settings
- [ ] **APP-03**: A minimal settings window lets the user choose which activities are shown and set an accent/theme
- [x] **APP-04**: The app ships as a Developer-ID signed + notarized + stapled download that opens on a clean Mac without Gatekeeper warnings

## v2 Requirements

Deferred to a later milestone (still in product scope, after the core island ships). Tracked, not in the current roadmap.

### Now Playing polish (NOW)

- **NOW-04**: Seek / scrub bar with elapsed time on the expanded Now Playing view
- **NOW-05**: Sneak-peek — the island briefly auto-expands on a track change, then collapses
- **NOW-06**: Color-adaptive tint — the island accent adapts to the album art's dominant color
- **NOW-07**: Decorative animated waveform on the album art (not a real audio tap)

### Timer (TMR)

- **TMR-01**: User can start a countdown / Pomodoro timer that shows as a live activity in the island

### Device polish (DEV)

- **DEV-03**: AirPods per-bud battery percentage shown on connect

### File Shelf (SHELF)

- **SHELF-01**: User can drag files onto the island to hold them temporarily, then drag them back out
- **SHELF-02**: User can share / AirDrop a held file from the shelf

### HUD Replacement (HUD)

- **HUD-01**: Volume changes show a notch-based HUD instead of the system default
- **HUD-02**: Brightness changes show a notch-based HUD instead of the system default

## Out of Scope

Explicitly excluded. Documented to prevent scope creep. Anti-features carry a warning.

| Feature | Reason |
|---------|--------|
| Messaging / notification mirroring (iMessage, WhatsApp, Slack) | No clean public API — needs Notification-Center scraping / accessibility hacks; fragile, privacy-loaded, high maintenance |
| Calls / FaceTime / phone integration | Requires non-public Continuity/CallKit-adjacent hooks; brittle |
| Calendar + weather glance | EventKit permissions + weather API + widget layout = a side-project that doesn't touch core island value |
| File conversion / zip-unzip | Kitchen-sink utility, unrelated to the island |
| Clipboard history manager | Separate product domain (storage, search, privacy) |
| Camera mirror / teleprompter | Camera permission + AVFoundation, unrelated to island value |
| Non-notch Macs / external-display floating pill | Doubles the hardest part (window geometry) before the core works; v1 targets notch Macs only |
| Synced lyrics (LRCLIB) | Network + sync logic; polish, not core |
| Mac App Store distribution | Now Playing needs the private MediaRemote API → guaranteed App Store rejection; direct notarized download instead |
| Real audio-tap visualizer | Audio capture is permission-heavy and hard; a decorative waveform looks identical to users (NOW-07) |

## Traceability

Each v1 requirement maps to exactly one phase. See ROADMAP.md for phase detail.

| Requirement | Phase | Status |
|-------------|-------|--------|
| APP-01 | Phase 0 | Pending |
| APP-02 | Phase 0 | Pending |
| APP-04 | Phase 0 | Complete |
| ISL-01 | Phase 1 | Complete |
| ISL-02 | Phase 1 | Complete |
| ISL-06 | Phase 1 | Complete |
| ISL-07 | Phase 1 | Complete |
| ISL-03 | Phase 2 | Complete |
| ISL-04 | Phase 2 | Complete |
| ISL-05 | Phase 2 | Complete |
| CHG-01 | Phase 3 | Complete |
| CHG-02 | Phase 3 | Descoped (connect-only, UAT 2026-06-27) |
| NOW-01 | Phase 4 | Pending |
| NOW-02 | Phase 4 | Pending |
| NOW-03 | Phase 4 | Pending |
| DEV-01 | Phase 5 | Pending |
| DEV-02 | Phase 5 | Pending |
| COORD-01 | Phase 6 | Pending |
| APP-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 19 ✓
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-26*
*Last updated: 2026-06-27 — Phase 3 complete (CHG-01 verified; CHG-02 descoped to connect-only per on-device UAT)*
