# Requirements: Notch — Dynamic Island for Mac (Islet)

**Defined:** 2026-07-13
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island.

## v1.5 Requirements — Home Focus & Widget Redesign

Home is decluttered to music-only (dropping the idle weather/calendar/date fallback now that Weather and Calendar have their own switcher tabs), file drops consolidate entirely into Tray with a Droppy-style Drop/AirDrop/Mail destination picker, Tray widens with larger file tiles, Weather is redesigned as an iOS-widget-style card (compact default, extended-with-forecast optional), and the expanded-state notch silhouette gains an outward-flaring top-edge transition — the idle/collapsed pill stays exactly as-is.

### Home

- [ ] **HOME-01**: Home shows live Now-Playing transport controls whenever something is playing (unchanged from today)
- [ ] **HOME-02** (REVISED 2026-07-14, Phase 30 discussion): When paused/stopped, Home shows the last-played track's cover+title WITH the same transport controls as the live state (play/pause/next/prev) — buttons get a new rounded-rectangle hover background in both live and last-played states. Superseded the original "without live transport controls" wording.
- [ ] **HOME-03**: When nothing has been played this session, Home shows an explicit empty state — the time/weather/calendar fallback glance is removed entirely (Weather/Calendar keep their own switcher tabs)

### Tray

- [x] **TRAY-01**: File-shelf content is visible only on the Tray tab — the additive shelf-strip-reveal on Home/Calendar/Weather is removed
- [x] **TRAY-02**: Dropping a file (from any tab) shows a Droppy-style Quick Action destination picker: Drop / AirDrop / Mail
- [x] **TRAY-03**: Choosing "Drop" stages the file into the Tray as today and switches the view to Tray so the result is visible
- [x] **TRAY-04**: Choosing "AirDrop" invokes the system AirDrop share sheet for the file; choosing "Mail" composes a new email with the file attached (Mail.app-only attachment support — documented, not silently discovered)
- [x] **TRAY-05**: The Tray view is widened with larger file tiles so more files are visible side-by-side

### Weather

- [ ] **WEATHER-01**: Weather tab shows a compact iOS-widget-style card by default — location, condition icon, current temperature, high/low
- [ ] **WEATHER-02**: A Settings toggle switches Weather to an extended widget adding a multi-day forecast row (day, icon, temp)

### Shape

- [x] **SHAPE-01**: The expanded-state notch silhouette gains an outward-flaring top-edge transition into the screen bezel; the idle/collapsed pill shape stays exactly as it is today

> **v1.6 Requirements (Liquid Glass & System HUD Suite) shipped 2026-07-19** — archived to `.planning/milestones/v1.6-REQUIREMENTS.md`. 11/12 requirements shipped, HUD-07 dropped (Phase 37 abandoned).

## v1.7 Requirements — Interaction & Calendar Polish

Fixes 4 real-usage interaction/layout regressions surfaced since v1.4-v1.6 shipped, plus 2 new Now Playing capabilities (favorite/like write-back, audio-output switcher) added mid-scoping and backed by dedicated research (`.planning/research/SUMMARY.md`). Started 2026-07-19 while v1.4 and v1.5 both remain open in parallel.

### Drag Detection

- [x] **DRAG-01**: The island's auto-expand / Quick Action destination picker (Drop/AirDrop/Mail) only triggers on a genuine external file drag approaching the island (via `DragApproachDetector`) — a plain click or hover on the collapsed/expanded island never triggers it
- [x] **DRAG-02**: The Quick Action picker (the during-drag view shown before a file lands) renders at the exact same width as the real Tray view, so file icon sizing is visually consistent between the drag-preview and landed states

### Tray

- [x] **TRAY-06**: The Tray/island is widened so every file icon fits without visual squeeze at typical file counts — per-file icon and button sizes stay unchanged from today

### View Switcher

- [x] **SWITCH-01**: Switching between Home/Tray/Calendar/Weather tabs animates the island continuously (single spring morph via the existing `matchedGeometryEffect`) directly to the new tab's size — no intermediate disappear/rebuild flicker
- [x] **SWITCH-02**: The visual glitch where the island briefly renders behind the switcher pill buttons during a large→small transition (e.g. Calendar → Tray) is eliminated

### Calendar Quick-Add

- [x] **CALVIEW-05**: Quick-add gains a date+time picker — Events get a start/end time range, Reminders get a single time. Default date is the calendar day the user tapped; default time is the next full hour if that day is today, otherwise 00:00
- [ ] **CALVIEW-06**: The add-event button moves from the right edge (currently visually clipped) to the left, next to the day-list divider
- [ ] **CALVIEW-07**: Calendar event rows get more padding/margin; the island grows a few pt wider and gains extra height to accommodate the added breathing room

### Now Playing — Favorite

- [ ] **FAV-01**: A star button, positioned left of the transport controls in the expanded Now Playing view, toggles the current track's favorite/liked status — writing back to the source app's own library: Apple Music via the AppleScript `loved` property, Spotify via its OAuth Web API for authorized accounts
- [ ] **FAV-02**: Spotify write-back works only for accounts explicitly authorized through Islet's own OAuth flow — a small, manually-approved set of users under Spotify's Development Mode quota (not unlimited without Spotify granting Extended Quota to an organization); documented as an accepted limitation, not silently discovered
- [ ] **FAV-03**: If a like/favorite write fails (e.g. Apple Music's documented bug for tracks not yet in the local library, or an unauthenticated/expired Spotify session), the star button visibly reflects the failure rather than silently appearing to succeed

### Now Playing — Audio Output Switcher

- [x] **OUTPUT-01**: A speaker-icon button, positioned right of the transport controls in the expanded Now Playing view, reveals a panel with a volume slider (a thick draggable bar) controlling the current audio output's volume
- [x] **OUTPUT-02**: The panel also shows a vertical list of all available system audio outputs, with the current output visually highlighted and shown on top, others listed below
- [x] **OUTPUT-03**: Tapping a non-current output in the list makes it the active system audio output and it animates to the top of the list (tap-to-select, not drag-to-reorder)
- [x] **OUTPUT-04**: The output list stays correct when a device connects or disconnects while the panel is open (e.g. AirPods reconnect) — no duplicate or stale entries, keyed by device UID not the ephemeral `AudioDeviceID`

## v1.8 Requirements — Settings Redesign & Island Navigation

Fixes the crowded, non-scrollable Settings window and adds two new interaction options — a compact top-edge switcher placement and a hover-to-resume affordance on the idle island. Started 2026-07-21 while v1.4, v1.5, and v1.7 all remain open in parallel.

### Settings

- [ ] **SETTINGS-02**: User can scroll to see all settings content when it exceeds the window height (fixes the current bug where Weather/Diagnostics are cut off and unreachable)
- [ ] **SETTINGS-03**: Settings' crowded General tab is split into new dedicated sidebar sections (e.g. Activities, Appearance, Fullscreen, Weather, Diagnostics) instead of one long list

### View Switcher

- [ ] **SWITCH-03**: User can choose an alternate compact switcher layout in Settings — 4 small icons at the top edge of the expanded island (2 left of the camera notch, 2 right) instead of the default pill below the island
- [ ] **SWITCH-04**: User can configure which icons appear on the left vs. right side of the top-edge layout (default: Home+Tray left, Calendar+Weather right)

### Now Playing — Resume

- [ ] **RESUME-01**: Hovering the collapsed island when nothing is playing expands it to preview the last track played this session (album art left, equalizer bars right) — same visual as the active Now Playing glance
- [ ] **RESUME-02**: Clicking the hover-preview resumes playback of that last track, if still possible

## v2 Requirements

Deferred to a future milestone, not in this roadmap.

### Architecture Redesign Polish (carried from v1.4)

- **ARCH-P1**: Animation Speed presets (Turtle/Human/Cheetah/Falcon-style) exposed as a Settings control, beyond v1.4's single fluid default curve (VISUAL-02)
- **ARCH-P2**: "Permissions Overview — X of Y granted" rollup row in Settings + a "Replay onboarding" button in About

### Other candidates (not yet scoped)

- Alternate app icon variants — descoped from Phase 27/VISUAL-03 (D-09/D-10): no icon assets exist yet; needs user-supplied icon files or a proper icon-design pass, not a Claude-generated placeholder
- Countdown timer
- Gesture-based swipe navigation (skip-track/tuck-away/return) — touches the same event-delivery layer as drag-in, revisit only after the architecture redesign is proven stable over time
- "Open Tray After Drop" convenience setting for the Quick Action picker's "Drop" outcome — Droppy-precedented, not in this milestone's explicit ask (research: FEATURES.md)
- Hourly forecast, weather alerts, radar — the milestone's own reference only asks for a daily forecast row (research: FEATURES.md)
- User-configurable flare depth/amount for SHAPE-01 — fixed design language for now
- Named/labeled Focus Mode detection ("Work Focus", "Sleep", etc.) — only if a future spike finds a reliable read path beyond the legacy binary DND flag (v1.6 research: PITFALLS.md)
- Dual-activity display generalized to 3+ concurrent activities — DUAL-01 explicitly scopes to exactly two; a third-slot model is out of scope until two-slot ships and is validated on real usage
- Full custom Sparkle install/progress flow rendered entirely as notch HUD — HUD-06 only needs the "available" notification, not the whole install UX
- Persisted "recently used outputs" quick-toggle ordering (audio-output switcher) — defer until the basic switcher is proven in daily use (v1.7 research: SUMMARY.md)
- Drag-to-promote/reorder as an accelerator on top of tap-to-select for the audio-output list — v1.7 research explicitly recommends tap-only for v1

## Out of Scope

| Feature | Reason |
|---------|--------|
| `NSSharingServicePicker` (the generic system share picker) | Research found the Services/Sharing menu machinery likely requires a key window; Islet's `NotchPanel` is deliberately never-key/non-activating. A custom 3-button SwiftUI picker calling `NSSharingService(named:).perform(withItems:)` directly is used instead. |
| WidgetKit / a real macOS widget extension | The "iOS-widget-style" ask (WEATHER-01/02) is purely visual — a styled card inside the existing panel, not a system widget extension |
| Full multi-day/hourly weather data beyond the daily forecast row | Anti-feature per research — the milestone's reference only shows a daily strip, not hourly/alerts/radar |
| Mail attachment support on non-Mail.app default clients | `NSSharingService(.composeEmail)` is confirmed Mail.app-specific for attachments; other clients degrade to an unattached `mailto:` — accepted limitation, not solved this milestone |
| OUTFIT-01 (the original combined weather+calendar+date Home glance) | Being actively removed from Home per HOME-03, not formalized — its calendar half already shipped independently as CALVIEW-01..04 |
| Named Focus Mode labels (HUD-05) | No confirmed public-or-quasi-public read path to the specific active Focus mode exists on current macOS — only the legacy binary DND flag is reliably readable; building UI around a mode name would stall on an unverified unknown (v1.6 research: PITFALLS.md) |
| True system-wide OSD suppression as an unconditional default (HUD-03/04) | The undocumented `defaults write com.apple.controlcenter EnableSystemBanners -bool false` toggle changes system behavior outside Islet's own window and is unverified beyond community forum reports; shipping it unconditionally without an on-device spike risks the confirmed Tahoe regression where a related technique breaks system-wide media-key passthrough |
| `SimplyCoreAudio` (or any third-party CoreAudio wrapper) for the audio-output switcher | Archived/unmaintained since March 2024; project's own "no dependency for a tiny native surface" precedent (IOKit, IOBluetooth) applies — public `AudioObject*`/`AudioHardwareService*` C API is a direct, small surface (v1.7 research: STACK.md) |
| Full MusicKit REST integration for Apple Music favorite/like | Unnecessary complexity for a same-Mac, same-user write — plain `NSAppleScript` against the `loved` property suffices (v1.7 research: FEATURES.md) |
| Fuzzy title/artist search to resolve Spotify track identity for favorite/like | False-positive risk (liking the wrong track); the track URI read directly from the current session is used instead (v1.7 research: PITFALLS.md) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHAPE-01 | Phase 29 | Complete |
| HOME-01 | Phase 30 | Pending |
| HOME-02 | Phase 30 | Pending |
| HOME-03 | Phase 30 | Pending |
| TRAY-01 | Phase 31 | Complete |
| TRAY-05 | Phase 32 | Complete |
| WEATHER-01 | Phase 33 | Pending |
| WEATHER-02 | Phase 33 | Pending |
| TRAY-02 | Phase 34 | Complete |
| TRAY-03 | Phase 34 | Complete |
| TRAY-04 | Phase 34 | Complete |
| DRAG-01 | Phase 43 | Complete |
| TRAY-06 | Phase 44 | Complete |
| DRAG-02 | Phase 44 | Complete |
| SWITCH-01 | Phase 45 | Complete |
| SWITCH-02 | Phase 45 | Complete |
| CALVIEW-05 | Phase 46 | Complete |
| CALVIEW-06 | Phase 46 | Pending |
| CALVIEW-07 | Phase 46 | Pending |
| OUTPUT-01 | Phase 48 | Complete |
| OUTPUT-02 | Phase 48 | Complete |
| OUTPUT-03 | Phase 48 | Complete |
| OUTPUT-04 | Phase 48 | Complete |
| FAV-01 | Phase 50 | Pending |
| FAV-02 | Phase 50 | Pending |
| FAV-03 | Phase 50 | Pending |
| SETTINGS-02 | Phase 51 | Pending |
| SETTINGS-03 | Phase 51 | Pending |
| SWITCH-03 | Phase 52 | Pending |
| SWITCH-04 | Phase 52 | Pending |
| RESUME-01 | Phase 53 | Pending |
| RESUME-02 | Phase 53 | Pending |

**Coverage (v1.5):**
- v1.5 requirements: 11 total
- Mapped to phases: 11 (100%)
- Unmapped: 0

**Coverage (v1.7):**
- v1.7 requirements: 15 total
- Mapped to phases: 15 (100%)
- Unmapped: 0
- Phase 47 (Audio Output — Pure Seam + Monitor) and Phase 49 (Favorite/Like — Spike) carry no formal REQ-ID themselves — they're infrastructure/spike phases preceding Phase 48/50's user-facing requirements, mirroring this project's own Phase 15/16/19 and Phase 22-01/24-01/38-01/39-01 precedent.

**Coverage (v1.8):**
- v1.8 requirements: 6 total
- Mapped to phases: 6 (100%)
- Unmapped: 0

v1.6's traceability table (GLASS-01, HUD-01..08, EQ-01, ONBOARD-04, DUAL-01) is archived in `.planning/milestones/v1.6-REQUIREMENTS.md`.

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-21 — v1.8 (Settings Redesign & Island Navigation) requirements defined: 6 requirements (SETTINGS-02/03, SWITCH-03/04, RESUME-01/02), not yet mapped to phases. v1.4, v1.5, and v1.7 all remain open in parallel — v1.7 paused at Phase 49 (Favorite/Like spike aborted, Phase 50 undecided).*
*v1.7 (Interaction & Calendar Polish) roadmap created: 8 phases (43-50), 100% coverage (15/15). Phase order: Drag Detection Hardening (43) → Tray & Quick Action Width Alignment (44, DRAG-02 bundled with TRAY-06 to avoid touching the shared width geometry twice) → View Switcher Morph Fix (45) → Calendar Quick-Add Improvements (46) — all 4 independent, no research dependency — then Audio Output Switcher split pure-seam-first (47) then UI wiring (48, hard dependency on 47), then Favorite/Like split spike-first (49) then implementation (50, hard dependency on 49), per research's explicit risk-isolation recommendation and this project's own Phase 22/24, Phase 38/39 spike-first precedent. Phase numbering continues from Phase 42 (v1.6's last phase).*
*v1.4 and v1.5 both remain open in parallel — v1.5's Phase 33 (Weather widget) on-device UAT still pending.*
*v1.6 (Liquid Glass & System HUD Suite) shipped and archived to `.planning/milestones/v1.6-REQUIREMENTS.md`/`.planning/milestones/v1.6-ROADMAP.md`.*
*v1.5 requirements defined 2026-07-13 — Roadmap created: 6 phases (29-34), 100% coverage (11/11). Phase order Flare → Home → Shelf Consolidation → Tray Widening → Weather → Quick Action Picker, per research recommendation and this project's pure-seams-first/risk-isolated-last convention (Phase 22→24 drag-in precedent). Corrected the "10 total" count from initial requirements definition — the actual v1.5 requirement list (HOME-01..03, TRAY-01..05, WEATHER-01..02, SHAPE-01) is 11 IDs.*
*v1.8 (Settings Redesign & Island Navigation) roadmap created: 3 phases (51-53), 100% coverage (6/6). Phase order: Settings Reorganization & Scroll Fix (51) → Top-Edge Switcher Layout & Placement Config (52) → Hover-to-Resume Idle Preview (53) — Settings and Switcher independently restructure already-shipped subsystems (Phase 27 sidebar, Phase 28/45 switcher tab system) with no dependency between them; Resume sequenced last since it carries this milestone's one open technical question (whether resuming a non-active track is supported by the existing NowPlayingMonitor/MediaRemote adapter transport) to verify early within its own phase. Phase numbering continues from Phase 50 (v1.7's last reserved phase, not yet executed).*
