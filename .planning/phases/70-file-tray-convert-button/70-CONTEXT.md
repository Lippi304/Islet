# Phase 70: File Tray Convert Button - Context

**Gathered:** 2026-07-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a 4th destination — "Convert" — to the existing Quick Action Destination Picker (Phase 34: Drop/AirDrop/Mail). Convert is enabled only when every dropped item is an image. Choosing it opens a second step, in the same picker card, showing image-format tiles (JPG/PNG/HEIC/TIFF); tapping/releasing on a format converts the dropped image(s) to that format and lands the result in the Tray via the same mechanism the "Drop" button already uses.

</domain>

<decisions>
## Implementation Decisions

### Conversion flow
- **D-01:** Choosing "Convert" does NOT convert immediately. It opens a second step inside the SAME picker card: the 4-button row (Drop/AirDrop/Mail/Convert) is replaced by a row of format tiles, same button style/size as today. No new card geometry/height — reuses the existing `quickActionPickerContentHeight`/card shape.
- **D-02:** Format tiles offered: **JPG, PNG, HEIC, TIFF** — full Finder "Convert Image" scope, not just the JPG/PNG the user mentioned in passing.
- **D-03 (carried forward from Phase 34's D-03):** One decision applies to the whole batch — if multiple images are dropped, the chosen format converts all of them in one action. Matches the existing "one destination decision per batch" rule; no reason to special-case Convert.

### Destination for the converted file
- **D-04:** After a format is chosen, the converted file(s) go through the exact same path the "Drop" button already uses — `ShelfCoordinator.append` / `ShelfFileStore.makeSessionCopy`'s session-copy mechanism — landing in the Tray as converted copies. No save dialog, no in-place overwrite of the original.

### Enablement / mixed drops
- **D-05:** Convert follows the existing D-09 (Phase 34) dim-never-hide pattern exactly: it renders `enabled: false` (dimmed, via the existing `enabled:` parameter on `quickActionButton`) whenever the pending drop contains ANY non-image file. Only enabled when literally every dropped item is an image — no partial-batch conversion.
- **D-06 (folded todo — see canonical_refs):** The existing `enabled:` dimming for AirDrop/Mail has **no matching controller-side gate** at the release-hit-test (`handleDragApproachEnd()` fires `handleQuickActionAirDrop()`/`handleQuickActionMail()` unconditionally regardless of `airDropAvailable`/`mailAvailable`). This is currently dormant because both flags are hardcoded `true` everywhere. Convert is the FIRST real, sometimes-false `enabled` flag in this component — **this phase MUST also fix the controller gate** (thread the enable flag into the hit-test dispatch), or a visually-dimmed Convert button would still fire on release: a real, immediately-visible bug on day one of the feature.

### Claude's Discretion
- Exact SF Symbol for the Convert button's icon and for each format tile (JPG/PNG/HEIC/TIFF), mirroring Drop/AirDrop/Mail's icon+label convention.
- Underlying image-conversion mechanism (`CGImageDestination`/ImageIO vs. `NSBitmapImageRep` vs. shelling out to `sips`) — technical choice for research/planning.
- How "is this an image" is detected (file extension check vs. `UTType.conforms(to: .image)`) — technical detail.
- Whether there's an explicit "back" affordance from the format-tile step to the original 4-button row, or whether releasing off-target during the format-tile step discards the pending drop entirely (mirroring Phase 34's D-13 "release off-target discards" rule) — not asked directly; treat entering the format-tile step as NOT yet a commit, only the format tap itself commits, and pick whichever back/cancel behavior is simplest given D-13's existing precedent.
- Naming of the new image-conversion seam/service (see Established Patterns below).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & origin
- `.planning/ROADMAP.md` §"Phase 70: File Tray Convert Button" — goal, depends-on note (standalone, no dependency on Phases 68/69)
- `.planning/seeds/filetray-convert-button.md` — original captured idea + reviewed reference screenshot details (Droppy's 4-tile picker: Keep/Droppy Cloud/AirDrop/Convert — Islet's own real 3 buttons are Drop/AirDrop/Mail, not Keep/Cloud/AirDrop; Convert slots in as Islet's 4th)

### Prior phase this one extends
- `.planning/phases/34-quick-action-destination-picker/34-CONTEXT.md` — the full D-01..D-15 decision set this phase builds on: full-takeover picker presentation (D-01), drag-and-release-on-target interaction model (D-10..D-13, NOT click-based), one-decision-per-whole-batch (D-03), dim-never-hide for unavailable destinations (D-09), no file preview (D-14).
- `.planning/phases/34-quick-action-destination-picker/34-UI-SPEC.md` — Layout & Interaction Contract referenced directly by the existing `quickActionPickerView()` implementation comment.

### Folded todo (must be closed as part of this phase, per D-06)
- `.planning/todos/pending/2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — the `enabled:` dimming has no controller-side release-hit-test gate; Convert is the first real trigger for this dormant bug.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `quickActionButton(icon:label:enabled:isHovered:)` (`Islet/Notch/NotchPillView.swift:2341`) — reuse directly for the Convert button itself AND for each format tile in the second step; already has the disabled-dim (D-09) and hover-scale (D-11) behavior built in.
- `ShelfCoordinator.append(_:)` / `ShelfFileStore.makeSessionCopy(of:id:)` (`Islet/Shelf/ShelfCoordinator.swift`) — the exact mechanism "Drop" already uses; reuse verbatim for landing converted files (D-04).
- `hoveredQuickActionButtonIndex: Int?` (`NotchPillView.swift` presentation state) — the existing live-hover-index mechanism (D-11); extend to index 3 for Convert, then reuse again for whichever indices the format tiles occupy once shown.
- `handleDragApproachEnd()`'s release-hit-test switch (`NotchWindowController.swift:1609-1611`, currently `case 0/1/2` → `handleQuickActionDrop/AirDrop/Mail`) — add `case 3` for Convert, then a second dispatch stage once the format-tile step is showing.

### Established Patterns
- Fixed-width button row, no width/geometry change needed: `quickActionButtonWidth` is a fixed **130pt** constant (`NotchPillView.swift:1060`), row spacing is 16pt, card width is `traySize.width` = **650pt** with 24pt horizontal padding (602pt available). 4 buttons need 4×130 + 3×16 = 568pt — comfortably fits today's card with no resize. Confirm this arithmetic still holds once research/planning finalize the format-tile step (likely 3-4 tiles too, same math).
- "Isolate the fragile/uncertain thing behind its own seam" (explicitly named in `34-CONTEXT.md`'s Established Patterns, precedent: `NowPlayingMonitor`, `WeatherService`, and Phase 34's own `QuickActionSharingService` for AirDrop/Mail) — the actual image-conversion call should get its own small service/seam rather than living inline in the view or controller.
- D-09/D-14 (Phase 34): destinations are dimmed, never hidden; no per-file preview, one decision per whole batch — Convert follows both unchanged (D-05, D-03 above).

### Integration Points
- `Islet/Notch/NotchPillView.swift` — `quickActionButtonRow()` (add the 4th tile + the format-tile sub-view), `quickActionButton()` (reused as-is)
- `Islet/Notch/NotchWindowController.swift` — `handleDragApproachEnd()` (hit-test dispatch + D-06's controller-gate fix), a new `handleQuickActionConvert()`-style handler, new pending-format-selection state
- New: an image-conversion seam (`Islet/Notch/` — naming left to Claude's discretion, mirrors `QuickActionSharingService.swift`'s existing separation)

</code_context>

<specifics>
## Specific Ideas

Reference screenshot reviewed 2026-07-29 (`image-cache/.../15.png`, from the app "Droppy"): 4 equal-width rounded-rect tiles in a row inside the notch capsule, each icon-above/label-below — "Keep" (tray-down icon), "Droppy Cloud" (droplet icon), "AirDrop" (wifi/broadcast icon), "Convert" (circular refresh-arrows icon). Islet's own existing 3 buttons are Drop/AirDrop/Mail (different labels/icons from Droppy's reference, but the same 4-tile-row layout pattern is what's being matched) — Convert becomes Islet's 4th tile in that same row, using a similar refresh/convert-style icon.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (A "partial-batch conversion" alternative — converting just the images in a mixed batch and leaving other files untouched — was considered as an option during discussion but the user picked the simpler "disable whenever any non-image file is present" rule instead; not deferred, just not chosen.)

</deferred>

---

*Phase: 70-file-tray-convert-button*
*Context gathered: 2026-07-29*
