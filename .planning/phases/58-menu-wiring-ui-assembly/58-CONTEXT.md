# Phase 58: Menu Wiring & UI Assembly - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Wires the three already-proven pieces (Phase 55's `ClipboardStore`, Phase 56's `ClipboardFileStore` encrypted persistence, Phase 57's `ClipboardMonitor` live capture) into Islet's existing status-item `NSMenu` for the first time. Delivers the full user-facing clipboard history feature end to end: a history section listing the last ~20-30 text/image copies, click-to-restore, ⌘0-⌘9 quick-select on the first 10, and a destructive-confirm "Delete All History." No new pasteboard-monitoring logic (that's Phase 57, done) and no new persistence logic (Phase 56, done) — this phase is pure assembly + the real-menu UI surface those subsystems never had before.

</domain>

<decisions>
## Implementation Decisions

### Image entry appearance
- **D-10:** Image copies render as a small thumbnail (~16-20pt, inline with row height — same height as a standard single-line `NSMenuItem`, not an enlarged row) rather than a generic icon + "Image" label. Matches research's `FEATURES.md` recommendation (thumbnail storage was already scoped for exactly this) and gives image entries the same at-a-glance recognizability CopyClip's text-only reference can't demonstrate.

### Pasteboard-access explanation (supersedes Phase 57 D-07 placeholder)
- **D-11:** The one-time pasteboard-access explanation is shown on first menu open (not on first captured item) — sets expectations before any history exists rather than after something has already happened.
- **D-12:** Presented as a native `NSAlert` (same mechanism Phase 57's spike proved works), not an inline menu row — consistent with how Islet already handles other one-time explanations (e.g. the trial-start notice).
- **D-13:** Claude drafts the actual copy — short, plain-language explanation of why Islet reads the pasteboard (to build clipboard history) and that sensitive/password-manager copies are never captured. No specific wording dictated by the user.

### Empty state
- **D-14:** Before anything has been copied, the clipboard section shows a single disabled, non-clickable placeholder row ("No items yet" or equivalent) rather than hiding the section entirely — confirms the feature exists and is working. "Delete All History" is naturally disabled/absent while the history is empty (Claude's discretion on exact mechanism).

### Section placement
- **D-15:** The clipboard history section (rows + "Delete All History") sits ABOVE the existing Settings…/Check for Updates…/Quit block, separated by a standard `NSMenuItem.separator()` — matches the user's CopyClip reference screenshot exactly (list on top, actions below it). The existing three items keep their current relative order, just pushed below the new section.

### Carried forward from research (not re-discussed) [informational]
Already effectively decided by `.planning/research/FEATURES.md` — listed here for background only, not open questions for this discussion.
- **[informational]:** Extend the existing status-item `NSMenu` with custom `NSMenuItem` rows (`NSHostingView`-wrapped SwiftUI content for text truncation + thumbnail), rather than a new `NSPanel`/popover — matches the user's explicit "additive to the existing menu, not a new Island view" decision from milestone-level discussion.
- **[informational]:** Text entries use single-line truncation + ellipsis (`.lineLimit(1)` / `.truncationMode(.tail)`) — every reviewed clipboard manager does this; full untruncated text stays stored (not pre-truncated) for future search support.
- **[informational]:** "Delete All History" confirmation uses a single native `NSAlert` — "Delete all clipboard history? This cannot be undone." with Cancel / Delete (destructive-styled) buttons, no "don't ask again" checkbox.
- **[informational]:** ⌘0-⌘9 are standard `NSMenuItem.keyEquivalent` on the first 10 rows only, active while the menu is open (same as CopyClip) — not a global hotkey.

### Claude's Discretion
- Exact SwiftUI row layout inside the `NSHostingView` (spacing, font size, truncation length in characters) — as long as it reads as a single-line row matching the surrounding native `NSMenuItem`s in height/style.
- Whether the disabled empty-state row and/or "Delete All History" use a literal `isEnabled = false` `NSMenuItem` vs. omission — implementation detail, not a visible-behavior difference the user specified.
- Whether the pasteboard-access `NSAlert` is triggered from `AppDelegate` directly or a new coordinator method — mirrors whatever shape Phase 56/57's spike-hook-to-real-wiring transition naturally suggests during planning.

### Reviewed Todos (not folded)
- `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — matched by the todo/phase matcher (generic keyword overlap on "phase"/"through"/"user") but all are UI-domain issues (view switcher morph, calendar grid, Quick Action picker) unrelated to a status-item menu feature. Same false-positive judgment as Phases 55/56/57's cross-reference against this identical trio.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §"Phase 58: Menu Wiring & UI Assembly" — goal, 4 success criteria, dependency on Phase 56 + Phase 57 (both complete)
- `.planning/REQUIREMENTS.md` §"v1.9 Requirements — Clipboard History" (CLIP-01, CLIP-02, CLIP-03, CLIP-05, lines 80-84, 161-165) — the requirements this phase closes
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.9 (Clipboard History)" (lines 115-132) — CopyClip reference behavior, target features, explicit "additive to existing menu, not a new Island view" scope note

### Research (dedicated, covers menu UI in depth)
- `.planning/research/FEATURES.md` — "Menu-Bar Dropdown UI: NSMenu vs. Custom Popover/Panel" section (NSMenu + NSHostingView recommendation), "UX Conventions: Delete All History" section (confirmation copy/buttons), text-truncation and image-thumbnail recommendations
- `.planning/research/SUMMARY.md`, `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md` — supporting detail

### Prior phases (prerequisites this phase assembles)
- `.planning/phases/55-clipboard-data-model-store/55-CONTEXT.md` — `ClipboardStore`'s append/evict/clear contract (30-item cap, FIFO, dedupe-and-reorder)
- `.planning/phases/56-encrypted-persistence/56-CONTEXT.md` — `ClipboardFileStore`'s save/load contract, D-04 graceful-degradation-on-decrypt-failure behavior this phase inherits (no error UI needed, just an empty-looking history)
- `.planning/phases/57-pasteboard-monitor-spike/57-CONTEXT.md` — D-07 (this phase's pasteboard-access-prompt placeholder to replace), `ClipboardMonitor`'s `onChange` callback contract, self-capture-marker guard (must not re-ingest a click-to-restore write)
- `Islet/Clipboard/ClipboardItem.swift`, `Islet/Clipboard/ClipboardStore.swift`, `Islet/Clipboard/ClipboardFileStore.swift`, `Islet/Clipboard/ClipboardMonitor.swift`, `Islet/Clipboard/KeychainClipboardKeyStore.swift` — the four subsystems this phase wires together
- `Islet/AppDelegate.swift` (lines 1-120, 230-370) — existing `NSMenu`/`statusItem` construction, DEBUG spike hooks (`debugSpikeStartClipboardMonitor`/`debugSpikeStopClipboardMonitor`) that get superseded by real (non-DEBUG) wiring in this phase

No external ADRs/specs beyond the project's own planning docs and dedicated milestone research.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/AppDelegate.swift:95-107` — the existing `NSMenu` construction (`Settings…`, `Check for Updates…`, separator, `Quit Islet`) this phase extends. No prior custom-view (`NSHostingView`-wrapped) `NSMenuItem` exists anywhere in the codebase — this phase establishes that pattern for the first time.
- `Islet/AppDelegate.swift:315-337` — Phase 57's DEBUG-only `debugSpikeStartClipboardMonitor`/`debugSpikeStopClipboardMonitor` show the exact `ClipboardMonitor(onChange:)` construction + idempotent start/stop shape this phase's real (non-DEBUG) wiring should mirror, minus the DEBUG guard.
- `Islet/Licensing/`, trial-start notice pattern — existing precedent for a one-time `NSAlert`-based explanation shown once per install, relevant to D-11/D-12's pasteboard-access prompt.

### Established Patterns
- `AppDelegate`'s `NSMenu` is built once at `applicationDidFinishLaunching` and assigned via `statusItem.menu = menu` — a static menu. This phase's dynamic content (history rows that change as items are captured/deleted) will need either an `NSMenuDelegate.menuNeedsUpdate(_:)` rebuild-on-open approach or an observer-driven rebuild whenever `ClipboardStore` changes; Claude decides the exact mechanism during planning (not a user-facing behavior difference either way).
- No existing `org.nspasteboard.*`/pasteboard-access-behavior UI anywhere — Phase 57's DEBUG alert is the only precedent, explicitly marked placeholder-only.

### Integration Points
- `ClipboardMonitor.onChange` callback → real `store.append(...)` (currently only exercised against a throwaway/console sink in Phase 57's spike) → `ClipboardFileStore.save(...)` for persistence, all wired for real for the first time in this phase.
- Menu click on a history row → `NSPasteboard.general.declareTypes`/write-back with the self-capture marker type (from Phase 57) so the monitor doesn't re-ingest its own restore write.
- `KeychainClipboardKeyStore().readOrCreateKey()` (Phase 56) is already the read/write path for the encryption key — reused as-is, no changes needed here.

</code_context>

<specifics>
## Specific Ideas

- User's installed CopyClip app (screenshot captured during milestone discussion) is the explicit visual/structural reference: status-icon dropdown, recent clips by preview text on top, ⌘0-⌘9 quick-select, "Delete All History" and "Preferences…" entries below the list. This phase's section-placement decision (D-15) locks Islet's menu to match that same top-to-bottom order.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Search/filter and per-item delete remain explicitly deferred to a future milestone per `.planning/research/FEATURES.md` — not raised again during this discussion.)

</deferred>

---

*Phase: 58-Menu Wiring & UI Assembly*
*Context gathered: 2026-07-22*
