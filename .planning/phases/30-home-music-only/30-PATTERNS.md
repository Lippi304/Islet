# Phase 30: Home Music-Only - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 5 (all modified, 0 new files)
**Analogs found:** 5 / 5 (all analogs are precedent additions within the same files — this phase is a pure internal refactor, no new file surface)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/IslandResolver.swift` (resolve() Home branch + enum cases) | store/reducer (pure) | transform | Same file's own Phase 28 round-4/5 additions (`.calendarExpanded`/`.weatherExpanded`/`.trayExpanded` cases + `selectedView` branching, lines 90-104) | exact — same function, same enum, same discipline |
| `Islet/Notch/NowPlayingState.swift` (+ `lastKnownTrack` field, + new small struct) | model (`@Published` carrier) | event-driven | Same file's own `hasPlayedSinceLaunch` field (lines 21-25) and `songChangeToast: TrackToast?` field (lines 26-33) | exact — same class, same "sticky snapshot" shape |
| `Islet/Notch/NotchWindowController.swift` (`handleNowPlaying()` — capture `lastKnownTrack`) | controller (AppKit glue) | event-driven | Same function's existing `hadPlayedSinceLaunch`/`previous`/`previousPosition` capture-before-mutate block (lines 1530-1555) | exact — same function, same capture discipline |
| `Islet/Notch/NotchPillView.swift` (`homeEmptyState`, `transportButton` hover bg, body switch wiring, `mediaExpanded` reuse for last-played) | component (SwiftUI view) | request-response (render-only) | `trayEmptyState` (lines 745-760) for the empty state; `mediaExpanded`/`transportButton` (lines 1490-1557) for the hover addition and last-played reuse | exact — direct copy-and-adapt templates named in CONTEXT.md D-09 |
| `IsletTests/IslandResolverTests.swift` (split `testExpandedHealthyNoMediaIsExpandedIdle` / `testHomeSelectedNoMediaReturnsExpandedIdle`) | test | request-response (pure function assertions) | Same file's existing `resolve(...)` test shape (e.g. `testHomeSelectedWithMediaPlayingShowsNowPlayingExpanded`, lines 261-271) | exact — same test file, same `resolve(...)` call/assert pattern |

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` (reducer, transform)

**Analog:** the file's own existing branches (no external analog needed — this is the single arbiter every prior phase extended in place)

**Enum shape** (lines 38-49) — add new cases alongside `.expandedIdle` (or replace it; A1 in RESEARCH.md leaves exact naming to executor):
```swift
enum IslandPresentation: Equatable {
    ...
    case expandedIdle                                      // expanded, healthy, nothing playing (date/time)
    case calendarExpanded                                  // Phase 28 / CALVIEW-01: month grid + day list
    case weatherExpanded                                   // 28-04 round 4: current-conditions full view
    case trayExpanded                                      // 28-04 round 5: dedicated files-only Tray view
}
```
Follow this exact per-case doc-comment convention (`// PhaseN / TAG: one-line rationale`) for whatever new case(s) replace `.expandedIdle`'s Home-branch role.

**`showsSwitcherRow(for:)` exhaustive switch** (lines 65-70) — MUST be updated in lockstep (Pitfall 2):
```swift
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .expandedIdle, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded: return true
    default: return false
    }
}
```
Any new Home last-played/empty case(s) belong in this list too (both render the switcher row, same as `.expandedIdle` did).

**Core reducer branch to change** (lines 89-105):
```swift
if isExpanded {
    if selectedView == .calendar { return .calendarExpanded }
    if selectedView == .weather { return .weatherExpanded }
    if selectedView == .tray { return .trayExpanded }
    if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
    if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
    return .expandedIdle
}
```
Replace the final `return .expandedIdle` with the `hasPlayedSinceLaunch`-gated branch (RESEARCH.md Pattern 1's illustrative shape):
```swift
    if hasPlayedSinceLaunch { return .homeLastPlayed }   // NEW — HOME-02
    return .homeEmpty                                     // NEW — HOME-03
```
Note: `resolve()` already receives `hasPlayedSinceLaunch: Bool` as a parameter (line 76) — no signature change needed, just consume the existing parameter in this branch.

**Error handling / validation:** none — `resolve()` is a TOTAL pure function (no throws, no optionals to unwrap beyond what's already handled). Keep it that way; no new failure paths introduced.

---

### `Islet/Notch/NowPlayingState.swift` (model, event-driven)

**Analog:** the file's own `hasPlayedSinceLaunch` (lines 21-25) and `songChangeToast: TrackToast?` (lines 26-33) fields — both are "sticky snapshot, session-only, orthogonal to `presentation`" fields, exactly what `lastKnownTrack` needs to be.

**Imports pattern** (line 1):
```swift
import AppKit
```
(Needed because artwork is `NSImage?` — same reason the file already imports AppKit for the existing `artwork` field.)

**Field to add** (append after line 37, following the existing doc-comment density convention):
```swift
// Phase 30 / HOME-02 — D-07/D-08: the most-recently-playing track, kept ALIVE across the
// transition to `.none` (unlike `presentation`/`artwork`, which the controller clears on
// stop). Session-only — never persisted, never reset except by app relaunch (fresh process
// state). Overwritten every time a NEW track starts .playing (D-08), never frozen on first
// capture. A dedicated struct (not a reuse of `TrackToast`, which is deliberately
// artwork-less) — see NowPlayingPresentation.swift's TrackToast doc comment for why that
// struct must stay title/artist-only.
@Published var lastKnownTrack: LastPlayedTrack? = nil
```
New struct — put it in `NowPlayingPresentation.swift` alongside `TrackToast` (same "plain value, Foundation/AppKit as needed" tier) or directly in `NowPlayingState.swift`; either is consistent with existing conventions:
```swift
struct LastPlayedTrack: Equatable {
    let title: String
    let artist: String
    let artwork: NSImage?
}
```
(`NSImage` is not `Equatable` by identity in a useful way for tests — mirror how `NowPlayingState.artwork` itself is already excluded from any `Equatable` conformance elsewhere; if a test needs equality, compare `title`/`artist` only, per project convention of keeping NSImage out of pure-seam equatable structs.)

---

### `Islet/Notch/NotchWindowController.swift` (`handleNowPlaying()`, controller/event-driven)

**Analog:** the same function's existing "capture pre-mutation value before it's overwritten" discipline, used 3 times already for `previous`, `previousPosition`, and `hadPlayedSinceLaunch`.

**Capture-before-mutate pattern** (lines 1543-1555, exact template):
```swift
// Phase 18 / NOW-05 (Pitfall 2) — capture the PRE-mutation hasPlayedSinceLaunch value
// before the line below overwrites it, mirroring how `previous`/`previousPosition` are
// captured before their own overwrites just above.
let hadPlayedSinceLaunch = nowPlayingState.hasPlayedSinceLaunch

// Phase 17 / NOW-04 — D-01/D-02: first real Play observed this Islet run lifts the launch
// gate permanently. Set BEFORE the render call below so the triggering snapshot itself
// isn't gated.
if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }
```
Add the `lastKnownTrack` capture with the SAME discipline, inside the `withAnimation` spring block (lines 1557-1592), BEFORE the existing artwork nil-clear logic runs (Pitfall 1 — read `art`/`p` at the point they're already in scope):
```swift
withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
    nowPlayingState.presentation = p
    ...
    // Phase 30 / HOME-02 (D-07/D-08): capture the sticky last-played snapshot BEFORE the
    // existing artwork nil-clear below runs (Pitfall 1) — overwritten on every NEW .playing
    // track, never touched on .paused/.none so it survives the stop transition.
    if case .playing(let title, let artist) = p {
        nowPlayingState.lastKnownTrack = LastPlayedTrack(title: title, artist: artist, artwork: art ?? nowPlayingState.artwork)
    }
    // existing artwork nil-clear logic (lines 1573-1577) stays UNCHANGED — do not
    // repurpose nowPlayingState.artwork's clear-on-.none contract (RESEARCH.md Pattern 2 /
    // Pitfall 1: read lastKnownTrack.artwork in the last-played branch, never
    // nowPlaying.artwork directly).
    if let art {
        nowPlayingState.artwork = art
    } else if p == .none || !isSameTrack(previous, p) {
        nowPlayingState.artwork = nil
    }
    renderPresentation()
    ...
}
```

**Error handling:** none new — `handleNowPlaying` has no throwing calls; the existing `if let art` / `switch p` optionality handling is the full extent of "error handling" in this pure-state-mutation function.

---

### `Islet/Notch/NotchPillView.swift` (SwiftUI view, request-response/render-only)

**Analog 1 — `trayEmptyState`** (lines 745-760) for the new `homeEmptyState` (D-09, LOCKED — exact code already verified by gsd-ui-checker in `30-UI-SPEC.md` lines 122-139):
```swift
private var trayEmptyState: some View {
    VStack(spacing: 4) {
        Image(systemName: "tray")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
        Text("No files yet")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        Text("Drag files onto the notch to add them here.")
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.top, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```
Copy verbatim as `homeEmptyState`, swap icon `"tray"` → `"music.note"`, heading → `"Nothing Playing"`, body → `"Start something in Spotify or Music."` (D-10, LOCKED). Wrap in `blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top, showSwitcher: true) { ... }` per 30-UI-SPEC.md line 143 (matching `expandedIsland`/`mediaExpanded`'s own `blobShape` call convention, lines 443-444 / 1497-1498).

**Analog 2 — `mediaExpanded` + `transportButton`** (lines 1490-1557) for last-played reuse (D-04) and hover background (D-05):

Body switch wiring point (lines 337-363) — add new case(s) mirroring the existing `.expandedIdle` line:
```swift
case .nowPlayingExpanded(let p, true):
    mediaExpanded(p, art: nowPlaying.artwork)                        // NOW-01/02 controls (healthy)
case .nowPlayingExpanded(_, false):
    mediaUnavailable                                                 // D-12 "nicht verfügbar"
case .expandedIdle:
    expandedIsland                                                   // D-11 date/time (healthy, no media)
```
New last-played case feeds `mediaExpanded` a synthesized presentation built from `lastKnownTrack` (RESEARCH.md Pattern 1):
```swift
case .homeLastPlayed:
    let last = nowPlaying.lastKnownTrack
    mediaExpanded(.paused(title: last?.title ?? "", artist: last?.artist ?? ""),
                  art: last?.artwork)
case .homeEmpty:
    homeEmptyState
```
Do NOT write a second view function — feed the existing `mediaExpanded(_:art:)` different data (D-04: byte-identical rendering, per 30-UI-SPEC.md's explicit contract).

`transportButton` — current state (lines 1549-1557):
```swift
private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
}
```
Add hover background per 30-UI-SPEC.md Layout Contract (lines 105-116, exact starting values — tune on-device per project convention):
```swift
private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    @State var isHovering = false   // per-instance local hover state (SwiftUI gives each call site its own storage)
    return Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.12) : Color.clear)
            )
            .frame(width: 32, height: 32)
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
}
```
Note: `@State` inside a helper function returning `some View` needs to live on a wrapper view struct in practice, not literally inside a free function body — the executor should follow whatever the existing file's convention is for per-instance local view state (check if `transportButton` needs to become a small private `TransportButton: View` struct with `@State private var isHovering = false`, since a plain function can't hold `@State`). This is an implementation detail flagged for the executor, not a locked API — 30-UI-SPEC.md's Layout Contract only locks the visual/behavioral contract (shape, size, fill, trigger), not the exact Swift mechanism.

**`expandedIsland`** (lines 436-459) — becomes dead code for the Home path per RESEARCH.md Open Question 2 (recommend: delete, since Weather/Calendar have their own dedicated `weatherFullView`/`calendarFullView` and don't call it). Grep for `expandedIsland` before deleting to confirm zero remaining callers.

**Preview section** (line 1895) — `IslandPresentationState(.expandedIdle)` preview needs updating to whatever new case replaces it (RESEARCH.md Assumption A3, low-risk, Xcode-canvas-only).

---

### `IsletTests/IslandResolverTests.swift` (test, request-response)

**Analog:** the file's own existing `resolve(...)` test shape, e.g. `testHomeSelectedWithMediaPlayingShowsNowPlayingExpanded` (lines 261-271):
```swift
func testHomeSelectedWithMediaPlayingShowsNowPlayingExpanded() {
    let r = resolve(activeTransient: nil,
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: true,
                    selectedView: .home)
    XCTAssertEqual(r, .nowPlayingExpanded(.playing(title: "Song", artist: "Artist"), healthy: true))
}
```

Tests to REWRITE, not delete (Pitfall 3) — split each of these two on `hasPlayedSinceLaunch`:
```swift
// OLD (line 194-202):
func testExpandedHealthyNoMediaIsExpandedIdle() {
    let r = resolve(activeTransient: nil, nowPlaying: .none, nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true, isExpanded: true)
    XCTAssertEqual(r, .expandedIdle)
}
// NEW — split into two:
func testExpandedHealthyNoMediaHasPlayedShowsLastPlayed() {
    let r = resolve(activeTransient: nil, nowPlaying: .none, nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true, isExpanded: true)
    XCTAssertEqual(r, .homeLastPlayed)   // or whatever case name the executor picks
}
func testExpandedHealthyNoMediaNeverPlayedShowsEmpty() {
    let r = resolve(activeTransient: nil, nowPlaying: .none, nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: false, isExpanded: true)
    XCTAssertEqual(r, .homeEmpty)
}
```
Same split for `testHomeSelectedNoMediaReturnsExpandedIdle` (lines 273-283), parametrized identically on `selectedView: .home` + `hasPlayedSinceLaunch`.

**Validation command:** `xcodebuild build -scheme Islet` (build-gate only per project memory `xcodebuild-test-headless-hang`); full `IslandResolverTests` run via manual Cmd-U in Xcode.

---

## Shared Patterns

### Single-arbiter discipline (applies to IslandResolver.swift only)
**Source:** `Islet/Notch/IslandResolver.swift` header comment (lines 1-33) + RESEARCH.md Anti-Patterns
**Apply to:** The last-played/empty-state branching MUST live inside `resolve()`. Never add an `if hasPlayedSinceLaunch { ... } else { ... }` inside `NotchPillView`'s body switch — the view only renders the resolver's verdict.

### Capture-before-mutate (applies to NotchWindowController.swift's `handleNowPlaying()`)
**Source:** `Islet/Notch/NotchWindowController.swift:1543-1555` (existing `hadPlayedSinceLaunch`/`previous`/`previousPosition` captures)
**Apply to:** `lastKnownTrack` capture — read/update it BEFORE the existing artwork nil-clear logic runs, inside the same `withAnimation` spring block.

### Exhaustive-switch lockstep (applies to IslandResolver.swift + NotchPillView.swift)
**Source:** `Islet/Notch/IslandResolver.swift:58-70` (WR-01 fix comment) — RESEARCH.md Pitfall 2
**Apply to:** Any new/renamed `IslandPresentation` case must be added to ALL of: `showsSwitcherRow(for:)`, `resolve()`, `NotchPillView`'s body `switch presentation` (line 337), and the SwiftUI preview section (~line 1895). Keep every switch exhaustive (no `default:`) so a missed case is a compile error, not a silent bug.

### Reuse over duplication for byte-identical states (applies to NotchPillView.swift)
**Source:** `mediaExpanded(_:art:)` (lines 1490-1545)
**Apply to:** Feed the SAME view function different data for live vs. last-played (D-04) rather than writing a parallel view — matches 30-UI-SPEC.md's explicit "byte-identical, not merely visually matching" requirement.

## No Analog Found

None — every file in this phase is a modification to an existing, well-precedented file; each has a directly analogous prior addition (Phase 17/18/28's own extensions to the same functions) to copy the shape from.

## Metadata

**Analog search scope:** `Islet/Notch/` (IslandResolver.swift, IslandPresentationState.swift, NowPlayingState.swift, NowPlayingPresentation.swift, NotchPillView.swift, NotchWindowController.swift), `IsletTests/IslandResolverTests.swift`
**Files scanned:** 7 (all fully or targeted-range read this session; no file exceeded 2,022 lines requiring more than 2 non-overlapping reads)
**Pattern extraction date:** 2026-07-14
