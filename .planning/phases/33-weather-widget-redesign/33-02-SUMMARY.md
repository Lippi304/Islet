---
phase: 33-weather-widget-redesign
plan: 2
subsystem: ui
tags: [swiftui, weatherkit, notch-panel, geometry]

requires:
  - phase: 33-01
    provides: combined WeatherKit fetch (current + daily forecast) and reverse-geocode place-name seam
provides:
  - Medium/Large iOS Weather widget clone for the Weather tab (permanent Medium hourly row, Settings-gated Large daily range-bar list)
  - HourlyForecast model + 3-dataset WeatherKit fetch (.current, .hourly, .daily)
  - WeatherStyle Settings enum replacing the old weatherExtended boolean toggle
  - blobShape content clipping to the island's real NotchShape silhouette (applies to all blobShape callers, not just Weather)
affects: [weather, notch-geometry, settings]

tech-stack:
  added: []
  patterns:
    - "blobShape now clips overlay content to NotchShape instead of letting overflow paint past the panel"
    - "Fixed-width Text columns inside NotchShape's tapered silhouette need lineLimit(1) + padding past topCornerRadius, not just visual width"

key-files:
  created: []
  modified:
    - Islet/Weather/WeatherService.swift
    - Islet/Notch/BasicOutfitState.swift
    - Islet/ActivitySettings.swift
    - IsletTests/WeatherServiceTests.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/SettingsView.swift

key-decisions:
  - "NotchShape's side walls taper inward by topCornerRadius (24pt) for nearly the whole content height, not just at the very top — any blobShape content padding must clear that inset, not just look visually centered"
  - "blobShape clips its content to NotchShape now (previously .overlay painted overflow straight through onto whatever sat behind the panel) — a correctness fix for every caller, verified non-regressive for Home/Tray/Calendar since their content already fit"
  - "weatherLargeContentHeight settled at 410 (290 Medium + ~120 for the 4-row daily list) after 3 static-height guesses (470/500/480) were each invalidated by a different bug (text-wrap, missing clip, missing clip-safe padding) rather than genuine under-measurement"

requirements-completed: [WEATHER-01, WEATHER-02]

duration: ~2h (incl. 6-round on-device UAT)
completed: 2026-07-15
---

# Phase 33: Weather Widget Redesign — Plan 02 Summary

**Medium/Large iOS Weather widget clone (hourly row + Settings-gated daily range-bar list) for the notch Weather tab, plus a blobShape content-clipping fix uncovered during on-device UAT**

## Performance

- **Duration:** ~2h (3 code tasks + 6-round on-device checkpoint)
- **Tasks:** 4 (3 auto + 1 blocking human-verify checkpoint)
- **Files modified:** 7

## Accomplishments
- Weather tab always shows Medium: existing header (location/icon/temp/H-L) plus a new hourly forecast row (up to 6 chips)
- Settings "Weather Style" Medium/Large segmented control live-switches to Large, adding a daily forecast list (4 rows: weekday/icon/low/gradient range-bar/high)
- `WeatherService.fetchCurrentAndForecast` now fetches `.current`, `.hourly`, `.daily` in one combined WeatherKit call, filtering the hourly array to now-or-later entries
- `blobShape` (shared by Home/Tray/Calendar/NowPlaying/Weather) now clips its content to the real `NotchShape` silhouette instead of letting overflow paint past the panel — closes a latent bug that was never visible before because no prior caller's content came close to overflowing

## Task Commits

1. **Task 1: hourly WeatherKit dataset + WeatherStyle settings enum** - `326b0ca`
2. **Task 2: weather view rework (hourly row + daily range-bar list)** - `e8d36cf`
3. **Task 3: controller geometry + Settings Medium/Large control** - `63fbac4`
4. **Task 4: on-device UAT checkpoint** - 6 gap-closure rounds, see below

**Checkpoint gap-closure commits:**

1. `b98ddf7` — round 1: filtered hourly forecast to now-or-later (was showing overnight hours mid-afternoon); hourly chips cluster/center instead of stretching full-width; largeDailyRowCount 5→4, tighter spacing, weatherLargeContentHeight 470→500
2. `87281d6` — round 2: found the real cause of persistent Large overflow — weekday/low/high Texts wrapped onto 2 lines inside narrow fixed-width columns (no `lineLimit(1)`), silently doubling row height; fixed + height 500→420
3. `be7fee4` — round 3: overflow persisted even after the wrap fix — root cause was structural: `blobShape`'s `.overlay` never clipped content to the shape at all; added `.clipShape(shape)` (all callers) + height 420→480
4. `a05263a` — round 4: the clip then cut off the daily row's edges — `NotchShape`'s side walls taper inward by `topCornerRadius` (24pt) for nearly the whole height, more than the row's 16pt padding; capped the range-bar to 110pt and bumped padding to 20pt so the row centers with real margin
5. `bbebea6` — round 5: with content finally correct, 480 left a large empty gap before the switcher icons vs. Medium's tight spacing; recomputed to 410

## Files Created/Modified
- `Islet/Weather/WeatherService.swift` - `HourlyForecast` model, 3-dataset combined fetch, now-or-later hourly filter
- `Islet/Notch/BasicOutfitState.swift` - `hourlyForecast` published field
- `Islet/ActivitySettings.swift` - `WeatherStyle` enum + `weatherStyleKey`, replacing `weatherExtendedKey`
- `IsletTests/WeatherServiceTests.swift` - `FakeWeatherService`/round-trip test updated for the 3-value completion
- `Islet/Notch/NotchPillView.swift` - `hourlyForecastRow`/`dailyForecastList`/`dailyForecastRow`, `blobShape` content clipping, Medium/Large height constants
- `Islet/Notch/NotchWindowController.swift` - `refreshWeather()` 3-way wiring, `positionAndShow`/`visibleContentZone` per-style geometry
- `Islet/SettingsView.swift` - Medium/Large segmented "Weather Style" Picker replacing the boolean toggle

## Decisions Made
- `blobShape`'s missing content-clipping was fixed at the shared-function level (not a Weather-only workaround) since any future caller with taller-than-expected content would hit the same silent-overflow-onto-background bug
- Range-bar capped to a fixed 110pt width rather than left fully flexible — matches the user's explicit ask to narrow the "graph" and is what let the row clear NotchShape's taper via natural centering instead of guessing more padding
- Settled on static height tuning (matching every other `blobShape` caller's existing convention) rather than introducing dynamic content-measurement (GeometryReader/PreferenceKey) — the recurring overflow was root-caused to three distinct concrete bugs (stale hourly data long since fixed, text wrap, missing clip), not genuine unmeasurability, so the existing convention didn't need replacing

## Deviations from Plan

### Auto-fixed Issues

**1. [Checkpoint finding] `blobShape` never clipped content to its shape**
- **Found during:** Task 4, round 3 of on-device UAT
- **Issue:** `.overlay` does not clip children to the parent's bounds by default; any content taller than `baseHeight` painted straight through onto whatever sat behind the floating panel (visibly, the Xcode editor)
- **Fix:** Added `.clipShape(shape)` to blobShape's overlay content, sized to match the fill
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** On-device UAT rounds 4-6 confirmed no more leak-through and no regression to Home/Tray/Calendar
- **Committed in:** `be7fee4`

---

**Total deviations:** 1 auto-fixed (structural rendering bug found via checkpoint UAT, not part of the original plan's scope)
**Impact on plan:** Necessary correctness fix uncovered by the plan's own Task 4 checkpoint; no scope creep beyond what the on-device verification required.

## Issues Encountered
- Three-round-long apparent "overflow" turned out to be three separate, distinct bugs (stale hourly array, text-wrapping in narrow columns, missing shape clipping) that each looked like "just increase the height" from the outside — resolved by reading the actual `NotchShape.swift` path math rather than continuing to guess constants.

## Next Phase Readiness
- WEATHER-01/WEATHER-02 fully closed; both Medium and Large verified on-device across 6 checkpoint rounds, including the mandatory hover→expand→move-down click-through trace at Large
- Phase 33 has no other pending plans — ready for `/gsd-complete-milestone` bookkeeping or the next v1.6 phase

---
*Phase: 33-weather-widget-redesign*
*Completed: 2026-07-15*
