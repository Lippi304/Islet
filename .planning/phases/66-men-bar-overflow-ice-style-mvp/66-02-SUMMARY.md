---
phase: 66-men-bar-overflow-ice-style-mvp
plan: 02
subsystem: menu-bar
tags: [nsstatusitem, appkit, macos, menu-bar-overflow]

requires:
  - phase: 66-men-bar-overflow-ice-style-mvp
    provides: "Plan 66-01's NO-GO verdict on the private-CGS approach, ruling out private symbols for this mechanism"
provides:
  - "MenuBarOverflowController: chevron+spacer NSStatusItem pair implementing the hide/reveal mechanism via the public spacer-NSStatusItem technique"
  - "clampedExpandedSpacerLength(candidate:screenWidth:) pure clamp function, unit-tested against T-66-01 (degenerate screen-width DoS)"
  - "ActivitySettings.menuBarOverflowRevealedKey replacing the retired menuBarOverflowKey Bool activity toggle"
  - "Unconditional AppDelegate wiring — feature activates at launch with no Settings gate (D-02)"
affects: [66-03-settings-view-cleanup, 66-04, menu-bar-overflow-ui-spec]

tech-stack:
  added: []
  patterns:
    - "Public spacer-NSStatusItem technique (Hidden Bar reference) for menu-bar hide/reveal, replacing the superseded private-CGS window-enumeration approach"
    - "Pure-function-extracted-for-testability shape (mirrors DisplayResolver.swift) for the clamp logic"

key-files:
  created:
    - Islet/Notch/MenuBarOverflowController.swift
    - IsletTests/MenuBarOverflowClampTests.swift
  modified:
    - Islet/ActivitySettings.swift
    - IsletTests/ActivitySettingsTests.swift
    - Islet/AppDelegate.swift
    - Islet/SettingsView.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "menuBarOverflowController stored as an implicitly-unwrapped var (not a class-scope default-initialized let) because MenuBarOverflowController is @MainActor and AppDelegate's class-scope stored-property initializers run in a synchronous nonisolated context — mirrors statusItem's construct-inside-applicationDidFinishLaunching pattern"
  - "SettingsView.swift's pre-existing 'coming soon' Menu Bar Overflow card repointed to the new menuBarOverflowRevealedKey (Rule 3 blocking-fix) rather than left broken; its full UI rework remains Plan 66-03's scope per this plan's own interfaces note"

requirements-completed: [MENUBAR-01, MENUBAR-02, MENUBAR-03]

duration: ~25min
completed: 2026-07-28
---

# Phase 66 Plan 02: MenuBarOverflowController Summary

**Chevron+spacer NSStatusItem pair implementing menu-bar hide/reveal via the public spacer technique (Hidden Bar reference), wired unconditionally into AppDelegate with no Settings gate.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-28
- **Tasks:** 2/2 completed
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments
- Built `MenuBarOverflowController` — chevron (visible, clickable) + spacer (invisible, pure width) NSStatusItem pair, toggling the spacer's length between a 20pt revealed state and a screen-width-clamped hidden state, no animation
- Pure `clampedExpandedSpacerLength(candidate:screenWidth:)` function covered by 4 unit tests (T-66-01: never negative/runaway for degenerate screen widths)
- Retired the stale `menuBarOverflowKey` Bool activity-toggle key from `ActivitySettings.swift`, replaced with `menuBarOverflowRevealedKey` (persists D-05 reveal/hide UI state, not a Bool activity toggle)
- Wired `MenuBarOverflowController` unconditionally into `AppDelegate.applicationDidFinishLaunching`, constructed after `statusItem`/`debugStatusItem` so the chevron lands leftmost among Islet's own menu-bar items (D-01)
- Release build succeeds clean; both new/modified test files pass (25 tests total in the two suites)

## Task Commits

1. **Task 1: MenuBarOverflowController.swift — chevron+spacer construction, toggle logic, screen-width clamp** - `acacd59` (feat)
2. **Task 2: ActivitySettings key swap + AppDelegate wiring + build verify** - `8a930bc` (feat)

_Note: pbxproj regeneration (xcodegen generate) is bundled into Task 2's commit, matching the plan's stated action ordering._

## Files Created/Modified
- `Islet/Notch/MenuBarOverflowController.swift` - Pure clamp function + @MainActor controller class owning the chevron/spacer NSStatusItems, click-toggle, autosaveName, and screen-width re-clamp
- `IsletTests/MenuBarOverflowClampTests.swift` - 4 unit tests for the pure clamp function
- `Islet/ActivitySettings.swift` - Removed `menuBarOverflowKey`, added `menuBarOverflowRevealedKey`
- `IsletTests/ActivitySettingsTests.swift` - Updated assertions for the key swap, added a new key-name test
- `Islet/AppDelegate.swift` - Construct + unconditionally start `MenuBarOverflowController` after `statusItem`/`debugStatusItem`
- `Islet/SettingsView.swift` - Repointed the pre-existing "coming soon" card's `@AppStorage` key (deviation, see below)
- `Islet.xcodeproj/project.pbxproj` - xcodegen regenerate to register the two new files

## Decisions Made
- Stored `menuBarOverflowController` as an implicitly-unwrapped `var`, constructed inside `applicationDidFinishLaunching` rather than as a class-scope default-initialized `let` — required because `MenuBarOverflowController` is `@MainActor` and a class-scope initializer on `AppDelegate` (not itself `@MainActor`) runs in a synchronous nonisolated context, which fails to compile against a `@MainActor` initializer.
- Used `NSStatusItem.variableLength` explicitly (not `.variableLength` shorthand) — the parameter type is `NSStatusItem.Length` (a `CGFloat` typealias), and Swift's dot-shorthand resolves static members against the underlying `CGFloat` type, which has no `variableLength` member.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SettingsView.swift's pre-existing "Menu Bar Overflow" card referenced the removed `menuBarOverflowKey`**
- **Found during:** Task 2 build verification
- **Issue:** `SettingsView.swift:74` had `@AppStorage(ActivitySettings.menuBarOverflowKey) private var menuBarOverflowEnabled = false`, feeding a `isComingSoon: true` `ActivityCardData` entry (leftover scaffolding from Phase 59/SETTINGS-05). Removing `menuBarOverflowKey` per this plan's own instruction broke the Release build. The plan's interfaces note explicitly assigns `SettingsView.swift` changes to Plan 66-03, but the plan's own acceptance criteria require a clean Release build.
- **Fix:** Repointed the `@AppStorage` key to `menuBarOverflowRevealedKey`, minimal one-line change — no retitling, no `isComingSoon` removal, no card rework (left for Plan 66-03 as the plan intends).
- **Files modified:** Islet/SettingsView.swift
- **Verification:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` — BUILD SUCCEEDED, zero errors
- **Committed in:** `8a930bc` (Task 2 commit)

**2. [Rule 1 - Bug] AppDelegate's class-scope `let menuBarOverflowController = MenuBarOverflowController()` failed to compile**
- **Found during:** Task 2 build verification
- **Issue:** `error: call to main actor-isolated initializer 'init(defaults:)' in a synchronous nonisolated context` — `AppDelegate` is not `@MainActor`, so a class-scope stored-property default initializer cannot call a `@MainActor` class's `init`.
- **Fix:** Changed to `private var menuBarOverflowController: MenuBarOverflowController!`, constructed inside `applicationDidFinishLaunching` (mirrors `statusItem`'s existing pattern) immediately before calling `.start()`.
- **Files modified:** Islet/AppDelegate.swift
- **Verification:** Build succeeds
- **Committed in:** `8a930bc` (Task 2 commit)

**3. [Rule 1 - Bug] `.variableLength` shorthand failed to resolve on `NSStatusItem.Length`**
- **Found during:** Task 2 build verification
- **Issue:** `error: type 'CGFloat' has no member 'variableLength'` — `NSStatusBar.system.statusItem(withLength: .variableLength)` failed because the parameter type resolves to the underlying `CGFloat` typealias, not `NSStatusItem`.
- **Fix:** Used the fully-qualified `NSStatusItem.variableLength` (matching `AppDelegate.swift`'s own existing precedent at line 107).
- **Files modified:** Islet/Notch/MenuBarOverflowController.swift
- **Verification:** Build succeeds
- **Committed in:** `acacd59` (Task 1 commit, folded in before the commit was made — no separate fix commit needed since Task 1's build-affecting error was caught before Task 1's own commit)

---

**Total deviations:** 3 auto-fixed (1 blocking cross-file fix, 2 build-blocking bugs)
**Impact on plan:** All three were required for the plan's own "BUILD SUCCEEDED, zero errors" acceptance criterion. No scope creep — the SettingsView.swift fix is the minimum one-line change; the card's actual rework stays Plan 66-03's job.

## Issues Encountered
None beyond the three auto-fixed deviations above.

## Self-Check: PASSED

- FOUND: Islet/Notch/MenuBarOverflowController.swift
- FOUND: IsletTests/MenuBarOverflowClampTests.swift
- FOUND: commit acacd59
- FOUND: commit 8a930bc

## Next Phase Readiness
- `MenuBarOverflowController` is live and unconditionally active — on-device UAT (not part of this plan) will be needed to confirm the real-hardware toggle behavior before Phase 66 closes.
- Plan 66-03 can proceed: rework `SettingsView.swift`'s "Menu Bar Overflow" card (remove `isComingSoon`, retitle/redescribe or remove entirely per D-02's "no toggle" intent).

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Completed: 2026-07-28*
