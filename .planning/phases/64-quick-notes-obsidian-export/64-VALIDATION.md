---
phase: 64
slug: quick-notes-obsidian-export
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-25
---

# Phase 64 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (`@testable import Islet`) |
| **Config file** | `Islet.xcodeproj` / `project.yml` (xcodegen-managed), no separate test config |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only — do NOT run `xcodebuild test` headlessly; it hangs in this repo due to a Bluetooth TCC-authorization wait in `BluetoothMonitor`, documented in `PROJECT.md` line 425, reconfirmed at Phase 56/58/59) |
| **Full suite command** | Manual Cmd-U in Xcode (interactive session required) |
| **Estimated runtime** | ~30-60s build; Cmd-U suite is interactive, no fixed runtime |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet build`
- **After every plan wave:** Manual Cmd-U in Xcode for the full `IsletTests` suite (existing `ClipboardStoreTests`/`ClipboardFileStoreTests` as regression baseline, plus new `QuickNotes*Tests`)
- **Before `/gsd:verify-work`:** On-device UAT (popover-focus spike, Cmd+Return submit, TCC-prompt flow, mid-write-interrupt survival, Obsidian-open-during-write behavior) plus full suite green
- **Max feedback latency:** ~60 seconds (build-only per-task; full suite is manual/interactive per-wave)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 64-01-xx | 01 | 1 | NOTES-01/03 | — | `QuickNotesStore.append`/`.remove` — cap=30 FIFO eviction, per-row delete never touches vault file | unit | `xcodebuild build` + manual Cmd-U: `QuickNotesStoreTests.swift` | ❌ W0 | ⬜ pending |
| 64-01-xx | 01 | 1 | NOTES-03 | — | Load-never-throws, plaintext round-trip (no CryptoKit) | unit | `QuickNotesFileStoreTests.swift` | ❌ W0 | ⬜ pending |
| 64-01-xx | 01 | 1 | NOTES-02 | — | Day heading once per day, `- HH:mm text`, 2-space-indented continuation lines (D-05 exact format) | unit | `QuickNotesFormatterTests.swift` | ❌ W0 | ⬜ pending |
| 64-01-xx | 01 | 1 | NOTES-02 | T-64-security (write corruption) | Tail-read detects existing/stale/empty/no-trailing-newline day heading (D-06/D-07); atomic append never read-modify-write | unit | `QuickNotesVaultWriterTests.swift` — highest-priority test, data-loss-critical | ❌ W0 | ⬜ pending |
| 64-01-xx | 01 | 1 | NOTES-02 | T-64-security (silent failure) | Failed write never added to `QuickNotesStore` (D-12) | unit | Inject unwritable target path, assert `.items` unchanged | ❌ W0 | ⬜ pending |
| 64-02-xx | 02 | — | NOTES-01 | — | Popover opens, text typeable, Cmd+Return submits | manual-only | On-device UAT checklist item — Pitfall 10 spike | — | ⬜ pending |
| 64-02-xx | 02 | — | NOTES-02 | — | Vault content survives app-level crash mid-write | manual-only | On-device UAT checklist item | — | ⬜ pending |
| 64-02-xx | 02 | — | NOTES-02 | — | macOS TCC prompt on first protected-folder write appears, persists across relaunch | manual-only | On-device UAT checklist item, resolves Assumption A4 | — | ⬜ pending |
| 64-02-xx | 02 | — | NOTES-03 | — | Recent-notes list renders most-recent-first, plaintext, matches Clipboard History visual pattern | manual-only | On-device visual check (Phase 59 precedent) | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Exact Task IDs finalized once PLAN.md files exist — see PLAN.md `<verification>` blocks for authoritative mapping.*

---

## Wave 0 Requirements

- [ ] `IsletTests/QuickNotesStoreTests.swift` — covers NOTES-01/NOTES-03 (append/remove/cap/FIFO)
- [ ] `IsletTests/QuickNotesFileStoreTests.swift` — covers NOTES-03 (load-never-throws, plaintext round-trip; mirrors `ClipboardFileStoreTests.swift` minus encryption assertions)
- [ ] `IsletTests/QuickNotesFormatterTests.swift` — covers NOTES-02 (D-05 exact string format, including multi-line indentation)
- [ ] `IsletTests/QuickNotesVaultWriterTests.swift` — covers NOTES-02 (D-06/D-07 tail-read + append correctness against real temp-directory fixture files) — highest priority given Pitfall 7/11 data-loss stakes
- [ ] No new test framework/config needed — `IsletTests` target and XCTest already fully cover this phase's testing needs

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Popover opens from "New Note…" item, text is typeable, Cmd+Return submits | NOTES-01 | AppKit window-focus behavior not headlessly observable; this IS the Pitfall 10 spike | On-device: click "New Note…", type without any prior click into the field, confirm keystrokes land, press Cmd+Return, confirm submit |
| Vault content survives an app-level crash mid-write | NOTES-02 | Requires killing the process mid-append; not automatable in CI | Kill app process during an append in a debug build, reopen vault file, confirm prior content intact and uncorrupted |
| macOS TCC prompt appears on first write to a protected folder and persists across relaunch | NOTES-02 | TCC prompts are not headlessly triggerable | Pick a protected folder (e.g. under `~/Documents`), submit a note, confirm TCC prompt appears; relaunch app, confirm no repeat prompt |
| Recent-notes list renders most-recent-first, plaintext, visually matches Clipboard History | NOTES-03 | SwiftUI render verification is a visual check, not unit-testable per this project's existing convention (Phase 59 precedent) | On-device: submit several notes, confirm list order and visual styling |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
