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
- [ ] **TRAY-02**: Dropping a file (from any tab) shows a Droppy-style Quick Action destination picker: Drop / AirDrop / Mail
- [ ] **TRAY-03**: Choosing "Drop" stages the file into the Tray as today and switches the view to Tray so the result is visible
- [ ] **TRAY-04**: Choosing "AirDrop" invokes the system AirDrop share sheet for the file; choosing "Mail" composes a new email with the file attached (Mail.app-only attachment support — documented, not silently discovered)
- [x] **TRAY-05**: The Tray view is widened with larger file tiles so more files are visible side-by-side

### Weather

- [ ] **WEATHER-01**: Weather tab shows a compact iOS-widget-style card by default — location, condition icon, current temperature, high/low
- [ ] **WEATHER-02**: A Settings toggle switches Weather to an extended widget adding a multi-day forecast row (day, icon, temp)

### Shape

- [x] **SHAPE-01**: The expanded-state notch silhouette gains an outward-flaring top-edge transition into the screen bezel; the idle/collapsed pill shape stays exactly as it is today

## v1.6 Requirements — Liquid Glass & System HUD Suite

Islet gets an edgier "Liquid Glass" material look, a suite of new/restyled Droppy-style collapsed-state system HUDs, and a new dual-activity display concept for when two top-priority activities are live at once. See `.planning/research/SUMMARY.md` for the full research backing these (Stack/Features/Architecture/Pitfalls).

### Material

- [ ] **GLASS-01**: The shared background material (pill, expanded island, all activity wings) is replaced by a "Liquid Glass" look — glossier and blurred/frosted rather than glass-clear — implemented from the user-supplied reference code, plugging into the existing `MaterialStyle`/`islandMaterial` seam

### Now Playing Polish

- [ ] **EQ-01**: The Now Playing equalizer bars are redesigned to the user-supplied reference visual style (view-layer only, no data/monitor changes)

### Onboarding

- [ ] **ONBOARD-04**: The first onboarding page's "Welcome to Islet" text is replaced by a live handwritten-signature-style reveal animation (distinct color, script styling) — scoped to that one page only, the rest of the app's font is unaffected

### System HUDs

- [ ] **HUD-01**: The Bluetooth/AirPods device-connected activity is restyled to the Droppy-pill look (visual only — `DeviceCoordinator`/`BluetoothMonitor` unchanged)
- [ ] **HUD-02**: The Charging activity is restyled to the Droppy-pill look (visual only — the existing IOKit power monitor unchanged)
- [ ] **HUD-03**: A Volume HUD appears on volume key press showing the live level in the Droppy-pill style, and suppresses the native system OSD when the spike confirms it's safe to do so on the dev machine (falls back to showing alongside the native OSD if suppression proves unreliable — do not ship the undocumented `EnableSystemBanners` toggle without confirming it doesn't regress on the project's own macOS Tahoe hardware)
- [ ] **HUD-04**: A Brightness HUD mirrors HUD-03's behavior for brightness key presses, sharing its OSD-replacement subsystem
- [ ] **HUD-05**: A Focus Mode HUD appears when the user toggles Focus/Do Not Disturb, showing generic on/off state only (named-mode detection, e.g. "Work Focus" vs "Sleep", is not guaranteed available on current macOS — see Out of Scope)
- [ ] **HUD-06**: An Update-available HUD appears when a new Islet version is published, backed by a real Sparkle 2 auto-update integration; tapping it triggers Sparkle's own standard install/progress dialog rather than a fully custom in-notch install flow (see Out of Scope)
- [ ] **HUD-07**: A Drop-session summary chip briefly appears after the Tray is closed following a drop session, showing how many files were saved — requires adding a session-boundary concept to `ShelfViewState`/`ShelfCoordinator` that does not exist today (`isVisible` is currently just `!items.isEmpty`)
- [ ] **HUD-08**: Starting 1 hour before a calendar event, the collapsed pill shows a live minute-countdown (calendar icon left, event time right) that updates continuously until the event starts — uses its own persistent timer, not the shared 3s `activityDuration` auto-dismiss

### Dual-Activity Display

- [ ] **DUAL-01**: When two top-priority activities are live simultaneously (e.g. the Calendar countdown and Now Playing), the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning via the current single-winner `IslandResolver` — generalizes to any two competing top-priority activities, not just Calendar+Music

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
| TRAY-02 | Phase 34 | Pending |
| TRAY-03 | Phase 34 | Pending |
| TRAY-04 | Phase 34 | Pending |

**Coverage:**
- v1.5 requirements: 11 total
- Mapped to phases: 11 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-13 — Roadmap created: 6 phases (29-34), 100% coverage (11/11). Phase order Flare → Home → Shelf Consolidation → Tray Widening → Weather → Quick Action Picker, per research recommendation and this project's pure-seams-first/risk-isolated-last convention (Phase 22→24 drag-in precedent). Corrected the "10 total" count from initial requirements definition — the actual v1.5 requirement list (HOME-01..03, TRAY-01..05, WEATHER-01..02, SHAPE-01) is 11 IDs.*
*v1.6 requirements defined: 2026-07-15 — 12 REQ-IDs (GLASS-01, EQ-01, ONBOARD-04, HUD-01..08, DUAL-01) backed by parallel Stack/Features/Architecture/Pitfalls research (`.planning/research/SUMMARY.md`). v1.5 left open in parallel, not archived; v1.6 phase numbering continues from the next free number. Traceability for v1.6 filled in by the roadmapper next.*
