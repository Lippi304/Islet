# Requirements: Notch — Dynamic Island for Mac (Islet)

**Defined:** 2026-07-11
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island.

## v1.4 Requirements — Architecture Redesign

A `NotchPanel`/`NotchWindowController` window-shell rewrite (resolving the unexplained Phase 22 drag-in blocker, informed by TheBoringNotch/DynamicNotchKit reference implementations), plus Droppy-inspired scope: a first-launch onboarding flow, a frosted/glossy visual redesign, a sidebar-categorized Settings window, and a calendar full view. Gesture-based swipe navigation was explicitly considered and deferred.

### Architecture

- [x] **ARCH-01**: The notch window shell (`NotchPanel`/`NotchWindowController`) is rebuilt with behavior identical to today — position on the built-in notch, hover/click/grace-collapse state machine, true-fullscreen hiding, click-through hit-testing, and multi-Space visibility all verified regression-free on-device — with the residual `NSDraggingDestination` scaffold from Phase 22 removed. Prerequisite for SHELF-01/02.
- [ ] **SHELF-01**: User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view (carried forward from v1.3, blocked by Phase 22)
- [ ] **SHELF-02**: Drop target shows "hot"/targeted visual feedback while a file is being dragged over, before release (carried forward from v1.3, blocked by Phase 22)

### Onboarding

- [ ] **ONBOARD-01**: First-launch flow presents a short carousel — hero screen, trial/license-key/buy choice, a permissions pre-explanation screen, then done — replacing today's passive Settings-only license flow
- [ ] **ONBOARD-02**: The permissions pre-explanation screen shows a one-line reason per permission (Bluetooth, Calendar, Location/WeatherKit) and its "Continue"/"Grant" action directly triggers the real system permission prompt for each, in sequence
- [ ] **ONBOARD-03**: The onboarding flow shows once (persisted flag), is skippable/dismissible, and does not include an in-app feature/gesture tutorial screen

### Visual Redesign

- [ ] **VISUAL-01**: The collapsed pill, expanded island, and activity wings render with a non-fully-transparent frosted/glossy material fill (not the current fill), using one shared material style across all three
- [ ] **VISUAL-02**: The default spring animation is slower and more deliberate than today's while remaining smooth (no dropped frames, no visible bounce/overshoot)

### Settings Redesign

- [ ] **SETTINGS-01**: The Settings window is restructured from a single tabbed form into a sidebar-categorized layout with sections General, Workspace (Shelf), System (Theming), and About/License — existing toggles and the accent-color picker preserved, no functional regression

### Calendar Full View

- [ ] **CALVIEW-01**: A calendar full view — month grid + the selected day's event list — is available as a third view alongside the existing Home (idle glance, stays default) and Tray (shelf) views
- [ ] **CALVIEW-02**: The calendar view shows an explicit empty state when the selected day has no events
- [ ] **CALVIEW-03**: A lightweight quick-add lets the user create either a calendar event or a reminder (their choice per entry) without leaving the island
- [ ] **CALVIEW-04**: The full calendar view and the existing Home-glance "next event" feature share one EventKit service layer rather than duplicating date/event logic

## v2 Requirements

Deferred to a future milestone, not in this roadmap.

### Architecture Redesign Polish

- **ARCH-P1**: Animation Speed presets (Turtle/Human/Cheetah/Falcon-style) exposed as a Settings control
- **ARCH-P2**: "Permissions Overview — X of Y granted" rollup row in Settings + a "Replay onboarding" button in About
- **ARCH-P3**: Extended theming — surface-style picker (e.g. flat vs. glass) and per-element color pickers beyond the existing accent color
- **ARCH-P4**: `.glassEffect()`/Liquid Glass progressive enhancement, gated behind macOS 26.0+ (defer until the pre-26 install base is small enough, or the deployment floor is reconsidered)

### Other candidates (not yet scoped)

- WEATHER-01, CAL-01, OUTFIT-01 — formalize the already-shipped Phase 14 weather/calendar/date glance as requirements
- System HUD replacement (volume/brightness/etc.) — Settings' "System" sidebar section is the natural future home
- Countdown timer
- Gesture-based swipe navigation (skip-track/tuck-away/return) — explicitly deferred this milestone; touches the same event-delivery layer as drag-in, revisit only after the architecture redesign is proven stable

## Out of Scope

| Feature | Reason |
|---------|--------|
| TheBoringNotch or DynamicNotchKit as a runtime dependency | Research confirmed Islet's own custom `NSPanel` shell is structurally correct; only the drag-detection mechanism changes, not the window primitive itself |
| Full plugin-marketplace ("Droplets") Settings section | Islet has no plugin architecture; building one is far beyond this milestone's scope — individual widget ideas may be mined directly into Islet's own features later, never as a marketplace |
| Clipboard manager, floating "Basket," Lock Screen widgets, cloud file sharing | Droppy features with no Islet equivalent and no product need identified; explicitly ruled out during scoping |
| In-app gesture/feature tutorial during onboarding | Explicitly rejected by the user; onboarding stays to identity (trial/license) + trust (permissions) only |
| Full calendar CRUD (edit/delete/recurring events, multi-calendar management) | Quick-add only; anything more complex sends the user to Calendar.app/Reminders.app, matching the "lightweight" framing |
| `EventKitUI`/`EKEventEditViewController` for quick-add | Confirmed to have no macOS/AppKit availability; quick-add is hand-built SwiftUI calling `EKEventStore`/`EKReminder` directly |
| Quick-launch-apps 3rd view-switcher slot (Droppy's own pattern) | Calendar full view was explicitly chosen instead |
| Gesture-based swipe navigation | Touches the same event-delivery layer that just failed in Phase 22; deferred until the architecture redesign is proven (see v2 candidates) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 23 | Complete |
| SHELF-01 | Phase 24 | Pending |
| SHELF-02 | Phase 24 | Pending |
| ONBOARD-01 | Phase 26 | Pending |
| ONBOARD-02 | Phase 26 | Pending |
| ONBOARD-03 | Phase 26 | Pending |
| VISUAL-01 | Phase 25 | Pending |
| VISUAL-02 | Phase 25 | Pending |
| SETTINGS-01 | Phase 27 | Pending |
| CALVIEW-01 | Phase 28 | Pending |
| CALVIEW-02 | Phase 28 | Pending |
| CALVIEW-03 | Phase 28 | Pending |
| CALVIEW-04 | Phase 28 | Pending |

**Coverage:**
- v1.4 requirements: 13 total
- Mapped to phases: 13 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-07-11*
*Last updated: 2026-07-11 — v1.4 roadmap created: Phases 23-28, 100% requirement coverage. Phase 23 (Shell Parity Rewrite) is a hard prerequisite for Phase 24 (Drag-In) only; Phases 25-28 (Theming, Onboarding, Settings, Calendar) are independent of the shell work.*
