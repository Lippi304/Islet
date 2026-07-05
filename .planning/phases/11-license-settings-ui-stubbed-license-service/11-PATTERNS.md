# Phase 11: License Settings UI (Stubbed License Service) - Pattern Map

**Mapped:** 2026-07-05
**Files analyzed:** 4 (2 new, 2 modified) + 2 verify-only
**Analogs found:** 4 / 4 (every new/modified file has a direct in-repo analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Islet/Licensing/LicenseService.swift` (NEW) | service (protocol + stub conformer) | request-response (async validate → Result completion) | `Islet/Notch/NowPlayingMonitor.swift` (`NowPlayingService` protocol, lines 40-47) | exact (role + protocol-isolation intent) |
| `IsletTests/LicenseServiceTests.swift` (NEW) | test | request-response (async completion assertion) | `IsletTests/PowerActivityTests.swift` (pure verdict matrix) + `IsletTests/TrialManagerTests.swift` (fake-injection style) | exact (role); async-completion style is new (needs `XCTestExpectation`) |
| `Islet/Licensing/LicenseState.swift` (MODIFY) | model / domain state | transform (status computation) | itself — extend in place (add `sessionActivated` + `.licensed` short-circuit) | exact (self) |
| `Islet/SettingsView.swift` (MODIFY) | component (SwiftUI view) | event-driven (user tap → state machine) | itself — the existing `Form`/`Section`/`.appearsActive` idiom | exact (self) |
| `Islet/AppDelegate.swift` (VERIFY-ONLY) | app glue | event-driven (didChangeNotification observer) | n/a — existing `licenseObserver` path is reused unchanged | verify only |
| `Islet/Notch/NotchWindowController.swift` (VERIFY-ONLY) | controller / arbiter | event-driven (defaultsObserver → updateVisibility) | n/a — existing live-unlock path reused unchanged | verify only |

---

## Pattern Assignments

### `Islet/Licensing/LicenseService.swift` (NEW — service, request-response)

**Analog:** `Islet/Notch/NowPlayingMonitor.swift` (the `NowPlayingService` protocol-isolation precedent)

**Copy the protocol-isolation shape** — analog `NowPlayingMonitor.swift:35-47`. The header comment establishes the exact convention this new file must mirror (fragile external quarantined behind one protocol, one concrete conformer, caller holds the protocol type):

```swift
// NowPlayingMonitor.swift:40-47 — the ONE seam Phase 12 swaps into.
protocol NowPlayingService: AnyObject {
    func start()
    nonisolated func stop()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void)
}
```

Key conventions to replicate from this analog:
- **`protocol X: AnyObject`** (class-bound), one `final class` conformer named `StubLicenseService` (analog: `final class NowPlayingMonitor: NowPlayingService`).
- **Closure-based completion, not async/await** — analog uses `runHealthCheck(then: @escaping (Bool) -> Void)` and injected `@escaping` closures throughout (`onSnapshot`, `onTerminated`). Phase 11's `activate(key:completion:)` returns `Result<Void, LicenseActivationError>` the same closure way. (RESEARCH A1; project is Swift 5 language mode per CLAUDE.md.)
- **`DispatchQueue.main.asyncAfter` one-shot for the simulated delay** — analog `NowPlayingMonitor.swift:107-111` uses exactly this idiom for its 3.0s health-check timeout:
  ```swift
  DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      if settled { return }
      settled = true
      setHealthy(false)
  }
  ```
  Phase 11 stub reuses this with `.now() + 1.0` (D-06 ~1s round-trip). This also guarantees the **completion fires on main** (documented protocol contract, RESEARCH Pitfall 2).
- **Header-comment style** — analog opens with a long block comment citing the CLAUDE.md mandate and naming the swap seam. The new file's header must document: the main-thread completion contract, the D-05 magic key as a DEBUG scaffold, and "Phase 12 deletes this file" (RESEARCH Pitfall 3).

**Target shape** (from RESEARCH Pattern 1, lines 163-188 — reproduced here as the contract the planner implements):
```swift
enum LicenseActivationError: Error, Equatable {
    case invalidKey
    case unreachable(String)   // stub never emits; exists so Phase 12 needs zero protocol change
}

protocol LicenseService: AnyObject {
    /// Completion is ALWAYS delivered on the MAIN thread (contract).
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void)
}

final class StubLicenseService: LicenseService {
    static let validKey = "ISLET-DEMO-OK"
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(trimmed == Self.validKey ? .success(()) : .failure(.invalidKey))
        }
    }
}
```

**Keep the stub pure** — no `LicenseState.shared` mutation inside `activate(...)`. Mirrors the analog's monitor→controller split: `NowPlayingMonitor` *emits* via `onSnapshot`, `NotchWindowController` *mutates* state. Here `StubLicenseService` returns a verdict; the `SettingsView` completion closure does the flip (see next section).

---

### `Islet/SettingsView.swift` (MODIFY — component, event-driven)

**Analog:** itself (extend the existing `Form`). All conventions already present in the file.

**Imports pattern** (line 1): `import SwiftUI`. Add `import AppKit` only if `NSWorkspace` is not already resolved via SwiftUI (verify; SwiftUI re-exports AppKit on macOS, so likely no new import).

**State + refocus re-read pattern** (existing, `SettingsView.swift:4-5` and `:86-89`) — copy this verbatim for the new `@State licenseStatus`:
```swift
@Environment(\.appearsActive) private var appearsActive   // refocus → re-sync
// ...
.onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
.onChange(of: appearsActive) { _, active in
    if active { launchAtLogin = LaunchAtLogin.isEnabled }
}
```
New view adds a sibling `@State private var licenseStatus = LicenseState.shared.status`, re-read the same two ways: `.onAppear { licenseStatus = LicenseState.shared.status }` and inside the existing `onChange(of: appearsActive)` block (RESEARCH Pitfall 4). Also add `@State private var enteredKey = ""` and `@State private var activationPhase: ActivationPhase = .idle` plus `private let licenseService: LicenseService = StubLicenseService()`.

**Section / LabeledContent layout pattern** (existing, `SettingsView.swift:53-79`) — the new License `Section` slots in at the **top of the `Form`** (D-02), following this exact idiom:
```swift
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    // ...
    LabeledContent("Accent") { HStack(spacing: 10) { /* ... */ } }
}
```

**REMOVE the existing end-date notice block** (`SettingsView.swift:23-28`) — RESEARCH "State of the Art" is explicit: the countdown *replaces* it, do not leave both:
```swift
// DELETE this — replaced by the adaptive License section's .trial countdown:
if let start = TrialManager.shared.trialStartDate() {
    let expiry = start.addingTimeInterval(TrialManager.trialLength)
    Text("Your 3-day trial started — ends \(expiry.formatted(date: .abbreviated, time: .omitted)).")
        .font(.footnote)
        .foregroundStyle(.secondary)
}
```

**Frame/padding conventions** (existing, `SettingsView.swift:90-91`): `.padding(20)` + `.frame(width: 360)` — the new section inherits this; the license `TextField` should `.frame(maxWidth: .infinity)` (UI-SPEC Spacing).

**Activate action = "service emits, caller mutates" pattern** (RESEARCH Pattern 2) — the completion closure does the `LicenseState` flip and fires the existing unlock trigger:
```swift
activationPhase = .validating
licenseService.activate(key: enteredKey) { result in   // completes on main (contract)
    switch result {
    case .success:
        LicenseState.shared.sessionActivated = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "license.activationNudge")
        licenseStatus = .licensed
        activationPhase = .success
    case .failure:
        activationPhase = .failure
    }
}
```

**Buy Now handoff** (UI-SPEC + RESEARCH lines 322-330): `NSWorkspace.shared.open(URL(string: "https://getislet.app")!)` — the documented LSUIElement default-browser pattern (do not shell out).

**Copy/typography contract** comes from `11-UI-SPEC.md` (locked): `.headline` for the expired heading, `.foregroundStyle(.secondary)` for the countdown, `.green`/`.red` for terminal status, `⟳`/`✓`/`✗` glyphs, exact strings in the Copywriting Contract table.

---

### `Islet/Licensing/LicenseState.swift` (MODIFY — model, transform)

**Analog:** itself. Two surgical additions; preserve the existing DEBUG-override discipline.

**Existing structure to extend** (`LicenseState.swift:19-56`) — singleton with `private init()`, computed `status` whose DEBUG override block must stay **first**:
```swift
final class LicenseState {
    static let shared = LicenseState()
    private init() {}
    // #if DEBUG override block (forceExpired / forceLicensed) — KEEP FIRST
    var status: LicenseStatus {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: Self.debugOverrideKey), ... { ... }
        #endif
        guard let start = TrialManager.shared.trialStartDate() else { return .trial(daysRemaining: 3) }
        switch trialStatus(...) { case .active(let d): return .trial(daysRemaining: d); case .expired: return .trialExpired }
    }
}
```

**Additions** (RESEARCH lines 217-234):
1. `var sessionActivated = false` — in-memory only, NOT persisted (honors "session only" + dodges flippable-bool Pitfall 1/3).
2. In `status`, after the `#if DEBUG` block and before the trial computation, add the short-circuit: `if sessionActivated { return .licensed }`.
3. `isEntitled` (`LicenseState.swift:58-63`) is **unchanged** — `.licensed → true` already holds.

**Testability note** (RESEARCH line 409): `private init()` blocks constructing a fresh `LicenseState` in a unit test. If the planner wants to unit-test the `.licensed` short-circuit, relax `init()` to internal (or add a `#if DEBUG` reset). Default recommendation: verify the state flip on-device (mirrors Phase 10's manual precedent), keep the unit test scoped to the pure stub.

---

### `IsletTests/LicenseServiceTests.swift` (NEW — test, async request-response)

**Analogs:** `IsletTests/PowerActivityTests.swift` (verdict-matrix structure) + `IsletTests/TrialManagerTests.swift` (async is the delta).

**Copy the test-file skeleton** (`PowerActivityTests.swift:1-13`):
```swift
import XCTest
@testable import Islet

// <header: what pure seam is under test, why it's unit-tested vs on-device>
final class PowerActivityTests: XCTestCase {
    func testChargingMapsToCharging() {
        let r = PowerReading(...)
        XCTAssertEqual(powerActivity(from: r), .charging(percent: 47))
    }
}
```
Replicate: `import XCTest` + `@testable import Islet`, `final class ... : XCTestCase`, a header comment explaining the seam, one focused `func testX()` per case, `// MARK:` section dividers.

**NEW vs the analogs — async completion needs `XCTestExpectation`.** Neither existing test is async (both assert synchronous pure functions). The stub completes after ~1s via `asyncAfter`, so each test must wait. Structure (RESEARCH Validation, D-05/D-06):
```swift
func testValidMagicKeySucceedsOnMainThread() {
    let exp = expectation(description: "activate completes")
    StubLicenseService().activate(key: "ISLET-DEMO-OK") { result in
        XCTAssertTrue(Thread.isMainThread)            // D-06 main-thread contract
        if case .success = result {} else { XCTFail("expected .success") }
        exp.fulfill()
    }
    wait(for: [exp], timeout: 3.0)                     // > 1s stub delay
}

func testUnknownNonEmptyKeyFailsWithInvalidKey() { /* expect .failure(.invalidKey) */ }
func testWhitespaceIsTrimmedBeforeCompare()      { /* "  ISLET-DEMO-OK \n" → .success */ }
```

**Cases to cover** (RESEARCH Test Map, lines 394-395): magic key → `.success`; any other non-empty key → `.failure(.invalidKey)`; whitespace trimming; completion on `Thread.isMainThread`; completion is asynchronous (not synchronous). Empty-input inertness is a view-layer concern (Activate disabled), not the stub's — do not assert it here unless the stub is given that responsibility.

**Fake-injection style** (from `TrialManagerTests.swift:12-32`) is NOT needed for the pure stub (it has no dependencies). Borrow it only if the planner adds a `LicenseState` reset seam.

---

## Shared Patterns

### Protocol-isolation for fragile externals
**Source:** `Islet/Notch/NowPlayingMonitor.swift:35-47`
**Apply to:** `LicenseService.swift`
The canonical convention: `protocol X: AnyObject` + one `final class` conformer, caller stores the protocol type. Header comment names the swap seam and the CLAUDE.md mandate. Phase 12's `PolarLicenseService` is a one-file drop-in.

### Closure-based completion + `DispatchQueue.main.asyncAfter` one-shot
**Source:** `Islet/Notch/NowPlayingMonitor.swift:100-112` (health-check timeout) and used ~5× in `NotchWindowController`
**Apply to:** `StubLicenseService.activate` (1.0s), the `SettingsView` activate flow
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { completion(...) }
```
No `Timer`, no recurring source (idle-CPU discipline). Guarantees main-thread completion.

### Service emits, caller mutates state
**Source:** `NowPlayingMonitor` (emits via `onSnapshot`) → `NotchWindowController` (mutates `@Published`)
**Apply to:** `StubLicenseService` (returns `Result`) → `SettingsView` completion closure (flips `LicenseState.sessionActivated`, fires trigger). Keeps the stub pure and unit-testable.

### Live-unlock via `UserDefaults.didChangeNotification` (REUSE — no new code)
**Source (verified, do NOT modify):**
- `AppDelegate.swift:57-61` — `licenseObserver` re-runs `applyMenuBarClickRouting(isLicensed: LicenseState.shared.isEntitled)` on every defaults change.
- `NotchWindowController.swift:322-325` — `defaultsObserver` → `handleSettingsChanged()` → (line 955) `updateVisibility()`, the single show/hide arbiter that re-reads `licenseState.isEntitled`.
**Apply to:** the `SettingsView` success branch writes any `UserDefaults` key to fire this path. This is the identical mechanism Phase 10's DEBUG `forceLicensed` uses (`AppDelegate.swift:177`). **Anti-pattern (RESEARCH):** do NOT add a second show/hide call site — trigger the notification and let `updateVisibility()` decide. The written nudge key is a trigger only, never read as entitlement truth.

### SwiftUI `@State` re-read on refocus (non-observable model)
**Source:** `SettingsView.swift:4-5, 86-89` (the `launchAtLogin` / `.appearsActive` pattern)
**Apply to:** `licenseStatus` re-read on `.onAppear` + `.onChange(of: appearsActive)`. Matches the existing non-`ObservableObject` convention; do NOT convert `LicenseState` to `@Published` this phase (RESEARCH A2, Pitfall 4).

### DEBUG-gated test seams
**Source:** `LicenseState.swift:24-42` (both the constants AND the read-site are `#if DEBUG`)
**Apply to:** optional `#if DEBUG` gate on the magic-key compare (belt-and-suspenders, RESEARCH Pitfall 3). Any developer affordance stays compiled out of Release.

### XCTest structure
**Source:** `IsletTests/PowerActivityTests.swift:1-13` (skeleton), `TrialManagerTests.swift:12-32` (fake injection, if needed)
**Apply to:** `LicenseServiceTests.swift` — plus `XCTestExpectation` + `wait(for:timeout:)` for the async completion (the one thing neither analog demonstrates).

---

## No Analog Found

None. Every new/modified file maps to a direct in-repo analog. The only genuinely new *technique* (not a new file role) is asynchronous XCTest with `XCTestExpectation` — the two existing test files assert synchronous pure functions, so the async-wait harness is the single pattern the planner introduces (standard XCTest, shown above).

---

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Licensing/`, `Islet/`, `IsletTests/`
**Files scanned (read):** `NowPlayingMonitor.swift`, `LicenseState.swift`, `SettingsView.swift`, `PowerActivityTests.swift`, `TrialManagerTests.swift`, `NotchWindowController.swift` (targeted: unlock path + defaultsObserver), `AppDelegate.swift` (targeted: license wiring)
**Pattern extraction date:** 2026-07-05
