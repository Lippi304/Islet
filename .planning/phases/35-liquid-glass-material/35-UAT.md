---
status: partial
phase: 35-liquid-glass-material
source: [35-01-SUMMARY.md, 35-02-SUMMARY.md, 35-03-SUMMARY.md, 35-04-SUMMARY.md]
started: 2026-07-16T00:37:15Z
updated: 2026-07-16T00:37:15Z
---

## Current Test

number: 1
name: Liquid Glass render on collapsed pill / expanded island
expected: |
  Collapsed pill and expanded island show a visible warped/rippled edge on the
  black material with a subtle color-fringed edge — a translucent "glass" look,
  not a flat opaque grey/black surface.
awaiting: user response (gap logged, remaining checks 2-7 blocked pending fix)

## Tests

### 1. Liquid Glass render on collapsed pill / expanded island
expected: Visible warped/rippled edge + subtle chromatic fringe on the island material; reads as translucent glass, not flat opaque grey.
result: issue
reported: "Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann" (screenshot attached: island shows as a flat opaque grey/dark panel with no visible edge warp, no chromatic fringe, and no transparency — cannot see the desktop/wallpaper through it at all)
severity: major

### 2. Collapse/expand transition smoothness
expected: No artifacts, no dropped frames, no diagonal-jump/bounce regression.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1 — no point verifying transition smoothness of an effect that isn't visually present yet.

### 3. All 3 wings show Liquid Glass (Now Playing, Charging, Device)
expected: All 3 wings show same warp+fringe as pill/expanded island, collapsed pill visibly subtler (D-04).
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 4. Foreground content stays crisp (only background material warps)
expected: Text/icons never distort, only the black background material shows warp.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 5. Settings Theming picker — 3rd Liquid Glass segment + default selection
expected: 3rd "Liquid Glass" segment exists, selected by default, live-updates island, zero regression to Gradient/Solid Black.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1 (same underlying material rendering).

### 6. Settings window's own calmer frosted background (no warp)
expected: Calm frosted/blurred dark gradient with rim-light edge, no warp, text readable.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 7. D-06 default-selection behavior (fresh install vs. existing preference)
expected: Fresh install defaults to Liquid Glass; existing explicit Gradient/Solid Black preference is respected.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

## Summary

total: 7
passed: 0
issues: 1
pending: 0
skipped: 0
blocked: 6

## Gaps

- truth: "The collapsed pill and expanded island render a translucent Liquid Glass look — visible edge warp, subtle chromatic fringe, and see-through transparency — not a flat opaque grey/black surface"
  status: failed
  reason: "User reported: 'Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann' — screenshot shows a flat opaque grey panel, no visible warp/fringe, no transparency to see through"
  severity: major
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
