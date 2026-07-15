---
phase: 34
slug: quick-action-destination-picker
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-15
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (XcodeGen `project.yml`) |
| **Config file** | `project.yml` — shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless in this project; see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual Cmd-U in Xcode (NOT `xcodebuild test`) |
| **Estimated runtime** | ~30-60s (build gate) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **After every plan wave:** Manual Cmd-U in Xcode (full `IsletTests` suite)
- **Before `/gsd:verify-work`:** Full suite must be green (manual Cmd-U), PLUS the mandatory on-device CR-01 hover→expand→move-down trace against the D-15 SMALLER card height, PLUS a real on-device AirDrop/Mail hand-off trial (still pending from the original spike), PLUS the NEW drag-in/drag-out/re-entry trace (confirms D-13b/Pitfall 6's discard-and-cleanup fires correctly)
- **Max feedback latency:** 60 seconds (build gate)

---

## Per-Requirement Verification Map (revision 2 — post-UAT drag-target model)

> Task-level IDs are assigned once the phase is replanned; this table maps requirements/decisions to test strategy per the refreshed RESEARCH.md "Validation Architecture" section.

| Requirement | Behavior | Test Type | Automated Command | File Exists? | Status |
|---------|----------|-----------|-------------------|-------------|--------|
| TRAY-02 | Picker shows DURING the drag (`dragEntered` edge), not after release | unit (extract `computeQuickActionButtonFrames`/hit-test math as a pure function, mirroring `isWithinDragAcceptRegion`/`expandedNotchFrame`) + manual on-device | `xcodebuild build -scheme Islet`; new pure-function unit test | ❌ Wave 0 | ⬜ pending |
| TRAY-03 | Release-on-"Drop" stages the file and switches to Tray | unit (`append`/`makeSessionCopy` already covered) + manual on-device (new release-on-target trigger path) | `xcodebuild build -scheme Islet`; manual Cmd-U | ⚠️ Partial Wave 0 — new hit-test-routing glue needs its own pure-function unit test | ⬜ pending |
| TRAY-04 | Release-on-"AirDrop"/"Mail" invokes `NSSharingService` | unit (`QuickActionSharingServiceTests.swift` already exists, unchanged) + manual on-device (real OS hand-off, still-pending spike) | `xcodebuild build -scheme Islet`; manual Cmd-U | ✅ Existing — new release-on-target routing needs the same pure-function unit test as TRAY-02 | ⬜ pending |
| D-13b / Pitfall 6 | Dragging out before release discards `pendingDrop` and cleans up the session-copy | unit (if `discardPendingDrop()` threaded through a testable seam) + manual on-device (no orphaned temp dirs after enter/exit-without-release) | `xcodebuild build -scheme Islet`; manual Cmd-U + manual filesystem check | ❌ Wave 0 | ⬜ pending |
| D-11 | Button under pointer highlights live during the drag | manual on-device only — pure rendering/feel check, not automatable | manual Cmd-U + on-device drag trace | N/A — manual by nature | ⬜ pending |
| D-04/D-05 | Charging/Device transient interrupts the picker; pending drop survives and resumes | unit — **no new coverage needed**, `resolve()`'s pure logic for `.quickActionPicker`/`pendingDrop` is UNCHANGED by this revision and already covered (`testPendingDropExpandedReturnsQuickActionPicker`, `testPendingDropOutranksSelectedViewFullTakeover`, `testChargingTransientOutranksPendingDrop`, `testPendingDropInertWhileNotExpanded`) | `xcodebuild build -scheme Islet` | ✅ Existing | ⬜ pending |
| D-06/D-07 | Dismissing without choosing discards the file(s), no auto-default | unit (controller-level, if extracted as pure/testable) + manual on-device (grace-collapse dismissal trigger) | `xcodebuild build -scheme Islet`; manual Cmd-U | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extract `computeQuickActionButtonFrames`/the button-column hit-test math as a standalone PURE function (mirrors `isWithinDragAcceptRegion`/`expandedNotchFrame`'s existing testable-seam convention) so TRAY-02/03/04's new hit-testing logic gets real unit coverage, not just manual on-device verification
- [ ] New test(s) for the Pitfall 6 fix — confirm `discardPendingDrop()` is actually called from `recheckDragAcceptRegion()`'s exit branch (controller-level integration test, or verified via the manual on-device filesystem check if a unit seam isn't practical)
- [ ] `IslandResolverTests.swift` — NO new coverage needed; the picker's precedence/resolver logic is unchanged by this revision and already has passing tests (see D-04/D-05 row above)
- [ ] Framework install: none — `IsletTests` target and `Islet` scheme already exist and are wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real AirDrop hand-off (system share sheet appears, transfer completes) | TRAY-04 | OS-level UI interaction with nearby devices cannot be automated or simulated in CI | Drop a file, drag-release over AirDrop, confirm the system AirDrop UI appears and a real device can receive the file |
| Real Mail.app compose-with-attachment hand-off | TRAY-04 | Requires Mail.app to actually launch/foreground and receive the attachment — OS-level, not automatable | Drop a file, drag-release over Mail, confirm Mail.app opens a new compose window with the file attached |
| CR-01 click-through trace for the picker's `visibleContentZone()` geometry at the NEW (117pt) card height | TRAY-02 | This project's own recurring failure mode (CR-01) — click-through hit-testing regressions are only caught by an actual hover→expand→move-down mouse trace on-device, not by any automated test | Hover to expand picker, move mouse down through the picker area, confirm clicks pass through/register correctly at every zone boundary |
| Charging/Device transient interrupting an open picker, then picker auto-resuming with same pending file(s) | D-04/D-05 | Requires physically plugging in a charger or connecting a Bluetooth device while the picker is open — hardware-triggered, not automatable | Open picker via file drop, plug in charger mid-picker, confirm charging splash shows then picker resumes with the same file still pending |
| Per-button live drag-hover highlight (fill 0.12→0.22, scale 1.0→1.04) tracks the pointer correctly across all 3 buttons | D-11 | Pure rendering/feel — requires an actual mouse drag over each button in turn | Drag a file over each of the 3 buttons in sequence, confirm each highlights only while the pointer is directly over it and un-highlights on move-off |
| Drag-in / drag-out / re-entry cycle without releasing (Open Question 3) | D-13b | New interaction surface (D-10 moves `pendingDrop` population earlier) with no prior precedent in this codebase — feel and correctness both need an on-device trace | Drag a file into the island, then out, then back in (without releasing) multiple times; confirm the picker appears/disappears correctly each time with no leaked temp files and no stuck state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
