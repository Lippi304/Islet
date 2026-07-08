# Phase 15: Architecture Refactor — Mechanical Fixes & DI Seams - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Seven independent, low-risk fixes identified by this session's full-codebase architecture audit
(5 parallel subsystem reviews, 21 ranked findings — see `<specifics>` for the audit source).
None require touching `NotchWindowController`'s activity-merge/timer logic or restructuring
folders — that's Phase 16+ (coordinator extraction), explicitly deferred.

In scope:
1. DRY `expandedNotchFrame`/`wingsFrame` duplicate formula (`NotchGeometry.swift`)
2. Extract `blobShape()` helper in `NotchPillView.swift`, mirroring the existing `wingsShape()`
3. Protocolize `LocationProvider` + add its missing main-thread contract; mark `BasicOutfitState` `@MainActor`
4. Give `LicenseState` a DI seam (protocol-typed `TrialManager`/`LicenseManager` collaborators)
5. Close the weather/calendar visibility-arbiter gap (15-min refresh timer must respect fullscreen/license gating)
6. **[Behavior fix, explicit exception]** Fix `EqualizerBars`' random-profile reshuffle-on-re-render bug
7. **[Behavior fix, explicit exception]** Preserve the real Polar.sh validation payload (`id`/`status`/`expiresAt`) instead of discarding it in `SettingsView.activate()`

Out of scope (deferred to Phase 16+): `NotchWindowController` coordinator extraction (any activity type), new folder taxonomy, any Clean-Architecture Domain/Data/Presentation layering.

</domain>

<decisions>
## Implementation Decisions

### Phase sequencing
- **D-01:** Split into two phases rather than one big phase. Phase 15 = mechanical/low-risk fixes (this phase). Phase 16 = `NotchWindowController` coordinator extraction, isolated because it's the highest-risk, most-invasive change and deserves its own plan/verify/close cycle.

### Behavior-preservation policy
- **D-02:** This phase's default is zero product-behavior change — every item except two is a pure structural extraction (same runtime output, different code shape).
- **D-03:** Items 6 (EqualizerBars) and 7 (Polar payload) are explicit, called-out exceptions — both are small, well-understood bugs found during the audit with an already-worked fix (see `<code_context>`). Verify each on-device individually, don't bundle their verification with the pure-refactor items.

### Coordinator scope (applies to Phase 16, captured here to avoid re-discussion)
- **D-04:** Phase 16 (not this phase) extracts ONLY the `DeviceCoordinator` — proving the `ActivityCoordinator` pattern on the highest-risk, most-documented activity type (11+ inline "gap-closure"/"Finding N" comments in `NotchWindowController`) before repeating it for Charging/NowPlaying/Outfit in a later phase, not yet created.

### Verification strategy
- **D-05:** Existing 18-file / 2,054-LOC test suite (`IsletTests/`) must stay green for every item. Items 3 and 4 (LocationProvider protocolization, LicenseState DI) should each get a *new* test file proving the extraction actually enables testing (e.g., `LicenseStateTests.swift` didn't exist before this phase — its absence was itself a finding).
- **D-06:** Items 5, 6, 7 touch runtime behavior visible on-device (visibility gating, an animated view, a paid-license flow) — each needs a manual on-device check in addition to any unit test, since `NotchWindowController`/`NotchPillView`/`SettingsView` aren't unit-testable AppKit/SwiftUI glue (confirmed in the audit's test-coverage-map finding).

### Claude's Discretion
- Wave ordering within the plan (which of the 7 items ship first) — no dependency between them except item 3 (LocationProvider protocol) is a natural pairing with item 5 (arbiter gap), since both touch the same weather/calendar refresh path.
- Whether items 6 and 7 get their own dedicated plan/wave (isolating the two behavior-changing items from the five pure-refactor items) or are folded into the same waves as their nearest sibling — pick whichever keeps verification cleanest.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audit source (this session, same conversation — not a separate file)
No separate audit document was written to disk; the full findings (all 21, file:line cited) were
produced by 5 parallel subagent reviews and are reproduced in full in `<code_context>` below.
Re-read the actual source files listed there before planning — this context captures the
*decisions*, not a substitute for reading the code.

### Project-level
- `.planning/PROJECT.md` — Context section, "Known technical debt carried into next milestone planning"
- `.planning/STATE.md` — Roadmap Evolution section, Phase 15/16 entries

No external specs/ADRs apply — this is an internal refactor with no product requirement doc.

</canonical_refs>

<code_context>
## Existing Code Insights — full findings from this session's audit, verified against real source

### 1. Duplicate frame-geometry formula
**File:** `Islet/Notch/NotchGeometry.swift:64-79`
`expandedNotchFrame(collapsed:expandedSize:)` and `wingsFrame(collapsed:wingsSize:)` have
byte-for-byte identical bodies, differing only in the parameter name. Fix: extract a
`topPinnedFrame(collapsed:size:)` helper; keep both original function names/signatures as thin
wrappers so every existing call site compiles unchanged. Worked diff already produced this
session (see prior artifact in conversation — planner/executor should re-derive from source,
this is a 4-line change).

### 2. Blob-shape duplication
**File:** `Islet/Notch/NotchPillView.swift:170-233`
`wingsShape(content:)` (221-233) already extracted the shared skeleton for the three wing
variants ("Finding 12" per its own comment). The four "blob" states — `collapsedIsland` (170-184),
`expandedIsland` (194-214), and (not yet read in full this session) `mediaExpanded`,
`mediaUnavailable` — each independently repeat the identical
`NotchShape(...).fill(...).matchedGeometryEffect(id:"island",in:ns).frame(...)` chain.
Fix: extract `blobShape(topCornerRadius:bottomCornerRadius:size:content:)` mirroring
`wingsShape`. **Important nuance found during the audit:** `collapsedIsland` is NOT a clean fit —
it fills with a DEBUG-only tint (not `.black`) and carries a hover `.scaleEffect` + dev `.offset`
that `expandedIsland`/`mediaExpanded`/`mediaUnavailable` don't have. Extract only the latter
three; leave `collapsedIsland` as its own case (genuinely distinct, not sloppy duplication —
verify `mediaExpanded`/`mediaUnavailable`'s exact overlay content before extracting, not yet
read in full this session).

### 3. LocationProvider protocol/threading gap
**File:** `Islet/Location/LocationProvider.swift` (whole file, ~55 lines)
Its Phase-14 siblings `WeatherKitService` (`Islet/Weather/WeatherService.swift:21`) and
`EventKitService` (`Islet/Calendar/CalendarService.swift:15`) both have `protocol` seams citing
the project's isolation convention explicitly in their header comments. `LocationProvider` is
stored as a concrete, non-optional type at `NotchWindowController.swift:93`, no protocol.
Its siblings also state "CONTRACT: delivered on MAIN thread" and enforce it with
`await MainActor.run` (`WeatherService.swift:9-10,23`; `CalendarService.swift:8-9,17`).
`LocationProvider`'s `CLLocationManagerDelegate` methods (lines ~45-54) have no hop, no comment —
implicitly trusts CoreLocation's default delegate-queue behavior. Its output ultimately mutates
`BasicOutfitState` (`Islet/Notch/BasicOutfitState.swift:7-9`), a plain `ObservableObject` with
**no `@MainActor`**.
Fix: add `protocol LocationService: AnyObject { func requestOnce(completion: @escaping (CLLocation?) -> Void) }`,
conform `LocationProvider`, change the controller's stored property to the protocol type. Add the
same "CONTRACT — delivered on MAIN thread" header comment. Mark `BasicOutfitState` `@MainActor`.

### 4. LicenseState DI seam
**File:** `Islet/Licensing/LicenseState.swift:19-87` (full file read this session)
```swift
final class LicenseState {
    static let shared = LicenseState()
    private init() {}
    var status: LicenseStatus {
        // ... #if DEBUG override ...
        if LicenseManager.shared.isLicensed { return .licensed }
        if sessionActivated { return .licensed }
        guard let start = TrialManager.shared.trialStartDate() else { return .trial(daysRemaining: 3) }
        // ... trialStatus(...) switch ...
    }
    var isEntitled: Bool { /* switch on status */ }
    var trialExpiryDate: Date? { TrialManager.shared.trialStartDate()?.addingTimeInterval(TrialManager.trialLength) }
}
```
Unlike every sibling in this subsystem (`TrialManager` takes an injected `KeychainStore`,
`LicenseManager` takes an injected `LicenseStore`, `LicenseService` is protocol-typed),
`LicenseState` hard-references `.shared` singletons directly. No `LicenseStateTests.swift`
exists. This is the single source of truth gating the entire paid app's `updateVisibility()`
call.
Fix (worked, verified-compiling shape):
```swift
protocol LicenseManaging: AnyObject { var isLicensed: Bool { get } }
protocol TrialStatusProviding: AnyObject { func trialStartDate() -> Date? }
extension LicenseManager: LicenseManaging {}
extension TrialManager: TrialStatusProviding {}

final class LicenseState {
    static let shared = LicenseState()
    private let licenseManager: LicenseManaging
    private let trialManager: TrialStatusProviding
    init(licenseManager: LicenseManaging = LicenseManager.shared,
         trialManager: TrialStatusProviding = TrialManager.shared) {
        self.licenseManager = licenseManager
        self.trialManager = trialManager
    }
    // status/isEntitled/trialExpiryDate bodies: replace `LicenseManager.shared.isLicensed`
    // with `licenseManager.isLicensed`, `TrialManager.shared.trialStartDate()` with
    // `trialManager.trialStartDate()`. No other logic changes.
}
```
Every existing call site (`NotchWindowController.swift:57,517,538`, `AppDelegate.swift`,
`SettingsView.swift:12,115,120,175,188`) keeps using `.shared` unmodified via the default
arguments. New test target: construct `LicenseState(licenseManager: FakeLicenseManager(),
trialManager: FakeTrialManager())` and pin the 4-way precedence order (DEBUG override →
persisted license → session activation → trial).

### 5. Weather/calendar arbiter gap
**File:** `Islet/Notch/NotchWindowController.swift:424-435` (`startOutfitRefresh`), `467-479` (`currentPresentation`)
The 15-minute `Timer` driving weather/calendar refresh is unconditional — no activity toggle,
and critically, `outfitState` is never routed through `currentPresentation()`/`updateVisibility()`
the way charging/device/now-playing are. It keeps firing WeatherKit/EventKit calls even while the
panel is hidden by fullscreen or locked out by an expired trial.
Fix: expose the "is the island currently visible" boolean that `updateVisibility()` already
computes internally (it returns/sets this from `shouldShow(...)`). Have the outfit-refresh path
early-return when not visible, resuming on the next `positionAndShow`. No change to weather/
calendar rendering while visible.

### 6. [Bug] EqualizerBars re-render bug
**File:** `Islet/Notch/NotchPillView.swift:596-622` (read in full this session)
```swift
struct EqualizerBars: View {
    let isPlaying: Bool
    var tint: Color = .white
    private static let barCount = 5
    private let profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)]
    private let boxHeight: CGFloat = 16

    init(isPlaying: Bool, tint: Color = .white) {
        self.isPlaying = isPlaying
        self.tint = tint
        self.profiles = (0..<Self.barCount).map { _ in
            (low: CGFloat.random(in: 3...6), high: CGFloat.random(in: 10...16),
             period: Double.random(in: 0.55...1.05), phase: Double.random(in: 0...1))
        }
    }
```
The doc comment (lines 601-604) claims profiles are "generated ONCE at init and held stable for
the view's lifetime (re-renders don't reshuffle it)." False for a plain `struct View`:
`EqualizerBars(...)` is reconstructed on every parent `body` pass (which happens on every Now
Playing position tick — `NotchWindowController.swift:1099` writes `nowPlayingState.position` on
every adapter callback, and `nowPlaying` is `@ObservedObject` on the view), so `init` — and its
`CGFloat.random` calls — re-runs every time. Visible glitch: the bars visibly reshuffle instead
of staying stable.
Fix (worked, verified shape):
```swift
@State private var profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)]
    = EqualizerBars.makeProfiles()

private static func makeProfiles() -> [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] {
    (0..<barCount).map { _ in
        (low: CGFloat.random(in: 3...6), high: CGFloat.random(in: 10...16),
         period: Double.random(in: 0.55...1.05), phase: Double.random(in: 0...1))
    }
}
// init(isPlaying:tint:) removed — isPlaying/tint keep their memberwise/default assignment.
```
SwiftUI ties `@State` to the view's position in the tree, not the struct's lifetime — the initial
value expression runs once per identity, which is what the original comment already promised.
On-device verify: Now Playing active, watch the equalizer bars over ~30s — profile shape (which
bars are tall/short, their relative rhythm) should stay visually consistent, not reshuffle.

### 7. [Bug] Discarded Polar validation payload
**Files:** `Islet/Licensing/PolarLicenseService.swift:38,52-60`, `Islet/Licensing/LicenseService.swift:38`, `Islet/SettingsView.swift:170-196` (not fully read this session — verify exact lines before implementing)
`PolarLicenseService.activate` decodes `id`/`status`/`expiresAt` into a private
`ValidatedLicenseKey` (`PolarLicenseService.swift:52-60`), but the `LicenseService` protocol only
returns `Result<Void, LicenseActivationError>` (`LicenseService.swift:38`), so
`SettingsView.activate()` fabricates a fresh `LicenseRecord(key: enteredKey, licenseID: "",
status: "granted", validatedAt: Date())` from scratch instead of persisting the real server
response. `LicenseManager.isLicensed` only ever re-checks the local cached Keychain record — it
never asks Polar again. **Product risk:** a refund/chargeback can never re-lock the app
client-side.
Fix: widen `LicenseService.activate` to return a small `ValidatedLicense { id, status, expiresAt }`
result type instead of `Void`, thread it through `StubLicenseService` (dummy success payload) and
`SettingsView.activate()` so `LicenseManager.recordValidation(_:)` persists the real Polar
response. Runtime effect for today's users is identical (still ends in `.licensed`) — this only
changes what's stored, not the activation success/failure UX. On-device verify: activate a real
key, confirm the app still unlocks exactly as before; this phase does NOT add expiry/revocation
*enforcement* — that's future work, only the data needed for it is preserved here.

</code_context>

<specifics>
## Specific Ideas

This phase's scope is entirely sourced from a single-session, full-codebase architecture audit
run earlier in this conversation: 5 parallel subagent reviews (window/visibility core,
activity/presentation, external service integrations, licensing/app shell, cross-cutting
quality) covering all 37 production Swift files, cross-checked against the actual source (all
file:line citations above were verified by direct file reads, not agent claims taken at face
value). The audit's own "Recommended next steps" ordering (fix the bug → DRY the geometry → DI
seam → close the arbiter gap → coordinator split) directly informed this phase's item list and
the Phase 15/16 split.

</specifics>

<deferred>
## Deferred Ideas

- **NotchWindowController full coordinator extraction** (Charging/Device/NowPlaying/Outfit) —
  Phase 16 does Device only; Charging/NowPlaying/Outfit coordinators are a future phase, gated on
  Phase 16's on-device verification actually landing clean.
- **Full Clean Architecture (Domain/Data/Presentation) folder restructuring** — explicitly
  rejected by the user this session as disproportionate ceremony for this app's size; the
  existing feature-folder structure (`Notch/`, `Licensing/`, `Weather/`, `Calendar/`, `Location/`)
  stays as-is.
- **Duplicated Keychain read-once-cache boilerplate** between `TrialManager`/`LicenseManager`
  (audit finding, medium severity) — not included in this phase's 7 items; candidate for a future
  quick task if it becomes a maintenance pain point.
- **Naming clarity across the three "License*" types** (audit finding, medium severity) — not
  included; a rename is higher-blast-radius than the DI seam and wasn't judged worth bundling
  here.
- **Magic-number sprawl in `NotchPillView.swift`** (audit finding, medium severity, no
  `Constants`/`Layout` enum anywhere in the app) — not included in this phase.

### Reviewed Todos (not folded)
None — no pending todos existed for this phase (`todo.match-phase 15` returned zero matches).

</deferred>

---

*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Context gathered: 2026-07-08*
