---
phase: 66
slug: men-bar-overflow-ice-style-mvp
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-28
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Third revision** — supersedes the spacer-technique version (2026-07-27) after D-07's
> second pivot back to debugging the private-CGS mechanism against live Ice.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing project standard, `IsletTests/` target, app-hosted per `project.yml`'s `TEST_HOST` config) |
| **Config file** | `Islet.xcodeproj` scheme `Islet` — no separate `.xctestplan` |
| **Quick run command** | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` for build verification; manual Cmd-U or real-launch debug-menu action for the on-device CGS behavior itself (cannot be scripted headlessly — private WindowServer state) |
| **Full suite command** | Same build command (build-only; full `xcodebuild test` remains unusable headless per project memory — TCC-wait precedent) |
| **Estimated runtime** | ~1-2 min (build); on-device UAT is human-paced |

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **After every plan wave:** Same build command
- **Before `/gsd:verify-work`:** A full on-device debugging/UAT checkpoint (enumeration + move + persistence + permission gate together) — RESEARCH.md's Pattern 1 (cheapest-first elimination: reinstall Ice → explicit permission gate → real-launch-vs-test-host comparison → deeper Ice comparison) must complete before production Controller rewiring, mirroring Plan 66-01's original blocking-spike-checkpoint structure. This phase is back to needing that structure — the now-superseded spacer-era validation's lighter "no spike gate" call no longer applies.
- **Max feedback latency:** ~120s (build) — on-device UAT and the CGS/Ice comparison work is human-paced, not latency-bounded

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-0X-0X | TBD | 0 | — | — | Ice.app is a real, launchable binary (not a dangling symlink) | env check | `brew reinstall --cask jordanbaird-ice` then verify bundle | ❌ W0 | ⬜ pending |
| 66-0X-0X | TBD | 0 | MENUBAR-04 | T-66-01 | `AXIsProcessTrusted()` gates all CGS enumeration/move calls (never runs un-gated) | unit + manual | `xcodebuild build` (gate function) + on-device grant/deny check | ❌ W0 | ⬜ pending |
| 66-0X-0X | TBD | TBD | MENUBAR-02 | — | Restored CGS move mechanism succeeds against live Ice comparison | manual on-device UAT | End-of-debugging-plan checkpoint | ❌ Depends on restoring + fixing the CGS mechanism first | ⬜ pending |
| 66-0X-0X | TBD | TBD | MENUBAR-03 | — | Hidden icons genuinely absent (reclamation, not occlusion) | manual on-device UAT | End-of-debugging-plan checkpoint | ❌ Same dependency as MENUBAR-02 | ⬜ pending |
| 66-0X-0X | TBD | TBD | D-03 | — | Third-party hidden/visible assignment persists across relaunch via Islet's own store + active re-apply | manual on-device UAT (kill/relaunch) | On-device relaunch check | ❌ `MenuBarOverflowAssignmentStore.swift` does not exist yet | ⬜ pending |

*(Full per-task map will be finalized once the planner assigns concrete task IDs.)*

---

## Wave 0 Requirements

- [ ] `brew reinstall --cask jordanbaird-ice` — Ice.app's cask receipt shows 0.11.12 installed, but the actual bundle is a dangling symlink to a deleted `/Applications/Ice.app`; D-07's live-comparison premise is a hard blocker until this is fixed
- [ ] Restore `IsletTests/MenuBarOverflowManualSpike.swift` from `git show adfbd70` — currently absent (deleted in Plan 66-03's cleanup)
- [ ] Add the explicit `AXIsProcessTrusted()` gate (Pitfall 1) — does not exist in any currently-live or git-historical version of this code; the deleted spike only printed the value, never branched on it
- [ ] New `MenuBarOverflowAssignmentStore.swift` (D-03's persisted third-party assignment) — does not exist anywhere yet; Ice's own `StatusItemDefaults`/`autosaveName` mechanism only covers Ice's own items, not third-party ones
- [ ] Remove or repurpose `IsletTests/MenuBarOverflowClampTests.swift` — tests the spacer-technique's pure clamp function (`clampedExpandedSpacerLength`), which has no role under the reverted CGS mechanism

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Live Ice.app comparison (CGS enumeration/window-list diff) | D-07 debugging premise | Requires a real running reference process on this exact hardware; not scriptable | Reinstall Ice, launch it, compare its live CGS enumeration/window list against Islet's restored spike using the techniques in RESEARCH.md's debugging methodology section |
| Accessibility permission grant/deny flow | MENUBAR-04 | TCC prompts and OS-level permission state are not scriptable/headless | Trigger the permission request, confirm the one-time popover per UI-SPEC.md, grant/deny and confirm the chevron-absent + Settings-row degraded state on deny |
| Cmd-drag another app's icon across the chevron | MENUBAR-02 | Native OS drag gesture — cannot be scripted via XCTest | Cmd-drag a real third-party menu-bar icon across the chevron, confirm it moves to the hidden section |
| Click chevron reveals/hides; hidden icons genuinely absent (not occluded) | MENUBAR-03 | Space-reclamation judgment requires human visual confirmation of true AppKit layout removal, not mere occlusion | Click chevron, confirm hidden icons appear inline and disappear again on re-click; confirm other icons shift into reclaimed space |
| Position persistence across relaunch (D-03, Islet's own store) | MENUBAR-01/02/03 | Requires killing/relaunching a hidden app — not scriptable | Hide an app's icon, quit and relaunch that app, confirm its icon reappears in the same hidden/visible grouping |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s (build-level); on-device UAT and live-Ice comparison are human-paced by design
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending — approval finalized once gsd-plan-checker verifies the plans built against this strategy
