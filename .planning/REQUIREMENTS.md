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

> **v1.8 Requirements (Settings Redesign & Island Navigation) shipped 2026-07-21** — archived to `.planning/milestones/v1.8-REQUIREMENTS.md`. 6/6 requirements shipped (SETTINGS-02/03, SWITCH-03/04, RESUME-01/02).

> **v1.9 Requirements (Clipboard History) shipped 2026-07-23** — archived to `.planning/milestones/v1.9-REQUIREMENTS.md`. 7/7 requirements shipped.

## v1.10 Requirements — Live Activities Suite

Adds 9 new Live Activities/HUDs (inspired by Droppy and the open-source Ice) plus a Droppy-style Settings grid overview to manage all Live Activities (existing + new) in one place. Scoped via a `superpowers:brainstorming` session followed by `.planning/research/` (STACK/FEATURES/ARCHITECTURE/PITFALLS/SUMMARY.md). Started 2026-07-23 while v1.4, v1.5, and v1.7 all remain open in parallel.

### Settings

- [x] **SETTINGS-04**: The Activities-related Settings sections are replaced by one Droppy-style grid of cards — one card per Live Activity (existing + new), each showing a mini live-preview of that activity's pill, its title, a one-line description, and an on/off toggle
- [x] **SETTINGS-05**: Every new Live Activity introduced this milestone defaults OFF; every already-shipped activity's existing default (mostly ON, Focus Mode OFF) is preserved exactly as-is by the migration — no existing user's persisted toggle state silently flips

### Caps Lock

- [x] **CAPS-01**: Toggling Caps Lock briefly shows an on/off HUD in the collapsed island (same transient wings pattern as Charging), auto-dismissing after ~1-2s

### Update-Activity

- [x] **UPDATE-01**: The existing Sparkle update-available HUD is reskinned to the Droppy look (leading icon, "Update" label, trailing version pill) — trigger logic and Sparkle plumbing unchanged

### Timer/Pomodoro

- [x] **TIMER-01**: User can start a countdown timer from the notch with a chosen duration; the collapsed island shows a live mm:ss countdown while running
- [x] **TIMER-02**: The expanded island offers pause/reset/add-time controls for a running timer
- [x] **TIMER-03**: When the timer completes, the island shows a completion HUD splash and the system plays a notification/sound
- [x] **TIMER-04**: A Pomodoro mode cycles work/break durations with a session counter, selectable as an alternative to a plain one-shot countdown

### Quick Notes

- [ ] **NOTES-01**: User can quickly capture a typed text note from the notch (menu-bar flyout, mirroring the existing Clipboard History submenu)
- [ ] **NOTES-02**: Each captured note is appended, with a timestamp, to one fixed .md file inside a user-chosen Obsidian vault folder — the file is created if missing, never overwritten/corrupted, and the append works even while Obsidian.app is closed
- [ ] **NOTES-03**: A local, unencrypted recent-notes list is shown in the same flyout, mirroring Clipboard History's most-recent-first list (decision: plaintext is fine since notes are destined for a plaintext vault file anyway — no AES-GCM parity with Clipboard History needed)

### Quick Actions

- [ ] **QACTION-01**: Settings lets the user enable/reorder a Quick Actions bar shown in the notch, choosing from a fixed catalog: mic mute/unmute, display sleep now, dark/light mode toggle, screen lock, Do Not Disturb toggle (best-effort), caffeinate/keep-awake toggle, empty Trash, launch app/open URL
- [ ] **QACTION-02**: Tapping an enabled Quick Action performs it immediately without expanding the notch any further than the action bar itself
- [ ] **QACTION-03**: The Do Not Disturb/Focus action is documented as best-effort (no stable public macOS API) — a failure is visible to the user, not silently swallowed

### Download-Progress

- [x] **DL-01**: When a file starts downloading into ~/Downloads (browser temp-file convention), the notch shows a live "downloading" indicator
- [x] **DL-02**: When the temp file is renamed to its final filename (download complete), the indicator shows a brief "done" state then clears — no exact-percentage guarantee across all browsers (presence + completion signal only)

### Meeting-HUD

- [x] **MEET-01**: While Zoom or Teams (native app) is running AND the microphone is active, the notch shows a call-timer HUD (elapsed mm:ss)
- [x] **MEET-02**: Tapping the Meeting-HUD's mute control toggles the system-wide microphone mute (not the in-app mute state) via a shared `MicMuteController`
- [x] **MEET-03**: Google Meet (browser-based) is explicitly not detected in v1.10 — documented as a known limitation, not silently missing

### Coding-Progress

- [ ] **CODE-01**: While a Claude Code CLI session with an active todo list is running (detected via a user-installed hook writing local status), the notch shows the todo completion fraction (e.g. "3/7")
- [ ] **CODE-02**: When no todo list is active but a session is running, the notch falls back to a short current-status text instead of showing nothing
- [ ] **CODE-03**: Islet ships (or generates via Settings) the hook script and documents the one-time setup step the user must perform in their own Claude Code config — an onboarding/documentation requirement, not just engineering
- [ ] **CODE-04**: When the Claude Code session ends or goes stale (no update within a timeout), the Coding-Progress indicator clears rather than showing stale state indefinitely

### Menübar-Overflow

- [ ] **MENUBAR-01**: A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons, mirroring Ice's MVP mechanic
- [ ] **MENUBAR-02**: The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section
- [ ] **MENUBAR-03**: Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden, not just repositioned off-screen while occupying visual space
- [ ] **MENUBAR-04**: This feature requires a new Accessibility permission grant, requested with a clear one-time explanation — distinct from Islet's existing WeatherKit/EventKit/Bluetooth permission prompts

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
| Full Obsidian Local REST API integration for Quick Notes | Requires the user to install/keep running a separate Obsidian community plugin — raises the bar past what "quick capture" should need; plain append to a user-chosen .md file is the lightweight pattern real Obsidian quick-capture tools already use (v1.10 research: FEATURES.md) |
| True per-app in-call mute state for Meeting-HUD (Zoom/Teams internal mute) | No public API/AppleScript surface exists; would require fragile, app-version-specific Accessibility hacks — system-wide CoreAudio input mute is used instead (v1.10 research: FEATURES.md) |
| Download pause/resume/cancel control | Not exposed to third-party apps by the OS without a browser extension — presence/completion only (v1.10 research: FEATURES.md) |
| Full custom action-scripting sandbox for Quick Actions | Scope creep toward a mini Shortcuts.app; a fixed catalog of ~8 pre-built actions with enable/reorder is used instead (v1.10 research: FEATURES.md) |
| Full Ice feature parity for Menübar-Overflow (always-hidden section, hover/scroll-to-reveal, auto-rehide timer, menu-bar tint/shape) | Menübar-Overflow is already the highest-risk feature in the milestone; MVP is one chevron, click-to-toggle only — everything else is a future-milestone candidate (v1.10 research: FEATURES.md) |
| Google Meet call detection for Meeting-HUD | Meet runs in a browser tab; no filesystem/process signal identifies it without a browser extension (v1.10 research: FEATURES.md) |
| AES-GCM at-rest encryption for Quick Notes (parity with Clipboard History) | Notes are destined for a plaintext Obsidian vault file anyway — local encryption of Islet's own copy was judged not worth the added complexity (explicit user decision) |
| Focus Mode auto-enable during a Timer/Pomodoro work session | No public API exists (same gap as the Quick Actions DND toggle) — revisit only if Apple ships one (v1.10 research: FEATURES.md) |

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
| SETTINGS-04 | Phase 59 | Complete |
| SETTINGS-05 | Phase 59 | Complete |
| CAPS-01 | Phase 60 | Complete |
| UPDATE-01 | Phase 60 | Complete |
| DL-01 | Phase 61 | Complete |
| DL-02 | Phase 61 | Complete |
| TIMER-01 | Phase 62 | Complete |
| TIMER-02 | Phase 62 | Complete |
| TIMER-03 | Phase 62 | Complete |
| TIMER-04 | Phase 62 | Complete |
| MEET-01 | Phase 63 | Complete |
| MEET-02 | Phase 63 | Complete |
| MEET-03 | Phase 63 | Complete |
| NOTES-01 | Phase 64 | Pending |
| NOTES-02 | Phase 64 | Pending |
| NOTES-03 | Phase 64 | Pending |
| QACTION-01 | Phase 65 | Pending |
| QACTION-02 | Phase 65 | Pending |
| QACTION-03 | Phase 65 | Pending |
| MENUBAR-01 | Phase 66 | Pending |
| MENUBAR-02 | Phase 66 | Pending |
| MENUBAR-03 | Phase 66 | Pending |
| MENUBAR-04 | Phase 66 | Pending |
| CODE-01 | Phase 67 | Pending |
| CODE-02 | Phase 67 | Pending |
| CODE-03 | Phase 67 | Pending |
| CODE-04 | Phase 67 | Pending |

**Coverage (v1.5):**
- v1.5 requirements: 11 total
- Mapped to phases: 11 (100%)
- Unmapped: 0

**Coverage (v1.7):**
- v1.7 requirements: 15 total
- Mapped to phases: 15 (100%)
- Unmapped: 0
- Phase 47 (Audio Output — Pure Seam + Monitor) and Phase 49 (Favorite/Like — Spike) carry no formal REQ-ID themselves — they're infrastructure/spike phases preceding Phase 48/50's user-facing requirements, mirroring this project's own Phase 15/16/19 and Phase 22-01/24-01/38-01/39-01 precedent.

**Coverage (v1.10):**
- v1.10 requirements: 27 total
- Mapped to phases: 27 (100%)
- Unmapped: 0

v1.6's traceability table (GLASS-01, HUD-01..08, EQ-01, ONBOARD-04, DUAL-01) is archived in `.planning/milestones/v1.6-REQUIREMENTS.md`.

v1.8's traceability table (SETTINGS-02/03, SWITCH-03/04, RESUME-01/02 — 6/6 shipped) is archived in `.planning/milestones/v1.8-REQUIREMENTS.md`.

v1.9's traceability table (CLIP-01..05, PRIV-01/02 — 7/7 shipped) is archived in `.planning/milestones/v1.9-REQUIREMENTS.md`.

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-23 — v1.9 (Clipboard History) shipped and archived to `.planning/milestones/v1.9-REQUIREMENTS.md`/`.planning/milestones/v1.9-ROADMAP.md` — 4 phases (55-58), 7/7 requirements shipped. v1.4, v1.5, and v1.7 all remain open in parallel — v1.7 paused at Phase 49 (Favorite/Like spike aborted, Phase 50 undecided).*
*v1.7 (Interaction & Calendar Polish) roadmap created: 8 phases (43-50), 100% coverage (15/15). Phase order: Drag Detection Hardening (43) → Tray & Quick Action Width Alignment (44, DRAG-02 bundled with TRAY-06 to avoid touching the shared width geometry twice) → View Switcher Morph Fix (45) → Calendar Quick-Add Improvements (46) — all 4 independent, no research dependency — then Audio Output Switcher split pure-seam-first (47) then UI wiring (48, hard dependency on 47), then Favorite/Like split spike-first (49) then implementation (50, hard dependency on 49), per research's explicit risk-isolation recommendation and this project's own Phase 22/24, Phase 38/39 spike-first precedent. Phase numbering continues from Phase 42 (v1.6's last phase).*
*v1.4 and v1.5 both remain open in parallel — v1.5's Phase 33 (Weather widget) on-device UAT still pending.*
*v1.6 (Liquid Glass & System HUD Suite) shipped and archived to `.planning/milestones/v1.6-REQUIREMENTS.md`/`.planning/milestones/v1.6-ROADMAP.md`.*
*v1.5 requirements defined 2026-07-13 — Roadmap created: 6 phases (29-34), 100% coverage (11/11). Phase order Flare → Home → Shelf Consolidation → Tray Widening → Weather → Quick Action Picker, per research recommendation and this project's pure-seams-first/risk-isolated-last convention (Phase 22→24 drag-in precedent). Corrected the "10 total" count from initial requirements definition — the actual v1.5 requirement list (HOME-01..03, TRAY-01..05, WEATHER-01..02, SHAPE-01) is 11 IDs.*
*v1.8 (Settings Redesign & Island Navigation) shipped and archived to `.planning/milestones/v1.8-REQUIREMENTS.md`/`.planning/milestones/v1.8-ROADMAP.md` — 3 phases (51-53), 6/6 requirements shipped, including a mid-UAT design fix (D-02 superseded: static play glyph replaces the bouncing equalizer bars in the idle-hover preview, since animated bars implied live playback when nothing was actually playing).*

*v1.10 (Live Activities Suite) roadmap created 2026-07-23: 9 phases (59-67), 100% coverage (27/27). Phase order: Settings-Redesign (59, foundation) → Caps Lock HUD + Update-Activity Restyle (60) → Download-Progress (61) → Timer/Pomodoro (62, generalizes `TransientQueue.preempt()`/`ActiveTransient.isPersistent` beyond the original Focus-Mode-only case) → Meeting-HUD (63, own detection spike, depends on 62's generalized persistent-transient path) → Quick Notes + Obsidian Export (64, resolves the 4-slot top-edge-switcher conflict in its own planning) → Quick Actions Bar (65, reuses Meeting-HUD's `MicMuteController`) → Menübar-Overflow (66, own feasibility spike, highest-novelty/zero-reuse feature) → Coding-Progress (67, reuses Phase 61's FileWatcher pattern) — per `.planning/research/SUMMARY.md`'s explicit foundation-first/ascending-risk build order. Phase numbering continues from Phase 58 (v1.9's last phase).*
