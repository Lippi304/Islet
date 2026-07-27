---
phase: 66
slug: men-bar-overflow-ice-style-mvp
status: draft
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
| **Quick run command** | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` for pure-logic pieces (width-clamp math); manual Cmd-U or on-device run for the visual chevron/spacer behavior itself |
| **Full suite command** | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` (build-only; full `xcodebuild test` remains unusable headless — documented project precedent) |
| **Estimated runtime** | ~1-2 min (build); on-device UAT is human-paced |

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **After every plan wave:** Full `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** One on-device UAT checkpoint covering MENUBAR-01/02/03 (chevron appears, drag works, reveal/hide genuinely changes visible strip width) — lighter-weight than the superseded mechanism's blocking spike wave, per RESEARCH.md's finding that a full spike-gate is no longer warranted for this public-API-only technique
- **Max feedback latency:** ~120s (build) — on-device UAT is human-paced, not latency-bounded

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-0X-0X | TBD | TBD | MENUBAR-01 | — | N/A | manual on-device UAT (visual) | End-of-task checkpoint visual check | ❌ W0 | ⬜ pending |
| 66-0X-0X | TBD | TBD | MENUBAR-02 | — | N/A | manual on-device UAT (native OS gesture, not scriptable) | End-of-task checkpoint drag test | ❌ W0 | ⬜ pending |
| 66-0X-0X | TBD | TBD | MENUBAR-03 | — | N/A | manual on-device UAT (space-reclamation) + unit test for width-clamp math | `xcodebuild build` (pure fn) + visual check | ❌ W0 | ⬜ pending |

*(Full per-task map will be finalized once the planner assigns concrete task IDs.)*

---

## Wave 0 Requirements

- [ ] Unit test for the spacer's expanded-length clamp math (`min(max(candidate, lowerBound), currentScreenWidth)`-shaped pure function), if the implementation extracts it as a testable pure function — mirrors this project's existing pure-function testing style
- [ ] No existing test file covers any part of this phase — the superseded `IsletTests/MenuBarOverflowManualSpike.swift` tested the OLD (Ice) mechanism; per D-06, do not extend it for this mechanism

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Chevron separates visible/hidden sections | MENUBAR-01 | Visual menu-bar layout judgment; no scriptable assertion for real menu-bar rendering | Launch app, confirm chevron appears leftmost among Islet's own items, visually separating sections |
| Cmd-drag another app's icon across the chevron | MENUBAR-02 | Native OS drag gesture — cannot be scripted via XCTest | Cmd-drag a real third-party menu-bar icon across the chevron, confirm it moves to the hidden section |
| Click chevron reveals/hides; hidden icons genuinely absent (not just occluded) | MENUBAR-03 | Space-reclamation judgment requires human visual confirmation that space is truly reclaimed via AppKit layout removal, not merely covered | Click chevron, confirm hidden icons appear inline and disappear again on re-click; confirm other icons shift into the reclaimed space |
| Position persistence across relaunch (D-03, resolved via `NSStatusItem.autosaveName`) | MENUBAR-01/02/03 | Requires killing/relaunching a hidden app — not scriptable | Hide an app's icon, quit and relaunch that app, confirm its icon reappears in the same hidden/visible grouping |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s (build-level); on-device UAT is human-paced by design
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending — approval finalized once gsd-plan-checker verifies the plans built against this strategy
