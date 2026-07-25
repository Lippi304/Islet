---
phase: 64-quick-notes-obsidian-export
plan: 06
subsystem: ui
tags: [swiftui, appkit, nspopover, nsmenu, scrollview, focusstate, gesture-arbitration]

# Dependency graph
requires:
  - phase: 64-quick-notes-obsidian-export (Plan 04)
    provides: Quick Notes popover/menu shipped, 64-UAT.md tests 2/7/8 regressions found
provides:
  - Quick Notes popover TextEditor gets real keyboard focus on open with zero prior click, via @FocusState + focusRequestToken (not AppKit makeFirstResponder)
  - Vault-not-configured empty-state popover dismisses normally on outside click/Escape (no focus request issued when vault is unconfigured)
  - Recent-notes row delete button reliably clickable even while the ScrollView's native overlay scrollbar is visible
  - Status-item menu order: New Note… -> separator -> Clipboard History (+ Delete All History) -> separator -> Settings…/Check for Updates… -> separator -> Quit Islet
  - Cmd+Return hint label next to Save Note
affects: [64-08-quick-notes-vault-delete]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@FocusState + a controller-owned Int token (bumped only under a guard condition) as the cross-boundary focus-request mechanism for SwiftUI content hosted in an AppKit NSPopover, replacing a direct makeFirstResponder call that targeted the wrong view and couldn't be conditioned safely"
    - "When a ScrollView's native overlay scrollbar visually/functionally overlaps trailing row content, moving the content's own hit-tested element further from the true edge (with contentShape scoped tightly before any padding) is the fix that held up on-device — SwiftUI-side scroll-indicator margin APIs (.contentMargins(for: .scrollIndicators)) did not resolve the click-eaten-by-AppKit-scroller-view symptom in this app's actual usage"

key-files:
  created: []
  modified:
    - Islet/QuickNotes/QuickNotesPopoverView.swift
    - Islet/AppDelegate.swift

key-decisions:
  - "Focus routing: AppDelegate bumps QuickNotesController.focusRequestToken only when vaultConfigured is true, observed via .onChange -> isTextFocused = true; no makeFirstResponder call remains anywhere in AppDelegate for this popover"
  - "Delete-button hit-target: after two failed attempts (14pt content inset; .contentMargins(.trailing, 20, for: .scrollIndicators)), the fix that survived on-device re-verification is the user's own direct guidance — revert the scrollbar to its normal true trailing edge, widen the popover 280->320pt, and move the delete icon's own trailing padding to 36pt with contentShape applied before the padding so the tappable region stays tight to the icon and doesn't reintroduce overlap via the added gap"
  - "Menu order: 'New Note…' moved to be the very first static menu item (was built third, after Settings/Check for Updates) so the dynamic Clipboard History block — still inserted via NSMenu.indexOfItem(withTarget:andAction:) right after it — renders at the very top; a clip.-tagged leading separator (rebuilt every menuNeedsUpdate call, same pattern as the existing trailing separator) sits between New Note… and Clipboard History"
  - "Vault-file reconciliation (re-read the .md file on popover open and prune locally-listed notes deleted directly in the vault) was requested mid-plan as additional scope. Deferred to Plan 64-08, not built here — it is new functionality (not a regression against this plan's own locked spec, unlike Tasks 1-3), and 64-08 already owns wiring vault-delete into the popover and already touches QuickNotesVaultWriter's read/enumerate contracts from 64-07. Flagging explicitly per the coordinator's request so the next agent knows this is NOT covered by 64-06."

patterns-established:
  - "Cross-boundary SwiftUI/AppKit focus request: a small Int token @Published on the view-model, incremented by the AppKit-side owner under whatever business-logic guard applies, observed via .onChange on the SwiftUI side to flip a @FocusState bool — avoids ever calling makeFirstResponder against a SwiftUI-hosted view directly."

requirements-completed: [NOTES-01, NOTES-03]

# Metrics
duration: multi-session (checkpoint, 4 on-device UAT rounds)
completed: 2026-07-25
---

# Phase 64 Plan 06: Quick Notes Popover/Menu Regression Fixes Summary

**Fixed 3 UAT-reported regressions (focus-on-type, empty-state stuck-open, scrollbar-vs-delete-button hit-target) and reordered the status-item menu, closing 64-UAT.md tests 2/7/8, across 4 on-device verification rounds that overturned 2 of the original 3 automated fixes.**

## Performance

- **Duration:** multi-session (checkpoint, 4 on-device UAT rounds)
- **Completed:** 2026-07-25
- **Tasks:** 3 automated tasks + 1 consolidated human-verify checkpoint (re-run 4 times)
- **Files modified:** 2 (`QuickNotesPopoverView.swift`, `AppDelegate.swift`)

## Accomplishments

- Quick Notes popover's `TextEditor` now receives real keyboard focus immediately on open with zero prior click, via `@FocusState` + a `focusRequestToken` published property — the root cause (an unconditional `makeFirstResponder` call targeting the wrong hosted view) is fully removed.
- The "Vault folder not set" empty-state popover now closes normally on outside click/Escape — no focus request of any kind is issued when the vault isn't configured, removing the responder-chain interference that blocked `.transient` dismissal.
- The recent-notes list's per-row delete button is now reliably clickable at any scroll position, including while the native overlay scrollbar is visible — after two dead-end attempts (visual content inset, then `.contentMargins(for: .scrollIndicators)`), the fix that survived on-device re-verification was widening the popover, reverting the scrollbar to its normal trailing edge, and moving the button itself 36pt left with a hit-region scoped tightly to the icon.
- "New Note…" now renders at the very top of the status-item menu, followed by a separator, then Clipboard History, matching the user's confirmed target order.
- Small `⌘⏎` hint added next to "Save Note" (requested mid-plan, unrelated to the regression fixes).

## Task Commits

Each task/fix was committed atomically:

1. **Task 1: Fix popover focus regression + empty-state stuck-open bug** - `30ac288` (fix)
2. **Task 2: Fix scrollbar-over-delete-button hit-target bug (content inset, superseded)** - `1c57ff7` (fix)
3. **Task 3: Reorder status-item menu via selector lookup (superseded)** - `7eef9ce` (fix)
4. **UAT round 2 re-fix: highPriorityGesture for delete tap (addressed wrong layer, kept as harmless)** - `ed45cae` (fix)
5. **UAT round 2 re-fix: move New Note to top of static menu** - `0949533` (fix)
6. **UAT round 3 re-fix: `.contentMargins(for: .scrollIndicators)` gutter (superseded — didn't hold on-device)** - `84dacd7` (fix)
7. **UAT round 3 re-fix: leading separator before Clipboard History** - `7c04507` (fix)
8. **UAT round 4 re-fix (root-cause, approved): widen popover 280→320pt, revert scrollbar to true edge, move delete button 36pt left with tight contentShape** - `9f0af57` (fix)
9. **Additional scope: Cmd+Return hint next to Save Note** - `7a7aa80` (feat)

_Note: Steps 2, 3, and 6 were genuine dead-end attempts, not scope creep — each was superseded by the next commit after on-device re-testing disproved the hypothesis. Kept in history per the atomic-commit-per-task protocol rather than squashed, so the debugging trail is visible._

## Files Created/Modified

- `Islet/QuickNotes/QuickNotesPopoverView.swift` - `focusRequestToken` on `QuickNotesController`; `@FocusState` + `.onChange` wiring on `QuickNotesPopoverView`; popover widened to 320pt; `QuickNoteRowView`'s delete icon uses `.highPriorityGesture` + 36pt trailing padding (contentShape scoped before the padding); `⌘⏎` hint next to Save Note
- `Islet/AppDelegate.swift` - `openQuickNotesPopover()` replaces the unconditional `makeFirstResponder` call with a `guard vaultConfigured` + `focusRequestToken += 1`; static menu reordered (`New Note…` now first); `menuNeedsUpdate(_:)` inserts a leading `clip.`-tagged separator before the Clipboard History anchor

## Decisions Made

See `key-decisions` in frontmatter above — summarized:
- Focus: token-based `@FocusState` request, gated on vault-configured, replaces `makeFirstResponder` entirely.
- Hit-target: after 2 failed attempts, the working fix moves the button (not the scrollbar) with a wider popover and a tightly-scoped `contentShape` ahead of the added padding.
- Menu order: "New Note…" moved to the actual top of the static menu build (not just a relative-insertion-index fix), plus a dedicated leading separator.
- Vault-file reconciliation (new scope requested mid-plan): deferred to Plan 64-08, not built here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, found via on-device UAT] Scrollbar-vs-delete-button hit-target required 3 fix attempts before the root cause was correctly identified**
- **Found during:** Consolidated checkpoint, re-run 3 times
- **Issue:** The plan's own Task 2 hypothesis (visual content padding fixes the overlap) was insufficient; a second hypothesis (SwiftUI gesture-arbitration loss vs. the ScrollView's pan recognizer, fixed via `.highPriorityGesture`) was also wrong; a third hypothesis (`.contentMargins(_:_:for: .scrollIndicators)` repositioning the indicator) still failed on-device. The actual root cause, confirmed only by the user's own on-device testing (clicking worked once the native `NSScroller` had auto-hidden and only failed while it visibly overlapped the button), was that the AppKit scroller view itself consumes clicks in its overlap region — no SwiftUI-side gesture or margin API could override that.
- **Fix:** Reverted the scrollbar to its normal true trailing edge; widened the popover 280→320pt; moved the delete icon's own trailing padding to 36pt (vs. the original 14pt) with `contentShape` applied before the padding so the tappable region doesn't stretch into the added gap.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`
- **Verification:** User-confirmed on-device, clicking during/immediately after an active scroll gesture (the only state that reproduces the bug).
- **Committed in:** `9f0af57`

**2. [Rule 1 - Bug, found via on-device UAT] Menu-reorder fix (Task 3) was insufficient — needed the static build order changed, not just the dynamic insertion index**
- **Found during:** First checkpoint round
- **Issue:** The plan's selector-based `insertionIndex` fix (`menu.indexOfItem(withTarget:andAction:) + 1`) only repositions the dynamic Clipboard History block *relative to* wherever "New Note…" sits — but "New Note…" was still built third in `applicationDidFinishLaunching`, so the whole block stayed below Settings/Check for Updates.
- **Fix:** Reordered the static menu construction so "New Note…" is item 0.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** User-confirmed menu order on-device.
- **Committed in:** `0949533`

**3. [Rule 2 - Missing critical, requested mid-plan] Separator between "New Note…" and "Clipboard History"**
- **Found during:** Second checkpoint round (user feedback: menu order correct but no visual break)
- **Issue:** The two sections sat together with no separator, unlike every other section boundary in the same menu.
- **Fix:** Added a `clip.`-tagged leading separator, rebuilt every `menuNeedsUpdate` call (same pattern as the existing trailing separator).
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** User-confirmed on-device.
- **Committed in:** `7c04507`

**4. [Additional scope, requested mid-plan, not a deviation from the original locked spec] Cmd+Return hint**
- **Found during:** Third checkpoint round
- **Issue:** N/A — new, explicitly requested feature, not a bug.
- **Fix:** Small secondary-styled `⌘⏎` `Text` next to "Save Note" (no existing shortcut-glyph convention elsewhere in the app to reuse).
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`
- **Verification:** User-confirmed visually on-device.
- **Committed in:** `7a7aa80`

---

**Total deviations:** 4 (2 root-cause corrections after failed hypotheses, 1 missing-visual-affordance fix, 1 explicitly-requested feature addition)
**Impact on plan:** All required to actually close UAT tests 2/7/8 and the menu-order request — the plan's original Task 2/3 approaches were reasonable first hypotheses but proved insufficient only through real on-device testing, which is exactly what this plan's non-autonomous checkpoint gate exists to catch. No unrelated scope creep — the Cmd+Return hint was explicitly requested by the user mid-plan, not self-initiated.

## Issues Encountered

- Three consecutive hypotheses for the scrollbar/delete-button hit-target bug failed on-device before the actual root cause (AppKit's native `NSScroller` view physically consuming clicks in its overlap region, not any SwiftUI-side gesture or layout mechanism) was identified via the user's own targeted testing (clicking specifically during/immediately after an active scroll, not after auto-hide). Resolved by following the user's direct layout guidance rather than attempting a fourth independent hypothesis.
- Menu-order fix required two rounds: the selector-based relative-insertion fix (Task 3 as planned) was necessary but not sufficient — the static menu's build order itself also needed to change.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None found — scanned both modified files for hardcoded empty values, placeholder text, and unwired data sources; none present.

## Next Phase Readiness

- UAT tests 2, 7 (hit-target half), and 8 no longer reproduce their reported failures; the status-item menu shows the user-confirmed order. Plan's own success criteria met and on-device approved.
- **Handoff to Plan 64-08:** the vault-file-reconciliation feature (re-read the target `.md` file on popover open and prune locally-listed notes that were deleted directly in the vault, outside the app) was requested as additional scope during this plan's UAT but was deliberately **not** built here — it's new functionality, not a regression against 64-06's own locked spec, and 64-08 already owns wiring vault-delete into the popover plus the `QuickNotesVaultWriter` read/enumerate contracts (from 64-07) it would need. 64-08's planning should explicitly confirm whether this reconciliation is in its scope or needs its own follow-up plan.
- UAT test 7's vault-file-deletion half (as opposed to the hit-target half fixed here) remains Plan 64-08's responsibility, per the original plan's own scoping note.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*

## Self-Check: PASSED

All modified files exist (`Islet/QuickNotes/QuickNotesPopoverView.swift`, `Islet/AppDelegate.swift`, this SUMMARY.md); all 9 referenced commit hashes (`30ac288`, `1c57ff7`, `7eef9ce`, `ed45cae`, `0949533`, `84dacd7`, `7c04507`, `9f0af57`, `7a7aa80`) confirmed present in git history.
