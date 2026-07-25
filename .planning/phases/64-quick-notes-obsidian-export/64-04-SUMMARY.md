---
phase: 64-quick-notes-obsidian-export
plan: 04
subsystem: ui
tags: [swiftui, appkit, nspopover, nsstatusitem, quick-notes]

requires:
  - phase: 64-01
    provides: QuickNote, QuickNotesStore, QuickNotesFileStore (pure reducer + persistence)
  - phase: 64-02
    provides: QuickNotesVaultWriter.append/isValidVaultFolder (vault file I/O)
  - phase: 64-03
    provides: ActivitySettings.quickNotesVaultFolderPathKey (vault folder picker)
provides:
  - QuickNotesController (ObservableObject bridging AppDelegate <-> SwiftUI popover)
  - QuickNotesPopoverView (4-state popover content: normal/vault-not-configured/error/empty)
  - QuickNoteRowView (hover-reveal delete row)
  - AppDelegate "New Note…" menu item + quickNotesPopover + submit/delete handlers
affects: [64-05]

tech-stack:
  added: []
  patterns:
    - "NSPopover anchored to NSStatusItem, hosted SwiftUI via NSHostingController (first use of NSPopover in this codebase)"
    - "do/catch success-path-only store mutation for a locked data-loss guard (D-12)"

key-files:
  created:
    - Islet/QuickNotes/QuickNotesPopoverView.swift
  modified:
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "submit() only clears the TextEditor's text on a successful onSubmit (controller.errorMessage == nil afterward), not unconditionally — the plan's own <action> text said 'unconditionally', but that directly contradicts this same plan's <behavior> spec (state 3: 'typed text still present' on error) and CONTEXT.md's locked D-12 data-loss guard. Resolved in favor of D-12 (locked rule) + the plan's own behavior spec over the action's literal wording."
  - "The 'Couldn't save…' error banner text is hardcoded directly in QuickNotesPopoverView (not just derived from controller.errorMessage's content) so the exact UI-SPEC copy lives in the view per the Copywriting Contract, while errorMessage itself still carries the same string when AppDelegate sets it on catch"

requirements-completed: [NOTES-01, NOTES-02, NOTES-03]

duration: 12min
completed: 2026-07-25
---

# Phase 64 Plan 04: Quick Notes Popover + AppDelegate Wiring Summary

**"New Note…" menu item opens a real NSPopover with a Cmd+Return-submitting TextEditor and recent-notes list, wired to AppDelegate's D-12 data-loss guard (vault write must succeed before the local store/list ever changes) and D-11 (vault path re-validated on every open).**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- `QuickNotesPopoverView.swift` created: `QuickNotesController` view-model + `QuickNotesPopoverView` (renders all 4 states: normal, vault-not-configured, error, empty) + `QuickNoteRowView` (hover-reveal trash delete, plain `.onHover` since this is a real `NSPopover`, not an `NSMenuItem.view`)
- `AppDelegate.swift` wired: "New Note…" menu item, `quickNotesPopover` (`NSPopover` + `NSHostingController`), `openQuickNotesPopover()` (re-checks `isValidVaultFolder` fresh every open, D-11), `handleQuickNoteSubmit(_:)` (D-12's locked guard: `quickNotesStore.append` only runs inside `QuickNotesVaultWriter.append`'s try-success path), `handleQuickNoteDelete(_:)` (local-list-only, never touches the vault, D-17)
- Registered the new file in `Islet.xcodeproj/project.pbxproj` (file reference, group entry, main-target Sources build phase)
- Build green (`xcodebuild -project Islet.xcodeproj -scheme Islet build`), all 9 grep-based acceptance criteria across both tasks pass

## Task Commits

Each task was committed atomically:

1. **Task 1: QuickNotesPopoverView (SwiftUI content)** - `66f8251` (feat)
2. **Task 2: AppDelegate wiring — menu item, popover, submit/delete handlers** - `983a746` (feat)

_Note: tdd="true" was satisfied via the plan's own build + grep-based acceptance criteria (its `<verify>` section explicitly states this class of AppKit/data-loss-ordering correctness "cannot be fully proven by a unit test against a private AppDelegate method" — no XCTest file was specified in either task's `<action>`), not a separate RED/GREEN XCTest cycle. Plan 64-05's on-device UAT is the designated behavioral verification step._

## Files Created/Modified

- `Islet/QuickNotes/QuickNotesPopoverView.swift` - `QuickNotesController`, `QuickNotesPopoverView` (4 states), `QuickNoteRowView`, `QuickNotesEmptyStateView`
- `Islet/AppDelegate.swift` - Quick Notes properties, "New Note…" menu item, launch-time load + closure wiring, `openQuickNotesPopover`/`handleQuickNoteSubmit`/`handleQuickNoteDelete`
- `Islet.xcodeproj/project.pbxproj` - registered `QuickNotesPopoverView.swift` in the main Islet target

## Decisions Made

- **Text-clear-on-submit resolved in favor of D-12 over the plan's literal action text:** the plan's `<action>` said `submit()` clears the field "unconditionally," but its own `<behavior>` block (state 3) requires the typed text to remain present on a failed save, and CONTEXT.md's D-12 is a locked rule, not discretion. Implemented `submit()` to clear the field only when `controller.errorMessage == nil` immediately after the synchronous `onSubmit` call returns — satisfies D-03 (clears on success) without violating D-12 (preserves on failure).
- **Error banner text hardcoded in the view, not solely bound to `controller.errorMessage`'s string content** — keeps the UI-SPEC's exact copy contract owned by the view itself (also required verbatim by Task 1's own grep-based acceptance criterion against `QuickNotesPopoverView.swift`), while `errorMessage` still acts as the presence/absence flag driving the banner's visibility.
- Save button uses `.buttonStyle(.borderedProminent)` + `.tint(Color.accentColor)` with a semibold label — matches UI-SPEC's Color/Typography contract (accent reserved for the submit button only, semibold reserved for its label only).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `submit()` clear-on-success-only instead of unconditional clear**
- **Found during:** Task 1 (QuickNotesPopoverView)
- **Issue:** The plan's `<action>` literally instructs clearing `text` unconditionally after `onSubmit`, which would silently discard the user's typed note on a failed vault write — directly violating this same plan's `<behavior>` state-3 description and CONTEXT.md's locked D-12 data-loss guard.
- **Fix:** `submit()` now clears `text` only when `controller.errorMessage == nil` right after the synchronous `onSubmit` call returns.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`
- **Verification:** Build green; behavior matches the plan's own state-3 spec and D-12; no grep-based acceptance criterion checks this specific line so no criterion regressed.
- **Committed in:** `66f8251` (Task 1 commit)

**2. [Rule 1 - Bug] Removed the literal string "NSTrackingArea" from a code comment**
- **Found during:** Task 1 (QuickNotesPopoverView), post-write acceptance check
- **Issue:** A doc comment on `QuickNoteRowView` explaining why plain `.onHover` (not `ClipboardRowView`'s tracking-area workaround) is used literally contained the word "NSTrackingArea", causing `grep -c "NSTrackingArea"` to return 1 instead of the required 0 (Task 1's own acceptance criterion).
- **Fix:** Reworded the comment to describe the same rationale ("tracking-area-based workaround") without the literal API name.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`
- **Verification:** `grep -c "NSTrackingArea" Islet/QuickNotes/QuickNotesPopoverView.swift` returns 0; build re-verified green.
- **Committed in:** `66f8251` (Task 1 commit)

**3. [Rule 3 - Blocking] `QuickNotesEmptyStateView` had a `body: String` property colliding with `View.body`**
- **Found during:** Task 1 first build attempt
- **Issue:** `let body: String` on a `View`-conforming struct redeclared the protocol-required `var body: some View`, a compile error (`invalid redeclaration of 'body'`).
- **Fix:** Renamed the property to `message`.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`
- **Verification:** `xcodebuild -project Islet.xcodeproj -scheme Islet build` succeeded after the fix.
- **Committed in:** `66f8251` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (1 data-loss bug, 1 acceptance-criterion-blocking comment wording, 1 compile-blocking rename)
**Impact on plan:** All three were necessary for correctness (data-loss prevention, the plan's own stated acceptance criteria, and compilation). No scope creep — no code beyond what the plan specified was added.

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The full "New Note…" capture flow is code-complete and build-verified: popover opens, Cmd+Return submits, D-11/D-12/D-17 guards are wired per CONTEXT.md's locked rules.
- Plan 64-05 (on-device UAT) is the next step — it must specifically verify Pitfall 10 (does `makeFirstResponder` actually land keyboard focus in the `TextEditor` on a status-item-anchored `NSPopover`, with zero extra click) and Assumption A2 (does `Cmd+Return` actually fire while the sibling `TextEditor` holds first responder). Both are flagged in 64-RESEARCH.md as genuinely unverified AppKit mechanics, not settled by this plan's build-only verification.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*
