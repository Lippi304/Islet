---
phase: quick-260725-hnu
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Islet/Calendar/CalendarGlance.swift
  - IsletTests/ClipboardFileStoreTests.swift
  - IsletTests/SettingsViewTests.swift
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "`xcodebuild test -only-testing:IsletTests/CalendarGlanceTests` passes on ANY calendar date, not only 2026-07-19 — defaultQuickAddTime's today-branch is decided by the injected `now`, never the wall clock."
    - "`xcodebuild test -only-testing:IsletTests/ClipboardFileStoreTests` passes — the orphan-cleanup test asserts fileA's DECRYPTED plaintext still equals image A's original bytes, instead of comparing ciphertext that necessarily differs on every AES.GCM.seal (fresh nonce)."
    - "`xcodebuild test -only-testing:IsletTests/SettingsViewTests` passes — the card-count assertion matches SettingsView.systemHUDCards' actual 9 entries."
    - "Production behavior is unchanged: the only non-test edit is a same-day comparison that is mathematically identical for every existing caller (all pass `now: Date()`)."
    - "No new production API was added to ClipboardFileStore just to satisfy a test."
  artifacts:
    - path: "Islet/Calendar/CalendarGlance.swift"
      provides: "Pure, wall-clock-free defaultQuickAddTime(selectedDay:now:)"
      contains: "isDate(selectedDay, inSameDayAs: now)"
    - path: "IsletTests/ClipboardFileStoreTests.swift"
      provides: "Plaintext-equality assertion for the still-referenced image file"
      contains: "AES.GCM.open"
    - path: "IsletTests/SettingsViewTests.swift"
      provides: "systemHUDCards count assertion matching the 9 shipped cards"
      contains: "systemHUDCards.count, 9"
  key_links:
    - from: "IsletTests/CalendarGlanceTests.swift"
      to: "defaultQuickAddTime(selectedDay:now:)"
      via: "injected `now` fully determines the today/not-today branch"
      pattern: "inSameDayAs: now"
    - from: "IsletTests/ClipboardFileStoreTests.swift"
      to: "AES-GCM sealed box on disk"
      via: "test-local decrypt with the same testKey (CryptoKit already imported by this test file)"
      pattern: "AES\\.GCM\\.(SealedBox|open)"
---

<objective>
Fix the 4 pre-existing failing unit tests in the Islet suite (all unrelated to Phase 63, all
confirmed pre-existing by 63-03-SUMMARY.md and 63-04-SUMMARY.md). Diagnosis is already done —
do NOT re-investigate.

Three root causes, two of them test bugs and one a real (if currently benign) purity defect:

1. **Real code defect, zero production impact.** `defaultQuickAddTime(selectedDay:now:)` calls
   `calendar.isDateInToday(selectedDay)`, reading the real wall clock instead of the injected
   `now`. Its own doc comment claims the opposite ("`now` is ALWAYS an explicit parameter --
   never Date()/Date.now inside this function"). The two `defaultQuickAddTime` tests pin
   `now` to 2026-07-19 and therefore only pass if the machine's clock happens to be that day.
2. **Test bug.** `testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile` compares raw
   ciphertext bytes across two `ClipboardFileStore.save` calls. `save` re-encrypts every image
   on every call and `AES.GCM.seal` draws a fresh nonce, so the ciphertext always differs at
   identical length — hence the confusing "41 bytes != 41 bytes" failure message.
3. **Stale test.** `testSystemHUDCardsCount` expects 8; `SettingsView.systemHUDCards` has had
   9 entries since `95581c4 feat(60-03): add Update Available Settings card`.

Purpose: get the suite green so future regression sweeps have a clean baseline.
Output: three minimal diffs (1 production line, 2 test files). No refactoring, no new API.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@Islet/Calendar/CalendarGlance.swift
@IsletTests/CalendarGlanceTests.swift
@IsletTests/ClipboardFileStoreTests.swift
@Islet/Clipboard/ClipboardFileStore.swift
@IsletTests/SettingsViewTests.swift
</context>

<interfaces>
<!-- Contracts the executor needs. No codebase exploration required. -->

Islet/Calendar/CalendarGlance.swift:78 — the function under repair (Foundation-only, pure seam):
`func defaultQuickAddTime(selectedDay: Date, now: Date) -> Date`

Its ONLY production call site, Islet/Notch/NotchPillView.swift:4449:
`let seed = defaultQuickAddTime(selectedDay: selectedDay, now: Date())`
Because that caller passes `Date()`, `isDateInToday(selectedDay)` and
`isDate(selectedDay, inSameDayAs: now)` are equivalent in production. The change is
behavior-preserving for shipping code and purity-restoring for tests.

Islet/Clipboard/ClipboardFileStore.swift — relevant surface:
```swift
static func load(root: URL, key: SymmetricKey) -> [ClipboardItem]
static func save(_ items: [ClipboardItem], root: URL, key: SymmetricKey) throws
static func deleteOrphanedImageFile(at fileURL: URL, root: URL)
private static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data
private static func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data
```
`encrypt`/`decrypt` are **private** — the test cannot call them, and this plan does NOT bump
their access level. `IsletTests/ClipboardFileStoreTests.swift` already has `import CryptoKit`
at line 3, so the test decrypts fileA itself with `AES.GCM.SealedBox(combined:)` +
`AES.GCM.open(_:using:)` — the exact two calls `ClipboardFileStore.decrypt` makes internally.

Islet/SettingsView.swift:175 — `var systemHUDCards: [ActivityCardData]` currently returns 9
elements, in this order: charging, device, focus, osd, calendarCountdown (all `isNew: false`),
then capsLock, downloadProgress, menuBarOverflow, update (all `isNew: true`). That is 5 old +
4 new.
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Make defaultQuickAddTime read the injected now, not the wall clock</name>
  <files>Islet/Calendar/CalendarGlance.swift</files>
  <action>
    At line 81, replace the guard condition `calendar.isDateInToday(selectedDay)` with
    `calendar.isDate(selectedDay, inSameDayAs: now)`. That is the entire change — one
    expression, same line, same guard shape, same else-branch.

    Do NOT touch the doc comment above the function (lines 74-77) — it already describes the
    corrected behavior; the code was the thing that lied. Do NOT touch `nextRelevantEvent`,
    `nextUpcomingEvent`, `daysInMonth`, or the `NotchPillView` call site. Do NOT edit
    `IsletTests/CalendarGlanceTests.swift` — the two failing tests are already correct and are
    the regression lock for this fix.
  </action>
  <verify>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; grep -v '^//' Islet/Calendar/CalendarGlance.swift | grep -c 'isDateInToday'</automated>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; xcodebuild test -scheme Islet -configuration Debug -only-testing:IsletTests/CalendarGlanceTests 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    `isDateInToday` count is 0 in non-comment lines of CalendarGlance.swift.
    `CalendarGlanceTests` passes in full, including
    `testDefaultQuickAddTimeForTodayReturnsNextFullHour` and
    `testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary`, on today's real date
    (2026-07-25 — deliberately NOT the 2026-07-19 the tests pin `now` to, which is precisely
    the condition that used to fail).
  </done>
</task>

<task type="auto">
  <name>Task 2: Assert decrypted plaintext, not ciphertext, for the still-referenced image file</name>
  <files>IsletTests/ClipboardFileStoreTests.swift</files>
  <action>
    In `testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile`:

    - Delete line 86, `let fileAContentsBefore = try Data(contentsOf: fileA)`. It becomes
      unused after this fix and Swift would emit an unused-value warning.
    - Replace line 91, `XCTAssertEqual(try Data(contentsOf: fileA), fileAContentsBefore)`, with
      a decrypt-then-compare against image A's original plaintext. Read fileA's bytes, wrap
      them in `AES.GCM.SealedBox(combined:)`, open with `AES.GCM.open(_:using: testKey)`, and
      `XCTAssertEqual` the result to `Data("image A bytes".utf8)` — the exact literal
      `imageItemA` was constructed from on line 77. Both calls are `throws`; the test is
      already `throws`, so `try` suffices, no `XCTUnwrap`/do-catch needed. `import CryptoKit`
      is already present at line 3.
    - Add a one-line comment on the new assertion naming WHY byte-equality was wrong:
      `save` re-encrypts on every call and `AES.GCM.seal` draws a fresh nonce, so the
      ciphertext legitimately differs while the plaintext must not.

    Keep line 90's `XCTAssertTrue(FileManager.default.fileExists(atPath: fileA.path))` and
    line 92's `XCTAssertFalse(...fileB...)` exactly as they are — those already cover the
    kept/deleted halves of the test's intent.

    Do NOT change `Islet/Clipboard/ClipboardFileStore.swift` at all. In particular, do NOT bump
    `decrypt`'s access level from `private` — the test does its own CryptoKit decrypt precisely
    so no production API grows for a test's sake. Do NOT touch the other five tests in this file.
  </action>
  <verify>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; git diff --name-only -- Islet/Clipboard/ClipboardFileStore.swift | grep -c . ; test $? -eq 1</automated>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; xcodebuild test -scheme Islet -configuration Debug -only-testing:IsletTests/ClipboardFileStoreTests 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    `ClipboardFileStoreTests` passes all 6 tests, including
    `testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile`.
    `ClipboardFileStore.swift` is untouched in the diff (git reports no change to it).
    No `fileAContentsBefore` identifier remains in the file.
  </done>
</task>

<task type="auto">
  <name>Task 3: Correct the stale systemHUDCards count assertions</name>
  <files>IsletTests/SettingsViewTests.swift</files>
  <action>
    Two edits, same stale-by-one-card root cause (`95581c4` added the 9th "Update Available"
    card and neither assertion was updated):

    - Line 39: `XCTAssertEqual(SettingsView().systemHUDCards.count, 8)` -> `..., 9)`. This is
      the assertion that currently fails.
    - Line 57 in `testSystemHUDCardsExistingBeforeNew`: `for card in cards.suffix(3)` ->
      `cards.suffix(4)`. This one does not currently fail, but with 9 cards `prefix(5)` covers
      indices 0-4 and `suffix(3)` covers 6-8, silently skipping index 5 (`capsLock`). The
      production array is 5 old + 4 new, so `suffix(4)` restores full coverage and makes
      prefix+suffix sum to the array length again. Same fix, same commit — leaving it means the
      ordering test half-checks a card it was written to check.

    Do NOT touch `Islet/SettingsView.swift` — the 9-card array is correct; the test was stale.
    Do NOT touch `testMediaCardsCount` (2), `testProductivityCardsCount` (5), or any of the
    `visibleSections` tests.
  </action>
  <verify>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; grep -v '^\s*//' IsletTests/SettingsViewTests.swift | grep -c 'systemHUDCards.count, 9'</automated>
    <automated>cd /Users/lippi304/conductor/workspaces/notch/algiers &amp;&amp; xcodebuild test -scheme Islet -configuration Debug -only-testing:IsletTests/SettingsViewTests 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    The `systemHUDCards.count, 9` grep returns 1.
    `SettingsViewTests` passes all 9 tests, including `testSystemHUDCardsCount` and
    `testSystemHUDCardsExistingBeforeNew`.
    `Islet/SettingsView.swift` is untouched in the diff.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| disk -> ClipboardFileStore.load | AES-GCM ciphertext read back from Application Support; already hardened (D-04 returns `[]` on any failure). Not modified by this plan. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-hnu-01 | Information Disclosure | `ClipboardFileStore.decrypt` access level | mitigate | Test performs its own CryptoKit decrypt with a test-local `SymmetricKey`; `decrypt` stays `private`, no production decrypt surface is widened for testability. |
| T-hnu-02 | Tampering | `defaultQuickAddTime` behavior change | accept | Sole production caller passes `now: Date()`, making `isDate(selectedDay, inSameDayAs: now)` provably identical to `isDateInToday(selectedDay)`. Pure Foundation seam, no I/O, no privileges. |
| T-hnu-SC | Tampering | package installs | accept | No package-manager step in this plan — zero dependency changes (Swift/Xcode-native only). |
</threat_model>

<verification>
Full-suite regression sweep after all three tasks, comparing against the documented
pre-existing baseline (63-04-SUMMARY.md: 528 tests, 4 failures):

```
cd /Users/lippi304/conductor/workspaces/notch/algiers && \
  xcodebuild test -scheme Islet -configuration Debug 2>&1 | tail -40
```

Expected: 528 tests, **0 failures**. Any failure count above 0 means either an in-scope fix
regressed or a NEW pre-existing failure surfaced — report it, do not silently absorb it.

Debug build gate (this project's standard, PROJECT.md-documented):

```
cd /Users/lippi304/conductor/workspaces/notch/algiers && \
  xcodebuild build -scheme Islet -configuration Debug 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

Diff-scope gate — exactly three files, one of them production, one line of production change:

```
cd /Users/lippi304/conductor/workspaces/notch/algiers && git diff --stat
```

Expected: `Islet/Calendar/CalendarGlance.swift` (1 insertion, 1 deletion),
`IsletTests/ClipboardFileStoreTests.swift`, `IsletTests/SettingsViewTests.swift`. Nothing else.
</verification>

<success_criteria>
- `xcodebuild test -scheme Islet -configuration Debug` reports 0 failures (was 4).
- `xcodebuild build -scheme Islet -configuration Debug` reports BUILD SUCCEEDED.
- `git diff --stat` lists exactly the 3 files in `files_modified`, no others.
- `Islet/Calendar/CalendarGlance.swift` diff is exactly one line (`isDateInToday(selectedDay)`
  -> `isDate(selectedDay, inSameDayAs: now)`).
- `Islet/Clipboard/ClipboardFileStore.swift` and `Islet/SettingsView.swift` are unmodified.
- The CalendarGlance fix holds independent of the machine date — the two `defaultQuickAddTime`
  tests pass today (2026-07-25), which is not the 2026-07-19 they pin `now` to.
</success_criteria>

<output>
Create `.planning/quick/260725-hnu-fix-3-pre-existing-failing-unit-tests-pu/260725-hnu-SUMMARY.md` when done.
</output>
