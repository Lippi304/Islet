# Pitfalls Research

**Domain:** Writing "liked" status back to Spotify/Apple Music from a third-party macOS app; enumerating/switching CoreAudio output devices — both as additions to Islet's existing Now Playing expanded view (v1.7 "Interaction & Calendar Polish" scope)
**Researched:** 2026-07-19
**Confidence:** MEDIUM (Spotify Web API policy findings HIGH-confidence/official; several CoreAudio/AppleScript specifics MEDIUM — single-source or forum-corroborated, flagged individually; own-hardware behavior remains genuinely unverified until spiked)

## Critical Pitfalls

### Pitfall 1: Spotify has no AppleScript (or MediaRemote command) path to "like" a track — Web API + OAuth is the only real option, and it's now gated behind a policy Islet likely fails

**What goes wrong:**
The obvious "cheap" implementation — reuse the same private-API/AppleScript pattern Islet already trusts for Now Playing — does not exist for this feature. Spotify's AppleScript dictionary has never exposed a "save/like track" command (the Spotify Community itself has an open, unresolved feature request for this going back years; even the deprecated `starred` playlist property doesn't help — MEDIUM confidence, community-sourced but consistent). Separately, `mediaremote-adapter`'s own documented command table (14 IDs: play/pause/stop/next/prev/seek/shuffle/repeat) has no like/love/favorite/rate command — despite streamed metadata sometimes carrying read-only `isLiked`/`isBanned`/`isInWishList`-shaped fields, there is no corresponding *write* command (MEDIUM confidence — no official spec, inferred from the adapter's documented command list). The only real path is Spotify's own Web API (`PUT /me/tracks`, "Save Tracks for Current User"), which requires a full OAuth Authorization Code + PKCE flow — a Spotify Developer Dashboard app registration, a Client ID, a loopback/custom-URL redirect, and a browser-based login the user must complete once.

Worse: as of May 15, 2025, Spotify's Developer Policy update restricts **Extended Quota Mode** (the tier that lifts the 5-user cap and higher rate limits) to organizations with an "established, scalable, impactful" platform use case — individual/hobby developers are explicitly deprioritized (HIGH confidence — Spotify's own developer blog post). Left in **Development Mode**, a Spotify app is capped at 5 manually-allowlisted Spotify accounts total. Since Islet is a paid, publicly-distributed hobby product from a single developer, it will very likely NOT qualify for Extended Quota under the new criteria — meaning a single shared Islet Client ID could only ever serve 5 real customers' Spotify accounts before hitting a hard wall.

**Why it happens:**
Islet's own precedent (MediaRemote via `mediaremote-adapter`) trained the instinct that "there's always a private-API/scripting bridge for this." Liking/saving is different: it mutates the user's cloud library, which every major streaming platform gates behind an authenticated, rate-limited, policy-reviewed API — not a local scripting hook.

**How to avoid:**
1. Spike this FIRST, before writing any UI. Concretely: create a real Spotify Developer Dashboard app, implement the Authorization Code + PKCE flow with a loopback redirect (`http://127.0.0.1:<port>/callback`), and call `PUT https://api.spotify.com/v1/me/tracks` for a real logged-in account, end to end, on real hardware.
2. During that spike, explicitly check the Dashboard's current quota-mode requirements/criteria (they may keep changing) — confirm whether extended quota is realistically obtainable, or whether Islet must ship a "bring your own Spotify Client ID" flow (the workaround pattern several small third-party Spotify menu-bar apps use, e.g. Spotiglass) where each user creates their own Developer Dashboard app and pastes in a Client ID. This is a materially worse onboarding UX and must be a conscious, user-visible product decision, not a silent workaround discovered mid-implementation.
3. If neither Extended Quota nor bring-your-own-Client-ID is acceptable, the Spotify half of this feature may need to be explicitly descoped (Apple Music only) — decide this BEFORE committing a full phase to it.
4. Do not assume the MediaRemote-streamed `isLiked`-shaped field (if present at all) is anything more than a read-only echo of Spotify's own state — verify on real hardware whether it exists and is reliable before designing the star button's "already liked" initial state around it.

**Warning signs:**
Any implementation plan that budgets "reuse mediaremote-adapter / AppleScript, no new auth flow" for the Spotify half is planning against a capability that doesn't exist. If Wave 1 of implementation doesn't include an actual Spotify Developer Dashboard registration and a live OAuth round-trip, the plan hasn't touched the real risk yet.

**Phase to address:**
Dedicated spike/research phase before full implementation (see downstream recommendation) — this is the single highest-risk item of the whole milestone, on the same order of magnitude as the OSD-suppression and Focus-Mode-entitlement surprises from Phase 38/39.

---

### Pitfall 2: Apple Music's AppleScript "loved" property is real, but the "current track" reference it needs is documented-broken for exactly Islet's playback scenario

**What goes wrong:**
`Music.app`'s scripting dictionary does have a track-level `loved`/`favorited` property that can, in principle, be set via AppleScript. But multiple corroborating sources (Apple Developer Forums threads, community reports) describe `current track`/`current playlist` as broken specifically for Apple Music (non-local, streaming) tracks on recent macOS — attempting to read or set properties via `current track` throws `"Music got an error: Can't get name of current track."`, and per one forum thread this is confirmed as an open, filed bug (FB19908171) as of macOS Tahoe-era releases. Critically, this fails hardest for a track that is playing but **not yet added to the user's local library** — which is a completely normal Apple Music streaming scenario, not an edge case Islet can dismiss.

**Why it happens:**
`current track` in the Music scripting dictionary was designed around iTunes-era local libraries; Apple Music's cloud-streamed catalog only partially maps onto that model, and Apple has not kept the AppleScript bridge in sync as streaming became the primary use case.

**How to avoid:**
1. Do not build the "like" button around `tell application "Music" to set loved of current track to true`. Spike it on real hardware FIRST against multiple real scenarios: a track already in the library, a track only in the "For You"/streaming catalog not yet added locally, and a track mid-play vs. paused.
2. If `current track` proves unreliable exactly as documented, the fallback is looking the track up by a stable identifier (e.g. matching on `persistent ID`/database ID via `tracks of library playlist 1 whose name is ... and artist is ...`) rather than `current track` — but title/artist matching is itself fragile (duplicate titles, remasters, features) and must be treated as a real accuracy risk, not just a technical annoyance.
3. Wrap every AppleScript call in a try/catch (Apple's own suggested workaround) and design the star button to show a distinct "couldn't verify/set" state rather than silently doing nothing or claiming success.

**Warning signs:**
The star button appears to work in a quick manual test (song already in library, recently added) but silently fails or throws for freshly-streamed tracks — this exact bimodal failure pattern is what the forum reports describe, so a "works when I tested it" result from a single manual check is not sufficient evidence.

**Phase to address:**
Same dedicated spike phase as Pitfall 1 (Apple Music sub-track).

---

### Pitfall 3: Automation (Apple Events) permission prompts have a documented reliability bug — the TCC prompt can silently fail to appear, and the target app can silently vanish from System Settings → Automation

**What goes wrong:**
Controlling either Spotify or Music.app via AppleScript requires the user to grant Islet Automation permission (an Apple Events / TCC prompt, backed by `NSAppleEventsUsageDescription` in Info.plist and, in some configurations, the `com.apple.security.automation.apple-events` entitlement — required regardless of Islet's existing unsandboxed status). Multiple developer forum reports describe a real, currently-open bug: if the target app (Spotify/Music) hasn't been used in a while, the permission prompt sometimes never fires on first automation attempt, AND the target app doesn't show up in System Settings → Privacy & Security → Automation for the user to manually grant it — leaving no UI path to fix it short of a full reset (`tccutil reset AppleEvents`) or reinstall. Reports note this affects Apple Music more than Spotify.

**Why it happens:**
This is a real macOS TCC subsystem bug (not an Islet implementation mistake), apparently tied to some app-launch-state race in how TCC discovers the automation target the first time it's addressed after a long idle period.

**How to avoid:**
1. Islet must detect and surface this failure mode distinctly from "user denied" — a generic AppleScript error (`-1743`, "not authorized to send Apple events") should NOT be presented to the user as a simple "permission needed, click to grant" flow if the app never even appears in the Automation pane to grant against.
2. Add a documented manual recovery path in Settings/help text: quitting and relaunching the target app (Spotify/Music) once, then retrying, is the most commonly reported workaround; a "reset and retry" affordance in Islet's own UI (re-trigger the AppleScript call after prompting the user to relaunch the target app) is cheap and directly addresses the known trigger.
3. Confirm both `NSAppleEventsUsageDescription` (required for the prompt text at all) and, if the entitlements list needs it, `com.apple.security.automation.apple-events` are present — verify this is not blocked by anything in Islet's existing hardened-runtime/notarization entitlement set (it already carries `disable-library-validation` for MediaRemoteAdapter; check for conflicts).

**Warning signs:**
"It worked on my dev machine" is not sufficient verification here — this bug is described as intermittent and state-dependent (idle time before first automation attempt). Test after actually leaving Spotify/Music unopened for a day, not just freshly launched.

**Phase to address:**
Same dedicated spike phase — this is an integration precondition for Pitfall 2's whole Apple Music path, and partially for a `Music`-based fallback if Islet ever needs one for Spotify too.

---

### Pitfall 4: AudioDeviceID is not a stable identity — using it (instead of the UID) to key the draggable device list will double-count or silently swap devices across Bluetooth reconnects

**What goes wrong:**
CoreAudio assigns a fresh, session-scoped `AudioDeviceID` (a plain integer) to a device essentially every time it appears in the device graph — including every Bluetooth reconnect. If Islet's new output-device list (or its drag-reorder state) is keyed by `AudioDeviceID`, a routine AirPods sleep/wake or reconnect will make the "same" physical device look like a brand-new entry: either it appears to vanish and reappear at the bottom of the list (breaking the user's drag-ordered preference), or — worse — a stale ID silently now points at nothing / at a different device, and a "switch to this device" action does the wrong thing.

**Why it happens:**
`AudioDeviceID` is explicitly documented as ephemeral/process-session-scoped, not a persistent identifier — but it is also the type every CoreAudio call (`AudioObjectSetPropertyData` for the default device, `AudioObjectGetPropertyData` for per-device properties) actually operates on, so it's tempting to just use it as the dictionary/list key directly since it's "right there."

**How to avoid:**
1. Always resolve and store `kAudioDevicePropertyDeviceUID` (a stable string, persistent across reconnects/reboots) as the actual identity key for the device list, drag order, and any "last selected output" persistence. Re-resolve the current `AudioDeviceID` from the UID immediately before every CoreAudio call that needs it (devices can be looked up by UID via `kAudioHardwarePropertyTranslateUIDToDevice`).
2. This exactly mirrors a pattern Islet's own `BluetoothMonitor.swift` already uses correctly — it keys `disconnectTokens` by `device.addressString`, not by any ephemeral object reference. Reuse that discipline explicitly for the new CoreAudio device monitor rather than re-deriving it from scratch.

**Warning signs:**
A device silently duplicates in the list after an AirPods sleep/wake cycle, or the drag-reordered position doesn't survive a Bluetooth reconnect — both are direct symptoms of keying by `AudioDeviceID`.

**Phase to address:**
Implementation phase for the audio-output switcher (does not need its own dedicated spike phase — this is a documented, public-API discipline, not an unknown — but must be an explicit code-review gate item, analogous to the CR-01 click-through class of bug this project has repeatedly reintroduced).

---

### Pitfall 5: CoreAudio's device-list/default-device-change notifications fire off the main thread — reintroducing the exact "forgot to hop to main" class of bug this codebase has hit twice before

**What goes wrong:**
`AudioObjectAddPropertyListenerBlock` (or the older `AudioObjectAddPropertyListener` C-callback form) for `kAudioHardwarePropertyDevices` / `kAudioHardwarePropertyDefaultOutputDevice` delivers callbacks on a CoreAudio-internal dispatch queue, not the main thread. A new `AudioOutputMonitor` written without an explicit main-thread hop before touching `@Published` state or driving `NSWindow`/SwiftUI updates will intermittently corrupt window state or silently no-op, exactly like the pre-fix `BluetoothMonitor`/`PowerSourceMonitor` callback pattern this codebase's own comments already document as a solved problem.

**Why it happens:**
It's an easy trap for a first-time programmer (or an AI executor pattern-matching too loosely) to assume `@MainActor` on the class is sufficient — but, exactly as `BluetoothMonitor.swift`'s own inline comments explain, Swift actor isolation does NOT retroactively main-isolate a callback that a system framework invokes via its own queue/ObjC runtime dispatch.

**How to avoid:**
Explicitly wrap every CoreAudio listener callback body in `DispatchQueue.main.async { … }` before touching any state, mirroring `BluetoothMonitor.connected(_:device:)`/`disconnected(_:device:)` and `NowPlayingMonitor`'s documented discipline verbatim. This should be a one-line code-review checklist item, not a design question.

**Warning signs:**
Intermittent UI glitches under real Bluetooth-connect timing that don't reproduce when triggered manually/slowly (classic off-main-thread symptom); a code review that doesn't find an explicit `DispatchQueue.main.async`/`@MainActor` hop inside the new monitor's callback closures.

**Phase to address:**
Implementation phase — enforce via code review, not a spike (this is a known, already-solved pattern in the codebase, purely a discipline/consistency risk).

---

### Pitfall 6: The new CoreAudio output-device list and the existing `BluetoothMonitor`'s connect/disconnect activity are two independent signals for the same physical event — integrating them naively double-shows or desyncs a device

**What goes wrong:**
When AirPods connect, TWO separate, asynchronously-firing system signals occur: IOBluetooth's connect notification (already driving Islet's existing Device-Connected HUD via `BluetoothMonitor`) and CoreAudio's `kAudioHardwarePropertyDevices` list-changed notification (driving the new output-device list). These do not fire in a guaranteed order or with any correlation ID linking them — a naive integration (e.g. showing the AirPods as a distinct row keyed on whichever signal arrived first, or trying to synchronously derive one from the other) can produce a flickering duplicate entry, a device that shows as "connected" in one UI surface and "disconnected" in the other for a brief window, or race-condition ordering bugs (Bluetooth connects, but the CoreAudio device isn't enumerable yet for another beat — the same kind of timing gap that already forced Islet's own delayed battery-refresh lookup in `BluetoothMonitor.battery(forAddress:)`).

**Why it happens:**
IOBluetooth (pairing/RF layer) and CoreAudio (audio routing layer) are genuinely different subsystems with independent event timelines; a device being Bluetooth-connected and a device being audio-output-capable-and-enumerated are related but not simultaneous facts.

**How to avoid:**
1. Do NOT try to derive the output-device list's Bluetooth devices FROM `BluetoothMonitor`'s existing state, and do not try to derive Bluetooth-connected/disconnected activity FROM the CoreAudio device list. Keep them as two independently-sourced, independently-correct monitors (this also matches the project's own established `ActivityCoordinator`/single-responsibility-monitor convention from Phase 16's `DeviceCoordinator` extraction).
2. Reconcile ONLY at the display layer if a "this is your AirPods" label/icon needs to match between the two surfaces — match loosely by name substring, never assume a 1:1 timing relationship, and treat a temporary mismatch (Bluetooth says connected, CoreAudio device list hasn't caught up yet) as an expected, transient state, not a bug to eliminate.
3. Filter the CoreAudio device list to actual output-capable devices only (`kAudioDevicePropertyStreams` on the output scope > 0) before ever surfacing it, so aggregate/virtual/input-only devices don't pollute the list independent of the Bluetooth-overlap question.

**Warning signs:**
A device transiently appears twice in the switcher UI right at connect time, or the switcher and the existing Bluetooth HUD briefly disagree about whether a device is connected — both point at an attempted hard link between the two monitors rather than accepting them as independent sources of truth.

**Phase to address:**
Implementation phase (design decision, not a spike) — but flag explicitly in the phase's plan/context doc so the executor doesn't reach for `BluetoothMonitor` as a shortcut data source for the new feature.

---

### Pitfall 7: Not every output device supports the same volume-control property — a naive single-property volume slider will silently fail, mute unexpectedly, or crash on unsupported devices

**What goes wrong:**
`kAudioDevicePropertyVolumeScalar` (the obvious "just set the volume" property) is not universally supported. Some devices only expose per-channel volume (channel 1/2) rather than a single master scalar; some (documented as a real regression starting macOS 12.0.1, forum-reported) misbehave specifically for Bluetooth devices, where a set call ends up muting output entirely instead of scaling it; and calling `AudioObjectSetPropertyData` for a property a given device genuinely doesn't support returns `kAudioHardwareUnknownPropertyError` rather than silently no-op-ing — an unguarded call can surface as a runtime error path if not defensively checked first.

**Why it happens:**
CoreAudio's property system is intentionally generic/pluggable across wildly different hardware (built-in speakers, aggregate devices, USB DACs, Bluetooth codecs) — there is no single volume mechanism guaranteed to exist and behave identically everywhere.

**How to avoid:**
1. Before wiring the volume slider to any device, call `AudioObjectHasProperty`/`AudioHardwareServiceHasProperty` for `kAudioDevicePropertyVolumeScalar` on the master channel (0) first; if absent, try per-channel (1/2) as a fallback; if both are absent, disable/hide the slider for that device rather than presenting a control that silently does nothing.
2. This mirrors a defensive pattern Islet's own `BluetoothMonitor.batteryPercent(_:)` already uses (`responds(to:)`-guarded KVC reads with graceful `nil` fallback rather than an unchecked call) — apply the same "check before calling, degrade gracefully" discipline here rather than assuming the property exists.
3. Spike the actual behavior on Islet's own dev-hardware Bluetooth headset specifically (the same machine that already surfaced the `.cgSessionEventTap`-vs-`.cghidEventTap` and Focus-Mode-entitlement surprises) before locking in the slider's implementation — don't trust generic documentation over an actual on-device read, per this project's own established lesson.

**Warning signs:**
The volume slider visibly moves but the device's actual audible volume doesn't change (silent no-op), or moving the slider unexpectedly mutes the device outright — both are the documented Bluetooth-specific failure modes, not generic bugs to debug from scratch.

**Phase to address:**
Implementation phase, but with a mandatory on-device functional-read spike step at the start (not just a code-level `AudioObjectHasProperty` check in isolation) — same "verify on real hardware, not just API surface" lesson as Phase 38's Communication Notifications entitlement gap.

---

### Pitfall 8: Switching the default output device is audibly glitchy, and a documented macOS bug can make Islet's own device-switch silently overridden by the system

**What goes wrong:**
Setting `kAudioHardwarePropertyDefaultOutputDevice` causes an audible pop/click as CoreAudio tears down and re-establishes the active output stream — an unavoidable OS-level artifact, not something Islet's implementation can fully eliminate. Separately, Apple Developer Forums document a real bug specific to AirPods handoff scenarios: after AirPods hand off from iPhone back to the Mac, an app's attempt to set a different default output device can be silently overridden — the system just switches back to AirPods immediately regardless of what the app requested, with no error returned to the calling app.

**Why it happens:**
The pop/click is inherent to how CoreAudio's HAL re-negotiates the active stream on a device switch; the AirPods-handoff override is a reported, unresolved system-level bug (not something a third-party app can detect or work around reliably from public API).

**How to avoid:**
1. Accept the pop/click as an OS-level limitation to design around (e.g., a very brief system-driven fade if Islet controls playback timing, though this is polish, not correctness) rather than a bug to chase — do not burn a debugging cycle here the way Phase 39's OSD-tap investigation initially did on a genuinely fixable issue; this one may not be fixable.
2. For the AirPods-handoff-override case: after calling `AudioObjectSetPropertyData` to change the default device, re-read `kAudioHardwarePropertyDefaultOutputDevice` shortly after (e.g. via the existing default-device-changed listener) to confirm the switch actually stuck; if it silently reverted, surface this to the user as "couldn't switch — try again" rather than leaving the UI showing a selection that isn't actually active.
3. Do not promise instantaneous, glitch-free switching in the UI/UX spec — set the expectation (brief mention in the phase's UI-SPEC) that a switch involves a momentary audio interruption, matching real CoreAudio behavior rather than an idealized instant cut.

**Warning signs:**
A code review or on-device UAT that treats "the slider/list updated" as proof the switch worked, without confirming the actual `kAudioHardwarePropertyDefaultOutputDevice` value afterward, will miss the silent-override case entirely.

**Phase to address:**
Implementation phase — the confirm-after-set discipline should be a concrete Success Criterion in that phase's ROADMAP entry, not left implicit.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Match "now playing" track to a Spotify/Apple Music library item by title+artist string instead of a stable ID | No extra API surface, ships faster | Wrong track liked (remix/live/remaster collisions), silently corrupts user's library | Only as an interim spike-stage hack — never for the shipped feature; must be replaced once a stable per-track identifier is confirmed reachable (Spotify: track URI from the Web API's currently-playing/search match; Apple Music: persistent ID lookup) |
| "Bring your own Spotify Client ID" UX instead of a shared Islet-owned app | Sidesteps the 5-user Development Mode cap entirely, ships without waiting on Spotify's review process | Materially worse onboarding (user must create a Developer Dashboard app themselves) — a real product/UX cost, not free | Acceptable ONLY as an explicit, user-communicated decision after Pitfall 1's spike confirms Extended Quota isn't realistically obtainable — not as a silent fallback discovered mid-implementation |
| Key the CoreAudio output-device list by `AudioDeviceID` instead of `kAudioDevicePropertyDeviceUID` | Slightly less code (no UID resolution step) | Duplicate/stale entries across every Bluetooth reconnect — a correctness bug, not a corner case | Never |
| Skip the `AudioObjectHasProperty` guard before volume-property calls | Fewer lines, works on the dev machine's tested devices | Runtime error / silent mute on unsupported hardware for real customers with different audio setups | Never — this class of unguarded-call bug is exactly what `BluetoothMonitor`'s existing `responds(to:)` guard pattern was written to prevent; reuse the discipline, don't skip it |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| Spotify Web API (OAuth) | Assuming a shared Islet Client ID scales to all paying customers like any other API integration | Verify quota-mode reality first (Pitfall 1) — may require a bring-your-own-Client-ID flow or Apple-Music-only scope for v1 of this feature |
| Music.app AppleScript | Building the like-toggle around `current track` | Spike `current track` reliability first for streamed (not-yet-library) tracks; fall back to an identifier-based library lookup if broken (Pitfall 2) |
| Automation/Apple Events permission | Treating any AppleScript failure as "just ask for permission again" | Detect the documented "app never appears in Automation pane" failure mode distinctly; provide a relaunch-target-app recovery path (Pitfall 3) |
| `mediaremote-adapter` | Assuming its 14-command table has a like/love/rate command because the metadata payload sometimes carries `isLiked`-shaped fields | Treat any such field as read-only/unverified; the write path must go through Web API (Spotify) or AppleScript (Apple Music), never through the command-send path |
| CoreAudio ↔ `BluetoothMonitor` | Deriving the output-device switcher's Bluetooth entries from `BluetoothMonitor`'s existing connect state, or vice versa | Keep both monitors independent; reconcile only loosely at the display layer (Pitfall 6) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Re-checking "is this track liked?" via a fresh AppleScript/Web-API call on every track-metadata tick from `NowPlayingMonitor` | Extra AppleScript round-trips or Spotify API calls fire far more often than the track actually changes, risking Spotify rate limits and audible AppleScript-launch stutter | Only re-check liked-state on a genuine track-identity change (mirror the existing song-change-toast's own change-detection, not the raw metadata stream), and cache the result until the track changes again | Noticeable once a user leaves Islet running through a long listening session with frequent track changes |
| Polling the full CoreAudio device list on a timer instead of relying on the `kAudioHardwarePropertyDevices` change listener | Wasted CPU wake-ups, fights this project's own established idle-CPU-gating convention (equalizer bars, countdown timer) | Use the property listener exclusively — this is a public, reliable, event-driven API, unlike the private-framework cases that forced polling elsewhere in this project (Focus Mode) | N/A — this is avoidable from the start, no threshold; flag any implementation that polls as a design mistake, not a scale issue |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing the Spotify OAuth refresh token in `UserDefaults`/plist instead of Keychain | Trivially exfiltrated/reset, same class of mistake this project explicitly avoided for trial/license state (Phase 10 decision) | Store Spotify tokens in the Keychain, mirroring the existing `KeychainLicenseStore` pattern already proven in this codebase |
| Embedding a Spotify Client Secret in the shipped app binary (if any flow variant calls for one) | A statically extractable secret in a distributed macOS app is not actually secret — publicly extractable via `strings`/binary inspection | Use Authorization Code with PKCE specifically (no client secret required/storable client-side) — this is Spotify's own documented recommendation for exactly this app class |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Star button shows an optimistic "liked" state immediately on tap, with no confirmation the underlying AppleScript/API call actually succeeded | User believes a song is saved to their library when the write silently failed (Automation permission bug, broken `current track`, API error) | Show a distinct pending/failed state, not just instant-toggle — the star should reflect confirmed state, with a brief revert-on-failure exactly like this project's existing license-validation "never silently claim success" precedent (Phase 12 decision) |
| Volume slider or output-switcher item shown for a device that doesn't actually support the operation just attempted (Pitfall 7/8) | User acts on a control that silently does nothing, looks broken | Hide/disable controls the device doesn't support rather than showing them unconditionally |
| Promising instant, glitch-free output switching in the UI copy/animation | Sets an expectation CoreAudio's actual HAL behavior can't meet (audible pop is normal) | Design the switch transition/animation acknowledging a brief real-world audio interruption rather than implying an instant silent cut |

## "Looks Done But Isn't" Checklist

- [ ] **Spotify like button:** Often "done" after testing with the developer's OWN allowlisted Spotify account in Development Mode — verify it isn't secretly capped at 5 total users before considering the feature customer-ready.
- [ ] **Apple Music like button:** Often "done" after testing only against tracks already in the local library — verify against a freshly-streamed, not-yet-added track (the documented `current track` failure mode).
- [ ] **Automation permission flow:** Often "done" after testing on a dev machine where Spotify/Music was just recently opened — verify behavior after the target app has sat unused for a day (the documented prompt-reliability bug).
- [ ] **Output device list:** Often "done" after testing with one Bluetooth device connected the whole session — verify across an actual disconnect/reconnect cycle (duplicate-entry / stale-ID risk).
- [ ] **Volume slider:** Often "done" after testing only with built-in speakers (which reliably support `kAudioDevicePropertyVolumeScalar`) — verify against the actual Bluetooth headset/AirPods on the dev machine.
- [ ] **Output device switch:** Often "done" after a single manual switch test — verify the post-switch value was actually confirmed (re-read `kAudioHardwarePropertyDefaultOutputDevice`), not just that the UI updated optimistically.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Spotify quota-mode wall discovered mid-implementation | HIGH | Descope to Apple-Music-only for this milestone, or pivot to bring-your-own-Client-ID — both are real replanning, not a quick patch; this is exactly why it must be spiked FIRST |
| Apple Music `current track` unreliable as designed | MEDIUM | Swap to identifier/library-lookup-based track resolution — contained to the one AppleScript integration file if isolated behind a protocol from the start (mirror `NowPlayingService`'s one-file-swap precedent) |
| Output device list double-counts after a reconnect | LOW | Re-key the list by UID instead of `AudioDeviceID` — a contained, mechanical fix if caught in code review before shipping |
| Volume slider silently no-ops on unsupported devices | LOW | Add the missing `AudioObjectHasProperty` guard and hide the control — contained, single-file fix |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| 1. Spotify Web API / quota-mode wall | Dedicated spike/research phase (before full "favorite" implementation) | A real OAuth round-trip + a real `PUT /me/tracks` call against a live account, plus an explicit read of Spotify's current quota-mode criteria, both completed and documented before locking implementation scope |
| 2. Apple Music `current track` reliability | Same spike phase | On-device test against both a library track and a freshly-streamed track, both play and pause states |
| 3. Automation permission reliability bug | Same spike phase | On-device test after leaving the target app (Spotify/Music) unopened for at least several hours; confirm the app appears in System Settings → Automation after the first grant |
| 4. AudioDeviceID vs UID identity | Implementation phase, code-review gate | Code review confirms the device list/persistence is keyed by `kAudioDevicePropertyDeviceUID`, not `AudioDeviceID` |
| 5. Off-main CoreAudio callbacks | Implementation phase, code-review gate | Code review confirms every CoreAudio listener callback explicitly hops to main before touching `@Published`/AppKit state |
| 6. BluetoothMonitor/CoreAudio double-signal integration | Implementation phase, design decision documented in phase CONTEXT.md | On-device UAT: connect/disconnect a Bluetooth device and confirm no duplicate/desynced entries appear across the existing Device HUD and the new output switcher |
| 7. Non-uniform volume-property support | Implementation phase, with a functional on-device spike step at phase start | On-device test against Islet's actual Bluetooth headset/AirPods, not just built-in speakers, before the slider UI is locked |
| 8. Output-switch glitch / silent AirPods-handoff override | Implementation phase | ROADMAP Success Criteria explicitly includes a post-switch re-read/confirm step, verified on-device |

## Sources

- Spotify Community — "Add 'Like song' as a method to AppleScript" (open feature request, unresolved) — MEDIUM confidence, community-sourced
- Spotify Community — AppleScript `starred` property deprecated — MEDIUM confidence
- `ungive/mediaremote-adapter` (GitHub) — documented 14-command table, no like/love/rate command — MEDIUM-HIGH confidence (direct repo read via WebFetch)
- Spotify for Developers — "Updating the Criteria for Web API Extended Access" (developer.spotify.com/blog, effective 2025-05-15) — HIGH confidence, official
- Spotify for Developers — Authorization Code with PKCE Flow docs (developer.spotify.com/documentation/web-api) — HIGH confidence, official
- Spotify for Developers — Quota modes docs (developer.spotify.com/documentation/web-api/concepts/quota-modes) — HIGH confidence, official
- Apple Developer Forums thread 798267 — "Apple Script for Music app no longer supports current track event" — MEDIUM-HIGH confidence, multiple corroborating reports, references filed bug FB19908171
- Apple Developer Forums thread 669239 — "AppleScript to retrieve track properties in Music no longer..." — MEDIUM confidence
- Apple Developer Forums thread 792157 — "App doesn't trigger Privacy Apple Events prompt after a while" — MEDIUM-HIGH confidence, developer-reported bug pattern
- Apple Developer Documentation — `NSAppleEventsUsageDescription`, `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioHardwarePropertyDefaultSystemOutputDevice`, `AudioDeviceID` — HIGH confidence, official
- Apple Developer Forums thread 763583 — default output device set silently overridden after AirPods handoff — MEDIUM confidence, single forum thread but describes a specific, plausible mechanism
- Apple Developer Forums thread 693516 — `AudioObjectSetPropertyData` Bluetooth volume behavior change (macOS 12.0.1+) — MEDIUM confidence
- `Islet/Notch/BluetoothMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift` (this repo) — direct source read, HIGH confidence for existing-codebase conventions (off-main dispatch discipline, `responds(to:)` defensive guards, UID/address-based keying)
- `.planning/STATE.md` decision log entries for Phase 38 (38-09) and Phase 39 (39-01, 39-07, 39-08) — this project's own prior undocumented-API/hidden-requirement precedent, used to calibrate the spike-first recommendation

---
*Pitfalls research for: Islet v1.7+ Now Playing "favorite" writeback + audio-output switcher*
*Researched: 2026-07-19*
