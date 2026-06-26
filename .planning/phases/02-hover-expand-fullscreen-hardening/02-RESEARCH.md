# Phase 2: Hover, Expand & Fullscreen Hardening - Research

**Researched:** 2026-06-27
**Domain:** macOS native overlay UX — focus-safe pointer input on a non-activating `NSPanel`, SwiftUI spring/`matchedGeometryEffect` morph, system-wide true-fullscreen detection
**Confidence:** MEDIUM-HIGH (interaction/animation HIGH; cross-process fullscreen detection MEDIUM — no perfect public API, but the notched-Mac safe-area signal is reliable and must be confirmed on-device)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Interaction model (ISL-03) — Alcove-style click-to-open**
- **D-01:** Hover affordance, NOT hover-to-open. Pointer entering the hot-zone fires **trackpad haptic** (`NSHapticFeedbackManager`) **+ a subtle bounce/scale** of the pill ("you're in" signal). Hover alone does NOT expand.
- **D-02:** **Expand on CLICK only.** A click on the pill expands it with the spring morph. ⚠️ This intentionally supersedes the literal ISL-03 wording "hovering the notch expands the island." Model is **click-to-open** (Alcove). Verifier must test **click-to-open + hover-haptic-bounce**, NOT hover-expand.
- **D-03:** Collapse when the pointer leaves the island, with a **~0.3–0.5s grace delay** so a brief rollout doesn't snap it shut.
- **D-04:** **Focus-safe is non-negotiable** (carries Phase-1 D-07): clicking to expand must **never activate Islet or steal focus** from the active app; clicks **outside** the pill must still pass through. The panel stays `.nonactivatingPanel`, `canBecomeKey/Main = false`.

**Expanded state (Phase-2 placeholder)**
- **D-05:** Expanded content = a **small date/time readout** as a temporary filler (real activity content → Phase 3+). It exists so the morph has a visible target.
- **D-06:** Expanded size = **compact** — only modestly larger than the notch, NOT a big Dynamic-Island panel.

**Animation (ISL-04)**
- **D-07:** **Snappy & playful spring with a slight bounce** (iPhone-DI / Alcove feel). Real **geometric form-morph** via `matchedGeometryEffect` + a shared `@Namespace` (corner radius + frame animate). **No cross-fade.**
- **D-08:** **Idle/collapsed pill stays static & invisible** (carries Phase-1 D-01/D-03). The ONLY motion in Phase 2 is the click-driven expand/collapse and the hover bounce — no idle pulsing.

**Fullscreen yield (ISL-05)**
- **D-09:** In **true fullscreen** (native fullscreen, fullscreen video, QuickLook) the island **hides completely by default** — no ghost control bar — and **auto-restores** when fullscreen exits. **Regular maximized / zoomed windows do NOT count** (island stays visible).
- **D-10:** The fullscreen-hide is **gated behind a single flag** (default = hidden) so a future "show island in fullscreen" toggle is a one-line wire-up. The toggle's **settings UI is Phase 6 (APP-03)** — do NOT build it here, only keep the seam.

### Claude's Discretion
- Exact hover **hot-zone** bounds (pill bounds, possibly slightly padded for easy targeting).
- **The focus-safe hover/click mechanism** (the key research item — see "Architecture Patterns" below).
- Exact spring `response`/`dampingFraction`, bounce magnitude, and grace-delay value within 0.3–0.5s.
- **Fullscreen detection mechanism** (must interop cleanly with the existing `didChangeScreenParametersNotification` + clamshell logic, Phase 1 D-04/D-05).
- Haptic feedback pattern type, and whether subtle haptics also fire on expand/collapse (not only hover-enter).
- Where the `isExpanded` state + date/time view live (likely an `@Published` on `NotchWindowController`).

### Deferred Ideas (OUT OF SCOPE)
- **"Show island in fullscreen" toggle UI** → Phase 6 (APP-03). Phase 2 ships the behavior behind a flag (D-10) but builds NO settings UI.
- **Activity content** inside the expanded island (now-playing, charging, devices) → Phase 3+. Phase 2's expanded state is a date/time placeholder only (D-05).
- **ISL-03 wording reconciliation:** ROADMAP/REQUIREMENTS still say "hovering expands"; the agreed model is click-to-open + hover haptic/bounce. Treat **click-to-open as authoritative**; do not edit those docs.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **ISL-03** | Open/close interaction (reinterpreted by D-01/D-02 as **click-to-open + hover haptic/bounce**; collapse on pointer-leave with grace delay) | Focus-safe pointer-input mechanism (global `NSEvent` monitor + conditional `ignoresMouseEvents`), `NSHapticFeedbackManager`, grace-delay state machine — see "Architecture Patterns" P1–P3 |
| **ISL-04** | Expand/collapse animate with a smooth **spring morph** (Alcove-quality), no flicker/jump, **no cross-fade** | `matchedGeometryEffect` + shared `@Namespace` + `withAnimation(.spring(...))`; concrete starting values; expanded-frame geometry seam — see P4–P5 |
| **ISL-05** | Island **hides/yields** when an app enters **true fullscreen**; excludes maximized/zoomed; auto-restores | System-wide fullscreen detection on a notched Mac (safe-area/menu-bar signal as primary, `NSWorkspace`/AX as corroboration), one unified show/hide decision path, single gating flag — see P6–P7 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are authoritative directives — plans MUST NOT contradict them:

- **Swift 5 language mode** (set explicitly; build machine is Xcode 26 which defaults to Swift 6 strict concurrency). `project.yml` already pins `SWIFT_VERSION: "5.0"`. `[VERIFIED: project.yml]`
- **macOS 14.0 deployment floor.** All APIs used must exist on 14.0. `[VERIFIED: project.yml]`
- **Small AppKit surface + SwiftUI content via `NSHostingView`.** AppKit owns the window/event-glue; SwiftUI fills it. Keep AppKit additions minimal. `[CITED: CLAUDE.md]`
- **Avoid Core Animation / hand-rolled `CALayer` animations.** SwiftUI spring + `matchedGeometryEffect` gives the morph for free. `[CITED: CLAUDE.md "What NOT to Use" / "Animation approach"]`
- **`@Published`/`ObservableObject`** for state into SwiftUI; Combine optional, not required. `[CITED: CLAUDE.md]`
- **Un-sandboxed.** Already set (`ENABLE_APP_SANDBOX: NO`). This MATTERS for Phase 2: un-sandboxed unlocks the Accessibility/AX fullscreen-attribute path and removes sandbox limits on cross-process window inspection. `[VERIFIED: project.yml]`
- **XcodeGen auto-discovery:** new `.swift` files under `Islet/` are picked up by `xcodegen generate`; no manual `.xcodeproj` edits. Run `xcodegen generate` after adding any source. `[VERIFIED: project.yml comments + Phase-1 SUMMARY]`
- **No DynamicNotchKit dependency** (Phase-1 D-06): custom `NSPanel` is already in place; do not introduce DynamicNotchKit for the persistent pill. `[CITED: 01-CONTEXT.md D-06]`
- **No Dock icon (`LSUIElement`/agent).** Already set; nothing in Phase 2 changes this. `[VERIFIED: project.yml]`

> **Toolchain reality (project memory):** build machine runs **macOS 26 "Tahoe" / Xcode 26.6 / Swift 6.3.3** — CLAUDE.md's "macOS 14-15 / Xcode 16" is stale on the *toolchain* (the macOS 14.0 deployment *floor* is unaffected). Phase-1 confirmed on-device that `level = .statusBar` renders over the Tahoe floating menu bar. Verify any borderline API behavior on Tahoe at execution time. `[VERIFIED: ~/.claude memory + 01-03-SUMMARY.md]`

## Summary

Phase 2 turns the static Phase-1 pill into an interactive Dynamic-Island morph. The three requirements decompose into **two genuinely hard, on-device-sensitive problems** and **several straightforward SwiftUI tasks**.

**Problem 1 — focus-safe pointer input on a non-activating panel.** The Phase-1 panel sets `ignoresMouseEvents = true` *unconditionally* and `.nonactivatingPanel` with `canBecomeKey/Main = false`. The reliable pattern (used by Alcove-class apps and TheBoringNotch) is: keep the panel non-activating and never key, but make `ignoresMouseEvents` **conditional** — flip it to `false` only while the pointer is inside the pill hot-zone, driven by a **global `NSEvent` mouse-moved monitor** (which observes events posted to *other* apps; it never sees your own window's events and never activates the app). When `ignoresMouseEvents` is `false`, the SwiftUI content inside the `NSHostingView` receives the `mouseDown` for the expand click *without activating Islet*, because `.nonactivatingPanel` + `canBecomeKey == false` is exactly the "respond to clicks while staying in the background" contract. The single biggest unknown is whether a **global mouse-moved monitor needs the Accessibility permission on Tahoe** — sources conflict; the plan must include an on-device check and a fallback (`NSTrackingArea` + a small always-interactive hot-zone) if it does. `[VERIFIED: Apple NSPanel/NSEvent docs + multiple community sources; permission question flagged ASSUMED]`

**Problem 2 — true-fullscreen detection that excludes maximized windows.** There is **no perfect public API** to read another process's fullscreen `styleMask` (Apple FB18862047 still open). But Islet runs on a **notched Mac** and is **un-sandboxed**, which gives two strong signals: (a) when a true-fullscreen app is frontmost, the **menu bar / notch band is given over to the app** and the built-in screen's top **safe-area inset collapses / the auxiliary top areas disappear** — i.e. the very `safeAreaTop`/`auxiliaryTopLeftArea` values the geometry seam already reads change; and (b) being un-sandboxed, the **Accessibility `kAXFullscreenAttribute`** on the frontmost app's focused window is directly readable. A regular maximized/zoomed window does NOT collapse the safe area or set the AX fullscreen flag — that is exactly the maximized-vs-fullscreen discriminator D-09 requires. Wire enter/exit via `NSWorkspace.activeSpaceDidChangeNotification` + `NSWorkspace.didActivateApplicationNotification`, feed it into the **same single show/hide decision path** as the existing clamshell logic. `[VERIFIED: Apple Developer Forums 792917 + NSScreen docs; exact safe-area behavior under fullscreen flagged for on-device confirmation]`

The SwiftUI morph itself is the easy part: one `isExpanded` `@Published` on `NotchWindowController`, two layouts in `NotchPillView` sharing a `@Namespace` via `matchedGeometryEffect`, all state changes wrapped in `withAnimation(.spring(...))`. The expanded panel frame is a pure extension of `NotchGeometry`.

**Primary recommendation:** Build the interaction as **global `NSEvent` mouse-moved monitor → conditional `ignoresMouseEvents` → SwiftUI `mouseDown`/`onTapGesture` for expand**, keeping the panel non-activating and never-key. Detect fullscreen via a **pure predicate over the rebuilt `ScreenDescriptor` (safe-area collapse) + AX fullscreen attribute as corroboration**, both feeding one `updateVisibility()` method alongside clamshell. Gate the hide behind one `Bool` default-true flag. Drive the morph with `matchedGeometryEffect` + `withAnimation(.spring(response: 0.35, dampingFraction: 0.65))` as a tuning starting point.

## Standard Stack

No new third-party packages. Phase 2 is entirely Apple frameworks already linked.

### Core (all already linked)
| Framework | Purpose | Why Standard | Confidence |
|-----------|---------|--------------|------------|
| **SwiftUI** (macOS 14 SDK) | The morph: `matchedGeometryEffect`, `@Namespace`, `withAnimation(.spring(...))`, date/time view | Declarative morph is the exact Dynamic-Island technique; CLAUDE.md mandates it | HIGH |
| **AppKit** (`NSEvent`, `NSPanel`, `NSHapticFeedbackManager`, `NSWorkspace`, `NSScreen`) | Global mouse monitor, conditional `ignoresMouseEvents`, haptics, fullscreen/space observers | The only layer that can observe system-wide pointer + window/space state | HIGH |
| **CoreGraphics** | Pure expanded-frame geometry (extends `NotchGeometry`) | Already the geometry seam's home | HIGH |
| **ApplicationServices / AXUIElement** (optional corroboration) | Read `kAXFullscreenAttribute` of the frontmost app's focused window | Most direct cross-process fullscreen signal; available because un-sandboxed | MEDIUM |

### Supporting
| Symbol | Purpose | When to Use | Confidence |
|--------|---------|-------------|------------|
| `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler:)` | Detect pointer entering/leaving the hot-zone while clicks elsewhere pass through | Primary hover mechanism | HIGH (existence) / MEDIUM (permission on Tahoe) |
| `NSEvent.mouseLocation` | Current pointer position in **global, bottom-left, unflipped** screen coords | Hit-test the pointer against the pill frame each mouse-moved tick | HIGH |
| `NSTrackingArea` | Hosting-view enter/exit tracking | **Fallback** if the global monitor needs Accessibility and you'd rather avoid it | HIGH |
| `NSHapticFeedbackManager.defaultPerformer.perform(_:performanceTime:)` | Trackpad "you're in" haptic (D-01) | On hover-enter; optionally on expand/collapse | HIGH |
| `NSWorkspace.shared.notificationCenter` → `activeSpaceDidChangeNotification`, `didActivateApplicationNotification` | Live fullscreen enter/exit events | Trigger the fullscreen re-evaluation | HIGH |
| `NSScreen.safeAreaInsets.top` / `auxiliaryTopLeftArea` | Collapses under true fullscreen on a notched Mac — the maximized-vs-fullscreen discriminator | Primary fullscreen signal | MEDIUM (verify on-device) |
| `AXUIElementCopyAttributeValue(_, kAXFullscreenAttribute, _)` | Direct fullscreen flag of the frontmost window | Corroboration / tie-breaker | MEDIUM |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Global `NSEvent` mouse-moved monitor | `NSTrackingArea` on the `NSHostingView` | Tracking area is permission-free and simpler, BUT requires the panel region to be hit-testable (`ignoresMouseEvents = false`) to fire — which means clicks in that region no longer pass through. Acceptable only if the hot-zone is exactly the (tiny) pill; loses click-through on the pill itself even when collapsed. Good **fallback**, weaker primary. |
| Global `NSEvent` mouse-moved monitor | `CGEvent.tapCreate` (used by some forks) | Lower-level, **definitely** requires Accessibility (Input Monitoring), more complex, more fragile. Avoid for v1. |
| Safe-area collapse for fullscreen | `CGWindowListCopyWindowInfo` bounds-vs-screen heuristic | Bounds heuristic is explicitly unreliable on notched Macs / auto-hide menu bars and **cannot distinguish maximized from fullscreen** — the exact thing D-09 forbids. Use only as a last-resort cross-check. |
| Safe-area collapse for fullscreen | AX `kAXFullscreenAttribute` only | AX is the most direct flag but may require an Accessibility prompt and is per-window (need to walk to the focused window). Best as **corroboration**, not sole source. |
| `matchedGeometryEffect` morph | Two views + `.transition(.opacity)` cross-fade | Explicitly forbidden by D-07 / ISL-04 ("no cross-fade"). |

**Installation:** none — no `npm`/SPM changes. New Swift files are auto-discovered by XcodeGen; run `xcodegen generate` after adding them, then `xcodebuild -scheme Islet`.

## Architecture Patterns

### Recommended file changes (extends Phase-1 layout, no new modules)
```
Islet/Notch/
├── NotchGeometry.swift          # + expandedNotchFrame(...) pure function (testable)
├── NotchPanel.swift             # unchanged styleMask; remove the *unconditional* ignoresMouseEvents=true
│                                #   (now driven by the controller); keep .nonactivatingPanel + canBecomeKey=false
├── NotchPillView.swift          # collapsed↔expanded layouts via matchedGeometryEffect + shared @Namespace;
│                                #   date/time placeholder; hover-bounce scale; tap → expand
├── NotchWindowController.swift  # owns isExpanded (@Published via a small ObservableObject /  ObservableObject model);
│                                #   global NSEvent mouse-moved monitor; hover/click → state;
│                                #   grace-delay collapse timer; haptics; fullscreen observers;
│                                #   ONE updateVisibility() merging clamshell + fullscreen
├── FullscreenDetector.swift     # NEW: pure predicate isTrueFullscreen(screen descriptor / signals) -> Bool
│                                #   + the AppKit-facing observer wiring
└── NotchInteractionState.swift  # NEW (optional): the ObservableObject holding isExpanded/isHovering for SwiftUI
```

### Pattern 1: Conditional click-through via a global mouse-moved monitor (the focus-safe hover/click core)
**What:** Keep the panel `.nonactivatingPanel`, `canBecomeKey == false`. Install a **global** `NSEvent` monitor for `.mouseMoved`. On each tick, hit-test `NSEvent.mouseLocation` against the pill's hot-zone frame (in global screen coords). When inside: set `panel.ignoresMouseEvents = false` (so the SwiftUI content can receive the click), set `isHovering = true`, fire the haptic on the *enter* transition, and start a small bounce. When outside: set `isHovering = false`, start the grace-delay collapse timer, and (after the grace window, if still collapsed) restore `ignoresMouseEvents = true`.
**When to use:** This is the primary mechanism for ISL-03 D-01/D-02/D-04.
**Why it's focus-safe:**
- A **global** monitor receives *copies* of events posted to **other** apps; it never consumes them and never activates Islet. `[CITED: Apple "Monitoring Events"]`
- The monitor handler is always invoked on the **main thread** — safe to touch AppKit/`@Published` directly. `[CITED: Apple addGlobalMonitorForEvents docs]`
- With `.nonactivatingPanel` + `canBecomeKey == false`, when `ignoresMouseEvents` is `false` the panel **receives the `mouseDown` without becoming key and without activating the app** — exactly the "respond to clicks in the background" contract. `[CITED: Apple nonactivatingPanel docs; artlasovsky.com]`

**Sketch (illustrative, not final):**
```swift
// Source: composed from Apple NSEvent / nonactivatingPanel docs + 01 code conventions
var monitor: Any?
func startHoverMonitoring(panel: NotchPanel, hotZone: () -> CGRect) {
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
        guard let self else { return }
        let p = NSEvent.mouseLocation            // global, bottom-left, UNflipped screen coords
        let inside = hotZone().contains(p)
        self.handlePointer(inside: inside, panel: panel)  // toggles ignoresMouseEvents, haptic, bounce, grace timer
    }
}
```
> **Gotchas (all flagged for the plan):**
> - **Accessibility permission:** Sources conflict on whether a *mouse-moved* global monitor needs the Accessibility permission on current macOS (keyboard monitors definitely do). **Plan must verify on-device on Tahoe**; if it does, either (a) prompt with `AXIsProcessTrustedWithOptions`, or (b) fall back to Pattern 1b. `[ASSUMED — needs on-device confirmation]`
> - **Coalescing/latency:** mouse-moved events are coalesced; the hit-test runs only as fast as ticks arrive — fine for a hot-zone, but do not rely on it for pixel-accurate sub-frame tracking.
> - **Coordinate spaces:** `NSEvent.mouseLocation` is **global, bottom-left origin, NOT flipped**, matching the panel's `frame` (also bottom-left). Hit-test directly against `panel.frame` — do not convert. The Phase-1 geometry already lives in this space (`y = maxY - height`). `[CITED: Apple mouseLocation docs]`
> - **Multi-monitor:** mouse-location is in the global desktop space spanning all screens; the pill is only on the built-in screen, so a frame `contains` test is sufficient.
> - **The panel must NOT become key to receive a click** — keep `canBecomeKey == false`. A non-activating panel still delivers `mouseDown` to its content view. Do **not** call `makeKeyAndOrderFront`; keep using `orderFrontRegardless()` (Phase-1 D-07).
> - **Toggle hygiene:** only flip `ignoresMouseEvents` back to `true` once the pointer is out AND the island is collapsed, so a click that lands right at the boundary still registers.

### Pattern 1b: NSTrackingArea fallback (permission-free)
**What:** If the global monitor proves to need Accessibility and that's undesirable for v1, attach an `NSTrackingArea` (`.activeAlways`, `.mouseEnteredAndExited`, `.inVisibleRect`) to a thin AppKit hit view inside the hosting view, and keep `ignoresMouseEvents = false` on just that view's region.
**Tradeoff:** No Accessibility prompt, but the pill region is no longer click-through even when collapsed (clicks on the ~30px notch band are swallowed). For a notch-hugging pill this is usually acceptable; document the difference. `[VERIFIED: NSTrackingArea docs]`

### Pattern 2: Hover-enter haptic + bounce (D-01)
**What:** On the *false→true* `isHovering` transition only (not every tick), call:
```swift
// Source: Apple NSHapticFeedbackManager docs
NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
```
and set a SwiftUI scale (e.g. `.scaleEffect(isHovering ? 1.06 : 1.0)`) animated with the same spring. Use `defaultPerformer` (never construct a performer) so it respects device/user prefs and no-ops on non-Force-Touch trackpads. `[CITED: Apple docs]`
**When:** hover-enter. Optionally also `perform(.generic, ...)` on expand/collapse (Claude's discretion, D-01 note).

### Pattern 3: Grace-delay collapse state machine (D-03)
**What:** On pointer-leave, do not collapse immediately; schedule a one-shot timer (0.3–0.5s). If the pointer re-enters before it fires, cancel it. If it fires and the pointer is still outside, set `isExpanded = false` inside `withAnimation(.spring(...))`. A click-to-expand also cancels any pending collapse. Model it as a tiny explicit state machine (`collapsed / hovering / expanded`) rather than scattered booleans — it's the most bug-prone part and the most unit-testable.
**Testable seam:** extract the transition logic as a pure function `nextState(current, event)` so the timer/hover/click choreography can be unit-tested without AppKit.

### Pattern 4: The SwiftUI morph (ISL-04, D-07)
**What:** One `@Namespace` shared between the collapsed and expanded subtrees; the black blob (and date/time element) carry `matchedGeometryEffect(id:in:)`; all state flips inside `withAnimation(.spring(...))`. The `NotchShape`'s `topCornerRadius`/`bottomCornerRadius` and the frame are interpolated by SwiftUI as the panel content grows.
**When to use:** the only animation in the phase besides the hover bounce.
**Starting values (tune on-device, Claude's discretion within D-07):**
```swift
// Source: Apple Animation.spring docs + community Dynamic-Island tunings; tune live
withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { isExpanded.toggle() }
// "Snappy with slight overshoot": response 0.3–0.4, dampingFraction 0.6–0.7.
// Alternative modern preset: .snappy(duration: 0.35, extraBounce: 0.15)  (macOS 14+).
```
Lower `dampingFraction` = more bounce; `response` = duration/speed. Community Apple-Wallet-style expansion uses `response: 0.28, dampingFraction: 0.78` (less bouncy) as a reference point. `[CITED: Apple Animation docs + dev.to/medium tunings]`

> **Panel-resize-vs-SwiftUI-animation interaction (important):** the *window* (`NSPanel`) must be large enough to contain the expanded content for the whole animation, or SwiftUI content gets clipped mid-morph. Recommended approach: **set the panel frame to the EXPANDED size up front** (transparent background means the extra area is invisible) and let SwiftUI animate the *content* within a fixed, expanded-sized window — rather than animating `panel.setFrame` in lockstep with the spring (which fights the SwiftUI animation and flickers). Alternatively, snap the panel to expanded size at the start of expand and back to collapsed size at the *end* of collapse. Decide in planning; the first option is simpler and flicker-free. `[ASSUMED — based on SwiftUI/AppKit hosting behavior; confirm on-device]`

### Pattern 5: Expanded-frame geometry (extends NotchGeometry, testable)
**What:** Add a pure function, e.g.:
```swift
// Source: extends the Phase-1 NotchGeometry seam (bottom-left, top-pinned, centered)
func expandedNotchFrame(collapsed: CGRect, expandedSize: CGSize) -> CGRect {
    // Centered on the same midX, still pinned to the top edge (y = maxY - height).
    let x = collapsed.midX - expandedSize.width / 2
    let y = collapsed.maxY - expandedSize.height
    return CGRect(x: x, y: y, width: expandedSize.width, height: expandedSize.height)
}
```
Keeps the same centering + top-pin contract as `notchFrame`, so it's unit-testable exactly like the existing geometry tests (coordinate-flip, centering, non-zero-origin screens). `[VERIFIED: matches NotchGeometry.swift conventions]`

### Pattern 6: True-fullscreen detection (ISL-05, D-09) — primary = safe-area collapse
**What:** When a frontmost app enters **true** fullscreen on the built-in display, the system reclaims the menu-bar/notch band: the built-in `NSScreen`'s `safeAreaInsets.top` collapses and the `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` become unavailable (the strips beside the notch disappear). A **maximized/zoomed** window does NOT do this — the safe area and aux strips remain. That difference is the maximized-vs-fullscreen discriminator. Build a **pure predicate** over the same `ScreenDescriptor` the geometry seam already produces:
```swift
// Source: NSScreen safeAreaInsets/auxiliaryTopLeftArea docs + Apple Dev Forums 792917
// On a notched built-in display, a TRUE-fullscreen app collapses the notch safe area.
func isTrueFullscreen(builtin: ScreenDescriptor) -> Bool {
    // builtin previously had a notch (safeAreaTop>0, both aux areas) — if it no longer reports
    // them while the display is still present, the band was handed to a fullscreen app.
    !builtin.hasNotch    // i.e. safe area collapsed though the display is still attached
}
```
**Live events:** subscribe to `NSWorkspace.shared.notificationCenter` for `activeSpaceDidChangeNotification` (fullscreen apps live on their own Space — enter/exit fires this) and `didActivateApplicationNotification`. On each, rebuild the built-in descriptor and re-run `updateVisibility()`.
**Corroboration (recommended, un-sandboxed only):** read the frontmost app's focused-window `kAXFullscreenAttribute` via `AXUIElement`; treat `true` as a definite hide. Use it to disambiguate edge cases (e.g. fullscreen video in a windowed player that doesn't take a Space).
**Three fullscreen kinds vs signal:** `[ASSUMED for video/QuickLook — confirm each on-device on Tahoe]`
| Kind | Takes own Space? | Collapses notch safe area? | AX fullscreen flag? | Reliable signal |
|------|------------------|----------------------------|---------------------|-----------------|
| Native fullscreen (green-button) | Yes | Yes | Yes | Space change + safe-area collapse (HIGH) |
| Fullscreen video (player goes full) | Usually yes | Yes (menu bar hidden) | Often yes | Safe-area collapse + AX (MEDIUM-HIGH) |
| QuickLook full preview | Sometimes | Menu bar hidden | Varies | Safe-area collapse; AX as tie-break (MEDIUM) |

> **Gotchas:**
> - **Do NOT use bounds-vs-screen heuristics** (`CGWindowListCopyWindowInfo`): explicitly unreliable on notched Macs and cannot tell maximized from fullscreen (Apple FB18862047 open). `[VERIFIED: Apple Dev Forums 792917]`
> - The safe-area signal must **only** be read on the *built-in notched* screen, and must not be confused with **clamshell** (where the built-in *drops out of `NSScreen.screens` entirely* — Phase-1 A3). Distinguish: built-in present but safe-area collapsed = fullscreen; built-in absent = clamshell. They are different inputs to the same decision.
> - On Tahoe the menu bar floats/hides differently; confirm the safe-area collapse still fires for each fullscreen kind on the real machine.

### Pattern 7: ONE unified visibility decision path (interop with Phase-1 D-04/D-05)
**What:** Phase-1 `resolveAndPosition()` decides show/hide purely on display selection (built-in present + notched). Phase 2 adds a fullscreen input. **Do not** add a second `orderOut`/`orderFront` site. Refactor to a single `updateVisibility()` that ANDs all reasons-to-show:
```swift
// All "should the pill be visible right now?" inputs converge here.
private func updateVisibility() {
    let hasTarget = (selectTargetScreen(...) != nil)            // Phase-1: clamshell/external/non-notch → hide
    let fullscreenHides = hideInFullscreen && isTrueFullscreen   // Phase-2: D-09/D-10 single flag
    if hasTarget && !fullscreenHides { positionAndShow() } else { panel?.orderOut(nil) }
}
private let hideInFullscreen = true   // D-10: single gating flag, default = hidden. Phase-6 settings wire to this.
```
**Where state lives:** `isExpanded` / `isHovering` on a small `ObservableObject` (e.g. `NotchInteractionState`) owned by `NotchWindowController` and injected into `NotchPillView` (matches the established `@Published`/`ObservableObject` pattern). The fullscreen `hideInFullscreen` flag is a plain stored property on the controller (no UI). `[VERIFIED: matches AppDelegate/controller ownership pattern]`

### Anti-Patterns to Avoid
- **Toggling `.nonactivatingPanel` at runtime:** `NotchPanel.swift`'s own comment notes AppKit does not fully re-apply activation behavior post-init. Set it once at init (already done); only `ignoresMouseEvents` is toggled. `[VERIFIED: NotchPanel.swift]`
- **Calling `makeKeyAndOrderFront` / `NSApp.activate` for the pill:** would steal focus — violates D-04. Use `orderFrontRegardless()` only. `[VERIFIED: 01 code + D-07]`
- **Animating `panel.setFrame` in lockstep with the SwiftUI spring:** causes flicker/clipping; prefer an expanded-sized window with SwiftUI animating content (Pattern 4 note).
- **`CALayer`/Core Animation hand-rolling:** forbidden by CLAUDE.md; SwiftUI gives the morph.
- **Cross-fade between two views:** forbidden by D-07/ISL-04 — must be a single `matchedGeometryEffect` morph.
- **A second show/hide call site for fullscreen:** creates race conditions with clamshell; everything goes through `updateVisibility()` (Pattern 7).
- **Bounds-vs-screen-size fullscreen heuristic:** unreliable on notched Macs and cannot exclude maximized (D-09).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pointer-enter/leave detection | A polling timer reading `NSEvent.mouseLocation` on a tick | Global `NSEvent` `.mouseMoved` monitor (Pattern 1) or `NSTrackingArea` (1b) | System delivers events efficiently; polling wastes CPU and adds latency |
| Trackpad haptic | Custom Force-Touch/IOKit calls | `NSHapticFeedbackManager.defaultPerformer` | Respects device capability + user prefs; no-ops gracefully on unsupported hardware |
| Spring/morph animation | `CADisplayLink`/`CALayer` keyframes | SwiftUI `withAnimation(.spring(...))` + `matchedGeometryEffect` | Mandated by CLAUDE.md; far less code, interruptible, physically correct |
| Fullscreen detection | Bounds-vs-screen window-list math | Safe-area collapse predicate + `NSWorkspace`/AX events (Patterns 6–7) | Bounds math can't exclude maximized (the exact D-09 requirement) and breaks on notched Macs |
| Space/fullscreen enter-exit events | Polling the active space | `NSWorkspace.activeSpaceDidChangeNotification` | First-party live notification; fullscreen lives on its own Space |

**Key insight:** Every hard part of Phase 2 has a first-party primitive. The work is *choreography* (state machine + one visibility path), not new mechanism. Keep the AppKit surface tiny (CLAUDE.md) — a monitor, two `NSWorkspace` observers, one haptic call.

## Common Pitfalls

### Pitfall 1: Global mouse monitor silently never fires (Accessibility gate)
**What goes wrong:** `addGlobalMonitorForEvents` returns a non-nil token but the handler never runs because the OS gated it behind Accessibility/Input-Monitoring.
**Why it happens:** macOS privacy hardening; behavior for *mouse* (vs keyboard) monitors is version-dependent and disputed across sources.
**How to avoid:** On first run, verify the monitor actually fires (log a hover tick on-device). If it doesn't, prompt via `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` or fall back to Pattern 1b (`NSTrackingArea`). **Plan a Wave-0 / early on-device probe for this.** `[ASSUMED — confirm on Tahoe]`

### Pitfall 2: Click activates Islet / steals focus
**What goes wrong:** Clicking the pill brings Islet to the front, demoting the user's foreground app.
**Why it happens:** Panel became key, or code called `makeKeyAndOrderFront`/`NSApp.activate`.
**How to avoid:** Keep `canBecomeKey == false`, `.nonactivatingPanel`, and only `orderFrontRegardless()`. Verify on-device (Phase-1's checkpoint #2 already proved the baseline; re-verify after making `ignoresMouseEvents` conditional). `[VERIFIED: D-04 + 01-03-SUMMARY threat T-01-07]`

### Pitfall 3: Pill stops being click-through after a hover (stuck interactive)
**What goes wrong:** `ignoresMouseEvents` left `false` after the pointer leaves, so the notch band swallows desktop/menu-bar clicks.
**Why it happens:** The restore branch wasn't reached (e.g. fast rollout, grace timer race).
**How to avoid:** Restore `ignoresMouseEvents = true` deterministically whenever `!isHovering && !isExpanded`; make the global monitor authoritative (it fires on every move, including the exit). Add an assertion/log in DEBUG.

### Pitfall 4: Morph flickers / content clipped mid-animation
**What goes wrong:** Expanded content is clipped or the window jumps because the panel frame and the SwiftUI animation are out of sync.
**Why it happens:** Animating `panel.setFrame` alongside the spring.
**How to avoid:** Use an expanded-sized (transparent) panel and animate only SwiftUI content, OR resize the window at the animation boundaries, not during (Pattern 4 note). Confirm on-device.

### Pitfall 5: Fullscreen-hide fights clamshell / double show-hide race
**What goes wrong:** On lid-close-while-fullscreen or rapid Space switches, the pill flashes or sticks hidden/shown.
**Why it happens:** Two independent `orderOut`/`orderFront` sites racing.
**How to avoid:** Single `updateVisibility()` (Pattern 7); both `didChangeScreenParametersNotification` and the `NSWorkspace` notifications call only it; keep the routine idempotent (Phase-1 already hops to the next run-loop turn for screen changes — keep that).

### Pitfall 6: Wrong coordinate space in the hit-test
**What goes wrong:** Hover never triggers, or triggers in the wrong place, on a built-in screen with a non-zero origin (external monitor to the left).
**Why it happens:** Flipping Y, or converting `NSEvent.mouseLocation` unnecessarily.
**How to avoid:** Both `NSEvent.mouseLocation` and `panel.frame` are global, bottom-left, unflipped — hit-test directly, no conversion (mirrors Phase-1 Pitfall 1). `[VERIFIED: mouseLocation docs + NotchGeometry conventions]`

### Pitfall 7: Fullscreen safe-area signal misfires on Tahoe's floating menu bar
**What goes wrong:** Tahoe's floating/auto-hiding menu bar changes when the band is "given up", so the safe-area collapse may behave differently than on macOS 14/15.
**Why it happens:** macOS 26 menu-bar rendering changes (project memory + community reports).
**How to avoid:** Treat the exact safe-area-under-fullscreen behavior as **on-device-verify on Tahoe** for all three fullscreen kinds; keep the AX corroboration path so the decision isn't single-signal. `[ASSUMED — Tahoe-specific]`

## Code Examples

### Hover-enter haptic (D-01)
```swift
// Source: Apple NSHapticFeedbackManager docs
// Call ONLY on the false->true isHovering transition (not every mouse-moved tick).
NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
```

### Spring morph trigger (ISL-04 / D-07)
```swift
// Source: Apple Animation.spring docs — tune response/dampingFraction on-device.
withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
    interaction.isExpanded.toggle()
}
```

### matchedGeometryEffect morph skeleton (no cross-fade)
```swift
// Source: Apple matchedGeometryEffect docs + CLAUDE.md "Animation approach"
@Namespace private var ns
// ... in body:
if interaction.isExpanded {
    expandedContent.matchedGeometryEffect(id: "island", in: ns)
} else {
    NotchShape().fill(.black).matchedGeometryEffect(id: "island", in: ns)
}
```

### NSWorkspace fullscreen/space observers (live enter/exit)
```swift
// Source: Apple NSWorkspace.activeSpaceDidChangeNotification docs
let wc = NSWorkspace.shared.notificationCenter
wc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
    self?.updateVisibility()   // re-read safe-area, re-decide show/hide (Pattern 7)
}
wc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
    self?.updateVisibility()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hover-to-expand (literal ISL-03) | **Click-to-open + hover haptic/bounce** (Alcove) | This phase (D-01/D-02) | Verifier tests click, not hover-expand |
| Hand-rolled `CALayer` morph | SwiftUI `matchedGeometryEffect` + spring | macOS 14+ stable | Less code, the canonical DI technique |
| `MRMediaRemote*` direct calls | (N/A this phase — Phase 4) | macOS 15.4 break | Not relevant to Phase 2 |
| `altool` notarization | `notarytool` | — | Not relevant to Phase 2 |

**Deprecated/outdated to avoid:**
- Bounds-vs-screen fullscreen heuristics on notched Macs (unreliable; Apple FB18862047 open).
- `CGEvent.tapCreate` for simple hover (heavier; requires Input Monitoring) — use `NSEvent` monitor or tracking area.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A **global `NSEvent` `.mouseMoved` monitor fires without the Accessibility permission** on Tahoe | Pattern 1 / Pitfall 1 | If wrong, hover silently never fires; need an Accessibility prompt or the `NSTrackingArea` fallback (1b). HIGH impact — probe early on-device. |
| A2 | A **true-fullscreen app collapses the built-in screen's `safeAreaInsets.top` / removes `auxiliaryTop*Area`**, while a maximized window does not | Pattern 6 | If wrong, fullscreen-hide either misfires on maximized windows or fails to fire on fullscreen; need AX-attribute as primary instead. MEDIUM-HIGH — confirm per fullscreen kind on Tahoe. |
| A3 | Fullscreen **video** and **QuickLook** trigger the same safe-area collapse as native fullscreen | Pattern 6 table | If wrong for those two kinds, ISL-05 partially fails; AX corroboration covers the gap. MEDIUM. |
| A4 | Setting the panel to **expanded size up front** (transparent extra area invisible) avoids morph flicker | Pattern 4 note | If wrong, may need to resize at animation boundaries; cosmetic but visible. LOW-MEDIUM. |
| A5 | `.spring(response: 0.35, dampingFraction: 0.65)` is a good Alcove-snappy starting point | Pattern 4 | Purely a tuning seed — expected to be adjusted on-device. LOW. |
| A6 | `NSWorkspace.activeSpaceDidChangeNotification` fires on fullscreen enter/exit (fullscreen apps occupy their own Space) | Pattern 6 / examples | If a fullscreen kind doesn't take a Space, the safe-area poll on `didActivateApplicationNotification` still catches it. LOW-MEDIUM. |

## Open Questions

1. **Does the mouse-moved global monitor need Accessibility on Tahoe? (A1)**
   - What we know: keyboard global monitors need it; mouse behavior is version-dependent and disputed.
   - What's unclear: exact Tahoe behavior for `.mouseMoved`.
   - Recommendation: early on-device probe (log a hover tick); plan the `NSTrackingArea` fallback as a ready branch.

2. **Exact fullscreen safe-area behavior per kind on Tahoe (A2/A3)**
   - What we know: native fullscreen reliably collapses the band; un-sandboxed AX flag is readable.
   - What's unclear: fullscreen video / QuickLook specifics under Tahoe's floating menu bar.
   - Recommendation: verify all three kinds on-device; keep AX corroboration so detection is multi-signal.

3. **Does AX corroboration trigger an Accessibility permission prompt the user must accept?**
   - What we know: AX reads of other apps' windows generally require the Accessibility grant.
   - Recommendation: prefer the safe-area signal as primary (no prompt); only fall to AX where safe-area is ambiguous, and decide in planning whether a one-time prompt is acceptable for v1 or deferred.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| SwiftUI (`matchedGeometryEffect`, `.spring`, `.snappy`) | ISL-04 morph | ✓ | macOS 14 SDK / 26 toolchain | — |
| AppKit (`NSEvent`, `NSPanel`, `NSWorkspace`, `NSHapticFeedbackManager`) | ISL-03/05 | ✓ | macOS 14+ | — |
| `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` | ISL-05 detection | ✓ (already used in Phase 1) | macOS 14+ | AX `kAXFullscreenAttribute` |
| AXUIElement / `kAXFullscreenAttribute` | ISL-05 corroboration | ✓ (un-sandboxed) | macOS 14+ | safe-area signal alone |
| Force-Touch trackpad (for haptic) | D-01 haptic | depends on hardware | — | `defaultPerformer` no-ops; bounce-only feedback remains |
| Accessibility permission (only IF mouse monitor gated) | ISL-03 hover | ✗ until granted | — | `NSTrackingArea` (Pattern 1b) — permission-free |
| `xcodegen`, `xcodebuild` | build | ✓ | Xcode 26.6 | — |

**Missing dependencies with no fallback:** none blocking.
**Missing dependencies with fallback:**
- Accessibility permission for the global mouse monitor — fallback to `NSTrackingArea`.
- Force-Touch trackpad — haptic gracefully no-ops; the visible bounce still satisfies the "you're in" affordance.

## Validation Architecture

> nyquist_validation is enabled (`.planning/config.json` → `workflow.nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | **XCTest** (Apple), hosted unit-test bundle `IsletTests` (`@testable import Islet`) |
| Config file | `project.yml` (XcodeGen) → `IsletTests` target + shared `Islet` scheme |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/<SuiteName>` |
| Full suite command | `xcodebuild test -scheme Islet` (Phase-1 baseline: 24 tests green) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ISL-04 | Expanded frame is centered + top-pinned, correct on non-zero-origin screens (pure geometry) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchGeometryTests` | ❌ Wave 0 (add `expandedNotchFrame` cases) |
| ISL-03 | Hover/click/grace-delay state machine transitions (pure `nextState`) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/InteractionStateTests` | ❌ Wave 0 (new file) |
| ISL-05 | `isTrueFullscreen` predicate: notched-built-in present + safe-area collapsed = true; maximized (safe area intact) = false; clamshell (built-in absent) handled separately | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` | ❌ Wave 0 (new file) |
| ISL-05 | `updateVisibility()` ANDs clamshell + fullscreen correctly (pure decision over inputs) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ❌ Wave 0 (extract a pure `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)`) |
| ISL-03 | Panel still `.nonactivatingPanel`, `canBecomeKey == false` after the conditional-`ignoresMouseEvents` change | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests` | ✅ (extend; the existing `testPanelIsClickThrough` asserting `ignoresMouseEvents == true` must be **updated** — Phase 2 makes it conditional) |
| ISL-03 | Click expands without activating Islet; clicks outside pass through; hover fires haptic + bounce | **manual on-device** | n/a (physical: foreground-app focus, trackpad haptic) | — |
| ISL-04 | Morph looks like a single smooth spring (no flicker/jump/cross-fade) | **manual on-device** | n/a (visual quality) | — |
| ISL-05 | Hide fires for native fullscreen, fullscreen video, QuickLook; stays visible for maximized; auto-restores on exit | **manual on-device** | n/a (real fullscreen apps + Tahoe menu bar) | — |

### Sampling Rate
- **Per task commit:** the relevant `-only-testing:` suite (< 30s) for any touched pure seam.
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite).
- **Phase gate:** full suite green + the three manual on-device checks signed off (mirrors Phase-1 Plan-03 human-verify checkpoint pattern) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `IsletTests/FullscreenDetectorTests.swift` — covers ISL-05 predicate (fullscreen vs maximized vs clamshell).
- [ ] `IsletTests/InteractionStateTests.swift` — covers ISL-03 hover/click/grace-delay `nextState`.
- [ ] `IsletTests/VisibilityDecisionTests.swift` — covers the pure `shouldShow(...)` merging clamshell + fullscreen.
- [ ] Extend `IsletTests/NotchGeometryTests.swift` — `expandedNotchFrame` centering/top-pin/coordinate-flip cases (ISL-04).
- [ ] Update `IsletTests/NotchPanelTests.swift` — the `ignoresMouseEvents` assertion must reflect the conditional model (initial state may still be `true`, but document the change).
- [ ] On-device probe plan: confirm the global mouse-moved monitor fires without Accessibility on Tahoe (A1) early, so the fallback decision is made before the morph work.
- Framework install: none — XCTest infra already exists.

## Security Domain

> `security_enforcement` not set to false in config → included. Phase 2 adds no network, persistence, or new entitlement by design.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | partial | macOS **TCC**: if the global mouse monitor needs Accessibility (A1), that is a privacy-sensitive grant — minimize/avoid (prefer `NSTrackingArea`); never request more than needed |
| V5 Input Validation | minimal | Hit-testing coordinates only; no untrusted external input parsed |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overlay traps/steals user input or focus from the active app | Tampering / DoS | Non-activating panel, `canBecomeKey=false`, conditional `ignoresMouseEvents` restored deterministically, `orderFrontRegardless` only (Pitfalls 2–3) — re-verify the Phase-1 T-01-07 mitigation holds after the change |
| Global mouse monitor = broad input observation (privacy/over-permission) | Info disclosure / over-privilege | Observe `.mouseMoved` only, no logging of locations, no keyboard mask; prefer the permission-free `NSTrackingArea` fallback; never request Accessibility unless on-device proves it necessary |
| AX cross-process window inspection prompts/permission creep | Over-privilege | Use AX only as a fallback corroboration; prefer the no-prompt safe-area signal; defer/limit any Accessibility prompt |

## Sources

### Primary (HIGH confidence)
- Apple Developer — `nonactivatingPanel` (NSWindow.StyleMask): non-activating panel receives clicks without activating the app. https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- Apple Developer — `addGlobalMonitorForEvents(matching:handler:)`: copies of events posted to other apps; handler on main thread. https://developer.apple.com/documentation/appkit/nsevent/1535472-addglobalmonitorforeventsmatchin
- Apple Developer — "Monitoring Events" (global monitors don't observe own app's stream). https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html
- Apple Developer — `NSEvent.mouseLocation` (global screen coords). https://developer.apple.com/documentation/appkit/nsevent/1533380-mouselocation
- Apple Developer — `NSHapticFeedbackManager` + `.levelChange`; always use `defaultPerformer`. https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager
- Apple Developer — `Animation.spring(response:dampingFraction:blendDuration:)`. https://developer.apple.com/documentation/SwiftUI/Animation/spring(response:dampingFraction:blendDuration:)
- Apple Developer — `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` (notch safe area; for custom fullscreen experiences). https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets , https://developer.apple.com/documentation/appkit/nsscreen/3882915-auxiliarytopleftarea
- Apple Developer — `NSWorkspace.activeSpaceDidChangeNotification`, `menuBarOwningApplication`. https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification
- Apple Developer Forums 792917 — "Fullscreen Detection": no perfect cross-process API (FB18862047 open); AX `kAXFullscreenAttribute` works un-sandboxed; bounds heuristics unreliable on notched Macs. https://developer.apple.com/forums/thread/792917
- Project codebase — `Islet/Notch/*.swift`, `IsletTests/*.swift`, `project.yml`, `01-03-SUMMARY.md` (Phase-1 baseline: `.statusBar` over Tahoe menu bar, clamshell drop-out, focus-safe click-through verified).

### Secondary (MEDIUM confidence)
- artlasovsky.com — "Fine-Tuning macOS App Activation Behavior" (`.nonactivatingPanel` subclass receiving input without activation). https://artlasovsky.com/fine-tuning-macos-app-activation-behavior
- fazm.ai — "SwiftUI Floating Panel: NSPanel Patterns" (non-activating panel + collectionBehavior recipe). https://fazm.ai/blog/swiftui-floating-panel
- TheBoringNotch (TheBoredTeam/boring.notch) — SwiftUI macOS notch app; uses `NSEvent` global mouse monitoring for notch hover (per BrightCoding writeup). https://github.com/TheBoredTeam/boring.notch , https://blog.brightcoding.dev/2026/03/24/boring-notch-your-macbooks-notch-just-got-powerful
- dev.to / Medium SwiftUI spring tunings (response/dampingFraction reference values). https://dev.to/sebastienlato/swiftui-animation-masterclass-springs-curves-smooth-motion-3e4o

### Tertiary (LOW confidence — flagged for on-device validation)
- Community conflict on whether a global *mouse-moved* monitor needs Accessibility on current macOS (HackTricks; keepassxc #3393; electrobun #334) — drives A1 + the Wave-0 probe. https://hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-input-monitoring-screen-capture-accessibility.html
- The Swift Den / SwiftUI Field Guide — safe-area-vs-visibleFrame arithmetic on notched Macs doesn't cleanly add up (motivates verifying the safe-area-collapse signal on-device). https://www.answeroverflow.com/m/1145112887048810606

## Metadata

**Confidence breakdown:**
- Interaction model (focus-safe click-to-open): MEDIUM-HIGH — mechanism verified against Apple docs; the Accessibility-permission edge (A1) is the one real unknown, with a ready fallback.
- Animation morph: HIGH — `matchedGeometryEffect` + spring is the canonical, mandated technique; only tuning values are open.
- Fullscreen detection: MEDIUM — no perfect public API; the safe-area-collapse signal (notched Mac) + AX corroboration is sound but the per-kind behavior on Tahoe needs on-device confirmation (A2/A3).
- Test architecture: HIGH — reuses Phase-1's pure-seam + on-device-checkpoint pattern exactly.

**Research date:** 2026-06-27
**Valid until:** ~2026-07-27 (stable Apple APIs; re-verify A1/A2/A3 after any macOS 26.x point update — Tahoe menu-bar behavior is the volatile element).
