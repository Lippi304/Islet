# Phase 1: The Empty Island (Window + Geometry) - Research

**Researched:** 2026-06-26
**Domain:** macOS native overlay windows (AppKit `NSPanel`) + notch geometry + multi-display targeting
**Confidence:** HIGH (window + geometry recipe verified against two prior-art apps and the build environment)

## Summary

Phase 1 is a pure AppKit-window + geometry problem with a thin SwiftUI render. The entire feature — a borderless, non-activating, always-on-top pill hugging the notch on the built-in display — is achievable with **first-party, long-stable APIs** (`NSPanel`, `NSScreen.safeAreaInsets`, `NSScreen.auxiliaryTopLeftArea/auxiliaryTopRightArea`, `CGDisplayIsBuiltin`, `NSApplication.didChangeScreenParametersNotification`). All of these were introduced no later than **macOS 12.0**, comfortably below the project's **macOS 14.0 floor** [VERIFIED: project.yml deploymentTarget 14.0]. No geometry/window API in this phase requires a minimum newer than the deployment target, so no fallback for API availability is needed — the only fallbacks needed are *data* fallbacks (when a screen has no notch and the auxiliary-area APIs return `nil`).

The two canonical open-source prior-art apps agree on the core math: **notch width = `screen.frame.width − auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width`** and **notch height = `screen.safeAreaInsets.top`**; a screen "has a notch" when `safeAreaInsets.top > 0` (equivalently, both auxiliary areas are non-`nil`). The pill is centered with `x = frame.midX − width/2`, `y = frame.maxY − height` (AppKit bottom-left origin), and the corner radius is **not exposed by any API** — it is approximated with constants (boring.notch ships closed top-radius ≈ 6, bottom-radius ≈ 14). The window is a custom `NSPanel` subclass with `styleMask = [.borderless, .nonactivatingPanel]`, a high `level`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `backgroundColor = .clear`, `hasShadow = false`, and `canBecomeKey/Main = false`; show it with `orderFrontRegardless()` (never `makeKeyAndOrderFront`, which would steal focus).

Correct-display + screen-change recovery is the genuinely hard part and is a **core success criterion, not polish** [CITED: 01-CONTEXT.md D-04/D-05]. The robust pattern (proven in boring.notch) is: persist target displays by **CGDisplay UUID** (not array index — indices reorder), re-resolve on `didChangeScreenParametersNotification`, and in clamshell mode the built-in screen simply **disappears from `NSScreen.screens`**, so "hide in clamshell" falls out naturally from "show only when a built-in notched screen is present." [VERIFIED: boring.notch source]

**Primary recommendation:** Build a `NotchWindowController` retained by `AppDelegate.applicationDidFinishLaunching` that (1) finds the built-in notched `NSScreen` via `CGDisplayIsBuiltin` + `safeAreaInsets.top > 0`, (2) creates one custom `NSPanel` (the recipe above) hosting an `NSHostingView` of a black `NotchShape`, (3) sizes/positions it to the notch geometry, and (4) re-runs that whole resolve-and-position routine on every `didChangeScreenParametersNotification`, hiding the panel (or never creating it) when no built-in notched screen exists. Use a `#if DEBUG` tint+offset flag (D-02) so the first-time builder can *see* the pill during development.

---

<user_constraints>
## User Constraints (from 01-CONTEXT.md)

### Locked Decisions
- **D-01:** The collapsed/idle pill **exactly hugs the physical notch** — same width and same corner radius — so it **visually merges with the hardware notch and is effectively invisible when idle** (Alcove look; satisfies ISL-07). Pure black.
- **D-02:** Because an exact-hug black pill is invisible against the real notch, the build must render it **temporarily tinted / visibly offset DURING DEVELOPMENT** (a debug flag) so the user can verify position, width, and corner radius — then ship idle-invisible. Required for a first-time programmer to confirm the phase works.
- **D-03:** Idle pill is **static — no animation, no pulsing** (ISL-07).
- **D-04:** The island lives **only on the built-in notch display**. With an external monitor connected (lid open), it stays on the built-in screen. In **clamshell mode (lid closed) the island hides entirely** — never relocates to an external display.
- **D-05:** The window **re-evaluates and re-positions on every screen-configuration change** (`NSApplication.didChangeScreenParametersNotification`): external plug/unplug, resolution change, and lid open/close. Must recover to the correct state automatically — never stuck on the wrong display or orphaned off-screen.
- **D-06:** Build a **custom `NSPanel`** (borderless, non-activating, status-bar-level / above normal windows, all-Spaces `collectionBehavior`) hosting the SwiftUI pill via `NSHostingView`. **No DynamicNotchKit dependency** — it is oriented at transient toasts, not a persistent always-visible compact pill. Full control, zero third-party surface.
- **D-07:** Phase 1 is a **static, non-interactive pill**. No hover, no expand/collapse, no click-through gating logic (all Phase 2). **However**, the window is built from the start as **non-activating + click-through**: it must **never steal focus** from the active app and must **never block clicks** to the menu bar / desktop around it. Foundation for ISL-02 and Phase 2.

### Claude's Discretion
- The exact notch-geometry API (`NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`) and the method for approximating the notch **corner radius** (macOS does not expose it directly — reference apps approximate/measure).
- The `NSPanel` style mask, exact window `level`, and `collectionBehavior` flag set for all-Spaces + above-fullscreen-aux behavior.
- How the dev-time tint (D-02) is toggled (build flag / `#if DEBUG` / a constant).
- Where the overlay controller lives in code (e.g. a `NotchWindowController` created and retained by `AppDelegate.applicationDidFinishLaunching`, alongside the existing status item).
- The screen-reconfiguration observer wiring and any debounce.

### Deferred Ideas (OUT OF SCOPE)
- **Configurable display behavior** (show island also on external monitors; configurable fullscreen behavior). External-display pill is out-of-scope for v1 in REQUIREMENTS. Fullscreen-yield is Phase 2 (ISL-05). User-configurability would be a Phase 6 Settings extension (APP-03). **Forward note:** keep display-selection logic open enough that a future "also show on external monitor" option is not architecturally blocked — but do **not** build it in Phase 1.
- **Hover, spring-morph expand/collapse, click-through gating, fullscreen-yield** → Phase 2. (The window is built non-activating + click-through now, but no hover/expand/gating logic.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **ISL-01** | A black, rounded island renders over the physical notch on the built-in display, matching the notch's width and corner radius | Notch geometry section: width = `frame.width − auxLeft.width − auxRight.width`, height = `safeAreaInsets.top`, corner radius via `NotchShape` constants (top≈6/bottom≈14). Pill = black `NotchShape` in `NSHostingView`. |
| **ISL-02** | The island stays above other windows and is visible across all Spaces / desktops | `NSPanel` `level` (`.statusBar`/`.screenSaver`/`.mainMenu+`), `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `orderFrontRegardless()`. |
| **ISL-06** | The island positions on the correct screen with external displays + clamshell (never wrong display) | Built-in detection via `CGDisplayIsBuiltin` + `safeAreaInsets.top > 0`; persist by CGDisplay UUID; re-resolve on `didChangeScreenParametersNotification`; clamshell → built-in absent from `NSScreen.screens` → hide. |
| **ISL-07** | When idle, the collapsed island is unobtrusive (near-invisible, not animating) | D-01 exact-hug pure-black merges with hardware notch; D-03 static (no animation). `#if DEBUG` tint (D-02) only in dev builds. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are authoritative directives — the planner must not recommend approaches that contradict them:

- **Swift 5 language mode** (`SWIFT_VERSION = 5.0`) even on the Swift 6.3 toolchain — avoid strict-concurrency churn. [VERIFIED: project.yml]
- **macOS 14.0 deployment floor** (`MACOSX_DEPLOYMENT_TARGET = 14.0`). [VERIFIED: project.yml]
- **Un-sandboxed** (`ENABLE_APP_SANDBOX = NO`), hardened runtime ON. [VERIFIED: project.yml]
- **SwiftUI for ~95% of UI; small AppKit surface** for the window shell only — drop into AppKit *only* for `NSPanel`/`NSStatusItem`/event hooks, host SwiftUI via `NSHostingView`. [CITED: CLAUDE.md tech-stack table]
- **No DynamicNotchKit dependency** for the persistent pill (CLAUDE.md "What NOT to Use" + Stack-Patterns rationale; reinforced by D-06). Roll a custom `NSPanel`.
- **Avoid Core Animation / hand-rolled `CALayer`** — SwiftUI gives the look for free. (Animation is Phase 2 anyway; for Phase 1 the pill is a static `Shape`.)
- **`project.yml` (XcodeGen) auto-discovers any new `.swift` under `Islet/`** — add overlay sources then `xcodegen generate`; no manual `.xcodeproj` edits. [VERIFIED: project.yml `sources: - path: Islet`]
- First-time programmer: explain important code; avoid unnecessary complexity. [CITED: CLAUDE.md builder-skill constraint]

## Build Environment (verified this session)

| Component | Value | Source |
|-----------|-------|--------|
| macOS | **27.0 / "Tahoe" (build 26A5368g)** — marketed as macOS 26 | `sw_vers` [VERIFIED] |
| Xcode | **26.6** (build 17F113) | `xcodebuild -version` [VERIFIED] |
| Swift toolchain | **6.3.3** (swiftlang-6.3.3.1.3) | `swift --version` [VERIFIED] |
| Language mode | **Swift 5.0** | project.yml `SWIFT_VERSION` [VERIFIED] |
| Deployment target | **macOS 14.0** | project.yml [VERIFIED] |

All Phase-1 APIs are available on macOS 14.0 and behave on macOS 26. **No API in this phase requires a minimum newer than 14.0.** [VERIFIED — see version table below]

## Standard Stack

### Core (all first-party — zero third-party dependencies for this phase)
| Framework / API | Min macOS | Purpose | Why Standard |
|-----------------|-----------|---------|--------------|
| `AppKit.NSPanel` (subclassed) | 10.0 | The borderless non-activating overlay window | The only AppKit primitive for a floating, non-activating, all-Spaces window; SwiftUI cannot model this. Both prior-art apps subclass `NSPanel`. [VERIFIED: DNK + boring.notch source] |
| `AppKit.NSHostingView` | 10.15 | Host the SwiftUI pill inside the `NSPanel` | The standard SwiftUI↔AppKit bridge; matches existing project pattern (`NSStatusItem` + SwiftUI). [VERIFIED: existing AppDelegate uses the same split] |
| `NSScreen.safeAreaInsets` | **12.0** | Notch height (`.top`) and has-notch test (`> 0`) | Apple's documented notch-detection API. [VERIFIED: prior-art use; CITED: developer.apple.com/documentation/appkit/nsscreen/safeareainsets] |
| `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` | **12.0** | Notch **width** = `frame.width − left.width − right.width` | Apple's documented notch-region API; returns `nil` on non-notch screens (used as the has-notch signal). [VERIFIED: prior-art; CITED: developer.apple.com/documentation/AppKit/NSScreen/auxiliaryTopLeftArea-uglc] |
| `CGDisplayIsBuiltin(_:)` (CoreGraphics) | 10.2 | Identify the **built-in** display (vs external) | Canonical built-in test; pairs with `NSScreenNumber` from `deviceDescription`. [CITED: developer.apple.com/documentation/coregraphics/1454566-cgdisplayisbuiltin] |
| `CGDisplayCreateUUIDFromDisplayID` (CoreGraphics) | 10.x | Stable per-display UUID for persistence across reconfig | boring.notch persists target display by UUID (indices reorder on plug/unplug). [VERIFIED: boring.notch NSScreen+UUID.swift] |
| `NSApplication.didChangeScreenParametersNotification` | 10.6 | Fire on plug/unplug, resolution change, clamshell open/close | The reliable, documented screen-reconfig hook; both prior-art apps use exactly this. [VERIFIED: boring.notch + DNK source] |
| `SwiftUI.Shape` (custom `NotchShape`) | 13.0+ (have 14.0) | Draw the rounded pill matching the notch radius | A `Shape.path(in:)` with quad curves; corner radius is a constant since no API exposes it. [VERIFIED: boring.notch NotchShape.swift] |

### Supporting
| API | Purpose | When to Use |
|-----|---------|-------------|
| `NSScreen.deviceDescription[NSScreenNumber]` | Get `CGDirectDisplayID` from an `NSScreen` | To call `CGDisplayIsBuiltin` / `CGDisplayCreateUUIDFromDisplayID`. [VERIFIED: prior-art] |
| `NSScreen.frame` / `.visibleFrame` / `.midX` / `.maxY` | Positioning math; menu-bar height = `frame.maxY − visibleFrame.maxY` | Window-frame computation. [VERIFIED: DNK `menubarHeight`] |
| `panel.orderFrontRegardless()` | Show without activating the app | Always — never `makeKeyAndOrderFront` (steals focus, violates D-07). [VERIFIED: DNK + boring.notch both use `orderFrontRegardless`] |
| `RoundedRectangle` / `Capsule` (SwiftUI) | Simpler alternative to a custom `NotchShape` | If a plain capsule visually matches well enough for v1 (the notch corners differ top vs bottom — see pitfall). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `NSPanel` | **DynamicNotchKit** | Rejected by D-06 + CLAUDE.md: DNK is built around transient `expand()/hide()` toasts, not a persistent always-visible compact pill; its panel uses `.screenSaver` level + `[.canJoinAllSpaces, .stationary]` — good reference, but you want full control. **Use DNK's source as a reference, add zero dependency.** |
| `CGDisplayIsBuiltin` for built-in test | `safeAreaInsets.top > 0` alone | `safeAreaInsets.top > 0` already implies a notch (only built-in notched displays have it), so it *almost* doubles as a built-in test. But an external monitor never has a notch, and the built-in could theoretically be mirrored — use **both** (built-in AND notched) to be unambiguous and future-proof. |
| Persist target display by **UUID** | Persist by array index | Array indices reorder when displays are added/removed — index-based selection lands on the wrong display. UUID is stable. [VERIFIED: boring.notch chose UUID] |
| Custom `NotchShape` (top+bottom radius differ) | `Capsule()` / `RoundedRectangle` | A `Capsule` has equal radii all around; the real notch has small top corners and larger bottom corners. For an *exact* hug (D-01), the asymmetric `NotchShape` is more faithful. For idle-invisible pure black it matters less, but D-02 dev-visibility wants it to look right. |

**Installation:** None. All APIs ship with the macOS SDK. No `npm`/SPM packages added for Phase 1. Add new `.swift` files under `Islet/` and run `xcodegen generate`.

**Version verification:** `safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` are macOS **12.0+** APIs [CITED: Apple docs] — well below the 14.0 floor. `CGDisplayIsBuiltin` is macOS 10.2+. `didChangeScreenParametersNotification` is 10.6+. **No availability fallback required.** (Apple's developer docs render client-side and could not be scraped this session for the literal "Available since" string; the 12.0 figure is corroborated by both prior-art apps targeting 12/13+ and the wide community record — tagged HIGH but see Assumptions Log A1.)

## Architecture Patterns

### Recommended Project Structure
```
Islet/
├── AppDelegate.swift          # EXISTING — add: create & retain NotchWindowController in applicationDidFinishLaunching
├── IsletApp.swift             # EXISTING — unchanged (settings window scene)
├── SettingsView.swift         # EXISTING — unchanged
├── LaunchAtLogin.swift        # EXISTING — unchanged
├── Notch/                     # NEW (XcodeGen auto-discovers)
│   ├── NotchWindowController.swift   # owns the NSPanel; resolve-display + position + screen-change observer
│   ├── NotchPanel.swift              # NSPanel subclass: styleMask, level, collectionBehavior, canBecomeKey=false
│   ├── NotchShape.swift              # SwiftUI Shape: asymmetric rounded pill (top/bottom radius)
│   ├── NotchPillView.swift           # SwiftUI: black NotchShape (+ #if DEBUG tint/offset)
│   └── NSScreen+Notch.swift          # NSScreen extensions: hasNotch, notchSize, notchFrame, displayID, isBuiltin, displayUUID
```
(Folder name is discretion; the split mirrors the existing "AppKit owns the window, SwiftUI fills it" pattern.) [CITED: 01-CONTEXT.md code_context]

### Pattern 1: Custom non-activating overlay `NSPanel`
**What:** Subclass `NSPanel`; configure once in `init`. Never let it become key/main.
**When to use:** The persistent island window (the whole phase).
**Example:**
```swift
// Source: synthesized from DynamicNotchKit/DynamicNotchPanel.swift +
//         boring.notch/BoringNotchWindow.swift (both verified this session)
import AppKit

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],   // borderless + never activates the app (D-07)
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear        // transparent window; the pill draws the black
        hasShadow = false               // no drop shadow around the notch
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false    // keep the object alive across show/hide
        ignoresMouseEvents = true       // Phase 1: fully click-through (D-07). Phase 2 makes this conditional.
        // Above normal windows AND visible across Spaces & over fullscreen-aux content (ISL-02):
        level = .statusBar              // see "Window level" note for the tradeoff vs .mainMenu+1 / .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
    // A non-activating overlay must NEVER take focus (D-07):
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```
Show it with `panel.orderFrontRegardless()` — NOT `makeKeyAndOrderFront`. [VERIFIED: both prior-art apps]

**Window level — the one real decision (Claude's discretion D-06):**
- DynamicNotchKit uses `.screenSaver`. [VERIFIED]
- boring.notch uses `.mainMenu + 3`. [VERIFIED]
- The Phase-1 hint and CLAUDE.md say `.statusBar`.
All three sit above normal windows. The pill must sit *over the notch*, i.e. over/at the menu-bar band. `.statusBar` is the documented "status item" band; `.mainMenu + N` explicitly orders relative to the menu bar; `.screenSaver` is highest. **Recommendation:** start with `.statusBar`; if on macOS 26 the menu bar ever paints over the pill in the notch band, bump to `.mainMenu + 1`. This is a one-line change — plan a verification step (manual visual) for it. [ASSUMED — A2: which level wins over the Tahoe menu bar at the notch needs on-device confirmation.]

### Pattern 2: Notch geometry via `NSScreen` (the verified math)
**What:** Compute width/height/centering from `NSScreen` properties.
**Example:**
```swift
// Source: NSScreen math verified against DynamicNotchKit/NSScreen+Extensions.swift
//         and boring.notch/sizing/matters.swift (getClosedNotchSize) this session.
import AppKit

extension NSScreen {
    /// True only for the built-in notched display.
    var hasNotch: Bool {
        // safeAreaInsets.top > 0 is the notch signal; auxiliary areas confirm it.
        safeAreaInsets.top > 0
            && auxiliaryTopLeftArea != nil
            && auxiliaryTopRightArea != nil
    }

    /// Physical notch size in this screen's coordinate space.
    var notchSize: NSSize? {
        guard
            let left = auxiliaryTopLeftArea?.width,
            let right = auxiliaryTopRightArea?.width
        else { return nil }
        let width  = frame.width - left - right          // boring.notch adds +4 to overlap the hardware edges
        let height = safeAreaInsets.top                  // real notch height
        return NSSize(width: width, height: height)
    }

    /// AppKit (bottom-left origin) frame centered on the notch.
    var notchFrame: NSRect? {
        guard let size = notchSize else { return nil }
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,                 // maxY is the TOP edge in AppKit coords
            width: size.width,
            height: size.height
        )
    }

    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    var isBuiltin: Bool {
        guard let id = displayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }

    /// Stable per-display UUID (survives reconfiguration; persist this, not an index).
    var displayUUID: String? {
        guard let id = displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }
}

/// The Phase-1 target: the one built-in, notched screen — or nil (clamshell / non-notch Mac).
func builtinNotchedScreen() -> NSScreen? {
    NSScreen.screens.first { $0.isBuiltin && $0.hasNotch }
}
```
**Notch width fudge factor:** boring.notch adds `+4` to the computed width so the pill overlaps the hardware edges and leaves no visible seam. Treat the exact fudge as a tunable constant to verify visually in dev (D-02). [VERIFIED: boring.notch `notchWidth = ... + 4`]

### Pattern 3: `NotchShape` (asymmetric rounded pill)
**What:** A `Shape` with a small top radius and larger bottom radius — the real notch silhouette.
**Constants (verified prior-art, closed/idle state):** top corner radius **≈ 6**, bottom corner radius **≈ 14**. [VERIFIED: boring.notch NotchShape default + `cornerRadiusInsets.closed = (top: 6, bottom: 14)`]
```swift
// Source: boring.notch/components/Notch/NotchShape.swift (verified this session).
// Builds a "hanging" notch silhouette: flat top, quad-curved corners, rounded bottom.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}
```

### Pattern 4: Screen-change recovery (the hard part — ISL-06)
**What:** One `resolveAndPosition()` routine; call it on launch and on every `didChangeScreenParametersNotification`.
**Example:**
```swift
// Source: pattern verified against boring.notch screenConfigurationDidChange / adjustWindowPosition.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var observer: Any?

    func start() {
        resolveAndPosition()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Coalesce bursts (a single reconfig can fire several times): hop to the
            // next main-loop turn so NSScreen.screens has fully settled.
            DispatchQueue.main.async { self?.resolveAndPosition() }
        }
    }

    private func resolveAndPosition() {
        guard let screen = builtinNotchedScreen(), let frame = screen.notchFrame else {
            panel?.orderOut(nil)        // clamshell / no notch → hide (D-04). Never relocate to external.
            return
        }
        let panel = self.panel ?? NotchPanel(contentRect: frame)
        if self.panel == nil {
            panel.contentView = NSHostingView(rootView: NotchPillView())
            self.panel = panel
        }
        panel.setFrame(frame, display: true)   // re-position for resolution changes / new screen
        panel.orderFrontRegardless()
    }

    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
}
```
**Clamshell falls out for free:** with the lid closed, the built-in display leaves `NSScreen.screens`, so `builtinNotchedScreen()` returns `nil` and the panel is ordered out — exactly D-04's "hide entirely in clamshell, never relocate." [VERIFIED: behavior consistent across prior-art + community reports; ASSUMED A3 — confirm on-device that the built-in truly drops out of `NSScreen.screens` in clamshell on macOS 26.]

### Pattern 5: Dev-visibility flag (D-02)
```swift
struct NotchPillView: View {
    var body: some View {
        NotchShape()
            .fill(fillColor)
            .offset(y: devOffset)    // small downward offset in DEBUG so the pill peeks below the hardware notch
    }
    private var fillColor: Color {
        #if DEBUG
        return .red.opacity(0.6)     // visible during development
        #else
        return .black                // ships idle-invisible (D-01)
        #endif
    }
    private var devOffset: CGFloat {
        #if DEBUG
        return 8
        #else
        return 0
        #endif
    }
}
```
(A single `#if DEBUG` constant is the simplest of the discretion options; a runtime `UserDefaults`/launch-arg toggle is overkill for Phase 1.) [CITED: D-02 allows build flag / `#if DEBUG` / a constant]

### Anti-Patterns to Avoid
- **`makeKeyAndOrderFront` to show the panel** — steals focus from the active app, violating D-07/ISL-02 feel. Use `orderFrontRegardless()`. [VERIFIED: prior-art]
- **Selecting the display by `NSScreen.screens[0]` / array index** — index reorders on plug/unplug; the island lands on the wrong display. Persist by **UUID** and re-resolve. [VERIFIED: boring.notch's deliberate UUID design]
- **Toggling `.nonactivatingPanel` in the style mask *after* init** — AppKit doesn't fully re-apply activation behavior post-init; set it once in `super.init`. [CITED: philz.blog "Curious Case of NSPanel's Nonactivating flag"]
- **Hand-rolling `CALayer`/Core Animation for the pill** — unneeded; SwiftUI `Shape.fill` is enough and CLAUDE.md forbids it for a beginner. (Animation is Phase 2 regardless.)
- **Assuming the notch height = menu-bar height.** They differ; `safeAreaInsets.top` is the *notch* height. Use `frame.maxY − visibleFrame.maxY` only as the *non-notch fallback*. [VERIFIED: boring.notch distinguishes the two]
- **Letting the panel show on a non-notch Mac.** Out of scope for v1 (REQUIREMENTS "Non-notch Macs … out of scope"); `builtinNotchedScreen()` returns `nil` there and the panel never shows — correct.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notch width/height detection | Pixel-scanning the wallpaper / hardcoding per-model dimensions | `safeAreaInsets.top` + `auxiliaryTopLeftArea/RightArea.width` | Apple exposes exact values per display; hardcoding breaks across MacBook models and scaling modes. [VERIFIED] |
| Built-in vs external display | Comparing display sizes / names heuristically | `CGDisplayIsBuiltin(displayID)` | Direct, documented boolean. Heuristics fail with same-size externals or mirrored setups. [CITED: Apple docs] |
| Re-finding "my" display after a reconfig | Caching an `NSScreen` reference or array index | `CGDisplayCreateUUIDFromDisplayID` → persist UUID → re-look-up | `NSScreen` objects and indices are invalidated/reordered on reconfig; UUID is stable. [VERIFIED: boring.notch] |
| Detecting plug/unplug/resolution/clamshell | Polling `NSScreen.screens` on a timer | `NSApplication.didChangeScreenParametersNotification` | One event covers all four; polling wastes CPU and lags. [VERIFIED: both prior-art] |
| Borderless non-activating all-Spaces window | A plain `NSWindow` with manual masks and focus hacks | `NSPanel` subclass with `.nonactivatingPanel` + `collectionBehavior` | `NSPanel` is purpose-built for non-activating floating windows; rolling it on `NSWindow` reintroduces focus-stealing bugs. [VERIFIED] |

**Key insight:** Every hard sub-problem in this phase already has a first-party API that the two leading open-source notch apps converged on. The phase's risk is **not** "can we detect the notch" (solved) — it is **getting multi-display + clamshell recovery exactly right**, which is purely a matter of using UUID persistence + the screen-params notification, both demonstrated above.

## Common Pitfalls

### Pitfall 1: Coordinate-space flip (top-left vs bottom-left origin)
**What goes wrong:** `safeAreaInsets`/auxiliary areas are conceptually "from the top," but AppKit window frames use a **bottom-left origin** with `y` increasing upward. Naively using a top-origin `y` puts the pill at the bottom of the screen.
**Why it happens:** Mixing UIKit-style top-origin thinking with AppKit geometry.
**How to avoid:** Position with `y = screen.frame.maxY − notchHeight` (top edge), `x = screen.frame.midX − notchWidth/2`. The verified `notchFrame` above already does this. [VERIFIED: DNK `notchFrame` uses `frame.maxY - height`]
**Warning sign:** Pill renders at the bottom-center of the screen.

### Pitfall 2: Wrong display after plug/unplug (the ISL-06 core risk)
**What goes wrong:** Island appears on an external monitor or vanishes after a reconfig.
**Why it happens:** Selecting by array index, or caching a stale `NSScreen`, or not re-positioning on `didChangeScreenParametersNotification`.
**How to avoid:** Resolve `builtinNotchedScreen()` fresh each time and re-position; persist nothing but the UUID. Hide when it returns `nil`. [VERIFIED: boring.notch design]
**Warning sign:** Island on the external display, or orphaned off-screen, after connecting a monitor or changing resolution.

### Pitfall 3: The pill is genuinely invisible in dev (you can't tell it works)
**What goes wrong:** An exact black hug against the real black notch shows *nothing* — the first-time builder can't confirm width/radius/position.
**Why it happens:** D-01 success *is* invisibility.
**How to avoid:** D-02 `#if DEBUG` tint + small offset so the pill peeks out during development; ship black/flush. Plan a dev-visible verification before the idle-invisible final check. [CITED: D-02]
**Warning sign:** "It builds and runs but I can't see anything" — expected; flip on the debug tint.

### Pitfall 4: Menu bar paints over the pill in the notch band (macOS 26 Tahoe)
**What goes wrong:** On Tahoe the menu bar is transparent/floating by default and the system draws the notch region; an overlay at too low a level can be occluded at the notch.
**Why it happens:** Window-level ordering relative to the menu bar at the notch.
**How to avoid:** If `.statusBar` is occluded, raise to `.mainMenu + 1` (boring.notch uses `.mainMenu + 3`). Verify visually on-device. [ASSUMED A2 — needs on-device check on macOS 26]
**Warning sign:** Pill visible elsewhere but clipped/hidden exactly at the notch.

### Pitfall 5: Panel steals focus or blocks clicks
**What goes wrong:** Clicking near the notch activates Islet or swallows clicks meant for the menu bar/desktop.
**Why it happens:** Missing `.nonactivatingPanel`, `canBecomeKey=true`, or not `ignoresMouseEvents`.
**How to avoid:** `.nonactivatingPanel` in styleMask, `canBecomeKey/Main = false`, `ignoresMouseEvents = true` (Phase 1 is fully click-through; Phase 2 makes mouse handling conditional). Show with `orderFrontRegardless`. [VERIFIED: prior-art; D-07]
**Warning sign:** App icon flashes to front on click near notch; menu-bar items under the pill stop responding.

### Pitfall 6: Reconfig notification fires multiple times / mid-transition
**What goes wrong:** `didChangeScreenParametersNotification` can fire several times for one physical change, or fire before `NSScreen.screens` has settled.
**Why it happens:** The system reports intermediate states during reconfiguration.
**How to avoid:** Coalesce by re-dispatching `resolveAndPosition()` to the next main-loop turn (a light debounce). The routine is idempotent, so extra calls are harmless. [VERIFIED: boring.notch dispatches async in its handler]
**Warning sign:** Brief flicker or transient wrong-display placement during plug/unplug.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcode notch dimensions per MacBook model | `safeAreaInsets` + `auxiliaryTop*Area` | macOS 12 (2021) | Exact per-display values; no model table to maintain. |
| Select display by `NSScreen.screens` index | Persist by `CGDisplay` **UUID** | boring.notch refactor (2025-11) | Survives plug/unplug reordering — the correct-display fix. [VERIFIED: NSScreen+UUID.swift dated 2025-11-21] |
| Opaque menu bar (pre-Tahoe) | Transparent/floating menu bar at notch (macOS 26) | macOS 26 / Tahoe (2025) | May affect which window `level` wins at the notch band — verify on-device (Pitfall 4). |

**Deprecated/outdated:**
- Nothing in this phase's API set is deprecated. `NSPanel`, `NSScreen` notch APIs, `CGDisplayIsBuiltin`, and the screen-params notification are all current on macOS 26.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `safeAreaInsets` / `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` were introduced in **macOS 12.0** | Standard Stack / version table | Low. Even if it were 13.0, still below the 14.0 floor — no behavioral impact. Apple docs couldn't be scraped this session (JS-rendered); figure corroborated by prior-art + community. |
| A2 | `.statusBar` window level renders the pill **over** the Tahoe menu bar at the notch band; bump to `.mainMenu + 1` if not | Architecture / Pitfall 4 | Medium. If wrong, pill is clipped at the notch until the level is bumped — a one-line fix, but a real on-device verification step is needed. |
| A3 | In clamshell mode the **built-in display drops out of `NSScreen.screens`** on macOS 26, so hide-in-clamshell falls out of the resolve logic | Pattern 4 | Medium. If the built-in lingered in `screens` while the lid is closed, the panel could try to render on an off display. Needs on-device clamshell test (plug external, close lid). |
| A4 | The `+4` notch-width fudge and top=6/bottom=14 corner radii are good *starting* constants for *this* MacBook | Pattern 2/3 | Low. Visual constants to tune in dev (D-02); not correctness-critical. The real notch radius is not API-exposed on any macOS — approximation is the only option. |

## Open Questions

1. **Exact window level over the Tahoe menu bar at the notch**
   - What we know: `.statusBar`, `.mainMenu+N`, and `.screenSaver` all sit above normal windows; prior-art picks differ (DNK `.screenSaver`, boring.notch `.mainMenu+3`, CLAUDE.md hint `.statusBar`).
   - What's unclear: which one cleanly wins over the macOS 26 transparent menu bar *in the notch band* on this machine.
   - Recommendation: implement with `.statusBar`; add a manual visual verification; if clipped, change to `.mainMenu + 1`. One-line, low-risk.

2. **Exact corner radius of this MacBook's physical notch**
   - What we know: no API exposes it; prior-art approximates (top≈6, bottom≈14 closed).
   - What's unclear: the precise radius for a pixel-perfect hug on *this* model.
   - Recommendation: ship the prior-art constants, verify with the D-02 dev tint, tune by eye. Acceptable for v1.

3. **Whether a plain `Capsule` is "good enough" vs the asymmetric `NotchShape`**
   - What we know: idle-invisible pure black makes the difference subtle; the dev-visible tint will reveal it.
   - Recommendation: start with `NotchShape` (faithful), since it's also what Phase 2's morph will animate; falling back to `Capsule` is trivial if the shape misbehaves.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| macOS SDK (AppKit, CoreGraphics, SwiftUI) | All of Phase 1 | ✓ | macOS 14.0 SDK via Xcode 26.6 | — |
| Xcode | Build/run/debug | ✓ | 26.6 (17F113) | — |
| Swift toolchain | Compile (Swift 5 mode) | ✓ | 6.3.3 | — |
| XcodeGen (`xcodegen`) | Regenerate `.xcodeproj` after adding files | — (assumed installed; used in Phase 0) | per project.yml workflow | Manually add files in Xcode if `xcodegen` missing |
| A physical notch MacBook (this machine) | Manual visual verification of pill-over-notch | ✓ | — (built-in notched display) | None — geometry math is unit-testable without it; *visual* confirmation requires the hardware (have it) |
| An external monitor | Manual ISL-06 / clamshell verification | ✗ (not confirmed available) | — | Verify display-resolution/selection logic via unit tests with mocked screen data; do a manual external+clamshell pass when a monitor is available |

**Missing dependencies with no fallback:** None block implementation. The geometry and display-selection *logic* is fully unit-testable with injected/mocked screen data; only the final visual + real multi-display pass needs hardware.

**Missing dependencies with fallback:** External monitor (for live ISL-06/clamshell check) — covered by unit tests now, plus a manual pass when hardware is available. Confirm `xcodegen` is installed (it was used in Phase 0).

## Validation Architecture

> `workflow.nyquist_validation` is `true` in config.json — this section is included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.6) — no third-party test dep needed |
| Config file | none yet — **Wave 0** adds an `IsletTests` target to `project.yml` + an XCTest bundle |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchGeometryTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| ISL-01 | Notch width = `frame.width − auxLeft − auxRight`; height = `safeAreaInsets.top`; frame centered (`midX − w/2`, `maxY − h`) | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchGeometryTests/testNotchFrameMath` | ❌ Wave 0 |
| ISL-01 | `NotchShape.path(in:)` produces a closed path of expected bounds for given radii | unit | `…-only-testing:IsletTests/NotchShapeTests/testPathBounds` | ❌ Wave 0 |
| ISL-01 | Pill renders **black** in release config, tinted in DEBUG | unit (config-conditional) + manual | `…-only-testing:IsletTests/NotchPillViewTests/testFillColorByConfig` | ❌ Wave 0 |
| ISL-06 | Built-in notched screen selected; external never chosen | unit (mock screens) | `…-only-testing:IsletTests/DisplaySelectionTests/testPicksBuiltinNotched` | ❌ Wave 0 |
| ISL-06 | No built-in notched screen (clamshell/non-notch) → resolver returns nil → panel hidden | unit (mock) | `…-only-testing:IsletTests/DisplaySelectionTests/testHidesWhenNoBuiltinNotch` | ❌ Wave 0 |
| ISL-06 | Re-resolve is idempotent and repositions on changed frame | unit | `…-only-testing:IsletTests/DisplaySelectionTests/testRepositionOnResolutionChange` | ❌ Wave 0 |
| ISL-02 | Panel configured: `.nonactivatingPanel` in styleMask, `canBecomeKey==false`, level above normal, `collectionBehavior` ⊇ `[.canJoinAllSpaces, .fullScreenAuxiliary]` | unit (inspect panel) | `…-only-testing:IsletTests/NotchPanelTests/testPanelConfiguration` | ❌ Wave 0 |
| ISL-07 | Idle pill is static (no animation driver/timer wired in Phase 1) | unit/structural | `…-only-testing:IsletTests/NotchPillViewTests/testNoAnimationState` | ❌ Wave 0 |
| ISL-01 (visual) | Pill visually hugs the physical notch (width, radius, position) | **manual** | Run app with DEBUG tint; eyeball over notch. Not automatable — pixel-over-hardware. | manual |
| ISL-02 (visual) | Stays above other windows & visible across Spaces | **manual** | Switch Spaces / open fullscreen app; confirm pill persists. | manual |
| ISL-06 (visual) | Plug/unplug external + clamshell: stays on built-in, hides in clamshell, recovers | **manual** | Connect monitor, change resolution, close lid; observe. Needs external monitor. | manual |
| ISL-02/D-07 (visual) | Never steals focus / blocks menu-bar & desktop clicks | **manual** | Click near notch; active app stays active; menu-bar items respond. | manual |

**To make geometry/display logic unit-testable:** extract the math into pure functions that take injected inputs (e.g. `notchFrame(screenFrame:auxLeftWidth:auxRightWidth:safeTop:)` and `selectTargetScreen(from: [ScreenInfo])` where `ScreenInfo` is a small struct of `{frame, safeTop, isBuiltin, hasNotch, uuid}`). This avoids depending on live `NSScreen` in tests. **Plan this seam in Wave 0 / first task.**

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests` (the unit suite — geometry, shape, display selection, panel config).
- **Per wave merge:** Full `xcodebuild test -scheme Islet -destination 'platform=macOS'`.
- **Phase gate:** Full unit suite green **plus** the manual visual checklist (pill-over-notch, Spaces, plug/unplug+clamshell, no-focus-steal) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `IsletTests` test target added to `project.yml` (+ `xcodegen generate`) — none exists today.
- [ ] `IsletTests/NotchGeometryTests.swift` — covers ISL-01 frame math (pure function).
- [ ] `IsletTests/NotchShapeTests.swift` — covers ISL-01 shape path.
- [ ] `IsletTests/DisplaySelectionTests.swift` — covers ISL-06 selection + hide-when-absent (mock `ScreenInfo`).
- [ ] `IsletTests/NotchPanelTests.swift` — covers ISL-02 panel configuration.
- [ ] `IsletTests/NotchPillViewTests.swift` — covers ISL-07 static + DEBUG/release fill.
- [ ] Source seam: extract geometry + display-selection into pure, injectable functions (no live `NSScreen` in tests).
- [ ] Manual-verification checklist captured in VALIDATION.md for the four visual criteria.

## Security Domain

> `security_enforcement` is not present in config.json (treated as enabled). This phase is a local UI overlay with **no** auth, network, persistence, secrets, or user input.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No protected resources |
| V5 Input Validation | no | Phase 1 takes no user/network input (pill is non-interactive, ignores mouse events) |
| V6 Cryptography | no | No crypto |

### Known Threat Patterns for a local AppKit overlay
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overlay obscures/clickjacks UI under it | Tampering/Elevation | `ignoresMouseEvents = true` (fully click-through in Phase 1) — clicks pass through to the real UI; pill blocks nothing. [D-07] |
| Focus theft / input redirection | Tampering | `.nonactivatingPanel` + `canBecomeKey/Main = false` — panel never takes focus or keyboard input. [D-07] |

No additional security work for this phase. (Notarization/hardened-runtime/sandbox posture were settled in Phase 0.)

## Sources

### Primary (HIGH confidence)
- **DynamicNotchKit** (MrKai77, MIT) — `Sources/DynamicNotchKit/Utility/DynamicNotchPanel.swift` (panel: styleMask `[.borderless, .nonactivatingPanel]`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .stationary]`, `backgroundColor = .clear`, `hasShadow = false`); `Sources/DynamicNotchKit/Utility/NSScreen+Extensions.swift` (`hasNotch`, `notchSize`, `notchFrame`, `menubarHeight`, `notchFrameWithMenubarAsBackup`); `Sources/DynamicNotchKit/DynamicNotch/DynamicNotch.swift` (screen-params observer, `initializeWindow`, `orderFrontRegardless`). [VERIFIED via raw.githubusercontent.com this session]
- **boring.notch / TheBoringNotch** (TheBoredTeam) — `boringNotch/components/Notch/BoringNotchWindow.swift` (`NSPanel` subclass: `collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]`, `level = .mainMenu + 3`, `canBecomeKey/Main = false`); `boringNotch/extensions/NSScreen+UUID.swift` (`displayUUID` via `CGDisplayCreateUUIDFromDisplayID`, UUID→screen cache rebuilt on `didChangeScreenParametersNotification`); `boringNotch/sizing/matters.swift` + `getClosedNotchSize` (notch width = `frame.width − auxLeft − auxRight + 4`, `safeAreaInsets.top > 0` has-notch test); `boringNotch/components/Notch/NotchShape.swift` (asymmetric `Shape`, default top=6/bottom=14); `boringNotch/boringNotchApp.swift` (`screenConfigurationDidChange`, `adjustWindowPosition`, UUID-based screen selection). [VERIFIED via raw.githubusercontent.com this session]
- **Project files** — `project.yml`, `Islet/AppDelegate.swift`, `Islet/IsletApp.swift` (existing patterns + build settings). [VERIFIED: read this session]
- `sw_vers` / `xcodebuild -version` / `swift --version` — build environment. [VERIFIED: run this session]

### Secondary (MEDIUM confidence)
- Apple Developer Documentation (JS-rendered; titles confirmed, body not scrapable this session): `nsscreen/safeareainsets`, `NSScreen/auxiliaryTopLeftArea-uglc`, `coregraphics/1454566-cgdisplayisbuiltin`, `nswindow/stylemask-swift.struct/nonactivatingpanel`. [CITED]
- fazm.ai "SwiftUI Floating Panel: NSPanel Patterns" + Itsuki Medium floating-panel articles — confirm the `.nonactivatingPanel` + `collectionBehavior` + `NSHostingView` + `orderFrontRegardless` recipe. [CITED, corroborates prior-art]
- philz.blog "The Curious Case of NSPanel's Nonactivating Style Mask Flag" — set `.nonactivatingPanel` at init, not after. [CITED]

### Tertiary (LOW confidence — flagged for on-device validation)
- macOS 26 "Tahoe" transparent/floating menu-bar behavior at the notch band (Apple Community / macmost / heise reports) — informs Pitfall 4 / Assumption A2 (window-level choice). Needs on-device confirmation.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — every API verified against two independent prior-art apps + the build environment; all below the 14.0 floor.
- Architecture (panel + geometry + screen recovery): **HIGH** — directly mirrors verified prior-art source; the UUID-persistence + screen-params pattern is the demonstrated solution to ISL-06.
- Pitfalls: **HIGH** for coordinate-flip, focus/click-through, wrong-display, multi-fire; **MEDIUM** for the macOS 26 menu-bar-level interaction (A2).
- Validation: **HIGH** — geometry/selection logic is cleanly unit-testable via a pure-function seam; visual criteria correctly identified as manual.

**Research date:** 2026-06-26
**Valid until:** ~2026-07-26 (stable APIs; re-check the window-level/menu-bar interaction after any macOS 26.x update, and re-confirm prior-art if you pin a library version).
