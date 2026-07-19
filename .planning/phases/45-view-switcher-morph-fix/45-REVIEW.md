---
phase: 45-view-switcher-morph-fix
reviewed: 2026-07-19T15:39:18Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - Islet/Notch/NotchPillView.swift
  - IsletTests/NotchPillViewTests.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 45: Code Review Report

**Reviewed:** 2026-07-19T15:39:18Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the consolidation of the 6 per-case `blobShape` call sites (`homeEmptyState`, `mediaExpanded`, `mediaUnavailable`, `calendarFullView`, `weatherFullView`, `trayFullView`) into one shared `tabContentView`/`tabWidth`/`tabHeight` call site, plus the new `testTabWidthHeightMatchesKnownPerCaseValues` regression test.

The width/height mapping in `tabWidth`/`tabHeight` was checked line-by-line against every original per-case `blobShape` argument (via `git diff bff2fc3^`) and matches exactly: Home/NowPlaying group 420×170, Calendar 460×196, Tray 650×117, Weather 420×290/410. The extracted content-only functions (`mediaContent`, `mediaUnavailableContent`, `homeEmptyContent`, `calendarContent`, `weatherContent`, `trayContent`) preserve their original modifiers verbatim — this is a clean, mechanical extraction with no rendering regressions found. `presentationSwitch`'s grouped case arm is still compiler-exhaustive (no `default:` there), so a future new `IslandPresentation` case will still force a compile error if left unrouted.

Two real weaknesses were found, both centered on things the refactor silently dropped or introduced: (1) Tray's dedicated `shelfItems: []` safety override — previously an independent belt-and-suspenders guard against double-rendering shelf items — is now gone, relying solely on the single global `shelfStripVisible` flag; it is harmless today only because that flag is hardcoded `false`. (2) `tabWidth`/`tabHeight` use a `default:` catch-all instead of listing all 6 known cases explicitly, which — combined with this file's own documented history of geometry-mismatch misclick bugs — means a future 7th switcher-row case could compile silently with the wrong size. The rest are documentation/comment-drift nits.

## Warnings

### WR-01: `tabContentView` drops Tray's explicit shelf-items safety override

**File:** `Islet/Notch/NotchPillView.swift:838-841`
**Issue:** Before this phase, `trayFullView` deliberately called `blobShape(..., shelfItems: [], shelfVisible: false, ...)` — a hardcoded empty array and `false`, independent of `shelfStripVisible` — with the file's own comment explaining this exists so the additive shelf-strip mechanism "must NOT also append itself a second time below this content" (trayContent already renders `shelfRow` itself). The consolidated `tabContentView` now calls `blobShape(..., shelfItems: shelfViewState.items, shelfVisible: shelfStripVisible, ...)` for **all 6** cases including Tray, removing that independent guard.

Today this is harmless only because `shelfStripVisible` (line 75) is a hardcoded `{ false }` getter, so `hasShelf` inside `blobShape` is always `false` and `shelfItems` is never read. But the two previously-independent safety layers (per-call-site `[]` AND the global `false` flag) have been collapsed into one. If `shelfStripVisible` is ever changed back to something conditional (e.g. `shelfViewState.isVisible`, as it demonstrably was before quick task 260714-3k6, per this same file's comment at line 64-70), Tray will silently start rendering the additive shelf strip with real items *underneath* its own dedicated `shelfRow` — the exact double-render regression the original code explicitly guarded against.

**Fix:** Special-case Tray's `shelfItems` argument at the single call site so the guard survives the consolidation, e.g.:
```swift
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          width: tabWidth, height: tabHeight,
          shelfItems: isTrayTab ? [] : shelfViewState.items,
          shelfVisible: isTrayTab ? false : shelfStripVisible,
          showSwitcher: true) { ... }
```
where `isTrayTab` is `if case .trayExpanded = presentation { true } else { false }` (mirroring the existing `isOnboardingPresentation`/`isTrayPresentation` pattern already in this file).

### WR-02: `tabWidth`/`tabHeight` silently fall through on unhandled cases instead of failing loudly

**File:** `Islet/Notch/NotchPillView.swift:94-109`
**Issue:** `tabWidth`/`tabHeight` use a `default:` catch-all rather than enumerating the 4 Home/NowPlaying-group cases explicitly. `presentationSwitch` (the router) is compiler-exhaustive with no `default:`, so adding a 7th switcher-row `IslandPresentation` case there forces a compile error until it's added to the grouped arm — but `tabWidth`/`tabHeight` would then silently return `expandedSize.width`/`homeContentHeight` for that new case with **no compiler warning**, even if the intended size is different. Given this file's own extensively documented history of misclick/z-order bugs caused by exactly this class of per-case height mismatch (see the `switcherContentHeight`/`homeContentHeight` box-math comments around lines 610-652), a silent wrong-default here is a real regression risk for whoever adds the next tab.
**Fix:** Enumerate the known cases explicitly and let `default` only cover genuinely non-tab presentations (which never reach these properties in practice), or add a comment/assertion tying the two switches together, e.g.:
```swift
var tabWidth: CGFloat {
    switch presentation {
    case .homeEmpty, .homeLastPlayed, .nowPlayingExpanded: return Self.expandedSize.width
    case .calendarExpanded: return Self.calendarWidth
    case .trayExpanded: return Self.traySize.width
    case .weatherExpanded: return Self.expandedSize.width
    default: return Self.expandedSize.width // unreachable for switcher-row tabs
    }
}
```

### WR-03: Test's claimed "established @AppStorage-test-isolation precedent" does not exist elsewhere

**File:** `IsletTests/NotchPillViewTests.swift:82-105`
**Issue:** The comment states the direct `UserDefaults.standard` mutation is done "per this project's established @AppStorage-test-isolation precedent," but a repo-wide search shows this is the **only** test file in `IsletTests/` that touches `UserDefaults.standard` directly. The actual existing precedent (`ActivitySettingsTests.swift`) isolates state via `UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")` — a fresh, unshared store per test, with no save/restore needed. This test mutates real process-global `UserDefaults.standard` (unavoidable here since `NotchPillView`'s `@AppStorage` has no injectable `store:` parameter) and manually saves/restores the prior value. The save/restore is correctly implemented (via `defer`), so this isn't a functional bug, but the comment misrepresents precedent and could lead a future engineer to copy this riskier global-mutation pattern into a context where suite-based isolation would be safer.
**Fix:** Reword the comment to state this is a new, narrower exception (not an existing precedent) forced by `@AppStorage`'s lack of a `store:` override in `NotchPillView`, and note that a `store:`-injectable `@AppStorage` would let future tests use the safer `suiteName:` pattern instead.

## Info

### IN-01: Comments throughout the file still reference the pre-rename function names

**File:** `Islet/Notch/NotchPillView.swift` (e.g. lines 66, 245-254, 594, 627, 645-648, 703-706, 912, 963-969, 1032, 1041-1042, 1250, 1306, 1335, 1448, 1472-1473, 1498, 1527, 1540, 1875-1895, 1930, 2009-2012, 2059, 2253, 2707, 2868, 2921, 3057, 3275, 3409)
**Issue:** This phase renamed `mediaExpanded`→`mediaContent`, `mediaUnavailable`→`mediaUnavailableContent`, `homeEmptyState`→`homeEmptyContent`, `calendarFullView`→`calendarContent`, `weatherFullView`→`weatherContent`, `trayFullView`→`trayContent`, but dozens of surrounding doc comments (added in earlier phases) still refer to the old names. Harmless at compile time, but hurts future `grep`/navigation and can mislead a reader into thinking those symbols still exist.
**Fix:** A follow-up pass updating the stale identifier references in comments would keep the file's extensive inline documentation trustworthy (this file relies heavily on comments as design history, so drift here compounds over time).

### IN-02: Stale line-number citation in test comment

**File:** `IsletTests/NotchPillViewTests.swift:83-84`
**Issue:** The comment cites "no `store:` override at NotchPillView.swift:100" — but the actual `@AppStorage(ActivitySettings.weatherStyleKey)` declaration is at line 124 in the current file. Line 100 is the closing brace of the unrelated `tabWidth` computed property.
**Fix:** Either drop the specific line number (it will drift again on the next edit) or reference the symbol name only, e.g. "no `store:` override on `weatherStyle`'s `@AppStorage` declaration."

---

_Reviewed: 2026-07-19T15:39:18Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
