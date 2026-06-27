# Phase 4: Now Playing - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 ships the **core install driver**: media currently playing in **Spotify or Apple
Music** shows **album art + title + artist** in the island, with working **play / pause /
next / previous** transport, built entirely behind **one isolated MediaRemote service** with
a **launch-time health check** that **fails gracefully** (explicit "unavailable") when the
system API is blocked. Covers **NOW-01** (art + title + artist), **NOW-02** (transport),
**NOW-03** (survive restart + graceful unavailable).

This is the first **persistent / ambient** activity (charging in Phase 3 was a ~3s transient
splash). The Phase-3 **wings** layout was explicitly designed as the skeleton this phase
reuses (art left, content right).

**In scope:** the now-playing glance (collapsed wings), the expanded controls view, the
play/pause/skip transport, the decorative equalizer-bar "now playing" symbol, the
playing/paused/stopped/unavailable states, and the isolated service that drives it.

**Explicitly NOT in this phase (deferred — see `<deferred>`):**
- **Seek / progress bar** (the 0:20 / 3:29 bar in the reference image) → **v2 (NOW-04)**. The
  expanded layout reserves vertical room for it; it is not built.
- **Shuffle + Repeat** toggles → **v2** (unlisted requirement; adapter support unverified).
  The control row reserves the **left slot (shuffle)** and **right slot (repeat)**; not built.
- **Sneak-peek** auto-expand on track change (the "Interpret – Titel" peek) → **v2 (NOW-05)**;
  its on/off **Settings toggle** is anchored for **Phase 6 (APP-03)**.
- **Star / favorite** button → **dropped entirely** (not a real MediaRemote command; Spotify
  "like" is not reachable through this API).
- **Color-adaptive tint** (NOW-06), **waveform on the album art** (NOW-07), **volume gesture**
  → v2.
- **General multi-activity priority resolver** (charging + media + device coexistence) →
  **Phase 6 (COORD-01)**. Phase 4 only handles charging-vs-nowplaying-vs-user-interaction.
- **Real audio-tap visualizer** → out of scope (REQUIREMENTS): the equalizer bars are
  **decorative / synthetic**, not coupled to the actual audio.
- **Settings UI** (source allowlist, sneak-peek toggle, accent/theme) → Phase 6 (APP-03).
</domain>

<decisions>
## Implementation Decisions

### Source scope (NOW-01 — deliberately narrowed)
- **D-01:** **v1 recognizes ONLY Spotify (`com.spotify.client`) and Apple Music
  (`com.apple.Music`)** via a **bundle-ID allowlist**. A browser tab (YouTube), Netflix, or any
  other now-playing source is **ignored** (no glance, no controls). ⚠️ This **intentionally
  narrows NOW-01's "any app" wording** (same divergence pattern as Phase-2 D-02 — captured here,
  ROADMAP/REQUIREMENTS wording left as-is unless the user later asks to edit them).

### Collapsed / ambient "now playing" glance (the wings)
- **D-02:** **While PLAYING**, the collapsed island shows the **wings layout**: a small **album-art
  thumbnail on the LEFT** wing and the **animated equalizer "now playing" bars on the RIGHT** wing
  (3–5 bars of varying height that grow/shrink — the classic now-playing symbol). Reuses the
  Phase-3 wings frame/skeleton.
- **D-03:** The bars are **decorative / synthetic** — a simple looping animation, **NOT** a real
  audio tap (real audio capture is out of scope). They look audio-reactive to the user without it.
- **D-04:** The bars animate **ONLY while actively playing**. This is the **first continuous
  (looping) animation in the app** — a deliberate, scoped exception to the prior one-shot rule,
  **gated on `isPlaying`**. The "idle CPU ~0% / no animation clock" guarantee still holds for the
  truly-idle (no-media) state and for paused (D-05).
- **D-05:** **PAUSED** (track still loaded) → the wings **stay visible** but the bars **freeze /
  go static** (signals "paused"). No looping animation while paused (idle CPU ~0% preserved).
- **D-06:** **Paused + no interaction for ~15 s** → a short exit animation, then the whole
  now-playing display **disappears** → back to the idle pill. Implemented as a **single one-shot
  `DispatchWorkItem`** (mirrors the charging `dismissWorkItem` / `graceWorkItem` — NO repeating
  timer). Resuming playback cancels it and restores the glance. (Whether hover/interaction resets
  the 15 s, consistent with the charging D-10 pattern, is Claude's discretion.)
- **D-07:** **STOPPED / no media** → a **short exit animation** ("music stopped"), then the
  now-playing display **disappears** → idle pill. (Distinct from pause: stop removes immediately
  after the cue; pause lingers up to 15 s.)

### Expanded controls view (see `assets/expanded-layout.png`)
- **D-08:** **Layout:** **album art LEFT** (square, rounded); **Title + Artist** stacked to the
  **RIGHT** of the art (Title bold, Artist secondary/grey); the **animated equalizer bars in the
  top-RIGHT** corner (continues the glance into the expanded view). Control row along the bottom.
  Reached via the existing **click-to-expand** downward morph (Phase-2).
- **D-09:** **Control row (v1) = `⏪  ⏯  ⏩` only**, centered (previous / play-pause / next —
  NOW-02). The layout **reserves the LEFT slot for Shuffle and the RIGHT slot for Repeat** (both
  built in v2), and the **Star / favorite is removed entirely**. Reserve vertical room above the
  controls for the future seek bar (D deferred).
- **D-10:** **Metadata = Title + Artist only** (no album name, no source-app icon) — minimal & clean.
- **D-11:** **No media playing (API healthy)** + the user clicks to expand → the expanded view shows
  the **existing Phase-2 date/time readout** as the "no music" state (nothing looks broken/empty).

### Transport behavior (NOW-02)
- Play/pause, next, previous act on the current Spotify/Apple-Music session via the MediaRemote
  service. Controls live in the expanded view; the panel is **already interactive when expanded**
  (`syncClickThrough`) and **focus-safe** (non-activating panel) — buttons receive clicks without
  stealing focus from the foreground app. (Phase-2 carry-forward, no new interaction model.)

### Unavailable / health (NOW-03)
- **D-12:** **API blocked / adapter unhealthy** (launch-time health check fails) → when the user
  expands the island, it shows **"Now Playing nicht verfügbar"** in place of the controls (the
  explicit indication required by success criterion 3). Distinct from "nothing playing": a healthy
  API with no media simply shows nothing (idle pill; date/time on expand per D-11).
- **D-13:** **API drops mid-session** (adapter dies while a track was showing) → **immediately
  clear state** back to the idle pill (NOW-03 "clears state, no crash"); the "nicht verfügbar"
  indication appears only on the **next** expand. No mid-session "unavailable" splash.

### Coexistence with charging (minimal — full resolver is Phase 6)
- **D-14:** Plugging in **while music plays** → the **charging splash briefly wins (~3 s)** (carries
  Phase-3 **D-11** if-ordering), then **returns to the now-playing wings** (NOT to empty). Phase 4
  only guarantees charging-vs-nowplaying-vs-interaction don't glitch; the **general priority
  resolver is Phase 6 (COORD-01)**.

### Locked by ROADMAP success criteria + CLAUDE.md (not negotiated here)
- All MediaRemote access lives behind a **single isolated service** with a **launch-time health
  check**, **consuming the adapter's streamed output (NOT re-spawning it)**, and **hopping
  callbacks to the main thread** (success criterion 4).
- Now Playing uses the **`mediaremote-adapter`** bridge (`ejbills/mediaremote-adapter` Swift
  wrapper over `ungive/mediaremote-adapter`) — **NOT** direct `dlopen` of MediaRemote and **NOT**
  `nowplaying-cli` (both broken on 15.4+).
- **Album art loads asynchronously** — it can lag the metadata; the UI fills art in async with a
  placeholder, never blocks on it.
- **Now Playing survives app restart** (re-reads current session on launch).
- **Hidden in true fullscreen / clamshell** — routes through the single `updateVisibility()` gate
  (Phase-2 D-09 / Phase-3 carry-forward).

### Claude's Discretion
- **The now-playing service/model abstraction** — mirror the Phase-3 pattern (a **pure
  seam** mapping raw now-playing info → presentation, a separate **`@Published` model**, **thin IPC
  glue** consuming the adapter stream, and a **view branch**). Keep it **now-playing-specific with a
  clean seam — NOT a general resolver** (Phase 6). Isolate behind one protocol so swapping the
  MediaRemote implementation later is a one-file change (CLAUDE.md mandate).
- Exact **bar count (3–5)**, bar animation tempo/curve, and the frozen-paused visual.
- Exact expanded geometry, art corner radius/size, fonts (start from the Phase-3 rounded-system
  vocabulary), and the transport SF Symbols + sizing.
- The **album-art async load** mechanism + the placeholder shown while art loads.
- Whether **hover/interaction resets the 15 s pause timeout** (likely yes — consistent with the
  charging D-10 pattern).
- **Spring / duration tuning** (start from the Phase-2 seeds: response ≈ 0.35, dampingFraction ≈
  0.65). The entrance/exit ("music stopped") cue specifics.
- The **pure-logic seam** (TDD like Phases 1–3): a total function mapping now-playing info
  (source bundle id, isPlaying/paused/stopped, title, artist, art ref) → presentation
  (`playing` / `paused` / `stopped` / `unavailable`, filtered by the D-01 allowlist),
  unit-testable in ms; the adapter/IPC + AppKit/SwiftUI wiring verified on-device.

### Folded Todos
(None — no pending todos matched this phase.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Now Playing / MediaRemote (primary for Phase 4)
- `CLAUDE.md` → **"Now Playing — the MediaRemote reality (read this carefully)"** — why direct
  MediaRemote / `nowplaying-cli` broke on 15.4, the **`mediaremote-adapter` dual-process trick**
  (spawns `/usr/bin/perl`, streams now-playing JSON over stdout), the Swift wrapper's API
  (`getTrackInfo {…}`, `play()`, `pause()`, `nextTrack()`, `setTime(seconds:)`), **artwork
  latency** (fill art async), the **"isolate behind one protocol/service"** mandate (D mandate),
  and that **App Store is impossible / notarization is fine**.
- `CLAUDE.md` → **Supporting Libraries** table — `mediaremote-adapter` (`ejbills/...` wrapper,
  set `MediaRemoteAdapter.framework` to **Embed & Sign**); installation step 2 in the setup section.
- `CLAUDE.md` → **Apple frameworks** table — MediaRemote (private, via adapter, MEDIUM
  confidence, 15.4+), Combine optional.
- `CLAUDE.md` → **"What NOT to Use"** — no direct `dlopen` of MediaRemote, no `nowplaying-cli`;
  un-sandboxed, Swift-5 language mode, macOS-14 floor.

### Animation / interaction (carry-forward feel)
- `CLAUDE.md` → **"Animation approach (the Dynamic-Island feel)"** — spring +
  `matchedGeometryEffect`; the equalizer bars are decorative SwiftUI animation only.

### Reference images (the user's explicit visual intent)
- `.planning/phases/04-now-playing/assets/expanded-layout.png` — the **expanded view** the user
  wants (art left · title/artist right · bars top-right · [seek bar — v2] · control row). Note: the
  star in the image is **dropped**, the seek/shuffle/repeat are **v2** (slots reserved per D-09).
- `.planning/phases/04-now-playing/assets/sneak-peek.png` — the **v2 sneak-peek** (collapsed notch
  drops slightly to show "Interpret – Titel" on track change). Deferred (NOW-05); kept for context.

### Phase-3 carry-forward (the pattern Phase 4 mirrors + the code it extends)
- `.planning/phases/03-charging-activity/03-CONTEXT.md` — the **"activity" pattern**: pure seam +
  separate `@Published` model + thin system glue + view branch; **D-11 precedence** (charging
  briefly wins — D-14 here), the **wings sideways layout** (D-02/D-08 reuse it), the **one-shot
  `DispatchWorkItem` dismiss** (D-06 reuses it), the single `updateVisibility()` gate.
- `Islet/Notch/PowerActivity.swift` — the **pure-seam template** (`PowerReading` → `ChargingActivity`
  via a total function, unit-tested). Phase 4's now-playing-info → presentation seam mirrors this.
- `Islet/Notch/ChargingActivityState.swift` — the **`@Published` model template** (a plain
  `ObservableObject` holding the current presentation). The now-playing model mirrors this.
- `Islet/Notch/PowerSourceMonitor.swift` — the **thin system-glue template** (callback hops to
  main, `@MainActor`, deinit teardown). The MediaRemote-adapter stream consumer mirrors this
  discipline (consume the stream, hop to main, tear down on deinit).
- `Islet/Notch/NotchWindowController.swift` — owns the panel + the **single `updateVisibility()`**
  show/hide site, the **dismiss/grace `DispatchWorkItem`s**, fullscreen/clamshell gating, screen
  observers. The now-playing service + state plug in here (mirror `handlePower` → a `handleNowPlaying`).
- `Islet/Notch/NotchPillView.swift` — the SwiftUI pill with the **`wings(for:)` branch** (extend
  for the media wings: art left, bars right) and the **`expandedIsland`** (currently date/time
  placeholder — D-11 keeps it for no-media; add the media expanded layout D-08). The body's
  **precedence `if`-ordering** grows (charging > now-playing wings/expanded > collapsed) — D-14.
- `Islet/Notch/NotchInteractionState.swift` — the user-gesture state machine (untouched; media is a
  separate `@Published` presentation, like charging).
- `Islet/Notch/NotchGeometry.swift` — pure geometry seam (`wingsFrame`, `expandedNotchFrame`);
  reuse the wings frame for the media glance.
- `Islet/Notch/NotchShape.swift` — the pill/wings shape.
- `Islet/AppDelegate.swift` + `Islet/SettingsView.swift` + the status-item menu — the launch point
  (start the now-playing service here) and where a "nicht verfügbar" hint / future toggles live.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 4: Now Playing"** (goal + 4 success criteria).
- `.planning/REQUIREMENTS.md` — **NOW-01** (art/title/artist), **NOW-02** (transport), **NOW-03**
  (restart + graceful unavailable); **NOW-04/05/06/07** (v2 — seek/sneak-peek/tint/waveform — the
  deferred items here); **COORD-01** (Phase-6 resolver — anchors D-14); **APP-03** (Phase-6
  settings — anchors the sneak-peek toggle + source-allowlist expansion).
- `.planning/PROJECT.md` — vision (as polished as Alcove), Key Decisions, out-of-scope (note the
  "Real audio-tap visualizer" out-of-scope line → D-03 decorative bars).

### Project setup (one-time, for the planner)
- `CLAUDE.md` → **"Installation / setup"** step 2 — add the SPM package
  `https://github.com/ejbills/mediaremote-adapter.git`, set `MediaRemoteAdapter.framework` to
  **Embed & Sign**. `project.yml` (XcodeGen) — run `xcodegen generate` after adding sources; the
  SPM dependency + Embed&Sign must be wired in `project.yml`, not by hand-editing `.xcodeproj`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The Phase-3 "activity" quartet is the template to mirror**: `PowerActivity.swift` (pure seam),
  `ChargingActivityState.swift` (`@Published` model), `PowerSourceMonitor.swift` (thin glue that
  hops to main + tears down in deinit), and the `NotchPillView.wings(for:)` branch. Phase 4 adds a
  parallel `NowPlaying*` quartet — **do not fold media into the charging or interaction enums**.
- **`NotchWindowController`** — owns the panel, the **single `updateVisibility()`** show/hide site,
  the one-shot `DispatchWorkItem` dismiss pattern (template for the D-06 15 s paused-timeout and the
  D-07 stop cue), fullscreen/clamshell gating, and the launch wiring (`start()`). Add a
  `handleNowPlaying(...)` mirroring `handlePower(...)`.
- **`NotchPillView`** — extend `wings(for:)` for the media glance (art left / animated bars right)
  and add a media expanded layout; keep `expandedIsland`'s date/time as the no-media state (D-11).
  The body's precedence `if`-chain gains a now-playing case (D-14 ordering).
- **`NotchGeometry`** — reuse `wingsFrame` for the media glance; the panel is already sized to the
  UNION of expanded + wings frames, so the media wings fit without a runtime resize.

### Established Patterns
- Small AppKit surface + SwiftUI via `NSHostingView`; `@Published`/`ObservableObject` into SwiftUI;
  **Swift-5 language mode**; **un-sandboxed**; **macOS-14 floor**.
- **TDD seam** (Phases 1–3): the riskiest CLASSIFICATION logic is a pure, fixture-tested function;
  the system/IPC + AppKit/SwiftUI wiring is verified on-device. Apply to the now-playing-info →
  presentation mapping (incl. the D-01 source allowlist) and the playing/paused/stopped logic.
- **One-shot `DispatchWorkItem`** for timed collapse (NOT a repeating timer) — reuse for D-06/D-07.
  ⚠️ NEW exception: the **decorative equalizer bars** ARE a continuous SwiftUI animation, but gated
  strictly on `isPlaying` (D-04) so the truly-idle / paused states keep idle CPU ~0%.
- **Single `updateVisibility()`** is the sole show/hide site — route the media glance through it so
  it inherits fullscreen + clamshell hide for free (a second show/hide site races them).
- `project.yml` (XcodeGen) auto-discovers new `.swift` under `Islet/`; the **SPM dependency +
  Embed&Sign** for `MediaRemoteAdapter.framework` must be added to `project.yml`, then
  `xcodegen generate`.

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` creates/retains `NotchWindowController` — start the
  now-playing service inside the controller's `start()` (mirroring the power monitor). Run the
  **launch-time health check** there; on failure set the "unavailable" flag (D-12).
- The adapter streams over a child process's stdout — **consume the stream once**, hop each update
  to **main** before touching `@Published`/AppKit, and **tear down** (terminate the child / cancel
  the reader) in deinit, mirroring `PowerSourceMonitor.stop()` discipline (no leaked process).
- The media glance + charging splash + fullscreen-hide all converge on `updateVisibility()`; the
  view's precedence `if`-ordering arbitrates which renders (D-14).

</code_context>

<specifics>
## Specific Ideas

- **Reference image (expanded), explicit:** album art left · "New Rules" / "Dua Lipa" title+artist
  right · animated equalizer bars top-right · [progress bar — v2] · bottom control row. The user's
  final control row is **Shuffle(left) · ⏪ · ⏯ · ⏩ · Repeat(right)** — but in **v1 only the three
  transport buttons exist**; shuffle/repeat slots are reserved, the **star is removed**.
- **Equalizer "now playing" bars:** 3–5 bars of varying height that grow/shrink — the classic iOS
  now-playing glyph. **Decorative/synthetic** (no real audio tap). Animate only while playing;
  **freeze** when paused.
- **Sneak-peek (v2):** on track change the collapsed notch drops slightly and shows
  "Interpret – Songtitel" briefly, then collapses. The user wants this **plus a Settings on/off
  switch** (Phase 6) — deferred but explicitly desired.
- **Sources:** the user explicitly wants **only Spotify + Apple Music** recognized in v1 — no
  browser/YouTube/Netflix.

</specifics>

<deferred>
## Deferred Ideas

- **Seek / progress bar** (NOW-04, v2) — the 0:20 / 3:29 bar in the reference image. The expanded
  layout **reserves room** for it; not built in v1. (A live progress bar implies a running timer
  while the panel is open — note when it lands.)
- **Shuffle + Repeat toggles** (unlisted → v2) — control row reserves **shuffle-left / repeat-right**
  slots. ⚠️ Needs research that the adapter can both **send** shuffle/repeat commands and **read
  back** the current mode (to render on/off) before it can ship even in v2.
- **Sneak-peek on track change** (NOW-05, v2) + its **on/off Settings toggle** (Phase 6 / APP-03) —
  explicitly wanted by the user; deferred. Anchor the toggle as a seam when Phase 6 builds settings.
- **Star / favorite button — DROPPED.** Not a real MediaRemote transport command; Spotify "like" is
  not reachable through this API. Removed entirely (not even v2) to avoid a dead button.
- **Color-adaptive island tint** (NOW-06) and **decorative waveform on the album art** (NOW-07) → v2.
- **Source allowlist expansion via Settings** (e.g. add browsers later) — the user chose the strict
  Spotify+Apple-Music-only cut for v1; a Phase-6 setting to widen it is a possibility, not v1.
- **General multi-activity priority resolver** (charging + media + device) → **Phase 6 (COORD-01)**.
  Phase 4 does only the minimal charging-vs-media-vs-interaction arbitration (D-14).
- **Clicking album art to open the source app**, hover-volume, and other extra gestures → not v1
  (not raised as required; out of scope to keep v1 focused).

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)

</deferred>

---

*Phase: 04-now-playing*
*Context gathered: 2026-06-27*
</content>
</invoke>
