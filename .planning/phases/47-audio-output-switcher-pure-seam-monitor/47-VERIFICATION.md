---
phase: 47-audio-output-switcher-pure-seam-monitor
verified: 2026-07-19T22:58:30Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 47: Audio Output Switcher — Pure Seam + Monitor Verification Report

**Phase Goal:** The pure device-list/sort logic and the event-driven CoreAudio monitor exist and are proven correct in isolation — public, documented API, same risk tier as the already-shipped VolumeReader/BrightnessReader and BluetoothMonitor — safe to build and fully de-risk before any UI is wired to it.

**Verified:** 2026-07-19T22:58:30Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `AudioOutputPresentation.swift`'s device value type + sort/reorder logic are pure, unit-tested, Foundation-only, zero AppKit/SwiftUI/CoreAudio | ✓ VERIFIED | `Islet/Notch/AudioOutputPresentation.swift` imports only `Foundation` (grep for `^import CoreAudio\|^import AppKit\|^import SwiftUI` → 0 matches). `AudioOutputDevice` is `Equatable, Identifiable` with `id` derived from `uid`. `isOutputCapableDevice` and `sortedAudioOutputDevices` are total functions. `IsletTests/AudioOutputPresentationTests.swift` has 9 tests covering identity, classify (positive/zero/negative), and sort (multi/empty/single/no-default/mixed-case). |
| 2 | `AudioOutputMonitor` enumerates real system audio-output devices, keyed by `kAudioDevicePropertyDeviceUID` (never `AudioDeviceID`), and reflects live connect/disconnect/default-output changes via `AudioObjectAddPropertyListener` | ✓ VERIFIED | `Islet/Notch/AudioOutputMonitor.swift` `currentDevices()` reads `kAudioDevicePropertyDeviceUID` per device, skips devices whose UID can't be resolved, and never uses `AudioDeviceID` as the stored identity (`AudioOutputDevice.uid` is the only identity field written). `start()` registers `AudioObjectAddPropertyListenerBlock` for both `kAudioHardwarePropertyDevices` and `kAudioHardwarePropertyDefaultOutputDevice`. On-device round (47-03-SUMMARY.md) confirms live Bluetooth connect/disconnect and default-output-change events are reflected, and UID is stable across a full disconnect+reconnect cycle (Jabra `uid=50-C2-75-65-8A-A4:output` identical both times). |
| 3 | Every CoreAudio callback-driven state update hops to main before touching `@Published`/stored state (mirrors BluetoothMonitor) | ✓ VERIFIED | The single `AudioObjectPropertyListenerBlock` registered for both selectors immediately wraps its body in `DispatchQueue.main.async { [weak self] in ... self.onDevicesChanged(self.currentDevices()) }` before touching any state or invoking the closure — matches `BluetoothMonitor`'s pattern. `grep -c "DispatchQueue.main.async"` → 2 occurrences (one in the shared listener block; `setDefaultOutput`'s confirm-after-set additionally uses `.main.asyncAfter`). On-device run reports no main-thread-checker purple warnings across two ~60s runs. |
| 4 | Per-device volume-property support (`kAudioDevicePropertyVolumeScalar`/`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`) verified against the dev machine's real Bluetooth headset, not just built-in speakers | ✓ VERIFIED | `hasVolumeControl(deviceUID:)` guards `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` via `AudioObjectHasProperty`, falling back to per-channel `kAudioDevicePropertyVolumeScalar`, never force-unwrapping. A real bug (deprecated `AudioValueTranslation` calling convention in `resolveDeviceID`, always returning `nil`) was found and fixed on-device (commit `f6e9613`) — current file uses the qualifier-data pattern (`inQualifierData`/`inQualifierDataSize`), confirmed present in the read source. Post-fix on-device results (47-03-SUMMARY.md): built-in speakers=true, Jabra Elite 8 Active (Bluetooth)=true, Elgato Wave XLR Pro (USB)=true, HP 25x (external monitor, non-Bluetooth)=false — differentiated results across device kinds, not a constant. Scope note: only 1 of 2 requested distinct Bluetooth devices was available and tested; this is a user-confirmed, accepted scope limitation (documented in 47-03-SUMMARY.md), not a fabricated pass. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/AudioOutputPresentation.swift` | Pure Foundation-only device value type + D-01 classify + D-02 sort | ✓ VERIFIED | Exists, Foundation-only, contains `struct AudioOutputDevice`, `isOutputCapableDevice`, `sortedAudioOutputDevices`. |
| `IsletTests/AudioOutputPresentationTests.swift` | Unit coverage for classify + sort | ✓ VERIFIED | 9 test methods; `xcodebuild build-for-testing` succeeds (`** TEST BUILD SUCCEEDED **`). |
| `Islet/Notch/AudioOutputMonitor.swift` | Event-driven CoreAudio monitor mirroring BluetoothMonitor's shape | ✓ VERIFIED | `@MainActor final class AudioOutputMonitor` with idempotent `start()`, full-teardown `nonisolated stop()`, `setDefaultOutput`, `hasVolumeControl`. Zero references to `BluetoothMonitor` (grep → 0). `VolumeReader.swift` unmodified since Phase 39 (last commit touching it is `15d5fc1`, predates Phase 47). |
| `IsletTests/AudioOutputMonitorManualSpike.swift` | Manual on-device verification harness | ✓ VERIFIED | Contains `MANUAL SPIKE` header, `AudioOutputMonitorManualSpike: XCTestCase`, calls `monitor.start()`, `monitor.setDefaultOutput(`, `monitor.stop()`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `AudioOutputMonitor.currentDevices()` | `isOutputCapableDevice`/`sortedAudioOutputDevices` | direct function call | ✓ WIRED | `currentDevices()` calls `isOutputCapableDevice(outputChannelCount:)` per device and returns `sortedAudioOutputDevices(devices)`. |
| `AudioOutputMonitor` listener callback | `onDevicesChanged` closure | `DispatchQueue.main.async` hop | ✓ WIRED | Confirmed present before every state touch/closure invocation. |
| `AudioOutputMonitorManualSpike` | `AudioOutputMonitor.start()/setDefaultOutput()/hasVolumeControl()/stop()` | direct instantiation + calls | ✓ WIRED | All four methods called in the spike; on-device run executed and results recorded in 47-03-SUMMARY.md. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build green | `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Test target compiles | `xcodebuild build-for-testing -scheme Islet -destination 'platform=macOS' -configuration Debug` | `** TEST BUILD SUCCEEDED **` | ✓ PASS |
| All 47-01/47-02/47-03 acceptance-criteria greps | re-run independently in this verification (24 grep checks across both files) | all matched expected counts | ✓ PASS |
| Real-hardware CoreAudio behavior (enumeration, UID stability, confirm-after-set, hasVolumeControl differentiation) | not independently re-runnable by this verifier (requires physical Bluetooth/USB hardware in a live Xcode Cmd-U session) | N/A | ? SKIP — see Human Verification note below |

### Requirements Coverage

No formal requirement IDs are scoped to Phase 47 per `.planning/REQUIREMENTS.md` line 152 ("Phase 47 ... carry no formal REQ-ID ... infrastructure phase preceding Phase 48's user-facing requirements"). This matches the phase's own PLAN frontmatter (`requirements: [D-01, D-02]`, `[D-01, D-03]`, `[D-03]` — these are phase-local decision IDs from `47-CONTEXT.md`, not entries in the global REQUIREMENTS.md traceability table). `OUTPUT-01..04` are confirmed still mapped to Phase 48 (Pending), not this phase — no orphaned requirements found for Phase 47.

### Anti-Patterns Found

None. Scanned all 4 phase-modified files (`AudioOutputPresentation.swift`, `AudioOutputMonitor.swift`, `AudioOutputPresentationTests.swift`, `AudioOutputMonitorManualSpike.swift`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` (case-insensitive) — zero matches. No stub return patterns (`return null`, empty closures, hardcoded empty arrays flowing to output) found in the reviewed source.

### Human Verification Required

None required as a blocking gate — the on-device verification (Task 2 of 47-03, a `checkpoint:human-verify` gate) was already executed by the developer during phase execution, with results documented in `47-03-SUMMARY.md` and cross-referenced above (device UIDs, hasVolumeControl per device kind, confirm-after-set switch result). This verifier cannot re-run physical hardware tests (no Bluetooth/USB devices attachable from this session), but the recorded on-device evidence is specific, differentiated across device kinds (not a uniform pass), and internally consistent with the source code read directly from disk — including the mid-checkpoint bug (`f6e9613`) whose fix is confirmed present in the current file. No further human action is required for this phase to be considered goal-achieved.

### Gaps Summary

No gaps. All 4 ROADMAP Success Criteria are verified against actual source code (not just SUMMARY.md narrative): the pure seam is genuinely Foundation-only and unit-tested; the monitor genuinely enumerates devices via UID and wires up both required property listeners; every callback hops to main before touching state; and `hasVolumeControl` is genuinely guarded and was verified with differentiated (not uniform) results against real Bluetooth/USB/built-in/external-monitor hardware, including a real bug found and fixed mid-phase. The one accepted scope limitation (1 of 2 requested distinct Bluetooth devices tested for D-03) is explicitly user-confirmed and documented, not a silent gap — it does not block Phase 47's goal (a single differentiated Bluetooth `hasVolumeControl=true` result, contrasted with a real non-Bluetooth `false` result, is sufficient evidence that the guard genuinely discriminates rather than always returning a constant).

---

_Verified: 2026-07-19T22:58:30Z_
_Verifier: Claude (gsd-verifier)_
