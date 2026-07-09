# Project Research Summary

**Project:** Islet — v1.3 "Notch Shelf" milestone (drag-and-drop file shelf)
**Domain:** Feature addition to an existing, shipped native macOS notch-overlay app (not a green-field project)
**Researched:** 2026-07-09
**Confidence:** MEDIUM-HIGH overall — architecture and pitfalls research is grounded in direct reads of the real Islet codebase (HIGH); the one genuine unknown (drag delivery through a click-through `NSPanel`) is flagged everywhere and needs an on-device spike before full implementation.

## Executive Summary

The Notch Shelf is a session-only, drag-and-drop file tray appended to Islet's existing notch overlay — drop files on the pill, they collect in a horizontally-scrolling strip while the island is expanded, and can be dragged back out to Finder or other apps. Every reference app (NotchDrop, DynamicLake's DynaClip, Yoink) validates the core interaction, and this project's own architecture research (grounded in direct reads of `NotchWindowController.swift`, `IslandResolver.swift`, `ActivityCoordinator.swift`) shows the shelf fits cleanly as a second, independent `@Published` axis rendered underneath whatever `IslandResolver` already decided — exactly the pattern already proven by the Phase 18 song-change toast. No new coordinator, no new `IslandPresentation` case, no protocol seam for `NSItemProvider` (a stable public API, unlike the fragile private MediaRemote bridge) — plain `ShelfState`/`ShelfLogic`/`ShelfFileImporter` mirroring existing pure/glue splits (`BasicOutfitState`, `PowerActivity`/`PowerSourceMonitor`).

The single highest-risk unknown, surfaced consistently across ARCHITECTURE.md and PITFALLS.md, is that Islet's panel is click-through via `panel.ignoresMouseEvents = true` outside a small hot-zone — and AppKit drag-destination delivery (`draggingEntered`/`.onDrop`) is routed through the exact same mouse-event path as clicks. A window ignoring mouse events also ignores drag sessions entirely, so today a file dragged onto the collapsed pill would silently do nothing. A second, related gap: the existing hover state machine is driven exclusively by `.mouseMoved`, which AppKit stops delivering the instant a mouse button is held down for a drag — so both drag-in detection and the "collapse after drag-out" behavior need a parallel `.leftMouseDragged`/`.leftMouseUp` global monitor, not a reuse of the existing `.mouseMoved` monitor. Both issues are well-understood and have a clear fix (extend `syncClickThrough()` and add a second global event monitor), but must be spiked/verified on-device before the shelf's view layer is built out, or the feature will "look done" in Xcode Previews while being non-functional on the real notch.

The recommended build order — pure model first (unit-tested `ShelfItem`/`ShelfLogic`, zero AppKit), then view wiring against hand-seeded state, then drag-OUT (simpler, no click-through collision), then drag-IN last (the riskiest, spike-first piece) — matches this project's own established convention (`IslandResolver` before controller wiring; `DeviceCoordinator` proven in isolation before Phase 16 wiring) and de-risks the one genuinely uncertain integration point by sequencing it after everything else is already proven.

## Key Findings

### Recommended Stack

No new third-party dependencies. The entire feature is built on stable, public Apple APIs already available in the existing toolchain: SwiftUI `.onDrop`/`.onDrag`, `NSItemProvider`, `UniformTypeIdentifiers` (`UTType.fileURL`), `FileManager` (private temp-directory copy), and `NSWorkspace.shared.icon(forFile:)` for cheap icon generation. `QLThumbnailGenerator` is a later, optional upgrade for true previews (P2, not MVP). No Keychain, no networking, no new Swift packages — this is the leanest addition the project has made.

**Core technologies:**
- SwiftUI `.onDrop(of:isTargeted:perform:)` — drop-target hot/targeted feedback and file acceptance — the standard, HIGH-confidence primitive for drag-in
- `NSItemProvider(contentsOf:)` / `.onDrag` — drag-out to Finder/other apps — the reliable choice; SwiftUI's file-promise-writer path is documented as unreliable and should be avoided
- `NSWorkspace.shared.icon(forFile:)` — cheap per-item icon generation without reading file bytes into memory — avoids the "unbounded shelf + raw Data" memory trap
- A second global `NSEvent` monitor for `.leftMouseDragged`/`.leftMouseUp` (mirrors the existing `.mouseMoved` monitor at `NotchWindowController.swift:299`) — required because ordinary hover tracking freezes during an active drag

### Expected Features

**Must have (table stakes / MVP, per FEATURES.md):**
- Drag file(s) onto collapsed pill auto-expands the island
- Hot/targeted visual feedback (`isTargeted` glow) before the user releases
- Multi-file and folder drop support
- Unbounded, horizontally-scrolling shelf strip appended below expanded content
- Per-item trash icon + a spatially-distinct "delete all" icon
- Drag shelf items back out to Finder/other apps
- Purely session-temporary — RAM only, cleared on manual delete, app restart, or Mac restart
- Click-to-open a shelf item in its default app (not in the original spec, but near-zero cost and closes the biggest gap vs. every reference app — recommend adding to REQUIREMENTS.md)

**Should have (competitive/P2, add after validation):**
- Real thumbnail/preview via `QLThumbnailGenerator` instead of generic icons
- Polished drag-out lift/shrink preview (scale + shadow)
- Non-empty-shelf badge on the collapsed/idle pill (so users don't forget staged files)

**Defer (v2+, explicitly out of scope):**
- Drop-triggered action picker (AirDrop/convert/share-link, DynamicLake's "DynaDrop") — deliberately deferred, matches project's existing "no DynamicLake-style extras yet" stance
- Any persisted or cross-restart retention, or iCloud sync — directly contradicts this milestone's explicit session-only requirement
- Fixed low item cap — explicitly rejected in favor of unbounded scroll
- Folder "spring-loading" (auto-navigate into dropped folders) — out of scope; folders are just another shelf item

### Architecture Approach

The shelf is not a competing activity in `IslandResolver`'s rank-ordered arbitration (`Charging > Device > NowPlaying`) — it is a second, orthogonal `@Published` axis (`ShelfState`) that `NotchPillView` renders as an extra row appended after the `switch presentation { }` block, gated on `interaction.isExpanded && !shelf.items.isEmpty` (and excluding the collapsed "wings" cases, pending a product decision flagged for discussion). This exactly mirrors the already-shipped Phase 18 song-change toast pattern, which is the load-bearing precedent for this whole integration.

**Major components:**
1. `ShelfItem` (pure value: id, originalURL, localURL, filename, addedAt) + `ShelfLogic` (pure functions: append/remove/clear) — unit-tested first, zero AppKit
2. `ShelfState` (`@Published var items: [ShelfItem]`) — mirrors `BasicOutfitState` exactly, no methods
3. `ShelfFileImporter` — the only glue file touching `NSItemProvider`/`UniformTypeIdentifiers`; resolves a drop to a source URL, copies it to a private per-launch temp directory off the main thread, hands back a `ShelfItem`
4. `NotchWindowController` (modified) — owns `shelfState`, wires `handleDrop(providers:)` (reusing the existing click-expand path), per-item removal, clear-all, and temp-dir teardown
5. `NotchPillView` (modified) — renders the shelf row, hosts `.onDrop` on the hot-zone, per-item + delete-all controls, drag-out `.onDrag`

Explicitly **not touched**: `IslandResolver`, `IslandPresentation`, `TransientQueue`, `ActivityCoordinator`, `DeviceCoordinator`. Panel sizing headroom for the shelf row must be reserved in the controller's panel-frame math only (not the shared `expandedSize` constant), exactly mirroring how the toast's `toastExtraHeight` was handled — otherwise every blob becomes visibly taller even with an empty shelf.

### Critical Pitfalls

1. **`ignoresMouseEvents = true` silently blocks all drag delivery, not just clicks** — a click-through panel never receives `draggingEntered`/`.onDrop` at all. Fix: an independent global `.leftMouseDragged` monitor that hit-tests a drag-specific hot-zone and flips `ignoresMouseEvents = false` through the existing `syncClickThrough()` single-writer before AppKit's drag machinery needs it.
2. **`.mouseMoved` stops firing during an active drag**, freezing the existing hover/grace-collapse state machine — dragging a file out of the shelf can leave the island stuck open indefinitely. Fix: add `.leftMouseDragged`/`.leftMouseUp` tracking into the same zone-hit-test logic used by `handlePointer`.
3. **Reusing the click hot-zone for drag detection causes false positives/negatives** — too tight for imprecise drag gestures, but naively widening it for all pointer purposes causes accidental expand on any drag merely passing near the notch. Fix: a separate, larger `dragHotZonePadding` plus a short dwell before promoting to expanded.
4. **Treating the shelf as another `IslandResolver`/`TransientQueue` case** — the natural-looking "just add a case" move makes the shelf wrongly mutually-exclusive with Now Playing/idle and exposes it to `TransientQueue`'s `maxDepth` eviction logic, which was built for flapping Bluetooth/charging events, not user file content. Fix: separate `@Published` field, Phase-18-toast pattern, never threaded through `resolve(...)`.
5. **Unbounded shelf + naive full-file loading balloons memory** — an unbounded, unaddressed capacity requirement combined with eager `loadDataRepresentation`/full-resolution `NSImage` per item can retain hundreds of MB for off-screen items, worsened by SwiftUI re-rendering the shelf on every unrelated resolver update. Fix: generate a small icon once via `NSWorkspace.shared.icon(forFile:)` at drop time, store only that + the URL, never raw `Data`; use `LazyHStack`.
6. **Stale/moved/deleted dropped-file URLs** — holding a plain URL in memory (correctly, since Islet is unsandboxed and needs no security-scoped bookmark) still requires guarding against the source file vanishing between drop and later drag-out. Fix: copy the file once at drop time into an app-owned temp directory (the shelf's own copy becomes authoritative), and check `fileExists` before any drag-out, pruning gracefully on failure.

## Implications for Roadmap

Based on research, suggested phase structure (this is a single-milestone feature addition, not a full project — phases below are sub-phases within v1.3):

### Phase 1: Pure Shelf Model (no AppKit, no drag APIs)
**Rationale:** Every prior feature in this codebase shipped pure-seam-first (`IslandResolver` before controller wiring, `DeviceCoordinator` proven in isolation before Phase 16 wiring) — the model layer has zero external-API risk and should be nailed down and unit-tested before any fragile drag/panel code is touched.
**Delivers:** `ShelfItem`, `ShelfLogic` (append/remove/clear/dedupe), unit tests (`ShelfLogicTests.swift`) with hand-built `ShelfItem`s.
**Addresses:** Data model decisions from FEATURES.md/ARCHITECTURE.md (dedupe on drop, session-only lifecycle).
**Avoids:** Pitfall 4 (shelf-as-resolver-case) and Pitfall 6 (memory model) — both are model-shape decisions best locked in before any view exists.

### Phase 2: Shelf View (hand-seeded state, no live drop)
**Rationale:** Confirms the panel-sizing math (reserved headroom vs. `expandedSize`) and the resolver-gating rule visually via `#Preview`, before any drag risk is introduced — matches the project's existing `#Preview` convention.
**Delivers:** `ShelfState`, the appended shelf row in `NotchPillView` (icon, per-item trash, delete-all), gated per the `isExpanded && !items.isEmpty` rule.
**Uses:** SwiftUI `ScrollView(.horizontal)`/`LazyHStack`, existing `matchedGeometryEffect`/spring conventions.
**Implements:** The "modifier, not competitor" architecture pattern (ARCHITECTURE.md) alongside `IslandResolver`'s untouched switch.

### Phase 3: Drag-OUT (shelf → Finder/other apps)
**Rationale:** Simpler than drag-in — no click-through collision, since the drag *originates* from an already-interactive expanded island. Lower risk, good place to validate `NSItemProvider(contentsOf:)` mechanics before tackling drag-in.
**Delivers:** `.onDrag` per shelf item using the item's own `localURL` copy; `fileExists` guard + graceful prune if the source vanished.
**Addresses:** FEATURES.md's "drag back out" table-stakes requirement.
**Avoids:** Pitfall 5 (stale URLs) — verified here before drag-in adds more surface area.

### Phase 4: Drag-IN (spike first, then wire)
**Rationale:** The single highest-uncertainty integration point in the whole feature (click-through panel vs. drag delivery, `.mouseMoved` freezing mid-drag) — sequencing it last means every other piece is already proven working, isolating the risky work.
**Delivers:** `ShelfFileImporter` (background copy off main thread), `handleDrop(providers:)` reusing the existing click-expand path, the second global `.leftMouseDragged`/`.leftMouseUp` monitor extending `syncClickThrough()`, drag-specific hot-zone + dwell timer.
**Avoids:** Pitfalls 1, 2, and 3 (click-through blocking, mid-drag freeze, hot-zone false positives) — all three concentrated in this phase by design.

### Phase Ordering Rationale

- Pure-model-first is not just "good practice" here — it is the project's own established, proven convention (verified by reading the real shipped code), so deviating from it would be inconsistent with the rest of the codebase, not just riskier.
- Drag-OUT before drag-IN because drag-out has no click-through collision; sequencing it first builds confidence in `NSItemProvider` mechanics on a lower-risk path.
- Drag-IN last and explicitly spiked because it is the one place PITFALLS.md and ARCHITECTURE.md both flag as needing on-device verification before commitment — building the view and drag-out first means a failed/iterating drag-in spike doesn't block or waste the rest of the feature.

### Research Flags

Phases likely needing deeper research/spiking during planning:
- **Phase 4 (Drag-IN):** Needs an on-device spike/prototype specifically for the `ignoresMouseEvents`/drag-delivery interaction and the `.leftMouseDragged` hover-freeze fix before full implementation — flagged as LOW-MEDIUM confidence in ARCHITECTURE.md ("Apple's documented behavior... not independently re-verified against a fetched doc page this session"). Recommend `/gsd:plan-phase --research-phase` or at minimum a tiny throwaway prototype before committing to the full drag-in implementation.
- **Product decision needed before Phase 2:** whether the shelf should render/suppress during collapsed "wings" transients (Charging/Device/NowPlaying-wings) mid-display — ARCHITECTURE.md explicitly flags this as unresolved and recommends a `/gsd:discuss-phase` conversation, not a default assumption.

Phases with standard, well-documented patterns (skip research-phase):
- **Phase 1 (Pure Model):** Plain Swift value types and pure functions — no external API risk, standard testing pattern already used repeatedly in this codebase.
- **Phase 2 (Shelf View):** Standard SwiftUI `ScrollView`/`LazyHStack`/conditional rendering — HIGH confidence, no novel APIs.
- **Phase 3 (Drag-OUT):** `NSItemProvider(contentsOf:)` is a well-documented, stable API with a clear "don't use file promises" steer already resolved by research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies; entire feature built on stable, long-standing public Apple APIs (SwiftUI drag modifiers, NSItemProvider, FileManager, NSWorkspace icon generation). |
| Features | MEDIUM | Table-stakes list is well-corroborated by three reference apps (NotchDrop, DynamicLake, Yoink), but those sources are README/marketing-blog level detail, not technical docs — the exact hit-testing/duplicate-handling mechanics they use are undocumented. |
| Architecture | HIGH | Grounded in direct reads of the real Islet source files (`NotchWindowController.swift`, `IslandResolver.swift`, `ActivityCoordinator.swift`, `NotchPillView.swift`, entitlements) — this is project-specific fact-finding, not general inference, for the integration-point analysis. Drag mechanics themselves are MEDIUM-HIGH (corroborated by multiple independent sources, no official Apple sample matched exactly). |
| Pitfalls | MEDIUM-HIGH | Grounded in the same direct code reads plus official Apple docs for `NSWindow.ignoresMouseEvents` and `NSItemProvider`; the core click-through/drag-delivery claim rests on general AppKit knowledge not independently re-verified against a live fetched doc page this session — flagged explicitly and should be confirmed via the Phase 4 spike. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Drag delivery through a click-through `NSPanel`:** the core premise that `ignoresMouseEvents = true` blocks `NSDraggingDestination` callbacks entirely is drawn from general AppKit documentation knowledge, not a directly fetched/re-verified Apple doc page this session — validate with a minimal on-device prototype at the start of Phase 4 before committing to the full drag-in architecture.
- **Shelf visibility during collapsed transient "wings" states:** ARCHITECTURE.md flags this as an open product decision (does a file dropped mid-charging-splash still show its shelf?) rather than a settled requirement — needs a `/gsd:discuss-phase` conversation before Phase 2 locks in the gating condition.
- **Exact hit-testing/duplicate-handling techniques used by competitor apps:** FEATURES.md and PITFALLS.md note that NotchDrop/DynamicLake/Yoink write-ups describe *what* they do but not *how* — this project's own architecture research (grounded in the real codebase) fills that gap for Islet specifically, so this is a low-severity gap.

## Sources

### Primary (HIGH confidence)
- Direct reads of the Islet codebase: `NotchWindowController.swift`, `IslandResolver.swift`, `ActivityCoordinator.swift`, `DeviceCoordinator.swift`, `NotchPillView.swift`, `IslandPresentationState.swift`, `NotchInteractionState.swift`, `BasicOutfitState.swift`, `NowPlayingPresentation.swift`, `Islet.entitlements`, `.planning/PROJECT.md`
- Apple Developer Documentation — `NSWindow.ignoresMouseEvents`, `NSItemProvider`, `onDrop(of:isTargeted:perform:)`
- Apple HIG — drag-and-drop destination visual-feedback guidance

### Secondary (MEDIUM confidence)
- NotchDrop (`github.com/Lakr233/NotchDrop`) — README-level: drag-to-notch, configurable auto-save, click-to-open, option+click delete
- DynamicLake/DynaClip (`dynamiclake.com` blog posts) — 5-file cap, multi-file drop, drop-action picker, real-time drag feedback
- Yoink (`eternalstorms.at/yoink/mac/`) — shelf-slide-out-on-drag pattern, iCloud sync philosophy
- DeepWiki summary of TheBoredTeam/boring.notch's shipped shelf system — third-party summary of a comparable shipped feature
- Wade Tregaskis — "SwiftUI drag & drop does not support file promises" — informs avoiding `NSFilePromiseProvider`
- The Eclectic Light Company / Create with Swift — `.onDrop`/`.onDrag`/`NSItemProvider` mechanics corroboration

### Tertiary (LOW confidence)
- General AppKit knowledge that `ignoresMouseEvents = true` blocks drag-destination delivery, not independently re-verified against a live-fetched doc page this session — flagged for on-device spike validation in Phase 4
- Community write-ups on `.leftMouseDragged` + drag-pasteboard change-count detection — single-source technique, corroborated only by the TheBoringNotch precedent

---
*Research completed: 2026-07-09*
*Ready for roadmap: yes*
