---
phase: 60-caps-lock-hud-update-activity-restyle
verified: 2026-07-23T22:50:00Z
status: passed
score: 9/9 must-haves verified
overrides_applied: 0
---

# Phase 60: Caps Lock HUD + Update-Activity Restyle Verification Report

**Phase Goal:** Users get a lightweight Caps Lock on/off HUD matching the existing transient-wings pattern, and the existing Sparkle update-available HUD is reskinned to the same Droppy look — the cheapest possible pairing, proving the new Settings-grid card pattern before harder features land.
**Verified:** 2026-07-23T22:50:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria + RESEARCH.md open questions)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: Toggling Caps Lock shows a brief on/off HUD in the collapsed island, auto-dismissing ~1-2s, no click needed | ✓ VERIFIED | `Islet/Notch/NotchPillView.swift:2879-2914` `capsLockWings(for:)` renders `capslock.fill` + `"Caps Lock On"`/`"Caps Lock Off"` text; `NotchWindowController.swift:291` `capsLockActivityDuration: TimeInterval = 1.5` (self-elapsing, `.capsLock` excluded from `isPersistent`); on-device checkpoint (60-05-SUMMARY.md step 5) confirmed both directions + 3x rapid-toggle stress test |
| 2 | SC2: Event-driven via `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`, own Settings-grid card, default OFF | ✓ VERIFIED | `Islet/Notch/CapsLockMonitor.swift:62` uses the exact locked API; `Islet/ActivitySettings.swift:35,53-55` `capsLockKey` in `defaultsToFalseKeys`; `Islet/SettingsView.swift:203` Caps Lock card with `onOptionsTap` wired to permission popover |
| 3 | SC3: Update-available HUD shows Droppy-style layout (leading icon, "Update" label, trailing version pill); Sparkle trigger/tap-to-install unchanged | ✓ VERIFIED | `NotchPillView.swift:2926-2970` `updateWings(for:)` (icon+label left, `UpdateVersionPill` right); `AppDelegate.swift:403-407` unchanged `didFindValidUpdate` callback gains a second signal (`updateDotView` still unhidden, dot not removed per D-02); `AppDelegate.swift:153` `onUpdateInstallRequested = { self?.checkForUpdates() }` — real Sparkle install path, unchanged |
| 4 | SC4: Both activities respect the Settings grid's on/off toggle | ✓ VERIFIED | `NotchWindowController.swift:2446-2451` (Caps Lock stop+flush on toggle-off) and `:2456-2458` (Update flush on toggle-off, WR-01 fix); `handleCapsLockChange`/`handleUpdateAvailable` both gated via `activityEnabled(...)` at the monitor-lifecycle/handler level |
| 5 | CAPS-01 requirement closed | ✓ VERIFIED | REQUIREMENTS.md:87,217 marked `[x]`/"Complete"; full code chain (activity → resolver → monitor → wing) traced and present |
| 6 | UPDATE-01 requirement closed | ✓ VERIFIED | REQUIREMENTS.md:91,218 marked `[x]`/"Complete"; note ROADMAP/REQUIREMENTS wording ("reskinned") is stale per locked decision D-01 (no prior island HUD existed to reskin — this is a new build matching the same visual language), functionally satisfied regardless |
| 7 | RESEARCH.md Pitfall 3 (live Accessibility reconcile) resolved with recorded empirical answer | ✓ VERIFIED | `CapsLockMonitor.swift:44-56,73-86` — 5s health-check retry timer (`armHealthCheck()`/`install()`) added specifically because a single `AXIsProcessTrusted()` check could read `false` even post-grant; 60-05-SUMMARY.md records the empirical finding ("trust propagates and the monitor installs live, no relaunch required") and the on-device confirmation |
| 8 | RESEARCH.md Pitfall 4 (Update wing tap-target reliability) resolved with recorded empirical answer | ✓ VERIFIED | `updateWings(for:)` passes `onTap: onUpdateTap` (`wingsShape`'s new override, `NotchPillView.swift:2950`) into `AppDelegate.checkForUpdates()`; 60-05-SUMMARY.md records "confirmed reliable across 5+ repeated taps at different points on the wing... zero click-through," matching Plan 60-05's Task 2 step 7 acceptance bar (5+ trials, full wing width) |
| 9 | Code review (60-REVIEW.md) findings resolved before phase close | ✓ VERIFIED | WR-01 (Update toggle-off flush) at `NotchWindowController.swift:2456-2458`; WR-02 (`assert()` sanity checks) at `NotchPillView.swift:2894-2896,2947-2949`; WR-03 (dispatch hop) kept with documented rationale at `CapsLockMonitor.swift:75-79`; IN-03 (`capsLockMonitor?.stop()` style) at `NotchWindowController.swift:2914`; commit `dfe1a93 fix(60): address code review findings (WR-01, WR-02, IN-03)` |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/CapsLockActivity.swift` | Pure `.on`/`.off` value type + total mapping | ✓ VERIFIED | Exists, substantive, no stub markers |
| `Islet/Notch/UpdateActivity.swift` | Pure `version: String` value type | ✓ VERIFIED | Exists, substantive |
| `Islet/Notch/CapsLockMonitor.swift` | Accessibility-gated `NSEvent.flagsChanged` monitor | ✓ VERIFIED | Exists; includes dedup fix + health-check retry (both on-device bugfixes) |
| `Islet/Notch/IslandResolver.swift` | `.capsLock`/`.updateAvailable` ranks 5/6, collapsed-only branches | ✓ VERIFIED | Lines 71,102-103,122-123,175-178 |
| `Islet/Notch/NotchPillView.swift` | `capsLockWings(for:)`, `updateWings(for:)`, `UpdateVersionPill`, `wingsShape(onTap:)` | ✓ VERIFIED | All present, non-stub, includes on-device-tuned geometry + WR-02 asserts |
| `Islet/Notch/NotchWindowController.swift` | Monitor ownership, handlers, toggle-reconciliation, `activityEnabled` generalization | ✓ VERIFIED | `handleCapsLockChange`, `handleUpdateAvailable`, `triggerUpdateInstall`, `startCapsLockMonitor`, WR-01 fix, `defaultsToFalseKeys`-based `activityEnabled` |
| `Islet/AppDelegate.swift` | Second `didFindValidUpdate` signal, `onUpdateInstallRequested`, DEBUG-only spike hook | ✓ VERIFIED | Lines 153,277,330-332,403-407; spike hook confirmed inside `#if DEBUG`/`#endif` (257-396) |
| `Islet/ActivitySettings.swift` | `updateHudKey`, `defaultsToFalseKeys` (11 keys) | ✓ VERIFIED | Lines 35,45,53-55 |
| `Islet/SettingsView.swift` | Update Available card, Caps Lock permission popover | ✓ VERIFIED | Lines 66,203,212-215,414-415,729 |
| `IsletTests/IslandResolverTests.swift` | 6 new tests (collapsed-only, falls-through, preempt for both activities) | ✓ VERIFIED | Lines 721-790, real assertions, not stubs |
| `IsletTests/ActivitySettingsTests.swift` | `testUpdateHudKeyName`, `testDefaultsToFalseKeysCoversAllFalseDefaultActivities` | ✓ VERIFIED | Lines 157,161 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `CapsLockMonitor` | `NotchWindowController.handleCapsLockChange` | `onChange` closure | ✓ WIRED | `startCapsLockMonitor()` constructs monitor with `{ [weak self] isOn in self?.handleCapsLockChange(isOn) }` |
| `handleCapsLockChange`/`handleUpdateAvailable` | `TransientQueue` | `preempt`/`enqueue` (preempt only when head is `.focus`) | ✓ WIRED | Matches D-05 rank rule exactly — never preempts Charging/Device/OSD |
| `AppDelegate.didFindValidUpdate` | `NotchWindowController.handleUpdateAvailable` | direct call, additive to `updateDotView` unhide | ✓ WIRED | Dot NOT removed (D-02) |
| `updateWings` tap | `AppDelegate.checkForUpdates()` | `onTap: onUpdateTap` → `onUpdateInstallRequested` closure → `triggerUpdateInstall()` | ✓ WIRED | Full chain traced, confirmed reliable on-device (5+ taps, zero click-through per 60-05-SUMMARY.md) |
| Settings toggle (`updateHudEnabled`/`capsLockEnabled`) | HUD visibility | `activityEnabled(...)` + live-reconciliation flush | ✓ WIRED | WR-01 fix closes the one gap found by code review (Update transient not flushed on toggle-off) |

### Behavioral Spot-Checks

Not applicable in the traditional sense — this phase's two highest-risk behaviors (Accessibility TCC-state gating, click-through/tap-target geometry) are explicitly documented in this codebase's own established precedent (OSDInterceptor, Phase 40/42/48) as un-assertable via XCTest or headless commands. Verification instead relied on: (a) the unit tests confirmed above (pure resolver/queue logic), and (b) the blocking on-device checkpoint (Plan 60-05 Task 2, `type="checkpoint:human-verify" gate="blocking"`) that was executed and approved during phase execution, not deferred. That checkpoint's 11-step protocol is the authoritative behavioral check for this phase; its recorded results are summarized in the Observable Truths table above (rows 1, 7, 8).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CAPS-01 | 60-01, 60-02, 60-03, 60-04, 60-05 | Caps Lock on/off HUD, event-driven, Settings-gated | ✓ SATISFIED | Full chain verified above |
| UPDATE-01 | 60-01, 60-02, 60-03, 60-04, 60-05 | New Update HUD (Droppy layout), Sparkle plumbing unchanged | ✓ SATISFIED | Full chain verified above; D-01 clarifies "reskin" wording is stale, not a functional gap |

No orphaned requirements found — REQUIREMENTS.md maps only CAPS-01/UPDATE-01 to Phase 60, both claimed by plans.

### Anti-Patterns Found

None introduced by this phase. Grepped all 9 modified/created source files for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`/empty-implementation patterns — zero matches in Phase 60's own code. (Unrelated pre-existing `placeholder` comments in `NotchPillView.swift`/`NotchWindowController.swift`/`SettingsView.swift` concern album-art fallback UI and debug seed test data — predate this phase, out of scope.)

### Code Review Resolution

`60-REVIEW.md` frontmatter confirms `status: clean`, `resolved: 2026-07-23T20:45:00Z`. All 3 Warnings independently re-verified in source:
- **WR-01** (Update toggle-off doesn't flush standing/queued transient) — fixed, `NotchWindowController.swift:2456-2458`.
- **WR-02** (missing `assert()` sanity checks in `capsLockWings`/`updateWings`) — fixed, both wings now carry the same asserts `osdWings` has.
- **WR-03** (redundant `DispatchQueue.main.async` hop) — the review's own suggested fix was verified incorrect by the executor (removing the hop reintroduces a real compiler warning under this project's closure-isolation rules); the dispatch was kept with the missing rationale now documented inline. This is a reasonable engineering judgment call, not a dodge — the code comment explains why the review's suggested fix doesn't apply.
- IN-03 (style consistency) fixed; IN-01/IN-02 explicitly left as optional per the review's own text (not required for phase close).

### Human Verification Required

None outstanding. The phase's inherently non-XCTest-able behaviors (Accessibility TCC gating, click-through tap-target reliability, visual clipping/positioning) were verified via a blocking on-device checkpoint (Plan 60-05, Task 2) that was executed and approved during phase execution — this was not a deferred item. The checkpoint's own governing plan (`60-05-PLAN.md`) marks it `gate="blocking"` with an explicit `<resume-signal>` requiring the word "approved" or a described failure before execution could proceed to `60-05-SUMMARY.md`; the SUMMARY confirms all 11 steps passed and 4 real bugs were found and fixed along the way (a stronger signal than a routine approval, since a rubber-stamp "approved" would not typically surface 4 unscoped bugs and 6 commits).

### Gaps Summary

No gaps found. All 4 ROADMAP Success Criteria are backed by traceable, non-stub code. Both requirements (CAPS-01, UPDATE-01) are closed. Both RESEARCH.md open questions (Pitfall 3 live-reconcile, Pitfall 4 tap-target reliability) have recorded empirical answers, and the code changes those answers motivated (health-check retry timer, modifier-key dedup, wing geometry rebuild) are present and match the SUMMARY's narrative exactly. All 3 code-review Warnings are resolved in source, verified independently rather than trusted from the REVIEW.md frontmatter alone. Working tree is clean (no uncommitted changes) and all commits referenced in the 5 plan SUMMARYs are present in git log.

---

_Verified: 2026-07-23T22:50:00Z_
_Verifier: Claude (gsd-verifier)_
