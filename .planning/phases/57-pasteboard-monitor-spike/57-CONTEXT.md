# Phase 57: Pasteboard Monitor — Spike - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

`ClipboardMonitor` — the one genuinely new, only-verifiable-on-real-hardware subsystem in v1.9: live `NSPasteboard.general` `changeCount`-diff polling (~500ms, gated), text/image classification, `org.nspasteboard.ConcealedType`/`TransientType` filtering, and a self-capture guard so click-to-restore's own write is never re-ingested. Proven in isolation via DEBUG-only spike hooks before Phase 58 wires it into the real menu. No menu UI, no `IslandResolver`/`TransientQueue` coupling — `ClipboardMonitor` is constructor-injected with an `onChange` callback and owned by `AppDelegate`, matching Phase 19/47/49's pure-seam-first precedent and this milestone's own Phase 55→56→57→58 build order.

</domain>

<decisions>
## Implementation Decisions

### Pasteboard-access prompt UX
- **D-07:** The one-time in-app explanation for macOS's pasteboard-access privacy prompt (SC#4) is a minimal placeholder for this spike — a simple `NSAlert`/console message proving the `NSPasteboard.general.accessBehavior` check + one-time-gate mechanism actually works. Phase 58 (menu wiring) replaces it with final polished copy once the real menu UI exists to host it properly. Mirrors Phase 56's spike-first precedent (DEBUG hooks now, real UX later).

### Concealed-type on-device test source
- **D-08:** SC#2's on-device concealed/transient-type verification uses a simulated source: a DEBUG-only spike hook manually writes an `NSPasteboardItem` tagged `org.nspasteboard.ConcealedType` (and/or `TransientType`) to the pasteboard. Guaranteed reproducible regardless of what's actually installed on the test Mac — not dependent on the user owning a specific password manager. Mirrors Phase 56's `spikeSeedItems()`-style hook pattern.

### On-device verification approach
- **D-09:** `ClipboardMonitor` is verified on-device the same way Phase 56 verified `ClipboardFileStore`: DEBUG-only spike hooks reachable from the existing debug menu (`AppDelegate`), feeding a throwaway/in-memory sink — NOT the real persisted `ClipboardStore`/`ClipboardFileStore`. Test copies made during this spike's on-device checkpoint never touch real history and need no manual cleanup before Phase 58 ships. Zero Release-build footprint, matching Phase 49/56's established DEBUG-hook precedent.

### Claude's Discretion
- Self-capture guard mechanism (marker pasteboard type vs. a simple boolean flag around the restore write) — research (`PITFALLS.md` Pitfall 1) recommends Maccy's marker-type approach as more robust against race windows; Claude implements per that recommendation unless planning surfaces a reason to deviate.
- Exact spike-hook naming/wiring shape in the debug menu — mirrors Phase 56-02's `spikeSeedItems()`/`spikeReloadStore()` naming convention.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §"Phase 57: Pasteboard Monitor — Spike" (lines 995-1007) — goal, 4 success criteria, dependency note (feeds Phase 55's `ClipboardStore`, independent of Phase 56's on-disk format)
- `.planning/REQUIREMENTS.md` §"v1.9 Requirements — Clipboard History" (PRIV-01, line 88) — the concealed/transient-exclusion requirement this phase satisfies

### Research (dedicated, already covers this phase in depth)
- `.planning/research/PITFALLS.md` — Pitfall 1 (self-capture loop, Maccy's marker-type fix), Pitfall 2 (over-aggressive polling / main-thread discipline), Pitfall 4 (concealed-marker convention is necessary but not sufficient — Bitwarden's documented gap), Pitfall 6 (no entitlement needed; macOS 15.4+/26 pasteboard-access prompt is a runtime UX consideration, not a signing issue)
- `.planning/research/SUMMARY.md` (lines 12-14, 49) — `ClipboardMonitor` architecture: `@MainActor`, constructor-injected `onChange`, idempotent `start()`/`nonisolated stop()`, owned by `AppDelegate` not `NotchWindowController`
- `.planning/research/ARCHITECTURE.md`, `.planning/research/FEATURES.md`, `.planning/research/STACK.md` — supporting detail for the above

### Prior phases (prerequisites this phase feeds/depends on)
- `.planning/phases/55-clipboard-data-model-store/55-CONTEXT.md` — `ClipboardStore`'s append/evict/clear contract this monitor's captured items must round-trip through (in Phase 58's real wiring)
- `.planning/phases/56-encrypted-persistence/56-CONTEXT.md` — the DEBUG-spike-hook + on-device-checkpoint pattern this phase's D-09 explicitly mirrors
- `Islet/Clipboard/ClipboardItem.swift`, `Islet/Clipboard/ClipboardStore.swift` — existing pure model/store (Phase 55, untouched by this phase)
- `Islet/Notch/NotchWindowController.swift` (lines 354, 1184, 1278) — existing `NSPasteboard(name: .drag).changeCount` polling precedent for drag detection; same main-thread, changeCount-gated discipline applies here

No external ADRs/specs beyond the project's own planning docs and dedicated milestone research.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchWindowController.swift` — existing `NSPasteboard(name: .drag).changeCount`-diff polling for drag detection (not a separate `DragApproachDetector` file — the polling lives inline in the controller). `ClipboardMonitor` should follow the same main-thread, changeCount-gated discipline but as its own independent class/timer — not sharing state with the drag-polling code (different pasteboard: `.general` vs `.drag`).
- `Islet/Licensing/`, `Islet/Shelf/ShelfFileStore.swift` — DEBUG-only spike-hook pattern already proven in Phase 56 (`AppDelegate`'s debug menu → `NotchWindowController` forwarding methods → monitor/store spike calls).

### Established Patterns
- No existing `NSPasteboard.general` read/write code anywhere in the codebase — genuinely new ground, though the `.drag`-pasteboard polling above is a close structural analog.
- No existing `org.nspasteboard.*` marker-type handling — new ground, baseline convention check is required scope per PRIV-01.
- DEBUG-only spike hook shape established in Phase 56 (`56-02-PLAN.md`/`56-02-SUMMARY.md`): `@objc private/internal` methods on `NotchWindowController`, forwarded from `AppDelegate`'s existing debug menu, guaranteed absent from Release builds (verified via build-log grep in Phase 49-01).

### Integration Points
- Phase 55's `ClipboardStore`/`ClipboardItem` — this phase's monitor emits classified items via callback; actual `store.append(...)` wiring is Claude's call during this phase's planning (either exercised directly against a throwaway store per D-09, or the callback simply logs/asserts during the spike).
- Phase 58 (menu wiring) is where `ClipboardMonitor`'s `onChange` callback gets wired to the REAL `ClipboardStore` + `ClipboardFileStore` for the first time, and where the final pasteboard-access-prompt explanation UI (superseding this phase's D-07 placeholder) gets built.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual references — this phase has no user-facing UI surface (the D-07 placeholder explanation is spike-quality only; real UI lands in Phase 58).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — matched by the todo/phase matcher (generic keyword overlap on "click", "phase", "device") but all are UI-domain issues (view switcher, calendar grid, Quick Action picker) unrelated to a pasteboard-monitoring spike with no UI surface. Not presented individually — same false-positive judgment as Phase 55/56's cross-reference.

</deferred>

---

*Phase: 57-Pasteboard Monitor — Spike*
*Context gathered: 2026-07-22*
