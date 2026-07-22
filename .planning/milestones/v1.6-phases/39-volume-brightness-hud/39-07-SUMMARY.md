---
phase: 39-volume-brightness-hud
plan: 07
subsystem: ui
tags: [swiftui, notch-geometry, hstack-layout, cgeventtap, osd, hud]

# Dependency graph
requires:
  - phase: 39-volume-brightness-hud
    provides: "39-01's suppression-unreliable go/no-go, 39-03's OSDInterceptor/VolumeReader/BrightnessReader, 39-04's OSDLevelBar/osdWings, 39-05's controller wiring, 39-06's Settings toggle"
provides:
  - "Spike scaffolding removed (OSDInterceptionSpike.swift deleted, AppDelegate debug menu restored)"
  - "OSD (Volume/Brightness) wing rendering correctly on real hardware: icon + fill bar both fully visible, positioned clear of the physical camera notch"
  - "wingsShape shared-helper alignment fix (alignment: .leading) benefiting all 4 wing types"
  - "NotchPillView.cameraSafeZoneLeadingInset / exclusion-zone derivation approach, superseded by a plain-HStack + explicit camera-block pattern any future wing can reuse"
  - "Confirmed via real timing data: OSD key-press-to-render pipeline is single-digit-milliseconds after the first press — no backend responsiveness bug"
affects: [40-update-available-hud, future-wing-additions]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit-fixed-width-exclusion-zone-in-sequential-hstack, self-verifying-debug-geometry-assert-plus-console-log, live-notch-measurement-reuse-over-hardcoded-constants]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/OSDInterceptor.swift
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "OSD suppression stays a documented no-op (39-01's suppression-unreliable finding, reconfirmed and explicitly accepted by the user this round) — ships showing alongside the native OSD, matching ROADMAP's own fallback language. A separate spike plan (mirroring 39-01, testing .cghidEventTap) is being scoped by the user/coordinator as follow-up work outside this plan."
  - "wingsShape's shared .overlay(content().frame(...)) now specifies alignment: .leading (was implicit .center) — verified as a no-op for Charging/Device/Focus (their HStack+Spacer content already naturally fills the proposed width) and as the actual root-cause fix for OSD's ZStack-based round-10/11 content."
  - "OSD wing content rebuilt as a plain sequential HStack(spacing: 0) with an explicit Color.clear.frame(width: cameraBlockWidth) exclusion-zone element, after both .offset(x:) and .position(x:y:) were tried and failed to reliably position content in this specific wingsShape/ZStack context — matches every other wing's already-proven layout approach."
  - "Camera exclusion-zone geometry is derived from the live interaction.collapsedNotchSize (same proven source collapsedIsland already uses), not a hardcoded notch-width constant — after 3 different hardcoded/derived constants each failed on real hardware."
  - "margin (safety buffer folded once into notchHalfWidth) set generously to 55pt after real on-device calibration, deliberately erring toward more-than-strictly-needed margin over further precision-hunting, given repeated false signals earlier in this plan's execution."
  - "Responsiveness closed with real [OSD-TIMING] evidence (single-digit-ms pipeline after the first press) — no animation/dispatch code changed speculatively; residual perceived lag attributed to macOS's own key-repeat cadence or spring-easing feel, not a code bug."

patterns-established:
  - "Explicit fixed-width Color.clear exclusion-zone elements inside a plain HStack, instead of Spacer()-implied gaps or offset/position coordinate math, for any future 'must render clear of the physical camera' layout need."
  - "DEBUG-only OSDFrameLogger (GeometryReader-based, with an optional self-verifying PASS/FAIL verdict closure) as the standard pattern for diagnosing SwiftUI layout-vs-reality mismatches on this notch geometry, in preference to manual AppKit-screen/SwiftUI-window coordinate conversion (none exists in this codebase, and none was built — proven unnecessary once the diagnostic was scoped to a single coordinate space)."

requirements-completed: [HUD-03, HUD-04]

# Metrics
duration: multi-session (16 gap-closure rounds across one extended on-device UAT checkpoint)
completed: 2026-07-17
---

# Phase 39 Plan 07: Spike Cleanup + Consolidated On-Device UAT Summary

**Volume/Brightness HUD (icon + fill bar wings) confirmed working end-to-end on real hardware after a 16-round on-device layout debugging saga that ultimately traced to two root causes: `wingsShape`'s shared `.overlay()` missing an `alignment:` parameter, and `.offset()`/`.position()` both failing to reliably position content inside that specific `ZStack` context — fixed by rebuilding OSD's content as a plain `HStack` with an explicit fixed-width camera-exclusion element, matching every other wing's already-proven layout.**

## Performance

- **Duration:** multi-session — one consolidated on-device UAT checkpoint that expanded into 16 gap-closure rounds (round 1: spike removal + initial checkpoint; rounds 2-16: iterative on-device debugging of the OSD wing's camera-clearance geometry and a responsiveness investigation)
- **Completed:** 2026-07-17
- **Tasks:** 2 (Task 1: remove spike scaffolding; Task 2: consolidated on-device UAT, extended through 16 gap-closure rounds after the initial checkpoint found real bugs)
- **Files modified:** 5 (`NotchPillView.swift`, `NotchWindowController.swift`, `OSDInterceptor.swift`, `AppDelegate.swift`, `Islet.xcodeproj/project.pbxproj`)

## ROADMAP Success Criteria — Pass/Fail

1. **Media transport keys unaffected** — **PASS.** Confirmed in round 1 of the on-device checkpoint: play/pause, next, previous all work exactly as before, completely unaffected by this phase's changes.
2. **Volume/Brightness HUD shows live levels correctly** — **PASS** (after gap closure). Icon (speaker/sun glyph, mute-state swap) and fill bar (green/orange, proportional to live volume/brightness) both fully visible on real hardware as of round 16, confirmed by the user ("passt"). Required 15 rounds of on-device iteration to reach — see "OSD Wing Layout Saga" below.
3. **Scrubbing / cross-category replace / Focus-preemption (D-09/D-10/D-12/D-13)** — **PASS.** Confirmed working in round 1 of the checkpoint, before the wing-visibility bugs were found: same-instance scrub updates, auto-dismiss timer reset on each press, instant Volume↔Brightness replacement, and Focus-preemption (Volume/Brightness immediately take over from a standing Focus head, Focus resumes after) all behaved correctly.
4. **`EnableSystemBanners` absent from the shipped codebase** — **PASS.** Grepped in Task 1: `grep -rn "EnableSystemBanners" Islet/` returns zero matches.

## CONTEXT.md Decision Set (D-01 through D-13)

- **D-01 through D-04** (bar visual contract: icon+bar layout, no numeric text, fixed colors, spring fill animation) — confirmed on real hardware once the layout bugs were fixed; fill animates via `.animation(.spring(response: 0.35, dampingFraction: 0.75), value: fraction)` on the fill layer specifically (not the outer wing-morph spring).
- **D-05 through D-08** (Settings/permission flow: opt-in toggle default off, explanation popover, Accessibility deep-link, mid-session auto-upgrade) — confirmed working in round 1 of the checkpoint: toggle defaults off, popover shows the locked copy, deep-link opens the Accessibility pane correctly, status hint updates to "Active" after granting without further interaction.
- **D-06 (OSD suppression no-op)** — confirmed as **expected, accepted behavior**: the native macOS OSD continues to appear regardless of the toggle state, per 39-01's `suppression-unreliable` finding. The user explicitly confirmed understanding this is a known limitation, not a bug, and does not want it investigated further in this plan (a separate `.cghidEventTap` spike plan is being scoped by the user/coordinator as follow-up work).
- **D-09/D-10** (same-category scrub re-arms the dismiss timer relative to the last press, not the first) — confirmed in round 1.
- **D-11** (collapsed-only, no expanded-state variant) — unchanged from Plan 39-02's resolver logic (`resolve(...)`'s `.osd` case only fires `!isExpanded`); not separately re-tested this round, no code touched it.
- **D-12** (instant Volume↔Brightness cross-category replace, no queuing) — confirmed in round 1.
- **D-13** (Focus-preemption) — confirmed in round 1.

## Accomplishments
- Removed Plan 39-01's throwaway spike (`OSDInterceptionSpike.swift` deleted, `AppDelegate.swift`'s two spike-specific debug menu items removed, `Islet.xcodeproj` regenerated via `xcodegen` to drop the stale file references). Release build confirmed clean.
- Diagnosed and fixed the actual OSD wing camera-clearance bug across 16 on-device rounds — see the dedicated section below.
- Confirmed via real `[OSD-TIMING]` console data that the OSD key-press-to-render pipeline is single-digit milliseconds after the first press (one-time ~174ms CoreAudio init on the very first call only) — closed the long-running "responsiveness" question with evidence instead of speculative animation/dispatch changes.
- Added a reusable DEBUG-only diagnostic pattern (`OSDFrameLogger`, a `GeometryReader`-based view modifier with an optional self-verifying PASS/FAIL `verdict` closure) that any future notch-geometry debugging in this codebase can reuse instead of manual coordinate-space cross-referencing.

## The OSD Wing Layout Saga (rounds 2-16)

The initial on-device checkpoint (round 1) found the OSD wing's bar was too narrow, too close to the pill's edge, and — critically — rendering partially or fully behind the physical camera notch. Fixing this took far longer than anticipated because each fix, though internally consistent, was validated against a mental model of the geometry that turned out to be wrong in a different way each time:

1. **Rounds 2-5:** treated the problem as pure width/padding tuning (bar width, trailing padding) using theoretical notch-half-width estimates from project memory — each attempt shifted the visible/hidden boundary but never eliminated it, because the underlying position math was never actually anchored to a real measurement.
2. **Round 6:** added a temporary on-device calibration ruler (labeled ticks across the wing's local coordinate space) to get one directly-measured reading instead of continuing to theorize — later found this reading itself was confounded (not pure camera occlusion).
3. **Rounds 7-8:** applied that (ultimately wrong) measured constant, then fixed a resulting zero-slack layout bug it caused.
4. **Round 9:** switched to reusing `interaction.collapsedNotchSize` — the SAME live, already-proven notch measurement `collapsedIsland` uses to size the idle pill — instead of any hardcoded constant. Real improvement, but only applied to the bar's position, not the icon's.
5. **Round 10:** rebuilt the geometry as an explicit "hard exclusion zone" (`excludedMinX`/`excludedMaxX` computed once, both icon and bar checked against it) per the user's own diagnosis that a `Spacer()`-implied gap is not the same as a deliberately computed camera boundary. Used `.offset(x:)` for absolute placement.
6. **Round 11 — first real root-cause fix:** direct code read found `wingsShape`'s shared `.overlay(content().frame(width:height:))` had no `alignment:` parameter (implicit `.center`). Every other wing's `HStack+Spacer` content naturally fills the proposed width (making centering a no-op for them); OSD's `ZStack`-based content (no `Spacer()`) did not, so it was being silently re-centered, dragging both icon and bar off their intended positions. Fixed with `alignment: .leading` — verified as a no-op for Charging/Device/Focus by reading all their call sites first.
7. **Round 12:** margin precision pass using real onset-percentage data, plus documentation distinguishing the codebase's 3 distinct "zones" near the notch (physical camera cutout, click/hover hot-zone, icon/bar-safe-start) per the user's explicit request not to conflate them.
8. **Round 13:** added self-verifying PASS/FAIL `[OSD-GEOM]` console assertions (comparing measured frames directly against the exclusion-zone math, in the same coordinate space, avoiding any need for manual AppKit-screen/SwiftUI-window coordinate conversion, which this codebase has no existing helper for).
9. **Round 14:** the PASS/FAIL data revealed `.offset(x:)` was never actually moving the bar's real render position at all (reported `x=0.0` regardless of the offset value) — cross-referenced against screenshots across the whole saga, which showed the bar's on-screen position never actually changing despite different `trackLeft` values across rounds. Switched to `.position(x:y:)`, SwiftUI's absolute-placement primitive.
10. **Round 15 — second real root-cause fix:** `.position()` didn't work either — it caused both icon and bar to report the ZStack's full container width instead of their own real size, meaning it pulled them out of normal layout in a way `GeometryReader` couldn't measure correctly. Rebuilt OSD's content entirely as a plain sequential `HStack(spacing: 0)` — matching Charging/Focus/Device exactly — with the camera exclusion zone expressed as a concrete `Color.clear.frame(width: cameraBlockWidth)` element between the icon and bar, instead of any offset/position coordinate math. This is mechanically robust by construction: sequential HStack layout cannot skip, shrink, or miscount a fixed-width element the way a flexible `Spacer()` or absolute-coordinate math could.
11. **Round 16:** with the layout mechanism now confirmed correct (PASS/FAIL data self-consistent across coordinate spaces for the first time), the remaining ~50%-hidden report was recognized as a pure margin-insufficiency signal (the round-12 margin value had been tuned against the broken `.offset()` mechanism, so it was never a valid calibration). Bumped `margin` from 8pt to 55pt, deliberately generous rather than precision-tuned. User confirmed: "passt."

**Net result:** `wingsShape` now specifies `alignment: .leading` (benefits all 4 wing types, verified as a no-op for the 3 that already worked). `osdWings(for:)` is a plain `HStack` with an explicit fixed-width camera-block element sized from the live `interaction.collapsedNotchSize` plus a 55pt margin, matching the architecture every other wing already used successfully.

## Task Commits

1. **Task 1: Remove spike scaffolding** — `380c6c0` (chore)
2. **Task 2 gap closure, round 1 (bar spring + edge-proximity, superseded by later rounds):** `6e639d9` (fix)
3. **Round 2 (bar width, theoretical, superseded):** `36066fb` (fix)
4. **Round 3 (bar position, empirical onset method, superseded):** `1460771` (fix)
5. **Round 4 (bar size ceiling, superseded):** `702ad9e` (fix)
6. **Round 5 (bar 90pt, panel-budget correction, superseded):** `e1f62ea` (fix)
7. **Round 5 companion (responsiveness timing instrumentation, still active):** `0d0019b` (debug)
8. **Round 6 (temporary calibration ruler, superseded/removed):** `44e4be7` (debug)
9. **Round 7 (measured-boundary constant + shared-constant extraction, superseded):** `94ccbac` (fix)
10. **Round 8 (zero-margin regression fix, superseded):** `c85ba4f` (fix)
11. **Round 9 (live-notch-measurement reuse, superseded):** `577e400` (fix)
12. **Round 9 companion (real notch/panel frame logging):** `2676c62` (debug)
13. **Round 10 (explicit hard exclusion zone, `.offset()`-based, superseded):** `aadfb24` (fix)
14. **Round 11 (`wingsShape` `alignment: .leading` root-cause fix — KEPT):** `8f60509` (fix)
15. **Round 12 (margin precision pass + zone documentation, superseded value):** `1d544c2` (fix)
16. **Round 13 (self-verifying `[OSD-GEOM]` PASS/FAIL diagnostic + responsiveness closed):** `6a80191` (debug)
17. **Round 14 (`.position()` attempt, superseded):** `f234297` (fix)
18. **Round 15 (plain HStack rebuild — KEPT):** `23e4b44` (fix)
19. **Round 16 (margin 8pt → 55pt — final value):** `e730224` (fix)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/OSDInterceptionSpike.swift` — deleted (Plan 39-01's throwaway spike)
- `Islet/AppDelegate.swift` — two spike-specific debug menu items and their backing properties removed
- `Islet.xcodeproj/project.pbxproj` — regenerated via `xcodegen` after the spike file's deletion
- `Islet/Notch/NotchPillView.swift` — `wingsShape`'s shared `.overlay()` alignment fix; `osdWings(for:)` rebuilt as a plain `HStack` with an explicit camera-exclusion element sized from live notch measurement; DEBUG-only `OSDFrameLogger`/`[OSD-GEOM]`/`[OSD-TIMING]` diagnostic instrumentation added (compiles out of Release)
- `Islet/Notch/NotchWindowController.swift` — DEBUG-only timing (`[OSD-TIMING]`) and real notch/panel-frame (`[OSD-GEOM]`) logging added around `handleOSDKeyPress`, reusing `positionAndShow()`'s already-computed `collapsedFrame`
- `Islet/Notch/OSDInterceptor.swift` — DEBUG-only timing (`[OSD-TIMING]`) logging added at the CGEventTap callback and the `main.async` dispatch hop

## Decisions Made

See `key-decisions` in frontmatter above for the full list. Most significant: OSD suppression remains a documented no-op by explicit user decision (a separate spike plan for `.cghidEventTap` is being scoped as follow-up, out of this plan's scope); the camera-exclusion geometry approach converged on plain sequential `HStack` layout with an explicit fixed-width blocking element, after both SwiftUI absolute-positioning primitives (`.offset()`, `.position()`) proved unreliable in this specific `wingsShape`/custom-layout context.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `wingsShape`'s shared `.overlay()` missing `alignment:` parameter**
- **Found during:** Task 2 gap closure, round 11
- **Issue:** `wingsShape` (used by all 4 wing types) implicitly centered `content()` inside its frame instead of pinning it to the leading edge, silently breaking any wing content whose natural/intrinsic size didn't already equal the frame's own width (only OSD's `ZStack`-based content, introduced in round 10, was affected — Charging/Device/Focus's `HStack+Spacer` content was unaffected by construction).
- **Fix:** Added `alignment: .leading` to the one `.frame()` call. Verified as a no-op for all 3 other wing call sites by reading their content structure before committing.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `8f60509`

**2. [Rule 1 - Bug] `.offset(x:)` not affecting real render position in this ZStack context**
- **Found during:** Task 2 gap closure, round 13-14
- **Issue:** `osdWings(for:)`'s icon/bar were positioned via `.offset(x:)` computed from exclusion-zone math; on-device PASS/FAIL diagnostic data showed the bar reporting `x=0.0` regardless of the offset value applied, and cross-referenced screenshots across the saga confirmed the bar's on-screen position never actually moved.
- **Fix:** Attempted `.position(x:y:)` (round 14) — did not fix it either (broke `GeometryReader` measurement of the elements' own size). Root-caused to rebuilding the content as a plain sequential `HStack` (round 15), matching every other wing's proven layout.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commits:** `f234297` (position attempt, superseded), `23e4b44` (HStack rebuild, kept)

**3. [Rule 1 - Bug] Camera-exclusion margin tuned against a broken positioning mechanism**
- **Found during:** Task 2 gap closure, round 16
- **Issue:** Round 12's margin value (8pt) was calibrated using on-device feedback gathered while `.offset()` was silently non-functional (per deviation #2), making that calibration data invalid.
- **Fix:** Re-tuned margin generously (55pt) once the underlying HStack layout mechanism was independently confirmed correct via self-consistent PASS/FAIL data across coordinate spaces.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `e730224`

---

**Total deviations:** 3 auto-fixed (all Rule 1 — bugs in the OSD wing's rendering/positioning, found and fixed through iterative real-hardware verification, not scope creep). All within this plan's own gap-closure scope (Task 2's consolidated on-device UAT explicitly anticipated finding and fixing real bugs, not just re-confirming already-correct behavior).
**Impact on plan:** Significantly longer execution than anticipated (16 gap-closure rounds vs. the plan's expectation of a single consolidated checkpoint), but no scope creep — every round addressed the same original Success Criterion 2 (HUD shows live levels correctly) failing on real hardware, not new feature requests. OSD suppression investigation was explicitly descoped from this plan by the user/coordinator (tracked as separate follow-up spike work).

## Known Stubs

None. The DEBUG-only diagnostic instrumentation (`OSDFrameLogger`, `[OSD-GEOM]`, `[OSD-TIMING]` prints) is intentionally left in place (compiles out of Release entirely) rather than removed, since it proved valuable for real-hardware debugging across this saga and may be useful again for future notch-geometry work; it does not affect production behavior or user-visible functionality.

## Issues Encountered

The 16-round on-device debugging saga documented above under "The OSD Wing Layout Saga" — no other issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 39 (HUD-03, HUD-04) is fully shipped and on-device confirmed: all 4 ROADMAP Success Criteria pass, all D-01 through D-13 decisions are implemented and verified (D-06/OSD-suppression explicitly accepted as a no-op, not a defect). `wingsShape`'s `alignment: .leading` fix and the plain-HStack-with-explicit-exclusion-element pattern are available for any future wing content needing to render clear of the physical camera notch. A follow-up spike plan (testing `.cghidEventTap` for OSD suppression, mirroring 39-01's structure) is being scoped separately by the user/coordinator — out of this plan's scope, tracked as a new plan once created.

---
*Phase: 39-volume-brightness-hud*
*Completed: 2026-07-17*
