---
phase: 27-settings-sidebar-redesign
plan: 02
subsystem: ui
tags: [swiftui, anyshapestyle, environment, notch-rendering]

# Dependency graph
requires:
  - phase: 27-01
    provides: MaterialStyle enum, 4 new EnvironmentKeys (nowPlayingAccent/chargingAccent/deviceAccent/islandMaterialStyle), migrateLegacyAccentIfNeeded
provides:
  - "NotchPillView's 4 fill sites (collapsedFill, blobShape, wingsShape, mediaWingsOrToast) branching Gradient vs Solid Black via AnyShapeStyle"
  - "NotchPillView's 6 accent-consuming call sites reading 3 independent per-element @Environment values instead of the single shared activityAccent"
  - "NotchWindowController.currentTheme() single-read-site helper + AppliedTheme-gated re-host pipeline covering all 4 theming preferences"
affects: [27-03, 27-settings-sidebar-redesign verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [AnyShapeStyle type erasure for divergent ShapeStyle branches, single-read-site UserDefaults helper gated by an Equatable snapshot struct]

key-files:
  created: []
  modified: [Islet/Notch/NotchPillView.swift, Islet/Notch/NotchWindowController.swift]

key-decisions:
  - "Two accent-consuming call sites not listed in the plan's authoritative mapping (deviceWings' connection-sign checkmark/xmark, mediaExpanded's ProgressBar tint) were discovered via grep and migrated to deviceAccent/nowPlayingAccent respectively (Rule 3 - blocking, since the accent declaration removal would have broken their compile)"

patterns-established:
  - "islandFill computed property is the single branch point for Gradient vs Solid Black - all 4 shape fill sites read it, never branch independently"
  - "currentTheme() is the only UserDefaults read site for the 4 theming keys - both panel creation and applyAccentIfChanged call it, no duplicate raw reads"

requirements-completed: [VISUAL-03]

duration: ~30min
completed: 2026-07-12
---

# Phase 27 Plan 02: Notch Rendering Pipeline Theming Summary

**Wired Phase 27's MaterialStyle enum and 3 per-element accent EnvironmentKeys into NotchPillView's actual render call sites and NotchWindowController's live re-host pipeline — the notch shell now live-updates its material (Gradient/Solid Black) and 3 independent leaf-element accents with no app restart.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-07-12T20:07:48Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `NotchPillView.swift`'s 4 fill sites (`collapsedFill`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) now branch Gradient/Solid Black through a single `AnyShapeStyle`-returning `islandFill` computed property
- All 6 accent-consuming call sites (charging glyph, collapsed equalizer, device glyph, device connection-sign, expanded equalizer, expanded progress bar) read their own per-element `@Environment` value — changing one preference no longer affects the other two elements
- `NotchWindowController.swift`'s UserDefaults-observer → compare-cached → re-host pipeline extended (not duplicated) via a single `currentTheme()` helper and an `Equatable` `AppliedTheme` snapshot, covering all 4 new preferences at exactly 2 read sites
- Debug and Release builds both green (Release-parity discipline honored per Task 2's gate)

## Task Commits

1. **Task 1: NotchPillView.swift — AnyShapeStyle material branch + 4 per-element accent call sites** - `ed2bcb7` (feat)
2. **Task 2: NotchWindowController.swift — single-read-site theme pipeline** - `1b5468f` (feat)

**Plan metadata:** (pending — this SUMMARY commit)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - islandFill/gradientMaterial/solidBlackMaterial, 3 accent @Environment properties + islandMaterialStyle, all 4 fill sites + 6 accent call sites migrated
- `Islet/Notch/NotchWindowController.swift` - AppliedTheme struct, currentTheme() single-read-site, makeRootView(theme:), applyAccentIfChanged() now gates on all 4 values

## Decisions Made
- The plan's authoritative accent-call-site mapping listed 4 sites (717/775/826/1020, pre-edit line numbers); a direct grep of the file after the `@Environment(\.activityAccent)` declaration was removed surfaced 2 additional bare `accent` references the plan didn't name: `deviceTrailing`'s connection-sign checkmark/xmark (mapped to `deviceAccent`, same wing element as the glyph beside it) and `mediaExpanded`'s `ProgressBar` tint (mapped to `nowPlayingAccent`, same media element as the equalizer bars). Both were Rule 3 (blocking — would not compile once the shared `accent` property was removed).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Migrated 2 accent call sites not in the plan's authoritative mapping**
- **Found during:** Task 1 (NotchPillView.swift accent migration)
- **Issue:** Plan's interfaces block listed 4 accent-consuming call sites as "authoritative" (717/775/826/1020) but a post-edit grep for the bare `accent` identifier found 2 more: `deviceTrailing`'s `.foregroundStyle(isConnected ? accent : ...)` (connection sign) and `mediaExpanded`'s `ProgressBar(..., tint: accent)`. Both would have been compile errors once the single `@Environment(\.activityAccent) private var accent` declaration was removed.
- **Fix:** Mapped `deviceTrailing`'s connection sign to `deviceAccent` (same device wing as the glyph) and `mediaExpanded`'s progress bar to `nowPlayingAccent` (same media element as the equalizer bars).
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** `grep -c "tint: accent)\|accent: accent)\|foregroundStyle(accent\.\|? accent :"` returns 0; Debug build green.
- **Committed in:** ed2bcb7 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** Necessary for the plan's own stated truth ("changing one @Environment value does not affect the other two elements' rendered color") to actually hold across every leaf element, not just the 4 explicitly named ones. No scope creep — same per-element mapping discipline the plan already established.

## Note on Task 2's acceptance-criteria grep

Task 2's acceptance criteria state `grep -c "currentTheme()"` should equal 2 (panel-creation site + applyAccentIfChanged). The actual count is 3, because the function's own declaration (`private func currentTheme() -> AppliedTheme`) also contains the literal substring `currentTheme()` and is unavoidably matched by that grep pattern. The underlying requirement — `currentTheme()` called at exactly 2 sites — is satisfied (line ~794 panel creation, line ~1388 `applyAccentIfChanged`); this is a grep-pattern artifact in the plan's acceptance criteria, not a deviation in behavior.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- VISUAL-03's render-layer half is complete and build-verified (Debug + Release); Plan 27-03 (Settings-UI half, zero file overlap) can proceed/land independently.
- On-device UAT of the live material-style/accent switching (per the plan's `must_haves.truths`) is recommended once both 27-02 and 27-03 have merged, since the Settings UI is what actually flips these UserDefaults keys.

---
*Phase: 27-settings-sidebar-redesign*
*Completed: 2026-07-12*
