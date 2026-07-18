# Phase 42: Dual-Activity Display - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 5 (all existing files, additively modified — no new files this phase)
**Analogs found:** 5 / 5 (every file is its own best analog; concrete precedent patterns extracted from within each)

## File Classification

| Modified File | Role | Data Flow | Closest Analog (pattern source) | Match Quality |
|----------------|------|-----------|----------------------------------|---------------|
| `Islet/Notch/IslandResolver.swift` | service (pure resolver) | transform | itself — Phase 41's `calendarCountdown` ambient-branch check (line 170) | exact |
| `Islet/Notch/IslandPresentationState.swift` | model / store (`@Published` carrier) | event-driven | itself — `hoveredQuickActionButtonIndex` additive field (Phase 34, lines 18-24) | exact |
| `Islet/Notch/NotchPillView.swift` | component (SwiftUI view) | request-response (render) | `countdownWings(for:)` (lines 2240-2266) + `wingsShape(...)` (lines 1947-1993) + `artThumbnail(_:side:corner:)` (lines 2518-2536) | exact |
| `Islet/Notch/NotchWindowController.swift` | controller | event-driven | `currentPresentation()`/`renderPresentation()` (lines 784-831) + `scheduleActivityDismiss()` stagger (lines 1798-1833) + `hotZone`/`visibleContentZone()` geometry (lines 994-999, 1250-1307) | exact |
| `IsletTests/IslandResolverTests.swift` | test | N/A | `testCalendarCountdownOutranksAmbientMedia` / `testCalendarCountdownFallsThroughWhenExpanded` (lines 721-760) | exact |

No new files are created this phase — CONTEXT.md/RESEARCH.md both confirm this is a pure additive extension of 5 existing files. There is nothing in "No Analog Found."

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` (service, transform)

**Analog:** itself — the existing ambient branch this phase extends (lines 166-176), and the file's own established "TOTAL pure reducer" + "small explicit pure helper function" conventions (`nowPlayingHealthGate`, `nowPlayingLaunchGate`, `songChangeToastGate`).

**Imports pattern** (line 1):
```swift
import Foundation
```
Foundation-only — no AppKit/SwiftUI. Every value type and function in this file follows this constraint (D-03's ranking table must stay Foundation-only too).

**The enum-to-extend pattern** (`IslandPresentation`, lines 61-77) — per ROADMAP/CONTEXT.md constraint, do NOT add a case here. `SecondaryActivity` must be a **new, separate** `Equatable` enum living alongside `IslandPresentation`, not a case inside it:
```swift
enum IslandPresentation: Equatable {
    case onboarding(OnboardingStep)
    case idle
    case charging(ChargingActivity)
    // ...
    case calendarCountdown(CalendarCountdownActivity)      // Phase 41 / HUD-08
    // ...
}
```

**Core pattern — the exact edit point** (ambient branch, lines 166-176):
```swift
// Phase 41 / HUD-08 (D-01): a present countdown always wins over ambient now-playing wings
// — checked FIRST in this branch, before nowPlayingLaunchGate, the ONLY place this
// priority rule may be expressed (Pitfall 3: never a suppression flag in a monitor or the
// view layer).
if let countdown = calendarCountdown { return .calendarCountdown(countdown) }
// Phase 17 / NOW-04 — D-01/D-03: the launch gate applies ONLY to this ambient branch; the
// isExpanded branch above is untouched, so a manual expand always reveals the real state.
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
return .idle
```
This is the literal line range (170-174) D-01/D-02/D-03's 2-entry ordered table replaces — the countdown-wins-outright branch becomes countdown-wins-primary-with-nowPlaying-demoted-to-secondary. RESEARCH.md Pattern 1 (AmbientVerdict tuple/struct) and Code Examples' `resolveAmbientPair` illustrate the target shape; this file's own convention (see below) is the concrete style to match.

**Established "small pure helper, doc-commented, TOTAL function" convention** (e.g. `nowPlayingLaunchGate`, lines 186-194):
```swift
// Phase 17 / NOW-04 — D-01/D-02: a track that hasn't actually played (isPlaying == true) since
// Islet launched must not auto-show the ambient wings glance. TOTAL pure helper mirroring
// nowPlayingHealthGate's shape: ...
func nowPlayingLaunchGate(hasPlayedSinceLaunch: Bool, nowPlaying: NowPlayingPresentation) -> NowPlayingPresentation {
    hasPlayedSinceLaunch ? nowPlaying : .none
}
```
The new ranking table function should match this shape: a doc comment citing the phase/decision IDs, a total (no optional-crash) signature, one clear expression or small switch.

**Error handling pattern:** N/A — this file has no throwing/error paths; every function is TOTAL (always returns a value for every input). D-04's "single activity → secondary nil" must be expressed as a plain fallthrough branch, not an error case.

---

### `Islet/Notch/IslandPresentationState.swift` (model/store, event-driven)

**Analog:** itself — the file already demonstrates adding one `@Published` field alongside `presentation` (Phase 34's `hoveredQuickActionButtonIndex`).

**Full file is the pattern** (29 lines total — read in full, no partial reads needed):
```swift
final class IslandPresentationState: ObservableObject {
    @Published var presentation: IslandPresentation

    // Phase 34 (UAT revision, D-11) — the live drag-hover carrier for the Quick Action picker's
    // 3 destination buttons. Controller-owned: ... assigns it here, only on change ...
    // The view is a pure consumer, never a computer, of this value — mirrors `presentation` itself
    // in that respect.
    @Published var hoveredQuickActionButtonIndex: Int? = nil

    init(_ presentation: IslandPresentation = .idle) {
        self.presentation = presentation
    }
}
```
The new `@Published var secondary: SecondaryActivity? = nil` field follows this EXACT precedent: same doc-comment style (phase/decision id, "controller-owned", "view is a pure consumer"), same optional-with-nil-default shape, added as a sibling stored property — no methods, no computed logic in this class.

**Critical constraint from RESEARCH.md Pitfall 1:** `secondary` must always be set from the SAME `resolve(...)` call that sets `presentation` (see `NotchWindowController.renderPresentation()` below) — never mutated independently, or a stale secondary can survive into a transient splash.

---

### `Islet/Notch/NotchPillView.swift` (component, render)

**Analog:** `countdownWings(for:)` (lines 2240-2266) is the closest full-shape analog (most recently added ambient wing, tap-enabled, `TimelineView`-gated); `wingsShape(...)` (lines 1947-1993) is the underlying shared shape-building helper; `artThumbnail(_:side:corner:)` (lines 2518-2536) is the circular-crop-adjacent precedent for D-06.

**Namespace pattern** (line 198):
```swift
// The single shared morph identity (D-07): the collapsed and expanded blobs both
// morph against this one geometry group via matchedGeometryEffect(id: "island").
@Namespace private var ns
```
Per RESEARCH.md Pattern 2 (and D-09's own wording), reuse this SAME `ns` with a NEW distinct `id:` (e.g. `"secondaryBubble"`) — do not add a second `@Namespace`.

**Critical `matchedGeometryEffect`-before-`.frame` ordering** (documented 3x already in this file, e.g. `collapsedIsland`, lines 850-859):
```swift
return shape
    .fill(collapsedFill)
    // Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED: SwiftUI's
    // matchedGeometryEffect is itself implemented via an internal frame+offset, so it
    // must be applied BEFORE any local `.frame(...)`, not after. ...
    .matchedGeometryEffect(id: "island", in: ns)
    .frame(width: size.width, height: size.height)
```
The SAME ordering (`.matchedGeometryEffect` then `.frame`) is repeated identically in `wingsShape` (lines 1956-1959). Any new secondary-bubble shape call MUST follow this exact order or reproduce the documented diagonal-bounce bug.

**Core shape pattern — `wingsShape` (lines 1947-1993), the shared flanking-shape builder:**
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    @ViewBuilder content: () -> Content
) -> some View {
    let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)
    let size = CGSize(width: leftWidth + rightWidth, height: Self.wingsSize.height)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: size.width, height: size.height)
        .overlay(liquidGlassEffectLayer(shape: shape, size: size, parameters: .expanded))
        .overlay(
            content()
                .frame(width: size.width, height: size.height, alignment: .leading)
        )
        .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
        .onTapGesture { onClick() }
}
```
NOT directly reusable (wings render ONE shape; the bubble is a SECOND, simultaneous shape) — but its `.fill → .matchedGeometryEffect → .frame → .overlay → .onTapGesture` sequence, and its `onTapGesture { onClick() }` tap-wiring convention (D-12), is the exact skeleton to mirror for the bubble's own `Circle()`-based shape function.

**Closest full-analog — `countdownWings(for:)` (lines 2240-2266)**, the most recently added ambient wing:
```swift
private func countdownWings(for activity: CalendarCountdownActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: Self.wingsLabelWidth / 2) {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, activity.eventStart.timeIntervalSince(context.date))
            let color = urgencyColor(for: activity.eventStart, at: context.date)
            HStack(spacing: 0) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .padding(.leading, 14)
                Spacer()
                Text(formatMMSS(remaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .padding(.trailing, 20)
            }
        }
    }
}
```
Demonstrates: a `private func` taking the domain activity, building content via a shared shape helper, doc-commented with the phase/bugfix history. Tap-to-expand (D-12) is inherited "for free" from `wingsShape`'s own `.onTapGesture` — the bubble's own shape function should do the same (call its own `onTapGesture` closure, per D-12's "independent tap target").

**Circular artwork crop pattern — `artThumbnail(_:side:corner:)` (lines 2518-2536), D-06's direct precedent:**
```swift
@ViewBuilder
private func artThumbnail(_ art: NSImage?, side: CGFloat, corner: CGFloat) -> some View {
    if let art {
        Image(nsImage: art)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    } else {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: side, height: side)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: side * 0.45))
                    .foregroundStyle(.white.opacity(0.7))
            )
    }
}
```
The bubble's circular variant swaps `RoundedRectangle(cornerRadius: corner, ...)` for `Circle()` in both branches — same nil→placeholder structure, same `.aspectRatio(contentMode: .fill)` + `.frame` + `.clipShape` sequence (RESEARCH.md's Code Examples section already has the adapted version, `artThumbnailCircular`).

**Composition point — `presentationSwitch` (lines 715-757) and `body`'s outer `ZStack` (lines 759-770):**
```swift
@ViewBuilder
private var presentationSwitch: some View {
    switch presentation {
    // ... every existing case, UNCHANGED — do not add a case here ...
    case .idle:
        collapsedIsland
    }
}

var body: some View {
    ZStack(alignment: .top) {
        presentationSwitch
    }
    .frame(width: ..., height: ..., alignment: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```
The secondary bubble is composed as a NEW sibling inside `body`'s `ZStack`, conditioned on `presentationState.secondary != nil` — `presentationSwitch` itself stays byte-for-byte unchanged (ROADMAP success criterion 4).

**Error handling pattern:** N/A for this file — SwiftUI views have no throw paths; nil-handling is via `if let`/`@ViewBuilder` branches (see `artThumbnail` above).

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** `currentPresentation()`/`renderPresentation()` (lines 784-808) for the resolve-and-publish wiring; `scheduleActivityDismiss()` (lines 1798-1833) for the `DispatchWorkItem`-based stagger/delay convention (D-11); `hotZone`/`visibleContentZone()` (lines 994-999, 1250-1307) for the click-through geometry the bubble's tap target (D-12) depends on.

**Imports / constants pattern** (lines 386-387):
```swift
private let springResponse: Double = 0.6
private let springDamping: Double = 0.62
```
Every animated state mutation in this file wraps in `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` — reuse these same constants for the bubble's own morph-in, and for the staggered secondary reveal (D-11).

**Core resolve-and-publish pattern** (lines 784-831):
```swift
private func currentPresentation() -> IslandPresentation {
    let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
    let np = npEnabled ? nowPlayingState.presentation : .none
    let healthy = nowPlayingHealthGate(enabled: npEnabled, isHealthy: nowPlayingState.isHealthy)
    return resolve(activeTransient: transientQueue.head,
                   nowPlaying: np,
                   nowPlayingHealthy: healthy,
                   hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch,
                   isExpanded: interaction.isExpanded,
                   selectedView: viewSwitcherState.selectedView,
                   onboardingStep: onboardingStep,
                   pendingDrop: pendingDrop,
                   calendarCountdown: calendarCountdownActivity)
}

// Write the resolver's verdict to the @Published carrier the view observes. The CALLER owns
// the spring wrapper (so the morph is attached AT the originating mutation, D-08) — this just
// assigns. Every head/expanded/now-playing mutation ends by calling this + updateVisibility().
private func renderPresentation() {
    presentationState.presentation = currentPresentation()
}
```
Per RESEARCH.md Pitfall 1, `renderPresentation()` is THE single site to extend: whatever shape `resolve(...)` returns (tuple/struct with `secondary`), this function must set BOTH `presentationState.presentation` AND `presentationState.secondary` from the SAME call, every time — never a second independent assignment elsewhere.

**Stagger/delay convention (D-11) — `scheduleActivityDismiss()` `DispatchWorkItem` pattern (lines 1798-1833):**
```swift
private func scheduleActivityDismiss() {
    dismissWorkItem?.cancel()
    guard let head = transientQueue.head, !head.isPersistent else { return }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        _ = self.transientQueue.advance()
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.syncActivityModels()
            self.renderPresentation()
        }
        self.updateVisibility()
        if self.transientQueue.head != nil {
            self.deviceCoordinator.activityPromoted()
            self.scheduleActivityDismiss()
        }
    }
    dismissWorkItem = work
    let duration: TimeInterval = { /* per-category duration */ }()
    DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
}
```
This is the exact `cancel-existing → build DispatchWorkItem capturing [weak self] → wrap the state mutation in withAnimation(.spring(...)) → store the work item → DispatchQueue.main.asyncAfter` shape D-11's staggered secondary-bubble reveal should reuse: set `presentation` (primary) immediately in the existing `withAnimation` block, then schedule a SEPARATE `DispatchWorkItem` that sets `secondary` inside its OWN `withAnimation` block after the stagger delay — mirroring this file's own established "one wake-up then idle" convention (also seen at lines 1572, 2148-2163, 2169-2179 for the toast's own delayed-then-auto-dismiss pattern).

**Click-through geometry — `hotZone` computation (lines 994-999):**
```swift
// The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
// While expanded, the WHOLE expanded island (the panel union, padded) keeps it open so
// the pointer can reach the transport controls without tripping the grace-collapse.
expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
```
**`handlePointer(at:)` gating (lines 1209-1240):**
```swift
private func handlePointer(at point: CGPoint) {
    lastPointerLocation = point
    let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
    if interaction.isExpanded {
        syncClickThrough()
    }
}
```
**Per RESEARCH.md Pitfall 2 (the phase's single highest-risk item):** while COLLAPSED (i.e. exactly the ambient/wing tier both the primary pill and the new secondary bubble render in), the ONLY zone gating whether AppKit delivers a click at all is the small, fixed `hotZone` (sized to the ~179×32pt measured notch, not to any wing/bubble content width). `visibleContentZone()` (lines 1250-1307) already does per-presentation-aware sizing for the EXPANDED tier only — there is no equivalent for the collapsed/wing tier yet. The plan must include an explicit on-device verification + (if needed) a `hotZone`-equivalent widening for the collapsed tier so the bubble's real screen position (to the right of, and further out than, today's `hotZone`) actually registers taps.

**`visibleContentZone()` per-presentation branch pattern (lines 1250-1307), the model for any collapsed-tier equivalent:**
```swift
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let switcherRowShowing = showsSwitcherRow(for: presentationState.presentation)
    // ... per-case contentSize branches (isOnboardingActive, .trayExpanded, .weatherExpanded,
    //     .quickActionPicker, .calendarExpanded, else) ...
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: contentSize)
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```
If the collapsed-tier hot-zone needs widening for the bubble, this per-case `if/else if` branching-on-`presentationState.presentation` structure (each branch computing its own `contentSize`, with an explicit doc comment citing "must mirror NotchPillView's ... exactly, or the CR-01 click-swallowing/dead-zone regression class comes back") is the established convention to extend, not a new mechanism.

**Error handling pattern:** N/A — this file has no throw paths in the relevant code; `guard let`/optional-binding is the sole "failure" idiom (e.g. `guard let head = transientQueue.head else { return }`).

---

### `IsletTests/IslandResolverTests.swift` (test)

**Analog:** `testCalendarCountdownOutranksAmbientMedia` / `testCalendarCountdownFallsThroughWhenExpanded` (lines 721-760) — the most recent, same-domain (Countdown vs. NowPlaying) precedent this phase's tests directly extend.

**Test structure pattern** (lines 721-733):
```swift
func testCalendarCountdownOutranksAmbientMedia() {
    // D-01: resolve(...) returns .calendarCountdown ahead of .nowPlayingWings when both a
    // calendarCountdown and a .playing nowPlaying input are present, collapsed, no active
    // transient.
    let countdown = CalendarCountdownActivity(eventStart: Date().addingTimeInterval(300))
    let r = resolve(activeTransient: nil,
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: false,
                    calendarCountdown: countdown)
    XCTAssertEqual(r, .calendarCountdown(countdown))
}
```
Build inputs by hand (no mocks/fixtures — mirrors `PowerActivity`/`DeviceActivity` "tests build it by hand" convention already noted in `IslandResolver.swift`'s own header comment), call `resolve(...)` directly, assert on the return value with `XCTAssertEqual`. New DUAL-01 tests (both-live→secondary populated; single-live→secondary nil per D-04; transient→both suppressed per D-10) follow this exact shape — no new test infrastructure needed (RESEARCH.md's Wave 0 Gaps: "None").

**Existing transient-outranks-countdown precedent** (line ~750-760, adjacent test) is the direct analog for the new D-10 test ("transient suppresses BOTH primary and secondary") — same input-building style, asserting the resolver's transient branch still wins.

---

## Shared Patterns

### `.matchedGeometryEffect` before `.frame` (mandatory ordering)
**Source:** `Islet/Notch/NotchPillView.swift:850-858` (documented bugfix, "island-expand-diagonal-bounce"), repeated identically at `NotchPillView.swift:1956-1958`
**Apply to:** Any new shape-building code in `NotchPillView.swift` (the secondary bubble's `Circle()` shape call)
```swift
.matchedGeometryEffect(id: "secondaryBubble", in: ns)   // MUST precede .frame
.frame(width: Self.secondaryBubbleDiameter, height: Self.secondaryBubbleDiameter)
```

### Spring animation constants
**Source:** `Islet/Notch/NotchWindowController.swift:386-387`
**Apply to:** Every `withAnimation` wrapping a `presentation`/`secondary` mutation in `NotchWindowController.swift`
```swift
private let springResponse: Double = 0.6
private let springDamping: Double = 0.62
// usage: withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) { ... }
```

### `DispatchWorkItem` + `asyncAfter` stagger/delay convention
**Source:** `Islet/Notch/NotchWindowController.swift:1798-1833` (`scheduleActivityDismiss`), mirrored at lines 1572, 2148-2179 (song-toast delayed dismiss)
**Apply to:** D-11's staggered secondary-bubble reveal after a transient ends
```swift
let work = DispatchWorkItem { [weak self] in
    guard let self else { return }
    withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
        // set presentationState.secondary here, after the stagger delay
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay, execute: work)
```

### One pure arbiter — no view-layer or controller-layer precedence logic
**Source:** `Islet/Notch/IslandResolver.swift` header comment (lines 3-8) + PITFALLS.md Pitfall 6 (cited in CONTEXT.md/RESEARCH.md)
**Apply to:** All 4 modified files — `secondary` must be resolver-owned output (`IslandResolver.swift`), the controller (`NotchWindowController.swift`) only calls `resolve(...)` and assigns the result, and the view (`NotchPillView.swift`) only renders `presentationState.secondary` — never recomputes primary/secondary precedence itself.

### Foundation-only purity for resolver code
**Source:** `Islet/Notch/IslandResolver.swift:1, 3-8`
**Apply to:** `SecondaryActivity` enum + the new ranking-table function — no AppKit/SwiftUI/Timer imports, so it stays unit-testable in milliseconds via `IslandResolverTests.swift`.

## No Analog Found

None — this phase creates no new files; every modified file already contains a directly-applicable precedent pattern (see table above).

## Metadata

**Analog search scope:** `Islet/Notch/` (all 38 Swift files enumerated), `IsletTests/IslandResolverTests.swift`
**Files scanned/read this session:** `IslandResolver.swift` (full, 319 lines), `IslandPresentationState.swift` (full, 29 lines), `NotchPillView.swift` (targeted: 190-270, 680-870, 1930-2020, 2240-2330, 2505-2565 — namespace, presentationSwitch, body ZStack, collapsedIsland, wingsShape, countdownWings, artThumbnail), `NotchWindowController.swift` (targeted: 784-833, 960-1005, 1208-1307, 1790-1834 — currentPresentation/renderPresentation, hotZone/panelFrame, handlePointer/visibleContentZone, scheduleActivityDismiss), `IsletTests/IslandResolverTests.swift` (targeted: 1-80, 721-760 — test conventions + Phase 41 Countdown-vs-NowPlaying precedent)
**Pattern extraction date:** 2026-07-18
