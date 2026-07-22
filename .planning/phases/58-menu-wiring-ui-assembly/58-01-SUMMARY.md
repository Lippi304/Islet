---
phase: 58-menu-wiring-ui-assembly
plan: 01
subsystem: ui
tags: [appkit, nsmenu, nsmenuitem, nshostingview, nspasteboard, swiftui, clipboard]

# Dependency graph
requires:
  - phase: 55-clipboard-data-model-store
    provides: ClipboardItem/ClipboardStore (pure, unit-tested)
  - phase: 56-encrypted-persistence
    provides: ClipboardFileStore/KeychainClipboardKeyStore (AES-GCM at-rest encryption)
  - phase: 57-pasteboard-monitor-spike
    provides: ClipboardMonitor (live capture, self-capture guard, concealed-type exclusion)
provides:
  - Production (non-DEBUG) ClipboardStore/ClipboardMonitor wiring in AppDelegate — history loads at launch, new copies captured and persisted automatically
  - Flyout-submenu clipboard history section (anchor item + rows), MRU-first, empty-state row
  - Dual restore paths: SwiftUI onTapGesture (mouse) + global Cmd+0-9 hotkey monitor (works instantly on icon-click, independent of submenu open state)
  - restore(_:) — the one place that writes to NSPasteboard.general, tagged with ClipboardMonitor.restoreMarkerType
affects: [58-02-delete-all-pasteboard-explanation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSMenuItem.view hosting NSHostingView requires an explicit frame on both the SwiftUI content and the hostingView itself — NSMenu never auto-sizes a custom view"
    - "NSMenuItem keyEquivalents inside an unopened .submenu never fire — a menuWillOpen/menuDidClose-scoped local NSEvent keyDown monitor is the fix when a hotkey must work before the submenu is opened"
    - "SwiftUI .onHover unreliably receives mouseExited during NSMenu's tracking-mode run loop — NSTrackingArea on a wrapping NSView is the reliable alternative"

key-files:
  created: []
  modified:
    - Islet/AppDelegate.swift
    - .planning/phases/58-menu-wiring-ui-assembly/58-CONTEXT.md

key-decisions:
  - "D-15 REVISED (on-device UAT): clipboard rows moved from an inline top-of-menu list into a flyout submenu behind a single 'Clipboard History' anchor item, so more entries are visible at once — user-approved live, supersedes the original CopyClip-matching inline-list decision"
  - "Cmd+0-9 implemented as a hybrid: per-row NSMenuItem.keyEquivalent (works once the submenu is open) plus a local NSEvent keyDown monitor scoped to menuWillOpen/menuDidClose (works instantly on icon-click, before the submenu is ever opened) — required because submenu keyEquivalents don't fire while the submenu itself is closed"
  - "Row hover state moved off SwiftUI's .onHover onto a native NSTrackingArea (ClipboardRowContainerView/ClipboardHoverState) after .onHover was found to miss mouseExited during NSMenu's tracking-mode run loop, leaving highlight stuck on"

requirements-completed: [CLIP-01, CLIP-02, CLIP-03]

# Metrics
duration: single session (checkpoint)
completed: 2026-07-23
---

# Phase 58 Plan 01: Menu Wiring — Production Clipboard Store/Monitor + Dynamic History Menu Summary

**Production ClipboardStore/ClipboardMonitor wiring plus a dynamic, NSHostingView-rendered clipboard-history flyout submenu with dual restore paths (mouse click + a hybrid instant-on-icon-click Cmd+0-9 hotkey), confirmed on real hardware.**

## Performance

- **Duration:** single session (checkpoint) — Task 3 required an on-device pause/resume round
- **Tasks:** 3/3 completed (Task 3 was `checkpoint:human-verify`, approved with a mid-checkpoint design amendment)
- **Files modified:** 2 (`Islet/AppDelegate.swift`, `58-CONTEXT.md`)

## Accomplishments
- Replaced the `#if DEBUG`-only clipboard spike path with real, always-on wiring: `clipboardStore` seeded from `ClipboardFileStore.load` at launch, real `ClipboardMonitor` appending + persisting every genuine copy
- Built the first-ever `NSMenuDelegate`-driven dynamic menu rebuild in this codebase (`menuNeedsUpdate(_:)`), rendering clipboard rows via `NSHostingView` inside `NSMenuItem.view` — a first-of-kind AppKit/SwiftUI combination for this project
- Delivered CLIP-01 (MRU-first history, empty state), CLIP-02 (click-to-restore, no auto-paste), CLIP-03 (Cmd+0-9 quick-select) end to end, all confirmed on real hardware
- Found and fixed two real on-device bugs (invisible rows, stuck hover highlight) and shipped a user-requested live design amendment (flyout submenu + hybrid hotkey) without regressing any of the original checkpoint's verification steps

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire real ClipboardStore + ClipboardMonitor** - `2930605` (feat)
2. **Task 2: NSMenuDelegate dynamic rebuild — rows, empty state, dual click paths, Cmd+0-9** - `ef76154` (feat)
3. **Task 3: On-device check — dual click paths and real capture wiring** - `3e4acea` (fix, on-device UAT fixes + design amendment)

**Plan metadata:** (this commit, `docs(58-01): complete menu wiring & UI assembly plan`)

## Files Created/Modified
- `Islet/AppDelegate.swift` — production `clipboardStore`/`clipboardMonitor` properties + launch-time seed/start; `NSMenuDelegate` conformance with `menuNeedsUpdate(_:)`/`menuWillOpen(_:)`/`menuDidClose(_:)`; `ClipboardRowView`/`ClipboardRowContainerView`/`ClipboardHoverState`; `restoreClipboardItem(_:)`/`restore(_:)`
- `.planning/phases/58-menu-wiring-ui-assembly/58-CONTEXT.md` — D-15 amendment note recording the inline-list → flyout-submenu revision

## Decisions Made
- Kept the existing DEBUG-only clipboard spike hooks (`debugSpikeStartClipboardMonitor` etc.) in place alongside the new production path — harmless, developer-convenience only, per RESEARCH.md Pitfall 3's explicit allowance
- `menuWillOpen`/`menuDidClose` guard on `menu === self.menu` so the hotkey monitor only attaches/detaches around the top-level status-item menu, not any submenu open/close event
- Row width fixed at 260pt (`ClipboardRowView.rowWidth`) — both the SwiftUI content's `.frame(width:)` and the `NSHostingView`'s own `.frame` must agree on a concrete size since `NSMenuItem.view` is never auto-sized by AppKit

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NSHostingView inside NSMenuItem.view rendered rows at zero size**
- **Found during:** Task 3 (on-device checkpoint)
- **Issue:** Rows were correctly inserted into the menu (`menuNeedsUpdate` fired, `clipboardStore.items` was populated) but rendered completely invisible — the `NSHostingView` assigned to `menuItem.view` was never given an explicit frame, and `NSMenu` does not auto-size a custom view.
- **Fix:** Added `ClipboardRowView.rowWidth` (260pt) static constant; both the SwiftUI content's own `.frame(width:height:)` and the constructed `hostingView.frame` are now set explicitly to the same size before assignment to `menuItem.view`.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** On-device — rows render visibly with correct content.
- **Committed in:** `3e4acea`

**2. [Rule 1 - Bug] Row hover highlight stuck "on" after the pointer left**
- **Found during:** Task 3 (on-device checkpoint), same round
- **Issue:** SwiftUI's `.onHover` unreliably receives `mouseExited` during `NSMenu`'s tracking-mode run loop, so a row's `Color.primary.opacity(0.08)` highlight background stayed visible for whichever row was hovered last.
- **Fix:** Replaced the `@State isHovering` + `.onHover` pattern with a native `NSTrackingArea` on a new `ClipboardRowContainerView: NSView` wrapping the `NSHostingView`, publishing hover state through a new `ClipboardHoverState: ObservableObject` consumed via `@ObservedObject` in `ClipboardRowView`.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** On-device — highlight now tracks the mouse cleanly across rows with nothing stuck.
- **Committed in:** `3e4acea`

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs), plus 1 user-directed live design amendment (below).
**Impact on plan:** Both fixes were necessary for the feature to be usable at all (invisible rows made CLIP-01/02/03 unverifiable; stuck highlight is a visible UX defect). No unrequested scope creep — the row-width fix and hover fix are both scoped exactly to `ClipboardRowView`/`NSMenuItem.view` hosting, nothing else touched.

### Design Amendment (user-directed, live during on-device UAT — not an auto-fix)

**Supersedes locked decision D-15** (`58-CONTEXT.md`, originally "inline list at top of menu matching CopyClip").

During Task 3's on-device round, the user asked to see more clipboard entries at once than an inline top-of-menu list allows. Live redesign, confirmed with the user before implementing:
- Clipboard rows now live behind a single "Clipboard History" anchor `NSMenuItem` (disabled + titled "No items yet" when empty) with a flyout `.submenu` containing the rows — same `NSHostingView`-per-row approach and the same D-15 placement (anchor still sits above Settings…/Check for Updates…/Quit, same separator boundary).
- I flagged the known AppKit risk this creates before implementing: `NSMenuItem.keyEquivalent`s nested inside an unopened submenu don't fire, so a naive submenu move would break Cmd+0-9 on plain icon-click. Asked the user whether Cmd+0-9 needs to work instantly on icon-click or only once the submenu is open — user confirmed: must work instantly.
- Implemented as a hybrid: a `menuWillOpen(_:)`/`menuDidClose(_:)`-scoped local `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` monitor (`clipboardHotkeyMonitor`) intercepts pure-Cmd + digit 0-9 directly while the top-level menu is tracking, independent of submenu state — calls `restore(items[digit])`, then `menu.cancelTracking()`. Per-row `NSMenuItem.action`/`keyEquivalent` kept as the secondary path for when the submenu is actually open (RESEARCH.md Pitfall 1: never rely on only one trigger path).
- Verified on-device: Cmd+0 and Cmd+1 both restore instantly right after icon-click, without opening the submenu first; mouse-click restore inside the open submenu still works; new copies still appear at the top of the submenu on next open.

`58-CONTEXT.md`'s D-15 entry has been annotated in place with a "D-15 REVISED" note pointing to this SUMMARY rather than being rewritten, so the original locked decision stays visible as historical record (matches this project's Phase 25/38 precedent of flagging superseded decisions inline rather than silently rewriting them).

**Flag for whoever plans/executes 58-02:** that plan was written against the old inline top-of-menu row structure. The `menuNeedsUpdate(_:)` comment "Delete All History before this separator" now needs to be re-checked against the new anchor+submenu structure — "Delete All History" most naturally belongs either as a fixed last row inside the submenu (alongside the clipboard rows) or as a second top-level item next to the anchor, not literally "before the separator" as originally phrased against the old flat-list layout.

## Issues Encountered
None beyond the two auto-fixed bugs above — both were root-caused and fixed within the same on-device round, no repeated failed attempts.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CLIP-01/02/03 fully shipped and on-device confirmed; Plan 58-02 (Delete All History + pasteboard-access-explanation timing) is unblocked, with the menu-structure caveat noted above.
- Production clipboard capture is live for the remainder of this session/every future launch — no further wiring needed from 58-02.
- `clip.separator` remains the trailing boundary marker inside `menuNeedsUpdate(_:)`; 58-02 must re-verify where "Delete All History" fits against the anchor+submenu shape before assuming the original flat-list insertion point.

---
*Phase: 58-menu-wiring-ui-assembly*
*Completed: 2026-07-23*

## Self-Check: PASSED
- FOUND: Islet/AppDelegate.swift
- FOUND: .planning/phases/58-menu-wiring-ui-assembly/58-01-SUMMARY.md
- FOUND: .planning/phases/58-menu-wiring-ui-assembly/58-CONTEXT.md
- FOUND commit: 2930605
- FOUND commit: ef76154
- FOUND commit: 3e4acea
