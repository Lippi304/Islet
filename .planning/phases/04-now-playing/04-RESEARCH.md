# Phase 4: Now Playing - Research

**Researched:** 2026-06-27
**Domain:** macOS now-playing integration via the `mediaremote-adapter` Swift wrapper; SwiftUI gated looping animation; XcodeGen SPM + Embed&Sign
**Confidence:** HIGH (the adapter's actual source was read line-by-line; XcodeGen syntax cited from ProjectSpec; build toolchain probed on-device)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** v1 recognizes ONLY Spotify (`com.spotify.client`) and Apple Music (`com.apple.Music`) via a **bundle-ID allowlist**. Any other source (YouTube tab, Netflix, etc.) is ignored — no glance, no controls. (Intentionally narrows NOW-01's "any app" wording.)
- **D-02:** While PLAYING, the collapsed island shows the **wings layout**: small album-art thumbnail on the LEFT wing, animated equalizer "now playing" bars on the RIGHT wing. Reuses the Phase-3 wings frame/skeleton.
- **D-03:** Bars are **decorative / synthetic** — a simple looping animation, NOT a real audio tap.
- **D-04:** Bars animate **ONLY while actively playing**. First continuous (looping) animation in the app, a scoped exception **gated on `isPlaying`**. Idle CPU ~0% guarantee still holds for the truly-idle (no-media) state and for paused (D-05).
- **D-05:** PAUSED (track still loaded) → wings stay visible but bars **freeze / go static**. No looping animation while paused.
- **D-06:** Paused + no interaction for ~15s → short exit animation, then the now-playing display disappears → idle pill. Implemented as a **single one-shot `DispatchWorkItem`** (mirrors charging `dismissWorkItem`/`graceWorkItem` — NO repeating timer). Resuming playback cancels it. (Whether hover resets the 15s is discretion.)
- **D-07:** STOPPED / no media → short exit animation ("music stopped"), then display disappears → idle pill. (Distinct from pause: stop removes immediately after the cue; pause lingers up to 15s.)
- **D-08:** Expanded layout: album art LEFT (square, rounded); Title+Artist stacked RIGHT (Title bold, Artist secondary/grey); animated equalizer bars TOP-RIGHT; control row along the bottom. Reached via the existing click-to-expand downward morph.
- **D-09:** Control row (v1) = `⏪ ⏯ ⏩` only, centered. Reserve LEFT slot (Shuffle) + RIGHT slot (Repeat) for v2; **Star/favorite removed entirely**. Reserve vertical room above controls for the future seek bar.
- **D-10:** Metadata = Title + Artist only (no album name, no source-app icon).
- **D-11:** No media playing (API healthy) + user expands → expanded view shows the existing Phase-2 date/time readout as the "no music" state.
- **D-12:** API blocked / adapter unhealthy (launch-time health check fails) → on expand, show **"Now Playing nicht verfügbar"** in place of controls. Distinct from "nothing playing".
- **D-13:** API drops mid-session (adapter dies while a track showed) → **immediately clear state** back to the idle pill. The "nicht verfügbar" indication appears only on the NEXT expand. No mid-session "unavailable" splash.
- **D-14:** Plugging in while music plays → charging splash briefly wins (~3s, carries Phase-3 D-11 if-ordering), then returns to the now-playing wings (NOT to empty). Phase 4 only guarantees charging-vs-nowplaying-vs-interaction don't glitch.
- **Locked by ROADMAP + CLAUDE.md:** single isolated service + launch-time health check, **consuming the adapter's streamed output (NOT re-spawning per query)**, callbacks on the main thread; uses `ejbills/mediaremote-adapter` over `ungive/mediaremote-adapter` (NOT direct dlopen, NOT nowplaying-cli); album art loads async with a placeholder; survives app restart; hidden in fullscreen/clamshell via `updateVisibility()`.

### Claude's Discretion
- The now-playing service/model abstraction — mirror the Phase-3 quartet (pure seam + `@Published` model + thin IPC glue + view branch). Keep it now-playing-specific with a clean seam, isolated behind one protocol (one-file swap if Apple breaks it). NOT a general resolver (Phase 6).
- Exact bar count (3–5), bar tempo/curve, frozen-paused visual.
- Exact expanded geometry, art corner radius/size, fonts (start from Phase-3 rounded-system vocabulary), transport SF Symbols + sizing.
- Album-art async load mechanism + placeholder while art loads.
- Whether hover/interaction resets the 15s pause timeout (likely yes — consistent with charging D-10).
- Spring/duration tuning (seeds: response ≈ 0.35, dampingFraction ≈ 0.65). Entrance/exit ("music stopped") cue specifics.
- The pure-logic seam (TDD): total function mapping now-playing info → presentation (`playing`/`paused`/`stopped`/`unavailable`, filtered by D-01 allowlist), unit-testable in ms.

### Deferred Ideas (OUT OF SCOPE)
- **Seek / progress bar** (NOW-04, v2) — reserve room, do not build. (Implies a running timer while panel open — note when it lands.)
- **Shuffle + Repeat toggles** (v2) — reserve shuffle-left / repeat-right slots. Needs research the adapter can both SEND and READ BACK the mode before shipping even in v2.
- **Sneak-peek on track change** (NOW-05, v2) + its on/off Settings toggle (Phase 6 / APP-03).
- **Star / favorite button — DROPPED entirely** (not reachable; would be a dead button).
- **Color-adaptive tint** (NOW-06) and **waveform on album art** (NOW-07) → v2.
- **Source allowlist expansion via Settings** → Phase 6 possibility, not v1.
- **General multi-activity priority resolver** (charging + media + device) → Phase 6 (COORD-01).
- **Clicking album art to open source app**, hover-volume, extra gestures → not v1.
- **Real audio-tap visualizer** → out of scope (bars are decorative/synthetic).
- **Settings UI** (source allowlist, sneak-peek toggle, accent/theme) → Phase 6.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOW-01 | Media playing shows album art, title, artist | `TrackInfo.Payload` exposes `title`, `artist`, `bundleIdentifier`, and a pre-decoded `artwork: NSImage?` (Standard Stack / Code Examples). D-01 allowlist filters `bundleIdentifier` to `com.spotify.client` + `com.apple.Music` in the pure seam. |
| NOW-02 | Play/pause, next, previous from expanded island | `MediaController.togglePlayPause()` / `play()` / `pause()`, `nextTrack()`, `previousTrack()` — all verified present (Standard Stack). Commands are sent down the SAME persistent `loop` process's stdin (no re-spawn). |
| NOW-03 | Survives restart, degrades gracefully when API blocked/unavailable | Restart: `startListening()` emits the current session immediately. Graceful: `onTrackInfoReceived(nil)` for no-media, `onListenerTerminated` for mid-session death (D-13), a one-shot `getTrackInfo` probe at launch for the health check (D-12). Pure seam maps all of this to a `.unavailable` / cleared presentation. |
</phase_requirements>

## Summary

The single highest-risk integration — the MediaRemote bridge — is well-understood after reading the actual source of `ejbills/mediaremote-adapter` (the Swift wrapper) and `ungive/mediaremote-adapter` (the perl/framework engine underneath). The good news for the planner: **the wrapper already does most of the hard process work**. It spawns ONE persistent `/usr/bin/perl … loop` child, parses its newline-delimited JSON stdout, **already hops every callback to `DispatchQueue.main.async` internally**, **already self-restarts** the child every 100 events to dodge memory growth, and sends transport commands down that same child's stdin (falling back to a one-shot spawn only if the loop is dead). This directly satisfies success-criterion-4 ("consume the stream, not re-spawn") — but it also means **two assumptions in CONTEXT.md/CLAUDE.md need correcting**: the consumer does NOT itself need to hop callbacks to main (the wrapper already did), and the cited streaming method name is wrong (`getTrackInfo {…}` is the ONE-SHOT fetch; the stream is `onTrackInfoReceived` + `startListening()`).

The trickiest remaining design problem is the **launch-time health check (D-12)**. The `ungive` engine exposes a dedicated `test` subcommand for exactly this — but the `ejbills` Swift wrapper does **not** surface it. So the practical Swift-level health check must be synthesized from the APIs the wrapper *does* expose: a one-shot `getTrackInfo` probe at launch (it returns `nil` on "no media" AND on a failed/blocked process), combined with watching `onListenerTerminated`. Crucially, `onListenerTerminated` only fires when `eventCount != 0`, so a child that dies *before emitting any line* (the classic "entitlement denied" failure) will NOT call it — the health signal there is the absence of any callback within a short timeout, plus the one-shot probe result. This subtlety drives the D-12 vs D-13 distinction and must be planned explicitly.

The decorative equalizer bars (D-02/D-03/D-04) are a textbook SwiftUI `repeatForever` animation with one hard constraint: the animation clock must genuinely stop when `isPlaying` is false (idle-CPU guarantee). The reliable pattern is to drive each bar's height from an `@State` flag and apply `.animation(...)` / `withAnimation` keyed on that flag, and — the actual trap — to **remove the repeating animation entirely** (not just freeze a value) when paused, because a `.repeatForever` modifier left attached keeps SwiftUI's render loop alive even when the visible value looks static.

**Primary recommendation:** Add `ejbills/mediaremote-adapter` to `project.yml` pinned to a **revision/branch** (the repo has NO version tags), product `MediaRemoteAdapter`, `embed: true` + `codeSign: true`. Build a `NowPlaying*` quartet mirroring the Phase-3 `Power*` quartet: a pure `NowPlayingPresentation` seam (TDD, allowlist + state classification), a `@Published NowPlayingState`, a thin `NowPlayingMonitor` wrapping `MediaController` (start/stop/health-check, NO extra main-hop), and `NotchPillView` branches. Synthesize the launch health check from a one-shot `getTrackInfo` probe + `onListenerTerminated`.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ejbills/mediaremote-adapter` (Swift wrapper) | **no tags — pin to revision** `cf30c4f` (master, committed 2026-06-02) or branch `master` | `MediaController` class: stream now-playing, send transport, decode `TrackInfo` | The canonical modern bridge; TheBoringNotch credits this lineage. CONTEXT.md + CLAUDE.md lock it. `[VERIFIED: gh api repos/ejbills/mediaremote-adapter — Package.swift + source read]` |
| `ungive/mediaremote-adapter` (engine, transitive) | v0.7.6, 2026-05-11, BSD-3 | The perl script + `MediaRemoteAdapter.framework` that bypasses the 15.4 entitlement | Pulled in as the dynamic-library resource by the Swift wrapper; the `com.apple.perl` bundle-id is what's entitled to MediaRemote. `[VERIFIED: github.com/ungive/mediaremote-adapter releases]` |
| SwiftUI | macOS 14 SDK | Equalizer bars (`repeatForever`), expanded layout, art rendering | Project standard. `[CITED: CLAUDE.md]` |
| AppKit (`NSImage`) | macOS SDK | Artwork arrives pre-decoded as `NSImage?` | The wrapper decodes base64 → `NSImage` for you. `[VERIFIED: TrackInfo.swift source]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation `Process`/`Pipe` | SDK | Already used INSIDE the wrapper; you do not touch it directly | n/a — wrapper-internal |
| Combine | optional | Not needed — `@Published`/`ObservableObject` suffices (matches Phase-3) | Skip; CLAUDE.md says plain `ObservableObject` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Stream via `onTrackInfoReceived` + `startListening()` | `getTrackInfo {…}` one-shot per query | ONE-SHOT VIOLATES success-criterion-4 (re-spawns perl per query). Use the one-shot ONLY for the launch health probe, never for live updates. `[VERIFIED: MediaController.swift]` |
| Pin wrapper by revision/branch | Pin by version `from:` | The wrapper has **zero git tags** — `from:`/`majorVersion:` will fail to resolve. Must use `revision:` or `branch:`. `[VERIFIED: gh api .../tags returns empty]` |

**Installation (XcodeGen `project.yml` — the verified syntax):**
```yaml
# At project root, add a top-level packages: block:
packages:
  MediaRemoteAdapter:
    url: https://github.com/ejbills/mediaremote-adapter
    revision: cf30c4f1af29b5829d859f088f8dbdf12611a046   # no tags exist; pin a known-good commit
    # branch: master   # alternative — but a pinned revision is reproducible

# Under targets.Islet, add to dependencies: (the target currently has NONE):
targets:
  Islet:
    dependencies:
      - package: MediaRemoteAdapter
        product: MediaRemoteAdapter
        embed: true        # Embed & Sign — the framework is a runtime resource, not just link-time
        codeSign: true     # codeSignOnCopy — required for hardened-runtime + later notarization
```
Then `xcodegen generate`. `[CITED: XcodeGen ProjectSpec.md — packages/dependencies/embed/codeSign]` `[VERIFIED: project.yml currently has no packages and Islet target has no dependencies]`

**Version verification (run at plan time per the STATE.md blocker "verify against currently installed macOS"):**
```bash
gh api repos/ejbills/mediaremote-adapter/commits/master --jq '.sha + "  " + .commit.committer.date'
gh api repos/ungive/mediaremote-adapter/releases/latest --jq '.tag_name + "  " + .published_at'
```
Latest verified: wrapper master `cf30c4f` (2026-06-02); engine v0.7.6 (2026-05-11). `[VERIFIED: gh api 2026-06-27]`

## Architecture Patterns

### Recommended Project Structure (the `NowPlaying*` quartet, mirroring `Power*`)
```
Islet/Notch/
├── NowPlayingPresentation.swift   # PURE seam: TrackSnapshot → NowPlayingPresentation (TDD, Foundation-only, allowlist + state)
├── NowPlayingState.swift          # @Published ObservableObject holding the current presentation (mirrors ChargingActivityState)
├── NowPlayingMonitor.swift        # THIN glue wrapping MediaController: start/stop/health-check (mirrors PowerSourceMonitor)
└── NotchPillView.swift            # EXTEND: media wings branch + media expanded layout + EqualizerBars subview
IsletTests/
└── NowPlayingPresentationTests.swift  # fixtures for the pure seam (allowlist, playing/paused/stopped/unavailable)
```

### Pattern 1: The pure presentation seam (TDD — mirrors `PowerActivity.swift`)
**What:** A Foundation-only struct + total function. The wrapper's `TrackInfo` is NOT Foundation-only (it imports AppKit for `NSImage`), so the seam takes a **lifted plain value**, not the raw `TrackInfo` — exactly as `PowerActivity` takes a lifted `PowerReading`, not the IOPS dictionary.
**When to use:** All allowlist + state-classification logic. No `NSImage`, no `Process`, no system calls → unit-testable in ms.
**Example:**
```swift
// Source: pattern derived from Islet/Notch/PowerActivity.swift (verified existing code)
import Foundation

// The minimal raw snapshot NowPlayingMonitor lifts out of TrackInfo.Payload.
// Plain values (no NSImage) so tests construct it by hand — mirrors PowerReading.
struct TrackSnapshot: Equatable {
    let bundleIdentifier: String?
    let isPlaying: Bool?       // payload.isPlaying (nil-tolerant)
    let title: String?
    let artist: String?
    let hasArtwork: Bool       // monitor sets this from payload.artwork != nil; art itself goes to the @Published model, not the seam
}

// The presentation the media view renders. `unavailable` is a SEPARATE axis (health),
// not derived from a snapshot — see the health note below.
enum NowPlayingPresentation: Equatable {
    case playing(title: String, artist: String)
    case paused(title: String, artist: String)
    case none        // healthy API, nothing playing / not an allowlisted source (D-11 date/time on expand)
}

let allowedBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]   // D-01

// TOTAL pure mapping. nil snapshot OR non-allowlisted source OR no title → .none.
func nowPlayingPresentation(from s: TrackSnapshot?) -> NowPlayingPresentation {
    guard let s,
          let bundle = s.bundleIdentifier, allowedBundleIDs.contains(bundle),   // D-01 allowlist
          let title = s.title, !title.isEmpty                                    // engine guarantees title non-null when valid
    else { return .none }
    let artist = s.artist ?? ""
    // isPlaying nil → treat as paused (track loaded but state unknown) is a planner call;
    // recommend: (s.isPlaying == true) → playing, else paused. Cover both in tests.
    return (s.isPlaying == true) ? .playing(title: title, artist: artist)
                                 : .paused(title: title, artist: artist)
}
```
**Important — `unavailable` is NOT in this seam's output.** Health/availability (D-12) is an orthogonal axis driven by the launch probe + `onListenerTerminated`, not by any single track snapshot. Model it as a separate `@Published var isHealthy: Bool` (or a top-level enum the view consults first). Keeping the snapshot-classification pure and the health-state separate keeps the seam total and avoids conflating "nothing playing" with "API blocked" — the exact distinction D-11 vs D-12 requires.

### Pattern 2: The thin monitor (mirrors `PowerSourceMonitor`) — NO extra main-hop
**What:** Wrap one `MediaController`. Set `onTrackInfoReceived`, `onListenerTerminated`, `onDecodingError`, call `startListening()`. Tear down with `stopListening()` from the controller's deinit.
**When to use:** The single IPC seam. Isolate the whole adapter behind a small protocol so an Apple break is a one-file swap (CLAUDE.md mandate).
**Example:**
```swift
// Source: derived from MediaController.swift (verified) + PowerSourceMonitor.swift (existing)
import MediaRemoteAdapter

@MainActor
final class NowPlayingMonitor {
    private let controller = MediaController()
    // onSnapshot: nil means "no media now" (engine emitted NIL). Non-nil = a track update.
    private let onSnapshot: (TrackSnapshot?, NSImage?) -> Void
    private let onTerminated: () -> Void

    init(onSnapshot: @escaping (TrackSnapshot?, NSImage?) -> Void,
         onTerminated: @escaping () -> Void) {
        self.onSnapshot = onSnapshot
        self.onTerminated = onTerminated
    }

    func start() {
        // The wrapper ALREADY DispatchQueue.main.async's every callback — do NOT add a second hop.
        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            guard let p = info?.payload else { self.onSnapshot(nil, nil); return }
            let snap = TrackSnapshot(bundleIdentifier: p.bundleIdentifier,
                                     isPlaying: p.isPlaying, title: p.title,
                                     artist: p.artist, hasArtwork: p.artwork != nil)
            self.onSnapshot(snap, p.artwork)      // artwork is a pre-decoded NSImage? — already off-thread-decoded by the wrapper
        }
        controller.onListenerTerminated = { [weak self] in self?.onTerminated() }   // D-13 mid-session death
        controller.startListening()               // spawns ONE persistent `loop` child
    }

    // mirrors PowerSourceMonitor.stop() — call from the controller's deinit
    func stop() { controller.stopListening() }    // terminates the child, clears the readability handler

    // play/pause/next/prev pass straight through (commands ride the existing child's stdin):
    func togglePlayPause() { controller.togglePlayPause() }
    func nextTrack()       { controller.nextTrack() }
    func previousTrack()   { controller.previousTrack() }
}
```

### Pattern 3: Launch-time health check (D-12) — synthesized, because the wrapper hides `test`
**What:** The wrapper does not expose `ungive`'s `test` subcommand. Synthesize health from a one-shot `getTrackInfo` at launch.
**When to use:** Once at `start()`, to set the initial `isHealthy` flag.
**Example:**
```swift
// Source: getTrackInfo semantics verified in MediaController.swift; "null/NIL on no-media,
// non-zero exit on blocked" verified in ungive README.
func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
    // getTrackInfo spawns a one-shot `get`. It calls back with nil for BOTH
    // "no media" AND "process failed". That ambiguity means a single probe cannot
    // by itself prove "blocked". Recommended planner approach (pick one, document it):
    //   (a) Treat "probe returned within timeout" as HEALTHY (process ran), and rely on
    //       onListenerTerminated for later failure. Simplest; matches D-12's coarse need.
    //   (b) If a stricter signal is needed, the planner may add a tiny test-client call to
    //       the ungive `test` subcommand directly (out of the wrapper) — heavier, defer unless (a) is insufficient.
    var settled = false
    controller.getTrackInfo { info in
        if settled { return }; settled = true
        setHealthy(true)   // a callback at all = the perl/framework chain ran (option a)
    }
    // Timeout guard: if no callback arrives quickly, the child likely failed to even run.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        if settled { return }; settled = true
        setHealthy(false)  // never heard back → treat as unavailable (D-12 "nicht verfügbar")
    }
}
```
**Health-state-machine note for the planner:**
- `isHealthy = false` at launch (probe failed/timed out) → D-12: on expand show "Now Playing nicht verfügbar".
- `isHealthy = true`, `onTrackInfoReceived(nil)` → D-11: healthy, no media → idle pill; date/time on expand.
- `isHealthy = true` then `onListenerTerminated` fires AFTER showing a track → D-13: **clear state to idle immediately**, and flip `isHealthy = false` so the NEXT expand shows "nicht verfügbar". No mid-session splash.
- ⚠️ `onListenerTerminated` only fires when `eventCount != 0` (verified in source). A child that dies before emitting any line never calls it — that case is already covered by the launch probe / the no-callback timeout.

### Pattern 4: Gated decorative equalizer bars (D-02/D-03/D-04/D-05) — idle-CPU-safe
**What:** 3–5 bars whose heights animate up/down on a `repeatForever` autoreversing animation, driven by a single `isAnimating` flag bound to `isPlaying`.
**When to use:** The right-wing glance symbol + the top-right of the expanded view.
**Example:**
```swift
// Source: standard SwiftUI repeatForever pattern; gating verified against D-04 idle-CPU constraint.
struct EqualizerBars: View {
    let isPlaying: Bool                 // D-04: the SINGLE gate
    private let barCount = 4            // discretion: 3–5
    @State private var animate = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 2.5, height: animate ? 12 : 4)
                    // ⚠️ TRAP (D-04): the animation MUST be conditional. When isPlaying is
                    // false, pass `nil` so NO repeating animation stays attached — a left-on
                    // .repeatForever keeps SwiftUI's render loop alive (CPU never returns to ~0).
                    .animation(isPlaying
                        ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.12)
                        : .default,            // a finite, non-repeating animation when stopping
                        value: animate)
            }
        }
        .onChange(of: isPlaying) { playing in
            animate = playing              // start/stop the bounce; paused freezes at the static value
        }
        .onAppear { animate = isPlaying }
    }
}
```
**Paused freeze (D-05):** when `isPlaying` flips false, `animate` flips false and the bars settle to the static height with a finite animation, then NO clock runs. Verify on-device with a CPU sample that idle CPU returns to ~0 after pausing (see Validation Architecture — this is on-device-only).

### Pattern 5: View precedence ordering (D-14) — extend the existing `if`-chain
**What:** `NotchPillView.body` currently orders `charging.activity != nil` > `interaction.isExpanded` > collapsed. Phase 4 inserts the media cases.
**Recommended order (verify against D-14 on-device):**
```swift
if let activity = charging.activity {        // D-14: charging splash briefly wins (~3s)
    wings(for: activity)
} else if interaction.isExpanded {           // expanded view — media controls OR date/time(D-11) OR "nicht verfügbar"(D-12)
    expandedContent(media: nowPlaying.presentation, healthy: nowPlaying.isHealthy)
} else if nowPlaying.presentation != .none { // media glance wings (art left / bars right) — D-02
    mediaWings(nowPlaying.presentation, art: nowPlaying.artwork)
} else {
    collapsedIsland                          // idle pill
}
```
The charging `dismissWorkItem` already clears `charging.activity` after ~3s; the body then falls through to the media wings automatically — satisfying D-14 "returns to the now-playing wings, NOT to empty" with NO new resolver. The expanded branch internally chooses media-controls / date-time / unavailable based on `presentation` + `isHealthy`.

### Anti-Patterns to Avoid
- **Re-spawning per query:** Never drive live updates with `getTrackInfo` in a loop/timer — it spawns a perl process each call (violates success-criterion-4, wastes CPU). Use `startListening()` once. `[VERIFIED: MediaController.swift]`
- **Double main-hop:** Do not wrap the wrapper's callbacks in another `DispatchQueue.main.async` — they already arrive on main. Harmless but misleading; worse, it can desync ordering with the synchronous `withAnimation` you need.
- **A second show/hide site:** Route the media glance through the existing single `updateVisibility()` (Phase-2/3 lesson) so it inherits fullscreen + clamshell hide for free.
- **A repeating timer for the 15s pause dismiss (D-06):** Use a one-shot `DispatchWorkItem` mirroring the charging `dismissWorkItem` — no recurring clock.
- **Conflating "no media" with "blocked":** Keep `isHealthy` orthogonal to the snapshot seam (Pattern 1/3), or D-11 and D-12 collapse into one state.
- **Leaving `.repeatForever` attached when paused:** keeps the render loop alive → breaks the idle-CPU guarantee (Pattern 4 trap).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spawning/parsing the perl now-playing stream | Your own `Process`/`Pipe` + newline framing | `MediaController.startListening()` | The wrapper already does buffered newline framing, NIL handling, main-hop, sigpipe-ignore, and a 100-event self-restart. `[VERIFIED: MediaController.swift]` |
| Decoding album art | base64-decode + `NSImage(data:)` yourself | `payload.artwork` (pre-decoded `NSImage?`) | The wrapper decodes `artworkDataBase64` → `NSImage` in its `init(from:)`. `[VERIFIED: TrackInfo.swift]` |
| Sending transport commands | A second perl spawn per command | `controller.play()/pause()/togglePlayPause()/nextTrack()/previousTrack()` | They write to the existing child's stdin; only fall back to a one-shot if the loop died. `[VERIFIED: MediaController.swift sendCommand]` |
| MediaRemote entitlement bypass | dlopen / nowplaying-cli | the perl-via-`com.apple.perl` trick inside the engine | Direct dlopen returns nil on 15.4+; perl carries an Apple-entitled bundle id. `[CITED: ungive/mediaremote-adapter README; LyricFever #94]` |
| Avoiding child-process memory growth | manual restart logic | wrapper's built-in `restartThreshold = 100` | Already handled; the `loop` child is recycled transparently. `[VERIFIED: MediaController.swift]` |

**Key insight:** The wrapper is doing far more than "stream JSON" — it is a small, battle-tested process supervisor. Your job is a thin adapter (lift `payload` → `TrackSnapshot` + `NSImage`, route to the pure seam + `@Published` model) and the launch health check it does NOT provide. Do not duplicate what it already does.

## Common Pitfalls

### Pitfall 1: `getTrackInfo` returning `nil` is ambiguous (no-media vs failure)
**What goes wrong:** A naive launch check treats `nil` as "blocked", flagging a perfectly healthy machine with nothing playing as "nicht verfügbar" (false D-12).
**Why it happens:** `getTrackInfo`'s readability/termination handlers both call `onReceive(nil)` for "NIL" (no media), decode failure, AND spawn failure — all collapse to `nil`. `[VERIFIED: MediaController.swift getTrackInfo]`
**How to avoid:** Treat "a callback arrived at all" as healthy (Pattern 3 option a); only "no callback within timeout" → unavailable. Document the chosen semantics in the plan.
**Warning signs:** "nicht verfügbar" appearing when music isn't playing but the API is fine.

### Pitfall 2: `onListenerTerminated` does NOT fire on a never-emitted child (D-12 vs D-13)
**What goes wrong:** Relying on `onListenerTerminated` alone for the health flag misses the "blocked from the start" case (the child dies before any line, `eventCount == 0`, callback suppressed). `[VERIFIED: MediaController.swift terminationHandler — `if self?.eventCount != 0`]`
**How to avoid:** Cover the launch-failure case with the one-shot probe + timeout (Pattern 3); reserve `onListenerTerminated` for the mid-session-drop case (D-13) where a track was already showing.
**Warning signs:** App launched with API blocked but never shows "nicht verfügbar".

### Pitfall 3: `Bundle.module` / `run.pl` not found unless the framework is truly Embed-&-Signed
**What goes wrong:** The wrapper loads `run.pl` via `Bundle.module` and locates the dylib via `Bundle(for: MediaController.self).executablePath`. If the framework is merely linked (not embedded), these resolve to nothing at runtime → silent no-op (health check correctly reports unavailable, but for the wrong reason).
**Why it happens:** `embed`/`codeSign` omitted in `project.yml`, or hand-editing the generated `.xcodeproj` (which XcodeGen overwrites). `[VERIFIED: MediaController.swift perlScriptPath/libraryPath; CITED: SPM resource-bundle issues]`
**How to avoid:** Set `embed: true` + `codeSign: true` in `project.yml`, `xcodegen generate`, never hand-edit the project. Verify the built `.app` contains `Contents/Frameworks/MediaRemoteAdapter.framework` with `run.pl` inside.
**Warning signs:** Health check always fails; no now-playing ever appears even with music playing.

### Pitfall 4: SPM version pinning fails — the wrapper has no tags
**What goes wrong:** `from: 1.0.0` / `majorVersion:` cannot resolve; `xcodegen generate` + the Xcode resolve step errors or silently produces no package.
**Why it happens:** `gh api .../tags` returns empty — zero releases. `[VERIFIED 2026-06-27]`
**How to avoid:** Pin `revision: cf30c4f…` (reproducible) or `branch: master` (tracks head — riskier). Re-verify the commit at plan time (STATE.md blocker).
**Warning signs:** Package resolution error mentioning "no such version".

### Pitfall 5: Equalizer animation keeps CPU alive after pause (breaks the project's hard idle-CPU guarantee)
**What goes wrong:** Leaving a `.repeatForever` animation attached when paused keeps SwiftUI's display link / render loop running even though the bars look static — idle CPU never returns to ~0 (D-04 violation).
**How to avoid:** Pattern 4 — swap to a finite animation (or `nil`) when `isPlaying` is false so no repeating clock remains. Confirm on-device with Activity Monitor / `sample` while paused.
**Warning signs:** Energy/CPU non-zero while paused or no-media.

### Pitfall 6: Mutating `@Published` outside `withAnimation` (or the wrong way) on the main callback
**What goes wrong:** The morph/entrance won't animate, or it animates when it shouldn't (the bars are the only thing that should loop — D-08 says the view drives no other animation).
**How to avoid:** Mirror `handlePower`: in the controller's `handleNowPlaying`, wrap state mutations in `withAnimation(.spring(response: 0.35, dampingFraction: 0.65))` exactly where charging does. The pure % / metadata refresh within a standing glance updates WITHOUT a new entrance (mirror the "% tick" branch).

## Code Examples

### Verified `TrackInfo.Payload` field reference (what you can read)
```swift
// Source: gh api repos/ejbills/mediaremote-adapter contents/.../TrackInfo.swift (VERIFIED 2026-06-27)
public struct Payload: Codable {
    public let title: String?
    public let artist: String?
    public let album: String?              // D-10 says DON'T show album in v1
    public let isPlaying: Bool?            // primary play/pause signal
    public let durationMicros: Double?     // (seek — v2, NOW-04)
    public let elapsedTimeMicros: Double?  // (seek — v2)
    public let applicationName: String?
    public let bundleIdentifier: String?   // D-01 allowlist key: "com.spotify.client" / "com.apple.Music"
    public let artworkDataBase64: String?
    public let artworkMimeType: String?
    public let timestampEpochMicros: Double?
    public let PID: pid_t?
    public let shuffleMode: ShuffleMode?   // (v2 — and YES, readable, see Open Questions)
    public let repeatMode: RepeatMode?     // (v2 — readable)
    public let playbackRate: Double?       // 1.0 playing / 0.0 paused (secondary signal)
    public let artwork: NSImage?           // PRE-DECODED — use this directly (D async-art: still arrives with the payload)
    public var currentElapsedTime: TimeInterval?  // computed (seek — v2)
}
```

### Verified transport API (what you can command — NOW-02)
```swift
// Source: MediaController.swift (VERIFIED). All write to the persistent loop child's stdin.
controller.play()            // ["play"]
controller.pause()           // ["pause"]
controller.togglePlayPause() // ["toggle_play_pause"]   ← recommend for a single ⏯ button
controller.nextTrack()       // ["next_track"]          ← ⏩
controller.previousTrack()   // ["previous_track"]      ← ⏪
controller.stop()            // ["stop"]
controller.setTime(seconds:) // ["set_time", n]         (seek — v2)
// Star/like exists (likeTrack/banTrack) but is DROPPED per CONTEXT.md — do not wire.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct `dlopen` MediaRemote + `MRMediaRemoteGetNowPlayingInfo` | perl-bridge via `mediaremote-adapter` | macOS 15.4 (Mar 2025) added `mediaremoted` entitlement check | Direct calls return nil; the bridge is the only working path. `[CITED: ungive README; LyricFever #94]` |
| `nowplaying-cli` backend | `mediaremote-adapter` | broke on 15.4 | CLAUDE.md "What NOT to Use". `[CITED: CLAUDE.md]` |
| Manual `Process` supervision | `MediaController` (self-restarting, main-hopping) | wrapper matured 2025–2026 | You write a thin adapter, not a process supervisor. `[VERIFIED: source]` |

**Deprecated/outdated:**
- CONTEXT.md/CLAUDE.md cited streaming API `getTrackInfo {…}` — **that is the one-shot**, not the stream. Stream = `onTrackInfoReceived` + `startListening()`. `[VERIFIED — see Assumptions Log A1]`
- `setTime(seconds:)` is real but maps to v2 seek (NOW-04) — not used in v1.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CONTEXT.md's cited streaming method `getTrackInfo {…}` is actually the ONE-SHOT; the stream is `onTrackInfoReceived`+`startListening()` | Standard Stack / State of the Art | LOW — VERIFIED in source; flagged because it contradicts an upstream doc the planner trusts. Using the wrong one re-spawns perl per query (criterion-4 violation). |
| A2 | The wrapper's internal `DispatchQueue.main.async` means the consumer needs NO extra main-hop | Pattern 2 | LOW — VERIFIED in source; corrects CONTEXT.md "hop callbacks to main thread" (the wrapper already did). Still document main-affinity. |
| A3 | Health-check option (a) — "any callback = healthy, no callback in 3s = unavailable" — is sufficient for D-12 | Pattern 3 | MEDIUM — a design choice, not a fact. The wrapper hides `ungive`'s precise `test` subcommand, so a perfectly precise check needs a separate test-client call. Confirm coarse check is acceptable, or budget the heavier path. **Needs user/planner confirmation.** |
| A4 | `isPlaying == nil` should be treated as paused | Pattern 1 | LOW — the engine guarantees `playing` non-null when valid; nil only on edge cases. Tests should cover both. |
| A5 | Pinning to commit `cf30c4f` (master head 2026-06-02) is the right reproducibility choice vs `branch: master` | Standard Stack / Pitfall 4 | LOW — verified no tags exist; a pinned commit is strictly safer than tracking head. Re-verify commit currency at plan time. |
| A6 | macOS 26 (Tahoe) on this build machine still honors the `com.apple.perl` MediaRemote entitlement bypass | Don't Hand-Roll / Sources | MEDIUM — community-confirmed for 15.4–26 betas, but Apple can break it any release (STATE.md standing blocker). **On-device launch probe is the real proof — must pass UAT.** |

## Open Questions

1. **Does the adapter READ BACK shuffle/repeat reliably (for v2 NOW-04 toggles)?**
   - What we know: `payload.shuffleMode`/`repeatMode` exist and decode (`ShuffleMode`/`RepeatMode` enums verified); `toggleShuffle()`/`setRepeatMode()` exist to SEND.
   - What's unclear: whether Spotify vs Apple Music both populate the read-back fields consistently. CONTEXT.md flags this as a v2 gate.
   - Recommendation: OUT OF SCOPE for v1 (D-09 reserves the slots only). Defer the verification to v2 planning; the read-back fields existing is a positive early signal.

2. **Does `isPlaying`/`playbackRate` flip cleanly on Spotify vs Apple Music pause, or is one source laggy?**
   - What we know: both `isPlaying` (Bool) and `playbackRate` (0.0/1.0) are emitted; `isPlaying` is the primary signal.
   - What's unclear: per-app emission timing on pause (affects how snappily the bars freeze, D-05).
   - Recommendation: on-device UAT with both apps; if `isPlaying` lags, fall back to `playbackRate == 0` as a secondary gate. Pure seam can accept either.

3. **Artwork latency on track change — does `artwork` ever arrive nil-then-filled?**
   - What we know: CLAUDE.md warns art lags metadata; the wrapper's `preservingArtworkIfDowngrade` keeps prior art if a same-track update drops it.
   - What's unclear: whether a brand-new track first emits with `artwork == nil` then a follow-up with art.
   - Recommendation: design the media wings/expanded art slot to show a placeholder (e.g. a music-note SF Symbol on a neutral fill) and fill `NSImage` async — the locked decision already requires this. Treat nil-art as "placeholder", never empty.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/usr/bin/perl` (Apple platform binary) | the adapter's entitlement bypass | ✓ (ships with macOS) | system | none — but it's always present on macOS |
| XcodeGen | adding the SPM package to project.yml | ✓ (project already uses it) | n/a | none |
| `MediaRemoteAdapter.framework` (via SPM) | the whole feature | resolved at build via SPM | wrapper master `cf30c4f` | none — feature core |
| macOS 26 entitlement bypass still functional | NOW-01/02 at runtime | UNVERIFIABLE at plan time | Tahoe | D-12 "nicht verfügbar" graceful degrade is the fallback |
| Spotify / Apple Music installed | on-device UAT only | user-dependent | n/a | test with whichever is installed |

**Missing dependencies with no fallback:** none at build time.
**Missing dependencies with fallback:** the runtime entitlement bypass — if Apple has broken it on this exact Tahoe build, the launch health check fires D-12 and the app degrades gracefully (this is itself a success-criterion-3 requirement, so a "failure" is a tested path, not a blocker).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 26.6 / Swift 5 language mode) |
| Config file | none — `IsletTests` bundle wired in `project.yml` (host = Islet.app, `@testable import Islet`) |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests 2>&1 \| xcbeautify` (or without xcbeautify) |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOW-01 | Allowlist: Spotify/Apple Music → presentation; other bundle id → `.none` | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests/testAllowlistFiltersBundleID` | ❌ Wave 0 |
| NOW-01 | Title/artist mapping; empty/nil title → `.none` | unit | same bundle, `testNoTitleMapsToNone` | ❌ Wave 0 |
| NOW-02 | (transport) commands reach the live session | manual / on-device | UAT: play/pause/next/prev in Spotify + Apple Music | n/a (system IPC — not unit-testable) |
| NOW-03 | `isPlaying` true→playing, false/nil→paused classification | unit | `testPlayingVsPausedClassification` | ❌ Wave 0 |
| NOW-03 | snapshot nil (no media) → `.none` (D-11, not D-12) | unit | `testNilSnapshotMapsToNone` | ❌ Wave 0 |
| NOW-03 | health flag: launch failure → unavailable; mid-drop → clear + unavailable-next | manual / on-device | UAT: launch with music, kill source, observe clear→idle then "nicht verfügbar" on next expand | n/a (process lifecycle — on-device) |
| D-04 | bars freeze + idle CPU ~0% when paused/no-media | manual / on-device | UAT: pause, `sample Islet` / Activity Monitor Energy | n/a (render-loop behavior — on-device) |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests`
- **Per wave merge:** full `IsletTests` suite (existing PowerActivity/Geometry/etc. must stay green)
- **Phase gate:** full suite green + on-device UAT of NOW-02 transport, NOW-03 graceful-unavailable, and D-04 idle-CPU before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/NowPlayingPresentationTests.swift` — covers NOW-01 (allowlist, title/artist), NOW-03 (playing/paused/none classification). Pure-seam fixtures, no system calls.
- [ ] No new shared fixtures/conftest needed — `TrackSnapshot` is hand-constructed like `PowerReading`.
- [ ] No framework install needed — XCTest bundle already exists.

*The IPC glue, health-check lifecycle, transport commands, and the equalizer idle-CPU behavior are NOT unit-testable (real system media + process lifecycle + render loop). They are explicitly on-device UAT — mirroring how Phase 3's IOKit glue was on-device while the pure power seam was unit-tested.*

## Security Domain

> `security_enforcement` not present in config → treated as enabled. Phase 4 spawns a child process and parses external JSON, so security is relevant.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a (local media only) |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a — no privileged escalation; the bypass is Apple's own platform-binary entitlement, not ours |
| V5 Input Validation | yes | The JSON from the perl child is decoded with `Codable` + `decodeIfPresent` (the wrapper is fully nil-tolerant — verified). Your seam reads every field as optional with defaults (mirror PowerSourceMonitor's defensive reads). Never force-unwrap a payload field. |
| V6 Cryptography | no | n/a — no secrets, no crypto |
| V10 Malicious Code / Process | yes | The child is `/usr/bin/perl` (Apple platform binary) with fixed args from the embedded `run.pl`. No user-controlled command construction. Ensure the child is terminated on deinit (`stopListening()`) so no orphaned process leaks (mirror `PowerSourceMonitor.stop()` / T-03-06). |

### Known Threat Patterns for Swift + child-process + private-framework bridge
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Orphaned/leaked perl child after app teardown | Denial of Service (resource leak) | Call `controller.stopListening()` in the controller's `deinit` (mirrors the existing `powerMonitor.stop()` discipline). The wrapper terminates the child + clears the readability handler. `[VERIFIED: stopListening()]` |
| Malformed/oversized JSON line from the child | Tampering / DoS | The wrapper decodes per-line with `JSONDecoder` and routes failures to `onDecodingError` without crashing; your seam treats all fields optional. Do not trust title/artist length — SwiftUI `.lineLimit(1)`/truncation on display. |
| Untrusted artwork bytes → image decode | Tampering | `NSImage(data:)` decode happens inside the wrapper; an invalid image yields `artwork == nil` → your placeholder path. No raw byte handling in your code. |
| Private-framework breakage masquerading as silent failure | (availability) | The launch health check (D-12) + `onListenerTerminated` (D-13) are the explicit, tested degrade paths — a broken bridge shows "nicht verfügbar", never a crash (success-criterion-3). |

## Sources

### Primary (HIGH confidence)
- `gh api repos/ejbills/mediaremote-adapter` — `Package.swift`, `Sources/MediaRemoteAdapter/MediaController.swift`, `Sources/MediaRemoteAdapter/TrackInfo.swift` read in full (2026-06-27): API surface, threading, lifecycle, fields.
- `github.com/ungive/mediaremote-adapter` — engine README: `get`/`loop`/`test` subcommands, NIL-on-no-media, non-zero-exit-on-blocked, v0.7.6 (2026-05-11), BSD-3, macOS 15.4+/26 support.
- `github.com/yonaskolb/XcodeGen` ProjectSpec.md — `packages:` / `dependencies:` / `embed` / `codeSign` YAML syntax.
- Local code (verified existing): `Islet/Notch/PowerActivity.swift`, `PowerSourceMonitor.swift`, `ChargingActivityState.swift`, `NotchWindowController.swift`, `NotchPillView.swift`, `NotchGeometry.swift`, `IsletTests/PowerActivityTests.swift`, `project.yml`, `Islet/AppDelegate.swift`.
- On-device probe: `swift --version` (6.3.3), `xcodebuild -version` (Xcode 26.6, build 17F113).

### Secondary (MEDIUM confidence)
- WebSearch (verified against the ungive README): the `com.apple.perl` entitlement bypass remains functional on macOS 15.4–26.
- `github.com/aviwad/LyricFever` issue #94 — corroborates the 15.4 direct-access break.

### Tertiary (LOW confidence)
- General SwiftUI `repeatForever` idle-CPU community guidance — the GATING approach (Pattern 4) is standard but the exact idle-CPU result MUST be confirmed on-device (Validation Architecture).

## Metadata

**Confidence breakdown:**
- Standard stack / adapter API: HIGH — read the actual source line-by-line, not docs.
- XcodeGen SPM wiring: HIGH — cited ProjectSpec + verified current project.yml has no packages.
- Architecture (quartet mirror): HIGH — Phase-3 templates read directly; Phase 4 is a structural parallel.
- Health-check design (D-12): MEDIUM — the wrapper hides the precise `test` command; the synthesized check is a sound design choice but a choice (A3).
- Equalizer idle-CPU: MEDIUM — pattern is standard, result needs on-device confirmation.
- Runtime entitlement longevity (macOS 26): MEDIUM — community-confirmed, Apple-breakable (standing STATE.md blocker; the launch probe is the real proof).

**Research date:** 2026-06-27
**Valid until:** 2026-07-11 (14 days — the adapter tracks macOS closely; re-verify the wrapper commit + that the bypass still works at plan/execute time, per the STATE.md blocker).

## RESEARCH COMPLETE

**Phase:** 4 - Now Playing
**Confidence:** HIGH (with two MEDIUM design areas flagged: D-12 health-check synthesis and equalizer idle-CPU, both verifiable on-device)

### Key Findings
- The `ejbills/mediaremote-adapter` source was read in full. The real streaming API is `onTrackInfoReceived` + `startListening()` (CONTEXT.md cited `getTrackInfo`, which is the ONE-SHOT — flagged A1). The wrapper already hops every callback to main (no extra hop needed — A2), already consumes ONE persistent `loop` child, and self-restarts every 100 events — satisfying success-criterion-4 out of the box.
- Artwork arrives as a **pre-decoded `NSImage?`** on `payload.artwork`; transport is `togglePlayPause()/nextTrack()/previousTrack()` riding the existing child's stdin. The `bundleIdentifier` field is the D-01 allowlist key.
- The wrapper does NOT expose `ungive`'s precise `test` health subcommand → the launch-time health check (D-12) must be synthesized from a one-shot `getTrackInfo` probe + timeout, with `onListenerTerminated` reserved for mid-session death (D-13). `onListenerTerminated` is suppressed when `eventCount == 0`, which is why the launch case needs the probe (Pitfall 2).
- SPM pinning: the wrapper has **zero git tags** — pin `revision: cf30c4f…` (or `branch: master`), product `MediaRemoteAdapter`, `embed: true` + `codeSign: true` in `project.yml`, then `xcodegen generate` (Pitfall 4).
- The decorative equalizer bars must REMOVE the `.repeatForever` animation when `isPlaying` is false (not just freeze a value) to honor the idle-CPU guarantee (Pitfall 5).

### File Created
`.planning/phases/04-now-playing/04-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack (adapter API) | HIGH | Source read line-by-line via gh api |
| Architecture (quartet mirror) | HIGH | Phase-3 templates read directly; structural parallel |
| Pitfalls | HIGH | Each derived from the verified source or existing code |
| Health-check design (D-12) | MEDIUM | Wrapper hides `test`; synthesized check is a documented choice (A3) |
| Equalizer idle-CPU | MEDIUM | Standard pattern, on-device confirmation required |

### Open Questions
- Shuffle/repeat read-back consistency across Spotify vs Apple Music (v2 gate — out of scope for v1, fields exist).
- Per-app `isPlaying` flip timing on pause (affects bar-freeze snappiness — on-device UAT).
- Whether a brand-new track ever emits nil-art-then-filled (placeholder design already required).

### Ready for Planning
Research complete. The planner can create PLAN.md files: a Wave-0 test file + the `NowPlaying*` quartet, the `project.yml` SPM wiring, and the `NotchPillView`/`NotchWindowController` extensions, with on-device UAT for transport, graceful-unavailable, and idle-CPU.
