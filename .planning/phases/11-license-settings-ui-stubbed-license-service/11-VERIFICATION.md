---
phase: 11-license-settings-ui-stubbed-license-service
verified: 2026-07-05T14:52:00Z
status: passed-with-manual
score: 6/6 truths code-verified (5 require a manual on-device / Cmd-U confirmation pass)
requirements: [TRIAL-03]
compile_gate: BUILD SUCCEEDED (merged tree, per orchestrator)
code_verified:
  - "TRIAL-03: days-remaining countdown ('n days left in your trial.', singular for 1) present; old end-date notice removed"
  - "Buy Now 'Buy Islet — €7.99' → NSWorkspace.open(https://getislet.app) present"
  - "Activation state machine idle→validating→success/failure present; Activate disabled while validating and when trimmed-empty"
  - "sessionActivated flip + license.activationNudge UserDefaults trigger wired to Phase 10 defaultsObserver→handleSettingsChanged→updateVisibility→isEntitled (ordering correct: flag set before nudge write)"
  - "sessionActivated is in-memory-only var, never persisted (T-11-02) → resets false on relaunch"
  - "Adaptive Section('License') is first child of Form (line 38, before Launch-at-login line 57); .trial/.trialExpired/.licensed render locked copy"
  - "Menu-bar 'Settings…' → openSettings path (AppDelegate) untouched by Phase 11 — no Phase 10 regression introduced"
  - "LicenseServiceTests covers D-05 key→verdict + D-06 async main-thread contract (4 tests, logic inspected)"
manual_verification:
  - test: "Full test suite (Cmd-U / xcodebuild test) green — LicenseServiceTests D-05/D-06"
    expected: "4 tests pass: magic key→.success on main thread, non-magic→.failure(.invalidKey), whitespace trimmed→.success, completion asynchronous"
    why_human: "xcodebuild test HANGS headlessly in this env (test bundle hosted in full Islet.app which boots NSPanel/MediaRemote/IOBluetooth and never yields without an interactive GUI). Pre-existing repo constraint, not a Phase 11 defect. Requires interactive Cmd-U."
  - test: "Live unlock: expired/trial state → Settings → paste ISLET-DEMO-OK → Activate"
    expected: "⟳ Validating… ~1s, then section flips to 'Licensed ✓' and the locked island re-appears WITHOUT restart (no abrupt yank)"
    why_human: "Interaction + window-visibility timing; LicenseState is a private init() singleton so the .licensed short-circuit is not unit-reachable."
  - test: "Buy Now browser handoff (D-07)"
    expected: "Clicking 'Buy Islet — €7.99' opens the default browser at https://getislet.app"
    why_human: "External app handoff via NSWorkspace.open is not unit-observable."
  - test: "Adaptive layout across .trial / .trialExpired / .licensed (D-01)"
    expected: "trial/expired show days-or-heading + Buy Now + field; licensed shows 'Licensed ✓' only (Buy Now + field hidden). Drive via DEBUG forceExpired/forceLicensed + magic key."
    why_human: "Visual layout across three enum states."
  - test: "No persistence across relaunch (T-11-02 / Pitfall 1)"
    expected: "Activate with magic key, quit + relaunch → app back in trial/expired (island locked); entitlement did not survive."
    why_human: "Process-lifetime behavior."
  - test: "Menu-bar → Settings one-click (SC#4, Phase 10 regression check)"
    expected: "Clicking the menu-bar item's 'Settings…' opens the Settings window in one action."
    why_human: "Menu-bar interaction + window focus not unit-observable."
warnings:
  - id: WR-01
    disposition: accepted-deviation
    summary: "'✓ License activated' (.green) success status line is unreachable — on success licenseStatus=.licensed and activationPhase=.success are set in the same render pass; the .licensed Section case renders only 'Licensed ✓' (omits licenseEntry, which hosts statusLine), so the green line shows zero frames and the activationPhase=.success assignment is dead."
    goal_impact: "None. Success feedback is still unambiguous via the 'Licensed ✓' section flip. The idle→validating→failure status lines ARE reachable. This is a locked-UI-SPEC copy miss (D-04), not a goal blocker. Recommend either dropping the dead assignment or briefly showing the green line before collapsing (per REVIEW WR-01 fix)."
  - id: IN-01
    disposition: minor
    summary: "Activate empty-guard trims .whitespaces while the service trims .whitespacesAndNewlines — a newline-only key ('\\n') is enabled and wastes one ~1s round-trip resolving to .failure. No correctness/security impact."
---

# Phase 11: License Settings UI — Stubbed License Service — Verification Report

**Phase Goal:** Deliver the License section of Settings — trial days-remaining (TRIAL-03), Buy Now handoff, and an idle→validating→success/failure activation state machine driven by a protocol-isolated stub license service, with a successful magic-key activation live-unlocking the island via the existing Phase 10 path and no persisted entitlement.
**Verified:** 2026-07-05T14:52:00Z
**Status:** passed-with-manual
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | TRIAL-03: Settings shows days-remaining ("n days left in your trial.", singular for 1), replacing the old end-date notice (D-01/D-03) | ✓ VERIFIED (code) · visual=manual | `SettingsView.swift:40-44` `days == 1 ? "1 day left in your trial." : "\(days) days left in your trial."` `.foregroundStyle(.secondary)`. Old end-date `Text` block gone (only a code comment references it). |
| 2 | Buy Now "Buy Islet — €7.99" opens https://getislet.app in default browser (D-07) | ✓ VERIFIED (code) · handoff=manual | `SettingsView.swift:130-134` `Button("Buy Islet — €7.99") { NSWorkspace.shared.open(URL(string: "https://getislet.app")!) }`. Hardcoded URL, no injection surface (T-11-04). |
| 3 | Activation state machine idle→validating→success/failure with inline status line; Activate disabled while validating and when field empty (D-04/D-05/D-06) | ⚠️ VERIFIED with WARNING · live=manual | `ActivationPhase` enum + `statusLine` (`:150-161`) + `activate()` (`:165-185`). Disabled on `.validating` OR trimmed-empty (`:143-144`). Validating + failure status lines reachable. **WR-01:** the `.success` green line is unreachable (section flips to `Licensed ✓`) — accepted deviation, success still confirmed via section flip. |
| 4 | Menu-bar → Settings one-click intact (no Phase 10 regression) | ✓ VERIFIED (code) · click=manual | `AppDelegate.swift:43-44` menu "Settings…" → `openSettings` → posts `.openIsletSettings` (`:129-133`). Phase 11 changed only `SettingsView` body; the menu/routing path is untouched. |
| 5 | Successful magic-key activation flips in-memory `sessionActivated`, fires Phase 10 `updateVisibility()` live-unlock, entitlement does NOT persist across relaunch (T-11-02) | ✓ VERIFIED (code) · timing+relaunch=manual | `SettingsView.swift:170` `sessionActivated = true` set BEFORE `:177` nudge write → `NotchWindowController.defaultsObserver:322` → `handleSettingsChanged:916` → `updateVisibility:955` re-reads `licenseState.isEntitled`. `sessionActivated` is a plain in-memory `var` (`LicenseState.swift:29`), never written to UserDefaults/Keychain → resets `false` on relaunch. |
| 6 | Adaptive section .trial/.trialExpired/.licensed render correct locked copy; License section first in Form (D-01/D-02) | ✓ VERIFIED (code) · visual=manual | `Form {` `:33` → `Section("License")` `:38` (FIRST child, before `Toggle("Launch Islet at login")` `:57`). Switch renders days line / `Text("3-day trial period expired").font(.headline)` / `Text("Licensed ✓")` only (`:39-54`). |

**Score:** 6/6 truths code-verified. Truth #3 carries an accepted WARNING (WR-01). Truths #1–6 all require a manual on-device / Cmd-U pass for the visual/interaction/lifetime portions (routed to the user).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Licensing/LicenseService.swift` | Protocol + error enum + StubLicenseService | ✓ VERIFIED | `protocol LicenseService: AnyObject`, `enum LicenseActivationError { invalidKey, unreachable(String) }`, `StubLicenseService.validKey = "ISLET-DEMO-OK"`, `DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)`. `#if DEBUG`-gated compare (Release rejects all — T-11-01). Stub is PURE (no `LicenseState` reference). 61 lines. |
| `Islet/Licensing/LicenseState.swift` | sessionActivated + .licensed short-circuit | ✓ VERIFIED | `var sessionActivated = false` (`:29`); `if sessionActivated { return .licensed }` (`:54`) positioned AFTER the `#endif` of the DEBUG override block, before trial computation. `isEntitled` maps `.licensed→true` unchanged. |
| `Islet/SettingsView.swift` | Adaptive License Section + state machine | ✓ VERIFIED | `Section("License")` first in Form; state machine + Buy Now + live-unlock wiring present. WR-01 warning noted. |
| `IsletTests/LicenseServiceTests.swift` | Async key→Result + main-thread tests | ✓ VERIFIED (logic) · run=manual | 4 tests: magic key→`.success`+`Thread.isMainThread`, `"NOPE-1234"`→`.failure(.invalidKey)`, whitespace-trimmed→`.success`, async proof (`completed` still false after call returns). `XCTestExpectation` + `wait(for:timeout:3.0)`. Cannot execute headlessly (see manual note). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `StubLicenseService.activate` | `DispatchQueue.main.asyncAfter` | ~1s main-thread completion | ✓ WIRED | `LicenseService.swift:48` |
| `LicenseState.status` | `.licensed` | `sessionActivated` short-circuit | ✓ WIRED | `LicenseState.swift:54` |
| `SettingsView` License Section | `LicenseState.shared.status` | `@State licenseStatus` re-read on onAppear + appearsActive | ✓ WIRED | `SettingsView.swift:12, 115, 120` |
| `SettingsView.activate()` | `licenseService.activate` | closure flips sessionActivated + nudge write | ✓ WIRED | `SettingsView.swift:167-178` |
| activation success | `NotchWindowController.updateVisibility` | UserDefaults.didChangeNotification | ✓ WIRED | `SettingsView.swift:177` → `NotchWindowController.swift:322-325` `defaultsObserver` → `handleSettingsChanged` → `updateVisibility` (re-reads `isEntitled`) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| License Section | `licenseStatus` | `LicenseState.shared.status` (computed: DEBUG override → sessionActivated → `TrialManager` trial computation) | Yes — real trial clock via TrialManager | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Compile gate | `xcodebuild build -scheme Islet` | BUILD SUCCEEDED (merged tree, per orchestrator) | ✓ PASS |
| Unit tests (D-05/D-06) | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` | HANGS headlessly (pre-existing env constraint) | ? SKIP → manual Cmd-U |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TRIAL-03 | 11-01, 11-02 | User can see the number of trial days remaining from the Settings window | ✓ SATISFIED (code) | `SettingsView.swift:40-44` days-remaining line driven by `LicenseState.status → .trial(daysRemaining:)`. Visual confirmation deferred to manual. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER in any of the 4 modified files | — | None |
| `SettingsView.swift` | 169-180 | Dead `activationPhase = .success` assignment (WR-01) | ⚠️ Warning | Green success line never renders; success still confirmed via `Licensed ✓` flip — not goal-blocking |
| `SettingsView.swift` | 144 | `.whitespaces` vs service `.whitespacesAndNewlines` mismatch (IN-01) | ℹ️ Info | Newline-only key wastes one round-trip; no correctness/security impact |

### Human Verification Required

The compile gate passed, all wiring/purity/persistence invariants are code-verified, and the unit-test logic is inspected-correct. The following require the user's interactive pass (all listed in `manual_verification` frontmatter):

1. **Run the test suite (Cmd-U)** — `xcodebuild test` hangs headlessly (test bundle hosted in the full app that boots the NSPanel/MediaRemote/IOBluetooth). Confirm the 4 `LicenseServiceTests` pass. Pre-existing repo constraint, not a Phase 11 defect.
2. **Live unlock** — expired/trial → Settings → paste `ISLET-DEMO-OK` → Activate → `⟳ Validating…` ~1s → `Licensed ✓`, island re-appears without restart.
3. **Buy Now** — click "Buy Islet — €7.99" → default browser opens `https://getislet.app`.
4. **Adaptive layout** — drive `.trial`/`.trialExpired`/`.licensed` via DEBUG `forceExpired`/`forceLicensed` + magic key; confirm each matches UI-SPEC.
5. **No persistence** — activate, quit + relaunch → app back in trial/expired (island locked).
6. **Menu-bar → Settings one-click** — confirm Phase 10 path still opens Settings in one action.

### Gaps Summary

No goal-blocking gaps. Every success criterion is implemented and wired in the codebase; the stub service is pure and protocol-isolated (clean Phase 12 swap seam); entitlement is in-memory-only (T-11-02 satisfied) and the live-unlock reuses Phase 10's `updateVisibility()` arbiter with correct set-before-write ordering.

One accepted deviation (WR-01): the locked D-04 copy "✓ License activated" (green) never renders because the section flips to "Licensed ✓" in the same render pass. This does not block the phase goal — the user still receives clear, unambiguous success feedback via the "Licensed ✓" section state, and the validating/failure status lines are reachable. Recommend the executor drop the dead `activationPhase = .success` assignment (or delay the `.licensed` flip ~0.8s to flash the green line) as low-priority polish, and align the empty-guard trimming to `.whitespacesAndNewlines` (IN-01) at the same time.

Status is **passed-with-manual** rather than plain passed because the visual, interaction, live-timing, relaunch-lifetime, and unit-test-execution portions of all six criteria cannot be confirmed programmatically in this headless environment and are routed to the user's Cmd-U / on-device pass.

---

_Verified: 2026-07-05T14:52:00Z_
_Verifier: Claude (gsd-verifier)_
