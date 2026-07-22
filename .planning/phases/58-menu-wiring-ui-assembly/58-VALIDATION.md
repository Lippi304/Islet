---
phase: 58
slug: menu-wiring-ui-assembly
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-07-23
---

# Phase 58 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing target `IsletTests`, `project.yml:197-228`) |
| **Config file** | `project.yml` (XcodeGen-managed target definition) |
| **Quick run command** | Manual Cmd-U in Xcode (headless `xcodebuild test` hangs — see prior phase research) |
| **Full suite command** | Manual Cmd-U in Xcode, full `IsletTests` scheme |
| **Estimated runtime** | ~1-2 minutes (manual) |

---

## Sampling Rate

- **After every task commit:** Manual Cmd-U for any touched unit-testable logic (self-capture guard, eviction, file-store save/load — all pre-existing, should stay green untouched)
- **After every plan wave:** Full manual Cmd-U pass + on-device menu interaction smoke test (open menu, click a row, ⌘-select a row, Delete All)
- **Before `/gsd:verify-work`:** On-device UAT checkpoint covering all 4 ROADMAP success criteria (CLIP-01, CLIP-02, CLIP-03, CLIP-05) — inherently manual, matching every prior menu/UI-wiring phase in this project (Phase 48, Phase 53, Phase 54)
- **Max feedback latency:** N/A — manual verification, not watch-mode

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 58-01-* | 01 | 1 | CLIP-01 | — | MRU-first list, capped/evicted | unit (eviction) + manual UAT (rendering) | `Cmd-U` — `IsletTests/ClipboardStoreTests.swift` | ✅ (eviction) / manual UAT (rendering) | ⬜ pending |
| 58-01-* | 01 | 1 | CLIP-02 | — | Click restores to pasteboard, no auto-paste, no self-capture duplicate | manual on-device UAT | `Cmd-U` — `IsletTests/ClipboardMonitorTests.swift` (guard logic) | ✅ (guard logic) / manual UAT (end-to-end) | ⬜ pending |
| 58-01-* | 01 | 1 | CLIP-03 | — | ⌘0-⌘9 selects first 10 entries | manual on-device UAT | `Cmd-U` (if extracted as pure helper) or manual | ❌ — Wave 0 gap if extracted (Claude's Discretion) | ⬜ pending |
| 58-01-* | 01 | 1 | CLIP-05 | — | Delete All History confirms, then actually deletes on-disk | unit (save/load) + manual UAT (alert + wiring) | `Cmd-U` — `IsletTests/ClipboardFileStoreTests.swift` | ✅ (save/load) / manual UAT (alert) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. All underlying logic (`ClipboardStore`, `ClipboardFileStore`, `ClipboardMonitor`) already has test coverage from Phases 55-57 (`IsletTests/ClipboardStoreTests.swift`, `IsletTests/ClipboardFileStoreTests.swift`, `IsletTests/ClipboardMonitorTests.swift`). If the planner extracts a pure helper for ⌘0-⌘9 key-equivalent assignment or MRU-ordering, that is a new easily-testable addition but not a prerequisite gap.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu displays clipboard history section, MRU-first, alongside existing entries | CLIP-01 | Real `NSMenu` rendering cannot be meaningfully unit-tested | Click menu-bar icon; verify history section shows ≤30 items, newest first, existing Settings/Check for Updates/Quit still present |
| Click restores item to system pasteboard without auto-paste | CLIP-02 | Real `NSPasteboard`/`NSMenu` interaction | Click a history row; verify system pasteboard content changes and no paste occurs in frontmost app |
| ⌘0-⌘9 select first 10 entries | CLIP-03 | Real keyboard-driven `NSMenuItem` interaction, including the `NSMenuItem.view` + keyEquivalent interaction risk flagged in RESEARCH.md (Assumption A2) | Open menu, press ⌘0 through ⌘9, verify each selects/copies the corresponding entry |
| Delete All History confirms then deletes on-disk | CLIP-05 | `NSAlert` confirmation flow and end-to-end wiring | Trigger Delete All History; verify destructive-confirmation dialog appears; confirm; verify menu section empties and on-disk store file reflects empty state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Manual UAT checkpoint scheduled for all 4 success criteria
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
