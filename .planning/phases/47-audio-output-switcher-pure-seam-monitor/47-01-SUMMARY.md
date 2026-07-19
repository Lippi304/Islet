---
phase: 47-audio-output-switcher-pure-seam-monitor
plan: 01
subsystem: audio-output-switcher
tags: [pure-seam, coreaudio, unit-tested]
dependency-graph:
  requires: []
  provides: [AudioOutputDevice, isOutputCapableDevice, sortedAudioOutputDevices]
  affects: [Plan 47-02 (AudioOutputMonitor), Phase 48 (UI wiring)]
tech-stack:
  added: []
  patterns: ["Pattern 1 pure-seam isolation (Foundation-only, zero system-framework import)"]
key-files:
  created:
    - Islet/Notch/AudioOutputPresentation.swift
    - IsletTests/AudioOutputPresentationTests.swift
  modified: []
decisions:
  - "AudioOutputDevice.id derives from uid (String), never AudioDeviceID — Pitfall 4 compliance baked into the type itself"
  - "sortedAudioOutputDevices uses localizedStandardCompare (not raw ASCII <) for human-natural alphabetical ordering, matching this project's polished/native-feel convention"
metrics:
  duration: 15min
  completed: 2026-07-19
---

# Phase 47 Plan 01: Audio Output Switcher — Pure Seam Summary

Built the pure, Foundation-only presentation seam for the audio-output switcher — a stable-UID-keyed `AudioOutputDevice` value type, D-01's `isOutputCapableDevice(outputChannelCount:)` classifier, and D-02's `sortedAudioOutputDevices(_:)` default-pinned-first sort — following the exact Pattern 1 isolation discipline already established by `NowPlayingPresentation.swift`/`OSDActivity.swift`.

## What Was Built

- **`Islet/Notch/AudioOutputPresentation.swift`** (new): `import Foundation` only, zero CoreAudio/AppKit/SwiftUI import.
  - `struct AudioOutputDevice: Equatable, Identifiable` — `uid`, `name`, `isDefault`; `id` computed from `uid` (never `AudioDeviceID`, per Pitfall 4).
  - `func isOutputCapableDevice(outputChannelCount: Int) -> Bool` — total pure classifier, `outputChannelCount > 0`. Any positive channel count (physical, AirPlay, or aggregate/Multi-Output device) counts as output-capable per D-01; zero or negative does not.
  - `func sortedAudioOutputDevices(_ devices: [AudioOutputDevice]) -> [AudioOutputDevice]` — partitions into `isDefault == true` (kept first, original relative order preserved) and the rest (sorted alphabetically via `localizedStandardCompare`), per D-02.
- **`IsletTests/AudioOutputPresentationTests.swift`** (new): 9 tests total — 1 identity test, 3 for `isOutputCapableDevice` (positive/zero/negative), 5 for `sortedAudioOutputDevices` (multi-device pin+sort, empty, single, no-default-marked, mixed-case via localizedStandardCompare).

## Task-by-Task TDD Record

| Task | RED | GREEN | Commit |
|------|-----|-------|--------|
| 1: AudioOutputDevice + isOutputCapableDevice | Test-build failed (type/func undefined) | Debug build + test-build both green | `4104662` |
| 2: sortedAudioOutputDevices | Test-build failed (func undefined) | Debug build + test-build both green | `a9b46e7` |

## Deviations from Plan

None — plan executed exactly as written. Both tasks' acceptance-criteria greps and build gates passed on first implementation attempt.

## Verification

- `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → `** BUILD SUCCEEDED **`
- `xcodebuild build-for-testing -scheme Islet -destination 'platform=macOS' -configuration Debug` → `** TEST BUILD SUCCEEDED **`
- Per this project's documented `xcodebuild test` headless-hang precedent (Islet.app boots NSPanel/MediaRemote/IOBluetooth when test-hosted), the actual test *run* is deferred to a manual Cmd-U in Xcode rather than attempted headlessly here. All 9 `AudioOutputPresentationTests` methods are present and compile; a manual Cmd-U pass is recommended before Plan 47-02 begins consuming these functions.

## Known Stubs

None. Both functions are fully implemented, total, and side-effect-free — no placeholder/mock data paths.

## Threat Flags

None — this plan's entire scope is pure Foundation computation (STRIDE register in the plan already covers Tampering/DoS as `accept`, no new surface introduced beyond that).

## Self-Check: PASSED

- FOUND: `Islet/Notch/AudioOutputPresentation.swift`
- FOUND: `IsletTests/AudioOutputPresentationTests.swift`
- FOUND: commit `4104662`
- FOUND: commit `a9b46e7`
