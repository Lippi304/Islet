---
status: partial
phase: 02-hover-expand-fullscreen-hardening
source: [02-VERIFICATION.md]
started: 2026-06-27T15:55:00Z
updated: 2026-06-27T15:55:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Hover/click feel — move the pointer onto the pill, then click to expand
expected: Hover fires a trackpad haptic + a subtle bounce WITHOUT expanding (D-01); a click expands with a snappy spring morph (D-02); pointer-leave collapses after ~0.4s grace; a quick re-entry cancels the collapse
result: [pending]

### 2. Morph quality — watch a full expand→collapse cycle
expected: The black blob MORPHS as one shape (corner radius + frame interpolate) with no cross-fade, no flicker, no jump (ISL-04 / SC#2)
result: [pending]

### 3. Fullscreen VIDEO yield — enter fullscreen YouTube (Safari) and QuickTime fullscreen on the built-in notched display
expected: The island hides completely (no ghost bar); exiting restores it
result: [pending]

### 4. QuickLook yield — Finder → select file → Space → toggle QuickLook fullscreen
expected: The island hides while QuickLook is fullscreen; closing restores it
result: [pending]

### 5. Maximized window must STAY visible — double-click title bar / option-click green button (zoom, NOT fullscreen)
expected: The island stays visible (a merely maximized/zoomed window is not a fullscreen Space, D-09)
result: [pending]

### 6. Clamshell + external-display coexistence — close/open the lid; enter fullscreen on the external while the built-in is present
expected: No flicker, no stuck-hidden, no stuck-shown; the island only ever shows on the built-in notched display
result: [pending]

### 7. Focus-safety of the auto-restore — let fullscreen exit while another app is foreground
expected: Restoring the island (orderFrontRegardless only) does NOT steal focus from the foreground app (D-04 / SC#4)
result: [pending]

### 8. Click-through around the island — click the desktop / menu bar OUTSIDE the pill while idle and while expanded
expected: Clicks outside the pill pass through to whatever is underneath; interacting with the island never activates Islet (SC#4); the WR-02 toggle-shut/exit edge case behaves
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps

## Known Deferred (not a gap)

- ~1-frame island flash at the END of the fullscreen-ENTER transition. Root-caused as window-server compositing of the `.canJoinAllSpaces` panel onto the activating fullscreen Space; the reactive `orderOut` cannot pre-empt it. Negligible in release (pill ships pure black / flush). Product-deferred to a later polish phase (Plan 05 / Phase 6). Documented in 02-04-SUMMARY.md.

## Note: ROADMAP wording

ROADMAP Success Criterion #1 literally says "hovering expands"; decision D-02 (Alcove click-to-open) supersedes it — hover gives an affordance (haptic + bounce) but only a CLICK expands. Verified against D-02. Reconcile the ROADMAP/REQUIREMENTS wording if desired.
