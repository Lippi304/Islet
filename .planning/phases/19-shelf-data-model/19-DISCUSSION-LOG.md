# Phase 19: Shelf Data Model - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 19-Shelf Data Model
**Areas discussed:** Duplicate handling, Local copy strategy, Shelf ordering

---

## Duplicate handling

| Option | Description | Selected |
|--------|-------------|----------|
| Same source path | Dropping the exact same file (identical originalURL) twice is a duplicate and gets ignored; two different files sharing a filename are NOT duplicates | ✓ |
| Same filename | Any file named "report.pdf" counts as the same shelf item regardless of source folder | |
| No dedup | Every drop adds a fresh entry, even a re-drop of the exact same file | |
| You decide | Claude picks during planning | |

**User's choice:** Same source path.

| Option | Description | Selected |
|--------|-------------|----------|
| Silent no-op | The drop is ignored entirely — item stays where it was, addedAt unchanged | ✓ |
| Refresh position | Existing item removed and re-added at its addedAt-determined position | |
| You decide | Claude picks during planning | |

**User's choice:** Silent no-op.
**Notes:** None.

---

## Local copy strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately on add | File bytes copied to a session-temp directory the moment it lands on the shelf | ✓ |
| Lazily on first use | originalURL stored at add-time; copy only happens on first drag-out/open | |
| You decide | Claude picks during planning | |

**User's choice:** Immediately on add.

| Option | Description | Selected |
|--------|-------------|----------|
| Sofort löschen (delete immediately) | Internal temp copy deleted the moment the item leaves the shelf (individual removal, delete-all, or app quit) | ✓ |
| System räumt später auf (leave for OS cleanup) | Temp copy left in system temp dir, macOS clears it eventually | |
| Entscheide du (you decide) | Claude picks during planning | |

**User's choice:** Sofort löschen (delete immediately).
**Notes:** User's first response (free text, German) clarified a distinct but related point before the actual question was re-asked: the shelf must never touch or delete the *original* file wherever it lives — it may only ever read from it to make its own copy. This is captured as D-04 in CONTEXT.md alongside the temp-copy cleanup decision (D-05).

---

## Shelf ordering

| Option | Description | Selected |
|--------|-------------|----------|
| Append to the end | New drops land on the right, oldest items stay leftmost — matches natural drop order | ✓ |
| Prepend to the front | New drops land on the left — most recent item always visible without scrolling | |
| You decide | Claude picks during planning | |

**User's choice:** Append to the end.
**Notes:** None.

---

## Claude's Discretion

- Exact temp directory location/naming scheme for the session-copy files.
- `ShelfItem.id` generation strategy (UUID assumed as standard default).
- Where the new Swift files live in the project structure (new `Islet/Shelf/` folder vs. existing `Islet/Notch/`).

## Deferred Ideas

None — discussion stayed within phase scope.
