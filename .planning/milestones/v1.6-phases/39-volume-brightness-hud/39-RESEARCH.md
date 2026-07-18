# Phase 39: Volume & Brightness HUD - Research

**Researched:** 2026-07-17
**Domain:** Private/undocumented macOS system-HUD suppression (CGEventTap on NX_SYSDEFINED) + private-framework level reading (CoreAudio, DisplayServices) integrated into Islet's existing `IslandResolver`/`TransientQueue` arbiter
**Confidence:** MEDIUM-HIGH — grounded in this project's own working `DropInterceptTap.swift` CGEventTap precedent (confirmed on-device), the reference app Droppy's actual shipping source (fetched live 2026-07-17), and Apple's documented `CGEvent.tapCreate` permission model. LOW confidence specifically on the exact NX_SYSDEFINED bit-decode constants (undocumented private header, community-sourced) and on one open architectural question (see Open Questions).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Level-Indicator Visual Style**
- D-01: Both HUDs use the Droppy-style filled-bar layout from the user's own reference screenshot (`reference-droppy-volume-charging-pills.png`, saved during Phase 36): icon on the LEFT wing, a horizontal filled progress bar on the RIGHT wing. No numeric percentage text anywhere. Deliberate divergence from Phase 36's icon+label convention.
- D-02: Bar color is FIXED, not accent-tinted: Volume bar = green, Brightness bar = orange/yellow. Icon is also fixed white/system color (never accent-tinted).
- D-03: Volume HUD swaps `speaker.wave.fill`-class icon to `speaker.slash.fill` when muted (0% or hardware mute), with the bar fully drained.
- D-04: The bar fill animates with a spring (not an instant snap) when the level changes.

**Accessibility Permission UX**
- D-05: OSD suppression sits behind ONE Settings toggle, OFF by default — mirrors Focus Mode's D-01 exactly.
- D-06: Showing the HUD itself does NOT require Accessibility — only actively SUPPRESSING the native OSD does. If the toggle is on but Accessibility is denied/never granted, the HUD still shows, alongside the native system OSD.
- D-07: If Accessibility is granted later while Islet is already running with the toggle on, suppression must start automatically — no relaunch, no re-toggling. Reuse `DropInterceptTap`'s existing 5s health-check-timer pattern.
- D-08: The Settings toggle includes an explanation + a deep-link to System Settings → Privacy & Security → Accessibility via the `x-apple.systempreferences:` URL scheme when switched on — same pattern as Focus Mode's Full-Disk-Access deep-link (D-03 in `38-CONTEXT.md`). **Research finding: that deep-link pattern was never actually implemented in Phase 38 — see this document's Assumptions Log note.**

**Scrubbing & Auto-Dismiss Timing**
- D-09: Unlike `TransientQueue.updateHead()`'s existing behavior for Charging's % ticks (updates in place WITHOUT re-arming the dismiss timer), Volume/Brightness's dismiss timer MUST reset on every key press. Requires a new `updateHead` variant or an additional parameter — planner's call.
- D-10: Volume/Brightness use their own shorter auto-dismiss duration — **1.5 seconds** — not the shared 3s `activityDuration` constant.
- D-11: Volume/Brightness are scoped **collapsed-pill-only**, same as Focus (Phase 38 D-07) — NOT a full expanded-island takeover.

**Volume↔Brightness↔Focus Priority**
- D-12: Volume and Brightness instantly replace each other (cross-category, not same-category) — pressing Brightness while Volume's HUD is showing immediately swaps to Brightness, does NOT queue behind Volume. Both categories should be modeled so this falls out naturally (e.g., as sub-cases of one shared `ActiveTransient` case).
- D-13: Rank order: Charging (1) → Device (2) → Focus (3) → Volume/Brightness (4, new, shared rank). Since Focus is `isPersistent`, Volume/Brightness must use `TransientQueue.preempt()` against a standing Focus head too, briefly interrupting Focus's pill for their ~1.5s duration.

### Claude's Discretion
- Whether Volume and Brightness are modeled as one shared `ActiveTransient` case with an inner enum (e.g., `.osd(OSDActivity)`) or as two separate cases.
- Exact mechanism for reading the live system volume/brightness LEVEL — this project has no existing CoreAudio/DisplayServices code to reuse; this research resolves this (see Standard Stack / Architecture Patterns).
- Naming of the new `VolumeActivity`/`BrightnessActivity` (or shared `OSDActivity`) types and the new Monitor/interceptor types.
- Whether the Settings toggle for OSD suppression lives in its own row or alongside Focus's existing permission-gated toggles.

### Deferred Ideas (OUT OF SCOPE)
None raised during discussion — stayed within phase scope throughout.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HUD-03 | A Volume HUD appears on volume key press showing the live level in the Droppy-pill style, and suppresses the native system OSD when the spike confirms it's safe to do so (falls back to showing alongside the native OSD if suppression proves unreliable — do not ship `EnableSystemBanners` without confirming it doesn't regress on this project's own macOS Tahoe hardware) | Architecture Patterns (OSDInterceptor, resolver `.osd` case), Standard Stack (CoreAudio volume read), Common Pitfalls 1-4, Open Questions 1-2 |
| HUD-04 | A Brightness HUD mirrors HUD-03's behavior for brightness key presses, sharing its OSD-replacement subsystem | Architecture Patterns (shared `OSDInterceptor`/`OSDActivity`), Standard Stack (DisplayServices brightness read), Pattern 3 (BrightnessReader) |
</phase_requirements>

## Summary

This phase adds two new collapsed-only HUD types (Volume, Brightness) sharing one OSD-suppression subsystem, modeled as new cases inside the existing `IslandResolver`/`TransientQueue` arbiter this project already uses for Charging/Device/Focus. The two hard technical problems are: (1) intercepting `NX_SYSDEFINED` volume/brightness key events via a **second** `CGEvent.tapCreate` (Islet already has exactly one working tap, `DropInterceptTap.swift`, whose permission/lifecycle pattern is directly reusable) and (2) reading the *live level* (not just the key press) via two different private/semi-private system APIs — `CoreAudio`/`AudioObjectPropertyAddress` for volume (public API, no special permission) and the private `DisplayServices.framework` for Apple Silicon internal-display brightness (loaded dynamically via `CFBundle`, same technique this project already uses for `MediaRemoteAdapter`-class fragile-surface isolation).

The riskiest single fact, confirmed by Droppy's own shipping source: `.cgAnnotatedSessionEventTap` breaks play/pause/next/previous system-wide on macOS Tahoe — this project's own `DropInterceptTap.swift` already independently arrived at `.cgSessionEventTap`, so the spike's job is narrower than starting from scratch — it needs to prove the *volume/brightness-specific* NX_SYSDEFINED decode-and-swallow logic doesn't regress the 4 transport keys, not re-litigate which tap variant to use. A second, previously-undocumented-in-this-project fact surfaced by this research: Droppy runs its media-key tap's run loop on a **dedicated background `DispatchQueue`**, not the main run loop `DropInterceptTap.swift` uses — this was Droppy's own fix for a "double HUD on M4 Macs" main-thread-contention bug, and the new interceptor should follow Droppy's pattern, not `DropInterceptTap`'s, on this one point.

**Primary recommendation:** Model Volume+Brightness as one `ActiveTransient.osd(OSDActivity)` case (inner enum `.volume`/`.brightness`) so `TransientQueue.updateHead`'s existing same-category-replace semantics give D-12's "instant mutual replace" for free with a 2-line addition; build a new `OSDInterceptor.swift` that mirrors `DropInterceptTap.swift`'s permission/health-check/lifecycle skeleton but runs its tap on a dedicated `DispatchQueue` (Droppy's fix) and use a `.listenOnly` fallback tap for HUD-only detection when Accessibility is denied (see Open Questions — this needs an explicit decision before planning locks the toggle's scope).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Volume/brightness key detection (NX_SYSDEFINED) | Backend (app process, system glue layer) | — | CGEventTap is a process-level OS hook; there is no "server" tier in this single-process macOS app |
| Native OSD suppression | Backend (system glue layer) | — | Consuming the event at the tap IS the suppression mechanism; nothing else can do this |
| Live volume level read | Backend (system glue layer, CoreAudio) | — | `AudioObjectPropertyAddress` is a public system API, isolated to one file per project convention |
| Live brightness level read | Backend (system glue layer, private framework) | — | `DisplayServices.framework` dynamic load, isolated to one file — the single most likely thing Apple changes in a future OS |
| Priority arbitration (which HUD wins) | Backend (pure `IslandResolver`/`TransientQueue`) | — | Framework-free pure reducer, unit-testable in ms — this project's established "one pure arbiter" principle |
| HUD rendering (bar, icon, spring fill) | Client (SwiftUI, `NotchPillView`) | — | Pure view layer, drives no animation/timing itself (D-08 convention already established) |
| Settings toggle + permission deep-link | Client (SwiftUI, `SettingsView`) | Backend (`ActivitySettings` shared keys) | Mirrors the existing Focus toggle exactly — `@AppStorage` in the view, key constant shared with the controller |

## Standard Stack

### Core
| API / Framework | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `CoreGraphics` `CGEvent.tapCreate` | Ships with macOS SDK | Intercept + optionally swallow `NX_SYSDEFINED` volume/brightness key events | Already the ONLY working technique for OSD suppression — no public API exists; this project already has one working tap (`DropInterceptTap.swift`) proving the exact permission/lifecycle pattern on this exact dev machine (macOS 26/Tahoe) `[VERIFIED: codebase]` |
| `AudioToolbox`/`CoreAudio` `AudioObjectGetPropertyData` | Ships with macOS SDK | Read live system output volume + mute state | Public, documented Apple API — no private-framework risk for the volume half of this phase `[CITED: developer.apple.com]` |
| `DisplayServices.framework` (private, `/System/Library/PrivateFrameworks/`) | Ships with macOS, unversioned | Read live internal-display brightness on Apple Silicon | The only known working brightness-read path on Apple Silicon internal displays — `CoreDisplay`'s public-facing brightness calls don't work there `[CITED: community reverse-engineering, corroborated by Droppy's shipping source]` |
| `ApplicationServices` `AXIsProcessTrustedWithOptions` | Ships with macOS SDK | Accessibility permission check/prompt | Identical call already used by `DropInterceptTap.swift` on this exact codebase `[VERIFIED: codebase]` |

### Supporting
| API | Purpose | When to Use |
|---------|---------|-------------|
| `CGRequestListenEventAccess()` / Input Monitoring TCC | Lower-friction permission for a `.listenOnly` (observe, not suppress) tap | Only if the planner adopts the dual-tap fallback strategy from Open Questions (HUD-only detection without Accessibility) |
| `CFBundleCreate`/`CFBundleGetFunctionPointerForName` | Dynamically load `DisplayServices.framework` at runtime | The correct, App-Store-incompatible-but-notarization-safe way to call an unlinked private framework — same class of technique as this project's own `MediaRemoteAdapter` isolation-behind-one-file discipline |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CoreDisplay_Display_GetUserBrightness` (public-facing CoreDisplay call) | `DisplayServicesGetBrightness` | CoreDisplay's brightness calls are confirmed broken on Apple Silicon per multiple community sources — DisplayServices is the only path that works on this project's Apple-Silicon-only v1 target, so there is no real alternative here, not a stylistic choice |
| `NSEvent.addGlobalMonitorForEvents(matching: .systemDefined)` | `CGEvent.tapCreate(.listenOnly, ...)` | NSEvent's global monitor is reported unreliable specifically for media/system-defined keys by multiple sources; a CGEventTap (even listen-only) is the dependable path |
| `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` | `VirtualMasterVolume` was renamed to `VirtualMainVolume` as of Xcode 13 — the project's Xcode 16+/macOS 26 SDK requires the new symbol name; using the old one will fail to compile or resolve |

**Installation:** No new package dependencies. Every API above is either a public Apple framework already linked (`CoreGraphics`, `AudioToolbox`, `ApplicationServices`) or a system-owned private framework loaded dynamically at runtime via `CFBundle` (no SPM/CocoaPods entry, no linking step, no `Embed & Sign`).

**Version verification:** Not applicable — no SPM packages added this phase (verified by inspecting `project.yml`; the only existing SPM dependency, `MediaRemoteAdapter`, is unrelated to this phase and untouched).

## Package Legitimacy Audit

**Not applicable.** This phase adds zero new external packages (no npm/PyPI/SPM/CocoaPods dependencies). All new surface area is Apple-owned system frameworks — public (`CoreAudio`) or private-but-system-signed (`DisplayServices.framework`, loaded dynamically, same Team ID as the OS, so no library-validation/entitlement gap of the kind this project already hit with the third-party-signed `MediaRemoteAdapter` framework — see `release-library-validation-crash` project memory). No `slopcheck`/registry verification is required.

## Architecture Patterns

### System Architecture Diagram

```
Hardware key press (F10/F11/F12-class volume/brightness keys)
        │
        ▼
   macOS WindowServer ──emits──▶ NX_SYSDEFINED (CGEventType.systemDefined, raw 14)
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│  OSDInterceptor (NEW — this phase)                         │
│  CGEvent.tapCreate(.cgSessionEventTap, .headInsertEventTap)│
│  running on a DEDICATED DispatchQueue (Droppy's double-HUD │
│  fix — NOT the main run loop DropInterceptTap.swift uses)  │
│                                                              │
│  decode NX_KEYTYPE_* from event.data1 (bit-shift) ──┐      │
│                                                        │      │
│  ┌── SOUND_UP/DOWN/MUTE, BRIGHTNESS_UP/DOWN ──────────┘      │
│  │        │                                                  │
│  │        ├─▶ if suppression armed (toggle ON + Accessibility│
│  │        │    granted + defaultTap alive): consume event    │
│  │        │    (return nil) → native OSDUIHelper never sees  │
│  │        │    it, no system HUD spawns                      │
│  │        │                                                  │
│  │        └─▶ else: pass event through unmodified            │
│  │             (native OSD still shows, per D-06 fallback)   │
│  │                                                            │
│  │        hop to main ──▶ read live level:                   │
│  │           volume  → AudioObjectGetPropertyData (CoreAudio)│
│  │           brightness → DisplayServicesGetBrightness       │
│  │                        (dynamically loaded private fw)    │
│  │                                                            │
│  └── PLAY/FAST/REWIND/PREVIOUS + everything else ────────────┼─▶ passed through
│       UNTOUCHED, never enters the suppress/pass decision       UNMODIFIED
└───────────────────────────────────────────────────────────┘
        │ onLevelChanged(OSDActivity) callback, already on main
        ▼
NotchWindowController.handleOSDChange(_:)
   if head == .focus → transientQueue.preempt(.osd(activity))   (D-13)
   else               → transientQueue.enqueue(.osd(activity))
   scheduleActivityDismiss(duration: osdActivityDuration)         (D-09/D-10, re-armed every press)
        │
        ▼
IslandResolver.resolve(...)  — pure reducer
   case .osd(let o) where !isExpanded: return .osd(o)             (D-11 collapsed-only, rank 4)
        │
        ▼
NotchPillView.osdWings(for:)  — Droppy bar-style wing (D-01/D-02/D-03/D-04)
```

### Recommended Project Structure
```
Islet/Notch/
├── OSDActivity.swift          # NEW — pure value + mapping, mirrors FocusActivity.swift
├── OSDInterceptor.swift       # NEW — CGEventTap glue, mirrors DropInterceptTap.swift shape
├── VolumeReader.swift         # NEW — thin CoreAudio glue, mirrors PowerSourceMonitor.swift's readCurrentPower()
├── BrightnessReader.swift     # NEW — thin DisplayServices glue, isolated per "one fragile surface, one file" convention
├── IslandResolver.swift       # EXTEND — ActiveTransient.osd case, IslandPresentation.osd case, resolve() branch, updateHead same-category match
├── NotchPillView.swift        # EXTEND — osdWings(for:) new wing content
├── NotchWindowController.swift# EXTEND — start/stop OSDInterceptor, handleOSDChange, dismiss-timer re-arm
└── ActivitySettings.swift     # EXTEND — osdSuppressionKey, permission status hint, deep-link URL
```

### Pattern 1: Second CGEventTap sharing this project's proven skeleton, on a dedicated queue

**What:** `OSDInterceptor` mirrors `DropInterceptTap.swift`'s `AXIsProcessTrustedWithOptions` → `CGEvent.tapCreate` → `CFMachPortCreateRunLoopSource` → 5s health-check-timer skeleton verbatim, with ONE structural change: the run loop source is added to a **dedicated background `DispatchQueue`'s** run loop, not `CFRunLoopGetMain()`.

**When to use:** Any time a second CGEventTap is added to this codebase — this is now the established pattern, not a one-off.

**Example:**
```swift
// Source: this project's own DropInterceptTap.swift (permission/health-check skeleton, VERIFIED)
// + Droppy/MediaKeyInterceptor.swift (dedicated-queue fix, CITED via WebFetch 2026-07-17)
final class OSDInterceptor {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private let tapQueue = DispatchQueue(label: "com.islet.osd-tap", qos: .userInteractive)
    private var tapRunLoop: CFRunLoop?

    func start() {
        guard machPort == nil else { return }
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,          // NEVER .cgAnnotatedSessionEventTap — Pitfall 1
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.systemDefined.rawValue), // raw value 14
            callback: { proxy, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<OSDInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }   // silent no-op on missing Accessibility — mirrors DropInterceptTap D-12
        machPort = tap
        tapQueue.async { [weak self] in
            guard let self else { return }
            self.tapRunLoop = CFRunLoopGetCurrent()
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(self.tapRunLoop, source, .commonModes)
            self.runLoopSource = source
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()   // keeps this dedicated queue's run loop alive
        }
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkHealthAndReinstallIfNeeded()
        }
    }
    // ... handle(), stop() mirror DropInterceptTap.swift's shape
}
```

### Pattern 2: NX_SYSDEFINED bit-decode + strict key-type allowlist

**What:** `event.data1`'s top 16 bits carry the key code; the byte below that carries down/up state. Every code EXCEPT the 5 volume/brightness codes must be passed through completely untouched, never entering the suppress-decision branch at all.

**When to use:** Inside `OSDInterceptor.handle(type:event:)`.

**Example:**
```swift
// Source: Droppy/MediaKeyInterceptor.swift (fetched 2026-07-17) + corroborated by
// gist.github.com/swillits, gist.github.com/alexkli, nhurden/MediaKeyTap — MEDIUM confidence,
// undocumented private header (IOLLEvent.h), multiple independent sources agree on these values.
private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    guard type.rawValue == 14 /* NX_SYSDEFINED */,
          let nsEvent = NSEvent(cgEvent: event),   // MUST happen on main (Caps Lock/TSM crash — Pitfall 1)
          nsEvent.subtype.rawValue == 8             // NX_SUBTYPE_AUX_CONTROL_BUTTONS
    else { return Unmanaged.passUnretained(event) }

    let data1 = nsEvent.data1
    let keyCode  = (data1 & 0xFFFF0000) >> 16
    let keyFlags = (data1 & 0x0000FFFF)
    let keyDown  = ((keyFlags & 0xFF00) >> 8) == 0x0A

    switch keyCode {
    case 0, 1, 7, 2, 3:   // SOUND_UP, SOUND_DOWN, MUTE, BRIGHTNESS_UP, BRIGHTNESS_DOWN
        guard keyDown, suppressionArmed else { return Unmanaged.passUnretained(event) }
        onKeyPress(keyCode)   // triggers the level-read + resolver enqueue, on main
        return nil            // SWALLOW — this is what suppresses the native OSD
    default:
        return Unmanaged.passUnretained(event)   // PLAY/FAST/REWIND/PREVIOUS + everything else: untouched
    }
}
```

### Pattern 3: Isolated level-reading glue (mirrors `PowerSourceMonitor.readCurrentPower()`)

**What:** Volume and brightness reads live in their own thin, single-purpose files, following this project's "one fragile system surface, one file" convention already applied to `NowPlayingMonitor`, `PowerSourceMonitor`, `FocusModeMonitor`.

**Example (volume, public API):**
```swift
// Source: developer.apple.com CoreAudio docs (CITED) + community example (WebSearch, verified against
// current symbol name — kAudioHardwareServiceDeviceProperty_VirtualMainVolume, renamed from
// VirtualMasterVolume as of Xcode 13; this project's SDK is Xcode 16+/macOS 26)
func readSystemVolume() -> (percent: Int, muted: Bool) {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var outputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return (0, false) }

    var volume = Float32(0)
    var volumeSize = UInt32(MemoryLayout<Float32>.size)
    var volAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    _ = AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &volumeSize, &volume)

    var muted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    _ = AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &muted)

    return (Int((volume * 100).rounded()), muted == 1)
}
```

**Example (brightness, private framework, dynamic load):**
```swift
// Source: Droppy/BrightnessManager.swift (fetched 2026-07-17, CITED) — DisplayServices is the
// ONLY confirmed-working brightness-read path on Apple Silicon internal displays; CoreDisplay's
// equivalent calls are confirmed broken there by multiple independent sources.
final class BrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightnessFn?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString)
        else { return }
        getBrightness = unsafeBitCast(ptr, to: GetBrightnessFn.self)
    }

    func readBrightness() -> Int? {
        guard let getBrightness else { return nil }   // silent-degrade — no HUD shown if the private symbol vanishes in a future OS
        var value: Float = 0
        guard getBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
        return Int((value * 100).rounded())
    }
}
```

### Anti-Patterns to Avoid
- **Running the second tap's run loop source on `CFRunLoopGetMain()`:** `DropInterceptTap.swift` does this and it's fine for a rare drag-drop event, but volume/brightness keys fire rapidly during scrubbing — Droppy's own history shows this causes a main-thread-contention "double HUD" bug. Use a dedicated `DispatchQueue` for this tap specifically.
- **Decoding `NSEvent(cgEvent:)` off the main thread:** confirmed Caps Lock/Text-Services-Manager crash (PITFALLS.md Pitfall 1, Droppy's own fix). Always construct the `NSEvent` on main (`DispatchQueue.main.sync` inside the C callback, or do the entire decode after hopping to main).
- **Routing transport keys through the same suppress/pass decision branch as volume/brightness:** even with correct code today, a future refactor that "simplifies" the switch into one shared path risks reintroducing the annotated-tap-class regression. Keep the transport-key `default:` case a hard, unconditional passthrough.
- **A naive re-enable-on-disable loop in the health-check timer:** must re-check `AXIsProcessTrusted()` (no-prompt query) before calling `start()` again — see Common Pitfalls below for why `DropInterceptTap`'s existing health check is insufficient as-is for this phase's D-07 requirement.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Volume/brightness key detection | A custom `NSEvent` local monitor or polling `IOHIDDevice` | `CGEvent.tapCreate` on `.cgSessionEventTap` | This project already proved this exact API/permission combination works via `DropInterceptTap.swift` — reuse the skeleton, don't reinvent |
| Live volume level | Parsing `osascript "output volume of (get volume settings)"` output | `AudioObjectGetPropertyData` (CoreAudio) | Public, synchronous, no subprocess spawn (Droppy itself only falls back to `osascript` when CoreAudio fails — treat that as a last-resort fallback, not the primary path) |
| Live brightness level | Reading `/Library/Preferences` plists or shelling to `brightness` CLI | `DisplayServicesGetBrightness` dynamic load | Direct in-process call, no subprocess/file-parsing fragility |
| Priority arbitration | A bespoke `if activeTransient == nil && volumeChanged { ... }` conditional in the view or controller | `IslandResolver`/`TransientQueue` (existing) | Pitfall 6 (PITFALLS.md) — every new HUD type enqueues through the resolver, no exceptions, this project has already paid the cost of getting this wrong once (pre-Phase-6 architecture) |

**Key insight:** Every piece of new surface area in this phase (event tap, CoreAudio read, DisplayServices read) already has a directly analogous, working precedent somewhere in this codebase or in Droppy's shipping source. The actual work is composition and isolation-per-fragile-surface discipline, not novel systems programming.

## Common Pitfalls

### Pitfall 1: `.cgAnnotatedSessionEventTap` breaks transport keys on this project's exact macOS version
*(Full detail already captured in `.planning/research/PITFALLS.md` Pitfall 1 — summarized here for planning convenience, not duplicated in full.)*
**What goes wrong:** Using the annotated tap variant intercepts play/pause/next/previous before they reach the media subsystem, breaking them system-wide.
**How to avoid:** `.cgSessionEventTap` only — this project's own `DropInterceptTap.swift` already independently converged on this for an unrelated feature, which is corroborating evidence this is the right choice on this exact machine, not just Droppy's say-so.
**Warning signs:** Media keys stop working anywhere on the system, not just in Islet, after this ships.

### Pitfall 2: `DropInterceptTap`'s existing health-check timer cannot satisfy D-07's "auto-start once Accessibility is granted later" requirement as-is
**What goes wrong:** `DropInterceptTap.checkHealthAndReinstallIfNeeded()` is `guard let machPort else { return }` — it only reinstalls a tap that was successfully created and later disabled. If `tapCreate` returned `nil` at `start()` time (Accessibility not yet granted), `machPort` stays `nil` forever, and this exact health-check body never attempts a fresh `start()`.
**Why it happens:** The existing pattern was built for Phase 24's drag-in feature, where Accessibility was expected to already be granted by the time the tap mattered (Pitfall C in that file's own comments is about a Release re-sign going silently inert, not about permission being granted mid-session for the first time).
**How to avoid:** `OSDInterceptor`'s health check must be written to ALSO attempt `start()` when `machPort == nil` and `AXIsProcessTrusted()` (the no-prompt query variant) now returns `true` — this is new logic, not a verbatim copy of `DropInterceptTap`'s check.
**Warning signs:** User grants Accessibility in System Settings while Islet is running with the toggle already on, but suppression never activates until the app is relaunched — directly contradicts D-07's locked requirement.

### Pitfall 3: Reading CoreAudio/DisplayServices properties synchronously inside the C tap callback risks WindowServer-adjacent contention during rapid scrubbing
**What goes wrong:** The tap callback fires on every single key repeat during scrubbing (potentially many times per second). If the level-read (`AudioObjectGetPropertyData`/`DisplayServicesGetBrightness`) runs synchronously inside the callback before returning, and that callback is on the dedicated tap queue (Pattern 1), the level-read itself is cheap and fine there — but if it's accidentally done via `DispatchQueue.main.sync` (blocking) rather than `.async`, and the main thread is itself busy re-rendering the spring animation from the PREVIOUS key press, this can back up the tap queue and delay event delivery, which is exactly the kind of contention Droppy's "double HUD" bug came from (though in their case it was `NSEvent(cgEvent:)` construction, not a property read).
**How to avoid:** Decode the key + swallow/pass decision synchronously on the tap queue (fast, no I/O); hop `DispatchQueue.main.async` (not `.sync`) to do the level-read + resolver enqueue, since the resolver/`@Published` mutation must happen on main anyway per this project's established convention.
**Warning signs:** Scrubbing feels laggy or the bar visibly stutters/skips values under rapid repeated presses — profile with Instruments during an on-device scrubbing test specifically.

### Pitfall 4: `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` will not resolve on this project's SDK
**What goes wrong:** Multiple older tutorials and StackOverflow answers use `VirtualMasterVolume`; this symbol was renamed to `VirtualMainVolume` as of Xcode 13 (Apple's broader Master→Main renaming pass). This project targets Xcode 16+/macOS 26 SDK.
**How to avoid:** Use `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` — verify by attempting to build; the old symbol name will either fail to resolve or trigger a deprecation warning depending on SDK version.
**Warning signs:** Build error "cannot find kAudioHardwareServiceDeviceProperty_VirtualMasterVolume in scope" if a stale reference/tutorial is copied verbatim.

## Code Examples

See Architecture Patterns section above (Patterns 1–3) for the full verified/cited code — all four canonical operations (tap creation, key-code decode, volume read, brightness read) are covered there with inline source attribution to avoid duplicating large code blocks in two places.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` | Xcode 13 (2021) | Old symbol name is stale in many still-circulating tutorials; must use the renamed constant on this project's SDK |
| `CoreDisplay_Display_GetUserBrightness`/`SetUserBrightness` (Intel-era brightness API) | `DisplayServicesGetBrightness`/`SetBrightness` | Apple Silicon transition (2020-21) | CoreDisplay's brightness calls don't function on Apple Silicon internal displays — irrelevant for this project's stated Apple-Silicon-only v1 scope, but important to not accidentally reach for the wrong/legacy API from an older tutorial |
| `nowplaying-cli`/direct `dlopen` of `MediaRemote.framework` | `mediaremote-adapter` bridge (already adopted, unrelated to this phase) | macOS 15.3/15.4 | Confirms this project's dev machine sits on the current side of a real, precedented "Apple broke a private-API surface" event — the same risk class this phase's own CGEventTap technique carries forward |

**Deprecated/outdated:**
- `.cgAnnotatedSessionEventTap` for this use case: never valid on this project's target OS (Tahoe) — confirmed regression, not merely discouraged style.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | NX_KEYTYPE_SOUND_UP=0, SOUND_DOWN=1, MUTE=7, BRIGHTNESS_UP=2, BRIGHTNESS_DOWN=3, and the bit-decode formula (`(data1 & 0xFFFF0000) >> 16` for keyCode, `((data1 & 0xFF00) >> 8) == 0x0A` for key-down) | Pattern 2 | If wrong, the interceptor silently fails to recognize volume/brightness keys (or misfires on the wrong key) — LOW actual risk because this is trivially verifiable on-device in the spike by logging every decoded `keyCode` while pressing each real key, before any suppression logic is written |
| A2 | `.listenOnly` CGEventTap requires Input Monitoring (not Accessibility) for NX_SYSDEFINED specifically, making a HUD-only fallback tap viable when Accessibility is denied | Open Questions #1 | If wrong (i.e., even `.listenOnly` requires Accessibility for this event type), D-06's "HUD shows without Accessibility" requirement cannot be satisfied via a second tap at all, and needs a different detection mechanism or a scope change to D-06 itself — HIGH risk, must be resolved by the spike before implementation, not assumed |
| A3 | `DisplayServices.framework`'s `DisplayServicesGetBrightness` symbol is stable/unchanged on macOS 26 (Tahoe) | Standard Stack, Pattern 3 | If the symbol was renamed/removed in Tahoe, brightness reading silently returns `nil` (the reader already degrades gracefully per its own design) — MEDIUM risk, verify via the spike's own on-device check, cheap to confirm (one `CFBundleGetFunctionPointerForName` call) |
| A4 | Requesting Accessibility for a SECOND `CGEvent.tapCreate` in the same process does not require a second/separate TCC prompt beyond what `DropInterceptTap` already triggers (Accessibility is granted per-app, not per-tap) | Common Pitfalls, Pattern 1 | LOW risk — this is how macOS's TCC model works for Accessibility (app-level grant), well-established, not really in question |

**Note on the CONTEXT.md D-08 deep-link precedent claim:** CONTEXT.md's D-08 says the Settings toggle's deep-link should follow "the same pattern as Focus Mode's Full-Disk-Access deep-link (D-03 in `38-CONTEXT.md`)." This research found that pattern **was never actually built** — Phase 38's on-device spike (38-01) found `INFocusStatusCenter` reached `.authorized` directly (Path A), so Focus Mode ships using `INFocusStatusCenter.requestAuthorization(completion:)` (a native completion-based API call, `SettingsView.swift:274`), not an `x-apple.systempreferences:` URL deep-link. **There is no existing deep-link code in this codebase to reuse.** This is not a blocker — Accessibility genuinely has no completion-based re-request API (unlike `INFocusStatusCenter`), so a real `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)` deep-link is actually the *correct* mechanism here, more so than it would have been for Focus — but the planner should know this is genuinely new code, not a copy-paste of an existing pattern.

## Open Questions

1. **Does the Settings toggle gate the ENTIRE feature (detection + HUD + suppression), or ONLY suppression?**
   - What we know: D-05 says "OSD suppression sits behind ONE Settings toggle... mirrors Focus Mode's D-01 exactly" (Focus's D-01 gated the whole feature). D-06 says "showing the HUD itself does NOT require Accessibility" and describes the HUD still showing when the toggle is ON but Accessibility is denied. HUD-03's own requirement text frames "HUD appears on key press" as the primary ask, with suppression as an additive risky bonus.
   - What's unclear: whether the HUD should appear on every volume/brightness key press **unconditionally** (toggle only controls whether suppression is additionally attempted), or whether the HUD is invisible whenever the toggle is OFF (toggle gates the whole feature, mirroring Focus exactly) — these are materially different amounts of new code (one always-on `.listenOnly` detection tap vs. one toggle-gated `.defaultTap`-or-nothing tap) and different permission-prompt UX (Input Monitoring shown to every user vs. only to users who opt in).
   - Recommendation: resolve explicitly before planning locks the toggle's wiring — this is a genuine product decision hiding inside what CONTEXT.md's decisions currently only partially specify. Given HUD-03's phrasing, the "always-on HUD via listenOnly + toggle-gated suppression via defaultTap" reading is more consistent with the requirement text, but needs explicit confirmation (via `/gsd:discuss-phase` follow-up or the planner's own discretion call, whichever this project's workflow prefers at this point).

2. **Does a `.listenOnly` tap on `.cgSessionEventTap` for `NX_SYSDEFINED` specifically require Input Monitoring, or does it fall through to Accessibility too?**
   - What we know: general Apple/community sources confirm `.listenOnly` triggers Input Monitoring while `.defaultTap` triggers Accessibility, as a rule for CGEventTap broadly.
   - What's unclear: whether this general rule holds specifically for the `.cgSessionEventTap` location + `NX_SYSDEFINED` event type combination on macOS 26/Tahoe — this project has zero direct on-device evidence for the listen-only case (its one existing tap, `DropInterceptTap`, only ever uses `.defaultTap`).
   - Recommendation: the phase's own spike (Success Criterion 1) should explicitly test BOTH tap variants on-device and record which permission dialog each one triggers, before the planner commits to the dual-tap architecture this research recommends.

3. **Should the muted-state check use `kAudioDevicePropertyMute` alone, or also treat volume-scalar 0 as "muted" for D-03's icon-swap?**
   - What we know: D-03 explicitly says "muted (0% or hardware mute)" — both conditions should trigger the icon swap.
   - What's unclear: nothing technical — this is a straightforward `muted || percent == 0` OR in the pure `OSDActivity` mapping function, flagged here only so the planner writes the test case for both trigger paths, not just one.
   - Recommendation: implement as `isMuted = hardwareMuted || percent == 0` in the pure mapping function (mirrors `focusActivity(from:)`'s total-function style), unit-test both branches.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `CoreAudio`/`AudioToolbox` framework | Volume level read | ✓ | Ships with macOS SDK | — |
| `/System/Library/PrivateFrameworks/DisplayServices.framework` | Brightness level read | ✓ (present on all current macOS, including Tahoe) | Unversioned, system-owned | If the symbol is missing/renamed in a future OS: `BrightnessReader.readBrightness()` already degrades to `nil` (no HUD shown for brightness only — Volume HUD unaffected, per the "isolate behind one file" discipline) |
| Accessibility permission (`AXIsProcessTrustedWithOptions`) | OSD suppression (`.defaultTap`) | Depends on user grant — NOT pre-granted on a fresh install | — | D-06's own explicit fallback: HUD shows alongside native OSD, no suppression |
| Input Monitoring permission (`CGRequestListenEventAccess`) | HUD-only detection tap (`.listenOnly`), IF the planner adopts the dual-tap architecture from Open Questions #1 | Depends on user grant | — | If denied and adopted as a hard requirement for HUD display: no HUD at all for that key category — needs an explicit product decision, see Open Questions #1 |

**Missing dependencies with no fallback:** None — every dependency above has a documented graceful-degrade path already required by the locked decisions (D-06).

**Missing dependencies with fallback:** Accessibility (falls back to HUD-without-suppression per D-06); DisplayServices symbol resolution (falls back to no-brightness-HUD, isolated per-file).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target |
| Config file | `Islet.xcodeproj/xcshareddata/xcschemes/Islet.xcscheme` (generated by `project.yml` via XcodeGen) |
| Quick run command | `xcodebuild build -scheme Islet -destination 'platform=macOS'` |
| Full suite command | Manual Cmd-U in Xcode — **`xcodebuild test` is known to hang** on this project because the test host boots the full `Islet.app` (NSPanel/MediaRemote/IOBluetooth all initialize), per this project's own recorded memory (`xcodebuild-test-headless-hang`). Do not add `xcodebuild test` as an automated gate for this phase's plans. |

### Phase Requirement → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HUD-03/HUD-04 (resolver rank/preempt/collapsed-only) | `.osd` case wins collapsed, falls through expanded, preempts Focus, is not persistent, `updateHead` same-category-replace | unit | `xcodebuild build -scheme Islet` (build-only gate; run new `IslandResolverTests` cases via manual Cmd-U) | ❌ Wave 0 — new test cases needed in `IsletTests/IslandResolverTests.swift`, mirroring the existing `testFocus*`/`testPreemptPushesFocusToFrontOfPending` block (lines 619–665) |
| D-03 (muted icon-swap logic) | `OSDActivity`'s pure mapping treats `muted \|\| percent == 0` as the muted state | unit | same as above | ❌ Wave 0 — new `OSDActivityTests.swift` (or a section in an existing pure-value test file), mirroring `FocusActivity`'s total-function test style |
| CGEventTap suppression / transport-key passthrough | All 4 media transport keys + volume/brightness keys behave correctly | manual-only | N/A — cannot be automated (real hardware key events, real system OSD) | manual-only, justified: this is exactly Success Criterion 1's own on-device spike |
| D-07 (auto-start suppression once Accessibility granted mid-session) | health-check timer attempts a fresh `start()` when `machPort == nil` and permission is now granted | manual-only | N/A — requires live System Settings interaction | manual-only, justified: TCC permission state cannot be simulated in XCTest |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **Per wave merge:** same build command + manual Cmd-U for the new pure-logic unit tests
- **Phase gate:** build green + the Success Criterion 1 on-device spike explicitly confirmed (all 4 transport keys + volume/brightness keys tested manually) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] New test cases in `IsletTests/IslandResolverTests.swift` covering: `.osd` resolves collapsed-only (mirrors `testFocusWinsWhenCollapsed`/`testFocusFallsThroughWhenExpanded`), `.osd` is NOT persistent, `.osd` preempts a standing Focus head, `TransientQueue.updateHead` replaces `.osd(.volume)` with `.osd(.brightness)` instantly (D-12's core mechanism)
- [ ] New `OSDActivity.swift` + its pure-mapping test coverage (mirrors `FocusActivity.swift`'s shape)
- [ ] No framework install needed — `IsletTests` target already exists and builds

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not applicable — single-user local macOS app, no auth surface touched by this phase |
| V3 Session Management | no | Not applicable |
| V4 Access Control | yes | macOS TCC (Accessibility, and possibly Input Monitoring per Open Questions) IS this phase's access-control boundary — gated correctly per D-06's degrade-on-denial requirement, never silently bypassed |
| V5 Input Validation | yes | Every value read from `AudioObjectGetPropertyData`/`DisplayServicesGetBrightness` must be clamped (0...100) before rendering — mirrors `PowerSourceMonitor`'s existing `d[kIOPSCurrentCapacityKey] as? Int ?? 0` defensive-optional-cast convention; a malformed/out-of-range read must never force-unwrap or crash |
| V6 Cryptography | no | Not applicable — no new crypto surface |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A revoked Accessibility grant mid-session causes the tap-disabled callback to fight the system in a re-enable loop | Denial of Service (against the user's own WindowServer responsiveness) | Check `AXIsProcessTrusted()` before any re-enable attempt; stop the interceptor entirely if permission was revoked — this is Droppy's own documented fix for exactly this bug, and PITFALLS.md's Security Mistakes table already flags it project-wide |
| Consuming a key event for a device the app cannot actually control (e.g. a USB audio interface with no software volume path) | Denial of Service (user's own volume keys become dead) | Check `supportsVolumeControl`/an equivalent capability probe before swallowing the event — PITFALLS.md's existing UX Pitfalls table already names this exact scenario |
| Private-framework symbol resolution failing silently and being misread as "brightness is 0" rather than "read failed" | Tampering (of displayed state, not actual security, but a real correctness bug) | `BrightnessReader.readBrightness()` returns `Int?`, not a bare `Int` defaulted to 0 — a failed read must suppress the Brightness HUD entirely, never render a false "0%" |

## Sources

### Primary (HIGH confidence)
- `Islet/Notch/DropInterceptTap.swift` (this codebase) — the exact `.cgSessionEventTap`/`AXIsProcessTrustedWithOptions`/health-check-timer pattern, confirmed working on-device (24-03-SUMMARY.md)
- `Islet/Notch/IslandResolver.swift`, `Islet/Notch/FocusActivity.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/NotchPillView.swift` (this codebase) — the exact resolver/queue/wing/monitor patterns this phase extends
- `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift` (this codebase) — the exact toggle/permission-hint/`@AppStorage` pattern to mirror, and confirmation that Phase 38's deep-link precedent claim in CONTEXT.md D-08 does not actually exist in the codebase (Path A/`INFocusStatusCenter.requestAuthorization` was used instead)
- `.planning/research/PITFALLS.md` (this project) — Pitfall 1, Integration Gotchas, Security Mistakes tables — the authoritative prior research this phase's CONTEXT.md explicitly directs readers to
- Apple Developer Forums thread 122492, HackTricks macOS Input Monitoring/Accessibility page — CGEventTap `.listenOnly` (Input Monitoring) vs `.defaultTap` (Accessibility) permission distinction

### Secondary (MEDIUM confidence)
- `github.com/1of1Adam/Droppy` `MediaKeyInterceptor.swift`, `VolumeManager.swift`, `BrightnessManager.swift` (fetched live via WebFetch, 2026-07-17) — dedicated-DispatchQueue double-HUD fix, NX_KEYTYPE_* constant values, CoreAudio VirtualMainVolume read/write/fallback chain, DisplayServices dynamic-load pattern via `CFBundle`
- Apple Developer Documentation — `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume`/`VirtualMainVolume` rename (Xcode 13)
- Community reverse-engineering sources (alexdelorenzo.dev, nriley/brightness) — CoreDisplay-vs-DisplayServices split on Apple Silicon, corroborated independently by Droppy's own source choosing DisplayServices

### Tertiary (LOW confidence)
- `gist.github.com/swillits`, `gist.github.com/alexkli`, `nhurden/MediaKeyTap` — NX_SYSDEFINED bit-decode formula (`data1` shift/mask for keyCode/keyState) — undocumented private header (`IOLLEvent.h`), community-sourced only, but multiple independent sources agree on the same values, and the spike is designed to verify this on-device before any suppression logic depends on it (see Assumptions Log A1)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API has either a working in-codebase precedent or a public Apple doc reference
- Architecture: HIGH — the resolver/queue extension shape is directly analogous to Phase 38's already-shipped Focus Mode precedent
- Pitfalls: MEDIUM-HIGH — the tap-variant/transport-key regression is HIGH confidence (project's own precedent + Droppy's shipping source agree); the exact bit-decode constants are MEDIUM (community-sourced, spike-verifiable); the toggle-scope question (Open Questions #1/#2) is a genuine unresolved product/technical question, not just a confidence gap

**Research date:** 2026-07-17
**Valid until:** 30 days (stable Apple-framework surface; the private DisplayServices/CGEventTap techniques carry the usual "any macOS point release could change this" caveat already flagged throughout — re-verify immediately if a macOS update ships before implementation starts)
