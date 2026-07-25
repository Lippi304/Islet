---
status: diagnosed
phase: 64-quick-notes-obsidian-export
source: [64-01-SUMMARY.md, 64-02-SUMMARY.md, 64-03-SUMMARY.md, 64-04-SUMMARY.md]
started: 2026-07-25T15:45:00Z
updated: 2026-07-25T15:58:00Z
---

## Current Test

[testing paused — 4 items outstanding]

## Tests

### 1. Vault folder selection (Settings → Quick Notes → options)
expected: Pick a real folder under ~/Documents via the options button; path persists and displays.
result: pass
verified: Implied by test 3 succeeding (a note was saved to the vault file, which requires a valid folder to be set).

### 2. Popover keyboard focus on open (Pitfall 10 / A1)
expected: Menu-bar icon → "New Note…" → without clicking, start typing immediately; characters land in the TextEditor.
result: issue
reported: "Tippen ohne Klick geht nicht, also das Eingabefeld hat nicht direkt Fokus."
severity: major

### 3. Multi-line note + Cmd+Return submit (Pitfall 10 / A2)
expected: Type a multi-line note, Cmd+Return submits while TextEditor still has focus; field clears, new note appears at top with HH:mm.
result: pass
reported: "Direkt speichern mit Befehl funktioniert das."

### 4. TCC permission prompt (first write + no repeat on relaunch)
expected: macOS TCC prompt appears on first protected-folder write; granting it persists — no repeat prompt on second write after relaunch.
result: pending

### 5. Vault file format (D-05 exact shape)
expected: `## YYYY-MM-DD` heading, `- HH:mm <text>` bullets, 2-space-indented continuation lines.
result: pending

### 6. Crash survival during write (Pitfall 7 — highest stakes)
expected: Force-quit Islet during/right after a write; vault file remains intact and uncorrupted after relaunch.
result: pending
reason: Not yet run — user has not performed this check yet. Lower incremental risk since the write path (FileHandle.seekToEndOfFile + append, no read-modify-write) is unit-tested in QuickNotesVaultWriterTests, but this on-device confirmation is still outstanding before the phase is considered fully closed.

### 7. Per-row delete (D-17) + history list scrolling
expected: Hover row → trash icon → click → disappears immediately, no confirm dialog, hit-target works regardless of scroll position. Per original D-17: vault file untouched by delete.
result: issue
reported: "wenn man in der History der File eben löschen drücken will geht es aber wenn man man gescrollt hat ist die scrollleiste darüber" (scrollbar sits on top of the delete button once the list is scrolled — hit-testing/z-order bug). Additionally: user wants delete to also remove the entry from the vault .md file, reversing the original D-17/D-07 design decision (see Gaps below — approved scope change, not just a bug).
severity: major

### 8. Vault-not-set empty state (D-11)
expected: Clear/rename the vault folder → "New Note…" → "Vault folder not set" empty state, input disabled.
result: issue
reported: "Problem ist eher das Fenster schließt sich nicht mehr" (the empty-state popover no longer closes — window gets stuck open).
severity: major

### 9. Failed-write error banner (D-12)
expected: A note whose write fails shows error banner "Couldn't save — check your vault folder in Settings.", typed text remains, failed note does not appear in the list.
result: pending

## Summary

total: 9
passed: 2
issues: 3
pending: 4
skipped: 0
blocked: 0

## Gaps

- truth: "Popover gains keyboard focus in the TextEditor immediately on open, without requiring a click (Pitfall 10 / A1)."
  status: failed
  reason: "User reported: typing without a click does not work — the input field does not get direct focus."
  severity: major
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The delete button's hit target in the recent-notes history list remains clickable regardless of scroll position."
  status: failed
  reason: "User reported: the delete icon becomes unclickable/obscured once the list has been scrolled — the scrollbar sits on top of it."
  severity: major
  test: 7
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The empty-state popover (vault folder not set) closes normally like the rest of the app's popovers."
  status: failed
  reason: "User reported: the popover no longer closes when it is showing the 'vault folder not set' empty state."
  severity: major
  test: 8
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "SCOPE CHANGE (user-approved, reverses locked D-17/D-07 decision): deleting a note from the recent-notes list also removes the corresponding entry from the vault .md file, not just the local list."
  status: failed
  reason: "User explicitly requested this during UAT: 'ansonsten finde ich macht der Lösch Knopf keinen Sinn' (otherwise the delete button doesn't make sense). Confirmed via follow-up question — user chose 'Auch aus Vault-Datei löschen' over keeping D-17's local-only delete. This requires safe read-modify-write of the vault file (locate the matching line, atomic rewrite via temp-file + rename) — needs deliberate design given D-07/Pitfall 7's data-loss concerns about non-append writes to a user-owned, externally-edited Obsidian file. Needs a real design pass in plan-phase, not an ad-hoc patch."
  severity: major
  test: 7
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "SCOPE CHANGE (user-approved, reverses locked D-08 decision): the Quick Notes popover lets the user browse and select among the files in the chosen vault folder, instead of always writing to one fixed file (Islet Notes.md)."
  status: failed
  reason: "User explicitly requested this during UAT: 'Ich würde auch gerne das man zwischen Files wechseln kann ... die Files sehen kann und auswählen kann'. Confirmed via follow-up question — user chose 'Jetzt als Gap in Phase 64 einbauen' over deferring to a later phase. This is new UI (file listing/selection inside or near the popover) plus a change to which file QuickNotesVaultWriter targets — needs a real design pass in plan-phase, not an ad-hoc patch."
  severity: major
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "'New Note…' is positioned above 'Clipboard History' in the status-item menu."
  status: failed
  reason: "User requested this menu reordering directly (with a screenshot of the current menu layout)."
  severity: minor
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

## Notes

Two of the six gaps above are deliberate, user-approved scope/design changes rather than implementation bugs against the phase's own spec (reversing D-17's local-only delete, and reversing D-08's single-fixed-file target). Both were confirmed explicitly via follow-up questions rather than assumed from a passing remark. They should go through `/gsd:plan-phase 64 --gaps` for a proper design pass — the vault-delete change in particular needs careful handling of atomic file rewrite, concurrent Obsidian edits, and matching the right line to remove — not a quick patch.

Tests 4, 5, 6, and 9 remain untested; recommend covering them in the same on-device pass once the gap-closure plans are executed and the popover/focus bug (test 2) is fixed (retesting focus-dependent flows is easier once that's resolved).
