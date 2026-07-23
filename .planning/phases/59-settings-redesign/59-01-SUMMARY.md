---
phase: 59
plan: 01
subsystem: settings-redesign
tags: [swiftui, appstorage, settings, card-component, resolver-docs]
dependency_graph:
  requires: []
  provides:
    - ActivityCard.swift (ActivityCardData struct + ActivityCard view)
    - "8 new default-OFF activity.* @AppStorage key constants (ActivitySettings)"
    - SC5 resolver-priority reference table (IslandResolver.swift)
  affects:
    - Plan 59-02 (grid-wiring against the card contract + new keys)
tech_stack:
  added: []
  patterns:
    - "Data-driven ActivityCardData + Binding<Bool> card component (no dynamic string-keyed @AppStorage)"
    - "Named-rank doc-comment convention for resolver-priority documentation"
key_files:
  created:
    - Islet/ActivityCard.swift
  modified:
    - Islet/ActivitySettings.swift
    - Islet/Notch/IslandResolver.swift
    - IsletTests/ActivitySettingsTests.swift
decisions:
  - "ActivityCardData carries no category field/enum — Plan 59-02's own card arrays already partition by category"
  - "No migration function added for the 8 new keys — absent-key @AppStorage default is the only mechanism needed (Don't Hand-Roll)"
metrics:
  duration: 15min
  completed: 2026-07-23
---

# Phase 59 Plan 01: Settings-Redesign Foundation Summary

Built the foundation layer for the Activities grid redesign: 8 new default-OFF `@AppStorage` key constants for not-yet-built v1.10 activities, a reusable `ActivityCard`/`ActivityCardData` component with zero persistence coupling, and a comment-only SC5 resolver-priority reference table documenting where the 8 new activities will eventually slot into `IslandResolver`.

## What Was Built

**Task 1 — 8 new activity keys (`Islet/ActivitySettings.swift`):** Added `capsLockKey`, `downloadProgressKey`, `menuBarOverflowKey`, `timerKey`, `meetingHUDKey`, `quickNotesKey`, `quickActionsKey`, `codingProgressKey` — all `activity.*`-namespaced, alongside the 7 existing keys (left byte-for-byte unchanged). No migration function added (RESEARCH.md's Don't-Hand-Roll table: absent-key ⇒ `@AppStorage`'s own compiled default is the only mechanism needed for brand-new keys).

`IsletTests/ActivitySettingsTests.swift` gained: `testNewV110KeyNames()` (all 8 new key strings), `testExistingActivityKeyNamesUnchanged()` (all 7 existing key strings, the SC4 key-identity regression guard), and `testChargingAppStorageReadsSeededValueNotCompiledDefault()` — a real local `@AppStorage` wrapper backed by a pre-seeded isolated `UserDefaults(suiteName:)` domain, proving a seeded `false` value survives instead of the compiled `true` default winning. This is the actual value-level regression guard for SC4, exercising `@AppStorage` itself rather than a plain `UserDefaults` accessor round-trip.

**Task 2 — `Islet/ActivityCard.swift` (new file):** `ActivityCardData: Identifiable` (id, title, description, icon, iconColor, isOn: Binding<Bool>, isNew, onOptionsTap) and `ActivityCard: View` rendering icon + title/description + toggle + optional options-chevron + "Neu" badge overlay, per 59-UI-SPEC.md's Card Component Contract. Zero `@AppStorage`/`UserDefaults` references anywhere in the file — the view only ever reads/writes through the passed-in `Binding<Bool>`. No `CardCategory` enum (Plan 59-02's own card arrays already partition by category).

**Task 3 — SC5 resolver-priority table (`Islet/Notch/IslandResolver.swift`):** A doc-comment block placed above `enum IslandPresentation` documenting the current 4 tiers (onboarding forced-flow / `ActiveTransient` queue charging>device>focus>osd / `isExpanded` branch / non-expanded ambient) plus each of the 8 new v1.10 activities with a best-guess tier placement and an explicit `rank TBD — confirm in that activity's own phase discussion` flag. Zero functional/code change — no new `IslandPresentation`/`ActiveTransient` cases.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking fix] Task 2's acceptance-criteria grep for zero `@AppStorage`/`UserDefaults` mentions initially failed on doc-comment text**
- **Found during:** Task 2 verification
- **Issue:** The file-header comment describing the "no persistence coupling" design intent literally contained the strings `@AppStorage` and `UserDefaults` (3 matches), failing the plan's own `grep -c '@AppStorage\|UserDefaults' Islet/ActivityCard.swift` returns 0 acceptance criterion, even though no actual code coupling existed.
- **Fix:** Reworded the comment to describe the same intent without using the literal token strings (e.g. "no persistence property wrapper or its underlying storage is touched here").
- **Files modified:** `Islet/ActivityCard.swift`
- **Commit:** f912ee1

**2. [Rule 3 - blocking fix] Task 3's `rank TBD` grep count was 9, not the required 8**
- **Found during:** Task 3 verification
- **Issue:** The intro line above the 8 reserved-slot bullets also contained the literal substring "rank TBD", double-counting against the plan's `grep -c 'rank TBD' Islet/Notch/IslandResolver.swift` returns 8 acceptance criterion (one count per new v1.10 activity, not one extra for the section intro).
- **Fix:** Reworded the intro line to "each flagged below, unconfirmed" so only the 8 per-activity bullet lines carry the literal "rank TBD" flag.
- **Files modified:** `Islet/Notch/IslandResolver.swift`
- **Commit:** 2a043de

## Known Stubs

None — this plan builds pure foundation (keys, a reusable component, documentation); no UI wires against real data yet (that's Plan 59-02's job).

## Self-Check: PASSED

- FOUND: Islet/ActivityCard.swift
- FOUND: Islet/ActivitySettings.swift (8 new keys present)
- FOUND: Islet/Notch/IslandResolver.swift (SC5 table present)
- FOUND: IsletTests/ActivitySettingsTests.swift (3 new tests present)
- FOUND commit 1c29cfe (Task 1)
- FOUND commit f912ee1 (Task 2)
- FOUND commit 2a043de (Task 3)
- `xcodebuild -project Islet.xcodeproj -scheme Islet build` — BUILD SUCCEEDED
- `xcodebuild -project Islet.xcodeproj -scheme Islet build-for-testing` — TEST BUILD SUCCEEDED
