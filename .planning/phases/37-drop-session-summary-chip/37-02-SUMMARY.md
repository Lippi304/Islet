---
phase: 37-drop-session-summary-chip
plan: 02
subsystem: notch-view-rendering
tags: [swiftui, notch-pill, drop-session-chip, hud-07]
dependency-graph:
  requires: [37-01]
  provides: [chipTextRow-renderer, collapsed-and-wings-chip-growth]
  affects: [37-03]
tech-stack:
  added: []
  patterns:
    - "Reused Phase 18's toastTextRow growth mechanics verbatim for a second independent one-shot field (SessionSummaryChip)"
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
decisions: []
metrics:
  duration: "~15min"
  completed: 2026-07-17
---

# Phase 37 Plan 02: Drop-Session Summary Chip Renderer Summary

Chip text row + chip-aware growth wired into both collapsed-state render paths (`collapsedIsland` for `.idle`, `mediaWingsOrToast` for `.nowPlayingWings`), as a verbatim reuse of Phase 18's song-change-toast growth mechanics.

## What Was Built

- **`chipTextRow(_ chip: SessionSummaryChip) -> some View`** (new, directly after `toastTextRow(_:)`): structurally identical to `toastTextRow` — same font (`.system(size: 12, weight: .medium, design: .rounded)`), `.foregroundStyle(.white)`, `.lineLimit(1)`, `.truncationMode(.tail)`, `.padding(.horizontal, 16)`, `.frame(width: Self.wingsSize.width, height: Self.toastExtraHeight, alignment: .center)`. Content: `Text(chip.count == 1 ? "1 file saved" : "\(chip.count) files saved")` (D-05 pluralization).
- **`collapsedIsland`** (the `.idle` render path, nothing playing): reads `shelfViewState.sessionSummaryChip`. When present, the shape's `.frame` uses `Self.wingsSize.width` / `Self.wingsSize.height + Self.toastExtraHeight` instead of the measured-notch `size`; when absent, the existing `size`-based frame is completely unchanged (no regression to D-01 hardware-notch-merge sizing). `.matchedGeometryEffect` still precedes `.frame` (diagonal-bounce bugfix preserved). New `.overlay(alignment: .top) { if let chip { chipTextRow(chip) } }` added after the existing `liquidGlassEffectLayer` overlay — chip-only, no VStack needed since `collapsedIsland` has no other top-row content.
- **`mediaWingsOrToast(_:)`** (the `.nowPlayingWings` render path, media playing): reads `shelfViewState.sessionSummaryChip` alongside the existing `songChangeToast`. `height` now adds a second independent term (`+ Self.toastExtraHeight` when chip present) on top of the existing toast term — both can be non-nil simultaneously and stack. Inside the existing `VStack` overlay, a sibling `if let chip { chipTextRow(chip).transition(.opacity) }` added after the toast row.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift` — FOUND (modified, present on disk)
- Commit `aaaa886` — FOUND (`git log --oneline` confirms)
- `grep -c "func chipTextRow"` → 1
- `grep -c "shelfViewState.sessionSummaryChip"` → 2 (one in `collapsedIsland`, one in `mediaWingsOrToast`)
- `grep -A2 "1 file saved" | grep -c "files saved"` → 2 (pluralized branch present, both call sites via shared function)
- `xcodebuild build -scheme Islet -destination 'platform=macOS'` → BUILD SUCCEEDED
- `grep -c "matchedGeometryEffect"` in file → 15 total (ordering before `.frame` preserved in both touched functions; no new matchedGeometryEffect call added by this plan, only frame-argument branching)
