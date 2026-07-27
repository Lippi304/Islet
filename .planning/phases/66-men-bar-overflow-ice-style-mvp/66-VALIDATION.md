---
phase: 66
slug: men-bar-overflow-ice-style-mvp
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-27
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing project standard, `IsletTests/` target) |
| **Config file** | `Islet.xcodeproj` scheme `Islet` — no separate `.xctestplan` found |
| **Quick run command** | Manual Xcode Cmd-U for the new spike test method — `xcodebuild test` hangs headless in this repo (documented project precedent) |
| **Full suite command** | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` (build-only; full `xcodebuild test` remains unusable headless) |
| **Estimated runtime** | ~1-2 min (build); Cmd-U spike is manual/on-device |

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`; manual Cmd-U spike run for any mechanism-touching task
- **After every plan wave:** Full `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** On-device UAT covering SC#1-#5 (per ROADMAP's own explicit spike/UAT mandate) must be green
- **Max feedback latency:** ~120s (build) — the on-device spike/UAT itself is human-paced, not latency-bounded

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-01-01 | 01 | 0 | MENUBAR-01/02/03 | — | N/A | manual (spike) | Cmd-U `MenuBarOverflowManualSpike.swift` | ❌ W0 | ⬜ pending |
| 66-0X-0X | TBD | TBD | MENUBAR-04 | V4 Access Control | Gate mechanism behind `AXIsProcessTrusted()` — nil/untrusted is a silent no-op, never a crash or dialog | unit + manual | `xcodebuild build` + manual permission-denied UAT | ❌ W0 | ⬜ pending |

*(Full per-task map will be finalized once the planner assigns concrete task IDs — this phase's Wave 0 spike gates everything downstream.)*

---

## Wave 0 Requirements

- [ ] `IsletTests/MenuBarOverflowManualSpike.swift` — covers MENUBAR-01/02/03, mirrors `MeetingMonitorManualSpike.swift` exactly (manual-only, Cmd-U, always-green assertion, human checklist referenced from the plan). This is the ROADMAP's own mandated on-device spike (Success Criteria #1) reading Ice's actual `MenuBarItemManager.swift`/`Bridging.swift` mechanism directly.
- [ ] Pure unit tests for the Accessibility permission 3-state mapping, mirroring `Islet/PermissionStatus.swift`'s existing pure-function style — **only if** MENUBAR-04's status card reuses/extends that rollup; otherwise `AXIsProcessTrusted()` is called directly like `OSDInterceptor`/`CapsLockMonitor` and needs no new mapping function (planner's call).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chevron separates visible/hidden sections | MENUBAR-01 | Visual menu-bar layout judgment; no scriptable assertion for real menu-bar rendering | Launch app, confirm chevron appears leftmost among Islet's own items, visually separating sections |
| Cmd-drag another app's icon across the chevron | MENUBAR-02 | Native OS drag gesture — cannot be scripted via XCTest | Cmd-drag a real third-party menu-bar icon (e.g. a system icon) across the chevron, confirm it moves to the hidden section |
| Click chevron reveals/hides; hidden icons genuinely absent (not just occluded) | MENUBAR-03 | Space-reclamation judgment (Pitfall 2 from RESEARCH.md) requires human visual confirmation that space is truly reclaimed, not merely covered by the frontmost app's menu | Click chevron, confirm hidden icons appear inline and disappear again on re-click; confirm reclaimed space is real (other icons shift, not just visually covered) |
| Accessibility permission denied → visible degradation | MENUBAR-04 | System permission dialogs and System Settings deep-links cannot be driven by XCTest | Deny Accessibility permission, confirm chevron does not appear and Settings shows the "Permission required" state with a working System Settings link |
| Sleep/wake and Dock-relaunch persistence (D-03) | MENUBAR-01/02/03 | Requires real sleep/wake cycle and killing/relaunching a hidden app — not scriptable | Hide an app's icon, sleep/wake the Mac, confirm it's still hidden; quit and relaunch the hidden app, confirm Islet re-applies the hidden assignment when its status item reappears |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s (build-level); on-device UAT is human-paced by design
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-27 (via gsd-plan-checker verification pass)
