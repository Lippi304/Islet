---
phase: 52-top-edge-switcher-layout-placement-config
verified: 2026-07-21T16:01:09Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 52: Top-Edge Switcher Layout & Placement Config Verification Report

**Phase Goal:** Users can opt into an alternate compact top-edge switcher layout instead of today's pill-below-the-island, with user-configurable left/right icon placement.
**Verified:** 2026-07-21T16:01:09Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | In Settings, the user can switch between the default below-island pill switcher and an alternate top-edge 4-icon layout | ✓ VERIFIED | `Islet/SettingsView.swift:350-357` — `switcherSection` renders a segmented `Picker("Layout", selection: $switcherLayout)` with `.pill`/`.topEdge` tags, bound to `@AppStorage(ActivitySettings.switcherLayoutKey)` (line 69). `NotchPillView.swift:2019,2035,2060-2066` reads the same key and gates `switcherRow` vs. `topEdgeSwitcherRow` rendering on it. On-device UAT (52-04-SUMMARY.md) confirmed the toggle live-switches the rendered layout. |
| 2 | In the top-edge layout, 2 icons render to the left of the camera/notch cutout and 2 render to the right, both clear of the physical camera housing on real hardware | ✓ VERIFIED | `NotchPillView.swift:2143-2168` — `topEdgeSwitcherRow` is an `HStack(spacing:0)` with a leading 2-icon `HStack`, a `Color.clear.frame(width: topEdgeCutoutWidth)` center spacer, and a trailing 2-icon `HStack`. `topEdgeCutoutWidth` (line 2128-2134) computes the real cutout width via `topEdgeCutoutGap(...)` (`NotchGeometry.swift:64-74`), which wraps the verified `notchSize(...).width` formula — never `auxLeftWidth+auxRightWidth`. Physical-hardware clearance claim is UAT-only by nature; 52-04-SUMMARY.md records the on-device walkthrough's step 6 (cutout-gap clearance check) as explicitly approved ("Klappt alles wunderbar"), and all 12 steps of the recorded human-check block in 52-04-PLAN.md were walked and approved — treated as satisfied per task instructions. |
| 3 | The top-edge layout's default icon split is Home+Tray on the left, Calendar+Weather on the right | ✓ VERIFIED | `NotchPillView.swift:148-151` and `SettingsView.swift:70-73` both declare `slotLeftOuter: SelectedView = .home`, `slotLeftInner: SelectedView = .tray`, `slotRightInner: SelectedView = .calendar`, `slotRightOuter: SelectedView = .weather` against the same `@AppStorage` keys — independently confirmed via a live test run: `testOrderedSlotViewsDefaultsToTodaysPillOrder` (NotchPillViewTests) passes, asserting `[.home, .tray, .calendar, .weather]`. |
| 4 | The user can reassign which icons appear on the left vs. right side in Settings, and the island reflects the change immediately | ✓ VERIFIED | `SettingsView.swift:362-371` — 4 independent `.pickerStyle(.menu)` dropdowns bound to the 4 slot `@AppStorage` keys, each offering all 4 `SelectedView` options via shared `slotOptions` (no fixed-pair restriction, D-01). `NotchPillView.swift` reads the identical keys live (no controller plumbing, no relaunch needed — `@AppStorage` triggers a SwiftUI re-render). `testOrderedSlotViewsReflectsUserDefaultsOverride` passes (verified via live test execution). On-device UAT step 8 confirmed live propagation with no relaunch. |
| 5 | Both switcher layouts remain fully functional for switching tabs — the existing pill mode shows no regression | ✓ VERIFIED | `switcherRow` (`NotchPillView.swift:2110-2120`) still calls `onSwitcherSelect`/sets `filled:` exactly as before, now via `ForEach(orderedSlotViews, ...)` (always 4 children, Phase-45 structural-identity rule preserved). Pre-existing regression tests `testShelfStripVisibleIsAlwaysFalse` and `testTabWidthHeightMatchesKnownPerCaseValues` pass unmodified (confirmed via live test execution below). `NotchWindowController.visibleContentZone()`'s click-through `switcherHeight` term is gated `switcherRowShowing && layout == .pill` (line 1447), keeping the hit-test rect in lockstep with rendered content in both modes. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/ViewSwitcherState.swift` | `SelectedView: String/Equatable/Hashable/CaseIterable` + `orderedSlotIcons(...)` | ✓ VERIFIED | Confirmed via direct read — enum declared exactly as specified; `orderedSlotIcons` returns `[leftOuter, leftInner, rightInner, rightOuter]`, no dedup logic. |
| `Islet/ActivitySettings.swift` | `SwitcherLayout` enum + `switcherLayoutKey` + 4 slot keys | ✓ VERIFIED | Confirmed via grep — `enum SwitcherLayout: String, CaseIterable { case pill, topEdge }`, `switcherLayoutKey = "switcher.layout"`, 4 slot keys, bare `typealias SwitcherLayout` all present. |
| `Islet/Notch/NotchGeometry.swift` | `topEdgeCutoutGap(...)` pure function | ✓ VERIFIED | Confirmed via direct read — thin wrapper around `notchSize(...).width ?? 0`, matches Pitfall-2 mitigation. |
| `Islet/Notch/NotchPillView.swift` | Data-driven `switcherRow`, `topEdgeSwitcherRow`, layout-aware height math | ✓ VERIFIED | Confirmed via direct read — `orderedSlotViews`, `icon(for:)`, `switcherRow` (ForEach), `topEdgeSwitcherRow`, `topEdgeCutoutWidth`, `showsPillRow`, `totalHeight` all present and wired exactly as SUMMARY claims. |
| `Islet/Notch/NotchWindowController.swift` | `visibleContentZone()` gated on `switcherLayout == .pill` | ✓ VERIFIED | Confirmed via grep — `switcherRowShowing && layout == .pill` present, `layout` read with `?? .pill` safe fallback. |
| `Islet/SettingsView.swift` | `.switcher` `SidebarSection` case + `switcherSection` + `hasNotch` gating | ✓ VERIFIED | Confirmed via direct read — `case switcher` in enum, title "Switcher", icon `square.grid.2x2`, `switcherSection` view with Layout picker + 4 menu dropdowns, `visibleSections(hasNotch:)` filters `.switcher` out, `hasNotchDisplay` refreshed on appear/refocus. |
| `IsletTests/SettingsViewTests.swift` | `visibleSections(hasNotch:)` regression test | ✓ VERIFIED | File exists, both branches tested, confirmed passing via live test execution. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `NotchPillView.swift` `switcherRow`/`topEdgeSwitcherRow` | `ViewSwitcherState.swift` `orderedSlotIcons(...)` | `orderedSlotViews` computed property | ✓ WIRED | Both `switcherRow` (line 2112) and `topEdgeSwitcherRow` (lines 2146-2161) read `orderedSlotViews`, which calls `orderedSlotIcons(...)` (line 163-ish) — one shared ordering source, D-03 satisfied. |
| `NotchPillView.swift` `totalHeight`/`blobShape` | `NotchWindowController.swift` `visibleContentZone()` | `switcherLayout == .pill` gate mirrored in both (three-site rule) | ✓ WIRED | `blobShape`'s `showsPillRow` (line 2035), body's `totalHeight` (lines 120-126), and `visibleContentZone()`'s `switcherHeight` (line 1447) all independently gate on the same `switcherLayout == .pill` condition. |
| `SettingsView.swift` `switcherSection` Pickers | `ActivitySettings.swift` `switcherLayoutKey`/`switcherSlot*Key` | `@AppStorage` | ✓ WIRED | 5 `@AppStorage` vars declared at lines 69-73, bound directly to the Pickers at lines 351-370. Same keys `NotchPillView` reads — confirmed byte-identical key strings via grep on both files. |
| `SettingsView.swift` `SidebarSection.visibleSections(hasNotch:)` | `NotchGeometry.swift` `hasNotch(...)` | `selectTargetScreen(from:)?.hasNotch` | ✓ WIRED | `refreshNotchAvailability()` (line 694-695) calls `selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })?.hasNotch ?? false`, feeding `hasNotchDisplay` state that drives the sidebar `ForEach`. |

### Behavioral Spot-Checks / Test Execution

Ran independently (not trusting SUMMARY.md's reported numbers) via `xcodebuild test`:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Phase-52 targeted suites (NotchPillViewTests, NotchGeometryTests, ActivitySettingsTests, SettingsViewTests) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests -only-testing:IsletTests/NotchGeometryTests -only-testing:IsletTests/ActivitySettingsTests -only-testing:IsletTests/SettingsViewTests` | 44/44 tests passed, 0 failures | ✓ PASS |
| Pre-existing regression tests unmodified | Same run | `testShelfStripVisibleIsAlwaysFalse`, `testTabWidthHeightMatchesKnownPerCaseValues` both passed | ✓ PASS |
| Release build compiles clean | `xcodebuild build -scheme Islet -configuration Release` | `** BUILD SUCCEEDED **` | ✓ PASS |
| CalendarGlanceTests (out-of-scope check) | `xcodebuild test -scheme Islet -only-testing:IsletTests/CalendarGlanceTests` | 17/19 passed, exactly 2 pre-existing failures (`testDefaultQuickAddTimeForTodayReturnsNextFullHour`, `testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary`) | ✓ CONFIRMED PRE-EXISTING — file last touched by Phase 46 commit `f7008c6`, zero Phase 52 commits touch this file (`git log -- IsletTests/CalendarGlanceTests.swift`). Not a Phase 52 gap; user already reviewed and approved treating as out-of-scope debt per task instructions. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SWITCH-03 | 52-01, 52-02, 52-03, 52-04 | User can choose an alternate compact switcher layout in Settings — 4 small icons at the top edge (2 left/2 right of cutout) instead of the default pill | ✓ SATISFIED | REQUIREMENTS.md line 83 marked `[x]` Complete (line 163: "Complete"); code evidence above (SC#1, SC#2). |
| SWITCH-04 | 52-01, 52-02, 52-03, 52-04 | User can configure which icons appear on left vs. right of the top-edge layout (default: Home+Tray left, Calendar+Weather right) | ✓ SATISFIED | REQUIREMENTS.md line 84 marked `[x]` Complete (line 164: "Complete"); code evidence above (SC#3, SC#4). |

No orphaned requirements found — REQUIREMENTS.md line 163-164 maps exactly SWITCH-03/SWITCH-04 to Phase 52, matching all 4 plans' `requirements:` frontmatter.

### Anti-Patterns Found

None. Scanned all 6 modified source files for `TODO`/`FIXME`/`XXX`/`TBD`/`placeholder`/`not implemented`/empty-return patterns scoped to switcher/topEdge/slot code — zero matches. The one `placeholder` grep hit in `NotchPillView.swift` (line 3062) is pre-existing NowPlaying Shuffle/Repeat UI, unrelated to this phase.

### Human Verification Required

None outstanding. The two hardware-dependent claims (SC#2's physical camera clearance, D-04's 36pt-icon-in-42pt-band fit) were already verified via a recorded on-device UAT walkthrough: `52-04-PLAN.md` Task 2 (`checkpoint:human-verify`, blocking gate) documents all 12 `how-to-verify` steps, and `52-04-SUMMARY.md` records the user's explicit "approved" / "Klappt alles wunderbar" response covering all 5 ROADMAP success criteria, the fit/clearance checks, D-03 live reorder propagation, D-05 selection-state, duplicate-slot-assignment safety, and rapid-toggle stability. Step 11 (non-notch display check) was explicitly noted as skipped (no such display available) rather than silently passed.

### Gaps Summary

None. All 5 ROADMAP success criteria are independently verified against source code (not just SUMMARY.md claims), all artifacts exist and are substantively implemented (no stubs), all key links are wired through real `@AppStorage`-shared state (not mocked/hardcoded), the targeted automated test suite was independently re-executed and passes 44/44, the Release build independently re-verified as succeeding, and the on-device UAT record for the 2 hardware-only claims exists and covers them. The 2 `CalendarGlanceTests` failures are confirmed pre-existing (Phase 46, untouched by any Phase 52 commit) and are not a Phase 52 gap — noted here only as a pre-existing debt item per task instructions, not blocking this phase's verification.

---

*Verified: 2026-07-21T16:01:09Z*
*Verifier: Claude (gsd-verifier)*
