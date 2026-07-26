# Phase 66: Menübar-Overflow (Ice-Style MVP) - Research

**Researched:** 2026-07-27
**Domain:** macOS menu-bar item management via private/undocumented `NSStatusItem`-repositioning APIs, gated behind the Accessibility (`AXIsProcessTrusted`) permission
**Confidence:** MEDIUM-HIGH (mechanism itself verified directly against Ice's real source; genuine-space-reclamation claim and cross-macOS-version durability remain the phase's own mandated on-device spike questions)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — mirroring Ice's actual mechanic, where truly-hidden icons sit further left (off the visible strip) and always-visible icons stay to the right, closer to the system clock.
- **D-02:** The feature activates automatically as soon as Accessibility permission is granted — there is no separate Settings on/off toggle for the mechanism itself. This deliberately diverges from the v1.10 "new activities default OFF" convention (research Pitfall 5), because Menübar-Overflow is not an `IslandResolver`/notch activity — it's a standalone menu-bar mechanism, same category as Quick Notes (Phase 64 D-13, menu-bar-only, zero resolver participation).

#### Persistence
- **D-03:** The hidden/visible icon assignment persists across app relaunch — Islet remembers which other apps' icons were hidden (keyed by bundle identifier, mirroring Ice's own persistence approach) and restores that grouping the next time those icons are (re)created by their owning apps.

#### Permission-denied degradation (MENUBAR-04)
- **D-04:** If Accessibility permission is denied, the chevron does not appear in the menu bar at all — no broken/dead icon sitting there. Settings shows a clear "Permission required" state with a button that opens System Settings → Privacy & Security → Accessibility directly.

#### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons **inline in the menu bar itself** (Ice-style — they slide/appear directly in the strip), not in a separate dropdown/popover. Clicking again re-hides them.

### Claude's Discretion
- Exact persistence storage mechanism/format (UserDefaults keyed by bundle ID vs. plist, etc.) for D-03.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide transition (D-05).
- Exact one-time permission-explanation copy/wording (D-04/MENUBAR-04).
- Whether Islet's **own** status item(s) (the main status item, and the debug-only status item) can also be dragged behind the chevron, or are exempt from hiding — not discussed; default assumption is **exempt** (Islet's own icon stays always visible) unless the phase's own spike/research finds a strong reason otherwise.
- All technical mechanism details the ROADMAP's own Success Criteria #1 already assigns to an on-device spike (the private `NSStatusItem`-repositioning technique, sleep/wake and Dock-relaunch edge cases) — this is research/spike work, not a discussion decision.

### Deferred Ideas (OUT OF SCOPE)
- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md), reaffirmed here, not re-opened for discussion.
- **Hiding Islet's own status item(s) behind the chevron** — not decided; left to Claude's discretion, default assumption is that Islet's own icon(s) stay exempt/always-visible (see Claude's Discretion above).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MENUBAR-01 | A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons, mirroring Ice's MVP mechanic | Architecture Patterns (chevron NSStatusItem construction, reuses AppDelegate.swift statusItem precedent); MenuBarSection 3-tier model verified against Ice source |
| MENUBAR-02 | The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section | Don't Hand-Roll (Cmd-drag is native, zero app code); Architecture Patterns/EventManager.handleLeftMouseDragged precedent for the optional auto-reveal UX assist |
| MENUBAR-03 | Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden, not just repositioned off-screen while occupying visual space | Pitfall 2 (genuine space reclamation is the spike's central open question); Standard Stack (synthetic CGEvent move mechanism) |
| MENUBAR-04 | This feature requires a new Accessibility permission grant, requested with a clear one-time explanation — distinct from Islet's existing WeatherKit/EventKit/Bluetooth permission prompts | Architecture Patterns 2/3 (existing AXIsProcessTrusted + deep-link precedent in this codebase); Pitfall 4 (macOS 15+ modal-suppression behavior); Security Domain (V4 Access Control) |
</phase_requirements>

## Summary

Ice (github.com/jordanbaird/Ice, MIT) does **not** hide other apps' menu-bar icons via any Apple-documented API. It combines three private/undocumented layers: (1) `Bridging.swift` links directly against private `CGS*` SkyLight/CoreGraphics symbols (`CGSMainConnectionID`, `CGSGetScreenRectForWindow`, `CGSGetProcessMenuBarWindowList`, `CGSGetOnScreenWindowList`, etc.) declared via `@_silgen_name` — pure window/space *introspection* only, no window-server mutation calls exist in this file; (2) `MenuBarItemManager.swift` performs the actual *repositioning* by synthesizing `CGEvent` mouse-down/drag/up sequences ("scromble" events, its own internal term) that mimic a real user physically dragging the target app's status-item button to a destination X-coordinate, with a 5-attempt `wakeUpItem()` retry loop for unresponsive items; (3) `Permission.swift`/`PermissionsManager.swift` gate the whole `AppState.performSetup()` bootstrap behind `AXIsProcessTrustedWithOptions` (via the small `AXSwift` package), polled every 1 second so a mid-session grant activates the feature without requiring a relaunch — no Screen Recording permission is required for the MVP hide/show mechanic itself (Ice's Screen Recording use is for a *separate*, non-MVP live-icon-image preview feature, `isRequired: false`).

Critically, **this codebase already has three working, shipped instances of exactly the permission-check pattern this phase needs**: `OSDInterceptor.isAccessibilityTrusted`, `CapsLockMonitor.isAccessibilityTrusted`, and `DropInterceptTap`'s prompt-and-proceed call, all using the bare `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions()` public-but-unusual API — no `AXSwift` package needed. This contradicts CONTEXT.md's canonical_refs claim that "no existing Accessibility-permission code" exists in the codebase; the mechanism is precedented, only the drag-to-hide-and-reveal chevron behavior is genuinely novel. `CapsLockMonitor.start()` additionally has a directly reusable 5-second health-check-retry pattern for exactly the D-02 requirement ("activates automatically once permission granted, no relaunch").

The single largest open risk — and the reason the ROADMAP mandates an on-device spike before any production code — is **whether "hiding" genuinely reclaims screen space (SC#4) or merely occludes the icon behind the frontmost app's own menu**. Ice's `MenuBarItemManager` moves third-party items to X-coordinates to the *left* of its own hidden-section control item; it never calls anything equivalent to `NSStatusItem.isVisible = false` on items it does not own (it cannot — that property lives in the other process's `NSStatusItem` object, inaccessible cross-process). Real screen space is only reclaimed for Ice's *own* control items via the public `NSStatusItem.isVisible = false` property (confirmed in `ControlItem.swift`). For third-party items, apparent space reclamation depends on the frontmost app's own menu (File/Edit/View…) visually covering the repositioned icon — an occlusion effect, not a layout removal. Multiple recent Ice GitHub issues (#679 "Unable to display menu bar items" on macOS Tahoe, #331/#675 icons "disappear at random") corroborate that this technique is version-fragile in practice, reinforcing the project's own "isolate the fragile thing behind its own seam" precedent (`NowPlayingMonitor`, `MicMuteController`) and the mandated spike-first order.

**Primary recommendation:** Build the spike as an `XCTestCase`-based manual-spike file (mirroring `IsletTests/MeetingMonitorManualSpike.swift` verbatim — Cmd-U only, console-driven, always-green assertion, human checklist in the plan) that (a) links the same handful of private `CGS*` symbols Ice uses via `@_silgen_name` in a new `Bridging.swift`-style file, (b) drives one real third-party icon through a synthetic-drag move using the same `CGEvent` technique, and (c) has the human visually confirm on real hardware whether the vacated position is truly reclaimed or merely covered. Reuse the existing `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions()` pattern and `CapsLockMonitor`-style health-check timer for the permission plumbing — do not add the `AXSwift` package.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chevron `NSStatusItem` creation & click handling | App process (new isolated manager type, constructed from `AppDelegate`) | Settings UI (SwiftUI, status display only) | Follows `AppDelegate.swift:107`/`:490` `statusItem`/`debugStatusItem` construction precedent; per D-02 there is no Settings on/off toggle, so Settings never owns activation logic |
| Other apps' icon detection & private repositioning | New isolated manager type (e.g. `MenuBarOverflowController` + a `Bridging`-style private-API file) | macOS Window Server (out-of-process, private `CGS*` symbols) | Highest-novelty/zero-reuse code in the milestone; must get its own seam per the project's `NowPlayingMonitor`/`MicMuteController` precedent, validated by the mandated spike first |
| Accessibility permission check & one-time explanation | New isolated manager type, reusing `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions()` pattern already in `OSDInterceptor.swift`/`CapsLockMonitor.swift`/`DropInterceptTap.swift` | Settings UI (permission-status card, D-04) | Precedented mechanism, not genuinely new — only the explanation copy/UI instance is new (MENUBAR-04's "distinct from existing prompts") |
| Hidden/visible bundle-ID assignment persistence | New `UserDefaults`-backed store, namespaced like `ActivitySettings` | New isolated manager type (re-applies stored assignment whenever a matching bundle ID's status item reappears) | D-03; no existing subsystem to reuse — must be its own small store, and must actively re-apply on relaunch/Dock-launch since Ice itself does not solve this generically (see Pitfall 1 below) |
| Cmd-drag repositioning gesture | macOS system (native, zero app code) | New isolated manager type (optional: auto-reveal hidden section while a Cmd-drag is in progress, Ice `EventManager.handleLeftMouseDragged` precedent) | Cmd-dragging any `NSStatusItem` (including third-party ones) to reposition it is native macOS behavior that has existed since classic Mac OS X — Ice adds zero custom drag code for the move itself, only a drag-in-progress UX assist |

## Standard Stack

### Core

No new external package dependency is recommended. The mechanism this phase needs is a handful of private C symbols linked directly via Swift's `@_silgen_name`, exactly as Ice does — this is a private-API linkage pattern, not a library.

| Approach | Purpose | Why Standard (for this exact problem) |
|----------|---------|----------------------------------------|
| `@_silgen_name`-declared private `CGS*` functions (own `Bridging.swift`-style file) | Query window list / window frame / space for other apps' menu-bar item windows | `[VERIFIED: github.com/jordanbaird/Ice, direct source read]` — this is what Ice itself does; no public API exposes this |
| Synthetic `CGEvent` mouse-down/dragged/up sequences (own file, mirroring `MenuBarItemManager.move(item:to:)`) | Physically reposition another app's `NSStatusItem` by simulating a real drag | `[VERIFIED: github.com/jordanbaird/Ice, direct source read]` — no public API moves another process's status item |
| `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()` (public `ApplicationServices`/`HIServices` API, no import needed beyond `AppKit`) | Check/request Accessibility trust | `[VERIFIED: codebase]` — already used in `Islet/Notch/OSDInterceptor.swift:46`, `Islet/Notch/CapsLockMonitor.swift:34`, `Islet/Notch/DropInterceptTap.swift:40` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `NSStatusBar.system.statusItem(withLength:)` | AppKit (built-in) | Construct the chevron's own `NSStatusItem` | Same call already used at `AppDelegate.swift:107`/`:490` |
| `UserDefaults` | Foundation (built-in) | Persist hidden/visible bundle-ID assignments (D-03) | Namespaced keys, mirroring `ActivitySettings`'s `@AppStorage` style but keyed by arbitrary bundle IDs |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw `@_silgen_name` private symbols | `AXSwift` package (Ice's dependency for the *permission* wrapper only, not the CGS mechanism) | `AXSwift`'s `checkIsProcessTrusted(prompt:)` is a one-line wrapper around `AXIsProcessTrustedWithOptions` — adds a dependency for something the codebase already does inline (ladder rung 2: reuse in-codebase pattern instead) |
| Ice's synthetic-drag `CGEvent` technique | Accessibility API (`AXUIElement`) to directly set another process's window position | `[ASSUMED]` — Ice's own `Bridging.swift` contains zero `AXUIElement` calls despite requiring Accessibility trust; Accessibility trust is required to *create* certain `CGEventTap`/`CGEvent.tapCreate` calls and to read `CGWindowListCopyWindowInfo` process names, not to directly manipulate other apps' `AXUIElement` positions for status items — this needs on-device confirmation during the spike, since it changes which private API surface the spike must validate |

**Installation:** No package manager changes required — no `npm install`/SPM package additions. New Swift source files only.

**Version verification:** N/A — no versioned package is being added. If a future change decides to add `AXSwift` after all, verify via `swift package resolve` against `https://github.com/tmandry/AXSwift` (last known state: small, single-purpose wrapper, MIT).

## Package Legitimacy Audit

Not applicable — this phase adds no new external package dependency (see Standard Stack: Core, above). The private-API mechanism is implemented as first-party Swift source declaring `@_silgen_name` symbols, following the codebase's own existing `Bridging`-free-but-precedented pattern (e.g. `BrightnessReader`'s private `DisplayServices` framework `dlopen`, per `OSDInterceptor.swift`'s own comment referencing it) — not a downloaded package.

**Packages removed due to slopcheck verdict:** none (no packages proposed).
**Packages flagged as suspicious:** none.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  macOS Window Server (out-of-process, other apps' NSStatusItems)     │
│                                                                        │
│   [3rd-party icon A]  [3rd-party icon B]  [Islet's own icons]         │
└───────────────▲────────────────────────────────────────▲─────────────┘
                 │ private CGS* introspection            │ owned, public
                 │ (read window list/frame)               │ NSStatusItem API
                 │ synthetic CGEvent drag                 │
┌────────────────┴────────────────────────────────────────┴────────────┐
│  Islet app process                                                    │
│                                                                        │
│  AppDelegate ──creates──► ChevronControlItem (NSStatusItem, leftmost, │
│      │                     D-01) ──click──► reveal/hide toggle (D-05) │
│      │                                                                 │
│      ├──gates on──► AccessibilityPermissionCheck                      │
│      │              (AXIsProcessTrusted / WithOptions — reuses         │
│      │               OSDInterceptor/CapsLockMonitor pattern)          │
│      │              ──denied──► chevron never created (D-04);         │
│      │                          Settings shows "Permission required"  │
│      │              ──granted mid-session──► 5s health-check timer    │
│      │                (CapsLockMonitor.start() precedent) activates   │
│      │                the feature with no relaunch (D-02)             │
│      │                                                                 │
│      └──owns──► MenuBarOverflowController (new, isolated seam)        │
│                    ├─ detects other apps' status-item windows          │
│                    │  (private CGS* window-list read)                 │
│                    ├─ Cmd-drag across chevron ──native macOS──►        │
│                    │  (zero app code for the drag itself; optional    │
│                    │   UX assist: auto-reveal hidden section while    │
│                    │   dragging, Ice EventManager precedent)          │
│                    ├─ on drop: repositions target item via synthetic  │
│                    │  CGEvent sequence past the chevron (private,     │
│                    │  spike-validated mechanism)                       │
│                    ├─ persists bundle-ID → hidden/visible assignment  │
│                    │  (new UserDefaults store, D-03)                  │
│                    └─ re-applies assignment whenever NSWorkspace      │
│                       reports a matching bundle ID's app (re)launched │
│                       (Pitfall 1 — required because Ice itself does   │
│                       not solve this generically)                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
Islet/Notch/  (or a new Islet/MenuBar/ group, mirroring Ice's own top-level split)
├── MenuBarOverflowBridging.swift    # private CGS* @_silgen_name declarations (introspection only)
├── MenuBarOverflowController.swift  # isolated manager: detect/move/persist, mirrors NowPlayingMonitor/MicMuteController seam discipline
├── MenuBarOverflowStore.swift       # UserDefaults-backed bundle-ID → hidden/visible store (D-03)
└── (chevron NSStatusItem construction lives in AppDelegate.swift, alongside statusItem/debugStatusItem)

IsletTests/
└── MenuBarOverflowManualSpike.swift # SC#1's mandated spike — mirrors MeetingMonitorManualSpike.swift exactly
```

### Pattern 1: Manual on-device spike as an XCTestCase (this project's established precedent)

**What:** A single `XCTestCase` method, run via Xcode Cmd-U only (never `xcodebuild test`, which hangs headless in this project per the documented `xcodebuild-test-headless-hang` precedent), that exercises the real mechanism against real hardware and prints console diagnostics for a human to read against a written checklist. The assertion is always `XCTAssertTrue(true)` — pass/fail is human-judged from the console output plus the plan's on-device checklist, not from the test framework.

**When to use:** Exactly SC#1's mandate — validating a private/undocumented mechanism (permission-denied, sleep/wake, Dock-relaunch cases) before committing to a production implementation.

**Example (precedent, not this phase's file):**
```swift
// Source: IsletTests/MeetingMonitorManualSpike.swift (this codebase, Phase 63)
final class MeetingMonitorManualSpike: XCTestCase {
    @MainActor
    func testManualDetectionHeuristic() {
        print("[MeetingSpike] about to read+toggle system input mute — NO TCC prompt expected")
        // ... exercises the real mechanism ...
        RunLoop.current.run(until: Date().addingTimeInterval(180))
        XCTAssertTrue(true, "manual spike — see console output and plan Task 2 for pass/fail criteria")
    }
}
```
The Phase 66 spike should follow this shape 1:1, substituting the CGS-symbol window-list read + synthetic-drag move for the mic-mute read/toggle, and covering permission-denied / sleep-wake / Dock-relaunch as separate checklist steps within the same run.

### Pattern 2: Accessibility-gated feature bootstrap with mid-session activation (existing codebase precedent)

**What:** Gate a feature's `start()` behind `AXIsProcessTrusted()`; if untrusted, arm a repeating timer instead of giving up, so a grant made later in System Settings activates the feature without an app relaunch.

**When to use:** Directly satisfies D-02 ("activates automatically once Accessibility permission is granted — no separate toggle").

**Example:**
```swift
// Source: Islet/Notch/CapsLockMonitor.swift (this codebase, Phase 60)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

func start() {
    guard monitorToken == nil else { return }
    guard Self.isAccessibilityTrusted else {
        armHealthCheck()   // 5s retry, per line ~44-52 comment: "a single AXIsProcessTrusted()
        return             // check at toggle-time can still read false even when System
    }                       // Settings already shows the grant checked"
    install()
}
```

### Pattern 3: Deep-link to System Settings' Accessibility pane on denial (existing codebase precedent, directly satisfies D-04)

**What:** `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`

**When to use:** Exactly D-04's "button that opens System Settings → Privacy & Security → Accessibility directly." Already used verbatim in `Islet/SettingsView.swift:760` and `:790` for OSD suppression and Caps Lock.

### Anti-Patterns to Avoid

- **Adding the `AXSwift` package:** Ice uses it only as a thin wrapper around `AXIsProcessTrustedWithOptions`; this codebase already calls the raw API directly in three places. Adding a dependency for something already precedented in-repo is unnecessary (ladder rung 2).
- **Force-prompting Accessibility on every check:** `CapsLockMonitor`/`OSDInterceptor` deliberately never call the `prompt: true` variant from a passive health-check — only `DropInterceptTap` calls it once, at explicit user-initiated `start()`. Accessibility has no re-request API; repeatedly calling the prompt variant does not re-show a dialog once denied and is functionally a no-op after the first call, so gate the prompt call behind a genuine user action (first grant of the feature), not a timer.
- **Treating "item moved past the control item" as equivalent to "screen space reclaimed":** Ice's own mechanism does NOT call any AppKit removal API on third-party items (it cannot — no cross-process access to another app's `NSStatusItem` object). Do not assume SC#4 is satisfied just because Ice's `move()` succeeds; this must be visually confirmed on real hardware during the spike (see Pitfall 3).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cmd-drag repositioning of a menu-bar icon | Custom `NSDraggingSession`/drop-target code for the drag gesture itself | Nothing — it's free, native macOS behavior for any `NSStatusItem`, including third-party ones (verified: Ice's `EventManager.swift` contains no custom drag-move code, only a `.leftMouseDragged` *observer* for a UX assist) | The OS already handles Cmd-drag repositioning; building custom drag machinery here would duplicate free system behavior and risks fighting the OS's own drag session |
| Accessibility permission check/request plumbing | A new `PermissionsManager`-style abstraction (Ice's own class) | The codebase's existing bare `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions()` + health-check-timer pattern (`OSDInterceptor`, `CapsLockMonitor`) | Three working precedents already exist; a fourth near-identical implementation with a different shape (Ice's `ObservableObject` class) would fragment the pattern for no benefit |
| Deep-linking to the Accessibility settings pane | A generic "open Privacy & Security" helper | The exact `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` URL string, copy-pasted from `SettingsView.swift:760`/`:790` | Already proven working in this exact app on this exact deployment target |

**Key insight:** The only genuinely novel code in this phase is the private-API window detection + synthetic-drag repositioning mechanism (Bridging + Controller). Everything else — the chevron `NSStatusItem`, the Accessibility check, the deep link, the Cmd-drag gesture itself — has direct, working precedent either in this codebase or as native, code-free macOS behavior. Plans should be scoped accordingly: most of the phase's task budget belongs to the spike and the isolated mechanism seam, not to permission plumbing or UI chrome.

## Common Pitfalls

### Pitfall 1: Hidden-icon assignment does not survive an app relaunch/Dock-relaunch automatically — directly affects D-03

**What goes wrong:** After the user hides another app's icon, quitting and relaunching that *other* app (or a Dock-relaunch) creates a brand-new `NSStatusItem` in that process, at a position macOS itself decides (or wherever the OS's own `NSStatusItem.autosaveName`-keyed `UserDefaults` position remembers, *if* that specific third-party app happens to set an autosave name — most apps that don't opt into this land in a default/visible position).

**Why it happens:** `[VERIFIED: github.com/jordanbaird/Ice, MenuBarItemManager.swift]` — Ice's own `cacheItemsIfNeeded()` (triggered on a 5s timer and on every `NSWorkspace.shared.publisher(for: \.runningApplications)` change) recomputes section membership *purely from each item's current physical X-position* relative to the control items. No persisted "these bundle IDs are hidden" list drives an active re-hide of a freshly-recreated item was found anywhere in `MenuBarItemManager.swift`, `MenuBarManager.swift`, or the Settings managers reviewed. Islet's own persistence (D-03, keyed by bundle identifier) is therefore not just "remember a preference" — it must **actively re-invoke the move mechanism** every time a bundle ID with a stored "hidden" assignment reappears in `NSWorkspace.shared.runningApplications`, exactly as the CONTEXT's own discretion note anticipated.

**How to avoid:** Subscribe to `NSWorkspace.shared.publisher(for: \.runningApplications)` (or `NSWorkspace.didLaunchApplicationNotification`), diff against the stored hidden-bundle-ID set, and re-run the move-to-hidden sequence for any newly-appeared status item whose owning bundle ID is in that set. This must be idempotent and tolerant of the item not being immediately available (mirrors Ice's own retry/wake-up loop).

**Warning signs:** A previously-hidden icon reappearing in the visible strip every time its owning app relaunches, requiring the user to re-hide it manually — this would silently violate D-03.

### Pitfall 2: "Genuine space reclamation" (SC#4) may not hold for third-party items — this IS the spike's central question

**What goes wrong:** Building the production UI/UX around an assumption that hiding an icon shrinks the visible menu-bar strip, when the real mechanism only occludes the icon behind the frontmost app's own menu titles.

**Why it happens:** `[VERIFIED: github.com/jordanbaird/Ice, ControlItem.swift:556-560]` — the only confirmed real AppKit-level space reclamation (`statusItem.isVisible = false`, which macOS documents as removing the item from layout) applies to Ice's *own* control items, which Ice owns as first-class `NSStatusItem` Swift objects. Third-party items are only ever *repositioned*, never had `isVisible` toggled by Ice, because Ice has no in-process object reference to another app's `NSStatusItem`.

**How to avoid:** The mandated spike (SC#1) must specifically observe, on real hardware, whether other visible icons shift/reflow to fill the vacated space when an item is moved past the chevron, or whether the vacated position is simply covered by the frontmost app's menu (an occlusion, not a reclamation). If it is occlusion-only, SC#4 as literally worded ("real screen space reclaimed") may need to be revisited with the user before the production mechanism is built — this is exactly the kind of finding the spike-first ROADMAP ordering exists to surface early.

**Warning signs:** Icons that were "hidden" reappearing/flickering when switching frontmost app (since the occluding menu changes width per-app), or the visible strip's total width not changing after a hide.

### Pitfall 3: The technique is empirically fragile across macOS versions

**What goes wrong:** A mechanism that works today silently breaks after a macOS point release.

**Why it happens:** `[CITED: github.com/jordanbaird/Ice/issues]` — multiple open issues report exactly this: #679 "Unable to display menu bar items on macOS Tahoe," #331/#675 hidden/always-hidden icons "disappear at random." These are private, undocumented SkyLight/CoreGraphics symbols with no API stability guarantee.

**How to avoid:** Isolate the mechanism behind its own seam (per this project's `NowPlayingMonitor`/`MicMuteController` precedent) so a future OS-version break is a contained, single-file fix rather than a scattered regression. Document the risk explicitly in code comments, mirroring how `OSDInterceptor.swift` documents its own tap-mode fallback discipline.

**Warning signs:** Items failing to move (the spike's retry/wake-up loop exhausting its attempts), or a `CGEvent.tapCreate`/window-list read silently returning empty/nil.

### Pitfall 4: `AXIsProcessTrustedWithOptions`'s prompt no longer shows a modal dialog on macOS Sequoia (15)/Tahoe (26)

**What goes wrong:** Code (or UX copy) that assumes calling the "with options, prompt: true" variant pops a system dialog the user can approve inline.

**Why it happens:** `[CITED: community reports, MEDIUM confidence, matches this project's own deployment target of macOS 15.0+]` — on macOS Sequoia and Tahoe, this call instead silently adds the app to the System Settings → Privacy & Security → Accessibility list (unchecked) and returns immediately; there is no modal for the user to approve in-place. The user must be sent to System Settings and manually toggle it on.

**How to avoid:** This validates D-04's design exactly as locked — a "Permission required" state with a button that opens System Settings directly is not just good UX, it is now the *only* viable flow on this project's deployment target. Do not build any UI copy implying an in-app approval dialog will appear.

**Warning signs:** A permission-explanation popover that says "click Allow" with no actual system dialog appearing.

### Pitfall 5: `xcodebuild test` hangs headless in this repo — do not gate the spike or CI on it

**What goes wrong:** Writing the spike as a normal automated test expected to pass in a headless/CI run.

**Why it happens:** `[VERIFIED: codebase — .planning/PROJECT.md, project memory "xcodebuild-test-headless-hang"]` — this project's full test host already hangs headless due to a pre-existing TCC-authorization wait (Bluetooth). Adding a second TCC-gated permission (Accessibility) to the same test target compounds this risk.

**How to avoid:** Follow the `MeetingMonitorManualSpike.swift` precedent exactly — a single manual-only `XCTestCase`, explicitly commented "DO NOT RUN VIA `xcodebuild test`", run via Cmd-U for that one method only.

## Code Examples

### Reading the actual private-symbol declaration style used for window introspection

```swift
// Source: github.com/jordanbaird/Ice, Ice/Bridging/Shims/Private.swift (direct source read)
import CoreGraphics

typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ rect: inout CGRect
) -> CGError
```

### Existing codebase pattern for the Accessibility permission gate (reuse this shape)

```swift
// Source: Islet/Notch/CapsLockMonitor.swift (this codebase)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

func start() {
    guard monitorToken == nil else { return }
    guard Self.isAccessibilityTrusted else {
        armHealthCheck()
        return
    }
    install()
}
```

### Existing codebase pattern for the one-time explanation + deep link (reuse this shape, new copy per MENUBAR-04)

```swift
// Source: Islet/SettingsView.swift:744-768 (osdPermissionExplanationView, this codebase)
Button("Open System Settings") {
    NSWorkspace.shared.open(URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    showOSDPermissionExplanation = false
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `AXIsProcessTrustedWithOptions(prompt: true)` shows a modal system dialog immediately | Same call adds the app to the Accessibility list but shows no modal; user must open System Settings manually | `[CITED, MEDIUM confidence]` macOS Sequoia (15) onward, confirmed persisting into Tahoe (26) | Directly validates D-04's "button that opens System Settings" as necessary, not just polish |

**Deprecated/outdated:** None specific to this mechanism found beyond the above — the private `CGS*` API surface itself has no formal deprecation notices (it is undocumented, not deprecated-documented).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Ice's synthetic-`CGEvent`-drag technique (not `AXUIElement` position-setting) is the actual mechanism by which items are repositioned, and Accessibility trust is required to create the relevant `CGEventTap`/read process window info rather than to manipulate another app's `AXUIElement` directly | Standard Stack (Alternatives Considered), Architecture Patterns | If wrong, the spike would need to validate a materially different private API surface (`AXUIElement` position-setting) than what this research documents; would require re-reading Ice's `Bridging.swift` `AXUIElement`-adjacent code more deeply (none was found in the file, but the possibility of a second undiscovered file using it was not exhaustively ruled out) |
| A2 | `AXIsProcessTrustedWithOptions`'s modal-suppression behavior on macOS 15+/26 (Pitfall 4) generalizes to this project's actual target hardware/OS build, not just the community reports found | Common Pitfalls (Pitfall 4) | If wrong (i.e., a modal still appears on this project's specific macOS build), the one-time explanation copy could reference System Settings unnecessarily verbosely, or miss an opportunity to rely on the in-app dialog — low-severity UX-only risk, easily corrected during the phase's own UAT |
| A3 | The mandated spike's private-symbol/synthetic-drag mechanism will work unmodified on Apple Silicon under this project's actual macOS 15.0+ deployment target — Ice's own GitHub issues (#679) report breakage specifically on Tahoe (26), the newest OS version, so cross-version durability is genuinely unverified for this project's own hardware | Summary, Pitfall 3 | This is precisely why the ROADMAP mandates the spike before any production commitment — if the spike fails, the phase's entire approach needs re-scoping (possibly to a narrower/differently-implemented mechanism), which is the spike's whole purpose to surface early |

**If this table is empty:** N/A — see entries above; none of these need to block planning, since the phase's own mandated SC#1 spike is the designed mechanism for resolving A1 and A3 empirically before production code is written.

## Open Questions

1. **Does the vacated position genuinely reclaim visible menu-bar space, or only get occluded by the frontmost app's menu (Pitfall 2)?**
   - What we know: Ice's own source contains no cross-process AppKit removal call for third-party items; only its own control items get `isVisible = false`.
   - What's unclear: The actual visual behavior on real hardware — this project's own screen geometry, resolution, and typical icon count may make the occlusion effect visually indistinguishable from "genuine" reclamation, or may not.
   - Recommendation: This is exactly what the ROADMAP's mandated spike (SC#1) must observe and report before the production mechanism is built; the planner should make this the spike's primary acceptance criterion, not a secondary check.

2. **Does the codebase's existing `AXIsProcessTrusted()`-gated pattern extend cleanly to the private `CGEventTap`/window-list-read calls this phase needs, or does the window-list read require a *different* permission (e.g., Screen Recording, per Ice's separate `ScreenRecordingPermission` for its live-icon-preview feature)?**
   - What we know: Ice requires Accessibility as `isRequired: true` for its MVP hide/show mechanic and Screen Recording only as `isRequired: false` for a separate (out-of-scope-for-this-MVP) live-image-preview feature.
   - What's unclear: Whether `Bridging.getWindowList`/`CGSGetProcessMenuBarWindowList`-style calls specifically require Accessibility trust to return non-empty results for *other processes'* windows, independent of the drag-move mechanism.
   - Recommendation: The spike should explicitly test window-list reads with Accessibility denied (per the ROADMAP's own "including the Accessibility-permission-denied... case" requirement) to confirm this returns empty/fails gracefully rather than partially working.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build/spike | ✓ | 26.6 (research machine) | — |
| Swift toolchain | Build/spike | ✓ | 6.3.3 | — |
| macOS (research machine) | N/A — not the deployment target | ✓ | 27.0 (beta) | Deployment target remains 15.0+ per project; on-device spike/UAT must run on the user's actual target hardware, not necessarily this research machine |
| Accessibility TCC permission | Spike, production feature | Unknown until on-device run | — | None — this permission is the feature's core dependency; SC#1 explicitly requires testing the denied case too |

**Missing dependencies with no fallback:** None identified — this is a code-only phase against an already-configured, non-sandboxed Xcode project (`ENABLE_APP_SANDBOX = NO` confirmed in `Islet.xcodeproj/project.pbxproj`).

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing project standard, `IsletTests/` target) |
| Config file | `Islet.xcodeproj` scheme `Islet` — no separate `.xctestplan` found |
| Quick run command | Manual Xcode Cmd-U for the single new spike test method — `xcodebuild test` hangs headless in this repo (documented precedent) |
| Full suite command | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` (build-only; full `xcodebuild test` remains unusable headless per project memory) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MENUBAR-01 | Chevron appears, separates visible/hidden sections | manual on-device UAT | Cmd-U spike + visual check | ❌ Wave 0 — new `MenuBarOverflowManualSpike.swift` |
| MENUBAR-02 | Cmd-drag another app's icon across the chevron moves it to hidden | manual on-device UAT (native OS gesture, cannot be scripted via XCTest) | Cmd-U spike console log + human drag test | ❌ Wave 0 |
| MENUBAR-03 | Click chevron reveals/hides; hidden icons genuinely absent | manual on-device UAT (visual space-reclamation judgment, Pitfall 2) | Cmd-U spike + human visual confirmation | ❌ Wave 0 |
| MENUBAR-04 | Accessibility permission requested with one-time explanation, distinct copy, denies gracefully | unit (pure permission-state mapping, mirrors `PermissionStatus.swift`'s existing pure-function pattern) + manual UAT for the actual system dialog/deep-link behavior | `xcodebuild test`-safe pure functions only; system-dialog behavior itself is manual-only | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Manual Cmd-U spike run for mechanism-touching tasks; standard `xcodebuild build` for others
- **Per wave merge:** Full `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **Phase gate:** On-device UAT covering SC#1-#5 (per the ROADMAP's own explicit spike/UAT mandate) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/MenuBarOverflowManualSpike.swift` — covers MENUBAR-01/02/03, mirrors `MeetingMonitorManualSpike.swift` exactly (manual-only, Cmd-U, always-green assertion, human checklist referenced from the plan)
- [ ] Pure unit tests for the Accessibility permission 3-state mapping if a new mapping function is introduced, mirroring `Islet/PermissionStatus.swift`'s existing pure-function style (only if MENUBAR-04's status card reuses/extends that rollup; otherwise `AXIsProcessTrusted()` is called directly like `OSDInterceptor`/`CapsLockMonitor` and needs no new mapping function)

*(No existing test file covers any part of this phase — all listed items are net-new.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Single-user local macOS app, no auth surface touched by this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes (OS-level, not app-level) | Gate all mechanism activation behind `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions()` — never attempt the private mechanism while untrusted (D-12 precedent in `DropInterceptTap.swift`: "a nil tap is a silent no-op, no crash, no dialog") |
| V5 Input Validation | Partial | Bundle identifiers read from `NSWorkspace.runningApplications`/window info are OS-supplied, not user-supplied text — no injection surface, but the persisted store should still guard against malformed/empty bundle-ID strings before using them as `UserDefaults` keys |
| V6 Cryptography | No | Hidden/visible assignment (a list of bundle identifiers) is not sensitive data — no encryption required (mirrors NOTES-03's precedent decision that not everything needs Clipboard-History-style AES-GCM parity) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Synthetic `CGEvent` injection is itself a powerful capability (any process with Accessibility trust can synthesize input events system-wide) | Elevation of Privilege (inherent to the OS permission, not introduced by this app) | Scope all synthetic-event generation strictly to the menu-bar item move sequence; never build a generalized "send arbitrary events" helper. Mirrors this project's existing discipline in `OSDInterceptor`/`DropInterceptTap`, which scope their `CGEventTap` usage narrowly to their one documented purpose |
| A failed/partial move leaving another app's icon in an indeterminate position | Tampering (unintended side effect on a third-party app's UI state) | Follow Ice's own retry-with-timeout discipline (`wakeUpItem()`, bounded attempts) and fail closed — leave the item where it is rather than looping indefinitely or leaving it in a half-moved state |

## Sources

### Primary (HIGH confidence)
- github.com/jordanbaird/Ice — `Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift` (direct raw-file fetch and read, 1671 lines, `move()`/`cacheItemsIfNeeded()`/`enforceControlItemOrder()` verified)
- github.com/jordanbaird/Ice — `Ice/Bridging/Bridging.swift` + `Ice/Bridging/Shims/Private.swift` (direct raw-file fetch and read, `@_silgen_name` CGS declarations verified)
- github.com/jordanbaird/Ice — `Ice/Permissions/Permission.swift` + `PermissionsManager.swift` (direct raw-file fetch and read, `AccessibilityPermission`/`ScreenRecordingPermission` verified)
- github.com/jordanbaird/Ice — `Ice/MenuBar/ControlItem/ControlItem.swift`, `Ice/MenuBar/MenuBarSection.swift`, `Ice/Events/EventManager.swift`, `Ice/Main/AppState.swift`, `Ice/Main/AppDelegate.swift` (direct raw-file fetch and grep/read)
- This codebase — `Islet/Notch/OSDInterceptor.swift`, `Islet/Notch/CapsLockMonitor.swift`, `Islet/Notch/DropInterceptTap.swift`, `Islet/SettingsView.swift`, `Islet/AppDelegate.swift`, `Islet/PermissionStatus.swift`, `Islet/Notch/MicMuteController.swift`, `IsletTests/MeetingMonitorManualSpike.swift` (direct read)

### Secondary (MEDIUM confidence)
- Community reports on `AXIsProcessTrustedWithOptions` modal-suppression behavior on macOS Sequoia/Tahoe (multiple developer-forum threads, cross-referenced against this project's own macOS 15.0+ deployment target)
- github.com/jordanbaird/Ice/issues #679, #331, #675 — cross-macOS-version fragility reports

### Tertiary (LOW confidence)
- None used as load-bearing claims in this document.

## Metadata

**Confidence breakdown:**
- Standard stack (private-API mechanism identification): HIGH — verified directly against Ice's real, current source, not description-from-memory
- Architecture (permission gating, persistence gap, chevron construction): HIGH for the codebase-precedented parts (permission plumbing, deep link), MEDIUM for the persistence-reapplication design (Pitfall 1 — inferred from absence of evidence in Ice's source, not a positive confirmation)
- Pitfalls (space-reclamation question, cross-version fragility, modal-suppression on macOS 15+): MEDIUM — grounded in source review and community reports, but the phase's own mandated spike is explicitly the mechanism for resolving the highest-stakes one (Pitfall 2) with certainty

**Research date:** 2026-07-27
**Valid until:** ~14 days — this domain depends on undocumented private APIs and a specific macOS version's TCC prompt behavior, both of which can change with any macOS point release; re-verify against Ice's source and the actual macOS build on the target hardware if planning is delayed
