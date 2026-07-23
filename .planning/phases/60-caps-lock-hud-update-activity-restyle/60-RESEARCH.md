# Phase 60: Caps Lock HUD + Update-Activity Restyle - Research

**Researched:** 2026-07-23
**Domain:** Native macOS (Swift/AppKit/SwiftUI) — new transient island HUDs, global keyboard-event monitoring, Sparkle callback wiring
**Confidence:** HIGH (all core findings verified directly against the live codebase via grep/Read; the one external-API claim — Accessibility gating of global key monitors — is CITED against archived-but-authoritative Apple documentation)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** ROADMAP.md's "reskin the existing update-available HUD" wording is stale. Phase 40 built exactly that (a collapsed-pill badge HUD), then redesigned it to a menu-bar status-item red dot (commit `30d9f82`) after an unfixable click-through/hot-zone bug; `Islet/Notch/UpdateAvailableState.swift` was deleted. **There is no existing island HUD to reskin.** UPDATE-01 is a **new** transient built from scratch using the wings pattern.
- **D-02:** The new Update HUD is added **alongside** the existing menu-bar dot — the dot is NOT removed. Both fire from the same `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)` callback (`Islet/AppDelegate.swift:390`).
- **D-03:** Caps Lock HUD shows an icon + text label in **both** the ON state ("Caps Lock On") and the OFF state ("Caps Lock Off") — unlike Charging's wings (label only in the positive state).
- **D-04:** The trailing pill on the Update HUD shows the version number only (e.g. "v1.11"), sourced from `SUAppcastItem.displayVersionString` (already passed into `didFindValidUpdate`). Mirrors `BatteryIndicator`'s role as a compact trailing readout.
- **D-05:** Both new transients rank **below OSD** (rank 4) in `TransientQueue` — i.e. rank 5/6, added as new named-comment ranks per the existing convention, not renumbered.
- **D-06 (Claude's Discretion):** Exact relative order between Caps Lock (rank 5) and Update (rank 6) — low-stakes.
- **D-07:** Both new HUDs are **collapsed-only** — same rule as Focus/OSD — they do NOT pre-empt an expanded view.

### Claude's Discretion
- Exact SF Symbol choice for the Caps Lock icon (e.g. `capslock.fill`) and its color treatment for on vs. off states.
- D-06 above (Caps Lock vs. Update relative rank order).
- Whether the Update HUD's tap-to-install gesture reuses `wings(for:)`'s existing tap-handling wiring or needs its own — **RESOLVED BELOW**: it needs its own; see Architecture Patterns and Common Pitfalls.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. "Island briefly disappears during click-through" (existing, separately-tracked bug) is flagged as a risk, not folded into this phase's scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAPS-01 | Toggling Caps Lock briefly shows an on/off HUD in the collapsed island (same transient wings pattern as Charging), auto-dismissing after ~1-2s | `wingsShape`/`osdWings(for:)` pattern (self-elapsing, non-persistent); `CapsLockMonitor` design mirroring `PowerSourceMonitor`'s lifecycle + `OSDInterceptor`'s Accessibility-trust gate; resolver/queue wiring pattern; Settings card + permission popover pattern |
| UPDATE-01 | The Update-available HUD (leading icon, "Update" label, trailing version pill) — new build, trigger logic/Sparkle plumbing unchanged | `wingsShape` pattern; new `updateHudKey` AppStorage + Settings card (does not exist yet); `AppDelegate.didFindValidUpdate` dual-signal wiring; version-pill styling derived from `BatteryIndicator`'s visual language (not its content); tap-to-install gesture design (net-new, no existing precedent) |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **First-time programmer**: explanations should accompany non-trivial code; avoid unnecessary complexity — favor mirroring existing wing/monitor patterns exactly over inventing new abstractions.
- **No App Sandbox** (`ENABLE_APP_SANDBOX: NO` in `project.yml:123`, confirmed) — no sandbox-entitlement friction for a new `NSEvent` global monitor or Accessibility API use.
- **Direct/notarized distribution only** — Hardened Runtime stays on; no new entitlement is required for `NSEvent.addGlobalMonitorForEvents` or `AXIsProcessTrusted()` (both are plain TCC-gated APIs, not sandbox entitlements).
- Swift 5 language mode / Swift 6 toolchain — match existing `nonisolated(unsafe)` / `@MainActor` conventions already used by `PowerSourceMonitor`/`OSDInterceptor` for the new monitor class.

## Summary

Both new HUDs are additive, collapsed-only `IslandPresentation`/`ActiveTransient` cases that plug into an already well-proven pattern: a `wingsShape(leftWidth:rightWidth:content:)` helper, a pure `resolve()` reducer, and a `TransientQueue` with `enqueue`/`preempt`/`advance`. The **visual** work (matching D-03/D-04) is low-risk and mechanical — 4 near-identical precedents already exist (`wings(for:)`, `focusWings(for:)`, `osdWings(for:)`, `deviceWings(for:)`).

Three things make this phase **not** pure copy-paste, and the planner should size tasks accordingly:

1. **Caps Lock requires Accessibility permission**, contrary to CONTEXT.md's framing that this is "purely a new pattern with nothing to model." Apple's own documentation states a global event monitor "may only monitor key events if accessibility is enabled or if the application is trusted for accessibility" — and `flagsChanged` is a key event. This codebase already has a working, in-place pattern for exactly this permission category: `OSDInterceptor.isAccessibilityTrusted` (`AXIsProcessTrusted()`) plus the Settings "onOptionsTap → popover → deep-link to System Settings' Accessibility pane" flow (`osdPermissionExplanationView`/`focusPermissionExplanationView`). Caps Lock should reuse this exact permission bucket and UI pattern, not invent a new one — but the current Caps Lock Settings card (`Islet/SettingsView.swift:194-197`) has `onOptionsTap: nil` and needs this wired in.
2. **A new `updateHudKey` AppStorage key + Settings card does not exist yet.** Phase 59 wired only `capsLockKey`. `autoUpdateCheckKey` exists but gates Sparkle's background check, not this HUD's visibility. This is a small but real gap the plan must include (new key, new `@AppStorage` property, new `ActivityCardData` entry, default `false`).
3. **The Update HUD's tap-to-install action cannot reuse `wingsShape`'s built-in tap gesture as-is.** Every existing wing (`Charging`/`Device`/`Focus`/`OSD`) shares one `.onTapGesture { onClick() }` baked directly into the shared `wingsShape` helper (`NotchPillView.swift:2347`), where `onClick` is the universal "expand to Home" action. No wing in this codebase has ever needed a *distinct* per-activity tap action — the closest precedent (the secondary now-playing bubble) is a physically separate overlay view with its own `.onTapGesture { onSecondaryTap() }`, not a variant of `wingsShape` itself. Giving the Update HUD a genuine "tap = trigger Sparkle install" action requires either (a) adding an optional tap-override parameter to `wingsShape`, or (b) building the Update wing without the shared helper. This is new interaction territory, not a restyle.

Additionally, a **pre-existing, unrelated latent bug** in `NotchWindowController.activityEnabled(_:)` (`NotchWindowController.swift:673-676`) will silently break both new activities' "default OFF" requirement unless the plan explicitly accounts for it (see Common Pitfalls, Pitfall 1 — this is the single highest-value finding in this research).

**Primary recommendation:** Build both HUDs by literally cloning `focusWings(for:)`/`osdWings(for:)`'s shape and `PowerSourceMonitor`/`OSDInterceptor`'s monitor-lifecycle skeleton, add the two new `IslandPresentation`/`ActiveTransient`/`TransientQueue` ranks exactly like Focus/OSD were added, fix `activityEnabled(_:)`'s default-value logic as part of this phase (not a follow-up), wire Caps Lock through the existing Accessibility-permission Settings-popover pattern, and give `wingsShape` an optional tap-override parameter for the Update HUD's distinct tap-to-install action.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Caps Lock key-state detection | Browser/Client-equivalent: AppKit event-monitor layer (`NSEvent.addGlobalMonitorForEvents`) | — | Pure OS input-event capture, same tier as `PowerSourceMonitor`/`OSDInterceptor` (IOKit/CGEventTap) |
| Caps Lock HUD render | SwiftUI view layer (`NotchPillView`) | — | Matches every existing wing; no new tier |
| Caps Lock enable/permission state | App-owned persistence (`ActivitySettings`/`UserDefaults`) + TCC (Accessibility) | Settings UI (`SettingsView`) | Mirrors Focus/OSD's opt-in + permission-popover pattern exactly |
| Update-available detection | Sparkle (`SPUUpdaterDelegate` callback) | — | Existing, unchanged trigger — this phase only adds a second signal off the same callback |
| Update HUD render | SwiftUI view layer (`NotchPillView`) | — | New wing, same tier as Charging/Focus/OSD |
| Update HUD tap-to-install action | AppKit/SwiftUI interaction layer (new tap-override wiring) | Sparkle (`updaterController.checkForUpdates` or equivalent) | Net-new interaction path; no existing wing has a non-universal tap action |
| Transient priority/queueing | Pure Foundation reducer (`IslandResolver.swift`) | — | Both HUDs are additive cases in the existing single arbiter, zero new tier |

## Standard Stack

No new third-party dependencies. Every capability this phase needs already ships in the existing stack:

| Framework | Purpose | Already used for |
|-----------|---------|-------------------|
| AppKit (`NSEvent`) | Global `.flagsChanged` monitor for Caps Lock | Net-new use in this codebase, but a stock, documented AppKit API — [CITED: developer.apple.com/library/archive/.../MonitoringEvents.html] |
| AppKit (`ApplicationServices`/`AXIsProcessTrusted`) | Accessibility-trust check gating the Caps Lock monitor | Already used by `OSDInterceptor.isAccessibilityTrusted` [VERIFIED: codebase, `Islet/Notch/OSDInterceptor.swift:46`] |
| Sparkle 2.x (`SUAppcastItem.displayVersionString`) | Version string for the Update HUD's trailing pill | Already integrated (`Islet/AppDelegate.swift`); `displayVersionString` confirmed via official Sparkle docs [CITED: sparkle-project.org/documentation/api-reference/Classes/SUAppcastItem.html] |
| SwiftUI (`wingsShape`, `NotchShape`, `matchedGeometryEffect`) | Wing rendering | Existing, reused verbatim |
| Foundation (`IslandPresentation`/`ActiveTransient`/`TransientQueue`) | Priority/queue logic | Existing, extended with 2 new cases |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` (locked by ROADMAP SC2) | `CGEventTap` at `.cghidEventTap` (the mechanism `OSDInterceptor` already uses) | CGEventTap requires a dedicated background run-loop/queue and manual `NSEvent(cgEvent:)` bridging (more code) but has an already-proven-working live-reconcile-without-relaunch story in this exact codebase (39-07/39-08). `NSEvent.addGlobalMonitorForEvents` is simpler to write but its live-vs-relaunch reconciliation behavior when Accessibility trust changes mid-session is unverified in this codebase (see Pitfall 3). Not a live decision to revisit — SC2 already locks the API — but worth a short on-device spike given the uncertainty. |

## Package Legitimacy Audit

Not applicable — this phase introduces **zero new external packages** (no npm/pip/cargo/SPM additions). Every API used (`NSEvent`, `AXIsProcessTrusted`, `SUAppcastItem`) ships in an already-integrated framework (AppKit, ApplicationServices, Sparkle 2.x). Skip the slopcheck/registry-verification gate.

## Architecture Patterns

### System Architecture Diagram

```
                         ┌─────────────────────────────┐
                         │   NSEvent global monitor     │
   Caps Lock key press → │  (.flagsChanged, gated on   │
                         │   AXIsProcessTrusted())      │──┐
                         └─────────────────────────────┘  │
                                                            │  onChange(isCapsLockOn)
                         ┌─────────────────────────────┐  │
  Sparkle finds update → │ SPUUpdaterDelegate callback  │  │
                         │  .didFindValidUpdate(item)   │──┼──┐
                         └─────────────────────────────┘  │  │
                                                            ▼  ▼
                                              ┌───────────────────────────┐
                                              │ NotchWindowController      │
                                              │  handleCapsLockChange(_:)  │
                                              │  handleUpdateAvailable(_:) │
                                              └───────────────┬───────────┘
                                                               │ enqueue/preempt(.capsLock/.update)
                                                               ▼
                                              ┌───────────────────────────┐
                                              │      TransientQueue        │
                                              │  head / pending (max 2)    │
                                              └───────────────┬───────────┘
                                                               │ transientQueue.head
                                                               ▼
                                              ┌───────────────────────────┐
                                              │   resolve(...) reducer     │
                                              │ (IslandResolver.swift)     │──→ IslandPresentation
                                              └───────────────┬───────────┘         (.capsLock/.update,
                                                               │                     collapsed-only)
                                                               ▼
                                              ┌───────────────────────────┐
                                              │      NotchPillView         │
                                              │  capsLockWings(for:) /     │
                                              │  updateWings(for:)         │──→ rendered wing
                                              └───────────────────────────┘
```

### Recommended Project Structure

No new files are strictly required — every precedent (Focus, OSD) added its view/model/monitor code inline in the existing files:

```
Islet/Notch/
├── NotchPillView.swift        # + capsLockWings(for:), updateWings(for:)
├── IslandResolver.swift       # + 2 IslandPresentation/ActiveTransient cases, resolve() branches
├── NotchWindowController.swift# + handleCapsLockChange/handleUpdateAvailable, CapsLockMonitor ownership
├── CapsLockMonitor.swift      # NEW — mirrors PowerSourceMonitor's start()/stop()/onChange skeleton
Islet/
├── ActivitySettings.swift     # + updateHudKey (capsLockKey already exists)
├── SettingsView.swift         # + updateHudEnabled @AppStorage, updateHud ActivityCardData, capsLock onOptionsTap wiring
├── AppDelegate.swift          # didFindValidUpdate gains a 2nd signal call alongside updateDotView unhide
```

### Pattern 1: The Wings Shape (visual template — copy exactly)

**What:** `wingsShape(leftWidth:rightWidth:content:)` is the ONE shared helper every collapsed transient wing renders through: flat `NotchShape` (12pt top / 6pt bottom radius), `.matchedGeometryEffect(id: "island")`, fixed height `wingsSize.height` (32pt), `liquidGlassEffectLayer` overlay, and a baked-in `.onTapGesture { onClick() }`.
**When to use:** Every new collapsed wing (Caps Lock, Update) should call this helper exactly like `focusWings(for:)` does — icon-only or icon+label left flank, `Spacer()`, trailing content right flank.
**Example (Focus wing, the closest structural precedent for Caps Lock since Focus also always shows icon+label):**
```swift
// Source: Islet/Notch/NotchPillView.swift:2588-2612 (verbatim, elided)
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: 160) {
        HStack(spacing: 0) {
            Image(systemName: "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(.leading, 14)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("On").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            }
            .padding(.trailing, 20)
        }
    }
}
```
Caps Lock's `capsLockWings(for:)` should follow this exact shape, but with an icon+label on **both** left AND right (D-03: both the icon and "Caps Lock On"/"Caps Lock Off" text visible in both states — unlike Focus, which has icon-only-left).

### Pattern 2: `wingsShape` Needs a Tap-Override Parameter (net-new, not a copy)

**What:** `wingsShape`'s hardcoded `.onTapGesture { onClick() }` (`NotchPillView.swift:2347`) means every existing wing's tap always expands to Home — there is no existing per-wing tap customization.
**When to use:** The Update HUD's tap-to-install action needs a DIFFERENT effect (trigger Sparkle's install flow, not expand-to-Home).
**Recommended approach:** Add an optional `onTap: (() -> Void)? = nil` parameter to `wingsShape`, defaulting to the existing `onClick()` behavior when `nil` so every other caller (Charging/Device/Focus/OSD) is unaffected:
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    onTap: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
) -> some View {
    // ...unchanged body...
    .onTapGesture { (onTap ?? onClick)() }
}
```
This is the smallest change that satisfies D-04's tap-to-install ask without touching any of the 4 existing call sites' behavior.

### Pattern 3: The Monitor Lifecycle Skeleton (`PowerSourceMonitor`/`OSDInterceptor`)

**What:** Every OS-level event source in this codebase follows the same shape: a small `@MainActor` (or tap-queue-isolated) class with `init(onChange:)`, idempotent `start()`/`stop()`, `nonisolated(unsafe)` state for C-callback interop, and ownership by `NotchWindowController` (`private var xMonitor: XMonitor?`, guarded `guard xMonitor == nil else { return }` start, `.stop()` in `deinit`).
**When to use:** The new `CapsLockMonitor` (`NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`) should follow this skeleton.
**Example — the closest actual precedent for the Accessibility-gating half is `OSDInterceptor`, not `PowerSourceMonitor`** (`PowerSourceMonitor` needs no permission at all):
```swift
// Source: Islet/Notch/OSDInterceptor.swift:43-46, 102-106 (verbatim)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

private func desiredMode() -> TapMode {
    (suppressionArmed() && Self.isAccessibilityTrusted) ? .detectAndSuppress : .detectOnly
}
```
`CapsLockMonitor` should gate on `AXIsProcessTrusted()` the same way, and `NotchWindowController` should reuse the exact same Settings-popover pattern (`osdPermissionExplanationView`, deep-linking to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`) for Caps Lock's `onOptionsTap`.

### Pattern 4: Adding a New Rank to `IslandPresentation`/`ActiveTransient`/`TransientQueue` (mechanical, proven twice already — Focus Phase 38, OSD Phase 39)

Four edit sites, each with an exact existing precedent to mirror:

1. **`IslandPresentation`/`ActiveTransient` enum cases** (`IslandResolver.swift:99-118`):
```swift
// mirrors: case osd(OSDActivity) // rank 4 transient, collapsed-only (D-11)
case capsLock(CapsLockActivity)   // Phase 60 / CAPS-01: rank 5 transient, collapsed-only
case updateAvailable(UpdateActivity) // Phase 60 / UPDATE-01: rank 6 transient, collapsed-only
```
2. **`resolve()`'s transient switch** (`IslandResolver.swift:163-171`) — add, in the SAME shape as the existing `.focus`/`.osd` collapsed-only branches:
```swift
case .capsLock(let c) where !isExpanded: return .capsLock(c)
case .capsLock: break   // expanded — falls through unmodified
case .updateAvailable(let u) where !isExpanded: return .updateAvailable(u)
case .updateAvailable: break
```
3. **`ActiveTransient.isPersistent`** (`IslandResolver.swift:120-124`) — leave both OUT of the `isPersistent` true-case (they self-elapse via the shared ~3s timer, or a shorter one mirroring OSD's `osdActivityDuration` if a briefer ~1-2s window is wanted per CAPS-01's "auto-dismissing after ~1-2s").
4. **Controller-side preempt/enqueue** (`NotchWindowController.swift` — `handleFocusChange`/`handleOSDKeyPress` are the two shapes to mirror): since both new activities rank BELOW Focus (rank 3) and OSD (rank 4), they must mirror OSD's exact "preempt Focus if it's head, else enqueue" shape — **never preempt Charging/Device/Focus/OSD themselves** (they only need to unstick the one non-self-elapsing persistent transient, Focus):
```swift
// mirrors handleOSDKeyPress's enqueue/preempt branch (NotchWindowController.swift:2184-2190)
if case .focus = transientQueue.head {
    changed = transientQueue.preempt(.capsLock(activity))
} else {
    changed = transientQueue.enqueue(.capsLock(activity))
}
```

### Anti-Patterns to Avoid
- **Renumbering existing named ranks.** The convention (Phase 59's own SC5 comment block, `IslandResolver.swift:82-99`) is additive named-comment ranks, never renumbering 1-4.
- **Calling `AXIsProcessTrustedWithOptions(prompt: true)` anywhere in-app.** This codebase's established convention (OSD/Focus) is deep-link-to-System-Settings only, never an in-process re-prompt.
- **Assuming `activityEnabled(_:)` is safe to reuse as-is** for either new key without first checking/fixing its default-value logic (see Pitfall 1).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Collapsed wing shape/morph | A new `NotchShape`/`matchedGeometryEffect` variant | `wingsShape(leftWidth:rightWidth:content:)` | Identical visual language every other wing already uses; a second shape helper would desync from future tuning (39-07's own lesson) |
| Priority/queueing | A second priority system alongside `TransientQueue` | Add 2 more `ActiveTransient` cases + resolver branches | `TransientQueue`/`resolve()` is already the single arbiter (D-05, Phase 6); a parallel mechanism would violate that invariant immediately |
| Accessibility permission check/UI | A new permission-explanation view or a new TCC prompt path | `OSDInterceptor.isAccessibilityTrusted` + the existing `osdPermissionExplanationView`-style popover pattern | One System Settings pane (Accessibility) already gates OSD; Caps Lock needs the exact same one — a second, differently-worded popover for the same permission would be confusing and redundant |
| Version-number formatting | A custom SemVer parser | `SUAppcastItem.displayVersionString` (already the human-readable string Sparkle computes) | Sparkle already resolves `CFBundleShortVersionString` correctly; re-deriving it risks a mismatch with what Sparkle's own update dialog shows |

**Key insight:** Every piece this phase needs (shape, queue, permission-gate pattern, version string) already exists somewhere in this codebase or framework — the work is disciplined reuse across 4-5 files, not new architecture.

## Common Pitfalls

### Pitfall 1 (HIGHEST VALUE FINDING): `activityEnabled(_:)`'s hardcoded default breaks "default OFF" for any new key
**What goes wrong:** `NotchWindowController.activityEnabled(_:)` (`NotchWindowController.swift:673-676`) is:
```swift
private func activityEnabled(_ key: String) -> Bool {
    let defaultValue = (key == ActivitySettings.focusKey) ? false : true
    return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
}
```
This special-cases exactly ONE key (`focusKey`) as defaulting to `false`; every other key — including `osdSuppressionKey` (already declared `false` in `SettingsView`) and both of this phase's new keys (`capsLockKey`, and the new `updateHudKey`) — falls through to `defaultValue = true` whenever `UserDefaults.standard.object(forKey:)` returns `nil` (i.e., before SwiftUI's `@AppStorage` has ever WRITTEN a value for that key, which only happens on first user interaction with the toggle, not on mere declaration).
**Why it happens:** `@AppStorage(key) var x = false` does not eagerly write `false` into `UserDefaults` — the SwiftUI-side default and this controller-side helper's fallback are two independently-hardcoded locations (mirrors this codebase's own documented pattern for `MaterialStyle`'s two independent default locations), and this one was never updated when Phase 59 added 8 new false-default keys.
**How to avoid:** Fix `activityEnabled(_:)` as part of this phase's task list (not deferred) — e.g., invert to an explicit `defaultsToFalseKeys: Set<String>` membership check covering `focusKey`, `osdSuppressionKey`, and every Phase 59 key (`capsLockKey`, `downloadProgressKey`, `menuBarOverflowKey`, `timerKey`, `meetingHUDKey`, `quickNotesKey`, `quickActionsKey`, `codingProgressKey`, plus this phase's new `updateHudKey`), OR seed real defaults at launch via `UserDefaults.standard.register(defaults:)`. Either fix generalizes correctly for Phases 61-67 too, which reuse the same 8 keys.
**Warning signs:** A fresh install (or a clean-TCC-state test) shows the Caps Lock or Update HUD firing/visible before the user has ever opened Settings and explicitly enabled it — directly contradicting SETTINGS-05 ("every new Live Activity... defaults OFF") and CONTEXT.md's own Phase Boundary framing ("both default OFF").

### Pitfall 2: `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` silently does nothing without Accessibility trust
**What goes wrong:** Without the app being Accessibility-trusted, the global monitor installs successfully (no error) but simply never receives `.flagsChanged` events — CAPS-01 would appear "built but broken" with no crash or log to explain why.
**Why it happens:** [CITED: developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html] — "[a global event monitor] may only monitor key events if accessibility is enabled or if the application is trusted for accessibility." `flagsChanged` (modifier/Caps Lock state) is a key event type, same bucket as `keyDown`/`keyUp`.
**How to avoid:** Gate `CapsLockMonitor`'s effective "armed" state on `AXIsProcessTrusted()` exactly like `OSDInterceptor.desiredMode()` does; add the Settings `onOptionsTap` popover + deep-link for Caps Lock's card (currently `nil`, `SettingsView.swift:197`); do NOT ship this without a Settings-side permission affordance.
**Warning signs:** On-device testing on a machine that has never granted Islet Accessibility access (a real first-run scenario) — Caps Lock toggling produces no HUD at all.

### Pitfall 3 (flagged, unresolved — recommend a short spike): unverified live-reconcile vs. relaunch-required behavior for `NSEvent` global monitors
**What goes wrong:** `OSDInterceptor`'s CGEventTap-based approach has a PROVEN, working `reconcileMode()` health-check timer that live-upgrades from `.detectOnly` to `.detectAndSuppress` the moment Accessibility is granted mid-session, no relaunch needed (39-08 finding). It is genuinely unclear whether a plain `NSEvent.addGlobalMonitorForEvents` monitor behaves the same way, or whether (per some community reports) the process needs to be relaunched after Accessibility is granted for event delivery to actually start. This codebase has zero precedent to check against (no prior `NSEvent` global monitor exists).
**Why it happens:** SC2 locks the API to `NSEvent.addGlobalMonitorForEvents`, a different mechanism from the one this codebase has already empirically proven (CGEventTap). The behaviors may differ.
**How to avoid:** Treat "does toggling Accessibility permission mid-session (without relaunching Islet) make the Caps Lock monitor start firing?" as an explicit on-device verification step in the plan, not an assumption. If it does NOT reconcile live, the mitigation is simple (a poll timer that tears down and reinstalls the monitor, mirroring `reconcileMode()`'s shape) but must be planned for, not discovered mid-execution.
**Warning signs:** Granting Accessibility to Islet mid-session and toggling Caps Lock produces no HUD until the app is quit/relaunched.

### Pitfall 4: Update HUD's tap target risks the exact click-through bug class Phase 40 fled from
**What goes wrong:** Phase 40's original collapsed-pill update badge was abandoned specifically because `NotchWindowController.hotZone` (sized to the small collapsed-pill/notch-cutout frame) did not reliably cover the badge's actual on-screen tap position, so taps silently passed through to whatever was behind the app (`40-03-SUMMARY.md`). Phase 42's later fix (`collapsedInteractiveZone()`, `NotchWindowController.swift:1476-1498`) only special-cases the secondary now-playing bubble and the idle hover-preview widening — it does **not** generically widen for every wing's actual rendered width. Whether Charging/Focus/OSD wings' taps currently work correctly because `hotZone`/`collapsedFrame` already track the presentation's real rendered frame (via `positionAndShow()`'s separate `wingsFrame(collapsed:wingsSize:)` computation) or for some other reason was not fully traced in this session — but the Update HUD is the first NEW wing since the Phase 40 bug was root-caused, and its tap target is a genuinely NEW interactive affordance (tap-to-install), unlike Charging/Focus/OSD's universal "tap = expand" (which happens to be forgiving of small hit-test misses since any tap on the general pill area does the same thing).
**Why it happens:** The click-through geometry (`hotZone`/`collapsedInteractiveZone()`) and the rendered wing geometry (`wingsFrame`) are computed by two different code paths that must stay in sync; Phase 40's bug was exactly this desync.
**How to avoid:** Do NOT treat "wire a tap gesture on the Update wing" as low-risk just because `wingsShape` already has `.onTapGesture` machinery. Add an explicit on-device tap-target verification step to the plan (does tapping the rendered Update HUD's various regions reliably trigger the install action, with zero click-through, across repeated attempts) before considering UPDATE-01 done. This is a risk to actively verify, not a blocker to avoid building.
**Warning signs:** Tapping the Update HUD sometimes does nothing, or the click reaches an app/window behind Islet instead.

### Pitfall 5: The Update HUD Settings card + toggle does not exist yet — do not assume it is "just reading Phase 59's wiring"
**What goes wrong:** CONTEXT.md flags this as an open question; it is now resolved by direct inspection: `grep` of `Islet/ActivitySettings.swift` and `Islet/SettingsView.swift` for `update`/`Update` finds only `autoUpdateCheckKey`/`autoUpdateCheckEnabled` (Phase 40, gates Sparkle's background check) — there is no `updateHudKey`/`updateHudEnabled`/`ActivityCardData(id: "update"...)` anywhere. Building the Update HUD without first adding this key+card would leave it permanently on (no toggle) or crash-free but requirement-incomplete (SC4 requires "respects the Settings grid's on/off toggle").
**How to avoid:** Add `static let updateHudKey = "activity.updateHud"` to `ActivitySettings.swift` (mirroring the Phase 59 comment block's "8 new keys" convention — this becomes the 9th), a new `@AppStorage(ActivitySettings.updateHudKey) private var updateHudEnabled = false` in `SettingsView.swift`, and a new `ActivityCardData(id: "update", ...)` entry in `systemHUDCards` (alongside `capsLock`/`downloadProgress`/`menuBarOverflow`).

## Code Examples

### Existing `wings(for:)` — the visual template (verbatim, for reference)
```swift
// Source: Islet/Notch/NotchPillView.swift:2355-2378
private func wings(for activity: ChargingActivity) -> some View {
    // ...
    return wingsShape(
        leftWidth: isCharging ? Self.wingsLabelWidth / 2 : Self.wingsSize.width / 2,
        rightWidth: Self.wingsSize.width / 2
    ) {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))
                if isCharging {
                    Text("Charging").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
            }
            .padding(.leading, 12)
            Spacer()
            BatteryIndicator(level: percent, accent: chargingAccent)
                .padding(.trailing, 14)
        }
    }
}
```

### `TransientQueue`'s enqueue/preempt/advance (verbatim — the exact mechanics new handlers must call)
```swift
// Source: Islet/Notch/IslandResolver.swift:329-386
mutating func enqueue(_ t: ActiveTransient) -> Bool {
    if head == nil { head = t; return true }
    if head == t || pending.contains(t) { return false }
    pending.append(t)
    if pending.count > maxDepth { pending.removeFirst() }
    return false
}

mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}
```
Note: `preempt` only special-cases `.focus` as the head being displaced — it is NOT a generic "higher rank always wins" mechanism. New handlers for Caps Lock/Update must call `preempt` only when `head` is `.focus` (mirroring OSD exactly), never when head is `.osd`/`.charging`/`.device` (those outrank Caps Lock/Update and should naturally win by simply not being preempted).

### Sparkle's version string (official API, confirmed)
```swift
// SUAppcastItem.displayVersionString: String { get } — [CITED: sparkle-project.org]
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateDotView?.isHidden = false
        // New second signal for this phase:
        notchController?.handleUpdateAvailable(version: item.displayVersionString)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ROADMAP.md's "reskin the existing update HUD" wording | There is no existing island HUD — UPDATE-01 is new-build | Phase 40 (2026-07-18), superseded by D-01 | Plan must NOT search for/attempt to modify deleted `UpdateAvailableState.swift` — treat as greenfield |
| Collapsed-pill badge for update-available | Menu-bar status-item red dot (kept, unchanged) | Phase 40 (commit `30d9f82`) | The new island HUD is additive alongside the dot, not a replacement (D-02) |

**Deprecated/outdated:** `Islet/Notch/UpdateAvailableState.swift` — deleted in Phase 40, do not resurrect or reference.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` behaves identically to `keyDown`/`keyUp` with respect to Accessibility-trust gating (per general Apple docs language, not a `flagsChanged`-specific statement) | Common Pitfalls, Pitfall 2 | If `flagsChanged` is actually exempt (unlikely per docs wording, but not 100% explicitly confirmed for this exact event type), the permission-gating work is unnecessary extra scope — low risk either way since gating defensively is harmless if untrue |
| A2 | An `NSEvent`-based global monitor's live-reconcile behavior when Accessibility trust changes mid-session (vs. requiring relaunch) is unverified in this specific codebase/macOS version | Common Pitfalls, Pitfall 3 | If it requires a relaunch and the plan doesn't build a fallback poll/reinstall mechanism, CAPS-01 could silently fail to activate for users who grant permission mid-session without relaunching |
| A3 | Whether Charging/Device/Focus/OSD wings' tap targets currently work correctly because of some geometry-sync mechanism not fully traced this session (vs. coincidentally being forgiving of small hit-test gaps since their tap action is always the same universal expand) | Common Pitfalls, Pitfall 4 | If the current wings' tap-correctness is coincidental rather than structural, the Update HUD's genuinely distinct tap-to-install action is at HIGHER risk than assumed, not lower |

## Open Questions

1. **Does `flagsChanged`, specifically, require Accessibility trust, or only `keyDown`/`keyUp`?**
   - What we know: Apple's archived documentation states monitoring "key events" (unqualified) requires Accessibility trust for global monitors; `flagsChanged` is conventionally classified as a key event type in NSEvent's own type system.
   - What's unclear: No source found explicitly tests/confirms `flagsChanged` in isolation (some community sources hedge on this).
   - Recommendation: Build defensively assuming it IS gated (per Pitfall 2's plan); an on-device spike early in execution (Task 1, mirroring Phase 38/39's own spike-first precedent) will resolve this in minutes either way.

2. **Does an `NSEvent` global monitor need the process relaunched after Accessibility is granted, unlike this codebase's proven CGEventTap reconcile?**
   - What we know: `OSDInterceptor`'s CGEventTap-based approach reconciles live (39-08, proven). Some general community sources claim NSEvent-based Accessibility-gated features need a relaunch.
   - What's unclear: No direct precedent in this codebase for `NSEvent.addGlobalMonitorForEvents` specifically.
   - Recommendation: Verify on-device as part of Task 1's spike; if relaunch IS required, add a lightweight poll (mirroring `OSDInterceptor.healthCheckTimer`) that tears down/reinstalls the monitor, OR accept "grant Accessibility, relaunch Islet" as a documented one-time step (lower-effort fallback, consistent with this codebase's existing "Accessibility has no `requestAuthorization`-style re-request API" acknowledgment in `osdPermissionExplanationView`'s own comment).

3. **Exact relative rank order, Caps Lock (5) vs. Update (6)** — D-06, explicitly left to planner/Claude's discretion; either order is acceptable per CONTEXT.md.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Accessibility permission (`AXIsProcessTrusted`) | CAPS-01 (global `.flagsChanged` monitor) | Depends on end-user grant, not verifiable at research time | macOS TCC, current on all supported OS versions | Settings popover deep-links to System Settings' Accessibility pane (existing pattern); feature stays inert (no HUD) until granted, same graceful-degrade shape as OSD suppression |
| Sparkle 2.x (`SUAppcastItem`) | UPDATE-01 | Yes — already integrated (`Islet/AppDelegate.swift`, `import Sparkle`) | 2.x (already pinned in project, not re-verified this session — no version change needed) | — |
| Xcode / `xcodebuild` | Build verification | Yes (project already builds; environment untouched by this phase) | 16+ (per CLAUDE.md) | — |

**Missing dependencies with no fallback:** None — Accessibility permission has a documented, existing graceful-degrade path (feature silently inert, not a crash).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`IsletTests/`), `@testable import Islet` |
| Config file | Xcode scheme `Islet` (no standalone `.xctestplan` found) |
| Quick run command | Xcode `Cmd+U` (headless `xcodebuild test` is documented in this project to hang — see `PROJECT.md`; do NOT rely on scripted test execution) |
| Full suite command | Same — manual Cmd+U in Xcode is this project's only confirmed-working test-execution path |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAPS-01 | `resolve()` returns `.capsLock` when transient head is `.capsLock` and `!isExpanded`; falls through when expanded | unit (pure, mirrors `testChargingOutranksDeviceAndMedia`-style tests) | Cmd+U → `IslandResolverTests` | ❌ Wave 0 — add `testCapsLockCollapsedOnly`/`testCapsLockFallsThroughWhenExpanded` |
| CAPS-01 | `TransientQueue` preempts a standing `.focus` head for `.capsLock`, else enqueues | unit | Cmd+U → `IslandResolverTests` | ❌ Wave 0 |
| CAPS-01 | Accessibility-gated activation (global monitor fires only when trusted) | manual/on-device (cannot unit-test TCC state) | on-device spike/checkpoint | N/A — inherently manual, mirrors `OSDInterceptor`'s own untestable-by-XCTest precedent |
| UPDATE-01 | `resolve()` returns `.updateAvailable` when transient head is `.updateAvailable` and `!isExpanded` | unit | Cmd+U → `IslandResolverTests` | ❌ Wave 0 |
| UPDATE-01 | New `updateHudKey` toggle gates the HUD's activation (mirrors `ActivitySettingsTests`) | unit | Cmd+U → `ActivitySettingsTests` | ❌ Wave 0 |
| UPDATE-01 | Tap-to-install triggers the correct action, no click-through | manual/on-device | on-device checkpoint (mock appcast, mirroring Phase 40's own mock-feed test method) | N/A — inherently manual (window click-through cannot be XCTest-asserted, per this codebase's own established precedent) |

### Sampling Rate
- **Per task commit:** Cmd+U on the affected test class (`IslandResolverTests`, `ActivitySettingsTests`)
- **Per wave merge:** Full Cmd+U suite (all `IsletTests/*.swift`)
- **Phase gate:** Full suite green (aside from the 2 pre-existing unrelated `CalendarGlanceTests` failures noted in STATE.md Phase 52) plus on-device checkpoint approval before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/IslandResolverTests.swift` — add `testCapsLockCollapsedOnly`/`testCapsLockFallsThroughWhenExpanded`/`testUpdateAvailableCollapsedOnly`/`testUpdateAvailableFallsThroughWhenExpanded` (mirrors existing `testFocus*`/`testOSD*` naming convention already in the file)
- [ ] `IsletTests/ActivitySettingsTests.swift` — add coverage for the new `updateHudKey` default-false behavior (mirrors existing per-key tests)
- [ ] No framework install needed — XCTest already fully wired

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | N/A — no auth surface touched |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes (narrowly) | OS-level TCC gate (`AXIsProcessTrusted()`) — never bypass or attempt to force-prompt; always defer to the user's own System Settings grant, matching existing `OSDInterceptor`/Focus precedent |
| V5 Input Validation | Marginal | The only "input" is the OS-delivered `NSEvent`/`SUAppcastItem` — both are system-trusted sources, not user-supplied text; no injection surface |
| V6 Cryptography | No | N/A — Sparkle's own EdDSA update-signature verification is unchanged by this phase (out of scope, "trigger logic and Sparkle plumbing unchanged" per UPDATE-01) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-broad global keyboard monitoring (capturing more than Caps Lock state) | Information Disclosure | `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` only observes modifier-flag changes, never full keystrokes — scope the event mask narrowly and never widen it to `.keyDown`/`.keyUp` without a fresh privacy review |
| Silent permission-state assumption (feature "looks broken" instead of explaining why) | Denial of Service (to the user's understanding, not a security DoS) | Always pair the Accessibility-gated feature with the existing Settings-popover explanation pattern, never a silent no-op |

## Sources

### Primary (HIGH confidence)
- `Islet/Notch/NotchPillView.swift` (this repo) — `wingsShape`, `wings(for:)`, `focusWings(for:)`, `osdWings(for:)`, secondary-bubble tap precedent — read directly, lines cited throughout
- `Islet/Notch/IslandResolver.swift` (this repo) — `IslandPresentation`/`ActiveTransient`/`TransientQueue`/`resolve()` — read directly, lines cited throughout
- `Islet/Notch/NotchWindowController.swift` (this repo) — `activityEnabled(_:)`, `handleFocusChange`/`handleOSDKeyPress`, `collapsedInteractiveZone()`, `startOSDInterceptor()` — read directly, lines cited throughout
- `Islet/Notch/OSDInterceptor.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/BatteryIndicator.swift` (this repo) — monitor-lifecycle and styling precedents — read directly
- `Islet/AppDelegate.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift` (this repo) — Sparkle callback, existing/missing AppStorage keys — read directly, confirmed via grep that `updateHudKey` does not exist
- `.planning/milestones/v1.6-phases/40-update-available-hud-sparkle-integration/40-03-SUMMARY.md` (this repo) — click-through bug root cause, menu-bar-dot redesign rationale
- sparkle-project.org/documentation/api-reference/Classes/SUAppcastItem.html — `displayVersionString` property confirmed

### Secondary (MEDIUM confidence)
- developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html — Accessibility-trust requirement for global key-event monitors (archived but official Apple documentation; explicit quote captured)

### Tertiary (LOW confidence)
- General web search results (blog posts, forum threads) on whether `flagsChanged` specifically (vs. `keyDown`/`keyUp` generally) is Accessibility-gated, and whether NSEvent monitors need a relaunch to pick up a live Accessibility grant — flagged in Assumptions Log A1/A2, recommend on-device spike rather than trusting these sources further

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, every API already integrated or a stock, documented framework call
- Architecture: HIGH — every pattern (wings, resolver, queue, monitor lifecycle) verified directly against this exact codebase, not inferred
- Pitfalls: HIGH for Pitfalls 1/4/5 (verified directly via grep/read of live code); MEDIUM for Pitfalls 2/3 (Pitfall 2 is CITED against official-but-archived Apple docs; Pitfall 3 is an explicitly flagged open question recommending an on-device spike)

**Research date:** 2026-07-23
**Valid until:** ~30 days (stable native-macOS codebase; the one time-sensitive external fact — Sparkle's `displayVersionString` API — is a mature, unlikely-to-change public API)
