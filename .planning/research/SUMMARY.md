# Project Research Summary

**Project:** Islet — v1.4 "Architecture Redesign" (window-shell rewrite + onboarding + sidebar Settings + glass theming + calendar view)
**Domain:** Native macOS notch-overlay utility, rewriting a shipped app's core AppKit/SwiftUI window shell and layering four new feature areas on top
**Researched:** 2026-07-11
**Confidence:** MEDIUM-HIGH

## Executive Summary

This is not greenfield research — Islet is a shipped, on-device-verified macOS notch utility, and this research milestone answers five specific questions: how to rewrite the `NotchPanel`/`NotchWindowController` shell to finally resolve the Phase 22 drag-in blocker, and how to build onboarding, a sidebar Settings redesign, frosted/glossy Material theming, and a full calendar view on top of it. All four research tracks converge on the same architectural verdict: keep Islet's existing custom `NSPanel` shell (neither TheBoringNotch nor DynamicNotchKit should be adopted as a dependency), but replace the ONE mechanism that has twice failed on-device — `NSDraggingDestination`/`registerForDraggedTypes` on the window — with the global-`NSEvent`-monitor + `NSPasteboard(name: .drag)` polling pattern TheBoringNotch actually ships in production, only handing off to SwiftUI `.onDrop` once the island is already expanded and interactive. Every other capability (onboarding carousel, `NavigationSplitView` Settings, `NSVisualEffectView`/`Material`-based theming, calendar month grid via EventKit) is coverable entirely with first-party AppKit/SwiftUI/EventKit/Foundation APIs — no new SPM dependency is required anywhere in this milestone.

The recommended approach is strict sequencing, not a single big rewrite: prove the rebuilt shell is behaviorally identical to today (hover/click/fullscreen/multi-Space/click-through) BEFORE re-attempting drag-in on top of it, because Phase 22's two on-device failures were never conclusively root-caused and re-building drag-in and the shell simultaneously would make a third failure undiagnosable. Onboarding, theming, and Settings-sidebar work have no hard dependency on the shell rewrite and can proceed in parallel; the calendar view is only soft-dependent on the shell if it ends up needing a new interaction affordance (unlikely, since gesture navigation is explicitly out of scope).

The key risks are: (1) the `draggingEntered` mystery could resurface in a new shape if the rewrite isn't disciplined about testing one variable at a time against a known-good 4-method baseline; (2) a "rewrite informed by reference apps" risks silently dropping Islet's own hard-won, invisible-until-you-hit-the-bug fixes (the Phase 9 CGS-Space fullscreen fix, the CR-01 single-arbiter click-through discipline) because those fixes aren't things a fresh reference-app pattern-match would naturally reproduce; and (3) two new feature areas introduce genuinely new permission surfaces (Reminders write access, and possibly broader Calendar write access) that don't fit this codebase's existing "lazy-request, never-retry" contract cleanly — this needs an explicit, locked decision during onboarding/calendar planning, not an implicit one.

## Key Findings

### Recommended Stack

No new dependencies. The shell rewrite uses AppKit `NSPanel`/global `NSEvent` monitors/`NSPasteboard`; theming uses `NSVisualEffectView` bridged via `NSViewRepresentable` (not raw SwiftUI `.ultraThinMaterial`, which reads as too transparent for the explicitly-requested "glossy, substantial" look); Settings uses `NavigationSplitView` + `.toolbar(removing: .sidebarToggle)` (macOS 14+, at Islet's existing floor); calendar uses the already-integrated `EKEventStore`, extended with a `fetchMonth(...)` method and (for quick-add) `requestFullAccessToReminders()`/`EKReminder`, which requires a new `NSRemindersFullAccessUsageDescription` Info.plist key not currently present in `project.yml`.

**Core technologies:**
- Global `NSEvent` monitors (`.leftMouseDown/.leftMouseDragged/.leftMouseUp`) + `NSPasteboard(name: .drag)` polling — replaces `NSDraggingDestination` entirely for drag-approach detection; the same event family already powers Islet's proven hover monitor.
- SwiftUI `.onDrop(of:isTargeted:perform:)` on the expanded shelf view — receives the actual drop payload only once the panel is already interactive (non-click-through), sidestepping the whole "does AppKit drag delivery survive a click-through never-key panel" question.
- `NSVisualEffectView` via `NSViewRepresentable` — frosted/glossy material fill; both reference apps independently converged on this over raw SwiftUI `Material`.
- `NavigationSplitView` + `List(selection:)` — sidebar Settings, byte-for-byte matches TheBoringNotch's own shipped `SettingsView.swift` shape.
- `EKEventStore` extensions (`fetchMonth`, `requestFullAccessToReminders`) — additive to the already-shipped `CalendarService` seam from Phase 14.

### Expected Features

**Must have (table stakes, v1.4 launch):**
- Onboarding carousel: hero → trial/license/buy choice → permission pre-explanation → done, replacing today's passive Settings-only license flow.
- Frosted/glossy Material pill fill (collapsed + expanded + wings) with a moderately slower default spring.
- `NavigationSplitView` Settings with 4 sections: General, Workspace (Shelf), System (Theming), About/License.
- Calendar full view: month grid + day event list + hand-built quick-add form (Apple's `EKEventEditViewController` has no macOS availability), as the 3rd view-switcher slot.

**Should have (v1.x, add after validation):**
- Animation Speed presets (Turtle/Human/Cheetah/Falcon-style), once the new default spring feel is validated on-device.
- "Permissions Overview — X of Y granted" rollup row and "Replay onboarding" button.
- Theming surface-style picker (Dynamic Glass vs. flat Black) and per-element color pickers.

**Defer (v2+):**
- `.glassEffect()`/Liquid Glass progressive enhancement (requires macOS 26.0+, would silently cut off most of the current install base at Islet's macOS 14.0 floor).
- System HUD replacement grid — long-deferred backlog item, separate milestone.
- Full calendar CRUD, plugin-marketplace Settings section, in-app gesture tutorial — all explicitly rejected as scope creep beyond what Islet actually is.

### Architecture Approach

Keep the existing custom `NotchPanel: NSPanel` + `NotchWindowController` shape — both reference implementations (TheBoringNotch, DynamicNotchKit) confirm this is structurally the correct primitive, and DynamicNotchKit's transient expand/hide/rebuild lifecycle is actively wrong for Islet's persistent always-visible pill. The one component being genuinely replaced is drag-in detection: delete the residual `NSDraggingDestination` conformance and 4 stub overrides from `NotchPanel.swift`, add a new `DragApproachDetector` (global monitors + pasteboard polling + geometric hit-test) owned by `NotchWindowController` exactly like `PowerSourceMonitor`/`BluetoothMonitor` are today, feeding the SAME `.dragEntered` state-machine transition and `DragDropSupport.swift` pure seams Phase 22-02 already built and unit-tested — that work is not wasted, only the AppKit glue that feeds it changes.

**Major components:**
1. `NotchPanel` — window shell only; rewritten to drop `NSDraggingDestination`, otherwise unchanged shape (styleMask/level/collectionBehavior/`ignoresMouseEvents` toggle point).
2. `NotchWindowController` — single AppKit↔SwiftUI arbiter; core (hover hit-test, state-machine drive, `resolve()` calling, monitor ownership) preserved verbatim; only geometry/hit-test/drag-registration internals change. New `DragApproachDetector` owned here.
3. `IslandResolver`/`NotchInteractionState`/`NotchGeometry`/`DragDropSupport`/`ShelfCoordinator`/`CGSSpace` — all pure or already-independent seams, UNTOUCHED by the redesign by construction.
4. `NotchPillView` (SwiftUI) — hosts theming/onboarding/calendar UI work, layered on top of whatever shell exists, no shell dependency once shell parity is proven.

### Critical Pitfalls

1. **The `draggingEntered` mystery could rebuild itself into the new architecture** — root cause of the two Phase 22 on-device failures is still genuinely unknown. Prevention: re-run the exact 4-method known-good spike shape on the new shell FIRST, then change exactly one variable at a time (closures, then `draggingEnded` specifically — the one unexplained code-shape delta between working and failing) with an on-device check after each. Given the stack/architecture recommendation is to abandon `NSDraggingDestination` entirely in favor of the global-monitor pattern, this pitfall is largely sidestepped rather than solved — but the new `DragApproachDetector` still deserves its own one-variable-at-a-time on-device validation discipline since it's an unproven pattern in this exact codebase.
2. **The rewrite silently regresses 4 milestones of on-device-verified interaction behavior** (hover/click/fullscreen/multi-Space/click-through) — no headless test can catch this. Prevention: characterization tests on `nextState`/`syncClickThrough` before touching the shell, and a full Phase 2 + Phase 9 + CR-01/WR-01 on-device UAT re-run as an explicit phase gate before the shell-rewrite phase closes.
3. **Phase 9's private-API CGS-Space fullscreen fix gets half-copied or dropped** — it's invisible in any reference app and has no user-visible effect except eliminating a specific 1-frame flash. Prevention: explicitly re-verify the CGS Space join is present and additive, and re-run all 3 documented fullscreen trigger methods on-device.
4. **Onboarding races or duplicates the existing first-launch trial/license hook** in `AppDelegate.swift` (lines 25-94) — and a front-loaded permissions screen risks permanently degrading a feature for any user who reflexively denies, given every existing service's "never retry, never re-prompt" contract. Prevention: replace (don't parallel-gate) the existing `isFirstLaunch` branch; default the permissions screen to educational-only, keep real requests lazy-at-first-use.
5. **Settings sidebar split drops the license-state refocus re-sync** currently anchored to the whole window's `onAppear`/`appearsActive` lifecycle — decomposing into per-section child views without hoisting this logic causes stale license/login-item state on section switch. Prevention: hoist the re-sync to the `NavigationSplitView` container, not each child view.
6. **CalendarService widening for write access breaks the existing read-only glance, and Reminders needs a permission never requested before** — the single-conformer protocol has no precedent for a second consumer with different requirements; Reminders is a wholly separate `EKEntityType`/Info.plist key from Calendar. Prevention: add new methods rather than modifying `fetchUpcoming`'s existing contract; confirm quick-add targets Calendar vs. Reminders before writing any code, add `NSRemindersFullAccessUsageDescription` if needed.

## Implications for Roadmap

Based on research, suggested phase structure (all 4 research tracks agree on this ordering):

### Phase 1: Shell Parity Rewrite
**Rationale:** The window shell is the actual unproven integration point now (not drag-in) — every other feature area sits on top of `NotchPanel`/`NotchWindowController`, and Phase 22 conflated shell-soundness with drag-feature risk, making its failure undiagnosable. This phase isolates shell risk alone, proven regression-free, before anything else touches it.
**Delivers:** Rebuilt `NotchPanel`/AppKit-facing slice of `NotchWindowController` with the residual `NSDraggingDestination` scaffold deleted, byte-for-byte-equivalent external behavior to today (position/hide/hover/click/CGS-Space/click-through), optionally with `HoverInteractionController` extracted per the project's own established coordinator-split convention (Phase 16 precedent).
**Addresses:** No new FEATURES.md item directly — this is the architectural prerequisite for SHELF-01/02 (drag-in).
**Avoids:** Pitfalls 1, 2, 3 (draggingEntered mystery, regression of 4 verified milestones, CGS-Space fix drop). Explicit acceptance criteria: 0 diff to `IslandResolver.swift`/`DeviceCoordinator.swift`/`Islet/Shelf/`; full Phase 2 + Phase 9 + CR-01/WR-01 UAT re-run.

### Phase 2: Drag-In via DragApproachDetector
**Rationale:** Hard-dependent on Phase 1 only. Reuses Phase 22-02's already-built-and-tested `DragDropSupport.swift`/`.dragEntered` seams verbatim, so this phase is materially smaller than the original Phase 22 — wiring, not invention.
**Delivers:** New `DragApproachDetector` (global monitors + pasteboard polling + geometric region hit-test) + SwiftUI `.onDrop` wiring on the expanded shelf view.
**Uses:** Global `NSEvent` monitor + `NSPasteboard(name: .drag)` pattern from STACK.md; `NotchGeometry`/`expandedZone` math reused for region computation.
**Implements:** Architectural Pattern 1 (global-monitor drag detection, AppKit drag-destination only once already-interactive).

### Phase 3: Visual/Material Theming Redesign
**Rationale:** No shell dependency once Phase 1 lands (can run in parallel with Phase 2 or even before it — different files, zero shared surface).
**Delivers:** `NSVisualEffectView`-backed frosted/glossy pill fill (collapsed + expanded + wings) via one shared `NotchMaterialStyle` token, tuned slower default spring.
**Addresses:** FEATURES.md Area 2 table stakes (non-transparent frosted fill, shared material token, legible-content baseline).
**Avoids:** Pitfall 6 (Material looking flat because the panel is permanently unfocused) — on-device visual approval in the real never-focused `NotchPanel` runtime, mid-spring-morph, is the acceptance gate, not Xcode preview.

### Phase 4: Onboarding Flow
**Rationale:** Independent of Phases 1-2 (touches `AppDelegate`/app-launch sequencing and Settings, not notch shell mechanics), but should sequence before general "resume normal use" polish since it governs first impressions and permission-request timing.
**Delivers:** Onboarding carousel (hero → trial/license/buy → permission pre-explanation → done) that directly replaces (not parallels) `AppDelegate.swift`'s existing `isFirstLaunch` → `openSettings()` branch.
**Addresses:** FEATURES.md Area 1 table stakes.
**Avoids:** Pitfall 4 (racing/duplicating the existing first-launch hook; front-loaded irreversible permission denial) — locked decision required: permissions screen is educational-only, real requests stay lazy-at-first-use.

### Phase 5: Settings Sidebar Redesign
**Rationale:** Independent of Phases 1-2; naturally sequenced after or alongside Phase 3/4 since it hosts their controls (Theming section, Permissions Overview, Replay-onboarding).
**Delivers:** `NavigationSplitView` Settings with General/Workspace/System/About-License sections, replacing the single tabbed `Form`.
**Uses:** `NavigationSplitView` + `.toolbar(removing: .sidebarToggle)` from STACK.md.
**Avoids:** Pitfall 5 (license-state refocus re-sync dropped per section) — hoist re-sync logic to the `NavigationSplitView` container.

### Phase 6: Calendar Full View
**Rationale:** Soft-dependent on Phase 1 only if it needs a new interaction affordance beyond click/hover (unlikely, since gesture navigation is explicitly deferred) — otherwise independent, and depends on Phase 3's theming/Phase 5's view-switcher slot conceptually more than the shell.
**Delivers:** Month grid + day event list + hand-built quick-add form, as the 3rd view-switcher slot alongside Home/Tray.
**Addresses:** FEATURES.md Area 4 table stakes and differentiators.
**Avoids:** Pitfall 7 (CalendarService widening breaking the existing glance; missing Reminders permission) — additive methods only, explicit Calendar-vs-Reminders scope decision locked before implementation, `NSRemindersFullAccessUsageDescription` added to `project.yml` if needed.

### Phase Ordering Rationale

- Phase 1 must come first: it is the one phase every other phase's stability assumption rests on, and it is the phase where "rewrite touches shared 1378-line arbiter file" risk is highest.
- Phase 2 must follow Phase 1 directly (hard dependency) — attempting drag-in before the shell is reproven is a literal re-run of Phase 22's failure mode.
- Phases 3, 4, 5, 6 have no hard dependency on Phase 1/2 and can be parallelized or reordered for throughput — the one invariant is that Phase 2 (drag-in) must never be attempted before Phase 1 (shell parity) closes.
- This grouping directly mirrors ARCHITECTURE.md's own "De-Risking Sequencing" analysis and PITFALLS.md's Pitfall 2 recommendation (isolate the risky base layer, gate on full on-device UAT, before layering new features on top).

### Research Flags

Needs research during planning (`--research-phase`):
- **Phase 1 (Shell Parity Rewrite):** The `draggingEntered` root cause remains genuinely unresolved after two on-device debugging rounds; even with the architecture pivoting away from `NSDraggingDestination`, the new `DragApproachDetector` pattern is unproven in this codebase and deserves its own isolated-spike validation protocol during planning.
- **Phase 6 (Calendar Full View):** Whether the existing `CalendarService`/Info.plist grant already covers full-access (not just read) Calendar authorization, and whether quick-add targets Calendar events vs. Reminders, must be verified against actual Phase 14 code before implementation — flagged LOW-MEDIUM confidence in FEATURES.md pending phase-specific verification.

Phases with standard, well-documented patterns (skip research-phase):
- **Phase 2 (Drag-In):** Pure seams already exist and are unit-tested (Phase 22-02); this phase is wiring against a proven external pattern (TheBoringNotch's `DragDetector.swift`), not invention.
- **Phase 3 (Theming):** `NSVisualEffectView` bridging is long-stable AppKit API (macOS 10.10+); the only open question is design taste, resolved via on-device iteration, not research.
- **Phase 4 (Onboarding):** Plain SwiftUI `enum`/`switch`/`withAnimation` pattern, directly matches TheBoringNotch's own shipped `OnboardingView.swift`.
- **Phase 5 (Settings Sidebar):** `NavigationSplitView` is official, well-documented SwiftUI API at macOS 13+, well below Islet's floor.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every recommendation grounded in actual fetched source from TheBoringNotch/DynamicNotchKit `main` branches plus official Apple docs plus Islet's own current on-disk source — not summarized from training-data memory. |
| Features | MEDIUM-HIGH | SwiftUI/AppKit/EventKit API claims verified against official docs; UX-pattern claims (permission pre-explanation grant-rate improvement, `NavigationSplitView` Settings patterns) rest on WebSearch community consensus, not Apple-official guidance. |
| Architecture | MEDIUM-HIGH | Grounded directly in this project's own git history (real commit diffs of the working spike vs. failing production wiring) plus fetched reference-repo source — genuinely strong evidence, but the residual drag-delivery root cause is explicitly still unresolved, which caps confidence on Phase 2 specifically. |
| Pitfalls | MEDIUM-HIGH | Grounded in this project's own phase history, STATE.md blockers, and direct reads of current source files; the drag-registration mystery itself is flagged LOW confidence on any single explanation even though the ranked-candidate methodology is well-evidenced. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Drag delivery root cause:** Still unresolved after two on-device debugging rounds. The architecture pivot away from `NSDraggingDestination` sidesteps rather than closes this gap — Phase 1/2 planning should still budget for the possibility that the new `DragApproachDetector` pattern needs its own isolated on-device validation rounds, not assume it will "just work" because it's proven elsewhere.
- **Calendar authorization tier:** Whether Islet's existing Info.plist/EventKit call already requests full (not read-only) Calendar access is unverified against actual Phase 14 code — must be confirmed during Phase 6 planning, not assumed.
- **Reminders vs. Calendar target for quick-add:** Not yet decided as a product question — this determines whether a new `NSRemindersFullAccessUsageDescription` Info.plist key and a wholly new permission flow are needed. Lock this decision explicitly during Phase 6's discuss-phase step.
- **Material rendering mid-spring-morph:** No source (including this research) confirms whether SwiftUI `Material`/`NSVisualEffectView` composites artifact-free during an active `matchedGeometryEffect` collapse↔expand animation in Islet's specific never-focused panel configuration — budget multiple on-device visual-iteration rounds for Phase 3 as the default expectation, per this project's own history (Phase 18, Phase 20).
- **Onboarding permissions screen behavior (educational vs. real-request):** PITFALLS.md flags this as a locked discuss-phase decision, not a default — must be explicitly captured in Phase 4's CONTEXT.md before implementation begins.

## Sources

### Primary (HIGH confidence)
- `github.com/TheBoredTeam/boring.notch` — fetched `main` branch directly: `BoringNotchWindow.swift`, `DragDetector.swift`, `ShelfDropService.swift`, `SettingsView.swift`, `OnboardingView.swift`, `ContentView.swift`, `sizing/matters.swift`.
- `github.com/MrKai77/DynamicNotchKit` — fetched `main` branch: `Package.swift`, `DynamicNotchPanel.swift`, `VisualEffectView.swift`, `DynamicNotch.swift`.
- `developer.apple.com` — `NavigationSplitView`, `toolbar(removing:)`, `EKEventStore.requestFullAccessToEvents()`/Reminders sibling API, `glassEffect(_:in:)`, `Material`, `NSVisualEffectView`, `EventKitUI`/`EKEventEditViewController` official docs.
- This project's own git history (`gsd-new-project-setup` branch, commits `7571001`, `326804d`, `8fb5517`, `8af3e77`, `d1245e8`, `8dbd064`) — read directly via `git show`.
- `Islet/Notch/NotchPanel.swift`, `NotchWindowController.swift`, `CGSSpace.swift`, `NotchGeometry.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/SettingsView.swift`, `Islet/AppDelegate.swift`, `Islet/Licensing/TrialManager.swift`/`LicenseState.swift`, `project.yml` — current on-disk source, read in full.
- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/22-drag-in/*` — full phase history including on-device UAT verdicts.

### Secondary (MEDIUM confidence)
- WebSearch — macOS/mobile permission pre-prompt UX best practices (contextual timing, grant-rate improvement).
- WebSearch — SwiftUI `Material` vs `NSVisualEffectView` for custom glass surfaces; `Material`/`glassEffect` degradation on non-focused windows.
- WebSearch — `NavigationSplitView` macOS Settings-window patterns (`.toolbar(removing: .sidebarToggle)`, persisted section selection).
- WebSearch — EventKit macOS 14+ full-access vs. write-only vs. Reminders-separate-scope permission model, corroborated by WWDC23 session material.
- philz.blog "The Curious Case of NSPanel's Nonactivating Style Mask Flag" — corroborates this panel configuration is a documented source of undocumented AppKit behavior, though not directly the drag-delivery mystery.

### Tertiary (LOW confidence)
- The `draggingEntered` residual-failure root cause (Hypotheses H1-H4 in ARCHITECTURE.md, the `draggingEnded` "NEW LEAD" in PITFALLS.md) — grounded in real evidence but explicitly unresolved; treat as a ranked-candidate list to test during Phase 1/2 execution, not a settled finding.

---
*Research completed: 2026-07-11*
*Ready for roadmap: yes*
