# Phase 41: Calendar Countdown HUD - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 8 (2 new, 6 modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/CalendarCountdownMonitor.swift` (NEW) | monitor/service | event-driven + one-shot deadline scheduling | `Islet/Notch/FocusModeMonitor.swift` (lifecycle shape) + `Islet/Notch/DropInterceptTap.swift` (health-check-timer re-arm precedent) | role-match (lifecycle exact, scheduling model differs — polling vs. deadline) |
| `Islet/Calendar/CalendarGlance.swift` (MODIFIED — add `nextUpcomingEvent`) | utility (pure selection function) | transform | same file, `nextRelevantEvent(events:now:)` | exact |
| `Islet/Calendar/CalendarService.swift` (MODIFIED — possible new fetch method, Open Question 1) | service (EventKit seam) | request-response (async fetch) | same file, `fetchUpcoming(completion:)` / `fetchMonth(containing:completion:)` | exact |
| `Islet/Notch/IslandResolver.swift` (MODIFIED — new case, param, ordering) | pure resolver / reducer | transform (CRUD-free state reducer) | same file, `resolve(...)` ambient branch (lines 157-161) | exact |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED — monitor ownership, `handleCalendarCountdownChange`, settings wiring) | controller | event-driven | same file, `startFocusModeMonitor()`/`handleFocusChange(_:)` (lines 658-663, 1657-1672) | exact |
| `Islet/Notch/NotchPillView.swift` (MODIFIED — new `countdownWings(for:)`, presentation-switch case) | component (SwiftUI view) | request-response (render from state) | same file, `focusWings(for:)` (lines 2259-2287) for wing shape; `EqualizerBars` (lines 2757-2802) for the `TimelineView` per-tick gating | exact |
| `Islet/ActivitySettings.swift` (MODIFIED — new `calendarCountdownKey`) | config | CRUD (UserDefaults key) | same file, `deviceKey`/`nowPlayingKey` (default-ON keys, lines 15-18) | exact |
| `Islet/SettingsView.swift` (MODIFIED — new `Toggle`) | component (SwiftUI view) | request-response | same file, `Toggle("Devices", isOn: $deviceEnabled)` (line 219) — plain, non-permission-gated toggle | exact |
| `IsletTests/IslandResolverTests.swift` (MODIFIED — new test cases) | test | — | same file, `testDeviceOutranksAmbientMedia()` (lines 29-37) | exact |
| `IsletTests/CalendarGlanceTests.swift` (MODIFIED — new test cases for `nextUpcomingEvent`) | test | — | same file, existing `nextRelevantEvent` tests (lines 10-21) | exact |

**Note:** `IsletTests/CalendarGlanceTests.swift` already exists (contradicts 41-RESEARCH.md's "no dedicated test file yet" — confirmed present with full coverage of `nextRelevantEvent`/`daysInMonth`/`events(on:)`). Add `nextUpcomingEvent` tests to this existing file, do not create a new one.

## Pattern Assignments

### `Islet/Notch/CalendarCountdownMonitor.swift` (NEW — monitor, event-driven)

**Analog:** `Islet/Notch/FocusModeMonitor.swift` (lifecycle shape only — do NOT copy its polling `t.schedule(deadline: .now(), repeating: 2.5, ...)`)

**Lifecycle pattern** (`FocusModeMonitor.swift` lines 29-41, 43-54, 85-97):
```swift
@MainActor
final class FocusModeMonitor {
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    private let onChange: (Bool) -> Void
    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        guard !running else { return }   // idempotent — never double-schedule.
        running = true
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 2.5, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    nonisolated func stop() {
        timer?.cancel()
        timer = nil
        running = false
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode — owner's deinit calls stop().
    }
}
```
**What to change for CalendarCountdownMonitor:** replace the repeating `schedule(deadline:repeating:)` with a ONE-SHOT `t.schedule(deadline: .now() + interval)` (no `repeating:` argument) recomputed and rearmed on every fire — per 41-RESEARCH.md Pattern 3, three deadline kinds: (a) `event.start - 3600s` when a future event exists beyond the lookahead, (b) `event.start` when a countdown is active (dismiss + D-09 re-arm), (c) no timer armed at all when no event exists (rely on `.EKEventStoreChanged`). Also add an `NSNotificationCenter` observer for `.EKEventStoreChanged` in `start()` that triggers an immediate re-check (debounced per Pitfall 4 if bursts are seen on-device — mirrors `DropInterceptTap.swift`'s own defensive re-check timer below).

**Re-check/reinstall pattern** (`DropInterceptTap.swift` lines 63-75, health-check timer that re-verifies and self-heals):
```swift
// Poll every 5s and reinstall if needed.
healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
    self?.checkHealthAndReinstallIfNeeded()
}

private func checkHealthAndReinstallIfNeeded() {
    guard let machPort else { return }
    if !CGEvent.tapIsEnabled(tap: machPort) {
        stop()
        start()
    }
}
```
**When to use:** as the shape for "cancel-then-reschedule" discipline — every re-check (deadline fire OR `.EKEventStoreChanged` notification) must cancel any prior scheduled timer before arming a new one, exactly like `NotchWindowController.scheduleActivityDismiss()` does (`dismissWorkItem?.cancel()` before creating a new `DispatchWorkItem`, see below).

**Owner-driven teardown discipline** — mirrors `stop()`'s `nonisolated` shape so `NotchWindowController.deinit` can call `calendarCountdownMonitor?.stop()` directly (see controller pattern below).

---

### `Islet/Calendar/CalendarGlance.swift` (MODIFIED — add `nextUpcomingEvent`)

**Analog:** same file, `nextRelevantEvent(events:now:)` (lines 37-58)

**Pure total-function pattern to mirror** (lines 1-22, 37-58):
```swift
import Foundation

// `now` is ALWAYS an explicit parameter -- never Date()/Date.now inside this function --
// mirroring DeviceActivity.swift's "caller passes now" discipline so tests stay deterministic.

struct EventInput: Equatable {
    let title: String
    let start: Date
    let end: Date
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
}

// D-04: today's next in-progress-or-upcoming event, else tomorrow's first event, else nil.
// Total function -- an empty or entirely-past `events` array returns nil, never crashes.
func nextRelevantEvent(events: [EventInput], now: Date) -> CalendarGlance? {
    let calendar = Calendar.current
    if let todayEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: now) && $0.end > now })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: todayEvent.title, startDate: todayEvent.start, isToday: true, ...)
    }
    // ... tomorrow fallback ...
    return nil
}
```
**New function shape** (per 41-RESEARCH.md Pattern 4, already drafted there — copy verbatim, add as a sibling, do NOT modify `nextRelevantEvent`):
```swift
func nextUpcomingEvent(events: [EventInput], now: Date, lookahead: TimeInterval = 3600) -> EventInput? {
    events
        .filter { $0.start > now && $0.start <= now.addingTimeInterval(lookahead) }
        .sorted { $0.start < $1.start }
        .first
}
```
**Critical distinction (Pitfall 2):** `nextRelevantEvent` includes in-progress events (`start <= now`, `end > now`) — `nextUpcomingEvent` must use `start > now` (strictly not-yet-started) or the countdown will show a negative/elapsed time.

---

### `Islet/Calendar/CalendarService.swift` (MODIFIED — Open Question 1, planner's call)

**Analog:** same file, `fetchUpcoming(completion:)` (lines 43-62)

**Fetch pattern to mirror if adding a new protocol method:**
```swift
func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void) {
    Task {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else {
            await MainActor.run { completion(nil) }   // D-03: silent degrade, no retry/nag
            return
        }
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: Date(),
                                                  end: Date().addingTimeInterval(2 * 24 * 3600),
                                                  calendars: calendars)
        let events = store.events(matching: predicate)
        let mapped = events.map { mapToEventInput($0) }
        let glance = nextRelevantEvent(events: mapped, now: Date())
        await MainActor.run { completion(glance) }
    }
}
```
**If adding a new method** (RESEARCH.md's recommended Option (b)): mirror this exact shape but return raw `[EventInput]` via `mapToEventInput` (already factored, lines 93-103) with a predicate window matching the countdown's needs (e.g. `Date()...Date()+3600s` or slightly wider), added to the `CalendarService` protocol (lines 15-38) and its sole conformer `EventKitService`. No new permission request — `requestFullAccessToEvents()` is already the gate.

**Silent-degrade convention** (protocol doc comment, lines 15-19): every method settles a safe empty/nil value on denial, never retries/re-prompts — Calendar Countdown must follow this exactly (no countdown ever appears, no nag, per CONTEXT.md's Integration Points).

---

### `Islet/Notch/IslandResolver.swift` (MODIFIED — new case + resolve() param)

**Analog:** same file, ambient branch (lines 157-161) and `nowPlayingLaunchGate` (lines 172-180)

**New pure value type** (mirrors `FocusActivity`'s Foundation-only shape, `Islet/Notch/FocusActivity.swift` lines 12-14):
```swift
enum FocusActivity: Equatable {
    case on
}
```
Apply the same discipline for `CalendarCountdownActivity` (per 41-RESEARCH.md Code Examples):
```swift
struct CalendarCountdownActivity: Equatable {
    let eventStart: Date   // the view computes mm:ss + urgency color from (eventStart - now)
}
```

**Ambient branch extension pattern** (`IslandResolver.swift` lines 156-161):
```swift
// Phase 17 / NOW-04 — D-01/D-03: the launch gate applies ONLY to this ambient branch...
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
return .idle
```
**Recommended new shape** (D-01, checked-ordered pair, new case wins first — matches this file's own "TOTAL pure reducer" discipline, no new branching complexity):
```swift
if let countdown = calendarCountdown { return .calendarCountdown(countdown) }  // D-01: always wins the ambient slot
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }
return .idle
```
Add `calendarCountdown: CalendarCountdownActivity? = nil` as a new trailing default-nil parameter to `resolve(...)` (line 116) — additive, existing call sites compile unchanged.

**IslandPresentation case addition** — add `case calendarCountdown(CalendarCountdownActivity)` to the enum (alongside line 61's `.nowPlayingWings`), doc-commented with its ambient rank per this file's existing convention (see lines 55-68 for the comment style to match).

**`songChangeToastGate` — explicitly UNCHANGED** (D-02, lines 195-197): confirm in the plan that zero code changes are needed here; it only reads `activeTransient`/`isExpanded`/`toastEnabled`, no ambient-tier input.

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — monitor ownership + handler)

**Analog:** same file, `startFocusModeMonitor()` (lines 658-663) + `handleFocusChange(_:)` (lines 1657-1672) + `scheduleActivityDismiss()` (lines 1772-1807, for the cancel-then-reschedule discipline only, NOT for direct reuse — Pitfall 5)

**Monitor-start pattern** (lines 657-663):
```swift
// Phase 38 / HUD-05 — idempotent start, mirrors startPowerMonitor()'s exact shape.
private func startFocusModeMonitor() {
    guard focusModeMonitor == nil else { return }
    let monitor = FocusModeMonitor { [weak self] isFocused in self?.handleFocusChange(isFocused) }
    focusModeMonitor = monitor
    monitor.start()
}
```
Mirror for `startCalendarCountdownMonitor()`: `guard calendarCountdownMonitor == nil else { return }`, construct with an `onChange: (CalendarCountdownActivity?) -> Void` closure, `.start()`.

**Change-handler pattern** (lines 1657-1672, `handleFocusChange`):
```swift
private func handleFocusChange(_ isFocused: Bool) {
    if isFocused {
        guard let activity = focusActivity(from: true) else { return }
        let changed = transientQueue.enqueue(.focus(activity))
        if changed {
            presentTransientChange()
        }
    } else {
        flushTransients(.focus)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            renderPresentation()
        }
        updateVisibility()
    }
}
```
**Critical divergence for `handleCalendarCountdownChange`** (Pitfall 5, 41-RESEARCH.md): the Countdown is AMBIENT, not an `ActiveTransient` — it must NEVER call `transientQueue.enqueue(...)`/`flushTransients(...)`/`scheduleActivityDismiss()`. Instead mutate a plain `@Published var calendarCountdown: CalendarCountdownActivity?` directly, then:
```swift
private func handleCalendarCountdownChange(_ activity: CalendarCountdownActivity?) {
    calendarCountdown = activity
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()
}
```
(mirrors `handleFocusChange`'s off-branch tail exactly — render + updateVisibility, no transient-queue plumbing at all).

**Cancel-then-reschedule discipline to mirror inside the monitor, not the controller** (`scheduleActivityDismiss()` lines 1772-1773, 1806): `dismissWorkItem?.cancel()` before creating a new `DispatchWorkItem`/timer — the same discipline `CalendarCountdownMonitor`'s own re-check function must apply internally before arming its next one-shot deadline.

**Settings wiring precedent** — `activityEnabled(ActivitySettings.focusKey)` gate at line 511 (`if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized { startFocusModeMonitor() }`) — Calendar Countdown's start call should mirror this shape but WITHOUT the permission-authorized conjunct (Calendar access is already resolved lazily inside `CalendarService`, not gated by a separate `isAuthorized` static like Focus): `if activityEnabled(ActivitySettings.calendarCountdownKey) { startCalendarCountdownMonitor() }`.

**Teardown** — mirrors line 2309's `focusModeMonitor?.stop()` in the controller's `deinit`/teardown path: add `calendarCountdownMonitor?.stop()` alongside it.

---

### `Islet/Notch/NotchPillView.swift` (MODIFIED — new wing view + switch case)

**Analog 1 (wing shape):** `focusWings(for:)` (lines 2259-2287)
```swift
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: 160) {
        HStack(spacing: 0) {
            Image(systemName: "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(.leading, 14)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("On")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.trailing, 20)
        }
    }
}
```
**Analog 2 (per-tick gated TimelineView refresh — D-04's resolved mechanism):** `EqualizerBars` (lines 2757-2802), specifically the idle-CPU-trap discipline:
```swift
// ⚠️ THE IDLE-CPU TRAP: `TimelineView(.animation(paused: !isPlaying))` MUST stay the outer
// clock gate ... so idle CPU returns to ~0 the instant playback pauses. Do NOT swap this
// for an unconditional `.repeatForever` or a live `Timer`.
var body: some View {
    TimelineView(.animation(paused: !isPlaying)) { context in
        let t = context.date.timeIntervalSinceReferenceDate
        // ... derive display value from `t` ...
    }
}
```
**Concrete `countdownWings(for:)` to write** (already drafted in 41-RESEARCH.md Code Examples, mirrors `focusWings(for:)`'s `wingsShape(leftWidth:rightWidth:)` call shape, uses `TimelineView(.periodic(from:by:1))` per D-04's resolved mechanism, NOT `.animation(paused:)` — the countdown wing has no "present but inactive" state, unlike `EqualizerBars`):
```swift
private func countdownWings(for activity: CalendarCountdownActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: Self.wingsSize.width / 2) {
        HStack(spacing: 0) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(urgencyColor(for: activity.eventStart))
                .padding(.leading, 14)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, activity.eventStart.timeIntervalSince(context.date))
                Text(formatMMSS(remaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(urgencyColor(for: activity.eventStart, at: context.date))
                    .padding(.trailing, 20)
            }
        }
    }
}
```

**Presentation-switch wiring** (`presentationSwitch`, lines 742-781) — add one case in the same style as line 776:
```swift
case .focus(let activity): focusWings(for: activity)                 // D-02 rank 3 transient (38-04)
```
becomes (new case, inserted in the ambient section near `.nowPlayingWings` at line 753, since Countdown is ambient not transient):
```swift
case .calendarCountdown(let activity): countdownWings(for: activity)  // Phase 41 / HUD-08: ambient, D-01 always wins over nowPlayingWings
```

`urgencyColor(for:at:)` and `formatMMSS(_:)` are new small pure helpers (D-05: orange full window, red final minute) — no direct analog needed, trivial `Color`/`String(format:)` logic; place alongside `countdownWings(for:)`.

---

### `Islet/ActivitySettings.swift` (MODIFIED — new key)

**Analog:** same file, `deviceKey`/`nowPlayingKey` (lines 15-18) — plain default-ON keys, NOT the permission-gated `focusKey`/`osdSuppressionKey` shape (lines 22-26), since Calendar access has no separate "authorized" static check the way Focus/OSD do.
```swift
static let chargingKey   = "activity.charging"
static let nowPlayingKey = "activity.nowPlaying"
static let songChangeToastKey = "activity.songChangeToast"
static let deviceKey     = "activity.device"
```
**New key to add:**
```swift
// Phase 41 / HUD-08 (D-03) — default ON, matches Charging/Device/Now-Playing's
// opt-out convention (not opt-in like Focus/OSD, which are permission-gated).
static let calendarCountdownKey = "activity.calendarCountdown"
```

---

### `Islet/SettingsView.swift` (MODIFIED — new Toggle)

**Analog:** same file, plain default-true toggle pattern (line 219):
```swift
@AppStorage(ActivitySettings.deviceKey) private var deviceEnabled = true
...
Toggle("Devices", isOn: $deviceEnabled)
```
**New declaration + toggle to add** (D-03: default ON, no permission popover — Calendar's permission flow is already handled inside `CalendarService`'s own lazy `requestFullAccessToEvents()`, not surfaced as a Settings-toggle-triggered explanation the way Focus/OSD are):
```swift
@AppStorage(ActivitySettings.calendarCountdownKey) private var calendarCountdownEnabled = true
...
Toggle("Calendar Countdown", isOn: $calendarCountdownEnabled)
```
Placed in the `Section("Activities")` block (lines 214-219 today) alongside the other plain toggles — NOT alongside the permission-gated Focus/OSD toggles (lines 224-248), since D-03 explicitly matches the opt-out convention.

---

### `IsletTests/IslandResolverTests.swift` (MODIFIED — new test cases)

**Analog:** same file, `testDeviceOutranksAmbientMedia()` (lines 29-37):
```swift
func testDeviceOutranksAmbientMedia() {
    let r = resolve(activeTransient: .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)),
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: false)
    XCTAssertEqual(r, .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)))
}
```
**New tests to add** (per 41-RESEARCH.md Validation Architecture, Req HUD-08):
1. `resolve(...)` returns `.calendarCountdown` ahead of `.nowPlayingWings` when both `calendarCountdown` and `nowPlaying` inputs are present (D-01) — same call shape as above, add `calendarCountdown: CalendarCountdownActivity(eventStart: someDate)`, assert `.calendarCountdown(...)`.
2. `resolve(...)` never returns `.calendarCountdown` while `isExpanded == true` or while any `ActiveTransient` is present — mirror `testShelfComposingBranchesUnreachableDuringTransient()` (lines 45-53)'s "pass a transient, assert the ambient case is unreachable" shape.

---

### `IsletTests/CalendarGlanceTests.swift` (MODIFIED — new test cases)

**Analog:** same file, existing `nextRelevantEvent` tests (lines 10-21, 23-38, 78-82):
```swift
func testInProgressEventTodayIsReturned() {
    let now = Date()
    let event = EventInput(title: "Standup",
                            start: now.addingTimeInterval(-10 * 60),
                            end: now.addingTimeInterval(20 * 60),
                            colorRed: 1, colorGreen: 0, colorBlue: 0)
    let result = nextRelevantEvent(events: [event], now: now)
    XCTAssertEqual(result, CalendarGlance(title: "Standup", startDate: event.start, isToday: true,
                                           colorRed: 1, colorGreen: 0, colorBlue: 0))
}

func testEmptyEventsListReturnsNilWithoutCrashing() {
    let result = nextRelevantEvent(events: [], now: Date())
    XCTAssertNil(result)
}
```
**New tests to add for `nextUpcomingEvent(events:now:lookahead:)`** (per 41-RESEARCH.md Validation Architecture, Pitfall 2 coverage):
1. Excludes an already-started event (`start <= now`) even if `end > now` — the exact case `nextRelevantEvent` WOULD include, proving the two functions diverge correctly.
2. Includes an event exactly at the 1hr boundary (`start == now.addingTimeInterval(3600)`, inclusive per the `<=` in the recommended implementation).
3. Returns nil on empty input (mirrors `testEmptyEventsListReturnsNilWithoutCrashing`).
4. Returns nil when all events are outside the lookahead window (too far in the future, or in the past).

---

## Shared Patterns

### One pure arbiter (Pitfall 6)
**Source:** `Islet/Notch/IslandResolver.swift` — `resolve(...)`'s entire structure
**Apply to:** `IslandResolver.swift` (the ONLY place D-01's priority check may live), `NotchWindowController.swift` (feeds `calendarCountdown` in, never branches on it itself before calling `resolve`)
```swift
// D-01 lives ONLY here — never as a suppression flag in NowPlayingMonitor or a
// view-layer @State check.
if let countdown = calendarCountdown { return .calendarCountdown(countdown) }
```

### `now`-as-explicit-parameter discipline
**Source:** `Islet/Calendar/CalendarGlance.swift` file header (lines 9-10), `Islet/Notch/IslandResolver.swift`'s `nowPlayingLaunchGate` doc comment
**Apply to:** `nextUpcomingEvent(events:now:lookahead:)` — never `Date()`/`Date.now` inside the pure function; the monitor (system glue) is the only caller allowed to construct a real `Date()`.

### Idempotent monitor lifecycle + nonisolated stop()
**Source:** `Islet/Notch/FocusModeMonitor.swift` (full file, lines 29-97)
**Apply to:** `CalendarCountdownMonitor.swift` — `guard !running else { return }` in `start()`, `nonisolated func stop()` callable from the owner's `deinit`.

### Cancel-then-reschedule discipline
**Source:** `Islet/Notch/NotchWindowController.swift`, `scheduleActivityDismiss()` (lines 1772-1773, 1806)
**Apply to:** `CalendarCountdownMonitor`'s internal re-check function — cancel any prior scheduled deadline before arming the next one, every time (deadline fire, `.EKEventStoreChanged` notification, or app-level trigger).

### Silent-degrade on permission denial
**Source:** `Islet/Calendar/CalendarService.swift` file header (lines 8-9) and `fetchUpcoming` (lines 46-50)
**Apply to:** `CalendarCountdownMonitor` — Calendar access denial means the countdown simply never appears (no timer armed), never retries/nags.

### Settings toggle: plain default-ON (not permission-gated)
**Source:** `Islet/ActivitySettings.swift` (lines 15-18) + `Islet/SettingsView.swift` (line 219, `Toggle("Devices", ...)`)
**Apply to:** `calendarCountdownKey` + its `SettingsView.swift` toggle — D-03 explicitly matches this simpler shape, NOT Focus/OSD's permission-explanation-popover shape (lines 224-248 of `SettingsView.swift`).

### `TimelineView` as the ONLY sanctioned per-tick UI clock (idle-CPU trap)
**Source:** `Islet/Notch/NotchPillView.swift`, `EqualizerBars` header comment (lines 2750-2756)
**Apply to:** `countdownWings(for:)`'s mm:ss display — `TimelineView(.periodic(from: .now, by: 1))` scoped to the wing's own mount lifecycle; never a `Timer`/`DispatchSourceTimer` driving `@State` for this purpose.

## No Analog Found

None — every file this phase touches has a direct, on-disk precedent (see table above). The one genuinely novel piece (EventKit-change-notification-driven scheduling, replacing "poll" with "one-shot deadline + push notification") has no existing precedent in this codebase to copy verbatim; `41-RESEARCH.md` Pattern 2/3 and this document's `CalendarCountdownMonitor.swift` section give the concrete shape to write from first principles, adapted from `FocusModeMonitor`'s lifecycle skeleton.

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Calendar/`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `IsletTests/`
**Files scanned:** `IslandResolver.swift`, `FocusModeMonitor.swift`, `FocusActivity.swift`, `DropInterceptTap.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `CalendarGlance.swift`, `CalendarService.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `IslandResolverTests.swift`, `CalendarGlanceTests.swift`
**Pattern extraction date:** 2026-07-18
