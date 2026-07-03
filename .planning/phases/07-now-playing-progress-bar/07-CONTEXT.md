# Phase 7: Now Playing Progress Bar - Context

**Gathered:** 2026-07-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 adds a **display-only playback progress bar** to the expanded Now Playing view:
a horizontal bar showing position within the current track, plus elapsed/total time
labels, updating smoothly while playing and holding perfectly still while paused. Covers
**PBAR-01** only.

**In scope:** the bar itself, the two time labels, the visual/color treatment, the
vertical layout change needed to fit them into the existing expanded island, and the
update mechanism that makes the bar move smoothly between MediaRemote's own snapshot
pushes.

**Explicitly NOT in this phase:**
- **Tap-to-seek / drag-to-seek** — REQUIREMENTS.md Out of Scope: adds gesture complexity
  out of scope for a display-only polish milestone. The bar is inert to clicks/drags.
- **Shuffle/Repeat controls, sneak-peek, color-adaptive tint, waveform on artwork** — all
  pre-existing v2 deferrals from Phase 4 (04-CONTEXT.md), untouched here.
- **Fullscreen-flash fix** — that's Phase 8 (FS-01), a separate, unrelated requirement.
- **Widening the Spotify/Apple-Music source allowlist** — Phase 4 D-01, unchanged.
</domain>

<decisions>
## Implementation Decisions

### Time label format & placement
- **D-01:** Right-side label shows **total track duration**, not a counting-down
  "remaining" value — format `elapsed / total`, e.g. **"1:23 / 3:45"**. This resolves a
  wording conflict in REQUIREMENTS.md PBAR-01 (says "elapsed/remaining" but its own
  example `"1:23 / 3:45"` is elapsed/total): the **example wins**, "remaining" in the
  requirement text should be read as "the other/total time," not a countdown.
- **D-02:** Labels **flank the bar ends** on one row — elapsed immediately left of the
  bar, total immediately right (Apple Music mini-player style), not stacked below the bar
  on a separate row.

### Visual style & color
- **D-03:** The bar's **filled portion uses the app's accent color** (the same
  `@AppStorage` accent that already tints the equalizer bars and charging bolt — Phase 6
  D-11 pattern); the unfilled track portion stays a dim grey/white. Extends the existing
  "accent = the small living color" convention (Phase 6 CONTEXT `<specifics>`) to this bar.
- **D-04:** **Thin minimalist line** (~2-3pt tall, rounded caps) — not a thick Alcove-style
  capsule. Unobtrusive, Apple Music mini-player weight.
- **D-05:** Time label text **matches the existing title/artist typography** — secondary
  grey, not accent-tinted, consistent with how Artist text is already styled (D-10 in
  Phase 4 CONTEXT: `.foregroundStyle(.secondary)`).

### Layout & island height
- **D-06:** The expanded island **grows taller** (~16-20pt) to fit the bar + flanking
  labels — the currently reserved 4pt spacer (`mediaExpanded`, D-09 placeholder) is far too
  small for a real bar+labels row and is replaced, not reused as-is. Existing spacing
  elsewhere in the expanded layout is **not** compressed to compensate — no cramping
  tradeoffs on the art/title/artist row or the control row.
- Placement in the vertical stack: **between the top row (art/title/artist/bars) and the
  bottom control row** — the same position the 4pt spacer already occupies conceptually,
  just resized to fit the real content.

### Update smoothness
- **D-07:** The bar **animates continuously** while playing — a visibly gliding fill, not
  a once-per-second step/jump. This matches the "alive" feel of the equalizer bars
  (Phase 4 D-04, the app's first continuous animation) rather than introducing a visibly
  discrete second interaction pattern.
- **Technical basis (confirmed during discussion, not a request — feeds research/planning
  directly):** the `mediaremote-adapter` stream (`NowPlayingMonitor.swift`) only pushes a
  new snapshot on play/pause/track-change events, not continuously. A locally-driven UI
  timer is required to interpolate the displayed position between snapshots. The vendored
  `TrackInfo.Payload` (pinned commit `cf30c4f1af29b5829d859f088f8dbdf12611a046` per
  `project.yml`) already carries `durationMicros`, `elapsedTimeMicros`,
  `timestampEpochMicros`, and `playbackRate`, plus a ready-made drift-corrected
  `currentElapsedTime` computed property (`elapsedSeconds + (now - timestampSeconds) *
  rate`) — this is the extrapolation formula to reuse, not reinvent. **None of these
  fields currently flow through the app's own pure seam** (`TrackSnapshot` in
  `NowPlayingPresentation.swift` only carries `bundleIdentifier`/`isPlaying`/`title`/
  `artist`) — extending that seam (and `NowPlayingState`'s `@Published` model) to carry
  duration/elapsed/timestamp/rate is required plumbing, not a new architectural decision.
  This does **not** add polling of MediaRemote itself — only a local SwiftUI-side
  animation/timer recomputing from already-received data, preserving the "isolate all
  MediaRemote access behind one monitor, no re-spawning" mandate (CLAUDE.md).

### Claude's Discretion
- Exact bar height in points (~2-3pt), exact accent-vs-track color values, corner radius
  of the rounded caps, and the exact SwiftUI mechanism for the continuous local timer
  (e.g. `TimelineView`, a `Timer.publish`, or driving off the existing display-link-style
  approach the equalizer bars already use) — pick whichever fits the codebase's existing
  animation patterns.
- Whether the local UI timer runs only while the island is **expanded** (progress bar only
  ever renders there) to keep idle CPU ~0% when collapsed — consistent with the project's
  established idle-CPU discipline (no repeating timer while collapsed/not visible).
- Exact new expanded-island height value and how it composes with
  `NotchPillView.expandedSize` / `NotchGeometry`'s existing frame math — as long as it
  grows (D-06) and doesn't compress the existing rows.
- How the bar/labels render (or don't) during the D-12 "Now Playing nicht verfügbar" state
  and the D-11 no-media date/time state — these are different view branches
  (`mediaUnavailable`, `expandedIsland`) that this phase doesn't touch; the bar only
  appears in `mediaExpanded` (playing/paused).
- Whether pausing freezes the bar's fill position exactly at the last known elapsed value
  (implied by REQUIREMENTS.md "holds still while paused") vs. any other paused-state
  micro-behavior not explicitly discussed.

### Folded Todos
(None — no pending todos matched this phase.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 7: Now Playing Progress Bar"** (goal + 4 success
  criteria).
- `.planning/REQUIREMENTS.md` → **PBAR-01** (the locked requirement; note the
  elapsed/total-vs-remaining wording ambiguity resolved by D-01 above) and the **Out of
  Scope** table (tap-to-seek explicitly excluded).
- `.planning/PROJECT.md` — Key Decisions (accent = the small living color pattern, D-11
  from Phase 6) and Constraints.

### Now Playing code this phase extends (Phase 4's quartet)
- `Islet/Notch/NowPlayingPresentation.swift` — the pure seam. `TrackSnapshot` currently
  has NO duration/elapsed/timestamp/rate fields; `NowPlayingPresentation` enum
  (`.playing`/`.paused`/`.none`) will likely need to carry playback-position data through
  to the view, or a parallel struct/property will need to be threaded alongside it. The
  file-header comment's rationale for keeping `.unavailable` OUT of this enum (D-12 is an
  orthogonal axis) is the same discipline to preserve when adding position data.
- `Islet/Notch/NowPlayingState.swift` — the `@Published` model (`presentation`, `artwork`,
  `isHealthy`). Will need new `@Published` fields for duration/elapsed/timestamp/rate (or
  a bundled struct) so the view can read live position data.
- `Islet/Notch/NowPlayingMonitor.swift` — the ONLY file that imports `MediaRemoteAdapter`
  (isolation mandate, CLAUDE.md). `TrackSnapshot` construction (~line 74) currently drops
  `p.durationMicros`/`p.elapsedTimeMicros`/`p.timestampEpochMicros`/`p.playbackRate` on the
  floor — these need to flow through from here.
- `Islet/Notch/NotchPillView.swift` → `mediaExpanded(_:art:)` (~line 372-429) — the exact
  layout to modify: the `Spacer(minLength: 0).frame(height: 4)` at line 411 (labeled
  "D-09: reserved vertical room for the future seek bar") is the insertion point. Also
  `Self.expandedSize` (the panel's expanded frame constant) needs to grow per D-06.
- `IsletTests/NowPlayingPresentationTests.swift` — the existing pure-seam test suite to
  extend alongside any `TrackSnapshot`/presentation changes.

### Vendored dependency (position/duration data source)
- `project.yml` line ~19-20 — pins `ejbills/mediaremote-adapter` at commit
  `cf30c4f1af29b5829d859f088f8dbdf12611a046` (no tags exist upstream). Confirm this exact
  revision when researching — `TrackInfo.Payload` (in the package's `TrackInfo.swift`)
  exposes `durationMicros: Double?`, `elapsedTimeMicros: Double?`,
  `timestampEpochMicros: Double?`, `playbackRate: Double?`, and a computed
  `currentElapsedTime: TimeInterval?` that already does drift-corrected extrapolation
  (`elapsedSeconds + (now - timestampSeconds) * rate`, holds still when `isPlaying != true`)
  — reuse this formula rather than re-deriving it. The checked-out source lives under Xcode's
  DerivedData (`SourcePackages/checkouts/mediaremote-adapter/Sources/MediaRemoteAdapter/
  TrackInfo.swift`), which is a regenerated build artifact — re-locate it via
  `xcodebuild -resolvePackageDependencies` + a DerivedData search if it's not present, don't
  assume the path is stable across clean builds.
- `CLAUDE.md` → **"Now Playing — the MediaRemote reality"** — the wrapper's
  `getTrackInfo`/`onTrackInfoReceived` streaming model this phase's position updates ride on
  top of (no new IPC, no polling of MediaRemote itself).

### Prior-phase precedent for accent + typography reused here
- `.planning/phases/06-priority-resolver-settings-v1-ship/06-CONTEXT.md` → **D-11/D-12**
  (accent tints "lively" elements: bolt/equalizer/device icon; curated palette,
  persistence) — the pattern D-03 here extends to the progress bar.
- `.planning/phases/04-now-playing/04-CONTEXT.md` → **D-10** (title bold white / artist
  secondary grey typography) — the pattern D-05 here reuses for time labels; **D-09**
  (the reserved seek-bar spacer this phase fills in); **NOW-04** listed as the deferred
  seek/progress bar requirement this phase now implements the display half of (seek
  itself stays out of scope).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Accent color plumbing** already exists end-to-end (Settings → `@AppStorage` →
  `NotchPillView`'s `accent` parameter → equalizer bars / charging bolt) — the progress
  bar's fill (D-03) is a new consumer of an already-wired value, not new plumbing.
- **`EqualizerBars`** (~line 480) is the existing continuous-animation precedent — same
  "gate on `isPlaying`, freeze when paused" discipline (D-04/D-05 in Phase 4) the new bar's
  update timer (D-07) should follow.
- **`TrackInfo.Payload.currentElapsedTime`** (vendored package) is a ready-made,
  drift-corrected elapsed-time formula — avoids hand-rolling timestamp math.

### Established Patterns
- **Pure-seam + `@Published` model + thin glue** discipline (Phase 1-6 convention):
  extending `TrackSnapshot`/`NowPlayingPresentation` (pure) and `NowPlayingState`
  (`@Published`) is the correct layering for the new position data — do not compute
  elapsed-time-now math inside the view.
- **One-shot `DispatchWorkItem` for timed events, but a scoped continuous animation is
  already precedented** by the equalizer bars — the progress bar's local UI timer (D-07)
  is the second instance of this narrow exception, not a new architectural pattern.
- `matchedGeometryEffect(id: "island", ...)` on the expanded blob (`NotchShape` +
  `.frame(width:height:)` at `Self.expandedSize`) means the height change (D-06) flows
  through the existing morph animation automatically — no separate resize logic needed.

### Integration Points
- `mediaExpanded(_:art:)`'s existing `VStack(spacing: 6)` in `NotchPillView.swift` is where
  the bar+labels row replaces the current 4pt spacer.
- `NowPlayingMonitor.swift`'s `onTrackInfoReceived` closure (~line 70-79) is where the new
  fields get lifted out of `p` into an extended `TrackSnapshot`.
- The local continuous timer (D-07) should start/stop alongside the island's
  expanded/collapsed state (Claude's discretion note above) — likely hooked wherever
  `NotchWindowController` already knows the panel is expanded.

</code_context>

<specifics>
## Specific Ideas

- **The exact wording conflict in REQUIREMENTS.md** ("elapsed/remaining" text vs.
  "1:23 / 3:45" example) was raised and explicitly resolved: go with the example
  (elapsed/total), not the word "remaining."
- **"Apple Music mini-player" was the repeated visual reference** across both the time
  label placement and the bar shape/color choices — thin line, flanking labels, accent
  fill, secondary-grey numbers all point at that same minimal reference aesthetic (distinct
  from the "thick Alcove capsule" alternative, which was explicitly not chosen).

</specifics>

<deferred>
## Deferred Ideas

- **Tap/drag-to-seek** — already excluded by REQUIREMENTS.md Out of Scope; reconfirmed
  in scope discussion, not re-opened.
- **Accent-tinted time label numbers** — considered and rejected in favor of matching the
  existing title/artist grey typography (D-05).
- **Thick Alcove-style capsule bar** — considered and rejected in favor of the thin line
  (D-04).
- **Once-per-second stepped update** — considered and rejected in favor of continuous
  smooth animation (D-07).

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)

</deferred>

---

*Phase: 07-now-playing-progress-bar*
*Context gathered: 2026-07-04*
