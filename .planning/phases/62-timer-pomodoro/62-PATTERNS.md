# Phase 62: Timer/Pomodoro - Pattern Map

**Mapped:** 2026-07-24
**Files analyzed:** 9 (3 new source, 3 modified source, 3 test)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/TimerActivity.swift` (NEW) | model | transform (pure mapping) | `Islet/Notch/DownloadActivity.swift` | exact |
| `Islet/Notch/TimerActivityState.swift` (NEW) | store (`@Published` holder) | event-driven (state mutation from taps/timer fires) | `Islet/Notch/ChargingActivityState.swift` (shape) + `Islet/Notch/DownloadCoordinator.swift` (stateful mutation/testable-overload discipline) | role-match |
| `Islet/Notch/TimerMonitor.swift` (NEW) | service (scheduling monitor) | event-driven (one-shot deadline timer) | `Islet/Notch/CalendarCountdownMonitor.swift` | exact |
| `Islet/Notch/IslandResolver.swift` (MODIFIED) | model / pure reducer | transform (CRUD-like ranking over a fixed input set) | itself (extend existing `IslandPresentation`/`ActiveTransient`/`resolve()`/`TransientQueue`) | exact |
| `Islet/Notch/NotchPillView.swift` (MODIFIED) | component (SwiftUI view) | request-response (render presentation → view; button taps → controller callback) | itself (`countdownWings`/`capsLockWings`/`downloadWings` for wings; `navCircleButton`/`chipButton` for controls; `homeEmptyContent`/`onboardingCarousel` for new Home button + sheet) | exact |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED) | controller | event-driven (monitor callbacks → queue mutation → render) | itself (`startDownloadMonitor()`, `deviceCoordinator`/`downloadCoordinator` construction block, `scheduleActivityDismiss()`, `handleSettingsChanged()`) | exact |
| `IsletTests/TimerActivityTests.swift` (NEW) | test | transform | `IsletTests/DownloadActivityTests.swift` | exact |
| `IsletTests/TimerActivityStateTests.swift` (NEW) | test | event-driven | `IsletTests/DownloadCoordinatorTests.swift` | exact |
| `IsletTests/IslandResolverTests.swift` (MODIFIED, extend) | test | transform | itself, `MARK: Phase 61 / DL-01/DL-02` block (lines 724-770) | exact |

## Pattern Assignments

### `Islet/Notch/TimerActivity.swift` (NEW — model, transform)

**Analog:** `Islet/Notch/DownloadActivity.swift` (full file, 54 lines — read in one pass)

**File-header pattern** (lines 1-14): a pure, Foundation-only file that holds the raw-reading type a later monitor lifts values into, PLUS the presentation enum, PLUS stateless helpers — no state across calls. Copy this exact framing for `TimerActivity.swift`'s header comment.

**Sub-state-persistent presentation enum** (lines 35-40):
```swift
// The presentation payload (D-09: `.inProgress` carries no filename; D-12: `.done`
// carries the real, final filename).
enum DownloadActivity: Equatable {
    case inProgress
    case done(filename: String)
}
```
Apply this shape to `TimerActivity`: e.g. `.running(deadline: Date, mode: .countdown/.pomodoro, phase: .work/.break, cycle: Int)`, `.paused(remaining: TimeInterval, ...)`, `.completed`/`.segmentDone` — mirrors RESEARCH.md's Pattern 2 recommendation exactly.

**Pure stateless helper convention** (lines 45-53):
```swift
// Pure D-08 suffix check, no state, no I/O.
func isDownloadTempFile(path: String) -> Bool {
    downloadTempSuffixes.contains { path.hasSuffix($0) }
}

// Pure D-12 final-name extraction, no state, no I/O.
func downloadFilename(fromPath path: String) -> String {
    (path as NSString).lastPathComponent
}
```
Mirror this for any pure Timer mapping helper (e.g. a pure `remaining(from: deadline, now:)` if one lives at this layer instead of in the view). **Never call `Date()` inside this file** — Anti-Pattern warning in RESEARCH.md, confirmed by this analog's own convention (DownloadActivity.swift never reads the live clock).

---

### `Islet/Notch/TimerActivityState.swift` (NEW — store, event-driven)

**Analog 1 (shape):** `Islet/Notch/ChargingActivityState.swift` (full file, 12 lines)
```swift
// Plain published holder: no methods, no timers, no IOKit. The controller (Plan 03)
// reads IOPS, maps via powerActivity(from:), and sets `.activity` (nil → no splash).
final class ChargingActivityState: ObservableObject {
    @Published var activity: ChargingActivity?
}
```
Timer's state holder needs MORE than this (pause/resume/add-time/reset/segment-advance mutation methods live somewhere) — RESEARCH.md's Architecture diagram assigns this richer behavior to `TimerActivityState`, so treat `ChargingActivityState` only as the "plain `@Published` holder" skeleton, not the full shape.

**Analog 2 (testable-overload discipline for the mutation logic):** `Islet/Notch/DownloadCoordinator.swift:59-67`
```swift
// ActivityCoordinator conformance — reads the live clock and forwards to the testable
// overload below (mirrors DeviceCoordinator's handle(_:)/handle(_:now:) split).
func handle(_ reading: DownloadReading) {
    handle(reading, now: Date())
}

// The testable overload — no Date() call anywhere inside this body, so `startedAt`
// timestamps are deterministic in tests.
func handle(_ reading: DownloadReading, now: Date) {
    ...
}
```
Apply this exact split to every `TimerActivityState` mutation that needs "now" (pause capturing `remaining = deadline.timeIntervalSinceNow`, add-time extending the deadline): a public no-arg entry point that reads `Date()`, forwarding to a `now:`-parameterized overload with zero live-clock reads — this is what `IsletTests/TimerActivityStateTests.swift` (Wave 0 gap) needs to test deadline math deterministically.

**Reach-back closures + coordinator construction convention:** `Islet/Notch/DownloadCoordinator.swift:14-57` (already read above) shows the 4-closure init pattern (`queueHead`, `enqueue`, `replaceHead`, `removeInProgress`, `presentTransientChange`) — `TimerActivityState`/`TimerMonitor` together will need an equivalent small set of reach-back closures wired from `NotchWindowController` (see that file's pattern assignment below), not a stored reference to the controller itself.

---

### `Islet/Notch/TimerMonitor.swift` (NEW — service, event-driven)

**Analog:** `Islet/Notch/CalendarCountdownMonitor.swift` (full file, 110 lines — read in one pass)

**Lifecycle skeleton** (lines 17-46, 96-109):
```swift
@MainActor
final class CalendarCountdownMonitor {
    private let calendarService: CalendarService
    private let onChange: (CalendarCountdownActivity?) -> Void

    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    ...
    init(calendarService: CalendarService, onChange: @escaping (CalendarCountdownActivity?) -> Void) {
        self.calendarService = calendarService
        self.onChange = onChange
    }

    // Idempotent — never double-register the EKEventStoreChanged observer.
    func start() {
        guard !running else { return }
        running = true
        ...
        recheck()
    }

    nonisolated func stop() {
        timer?.cancel()
        timer = nil
        ...
        running = false
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The owner (NotchWindowController) is @MainActor and owns this monitor for its
        // active lifetime; its deinit calls calendarCountdownMonitor.stop() — mirrors
        // FocusModeMonitor.deinit's owner-driven-teardown discipline exactly.
    }
}
```
Copy this `@MainActor final class` + `nonisolated(unsafe) var timer`/`running` + idempotent `start()`/`nonisolated stop()`/empty `deinit` skeleton verbatim for `TimerMonitor`.

**One-shot deadline arm/cancel-then-reschedule pattern** (lines 87-94, cited verbatim in RESEARCH.md Pattern 1 and Code Examples):
```swift
private func armTimer(at date: Date) {
    let t = DispatchSource.makeTimerSource(queue: .main)
    // Deliberately no repeat/interval argument — one-shot divergence from FocusModeMonitor's polling shape.
    t.schedule(deadline: .now() + max(0, date.timeIntervalSinceNow))
    t.setEventHandler { [weak self] in self?.recheck() }
    t.resume()
    timer = t
}
```
And the cancel-then-reschedule discipline applied on every re-check (lines 56-60):
```swift
private func scheduleNext(from events: [EventInput]) {
    // Cancel-then-reschedule discipline, applied on EVERY re-check (deadline fire,
    // .EKEventStoreChanged fire, or the initial start() call).
    timer?.cancel()
    timer = nil
    ...
}
```
`TimerMonitor` re-arms on every pause/resume/add-time/segment-advance the exact same way — never a repeating `Timer.scheduledTimer`.

---

### `Islet/Notch/IslandResolver.swift` (MODIFIED — model/pure reducer, transform)

**Analog:** itself — extend the existing enums/functions in place, do not create parallel structures.

**1. `IslandPresentation`/`ActiveTransient` enum case convention** (lines 96-127) — named-rank trailing comments:
```swift
case downloadProgress(DownloadActivity)                // Phase 61 / DL-01/DL-02: rank 5 transient, collapsed-only (D-03), sub-state-persistent (D-02/D-13 -- see isPersistent below)
case capsLock(CapsLockActivity)                        // Phase 60 / CAPS-01: rank 6 transient, collapsed-only (D-07)
```
Add `case timer(TimerActivity)` to both enums with the same trailing-comment convention, plus a NEW `case timerExpanded(TimerActivity)` to `IslandPresentation` only (Pattern 4 — the first transient needing dedicated expanded content, no `ActiveTransient` equivalent needed since that enum only tracks the collapsed-queue head).

**2. `isPersistent` sub-state extension** (lines 136-145, RESEARCH.md Pattern 2, cite verbatim):
```swift
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }
        return false
    }
}
```
Add a `.timer` branch keyed on the running/paused sub-state (e.g. `if case .timer(let t) = self, t.isRunningOrPaused { return true }`) — `.completed`/`.segmentDone` must NOT match, so it falls through to `return false` and self-elapses via the shared ~3s dismiss, exactly like `.downloadProgress(.done)`.

**3. `preempt()` generalization — the literal SC5 fix** (lines 364-370):
```swift
// BEFORE
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}

// AFTER
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard let currentHead = head, currentHead.isPersistent else { return enqueue(t) }
    head = t
    pending.insert(currentHead, at: 0)
    return true
}
```
This one-guard-clause change is in scope for this phase (Pitfall 2 — it also retroactively fixes Download-Progress preemption).

**4. `resolve()`'s collapsed-only switch pattern to extend** (lines 175-189):
```swift
case .downloadProgress(let d) where !isExpanded: return .downloadProgress(d) // Phase 61 rank 5, collapsed-only (D-03)
case .downloadProgress: break                         // expanded -- falls through to the isExpanded branch below, unmodified
```
Timer does NOT follow this `break`-through shape (Pattern 4, Open Question 1 RESOLVED — expanded controls take priority). Add instead:
```swift
case .timer(let t) where !isExpanded: return .timer(t)         // collapsed pill
case .timer(let t): return .timerExpanded(t)                    // NEW: dedicated expanded controls, takes priority over selectedView/pendingDrop/nowPlaying
```
placed inside the initial `switch activeTransient` block (same tier as Charging/Device/Focus/OSD/Download/CapsLock/Update), never inside the `if isExpanded { ... }` block below.

**5. `updateHead(_:)` same-category refresh convention** (lines 385-393) — extend with a `(.timer, .timer)` arm for pause/reset/add-time/segment-advance mutations (Pitfall 4):
```swift
mutating func updateHead(_ t: ActiveTransient) {
    guard let h = head else { return }
    switch (h, t) {
    case (.charging, .charging): head = t
    case (.device, .device):     head = t
    case (.osd, .osd): head = t
    case (.downloadProgress, .downloadProgress): head = t
    default: break   // different category — ignore (use enqueue)
    }
}
```

---

### `Islet/Notch/NotchPillView.swift` (MODIFIED — component, request-response)

**Analog for `timerWings(for:)` (collapsed pill):** `countdownWings(for:)` (lines 2649-2675) + `formatMMSS` helper (lines 2639-2642):
```swift
private func formatMMSS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

private func countdownWings(for activity: CalendarCountdownActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: Self.wingsLabelWidth / 2) {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, activity.eventStart.timeIntervalSince(context.date))
            let color = urgencyColor(for: activity.eventStart, at: context.date)
            HStack(spacing: 0) {
                Image(systemName: "calendar")...
                Spacer()
                Text(formatMMSS(remaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
        }
    }
}
```
Reuse `formatMMSS` verbatim (do not re-derive). Build `timerWings(for:)` on this same `TimelineView(.periodic(from:.now,by:1))` + `wingsShape` shape — **both icon and text color must come from the SAME computed value inside the single `TimelineView` tick closure** (the file's own comment at lines 2644-2648 explicitly warns against desync from putting the icon outside the TimelineView).

**Analog for wing width/margin math (camera-clearance convention):** `capsLockWings` (lines 2880-2915) and `downloadWings` (lines 2994-3046) both compute `leftWidth`/`rightWidth` from `interaction.collapsedNotchSize` plus an on-device-tuned `margin` constant, with defensive `assert`s:
```swift
let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
let margin: CGFloat = 20   // (downloadWings' value; capsLockWings uses 65, updateWings uses 30)
let notchHalfWidth = rawNotchHalfWidth + margin
let cameraBlockWidth = notchHalfWidth * 2
...
assert(cameraBlockWidth > 0, "... camera block width (\(cameraBlockWidth)) must be positive")
assert(rightWidth < 325 && leftWidth < 325, "... footprint must stay inside the ~325pt safe panel-frame budget")
```
Per UI-SPEC's Spacing Scale note: **start `timerWings(for:)`'s margin from `downloadWings`' (20) or `capsLockWings`' (65) existing value as baseline, retune on-device only if content width differs — do not guess a fresh value.**

**Analog for `timerExpandedContent(for:)` (the NEW expanded controls, D-08):** `navCircleButton` (lines 1977-1988):
```swift
private func navCircleButton(systemName: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.black : Color.white)
            .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
            .background(Circle().fill(filled ? Color.white : Color.clear))
            .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
}
```
Use directly for Pause/Resume (filled, toggles glyph), Reset, Add-Time, Stop (all outlined) per D-08/D-10 — **do NOT use `chipButton`** (lines 2012-2025, the text-chip style explicitly rejected by D-08). Each needs an explicit `.accessibilityLabel` per UI-SPEC (icon-only, no caption).

**Analog for the duration/mode picker sheet (D-01/D-02/D-03 — genuinely new UI):** `onboardingCarousel(_:)` (starts line 1744) is the closest step-based-flow precedent per RESEARCH.md's own "no existing picker/sheet pattern" finding — read this function's full body when implementing the sheet (it's the only multi-control-row, mode-switching flow in this codebase), but expect to write mostly new layout code, not copy verbatim. `chipButton` (lines 2012-2025) IS the correct reuse for the duration/mode preset chips (D-02/D-03 — NOT the same context as D-08's circular buttons):
```swift
private func chipButton(_ label: String, fontSize: CGFloat = 14, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.12)))
    }
    .buttonStyle(.plain)
}
```

**Analog for the "Start Timer" Home button placement + completion-splash icon sizing:** `homeEmptyContent` (lines 1144-1156):
```swift
private var homeEmptyContent: some View {
    VStack(spacing: 4) {
        Image(systemName: "music.note")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
        Text("Nothing Playing")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        Text("Start something in Spotify or Music.")
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}
```
The "Start Timer" button (D-01) slots into whichever Home sub-state view (`homeLastPlayed`/`homeEmptyContent`) is already rendering, inline — not a new empty state. **Per Open Question 2's resolution, do NOT reuse this 28px icon for the completion splash** — the splash renders inside the collapsed `wingsShape` container (like `downloadWings`' 14px `checkmark.circle.fill` icon, lines 3033-3037), not inside this expanded `blobShape` box; shrink to the standard 14-20px wing icon size instead.

**Presentation-switch wiring point** (lines 913-946, 955-983): add `case .timer(let a): timerWings(for: a)` next to the other collapsed-transient cases (~line 940-942), and `case .timerExpanded(let a): timerExpandedContent(for: a)` as a NEW top-level case in `presentationSwitch` — **not** routed through the shared `tabContentView`/`blobShape` grouping (lines 934, 955-984), since Timer's expanded view is its own distinct shape per Pattern 4, not one of the 6 switcher-row tabs.

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — controller, event-driven)

**Analog for monitor start/stop lifecycle:** `startDownloadMonitor()` (lines 828-833):
```swift
// Phase 61 / DL-01/DL-02 (Plan 04) — idempotent start, mirrors startCapsLockMonitor()'s
// exact shape.
private func startDownloadMonitor() {
    guard downloadMonitor == nil else { return }
    let monitor = DownloadMonitor { [weak self] reading in self?.downloadCoordinator.handle(reading) }
    downloadMonitor = monitor
    monitor.start()
}
```
Copy this exact idempotent-guard + construct + assign + `.start()` shape for `startTimerMonitor()`.

**Analog for coordinator/state construction with reach-back closures** (lines 523-557, `downloadCoordinator` init block):
```swift
downloadCoordinator = DownloadCoordinator(
    queueHead: { [weak self] in self?.transientQueue.head },
    enqueue: { [weak self] t in
        guard let self else { return false }
        if case .focus = self.transientQueue.head { return self.transientQueue.preempt(t) }
        return self.transientQueue.enqueue(t)
    },
    replaceHead: { [weak self] t in
        guard let self else { return }
        self.transientQueue.updateHead(t)
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.renderPresentation()
        }
        self.scheduleActivityDismiss()
    },
    removeInProgress: { [weak self] in ... },
    presentTransientChange: { [weak self] in self?.presentTransientChange() }
)
```
**Important divergence for Timer:** the `enqueue` closure's `if case .focus = self.transientQueue.head { return self.transientQueue.preempt(t) }` guard is the OLD hardcoded-`.focus` pattern every existing coordinator copies — per the IslandResolver.swift pattern assignment above (SC5 fix), this phase's own coordinator wiring should use the GENERALIZED `preempt(t)` unconditionally (since `preempt()` itself now internally guards on `head.isPersistent`), i.e. simplify new call sites to always call `self.transientQueue.preempt(t)` rather than re-deriving the same `.focus`-only guard the resolver file itself is being fixed to eliminate. Flag this to the planner explicitly — don't propagate the pre-fix idiom into new code.

**Analog for the shared dismiss-timer persistence gate** (`scheduleActivityDismiss()`, lines 2359-2394): already generic (`guard let head = transientQueue.head, !head.isPersistent else { return }`) — Timer's `.running`/`.paused` sub-states automatically skip the timer once `isPersistent` is extended (IslandResolver.swift change above), zero changes needed here beyond that.

**Analog for `syncActivityModels()` per-category model clearing** (lines 2400-2409) — add a `case .timer: chargingState.activity = nil` arm (or equivalent for Timer's own `@Published` state) mirroring every existing arm's shape.

**Analog for settings toggle-on/off reconciliation** (`handleSettingsChanged()`, lines 2520-2538, the Caps Lock and Download Progress blocks):
```swift
if activityEnabled(ActivitySettings.capsLockKey) {
    startCapsLockMonitor()
} else if capsLockMonitor != nil {
    capsLockMonitor?.stop(); capsLockMonitor = nil
    flushTransients(.capsLock)
}
```
Timer likely needs the Download Progress variant (with an extra `.reset()` call) since it has real session state to clear on toggle-off, not the simpler Caps Lock variant.

---

### `IsletTests/TimerActivityTests.swift` (NEW — test, transform)

**Analog:** `IsletTests/DownloadActivityTests.swift` — plain `XCTAssert` style, no shared fixture, testing the pure enum/helper functions in `DownloadActivity.swift` directly. Mirror this file's structure for `TimerActivity`'s pure mapping/segment-advance logic.

### `IsletTests/TimerActivityStateTests.swift` (NEW — test, event-driven)

**Analog:** `IsletTests/DownloadCoordinatorTests.swift` (lines 1-58 read):
```swift
@MainActor
final class DownloadCoordinatorTests: XCTestCase {
    func testCreatedMatchingTempPathTracksAndEnqueuesInProgress() {
        var q = TransientQueue()
        var enqueueCount = 0
        var presentCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: {},
            presentTransientChange: { presentCount += 1 }
        )
        let reading = DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil)
        coordinator.handle(reading, now: Date())
        XCTAssertEqual(enqueueCount, 1)
        XCTAssertEqual(presentCount, 1)
    }
    ...
}
```
"No fakes, wire a real `var q = TransientQueue()`, count closure calls with local `var ...Count = 0` variables" — the exact convention to use for `TimerActivityStateTests`, calling the `now:`-parameterized testable overload for deterministic pause/resume/add-time deadline-math assertions.

### `IsletTests/IslandResolverTests.swift` (MODIFIED, extend)

**Analog:** itself — the `MARK: Phase 61 / DL-01/DL-02` block (lines 724-770) is the direct template to clone for Timer:
```swift
func testDownloadProgressCollapsedOnly() { ... }        // -> testTimerCollapsedOnly()
func testDownloadProgressFallsThroughWhenExpanded() { }  // Timer instead RETURNS .timerExpanded (Pattern 4 diverges here — do NOT clone this one verbatim, write a NEW testTimerShowsExpandedControlsWhenExpanded() asserting .timerExpanded, not homeEmpty fallthrough)
func testDownloadProgressPreemptsStandingFocusHead() { } // -> testTimerPreemptsStandingFocusHead()
func testUpdateHeadReplacesDownloadProgressAcrossInnerCasesInstantly() { } // -> testUpdateHeadReplacesTimerAcrossInnerCasesInstantly()
```
Also extend `testActiveTransientIsPersistentFlags()` (lines 646-660) with `.timer(.running(...))`/`.timer(.paused(...))` → true and `.timer(.completed)`/`.timer(.segmentDone)` → false assertions, mirroring the existing `.downloadProgress` pair exactly (lines 658-659). Add a NEW regression test for the generalized `preempt()` guard (Pitfall 2) asserting a `.downloadProgress(.inProgress)` head IS now preempted by a Charging/Device transient — this is a behavior change existing tests don't cover yet.

## Shared Patterns

### One-shot deadline scheduling (never a repeating poll)
**Source:** `Islet/Notch/CalendarCountdownMonitor.swift:87-94`
**Apply to:** `TimerMonitor.swift` exclusively for firing completion (sound + splash) — `TimelineView` remains display-only.

### Sub-state-persistent transient + generalized `isPersistent`/`preempt()`
**Source:** `Islet/Notch/IslandResolver.swift:136-145, 364-370` (Download-Progress precedent + the SC5 fix)
**Apply to:** `TimerActivity`'s running/paused vs completed/segmentDone split; ALL new coordinator `enqueue` closures in `NotchWindowController.swift` should call the generalized `preempt(t)` directly rather than re-deriving `if case .focus = head`.

### Circular icon buttons, not text chips
**Source:** `Islet/Notch/NotchPillView.swift:1977-1988` (`navCircleButton`)
**Apply to:** All 4 expanded Timer controls (Pause/Resume, Reset, Add-Time, Stop) — D-08 explicitly excludes `chipButton` for this row (chips are still correct for the duration-picker sheet's preset chips, D-02/D-03).

### `formatMMSS` reuse
**Source:** `Islet/Notch/NotchPillView.swift:2639-2642`
**Apply to:** Both `timerWings(for:)`'s live countdown and the Pomodoro "Work · Cycle N" label's mm:ss portion — do not write a second formatter.

### Testable-overload discipline (no live `Date()` in mutation logic)
**Source:** `Islet/Notch/DownloadCoordinator.swift:59-67`
**Apply to:** Every `TimerActivityState` method that computes deadlines (pause/resume/add-time/segment-advance) — public `Date()`-reading entry point forwards to a `now:`-parameterized overload, enabling deterministic tests.

### Idempotent monitor start/stop + `@MainActor`/`nonisolated(unsafe)` lifecycle skeleton
**Source:** `Islet/Notch/CalendarCountdownMonitor.swift:17-46, 96-109`
**Apply to:** `TimerMonitor.swift`, and its construction/wiring in `NotchWindowController.swift` (mirrors `startDownloadMonitor()`).

## No Analog Found

None — every file in scope has at least one strong, directly-citable analog already in the codebase. The duration/mode picker sheet (D-01/D-02/D-03) has only a partial analog (`onboardingCarousel`'s step-flow shape + `chipButton`'s chip style) since RESEARCH.md's own finding is that no dedicated picker/sheet pattern exists yet — flagged above, not omitted.

## Metadata

**Analog search scope:** `Islet/Notch/` (IslandResolver.swift, CalendarCountdownMonitor.swift, ChargingActivityState.swift, DownloadActivity.swift, DownloadCoordinator.swift, DownloadMonitor.swift, NotchPillView.swift, NotchWindowController.swift), `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `IsletTests/` (IslandResolverTests.swift, DownloadCoordinatorTests.swift)
**Files scanned:** 11 read directly (targeted ranges for files > 2000 lines: NotchPillView.swift, NotchWindowController.swift), plus grep-located line numbers across all of `Islet/Notch/`
**Pattern extraction date:** 2026-07-24
