# Phase 28: Calendar Full View - Pattern Map

**Mapped:** 2026-07-13
**Files analyzed:** 9 (5 modified, 3-4 new)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Calendar/CalendarService.swift` (extend) | service | CRUD (extend fetch + add write) | itself — `fetchUpcoming` (L19-54) is the pattern for the new `fetchMonth`/`createReminder` methods | exact (self-analog) |
| `Islet/Calendar/CalendarGlance.swift` (extend) | utility (pure business logic) | transform | itself — `nextRelevantEvent(events:now:)` (L37-58) is the pattern for new day/month-bucketing functions | exact (self-analog) |
| `Islet/Calendar/ReminderInput.swift` (new) | model | transform | `Islet/Calendar/CalendarGlance.swift`'s `EventInput` struct (L15-22) | exact |
| `Islet/Location/LocationProvider.swift`-style Reminders permission (folded into `CalendarService.swift`, NOT a new file) | service | event-driven (lazy permission) | `Islet/Location/LocationProvider.swift` `requestOnce` (L25-39) | exact |
| `Islet/Notch/IslandPresentationState.swift` (extend enum) | store | event-driven (state carrier) | itself — no change needed beyond adding a case to the enum it carries | exact (self-analog) |
| `Islet/Notch/IslandResolver.swift` (extend `resolve(...)`) | utility (pure reducer) | transform | itself — `resolve(...)` (L35-60) is the pattern for adding the `selectedView` input/branch | exact (self-analog) |
| `Islet/Notch/NotchInteractionState.swift` or new sibling model (extend/new) | store | event-driven | `Islet/Shelf/ShelfViewState.swift` (whole file) — "one small `@Published` model per feature" precedent | exact |
| `Islet/Notch/NotchPillView.swift` (extend: switcher pill, `.calendarExpanded` view, quick-add) | component | request-response (render + user action) | itself — `blobShape`/`navCircleButton`/`chipButton`/`calendarColumn`/`shelfRow` (L577-693, L924-945) are the exact reusable primitives | exact (self-analog) |
| `Islet/Notch/NotchWindowController.swift` (extend: wiring, force-reveal) | controller | event-driven | itself — `currentPresentation()`/`visibleContentZone()`/`syncClickThrough()` (L627-641, L936-950, L1003-1017) are the 3 call sites to route through one new source of truth | exact (self-analog) |
| `project.yml` (add 2 keys) | config | — | existing `INFOPLIST_KEY_NSCalendarsUsageDescription`/`...FullAccessUsageDescription` (L64-65) | exact |
| `IsletTests/CalendarGlanceTests.swift` (extend) | test | — | itself — existing test shape (whole file, 83 lines) | exact |
| `IsletTests/IslandResolverTests.swift` (extend) | test | — | itself — existing test shape (L1-60 shown) | exact |
| `IsletTests/ReminderInputTests.swift` or fold into `CalendarGlanceTests.swift` (new/extend) | test | — | `IsletTests/LocationServiceTests.swift` (whole file, 42 lines) — fake-conformer pattern for permission-gated services | exact |

## Pattern Assignments

### `Islet/Calendar/CalendarService.swift` (service, CRUD — extend, do not replace)

**Analog:** itself (existing `fetchUpcoming`)

**Imports pattern** (lines 1-2):
```swift
import EventKit
import AppKit
```
Reminders needs no new import — `EKReminder`/`EKReminderStore` live in the same `EventKit` module already imported.

**Protocol-isolation + main-thread-completion contract** (lines 15-20):
```swift
protocol CalendarService: AnyObject {
    /// Fetch the next relevant calendar event.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `nil` on Calendar access denial (D-03) — never retries, never re-prompts.
    func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void)
}
```
Add `fetchMonth(containing:completion:)`, `createEvent(...)`, `createReminder(title:dueDate:completion:)` to this SAME protocol (CALVIEW-04) — never a parallel `ReminderService`.

**Core fetch pattern with EventKit predicate + T-14-06 untrusted-title handling** (lines 22-54):
```swift
final class EventKitService: CalendarService {
    private let store = EKEventStore()

    func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void) {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else {
                await MainActor.run { completion(nil) }
                return
            }
            let calendars = store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: Date(),
                                                      end: Date().addingTimeInterval(2 * 24 * 3600),
                                                      calendars: calendars)
            let events = store.events(matching: predicate)
            let mapped = events.map { ek -> EventInput in
                var red = 1.0, green = 1.0, blue = 1.0
                if let rgb = ek.calendar.color.usingColorSpace(.deviceRGB) {
                    red = Double(rgb.redComponent)
                    green = Double(rgb.greenComponent)
                    blue = Double(rgb.blueComponent)
                }
                // T-14-06: ek.title is UNTRUSTED — passed through as a plain String only.
                return EventInput(title: ek.title ?? "", start: ek.startDate, end: ek.endDate,
                                  colorRed: red, colorGreen: green, colorBlue: blue)
            }
            let glance = nextRelevantEvent(events: mapped, now: Date())
            await MainActor.run { completion(glance) }
        }
    }
}
```
`fetchMonth` copies this shape widened to `calendar.dateInterval(of: .month, for: date)` instead of the 2-day window (see RESEARCH.md Code Examples for the full widened version — already vetted against this exact file).

**Reminders lazy permission pattern to graft in** — copy `LocationProvider.requestOnce`'s "settle once, no retry" discipline but call `store.requestFullAccessToReminders()` (async, not delegate-based) since `EKEventStore` already has this async API (unlike `CLLocationManager`'s delegate-callback shape). No new store instance — reuse `self.store` (same `EKEventStore` instance handles both Calendar and Reminders; RESEARCH.md's own anti-pattern warns against a second store).

---

### `Islet/Calendar/CalendarGlance.swift` (business logic / pure seam, transform — extend)

**Analog:** itself

**Foundation-only, no-Date()-inline discipline header** (lines 1-11):
```swift
import Foundation

// `now` is ALWAYS an explicit parameter -- never Date()/Date.now inside this function --
// mirroring DeviceActivity.swift's "caller passes now" discipline so tests stay deterministic.
```

**Plain-struct untrusted-title convention** (lines 15-22):
```swift
struct EventInput: Equatable {
    let title: String
    let start: Date
    let end: Date
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
}
```

**Core pure day-selection pattern to extend** (lines 37-58) — the new month/day-bucketing functions (`daysInMonth(for:)`, `events(on:events:)`, prev/next month math) must follow this exact shape: total function (never crashes on empty input, T-14-02), `Calendar.current`, explicit `now:`/reference-date parameter:
```swift
func nextRelevantEvent(events: [EventInput], now: Date) -> CalendarGlance? {
    let calendar = Calendar.current
    if let todayEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: now) && $0.end > now })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: todayEvent.title, startDate: todayEvent.start, isToday: true,
                               colorRed: todayEvent.colorRed, colorGreen: todayEvent.colorGreen, colorBlue: todayEvent.colorBlue)
    }
    // ... tomorrow fallback, then nil
}
```
RESEARCH.md's own example (`events(on day:events:calendar:)`, lines 157-162 of 28-RESEARCH.md) is already written in this exact style — copy verbatim as the day-filter function; add a sibling `daysInMonth(for:calendar:)` returning `[Date?]` (nil-padded leading cells) using `Calendar.range(of:in:for:)` + `Calendar.date(byAdding:to:)`, still Foundation-only.

---

### `Islet/Calendar/ReminderInput.swift` (new model, transform)

**Analog:** `EventInput` struct in `CalendarGlance.swift` (lines 15-22, shown above)

Copy the EXACT shape: plain `String` title (T-14-06 — `EKReminder.title` is the same untrusted-external-text risk class as `EKEvent.title`), no methods, `Equatable`. Add only the fields Reminders need beyond Event (e.g. `dueDate: Date?`) — do not duplicate color fields unless reminders carry a calendar-color too.

---

### `Islet/Notch/IslandPresentationState.swift` (store — trivial extension)

**Analog:** itself, no structural change

```swift
final class IslandPresentationState: ObservableObject {
    @Published var presentation: IslandPresentation
    init(_ presentation: IslandPresentation = .idle) {
        self.presentation = presentation
    }
}
```
No change needed here beyond `IslandResolver.swift`'s `IslandPresentation` enum (below) gaining a `.calendarExpanded` case — this carrier is generic over the enum already.

---

### `Islet/Notch/IslandResolver.swift` (pure reducer, transform — extend `resolve(...)`)

**Analog:** itself

**Enum to extend** (lines 17-25):
```swift
enum IslandPresentation: Equatable {
    case onboarding(OnboardingStep)
    case idle
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case nowPlayingWings(NowPlayingPresentation)
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool)
    case expandedIdle
    // NEW: case calendarExpanded
}
```

**Reducer signature + body to extend** (lines 35-60):
```swift
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool,
             onboardingStep: OnboardingStep? = nil) -> IslandPresentation {
    if let step = onboardingStep { return .onboarding(step) }
    switch activeTransient {
    case .charging(let a): return .charging(a)
    case .device(let d):   return .device(d)
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) }
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }
    return .idle
}
```
Add a new defaulted `selectedView: SelectedView = .home` parameter (source-compat, mirrors how `onboardingStep` was added as a defaulted trailing parameter in a prior phase) and one new `if selectedView == .calendar { return .calendarExpanded }` line inside the `isExpanded` branch, placed AFTER the now-playing checks (media still outranks the calendar view — same rank precedent as `.expandedIdle`). RESEARCH.md's own Pattern 3 code example (lines 168-199 of 28-RESEARCH.md) is this exact diff, already vetted — copy it directly. Tray is NOT a new `IslandPresentation` case (RESEARCH.md's explicit recommendation) — it stays `.expandedIdle` and the shelf-force-reveal is a `NotchPillView`/`NotchWindowController` concern only (see below).

**Anti-pattern to flag in the plan:** never add a second `if selectedView == .calendar` check inside `NotchPillView`'s body alongside the `switch presentation` — the view must stay a pure switch (established since Phase 6 / COORD-01 / D-05).

---

### `Islet/Notch/NotchInteractionState.swift` vs. new sibling model (store, event-driven)

**Analog:** `Islet/Shelf/ShelfViewState.swift` (whole file, 19 lines) — the "one small `@Published` model per feature" precedent:
```swift
final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []
}
```
Recommendation (per RESEARCH.md Open Question 1, and matching this precedent over growing `NotchInteractionState`, which today only holds `phase`/`collapsedNotchSize`): create a new small `ViewSwitcherState: ObservableObject` with `@Published var selectedView: SelectedView = .home`, owned/mutated by `NotchWindowController` exactly like `shelfViewState` is today (see `NotchWindowController.swift` line 91: `private let shelfViewState = ShelfViewState()`).

---

### `Islet/Notch/NotchPillView.swift` (component, request-response — extend)

**Analog:** itself — reuse these exact existing private helpers, do not reimplement:

**Switch-over-presentation render pattern** (lines 241-261):
```swift
switch presentation {
case .onboarding(let step):
    onboardingCarousel(step)
case .charging(let a):
    wings(for: a)
case .device(let d):
    deviceWings(for: d)
case .nowPlayingWings(let p):
    mediaWingsOrToast(p)
case .nowPlayingExpanded(let p, true):
    mediaExpanded(p, art: nowPlaying.artwork)
case .nowPlayingExpanded(_, false):
    mediaUnavailable
case .expandedIdle:
    expandedIsland
case .idle:
    collapsedIsland
}
```
Add `case .calendarExpanded: calendarFullView` as one more pure switch arm — no re-deciding precedence.

**`blobShape` — the shared shell every expanded case reuses** (lines 637-666): the new `calendarFullView` must call `blobShape(topCornerRadius: 6, bottomCornerRadius: 32, shelfItems: shelfViewState.items) { ... }` exactly like `expandedIsland` (lines 322-337) — same 360pt width, same shelf-growth mechanism, no second shape:
```swift
private var expandedIsland: some View {
    blobShape(topCornerRadius: 6, bottomCornerRadius: 32, shelfItems: shelfViewState.items) {
        HStack(spacing: 0) {
            if let weather = outfit.weather { weatherColumn(weather) }
            Spacer()
            centerColumn
            Spacer()
            if let calendarGlance = outfit.calendar { calendarColumn(calendarGlance) }
        }
        .padding(.horizontal, 16)
    }
}
```

**`navCircleButton` — reuse verbatim for the 3 switcher icons** (lines 577-587):
```swift
private func navCircleButton(systemName: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.black : Color.white)
            .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
            .background(Circle().fill(filled ? Color.white : Color.clear))
            .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
    }
    .buttonStyle(.plain)
}
```
UI-SPEC.md confirms: active icon = `navCircleButton(filled: true)`, inactive = `navCircleButton(filled: false)`.

**`chipButton` — reuse verbatim for quick-add "+ Add"/"Add Event"/"Add Reminder" controls** (lines 594-607):
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

**`calendarColumn` — the exact event-row rendering pattern (color dot + truncated title + time) to reuse for the day-list rows** (lines 924-945):
```swift
private func calendarColumn(_ glance: CalendarGlance) -> some View {
    VStack(alignment: .trailing, spacing: 2) {
        Text(glance.isToday ? "Today" : "Tomorrow")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        HStack(spacing: 4) {
            Text(glance.title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Circle()
                .fill(Color(red: glance.colorRed, green: glance.colorGreen, blue: glance.colorBlue))
                .frame(width: 6, height: 6)
        }
        Text(glance.startDate, format: .dateTime.hour().minute())
            .font(.system(size: 10, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
```
The `.lineLimit(1)`/`.truncationMode(.tail)` on `Text(glance.title)` is MANDATORY (V5 — T-14-06 mitigation) — apply identically to the new day-list rows AND to any `ReminderInput`-title rendering.

**Outer frame height branch to extend** (lines 276-280) — the new `.calendarExpanded` case needs the SAME shelf-aware height math as `expandedIsland`, so no new branch is needed here IF `calendarFullView` also routes through `blobShape`'s existing `shelfItems:` parameter (confirm during planning that `isOnboardingPresentation`-style special-casing is NOT needed for calendar, since it reuses `expandedSize` unlike onboarding's wider/taller `onboardingSize`).

**Segmented Event/Reminder picker — reuse the exact existing convention from `Islet/SettingsView.swift`** (lines 238-242):
```swift
Picker("Style", selection: $materialStyle) {
    Text("Gradient").tag(MaterialStyle.gradient)
    Text("Solid Black").tag(MaterialStyle.solidBlack)
}
.pickerStyle(.segmented)
```
Copy this exact shape for the quick-add Event/Reminder toggle (`Picker("Type", selection: $quickAddKind) { Text("Event").tag(...); Text("Reminder").tag(...) }.pickerStyle(.segmented)`).

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven — extend)

**Analog:** itself — the 3 call sites RESEARCH.md's Pitfall 3 identifies must all read ONE new source of truth.

**`currentPresentation()` — add the `selectedView` input here** (lines 627-641):
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
                   onboardingStep: onboardingStep)
    // ADD: selectedView: viewSwitcherState.selectedView
}
```

**`visibleContentZone()` — the click-through hit-test that must ALSO account for Tray force-reveal** (lines 936-950):
```swift
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight
    let contentSize: CGSize = isOnboardingActive
        ? NotchPillView.onboardingSize
        : CGSize(width: expandedSize.width, height: expandedSize.height + shelfHeight)
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: contentSize)
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```
Per Pitfall 3, `shelfHeight` here, `blobShape`'s `hasShelf` in `NotchPillView.swift` (line 644: `let hasShelf = !shelfItems.isEmpty`), and `.frame(...)` in `NotchPillView.body` (line 279: `shelfViewState.items.isEmpty ? 0 : Self.shelfRowHeight`) are the 3 sites — introduce ONE computed property (e.g. `ShelfViewState.isVisible: Bool { !items.isEmpty || forcedByTray }`, RESEARCH.md's own recommended shape) and route all 3 through it. **Never OR a bool inline at only one or two of the three sites** — this is the exact regression class the project's own `cr01-clickthrough-or-defeat-gotcha` memory documents.

**`syncClickThrough()` — must NOT be touched beyond reading the same new source of truth** (lines 1003-1017):
```swift
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```
The comment at lines 1006-1011 explicitly warns: `pointerInZone` (the broad keep-open zone) must NEVER be OR'd into `interactive` here — only `visibleContentZone()`'s narrowed rect may grant interactivity while expanded. Same discipline applies to any Tray-force-reveal change.

---

### `project.yml` (config)

**Analog:** existing Calendar keys (lines 62-65):
```yaml
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "Islet zeigt eine kurze Mitteilung in der Notch, wenn ein Bluetooth-Gerät wie deine AirPods verbunden oder getrennt wird."
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Islet zeigt das aktuelle Wetter in der Notch an, sobald du deinen Standort einmalig freigibst."
INFOPLIST_KEY_NSCalendarsUsageDescription: "Islet zeigt dein naechstes anstehendes Kalenderereignis in der Notch an."
INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription: "Islet zeigt dein naechstes anstehendes Kalenderereignis in der Notch an."
```
Add BOTH `INFOPLIST_KEY_NSRemindersUsageDescription` and `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription` (D-05 — Pitfall 2 warns adding only one silently breaks first-touch), same string style/language as the existing 4 keys, same indentation level.

---

### Tests

**`IsletTests/CalendarGlanceTests.swift`** (extend, 83 lines) — analog is itself:
```swift
final class CalendarGlanceTests: XCTestCase {
    func testInProgressEventTodayIsReturned() {
        let now = Date()
        let event = EventInput(title: "Standup", start: now.addingTimeInterval(-10 * 60),
                                end: now.addingTimeInterval(20 * 60), colorRed: 1, colorGreen: 0, colorBlue: 0)
        let result = nextRelevantEvent(events: [event], now: now)
        XCTAssertEqual(result, CalendarGlance(title: "Standup", startDate: event.start, isToday: true,
                                               colorRed: 1, colorGreen: 0, colorBlue: 0))
    }
    // ... T-14-02 empty-array-never-crashes test at the end
}
```
Extend with tests for the new `daysInMonth(for:)`/`events(on:events:)` functions, same "Given/nextRelevantEvent returns/XCTAssertEqual" comment-then-assert shape, plus an explicit empty-array-never-crashes case (CALVIEW-02/T-14-02 precedent).

**`IsletTests/IslandResolverTests.swift`** (extend, 378 lines total) — analog is itself:
```swift
func testChargingOutranksDeviceAndMedia() {
    let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true, hasPlayedSinceLaunch: true, isExpanded: true)
    XCTAssertEqual(r, .charging(.charging(percent: 47)))
}
```
Add `testCalendarExpandedShownWhenSelectedViewIsCalendarAndExpanded()`, `testCalendarOutrankedByNowPlayingExpanded()`, `testCalendarNotShownWhenNotExpanded()` following this exact Given/When/Then comment + `XCTAssertEqual` shape, passing the new `selectedView:` parameter explicitly.

**Reminders permission test** — analog is `IsletTests/LocationServiceTests.swift` (whole file, 42 lines), the fake-conformer pattern for any lazy-permission service:
```swift
private final class FakeLocationService: LocationService {
    private(set) var requestOnceCallCount = 0
    private(set) var lastCompletion: ((CLLocation?) -> Void)?
    func requestOnce(completion: @escaping (CLLocation?) -> Void) {
        requestOnceCallCount += 1
        lastCompletion = completion
    }
}
```
If a pure `ReminderInput`-mapping function is extracted (mirroring `EventInput`'s mapping), test it the same way `CalendarGlanceTests` tests `EventInput`/`nextRelevantEvent` — no live `EKReminderStore` in unit tests (RESEARCH.md Validation Architecture: real store save/permission dialog is manual UAT only, matches `EventKitService`'s existing untested-by-XCTest live-store shape).

## Shared Patterns

### Protocol-isolation for fragile externals
**Source:** `Islet/Calendar/CalendarService.swift` (whole file) / `Islet/Location/LocationProvider.swift` (whole file)
**Apply to:** `CalendarService.swift`'s new Reminders methods — same protocol, same conformer, never a second service/store.

### Pure seam discipline (Foundation-only, explicit `now`/reference-date, total function)
**Source:** `Islet/Calendar/CalendarGlance.swift` lines 1-11, 37-58
**Apply to:** All new month/day-bucketing functions in `CalendarGlance.swift`.

### Single-arbiter presentation state
**Source:** `Islet/Notch/IslandResolver.swift` lines 35-60; enforced render-side at `Islet/Notch/NotchPillView.swift` lines 241-261
**Apply to:** `.calendarExpanded` case addition — the view's `switch` must stay pure, no parallel `if selectedView ==` checks in the view body.

### Untrusted external text handling (T-14-06)
**Source:** `Islet/Calendar/CalendarService.swift` lines 11-14, 47-49; rendered at `Islet/Notch/NotchPillView.swift` lines 930-934 (`.lineLimit(1)`/`.truncationMode(.tail)`)
**Apply to:** `ReminderInput.title`, and any new day-list/quick-add view rendering event or reminder titles.

### Lazy, silent-degrade, first-use permission request
**Source:** `Islet/Location/LocationProvider.swift` lines 25-39
**Apply to:** The Reminders permission call inside `CalendarService.swift`'s new `createReminder(...)` method — settle `completion(false)` on denial, never retry/nag, never called at launch/onboarding (D-04).

### One small `@Published` model per feature (not growing a shared state object)
**Source:** `Islet/Shelf/ShelfViewState.swift` (whole file)
**Apply to:** The new switcher-selection state (`ViewSwitcherState` or similar), owned/mutated only by `NotchWindowController`, mirroring `shelfViewState`'s ownership (`NotchWindowController.swift` line 91).

### Reusable chrome primitives (do not reimplement)
**Source:** `Islet/Notch/NotchPillView.swift` — `blobShape` (L637-666), `navCircleButton` (L577-587), `chipButton` (L594-607), `calendarColumn`-style event row (L924-945), `shelfRow` (L672-693)
**Apply to:** Switcher pill icons, quick-add controls, month-grid/day-list content box, all inside `NotchPillView.swift`.

### Segmented Picker convention
**Source:** `Islet/SettingsView.swift` lines 238-242
**Apply to:** Quick-add Event/Reminder toggle.

### The 3-call-site click-through hazard (CR-01 precedent)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 936-950 (`visibleContentZone`), 1003-1017 (`syncClickThrough`); `Islet/Notch/NotchPillView.swift` lines 279, 644
**Apply to:** ANY Tray-force-reveal or calendar-view-visibility change that touches shelf/shape height — route through one new shared boolean/computed property, never patch one site with an inline OR.

## No Analog Found

None — every new file/change has a same-shaped precedent already in this codebase (confirmed by both RESEARCH.md's own "Key insight" and this pattern map's file-by-file mapping above).

## Metadata

**Analog search scope:** `Islet/Calendar/`, `Islet/Notch/`, `Islet/Location/`, `Islet/Shelf/`, `Islet/SettingsView.swift`, `IsletTests/`, `project.yml`
**Files scanned:** `CalendarService.swift`, `CalendarGlance.swift`, `LocationProvider.swift`, `IslandPresentationState.swift`, `IslandResolver.swift`, `NotchInteractionState.swift`, `ShelfViewState.swift`, `NotchPillView.swift` (targeted sections), `NotchWindowController.swift` (targeted sections), `SettingsView.swift` (targeted section), `CalendarGlanceTests.swift`, `LocationServiceTests.swift`, `IslandResolverTests.swift` (targeted section), `project.yml` (targeted section)
**Pattern extraction date:** 2026-07-13
