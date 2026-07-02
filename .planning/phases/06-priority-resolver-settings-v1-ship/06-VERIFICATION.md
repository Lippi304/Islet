---
phase: 06-priority-resolver-settings-v1-ship
verified: 2026-07-01T23:22:00Z
status: human_needed
score: 6/6 must-haves verified (includes 1 override)
overrides_applied: 1
overrides:
  - must_have: "The production build is signed, notarized, and stapled, opening cleanly on a second Mac"
    reason: "No paid Apple Developer account exists yet ($99/yr, D-15 carry-over, explicit CLAUDE.md constraint). scripts/release.sh's real notarize+staple path is fully implemented and gated correctly behind DEVELOPER_ID/NOTARY_PROFILE placeholders (verified in 06-05 and 06-12); the dry-run path was validated end-to-end. Real notarization is deferred until the account is purchased, not a missing implementation."
    accepted_by: "user"
    accepted_at: "2026-07-02T00:40:00Z"
re_verification:
  previous_status: gaps_found
  previous_score: "5/6 (includes 1 override)"
  gaps_closed:
    - "Charging/Device transients enqueue and play sequentially without overlap, no glitching (COORD-01) — WR-1 (battery-poll FIFO desync) and WR-2 (over-eager dismiss-timer reset) both fixed in 06-13 via matchPendingBatteryPoll identity-match and an oldHead-guarded flushTransients; confirmed by direct code read, not just SUMMARY claim, plus 131/131 passing unit tests including 7 new WR-1/WR-2 regression tests, and a fresh independent 06-REVIEW.md pass confirming both fixes present and correct with no regression."
  gaps_remaining: []
  regressions: []
gaps: []
deferred: []
human_verification:
  - test: "06-07 gap-closure on-device checks (nil-address splash, dismiss-timer re-arm, second-device battery)"
    expected: "Toggling Now Playing off after 'nicht verfügbar' shows plain idle date/time; connecting a device then quickly plugging in the charger gives the device splash a fresh ~3s window after charging yields; connecting two BT devices in succession shows each its OWN correct battery %."
    why_human: "06-07-SUMMARY.md is still marked 'PAUSED at Task 3' with no later commit recording an on-device approval. 06-13 fixed the underlying WR-1 identity-desync logic bug at the code/unit-test level, but the original Task 3 on-device checkpoint for 06-07's other findings (nil-address splash, dismiss-timer re-arm) was never itself completed."
  - test: "06-08 gap-closure on-device checks (health-gate stability, paused-media hover-pause)"
    expected: "Playing music continuously 30+s while expanding/collapsing never shows 'nicht verfügbar'. Pausing playback, expanding, and hovering the transport controls past 15s keeps the paused glance visible under the pointer."
    why_human: "06-08-SUMMARY.md is still marked 'PAUSED at Task 3'; no later commit documents approval."
  - test: "06-10 gap-closure on-device checks (transport-button tap isolation)"
    expected: "Rapidly tapping play/pause/next/previous in the expanded media view only triggers its own action, never also collapses/toggles the island; the collapsed pill, wing glances, expanded idle view, and 'unavailable' message still all toggle as before."
    why_human: "06-10-SUMMARY.md is still marked 'PAUSED at Task 3' / requirements-completed: [], explicitly instructing not to mark COORD-01/NOW-01/NOW-02 complete until approved; no later commit documents approval."
  - test: "Settings window live visual behavior (toggle-driven monitor lifecycle + accent re-tint)"
    expected: "Flipping each of the three activity toggles off/on actually starts/stops the corresponding monitor (e.g. toggling Charging off makes a plug-in event produce no splash); picking a different accent swatch re-tints the battery indicator, equalizer bars, and device glyph immediately without an app restart."
    why_human: "Code wiring is confirmed correct by static read + a clean build/test pass. Note for the human tester: 06-REVIEW.md's WR-02 finding (see Anti-Patterns / non-blocking issues below) documents that the accent-change code path fully re-hosts the SwiftUI view (`NSHostingView` replacement) rather than updating an existing `@Published` model in place — watch specifically for a visible flash/reset of the island (and equalizer bar reshuffle) at the moment the accent swatch is changed, not just whether the new color eventually appears."
---

# Phase 6: Priority Resolver, Settings & v1 Ship Verification Report

**Phase Goal:** All three activity sources coexist gracefully under one priority resolver, the user can configure which activities show and pick an accent/theme, and the app ships as a production notarized release.
**Verified:** 2026-07-01T23:22:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure plan 06-13 (WR-1/WR-2 transient-queue fixes)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Charging outranks Device outranks Now Playing; a transient briefly wins even over expanded, then yields to ambient (COORD-01, 06-01) | VERIFIED | `Islet/Notch/IslandResolver.swift:34-50` `resolve()`; `IsletTests/IslandResolverTests.swift` — resolver suite green |
| 2 | Charging/Device transients enqueue and play sequentially without overlap, no glitching (COORD-01, 06-01/06-04/06-13) | VERIFIED | Previously FAILED (WR-1/WR-2). Now fixed in 06-13: `matchPendingBatteryPoll(_:promoted:)` (`Islet/Notch/IslandResolver.swift:66-90`) matches the promoted device by `DeviceActivity` identity, not FIFO position, replacing `pendingDeviceAddresses` with `pendingDeviceBatteryPolls` throughout `NotchWindowController.swift` (confirmed zero remaining references via `grep -rn "pendingDeviceAddresses" Islet/`, empty result); `flushTransients` (`NotchWindowController.swift:900-920`) now captures `oldHead` before `removeAll(where:)` and gates the dismiss-timer cancel/re-arm behind `transientQueue.head != oldHead`. Both confirmed present and correctly wired by direct code read (not just SUMMARY claim). 131/131 unit tests pass, including 7 new regression tests covering the identity-match and head-unchanged/head-changed invariants. Independent `06-REVIEW.md` (run fresh against this same code) explicitly confirms "the previously-reported gap-closure defects... are present and correctly fixed in the current code... no regression found there." |
| 3 | NotchPillView renders ONE IslandPresentation via a single switch, no if-chain (06-04) | VERIFIED | `Islet/Notch/NotchPillView.swift` single `switch presentation` |
| 4 | Settings window: 3 independent toggles (default ON), curated ~5-6 swatch accent palette (default neutral), persisted via @AppStorage, survives restart (APP-03, 06-03) | VERIFIED | `Islet/SettingsView.swift` (3 `Toggle`s + palette `ForEach`), `Islet/ActivitySettings.swift` (6-swatch palette, `@AppStorage`-compatible keys); controller reads the same keys, wired end-to-end |
| 5 | The Now Playing launch-time health check is re-verified and the production build is signed, notarized, and stapled, opening cleanly on a second Mac (ROADMAP SC #3) | PASSED (override) | Health-check half VERIFIED (06-05-SUMMARY.md D-16, on-device healthy). Notarize/staple half: override accepted 2026-07-02 — no paid Apple Developer account yet; dry-run pipeline proven end-to-end, real notarization deferred until credentials exist |
| 6 | Gap-closure fixes (06-07..06-13) are behavior-preserving and code-complete per code review | VERIFIED (4 non-blocking warnings noted) | Fresh full-scope `06-REVIEW.md` (16 files, standard depth): 0 critical, 4 warnings (WR-01 accent-tint inconsistency, WR-02 accent-change view-tree rehost, WR-03 missing `withAnimation` on health-check callback, WR-04 low-probability BluetoothMonitor data race), 3 info. All are polish/consistency/theoretical-risk issues, not functional breaks of any must-have truth (see Anti-Patterns below). 131/131 unit tests pass; full `xcodebuild build` succeeds clean. |

**Score:** 6/6 truths verified (includes 1 override)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/IslandResolver.swift` | Pure ranked resolver + bounded de-duped TransientQueue + WR-1 identity-match helper | VERIFIED | `PendingBatteryPoll` struct + `matchPendingBatteryPoll(_:promoted:)` added (lines 66-90), Foundation-only (1 import), 131 unit tests green |
| `Islet/Notch/NotchWindowController.swift` | Owns TransientQueue, single dismiss, settings-gated monitor lifecycle, identity-safe battery poll matching, head-guarded timer reset | VERIFIED | `pendingDeviceBatteryPolls` fully replaces `pendingDeviceAddresses` (0 references remain); `triggerDeviceBatteryRefreshIfPromoted()` (line 778) calls `matchPendingBatteryPoll`; `flushTransients` (line 900) captures `oldHead` and guards on line 914 |
| `IsletTests/IslandResolverTests.swift` | WR-1/WR-2 regression coverage | VERIFIED | `testMatchPendingBatteryPollFindsByIdentityNotFIFOPosition` + 4 more identity-match tests (lines 159-210) + 2 `removeAll(where:)` head-invariant tests (lines 212-235+) |
| `Islet/Notch/NotchPillView.swift` | Single-switch render over IslandPresentation, tap-gesture scoped off transport buttons | VERIFIED | `switch presentation`; `mediaExpanded` scopes tap off the button row |
| `Islet/SettingsView.swift` | 3 toggles + accent palette UI | VERIFIED | Exists, substantive, bound to `@AppStorage` |
| `Islet/ActivitySettings.swift` | Shared keys + palette + accent Environment key | VERIFIED | Single source of truth read by both `SettingsView` and the controller |
| `Islet/Notch/BluetoothMonitor.swift` | Thin @MainActor IOBluetooth connect/disconnect monitor | VERIFIED (WR-04 theoretical data race noted, non-blocking) | Exists, wired via `startBluetoothMonitor()`/`handleDevice` |
| `scripts/release.sh` | archive→sign→dmg→notarize→staple pipeline, both .app and DMG stapled | PARTIAL / ORPHANED for real notarization (override accepted) | Dry-run path proven end-to-end; real notarize/staple unreachable without paid Developer ID |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchWindowController.currentPresentation()` | `IslandResolver.resolve()` | direct function call, settings-gated inputs | WIRED | unchanged, still correct |
| `handlePower`/`handleDevice` | `TransientQueue.enqueue` | direct mutation + `presentTransientChange()` | WIRED | unchanged |
| `triggerDeviceBatteryRefreshIfPromoted()` | `IslandResolver.matchPendingBatteryPoll(_:promoted:)` | direct function call, identity match | WIRED (fixed) | `NotchWindowController.swift:778-783` — replaces the old buggy FIFO pop; confirmed by code read |
| `flushTransients` | `dismissWorkItem` cancel/re-arm | `oldHead != transientQueue.head` guard | WIRED (fixed) | `NotchWindowController.swift:900-920` — confirmed the guard sits before the cancel/re-arm block, exactly as planned |
| `SettingsView` (`@AppStorage`) | `NotchWindowController.handleSettingsChanged()` | `UserDefaults.didChangeNotification` observer | WIRED | unchanged |
| `ActivitySettings.accent(for:)` | `NotchPillView` (`\.activityAccent`) | `.environment(\.activityAccent, …)`, re-injected via full view-tree rehost | WIRED (functionally), but re-hosts rather than live-updates (WR-02, non-blocking per review) | `NotchWindowController.swift:924-929` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `NotchPillView` wings/expanded views | `presentation` | `NotchWindowController.renderPresentation()` ← `resolve(...)` ← live state | Yes | FLOWING |
| Battery % on device splash | `DeviceActivity.connected(battery:)` | `BluetoothMonitor.battery(forAddress:)` via `matchPendingBatteryPoll`-selected address | Yes, and now attaches to the CORRECT address post-promotion (WR-1 fixed) | FLOWING (defect closed) |
| `SettingsView` toggles/accent | `@AppStorage` bound vars | `UserDefaults.standard` | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit test suite (post-06-13) | `xcodebuild test -scheme Islet -destination 'platform=macOS'` | 131/131 tests passed, 0 failures | PASS |
| Full build compiles | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | PASS |
| `pendingDeviceAddresses` fully removed | `grep -rn "pendingDeviceAddresses" Islet/` | empty result | PASS |
| WR-1/WR-2 fix code present at cited locations | direct `Read` of `IslandResolver.swift:66-90` and `NotchWindowController.swift:755-920` | matches plan's described logic exactly | PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention found in this project; no probes declared in phase PLANs. SKIPPED (no probe convention in this project).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| COORD-01 | 06-01, 06-04, 06-07, 06-09, 06-13 | Activities coexist by sensible priority, no overlap/glitch | SATISFIED | Resolver logic + tests solid; WR-1/WR-2 defects fixed in 06-13, confirmed by code read + tests + independent review |
| APP-03 | 06-03, 06-04, 06-06 | Minimal settings window: activity toggles + accent, persisted | SATISFIED | Verified above, full wiring confirmed |
| DEV-01 / DEV-02 | 06-02 (traced to Phase 5 in REQUIREMENTS.md) | Device connect/disconnect splash, event-driven, no polling | SATISFIED (functionally) but ORPHANED in traceability | `REQUIREMENTS.md` still lists `DEV-01`/`DEV-02` as `Phase 5 / Pending`; Phase 5's own plans were never executed. Functionality was deliberately folded into Phase 6 instead (documented in `.planning/STATE.md`), code-complete + tested here. Documentation/traceability staleness, not a functional gap. |
| NOW-01 / NOW-02 / NOW-03 | 06-08, 06-10, 06-11 (gap-closure, traced to Phase 4) | Now Playing correctness fixes | SATISFIED (code) / NEEDS HUMAN (on-device confirmation for 06-08/06-10 checkpoints never completed) | See Human Verification |
| APP-04 | 06-05, 06-12 (traced to Phase 0 in REQUIREMENTS.md) | Signed+notarized+stapled distributable | OVERRIDE ACCEPTED — real notarization deferred pending paid Apple Developer account | `scripts/release.sh` remains placeholder-gated for the real path; dry-run proven end-to-end |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchPillView.swift` | 223-229, 275-302 | WR-01 (non-blocking, new in 06-REVIEW.md): charging wing tints the battery bar but not the bolt glyph; device wing tints the glyph but not the battery bar — inconsistent with each other and the documented D-11 spec | Warning (non-blocking) | Visual inconsistency only — accent still applies and persists; does not break the APP-03 "set an accent/theme" truth |
| `Islet/Notch/NotchWindowController.swift` | 922-929 | WR-02 (non-blocking, new in 06-REVIEW.md): `applyAccentIfChanged()` fully re-hosts (`NSHostingView` replacement) instead of updating an `@Published` model in place, breaking `matchedGeometryEffect` continuity at that one mutation site | Warning (non-blocking) | Potential visible flash/reset when changing accent mid-morph/expanded; flagged into the existing "Settings live visual behavior" human-verification item for the tester to specifically watch for |
| `Islet/Notch/NotchWindowController.swift` | 331-343 | WR-03 (non-blocking, new in 06-REVIEW.md): health-check-driven presentation update not wrapped in `withAnimation`, unlike every other mutation site | Warning (non-blocking) | Rare one-off jarring snap instead of spring, only if health flips while expanded |
| `Islet/Notch/BluetoothMonitor.swift` | 40-45, 150-156 | WR-04 (non-blocking, new in 06-REVIEW.md): `nonisolated(unsafe)` token dictionaries theoretically racy between `deinit` and a scheduled main-queue callback | Warning (non-blocking, low-probability, pre-existing project-wide pattern) | No observed crash; mirrors existing `PowerSourceMonitor` pattern |
| (info items IN-01/IN-02/IN-03 from 06-REVIEW.md) | various | Dead `deviceSuppressedAtLaunch` state, magic-number duplication, asymmetric device-disable cleanup | Info | Non-functional code-quality notes |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any phase-touched file. No hardcoded-empty stub patterns found.

## Human Verification Required

See frontmatter `human_verification` for full detail. Summary:

### 1. 06-07 gap-closure on-device checks (nil-address splash, dismiss-timer re-arm, second-device battery)
**Why human:** `06-07-SUMMARY.md` still marked "PAUSED at Task 3"; 06-13 fixed the WR-1 code-level defect but did not itself complete this original on-device checkpoint.

### 2. 06-08 gap-closure on-device checks (health-gate stability, paused-media hover-pause)
**Why human:** `06-08-SUMMARY.md` still marked "PAUSED at Task 3"; no later commit documents approval.

### 3. 06-10 gap-closure on-device checks (transport-button tap isolation)
**Why human:** `06-10-SUMMARY.md` still marked "PAUSED at Task 3" / `requirements-completed: []`; no later commit documents approval.

### 4. Settings window live visual behavior (toggle lifecycle + accent re-tint)
**Why human:** Wiring confirmed correct by static read + clean build/test, but live on-screen behavior wasn't exercised on-device. Note: `06-REVIEW.md`'s WR-02 finding means the tester should watch specifically for a view flash/reset at the moment of an accent change, not just eventual color correctness.

## Gaps Summary

The one previously-open code-level gap — COORD-01's WR-1 (battery-poll identity desync) and WR-2 (over-eager dismiss-timer reset) — is now closed. Both fixes were independently verified in this pass by direct code read (not SUMMARY trust): `matchPendingBatteryPoll` replaces FIFO-position trust with `DeviceActivity` identity matching, and `flushTransients` now gates its dismiss-timer reset on `transientQueue.head != oldHead`. 131/131 unit tests pass (124 pre-existing + 7 new WR-1/WR-2 regression tests), the full app builds clean, and a fresh independent code review (`06-REVIEW.md`) explicitly confirms both fixes are present and correct with no regression.

The notarization override from the prior verification pass carries forward unchanged (no paid Apple Developer account yet; deliberate, documented deferral).

Four human-verification items carry forward from the prior verification pass, none closed by 06-13 (which was scoped only to the WR-1/WR-2 code fix, not to completing the still-paused on-device checkpoints from 06-07/06-08/06-10, or to exercising Settings' live visual behavior). Per the decision tree, outstanding human-verification items place this phase at `human_needed` rather than `passed`, even though all code-level truths are now verified.

`06-REVIEW.md`'s four new Warning findings (WR-01 accent-tint inconsistency, WR-02 accent-change view-tree rehost, WR-03 missing `withAnimation`, WR-04 theoretical BluetoothMonitor race) are treated as known non-blocking issues per this verification's scope — none was found to violate a must-have truth outright (accent still applies and persists; Settings toggles still work; no crash observed). They are recorded here for the record and to inform human-verification item #4, not re-opened as new gaps requiring a fresh closure cycle.

---

_Verified: 2026-07-01T23:22:00Z_
_Verifier: Claude (gsd-verifier)_
