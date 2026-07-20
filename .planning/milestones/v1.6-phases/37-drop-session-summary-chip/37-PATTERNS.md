# Phase 37: Drop-Session Summary Chip - Pattern Map

**Mapped:** 2026-07-16
**Files analyzed:** 5 (2 new/extended state files, 3 modified controller/resolver/view files — no wholly new files; this phase is additive fields + functions on existing files, per CONTEXT.md's "Claude's Discretion" section)
**Analogs found:** 5 / 5 (all exact — this phase is an explicit verbatim reuse of Phase 18's toast stack, not a novel pattern)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Shelf/ShelfViewState.swift` (or `ShelfCoordinator.swift`) — new session-boundary state + gross append counter | model/state | event-driven (mutation-counting) | `Islet/Notch/NowPlayingState.swift` (`hasPlayedSinceLaunch`, `songChangeToast` fields) | exact |
| `Islet/Notch/IslandResolver.swift` — new pure gate function for the chip's suppression rule (D-06) | service (pure seam) | transform/request-response | `Islet/Notch/IslandResolver.swift:173-175` `songChangeToastGate(...)` | exact |
| `Islet/Notch/NowPlayingPresentation.swift`-style new file/section — pure content-derivation (`"N files saved"` text, pluralization) | service (pure seam) | transform | `Islet/Notch/NowPlayingPresentation.swift:95-103` `songChangeToastContent(...)` + `TrackToast` struct (lines 82-85) | exact |
| `Islet/Notch/NotchPillView.swift` — new chip rendering under collapsed wings | component (SwiftUI view) | request-response (render from `@Published` state) | `Islet/Notch/NotchPillView.swift:2020-2084` `mediaWingsOrToast(_:)` / `toastTextRow(_:)` | exact (verbatim reuse per D-04) |
| `Islet/Notch/NotchWindowController.swift` — session-count hook (append sites), collapse-trigger (D-01/D-02), dismiss timer, interrupt-clears-chip (D-07) | controller | event-driven | `Islet/Notch/NotchWindowController.swift` toast lifecycle: lines 211-221 (work item + duration constant), 701-716 (`presentTransientChange` interrupt-clear), 1309-1339 (`handleClick` expand-clears-toast), 1795-1815 (gate check + set), 1869-1878 (`scheduleToastDismiss`); collapse trigger at 1260-1304 (`handleHoverExit`'s `graceWorkItem`) | exact |

## Pattern Assignments

### Session-boundary + gross-count state (model)

**Analog:** `Islet/Notch/NowPlayingState.swift:11-45` (plain `ObservableObject`, no methods/timers, one-shot fields) and `Islet/Shelf/ShelfViewState.swift:7-22` (the existing shelf state class this phase extends)

**Existing shelf state shape** (`Islet/Shelf/ShelfViewState.swift:1-22`):
```swift
final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []

    // The ONE source of truth every shelf-visibility check must read — never patch one
    // call site with an inline check while leaving siblings on a different one.
    var isVisible: Bool { !items.isEmpty }
}
```

**NowPlayingState's one-shot / session-tracking field precedent to mirror** (`Islet/Notch/NowPlayingState.swift:21-33`):
```swift
// has X happened at least once since Y? ORTHOGONAL flag, default false, set once, no re-arm.
@Published var hasPlayedSinceLaunch: Bool = false
// The toast's OWN snapshot, stored SEPARATELY — never aliased to the live/current value.
// Set by the controller when a genuine event passes the suppression gate; cleared by the
// toast's own dismiss timer, by an interrupting transient/manual-expand, or by a toggle off.
@Published var songChangeToast: TrackToast? = nil
```

**Where the mutation points live (D-03's gross-count hook — `ShelfCoordinator`, not `ShelfViewState`):**
`Islet/Shelf/ShelfCoordinator.swift:28-35` (`append`), `:40-45` (`remove`), `:50-57` (`clear`) are the exact three tested mutation points. `append` returns `Bool` (`@discardableResult`) — the session counter increments only when `added == true` (mirrors how the coordinator itself already guards against counting a rejected/duplicate append, see WR-01 comment at lines 22-27).

**Apply:** add a new `@Published var sessionFilesSaved: Int` (or similar) field either directly on `ShelfCoordinator` (mirroring `TransientQueue`'s `private(set)` counters) or on `ShelfViewState` (mirroring `NowPlayingState`'s `@Published` shape) — CONTEXT.md leaves this shape choice to the planner. Whichever host is chosen, follow `NowPlayingState`'s discipline: plain field, no internal timer/method, incremented/reset only by the controller (`NotchWindowController`), never self-mutating.

---

### Suppression gate (pure seam)

**Analog:** `Islet/Notch/IslandResolver.swift:173-175`

```swift
func songChangeToastGate(activeTransient: ActiveTransient?, isExpanded: Bool, toastEnabled: Bool) -> Bool {
    activeTransient == nil && !isExpanded && toastEnabled
}
```

**Apply verbatim per D-06** — same three-input shape (`activeTransient`, `isExpanded`, an `enabled`-style toggle if the chip gets one, else drop that param). Add as a new sibling `TOTAL` pure function in `IslandResolver.swift`, same file/section (right after `songChangeToastGate`, before the `PendingBatteryPoll` block at line 177), same doc-comment discipline (cites the phase/requirement, explains why it's a standalone function and not threaded through `resolve(...)`).

---

### Content-derivation (pure seam: pluralized text + one-shot struct)

**Analog:** `Islet/Notch/NowPlayingPresentation.swift:82-103`

```swift
// Phase 18 / NOW-05 — the song-change toast's own title/artist snapshot. A plain value
// (no NSImage), so tests construct it by hand; mirrors TrackSnapshot's role.
struct TrackToast: Equatable {
    let title: String
    let artist: String
}

// TOTAL pure detection: does this transition deserve a song-change toast? ...
func songChangeToastContent(previous: NowPlayingPresentation, current: NowPlayingPresentation,
                             hasPlayedSinceLaunch: Bool) -> TrackToast? {
    guard hasPlayedSinceLaunch else { return nil }
    guard !isSameTrack(previous, current) else { return nil }
    switch current {
    case .playing(let t, let a), .paused(let t, let a): return TrackToast(title: t, artist: a)
    case .none: return nil
    }
}
```

**Apply per D-05:** new struct (e.g. `struct SessionSummaryChip: Equatable { let count: Int }`, mirroring `TrackToast`'s plain-value shape) + a `TOTAL` pure function that takes the gross count and the D-01/D-02 trigger condition and returns `SessionSummaryChip?` (nil when count == 0 — no chip on a Tray session with zero drops). Pluralization ("1 file saved" vs "N files saved") is either baked into this pure function's returned string, or (better, matching the project's "plain value in, view formats" split seen in `toastTextRow`) kept as a raw `Int` on the struct and formatted at render time in the view — either is consistent with existing conventions; planner's call per CONTEXT.md discretion. Place in the shelf pure-seam layer (mirrors `ShelfViewState.swift`'s existing `shouldOpenShelfItem`/`shouldBeginShelfItemDrag` TOTAL pure gates at lines 27, 32) since this is shelf-domain logic, not now-playing domain — do not add it to `NowPlayingPresentation.swift`.

---

### Chip rendering (component — verbatim reuse per D-04)

**Analog:** `Islet/Notch/NotchPillView.swift:2020-2084`

**Imports/context** — no new imports needed; `NotchPillView.swift` already imports SwiftUI and references `nowPlaying`/state objects as `@ObservedObject`/`@EnvironmentObject`-style properties on the view.

**Shape + growth mechanics** (lines 2021-2049):
```swift
@ViewBuilder
private func mediaWingsOrToast(_ p: NowPlayingPresentation) -> some View {
    let toast = nowPlaying.songChangeToast
    let height = Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)
    let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
    shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: height)
        .overlay(liquidGlassEffectLayer(shape: shape, size: CGSize(width: Self.wingsSize.width, height: height), parameters: .expanded))
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                mediaWingsRow(p, art: nowPlaying.artwork)
                if let toast {
                    toastTextRow(toast)
                        .transition(.opacity)
                }
            }
        }
        .onTapGesture { onClick() }
}
```

**Text row** (lines 2074-2084):
```swift
private func toastTextRow(_ toast: TrackToast) -> some View {
    Text("\(toast.title) — \(toast.artist)")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 16)
        .frame(width: Self.wingsSize.width, height: Self.toastExtraHeight, alignment: .center)
}
```

**Constants used** (`Islet/Notch/NotchPillView.swift:240`, `:508`):
```swift
static let wingsSize = CGSize(width: 290, height: 32)
static let toastExtraHeight: CGFloat = 32
```

**Apply per D-04 (verbatim reuse, no new visual language):** whichever collapsed-idle-pill rendering function is showing when the Tray session ends (D-01: island collapses to the idle pill, NOT the media wings — check what the idle/collapsed pill's own render function is called, likely near `mediaWingsOrToast`'s siblings for `chargingWings`/`deviceWings`/an idle-pill case) needs the SAME `toast != nil ? extraHeight : 0` growth + `VStack` overlay + `.transition(.opacity)` pattern, reading a new `@Published` chip field instead of `nowPlaying.songChangeToast`. Reuse `toastExtraHeight` and `wingsSize` as-is (same constants, do not redeclare). New chip text function mirrors `toastTextRow` 1:1 with pluralized "N files saved" content instead of "title — artist".

---

### Controller lifecycle (event-driven: trigger, timer, interrupt-clear)

**Analog:** `Islet/Notch/NotchWindowController.swift` toast stack (multiple sites)

**Work-item + duration constants** (lines 211-221):
```swift
private var toastDismissWorkItem: DispatchWorkItem?
...
private let songToastDuration: TimeInterval = 2.0
```

**Interrupt-clears-toast on a NEW transient** (lines 701-716, `presentTransientChange`):
```swift
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        if nowPlayingState.songChangeToast != nil {
            toastDismissWorkItem?.cancel()
            nowPlayingState.songChangeToast = nil
        }
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```

**Interrupt-clears-toast on manual re-expand** (lines 1315-1325, `handleClick` — this is D-07's exact precedent cited in CONTEXT.md):
```swift
let wasExpanded = interaction.isExpanded
withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
    interaction.phase = nextState(interaction.phase, .clicked)
    if !wasExpanded && interaction.isExpanded && nowPlayingState.songChangeToast != nil {
        toastDismissWorkItem?.cancel()
        nowPlayingState.songChangeToast = nil
    }
    renderPresentation()
}
```

**Gate check + set at the trigger site** (lines 1804-1815, adapted pattern — for the chip this fires at collapse, not at a track-change callback):
```swift
if songChangeToastGate(activeTransient: transientQueue.head, isExpanded: interaction.isExpanded,
                        toastEnabled: activityEnabled(ActivitySettings.songChangeToastKey)),
   let toast = songChangeToastContent(previous: previous, current: p, hasPlayedSinceLaunch: hadPlayedSinceLaunch) {
    nowPlayingState.songChangeToast = toast
    scheduleToastDismiss()
}
```

**One-shot dismiss timer** (lines 1869-1878):
```swift
private func scheduleToastDismiss() {
    toastDismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.nowPlayingState.songChangeToast = nil
        }
    }
    toastDismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + songToastDuration, execute: work)
}
```

**D-01's actual collapse trigger site** (lines 1260-1304, `handleHoverExit`'s `graceWorkItem` — the grace-collapse path; click-away collapse is the `!wasExpanded` inverse branch inside `handleClick`, same function shown above):
```swift
let work = DispatchWorkItem { [weak self] in
    guard let self else { return }
    guard !self.isDraggingShelfItem else { return }
    guard !self.isOnboardingActive else { return }
    withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
        self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
        self.renderPresentation()
        if !self.interaction.isExpanded { self.discardPendingDrop() }
    }
    self.updateVisibility()
    self.syncClickThrough()
}
graceWorkItem = work
DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
```

**Append mutation points to hook the D-03 gross counter into** (lines 1034-1038, 2002-2006 — both existing `shelfCoordinator.append(item)` call sites; a new drop-in path may add a third):
```swift
private func handleQuickActionDrop() {
    for item in pendingDrop?.items ?? [] {
        shelfCoordinator.append(item)
    }
    resyncShelfViewState()
    ...
}
```

**Apply:**
1. At every `shelfCoordinator.append(item)` call site, after a successful append, increment the new session counter (D-03: gross, not net — increment regardless of later `remove`/`clear`).
2. At the exact moment `interaction.phase` transitions to collapsed (both `handleHoverExit`'s `graceWorkItem` body AND `handleClick`'s toggle-shut branch) WHILE `viewSwitcherState.selectedView == .tray` was the pre-collapse selection (D-01) AND the session counter > 0: set the new chip field, mirroring the gate-check-then-set pattern at lines 1810-1814, then call a new `scheduleChipDismiss()` mirroring `scheduleToastDismiss()` 1:1 with its own duration constant (mirror `songToastDuration` naming/value, ~2s per D-04).
3. Reset the session counter to 0 at the SAME collapse instant (D-02: session boundary resets immediately at collapse, not on next drop).
4. Add the interrupt-clear at both existing sites shown above (`presentTransientChange` for a new transient winning, `handleClick`'s re-expand branch for D-07) — same `workItem?.cancel()` + field-to-nil pattern, new chip field instead of `songChangeToast`.

---

## Shared Patterns

### One-shot `@Published` transient field + dedicated `DispatchWorkItem` dismiss timer
**Source:** `Islet/Notch/NowPlayingState.swift:33` (field) + `Islet/Notch/NotchWindowController.swift:214,221,1869-1878` (timer)
**Apply to:** the new chip's state field and its dismiss scheduling — this is the project's single established shape for "brief transient text overlay" (also used by `chargingState.activity`/`deviceState.activity` dismiss timers). Do not invent a new timer mechanism (no `Timer.scheduledTimer`, no recurring polling) — one `DispatchWorkItem`, cancel-then-reschedule, `asyncAfter`.

### Pure suppression gate as a standalone function, not threaded through `resolve(...)`
**Source:** `Islet/Notch/IslandResolver.swift:160-175` (`songChangeToastGate` + its doc-comment rationale)
**Apply to:** the chip's own gate function — same deliberate architectural split (toast/chip suppression lives OUTSIDE the `IslandPresentation` resolver, as its own `TOTAL` pure function the controller calls directly before mutating the `@Published` field).

### Interrupt-clears-transient-overlay on expand or a higher-priority transient
**Source:** `Islet/Notch/NotchWindowController.swift:701-716` and `:1315-1325`
**Apply to:** wire the SAME two interrupt sites for the new chip field (D-07 names this exact precedent). Both are `withAnimation` blocks already present in the controller — add the chip's cancel+nil alongside the existing toast cancel+nil, do not create parallel new interrupt call sites.

### Coordinator mutation points are the sole hook for domain counters
**Source:** `Islet/Shelf/ShelfCoordinator.swift:28-57` (`append`/`remove`/`clear`)
**Apply to:** the D-03 gross-count logic reads/increments at these three tested methods (or at their call sites in the controller, per the discretion note) — never duplicate shelf-mutation logic elsewhere.

## No Analog Found

None — every file this phase touches has an exact, explicitly-cited Phase 18 or existing-shelf analog (CONTEXT.md's canonical_refs section already did this mapping; this file makes it concrete with line numbers and code).

## Metadata

**Analog search scope:** `Islet/Notch/` (IslandResolver.swift, NotchPillView.swift, NotchWindowController.swift, NowPlayingState.swift, NowPlayingPresentation.swift, ViewSwitcherState.swift), `Islet/Shelf/` (ShelfViewState.swift, ShelfCoordinator.swift)
**Files scanned:** 8 (all files named in 37-CONTEXT.md's `canonical_refs`, plus `ViewSwitcherState.swift` for `SelectedView`/`.tray` confirmation)
**Pattern extraction date:** 2026-07-16
