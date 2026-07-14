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

## v2 Requirements

Deferred to a future milestone, not in this roadmap.

### Architecture Redesign Polish (carried from v1.4)

- **ARCH-P1**: Animation Speed presets (Turtle/Human/Cheetah/Falcon-style) exposed as a Settings control, beyond v1.4's single fluid default curve (VISUAL-02)
- **ARCH-P2**: "Permissions Overview — X of Y granted" rollup row in Settings + a "Replay onboarding" button in About
- **ARCH-P4**: `.glassEffect()`/Liquid Glass progressive enhancement, gated behind macOS 26.0+ (defer until the pre-26 install base is small enough, or the deployment floor is reconsidered)

### Other candidates (not yet scoped)

- Alternate app icon variants — descoped from Phase 27/VISUAL-03 (D-09/D-10): no icon assets exist yet; needs user-supplied icon files or a proper icon-design pass, not a Claude-generated placeholder
- System HUD replacement (volume/brightness/etc.) — Settings' "System" sidebar section is the natural future home
- Countdown timer
- Gesture-based swipe navigation (skip-track/tuck-away/return) — touches the same event-delivery layer as drag-in, revisit only after the architecture redesign is proven stable over time
- "Open Tray After Drop" convenience setting for the Quick Action picker's "Drop" outcome — Droppy-precedented, not in this milestone's explicit ask (research: FEATURES.md)
- Hourly forecast, weather alerts, radar — the milestone's own reference only asks for a daily forecast row (research: FEATURES.md)
- User-configurable flare depth/amount for SHAPE-01 — fixed design language for now

## Out of Scope

| Feature | Reason |
|---------|--------|
| `NSSharingServicePicker` (the generic system share picker) | Research found the Services/Sharing menu machinery likely requires a key window; Islet's `NotchPanel` is deliberately never-key/non-activating. A custom 3-button SwiftUI picker calling `NSSharingService(named:).perform(withItems:)` directly is used instead. |
| WidgetKit / a real macOS widget extension | The "iOS-widget-style" ask (WEATHER-01/02) is purely visual — a styled card inside the existing panel, not a system widget extension |
| Full multi-day/hourly weather data beyond the daily forecast row | Anti-feature per research — the milestone's reference only shows a daily strip, not hourly/alerts/radar |
| Mail attachment support on non-Mail.app default clients | `NSSharingService(.composeEmail)` is confirmed Mail.app-specific for attachments; other clients degrade to an unattached `mailto:` — accepted limitation, not solved this milestone |
| OUTFIT-01 (the original combined weather+calendar+date Home glance) | Being actively removed from Home per HOME-03, not formalized — its calendar half already shipped independently as CALVIEW-01..04 |

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
