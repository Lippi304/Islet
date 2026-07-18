# Project Research Summary

**Project:** Islet v1.7 — Interaction & Calendar Polish (Now Playing "favorite" write-back + audio-output switcher)
**Domain:** Native macOS notch-overlay utility (Dynamic Island clone) — two new Now Playing expanded-view capabilities, extending an existing shipped app
**Researched:** 2026-07-19
**Confidence:** MEDIUM overall (HIGH on codebase integration and CoreAudio public APIs; MEDIUM on Spotify Web API endpoint shapes and AppleScript `loved`/Automation reliability; genuinely unverified until spiked on real hardware)

## Executive Summary

This research covers two candidate additions to Islet's Now Playing expanded view: a "favorite/like" write-back to Spotify/Apple Music, and a live audio-output-device switcher with per-device volume. Both slot cleanly into Islet's existing architecture — the two reserved-but-empty 28x28 slots flanking the transport-control row (explicitly held open by decision D-09) are exactly where the star and speaker icons belong, and both features extend already-proven patterns (`NowPlayingMonitor`'s single-bridge isolation for favorite; a new `AudioOutputMonitor` mirroring `BluetoothMonitor`'s event-driven shape for the output switcher) rather than requiring any new architectural layer.

The two features carry very different risk profiles. The **audio-output switcher is low-risk**: everything it needs (`kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultOutputDevice`, `AudioObjectAddPropertyListener`) is public, documented CoreAudio, the same framework `VolumeReader.swift` already uses in production — the real work is disciplined engineering (key devices by stable `kAudioDevicePropertyDeviceUID` not the session-ephemeral `AudioDeviceID`, hop off CoreAudio's callback thread to main, guard `kAudioDevicePropertyVolumeScalar` per-device before wiring the slider, confirm a device-switch actually stuck by re-reading the property afterward). **The favorite/like feature is the single highest-risk item in the whole milestone.** Apple Music's AppleScript `loved` property is real but documented-broken for streaming (not-yet-in-library) tracks, and both platforms' Automation-permission (TCC) prompt has a known reliability bug. Spotify is worse: there is no AppleScript or MediaRemote command path to "like" a track at all — the only real mechanism is Spotify's Web API behind a full OAuth PKCE flow, and Spotify's 2025 policy change caps unapproved apps at 5 total allowlisted users (Development Mode), meaning a shared Islet Client ID likely cannot serve real paying customers without either an unlikely Extended Quota approval or a materially worse "bring your own Client ID" flow.

The recommended approach: build the low-risk, public-API output switcher first and treat it as a near-pure extension of Phase 39's CoreAudio work; isolate the favorite/like feature's two genuine unknowns (Apple Music's `current track` reliability, Spotify's OAuth/quota-mode reality, and whether the vendored `mediaremote-adapter` wrapper even exposes a like-command send) into a dedicated spike phase before any UI is built around them — mirroring this project's own established precedent (Phase 22 drag-in spike, Phase 38/39 undocumented-API spikes). If the Spotify spike confirms the quota wall is real and unacceptable, be prepared to explicitly descope Spotify to Apple-Music-only for this milestone rather than discovering it mid-implementation.

## Key Findings

### Recommended Stack

No new core stack — this extends the existing SwiftUI/AppKit/CoreAudio/mediaremote-adapter baseline. New additions are narrowly scoped and (aside from Spotify OAuth) require zero new dependencies — everything ships with the macOS SDK.

**Core additions:**
- **Spotify Web API (`PUT /me/library` / `GET /me/library/contains`, post Feb-2026 migration)** — the only way to write to a Spotify user's Liked Songs; Spotify's AppleScript dictionary has never had a save/like command.
- **`ASWebAuthenticationSession` + PKCE (no client secret)** — Apple's system-managed OAuth browser sheet; PKCE is mandatory since this is an unsandboxed, direct-distributed app where a baked-in client secret would be trivially extractable.
- **`NSAppleScript`** (already-precedented pattern) — sets Apple Music's `loved` property and reads Spotify's `id of current track` for a track URI; must run off-main and handle `errAEEventNotPermitted` (-1743).
- **CoreAudio (`AudioHardwareService*`/`AudioObject*` C API)** — device enumeration, default-output get/set, per-device volume via `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume`, live updates via `AudioObjectAddPropertyListenerBlock` — direct extension of the existing `VolumeReader.swift` surface, same framework already linked.
- **No third-party libraries** — `SimplyCoreAudio` was considered and rejected (archived/unmaintained since March 2024); the project's own "no dependency for a tiny native surface" precedent (IOKit, IOBluetooth) applies equally here.

### Expected Features

**Must have (table stakes):**
- Like/favorite button reflects real per-app state on load (not a fake local-only heart)
- Output panel shows the actual live system default output, highlighted, updating live as devices connect/disconnect or change elsewhere (System Settings, Control Center)
- Volume slider genuinely controls system output volume in real time
- Tapping a device in the output list immediately switches system audio — **tap-to-select, not drag-to-select** (zero precedent anywhere — macOS Control Center, iOS AirPlay picker, and SoundSource all use tap; drag-as-selection-trigger is an accidental-action risk)

**Should have (differentiators):**
- Apple Music like/love write-back via AppleScript — closes a real parity gap with the cited competitor Droppy, low-medium complexity, no network dependency
- Spotify like/save write-back via OAuth — a genuine differentiator since two named competitors (TheBoringNotch, Droppy) either have it broken or don't ship it at all, but materially higher complexity/risk
- Drag-to-promote as an *optional accelerator* layered on top of tap-to-select (never a replacement)

**Defer (v2+):**
- Persisted "recently used outputs" quick-toggle ordering — defer until the basic switcher is proven in daily use
- Full custom Apple MusicKit REST integration — unnecessary complexity for a same-Mac, same-user write; plain AppleScript suffices
- Fuzzy title/artist search to resolve Spotify track identity — false-positive risk (liking the wrong track); use the track URI directly instead

### Architecture Approach

Both features extend Islet's existing three-layer discipline (system glue -> pure presentation seam -> the one resolver) without adding a new layer. Favorite/like is 2-3 lines added to the *existing* `NowPlayingService`/`NowPlayingMonitor` protocol and `TrackSnapshot` (same fragile bridge, same isolation boundary — a second protocol would duplicate lifecycle code for zero added safety). The audio-output switcher needs a genuinely new file, `AudioOutputMonitor.swift`, because it needs a fundamentally different shape than the existing stateless, pull-based `VolumeReader` (a live device list + property listeners, mirroring `BluetoothMonitor`'s event-driven register/callback pattern) — but it does NOT need protocol isolation the way MediaRemote does, since CoreAudio is public, documented API. The output panel itself is local, controller-visible view state (a sibling `@Published` boolean on `IslandPresentationState`, not a new `IslandPresentation` resolver case) — it's a disclosure *within* Now Playing, not a competing top-level activity, and must stay visible to `NotchWindowController` for click-through hit-testing (the exact invariant the project's own CR-01 regression already broke once).

**Major components:**
1. `NowPlayingMonitor`/`NowPlayingService` (MODIFY) — gains `toggleFavorite()` + `isFavorite: Bool?` on the same persistent adapter channel as transport control
2. `AudioOutputMonitor` (NEW) — event-driven CoreAudio glue, mirrors `BluetoothMonitor`'s shape exactly
3. `AudioOutputPresentation.swift` (NEW) — pure seam, `AudioOutputDevice` value type + sort/reorder logic, unit-testable
4. `NotchWindowController` (MODIFY) — starts/stops the new monitor, wires the two reserved-slot buttons, extends the geometry-union + `visibleContentZone()` "three-site rule" already established for every prior taller-content addition (Tray, Weather, Quick Action Picker)
5. `NotchPillView.mediaExpanded` (MODIFY) — the two already-reserved `Color.clear(28x28)` slots (D-09) become real star/speaker buttons; new `outputPanel(...)` subview

### Critical Pitfalls

1. **Spotify has no scripting/private-API path to "like" a track, and its 2025 policy caps unapproved apps at 5 users** — spike a real OAuth PKCE round-trip + a real `PUT` call FIRST, and explicitly check current quota-mode criteria before committing to a shared-Client-ID design; be ready to descope to Apple-Music-only.
2. **Apple Music's `current track` AppleScript reference is documented-broken for streamed (not-yet-in-library) tracks** — don't build the star around `current track` untested; spike against a library track, a streaming-only track, and both play/pause states; wrap in try/catch with a distinct "couldn't verify" UI state.
3. **The Automation (Apple Events/TCC) permission prompt has a real, documented reliability bug** — it can silently fail to appear and the target app can vanish from System Settings -> Automation after idle periods; detect this failure mode distinctly from "user denied" and provide a relaunch-target-app recovery path.
4. **`AudioDeviceID` is session-ephemeral, not a stable identity** — key the device list/drag-order/persistence by `kAudioDevicePropertyDeviceUID`, never by `AudioDeviceID`, or Bluetooth reconnects will duplicate/desync entries (mirrors `BluetoothMonitor`'s existing `addressString`-keying discipline).
5. **CoreAudio device/default-output listener callbacks fire off the main thread** — every callback body must explicitly hop via `DispatchQueue.main.async` before touching `@Published`/AppKit state, exactly like `BluetoothMonitor`'s already-solved pattern; this is a known, easy-to-reintroduce class of bug in this codebase.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Audio Output Switcher — Pure Seam + Monitor
**Rationale:** Public-API-only, no external unknowns, same risk tier as the already-shipped `VolumeReader`/`BrightnessReader` — safe to build first and fully de-risk before touching the harder favorite/like feature.
**Delivers:** `AudioOutputPresentation.swift` (device value type + sort/reorder pure functions, unit-tested) and `AudioOutputMonitor.swift` (event-driven CoreAudio glue: enumerate, listen, set-default, per-device volume-property guard).
**Addresses:** Output panel table-stakes features (live device list, tap-to-select, real volume slider).
**Avoids:** Pitfall 4 (UID vs AudioDeviceID keying), Pitfall 5 (off-main callback hop), and the volume-property-support pitfall (guard `kAudioDevicePropertyVolumeScalar` before wiring the slider; verify on the dev machine's actual Bluetooth headset, not just built-in speakers).

### Phase 2: Audio Output Switcher — UI Wiring
**Rationale:** Zero remaining unresolved external-API risk once Phase 1 lands — pure SwiftUI/AppKit work, safe to fully on-device-UAT before the favorite feature's spike phase even needs to conclude.
**Delivers:** The speaker-icon reserved slot becomes a real button; `outputPanel(...)` subview (volume slider reusing `readSystemVolume()`/`adjustSystemVolume()` verbatim + reorderable device list); sibling `@Published outputPanelOpen` on `IslandPresentationState`; the geometry three-site rule (blobShape height, panel-frame union, `visibleContentZone()`) applied together, not independently.
**Uses:** CoreAudio stack from STACK.md; architecture Pattern 3 (controller-visible disclosure state, not a resolver case).
**Implements:** `IslandPresentationState` sibling-field pattern; click-through hit-zone extension.

### Phase 3: Favorite/Like — Spike (Apple Music + Spotify + Automation reliability)
**Rationale:** This is the milestone's single highest-risk item — three independent unknowns (Apple Music `current track` reliability, Spotify OAuth/quota-mode reality, Automation-permission TCC bug, and whether the vendored `mediaremote-adapter` wrapper exposes a like-command send at all) must be resolved on real hardware before any UI is planned in detail, exactly mirroring this project's own Phase 22/38/39 precedent.
**Delivers:** A documented go/no-go on Spotify scope (ship OAuth, ship bring-your-own-Client-ID, or descope to Apple-Music-only for this milestone); confirmed behavior of `current track` across library/streaming/play/pause states; confirmed Automation-prompt behavior after target-app idle time; confirmed whether the wrapper's `MediaController` can send a like command (patch its command table if not).
**Avoids:** Pitfall 1 (Spotify quota wall), Pitfall 2 (Apple Music `current track` failure), Pitfall 3 (Automation TCC bug) — all three explicitly require on-device verification, not documentation-only research.

### Phase 4: Favorite/Like — Implementation (scoped per Phase 3's findings)
**Rationale:** Only plan the concrete write path once Phase 3 answers whether it's read/write, write-only, or Apple-Music-only.
**Delivers:** `toggleFavorite()` + `isFavorite: Bool?` added to the existing `NowPlayingService`/`NowPlayingMonitor`/`TrackSnapshot` seam (favorite does NOT get its own isolated protocol — same bridge, same isolation boundary as transport control); the star reserved slot becomes a real button; Keychain-backed Spotify token storage (mirroring the existing `KeychainLicenseStore` pattern) if Spotify ships.
**Implements:** Architecture Pattern 1 (extend `NowPlayingService`, don't duplicate it).
**Avoids:** The optimistic-success UX pitfall — the star must show pending/failed/verified state, never claim success before a confirmed write, mirroring the project's existing license-validation "never silently claim success" precedent.

### Phase Ordering Rationale

- **Low-risk, public-API feature first:** the output switcher has zero external unknowns and directly reuses Phase 39's proven CoreAudio patterns — building it first banks a real shipped feature while the favorite/like spike proceeds independently.
- **Spike isolated before implementation, not blended into it:** favorite/like's three genuine unknowns (Spotify quota, Apple Music `current track`, Automation TCC reliability) are exactly the class of surprise this project has hit before (Phase 22, 38, 39) — resolving them first prevents a mid-phase scope collapse.
- **A spike failure on favorite/like never blocks or contaminates the output-switcher work** — the two features share no code path (per the architecture research's own build-order recommendation), so sequencing them in parallel-safe order (output switcher fully shippable regardless of the spike's outcome) is deliberate risk isolation.

### Research Flags

Needs research (`/gsd:plan-phase --research-phase <N>`):
- **Phase 3 (Favorite/Like spike):** Three independent undocumented/policy-gated unknowns (Spotify quota-mode reality, Apple Music `current track` reliability, Automation TCC prompt bug) — none resolvable from documentation alone, all require a real on-device round-trip.
- **Phase 4 (Favorite/Like implementation):** Scope depends entirely on Phase 3's findings (read/write vs write-only vs Apple-Music-only) — cannot be planned in detail until the spike concludes.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Output switcher — pure seam + monitor):** Public, documented CoreAudio API; the project already has two working examples to copy from (`VolumeReader.swift`, `BrightnessReader.swift`) plus `BluetoothMonitor.swift`'s event-driven shape to mirror directly.
- **Phase 2 (Output switcher — UI wiring):** Pure SwiftUI/AppKit work once Phase 1 lands; the "geometry three-site rule" is an already-named, already-repeated convention in this codebase (Tray, Weather, Quick Action Picker all followed it).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | HIGH for CoreAudio device switching/volume, AppleScript `loved` property, and `ASWebAuthenticationSession` (official docs, multiple corroborating sources); MEDIUM for exact Spotify Web API endpoint shapes (Feb 2026 migration is very recent, worth re-verifying at plan/execute time) |
| Features | MEDIUM-HIGH | Favorite/like mechanics verified against Apple/Spotify developer docs and community reports; UI-pattern precedent (tap-vs-drag) verified against macOS/iOS system UI and SoundSource — no ambiguity there |
| Architecture | MEDIUM | HIGH for the integration points (grounded in direct codebase reads: `NowPlayingMonitor`, `VolumeReader`, `IslandResolver`, `NotchPillView`); MEDIUM/LOW for two external-API questions (whether the vendored `mediaremote-adapter` wrapper can send a like command; whether it reports read-state) — both explicitly flagged spike-required |
| Pitfalls | MEDIUM | Spotify Web API policy findings are HIGH-confidence/official; several CoreAudio/AppleScript specifics are MEDIUM (single-source or forum-corroborated, individually flagged); own-hardware behavior remains genuinely unverified until spiked |

**Overall confidence:** MEDIUM — the audio-output switcher is high-confidence, low-risk, standard-pattern work; the favorite/like feature has three real, policy/platform-level unknowns that could change its scope after a spike, on the same order of magnitude as this project's prior Phase 38/39 undocumented-API surprises.

### Gaps to Address

- **Whether `ejbills/mediaremote-adapter`'s `MediaController` wrapper exposes sending `MRMediaRemoteCommandLikeTrack` at all** — not found documented in any research pass; must be spiked (worst case: patch the wrapper's own command table, contained to `NowPlayingMonitor.swift`).
- **Whether the streamed MediaRemote payload ever reports a rating/favorite read-state** — if not, the star can only be a write-only, optimistic session-local toggle rather than a real bidirectional control; this materially changes the feature's scope and must be resolved before implementation planning, not discovered mid-execution.
- **Spotify's Extended Quota approval odds for a solo-developer paid hobby app** — the policy criteria may keep changing; confirm current state directly on the Developer Dashboard during the spike rather than trusting this research's snapshot.
- **Apple Music's `current track` failure mode on the project's actual target OS build** — confirmed broken in forum reports as of Tahoe 26.0.0, but must be independently re-confirmed on this project's own dev hardware, not assumed transferable from community reports.

## Sources

### Primary (HIGH confidence)
- Direct codebase reads: `Islet/Notch/NowPlayingMonitor.swift`, `NowPlayingPresentation.swift`, `IslandResolver.swift`, `IslandPresentationState.swift`, `VolumeReader.swift`, `BluetoothMonitor.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `.planning/PROJECT.md`
- Spotify for Developers — official docs: Save Tracks/Save Items to Library reference, February 2026 migration guide, redirect URI/PKCE docs, Extended Access quota-mode criteria (developer.spotify.com)
- Apple Developer Documentation — `ASWebAuthenticationSession`, `kAudioHardwarePropertyDevices`/`DefaultOutputDevice`/`DefaultSystemOutputDevice`, `AudioObjectAddPropertyListener`, `NSAppleEventsUsageDescription`
- [theos/headers MediaRemote.h](https://github.com/theos/headers/blob/master/MediaRemote/MediaRemote.h) — confirms `MRMediaRemoteCommandLikeTrack`/`DislikeTrack` exist as private command constants (community-maintained header, not Apple source)

### Secondary (MEDIUM confidence)
- Apple Developer Forums threads 669239, 798267, 792157, 763583, 693516 — Music.app `current track`/`loved` reliability, Automation-prompt TCC bug, AirPods-handoff default-output override, Bluetooth volume-property regression
- Spotify Community threads — no native AppleScript like/save command exists (multiple corroborating reports)
- `ungive/mediaremote-adapter` GitHub repo — documented 14-command table, no like/love/rate command found
- [TheBoredTeam/boring.notch Issue #929](https://github.com/TheBoredTeam/boring.notch/issues/929) and [1of1Adam/Droppy README](https://github.com/1of1Adam/Droppy) — competitor like-button reliability/scope comparison
- Rogue Amoeba SoundSource manual, Apple Support "Change sound output settings" — tap-to-select precedent confirmation

### Tertiary (LOW confidence)
- `com.spotify.client.PlaybackStateChanged` distributed-notification pattern (multiple independent open-source community references) — flagged for a local spike before relying on it as the track-identity source
- `SimplyCoreAudio` repo metadata — confirms archived/unmaintained status, informational only (rejected as a dependency)

---
*Research completed: 2026-07-19*
*Ready for roadmap: yes*
