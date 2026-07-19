# Phase 44: Tray & Quick Action Width Alignment - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Two width-alignment bugs bundled into one phase because they share the same width constant (`NotchPillView.traySize`), per this project's own Phase 31→32 sequencing precedent (avoid touching the shared geometry twice):

1. **TRAY-06** — the Tray view fits every file icon without visual squeeze at typical file counts. Confirmed during discussion: this is NOT a currently-reproducible defect — Phase 32 already widened Tray to 650pt with horizontal scrolling, and the user has not observed squeeze in the Tray itself. TRAY-06 is carried mostly for formal re-verification/lock-in, not a known active bug.
2. **DRAG-02** — the Quick Action picker (the 3 Drop/AirDrop/Mail buttons shown during an in-progress drag) currently renders as a visibly smaller box than the real landed Tray view, so the buttons look cramped/misplaced relative to it. This IS the user's actual complaint and the real work of this phase: make the picker's box the same size (both width and height) as the real Tray view.

No new capabilities — pure geometry/sizing alignment of already-shipped features.

</domain>

<decisions>
## Implementation Decisions

### Tray squeeze (TRAY-06)
- **D-01:** No active squeeze defect confirmed by the user. Do not chase a reproduction that doesn't exist — treat TRAY-06 as satisfied by Phase 32's existing 650pt/horizontal-scroll implementation, re-verified as part of this phase's on-device check (see Verification below). Do not widen Tray further as a proactive measure.
- **D-02:** If research/planning uncovers an actual squeeze case not caught above (e.g. at some specific file count), Claude/planner decides the exact target width to fix it — no locked target width was given, the user deferred this ("you decide").

### Picker sizing (DRAG-02) — supersedes ROADMAP's "width exactly" wording
- **D-03:** The Quick Action picker must match the real landed Tray view's **full footprint — both width AND height**, not just width. The ROADMAP/REQUIREMENTS text for DRAG-02 only mentions width; the user's own framing ("genauso breit und tief" — exactly as wide and deep) extends this to height too. This decision supersedes the narrower width-only reading.
- **D-04:** Width target: `NotchPillView.traySize.width` (currently 650pt) — replacing the two current hardcoded `expandedSize.width` (420pt) sites:
  - `NotchWindowController.swift` ~line 1023-1025, `quickActionPickerFrame` reservation
  - `NotchPillView.swift` ~line 1471-1474, `quickActionPickerView()`'s `blobShape(...)` call (currently passes no `width:` override, defaulting to `expandedSize.width`)
- **D-05:** Height target: the **full Tray footprint including switcher-row space** — `Self.trayContentHeight + Self.switcherRowHeight` (145 + switcher row height, matching `trayFullView`'s actual computed height at line ~857) — NOT just `trayContentHeight` alone. This is deliberate even though the picker itself does not show the switcher row content (`showSwitcher: false` stays as-is per the existing D-01 comment in code) — only the reserved footprint/box size needs to match, not the switcher row's visible content.
  - Both the `quickActionPickerFrame` reservation (`NotchWindowController.swift`) and `quickActionPickerView()`'s `height:` argument (`NotchPillView.swift`, currently `quickActionPickerContentHeight` = 117) need updating to this new value.
- **D-06:** The 3 Drop/AirDrop/Mail buttons themselves stay unchanged (same size, same `HStack(spacing: 16)` row, `quickActionButtonRow()`) — they simply sit centered in the now-bigger box with more surrounding empty space. No button reflow, no scaling up to fill the space.

### Verification rigor
- **D-07:** A quick manual on-device check is sufficient — same style as Phase 43's D-04 (no formal multi-scenario UAT checklist required in the plan).
- **D-08:** The check MUST explicitly include: (a) the CR-01/CR-02-class click-through hover→expand→move-down trace at the new geometry, AND (b) explicit re-verification that the 3 button tap zones (`computeQuickActionButtonFrames`) still land correctly now that there's more empty space around them in the bigger box — the buttons stay the same size/position-relative-to-center, but the surrounding card grew, so the hit-test math must be re-confirmed, not assumed to "just work."

### Claude's Discretion
- Exact width if an actual Tray squeeze case is found during research/planning (D-02) — no locked number given.
- Whether `quickActionPickerContentHeight` (117) is deleted/replaced outright or kept as a named constant with a new value — implementation detail.
- Any animation/transition detail for the picker's size change when a drag starts while a non-Tray tab was active — not raised as a concern by the user; treat as a normal geometry-parameter change like Phase 32's `width:`/`height:` overrides, no special-cased transition needed.

### D-05 superseded — on-device UAT round 3 (44-02)
- **D-09 (supersedes D-05):** Height no longer matches Tray's full footprint. Rounds 1-2 of the
  44-02 on-device checkpoint fixed the button-overflow and hover-hit-test bugs D-05's height
  choice exposed; round 3 feedback was that the resulting empty margin below the button row (the
  picker never renders switcher-row content, D-06) looked wrong regardless — "Mach die Island von
  der Höhe mal ein bisschen wieder kleiner das ist zu viel Rand finde ich." User explicitly chose
  to override D-05 (re-introduce a size difference vs. the landed Tray view) rather than pad the
  empty space with content. Height reverted to a content-hugging value —
  `NotchPillView.quickActionPickerContentHeight` = `cameraClearance + quickActionButtonRowHeight +
  16` = 117, numerically identical to the pre-Phase-44 constant, now derived from named constants
  instead of a bare comment. **D-04 (width = traySize.width) is unaffected** — only height
  reverted; the picker is still exactly as WIDE as the real Tray, just not as tall.

- **D-10 (further extends D-09, reverses the original relationship):** Round 4 asked to go the
  other direction — instead of the picker matching Tray, make the real (landed) Tray match the
  now-117pt picker: "Können wir die File Tray genauso so groß machen wie die Ablage zum reinziehen
  jetzt ist. Die Höhe will ich genauso bei beiden." `NotchPillView.trayContentHeight` (previously
  145, tuned up over 3+ prior gap-closure rounds specifically to stop file icons/text clipping)
  now equals `quickActionPickerContentHeight` (117) directly, single-source-of-truth. **Explicit,
  acknowledged risk:** 117 is LESS than `cameraClearance(42) + trayShelfRowTopInset(10) +
  trayShelfRowHeight(70) = 122` alone, with zero bottom margin — below the minimum trayContentHeight
  needed in that documented prior history. User was shown this exact math and the regression
  precedent and chose to proceed anyway ("Trotzdem exakt auf 117pt setzen"). **Needs an explicit
  on-device check with a full shelf of files (not just a green build) before being considered
  verified** — if file icons/text clip at the bottom, the fix is almost certainly
  `trayShelfRowHeight`/`trayShelfRowTopInset` re-tuning, not reverting this height tie.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` §"Phase 44: Tray & Quick Action Width Alignment" (~line 620) — goal, 3 success criteria, TRAY-06/DRAG-02. Note: success criterion 2's "exact same width" wording is superseded by D-03 (width AND height).
- `.planning/REQUIREMENTS.md` (~line 41-46) — TRAY-06, DRAG-02 exact wording

### Regression-class precedent (must follow)
- Project memory `cr01-clickthrough-or-defeat-gotcha` — any change touching `visibleContentZone()`/click-through hit-testing needs an explicit on-device hover→expand→move-down trace before being considered verified (D-08 codifies this for this phase, plus the added button-hit-test re-check)

### Prior phase (established the shared width constant this phase must reuse, not duplicate)
- `.planning/phases/32-tray-widening/32-CONTEXT.md` — established `traySize` (650×144), `trayContentHeight` (145), `trayShelfRowHeight`/`trayShelfRowTopInset`; this phase's D-04/D-05 reuse those exact constants for the picker rather than inventing new ones
- `.planning/phases/43-drag-detection-hardening/43-CONTEXT.md` — D-04 precedent for "quick manual check, no formal UAT checklist" verification style, reused here as D-07

</canonical_refs>

<code_context>
## Existing Code Insights

### Confirmed root cause (DRAG-02)
- `Islet/Notch/NotchWindowController.swift` ~line 1023-1025 — `quickActionPickerFrame` is computed via `expandedNotchFrame(collapsed:expandedSize:)` with `CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight)` — hardcoded to `expandedSize.width` (420), never `traySize.width` (650).
- `Islet/Notch/NotchWindowController.swift` ~line 1392 — a second site: `contentSize = CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight)` when `presentationState.presentation` is `.quickActionPicker` — same hardcoded value, must also change.
- `Islet/Notch/NotchPillView.swift` ~line 1471-1477 — `quickActionPickerView()` calls `blobShape(...)` with `height: Self.quickActionPickerContentHeight` and no `width:` argument at all, so it silently falls back to `Self.expandedSize.width` (420) per `blobShape`'s own default (`baseWidth = width ?? Self.expandedSize.width`, ~line 1845).
- Existing constants to reuse (from Phase 32, `Islet/Notch/NotchPillView.swift`): `static let traySize = CGSize(width: 650, height: 144)` (~line 663), `static let trayContentHeight: CGFloat = 145` (~line 664), `switcherRowHeight` (used at ~line 857 for `trayFullView`'s actual height calc: `isTrayPresentation ? Self.trayContentHeight + Self.switcherRowHeight : ...`).
- Current picker-only constant: `static let quickActionPickerContentHeight: CGFloat = 117` (~line 727) — too short relative to Tray's real height once switcher-row space is included per D-05.

### Established patterns
- `blobShape()`'s `width:`/`height:` optional override parameters (already exist, used by `trayFullView`, `calendarView`, `onboardingCarousel`) — the fix is simply passing the same `traySize.width`/Tray-height values `trayFullView` already uses, not inventing a new mechanism.
- Geometry "three-site rule" (per existing code comment at NotchWindowController ~line 1019): any full-view geometry change touches (1) the frame reservation in `positionAndShow()`, (2) the `contentSize` branch, (3) the SwiftUI view's own `blobShape` call — all three must agree. This phase's picker-width fix must update all three consistently, same as `trayFrame`/`weatherExpandedFrame` did for their own presentations.
- `computeQuickActionButtonFrames(card:)` (`Islet/Notch/DragDropSupport.swift` ~line 55) — pure function computing button hit-rects from the card rect; feeding it the new bigger card rect should "just work" arithmetically, but D-08 requires explicitly confirming this on-device rather than assuming.

### Integration points
- `Islet/Notch/NotchWindowController.swift` — `positionAndShow()` (~line 1023, quickActionPickerFrame reservation), `updateContentSize`-style branch (~line 1386-1392, contentSize for `.quickActionPicker` case)
- `Islet/Notch/NotchPillView.swift` — `quickActionPickerView()` (~line 1471), `quickActionPickerContentHeight` (~line 727), `traySize`/`trayContentHeight` (~line 663-664)

</code_context>

<specifics>
## Specific Ideas

- User's own words: "Nein es geht darum wenn man eine File droppen will auf die 3 Buttons mit drop/airdrop/mail die 3 buttons sind nicht richtig in der File Tray. Mein Gedanke ist diese Tray beim Drop genauso breit und tief zu machen wie die normale File Tray wenn man seine gedroppten files sieht." (No, it's about: when you want to drop a file onto the 3 Drop/AirDrop/Mail buttons, the 3 buttons aren't sitting properly within the [smaller] File Tray box. My thought is to make this Tray-during-drop exactly as wide and deep as the normal File Tray you see once files have landed.) — this is the direct source of D-03 (width AND height, not width-only).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (Tray squeeze status, picker sizing mechanism, and verification rigor all fall within this phase's TRAY-06/DRAG-02 domain).

</deferred>

---

*Phase: 44-tray-quick-action-width-alignment*
*Context gathered: 2026-07-19*
