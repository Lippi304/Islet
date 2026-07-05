# Phase 12: Real Polar.sh License Integration - Pattern Map

**Mapped:** 2026-07-05
**Files analyzed:** 6 (2 new src, 1 edit src, 1 edit call-site, 1 new test, 1 build regen)
**Analogs found:** 6 / 6 (every file has an in-repo analog — this is a drop-in phase, not greenfield)

All analogs live in `Islet/Licensing/` and `IsletTests/`. Every new file mirrors an existing,
proven file in the SAME directory. The planner should treat this as "copy the neighbor, change
the payload," not "invent new structure."

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Islet/Licensing/PolarLicenseService.swift` | service (network client) | request-response | `Islet/Licensing/LicenseService.swift` (`StubLicenseService`) + `Islet/Notch/NowPlayingMonitor.swift` (protocol isolation) | exact (same protocol conformer) |
| `Islet/Licensing/KeychainLicenseStore.swift` | store / persistence | file-I/O (single-item CRUD) | `Islet/Licensing/TrialManager.swift` (`KeychainStore` + `KeychainTrialStore`) | exact (same SecItem shape) |
| `Islet/Licensing/LicenseState.swift` (EDIT) | model / source-of-truth | request-response (launch read) | itself + `TrialManager` in-memory cache (`cachedStartDate`/`hasCachedStartDate`) | exact (extend existing) |
| `Islet/SettingsView.swift` (EDIT, line 20 only) | component (call site swap) | request-response | itself (activate flow lines 164–184) | exact |
| `IsletTests/PolarLicenseServiceTests.swift` | test | request-response | `IsletTests/LicenseServiceTests.swift` + `IsletTests/TrialManagerTests.swift` (`FakeKeychainStore`) | exact (same XCTest + fake-seam idiom) |
| `project.yml` regen (`xcodegen generate`) | config | build | existing folder-glob sources (`- path: Islet`, `- path: IsletTests`) | N/A — see Shared Patterns |

---

## Pattern Assignments

### `Islet/Licensing/PolarLicenseService.swift` (service, request-response) — NEW

**Analog:** `Islet/Licensing/LicenseService.swift` (`StubLicenseService`, lines 41–61) for the
protocol contract; `Islet/Notch/NowPlayingMonitor.swift` (lines 34–47) for the protocol-isolation
convention it must honor.

**read_first:** `Islet/Licensing/LicenseService.swift` (whole file, 62 lines).

**Protocol to conform to — DO NOT CHANGE IT** (`LicenseService.swift` lines 28–39):
```swift
enum LicenseActivationError: Error, Equatable {
    case invalidKey
    case unreachable(String)     // already exists for exactly this phase's transport failures
}

protocol LicenseService: AnyObject {
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void)
}
```
`PolarLicenseService` is a `final class ...: LicenseService` — a ZERO-protocol-change drop-in.
`.unreachable(String)` already exists (added in Phase 11 precisely so Phase 12 needs no protocol edit).

**Main-thread completion contract to copy** — the stub guarantees it via `asyncAfter` on main
(`LicenseService.swift` lines 45–60); the URLSession path must re-establish it explicitly because
`dataTask` callbacks land on a background queue. Mirror the RESEARCH Pattern-1 `finish()` helper:
```swift
func finish(_ r: Result<Void, LicenseActivationError>) {
    DispatchQueue.main.async { completion(r) }   // CONTRACT: SettingsView mutates @State w/o a hop
}
```

**Input-handling convention to copy** (`StubLicenseService.activate`, `LicenseService.swift` lines 50–53):
trim opaque untrusted input, never interpolate it (T-11-03):
```swift
let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
```
Then it goes into a JSON body value only (never a URL/log/shell).

**Protocol-isolation convention to honor** (`NowPlayingMonitor.swift` lines 34–47) — the fragile
external (here: the Polar network + private-endpoint quirks) is quarantined behind ONE `AnyObject`
protocol; callers hold the protocol type only, so a future Polar break is a one-file swap:
```swift
protocol NowPlayingService: AnyObject { func start(); ... }   // callers type against THIS
@MainActor final class NowPlayingMonitor: NowPlayingService {  // concrete conformer, swappable
    private nonisolated(unsafe) let controller = MediaController()
```
Apply the identical discipline: `SettingsView` already types the seam as `LicenseService`
(`SettingsView.swift` line 20), so no call-site type changes beyond the constructor.

**Testable network seam** — do NOT hard-code `URLSession.shared`. Inject an `HTTPSession`
protocol so tests supply a `FakeHTTPSession` (RESEARCH §Testable seams / Code Examples lines 405–417):
```swift
protocol HTTPSession {
    func perform(_ request: URLRequest,
                 completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}
final class PolarLicenseService: LicenseService {
    private let session: HTTPSession
    init(session: HTTPSession = URLSessionHTTP()) { self.session = session }
}
```

**Core request-response + error mapping** — copy RESEARCH.md Pattern 1 verbatim
(12-RESEARCH.md lines 261–301): POST `https://api.polar.sh/v1/customer-portal/license-keys/validate`,
15s timeout, body `{key, organization_id}` ONLY, then:
- `URLError`/transport → `.unreachable(error.localizedDescription)`
- 200 + decoded `status == "granted"` → `.success(())`
- 400/404/422 → `.invalidKey`
- default (5xx etc.) → `.unreachable("Server error \(code)")`  (NEVER `.invalidKey` — D-04)

Request/response Codable models: RESEARCH.md lines 156–163 (`ValidatedLicenseKey`) and lines
393–403 (`ValidateRequest` with `organization_id` CodingKey). Org ID constant: `952bfc3a-c29b-4024-bf2e-deded1be5908`.

---

### `Islet/Licensing/KeychainLicenseStore.swift` (store, single-item CRUD) — NEW

**Analog:** `Islet/Licensing/TrialManager.swift` (`KeychainStore` protocol lines 15–19 +
`KeychainTrialStore` struct lines 23–72). This is the EXACT SecItem shape to copy — only the
`service` string and the stored value type change.

**read_first:** `Islet/Licensing/TrialManager.swift` (lines 1–72).

**Injectable protocol seam to copy** (`TrialManager.swift` lines 15–19) — rename to `LicenseStore`,
change the payload type from `Date` to a `LicenseRecord`:
```swift
protocol KeychainStore {                     // → LicenseStore
    func read() -> Date?                      // → func read() -> LicenseRecord?
    @discardableResult func write(_ date: Date) -> Bool   // → write(_ record: LicenseRecord) -> Bool
    func delete()
}
```

**Real SecItem implementation to mirror** (`KeychainTrialStore`, `TrialManager.swift` lines 23–72).
Copy all three methods; change only the service string and encode a `Codable` record (NOT a bool —
D-07 / T-11-02):
```swift
struct KeychainTrialStore: KeychainStore {
    private let service = "com.lippi304.islet.trial"     // → "com.lippi304.islet.license"
    private let account = "trialStartDate"               // → "validatedLicense"

    func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, ... else { return nil }
        // → decode JSONDecoder().decode(LicenseRecord.self, from: data) with graceful nil-fallback
    }

    @discardableResult func write(_ date: Date) -> Bool {
        // delete-then-add upsert (lines 57–61) — copy exactly:
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = payload   // → JSONEncoder().encode(record)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock  // COPY THIS
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func delete() { SecItemDelete(query as CFDictionary) }  // lines 64–71
}
```
Keep `kSecAttrAccessibleAfterFirstUnlock` (line 60) and the delete-then-add upsert (lines 57–61)
identical — both are load-bearing.

**Record shape** (RESEARCH.md lines 315–321):
```swift
struct LicenseRecord: Codable {
    let key: String        // the validated key (proof-of-purchase, NOT a flippable bool — T-11-02)
    let licenseID: String  // Polar license-key id
    let status: String     // "granted"
    let validatedAt: Date
}
```

---

### `Islet/Licensing/LicenseState.swift` (source-of-truth, EDIT)

**Analog:** itself (the `sessionActivated` short-circuit, lines 24–29 / 51–54) plus `TrialManager`'s
in-memory cache discipline (`TrialManager.swift` lines 87–96, 106–127) — the persisted read MUST be
cached after the first hit.

**read_first:** `Islet/Licensing/LicenseState.swift` (whole file, 80 lines).

**Where the persisted state hooks in** — a NEW persisted branch sits BETWEEN the DEBUG override and
the in-memory `sessionActivated` check inside `status` (lines 40–54):
```swift
var status: LicenseStatus {
    #if DEBUG ... override ... #endif           // lines 41–49 — stays first
    // NEW: if KeychainLicenseStore has a granted LicenseRecord → return .licensed
    //      (read ONCE, cache in memory — see below)
    if sessionActivated { return .licensed }    // line 54 — stays (covers same-session activation)
    guard let start = TrialManager.shared.trialStartDate() else { ... }   // trial fallback unchanged
```
`isEntitled` (lines 70–75) already maps `.licensed → true`, so no change there.

**Hot-path caching rule to copy** (`TrialManager.swift` lines 87–96, 106–127 + comment on the
prompt-flood incident): `status` is read on EVERY hover/click/drag via `updateVisibility()`. An
uncached Keychain read there caused the macOS auth-prompt flood (memory 2401 / 2380). Mirror
`cachedStartDate`/`hasCachedStartDate`:
```swift
private var cachedStartDate: Date?          // TrialManager.swift lines 95–96
private var hasCachedStartDate = false
func trialStartDate() -> Date? {
    if hasCachedStartDate { return cachedStartDate }   // line 107 — cache-first
    let keychainDate = keychain.read()                 // ONE real read, then cached
    ...
    cachedStartDate = resolved; hasCachedStartDate = true; return resolved
}
```
The license read needs the same `cachedRecord` / `hasCachedRecord` pair, populated once, and kept in
sync at every write/delete point (mirror lines 132–136 and 141–146). NOTE: `LicenseState` currently
has `private init()` (line 22) and holds no injected store — the planner must decide where the
license read-once-cache lives (a small `LicenseManager` mirroring `TrialManager`, injected the same
way `TrialManager.shared = TrialManager(keychain: KeychainTrialStore())` on line 75, is the closest
analog; `LicenseState.status` then calls it like it calls `TrialManager.shared.trialStartDate()`).

**Successful-activation persistence hook** — the SettingsView success branch (below) currently only
flips the in-memory `sessionActivated`; Phase 12 must ALSO persist the `LicenseRecord` so the next
launch short-circuits offline.

---

### `Islet/SettingsView.swift` (call-site swap, EDIT — minimal)

**Analog:** itself. The ONLY structural change is line 20 (the constructor); the activate flow
(lines 164–184) and the state machine are already Phase-12-ready.

**read_first:** `Islet/SettingsView.swift` lines 14–20 and 162–184.

**The one-line swap** (line 20):
```swift
private let licenseService: LicenseService = StubLicenseService()
// →                        = PolarLicenseService()
```
Type is already the PROTOCOL (`LicenseService`), exactly as the header comment (lines 14–16)
promised: "The seam is held as the PROTOCOL type ... so Phase 12's PolarLicenseService is a
one-line swap."

**Activate flow already handles both outcomes** (lines 164–184) — no change needed for `.success`,
but D-04 wants `.unreachable` distinguished from `.invalidKey`. Current code collapses all failures:
```swift
case .failure:                     // line 180 — currently ONE branch
    activationPhase = .failure
```
D-04 requires splitting `.failure(.unreachable)` → a distinct "server not reachable" + Retry state
vs `.failure(.invalidKey)` → "not recognized" (lines 149–160 `statusLine` + the `ActivationPhase`
enum line 17 gain an `.unreachable` case). This is a UI-copy edit, not a new pattern.

**Success-side persistence** — line 169 `LicenseState.shared.sessionActivated = true` stays, but the
new persisted `LicenseRecord` write is added alongside it (the live-unlock nudge on lines 176–177 is
already correct and must be preserved — it fires the existing `updateVisibility()` path).

---

### `IsletTests/PolarLicenseServiceTests.swift` (test) — NEW

**Analog:** `IsletTests/LicenseServiceTests.swift` (async main-thread + XCTestExpectation idiom) and
`IsletTests/TrialManagerTests.swift` (the `FakeKeychainStore` in-memory fake, lines 11–32).

**read_first:** `IsletTests/LicenseServiceTests.swift` (whole file) and `IsletTests/TrialManagerTests.swift` lines 1–33.

**Async + main-thread assertion idiom to copy** (`LicenseServiceTests.swift` lines 18–27):
```swift
let exp = expectation(description: "activate completes")
StubLicenseService().activate(key: "ISLET-DEMO-OK") { result in
    XCTAssertTrue(Thread.isMainThread, "completion contract: MUST fire on main")
    if case .success = result {} else { XCTFail(...) }
    exp.fulfill()
}
wait(for: [exp], timeout: 3.0)
```
Plus the `Result.error` helper extension (lines 66–72) for one-line `.invalidKey` assertions.

**In-memory fake pattern to copy** (`TrialManagerTests.swift` lines 11–32) — build `FakeHTTPSession`
(returns canned `(Data?, HTTPURLResponse?, Error?)` triples, captures `httpBody` for the
"body == {key, organization_id} only" assertion) and `FakeLicenseStore` (records `write` calls,
seeded for the "present granted record → no network call" test) the SAME way `FakeKeychainStore`
tracks `readCount`:
```swift
private final class FakeKeychainStore: KeychainStore {   // → FakeLicenseStore: LicenseStore
    var storedDate: Date?
    private(set) var readCount = 0
    func read() -> Date? { readCount += 1; return storedDate }
    @discardableResult func write(_ date: Date) -> Bool { storedDate = date; return true }
    func delete() { storedDate = nil }
}
```

**Coverage rows to implement:** the full LIC-02 test matrix is enumerated in 12-RESEARCH.md lines
502–511 (200-granted → success, 200-non-granted/garbage → invalidKey, 404 → invalidKey, URLError →
unreachable, 500 → unreachable, main-thread completion, body-shape assertion, seeded-record →
no-network launch, successful-validate persists record).

**Test-run constraint:** `xcodebuild test` HANGS in this project (tests hosted in full `Islet.app`);
the compile gate is `xcodebuild build -scheme Islet -configuration Debug`, the actual run is manual
Cmd-U (12-RESEARCH.md lines 479–492, memory 2380/2401). Keep every test pure-fake so it never
touches `api.polar.sh` or the real Keychain.

---

## Shared Patterns

### Protocol-isolation of a fragile external
**Source:** `Islet/Notch/NowPlayingMonitor.swift` lines 34–47 (also stated in CLAUDE.md's MediaRemote
mandate).
**Apply to:** `PolarLicenseService` (network) and `KeychainLicenseStore` (Security framework).
Callers hold the PROTOCOL type; the concrete conformer is a one-file swap. `SettingsView` already
does this for `LicenseService`; replicate for the new `LicenseStore` seam.

### Main-thread completion hop
**Source:** `Islet/Licensing/LicenseService.swift` lines 10–13 (contract) + 45–60 (stub honoring it).
**Apply to:** every `completion(...)` in `PolarLicenseService`. URLSession callbacks are background;
wrap in `DispatchQueue.main.async`. `SettingsView.activate` (lines 162–184) relies on this to mutate
`@State`/`LicenseState` with no manual hop.

### Injectable store seam + in-memory fake (unit-testability)
**Source:** `Islet/Licensing/TrialManager.swift` lines 15–19, 74–101 (`init(keychain:defaults:)`) +
`IsletTests/TrialManagerTests.swift` lines 11–32.
**Apply to:** `KeychainLicenseStore`/`LicenseStore` and the license read-once cache. Inject the store
via init default (`init(store: LicenseStore = KeychainLicenseStore())`), fake it in tests. Real
`SecItem*` verified on-device only.

### Read-once, cache-in-memory (Keychain hot-path protection)
**Source:** `Islet/Licensing/TrialManager.swift` lines 87–96 (comment on the prompt-flood incident),
106–127, 132–136, 141–146.
**Apply to:** the persisted-license read in `LicenseState.status`. `status` is on the
`updateVisibility()` hover/click hot path; an uncached Keychain read there floods macOS auth prompts
on ad-hoc builds (memory 2401). Cache after first read; keep write/delete in sync.

### Codable record, never a bare bool (T-11-02)
**Source:** D-07 + RESEARCH.md lines 315–321.
**Apply to:** `KeychainLicenseStore`. Persist `LicenseRecord` (key + id + status + timestamp), never
a flippable `Bool`, never UserDefaults for entitlement truth.

### New-file build registration (XcodeGen)
**Source:** `project.yml` lines 33–99 — sources are FOLDER GLOBS (`- path: Islet`, `- path: IsletTests`).
**Apply to:** every new file. Placing `.swift` files under `Islet/Licensing/` and `IsletTests/`
auto-registers them, but the planner MUST run `xcodegen generate` (regenerates
`Islet.xcodeproj/project.pbxproj`) before `xcodebuild build`, or the new files won't compile into the
target. This is the established add-a-file step in this project.

---

## No Analog Found

None. Every file in this phase has a direct in-repo analog — this is a "swap the neighbor's payload"
phase, not a greenfield one.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | All 6 files map to existing `Islet/Licensing/` + `IsletTests/` analogs. |

---

## Metadata

**Analog search scope:** `Islet/Licensing/`, `Islet/Notch/` (NowPlaying protocol isolation),
`Islet/SettingsView.swift`, `Islet/AppDelegate.swift`, `IsletTests/`, `project.yml`.
**Files scanned:** LicenseService.swift, TrialManager.swift, LicenseState.swift, SettingsView.swift,
NowPlayingMonitor.swift, LicenseServiceTests.swift, TrialManagerTests.swift, AppDelegate.swift (grep),
project.yml.
**Pattern extraction date:** 2026-07-05
