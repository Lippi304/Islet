# Stack Research — Now Playing: Favorite/Like + Audio Output Switcher

**Domain:** Native macOS notch-overlay utility (Islet) — stack additions for 2 new Now Playing expanded-view capabilities
**Researched:** 2026-07-19
**Confidence:** HIGH for CoreAudio device switching/volume, AppleScript Music `loved` property, and `ASWebAuthenticationSession` (official docs + multiple corroborating sources). MEDIUM for the exact Spotify Web API endpoint shapes — official docs fetched directly, but the Feb 2026 endpoint migration is very recent and worth re-verifying at plan/execute time.

This is **not** a greenfield stack doc — it covers only what's new for these 2 capabilities. Nothing here replaces or touches the existing validated stack (SwiftUI/AppKit shell, `mediaremote-adapter`/`NowPlayingMonitor`, `VolumeReader`/`BrightnessReader`/`OSDInterceptor` CoreAudio+DisplayServices integration from Phase 39). See `CLAUDE.md` for that baseline.

## Recommended Stack

### 1. "Liked/favorited" write-back to Spotify or Apple Music

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **Spotify Web API — `PUT /me/library` / `GET /me/library/contains`** | Current (post Feb-2026 migration) | Save/check a track in the user's Spotify "Liked Songs" | The **only** way to genuinely write to Spotify's library. Spotify's local AppleScript dictionary has never exposed a like/save command — a 2020 community feature request asking for exactly this was never fulfilled, and it's still absent. The old `PUT /me/tracks` / `GET /me/tracks/contains` are deprecated; sibling "contains" endpoints for other content types were already **removed outright** in the Feb 2026 API changes — build against the new URI-based endpoints, not the deprecated ID-based ones. Required scopes: `user-library-modify` (save), `user-library-read` (check current state). |
| **`AuthenticationServices` — `ASWebAuthenticationSession`** | Ships with macOS (10.15+) | OAuth 2.0 Authorization Code + PKCE login flow for the Spotify Web API | Apple's purpose-built, system-managed browser-sheet API for exactly this. Shares cookies with the user's default browser for instant re-auth if already logged into Spotify; avoids the abuse-detection risk and reinvention of a hand-rolled `WKWebView` login form. No third-party OAuth library needed. |
| **PKCE (no client secret)** | — | Spotify auth flow variant | Spotify's implicit grant flow is deprecated. PKCE needs only a public Client ID — critical for this project specifically because it's unsandboxed and direct-distributed (not App-Store-reviewed): a client secret baked into the shipped `.app` binary would be trivially extractable via `strings`/disassembly. PKCE avoids needing one at all. |
| **`NSAppleScript`** (Foundation, ships with macOS) | — | (1) Set Apple Music's `loved` property on the current track; (2) read Spotify's `id of current track` (`spotify:track:XXXX`) to get the track ID without a Search-API round-trip | Both Spotify and Apple Music remain independently AppleScript-scriptable per-app automation surfaces, distinct from MediaRemote. No dependency — same "use the tiny native surface directly" precedent this project already applies to IOKit/IOBluetooth. Must run off the main thread (a call can block if the target app is unresponsive) and must handle `errAEEventNotPermitted` (-1743) if Automation permission was denied/revoked. |

**Integration point:** a new `NowPlayingLikeService` (or similar), isolated behind its own small protocol the same way `NowPlayingMonitor` isolates the MediaRemote bridge — the two write-back mechanisms (Spotify OAuth+REST vs. Apple Music AppleScript) are structurally unrelated, so branch on the current source inside this one seam rather than threading an if/else through the UI layer.

**Decision this needs (flag for discuss-phase):** the Spotify OAuth flow needs a one-time app registration on the Spotify Developer Dashboard (free) to get a Client ID, plus deciding the redirect-URI custom scheme (e.g. `com.<team>.islet://spotify-callback`) — this is a real external setup step, not just code, and should be called out explicitly at plan time (same category as the existing Apple Developer account / Polar.sh setup steps).

**Known caveat to design around:** `loved of current track` for Apple Music is confirmed **broken for tracks not yet in the user's local library** (Apple Music catalog/streaming-only tracks) — on the current macOS Tahoe 26.0.0 public release this throws an error rather than silently failing; it works fine for tracks already in the library. The star button must catch this and disable/hide itself (or show a subtle "add to library first" affordance) rather than assume success — this mirrors the project's existing "degrade silently on permission/capability gaps" convention (WeatherKit, EventKit, Focus Mode).

### 2. Audio-output-device switcher + per-device volume

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **CoreAudio (Audio Hardware, C API) — `kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultOutputDevice`** | Ships with macOS | Enumerate audio output devices; get/set the system's active output device | Same framework `VolumeReader.swift` already uses — this is a direct extension of existing code, not a new integration point. `kAudioHardwarePropertyDevices` lists every `AudioObjectID` on the system; filter to output-capable ones via channel count under scope `kAudioObjectPropertyScopeOutput` (a device with zero output channels, e.g. a mic-only input, is excluded). Writing `kAudioHardwarePropertyDefaultOutputDevice` is exactly what dragging a device to the top position should do. |
| **AudioToolbox — `AudioHardwareServiceGetPropertyData`/`SetPropertyData` with `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume`** | Ships with macOS | Get/set a specific output device's overall volume (the thick slider) | The "virtual master volume" property abstracts away per-channel volume control. Some output devices (notably some USB/Bluetooth ones) don't expose a literal master channel and only respond correctly through the `AudioHardwareService` entry points, not the plain `kAudioDevicePropertyVolumeScalar` + `AudioObjectSetPropertyData` pair used for the default device today — use the Service variant for this feature to avoid a device-specific edge case. |
| **`AudioObjectAddPropertyListenerBlock`** on `kAudioHardwarePropertyDevices` + `kAudioHardwarePropertyDefaultOutputDevice` | Ships with macOS | Live-update the device list and the "current output" highlight when devices connect/disconnect, or the user changes output elsewhere (Control Center, System Settings) | Same event-driven pattern already used for IOKit power-source and Bluetooth notifications elsewhere in this app — no polling loop needed. |

**Integration point:** extend the existing CoreAudio surface (`VolumeReader.swift`) rather than introducing a parallel audio module — the new device-enumeration/switching code and the existing single-device volume-read code both live in the same framework and can share the `AudioObjectID` plumbing.

**Decision this needs (flag for discuss-phase):** the native "Sound Output" switcher (menu bar / Control Center) also flips `kAudioHardwarePropertyDefaultSystemOutputDevice` (system alert sounds) in lockstep with the main output device, unless the user has separately configured alert sounds to a different device. Recommendation: this feature should set only `kAudioHardwarePropertyDefaultOutputDevice` (matches "switch what I'm listening to," the actual feature intent) and leave the system-sound default alone, so it never silently overrides a user's separate alert-sound routing choice — confirm this matches user expectations before building.

## Installation

No new Swift Package Manager dependencies are required for either feature — everything above ships with the macOS SDK (`AuthenticationServices`, `Foundation`/`NSAppleScript`, `CoreAudio`, `AudioToolbox`). Only project configuration changes:

```xml
<!-- Info.plist additions -->
<key>NSAppleEventsUsageDescription</key>
<string>Islet needs permission to mark songs as liked in Spotify/Apple Music.</string>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.yourteam.islet</string></array>
  </dict>
</array>
```

```swift
// Link (CoreAudio/AudioToolbox likely already linked for VolumeReader):
import CoreAudio
import AudioToolbox
import AuthenticationServices
```

```bash
# External, one-time, not code:
# Register a free app at https://developer.spotify.com/dashboard
#  -> get Client ID (no secret needed for PKCE)
#  -> add the custom-scheme redirect URI to the app's allow-listed Redirect URIs
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| Spotify Web API (`PUT /me/library`) via `ASWebAuthenticationSession` + PKCE | Spotify iOS/macOS "App Remote" SDK (`SpotifyiOS.framework`) | Never for this feature — App Remote is a real-time playback-control SDK (duplicates what MediaRemote already gives Islet) and has **no** library-save/like capability at all. Not a substitute, regardless of preference. |
| AppleScript `loved` property for Apple Music | AXUIElement UI-scripting of Music's/Spotify's own heart/star button | Only as an absolute last resort. Fragile (breaks on any UI redesign), requires the broad system Accessibility permission (a much scarier prompt for users than per-app Automation), and silently no-ops if the target window isn't actually rendered/frontmost. Spotify has no such button reachable this way that maps to a real save anyway, since the underlying command doesn't exist. |
| Direct CoreAudio HAL calls (extend `VolumeReader.swift`) | `SimplyCoreAudio` (rnine/SimplyCoreAudio) | Only if the project's dependency philosophy shifts — it's **archived/unmaintained since March 2024**, and the surface actually needed here (list devices, get/set default, get/set volume, listen for changes) is small enough that the project's existing precedent ("no third-party Bluetooth library, IOKit surface is tiny, use it directly") applies just as well here. |
| `ASWebAuthenticationSession` for Spotify OAuth | Manual `WKWebView` login form | Never for a real OAuth provider login — reimplements what the system API does safely, is more likely to trip Spotify's automated bot/abuse detection, and loses the shared-cookie fast-login path. |
| PKCE (Authorization Code + PKCE) | Client Credentials flow | Client Credentials only authenticates the *app*, not a *user* — it cannot write to a specific user's library under any circumstance. Not viable for this feature. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| `PUT /me/tracks` / `GET /me/tracks/contains` (Spotify) | Deprecated as of Spotify's February 2026 Web API changes; sibling "contains" endpoints for other content types were already removed outright — building against the old shape risks targeting something Spotify may remove next. | `PUT /me/library` / `GET /me/library/contains` (URI-based, unified across content types) |
| Spotify Implicit Grant OAuth flow | Deprecated by Spotify in favor of Authorization Code + PKCE; not recommended for new apps. | Authorization Code with PKCE |
| `SimplyCoreAudio` | Archived/read-only since March 2024 — no further fixes if a future macOS changes CoreAudio behavior. | Direct `AudioObjectGetPropertyData`/`SetPropertyData`/`AudioHardwareServiceSetPropertyData` calls, same style as the existing `VolumeReader.swift` |
| `kAudioObjectPropertyElementMaster` | Deprecated since macOS 12.0 (renamed, not just relabeled) — using the old symbol emits a build warning today and risks removal in a future SDK. | `kAudioObjectPropertyElementMain` |
| AXUIElement-driven UI automation of Spotify's/Music's heart/like button | Requires the broad Accessibility permission, breaks silently on any UI redesign, needs the target window on screen. | Spotify Web API (Spotify) / AppleScript `loved` property (Apple Music) |
| Baking a Spotify Client Secret into the shipped binary | This is an unsandboxed, direct-distributed, notarized (not App-Store-reviewed) app — an embedded secret is trivially extractable, and Spotify's PKCE flow doesn't require one. | PKCE public-client flow (Client ID only) |
| Assuming `loved of current track` always succeeds for Apple Music | Confirmed broken for tracks **not in the user's local library** on the current Tahoe 26.0.0 public release (throws rather than silently failing); works for library tracks. | Catch the error explicitly; disable/hide the star rather than assume success |

## Stack Patterns by Variant

**If the current Now Playing source is Spotify:**
- Use the Web API path end-to-end: AppleScript `id of current track` → parse the `spotify:track:XXXX` URI → `PUT /me/library` (scope `user-library-modify`) to like, `GET /me/library/contains` (scope `user-library-read`) to show the star's current filled/unfilled state whenever the expanded view opens.
- Because Spotify's local scripting surface has no like/save command at all — the Web API is the only path.

**If the current Now Playing source is Apple Music:**
- Use `NSAppleScript` directly against the `Music` app (`tell application "Music" to set loved of current track to true`) — no OAuth, no network call, no Developer Dashboard registration needed.
- Because Apple Music's local scripting surface already supports this natively; adding OAuth here would be pure over-engineering.
- Guard for the library-membership caveat above; degrade to a disabled/hidden star, not a silent no-op or crash.

**If the current source is neither Spotify nor Apple Music (outside the existing allowlist):**
- Hide the favorite button entirely.
- Because this mirrors the existing `NowPlayingMonitor` allowlist-gating pattern already established for NOW-01 — no new precedent needed.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|------------------|-------|
| `ASWebAuthenticationSession` | macOS 10.15+ | Solid on the project's 15.0+ floor and current Tahoe 26 dev hardware. |
| `PUT /me/library` / `GET /me/library/contains` | Spotify Web API, current as of Feb 2026 | Very recently introduced — re-verify against Spotify's changelog at plan/execute time in case of further churn; treat the old `/me/tracks*` family as already-deprecated, not a safe fallback. |
| Spotify OAuth redirect URI rules | Enforced for all apps since Nov 2025 | Custom URL schemes (`com.example://callback`) remain explicitly supported; plain (non-loopback) `http://` redirects are no longer accepted — must be HTTPS or a loopback address (`127.0.0.1`/`[::1]`); bare `localhost` is rejected. |
| `NSAppleScript` "loved" property (Music) | Current through macOS Tahoe 26 | Confirmed working for library tracks; confirmed erroring for non-library (streaming-only) tracks as of the Tahoe 26.0.0 public release — build the guard, don't assume. |
| `kAudioObjectPropertyElementMain` | macOS 12.0+ | Well within the project's 15.0+ floor; use this symbol, not the deprecated `...ElementMaster`. |

## Sources

- Spotify for Developers — `developer.spotify.com/documentation/web-api/reference/save-tracks-user` (fetched directly; confirms deprecation + pointer to Save Items to Library). HIGH
- Spotify for Developers — `developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide` (fetched directly; confirms exact new `PUT /me/library` / `GET /me/library/contains` shapes and scopes). HIGH
- Spotify for Developers — `developer.spotify.com/documentation/web-api/concepts/redirect_uri` and the linked Feb 2025 security-requirements blog post (fetched directly; confirms custom schemes remain allowed, HTTP/loopback rules). HIGH
- Spotify Community — "Feature Request: Add 'Like song' as a method to applescript" (confirms no native Spotify AppleScript like/save command exists). MEDIUM-HIGH (community thread, but consistent with the absence of any such command in Spotify's published AppleScript dictionary)
- Chris Miller — "Get link to currently playing Spotify track via AppleScript" + multiple corroborating GitHub examples (`id of current track` → `spotify:track:...`). MEDIUM-HIGH (multiple independent sources agree)
- Apple Developer Forums threads (669239, 798267) — confirm Music.app's `loved` property works for library tracks but errors for streaming-only tracks, including a report specific to Tahoe 26.0.0. MEDIUM-HIGH (developer forum reports, consistent across multiple threads/years)
- Apple Developer Documentation — `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioHardwarePropertyDefaultSystemOutputDevice`, `kAudioHardwarePropertyDevices` reference pages. HIGH
- `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` Apple Developer Documentation + community CoreAudio Swift gists corroborating usage pattern. MEDIUM-HIGH
- SDL/rtaudio/QEMU deprecation-warning threads — confirm `kAudioObjectPropertyElementMaster` → `kAudioObjectPropertyElementMain` rename in the macOS 12.0 SDK. HIGH (compiler deprecation attribute text quoted directly)
- Apple Developer Documentation — `ASWebAuthenticationSession` reference + Kodeco/Andy Ibanez tutorials corroborating the custom-scheme redirect + `ASWebAuthenticationPresentationContextProviding` pattern. HIGH
- GitHub — `rnine/SimplyCoreAudio` repository (confirms archived March 23, 2024 status directly in repo metadata). HIGH

---
*Stack research for: Islet — "liked song" write-back + audio-output-device switcher (Now Playing expanded view)*
*Researched: 2026-07-19*
