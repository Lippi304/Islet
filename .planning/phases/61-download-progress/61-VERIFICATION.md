---
phase: 61-download-progress
verified: 2026-07-24T01:24:47Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
resolution:
  - item: "Scoped test suite (DownloadActivityTests + DownloadCoordinatorTests + IslandResolverTests, 101 tests) after e8a552c"
    result: "101/101 passed — confirmed via xcodebuild test in the orchestrator session (2026-07-24T03:29Z), after the verifier's own sandboxed session hit the documented Pitfall 5 hang. Includes the 3 new CR-01/WR-01 regression tests."
  - item: "CR-01 on-device re-check: download completing while Charging/Device is standing head"
    result: "User-confirmed on real hardware ('approved') — the promoted transient after Charging/Device's dismiss timer elapses is the download's done splash, not a stuck .inProgress spinner."
---

# Phase 61: Download-Progress Verification Report

**Phase Goal:** Dropping a file into ~/Downloads shows a live "downloading" indicator in the notch that clears to a brief "done" state on completion — the milestone's first genuinely new file-watching subsystem (FSEvents), proven once here before Coding-Progress reuses the same pattern.
**Verified:** 2026-07-24T01:24:47Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criteria) | Status | Evidence |
|---|---|---|---|
| 1 | Starting a real browser download shows a live "downloading" indicator within a couple seconds | ✓ VERIFIED | `DownloadMonitor.swift` watches `~/Downloads` via `FSEventStreamCreate` with `latency: 0.3` (well inside the "couple seconds" budget); `DownloadCoordinator.handle(_:)` enqueues `.downloadProgress(.inProgress)` on a matching `.created` reading (D-08); `downloadWings(for:)` renders the spinner. User-confirmed on real hardware per 61-05-SUMMARY.md UAT step 2 ("nein es klappt doch alles das ist das was ich meinte" — final approval after 4 visual-tuning rounds). |
| 2 | Temp-file rename to final filename shows a brief "done" state, then clears on its own | ✓ VERIFIED | `DownloadCoordinator`'s `.renamed` branch computes `.done(filename:)` via `downloadFilename(fromPath:)`; `ActiveTransient.isPersistent` is sub-state-aware (`.inProgress` true / `.done` false, `IslandResolver.swift:141-143`), so `.done` self-elapses via the shared ~3s dismiss timer (D-13). User-confirmed on-device (UAT step 2/3/4, Chrome/Edge/Firefox/Safari all confirmed). |
| 3 | Two rapid downloads are each detected as one logical download apiece, no double-fire | ✓ VERIFIED | Per-tempPath `inFlightDownloads` side table (D-06); `DownloadMonitor`'s `pendingRenamesByFileID` correlates rename halves via file ID across batches (Pitfall 2/3); D-05's "only most recent shown, others fire independently later" implemented via the `replaceHead`-vs-`enqueue` branch on `inFlightDownloads.isEmpty`. Covered by `DownloadCoordinatorTests` (`testTwoCreatedDifferentPathsBothTrackedSecondEnqueueDedupsNoOp`, `testTwoTrackedDownloadsFirstRenameEnqueuesSecondRenameReplacesHead`). User-confirmed on-device (UAT step 5). |
| 4 | Feature appears in Settings grid, default OFF, no indicator when disabled | ✓ VERIFIED | `Islet/SettingsView.swift:67` — `@AppStorage(ActivitySettings.downloadProgressKey) private var downloadProgressEnabled = false`; `Islet/SettingsView.swift:207` — card present in the grid (`isNew: true`); `ActivitySettings.swift:54` — `downloadProgressKey` is in `defaultsToFalseKeys`; `NotchWindowController.swift:650/2532-2537` gate monitor start/stop and flush on the same key. User-confirmed on-device (UAT steps 1 and 10). |

**Score:** 4/4 truths verified (all 4 ROADMAP Success Criteria)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `Islet/Notch/DownloadActivity.swift` | Pattern-1 seam: `DownloadEventKind`/`DownloadReading`/`DownloadActivity`/`isDownloadTempFile`/`downloadFilename` | ✓ VERIFIED | Exists, Foundation-only, matches spec exactly; 8 `DownloadActivityTests` present. |
| `Islet/Notch/DownloadCoordinator.swift` | Stateful per-tempPath coordinator, D-05/D-06/D-08/D-15 correlation, `reset()` | ✓ VERIFIED | Exists, conforms to `ActivityCoordinator`; 14 `DownloadCoordinatorTests` present including 3 CR-01/WR-01 regression tests added in `e8a552c`. `removeInProgress` closure present and correctly gates on `inFlightDownloads.isEmpty` in both the `.removed` path and the CR-01/WR-01 fix paths. |
| `Islet/Notch/DownloadMonitor.swift` | Real `FSEventStreamCreate` wrapper, top-level-only filtering, cross-batch rename correlation, `kFSEventStreamEventIdSinceNow` | ✓ VERIFIED | Exists; watches only `NSHomeDirectory()/Downloads` (D-07); `sinceWhen: kFSEventStreamEventIdSinceNow` (D-14); `deletingLastPathComponent == downloadsPath` top-level filter (Pitfall 1); `pendingRenamesByFileID` cross-batch correlation with a WR-03 cap-and-reset at 32 entries. |
| `Islet/Notch/IslandResolver.swift` | rank-5 `.downloadProgress` case, collapsed-only `resolve()`, sub-state `isPersistent`, `updateHead`/`removeAll(where:)` | ✓ VERIFIED | All present exactly as specified; `removeAll(where:)` correctly strips both `head` and `pending` (lines 396-406). |
| `Islet/Notch/NotchPillView.swift` | `downloadWings(for:)` real UI, `presentationSwitch` wired | ✓ VERIFIED | Present at line 940/2994; icon-only redesign (post-UAT), `.accessibilityLabel` added for WR-02; no `onTap` (D-11 preserved). |
| `Islet/Notch/NotchWindowController.swift` | Monitor ownership/lifecycle, coordinator construction, exhaustive-switch coverage, `deinit` teardown | ✓ VERIFIED | `downloadMonitor`/`downloadCoordinator` constructed and wired exactly like `capsLockMonitor`/`deviceCoordinator`; `TransientCategory`/`flushTransients`/`syncActivityModels` all cover `.downloadProgress`; `deinit` calls `downloadMonitor?.stop()` (line 3012). |
| `Islet/SettingsView.swift` | Settings-grid card, default OFF | ✓ VERIFIED | Card present, bound to `downloadProgressEnabled = false`. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `IslandResolver.swift` | `DownloadActivity.swift` | `case downloadProgress(DownloadActivity)` | ✓ WIRED | Present in both `IslandPresentation` and `ActiveTransient`. |
| `DownloadCoordinator.swift` | `IslandResolver.swift` | `ActiveTransient.downloadProgress(...)` via `enqueue`/`replaceHead`/`removeInProgress` closures | ✓ WIRED | Confirmed at `NotchWindowController.swift:523-557` — all 5 closures constructed and passed. |
| `DownloadCoordinator.swift` | `DownloadActivity.swift` | `isDownloadTempFile(path:)`/`downloadFilename(fromPath:)` | ✓ WIRED | Both helpers called inside `handle(_:now:)`. |
| `NotchWindowController.swift` | `DownloadMonitor.swift` | `DownloadMonitor(onEvent:)` → `downloadCoordinator.handle(_:)` | ✓ WIRED | `startDownloadMonitor()` constructs the monitor with a closure forwarding straight into `downloadCoordinator.handle(reading)`. |
| `NotchPillView.swift presentationSwitch` | `IslandPresentation.downloadProgress` | `case .downloadProgress(let activity): downloadWings(for: activity)` | ✓ WIRED | Line 940. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `downloadWings(for:)` | `activity: DownloadActivity` | `presentationSwitch` ← `IslandResolver.resolve()` ← `TransientQueue.head` ← `DownloadCoordinator.handle(_:)` ← `DownloadMonitor.onEvent` ← real `FSEventStreamCreate` callback | Yes | ✓ FLOWING — traced end-to-end from a live OS-level FSEvents callback through the coordinator's stateful correlation to the rendered wing; no static/hardcoded fallback found anywhere in the chain. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Debug build succeeds | `xcodebuild -configuration Debug build` | BUILD SUCCEEDED, no phase-file warnings | ✓ PASS |
| Release build succeeds | `xcodebuild -configuration Release build` | BUILD SUCCEEDED | ✓ PASS |
| Scoped test suite (DownloadActivityTests + DownloadCoordinatorTests + IslandResolverTests) | `xcodebuild test -only-testing:...` | "The test runner hung before establishing connection" — TEST FAILED to launch (not a test failure, a harness-launch failure) | ? SKIP — matches 61-RESEARCH.md's own documented Pitfall 5 (`xcodebuild test` hangs in non-interactive/sandboxed sessions); routed to human verification below. |
| Settings default-OFF | source read of `SettingsView.swift:67` | `= false` | ✓ PASS |
| No debt markers in phase files | `grep -n "TBD\|FIXME\|XXX"` across all Download*.swift + touched IslandResolver.swift/NotchWindowController.swift/NotchPillView.swift | Zero hits in this phase's own code (only pre-existing, unrelated "rank TBD" comments for FUTURE phases 62-67 in `IslandResolver.swift`'s reference table) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DL-01 | 61-01 through 61-05 | Live "downloading" indicator on download start | ✓ SATISFIED | Truth #1 above; REQUIREMENTS.md marks `[x]`. |
| DL-02 | 61-01 through 61-05 | Brief "done" state on rename-to-final-name, then clears | ✓ SATISFIED | Truth #2 above; REQUIREMENTS.md marks `[x]`. |

No orphaned requirements — REQUIREMENTS.md's Download-Progress section lists exactly DL-01/DL-02, both declared in every plan's frontmatter.

### Anti-Patterns Found

None blocking. One deliberate, labeled simplification:
- `Islet/Notch/DownloadMonitor.swift:38` — `// ponytail: cap-and-reset instead of proper LRU eviction` — explicitly documents the ceiling (a full-reset-on-overflow bound at 32 entries, WR-03's fix) and the upgrade path (timestamped eviction if unmatched entries become common). Not a stub — a labeled, intentional tradeoff with a stated trigger for revisiting it.

`61-UI-SPEC.md` was not updated to reflect the icon-only wing redesign that superseded Plan 61-03's original icon+text-label design (acknowledged directly in `61-05-SUMMARY.md`'s "Impact on plan" note, citing the same known gap from the Phase 38 Focus-wing precedent). Documentation-only drift, not a functional gap — informational, no action required this phase.

### Human Verification Required — RESOLVED

### 1. CR-01 race-condition re-check (post-UAT-approval fix) — ✓ RESOLVED

**Test:** Start a download while a Charging or Device transient is actively showing as the standing head. Let the download's temp file rename to its final name (completion) *before* the Charging/Device splash's own ~3s dismiss timer elapses. Then let that timer elapse naturally.
**Expected:** Once Charging/Device dismisses, the promoted head is the download's checkmark "done" splash (which then self-clears after ~3s) — never a permanently-stuck "Downloading…" spinner.
**Result:** User tested this exact scenario on real hardware and confirmed "approved" — the done splash promoted correctly, no stuck spinner.

### 2. Scoped test suite green after the CR-01/WR-01/WR-02/WR-03 fix commit — ✓ RESOLVED

**Test:** `xcodebuild test -only-testing:IsletTests/DownloadActivityTests -only-testing:IsletTests/DownloadCoordinatorTests -only-testing:IsletTests/IslandResolverTests`.
**Expected:** 101/101 scoped tests green (8 DownloadActivityTests + 14 DownloadCoordinatorTests + 79 IslandResolverTests) — includes the 3 new regression tests `e8a552c` added for CR-01/WR-01.
**Result:** Confirmed green (101/101, 0 failures) in the orchestrator session at 2026-07-24T03:29Z, run from outside the verifier's own sandboxed environment which hit the documented Pitfall 5 hang.

### Gaps Summary

No functional gaps. Every artifact, key link, and ROADMAP Success Criterion traces correctly end-to-end, including the CR-01 blocker fix found by code review (`e8a552c`), verified by direct source read AND a passing regression test AND a live on-device re-check of the exact race condition. Both items that required human input above are now resolved — phase verification status upgraded from `human_needed` to `passed`.

---

*Verified: 2026-07-24T01:24:47Z*
*Verifier: Claude (gsd-verifier)*
