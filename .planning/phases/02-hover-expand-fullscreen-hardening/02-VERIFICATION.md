---
phase: 02-hover-expand-fullscreen-hardening
verified: 2026-06-27T15:50:00Z
status: human_needed
score: 4/4 must-haves verified at code level
overrides_applied: 0
human_verification:
  - test: "Hover/click feel — move the pointer onto the pill, then click to expand"
    expected: "Hover fires a trackpad haptic + a subtle bounce WITHOUT expanding (D-01); a click expands with a snappy spring morph (D-02); pointer-leave collapses after ~0.4s grace; a quick re-entry cancels the collapse"
    why_human: "Haptic feel, bounce magnitude, spring snappiness, and grace timing are tactile/temporal qualities greps cannot judge; the global .mouseMoved monitor's unprompted firing on Tahoe (A1 probe) can only be confirmed on-device"
  - test: "Morph quality — watch a full expand→collapse cycle"
    expected: "The black blob MORPHS as one shape (corner radius + frame interpolate) with no cross-fade, no flicker, no jump (ISL-04 / SC#2)"
    why_human: "Visual smoothness of the matchedGeometryEffect morph is a perceptual quality; code proves single-morph + spring-at-mutation but not the rendered feel"
  - test: "Fullscreen VIDEO yield — enter fullscreen YouTube (Safari) and QuickTime fullscreen on the built-in notched display"
    expected: "The island hides completely (no ghost bar); exiting restores it"
    why_human: "Resolves RESEARCH Q2 — only NATIVE fullscreen was on-device verified; whether the CGS current-space type==4 probe also catches video fullscreen kinds is untested"
  - test: "QuickLook yield — Finder → select file → Space → toggle QuickLook fullscreen"
    expected: "The island hides while QuickLook is fullscreen; closing restores it"
    why_human: "Resolves RESEARCH Q2 — QuickLook may or may not take a dedicated fullscreen Space; untested on-device"
  - test: "Maximized window must STAY visible — double-click title bar / option-click green button (zoom, NOT fullscreen)"
    expected: "The island stays visible (a merely maximized/zoomed window is not a fullscreen Space, D-09)"
    why_human: "Confirms the exclusion boundary — a false positive here would wrongly hide the island over normal maximized windows"
  - test: "Clamshell + external-display coexistence — close/open the lid; enter fullscreen on the external while the built-in is present"
    expected: "No flicker, no stuck-hidden, no stuck-shown; the island only ever shows on the built-in notched display"
    why_human: "Multi-display Space transitions and the didChangeScreenParameters + activeSpaceDidChange interplay can only be exercised with real hardware"
  - test: "Focus-safety of the auto-restore — let fullscreen exit while another app is foreground"
    expected: "Restoring the island (orderFrontRegardless only) does NOT steal focus from the foreground app (D-04 / SC#4)"
    why_human: "Focus theft is observable only at runtime; greps confirm zero focus-stealing calls but cannot prove the live foreground app keeps focus"
  - test: "Click-through around the island — click the desktop / menu bar OUTSIDE the pill while idle and while expanded"
    expected: "Clicks outside the pill pass through to whatever is underneath; interacting with the island never activates Islet (SC#4)"
    why_human: "Conditional ignoresMouseEvents pass-through is a live event-routing behavior; the WR-02 toggle-shut/exit edge case in particular needs on-device confirmation"
known_deferred:
  - item: "~1-frame island flash at the END of the fullscreen-ENTER transition"
    reason: "Root-caused as window-server compositing of the .canJoinAllSpaces panel onto the activating fullscreen Space; our orderOut is reactive and cannot pre-empt it. Negligible in release (pill ships pure black / flush). Product-deferred by the user to a later polish phase (Plan 05 / Phase 6). NOT an ISL-04 morph flicker — the expand/collapse morph itself is clean."
    documented_in: "02-04-SUMMARY.md § Known issues"
---

# Phase 2: Hover, Expand & Fullscreen Hardening — Verification Report

**Phase Goal:** The island feels like a Dynamic Island — it expands on hover with a smooth spring morph, collapses back to a quiet pill, and correctly yields the notch region to true fullscreen apps.
**Verified:** 2026-06-27T15:50:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria + merged PLAN must_haves)

> Note on SC#1: ROADMAP/REQUIREMENTS wording says "hovering the notch expands." Decision **D-02** (02-CONTEXT.md, 02-DISCUSSION-LOG.md) explicitly supersedes this with the **Alcove click-to-open** model (hover = haptic + bounce affordance only; click expands). The user chose to proceed without editing the ROADMAP wording and instructed the verifier to "treat click-to-open as authoritative." SC#1 is therefore verified against the click-to-open model, not literal hover-expand.

| # | Truth (Success Criterion) | Status | Evidence |
|---|---------------------------|--------|----------|
| 1 | Pointer onto the notch gives an affordance and the island opens; moving away collapses it back to the quiet pill (D-02 click-to-open supersedes literal hover-expand) | ✓ VERIFIED (code) — feel pending human | `NotchInteractionState.nextState` transition table: `.collapsed+.pointerEntered→.hovering` (hover never expands), `.clicked→.expanded`, `.pointerExited` defers, `.graceElapsed→.collapsed`. Controller drives it via global `.mouseMoved` monitor + 0.4s grace timer + `handleClick`. 15 unit tests pass. Tactile feel = human item. |
| 2 | Expand/collapse animate as a smooth spring morph (Alcove-quality), no flicker/jump/cross-fade | ✓ VERIFIED (code) — visual pending human | Single `matchedGeometryEffect(id: "island", in: ns)` on BOTH collapsed and expanded blobs (NotchPillView:68,82) → one morph, no cross-fade. `withAnimation(.spring(response:0.35,dampingFraction:0.65))` at all 4 mutation sites; view drives no animation (D-08). Panel sized to expanded frame up front (no clip). Visual smoothness = human item. |
| 3 | True fullscreen (native, video, QuickLook) hides the island with no ghost bar, restores on exit | ✓ VERIFIED (code) — native on-device VERIFIED; video/QuickLook pending human | `isBuiltinDisplayInFullscreenSpace` (CGS current-space type==4) feeds the pure `shouldShow` AND in `updateVisibility`; single `orderOut`. **Native fullscreen confirmed on-device (Tahoe), type==4.** Video/QuickLook/maximized-exclusion = human items (RESEARCH Q2). |
| 4 | Clicks around the island pass through; interacting with the island never steals focus | ✓ VERIFIED (code) — pending human | Panel `.nonactivatingPanel` + `canBecomeKey/Main==false` (never toggled); shown only via `orderFrontRegardless` (single site); 0 focus-stealing calls; conditional `ignoresMouseEvents` centralized in `syncClickThrough()` (WR-02 fix). Live focus/pass-through = human item. |

**Score:** 4/4 truths verified at the code level. All 4 require on-device confirmation of runtime/tactile/visual behavior → status **human_needed**.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchGeometry.swift` | `expandedNotchFrame` pure fn + WR-03 width guard | ✓ VERIFIED | `expandedNotchFrame` present (l.64); WR-03 `guard width > 0 else { return nil }` (l.35). Wired in `positionAndShow`. 13 tests incl. negative/zero-width boundary. |
| `Islet/Notch/FullscreenDetector.swift` | pure `isTrueFullscreen` + `shouldShow` | ✓ VERIFIED | Both present. `isTrueFullscreen` documented as SUPERSEDED heuristic (kept for tests); `shouldShow` is the live runtime gate, wired into `updateVisibility`. |
| `Islet/Notch/FullscreenSpaceProbe.swift` | CGS runtime fullscreen signal, fail-safe | ✓ VERIFIED | `isBuiltinDisplayInFullscreenSpace` binds `CGSMainConnectionID`/`CGSCopyManagedDisplaySpaces` via `@_silgen_name`; every cast/key falls through to `false`. Wired into controller. |
| `Islet/Notch/NotchInteractionState.swift` | InteractionPhase enum + pure `nextState` + ObservableObject | ✓ VERIFIED | Full transition table; `NotchInteractionState` ObservableObject. Driven by controller, consumed by view. |
| `Islet/Notch/NotchPillView.swift` | matchedGeometryEffect morph + date/time placeholder + hover bounce | ✓ VERIFIED | Single `"island"` morph id on both blobs; `.scaleEffect` hover bounce (`isHovering && !isExpanded`); D-05 date/time overlay; `onClick` closure → controller. |
| `Islet/Notch/NotchShape.swift` | morphing silhouette, animatable radii | ✓ VERIFIED | Plain `CGFloat` `topCornerRadius`/`bottomCornerRadius` → SwiftUI interpolates across morph. |
| `Islet/Notch/NotchPanel.swift` | conditional ignoresMouseEvents; focus-safe invariants retained | ✓ VERIFIED | `.nonactivatingPanel`, `canBecomeKey/Main==false`, `.statusBar`, all-Spaces retained; `ignoresMouseEvents=true` init only (controller drives runtime). |
| `Islet/Notch/NotchWindowController.swift` | global monitor + click-expand + grace + conditional click-through + fullscreen wiring | ✓ VERIFIED | Global `.mouseMoved` monitor, `handleClick`, grace `DispatchWorkItem`, `syncClickThrough` (WR-02), `pointerInZone` edge (WR-01), `updateVisibility` single path, NSWorkspace observers, deinit teardown. |
| `IsletTests/*` (Interaction/Fullscreen/Visibility/Geometry) | RED→GREEN unit suites | ✓ VERIFIED | 53 tests, 0 failures, TEST SUCCEEDED. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| NotchWindowController | NotchInteractionState (`nextState`) | monitor/timer/click → `nextState` inside spring | ✓ WIRED | `nextState(` called at 4 mutation sites; `interaction.phase =` mutated 4× |
| NotchWindowController | NotchGeometry (`expandedNotchFrame`) | panel sized to expanded frame up front | ✓ WIRED | `expandedNotchFrame(` in `positionAndShow` |
| NotchWindowController | FullscreenSpaceProbe / FullscreenDetector | `isBuiltinDisplayInFullscreenSpace` → `shouldShow` AND | ✓ WIRED | both called in `updateVisibility` (single path) |
| NotchWindowController | NSWorkspace (activeSpaceDidChange + didActivateApplication) | observers re-run `updateVisibility` | ✓ WIRED | both observers registered on `NSWorkspace.shared.notificationCenter`, removed in deinit |
| NotchWindowController | NSHapticFeedbackManager | haptic on hover-enter false→true only | ✓ WIRED | `perform(.levelChange,…)` in `handleHoverEnter` |
| NotchPillView | NotchInteractionState | `@ObservedObject` drives isExpanded/isHovering | ✓ WIRED | `@ObservedObject var interaction`; morph + bounce keyed off it |
| AppDelegate | NotchWindowController | creates, retains, `start()` | ✓ WIRED | `notchController` retained; `controller.start()` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| NotchPillView | `interaction.phase` | `NotchInteractionState` mutated by controller's monitor/click/grace callbacks | Yes — driven by live pointer events through `nextState` | ✓ FLOWING |
| NotchWindowController (visibility) | `fullscreen` | `isBuiltinDisplayInFullscreenSpace` reading live CGS managed-display-spaces | Yes — on-device confirmed type==4 toggles native fullscreen | ✓ FLOWING |
| NotchWindowController (visibility) | `target` | `selectTargetScreen` over live `NSScreen.screens` descriptors | Yes — Phase-1 verified resolver | ✓ FLOWING |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ISL-03 | 02-01, 02-03 | Hover expands / collapse to quiet pill (→ D-02 click-to-open) | ✓ SATISFIED (code) — feel pending human | nextState machine + global monitor + grace timer + click-to-expand; focus-safe; 15 tests |
| ISL-04 | 02-01, 02-02 | Smooth spring morph, no flicker/jump | ✓ SATISFIED (code) — visual pending human | single matchedGeometryEffect + spring-at-mutation; expandedNotchFrame |
| ISL-05 | 02-01, 02-04 | Hide on true fullscreen, restore on exit | ✓ SATISFIED (code) — native on-device VERIFIED; other kinds pending human | CGS probe + shouldShow AND + single updateVisibility; NSWorkspace observers |

No orphaned requirements: every ID mapped to Phase 2 in REQUIREMENTS.md (ISL-03, ISL-04, ISL-05) is claimed by a plan's `requirements` frontmatter and verified above. REQUIREMENTS.md already marks all three Complete (l.106-108).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| NotchPillView.swift | 86 | `Text(Date.now, …)` evaluated once, no clock | ℹ️ Info | IN-01 from review — intentional D-05 Phase-2 placeholder; replaced by real activity content in Phase 3+. Not a phase-2 defect. |
| FullscreenSpaceProbe.swift | 32 | hardcoded private constant `kCGSSpaceFullscreen = 4` | ℹ️ Info | IN-03 from review — fail-safe (mismatch → shows, never wrongly hides); confirmed on-device Tahoe via DEBUG trace. Accepted private-API decision. |
| NotchPillView / NotchWindowController | — | `#if DEBUG` red tint / dev offset / hover-tick log | ℹ️ Info | Dev affordances, DEBUG-guarded; release ships pure black, no logging. |

No 🛑 blockers and no ⚠️ warnings remain. The three review WARNINGS (WR-01 grace-cancel-on-reentry, WR-02 click-through restore, WR-03 notch-width guard) were FIXED post-review (commits `a92297d`, `b55a97f`) and the fixes are present in the current code (verified: `pointerInZone` edge tracking, centralized `syncClickThrough()`, `guard width > 0 else { return nil }` with boundary tests).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes | `xcodebuild test -scheme Islet -destination 'platform=macOS'` | 53 tests, 0 failures, TEST SUCCEEDED | ✓ PASS |
| Build green | `xcodegen generate && xcodebuild build` | BUILD SUCCEEDED (per summaries; test run rebuilt clean) | ✓ PASS |
| Single hide/show path | `grep -c orderOut / orderFrontRegardless` controller | 1 / 1 | ✓ PASS |
| No focus-stealing calls | `grep -cE 'makeKeyAndOrderFront\|NSApp.activate\|makeKey('` | 0 | ✓ PASS |
| No local monitor / CGEvent tap | `grep -cE 'addLocalMonitorForEvents\|CGEvent'` | 0 | ✓ PASS |
| No AX prompt | `grep -cE 'AXUIElement\|AXIsProcessTrusted\|kAXFullscreen'` (all sources) | 0 | ✓ PASS |
| No Settings UI / UserDefaults (D-10 seam only) | `grep -cE 'UserDefaults\|@AppStorage'` controller | 0 | ✓ PASS |

Runtime hover/click/fullscreen behaviors cannot be exercised by a headless agent (need a GUI session + real fullscreen apps) → routed to Human Verification.

### Human Verification Required

1. **Hover/click feel** — onto the pill: expect haptic + bounce, no expand; click expands with snappy spring; leave → ~0.4s grace collapse; quick re-entry cancels collapse. (Confirms D-01/D-02/D-03 feel + A1 global-monitor-fires-unprompted-on-Tahoe probe.)
2. **Morph quality** — watch expand→collapse: expect one morphing black shape, no cross-fade/flicker/jump (SC#2).
3. **Fullscreen video** — YouTube (Safari) + QuickTime fullscreen: expect island hides, restores on exit (RESEARCH Q2).
4. **QuickLook** — Finder → Space → QuickLook fullscreen: expect hides, restores on close (RESEARCH Q2).
5. **Maximized stays visible** — zoom a window (NOT fullscreen): expect island STAYS visible (D-09 exclusion).
6. **Clamshell + external-display** — lid close/open; fullscreen on external with built-in present: expect no flicker / no stuck state.
7. **Focus-safe auto-restore** — exit fullscreen with another app foreground: expect no focus theft (orderFrontRegardless only, D-04).
8. **Click-through around the island** — click desktop/menu bar outside the pill (idle + expanded): expect pass-through, no Islet activation (SC#4 / WR-02 toggle-shut edge).

### Known Deferred (informational — not a gap)

- **~1-frame fullscreen-ENTER flash** — root-caused as window-server compositing of the `.canJoinAllSpaces` panel onto the activating fullscreen Space; the reactive `orderOut` cannot pre-empt it. Negligible in release (pill ships pure black / flush to the notch). Product-deferred by the user to a later polish phase (Plan 05 / Phase 6). This is NOT an ISL-04 morph flicker — the expand/collapse morph is clean. Documented in 02-04-SUMMARY.md.

### Gaps Summary

No code-level gaps. All four ROADMAP success criteria and all three requirement IDs (ISL-03, ISL-04, ISL-05) are satisfied in the actual codebase: the pure seams exist and are unit-tested (53/0), the AppKit/SwiftUI glue is fully wired (single show/hide path, single morph, focus-safe panel, CGS fullscreen probe), the three code-review warnings were fixed and confirmed in-code, and native fullscreen yield is on-device verified. What remains is on-device confirmation of tactile feel, visual morph smoothness, the non-native fullscreen kinds, multi-display coexistence, and live focus-safety — none of which an automated agent can judge. Per the verification rubric, code delivering the must-haves with outstanding on-device UAT is **human_needed**, not passed.

---

_Verified: 2026-06-27T15:50:00Z_
_Verifier: Claude (gsd-verifier)_
