# Pitfalls Research

**Domain:** v1.5 (Home Focus & Widget Redesign) — adding a share/AirDrop/Mail destination picker, consolidating shelf-reveal to Tray-only, a WeatherKit forecast call, and an expanded-only NotchShape flare to Islet's existing click-through/non-activating-`NSPanel`/`matchedGeometryEffect` architecture.
**Researched:** 2026-07-13
**Confidence:** MEDIUM (architectural analysis HIGH — grounded directly in this codebase's current source; NSSharingServicePicker-vs-nonactivating-panel behavior MEDIUM — WebSearch-corroborated, not independently on-device verified; WeatherKit combined-call API HIGH — official Apple API, WWDC22-documented)

## Critical Pitfalls

### Pitfall 1: NSSharingServicePicker likely won't work at all from Islet's non-activating panel

**What goes wrong:**
`NSSharingServicePicker.show(relativeTo:of:preferredEdge:)` presents its own transient popover-like window anchored to the view you pass it. Multiple independent sources (Apple Developer Forums, community writeups on AppKit Services integration) confirm the underlying Services/Sharing menu machinery **only works correctly when the anchoring window is key** — a non-key window's Services submenu is a documented broken edge case. Islet's `NotchPanel` is deliberately built the opposite way: `.nonactivatingPanel` style mask, `canBecomeKey == false` / `canBecomeMain == false`, shown exclusively via `orderFrontRegardless()` (never `makeKeyAndOrderFront`), and the whole click-through/focus-safe design (D-04, D-07) depends on it never becoming key. Presenting `NSSharingServicePicker` anchored to a view inside that panel is very likely to produce one of: the picker not appearing at all, appearing but not responding to clicks, or appearing behind the frontmost app (since Islet is never the active app).

**Why it happens:**
It's tempting to reach for `NSSharingServicePicker` because "AirDrop + Mail destination picker" sounds exactly like what it's built for — but that API was designed for normal document-based apps with real, activatable windows, not for a background `LSUIElement` agent whose entire raison d'être is *never* taking focus.

**How to avoid:**
Do not use `NSSharingServicePicker`'s picker **UI** at all. Islet already needs its own custom SwiftUI 3-button "Drop / AirDrop / Mail" picker (Droppy-style Quick Action layout) — build exactly that as a normal SwiftUI view inside the existing expanded blob (reusing the `switcherRow`/`navCircleButton` visual language already in `NotchPillView.swift`), and wire only the individual `NSSharingService(named: .sendViaAirDrop)` / `NSSharingService(named: .composeEmail)` objects' `.perform(withItems:)` directly — never `NSSharingServicePicker`. This sidesteps the key-window requirement for the *chrome*; only the system AirDrop/Mail windows those services spawn need real activation (Pitfall 2), and those are proper separate windows, not anchored popovers.

**Warning signs:**
Building this feature by prototyping `NSSharingServicePicker(items:)` first and only discovering it doesn't respond to input during on-device UAT — exactly the failure shape that hit Phase 22 (drag-in) and Phase 27 (Settings sidebar clicks), where the bug only surfaced on real hardware, not in code review or build gates.

**Phase to address:**
The phase that builds the destination picker — spike the AirDrop/Mail `NSSharingService.perform(withItems:)` call in isolation (a throwaway button, no picker UI, no drop-flow integration) before wiring it into the drag-in drop path. Mirrors the Phase 22→24 precedent of isolating the one genuinely uncertain integration point.

---

### Pitfall 2: Invoking AirDrop/Mail may still require a real activation, breaking the non-activating guarantee for other windows

**What goes wrong:**
Even bypassing the picker UI (Pitfall 1), `NSSharingService(named: .sendViaAirDrop).perform(withItems:)` opens a real system AirDrop panel and `.composeEmail` opens Mail.app — both are genuine separate windows that plausibly need Islet to briefly become the active app (`NSApp.activate(ignoringOtherApps: true)`) to reliably surface in front, exactly like `NotchWindowController.openOnboardingSettings()` already does for the Settings window. If that activation call is added carelessly (e.g. left unconditionally on, or not paired with a return-to-non-activating state), it risks: stealing focus from whatever app the user was in when they dropped a file (breaking the "never steals focus" ISL-03 guarantee), or leaving Islet's panel briefly key/activatable in a way that changes `syncClickThrough()`'s assumptions elsewhere.

**Why it happens:**
The codebase's ENTIRE click-through/hover model (`pointerInZone`, `syncClickThrough()`, `ignoresMouseEvents`) is built on the invariant "the panel is never key, Islet is never the active app." AirDrop/Mail is the first feature in this project that has a *legitimate* reason to briefly want activation — there is no existing precedent to copy other than `openOnboardingSettings()`, which activates for a completely different, modal, user-driven context (opening Settings), not a transient action inside the click-through hover flow.

**How to avoid:**
Scope any `NSApp.activate` call as tightly as possible: fire it immediately before `.perform(withItems:)`, and do not do anything to the panel's own key/activation state — the panel itself must stay `.nonactivatingPanel`/never-key regardless of whether the app-level process is briefly active. On-device-verify (not just build-verify) that after AirDrop/Mail's window closes, the island's hover/click-through/grace-collapse behavior is exactly as before (re-run the CR-01 hover→expand→move-down trace).

**Warning signs:**
Any hover-glitch, stuck-expanded, or click-swallowing symptom appearing specifically after using the new AirDrop/Mail button and not before — the CR-01 precedent shows this class of regression is easy to introduce and easy to miss without an explicit on-device trace.

**Phase to address:**
Same phase as Pitfall 1 — the isolated AirDrop/Mail spike should explicitly include a before/after click-through regression check, not just "does AirDrop open."

---

### Pitfall 3: Half-migrating "shelf-reveal on every tab" down to "Tray-only" — the additive `shelfVisible:` call sites are scattered, not centralized

**What goes wrong:**
Today, the additive shelf-strip reveal is wired independently at **multiple separate call sites** in `NotchPillView.swift` (grep confirms 5 occurrences of `shelfVisible: shelfViewState.isVisible, showSwitcher: true` — covering at minimum Home, Calendar, and Weather's `blobShape(...)` calls, plus onboarding-adjacent presentations), each independently passing `shelfVisible: shelfViewState.isVisible`. `trayFullView` is the *only* one already hardcoded to `shelfVisible: false` (deliberately, per its CR-01 fix comment, because Tray's own content already IS the files view). Making the shelf Tray-exclusive means changing `shelfVisible:` to `false` at every one of the *other* call sites — and this is precisely the failure shape the project's own Phase 28 code review already caught twice (CR-01: a phantom click-through band from a forgotten case; CR-02: a stale-month bug from a not-fully-threaded state update). A single missed call site leaves the "additive reveal" silently alive on one tab (most likely Calendar or Weather, since Home is the obvious one anyone remembers to check) — worse, per `visibleContentZone()`'s own CR-01 discipline, the click-through hit-test region is a **separate, hand-maintained mirror** of the same boolean (`shelfViewState.isVisible && !isTrayPresentation`) — if the view-side migration and the click-through-side migration disagree even briefly, you get exactly CR-01's phantom-band click-swallowing regression again, on a different feature.

**Why it happens:**
The codebase's own header comment on `showsSwitcherRow(for:)` explicitly documents this exact recurring failure mode: "Both NotchPillView (rendering) and NotchWindowController (panel/click-through geometry) used to maintain their own hand-duplicated copy of this exact case list... nothing enforced that agreement." The `shelfVisible:` gating was never consolidated the way `showsSwitcherRow` was — it's still multiple independent booleans in the view layer plus one independent mirror in `visibleContentZone()`.

**How to avoid:**
Before touching any of the scattered `blobShape(...)` call sites, introduce ONE shared function (mirroring `showsSwitcherRow(for:)`'s exact precedent) — e.g. `shelfStripVisible(for presentation: IslandPresentation, hasItems: Bool) -> Bool` — that both `NotchPillView`'s call sites AND `visibleContentZone()` call, so there is structurally only one place that says "shelf strip only shows when `presentation == .trayExpanded`" (or, if a brief additive-drop auto-reveal moment is intentionally kept before the picker interrupts it, encode that as an explicit, named, tested state rather than a per-call-site boolean). Grep for every remaining `shelfVisible: shelfViewState.isVisible` after the change — the count should be zero outside the new shared function.

**Warning signs:**
Any tab other than Tray still visually growing a shelf strip when files are staged; any tab where clicking in the lower part of the expanded island (below the visible content) fails to pass through to the app underneath — that is CR-01's signature symptom recurring.

**Phase to address:**
The Tray-consolidation phase — plan it as "introduce one shared gating function + verify zero remaining scattered `shelfVisible:` booleans" rather than "edit each call site individually," and explicitly re-run the CR-01 hover→expand→move-down on-device trace on every tab (not just Tray) since this touches the exact mechanism CR-01 broke before.

---

### Pitfall 4: Rewiring the drop-completion path to show a destination picker touches the single most regression-prone code path in the project

**What goes wrong:**
`handleDragApproachEnd()` in `NotchWindowController.swift` is the literal landing point of Phase 22's abandoned drag-in attempt, Phase 23's from-scratch panel rewrite, and Phase 24's finally-working `DropInterceptTap`/`DragApproachDetector` production implementation — the most expensive, most iterated, most fragile piece of AppKit glue in the codebase (three phases, one full architecture rewrite, two blind on-device failures before it worked). It currently unconditionally does `shelfCoordinator.append(item)` for every accepted dropped URL inside a `.leftMouseUp` global-monitor callback, mid-way through tearing down `isDragApproaching` state. Inserting a NEW async decision point here — "pause, show a 3-way destination picker, wait for the user's tap, THEN branch to shelf-append vs. AirDrop vs. Mail" — means suspending mid-flow logic that was hard-won through real hardware failures the code comments explicitly warn future readers about (e.g. "a geometrically-ambiguous Escape-cancel can never leave the island stuck expanded" — an invariant a paused/awaiting-picker state could easily violate).

**Why it happens:**
The destination-picker requirement reads as "just show a menu after drop" from the product side, but structurally it means changing a synchronous, single-pass drop handler into a two-phase one (accept drop → show picker → user choice → act), inside code that already has multiple carefully-sequenced cleanup steps (`isDragApproaching = false` unconditionally first, `handlePointer` resync at the end) that assume the whole thing completes in one call.

**How to avoid:**
Keep `handleDragApproachEnd()`'s existing accept/stage logic completely unchanged — it already knows how to get files into `shelfCoordinator` reliably. Model the destination picker as a **separate, later** UI step that operates on files already safely staged (i.e., always accept the drop into the shelf first, exactly as today, then show the picker as a follow-up prompt over the now-populated Tray, gating only whether the staged file ALSO gets AirDropped/emailed). This avoids adding any new async/awaiting state to the one function this project has already paid the most to get right. If product intent genuinely requires the picker to appear before anything is staged, isolate that specific reordering as its own spike phase (mirroring Phase 22's isolation approach) rather than folding it into the same plan as the picker UI itself.

**Warning signs:**
Any new intermittent "drop doesn't do anything" or "island stuck expanded after a drop" report during on-device testing — this exact symptom class (silent failure, no reproducible error, only visible on real hardware) is this project's documented history for this file.

**Phase to address:**
Isolate as its own phase or plan, sequenced with an explicit on-device spike BEFORE wiring the picker into the real drop flow — do not combine with the Weather or NotchShape work in the same plan, since a failure here has historically forced full architecture rewrites (Phase 23) with unrelated blast radius.

---

### Pitfall 5: Adding a forecast call as a second independent WeatherKit fetch doubles quota usage and duplicates the existing degrade-silently contract

**What goes wrong:**
`WeatherService.fetchCurrent(...)` is a single-purpose protocol method with exactly one conformer (`WeatherKitService`), called every 15 minutes by `startOutfitRefresh()`'s timer plus on every hidden→visible transition. The natural (wrong) move is to add a parallel `fetchForecast(...)` method that makes its own independent `WeatherKit.WeatherService.shared.weather(for:)` call — this silently **doubles** the network/quota cost of every refresh cycle (two API calls where one would do) and, worse, duplicates (and risks drifting from) the existing "settle nil on any denial/failure, never retry" contract (D-01) across two independently-erroring async paths instead of one.

**Why it happens:**
The existing method is named `fetchCurrent` and scoped to current-conditions only — extending it to also return forecast data looks like a breaking signature change, so a second parallel method feels safer/smaller-diff. It isn't: WeatherKit's `WeatherService.weather(for:including:)` officially supports fetching multiple datasets — e.g. `.current` and `.daily` — in a single call that counts as **one** request toward the quota (confirmed via Apple's WWDC22 session and developer forum discussion), returning a tuple `(current, daily)`.

**How to avoid:**
Extend the existing seam to a single combined fetch — e.g. `fetchCurrentAndForecast(latitude:longitude:completion:)` using `weather(for: location, including: .current, .daily)` — rather than adding a second, independently-scheduled call. This is also fewer lines of new code (the lazy option and the correct option coincide here). Keep the "one call, one place" pattern the codebase already uses for `NowPlayingMonitor`/`WeatherService` protocol isolation. If `fetchCurrent`'s existing single-value signature must stay for compatibility with the already-shipped `expandedIdle`/Weather-tab current-conditions display, keep it delegating to the combined call under the hood rather than firing two separate network requests per refresh cycle.

**Warning signs:**
Any code review finding two separate `service.weather(for:)` / `try await service.weather(...)` call sites inside the outfit-refresh path — that's the doubled-quota smell.

**Phase to address:**
The Weather-forecast phase, at the seam-design step — decide the combined-call shape before writing the view that consumes it, since the view's expected data shape (whether it gets one combined response or two separately-arriving ones) determines whether Pitfall 6 (below) becomes a problem too.

---

### Pitfall 6: Widget renders with only current-conditions data before forecast data arrives — no async-timing seam exists for "wait for both, or degrade independently"

**What goes wrong:**
`fetchCurrent(...)`'s contract is fire-and-forget: `completion` is called once, on the main thread, with either a `WeatherGlance?` or `nil` — there is no "in-flight" state the view can observe. If the new extended (forecast) widget is built by having the view independently trigger a forecast fetch on appear/tab-select, there is a real window where the compact current-conditions data has already rendered (from the existing 15-minute-cycle cache in `outfitState.weather`) while the forecast strip is still `nil`/loading — exactly the "artwork lags behind metadata" pattern already called out as a known WeatherKit-adjacent gotcha in this project's own STACK.md ("Artwork latency... design the UI to fill art in asynchronously"). Without an explicit loading/placeholder state, the extended widget will visibly pop the forecast strip in a beat after the rest of the card, which for a small, information-dense widget reads as janky rather than "asynchronous by design."

**Why it happens:**
The existing `WeatherGlance`/`outfitState.weather` model has no concept of partial/loading state — it's `nil` or fully populated. Bolting a forecast array onto the same all-or-nothing model without a loading placeholder is the path of least resistance.

**How to avoid:**
If Pitfall 5's combined `fetchCurrentAndForecast` call is used, this mostly resolves itself — current and forecast arrive together, atomically, so there's no partial-render window. If for some reason the two must stay separate calls, add an explicit `forecast: [DailyForecast]?` field to the model (nil = not yet loaded, distinct from "loaded but empty") and have the extended widget render a skeleton/placeholder row for the forecast strip specifically while `forecast == nil`, never an empty-looking gap.

**Warning signs:**
On-device UAT: switch the Settings toggle to the extended widget right after app launch (before the 15-minute cycle would naturally have forecast data) and watch for a visible pop-in of the forecast row a beat after the rest of the card renders.

**Phase to address:**
The Weather-forecast phase — cover explicitly in its on-device UAT checklist (mirrors Phase 14's own "artwork fills in asynchronously" style check).

---

### Pitfall 7: A shared `matchedGeometryEffect`-morphed shape gaining a new flare parameter at only SOME call sites breaks the collapsed↔expanded morph or reintroduces CR-01

**What goes wrong:**
Every rendered blob/pill/wings state in `NotchPillView.swift` constructs its own `NotchShape(topCornerRadius:bottomCornerRadius:)` instance sharing the SAME `matchedGeometryEffect(id: "island", in: ns)` — there are at least 9 distinct construction sites across `blobShape()` (used by Home/Tray/Calendar/Weather/NowPlaying/onboarding), `wingsShape()` (Charging/Device), the standalone collapsed-pill fill, and the song-toast blob. An "outward flare, expanded-only" requirement is a genuinely NEW geometric parameter (not just a corner-radius tweak like the existing 6/6 → 6/32 collapsed→expanded morph) — it must be threaded through `NotchShape`'s `path(in:)` computation and set to a "flat/no-flare" value at every COLLAPSED-state call site (idle pill, wings, hovering) while only ever being non-zero for the expanded blob states. Given this project's own documented history of "a case added to one switch and forgotten in the other" (CR-01, CR-02 — both explicitly named in `IslandResolver.swift`'s comments as *the same root failure class*), the concrete risk is: the flare gets added to `blobShape()` but the idle/wings/toast NotchShape constructions are left at their old signature (if the new parameter isn't given a safe default) — a compile break — OR, more insidiously, IS given a default of 0 and compiles fine, but one of `blobShape()`'s OWN call sites is missed, leaving that one expanded presentation (e.g. Weather, since it's the newest/least-touched tab) flat while Home/Tray/Calendar flare correctly — a visually inconsistent, easy-to-miss-in-code-review gap.

**Why it happens:**
There is no single source of truth for "which NotchShape construction is collapsed vs. expanded" the way `showsSwitcherRow(for:)` centralizes "which presentation shows the switcher row" — each of the 9+ call sites independently hardcodes its own corner-radius literals today, and a new flare parameter would naturally be added the same scattered way unless deliberately centralized.

**How to avoid:**
Add the flare as a parameter to the shared `blobShape()` helper function itself (not to each of its callers individually) with a fixed, single value used by every expanded presentation that routes through it — since `blobShape()` is ALREADY the one shared helper every expanded state uses, this is nearly free: only the true outliers (`wingsShape()` for Charging/Device, and the two standalone collapsed-pill/toast `NotchShape` constructions around lines ~1174/1237) need an explicit "flare: false/0" left completely untouched. Grep every `NotchShape(` construction site after the change and confirm each one is either inside `blobShape()` (gets the flare) or explicitly one of the known collapsed/wings/toast sites (explicitly excluded) — no orphaned direct construction should exist outside that accounting.
Separately: this codebase's `NotchShape` has **no explicit `animatableData` override** (confirmed by reading the full file) — its two stored `CGFloat` corner-radius properties rely on whatever implicit interpolation SwiftUI + `matchedGeometryEffect` currently provide for the existing 6/32 collapsed→expanded morph (Phase 25's on-device UAT explicitly re-verified "no morph artifacts" after touching this exact shape). A third flare parameter must be verified the same way, on-device, not assumed to interpolate just because the existing two do — if it doesn't animate smoothly, the fallback is adding an explicit `animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>` conformance, a bigger, riskier change to a shape shared by every single presentation in the app.

**Warning signs:**
Any expanded tab whose top edge stays flush/straight instead of flaring while others correctly flare; a visible snap/jump (rather than smooth morph) in the top-edge curve specifically during the collapsed→expanded transition, distinct from the rest of the shape's already-proven-smooth morph.

**Phase to address:**
The NotchShape flare phase — plan it with an explicit on-device checklist re-running Phase 25's exact 7-point morph-verification (gradient depth unaffected, no morph artifacts, rapid hover-enter/exit, activity-content regression) PLUS a new pass through every one of Home/Tray/Calendar/Weather/NowPlaying-expanded to confirm the flare renders identically on all five, since they are the call sites most likely to be inconsistently migrated.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Using `NSSharingServicePicker`'s built-in UI instead of custom SwiftUI buttons + direct `NSSharingService.perform(withItems:)` | Less UI code to write | Very likely broken/unresponsive from a non-activating panel (Pitfall 1) — this isn't really "debt," it's a probable functional failure | Never, for this specific panel architecture |
| Adding `fetchForecast` as a second independent WeatherKit call instead of a combined `.current, .daily` request | Smaller diff to the existing `fetchCurrent` signature | Doubles quota/network cost every refresh cycle, duplicates the nil-on-failure contract in two places | Never — the combined call is both simpler and cheaper |
| Leaving old scattered `shelfVisible: shelfViewState.isVisible` booleans in place and just overriding them per-tab with an extra `&& isTrayTab` condition instead of centralizing | Avoids touching `visibleContentZone()`'s existing CR-01-hardened logic | Recreates exactly the "hand-duplicated mirrored boolean" pattern the codebase's own comments identify as CR-01/CR-02's root cause | Never — this is the one thing this codebase has paid for twice already |

## Integration Gotchas

Common mistakes when connecting to external services/APIs.

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| `NSSharingServicePicker` | Assuming it "just works" like a normal AppKit control regardless of window activation state | Skip the picker UI entirely; build a custom SwiftUI picker and call individual `NSSharingService.perform(withItems:)` directly (Pitfall 1) |
| `NSSharingService.perform(withItems:)` (AirDrop/Mail) | Never activating the app, so the system AirDrop/Mail window fails to surface in front of other apps | Briefly `NSApp.activate(ignoringOtherApps: true)` immediately before the call, scoped tightly, without touching the panel's own never-key invariant (Pitfall 2) |
| WeatherKit forecast | Adding a second, independently-scheduled `weather(for:)` call for `.daily` data | Use `weather(for: location, including: .current, .daily)` — one call, one quota unit (Pitfall 5) |
| WeatherKit forecast | Assuming forecast data arrives synchronously with current-conditions since both come from "the same service" | Model an explicit loading/nil-vs-not-yet-loaded state if the calls are ever split, or use the combined call to avoid the problem entirely (Pitfall 6) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Two independent WeatherKit calls (current + forecast) every 15-minute refresh cycle | Slightly slower weather updates, and — at genuinely heavy usage across many installs sharing WeatherKit's per-Apple-ID-app quota — could matter, though for a single hobby app the 500k/month quota is nowhere close to being hit either way | Combined `weather(for:including:)` call (Pitfall 5) | Not a near-term risk for this project's scale; still the correct default to build right the first time |
| A new `NSSharingService.perform` call fired synchronously inside the same `.leftMouseUp` global-monitor callback that already does drag-teardown bookkeeping | Could add latency/blocking to the already-timing-sensitive drop-completion path (`handleDragApproachEnd`) that this project has twice rebuilt for reliability | Keep the picker/service invocation decoupled from the drop-acceptance path itself (Pitfall 4) | Any perceptible lag or dropped-frame stutter right at the moment of drop |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Passing a dropped file's ORIGINAL URL (not the session-copy `localURL` the shelf already creates) to `NSSharingService`/AirDrop/Mail | If the user later deletes/moves the original file, or if it's a path outside the app's expected sandbox-adjacent temp area, the share could silently fail or behave unexpectedly; also inconsistent with `ShelfFileStore`'s existing "session copy" discipline (already hardened once, per Phase 19's `deleteSessionCopy` path-validation fix) | Route AirDrop/Mail sharing through the SAME `localURL`/session-copy the shelf already uses, not the raw dropped `originalURL`, for consistency with the existing validated file-handling path |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Destination picker appears as a NEW modal-feeling interruption every single time a file is dropped, even for users who almost always just want "Drop" | Adds friction to what was previously a single-step action (drop → staged) | Confirm with the user/on-device whether "Drop" should have a fast-path (e.g. default action on drop, picker only for explicit alternate destinations) before building the always-interrupt version — this is a product decision, not just an implementation detail, and changing it later means re-touching the fragile drop-completion path again (Pitfall 4) |
| Weather compact widget and extended (forecast) widget use different layouts/heights that aren't accounted for in the shared `switcherContentHeight`/panel-union sizing | A Settings toggle switch between compact/extended could either clip content or leave a visibly oversized empty gap, since the panel is sized once up-front to a union of all known content sizes (`positionAndShow`'s `panelFrame` union) | Add the extended widget's real height to that same union from the start, mirroring how `onboardingSize`/`wingsSize` were each added as their own union member — don't let it be a live-resize |

## "Looks Done But Isn't" Checklist

- [ ] **AirDrop/Mail picker:** Often "looks done" once the picker UI renders and taps register — verify it actually WORKS end-to-end on real hardware (a real AirDrop transfer to a real nearby device, a real Mail compose window opening with the attachment), not just that the button click is caught in code.
- [ ] **Tray-exclusive shelf:** Often "looks done" once Tray itself shows files correctly — verify EVERY other tab (Home, Calendar, Weather, NowPlaying-expanded) no longer shows the shelf strip, and that clicking through the space where it used to render on those tabs passes through to the app underneath (re-run CR-01's exact click-through trace, not just a visual check).
- [ ] **Weather forecast widget:** Often "looks done" once the forecast row renders with plausible-looking data on the FIRST test — verify behavior on permission denial (forecast column silently absent, matching the existing current-conditions degrade-silently contract) and on the very first launch after enabling the extended toggle (Pitfall 6's pop-in check).
- [ ] **NotchShape flare:** Often "looks done" once ONE tab (typically Home, tested first) shows the flare correctly — verify all five expanded presentations (Home/Tray/Calendar/Weather/NowPlaying) flare identically, and that the idle/collapsed pill and the Charging/Device wings remain completely unflared/unchanged (explicit product requirement).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| NSSharingServicePicker doesn't work from the panel (Pitfall 1) | LOW, if caught early via an isolated spike | Discard the picker-UI approach, switch to custom SwiftUI buttons + direct `NSSharingService.perform(withItems:)` — no architecture rewrite needed since nothing else depends on the picker class |
| Drop-completion path regression from the new destination picker (Pitfall 4) | HIGH, if discovered late (matches Phase 22's actual cost — a full panel architecture rewrite) | Revert to the pre-picker `handleDragApproachEnd()` behavior (always stage to shelf), re-isolate the picker as its own follow-up spike exactly like Phase 22→24, don't attempt to debug blind a second time (explicit project precedent: the user's own call after two blind failures) |
| Half-migrated shelf gating leaves CR-01-style phantom click-swallowing on a non-Tray tab (Pitfall 3) | LOW-MEDIUM, if the shared-gating-function refactor is done up front | If discovered late, the fix is mechanical (grep + centralize) but requires a full on-device re-trace of every tab, not just the one where the bug was noticed |
| NotchShape flare parameter inconsistently applied (Pitfall 7) | LOW | Mechanical grep-and-fix once `blobShape()` is confirmed as the single flare-owning call site; low cost specifically because the shape's existing shared-helper structure already limits the blast radius if centralized correctly from the start |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| 1. NSSharingServicePicker likely broken from non-activating panel | AirDrop/Mail destination-picker phase, isolated spike first | On-device: tap AirDrop/Mail button from a real hover/expand state, confirm the system window appears, is clickable, and completes a real transfer/compose |
| 2. Activation for AirDrop/Mail breaks non-activating guarantees elsewhere | Same phase, same spike | On-device: re-run CR-01's hover→expand→move-down trace immediately after using AirDrop/Mail, confirm click-through/grace-collapse unchanged |
| 3. Half-migrated shelf-reveal gating (scattered `shelfVisible:` booleans) | Tray-consolidation phase | Grep: zero remaining `shelfVisible: shelfViewState.isVisible` outside one shared gating function; on-device: click-through check on every non-Tray tab |
| 4. Destination picker touching the fragile drop-completion path | Same phase as 1/2, sequenced as its own isolated plan | On-device: repeat several real drag-drop cycles, confirm no stuck-expanded state, no silent drop failures |
| 5. Forecast as a second independent WeatherKit call (quota/contract duplication) | Weather-forecast phase, at seam-design step | Code review: confirm exactly one `weather(for:including:)` call site per refresh cycle |
| 6. Forecast data arriving after widget already rendered (pop-in) | Weather-forecast phase | On-device: toggle extended widget right after launch, watch for forecast-row pop-in |
| 7. NotchShape flare inconsistently applied across expanded presentations | NotchShape-flare phase | On-device: re-run Phase 25's 7-point morph checklist + explicit pass through all 5 expanded tabs |

## Sources

- Direct source read: `Islet/Notch/NotchWindowController.swift` (full file, 1832 lines) — panel activation model, `syncClickThrough()`/`visibleContentZone()` CR-01 discipline, `handleDragApproachEnd()`/drag-in architecture history
- Direct source read: `Islet/Notch/IslandResolver.swift` — `showsSwitcherRow(for:)` centralization precedent, `forcedByTray` removal history (28-04 round 5), confirms the shared-gating-function pattern already exists for one axis but not for `shelfVisible:`
- Direct source read: `Islet/Notch/NotchShape.swift`, `Islet/Notch/NotchPillView.swift` (grep across all `NotchShape(`/`blobShape(`/`matchedGeometryEffect` sites) — confirms 9+ independent shape-construction sites, no explicit `animatableData` override
- Direct source read: `Islet/Weather/WeatherService.swift`, `Islet/Shelf/ShelfViewState.swift` — existing single-purpose protocol seams and contracts
- `.planning/PROJECT.md` (Key Decisions table, full read) — CR-01 (Phase 20/28), Phase 22 drag-in failure + Phase 23 rewrite, Phase 27 Settings on-device-only regressions, Phase 14 WeatherKit entitlement gap
- `.planning/STATE.md` — Phase 14 finding: "14-05 found and fixed two Hardened-Runtime entitlement gaps (Calendar, Location) plus a WeatherKit Portal App Services capability miss"; existing `Islet.entitlements`/`project.yml` confirm `com.apple.developer.weatherkit` + real Developer Team are already in place, so the forecast call is not expected to need a NEW capability, only a verified call-shape (Pitfall 5)
- [LSUIElement — CocoaDev](https://cocoadev.github.io/LSUIElement/) (MEDIUM — community reference confirming agent-app window activation semantics)
- [Can't get NSSharingServicePicker to… — Apple Developer Forums](https://developer.apple.com/forums/thread/722288) (MEDIUM — confirms picker reliability issues are a known, sometimes-unresolved class of problem even in normal apps)
- WebSearch aggregate on "NSSharingServicePicker ... key window" (MEDIUM — multiple independent community sources converge on "Services submenu only works if window is key"; not independently verified on this project's exact panel configuration — flagged for the isolated on-device spike)
- Apple WWDC22 "Meet WeatherKit" + Apple Developer Forums thread on `weather(for:including:)` (HIGH — official Apple API, confirms combined multi-dataset single-call semantics)

---
*Pitfalls research for: Islet v1.5 (Home Focus & Widget Redesign) — AirDrop/Mail picker, Tray-exclusive shelf, WeatherKit forecast, NotchShape flare*
*Researched: 2026-07-13*
