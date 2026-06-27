---
phase: 04-now-playing
plan: 03
subsystem: now-playing
tags: [swiftui, view, equalizer, matchedgeometry, transport, precedence, idle-cpu]

# Dependency graph
requires:
  - phase: 04-now-playing
    provides: "Plan 02: NowPlayingState @Published model (presentation + artwork + isHealthy); NowPlayingPresentation pure seam (Plan 01)"
provides:
  - "Islet/Notch/NotchPillView.swift — every visible media surface: collapsed glance wings (art/bars), expanded controls (art/title/artist/bars/⏪⏯⏩), D-12 unavailable view, D-14 precedence chain; observes NowPlayingState; transport via plain closures"
  - "EqualizerBars — file-scope, isPlaying-gated decorative bars (idle-CPU-safe)"
  - "NotchWindowController.nowPlayingState — a live NowPlayingState instance bound to the view (Plan 04 wires the monitor to drive it)"
affects: [04-04 (controller owns NowPlayingState + NowPlayingMonitor, forwards onSnapshot/onTerminated to nowPlayingState, wires onTogglePlayPause/onNext/onPrevious to monitor transport, applies the spring on mutation)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "isPlaying-gated decorative animation: .repeatForever ONLY in the isPlaying-true branch, finite .default when paused — removes the repeating clock so idle CPU returns to ~0 (D-04 / Pitfall 5)"
    - "Media branches reuse the established Phase-3 wings(for:) + expandedIsland recipe: NotchShape + matchedGeometryEffect(id:\"island\") + the static size seeds, so the ONE black island morphs across charging/media/expanded/collapsed (no cross-fade)"
    - "D-14 multi-activity arbitration as a one-line if-ordering in the body (NOT a resolver — that is Phase 6); the EXPANDED branch internally picks unavailable(D-12)/media/date-time(D-11) from isHealthy + presentation"
    - "Untrusted media metadata bounded at display: title+artist .lineLimit(1)+.truncationMode(.tail) (T-04-09); SwiftUI Text is already inert to format strings"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "barCount = 4, bar tempo = .easeInOut(duration: 0.4).repeatForever(autoreverses: true) with a 0.12s-per-bar stagger delay; bar size 2.5pt wide × 4→12pt height (RESEARCH Pattern 4 verbatim, discretion 3–5 → 4)"
  - "Art placeholder: nil artwork → a neutral RoundedRectangle (white.opacity 0.12) overlaid with Image(systemName: 'music.note'); non-nil → Image(nsImage:).resizable().aspectRatio(.fill).clipShape(RoundedRectangle) — shared artThumbnail(_:side:corner:) used by both wings (32-8pt sq, 6pt corner) and expanded (40pt sq, 8pt corner). Async art fills in for free (SwiftUI re-renders when @Published artwork flips nil→image)"
  - "[Rule 3] NotchWindowController gained a `let nowPlayingState = NowPlayingState()` instance + passes it to the view — adding the non-defaulted nowPlaying param broke the existing call site; Plan 04 wires the monitor to drive this instance"
  - "Transport buttons are plain closures (onTogglePlayPause/onNext/onPrevious) defaulted to no-ops, mirroring onClick — view stays AppKit-free + focus-safe; Plan 04 forwards to NowPlayingMonitor"
  - "Reserved (not built): Shuffle slot (left), Repeat slot (right), seek-bar height (above controls) — D-09 empty Color.clear spacers. Star/favorite DROPPED entirely (no slot)"

patterns-established:
  - "First continuous animation in the app is the deliberately-scoped, isPlaying-gated EqualizerBars — the idle-CPU contract lives in the conditional .animation, verified on-device in Plan 04 UAT"

requirements-completed: [NOW-01, NOW-02]

# Metrics
duration: 5min
completed: 2026-06-27
---

# Phase 4 Plan 03: Now-Playing Media View Summary

**`NotchPillView` extended with every visible now-playing surface — the collapsed glance wings (album art left / animated equalizer bars right), the expanded controls layout (art · title/artist · bars top-right · ⏪ ⏯ ⏩), the idle-CPU-safe `EqualizerBars` that animates only while playing, the D-12 "nicht verfügbar" view, and the D-14 charging > expanded > media-wings > collapsed precedence chain — all wired for transport callbacks and ready for Plan 04 to drive with the live monitor.**

## Performance

- **Duration:** ~5 min
- **Tasks:** 2
- **Files modified:** 2 (both Swift; xcodegen regenerated no pbxproj change — no new files)

## Accomplishments

- Added `@ObservedObject var nowPlaying: NowPlayingState` to `NotchPillView` (declared before the defaulted `onClick`/transport closures).
- Added file-scope `struct EqualizerBars` from RESEARCH Pattern 4 verbatim — the `.repeatForever` lives ONLY in the `isPlaying ?` true branch; the false branch passes a finite `.default`, so no repeating clock stays attached when paused/idle (D-04 / Pitfall 5 / T-04-10).
- Added `mediaWings(_:art:)` — the collapsed glance: album art LEFT, equalizer bars RIGHT, `.paused` freezes the bars static (D-05). Reuses the flat `NotchShape(6,6)` + `matchedGeometryEffect(id:"island")` + `Self.wingsSize`, mirroring the charging wings.
- Added `artThumbnail(_:side:corner:)` — shared art renderer with the nil → `music.note` placeholder (Open Q3 / T-04-11); async art fills in automatically.
- Added transport closures `onTogglePlayPause` / `onNext` / `onPrevious` (plain, no-op defaulted) and `transportButton(_:action:)` with `.buttonStyle(.plain)` (focus-safe).
- Added `mediaExpanded(_:art:)` — the D-08 layout (art left · bold title + grey artist right · bars top-right · centered ⏪ ⏯ ⏩) with reserved empty Shuffle/Repeat slots and reserved seek-bar height (D-09, none built); Star dropped.
- Added `mediaUnavailable` — `Text("Now Playing nicht verfügbar")` (D-12).
- Rewrote the body `if`-chain to the D-14 precedence; the EXPANDED branch internally selects unavailable(D-12) / media / date-time(D-11).
- Added DEBUG `#Previews`: Media Wings (playing), Media Wings (paused), Media Expanded, Unavailable; updated the existing Collapsed/Expanded/Charging previews to pass a `NowPlayingState`.
- App builds clean; full `IsletTests` suite stays green (77 tests, 0 failures).

## Final NotchPillView Initializer (Plan 04 wiring contract)

```swift
NotchPillView(
    interaction: NotchInteractionState,
    charging: ChargingActivityState,
    nowPlaying: NowPlayingState,          // NEW — bind the controller's NowPlayingState here
    onClick: () -> Void = {},
    onTogglePlayPause: () -> Void = {},    // NEW — forward to monitor.togglePlayPause()
    onNext: () -> Void = {},               // NEW — forward to monitor.nextTrack()
    onPrevious: () -> Void = {}            // NEW — forward to monitor.previousTrack()
)
```

`NotchWindowController` already owns `let nowPlayingState = NowPlayingState()` and passes `nowPlaying: nowPlayingState`. Plan 04 must:
- Construct `NowPlayingMonitor(onSnapshot:onTerminated:)` driving `nowPlayingState.presentation` / `.artwork` / `.isHealthy` (per Plan 02's contract), wrapping mutations in the existing `withAnimation(.spring(response:0.35, dampingFraction:0.65))`.
- Add `onTogglePlayPause:`/`onNext:`/`onPrevious:` to the `NotchPillView(...)` construction at line ~245, forwarding to the monitor.
- Call `monitor.start()` + `runHealthCheck { nowPlayingState.isHealthy = $0 }` at launch; `monitor.stop()` from `deinit`.

## Body Precedence (exact, D-14)

```
charging.activity != nil                  → wings(for:)            // charging splash briefly wins (~3s)
else interaction.isExpanded:
    !nowPlaying.isHealthy                  → mediaUnavailable       // D-12
    nowPlaying.presentation != .none       → mediaExpanded(...)     // NOW-01/02
    else                                   → expandedIsland         // D-11 date/time (healthy, no media)
else nowPlaying.presentation != .none     → mediaWings(...)         // D-02 collapsed glance
else                                       → collapsedIsland        // idle pill
```

The charging `dismissWorkItem` clears `charging.activity` after ~3s → the body falls through to the media wings automatically ("returns to the now-playing wings, NOT to empty" — D-14) with no new resolver.

## Equalizer / Art Tuning (chosen)

- **Bars:** 4 bars, 2.5pt wide, height 4→12pt, `.easeInOut(0.4).repeatForever(autoreverses:true)` with a `0.12 * i` per-bar stagger. All four numbers are on-device-tunable in Plan 05.
- **Art:** shared `artThumbnail`; wings use a (32−8)=24pt square @ 6pt corner, expanded uses 40pt @ 8pt corner; nil → music.note on a `white.opacity(0.12)` rounded fill.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NotchWindowController missing `nowPlaying` argument**
- **Found during:** Task 1 (build verification)
- **Issue:** Adding the non-defaulted `@ObservedObject var nowPlaying: NowPlayingState` (ahead of the defaulted `onClick`) broke the existing `NotchPillView(...)` construction in `NotchWindowController.swift:245` — `missing argument for parameter 'nowPlaying'`.
- **Fix:** Added `let nowPlayingState = NowPlayingState()` to the controller (mirroring `chargingState`) and passed `nowPlaying: nowPlayingState`. The instance stays `.none`/healthy until Plan 04 wires `NowPlayingMonitor` to drive it — at which point the live media surfaces light up with zero further view changes.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Commit:** b26c332

The plan's verify commands hardcode `/Users/lippi304/conductor/workspaces/notch/algiers`; this ran in an isolated worktree, so every command executed from the worktree root instead — an environment substitution, not a plan deviation (same as Plans 01/02).

## Issues Encountered

- **Worktree base mismatch (pre-task, infrastructure):** The worktree branch was initially based on a stray `15b83c5` "Initial commit" disconnected from project history — `4259520` (Plan 02's HEAD, my dependency) was NOT an ancestor. Per the worktree-branch-check instruction, `git reset --hard 4259520` materialized the correct tree before any task work. All subsequent work proceeded on the correct base.
- **`--no-verify` blocked:** The repo's `block-no-verify` pre-commit hook rejects `--no-verify`. All commits were made normally with hooks enabled; all succeeded.

## Known Stubs

None that block the plan goal. `NotchWindowController.nowPlayingState` is a live, correctly-typed instance that currently stays at its default `.none`/healthy because the monitor that drives it is Plan 04's scope — this is the documented hand-off seam (see the wiring contract above), not a stub: every media branch renders correctly the moment Plan 04 publishes state. The reserved Shuffle/Repeat/seek slots are intentional D-09 empty spacers (future NOW-04 v2), documented in code.

## Threat Flags

None. The two display-side threats in the plan's `<threat_model>` are mitigated as planned: T-04-09 (title/artist bounded with `.lineLimit(1)`+`.truncationMode(.tail)`), T-04-10 (EqualizerBars drops `.repeatForever` when paused). T-04-11 (nil/invalid art) falls to the music.note placeholder. No new security surface introduced (pure view layer, no network/file/auth/schema).

## Deferred to Plan 04 On-Device UAT (per 04-VALIDATION.md)

- D-04 idle-CPU ~0% when paused (`sample Islet` / Energy idle) — the gating is correct in code but the CPU result is on-device-only.
- NOW-01 live art/title/artist render from the real session.
- NOW-02 transport buttons reaching the live MediaRemote session.
- D-12 launch-fail showing "nicht verfügbar"; D-13 mid-drop clearing state.

## Self-Check: PASSED

- Files verified on disk: `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `.planning/phases/04-now-playing/04-03-SUMMARY.md` — all FOUND.
- Commits verified in git: `b26c332` (Task 1), `3b5cbb3` (Task 2) — all FOUND.
- Static checks: `struct EqualizerBars` present (1); `@ObservedObject var nowPlaying` present; `.repeatForever` only in the isPlaying-true branch; transport closures + ⏪⏯⏩ buttons present; `Text("Now Playing nicht verfügbar")` present; no shuffle/repeat/seek/star implementation (only comments). Build SUCCEEDED; 77 tests, 0 failures.

---
*Phase: 04-now-playing*
*Completed: 2026-06-27*
