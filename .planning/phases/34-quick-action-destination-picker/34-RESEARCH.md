# Phase 34: Quick Action Destination Picker - Research

**Researched:** 2026-07-15
**Domain:** AppKit sharing services (`NSSharingService`) from a non-key `NSPanel`; SwiftUI presentation-state integration in Islet's existing `IslandResolver`/`NotchWindowController` architecture
**Confidence:** HIGH (core spike question — verified against a shipping app with an architecturally identical non-key `NSPanel`, source-read directly, not just claims)

## Summary

The phase's one genuine unknown — whether `NSSharingService(named:).perform(withItems:)` for AirDrop and Mail compose works from Islet's permanently non-key `NotchPanel` — has a strong, directly-verified answer: **yes, it works without any key-window trick.** `TheBoredTeam/boring.notch`, an open-source notch-overlay app with an *architecturally identical* window (`.borderless, .nonactivatingPanel`, `canBecomeKey` hard-overridden to `false`, `LSUIElement = YES`, no Dock icon), calls `NSSharingService(named: .sendViaAirDrop)` / `.composeEmail` and `svc.perform(withItems:)` directly from that panel with **zero** `makeKey()`, `NSApp.activate()`, or window-activation code anywhere near the sharing call sites (confirmed by reading `QuickShareService.swift` and `SharingStateManager.swift` from its actual source tree via `gh api`). The only activation/key-window calls in that codebase are for its *separate* real Settings/Onboarding windows, never for sharing.

This means D-08's "narrowly-scoped key-window exception" is very likely **not needed at all**. The recommended plan: implement the picker calling `perform(withItems:)` directly with no panel changes, verify on Islet's own dev machine (the phase's required spike), and only reach for D-08's momentary-key fallback if the on-device spike proves the direct call silently no-ops (which the evidence above suggests is unlikely, but Islet's own `NotchPanel` differs from `BoringNotchWindow` in one respect worth spiking anyway — see Pitfall 1).

The exact `NSSharingService.Name` constants are `.sendViaAirDrop` and `.composeEmail` (confirmed both via the Apple AppKit SDK header and via boring.notch's live usage). Mail attachment support is confirmed Mail.app-specific in both Islet's own prior research and independent community reports (a Thunderbird bug report documents the exact same non-Mail-client `mailto:`-without-attachment degradation) — this is already correctly captured in Islet's REQUIREMENTS.md and needs no further hedging.

**Primary recommendation:** Implement AirDrop/Mail via direct `NSSharingService(named:).perform(withItems:)` calls with NO panel key-state changes, gated behind a completion delegate (`NSSharingServiceDelegate`) that drives the pending-drop state's dismissal — mirroring boring.notch's `SharingLifecycleDelegate` pattern (delegate callback + a short timeout fallback, itself directly comparable to this project's own Phase 21 drag-pin safety-net precedent). Spike this exact code path on-device first; keep D-08's momentary-key trick written but uncommitted as the documented fallback.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Picker presentation (3 buttons + file preview) | Frontend (SwiftUI, `NotchPillView`) | — | Pure view, follows existing per-presentation view pattern (`trayFullView`, `weatherFullContent`) |
| Picker precedence / lifecycle state | App logic (`IslandResolver`, pure) | Controller (`NotchWindowController`) | `IslandResolver.resolve()` is the single pure arbiter (D-04/D-05 ride existing rules); the controller owns the actual pending-drop mutable state and timers, mirroring `TransientQueue`/`beginShelfItemDrag` split |
| "Drop" destination file copy-in | Data/IO (`ShelfCoordinator`/`ShelfFileStore`) | — | Reused verbatim — `makeSessionCopy(of:id:)` + `append(_:)` already exist and are already called at the exact site this phase modifies |
| AirDrop/Mail invocation | OS integration (`NSSharingService`, AppKit) | — | Thin, isolated seam per this project's own "isolate the fragile/uncertain thing" convention (mirrors `NowPlayingMonitor`) — one new small type, not spread through the picker view |
| Sharing completion / pending-state cleanup | Controller (`NotchWindowController`) via delegate callback | — | `NSSharingServiceDelegate.didShareItems`/`didFailToShareItems` must clear the pending-drop state; needs a timeout fallback (see Code Examples) since delegate callbacks are not 100% guaranteed to fire promptly |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit `NSSharingService` | Ships with macOS SDK (10.8+, stable API) | AirDrop + Mail-compose-with-attachment invocation | The only public API for this; no third-party alternative exists or is warranted (CLAUDE.md's own "no unnecessary complexity" + this project's existing "use Apple frameworks directly" convention for IOKit/IOBluetooth applies identically here) |
| SwiftUI (existing) | Ships with macOS SDK | Picker view (3 buttons + preview) | Matches every other presentation in `NotchPillView.swift` |

No new third-party packages are needed for this phase — this is 100% Apple-framework surface, consistent with the project's existing "no third-party Bluetooth/power library" precedent in CLAUDE.md's Technology Stack section.

### Supporting
None beyond what's already in the project (`ShelfCoordinator`, `ShelfFileStore`, `IslandResolver`).

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct `NSSharingService(named:).perform(withItems:)` | `NSSharingServicePicker` (the generic system share menu) | Already ruled out in `.planning/REQUIREMENTS.md` Out of Scope — the picker itself is a system-drawn popover that (per boring.notch's own usage, which anchors it `relativeTo:of:`) wants a real anchor view; the 3 fixed buttons this phase specifies don't need the system's own service-discovery UI at all, so the simpler direct-perform call is strictly the right fit, not just the risk-averse one |
| Delegate + timeout-fallback pending-state cleanup | Blocking/synchronous wait for share completion | `perform(withItems:)` is asynchronous and shows its own OS-level UI (an AirDrop device-picker window or a Mail compose window) that this app cannot and should not try to control synchronously — must be event-driven |

**Version verification:** `NSSharingService` is not a package — no `npm view`/`pip index` equivalent applies. Verified as current, non-deprecated API via the live Apple Developer Documentation pages (`developer.apple.com/documentation/appkit/nssharingservice`, `.../name/sendviaairdrop`, `.../name/1402632-composeemail`), all reachable and un-flagged as deprecated as of this research date.

## Package Legitimacy Audit

Not applicable — this phase installs no external packages (npm/pip/cargo or Swift Package Manager). All new code uses AppKit/SwiftUI already linked into the project.

## Architecture Patterns

### System Architecture Diagram

```
File dropped on notch (any tab)
        │
        ▼
NotchWindowController.handleDragApproachEnd()   [existing, ~line 931]
        │  today: unconditionally copies file(s) in + shelfCoordinator.append()
        │  NEW: copies file(s) in (unchanged — reuse verbatim), stores as
        │       "pending drop" state, sets selectedView/isExpanded to show picker
        ▼
IslandResolver.resolve(...)                     [pure arbiter]
        │  NEW presentation case: .quickActionPicker(pendingDrop)
        │  D-04 unchanged: charging/device transient still wins unconditionally
        │  (picker is just another `isExpanded` branch case, same tier as
        │   .trayExpanded/.calendarExpanded/.weatherExpanded)
        ▼
NotchPillView                                   [SwiftUI render]
        │  NEW case renders: file icon+filename preview (ShelfItemView-style)
        │                     + 3 buttons: Drop / AirDrop / Mail
        ▼
   ┌────┴─────────────┬──────────────────────┐
   │                   │                      │
   ▼                   ▼                      ▼
"Drop" tapped     "AirDrop" tapped       "Mail" tapped
   │                   │                      │
   ▼                   ▼                      ▼
ShelfCoordinator   QuickActionSharing     QuickActionSharing
.append(item)      Service (NEW seam)     Service (NEW seam)
   │               .share(urls, via: .sendViaAirDrop)
   ▼                   │                      │
switch to Tray     NSSharingService(named: .sendViaAirDrop / .composeEmail)
                       .perform(withItems: urls)
                        │
                        ▼
                   delegate callback (didShareItems / didFailToShareItems)
                   or timeout fallback (mirrors Phase 21 drag-pin's
                   20s-safety-net precedent, shorter interval)
                        │
                        ▼
                   clear pending-drop state → resolver falls back to
                   whatever presentation was active before the drop
```

### Recommended Project Structure
No new files/folders beyond the project's existing flat `Islet/Notch/` and `Islet/Shelf/` layout:
```
Islet/
├── Notch/
│   ├── IslandResolver.swift        # + .quickActionPicker(PendingDrop) case, resolve() branch, showsSwitcherRow() entry
│   ├── NotchWindowController.swift # + pending-drop state, handleDragApproachEnd() branch, delegate callback handling
│   ├── NotchPillView.swift         # + quickActionPickerView (new case, modeled on trayFullView)
│   └── QuickActionSharingService.swift  # NEW — thin seam wrapping NSSharingService (isolate-the-fragile-thing pattern)
└── Shelf/
    └── ShelfCoordinator.swift      # unchanged — reused verbatim for "Drop"
```

### Pattern 1: Direct NSSharingService invocation from a non-key panel (the spike's core finding)
**What:** Call `NSSharingService(named:).perform(withItems:)` directly — no window activation, no key-window toggling.
**When to use:** Both AirDrop and Mail-compose-with-attachment, exactly as D-08/D-09 scope them.
**Evidence:** `TheBoredTeam/boring.notch` (`boringNotch/components/Shelf/Services/QuickShareService.swift`, read via `gh api repos/TheBoredTeam/boring.notch/contents/...`) calls this from a window (`BoringNotchWindow`/`BoringNotchSkyLightWindow`) with `override var canBecomeKey: Bool { false }` and `INFOPLIST_KEY_LSUIElement = YES` — architecturally identical to Islet's own `NotchPanel.swift` (`canBecomeKey: false`, `.nonactivatingPanel`, no Dock icon). No `makeKey`, `NSApp.activate`, or `orderFrontRegardless` call appears anywhere near their sharing code; those calls exist elsewhere in their codebase only for their separate real Settings/Onboarding windows.
```swift
// Source: pattern verified against TheBoredTeam/boring.notch (MIT-licensed reference app),
// QuickShareService.swift, live-read via `gh api repos/TheBoredTeam/boring.notch/contents/...`
if let svc = NSSharingService(named: .sendViaAirDrop), svc.canPerform(withItems: urls) {
    svc.delegate = sharingDelegate   // see Pattern 2 — needed for completion, NOT for the call to work
    svc.perform(withItems: urls)     // no window activation of any kind
}
```

### Pattern 2: Delegate + timeout fallback for pending-state cleanup
**What:** `NSSharingServiceDelegate` conformance to know when sharing finished (success or failure), backed by a short timeout in case the delegate never fires (matches this project's own Phase 21 `dragPinSafetyNetDuration` precedent — a guaranteed fallback alongside a best-effort callback).
**When to use:** Both AirDrop and Mail — the pending-drop state (D-05) must clear once the user has handed the file off, or the picker would appear to hang.
**Example (adapted from boring.notch's `SharingLifecycleDelegate`, restructured to this project's existing "struct-first, thin class only for the OS callback surface" convention seen in `DeviceCoordinator`):**
```swift
// Source: pattern adapted from TheBoredTeam/boring.notch models/SharingStateManager.swift
final class QuickActionSharingDelegate: NSObject, NSSharingServiceDelegate {
    private let onFinish: () -> Void
    private var finished = false
    private var timeoutWorkItem: DispatchWorkItem?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
        let timeout = DispatchWorkItem { [weak self] in self?.finish() }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout) // mirrors Phase 21's safety-net idiom, shorter window
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish() }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) { finish() }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutWorkItem?.cancel()
        onFinish()
    }
}
```
Note: unlike boring.notch's 2s timeout (tuned for their picker-fallback flow), Islet's AirDrop/Mail case should likely use a **longer** timeout or no forced-clear at all before the OS-level AirDrop/Mail window itself appears — `didShareItems`/`didFailToShareItems` fire once the *user* completes or cancels the OS UI, which can take much longer than 2s for AirDrop device discovery. Recommend the planner treat the exact timeout value as a Claude's-Discretion implementation detail to tune during on-device UAT, not lock it here.

### Anti-Patterns to Avoid
- **Forcing the panel key before spiking the direct call:** D-08's exception is deliberately narrow ("if the spike finds..."), not a default. Building the key-toggle machinery unconditionally would add real risk (a non-key panel is ISL-03's core value) for a workaround the evidence above suggests is unnecessary.
- **Routing "Drop" through anything other than the existing `ShelfCoordinator.append`/`ShelfFileStore.makeSessionCopy` call already at `handleDragApproachEnd()`:** CONTEXT.md's discretion note leaves this open, but there's no reason to add an intermediate step — the exact same file-copy-in mechanism already runs at the drop site today; the picker only gates *when* `append` is called, not *how*.
- **Building a general focus-behavior toggle on `NotchPanel`:** even if D-08's exception proves necessary, scope it as a single-purpose helper invoked only around the `.perform(withItems:)` call, never a persistent or reusable "make key" API surface on the panel itself.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AirDrop device picker UI | A custom device-discovery/AirDrop UI | `NSSharingService(named: .sendViaAirDrop)` | Apple owns AirDrop's actual transfer UI and device discovery entirely — `perform(withItems:)` hands off to it |
| Mail compose window | A custom compose sheet | `NSSharingService(named: .composeEmail)` | Opens Mail.app's real compose window with the attachment already added; no reason to reimplement |
| Share-completion timing | Polling/guessing when the user is "done" | `NSSharingServiceDelegate` callbacks + a bounded timeout fallback | The OS tells you via delegate; a fallback timeout (mirroring this project's own Phase 21 drag-pin precedent) is the only extra piece needed for robustness |

**Key insight:** This phase's entire OS-integration surface is two enum-constant lookups and one method call (`perform(withItems:)`) — the actual engineering risk was never "how to call the API" but "does it work from this specific panel," which the boring.notch precedent now answers with real shipped-app evidence.

## Common Pitfalls

### Pitfall 1: `NotchPanel`'s `orderFrontRegardless()`-only show cycle vs. boring.notch's `BoringNotchSkyLightWindow`
**What goes wrong:** Islet's `NotchPanel` (per `NotchWindowController.positionAndShow`) is shown via `panel.orderFrontRegardless()` only, with `level = .statusBar`. Boring.notch's window class name (`BoringNotchSkyLightWindow`) hints it may use the private `SkyLight`/`CGSSetWindowLevel` APIs for a higher window level than `.statusBar` (consistent with this project's own prior ISL-03/A2 finding about Tahoe menu-bar layering, see `PROJECT.md`/STATE.md A2 note). This is a *window-level* difference, not a key-window difference, but it means the two apps aren't 100% identical in every respect — worth explicitly confirming during the spike that Islet's own `.statusBar`-level, non-key panel behaves the same, not just assuming it because boring.notch's *key*-behavior matches.
**Why it happens:** Two independently-evolved codebases solving the same notch-overlay problem will diverge on window-level tuning even while agreeing on the "never key" architecture.
**How to avoid:** The phase's spike task should be a minimal, throwaway on-device test (call `NSSharingService(named: .sendViaAirDrop)!.perform(withItems: [testFileURL])` from Islet's real running `NotchPanel`-hosted code, not a standalone script) before committing to the full picker UI build.
**Warning signs:** AirDrop/Mail silently does nothing when tapped (no error, no window) — the one failure mode this precedent doesn't fully rule out for Islet's exact window level.

### Pitfall 2: `canPerform(withItems:)` returning false for non-file items
**What goes wrong:** `NSSharingService.canPerform(withItems:)` can return `false` for certain item types (e.g., a directory URL for AirDrop in some configurations, or an empty array). Silently doing nothing when the user taps a button with no feedback is a bad UX regression.
**Why it happens:** `canPerform` is a real capability check, not just an existence check — it will legitimately be `false` if `urls` is empty or contains something the service can't handle.
**How to avoid:** Guard on `canPerform(withItems:)` before calling `perform`, and treat a `false` result the same as an error path (dismiss picker / show inline feedback) — never a silent no-op.
**Warning signs:** Tapping AirDrop/Mail does nothing at all with multiple files or unusual file types.

### Pitfall 3: Mail attachment support is Mail.app-only (already documented, re-confirmed)
**What goes wrong:** Users with a different default mail client expect an attached file; `NSSharingService(.composeEmail)` degrades silently to an unattached `mailto:` link for non-Mail.app default clients.
**Why it happens:** This is a long-standing, still-current AppKit limitation — independently corroborated by a public Thunderbird bug report (Bugzilla #1491683, "Thunderbird doesn't attach files when called using NSSharingService on macOS") describing the exact same degradation this project's own `REQUIREMENTS.md` Out-of-Scope table already documents.
**How to avoid:** Already accepted as documented, out-of-scope behavior (REQUIREMENTS.md) — no code fix exists or is being asked for. Just don't let planning re-litigate it as a bug to fix.
**Warning signs:** N/A — this is expected/accepted behavior, not a defect.

### Pitfall 4: CR-01 click-through regression (project-standing discipline, applies fresh here)
**What goes wrong:** A new `IslandPresentation` case that isn't mirrored correctly in `visibleContentZone()`/`positionAndShow`'s panel-frame union causes either dead-zone clicks (picker buttons unreachable) or click-swallowing over empty area beyond the picker's real bounds.
**Why it happens:** This project has hit this exact regression class repeatedly (28-REVIEW.md CR-01/CR-02, Phase 33's own "geometry three-site rule" comment at `visibleContentZone()` line ~1026) whenever a new expanded-content case is added without updating all three sites: `NotchPillView.blobShape`'s height override, `positionAndShow`'s panel-frame union member, and `visibleContentZone()`'s matching branch.
**How to avoid:** Add the picker's content size as a new named constant (mirroring `traySize`/`weatherLargeContentHeight`), add a `panelFrame` union member for it in `positionAndShow` (mirroring `trayFrame`/`weatherExpandedFrame`), and add a matching branch in `visibleContentZone()` — all three in the SAME commit (per the project's own Phase 32 comment: "a size change here that isn't mirrored breaks click-through").
**Warning signs:** Buttons not clickable, or clicks over blank area outside the visible picker registering as inside it. Requires an explicit on-device hover→expand→move-down trace per this project's standing CR-01 discipline — flag this as a required validation step in the plan, not optional polish.

### Pitfall 5: Picker's pending-drop state surviving a Charging/Device transient interruption (D-05)
**What goes wrong:** If the pending-drop state lives only as a case-associated value inside `IslandPresentation.quickActionPicker(PendingDrop)`, it gets lost the instant `resolve()` returns `.charging(...)`/`.device(...)` instead (D-04's transient-wins rule) — there's nowhere for the resolver's pure return value to "remember" the interrupted picker.
**Why it happens:** `IslandPresentation` is a `Equatable` value returned fresh by `resolve()` on every call; it has no persistence across calls by itself.
**How to avoid:** Store the pending-drop payload in the CONTROLLER (`NotchWindowController`), not inside the resolver's return value — mirror `TransientQueue`'s own head/pending split, where the controller (not the pure resolver) owns state across time, and the resolver stays a pure function of controller-provided inputs. Pass the pending-drop payload as one more argument to `resolve(...)` (or gate on `selectedView`/a new bool), so D-04's existing transient-wins branch order is untouched and the pending payload is simply not fed to `resolve()` while a transient owns the head — it reappears once `resolve()` returns to evaluating that state, per D-05.
**Warning signs:** Plugging in the charger while the picker is open loses the dropped file(s) instead of resuming the picker afterward (violates D-05 directly).

## Code Examples

### Full request flow sketch (illustrative, not literal signatures — planner determines final shape)
```swift
// Source: composed from Apple's NSSharingService docs + boring.notch's verified usage pattern
final class QuickActionSharingService {
    private var activeDelegate: QuickActionSharingDelegate?

    func share(_ urls: [URL], via name: NSSharingService.Name, onFinish: @escaping () -> Void) {
        guard let svc = NSSharingService(named: name), svc.canPerform(withItems: urls) else {
            onFinish()   // Pitfall 2 — treat "can't perform" as immediate completion, not silent no-op
            return
        }
        let delegate = QuickActionSharingDelegate(onFinish: { [weak self] in
            self?.activeDelegate = nil
            onFinish()
        })
        activeDelegate = delegate   // keep the delegate alive for the async duration — NSSharingService does not retain it
        svc.delegate = delegate
        svc.perform(withItems: urls)   // Pattern 1 — no window activation, verified against boring.notch
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NSSharingServicePicker` (system share menu) for arbitrary destination choice | Direct `NSSharingService(named:).perform(withItems:)` for a fixed, small, known set of destinations | Not a recent API change — both APIs have coexisted since 10.8; this project's own Out-of-Scope decision (not an Apple deprecation) is what selects direct-perform over the picker | Simpler code, no anchor-view/popover positioning concerns, matches the phase's fixed 3-button design exactly |

**Deprecated/outdated:** Nothing in this API surface is deprecated. `NSSharingService`/`NSSharingService.Name.sendViaAirDrop`/`.composeEmail` remain live, current API as of this research date.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Islet's `NotchPanel` (`.statusBar` level) will behave identically to boring.notch's window (possibly a higher/private window level) regarding `NSSharingService` from a non-key panel | Pitfall 1, Summary | If Islet's specific window-level/space configuration differs enough to matter, the direct-perform call could still silently fail on Islet's own hardware even though boring.notch's works — this is exactly what the phase's own required on-device spike is for; do not skip it based on this research alone |
| A2 | The recommended timeout duration for the sharing-completion fallback (Pattern 2) is left as "tune during on-device UAT," not a locked value | Pattern 2 | A too-short timeout could clear the pending-drop state (and thus visually "forget" the picker) while the user is still mid-AirDrop-selection; a too-long one leaves a stale pending state lingering if the delegate never fires. Low risk since this is explicitly flagged as tunable, not asserted as correct |

## Open Questions

1. **Does Islet's exact `NotchPanel` (not just the architecturally-similar boring.notch window) actually invoke AirDrop/Mail successfully with zero key-window changes?**
   - What we know: A real shipping app with an architecturally identical non-key panel does this successfully with no workaround.
   - What's unclear: Whether Islet's own specific window level (`.statusBar`) or Space/collection-behavior configuration (`FS-01`'s dedicated max-level Space, `.canJoinAllSpaces, .fullScreenAuxiliary, .stationary`) introduces any difference boring.notch's setup doesn't share.
   - Recommendation: This is precisely what the phase's own required spike (already flagged in STATE.md Blockers/Concerns and CONTEXT.md D-08) must confirm on-device before the full picker plan is built out. Structure the plan's first task as this minimal spike, gated by a checkpoint, before building the rest of the picker.

2. **Exact timeout value for the sharing-completion fallback.**
   - What we know: The delegate callbacks (`didShareItems`/`didFailToShareItems`) are the primary signal; a fallback timeout is needed for robustness (mirrors this project's own Phase 21 precedent).
   - What's unclear: AirDrop device-discovery can legitimately take much longer than boring.notch's chosen 2s value before the user picks a device — a naive copy of that constant risks clearing state too early.
   - Recommendation: Leave as a planner/executor tuning decision during on-device UAT, not locked by this research.

## Environment Availability

Not applicable — no external tools/services/runtimes beyond what's already linked into this Xcode project (AppKit, SwiftUI, already-present `ShelfCoordinator`/`ShelfFileStore`). No new SPM dependency, no CLI tool, no service to probe.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (XcodeGen `project.yml`) |
| Config file | `project.yml` — shared `Islet` scheme |
| Quick run command | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless in this project; see project memory `xcodebuild-test-headless-hang`) |
| Full suite command | Manual Cmd-U in Xcode (NOT `xcodebuild test`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAY-02 | Dropping a file (any tab) shows the picker instead of auto-staging | unit (resolver branch) + manual on-device (drop trigger + CR-01 click-through trace) | `xcodebuild build -scheme Islet` (build gate); extend `IslandResolverTests.swift` with a `.quickActionPicker` case test | ❌ Wave 0 — new resolver case needs a new test, mirrors existing `testChargingOutranksDeviceAndMedia`-style precedent |
| TRAY-03 | "Drop" stages the file via existing `ShelfCoordinator.append`/`ShelfFileStore.makeSessionCopy` and switches to Tray | unit (`ShelfCoordinatorTests.swift` already covers `append`/`makeSessionCopy` — no new coverage needed for the reused mechanism itself) + unit (new: picker-triggers-append-and-switches-view) | `xcodebuild build -scheme Islet` | ⚠️ Partial — `ShelfCoordinatorTests.swift` exists and covers the reused primitive; the NEW "picker → Drop → append + switch" glue needs its own test |
| TRAY-04 | "AirDrop"/"Mail" invoke `NSSharingService` with the pending file(s); Mail.app-only attachment limitation is accepted, not tested | unit (mockable seam: `QuickActionSharingService` should accept an injectable `NSSharingService`-performing closure so `canPerform`/`perform` call counts are testable without triggering the real OS UI in CI) + manual on-device (the actual OS-level AirDrop/Mail hand-off, since this genuinely cannot be automated) | `xcodebuild build -scheme Islet` (build gate); manual Cmd-U for the mockable-seam unit test; REAL AirDrop/Mail hand-off is manual-only by nature — flag explicitly, do not attempt to automate | ❌ Wave 0 — new `QuickActionSharingServiceTests.swift` needed, following `LocationServiceTests.swift`'s existing protocol-mock pattern for OS-boundary seams |
| D-04/D-05 | Charging/Device transient interrupts the picker; pending drop survives and resumes | unit (pure `resolve()` behavior, same style as existing transient-precedence tests in `IslandResolverTests.swift`) | `xcodebuild build -scheme Islet` | ❌ Wave 0 — extend `IslandResolverTests.swift` |
| D-06/D-07 | Dismissing without choosing discards the file(s), no auto-default | unit (controller-level state test, if the pending-drop discard logic is extracted as a pure/testable function) + manual on-device (grace-collapse dismissal trigger) | `xcodebuild build -scheme Islet`; manual Cmd-U | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **Per wave merge:** Manual Cmd-U in Xcode (full `IsletTests` suite) — `xcodebuild test` is not viable in this project (headless hang)
- **Phase gate:** Full suite green (manual Cmd-U) before `/gsd:verify-work`, PLUS the mandatory on-device CR-01 hover→expand→move-down trace for the new picker geometry, PLUS a real on-device AirDrop/Mail hand-off trial (the one thing no automated test can cover)

### Wave 0 Gaps
- [ ] `IslandResolverTests.swift` — extend with `.quickActionPicker` resolver-branch cases (covers TRAY-02, D-04/D-05)
- [ ] New `QuickActionSharingServiceTests.swift` — mockable seam for `canPerform`/`perform` call verification without triggering real OS UI (covers TRAY-04's testable half)
- [ ] Possibly extend `ShelfCoordinatorTests.swift` or add a new small test for the "picker Drop → append + view switch" glue (covers TRAY-03's new-glue half; the underlying `append`/`makeSessionCopy` primitives are already covered)
- [ ] Framework install: none — `IsletTests` target and `Islet` scheme already exist and are wired

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no | N/A — no auth surface in this phase |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — local-only, single-user desktop utility |
| V5 Input Validation | yes | `item.filename`/URL display already has an established truncation/sanitization convention in `ShelfItemView.swift` (`.truncationMode(.middle)`, V5-tagged comment "T-20-01: item.filename is untrusted") — the picker's file-preview reuses this exact view/convention per D-02, so no new validation code is needed, just reuse |
| V6 Cryptography | no | N/A — no cryptographic operations in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Malicious/oversized filename used for UI-layout injection or truncation-bypass (e.g. extremely long filename breaking layout) | Tampering (of local display state, not a network threat) | Already mitigated by `ShelfItemView`'s existing `.lineLimit(1)` + `.truncationMode(.middle)` + `.frame(maxWidth:)` — reuse this exact view, do not build a new unguarded label for the picker's file preview |
| Dropped file with a path/URL that no longer exists by the time AirDrop/Mail is invoked (race between drop and destination choice) | Denial of Service (local, UX-level — "nothing happens") | `canPerform(withItems:)` returning `false`, or `NSSharingServiceDelegate`'s `didFailToShareItems`, both surface this cleanly — treat as the completion path (Pitfall 2), not a crash risk; `ShelfCoordinator.pruneMissingFiles()`'s existing precedent (stale-file cleanup on hover-enter) shows this project already has a convention for handling externally-deleted files gracefully |

This phase has no network surface, no credentials, no new persistent storage beyond the already-existing session-copy mechanism — its security profile is minimal and dominated by "don't crash/hang on an edge-case file state," which the existing codebase conventions already cover.

## Sources

### Primary (HIGH confidence)
- `TheBoredTeam/boring.notch` GitHub repository, read directly via `gh api repos/TheBoredTeam/boring.notch/contents/...` and `gh search code` (MIT-licensed, real shipping app): `boringNotch/components/Shelf/Services/QuickShareService.swift`, `boringNotch/models/SharingStateManager.swift`, `boringNotch/components/Shelf/Services/ShareServiceFinder.swift`, `boringNotch/components/Notch/BoringNotchWindow.swift`, `boringNotch/components/Notch/BoringNotchSkyLightWindow.swift`, `boringNotch.xcodeproj/project.pbxproj` (confirms `LSUIElement = YES`) — the single strongest evidence source for this phase's core spike question
- This project's own source: `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPanel.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Notch/ShelfItemView.swift`, `Islet/Notch/NotchPillView.swift`, `IsletTests/IslandResolverTests.swift` — read directly for exact current signatures and patterns
- Apple AppKit SDK header `NSSharingService.h` (via `phracker/MacOSX-SDKs` mirror on GitHub) — confirms exact `NSSharingService.Name` constant list including `NSSharingServiceNameSendViaAirDrop`/`NSSharingServiceNameComposeEmail`, and the `NSSharingServiceDelegate` protocol method list

### Secondary (MEDIUM confidence)
- `faichou.com/posts/air-share-with-swift/` — a minimal command-line-tool AirDrop example calling `NSSharingService(named: .sendViaAirDrop)!.perform(withItems:)` with no window at all, corroborating (independently, from a different codebase) that no key window is required
- Bugzilla #1491683 ("Thunderbird doesn't attach files when called using NSSharingService on macOS") — independent, non-Apple confirmation of the Mail.app-only attachment limitation already documented in this project's own `REQUIREMENTS.md`

### Tertiary (LOW confidence)
- None used as load-bearing claims — all findings above were cross-verified against at least one primary source.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure Apple-framework API, no ambiguity on which constants/methods to use
- Architecture (resolver/controller integration): HIGH — directly read this project's own current source, patterns are consistent and well-precedented
- Core spike question (non-key panel + NSSharingService): HIGH — verified against a real shipping app's actual source code with an architecturally identical window, not a claim or inference
- Pitfalls: MEDIUM-HIGH — CR-01/D-05 pitfalls are HIGH confidence (this project's own repeated, documented failure mode); the exact sharing-completion timeout tuning is genuinely open (flagged as Open Question, not asserted)

**Research date:** 2026-07-15
**Valid until:** 30 days (stable Apple API surface; re-verify if macOS ships a sharing-services change, similar in kind to the MediaRemote 15.4 break this project has already navigated once)
