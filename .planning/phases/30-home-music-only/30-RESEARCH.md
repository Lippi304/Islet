# Phase 30: Home Music-Only - Research

**Researched:** 2026-07-14
**Domain:** SwiftUI/AppKit native macOS app — presentation-state routing + view composition (no new external dependencies)
**Confidence:** HIGH

## Summary

This phase is a pure internal refactor of an already-mature architecture — no new libraries, no new frameworks, no new external state. Everything HOME-01/02/03 need already exists in the codebase in adjacent form: `NowPlayingState.hasPlayedSinceLaunch` is the exact boolean HOME-03 needs, `trayEmptyState` is the exact template for the new empty state, and `mediaExpanded(_:art:)` is the exact view HOME-02 needs to reuse verbatim (per D-04, last-played renders through the SAME function as live, just fed different data). The single load-bearing change is in `IslandResolver.resolve()`: the existing `.expandedIdle` fallback branch (`nowPlaying == .none` inside `isExpanded && selectedView == .home`) must become a `hasPlayedSinceLaunch`-gated branch to two new cases (or reused `.nowPlayingExpanded` fed sticky data + one new empty-state case).

The codebase's existing "single arbiter" discipline (all of Phase 6/26/28's commentary) means this branching MUST live inside `resolve()`, not duplicated in the view. The two genuinely new things to build are: (1) `NowPlayingState.lastKnownTrack: TrackToast?` (or similar; the existing `TrackToast` struct — `title`+`artist` — is already the exact shape needed, though it lacks artwork; a new small struct carrying title/artist/artwork is likely needed since `TrackToast` deliberately has no NSImage field per its own doc comment) and (2) the transport-button hover background (D-05), a straightforward `.onHover` + `RoundedRectangle` addition to the existing `transportButton(_:action:)` helper.

**Primary recommendation:** Reuse `mediaExpanded(_:art:)` unchanged in structure — feed it a synthesized `NowPlayingPresentation` (`.paused(title:artist:)`) built from `lastKnownTrack` when in the last-played state, rather than writing a second, parallel view. Add exactly one new `IslandPresentation` case (or repurpose `.expandedIdle`'s slot) for the empty state, and update `resolve()`'s Home branch to check `hasPlayedSinceLaunch` before falling through.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Last-played vs. empty-state routing | Pure reducer (`IslandResolver.resolve()`) | — | Single-arbiter discipline already established (Phase 6 D-05); every prior phase (17, 18, 28) added its branching here, never in the view |
| `lastKnownTrack` sticky capture | `NotchWindowController.handleNowPlaying()` (AppKit glue) | `NowPlayingState` (published storage) | Mirrors exactly how `hasPlayedSinceLaunch` and `songChangeToast` are already captured — inside the same spring-animated mutation block, main-actor, no new threading |
| Empty-state / last-played rendering | SwiftUI view (`NotchPillView.swift`) | — | Render-only per Phase 6 discipline: the view never decides precedence, it only switches on the resolver's verdict |
| Transport-button hover style | SwiftUI view (`transportButton` helper) | — | Purely visual, no state-model change; `.onHover` is local view state |

## Standard Stack

No new packages. This phase touches only existing first-party Swift/SwiftUI/AppKit code already in the repo.

### Core
| Component | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `.onHover` | ships with SDK | Transport-button hover background (D-05) | Already the established hover mechanism in this file (collapsed-pill hover bounce); no gesture library needed |
| Existing `IslandResolver.resolve()` pure reducer | n/a (in-repo) | Single arbiter for last-played/empty routing | Established project convention since Phase 6; every subsequent phase (17/18/26/28) added branching here |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Feeding `mediaExpanded` a synthesized `.paused(...)` from `lastKnownTrack` | A second, parallel `lastPlayedExpanded` view duplicating `mediaExpanded`'s layout | Duplicating ~50 lines of layout code the moment the two states must ever diverge visually (they currently must NOT, per D-04) — reuse is strictly preferred and matches "byte-identical, not merely visually matching" per 30-UI-SPEC.md |
| A new `lastKnownTrack: TrackToast?` reusing the existing `TrackToast` struct | A brand-new struct with artwork | `TrackToast` is explicitly documented as title/artist-only (no NSImage) for the song-toast use case — reusing it for `lastKnownTrack` would either need a second parallel artwork field on `NowPlayingState` (workable) or force `TrackToast` to grow an optional NSImage it was deliberately kept without. Planner should decide: simplest is a **new** small struct (e.g. `LastPlayedTrack { title, artist }`) + reuse the *existing* `NowPlayingState.artwork` field itself as the sticky artwork carrier (it already only clears on `p == .none` or a real track change — see Pitfall 1 below) rather than duplicating an artwork field. |

No `Installation` step — no packages to add.

## Package Legitimacy Audit

Not applicable. This phase adds zero third-party dependencies (Swift Package Manager or otherwise). No `slopcheck`/registry verification is required.

## Architecture Patterns

### System Architecture Diagram

```
MediaRemote adapter (perl bridge, unchanged)
        │  TrackSnapshot / nil
        ▼
NowPlayingMonitor.onSnapshot  ──────────────────────────────┐
        │                                                    │
        ▼                                                    │
NotchWindowController.handleNowPlaying(snapshot, art)        │ (NEW: capture lastKnownTrack
        │  nowPlayingPresentation(from:) — PURE seam          │  here, mirroring hasPlayedSinceLaunch's
        │  hasPlayedSinceLaunch = true (existing, on .playing)│  own "set once, before render" pattern)
        ▼                                                    │
NowPlayingState (@Published: presentation, artwork,          │
                 hasPlayedSinceLaunch, NEW: lastKnownTrack) ◄─┘
        │
        ▼
NotchWindowController.currentPresentation()
        │  calls resolve(..., hasPlayedSinceLaunch:, ...)     ◄── PURE reducer (IslandResolver.swift)
        │                                                          NEW: Home branch checks
        │                                                          hasPlayedSinceLaunch when
        │                                                          nowPlaying == .none
        ▼
IslandPresentationState.presentation (@Published verdict)
        │
        ▼
NotchPillView body switch(presentation)
    ├─ .nowPlayingExpanded(playing/paused, healthy: true) → mediaExpanded(_:art:)   [UNCHANGED — HOME-01]
    ├─ NEW case (or repurposed .expandedIdle w/ sticky data) → mediaExpanded(_:art:) fed lastKnownTrack [HOME-02]
    └─ NEW empty-state case → homeEmptyState (modeled on trayEmptyState)            [HOME-03]
```

### Recommended Project Structure
No new files. Extend these four existing files only:
```
Islet/Notch/
├── IslandResolver.swift          # resolve() Home branch + IslandPresentation enum (+1 case or repurpose)
├── IslandPresentationState.swift # no change expected (generic carrier)
├── NowPlayingState.swift         # + lastKnownTrack field
├── NotchWindowController.swift   # handleNowPlaying(): capture lastKnownTrack
└── NotchPillView.swift           # transportButton hover bg (D-05); new homeEmptyState; wire mediaExpanded to lastKnownTrack
```

### Pattern 1: Reuse `mediaExpanded` for both live and last-played (D-04)
**What:** Feed `mediaExpanded(_:art:)` a `NowPlayingPresentation` built from `lastKnownTrack` (e.g. `.paused(title:, artist:)`) when routing to the last-played state, rather than writing a new view.
**When to use:** Whenever two states must render byte-identically (per 30-UI-SPEC.md's explicit requirement) — feeding the same pure function different data is cheaper and safer than parallel views that can drift.
**Example (illustrative, matches existing file conventions):**
```swift
// IslandResolver.swift — resolve()'s Home branch, illustrative shape:
if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) }
if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
if hasPlayedSinceLaunch { return .homeLastPlayed }   // NEW — HOME-02
return .homeEmpty                                     // NEW — HOME-03 (replaces .expandedIdle)
```
```swift
// NotchPillView.swift — the .homeLastPlayed case in the body switch:
case .homeLastPlayed:
    mediaExpanded(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                          artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                  art: nowPlaying.artwork)   // artwork sticky-reused from existing NSImage field
```
*(Illustrative — not verified against a specific Context7/official source; this is a direct extrapolation from the existing `mediaExpanded`/`resolve()` code read in this session, tagged [ASSUMED] for exact case naming, see Assumptions Log.)*

### Pattern 2: Sticky artwork via existing nil-retention logic
**What:** `handleNowPlaying`'s existing artwork-retention branch (`06-10 Finding 16`) already keeps `nowPlayingState.artwork` populated across a same-track nil-artwork callback and only clears it on `p == .none || !isSameTrack(...)`. HOME-02/D-07/D-08 need artwork to persist THROUGH the transition into `.none` (last-played still shows the LAST track's art) — this is the opposite of the current clear-on-`.none` behavior.
**When to use:** The planner must explicitly decide whether to (a) stop clearing `nowPlayingState.artwork` on `.none` and instead let `lastKnownTrack` (a separate small struct with its own `artwork: NSImage?`) be the sole owner of sticky art, or (b) repurpose the existing `artwork` field itself as sticky and clear it only at app relaunch (never on `.none`). **(b) is simpler but changes the meaning of an existing, well-commented field** (its doc comment currently says "arrives with the payload, may be nil"). Recommend **(a)** — a dedicated field for `lastKnownTrack.artwork` — to avoid silently repurposing `NowPlayingState.artwork`'s documented contract. This is a genuine design decision for the planner, not settled by research; see Open Questions.

### Pattern 3: Hover-triggered background (D-05)
**What:** Wrap each transport button's icon in a `RoundedRectangle` fill toggled by `.onHover`.
**Example (matches 30-UI-SPEC.md's documented default exactly):**
```swift
private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
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
Needs a local `@State private var isHovering = false` per button instance — SwiftUI gives each call site its own `@State` storage automatically since `transportButton` is called 3 times as separate view instances in the HStack.

### Anti-Patterns to Avoid
- **Branching last-played/empty-state in the VIEW layer** (e.g. `if hasPlayedSinceLaunch { ... } else { ... }` inside `NotchPillView`) — violates the single-arbiter discipline this codebase has enforced since Phase 6; every prior phase's context/research explicitly calls this out (Phase 26/28 CONTEXT.md, this phase's own canonical_refs).
- **Writing a second view function for last-played** that duplicates `mediaExpanded`'s layout — guarantees future drift the moment one state changes without the other (exactly what D-04 forbids: "byte-identical, not merely visually matching").
- **Repurposing `NowPlayingState.artwork`'s clear-on-`.none` semantics silently** without a dedicated `lastKnownTrack` field — breaks the documented contract other readers of that field rely on (health-check/mediaUnavailable path also reads `nowPlaying.artwork` conceptually via the same model).
- **Adding a `.stopped` case to `NowPlayingPresentation`** to try to distinguish last-played from empty at the pure-seam level — the project's own established shape (D-01 note in 30-CONTEXT.md) deliberately keeps that enum 3-case and relies on the orthogonal `hasPlayedSinceLaunch` bool instead; do not touch `NowPlayingPresentation.swift`'s enum shape.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Empty-state layout | A new icon+heading+body view from scratch | Copy `trayEmptyState`'s exact `VStack(spacing: 4)` + `.padding(.top, 24)` structure (D-09, LOCKED) | Already pixel/spacing-matched precedent in the same file; 30-UI-SPEC.md gives the literal code |
| Hover detection | A custom `NSTrackingArea`/mouse-move gesture recognizer | SwiftUI `.onHover` | Already the established mechanism elsewhere in this file (collapsed-pill hover bounce) |
| "Has anything ever played" tracking | A new flag | Existing `NowPlayingState.hasPlayedSinceLaunch` (already exactly this) | D-02/D-03 in 30-CONTEXT.md explicitly say no new flag is needed for this half |

**Key insight:** Nothing in this phase requires new state-machine complexity — it is almost entirely "read an existing sticky bool one level higher in the reducer, and reuse an existing view function with substituted data." The only genuinely new persistent state is the `lastKnownTrack` capture (title/artist/artwork), which should mirror the `hasPlayedSinceLaunch` capture-and-set discipline already in `handleNowPlaying()` line-for-line.

## Common Pitfalls

### Pitfall 1: Artwork clearing on `.none` collides with sticky last-played art
**What goes wrong:** `handleNowPlaying`'s existing code clears `nowPlayingState.artwork = nil` whenever `p == .none` (06-10 Finding 16 logic, `NotchWindowController.swift:1573-1577`). If the last-played state naively reads `nowPlaying.artwork`, it will be nil the instant playback stops — showing no art at all, defeating HOME-02.
**Why it happens:** That clearing logic was written for the live-glance case, before "last-played" existed as a concept.
**How to avoid:** Capture artwork into the NEW `lastKnownTrack` field BEFORE the existing nil-clear runs (same "capture pre-mutation value" pattern already used for `previous`/`previousPosition`/`hadPlayedSinceLaunch` at the top of `handleNowPlaying`), and read from `lastKnownTrack.artwork` in the last-played branch — never from `nowPlaying.artwork` directly for that state.
**Warning signs:** On-device UAT shows a blank/placeholder square in the last-played state despite a track having played moments before.

### Pitfall 2: `showsSwitcherRow(for:)` and other exhaustive switches over `IslandPresentation` must be updated in lockstep
**What goes wrong:** `IslandPresentation` is a `switch`-matched enum in at least 3 places found in this session: `showsSwitcherRow(for:)` (IslandResolver.swift:65-70), the resolver's own `resolve()`, and `NotchPillView`'s body `switch presentation` (line 337). Removing/renaming `.expandedIdle` without updating all three (plus the SwiftUI preview at `NotchPillView.swift:1895` that hand-constructs `.expandedIdle`) will either fail to compile (good, caught immediately) or — if a case is added but a switch left non-exhaustive with a `default:` — silently render the wrong thing.
**Why it happens:** Documented in this file's own WR-01 fix comment: "a case added to one switch and forgotten in the other silently desyncs render vs. click-through geometry" (CR-01/CR-02 precedent from 28-REVIEW.md).
**How to avoid:** Grep for `expandedIdle` and `IslandPresentation` project-wide (5 files found this session: `IslandResolver.swift`, `IslandPresentationState.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `IslandResolverTests.swift`) before deleting/renaming the case; keep `showsSwitcherRow` exhaustive (no `default:`) so the compiler catches any missed case.
**Warning signs:** Compiler error "switch must be exhaustive" (safe) vs. a silently-wrong click-through zone in the collapsed pill for the new case (unsafe — must be checked manually per the CR-01 precedent in project memory).

### Pitfall 3: Existing tests assert the OLD `.expandedIdle` behavior and must be updated, not just left failing
**What goes wrong:** `IslandResolverTests.swift` has at least 2 tests (`testExpandedHealthyNoMediaIsExpandedIdle` line 194, `testHomeSelectedNoMediaReturnsExpandedIdle` line 261) that assert `resolve(...) == .expandedIdle` for the exact `nowPlaying == .none` condition this phase changes. These must be rewritten to assert the new last-played/empty-state split (parametrized on `hasPlayedSinceLaunch`), not simply deleted (test coverage would silently regress).
**Why it happens:** The resolver's behavior for this exact branch is what's changing; the old tests encode the old contract.
**How to avoid:** Plan explicit test-update tasks: split each old test into two (hasPlayedSinceLaunch true → last-played case, false → empty case).
**Warning signs:** `xcodebuild build` succeeds but `IslandResolverTests` (run via manual Cmd-U, see Validation Architecture) fails against updated resolver logic.

### Pitfall 4: `xcodebuild test` hangs — use `build` as the automated gate
**What goes wrong:** Running the full test suite via `xcodebuild test` from a background/headless agent hangs indefinitely (documented project memory: tests are hosted inside the full `Islet.app`, which boots the real `NSPanel`/MediaRemote perl bridge/IOBluetooth on launch).
**Why it happens:** The XCTest host app has real system-integration side effects at launch that don't tolerate a non-interactive session.
**How to avoid:** Use `xcodebuild build -scheme Islet` as the automated per-task/per-wave gate; route the actual `IslandResolverTests`/any new unit tests to a manual Cmd-U run in Xcode (per project memory `xcodebuild-test-headless-hang`).
**Warning signs:** An agent-run `xcodebuild test` command that never returns / times out.

### Pitfall 5: Resuming via last-played (D-06) sends a GENERIC transport command, not an app-targeted one
**What goes wrong:** `togglePlayPause()`/`nextTrack()`/`previousTrack()` (via `MediaController`/the mediaremote-adapter bridge) are system-level MediaRemote commands with no app/bundle-ID targeting parameter in this codebase's current wrapper usage. If the "last-played" app is no longer the system's current Now-Playing target (e.g. user switched to a different app, or the session fully ended), tapping Play in the last-played state sends a command to whatever the OS currently considers "now playing" — which per D-06 is accepted ("nothing visibly happens" if unreachable) but is worth flagging so the plan doesn't accidentally build app-targeted resume logic that doesn't exist in the adapter.
**Why it happens:** The Swift wrapper (`ejbills/mediaremote-adapter`) doesn't expose a "resume specific app" command in what's wired here — only global transport controls.
**How to avoid:** Do not attempt to store/pass a bundle identifier through to a resume call unless the planner explicitly re-scopes D-06 — per 30-CONTEXT.md D-06 this is explicitly accepted as-is (no error UI required).
**Warning signs:** A plan task that tries to add an app-targeted "resume" API call not currently exposed by `NowPlayingMonitor`/`MediaController`.

## Code Examples

### Existing `trayEmptyState` — direct template for `homeEmptyState` (D-09)
```swift
// Source: Islet/Notch/NotchPillView.swift:745-760 (read directly, this session)
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
The 30-UI-SPEC.md Layout Contract already provides the exact `homeEmptyState` swap-in (icon `music.note`, heading "Nothing Playing", body "Start something in Spotify or Music.") — see 30-UI-SPEC.md lines 122-139, verbatim, checker-verified.

### Existing `hasPlayedSinceLaunch` capture-before-mutate pattern — template for `lastKnownTrack` capture
```swift
// Source: Islet/Notch/NotchWindowController.swift:1543-1555 (read directly, this session)
let hadPlayedSinceLaunch = nowPlayingState.hasPlayedSinceLaunch
if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }
```
`lastKnownTrack` should be updated with the SAME discipline: inside the `withAnimation` spring block, whenever `p` is `.playing` (per D-08: "overwritten every time a new track starts playing"), BEFORE any nil-artwork clearing runs.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Home falls back to `expandedIdle` (weather/date/calendar glance) when nothing plays | Home shows ONLY music content in 3 states (live / last-played / empty) | This phase (2026-07-14, HOME-03) | `expandedIsland`'s weather/date/calendar HStack (`NotchPillView.swift:436-459`) becomes fully dead code for the Home path — Weather/Calendar already have their own dedicated `IslandPresentation` cases (`.weatherExpanded`/`.calendarExpanded`, Phase 28), so nothing else depends on `expandedIsland`/`.expandedIdle` remaining |
| HOME-02 originally specified controls HIDDEN in last-played | Controls stay visible identically to live state (D-04, REVISED 2026-07-14) | Mid-session revision during Phase 30 discussion | REQUIREMENTS.md and ROADMAP.md were both already edited in the discussion session — planner should treat the CURRENT wording as authoritative, not the enum/case names implied by an earlier draft |

**Deprecated/outdated:** The `expandedIsland` view function itself is not necessarily deleted — canonical_refs flags "confirm it isn't used elsewhere before deleting." Per the grep in this session, `.expandedIdle` (the presentation case) has no other consumer, but the executor should still leave `expandedIsland` (the view function) in place if there's any chance a future phase resurrects an idle glance elsewhere, or delete it cleanly if truly dead — this is a planner-level call, not resolved by research (Weather/Calendar do NOT use `expandedIsland`, they have `weatherFullView`/`calendarFullView`, confirmed by grep in this session).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Exact new `IslandPresentation` case names (`.homeLastPlayed`, `.homeEmpty`) and whether `.expandedIdle` is renamed vs. two new cases added alongside it | Architecture Patterns / Pattern 1 | Low — this is explicitly left to planner/executor discretion per 30-CONTEXT.md ("Exact naming/shape of the new IslandResolver branch(es)... implementation detail for planner/executor"); illustrative code in this doc is a suggestion, not a locked design |
| A2 | Whether `lastKnownTrack` should be a new dedicated struct (with its own `artwork: NSImage?`) vs. reusing/repurposing `NowPlayingState.artwork`'s clear-on-`.none` semantics | Architecture Patterns / Pattern 2, Pitfall 1 | Medium — picking the reuse path without updating the artwork-nil-clear logic in `handleNowPlaying` will silently break HOME-02's cover-art requirement; flagged explicitly as an open design decision, not resolved here |
| A3 | Whether the SwiftUI preview at `NotchPillView.swift:1895` (`IslandPresentationState(.expandedIdle)`) needs updating as part of this phase's diff | Common Pitfalls / Pitfall 2 | Low — a stale preview doesn't break the shipped app, only Xcode canvas previews; worth a mention in the plan but not a hard blocker |

All other claims in this research are `[VERIFIED: in-repo Read]` — every code snippet, line number, and existing-behavior claim above was read directly from the working tree in this session (not from training-data assumption), which is the strongest confidence tier available for a codebase-internal refactor phase with no external library involvement.

## Open Questions

1. **Should `lastKnownTrack` be a new dedicated struct, or repurpose `NowPlayingState.artwork`'s lifetime?**
   - What we know: `TrackToast` (title/artist only, no artwork) already exists for a similar sticky-snapshot purpose (song-change toast) but explicitly lacks an image field; `NowPlayingState.artwork` currently clears on `.none`.
   - What's unclear: Whether the planner wants a clean new `LastPlayedTrack { title, artist, artwork }` struct, or to change `handleNowPlaying`'s existing nil-clear condition so `artwork` itself becomes the sticky carrier (simpler diff, but changes an existing field's documented contract).
   - Recommendation: New dedicated struct — smaller blast radius, doesn't alter behavior of any code that already reads `nowPlayingState.artwork` expecting "current track's art, nil if nothing playing."

2. **Is `expandedIsland` (the view function) deleted in this phase, or left as dead code?**
   - What we know: Grep confirms no other `IslandPresentation` case renders it; Weather/Calendar have their own dedicated views.
   - What's unclear: Whether "no other feature will ever want an idle glance again" is true long-term (this project's history shows glances get resurrected/reshaped often — e.g. Phase 28's own "Smart Home" addendum).
   - Recommendation: Delete it as part of this phase's cleanup (dead code violates the project's own "no speculative code" convention seen throughout CLAUDE.md/prior phases) — but flag this explicitly as a task so the plan-checker can verify no residual reference survives.

## Environment Availability

Skipped — this phase has no external dependencies beyond the existing Xcode/Swift toolchain already verified working in prior phases (29 most recently, per project memory `build-machine-macos26-toolchain`). No new frameworks, no new SPM packages, no new system permissions.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `project.yml` (XcodeGen) — `IsletTests` target, scheme `Islet` shared scheme runs `[test]` |
| Quick run command | `xcodebuild build -scheme Islet` (build-only gate — see Pitfall 4, `xcodebuild test` hangs headless) |
| Full suite command | Manual Cmd-U in Xcode (per project memory `xcodebuild-test-headless-hang`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HOME-01 | Live playing state shows transport controls (unchanged) | unit (resolver) | build-gate only; existing `testExpandedHealthyPlayingShowsMediaControls`/`testHomeSelectedWithMediaPlayingShowsNowPlayingExpanded` already cover this — no new test needed | ✅ `IsletTests/IslandResolverTests.swift` |
| HOME-02 | `.none` + `hasPlayedSinceLaunch == true` → last-played case with controls | unit (resolver) | new resolver test(s) asserting the new case, run via Cmd-U | ❌ Wave 0 — new test cases needed, replacing/extending `testExpandedHealthyNoMediaIsExpandedIdle` / `testHomeSelectedNoMediaReturnsExpandedIdle` |
| HOME-03 | `.none` + `hasPlayedSinceLaunch == false` → empty-state case | unit (resolver) | new resolver test(s) | ❌ Wave 0 — same tests as above, split on the boolean |
| HOME-02 (artwork stickiness) | `lastKnownTrack`'s artwork survives the transition to `.none` | unit or manual on-device | if `lastKnownTrack` capture logic is pure-testable (plain struct mutation), a small XCTest; otherwise manual on-device (art is an NSImage from a real MediaRemote callback) | ❌ Wave 0, likely manual-only given NSImage/AppKit involvement |
| Transport hover bg (D-05) | Visual only | manual-only | on-device hover check | n/a — visual polish, no automated test expected (matches project convention: Phase 7/18/20/21/23/25/26/28/29 all tuned hover/visual values on-device, never unit-tested) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet`
- **Per wave merge:** Manual Cmd-U full `IsletTests` run (per project's documented headless-hang constraint)
- **Phase gate:** Full suite green (Cmd-U) + on-device UAT of all 3 Home states before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IslandResolverTests.swift` — split `testExpandedHealthyNoMediaIsExpandedIdle` and `testHomeSelectedNoMediaReturnsExpandedIdle` into `hasPlayedSinceLaunch`-parametrized pairs asserting the new last-played/empty-state cases
- [ ] No new test framework/config needed — `IsletTests` target and shared scheme already fully wired

## Security Domain

Not applicable — `security_enforcement` is not referenced in `.planning/config.json` for this project and this phase touches no authentication, network, cryptography, or user-input-validation surface (it is a pure internal presentation-state refactor operating on already-classified, already-allowlisted MediaRemote data). No ASVS categories apply.

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Native Swift + SwiftUI/AppKit only — already followed, no violation risk in this phase (no new dependency).
- **"Isolate all now-playing code behind one Swift protocol/service"** (explicit CLAUDE.md mandate) — already honored; this phase does not touch `NowPlayingMonitor`'s `NowPlayingService` protocol boundary at all, only the state/resolver/view layers above it. Do not add MediaRemote-specific logic outside `NowPlayingMonitor.swift`.
- **Builder skill level (first-time programmer):** Keep the new `IslandResolver` branch and `lastKnownTrack` capture as close in shape/comment style to the existing `hasPlayedSinceLaunch` pattern as possible — this phase is a good candidate for inline explanatory comments mirroring the file's existing dense-comment convention, per CLAUDE.md's "explanations accompany the important code."
- **Code quality:** "Only change what really needs to change — no cleanup on the side" — the `expandedIsland` view function's fate (Open Question 2) should be decided deliberately, not left ambiguous, but its deletion (if chosen) is in-scope cleanup directly caused by this phase's own change, not unrelated tidying.
- **Security:** No command injection/XSS/SQL injection surface in this phase — not applicable.

## Sources

### Primary (HIGH confidence — direct in-repo reads, this session)
- `Islet/Notch/IslandResolver.swift` (full file) — resolver logic, `IslandPresentation` enum, `showsSwitcherRow`
- `Islet/Notch/IslandPresentationState.swift` (full file)
- `Islet/Notch/NowPlayingState.swift` (full file)
- `Islet/Notch/NowPlayingMonitor.swift` (full file)
- `Islet/Notch/NowPlayingPresentation.swift` (full file) — pure seam, `TrackSnapshot`/`TrackToast`/`isSameTrack`
- `Islet/Notch/NotchPillView.swift` (lines 330-460, 585-760, 1435-1620, plus preview section 1892-2012) — body switch, `expandedIsland`, `trayEmptyState`, `calendarEmptyState`, `artThumbnail`, `mediaExpanded`, `transportButton`, `mediaUnavailable`
- `Islet/Notch/NotchWindowController.swift` (lines 620-660, 1520-1619) — `currentPresentation()`, `handleNowPlaying()`
- `IsletTests/IslandResolverTests.swift` (test name list) — existing coverage of `.expandedIdle` behavior
- `.planning/phases/30-home-music-only/30-CONTEXT.md`, `30-UI-SPEC.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — phase scope, locked decisions, UI contract
- `project.yml` — test target/scheme wiring confirmation

### Secondary (MEDIUM confidence)
- None used this session — the entire phase surface was directly readable in-repo, so no WebSearch/Context7 lookups were needed (this is a pure internal-refactor phase with zero new external libraries).

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, entire stack already fixed by prior phases (SwiftUI/AppKit, no libraries to select)
- Architecture: HIGH — read every touched file directly this session; all claims verified against actual code, not training-data assumption
- Pitfalls: HIGH — all 5 pitfalls are grounded in specific line numbers read this session plus one documented project-memory constraint (xcodebuild test hang)

**Research date:** 2026-07-14
**Valid until:** Effectively indefinite for this specific phase (internal-only refactor, no external API surface to go stale) — but re-verify file line numbers if other phases land in `IslandResolver.swift`/`NotchPillView.swift`/`NotchWindowController.swift` before Phase 30 executes, since concurrent phases could shift line numbers.
