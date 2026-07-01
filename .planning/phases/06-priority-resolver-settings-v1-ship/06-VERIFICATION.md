---
phase: 06-priority-resolver-settings-v1-ship
verified: 2026-07-01T22:37:31Z
status: gaps_found
score: 5/6 must-haves verified (includes 1 override)
overrides_applied: 1
overrides:
  - must_have: "The production build is signed, notarized, and stapled, opening cleanly on a second Mac"
    reason: "No paid Apple Developer account exists yet ($99/yr, D-15 carry-over, explicit CLAUDE.md constraint). scripts/release.sh's real notarize+staple path is fully implemented and gated correctly behind DEVELOPER_ID/NOTARY_PROFILE placeholders (verified in 06-05 and 06-12); the dry-run path was validated end-to-end. Real notarization is deferred until the account is purchased, not a missing implementation."
    accepted_by: "user"
    accepted_at: "2026-07-02T00:40:00Z"
gaps:
  - truth: "When several activities occur close together, the island shows them by a sensible priority without overlapping or glitching (ROADMAP SC #1 / COORD-01)"
    status: partial
    reason: >
      The pure resolver (resolve/TransientQueue) is correct and fully covered by 15/15
      passing unit tests. However, the independent 06-REVIEW.md code review (run against
      the same HEAD as this verification) found two real, still-unfixed logic defects
      introduced by the 06-07 gap-closure fixes themselves, both confirmed present by direct
      code read at the cited line numbers:
      WR-1 — pendingDeviceAddresses (NotchWindowController.swift:112-118, 768-773, 758-761)
      is a FIFO that can desync from transientQueue's own pending list once a disconnect
      transient evicts a different pending entry via maxDepth bound; triggerDeviceBatteryRefreshIfPromoted()
      then polls the wrong address and can apply device A's battery % under device B's
      name/glyph on the visible splash — a real "glitch" (wrong data shown), not cosmetic.
      WR-2 — flushTransients (NotchWindowController.swift:883-901) unconditionally cancels
      and restarts the shared ~3s dismiss timer even when the surviving head was never
      touched by the removal, so toggling one activity category off silently extends the
      on-screen time of an unrelated, already-standing splash for a different category.
    artifacts:
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "WR-1 (lines ~112-118, 758-773) and WR-2 (lines ~883-901) — see 06-REVIEW.md for full repro traces"
    missing:
      - "Fix WR-1: key pendingDeviceAddresses by (address, DeviceActivity) pair and match against the actually-promoted head instead of trusting FIFO position"
      - "Fix WR-2: only cancel/re-arm the dismiss timer when transientQueue.head actually changed as a result of the removal"
deferred: []
human_verification:
  - test: "06-07 Task 3 on-device checks: nil-address BT device splash, dismiss-timer re-arm on category promotion, second-device battery-poll correctness"
    expected: "All three findings behave as described in 06-07-PLAN.md's <how-to-verify>"
    why_human: "06-07-SUMMARY.md itself is still marked 'PAUSED at Task 3' / checkpoint never resolved in any later commit — no on-device confirmation exists in the repo history, and this is exactly the code path WR-1 (Observable Truth gap above) demonstrates a real defect in"
  - test: "06-08 Task 3 on-device checks: Now-Playing health-gate never false-flips while media streams; hover-pause holds a paused glance past 15s"
    expected: "Both behaviors hold as described in 06-08-PLAN.md's <how-to-verify>"
    why_human: "06-08-SUMMARY.md is still marked 'PAUSED at Task 3'; no later commit documents an on-device approval"
  - test: "06-10 Task 3 on-device checks: transport buttons never also toggle the island; all other tap regions still toggle correctly"
    expected: "Both behaviors hold as described in 06-10-PLAN.md's <how-to-verify>"
    why_human: "06-10-SUMMARY.md is still marked 'PAUSED at Task 3' / requirements-completed: [] with an explicit note not to mark COORD-01/NOW-01/NOW-02 done until approved; no later commit documents approval"
  - test: "Settings window live behavior: toggling each of the three activity switches actually starts/stops the corresponding monitor live, and picking a new accent swatch re-tints the wings/battery/equalizer immediately without a restart"
    expected: "Matches the code-level wiring in handleSettingsChanged/applyAccentIfChanged"
    why_human: "Wiring is confirmed correct by code read + passing unit/build checks, but the live visual re-tint and monitor start/stop was not exercised on-device in this verification pass"
---

# Phase 6: Priority Resolver, Settings & v1 Ship Verification Report

**Phase Goal:** All three activity sources coexist gracefully under one priority resolver, the user can configure which activities show and pick an accent/theme, and the app ships as a production notarized release.
**Verified:** 2026-07-01T22:37:31Z
**Status:** gaps_found
**Re-verification:** No — initial verification (no prior VERIFICATION.md existed; only 06-REVIEW.md and 06-UAT.md)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Charging outranks Device outranks Now Playing; a transient briefly wins even over expanded, then yields to ambient (COORD-01, 06-01) | VERIFIED | `Islet/Notch/IslandResolver.swift:34-50` `resolve()`; `IsletTests/IslandResolverTests.swift` 15/15 passing, incl. `testEnqueueWhileShowingEnqueuesBehind`, `testNoTransientWhilePlayingReturnsToWings` |
| 2 | Charging/Device transients enqueue and play sequentially without overlap, no glitching (COORD-01, 06-01/06-04) | FAILED (partial) | Pure `TransientQueue` logic verified + tested, BUT WR-1/WR-2 defects confirmed present in `NotchWindowController.swift` (see gap above) — a real "wrong device battery shown" and "unrelated splash duration silently extended" glitch |
| 3 | NotchPillView renders ONE IslandPresentation via a single switch, no if-chain (06-04) | VERIFIED | `Islet/Notch/NotchPillView.swift:121-136` single `switch presentation` over all 7 cases |
| 4 | Settings window: 3 independent toggles (default ON), curated ~5-6 swatch accent palette (default neutral), persisted via @AppStorage, survives restart (APP-03, 06-03) | VERIFIED | `Islet/SettingsView.swift` (3 `Toggle`s + palette `ForEach`), `Islet/ActivitySettings.swift` (6-swatch palette, index 0 = `.white` default, `@AppStorage`-compatible keys); controller reads the SAME keys (`activityEnabled`, `applyAccentIfChanged`) so live toggling and persistence are wired end-to-end |
| 5 | The Now Playing launch-time health check is re-verified and the production build is signed, notarized, and stapled, opening cleanly on a second Mac (ROADMAP SC #3) | PASSED (override) | Health-check half VERIFIED (06-05-SUMMARY.md D-16, on-device healthy). Notarize/staple half: override accepted 2026-07-02 — no paid Apple Developer account yet (D-15 carry-over); dry-run pipeline proven end-to-end, real notarization deferred until credentials exist |
| 6 | Gap-closure fixes (06-07..06-12) are behavior-preserving and code-complete per code review | VERIFIED (with 2 exceptions) | 06-REVIEW.md: 0 critical, 2 warnings (WR-1/WR-2, both independently reproduced by this verifier via direct code read), 3 info. All 124 unit tests pass; full `xcodebuild build` succeeds clean |

**Score:** 5/6 truths verified (includes 1 override)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/IslandResolver.swift` | Pure ranked resolver + bounded de-duped TransientQueue | VERIFIED | Exists, substantive, wired into controller, 15 unit tests green |
| `Islet/Notch/NotchWindowController.swift` | Owns TransientQueue, single dismiss, settings-gated monitor lifecycle | VERIFIED (wired) with 2 logic defects (WR-1/WR-2) | See gaps above |
| `Islet/Notch/NotchPillView.swift` | Single-switch render over IslandPresentation, tap-gesture scoped off transport buttons | VERIFIED | `switch presentation` (line 121); `wingsShape` shared tap helper; `mediaExpanded` scopes tap off the button row (06-10 fix) |
| `Islet/SettingsView.swift` | 3 toggles + accent palette UI | VERIFIED | Exists, substantive, renders `Toggle`s + palette `ForEach`, bound to `@AppStorage` |
| `Islet/ActivitySettings.swift` | Shared keys + palette + accent Environment key | VERIFIED | Exists, substantive, single source of truth read by both `SettingsView` and the controller |
| `Islet/Notch/BluetoothMonitor.swift` | Thin @MainActor IOBluetooth connect/disconnect monitor | VERIFIED | Exists, wired via `startBluetoothMonitor()`/`handleDevice` |
| `Islet/DeviceActivityState.swift` | (superseded) | CORRECTLY REMOVED | 06-09 deleted it as dead code (zero observers) — confirmed zero remaining references anywhere in the tree; not a regression |
| `scripts/release.sh` | archive→sign→dmg→notarize→staple pipeline, both .app and DMG stapled | PARTIAL / ORPHANED for real notarization | Pipeline exists and runs clean end-to-end for the dry-run path (confirmed structurally); the notarize/staple code paths themselves are unreachable/untested because both placeholders remain unfilled |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchWindowController.currentPresentation()` | `IslandResolver.resolve()` | direct function call, settings-gated inputs | WIRED | `NotchWindowController.swift:368-380` |
| `handlePower`/`handleDevice` | `TransientQueue.enqueue` | direct mutation + `presentTransientChange()` | WIRED | Lines 636, 744 |
| `scheduleActivityDismiss` | `TransientQueue.advance()` | one-shot `DispatchWorkItem` | WIRED | Lines 658-675 |
| `SettingsView` (`@AppStorage`) | `NotchWindowController.handleSettingsChanged()` | `UserDefaults.didChangeNotification` observer | WIRED | Lines 291-294, 833-872 |
| `ActivitySettings.accent(for:)` | `NotchPillView` (`\.activityAccent`) | `.environment(\.activityAccent, …)` on hosting view, re-injected on change | WIRED | Lines 826, 905-910; `NotchPillView.swift:51, 228, 248, 280, 300, 401` |
| `NotchWindowController.nowPlayingMonitor` | `NowPlayingService` protocol (not concrete class) | typed property | WIRED | Line 151 — matches CLAUDE.md's "isolate now-playing behind one protocol" mandate (06-11 fix) |
| `handleDevice` (nil-address reading) | splash still shown | fallthrough (no early return) | WIRED | Lines 712-729 (06-07 Finding 1 fix confirmed present) |
| `pendingDeviceAddresses` (FIFO) | `triggerDeviceBatteryRefreshIfPromoted()` | array `.first`/`.removeFirst()` | PARTIAL / BUGGY | Wired but logically unsound — WR-1, see gaps |
| `flushTransients` | `scheduleActivityDismiss` re-arm | unconditional call when `head != nil` | PARTIAL / BUGGY | Wired but over-eager — WR-2, see gaps |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `NotchPillView` wings/expanded views | `presentation` (`IslandPresentationState.presentation`) | `NotchWindowController.renderPresentation()` ← `resolve(...)` ← live `chargingState`/`transientQueue`/`nowPlayingState` | Yes | FLOWING |
| `SettingsView` toggles/accent | `@AppStorage` bound vars | `UserDefaults.standard` | Yes | FLOWING |
| Battery % on device splash | `DeviceActivity.connected(battery:)` | `BluetoothMonitor.battery(forAddress:)` via `scheduleDeviceBatteryRefresh` | Yes, but can attach to the WRONG address post-promotion | FLOWING (with WR-1 identity defect) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit test suite | `xcodebuild test -scheme Islet -destination 'platform=macOS'` | 124/124 tests passed, 0 failures | PASS |
| Resolver + presentation seams isolated | `-only-testing:IsletTests/IslandResolverTests -only-testing:IsletTests/NowPlayingPresentationTests` | 24/24 passed | PASS |
| Full Release-config build compiles | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | PASS |
| Real release pipeline (archive/sign/dmg/notarize) | not run (requires 10+ min archive + would still hit the unfilled-placeholder skip path per 06-12-SUMMARY.md's own last real run) | N/A — code-reviewed instead, matches 06-12-SUMMARY.md's documented last run (exit 0, SKIP banner, no `notarytool`/`stapler` invoked) | SKIP (evidence via prior documented run + static read) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention found in this project; no probes declared in phase PLANs. SKIPPED (no probe convention in this project).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| COORD-01 | 06-01, 06-04, 06-07, 06-09 | Activities coexist by sensible priority, no overlap/glitch | BLOCKED (partial) | Resolver logic + tests solid; WR-1/WR-2 real defects still present in shipped controller code |
| APP-03 | 06-03, 06-04, 06-06 | Minimal settings window: activity toggles + accent, persisted | SATISFIED | Verified above, full wiring confirmed |
| DEV-01 / DEV-02 | 06-02 (traced to Phase 5 in REQUIREMENTS.md) | Device connect/disconnect splash, event-driven, no polling | SATISFIED (functionally) but ORPHANED in traceability | `REQUIREMENTS.md` still lists `DEV-01`/`DEV-02` as `Phase 5 / Pending`; Phase 5's own 3 plans (05-01/02/03) were never executed (no SUMMARY files exist). The functionality was deliberately folded into Phase 6 instead (documented explicitly in `.planning/STATE.md`'s "Phase 5 status note" as an intentional scope merge, not neglect) and is code-complete + tested here. This is a documentation/traceability staleness issue, not a Phase 6 functional gap — flagged for the record. |
| NOW-01 / NOW-02 / NOW-03 | 06-08, 06-10, 06-11 (gap-closure, traced to Phase 4) | Now Playing correctness fixes | SATISFIED (code) / NEEDS HUMAN (on-device confirmation never completed — see Human Verification) | |
| APP-04 | 06-05, 06-12 (traced to Phase 0 in REQUIREMENTS.md, marked "Complete") | Signed+notarized+stapled distributable | BLOCKED — REQUIREMENTS.md's "Complete" status at Phase 0 is itself only a dry-run per `00-04-SUMMARY.md`'s own text ("documented Phase-6 carry-over"); Phase 6 (06-05/06-12) also left it as a dry-run. Real notarization has never happened at any phase. | `scripts/release.sh` still placeholder-gated |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchWindowController.swift` | 112-118, 758-773 | Logic defect (not a stub) — FIFO desync between `pendingDeviceAddresses` and `transientQueue.pending` (WR-1) | Warning | Can show a battery % from the wrong Bluetooth device on the live splash |
| `Islet/Notch/NotchWindowController.swift` | 883-901 | Logic defect (not a stub) — `flushTransients` always resets the shared dismiss timer, even for an untouched survivor (WR-2) | Warning | An unrelated settings toggle silently extends an already-standing splash's on-screen time |
| `Islet/Notch/NotchWindowController.swift` | 50-58 | Stale comment claims `NotchPillView` still observes `chargingState` for rendering (IN-1 in 06-REVIEW.md) — it was removed in 06-09 | Info | Misleading to future maintainers (first-time-programmer project per CLAUDE.md) |
| `IsletTests/IslandResolverTests.swift` | — | `TransientQueue.removeAll(where:)` has no direct unit test (IN-2), despite being exactly the function WR-2 lives in | Info | Coverage gap for the function most relevant to the WR-2 defect |
| `Islet/Notch/NotchPillView.swift` | 404-423 | `mediaExpanded`'s bottom-row `Spacer()`s/reserved boxes are now non-interactive dead zones after the 06-10 tap-gesture rescoping (IN-3) | Info | Documented, deliberate tradeoff per code comment — flagged per review's "no dead zones" check, not a functional bug |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any phase-touched file. No hardcoded-empty stub patterns found. `scripts/release.sh` uses `set -euo pipefail`, all variables quoted, no injection surface (confirmed by 06-REVIEW.md and independently re-read here).

## Human Verification Required

### 1. 06-07 gap-closure on-device checks (nil-address splash, dismiss-timer re-arm, second-device battery)

**Test:** Follow 06-07-PLAN.md Task 3's `<how-to-verify>`: (a) toggle Now Playing off after a "nicht verfügbar" state and confirm plain idle date/time; (b) connect a BT device, then quickly plug in the charger before the device splash elapses, confirm the device splash gets a fresh ~3s window after charging yields; (c) connect two BT devices in quick succession, confirm the second's splash eventually shows its OWN correct battery %.
**Expected:** All three pass as described.
**Why human:** `06-07-SUMMARY.md` is still literally marked "PAUSED at Task 3" with no later commit recording an on-device approval. Item (c) is exactly the scenario WR-1 (see gaps) demonstrates can fail under a slightly extended repro (3+ devices with a disconnect in between).

### 2. 06-08 gap-closure on-device checks (health-gate stability, paused-media hover-pause)

**Test:** Play music continuously 30+s while expanding/collapsing — confirm it never shows "nicht verfügbar" while media plays. Pause playback, expand, hover the transport controls past 15s — confirm the paused glance does not disappear under the pointer.
**Expected:** Both hold as described in 06-08-PLAN.md.
**Why human:** `06-08-SUMMARY.md` is still marked "PAUSED at Task 3"; no later commit documents approval.

### 3. 06-10 gap-closure on-device checks (transport-button tap isolation)

**Test:** Rapidly tap play/pause/next/previous in the expanded media view — confirm each ONLY triggers its own action and never also collapses/toggles the island. Tap the collapsed pill, wing glances, expanded idle view, and "unavailable" message — confirm all still toggle as before.
**Expected:** Both hold as described in 06-10-PLAN.md.
**Why human:** `06-10-SUMMARY.md` is still marked "PAUSED at Task 3" / `requirements-completed: []`, explicitly instructing not to mark COORD-01/NOW-01/NOW-02 complete until approved; no later commit documents approval.

### 4. Settings window live visual behavior

**Test:** Open Settings, flip each of the three activity toggles off/on and confirm the corresponding monitor actually starts/stops (e.g., toggling Charging off makes a plug-in event produce no splash); pick a different accent swatch and confirm the battery indicator, equalizer bars, and device glyph all re-tint immediately without an app restart.
**Expected:** Matches the code-level wiring traced in `handleSettingsChanged`/`applyAccentIfChanged`.
**Why human:** Code wiring is confirmed correct by static read + a clean build/test pass, but the live, on-screen re-tint and toggle-driven monitor lifecycle was not exercised on a running instance in this verification pass.

## Gaps Summary

Phase 6's core architecture — the pure `IslandResolver`/`TransientQueue` reducer, the settings/accent system, and the gap-closure refactors (protocol extraction, dead-code removal, tap-gesture rescoping) — is real, substantive, well-tested (124/124 green), and matches the codebase's own high documentation/teaching standard. APP-03 is fully achieved.

Two things keep this phase from a clean PASS:

1. **COORD-01 is not fully achieved.** The independent code review that just landed alongside this gap-closure wave (06-REVIEW.md) found two genuine, still-unfixed logic defects in the very code this phase's gap-closure work touched: a battery-identity FIFO desync (WR-1) that can show a live splash with one device's name and a different device's battery %, and an over-eager dismiss-timer reset (WR-2) that lets an unrelated settings toggle silently extend an unrelated splash's on-screen time. Both were independently re-confirmed by this verifier via direct code read at the cited line numbers — this is not merely trusting the review's SUMMARY claim.

2. **ROADMAP Success Criterion #3 (production notarized release) is not achieved.** `scripts/release.sh` remains gated behind two unfilled placeholders; the app has only ever shipped as an ad-hoc-signed dry run at any phase (including the "Complete" APP-04 status recorded against Phase 0, which was itself a dry run per its own SUMMARY). This is a well-documented, deliberate deferral pending a paid Apple Developer account — not a hidden implementation gap — but it is still a roadmap contract item that is objectively not true in the codebase today.

**This looks intentional for item 2.** To accept the notarized-release deferral as out of scope for this milestone close, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "The production build is signed, notarized, and stapled, opening cleanly on a second Mac"
    reason: "No paid Apple Developer account exists yet ($99/yr); deliberately deferred per D-15/D-01 across Phase 0 and Phase 6, consistent with CLAUDE.md's stated distribution constraint. Dry-run pipeline is proven end-to-end and will produce a real notarized build the moment credentials are filled in."
    accepted_by: "<your name>"
    accepted_at: "<ISO timestamp>"
```

Item 1 (WR-1/WR-2) does not look intentional — both are unaddressed defects newly introduced by the 06-07 fix itself, with no evidence of a deliberate accepted tradeoff (06-REVIEW.md classifies them as Warnings requiring a fix, not an accepted disposition). A short follow-up gap-closure plan targeting `NotchWindowController.swift`'s `pendingDeviceAddresses` and `flushTransients` is recommended before closing the milestone.

---

_Verified: 2026-07-01T22:37:31Z_
_Verifier: Claude (gsd-verifier)_
