---
phase: 47-audio-output-switcher-pure-seam-monitor
reviewed: 2026-07-19T22:48:06Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Islet/Notch/AudioOutputMonitor.swift
  - Islet/Notch/AudioOutputPresentation.swift
  - IsletTests/AudioOutputMonitorManualSpike.swift
  - IsletTests/AudioOutputPresentationTests.swift
findings:
  critical: 0
  warning: 4
  info: 1
  total: 5
status: issues_found
---

# Phase 47: Code Review Report

**Reviewed:** 2026-07-19T22:48:06Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the pure presentation seam (`AudioOutputPresentation.swift`), the CoreAudio glue
(`AudioOutputMonitor.swift`), and both associated test files. `resolveDeviceID(uid:)` was
reviewed fresh: the qualifier-data calling convention for
`kAudioHardwarePropertyTranslateUIDToDevice` (pointer-to-`CFString` passed as qualifier data,
sized via `MemoryLayout<CFString>.size`, output sized via `MemoryLayout<AudioDeviceID>.size`)
matches Apple's documented modern pattern and is correct on its own merits — no issue found
there. `AudioOutputPresentation.swift` is small, total, and its test coverage
(`AudioOutputPresentationTests.swift`) is solid.

The remaining issues are concentrated in `AudioOutputMonitor.swift`: an unsynchronized
`nonisolated(unsafe)` mutable-state pair shared between an actor-isolated `start()` and a
`nonisolated stop()`, ignored `OSStatus` returns from listener (de)registration, and a
CoreAudio CFString-ownership leak in the two device-metadata readers. None of these rise to
Critical (no crash reproduced, no security/data-loss vector), but the CFString leak and the
race are worth fixing before this ships as a long-lived monitor that gets started/stopped
repeatedly. The manual spike test also relies on a comment rather than a runtime guard to
avoid hanging an automated `xcodebuild test` run.

## Warnings

### WR-01: `running`/`listenerBlock` are unsynchronized between actor-isolated `start()` and `nonisolated stop()`

**File:** `Islet/Notch/AudioOutputMonitor.swift:16-21,65-81`
**Issue:** `running` and `listenerBlock` are declared `nonisolated(unsafe)`, which opts them
out of Swift's actor-isolation checking rather than proving they're safe. `start()` runs
`@MainActor` and mutates both properties; `stop()` is explicitly `nonisolated` ("so a future
owner's nonisolated deinit can call it") and mutates the same two properties with no lock or
actor hop. If `stop()` is ever invoked from a background thread (e.g., from a `deinit`, which
is the stated purpose of making it `nonisolated`) while `start()` is mid-execution on the main
actor, both properties can be read/written concurrently from two threads — a genuine data race
on the stored `AudioObjectPropertyListenerBlock?`, not just a theoretical one, since the whole
point of `nonisolated(unsafe)` here is to allow exactly that cross-thread call pattern.
**Fix:** Either isolate `stop()`'s state mutation with a lock (e.g., `os_unfair_lock` or
`NSLock` around the read/clear of `listenerBlock`/`running`), or keep `stop()` `nonisolated`
but hop back to main before touching state:
```swift
nonisolated func stop() {
    Task { @MainActor in
        self.stopOnMain()
    }
}
```
If a synchronous nonisolated teardown is truly required (e.g., for a nonisolated `deinit`),
guard the shared state with an explicit lock instead of relying on `nonisolated(unsafe)` alone.

### WR-02: `OSStatus` from listener (de)registration is silently discarded

**File:** `Islet/Notch/AudioOutputMonitor.swift:49,55,71,77`
**Issue:** `AudioObjectAddPropertyListenerBlock` and `AudioObjectRemovePropertyListenerBlock`
both return `OSStatus`, and all four call sites discard it. If registration fails (e.g., the
system object rejects the listener for some environment-specific reason), `running` is still
set to `true` and callers get no signal that they will never receive future device-change
callbacks — they'll only ever see the single synchronous `onDevicesChanged(currentDevices())`
snapshot at the end of `start()`. Every other CoreAudio call in this file (`AudioObjectGetPropertyData`,
`AudioObjectSetPropertyData`, `AudioObjectGetPropertyDataSize`) is guarded with `== noErr`;
these four are the only unchecked calls in the file.
**Fix:**
```swift
let addStatus = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, nil, block)
assert(addStatus == noErr, "failed to register devices listener: \(addStatus)")
```
At minimum, log on non-`noErr` so a registration failure isn't silent.

### WR-03: `deviceUID(for:)` / `deviceName(for:)` leak the returned `CFString`

**File:** `Islet/Notch/AudioOutputMonitor.swift:197-207,209-219`
**Issue:** For CF-typed properties (`kAudioDevicePropertyDeviceUID`, `kAudioObjectPropertyName`),
`AudioObjectGetPropertyData` follows CoreAudio's "Copy Rule": the caller receives an owned
(+1 retained) `CFStringRef` and is responsible for releasing it. Here, `var uid: CFString = ""
as CFString` is overwritten by a raw memory write through `&uid` (the `outData` pointer) —
this bypasses Swift's normal assignment/ARC bookkeeping for the *new* value, so the retained
reference CoreAudio hands back is never balanced with a `CFRelease`/`Unmanaged.release()`.
`currentDevices()` calls both of these for every enumerated device on every devices-changed
and default-output-changed event, so this leaks a `CFString` retain per device per event over
the monitor's lifetime.
**Fix:** Bridge through `Unmanaged` and release explicitly:
```swift
private func deviceUID(for deviceID: AudioDeviceID) -> String? {
    var unmanagedUID: Unmanaged<CFString>?
    var uidSize = UInt32(MemoryLayout<CFString?>.size)
    var uidAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &uidSize, &unmanagedUID) == noErr,
          let unmanagedUID
    else { return nil }
    defer { unmanagedUID.release() }
    return unmanagedUID.takeUnretainedValue() as String
}
```
Apply the same pattern to `deviceName(for:)`.

### WR-04: Manual spike test has no runtime guard against automated execution

**File:** `IsletTests/AudioOutputMonitorManualSpike.swift:8-41`
**Issue:** The header comment warns "MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test`", but
nothing in the test enforces that — `testManualDeviceEnumerationAndSwitch()` blocks the run
loop for a fixed 60 seconds (`15` + `45`) and will execute like any other test if the
`IsletTests` target is run as a whole (locally or in CI). A comment is not load-bearing;
anyone (or any CI config) that runs the full test target will hang for a minute waiting on
console-only pass/fail criteria, with no way to detect the intent from the test result itself.
**Fix:** Add a runtime skip so only an explicit opt-in runs it:
```swift
override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_MANUAL_AUDIO_SPIKE"] != nil,
                       "Manual spike — run via Xcode Cmd-U with RUN_MANUAL_AUDIO_SPIKE=1 set, see 47-03-PLAN.md Task 2")
}
```

## Info

### IN-01: Inconsistent "unknown device" sentinel between `resolveDeviceID` and `defaultOutputDeviceID`

**File:** `Islet/Notch/AudioOutputMonitor.swift:87,155`
**Issue:** `resolveDeviceID` initializes with the named constant `AudioDeviceID(kAudioObjectUnknown)`,
while `defaultOutputDeviceID` initializes with the literal `AudioDeviceID(0)`. They're
numerically equivalent (`kAudioObjectUnknown == 0`), so this isn't a bug, but the
inconsistency makes it easy to miss during future edits that the two are meant to represent
the same "no device" sentinel.
**Fix:** Use `AudioDeviceID(kAudioObjectUnknown)` in `defaultOutputDeviceID` too for
consistency (this is a one-token change; low priority).

---

_Reviewed: 2026-07-19T22:48:06Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
