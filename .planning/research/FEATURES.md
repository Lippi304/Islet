# Feature Research — Now Playing "Like" Button + Audio Output Switcher

**Domain:** macOS notch/Dynamic-Island utility (Islet) — Now Playing expanded-view extensions
**Researched:** 2026-07-19
**Confidence:** MEDIUM-HIGH (favorite/like write-back mechanics verified against Apple/Spotify developer docs and community reports; UI-pattern precedent verified against macOS/iOS system UI and comparable third-party apps; no Context7 library docs apply here — this is platform/API and UX-pattern research, not a library-integration question)

> Supersedes nothing — this is new, narrowly-scoped research for 2 candidate capabilities (favorite/like button, audio-output switcher) extending Islet's existing Now Playing expanded view. Prior milestone research (v1.6 Liquid Glass & System HUD Suite, v1.5, etc.) is preserved in git history; this file reflects only the current research pass.

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Like button reflects **real** per-app state on load (filled star if the currently-playing track is already loved/saved) | A fake local-only heart that doesn't match the actual player is worse than no button — users will notice the mismatch within one session and stop trusting it | MEDIUM | Apple Music: AppleScript `loved of current track` is readable directly. Spotify: requires a `GET /v1/me/tracks/contains?ids=` Web API call — the read side has the exact same OAuth dependency as the write side (see below), no way around it. |
| Output list shows the actual live system default output, highlighted/on top, and updates live if the user changes it elsewhere (System Settings, Control Center, unplugging AirPods) | This is exactly how macOS's own Control Center Sound module and SoundSource behave; anything less reads as broken | LOW-MEDIUM | Register a `kAudioHardwarePropertyDefaultOutputDevice` + `kAudioHardwarePropertyDevices` listener via `AudioObjectAddPropertyListenerBlock` — same event-driven pattern already used for `VolumeReader`/`BluetoothMonitor` in this codebase, not polling. |
| Volume slider in the output panel actually controls system output volume (thick bar, live-drag), not a decorative element | The milestone spec explicitly describes a "thick volume-slider bar" alongside the device list — this is the same real-time expectation set by Phase 39's Volume HUD | LOW | Direct reuse of Phase 39's `AudioObjectSetPropertyData(kAudioDevicePropertyVolumeScalar)` self-drive code path. |
| Tapping/selecting a different output device actually switches system audio immediately | Table stakes for *any* output picker — macOS Control Center, the iOS AirPlay picker, and SoundSource all do this on a single tap with no confirmation step | LOW-MEDIUM | `AudioObjectSetPropertyData(kAudioHardwarePropertyDefaultOutputDevice)`. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Apple Music "loved" write-back from the island | Droppy (the project's own cited competitor) explicitly ships this ("love tracks" in its own marketing copy) — matching it is parity, but doing it *reliably* (including a "track not yet in library" edge case, see Anti-Features note below) is where Islet can beat a $6.99 competitor | LOW-MEDIUM | `tell application "Music" to set loved of current track to true` via an AppleScript Apple Event — no OAuth, no network call, works instantly on the same Mac. Requires a new Automation permission (`NSAppleEventsUsageDescription` + first-use consent prompt) — same permission-surface pattern as Phase 38's Focus Mode `NSFocusStatusUsageDescription`/entitlement gotcha. Known rough edge: Apple's own AppleScript dictionary has documented bugs adding tracks that aren't already in the user's library (Apple Developer Forums thread 694200, "Add songs to Library in Music?") — a track streamed-but-not-yet-added may fail to accept `loved` silently; needs an on-device check, not just a code-path check. |
| Spotify "liked songs" write-back from the island | Real differentiator *if* it works — TheBoringNotch's own like button is confirmed broken/non-functional in a live GitHub issue (#929, "invisible and doesn't work") as of this research, and Droppy's own marketing copy conspicuously does **not** claim a Spotify love/like capability (only "playback with album art, visualizer & media controls") despite explicitly claiming it for Apple Music. Getting this right where two real, named competitors visibly haven't is a genuine differentiator. | MEDIUM-HIGH | See "Spotify Like — the hard path" below. This is a materially bigger lift than the Apple Music version: no local write API exists at all. |
| Drag-to-promote as an *optional accelerator* on top of tap-to-select in the output panel | A tactile "grab and drop AirPods to the top" gesture could feel delightful and matches the island's existing spring/`matchedGeometryEffect` animation language elsewhere in the app | MEDIUM | Only worth building *after* tap-to-select ships and works — see the dedicated recommendation below. Not a replacement for tap. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| **Drag-to-reorder-IS-select** as the *only* way to change output (the milestone's literal wording: "dragging a non-current output to the top position switches the active output") | Feels novel/premium, mirrors the existing Now Playing dual-activity bubble's playful interaction language | No precedent found anywhere: macOS Control Center's own Sound module (the literal same "volume slider + device list, current highlighted" layout the milestone spec describes), the iOS Control Center AirPlay/Now-Playing device picker, and Rogue Amoeba's SoundSource (the established third-party Mac output-routing tool) are all **tap/click-to-select**, none use drag-to-reorder as the selection trigger. Conflating "reorder this list" with "cause a real system side effect" is also a classic accidental-action trap — a user reordering the list just to *read* it more easily (or a mis-drag) would silently change what device is playing audio. | Tap-to-select as the actual mechanism; animate the newly-selected device sliding to the top *as a visual consequence* of the tap (keeps the "reorder" polish from the original spec without making drag the trigger). See the dedicated recommendation below. |
| Fuzzy title+artist search against the Spotify Web API to resolve "which Spotify track is this" for the like button | Seems like the obvious way to map MediaRemote's title/artist strings to a Spotify track ID | False-positive risk: liking the wrong track (wrong remix/live version/duplicate) is worse than no like button — a false-positive "like" silently corrupts the user's real Spotify library, exactly the kind of quiet data-corruption bug this class of app must avoid | Read the Spotify track URI directly off the Spotify desktop app's own `com.spotify.client.PlaybackStateChanged` distributed notification (a local trick referenced by several independent open-source Spotify menu-bar tools) instead of guessing via search — this gives an exact, unambiguous Spotify track ID with zero network round-trip on the read side. **Flagged MEDIUM confidence — verify with a local spike before relying on it (see Sources).** |
| Full custom Apple Music **MusicKit REST API** integration (developer token + user token) for the like button | Looks like "the official/modern way" since it's Apple's newest music API | Unnecessary complexity for a same-Mac, same-user write — MusicKit requires registering a MusicKit identifier under the paid Apple Developer Program, minting developer/user tokens, and making network calls to Apple's servers just to flip a boolean on a track already playing locally in Music.app | Plain AppleScript Apple Event to the already-running local `Music.app` — zero network dependency, zero extra Apple Developer configuration beyond the one-time Automation permission prompt. |

## Feature Dependencies

```
[Like button — Apple Music path]
    └──requires──> [NowPlayingMonitor's existing player-allowlist identification]
                       (must know "this is Apple Music, not Spotify" to route to AppleScript)
    └──requires──> [New Automation permission: NSAppleEventsUsageDescription entitlement/Info.plist key]

[Like button — Spotify path]
    └──requires──> [Spotify Developer Dashboard app registration (client ID) — one-time setup, done ahead of code]
    └──requires──> [OAuth Authorization Code + PKCE login flow, `user-library-modify` scope]
    └──requires──> [Keychain-backed token storage + refresh — same pattern as the existing PolarLicenseService's Keychain use]
    └──requires──> [Spotify desktop app's distributed-notification track URI (to avoid the fuzzy-search anti-feature)]

[Output switcher panel]
    └──requires──> [CoreAudio device enumeration: kAudioHardwarePropertyDevices]
    └──requires──> [CoreAudio default-output set: kAudioHardwarePropertyDefaultOutputDevice]
    └──enhances(reuses)──> [Phase 39's AudioObjectSetPropertyData volume self-drive code — same primitive, new call site]
    └──enhances(reuses)──> [Phase 39's event-driven CoreAudio listener pattern (no polling), same shape as VolumeReader]

[Drag-to-promote accelerator] ──enhances──> [Output switcher panel tap-to-select]
    (must not replace it — see anti-feature above)

[Like button (either path)] ──shares-UI-slot-with──> [Existing transport controls row]
    (star sits LEFT of play/pause/next/prev; speaker icon sits RIGHT — both are new children of the same HStack,
     no layout conflict, but widen the Now Playing expanded content and may need the same "island grows a few pt"
     treatment already applied to this milestone's Calendar quick-add work)
```

### Dependency Notes

- **Both Like-button paths require `NowPlayingMonitor`'s existing player identification** (already distinguishes Spotify vs Apple Music for the allowlist) — extend it with a routing seam (e.g. a `LikeService` protocol with two concrete implementations) rather than branching inline, mirroring the project's own established "one-file swap if Apple/Spotify breaks it" isolation principle already used for `NowPlayingMonitor` itself.
- **The output switcher is a near-pure extension of Phase 39's CoreAudio work**, not a new subsystem — the volume-set primitive, the event-driven listener pattern, and the Settings-toggle/kill-switch philosophy (self-drive with passthrough fallback) all transfer directly. The genuinely new code is device enumeration + the picker UI, not the audio plumbing.
- **The Spotify like path is the single biggest complexity/risk driver of either feature** — it is the only piece of this candidate scope that introduces a brand-new external network dependency (Spotify's OAuth servers), a brand-new credential-registration step (Spotify Developer Dashboard), and a brand-new long-lived-secret storage concern (refresh tokens in Keychain), none of which the rest of the app currently has (MediaRemote/CoreAudio/EventKit/WeatherKit are all local-or-Apple-first-party).

## MVP Definition

### Launch With (v1 of this scope)

- [ ] Apple Music like/love write-back via AppleScript Apple Event — low-medium complexity, no network dependency, matches Droppy's own shipped scope, closes the parity gap with the cited competitor
- [ ] Output switcher panel: volume slider (real CoreAudio control) + device list, current device highlighted on top, **tap-to-select** switches output — matches 100% of found precedent (macOS Control Center, iOS AirPlay/Now-Playing picker, SoundSource)
- [ ] Like button hidden/disabled (not fake-active) when the playing app isn't Apple Music, until/unless Spotify support ships — avoids a broken or fake-local-only heart, the exact failure mode TheBoringNotch's users are currently filing bugs about

### Add After Validation (v1.x)

- [ ] Spotify like/save write-back via OAuth PKCE + `user-library-modify`, sourcing the track URI from Spotify's own distributed notification (not fuzzy search) — ship once the Apple Music path and the OAuth/Keychain plumbing pattern (already precedented by `PolarLicenseService`) are both proven
- [ ] Drag-to-promote as an *optional* accelerator layered on top of the already-shipped tap-to-select in the output panel

### Future Consideration (v2+)

- [ ] Persisted "recently used outputs" ordering / quick-toggle between two known devices (a commonly requested BetterTouchTool-style workflow found in research) — defer until the basic switcher is proven in daily use

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Apple Music like/love write-back | MEDIUM-HIGH | LOW-MEDIUM | P1 |
| Output switcher (tap-to-select, volume slider, live device list) | HIGH | MEDIUM | P1 |
| Spotify like/save write-back | HIGH (bigger differentiator than Apple Music, since two named competitors visibly don't have it working) | MEDIUM-HIGH | P2 |
| Drag-to-promote accelerator in output panel | LOW-MEDIUM (delight, not function) | MEDIUM | P3 |

**Priority key:**
- P1: Ship this pass — low/medium cost, closes a real, verified competitive gap
- P2: Ship once P1's plumbing patterns (OAuth/Keychain, AppleScript automation-permission UX) are proven
- P3: Nice to have, layer on only after tap-to-select is shipped and working

## Competitor Feature Analysis

| Feature | TheBoringNotch | Droppy | Islet's Planned Approach |
|---------|-----------------|--------|---------------------------|
| Like/love button | Attempted, currently confirmed broken/invisible on Spotify per a live open GitHub issue (#929) — no confirmation it was ever a real write-back vs a UI stub | Apple Music "love tracks" explicitly shipped; Spotify explicitly scoped out (only playback/visualizer/album-art claimed) | Ship the same split deliberately and correctly: real AppleScript write-back for Apple Music now, real OAuth write-back for Spotify as a fast-follow — beating both named competitors by having a working Spotify path at all |
| Audio output switching | Not found in research | Not found in research (Droppy's HUD suite covers volume/brightness/AirPods-connect, not output routing) | Genuinely novel among the notch-app category researched — closest real precedent is Rogue Amoeba's SoundSource (a separate, non-notch menu-bar utility), not another notch app |

## Tap-vs-Drag Recommendation (explicit answer)

**Recommendation: tap-to-select is the primary and only required mechanism.** Every precedent examined — macOS's own Control Center Sound module (the literal same "volume slider + device list, current highlighted" layout the milestone spec describes), the iOS Control Center AirPlay/Now-Playing device picker, and SoundSource (the established third-party Mac output-routing tool) — uses a single tap/click on the target device to switch to it. None use drag-to-reorder as the switching trigger. Using drag as the *sole* selection mechanism would be a genuinely novel interaction with no user-familiarity precedent, and it conflates two distinct actions (reordering a list for viewing vs. causing a real system side effect) — an accidental-action risk class this project has already been careful to avoid elsewhere (e.g. Phase 34's drag-target redesign added drag *precision* to an *intentional*, already-in-flight file drag; it did not repurpose drag as a stand-in for tap on an otherwise-static list).

Ship tap-to-select as the real mechanism; if the "device visibly slides to the top" polish from the original spec is still wanted, animate that as the **visual result** of the tap (the same `matchedGeometryEffect`-driven language already used elsewhere in the app) rather than as something the user must manually drag to cause. A drag gesture can be added later, purely as an optional accelerator layered on top of a working tap path — never as a replacement for it.

## Sources

- [TheBoredTeam/boring.notch Issue #929 — "Like button for Spotify don't show up / doesn't work"](https://github.com/TheBoredTeam/boring.notch/issues/929) — MEDIUM (primary-source GitHub issue, confirms real reliability problems in a direct open-source competitor; does not confirm the original implementation's mechanism)
- [1of1Adam/Droppy GitHub README](https://github.com/1of1Adam/Droppy) — MEDIUM-HIGH (project's own repeatedly-cited competitor; explicit "love tracks" claim for Apple Music, explicit absence of the same claim for Spotify)
- [Apple Music API / MusicKit ratings endpoint (PUT /v1/me/ratings/songs/{id})](https://developer.apple.com/documentation/applemusicapi/) — HIGH (official Apple docs)
- Apple Developer Forums thread 694200, "Add songs to Library in Music?" — MEDIUM (community report of a real AppleScript-add-to-library bug relevant to the "loved" edge case)
- Spotify Community thread, "Applescript 'starred' property returns Error" — MEDIUM-HIGH (multiple corroborating reports that Spotify's AppleScript dictionary has no working local like/save capability)
- [Spotify Web API — Save Tracks for Current User endpoint](https://developer.spotify.com/documentation/web-api/reference/) and [Authorization Code with PKCE Flow docs](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) — HIGH (official Spotify docs; confirms `user-library-modify` scope and the OAuth PKCE flow needed)
- `com.spotify.client.PlaybackStateChanged` distributed-notification pattern (multiple independent open-source references, e.g. `andrehaveman/spotify-node-applescript`, a public loretoparisi gist) — MEDIUM (WebSearch-corroborated across multiple independent community sources, not an official Spotify doc — the one claim in this research flagged for a local spike before relying on it)
- [Apple Support — "Change the sound output settings on Mac"](https://support.apple.com/guide/mac-help/change-the-sound-output-settings-mchlp2256/mac) and [Control Center on Mac](https://support.apple.com/guide/mac-help/quickly-change-settings-mchl50f94f8f/mac) — HIGH (official Apple docs, confirms tap/click-to-select pattern in the system's own Sound module)
- [Rogue Amoeba SoundSource manual — Menu Bar Controls](https://rogueamoeba.com/support/manuals/soundsource/?page=menubarcontrols) — HIGH (official product manual, confirms click-to-select + slider pattern in the closest real third-party precedent)
- iMore / iPhoneLife coverage of the iOS Control Center AirPlay/Now-Playing picker — MEDIUM (secondary sources, consistent with each other and with Apple's own documented tap-to-select behavior)
- `.planning/PROJECT.md` — Phase 39 (Volume & Brightness HUD, CoreAudio self-drive precedent), Phase 38 (Focus Mode Automation-permission precedent), Phase 12 (`PolarLicenseService` Keychain-token precedent) — HIGH (this project's own shipped, verified code)

---
*Feature research for: Now Playing "like" write-back + audio output switcher, Islet candidate v1.7+ scope*
*Researched: 2026-07-19*
