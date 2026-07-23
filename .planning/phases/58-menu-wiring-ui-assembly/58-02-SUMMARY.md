---
phase: 58-menu-wiring-ui-assembly
plan: 02
subsystem: ui
tags: [appkit, nsmenu, nsmenuitem, nsalert, clipboard]

# Dependency graph
requires:
  - phase: 58-menu-wiring-ui-assembly
    plan: 01
    provides: Production clipboard wiring, NSMenuDelegate dynamic rebuild (menuNeedsUpdate), Clipboard History flyout submenu + anchor item
provides:
  - "Delete All History" destructive-confirm NSMenuItem — clears both clipboardStore (in-memory) and the on-disk encrypted index
  - Production pasteboard-access explanation (D-11/D-12/D-13 final copy), persisted one-time gate replacing Phase 57's DEBUG placeholder
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Persisted UserDefaults gate (not in-session Bool) for one-time explanations, set BEFORE the blocking NSAlert.runModal() call so an interrupted alert still can't reshow"
    - "Destructive NSAlert confirm gated strictly on .alertFirstButtonReturn — any other dismissal (Cancel, close box) is a no-op"

key-files:
  created: []
  modified:
    - Islet/AppDelegate.swift

key-decisions:
  - "Delete All History placed as a second top-level NSMenuItem next to the 'Clipboard History' anchor (outside its submenu), not nested inside the submenu with the dynamic rows — see Deviations below"

requirements-completed: [CLIP-05]

# Metrics
duration: single session (checkpoint)
completed: 2026-07-23
---

# Phase 58 Plan 02: Delete All History + Pasteboard-Access Explanation Summary

**Destructive-confirm "Delete All History" (real on-disk deletion, not just in-memory clear) plus the production one-time pasteboard-access explanation with final D-13 copy, closing Phase 58 — confirmed on real hardware.**

## Performance

- **Duration:** single session (checkpoint) — Task 3 was an on-device UAT pause/resume round
- **Tasks:** 3/3 completed (Task 3 was `checkpoint:human-verify`, approved on the first round)
- **Files modified:** 1 (`Islet/AppDelegate.swift`)

## Accomplishments
- "Delete All History" now shows a destructive-styled `NSAlert` ("Delete all clipboard history?" / "This cannot be undone." / red "Delete" + "Cancel") and, only on an explicit Delete click, clears both `clipboardStore` (in-memory) and rewrites `index.json.enc` to an empty array (RESEARCH.md Pitfall 2 — `ClipboardStore.clear()` alone never touches disk)
- Item disabled while history is empty (D-14), enforced by rebuilding `isEnabled` from `clipboardStore.items.isEmpty` on every `menuNeedsUpdate(_:)` pass
- Phase 57's `#if DEBUG`-only pasteboard-access placeholder (`debugSpikeCheckPasteboardAccessBehavior`, `debugHasShownPasteboardAccessExplanation`, its debug-menu entry) fully removed
- Production pasteboard-access explanation now fires on first menu open (not first captured item, D-11), as a native `NSAlert` (D-12), with final Claude-drafted copy (D-13), gated by a persisted `UserDefaults` flag set before `runModal()` so it can never show a second time
- All 4 ROADMAP Phase 58 success criteria (CLIP-01, CLIP-02, CLIP-03, CLIP-05) confirmed end-to-end on real hardware, closing the phase

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete All History — destructive confirm + real on-disk delete (CLIP-05)** - `b1a5e8c` (feat)
2. **Task 2: Pasteboard-access explanation — real timing + final copy (D-11/D-12/D-13)** - `efee849` (feat)
3. **Task 3: Phase-gate on-device UAT** - checkpoint, approved (no code changes)

**Plan metadata:** (this commit, `docs(58-02): complete Delete All History + pasteboard-access plan`)

## Files Created/Modified
- `Islet/AppDelegate.swift` — `confirmDeleteAllHistory()` + "Delete All History" `NSMenuItem` insertion in `menuNeedsUpdate(_:)`; `clipboardAccessExplanationShownKey` persisted gate + one-time `NSAlert` at the top of `menuNeedsUpdate(_:)`; Phase 57 DEBUG placeholder removed

## Decisions Made
- Kept the on-disk empty-rewrite (`ClipboardFileStore.save([], ...)`) as a second, explicit call alongside `clipboardStore.clear()` rather than folding delete-all into `ClipboardStore` itself — mirrors the existing append/save pairing already used everywhere else in `AppDelegate`, no new abstraction needed for a two-call sequence
- Persisted-flag-before-alert ordering (not after) for the pasteboard-access gate, so a killed/interrupted process during `runModal()` still can't reshow the explanation on next launch

## Deviations from Plan

### Auto-fixed Issues
None — both tasks built green on the first attempt, no bugs/blocking issues encountered during implementation.

### Design Clarification (plan wording re-derived against 58-01's on-device amendment — not a Rule 1-4 deviation)

**1. "Delete All History" placement re-derived against the anchor+submenu structure**
- **Found during:** Task 1, before writing any code
- **Issue:** 58-02-PLAN.md's Task 1 literally says to insert "Delete All History... so the final order is: clipboard rows → Delete All History → separator" — written against the OLD inline top-of-menu row layout (the plan's originally-locked D-15). During 58-01's on-device checkpoint, the user requested a live amendment (D-15 REVISED): clipboard rows moved behind a single "Clipboard History" anchor item with a flyout `.submenu`, so no top-level "clipboard rows" exist anymore to place "Delete All History" after.
- **Resolution:** Placed "Delete All History" as a second top-level `NSMenuItem`, a sibling of the "Clipboard History" anchor (not nested inside its submenu with the dynamic rows), still positioned before the `clip.separator` boundary — preserving D-15's overall "section sits above Settings…/Check for Updates…/Quit, separated by one separator" placement. This matches the option 58-01-SUMMARY.md itself flagged ("a second top-level item next to the anchor") and the placeholder comment 58-01 had already left in the code ("between the anchor and the boundary"). The alternative (nesting it as a fixed row inside the submenu) was rejected: it would put a destructive, always-relevant action behind an extra hover/open step, and would need special-casing inside the per-row `NSHostingView` loop for no benefit.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** On-device (Task 3) — "Delete All History" visible immediately next to "Clipboard History" without opening the submenu, confirmed working end-to-end.
- **Committed in:** `b1a5e8c`

---

**Total deviations:** 1 plan-wording re-derivation (pre-flagged by 58-01-SUMMARY.md as expected), 0 auto-fixed bugs.
**Impact on plan:** No scope creep — the re-derivation only resolves an ambiguity 58-01's own on-device amendment introduced; every acceptance-criteria grep in 58-02-PLAN.md still passes exactly as specified.

## On-Device UAT (Task 3)

Approved on the first round — all 7 verification steps confirmed by the user:
1. Pasteboard-access alert shown with final D-13 copy on first menu open, never again on subsequent opens
2. CLIP-01: clipboard history section (via the submenu) lists items most-recent-first alongside Settings…/Check for Updates…/Quit
3. CLIP-02: mouse click restores to pasteboard with no auto-paste
4. CLIP-03: Cmd+0-9 instantly restores the correct entry for 10+ seeded items, even before the submenu is opened
5. CLIP-05: destructive-styled confirmation dialog (red "Delete" button) shown; Cancel leaves history untouched; Delete empties the menu
6. On-disk deletion verified via the DEBUG "Spike: Print Clipboard Reload Result" hook — 0 items reload from disk, not just an empty in-memory list
7. Quit/relaunch round-trip confirmed: emptied history stays empty, new copies still capture and render correctly

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Phase 58 (Menu Wiring & UI Assembly) is complete: all 4 ROADMAP success criteria (CLIP-01, CLIP-02, CLIP-03, CLIP-05) confirmed on real hardware, closing v1.9 (Clipboard History) at 4/4 phases.
- No further wiring needed — production clipboard capture, restore, delete-all, and the access explanation are all live for every future launch.

---
*Phase: 58-menu-wiring-ui-assembly*
*Completed: 2026-07-23*

## Self-Check: PASSED
- FOUND: Islet/AppDelegate.swift
- FOUND: .planning/phases/58-menu-wiring-ui-assembly/58-02-SUMMARY.md
- FOUND commit: b1a5e8c
- FOUND commit: efee849
