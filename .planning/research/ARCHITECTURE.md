# Architecture Research — Trial/Licensing Integration into Islet

**Domain:** Integrating a trial-period + Polar.sh paid-licensing gate + real notarization into an existing, shipped native macOS notch app
**Researched:** 2026-07-05
**Confidence:** HIGH on integration points and existing-pattern extraction (verified by reading the actual files); HIGH on the Polar.sh API shape (fetched from official docs); MEDIUM on the exact offline-grace-period product decision (that's a product call, not an architecture fact)

> This is not a green-field "what does the domain look like" research doc — it is a **spot-check of the real Islet codebase** plus the Polar.sh customer-portal license-key API, answering exactly where five new pieces of functionality plug into an app that already has a proven single-arbiter visibility pattern and a proven protocol-isolation pattern for fragile external dependencies.

---

## The One Idea That Makes This Integration Make Sense

Islet already has two precedents this milestone must reuse, not reinvent:

1. **Protocol-isolation for fragile externals** — `NowPlayingService` (`Islet/Notch/NowPlayingMonitor.swift:40-47`) wraps the one truly fragile external dependency (private MediaRemote API) behind a tiny protocol so a break is a one-file swap. **Polar.sh's HTTP API is the second fragile external dependency this app will have** — it gets the identical treatment: a `LicenseService` protocol + one concrete `PolarLicenseService` conformer that is the ONLY file that imports `Foundation`'s networking for this purpose / knows Polar.sh's URL shape.

2. **Single-arbiter visibility (`updateVisibility()`, `NotchWindowController.swift:421-448`)** — there is exactly ONE place that decides show/hide (Pattern 7, enforced across Phases 2, 6, 8, 9 specifically to prevent race/flicker bugs). Licensing must compose into this existing AND-chain, not create a second hide/show call site.

Everything below elaborates those two sentences.

---

## Standard Architecture (current + proposed overlay)

### System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│  AppDelegate (Islet/AppDelegate.swift)                                  │
│   - owns NSStatusItem + menu (Settings…, Quit)                          │
│   - owns NotchWindowController (constructed + .start()'d unconditionally│
│     regardless of license state — see Recommendation 1 below)           │
│   - NEW: seeds TrialManager.recordFirstLaunchIfNeeded() before          │
│     constructing the controller (so the very first updateVisibility()   │
│     call already sees a valid trial state, no flash of unlicensed UI)   │
├────────────────────────────────────────────────────────────────────────┤
│  NotchWindowController (the existing single arbiter)                    │
│   - existing: powerMonitor, bluetoothMonitor, nowPlayingMonitor,        │
│     transientQueue, presentationState, interaction                      │
│   - NEW: private let licenseState: LicenseState  (shared instance)      │
│   - NEW: updateVisibility()'s shouldShow(...) gains one more AND term:  │
│     `isLicensed: licenseState.isEntitled` (mirrors hideInFullscreen)    │
│   - NEW: one one-shot DispatchWorkItem scheduled at the exact trial-    │
│     expiry instant (mirrors dismissWorkItem / mediaDismissWorkItem)     │
├────────────────────────────────────────────────────────────────────────┤
│  NEW: Islet/Licensing/  (mirrors Islet/Notch/'s pure-seam + thin-glue   │
│  split already used for PowerActivity/PowerSourceMonitor and            │
│  NowPlayingPresentation/NowPlayingMonitor)                               │
│                                                                          │
│   TrialLogic.swift       — PURE: trialStatus(startDate:now:length:)     │
│   TrialManager.swift     — GLUE: UserDefaults timestamp read/write,     │
│                             wraps TrialLogic, schedules the one-shot     │
│                             expiry DispatchWorkItem                      │
│   LicenseState.swift     — @Published model (mirrors NowPlayingState /  │
│                             ChargingActivityState: plain holder, no      │
│                             logic) — `status: LicenseStatus`, computed   │
│                             `isEntitled`                                 │
│   LicenseService.swift   — protocol (mirrors NowPlayingService exactly) │
│   PolarLicenseService.swift — concrete conformer; ONLY file that talks  │
│                             to api.polar.sh; Keychain read/write lives  │
│                             here too                                     │
├────────────────────────────────────────────────────────────────────────┤
│  SettingsView.swift (existing file, extended)                           │
│   - NEW Section("License"): TextField for key entry + "Activate" button │
│     + status label, reading/writing the SAME shared LicenseState        │
│     instance the controller reads (see Recommendation 3 for how they    │
│     stay in sync without a new DI mechanism)                            │
├────────────────────────────────────────────────────────────────────────┤
│  scripts/release.sh (existing file, unchanged structure)                │
│   - NEW: DEVELOPER_ID / NOTARY_PROFILE placeholders filled with the     │
│     real, now-purchased Apple Developer ID + a notarytool keychain      │
│     profile — no code branches change, only the two variables           │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | New or Modified |
|-----------|----------------|------------------|
| `TrialLogic.swift` | Pure function: given a start date, "now", and trial length, return `.active(daysRemaining:)` or `.expired`. Zero I/O, unit-testable in ms. | **New** |
| `TrialManager.swift` | Reads/writes the trial-start `Date` to `UserDefaults`, calls `TrialLogic`, schedules the one-shot expiry `DispatchWorkItem`. | **New** |
| `LicenseState.swift` | `ObservableObject` with `@Published var status: LicenseStatus` (`.trial(daysRemaining:)` / `.trialExpired` / `.licensed`) and a computed `isEntitled: Bool`. No logic beyond that — mirrors `NowPlayingState`. | **New** |
| `LicenseService` (protocol) | `activate(key:completion:)`, `validate(completion:)` — mirrors `NowPlayingService`'s protocol-isolation contract. | **New** |
| `PolarLicenseService.swift` | Concrete `LicenseService`; owns the `URLSession` calls to Polar's `/v1/customer-portal/license-keys/activate` and `/validate`, decodes JSON, reads/writes Keychain, explicitly hops to main before touching `@Published` state. | **New** |
| `NotchWindowController` | Adds `isLicensed` to the existing `shouldShow(...)` AND-chain in `updateVisibility()`; owns the shared `LicenseState` instance; schedules the trial-expiry one-shot work item in `start()`; tears it down in `deinit`. | **Modified** (`Islet/Notch/NotchWindowController.swift`) |
| `AppDelegate` | Calls `TrialManager.recordFirstLaunchIfNeeded()` once, before constructing `NotchWindowController`. | **Modified** (`Islet/AppDelegate.swift:12-51`) |
| `SettingsView` | Adds a License section bound to the shared `LicenseState`/`PolarLicenseService`. | **Modified** (`Islet/SettingsView.swift`) |
| `scripts/release.sh` | Fill `DEVELOPER_ID`/`NOTARY_PROFILE` placeholders (lines 22-23); no structural change — the script was explicitly written in Phase 0 to require zero edits beyond these two variables. | **Modified** (2-line change) |

---

## Recommendation 1 — Where does the license/trial gate live?

**Recommendation: compose it into `updateVisibility()`'s existing `shouldShow(...)` call (`NotchWindowController.swift:432-434`), as one more AND term — do NOT gate construction in `AppDelegate`.**

```swift
// Before (NotchWindowController.swift:430-436):
let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)
if shouldShow(hasTarget: target != nil,
              hideInFullscreen: hideInFullscreen,
              isFullscreen: fullscreen),
   let target {

// After:
let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)
if shouldShow(hasTarget: target != nil,
              hideInFullscreen: hideInFullscreen,
              isFullscreen: fullscreen,
              isLicensed: licenseState.isEntitled),   // NEW AND term
   let target {
```

**Why not gate at `AppDelegate` (skip constructing `NotchWindowController` at all when unlicensed)?**

- The Settings window (and the license-entry UI that lives inside it) is the ONE surface a locked-out user needs to reach to buy/enter a key. `AppDelegate` already unconditionally builds the status item and menu regardless of license state — so an `AppDelegate`-level gate would need to carve out an exception for Settings anyway, which is the same amount of plumbing as just always constructing everything and gating only the visual island.
- If the gate lived at construction time, a user who enters a valid key *while the trial-expired lockout is already showing* would need `AppDelegate` to retroactively construct-and-start a controller that was never built — a second construction path, which reintroduces exactly the kind of "two show/hide sites" bug class Phase 6/8/9 fought hard to eliminate (see Pattern 7 comment at `NotchWindowController.swift:414-420`).
- Gating inside `updateVisibility()` is fully reactive for free: it already re-runs on `didChangeScreenParameters`, `activeSpaceDidChange`, `didActivateApplication`, every transient enqueue/dismiss, and every settings change. License-state transitions (trial expires, user activates a key) just need to trigger one more call to the same function — no new show/hide plumbing.
- Hiding the panel via the existing else-branch (`panel?.orderOut(nil)`, `hotZone = nil`, `expandedZone = nil`) already achieves "no functionality" for free: with `hotZone`/`expandedZone` nil, `handlePointer(at:)` short-circuits (`NotchWindowController.swift:500-519`), so hover/click/haptics genuinely stop working, not just "invisible but still reacting." No separate interaction-disabling code is needed.

**Tradeoff accepted:** the power/Bluetooth/MediaRemote monitors keep running (idle-CPU ~0% by design, per the codebase's own event-driven-not-polling discipline) even while locked out. This is a deliberate, cheap tradeoff — not a functionality leak, since none of their output reaches the screen — and avoids a second start/stop lifecycle keyed to license state on top of the existing per-activity-toggle one (`activityEnabled(...)`, `handleSettingsChanged()`).

**Trial-expiry timing (no polling needed):** rather than adding a recurring timer to check "has the trial expired yet," schedule **one** `DispatchWorkItem` at the exact computed expiry instant in `TrialManager`/`start()`, firing a single `updateVisibility()` call — this is the *exact same idiom* already used four times in this file (`dismissWorkItem`, `graceWorkItem`, `mediaDismissWorkItem`, `deviceBatteryWork`: "one wake-up then idle, no recurring timer"). `updateVisibility()` also already gets triggered incidentally by ordinary system activity (screen wake, space switches, app switches), so in practice expiry is very unlikely to go unnoticed even without the dedicated work item — but the one-shot item makes it exact and is nearly free to add given the pattern already exists three times over in this file.

---

## Recommendation 2 — New components vs. existing-file additions

**New files (all under a new `Islet/Licensing/` group, mirroring the existing `Islet/Notch/` pure-seam + thin-glue split):**

| File | Pattern mirrored |
|------|-------------------|
| `TrialLogic.swift` | `PowerActivity.swift` / `NowPlayingPresentation.swift` — pure, unit-tested classification logic, zero I/O |
| `TrialManager.swift` | `PowerSourceMonitor.swift` — thin glue: UserDefaults I/O + wraps the pure function + owns the one-shot timer |
| `LicenseState.swift` | `NowPlayingState.swift` / `ChargingActivityState.swift` — plain `@Published` holder, no methods beyond simple computed properties |
| `LicenseService.swift` (protocol) | `NowPlayingService` protocol in `NowPlayingMonitor.swift:40-47` — verbatim pattern |
| `PolarLicenseService.swift` | `NowPlayingMonitor.swift`'s concrete-conformer role — the ONE file that imports networking for Polar and knows the URL/JSON shape; a future Polar API change is a one-file fix |

**Existing-file modifications (small, surgical):**

- `Islet/Notch/NotchWindowController.swift` — add `licenseState` property, add the `isLicensed` AND term (above), add the one-shot expiry work item in `start()`/`deinit` (mirrors existing teardown discipline at lines 1050-1084).
- `Islet/AppDelegate.swift` — one new call to seed the trial start date before `controller.start()` (around line 39-41).
- `Islet/SettingsView.swift` — one new `Section("License")` alongside the existing `Section("Activities")` (lines 42-64), same `Form`-based style.
- `scripts/release.sh` — fill two placeholder variables (lines 22-23); the script was explicitly pre-written in Phase 0 to require nothing else.
- `project.yml` — no new package dependency is required for the license/trial pieces themselves (plain `URLSession` + `Security` framework for Keychain, both system frameworks, no SPM package needed). If a Polar.sh Swift SDK wrapper is later preferred over raw `URLSession`, it would be added the same way `MediaRemoteAdapter` was (pinned `revision:`, since Polar's own SDKs are JS/Python-first — verify before assuming a Swift package exists).

**Do not** fold license state into the existing `NotchInteractionState`, `ChargingActivityState`, or `IslandPresentationState` models — those are deliberately narrow, single-purpose holders (the codebase's own comments are explicit about this: `ChargingActivityState.swift` header notes it is "the SEPARATE ... model ... NOT a NotchInteractionState phase, so the Phase-2 gesture machine stays untouched"). License gating is a different *axis* (can-the-app-run-at-all) from presentation (what-is-it-showing-right-now) and deserves its own model for the same reason those two are already kept apart.

---

## Recommendation 3 — Sharing license state between `NotchWindowController` and `SettingsView`

This is the one place where the existing `ActivitySettings` pattern (both `SettingsView` and the controller **independently** read the same `UserDefaults` keys, no shared object reference) does *not* transfer cleanly, because license validation must update the running controller's gate **live**, without an app restart, when the user types in a key.

**Recommendation: reuse the existing `UserDefaults.didChangeNotification` + `defaultsObserver` mechanism (`NotchWindowController.swift:302-305`, `handleSettingsChanged()` at line 854) rather than introducing a new shared-object-reference/DI style.**

Concretely:
- `PolarLicenseService`, on a successful `activate`/`validate`, writes a small **non-secret cache boolean** to `UserDefaults` (e.g., `"license.cachedEntitled"`) alongside the real secret (license key + Polar `activation_id`) in Keychain. Writing to `UserDefaults` automatically fires `didChangeNotification`, which `NotchWindowController` already observes.
- Extend `handleSettingsChanged()` (or add a small sibling `handleLicenseChanged()` called from the same observer) to re-read `LicenseState.status` from the persisted source of truth and call `updateVisibility()`.
- `SettingsView` reads/writes its own lightweight `LicenseState`-equivalent via `@AppStorage`/direct Keychain calls, exactly the way it already does for `chargingEnabled`/`nowPlayingEnabled`/`deviceEnabled` — no need to literally share a Swift object reference across files.

This keeps the "single source of truth is the persisted store, not an in-memory shared reference" discipline the codebase has used consistently since `ActivitySettings.swift`, and requires zero new plumbing beyond one more thing the existing `defaultsObserver` reacts to.

---

## Recommendation 4 — Data flow: UserDefaults vs. Keychain split

**Confirmed, with reasoning to record in the plan:**

| Value | Store | Why |
|-------|-------|-----|
| Trial start date/timestamp | `UserDefaults` | Not a secret. A user editing/deleting it just grants themselves a few extra free-trial days — a low-stakes, self-limiting act (they still eventually have to pay or lose the island entirely), not worth the complexity of Keychain access-group/entitlement handling for zero real protection gained (a determined user can delete a Keychain item just as easily as a UserDefaults key). Matches the project's explicit anti-speculative-complexity stance. |
| Validated license key (raw string) | **Keychain** | This is the tamper-sensitive value; Keychain survives app deletion/reinstall (unlike UserDefaults), which is desirable here — a legitimate paying customer who reinstalls Islet should not have to re-enter their key or re-purchase. |
| Polar `activation_id` (UUID returned by the `/activate` call) | **Keychain**, alongside the key | Confirmed by Polar's own documented flow (see Sources): the activation endpoint "reserves an allocation for a specific device" and the returned `activation_id` is meant to be stored and round-tripped into subsequent `/validate` calls as "extra validation." Storing it next to the key is the natural, Polar-recommended pattern — not an Islet-specific invention. |
| `lastValidatedAt` timestamp (last successful *online* validation) | Keychain (or UserDefaults — not tamper-sensitive on its own, but convenient to keep alongside the key) | Needed to implement an offline-grace window (e.g., "trust the cached Keychain state for N days since the last successful online check, then require re-validation") so a legitimate offline user (flight, no wifi) isn't locked out. **This offline-grace duration is a product decision, not an architecture fact — flag it for the roadmap/planning phase, do not hardcode a number from this research.** |
| `"license.cachedEntitled"` boolean (Recommendation 3) | `UserDefaults` | Deliberately non-secret — it exists purely to piggyback on `didChangeNotification` for live UI updates; the actual authority is the Keychain-stored key + activation_id + last-validated timestamp. A tampered UserDefaults boolean without a correspondingly valid Keychain entry is treated as untrusted the next time an online re-validation is due. |

---

## Recommendation 5 — Suggested build order for the roadmap

**License-gating logic should be built and fully tested against a stub *before* the real Polar.sh network integration.** Recommended phase order:

1. **Trial + lockout gate (local/stubbed license state).** Build `TrialLogic` (pure, unit-tested), `TrialManager` (UserDefaults glue + one-shot expiry timer), `LicenseState`, and the `updateVisibility()` integration — driven by a trivial stub (`LicenseState.status` manually settable, or a debug-only UserDefaults override) rather than a real `LicenseService`. This is the highest-risk integration point (touches the proven single-arbiter `NotchWindowController`) and should be de-risked and stabilized *before* any other new code touches that file again — matches the codebase's own established practice of building+testing the pure classification seam before wiring the live external glue (`PowerActivity.swift` before `PowerSourceMonitor.swift` in Phase 3; `NowPlayingPresentation.swift` before `NowPlayingMonitor.swift` in Phase 4).
2. **License-entry Settings UI**, wired against a stubbed `LicenseService` (e.g., an in-memory fake that "validates" any sufficiently key-shaped string after a fake delay). This exercises the full UI state machine (idle → validating → success/failure) without live network flakiness confounding UI bugs.
3. **Real `PolarLicenseService`** — the actual `URLSession` calls to `/v1/customer-portal/license-keys/activate` and `/validate`, Keychain read/write, main-thread hop — swapped in behind the *same* `LicenseService` protocol from step 2 with zero UI or `TrialManager`/`LicenseState` wiring changes. This is the first point a live Polar.sh product/API credentials are actually needed.
4. **Real notarization** (`scripts/release.sh` placeholder fill) — genuinely independent of the three steps above; touches only two shell variables and requires only the already-purchased Developer ID credentials. Zero code coupling to the licensing work, so it can be sequenced in parallel with, or after, steps 1-3 without blocking or being blocked by them. `PROJECT.md`'s stated reason for bundling it into this milestone is a *business* reason ("don't want a Gatekeeper warning on a paid product's first launch"), not a technical dependency.

---

## Recommendation 6 — Concurrency/threading concerns

- **`URLSession` completion handlers do NOT run on main by default** (they run on the session's delegate queue, a background queue, unless explicitly configured otherwise). This is the *opposite* assumption a first-time programmer might carry over from `NowPlayingMonitor.swift`'s comment ("the wrapper ALREADY dispatches every callback to `DispatchQueue.main.async` ... we add NO second main-hop"). `PolarLicenseService` must instead mirror **`PowerSourceMonitor.swift`'s** explicit-hop discipline (`DispatchQueue.main.async { ... }` wrapped around the callback body, `PowerSourceMonitor.swift:79-83`) before touching any `@Published` property on `LicenseState`. Flag this explicitly in the plan for whichever phase builds `PolarLicenseService` — it is the single most likely threading bug in this milestone.
- **Keychain calls (`SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`) are synchronous** and can block briefly on disk/Secure-Enclave I/O. Given the call frequency here is low (once at launch to read, once after an explicit "Activate" button tap to write — not a hot path, not on every frame or every monitor tick), it is acceptable to call them synchronously on the main thread, consistent with the project's anti-speculative-complexity stance. Do not introduce a background queue for this unless on-device testing shows a perceptible hitch.
- **The one-shot trial-expiry `DispatchWorkItem`** should follow the exact existing idiom used four times already in `NotchWindowController.swift`: store the item as a property, cancel it in `deinit`, schedule via `DispatchQueue.main.asyncAfter(deadline:)`, no recurring timer.
- **No new actor-isolation gymnastics expected.** `TrialManager`/`PolarLicenseService` should be plain `@MainActor` classes like `PowerSourceMonitor`/`NowPlayingMonitor`, with the same `nonisolated(unsafe)`-on-a-single-property escape hatch only if `stop()`/teardown needs to run from a `nonisolated deinit` (mirrors `PowerSourceMonitor.swift:62-65` and `NowPlayingMonitor.swift:51-56`) — likely unnecessary here since there is no persistent child process or run-loop source to tear down, just a single in-flight `URLSessionTask` that can be `.cancel()`'d synchronously.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: A second show/hide call site for "locked out"
**What people do:** Add a separate `if !licenseState.isEntitled { panel.orderOut(nil); return }` early-return at the top of some other method, instead of composing into `shouldShow(...)`.
**Why it's wrong:** Reintroduces the exact "two hide/show sites can race and flicker" bug class Phases 2/6/8/9 explicitly fixed by centralizing on one `updateVisibility()`. A second site is one of the concrete regressions a code reviewer should flag on sight in this codebase.
**Instead:** One more boolean AND term inside the existing `shouldShow(...)` call.

### Anti-Pattern 2: Sharing a live `LicenseState` object reference constructed in two different places
**What people do:** `AppDelegate` constructs its own `LicenseState()`, `SettingsView` constructs a different one via `@StateObject`, and they silently drift out of sync.
**Why it's wrong:** No single source of truth; the controller's gate could show stale entitlement even after a successful validation in Settings.
**Instead:** Persisted store (UserDefaults cache flag + Keychain) is the single source of truth; `didChangeNotification` is the live-update signal both sides already know how to listen for (Recommendation 3).

### Anti-Pattern 3: Polling for trial expiry
**What people do:** A repeating `Timer`/`DispatchQueue.main.asyncAfter` loop that re-checks trial status every N seconds "just to be safe."
**Why it's wrong:** Violates the codebase's explicit, repeatedly-stated "idle CPU ~0%, no polling clock, event/one-shot only" discipline (present in `PowerSourceMonitor`, `BluetoothMonitor`, and every dismiss-timer in `NotchWindowController`).
**Instead:** One `DispatchWorkItem` scheduled at the exact computed expiry instant (Recommendation 1).

### Anti-Pattern 4: Assuming URLSession's completion handler is already on main
**What people do:** Copy the "no second main-hop needed" comment style from `NowPlayingMonitor.swift` and skip the `DispatchQueue.main.async` wrap in `PolarLicenseService`.
**Why it's wrong:** `URLSession` callbacks are background-queue by default; skipping the hop is a crash/undefined-behavior risk the moment the completion touches `@Published` state or AppKit.
**Instead:** Mirror `PowerSourceMonitor.swift`'s explicit hop instead (Recommendation 6).

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Polar.sh customer-portal license-keys API | `POST https://api.polar.sh/v1/customer-portal/license-keys/activate` (first entry — binds the key to this device via a `label`, returns an `activation_id`) then `POST https://api.polar.sh/v1/customer-portal/license-keys/validate` (subsequent checks, passing back `key` + `organization_id` + the stored `activation_id`) | Both customer-portal endpoints are documented as usable **without authentication** directly from a client app — appropriate for a native Mac app with no backend server. Response includes `status` (`granted`/`revoked`/`disabled`), `expires_at`, and `activation` details — map these directly onto `LicenseStatus`. HIGH confidence (fetched directly from `polar.sh/docs`, 2026-07-05). |
| Apple Notary Service | `xcrun notarytool submit --keychain-profile ... --wait` + `xcrun stapler staple` | Already fully wired in `scripts/release.sh`; only the two placeholder variables need real values once the Developer ID cert + a `notarytool store-credentials` keychain profile exist. No code/architecture change needed here — this was explicitly designed as a fill-in-two-variables task in Phase 0. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `TrialManager`/`PolarLicenseService` ↔ `NotchWindowController` | Persisted store (`UserDefaults` cache flag + Keychain) + `UserDefaults.didChangeNotification` | Mirrors the existing `ActivitySettings` ↔ controller boundary; no new shared-object DI style introduced. |
| `LicenseService` protocol ↔ `PolarLicenseService` concrete conformer | Protocol conformance, closure-based callbacks (not async/await, to match the existing `NowPlayingService`/`PowerSourceMonitor` closure idiom used throughout this codebase) | A future Polar.sh API change is a one-file swap, exactly like the `NowPlayingService` precedent this milestone is explicitly told to mirror. |
| `SettingsView` ↔ `PolarLicenseService` | Direct call from a button action (`activate(key:completion:)`), completion hops to main, updates `@AppStorage`/Keychain, which the controller observes via `didChangeNotification` | Same shape as the existing `LaunchAtLogin.set(...)` call pattern already in `SettingsView.swift:20-38` (try/catch, revert UI state on failure). |

---

## Sources

- Direct reads of the actual codebase (HIGH confidence — verified, not inferred): `Islet/AppDelegate.swift`, `Islet/Notch/NotchWindowController.swift` (all ~1086 lines), `Islet/Notch/NotchPanel.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/NowPlayingState.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `Islet/IsletApp.swift`, `scripts/release.sh`, `project.yml`.
- `.planning/PROJECT.md` — confirms the v1.1 milestone scope (3-day trial, €7.99 one-time Polar.sh purchase, Keychain-cached validation, real Developer-ID notarization) and that the Developer account has already been purchased.
- Polar.sh official docs — [Activate License Key](https://polar.sh/docs/api-reference/customer-portal/license-keys/activate), [Validate License Key](https://polar.sh/docs/api-reference/customer-portal/license-keys/validate) — HIGH confidence, fetched directly 2026-07-05; confirms no-auth customer-portal endpoints, the `activation_id` round-trip pattern, and the `status`/`expires_at`/`activation` response shape used in Recommendation 4.
- A grep across the repo (`keychain|license|polar|trial`, case-insensitive) confirmed there is currently **zero** existing licensing/trial/Keychain code — this is a genuinely new subsystem, not an extension of something partially built.

---
*Architecture research for: Islet v1.1 Trial & Paid Release milestone*
*Researched: 2026-07-05*
