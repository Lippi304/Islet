---
phase: 06-priority-resolver-settings-v1-ship
plan: 03
subsystem: settings
tags: [settings, appstorage, accent, environment-key, app-03]
requires:
  - "Islet/SettingsView.swift (existing Form: Launch-at-Login + Version)"
  - "Islet/LaunchAtLogin.swift (settings-helper convention mirrored)"
provides:
  - "ActivitySettings: shared @AppStorage key constants (charging/nowPlaying/device/accentIndex)"
  - "ActivitySettings.palette + accent(for:) clamped index->Color mapping"
  - "\\.activityAccent EnvironmentKey (single accent source for the three leaf views)"
  - "SettingsView Form: three default-ON activity toggles + curated accent swatch row"
affects:
  - "Plan 04 (controller) reads the same keys to start/stop monitors + applies the accent"
tech-stack:
  added: []
  patterns:
    - "App-owned prefs via @AppStorage (UserDefaults is source of truth, unlike system-owned LaunchAtLogin)"
    - "Custom EnvironmentKey for single-source accent threading (06-RESEARCH Pattern 4)"
    - "Bounds-clamped index->Color map guards against tampered UserDefaults (T-06-07)"
key-files:
  created:
    - "Islet/ActivitySettings.swift"
  modified:
    - "Islet/SettingsView.swift"
decisions:
  - "Curated 6-swatch palette [white, blue, green, orange, pink, purple], index 0 = neutral default (D-12)"
  - "Three activity toggles default ON via @AppStorage absent-key semantics; no master switch / no duration (D-06/D-07/D-08)"
  - "Toggles grouped under Section(\"Activities\") for Form readability; Accent row uses LabeledContent + tap-to-select swatches (no ColorPicker)"
metrics:
  duration: 2 min
  completed: 2026-06-28
---

# Phase 6 Plan 03: Settings UI (APP-03) Summary

APP-03 settings surface: three independent default-ON activity toggles (Charging, Now Playing, Devices) plus a curated 6-swatch accent palette, persisted via `@AppStorage`/`UserDefaults`, added into the existing `SettingsView` Form alongside Launch-at-Login + Version — with a single shared `ActivitySettings` source defining the persistence keys, the palette, the clamped index→Color map, and the `\.activityAccent` Environment key for Plan 04 to consume.

## What Was Built

### Task 1 — `Islet/ActivitySettings.swift` (commit `7ad91d3`)
- `enum ActivitySettings` as the single source of truth for the four `@AppStorage`/`UserDefaults` keys: `activity.charging`, `activity.nowPlaying`, `activity.device`, `accentIndex` — the identical strings Plan 04's controller reads.
- Curated palette `[.white, .blue, .green, .orange, .pink, .purple]` (6 swatches, D-12) with `defaultAccentIndex = 0` (neutral white, preserves today's look).
- `accent(for:)` maps a persisted index → concrete `Color`, clamped via `palette.indices.contains` so an out-of-range/tampered value falls back to neutral (T-06-07 mitigation — cannot crash or index out of bounds).
- `private struct ActivityAccentKey: EnvironmentKey` + `EnvironmentValues.activityAccent` (default `.white`) — the single accent source the three lively leaf views will read (06-RESEARCH Pattern 4). Plan 04 sets it once on the hosting view.

### Task 2 — `Islet/SettingsView.swift` (commit `3b3da51`)
- Added four `@AppStorage` properties bound to the Task-1 keys: three activity Bools (default `true` via absent-key semantics, D-07) and `accentIndex` (default `ActivitySettings.defaultAccentIndex`).
- Inside the existing Form, a new `Section("Activities")` with `Toggle("Charging")`, `Toggle("Now Playing")`, `Toggle("Devices")`.
- A `LabeledContent("Accent")` row rendering `ActivitySettings.palette` as tappable `Circle` swatches with a selected ring (`strokeBorder(.primary, lineWidth: accentIndex == i ? 2 : 0)`); tapping sets `accentIndex` (persists via `@AppStorage`).
- Launch-at-Login Toggle (+ its onChange), the Version `LabeledContent`, the `appearsActive` re-sync, and `.padding(20).frame(width: 360)` are all preserved untouched. No `ColorPicker`, master switch, or per-activity duration (D-08/D-12).

## Verification

- `xcodebuild build -scheme Islet -destination 'platform=macOS'` → **BUILD SUCCEEDED** after each task (built in this worktree's regenerated `Islet.xcodeproj`).
- All Task-1 acceptance greps pass (keys present, palette = 6 colors, `EnvironmentKey`, `var activityAccent`, `func accent(for`).
- All Task-2 acceptance greps pass (`@AppStorage` count = 7 ≥ 4, all three new toggles present, `= true` default, `ActivitySettings.palette` referenced, **no** `ColorPicker` token, Launch-at-Login + Version preserved).
- DEFERRED to on-device UAT (Plan 04 / phase gate, per 06-VALIDATION Manual-Only): visually confirming live-apply + persistence across restart and the accent tinting only the three lively leaf elements.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded the Accent comment to satisfy the no-`ColorPicker` grep**
- **Found during:** Task 2 verification
- **Issue:** The acceptance criterion `grep -q "ColorPicker" … FAILS` is an automated proxy for "no free color picker view". My explanatory comment originally contained the literal word `ColorPicker` ("NOT a free ColorPicker"), which would have tripped the verifier's grep even though no `ColorPicker` *view* exists.
- **Fix:** Reworded the comment to "a fixed preset row, not a free color wheel" so the literal token no longer appears anywhere in the file.
- **Files modified:** `Islet/SettingsView.swift`
- **Commit:** `3b3da51` (folded into the Task 2 commit, before commit)

### Threat-model adherence
- T-06-07 (tampered `accentIndex`): mitigated as required — `accent(for:)` clamps via `palette.indices.contains`.
- T-06-08 (no secrets in @AppStorage): honored — only three Bools + one Int index persisted; no credentials.

## Known Stubs

None. The accent plumbing (palette, `accent(for:)`, `\.activityAccent`) and the toggle keys are complete, working definitions. Wiring them into monitor start/stop and threading the accent into the glyph/bars/icon is **explicitly out of scope for this plan** (owned by Plan 04, Wave 2) — not a stub, a planned hand-off. The toggles themselves persist real user state today.

## Notes for Plan 04

- Read the toggle state via `UserDefaults.standard.bool(forKey: ActivitySettings.chargingKey)` etc. Caveat: `UserDefaults.bool` returns `false` for an absent key, whereas the UI defaults these to `true`. Plan 04 should register defaults (`UserDefaults.standard.register(defaults:)`) or read with an absent-key→`true` fallback so a fresh install (no writes yet) is treated as all-ON, matching the UI.
- Apply the accent by computing `ActivitySettings.accent(for: accentIndex)` and injecting it once via `.environment(\.activityAccent, …)` on the hosting view; the three leaf views read `@Environment(\.activityAccent)`.

## Self-Check: PASSED
- FOUND: Islet/ActivitySettings.swift
- FOUND: Islet/SettingsView.swift (modified)
- FOUND: commit 7ad91d3
- FOUND: commit 3b3da51
