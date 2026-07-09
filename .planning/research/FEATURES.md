# Feature Research

**Domain:** Notch-overlay drag-and-drop file shelf (temporary file tray utilities)
**Researched:** 2026-07-09
**Confidence:** MEDIUM — direct competitors (NotchDrop, DynamicLake/DynaClip) document *what* they do but rarely *how* (drop-zone hit-testing, duplicate handling); Apple's own `onDrop`/`NSDraggingDestination` docs are HIGH confidence; architecture-dependency analysis below is based on this project's own shipped Phase 1-2/6 behavior (PROJECT.md), not external sources.

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Drag-over-pill triggers auto-expand | Every reference (NotchDrop, DynamicLake DynaClip, Alcove) opens the island the instant a drag enters it — the whole point of a notch shelf is "drop without navigating anywhere first." Already specified in this milestone. | MEDIUM | Not a new trigger on top of the existing click-to-expand path — it's a **third** expand path (drag-enter), since the user's mouse button is down and can't "click" separately. See Dependencies below. |
| "Hot" drop-zone visual feedback while hovering with a file | DynamicLake explicitly advertises "real-time feedback while dragging, ensuring precision in file placement"; Yoink and macOS Finder both accent/highlight the destination the instant a drag enters it (HIG: "you can change the drag image / destination when content is dragged over it"). Users need confirmation the tiny notch target registered the drag *before* they release the mouse. | LOW | SwiftUI `isTargeted` boolean (from `onDrop(of:isTargeted:perform:)`) + an accent glow/scale on the pill is sufficient — same primitive already used for the collapsed-pill hover bounce (ISL-03). |
| Multi-file drop in one gesture | DynamicLake: "Select and drop multiple files at once for bulk organization." Selecting several Finder items and dragging as a group is the default macOS gesture — a shelf that only accepts one file per drop would feel broken. | LOW | `NSItemProvider` drop delivers an *array* of providers per drop already; iterate and append one shelf entry per provider. No extra design needed beyond looping. |
| Folder drops | Finder never distinguishes "drag one file" from "drag one folder" as a gesture — users will drop folders without thinking about it. | LOW | A folder is just another `public.file-url` provider; treat it as a shelf item with a folder icon instead of a file icon. Opening it on click should reveal-in-Finder rather than try to "open" it as a document. |
| Per-item removal (trash icon on each shelf item) | Already specified in this milestone; matches NotchDrop ("deletable by holding option + clicking the x") and is the baseline expectation for any temporary tray (Yoink, macOS Stacks all have per-item removal). | LOW | Standard array-remove on a `@State`/`@Published` collection; no persistence to invalidate. |
| "Delete all" affordance | Already specified. Table stakes once item count is unbounded — without it, clearing a long session queue means many individual clicks. | LOW | Single button clearing the backing array. |
| Drag back out to Finder / other apps | Already specified; this is the entire reason a "shelf" beats a plain notification — it's a staging area, not a dead end. NotchDrop, Yoink, DynaClip all support this. | MEDIUM | Outbound `NSItemProvider`/`.onDrag` with the original file URL. Since this app is **not sandboxed** (confirmed in CLAUDE.md — MediaRemote rules out sandboxing anyway), there's no security-scoped-bookmark ceremony needed, which simplifies this versus a sandboxed app. |
| Unbounded, horizontally-scrolling strip | Already specified — explicitly diverges from DynaClip's fixed 5-file cap (see Anti-Features). | LOW | Plain `ScrollView(.horizontal)`; same SwiftUI idiom already used for the Phase 14 3-column glance layout. |
| Click-to-open a shelf item | Not explicitly in this milestone's spec, but **every** reference app has it (NotchDrop: "open with a simple click"; Yoink; DynaClip). Its absence would be the single most noticeable "missing table stakes" gap versus the reference apps this project benchmarks against. | LOW | `NSWorkspace.shared.open(url)` (or `activateFileViewerSelecting` for folders). Near-zero cost — recommend adding to REQUIREMENTS.md even though not in the original target-feature list. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Real thumbnail/preview per item (image/video/PDF preview, not just a generic file icon) | This is where Alcove-level "polish" is won or lost — a shelf full of identical generic icons feels like Finder, a shelf with live thumbnails feels like the iPhone Dynamic Island. None of the competitor writeups confirm they do this well. | MEDIUM | `QLThumbnailGenerator` (QuickLookThumbnailing) generates async thumbnails for arbitrary file types, including video frame and PDF first-page previews — same "fill in asynchronously" pattern this project already uses for Now Playing album art (PROJECT.md: "artwork latency... design the UI to fill art in asynchronously"). Reuse that async-fill pattern. |
| Polished drag-out lift/shrink preview | Alcove-quality feel — the item visibly "picks up" (scale + shadow) the instant a drag starts from the shelf, mirroring the iOS Dynamic Island's tactile feedback. | LOW-MEDIUM | SwiftUI's default `.onDrag` preview is a flat snapshot; a custom `NSItemProvider` preview image with a slight scale/shadow closes the gap cheaply. |
| Non-empty-shelf indicator on the *collapsed* pill (e.g. a small dot/badge) | Users who drop a file, let the island auto-collapse, and get distracted will forget files are staged — a subtle idle-pill cue ("you still have N files waiting") prevents silently losing dropped files, which is a real risk given content is never persisted. Not confirmed anywhere in competitor material, but a natural fit for this project's existing idle-pill design (Phase 1). | MEDIUM | New idle-pill visual state; needs its own design pass (badge shape, whether it survives across the resolver's other activities). Flag as a candidate REQUIREMENTS.md item, not a certainty. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Drop-triggered action menu (DynamicLake's "DynaDrop": choose AirDrop / convert / share-link on drop) | DynamicLake ships this and it demos well; feels like "more value per drop." | Directly the kind of "DynamicLake-style extra" this project has already chosen to defer (CLAUDE.md/PROJECT.md: messaging/notification mirroring and similar extras deferred until the core island is solid); adds AirDrop framework integration, conversion pipelines, and a whole action-picker UI to a milestone whose explicit goal is "standard `NSItemProvider` drag & drop... no private API needed." | Ship the plain shelf only. Revisit a drop-action picker as its own future milestone if ever wanted. |
| iCloud-synced / cross-device shelf (Yoink's model) | Yoink users like having their shelf everywhere. | Directly contradicts this milestone's explicit requirement: "purely session-temporary... never persisted to disk." Any sync layer is by definition persistence. | None needed — the spec already correctly excludes this. |
| Configurable retention window (NotchDrop's default "auto-save for 1 day, configurable") | NotchDrop, the most directly comparable open-source reference, does exactly this and it's a reasonable feature in isolation. | Also contradicts the explicit spec: "cleared on manual delete, app restart, or Mac restart." Worth naming explicitly here because NotchDrop is the closest prior art and someone skimming it might assume this project should match it — it should not, per the user's own requirement. | None needed — session-only is a deliberate, already-correct deviation from the most popular reference implementation. |
| Fixed low item cap (DynaClip's 5-file limit) | Keeps the UI simple and the strip a fixed width. | Contradicts the explicit "unbounded/horizontally-scrolling" requirement, and a hard cap actively loses a 6th dropped file with no signal — worse than persisting nothing at all. | Already correctly rejected by the unbounded-scroll spec; no action needed. |
| Folder "spring-loading" (drop a folder → shelf auto-navigates inside it, Finder-style) | Feels powerful, mirrors classic Finder drag-and-drop navigation. | No reference notch-shelf app does this; it requires building a mini file browser inside the shelf strip, which is a different feature entirely (file manager, not staging tray) and works against the "temporary staging" mental model. | Folder drops become a single shelf item (folder icon) that reveals-in-Finder on click, same as any file. |

## Feature Dependencies

```
Drag-triggered auto-expand
    └──requires──> Existing NSPanel click-through / hit-test model (Phase 1/2, ISL-01..04)
                       └──CONFLICTS WITH──> idle pill's ignoresMouseEvents / click-through design
                                                (see Dependency Notes — highest-risk unknown)

Shelf strip visible while expanded
    └──requires──> Existing matchedGeometryEffect expand/collapse state machine (ISL-04)
    └──enhances──> IslandResolver / TransientQueue (Phase 6, COORD-01)
                       └──CONFLICTS WITH──> resolver's auto-collapse timers (Charging/Device ~3s)
                                                (see Dependency Notes)

Thumbnail/preview generation ──enhances──> Click-to-open, drag-out preview
Non-empty-shelf idle-pill badge ──requires──> Idle-pill visual state (Phase 1) + shelf item count
```

### Dependency Notes

- **Drag-triggered auto-expand conflicts with the existing click-through idle pill (HIGH-RISK, project-specific):** Phase 1 shipped the idle pill as click-through ("clicks pass through") so it never steals ordinary clicks. `NSDraggingDestination` messages (`draggingEntered`/`draggingUpdated`/`performDragOperation`) route through the same window hit-testing path as mouse clicks — a window/view configured to ignore mouse events for click-through will typically **not** receive drag-destination callbacks either. Every reference app (NotchDrop, DynamicLake) must solve this same problem for their notch shelf, but none of the sources found document how. **This is the single biggest unknown for this milestone and should be spiked on-device before any shelf UI is built** — confirm whether the exact hit-testing mechanism already used for ISL-03's click-to-expand (which necessarily *does* accept clicks on the pill shape while passing through everywhere else) also carries drag sessions, or whether `registerForDraggedTypes` needs to be added to a different view/window layer than the one handling clicks.
- **Shelf visibility conflicts with the resolver's auto-collapse timers:** Charging and Device splashes auto-collapse the island ~3s after showing (Phase 3/6). If a file lands in the shelf while one of those transient activities is mid-display, the resolver's existing collapse timer must not blow away a non-empty shelf — otherwise a user who drops a file during, say, a charging splash loses the island (and effectively loses sight of their staged file) the moment the splash's unrelated timer fires. The shelf's "always show while non-empty" model (per PROJECT.md's target feature: "shelf strip is appended below whatever else is showing... whenever it has content") is architecturally different from Charging/Device/NowPlaying's single-slot, priority-ranked `TransientQueue` membership — it needs to be additive across whatever the resolver currently selects, not itself enqueued and time-boxed the same way. This needs an explicit decision in REQUIREMENTS.md/architecture, not just quiet reuse of the existing resolver.
- **Auto-expand-by-drag is a third expand trigger, not a variant of click-to-expand:** ISL-03 established exactly two states — hover (haptic + bounce, no expand) and click (expand). A file drag is neither: the mouse button is held down over a dropped-in file, there is no click event, and the existing "hover only bounces" rule would otherwise leave the pill collapsed while a file sits on top of it. The expand path taken for a drag-enter needs to be its own explicit branch alongside "user clicked" and "resolver selected an activity," with its own collapse condition (collapse only after the drag session ends AND the shelf's own display rules — not the transient-activity 3s timer — decide to hide).

## MVP Definition

### Launch With (v1.3 Notch Shelf)

Minimum viable product — matches the already-specified target features plus the two near-zero-cost table-stakes additions found in this research.

- [ ] Drag file(s) onto collapsed pill auto-expands the island — table stakes, core of the feature
- [ ] Hot/targeted visual feedback while a file hovers over the pill before drop — table stakes, users need confirmation before releasing
- [ ] Multi-file simultaneous drop — table stakes, default Finder multi-select gesture
- [ ] Folder drop support (folder icon, not a crash/no-op) — table stakes, Finder drags don't distinguish file vs. folder
- [ ] Shelf strip appended below current expanded content, unbounded + horizontally scrolling — already specified
- [ ] Per-item trash icon + one "delete all" icon — already specified
- [ ] Drag shelf items back out to Finder/other apps — already specified
- [ ] Purely session-temporary (RAM-only, cleared on manual delete/app restart/Mac restart) — already specified
- [ ] Click-to-open a shelf item in its default app (or reveal-in-Finder for folders) — near-zero cost, closes the biggest gap versus every reference app

### Add After Validation (v1.x)

- [ ] Real thumbnail/preview generation (QuickLook) instead of generic file icons — add once the plain-icon version proves the core interaction is solid; async-fill using the same pattern as Now Playing album art
- [ ] Polished drag-out lift/shrink preview — cosmetic pass once basic drag-out works
- [ ] Non-empty-shelf badge on the idle/collapsed pill — add if on-device use reveals people forget staged files exist

### Future Consideration (v2+)

- [ ] Drop-triggered action picker (AirDrop / convert / share-link) — explicitly deferred; only revisit if the plain shelf ships and users specifically ask for DynamicLake-style actions
- [ ] Any persisted/cross-restart retention — explicitly excluded by this milestone's own requirements; would need a full requirements re-scope to add

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Drag-onto-pill auto-expand + hot feedback | HIGH | MEDIUM (gated by click-through spike) | P1 |
| Multi-file / folder drop | HIGH | LOW | P1 |
| Shelf strip (scroll, per-item + delete-all trash) | HIGH | LOW | P1 |
| Drag-out to Finder | HIGH | MEDIUM | P1 |
| Click-to-open item | MEDIUM | LOW | P1 (recommend adding to scope) |
| Real thumbnails/previews | MEDIUM | MEDIUM | P2 |
| Drag-out preview polish | LOW-MEDIUM | LOW-MEDIUM | P2 |
| Idle-pill non-empty badge | MEDIUM | MEDIUM | P2/P3 |
| Drop-action picker (AirDrop/convert) | LOW (for this project's stated goals) | HIGH | P3 / explicitly deferred |

## Competitor Feature Analysis

| Feature | NotchDrop (open-source) | DynamicLake / DynaClip | Yoink | Our Approach |
|---------|--------------------------|--------------------------|-------|--------------|
| Retention | Auto-saves ~1 day, configurable | "Until removed manually" + auto-cleanup of old files | Persistent shelf, iCloud-synced | Strictly session-only (RAM), never written to disk — deliberate divergence from all three |
| Capacity | Unbounded (implied, no cap documented) | Fixed at 5 files | Unbounded | Unbounded, horizontal scroll — matches NotchDrop/Yoink, explicitly rejects DynaClip's cap |
| Drop actions | Store + open-on-click | Multi-action picker (shelf/convert/AirDrop/share-link) | Store + system services/share extension | Store + open-on-click only — no action picker (anti-feature above) |
| Removal | Option+click the x mark | Manual + auto-cleanup | Drag out or clear | Per-item trash icon + delete-all icon (no modifier-key gesture required) |
| Multi-file drop | Not documented | Explicitly supported ("select and drop multiple") | Supported | Supported (table stakes) |
| Hover/hot feedback | Not documented | "Real-time feedback while dragging" (undetailed) | Slide-out shelf reveal on drag-start | Targeted-state highlight/glow on the pill before drop |

## Sources

- NotchDrop (open-source reference) — `github.com/Lakr233/NotchDrop` — README confirms drag-to-notch, 1-day configurable auto-save, click-to-open, option+click delete. (MEDIUM — README-level detail only, no architecture docs)
- DynamicLake / DynaClip — `dynamiclake.com/blog/dynaclip-why-this-feature-is-so-strong`, `dynamiclake.com/blog/dynamic-island-for-mac-drag-and-drop` — 5-file cap, multi-file drop, drop-action picker (DynaDrop), "real-time feedback while dragging." (MEDIUM — marketing/blog copy, not technical docs)
- Yoink — `eternalstorms.at/yoink/mac/`, App Store listing — shelf-slides-out-on-drag-start pattern, iCloud sync, drag-out workflow philosophy. (MEDIUM)
- Apple HIG — `developers.apple.com/design/human-interface-guidelines/macos/user-interaction/drag-and-drop/` and `developer.apple.com/library/archive/.../dragdestination.html` — destination visual feedback expectations, spring-loading precedent. (HIGH)
- Apple Developer Docs — `developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:)` — `isTargeted` binding for hot-state feedback; `NSItemProvider` multi-provider drop delivery. (HIGH)
- This project's own PROJECT.md — Phase 1 (click-through idle pill), Phase 2 (ISL-03 click-vs-hover model), Phase 3/6 (IslandResolver + TransientQueue auto-collapse timers), Phase 4 (async artwork-fill precedent for thumbnails). (HIGH — primary source for all dependency/pitfall analysis)

---
*Feature research for: notch-overlay drag-and-drop file shelf*
*Researched: 2026-07-09*
