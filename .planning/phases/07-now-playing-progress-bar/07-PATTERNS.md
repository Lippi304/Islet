# Phase 7: Now Playing Progress Bar - Pattern Map

**Mapped:** 2026-07-04
**Files analyzed:** 5 (all modifications — no new files required per RESEARCH.md's
"Recommended Project Structure")
**Analogs found:** 5 / 5 (all self-analogs: extend the file's own established
conventions; 2 files also have a strong cross-file precedent)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NowPlayingPresentation.swift` | model (pure seam) | transform | self (extend in place); secondary: `Islet/Notch/PowerActivity.swift` (same pure-seam idiom family) | exact |
| `Islet/Notch/NowPlayingState.swift` | store/provider (`@Published` model) | event-driven | self (extend in place) | exact |
| `Islet/Notch/NowPlayingMonitor.swift` | service (thin glue / monitor) | streaming, event-driven | self (extend in place) | exact |
| `Islet/Notch/NotchPillView.swift` | component (SwiftUI view) | request-response (render) + streaming (continuous animation) | self — `EqualizerBars` struct (lines 491-547) in the SAME file is the load-bearing precedent for the new `ProgressBar` subview | exact |
| `IsletTests/NowPlayingPresentationTests.swift` | test | transform (unit test of pure function) | self (extend in place) | exact |

No file in this phase requires searching outside the existing "Phase-4 quartet" — every
file already exists and already has the exact pattern to extend inside itself or in a
sibling file in the same directory. This is a plumbing/extension phase, not new-surface
work.

## Pattern Assignments

### `Islet/Notch/NowPlayingPresentation.swift` (model, transform)

**Analog:** itself — the file's own existing `TrackSnapshot` / `NowPlayingPresentation` /
`nowPlayingPresentation(from:)` conventions. Confirmed via full read (69 lines).

**Full current content (this is the file to extend, not replace):**
```swift
// lines 22-27 — the pure DTO to extend with 4 new optional fields
struct TrackSnapshot: Equatable {
    let bundleIdentifier: String?  // the source app — checked against allowedBundleIDs (D-01)
    let isPlaying: Bool?           // nil → state unknown (A4: treat as paused)
    let title: String?             // nil / empty → nothing to show → .none
    let artist: String?            // nil → "" so the title still renders
}

// lines 31-35 — the presentation enum; CONTEXT.md flags this as the payload that may need
// duration/elapsed/timestamp/rate threaded through (either as new case params or a
// parallel struct/property)
enum NowPlayingPresentation: Equatable {
    case playing(title: String, artist: String)
    case paused(title: String, artist: String)
    case none   // healthy API, nothing playing / non-allowlisted source (D-11)
}

// lines 42-50 — the TOTAL pure mapping function to extend with the same guard-and-map style
func nowPlayingPresentation(from s: TrackSnapshot?) -> NowPlayingPresentation {
    guard let s,
          let bundle = s.bundleIdentifier, allowedBundleIDs.contains(bundle),  // D-01 allowlist
          let title = s.title, !title.isEmpty                                   // empty/nil title → none
    else { return .none }
    let artist = s.artist ?? ""
    return (s.isPlaying == true) ? .playing(title: title, artist: artist)       // A4: nil isPlaying → paused
                                 : .paused(title: title, artist: artist)
}
```

**Convention to copy for the new fields:** every field on `TrackSnapshot` is `Optional`
and nil-safety is resolved INSIDE the pure mapping function (never with force-unwraps or
in the view) — e.g. `artist ?? ""`. The 4 new fields (`durationMicros`, `elapsedTimeMicros`,
`timestampEpochMicros`, `playbackRate`) must follow the identical `Double?` + explicit
guard/fallback discipline RESEARCH.md's Pitfall 5 calls out (UI-SPEC.md's fallback
decision: reserve the row height, render at `opacity(0)` when nil, never a "--:--" branch
that changes layout).

**Pure-formula-to-port pattern (RESEARCH.md Pattern 2, source-verified against the
vendored package, must be reimplemented as a plain function here, not imported):**
```swift
// Port this EXACT branching into a new pure function in this file (e.g.
// currentElapsedSeconds(elapsed:timestamp:rate:isPlaying:now:) -> TimeInterval?).
// Source: vendored TrackInfo.Payload.currentElapsedTime (pinned commit
// cf30c4f1af29b5829d859f088f8dbdf12611a046) — copy the LOGIC, not the type.
if isPlaying != true {
    return elapsedSeconds   // paused/unknown → freeze exactly here (D-07 "holds still")
}
let timeSinceUpdate = now - timestampSeconds
return elapsedSeconds + (timeSinceUpdate * rate)
```
Do NOT let the paused branch touch `now`/`context.date` at all — the guard must come
FIRST, mirroring the vendored source exactly (RESEARCH.md Pitfall 1).

**Secondary analog for the "pure seam" idiom family** (confirms this is the established
project-wide pattern, not unique to Now Playing): `Islet/Notch/PowerActivity.swift` uses
the same "plain struct DTO + total mapping function, Foundation-only, no framework
imports" shape referenced in this file's own header comment ("Like NotchGeometry,
NotchInteractionState, and PowerActivity...").

---

### `Islet/Notch/NowPlayingState.swift` (store/provider, event-driven)

**Analog:** itself — full file already read (22 lines), reproduced below in full since it
is the entire pattern to extend.

```swift
final class NowPlayingState: ObservableObject {
    // The classified media presentation (D-11 .none = healthy, no media).
    @Published var presentation: NowPlayingPresentation = .none
    // The pre-decoded album art (arrives with the payload, may be nil → placeholder).
    @Published var artwork: NSImage?
    // D-12 health axis, ORTHOGONAL to presentation.
    @Published var isHealthy: Bool = true
}
```

**Convention to copy:** ONE `@Published` field per orthogonal axis, each with a one-line
comment explaining WHY it's separate from the others (mirrors `ChargingActivityState`'s
discipline per this file's own header comment). "Plain published holder: no methods, no
timers, no MediaRemote."

**Important architectural note for the planner (confirmed by reading `IslandResolver.swift`
via grep):** `IslandPresentation.nowPlayingExpanded(NowPlayingPresentation, healthy: Bool)`
already carries the WHOLE `NowPlayingPresentation` enum value through to the view — it does
NOT unpack title/artist into separate fields. **If the 4 new fields are added as
associated values on the `NowPlayingPresentation` enum cases (in
`NowPlayingPresentation.swift`) rather than as new `@Published` properties on
`NowPlayingState`, they flow through `IslandResolver`/`IslandPresentationState` to
`NotchPillView` automatically with ZERO changes needed in this file or in
`IslandResolver.swift`.** This is the lower-plumbing option and is consistent with how
title/artist already flow today. Only add new `@Published` fields here if the planner
decides the enum-case-payload route is too heavy (e.g. wants to avoid growing every enum
case's arity) — CONTEXT.md leaves this "which of the seam vs the model carries the new
data" as required plumbing to decide, not the enum-vs-published choice itself.

---

### `Islet/Notch/NowPlayingMonitor.swift` (service, streaming/event-driven)

**Analog:** itself — the exact insertion point already exists and is documented in-line.

**Imports pattern (lines 1-2, unchanged — no new imports needed):**
```swift
import MediaRemoteAdapter
import AppKit
```
This remains the ONLY file importing `MediaRemoteAdapter` (isolation mandate,
CLAUDE.md/RESEARCH.md) — the 4 new fields must be lifted HERE and nowhere else.

**Core streaming pattern — the exact lift-and-construct site to extend (lines 69-82):**
```swift
func start() {
    controller.onTrackInfoReceived = { [weak self] info in
        guard let self else { return }
        // NIL payload → no media (D-11). No second main-hop (the wrapper already hopped).
        guard let p = info?.payload else { self.onSnapshot(nil, nil); return }
        let snap = TrackSnapshot(bundleIdentifier: p.bundleIdentifier,
                                 isPlaying: p.isPlaying,
                                 title: p.title,
                                 artist: p.artist)
        self.onSnapshot(snap, p.artwork)   // artwork already off-thread-decoded by the wrapper
    }
    controller.onListenerTerminated = { [weak self] in self?.onTerminated() }   // D-13
    controller.startListening()   // ONE persistent `loop` child — emits the current session immediately
}
```
**Pattern to copy:** add the 4 new fields (`p.durationMicros`, `p.elapsedTimeMicros`,
`p.timestampEpochMicros`, `p.playbackRate`) as additional `TrackSnapshot(...)` constructor
arguments in this SAME closure — no new closures, no new lifecycle hooks, no polling. This
is a one-line struct-literal change once `TrackSnapshot` itself gains the new fields.

**Anti-pattern explicitly documented in this file's own header (do not violate):**
`getTrackInfo` (lines 96-107, the ONE-SHOT variant used only by `runHealthCheck`) must
NEVER be called on a timer for live position updates — RESEARCH.md Pitfall 4 restates this
exact file's own in-line warning ("used ONLY for the launch health probe, NEVER for live
updates").

---

### `Islet/Notch/NotchPillView.swift` (component, request-response render + streaming animation)

**Analog:** itself — `EqualizerBars` (lines 491-547) is the load-bearing continuous-animation
precedent; `mediaExpanded(_:art:)` (lines 372-429) is the exact layout insertion point;
the `accent` environment read (line 51) is the color-plumbing precedent.

**Continuous-animation pattern to mirror EXACTLY for the new `ProgressBar` (source,
lines 519-547, full struct already read):**
```swift
// ⚠️ THE IDLE-CPU TRAP (D-04 / Pitfall 5): the `.animation(...)` MUST be CONDITIONAL on
// `isPlaying`. When not playing it passes a FINITE `.default` animation — NOT a left-on
// `.repeatForever`. A `.repeatForever` left attached keeps SwiftUI's render loop / display
// link alive even when the bars look static, so idle CPU never returns to ~0.
struct EqualizerBars: View {
    let isPlaying: Bool                 // D-04: the SINGLE gate
    var tint: Color = .white
    // ...

    // TIME-DRIVEN (not @State-driven) so the loop is IMMUNE to ambient withAnimation(.spring)
    // transactions. TimelineView(.animation, paused: !isPlaying) ticks each frame while
    // playing and STOPS entirely when paused (no clock → idle CPU ~0, D-04 / Pitfall 5).
    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<Self.barCount, id: \.self) { i in
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.5, height: height(i, at: t))
                }
            }
            .frame(height: boxHeight)
        }
    }
}
```
**Pattern to copy for `ProgressBar`:** same `TimelineView(.animation(paused: !isPlaying))`
gate, same "single boolean gate, no `@State`-driven clock" discipline. Per D-07/UI-SPEC.md,
compute `elapsed = currentElapsedSeconds(...)` (the ported pure formula from
`NowPlayingPresentation.swift`) inside the `context in` closure — NOT raw `context.date`
math done directly in the view (RESEARCH.md's explicit anti-pattern: "Computing 'now minus
timestamp' math inside the SwiftUI view body directly on raw micros... breaks the
pure-seam/`@Published`-model/thin-glue layering").

**Accent-color consumption pattern to copy (lines 51, 401 — exact source):**
```swift
@Environment(\.activityAccent) private var accent
// ...
EqualizerBars(isPlaying: isPlaying, tint: accent)   // D-11 accent on the bars
```
The new bar's filled `Capsule` reads this SAME `accent` value (D-03) — zero new plumbing.

**Layout insertion point (exact current code to replace, line 411):**
```swift
// D-09: reserved vertical room for the future seek bar (NOT built — NOW-04 v2).
Spacer(minLength: 0).frame(height: 4)
```
This single line, inside the `VStack(spacing: 6)` at lines 384-424 (between the
art/title/artist/bars `HStack` ending at line 409 and the transport-button `HStack`
starting at line 413), is where the new `ProgressBar` + labels row goes. Per UI-SPEC.md,
target row height is 20pt (vs. the current 4pt spacer).

**Height-constant update (lines 74-93, exact arithmetic comment to edit in sync):**
```swift
static let expandedSize = CGSize(width: 360, height: 128)
```
Per UI-SPEC.md's math: `128 → 144` (84pt old content − 4pt removed spacer + 20pt new row =
100pt content; 32 clearance + 100 content + 12 bottom inset = 144). **Confirmed via
`grep -rn "expandedSize" Islet/` (RESEARCH.md Pitfall 3 / A2 resolved — genuinely single
source of truth):** the only OTHER consumers are `NotchGeometry.swift:64-67`
(`expandedNotchFrame(collapsed:expandedSize:)`, a pure function taking the value as a
parameter) and `NotchWindowController.swift:209`
(`private let expandedSize = NotchPillView.expandedSize`, a direct re-read of the same
constant). **No second hard-coded height exists** — updating this one `static let` is
sufficient; no parallel constant needs to be found/updated.

**Gesture-exclusion pattern to preserve (lines 404-409, exact existing discipline):**
```swift
// Finding 15 (06-10): tap-to-toggle scoped ONLY to this non-button top row
// (art/title/artist/bars) — never to the enclosing VStack or the bottom
// HStack below, which holds the transport Buttons.
.onTapGesture { onClick() }
```
The new `ProgressBar` row must NOT be inside the scope that carries this `.onTapGesture`
(UI-SPEC.md's Interaction Contract: the bar/labels are inert, no tap/drag of any kind) —
place it in its own scope in the `VStack`, matching how the transport-button `HStack`
below is already excluded from this same gesture today.

**Time-label typography pattern to copy (lines 388-398, exact source for the Artist
style D-05 says the new labels must match):**
```swift
Text(meta.artist)
    .font(.system(size: 12, design: .rounded))
    .foregroundStyle(.secondary)   // grey (D-10)
    .lineLimit(1)
    .truncationMode(.tail)
```
UI-SPEC.md specifies 11pt (not 12pt) for the new time labels but the SAME `.rounded`
design + `.secondary` color + no accent — add `.monospacedDigit()` per UI-SPEC.md (not
present on the artist label today, a new but small addition for this phase only).

---

### `IsletTests/NowPlayingPresentationTests.swift` (test, transform)

**Analog:** itself — full file already read (113 lines), the established naming/structure
convention to extend.

**Pattern to copy (exact style — `// MARK:` grouped by requirement ID, `TrackSnapshot`
built by hand, `XCTAssertEqual` against the pure function's output):**
```swift
// MARK: NOW-01 — title/artist mapping; empty/nil title → .none

func testNoTitleMapsToNone() {
    // Allowlisted source but no title (nil) → nothing meaningful to show → .none.
    let nilTitle = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                 isPlaying: true, title: nil, artist: "Artist")
    XCTAssertEqual(nowPlayingPresentation(from: nilTitle), .none)
}
```
**New test cases to add, following this exact `// MARK: PBAR-01 — ...` + hand-built
`TrackSnapshot` + `XCTAssertEqual` shape:**
1. Duration/elapsed/timestamp/rate correctly flow from `TrackSnapshot` into the extended
   `NowPlayingPresentation` payload (mirrors `testPlayingVsPausedClassification`'s shape).
2. The ported pure elapsed-time formula matches the vendored math for the PLAYING case
   (elapsed + (now − timestamp) × rate).
3. The ported formula's PAUSED-freeze branch returns `elapsedSeconds` unchanged regardless
   of `now`/`timestamp` drift (directly tests RESEARCH.md Pitfall 1's guardrail —
   `testXxxPausedFreezesElapsed` in the same naming convention as
   `testNilIsPlayingMapsToPaused`).
4. Nil duration/elapsed/timestamp fallback behavior per UI-SPEC.md's Copywriting Contract
   decision (row renders but bar/labels are semantically "no data" — mirrors
   `testNilSnapshotMapsToNone`'s "document the fallback, don't crash" shape).

## Shared Patterns

### Pure-seam + `@Published` model + thin-glue layering (applies to all 4 non-test files)
**Source:** the existing Phase-4 quartet's own file-header comments (`NowPlayingPresentation.swift`
lines 1-16, `NowPlayingMonitor.swift` lines 4-33).
**Apply to:** `NowPlayingPresentation.swift` (pure math/classification), `NowPlayingMonitor.swift`
(thin lift, zero logic), `NowPlayingState.swift` (plain published holder, zero logic),
`NotchPillView.swift` (render only, reads already-computed values — never computes
"now minus timestamp" itself).
```
Raw payload (vendored, optional fields)
   -> NowPlayingMonitor lifts fields into TrackSnapshot (thin, no logic)
   -> NowPlayingPresentation.swift classifies + computes pure elapsed-time formula
   -> NowPlayingState / IslandPresentation carries the classified value
   -> NotchPillView renders it inside a TimelineView tick, no raw math
```

### Idle-CPU-gated `TimelineView` continuous animation (applies to `NotchPillView.swift` only)
**Source:** `EqualizerBars`, `Islet/Notch/NotchPillView.swift` lines 519-547 (exact code
reproduced above under that file's Pattern Assignment).
**Apply to:** the new `ProgressBar` subview — `TimelineView(.animation(paused: !isPlaying))`,
never a `Timer`/Combine publisher stored in app state (RESEARCH.md's explicit anti-pattern,
also stated in this file's own header comment D-08: "This is the VIEW LAYER only. It drives
NO animation itself").

### Accent-color environment consumption (applies to `NotchPillView.swift` only)
**Source:** `Islet/Notch/NotchPillView.swift` line 51 (`@Environment(\.activityAccent)`)
and line 401 (`EqualizerBars(isPlaying:tint:)` call site).
**Apply to:** the new `ProgressBar`'s filled-portion `Capsule` — reuse the already-injected
`accent` value, D-03. No new environment key, no new `@AppStorage` read.

### Optional-field defensive mapping (applies to `NowPlayingPresentation.swift` and its tests)
**Source:** `Islet/Notch/NowPlayingPresentation.swift` lines 42-50 (`nowPlayingPresentation(from:)`'s
guard/nil-coalesce style) and `IsletTests/NowPlayingPresentationTests.swift`'s
`testNoTitleMapsToNone`/`testNilIsPlayingMapsToPaused`.
**Apply to:** the 4 new `Double?` fields — same "guard, fall back to a defined default,
unit-test the fallback branch explicitly" discipline, never a force-unwrap.

## No Analog Found

None — every file in this phase's scope is a targeted extension of an existing,
already-idiomatic file; no new architectural surface (no new controller, no new service
class, no new file) is required per RESEARCH.md's "Recommended Project Structure"
conclusion ("No new files strictly required").

## Metadata

**Analog search scope:** `Islet/Notch/` (5 files read in full: `NowPlayingPresentation.swift`,
`NowPlayingState.swift`, `NowPlayingMonitor.swift`, `NotchPillView.swift`,
`IsletTests/NowPlayingPresentationTests.swift`); `grep -rn "expandedSize" Islet/` to confirm
RESEARCH.md's A2 assumption (single source of truth — confirmed, no second hard-coded
height); `grep -n "nowPlayingExpanded\|enum IslandPresentation"` against
`IslandResolver.swift` to confirm the enum-payload passthrough architecture.
**Files scanned:** 5 read in full + 2 targeted greps (no file exceeded 2,000 lines; no
offset/limit reads were necessary).
**Pattern extraction date:** 2026-07-04
