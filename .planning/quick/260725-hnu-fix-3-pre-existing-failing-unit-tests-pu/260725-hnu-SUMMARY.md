---
phase: quick-260725-hnu
plan: 01
subsystem: testing
tags: [xctest, xcodebuild, cryptokit, aes-gcm, calendar, purity-seam]

requires:
  - phase: 63-meeting-hud
    provides: the regression sweep that surfaced these 4 pre-existing failures
provides:
  - Green Islet unit-test baseline (529 tests, 0 failures)
  - defaultQuickAddTime is genuinely wall-clock-free — its today-branch is decided solely by the injected `now`
  - Orphan-cleanup test asserts decrypted plaintext survival instead of unstable ciphertext
  - systemHUDCards assertions match the 9 shipped cards, with full prefix+suffix coverage restored
affects: [future regression sweeps, any phase touching CalendarGlance or the Settings activity cards]

tech-stack:
  added: []
  patterns:
    - "Pure Foundation seams take `now` as a parameter and must never call a wall-clock API internally — verified by the test, not just documented in a comment"
    - "Encrypted-file tests assert plaintext after a test-local decrypt; ciphertext bytes are never a stable comparison target under AES-GCM"

key-files:
  created: []
  modified:
    - Islet/Calendar/CalendarGlance.swift
    - IsletTests/ClipboardFileStoreTests.swift
    - IsletTests/SettingsViewTests.swift

key-decisions:
  - "Test decrypts fileA itself via AES.GCM.SealedBox(combined:) + AES.GCM.open — ClipboardFileStore.decrypt stayed private, no production API widened for testability (T-hnu-01)"
  - "suffix(3) -> suffix(4) fixed alongside the count assertion: with 9 cards, prefix(5)+suffix(3) silently skipped index 5 (capsLock), so the ordering test half-checked a card it was written to check"

patterns-established: []

requirements-completed: []

duration: 12min
completed: 2026-07-25
---

# Quick Task 260725-hnu: Fix 3 Pre-Existing Failing Unit Tests Summary

**Restored a green 529-test baseline by fixing one real purity defect in `defaultQuickAddTime` and two stale/invalid test assertions — with zero production behavior change.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-25T12:45Z
- **Completed:** 2026-07-25T12:57Z
- **Tasks:** 3 of 3
- **Files modified:** 3

## Accomplishments

### Task 1 — `defaultQuickAddTime` reads the injected `now` (commit `32b5e64`)

`Islet/Calendar/CalendarGlance.swift:81` guarded on `calendar.isDateInToday(selectedDay)`, reading the
real wall clock inside a function whose own doc comment (lines 9-10, 74-77) promises the opposite.
The two `defaultQuickAddTime` tests pin `now` to 2026-07-19 and therefore only passed when the
machine's clock happened to be that day.

Changed to `calendar.isDate(selectedDay, inSameDayAs: now)` — one expression, same guard shape.

Behavior-preserving in production: the sole call site, `Islet/Notch/NotchPillView.swift:4449`, passes
`now: Date()`, which makes the two expressions provably identical (verified by grep — that is the only
non-comment reference to the function anywhere in `Islet/`).

Result: `CalendarGlanceTests` — 19 tests, 0 failures, run on 2026-07-25 (deliberately **not** the
2026-07-19 the tests pin), which is precisely the condition that used to fail.

### Task 2 — plaintext-equality for the still-referenced image file (commit `08c58fa`)

`testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile` compared raw ciphertext bytes across two
`ClipboardFileStore.save` calls. Confirmed against the source: `save` re-encrypts every image on every
call (`ClipboardFileStore.swift:78`) and `AES.GCM.seal` draws a fresh nonce, so the ciphertext always
differs at identical length — the source of the confusing "41 bytes != 41 bytes" failure message.

Dropped the now-unused `fileAContentsBefore` capture and replaced the byte-equality assertion with a
test-local decrypt (`AES.GCM.SealedBox(combined:)` + `AES.GCM.open(_:using: testKey)`) compared against
`Data("image A bytes".utf8)`, plus a comment naming why byte-equality was wrong.

`Islet/Clipboard/ClipboardFileStore.swift` is untouched — `decrypt` stayed `private` (T-hnu-01 mitigated
as planned). The kept/deleted `fileExists` assertions were left exactly as they were.

Result: `ClipboardFileStoreTests` — 6 tests, 0 failures. No `fileAContentsBefore` identifier remains.

### Task 3 — corrected stale `systemHUDCards` assertions (commit `cf17509`)

Verified the production array first: `Islet/SettingsView.swift:175` returns 9 cards — charging, device,
focus, osd, calendarCountdown (`isNew: false`), then capsLock, downloadProgress, menuBarOverflow, update
(`isNew: true`). 5 old + 4 new, exactly as the plan described.

- `testSystemHUDCardsCount`: `8` -> `9` (the assertion that was failing; `95581c4` added the 9th card).
- `testSystemHUDCardsExistingBeforeNew`: `cards.suffix(3)` -> `cards.suffix(4)`. Not failing, but with 9
  cards `prefix(5)` covered 0-4 and `suffix(3)` covered 6-8, silently skipping index 5 (`capsLock`).
  `suffix(4)` makes prefix+suffix sum to the array length again.

`Islet/SettingsView.swift` untouched — the 9-card array was correct, the tests were stale.

Result: `SettingsViewTests` — 10 tests, 0 failures.

## Verification Results (actual, not expected)

| Gate | Result |
|------|--------|
| `xcodebuild test -scheme Islet -configuration Debug` | **529 tests, 0 failures** (293.8s) — `** TEST SUCCEEDED **` |
| `xcodebuild build -scheme Islet -configuration Debug` | `** BUILD SUCCEEDED **` |
| `git diff --stat HEAD~3 HEAD` | exactly 3 files, 8 insertions / 5 deletions |
| `CalendarGlance.swift` diff size | 1 insertion, 1 deletion (the single production line) |
| `ClipboardFileStore.swift` / `SettingsView.swift` modified? | No — both absent from the diff |

Diff scope confirmed:

```
 Islet/Calendar/CalendarGlance.swift      | 2 +-
 IsletTests/ClipboardFileStoreTests.swift | 7 +++++--
 IsletTests/SettingsViewTests.swift       | 4 ++--
```

## Deviations from Plan

None — the plan executed exactly as written. No deviation rules were triggered, no auto-fixes were
needed, no checkpoints were hit.

Two **count discrepancies between the plan's stated expectations and reality** are worth recording, since
neither is a failure but both mean the plan's numbers were slightly off:

1. **Full suite is 529 tests, not the 528 the plan quoted** from `63-04-SUMMARY.md`. Failures are 0, which
   is what matters, but the baseline figure in that summary was one test short of the current count.
2. **`SettingsViewTests` has 10 tests, not the 9 the plan's done-criteria stated.** All 10 pass.

Neither affects any success criterion. Recorded here rather than silently absorbed.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change. The one production
edit is a pure Foundation date comparison with no I/O and no privilege surface (T-hnu-02, accepted).

## Self-Check: PASSED

- `Islet/Calendar/CalendarGlance.swift` — FOUND, `isDateInToday` count in non-comment lines is 0
- `IsletTests/ClipboardFileStoreTests.swift` — FOUND, `fileAContentsBefore` count is 0
- `IsletTests/SettingsViewTests.swift` — FOUND, `systemHUDCards.count, 9` grep returns 1
- Commit `32b5e64` — FOUND
- Commit `08c58fa` — FOUND
- Commit `cf17509` — FOUND
- Post-commit deletion check on all 3 commits — no tracked files deleted
