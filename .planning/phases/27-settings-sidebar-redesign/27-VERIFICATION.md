---
phase: 27-settings-sidebar-redesign
verified: 2026-07-12T22:23:45Z
status: human_needed
score: 10/10 must-haves verified (code-level); 1 human verification item outstanding
overrides_applied: 0
human_verification:
  - test: "Run Cmd-U (IsletTests scheme) in Xcode and confirm all 8 ActivitySettingsTests methods pass"
    expected: "testMaterialStyleParsesGradient, testMaterialStyleParsesSolidBlack, testMaterialStyleParsesCorruptedValueToNil, testAccentClampsOutOfRangeIndexToDefault, testNewKeyNames, testMigrationOnFreshInstallWritesNothing, testMigrationSeedsAllThreeKeysFromLegacyAccentIndex, testMigrationIsIdempotentAndNeverClobbersAnAlreadySetKey all pass"
    why_human: "xcodebuild test hangs in this project (test target hosts the full NSPanel/MediaRemote/IOBluetooth app stack, a documented prior constraint) — only build/build-for-testing (compile-only) can be run headlessly. The 27-01-PLAN.md and 27-03-PLAN.md verify blocks both required a manual Cmd-U pass; neither 27-01-SUMMARY.md nor 27-03-SUMMARY.md nor 27-04-SUMMARY.md records that this pass was actually executed and confirmed (27-03-SUMMARY.md explicitly lists it under 'User Setup Required' as still recommended, and 27-04's on-device UAT covered app-level behavior only, not the unit-test suite)."
  - test: "Run Cmd-U (IsletTests scheme) and confirm DiagnosticReportTests passes, including the updated 3-line accent assertions"
    expected: "testTextContainsAllSectionsWithSuppliedValues and related tests pass with Now Playing/Charging/Device Accent lines"
    why_human: "Same xcodebuild test hang constraint as above; build-for-testing confirms the test file compiles against the new 3-param API shape but not that assertions actually pass at runtime."
---

# Phase 27: Settings Sidebar Redesign Verification Report

**Phase Goal:** Settings is restructured from a single tabbed form into a sidebar-categorized layout, with every existing control preserved, and gains a new Theming section (VISUAL-03, descoped from Phase 25) to customize the Phase 25 gradient shell's appearance.
**Verified:** 2026-07-12T22:23:45Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Settings opens as a `NavigationSplitView` with sidebar sections General, Workspace, System, About | ✓ VERIFIED | `Islet/SettingsView.swift:76-116` — `NavigationSplitView { ... } detail: { switch selection { .general/.workspace/.system/.about/.none } }`; `enum SidebarSection` with exactly these 4 cases, `TabView` fully removed (`grep -c "TabView"` == 0). On-device UAT (27-04-SUMMARY.md, approved) confirmed all 4 rows render and are clickable after the List→Button fix. |
| 2 | Every existing toggle and the accent-color picker are present and functional in their new section | ✓ VERIFIED | `generalSection` contains Launch-at-login, Charging/Now Playing/Song-Change Toast/Devices toggles, Fullscreen toggle, Diagnostics button (all 4 `grep`-confirmed). `aboutSection` contains the License block + Version. `systemSection` contains the material picker + 3 `swatchRow` accent pickers. |
| 3 | License and login-item state never flashes stale/default when switching sidebar sections | ✓ VERIFIED (code) + approved (UAT) | `.onAppear`/`.onChange(of: appearsActive)` refresh block preserved verbatim at the `NavigationSplitView` level (not per-case), so `launchAtLogin`/`licenseStatus` re-sync on every appear/refocus regardless of which section is showing. On-device UAT step 8 (rapid General↔About switching) was explicitly approved by the user in 27-04-SUMMARY.md. |
| 4 | The System (Theming) section lets the user customize material/surface style and per-element accent colors | ✓ VERIFIED | `Section("Appearance Style")` segmented Picker (`Gradient`/`Solid Black`) + `Section("Accent Colors")` with 3 independent `swatchRow` bindings (`nowPlayingAccentIndex`/`chargingAccentIndex`/`deviceAccentIndex`), all `@AppStorage`-backed to the Plan-01 keys. |
| 5 | MaterialStyle and the 3 accent indices parse from UserDefaults with a clamp-to-default fallback, never crashing on a corrupted/out-of-range value | ✓ VERIFIED (with a noted edge-case) | Render path: `NotchWindowController.currentTheme()` → `MaterialStyle(rawValue:) ?? .gradient`; `ActivitySettings.accent(for:)` clamps every index read (`palette.indices.contains(index) ? ... : palette[defaultAccentIndex]`) — never indexes out of bounds. `ActivitySettingsTests.swift` pins the corrupted-string→nil and clamp-to-default behaviors. Caveat: `SettingsView`'s raw `@AppStorage nowPlayingAccentIndex` etc. store the raw Int with no clamp at the UI layer, so a corrupted legacy value migrated in would show no selection ring in Settings (does not crash — code-review WR-01, see Anti-Patterns). |
| 6 | An existing user's accent look is preserved across upgrade — 3 new per-element keys seed once from the legacy `accentIndexKey` (D-08) | ✓ VERIFIED | `ActivitySettings.migrateLegacyAccentIfNeeded()` — idempotency guard (`alreadyMigrated`), `as? Int` guard on the legacy read, writes to all 3 new keys. Wired in `AppDelegate.swift:35` BEFORE `controller.start(isFirstLaunch:)` at line 75 (correct ordering). 3 dedicated tests (fresh-install no-op, seed-from-legacy, idempotent-no-clobber) all present in `ActivitySettingsTests.swift`. |
| 7 | Changing material-style or any per-element accent live-updates the pill/expanded/wings with no restart (D-06) | ✓ VERIFIED (code) + approved (UAT) | `NotchWindowController.currentTheme()` → `AppliedTheme` (Equatable) gates `applyAccentIfChanged()`'s re-host, called from `handleSettingsChanged()` (UserDefaults-observer-driven). Both the panel-creation site and `applyAccentIfChanged()` call the same `currentTheme()` (2 call sites, confirmed by grep). On-device UAT steps 5-6 (material toggle + independent accent swatches) explicitly approved. |
| 8 | Gradient vs Solid Black branches through `AnyShapeStyle` type erasure, not an illegal `some ShapeStyle` runtime branch | ✓ VERIFIED | `private var islandFill: AnyShapeStyle { switch materialStyle { ... } }`; `collapsedFill` return type changed to `AnyShapeStyle` with both DEBUG/RELEASE branches wrapped; all 4 fill call sites (`collapsedFill`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) use `islandFill`/`collapsedFill` — confirmed via grep at `NotchPillView.swift` lines 188-191, 303, 649, 705, 768, 1099-1103. |
| 9 | Debug and Release builds both succeed with zero remaining references to deleted single-value accent/material symbols | ✓ VERIFIED | Ran both builds directly: `xcodebuild build -configuration Debug` → BUILD SUCCEEDED; `xcodebuild build -configuration Release` → BUILD SUCCEEDED. `grep -rn "activityAccent\|appliedAccentIndex" Islet/` → 0 matches. `grep -rn "@AppStorage(ActivitySettings.accentIndexKey)" Islet/` → 0 matches. `grep -rn '\bNavigationView\b' Islet/` → 0 matches. |
| 10 | On-device UAT confirms all 4 sidebar sections, live theming across pill/expanded/wings, and no section-switch state staleness | ✓ VERIFIED (per task instruction) | 27-04-SUMMARY.md documents 3 rounds of live on-device debugging (Settings-window-never-opens bug, sidebar List-selection-never-registers bug), both root-caused and fixed, with the user typing "approved" for the full 10-step walkthrough. Per this verification's explicit instruction, this checkpoint is treated as satisfied human-verification, not an open gap. |

**Score:** 10/10 truths verified at the code/build level; all UAT-dependent truths (3, 7, 10) are additionally backed by the documented, approved on-device checkpoint.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/ActivitySettings.swift` | `MaterialStyle` enum, 4 new keys, 4 EnvironmentKeys, `migrateLegacyAccentIfNeeded()` | ✓ VERIFIED | All present, confirmed by direct read + grep. |
| `IsletTests/ActivitySettingsTests.swift` | Pure-logic clamp + migration test coverage (8 methods) | ✓ VERIFIED | 8 `func test` methods present, covering all 5 Task-1 + 3 Task-2 behaviors. |
| `Islet/Notch/NotchPillView.swift` | `AnyShapeStyle` islandFill + 3 per-element accent reads at all consuming call sites | ✓ VERIFIED | 4 fill sites + 6 accent-consuming call sites (2 more than the plan's originally-named 4, correctly migrated per 27-02-SUMMARY's documented deviation) all confirmed via grep. |
| `Islet/Notch/NotchWindowController.swift` | `currentTheme()` single-read-site helper + 4-value cached re-host pipeline | ✓ VERIFIED | `AppliedTheme` struct, `currentTheme()` called at exactly 2 sites (panel creation + `applyAccentIfChanged`). |
| `Islet/SettingsView.swift` | `NavigationSplitView` sidebar shell + relocated controls + Theming section UI | ✓ VERIFIED | Full 4-section structure confirmed; `TabView` fully removed. |
| `Islet/Diagnostics.swift` | 3-accent diagnostic report text | ✓ VERIFIED | `nowPlayingAccentIndex/chargingAccentIndex/deviceAccentIndex: Int` signature; 3 report lines (`Now Playing Accent:`/`Charging Accent:`/`Device Accent:`); old combined `Accent index:` line fully removed. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Islet/AppDelegate.swift` | `Islet/ActivitySettings.swift` | `migrateLegacyAccentIfNeeded()` call before `controller.start()` | ✓ WIRED | Line 35 (migration) precedes line 75 (`controller.start(isFirstLaunch:)`). |
| `Islet/Notch/NotchWindowController.swift` | `Islet/Notch/NotchPillView.swift` | `makeRootView(theme:)` `.environment(...)` injection | ✓ WIRED | `makeRootView` chains 4 `.environment(\.nowPlayingAccent, ...)` / `.chargingAccent` / `.deviceAccent` / `.islandMaterialStyle` calls; `NotchPillView` declares matching `@Environment` properties consumed at 6 call sites. |
| `Islet/SettingsView.swift` | `Islet/ActivitySettings.swift` | `@AppStorage` bindings to the 4 new keys | ✓ WIRED | All 4 `@AppStorage` properties bind to `ActivitySettings.materialStyleKey`/`nowPlayingAccentKey`/`chargingAccentKey`/`deviceAccentKey`; writes from `systemSection`'s Picker/swatchRows flow through the same UserDefaults-observer pipeline `NotchWindowController` reads via `currentTheme()`. |

### Data-Flow Trace (Level 4)

Settings' Theming controls write directly to `@AppStorage`-backed UserDefaults keys; `NotchWindowController`'s existing `defaultsObserver` → `handleSettingsChanged()` → `applyAccentIfChanged()` → `currentTheme()` pipeline reads those same keys and re-hosts the view on change (no static/hardcoded fallback, no disconnected props). Data flows end-to-end: Settings UI write → UserDefaults → observer → `currentTheme()` → `AppliedTheme` compare → re-host → `NotchPillView`'s `@Environment` reads. ✓ FLOWING.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build | `xcodebuild build -configuration Debug` | BUILD SUCCEEDED | ✓ PASS |
| Release build | `xcodebuild build -configuration Release` | BUILD SUCCEEDED | ✓ PASS |
| Test target compiles (post-27-03 API shape) | `xcodebuild build-for-testing -configuration Debug` | TEST BUILD SUCCEEDED | ✓ PASS |
| Dead-reference sweep | `grep -rn "activityAccent\|appliedAccentIndex" Islet/` | 0 matches | ✓ PASS |
| Legacy `@AppStorage` binding removed | `grep -rn "@AppStorage(ActivitySettings.accentIndexKey)" Islet/` | 0 matches | ✓ PASS |
| Deprecated `NavigationView` absent | `grep -rn '\bNavigationView\b' Islet/` | 0 matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SETTINGS-01 | 27-03, 27-04 | Settings restructured into sidebar-categorized layout (General/Workspace/System/About), existing toggles + accent picker preserved, no functional regression | ✓ SATISFIED | Truths 1-3 above; on-device UAT approved. |
| VISUAL-03 | 27-01, 27-02, 27-03, 27-04 | New Theming section customizes shell material/surface style and per-element accent colors | ✓ SATISFIED | Truths 4-8 above; live-wiring verified in code and approved on-device. |

No orphaned requirements: REQUIREMENTS.md maps only SETTINGS-01 and VISUAL-03 to Phase 27, both are claimed across the 4 plans' frontmatter.

**Note:** REQUIREMENTS.md's traceability table and checkbox list still show VISUAL-03/SETTINGS-01 as `[ ]` unchecked / status "Pending" even though ROADMAP.md already marks Phase 27 `[x]` complete and both requirements are demonstrably implemented. This is a stale-documentation gap (a known pattern in this project — REQUIREMENTS.md is not auto-updated by phase completion), not a code/goal gap. Recommend updating REQUIREMENTS.md's checkboxes and Traceability table status column to "Complete" as a housekeeping follow-up.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/ActivitySettings.swift` | 67-79 | `migrateLegacyAccentIfNeeded` copies the legacy index unclamped into the 3 new keys | ℹ️ Info | Only reachable if the pre-Phase-27 `accentIndexKey` was already corrupted/out-of-range; render path stays safe (clamped at `accent(for:)`), but `SettingsView`'s swatch rows would show no selection ring in that edge case. Already identified in 27-REVIEW.md (WR-01) with a fix suggested. Not a crash, not a regression for any normal user — does not block phase goal. |
| `Islet/ActivitySettings.swift` | 96 | `typealias MaterialStyle = ActivitySettings.MaterialStyle` at module scope | ℹ️ Info | Namespace hygiene concern (27-REVIEW.md WR-02) — no functional impact today, 2 consuming files use it consistently. |

No TBD/FIXME/XXX/HACK/PLACEHOLDER debt markers found in any of the 9 files modified across this phase's plans (only benign uses of the word "placeholder" describing legitimate UI/UX concepts — the Workspace empty-state copy and pre-existing album-art/drag-seed placeholders unrelated to this phase's changes).

### Human Verification Required

### 1. ActivitySettingsTests — Cmd-U pass confirmation

**Test:** Open `Islet.xcodeproj` in Xcode, select the `IsletTests` scheme (or leave `Islet` selected), press Cmd-U.
**Expected:** All 8 `ActivitySettingsTests` methods pass (`testMaterialStyleParsesGradient`, `testMaterialStyleParsesSolidBlack`, `testMaterialStyleParsesCorruptedValueToNil`, `testAccentClampsOutOfRangeIndexToDefault`, `testNewKeyNames`, `testMigrationOnFreshInstallWritesNothing`, `testMigrationSeedsAllThreeKeysFromLegacyAccentIndex`, `testMigrationIsIdempotentAndNeverClobbersAnAlreadySetKey`).
**Why human:** This project's established constraint is that `xcodebuild test` hangs headlessly (the test target boots the full `NSPanel`/MediaRemote/IOBluetooth app stack). `xcodebuild build-for-testing` (run during this verification) confirms the test file compiles against the current API shape but cannot confirm the assertions actually pass at runtime. Both 27-01-PLAN.md and 27-03-PLAN.md's `<verify>` blocks required this manual Cmd-U pass; no SUMMARY.md for 27-01/27-03/27-04 records that it was actually executed and confirmed (27-03-SUMMARY.md explicitly lists it under "User Setup Required" as still recommended at the time it was written).

### 2. DiagnosticReportTests — Cmd-U pass confirmation

**Test:** Same Cmd-U run as above, confirm `DiagnosticReportTests` passes, specifically `testTextContainsAllSectionsWithSuppliedValues`'s updated assertions (`"Now Playing Accent: 2"`, `"Charging Accent: 1"`, `"Device Accent: 3"`).
**Expected:** All `DiagnosticReportTests` methods pass with the new 3-line accent format.
**Why human:** Same `xcodebuild test` hang constraint — `build-for-testing` confirms compilation only.

### Gaps Summary

No code-level or build-level gaps. The phase's 4 ROADMAP success criteria and both requirement IDs (SETTINGS-01, VISUAL-03) are all backed by direct code evidence: the `NavigationSplitView` sidebar shell, all relocated controls, the Theming section's live-wired material/accent pipeline, the D-08 legacy-accent migration, and a clean Debug+Release build with zero dead references to the removed single-value accent mechanism. The phase's own `checkpoint:human-verify` (27-04 Task 2) was executed on-device across 3 debugging rounds and explicitly approved by the user — per this verification's instructions, that is treated as satisfied, not an open gap.

The one remaining gap is narrower: two unit-test files (`ActivitySettingsTests.swift`, `DiagnosticReportTests.swift`) were updated with new/changed test methods whose plans' own `<verify>` blocks required a manual Cmd-U confirmation pass, and no SUMMARY.md in this phase documents that pass having been run and confirmed (as opposed to the app-level on-device UAT, which IS explicitly documented as approved). Since this project's tooling makes automated test execution impossible, this routes to human verification rather than being marked FAILED — the tests are known to compile cleanly (`build-for-testing` succeeded) and their logic was reviewed line-by-line above with no defects found, so this is a confirmation step, not a suspected defect.

Two minor code-review findings (WR-01 unclamped legacy migration edge case, WR-02 typealias namespace hygiene) are already documented in `27-REVIEW.md` and do not block the phase goal.

---

_Verified: 2026-07-12T22:23:45Z_
_Verifier: Claude (gsd-verifier)_
