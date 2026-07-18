# Phase 38: Focus Mode HUD - Research

**Researched:** 2026-07-17
**Domain:** macOS Focus/DND detection (INFocusStatusCenter vs. Assertions.json+FDA) + `IslandResolver`/`TransientQueue` extension for a new non-self-dismissing transient class
**Confidence:** MEDIUM-HIGH on detection-path facts (cross-verified against Apple's own forum + docs + PITFALLS.md's Droppy-sourced findings); HIGH on the resolver/controller architecture findings (read directly from this repo's own source)

## Summary

This phase has two genuinely separate risks, and this research treats them separately because they were conflated in the phase's framing. **Risk A (detection):** neither candidate Focus-detection path is a clean win. `INFocusStatusCenter` is gated behind the **Communication Notifications capability** — a real Apple entitlement that requires the app to actually implement `INSendMessageIntent`/`INStartCallIntent`-style messaging/calling intents. Islet is not a communications app and has no legitimate way to add this capability, which means the spike's very first checkpoint (`requestAuthorization` even returning `.authorized`) is likely to fail structurally, not just empirically — this should collapse the spike to a fast no-go rather than a multi-day investigation. The `~/Library/DoNotDisturb/DB/Assertions.json` + Full Disk Access fallback is more likely to actually work (Droppy ships it today, per PITFALLS.md), but costs the user an unprompted, scary-sounding permission grant with zero programmatic TCC prompt.

**Risk B (architecture) — the more important finding of this research:** `TransientQueue`/`scheduleActivityDismiss()` in `NotchWindowController.swift` apply **one uniform 3-second auto-dismiss timer to every transient that becomes `head`**, with no per-category exception today. Focus is explicitly required (D-06) to persist for the **entire duration** Focus is active — hours, not 3 seconds. Wiring `.focus` into `ActiveTransient` "the same way Charging/Device are wired" without touching `scheduleActivityDismiss()` will silently auto-dismiss the Focus pill after 3 seconds and never bring it back (the queue has nothing else pending to advance to). This is a real, code-verified gap the planner must design around — it is the actual "new pipeline" work this phase is supposed to prove, more than the visual wing itself.

A second, related gap: `TransientQueue.enqueue()` is pure FIFO — a transient never preempts an already-showing head, it only queues behind it. D-08 requires Charging/Device to **interrupt** an already-showing Focus pill immediately, not wait behind it. Today's Charging/Device pair has never needed to preempt each other (both are brief, sequential, self-dismissing), so no preemption code exists to copy. This phase must add it.

**Primary recommendation:** Treat this phase as two independent deliverables. (1) Run the spike with `INFocusStatusCenter` demoted to "confirm-it's-a-dead-end-quickly" rather than the preferred path — budget most spike time on Assertions.json + FDA UX acceptability instead. (2) Design the resolver/controller change around three explicit facts: Focus is **non-self-dismissing** (no `activityDuration` timer), Focus **loses to Charging/Device on preemption** (new logic), and Focus **does not win the expanded branch** (a `where` guard in `resolve()`'s switch, cheap and precedented).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Focus/DND raw signal detection | API/Backend (system-framework glue, `FocusModeMonitor`) | — | Same tier as `PowerSourceMonitor`/`BluetoothMonitor` — thin, isolated system-call wrapper |
| Full Disk Access permission UX | AppKit (deep-link + explanation UI) | Settings (toggle + status subtitle) | `x-apple.systempreferences:` deep link is an `NSWorkspace.open` AppKit call; the toggle/subtitle is SwiftUI Settings |
| Focus on/off → collapsed pill | API/Backend (`IslandResolver`, pure) | SwiftUI (`NotchPillView` wing render) | Same tier split as Charging/Device today: pure resolver decides, view renders |
| Transient timing/preemption (persist-until-off, Charging/Device interrupt) | API/Backend (`NotchWindowController`, `TransientQueue`) | — | This is genuinely new controller logic, not resolver logic — `scheduleActivityDismiss()`/`enqueue()` live in the controller, not `IslandResolver.swift` |
| Settings toggle + permission status hint | SwiftUI (`SettingsView`, `ActivitySettings`) | — | Direct extension of the existing `@AppStorage` activity-toggle pattern |

## User Constraints (from CONTEXT.md)

<user_constraints>

### Locked Decisions

- **D-01:** The Focus Mode feature as a whole (regardless of which detection path the spike lands on) sits behind ONE Settings toggle, off by default — an opt-in feature, not something enabled automatically. Users who don't care about it never see any permission ask.
- **D-02:** Whatever authorization the winning detection path needs is only requested at the moment the user switches the Settings toggle on — not during onboarding, not lazily on first Focus trigger. This applies uniformly to BOTH paths: the lightweight `INFocusStatusCenter.requestAuthorization` TCC-style prompt (if that path wins the spike) and the manual Full Disk Access explanation+deep-link flow (if the `Assertions.json` fallback is needed). One consistent mental model for the user regardless of which technical path won.
- **D-03:** If Full Disk Access is the path needed, the in-app explanation (shown when the toggle is switched on) includes a deep link that opens System Settings → Privacy & Security → Full Disk Access directly, via the `x-apple.systempreferences:` URL scheme — not just text instructions to navigate there manually.
- **D-04:** If the user declines/never grants the needed permission, Islet accepts this silently — no re-ask, no nag, no periodic re-check popup. Mirrors the project's existing Calendar/Weather degrade convention (silent, no retry). The toggle stays on but the feature is inert.
- **D-05:** The Settings toggle shows a persistent status hint reflecting the REAL permission state — e.g. "Permission needed — tap to grant" vs. "Active" — not a bare on/off switch with no feedback. This is what makes D-04's silent-inertness acceptable: the user isn't left guessing why nothing happens.
- **D-06:** The Focus HUD is a persistent `ActiveTransient` state (same behavioral shape as Charging/Device today) — it shows "Focus On" for the entire duration Focus is active and dismisses the instant Focus turns off. NOT a brief toast like the song-change toast. This is deliberate: giving the new `ActiveTransient` case real state to arbitrate is the actual point of this phase (pipeline-proving), not a cosmetic detail.
- **D-07:** Unlike Charging/Device (which take over the ENTIRE expanded view — "transient wins even over expanded" in `IslandResolver`), Focus is scoped to **collapsed-pill-only** takeover. Hovering to expand the island while Focus is active works completely normally — Tray/Calendar/Weather/Now-Playing all remain accessible as usual; Focus state simply isn't shown once expanded. Rationale: Focus sessions can run for hours, and blocking the entire expanded island for that whole duration (as a literal Charging/Device-style full takeover would) is a real UX cost Charging/Device don't have (those are brief, self-limiting states). This is a genuinely new behavior class for `IslandResolver` — a transient that wins in the collapsed pill but does NOT participate in the `isExpanded` branch's transient-wins-over-expanded shortcut — not a resolver bypass (still routes through the resolver, per ROADMAP Success Criterion #4, just with a narrower win condition than the existing two transients).
- **D-08:** Priority: Charging/Device outrank Focus. If Focus is active and a Charging/Device event fires, Charging/Device wins the collapsed pill (interrupts Focus's pill); Focus's pill reappears automatically once Charging/Device clears, if Focus is still on. Mirrors the existing precedent of Now-Playing yielding to Charging/Device.
- **D-09:** "Focus Off" has no separate visible HUD moment — the "Focus On" pill simply disappears the instant Focus turns off (same pattern as Charging's wing disappearing on unplug, not a "Not Charging" pill). No toast-style "Focus Off" confirmation flash.
- **D-10:** Reuses Phase 36's established Droppy-pill wing language: LEFT = Focus icon (macOS's own moon-crescent Focus glyph) + "Focus" text label. RIGHT = a simple on/off status indicator. Visually consistent with the rest of the Phase 36 HUD restyle suite — no new visual language invented for this HUD.
- **D-11:** Icon/label color is FIXED, not accent-tinted — follows Phase 36's precedent for universal system-level states (Charging's bolt/battery) rather than the accent-tinted treatment used for Bluetooth's device glyph. Focus On should read consistently regardless of the user's chosen accent theme.
- **D-12:** If the spike finds NEITHER detection path viable/shippable (INFocusStatusCenter's boolean unreliable AND the Assertions.json/FDA path judged too invasive), HUD-05 is descoped cleanly — same clean-abandonment precedent as Phase 37: no Settings toggle shipped, no half-built UI, REQUIREMENTS.md updated to drop it. The phase's actual goal (proving the new-`ActiveTransient`-pipeline pattern once) is still considered achieved as long as the spike got far enough to build and validate the pipeline against whichever path showed real signal during the spike itself — the final ship/no-ship call on the user-facing feature is separate from the pipeline validation.

### Claude's Discretion

- Exact poll interval for the `Assertions.json` fallback path, if used (PITFALLS.md flags this as a tunable idle-CPU/responsiveness tradeoff — must stay well above the 0.1–0.5s range Droppy uses, per the project's existing timer-hygiene convention established for the Calendar countdown HUD's own pitfall).
- Exact SwiftUI mechanism for the new "collapsed-only, not expanded" resolver behavior (D-07) — e.g. a new field on `ActiveTransient`/a new resolver parameter distinguishing collapsed-scope vs. full-scope transients — planner's call on the cleanest way to express this without duplicating the existing switch-statement structure.
- Naming of the new `FocusActivity`/`FocusModeMonitor` types and the new `ActiveTransient` case.
- Whether the Settings toggle for Focus Mode HUD lives in the existing Theming/Activity-toggles section of Settings or gets its own row — implementation detail, not a product decision.

### Deferred Ideas (OUT OF SCOPE)

- **Named/labeled Focus Mode detection** ("Work Focus", "Sleep", etc.) — explicitly out of scope per REQUIREMENTS.md's own Out of Scope table; only revisit if a future spike finds a reliable read path beyond the legacy binary DND flag.
- **Re-checking/re-prompting for permission periodically** — considered and explicitly rejected (D-04) in favor of the silent-degrade convention; not something to build even as a future toggle.

</user_constraints>

## Phase Requirements

<phase_requirements>

| ID | Description | Research Support |
|----|-------------|------------------|
| HUD-05 | A Focus Mode HUD appears when the user toggles Focus/Do Not Disturb, showing generic on/off state only (named-mode detection not guaranteed available — see Out of Scope) | Detection-path guidance (Architecture Patterns §1), resolver scope mechanism (§2), Monitor pattern (§3), and the critical non-self-dismissing-transient pitfall (Common Pitfalls) below jointly cover everything needed to plan the spike-gated implementation |

</phase_requirements>

## Standard Stack

No new third-party packages. Everything needed is either an Apple system framework already reachable from an unsandboxed macOS app, or plain Foundation/FileManager code following this repo's existing Monitor pattern.

### Core

| Component | Source | Purpose | Why Standard |
|-----------|--------|---------|---------------|
| `Intents` framework (`INFocusStatusCenter`) | Apple system framework, macOS 12+ | Path A: generic authorized boolean Focus signal | Apple's only semi-public Focus API — but see gating caveat below |
| `~/Library/DoNotDisturb/DB/Assertions.json` + `FileManager`/`DispatchSourceTimer` polling | Undocumented file, no framework | Path B: fallback boolean Focus signal via `storeAssertionRecords` non-empty check | The only path that has actually shipped in a comparable app (Droppy) on current macOS |
| `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:...")!)` | AppKit, already used implicitly elsewhere in macOS apps (not yet in this codebase) | Deep link to System Settings → Privacy & Security → Full Disk Access (D-03) | Standard, documented URL-scheme mechanism; no better alternative exists post-Ventura |

### Package Legitimacy Audit

Not applicable — this phase adds zero new SwiftPM/CocoaPods/npm dependencies. Both detection paths use only Apple system frameworks (`Intents`, `Foundation`, `AppKit`) already linked or trivially linkable. Skip the slopcheck/registry-verification gate entirely; there is nothing to verify.

## Architecture Patterns

### 1. Detection paths — concrete, implementation-ready spike checklist

#### Path A: `INFocusStatusCenter` (Apple framework: `Intents`)

**API surface** [CITED: developer.apple.com/documentation/sirikit/infocusstatuscenter; developer.apple.com/forums/thread/682143]:
```swift
import Intents

// Singleton accessor
INFocusStatusCenter.default

// Current authorization state (an enum — .notDetermined / .denied / .authorized / .restricted,
// mirroring the shape of every other TCC-style Apple authorization enum; exact case names
// should be confirmed against Xcode's Quick Help at implementation time — the doc page itself
// renders via JS and did not yield the literal enum declaration to WebFetch during this research)
INFocusStatusCenter.default.authorizationStatus

// Request authorization — completion handler style, called ONLY when the user flips the
// Settings toggle on (D-02), never at launch/onboarding
INFocusStatusCenter.default.requestAuthorization { status in
    // status: INFocusStatusAuthorizationStatus
}

// The actual signal, valid only once authorizationStatus == .authorized
INFocusStatusCenter.default.focusStatus.isFocused   // Bool?
```

**The gating problem — this is the load-bearing fact the spike must check FIRST, before writing any polling code:**
An Apple engineer stated on the official developer forum [CITED: developer.apple.com/forums/thread/682143]: *"Focus Status will only be available to apps that have the Communication Notifications capability added in Xcode's Signing & Capabilities tab, which also adds the Communication Notification boolean YES to the target's .entitlements file."* A developer building a media (non-communication) app was explicitly told this capability would not be granted for that use case. Communication Notifications is not a checkbox — Apple's own guidance ties it to apps that actually implement `INSendMessageIntent`/`INStartCallIntent`-style messaging/calling intents (real calling/messaging apps, e.g. WhatsApp-style clients) [CITED: developer.apple.com/documentation/usernotifications/implementing-communication-notifications]. Islet has no messaging/calling feature and no legitimate basis to add this capability. `[ASSUMED]`: given this, `requestAuthorization` almost certainly resolves to `.denied` for Islet regardless of user action, making `focusStatus.isFocused` permanently unusable — but this is a **hypothesis to confirm on-device in ~5 minutes**, not a multi-day investigation.

There is a second, independent problem even if authorization somehow succeeded: a developer on the same thread reported KVO does not work on `focusStatus` and it is not `@objc dynamic` — the only workaround is polling [CITED: developer.apple.com/forums/thread/682143]. So even in the best case, `INFocusStatusCenter` buys nothing over Path B except (maybe) a real TCC-style prompt instead of a manual FDA grant — it does not remove the need to poll.

**Minimal spike (go/no-go in one file, ~15 lines):**
```swift
import Intents

func spikeFocusStatusCenter() {
    print("authorizationStatus before request:", INFocusStatusCenter.default.authorizationStatus)
    INFocusStatusCenter.default.requestAuthorization { status in
        print("requestAuthorization result:", status)
        if status == .authorized {
            print("focusStatus.isFocused:", INFocusStatusCenter.default.focusStatus.isFocused as Any)
        }
    }
}
```
**Go/no-go criterion:** if `requestAuthorization`'s completion status is anything other than `.authorized` on this dev machine (macOS 26/Tahoe) with no Communication Notifications capability added to the target, this path is dead — move directly to Path B or D-12 descope. Do not spend spike time trying to add the Communication Notifications capability speculatively; it requires real messaging/calling intent handlers Islet doesn't have and shouldn't fake to unlock an unrelated feature.

#### Path B: `~/Library/DoNotDisturb/DB/Assertions.json` + Full Disk Access

**File format** [MEDIUM confidence — cross-referenced across two independent community sources plus PITFALLS.md's direct read of Droppy's shipping source; CITED: gist.github.com/drewkerr/0f2b61ce34e2b9e3ce0ec6a92ab05c18]:
```json
{
  "data": [
    {
      "storeAssertionRecords": [
        {
          "assertionDetails": { "assertionDetailsModeIdentifier": "com.apple.focus.work" },
          "assertionStartDateTimestamp": 774822123.456
        }
      ]
    }
  ]
}
```
Detection logic: `data[0].storeAssertionRecords` non-empty ⇒ some Focus/DND mode is active. Empty array or absent key ⇒ Focus is off. **Named-mode detail exists** (`assertionDetailsModeIdentifier`, matchable against a separate `ModeConfigurations.json` for a human-readable name) but is explicitly out of scope for this phase (REQUIREMENTS.md Out of Scope table) — only the presence/absence of the array is needed.

**Defensive parsing note** [MEDIUM confidence, one source flagged this specifically for recent macOS]: on some macOS versions the `storeAssertionRecords` key can be transiently absent mid-transition, not just empty — PITFALLS.md's own Pitfall 2 already flags this ("a parse failure = 'no data yet', not 'Focus is off'"). Parse with `.get`-style optional chaining at every level; never force-unwrap; treat any decode failure as "no change, keep prior state" rather than "Focus is off."

**Full Disk Access mechanics:**
- No programmatic TCC prompt exists for Full Disk Access — confirmed by every source consulted, including PITFALLS.md's own prior research. The user must manually add the app in System Settings.
- Deep link (D-03) [MEDIUM confidence — the anchor name is the part most likely to shift across macOS versions; verify on-device during the spike]:
  ```swift
  NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!)
  ```
  An older, pre-Ventura anchor form (`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`) is reported as broken on modern macOS by one source — use the `com.apple.settings.PrivacySecurity.extension` form and confirm it actually lands on the Full Disk Access sub-pane (not just Privacy & Security's top level) on this project's own macOS 26/Tahoe dev machine before locking the string into code.
- No entitlement is needed to *request* FDA (unlike Accessibility's `.defaultTap`) — Islet is already unsandboxed (`Islet.entitlements` has no `com.apple.security.app-sandbox` key), so there's no sandbox-container mismatch to work around. FDA is purely a TCC database grant the user makes in System Settings; the app doesn't declare anything for it.
- **Verify on first read, not just first grant:** a fresh, ungranted install must not crash or spin. `FileManager.default.contents(atPath:)` returning `nil` (permission denied) must be treated identically to "file doesn't exist yet" — silently inert, matching D-04.

**Poll interval (Claude's Discretion, per CONTEXT.md):** Droppy uses 0.5s [CITED: PITFALLS.md Pitfall 2, sourced from Droppy/DNDManager.swift]. PITFALLS.md's own Technical Debt table caps this: "acceptable only if lookahead is capped and interval is ≥1s with tolerance; never sub-second." Recommend **2–3 seconds** via `DispatchSourceTimer` with a coalescing tolerance — Focus toggles are a deliberate human action (opening Control Center or a keyboard shortcut), not something needing sub-second responsiveness; a 2-3s worst-case detection lag is imperceptible for a HUD announcing "Focus On" for an hours-long session. Gate the timer to only run while the Settings toggle (D-01) is on AND Full Disk Access is granted — do not poll at all if either is false.

### 2. Resolver scope mechanism (D-07) — the "collapsed-only, not expanded" transient

The cleanest mechanism, given the existing `resolve(...)` structure (`IslandResolver.swift:90-140`), is a **`where`-guarded case in the existing switch**, not a new field/parameter threaded through the whole function signature. This is a one-line addition to an already-exhaustive switch, not a broad refactor:

```swift
// ActiveTransient gains a third case (naming at planner's discretion — .focus(FocusActivity) below):
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case focus(FocusActivity)
}

// resolve(...)'s existing switch — ADD one guarded case + one unguarded fallthrough case:
switch activeTransient {
case .charging(let a): return .charging(a)          // unchanged — wins collapsed AND expanded
case .device(let d):   return .device(d)             // unchanged — wins collapsed AND expanded
case .focus(let f) where !isExpanded: return .focus(f) // D-07: Focus wins ONLY when collapsed
case .focus: break                                    // D-07: expanded — fall through to normal
                                                       //   isExpanded branch below (Tray/Calendar/
                                                       //   Weather/NowPlaying resolve exactly as if
                                                       //   no transient were active)
case nil: break
}
```
This satisfies D-07 exactly: Focus still routes through the resolver (no bypass, per Pitfall 6's "no exceptions" rule and the phase's own Success Criterion #4), but the `where` guard is the ONE new conditional the whole phase needs at the resolver layer — everything below it (the `isExpanded` branch: `pendingDrop` / `selectedView == .calendar/.weather/.tray` / now-playing / home) is untouched, because when Focus doesn't win, `activeTransient` being `.focus` is simply irrelevant to the rest of `resolve()` (none of the existing branches read `activeTransient` again). No new parameter, no new field on `IslandPresentation`, no duplicated switch structure — matches the "cleanest way... without duplicating the existing switch-statement structure" ask in CONTEXT.md's discretion note.

**IslandPresentation** needs one new case: `.focus(FocusActivity)`, rendered in `NotchPillView.swift` via a new `focusWings(for:)` function following the exact same `wingsShape(...)` helper Charging/Device already use (see Code Examples below) — this is genuinely simple and low-risk; it's the transient-timing problem (§3 below) that carries the real risk.

### 3. `FocusModeMonitor` — following the existing Monitor-protocol pattern

`PowerSourceMonitor` and `BluetoothMonitor` are both `@MainActor final class`es that: (a) take an `onChange`/`onReading` closure in `init`, (b) expose `start()`/`stop()`, (c) do zero classification themselves (that lives in a pure sibling type — `PowerActivity`/`DeviceActivity`), and (d) are event-driven (IOKit/IOBluetooth notifications), never polling.

`FocusModeMonitor` breaks pattern (d) unavoidably — there is no push notification for Focus/DND state changes on either detection path (PITFALLS.md Pitfall 2 confirms no `NSDistributedNotificationCenter` event exists for this). It should still follow (a)/(b)/(c):

```swift
@MainActor
final class FocusModeMonitor {
    private var timer: DispatchSourceTimer?
    private let onChange: (Bool) -> Void   // true = Focus/DND active

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        // Guard: only runs if the Settings toggle is on AND (whichever path won the spike)
        // reports itself authorized/granted — checked by the CALLER before calling start(),
        // mirroring how PowerSourceMonitor/BluetoothMonitor are only started when their
        // respective ActivitySettings key is enabled (see NotchWindowController's existing
        // start/stop wiring for chargingKey/deviceKey).
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 2.0, leeway: .milliseconds(500))  // Claude's Discretion: 2s, coalescing leeway
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        // Whichever path won the spike: read Assertions.json OR INFocusStatusCenter.focusStatus.
        // Isolated behind this ONE function so a future macOS restricting either path further
        // is a one-file swap (PITFALLS.md's repeated "isolate behind one protocol" mitigation).
        onChange(currentFocusState())
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
```
A pure `FocusActivity` sibling type (mirroring `PowerActivity`/`DeviceActivity`) should own zero logic beyond the two states this phase actually needs (`.on`/`.off` — no named-mode payload, per REQUIREMENTS.md's Out of Scope), so it stays trivially unit-testable exactly like its siblings.

### 4. THE critical gap: `scheduleActivityDismiss()` applies a uniform 3s timer to every transient

**This is the single most important finding of this research — more important than which detection path wins the spike.** Read directly from `NotchWindowController.swift:1538-1563`:

```swift
private let activityDuration: TimeInterval = 3.0   // D-09 single tuning seed

private func scheduleActivityDismiss() {
    dismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        _ = self.transientQueue.advance()             // promote next pending or clear
        withAnimation(...) { self.syncActivityModels(); self.renderPresentation() }
        self.updateVisibility()
        if self.transientQueue.head != nil {
            self.scheduleActivityDismiss()            // re-arm the ~3s for the next transient
        }
    }
    dismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + activityDuration, execute: work)
}
```
This fires for **every** transient that becomes `transientQueue.head`, with no per-category branch. D-06 requires Focus to persist for the entire duration Focus is active (hours). Wiring `.focus` into `ActiveTransient` and calling `transientQueue.enqueue(.focus(...))` the same way Charging/Device are enqueued today will, unmodified, cause the Focus pill to **auto-dismiss after exactly 3 seconds** via this existing timer, then `advance()` clears the head (nothing is pending), and the pill never returns even though Focus is still on. This is not a hypothetical edge case — it is the literal, deterministic behavior of the code as it stands today.

**The fix must distinguish "self-dismissing" transients (Charging/Device) from "persists until told otherwise" transients (Focus).** The cleanest options, in order of how much they touch:

1. **A per-category branch in `scheduleActivityDismiss()`'s scheduling call site** — wherever Focus becomes head, do not call `scheduleActivityDismiss()` at all; instead let Focus persist until the monitor itself reports `.off`, at which point the controller calls `transientQueue.removeAll(where: { if case .focus = $0 { true } else { false } })` (this method already exists, built for exactly this "an activity is toggled off live" shape — see `IslandResolver.swift:255-265`'s doc comment, itself written for the Charging/Device disable-in-Settings case). This reuses existing machinery instead of inventing new machinery — recommended.
2. A computed `var isPersistent: Bool` on `ActiveTransient` (`true` only for `.focus`) that the controller checks before deciding whether to arm `scheduleActivityDismiss()` for a newly-promoted head. Slightly more explicit than (1) but touches more call sites (the dismiss-scheduling decision, and `advance()`'s "if head != nil, re-arm" branch which currently unconditionally re-arms).

Either way: **the planner must design an explicit "Focus does not participate in the 3s auto-dismiss cycle" mechanism as its own task**, verified with a dedicated unit test (e.g. "Focus remains head after `activityDuration` elapses with no Charging/Device event") — this is exactly the kind of thing that looks done (pill shows briefly) but isn't (pill vanishes after 3s in real usage) per the "Looks Done But Isn't" discipline.

### 5. THE second gap: `TransientQueue.enqueue()` never preempts an already-showing head

D-08 requires Charging/Device to **interrupt** an already-showing Focus pill immediately (not queue behind it and wait). Today's `enqueue()` is pure FIFO (`IslandResolver.swift:225-231`): if `head` is already occupied, the incoming transient is appended to `pending` and only shown once the current head's dismiss timer elapses and calls `advance()`. Charging/Device have never needed to preempt each other because both are already self-dismissing within ~3s — "queue behind and wait 3s" is imperceptible. Focus is different: since Focus (per §4) has **no** dismiss timer of its own, a Charging/Device transient arriving while Focus is head would sit in `pending` **forever** — `advance()` is never called because nothing ever triggers Focus's dismissal.

**Required new capability:** when a Charging/Device transient arrives while `head` is `.focus`, it must **preempt** — become the new head immediately, while pushing the displaced Focus transient to the **front** of `pending` (not appended to the back) so that when Charging/Device's own `scheduleActivityDismiss()` elapses and calls `advance()`, `pending.removeFirst()` naturally restores Focus as head again (satisfying "Focus's pill reappears automatically once Charging/Device clears" for free, once the preemption itself is written). Conversely, if Focus arrives while Charging/Device is already head, existing plain `enqueue()` behavior is already correct (Focus queues behind, gets promoted once Charging/Device's own timer elapses) — no change needed for that direction.

Recommend adding one new method to `TransientQueue`, e.g. `mutating func preempt(_ t: ActiveTransient) -> Bool` used only by the controller's Charging/Device enqueue call sites, guarded by `if case .focus = head`. This is additive (a new method, not a rewrite of `enqueue()`), keeping the existing Charging/Device-vs-Charging/Device dedup/bound behavior in `enqueue()` completely untouched.

### Recommended file-level integration points (for the planner's task breakdown)

```
FocusActivity.swift            (new, pure — mirrors PowerActivity.swift/DeviceActivity.swift)
FocusModeMonitor.swift          (new — mirrors PowerSourceMonitor.swift/BluetoothMonitor.swift)
IslandResolver.swift            (edit — new ActiveTransient case, new IslandPresentation case,
                                  the `where`-guarded switch case from §2, new TransientQueue.preempt())
NotchWindowController.swift     (edit — start/stop the monitor gated on the Settings key + granted
                                  permission, the non-self-dismissing wiring from §4, the
                                  preemption call site from §5, syncActivityModels() gains a
                                  `.focus` case)
NotchPillView.swift             (edit — new focusWings(for:) following wingsShape(...), D-10/D-11)
ActivitySettings.swift          (edit — new focusKey, permission-status enum/key for D-05)
SettingsView.swift              (edit — new Toggle + status-hint Text, D-01/D-05, explanation +
                                  deep-link UI for D-03 if FDA path wins)
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing of `Assertions.json` | A hand-rolled string-search/regex over the file | `JSONSerialization`/`Codable` with optional-chained access at every level | The file's shape can shift transiently mid-Focus-transition (PITFALLS.md); a real parser degrades to "no change" on a malformed read, a regex/substring search can silently misfire |
| Full Disk Access status detection | Polling `FileManager.isReadableFile(atPath:)` in a loop as a proxy for "granted" | Attempt the actual read and treat `nil`/thrown-error as "not granted" (same effective signal, no extra API surface) | `isReadableFile` and actual TCC-gated read access can disagree; the read attempt is the ground truth |
| Transient timing (§4/§5) | A bespoke standalone timer/state machine living only in `FocusModeMonitor` or the view layer | Extend `TransientQueue`/`scheduleActivityDismiss()`'s existing machinery (per-category dismiss gating + a `preempt()` method) | Pitfall 6 (PITFALLS.md): every new HUD type must route through `IslandResolver`/`TransientQueue`, no exceptions — a bespoke timer here reintroduces the exact scattered-priority-logic bug class Phase 6 was built to eliminate |

**Key insight:** the temptation on this phase is to hand-roll Focus's timing because it's "just one boolean, simpler than Charging/Device" — that's exactly backwards. Focus is timing-simpler (no percent, no glyph variants) but timing-*harder* (persists indefinitely, must be preemptible) than anything `TransientQueue` currently models. Resist the urge to special-case it in the view or controller outside the queue.

## Common Pitfalls

### Pitfall A: Spending spike time on `INFocusStatusCenter` before checking the Communication Notifications gate
**What goes wrong:** Building a full polling/authorization UI around `INFocusStatusCenter` before confirming `requestAuthorization` can ever return `.authorized` for a non-communications app.
**Why it happens:** The API name and shape look like exactly the right tool ("Focus Status Center" sounds generic), and forum discussion of the gating restriction is easy to miss without a targeted search.
**How to avoid:** Run the ~15-line spike in Architecture Patterns §1 FIRST, before writing any `FocusModeMonitor` code against this path. If `requestAuthorization` doesn't resolve to `.authorized` within the spike, move directly to Path B (or D-12 descope) without further investment.
**Warning signs:** `authorizationStatus` reports `.denied` immediately after `requestAuthorization`, with no System Settings prompt ever appearing to the user — the signature symptom of a capability-gated denial rather than a user decision.

### Pitfall B: Wiring `.focus` through the exact same code path as `.charging`/`.device` and assuming it "just works" (THE central risk of this phase)
**What goes wrong:** Per Architecture Patterns §4, the Focus pill silently vanishes after 3 seconds regardless of whether Focus is still on, because `scheduleActivityDismiss()`'s uniform timer doesn't know Focus is different.
**Why it happens:** The existing `ActiveTransient` cases are visually and structurally similar (an enum case, an `IslandPresentation` case, a wing view) — it's easy to pattern-match "add a case" without noticing the controller's timing model has a hidden uniform assumption baked in.
**How to avoid:** Write the "Focus outlives 3s with nothing else happening" unit/integration test FIRST (before or alongside the wing view), verifying it fails against a naive same-as-Charging implementation, then implement the non-self-dismissing wiring from §4 to make it pass.
**Warning signs:** On-device UAT: toggle Focus on, wait 5+ seconds with nothing else happening, watch the pill disappear even though Focus is still active in Control Center.

### Pitfall C: Charging/Device queuing behind an indefinitely-standing Focus pill instead of preempting it
**What goes wrong:** Per §5, if the preemption logic isn't added, a Charging/Device transient arriving while Focus is head sits in `pending` forever (since Focus never elapses to call `advance()`) — the charger gets plugged in but Islet shows nothing new at all.
**Why it happens:** This is the flip side of Pitfall B — even after fixing Focus's own non-self-dismissal, the *other* transients' arrival path still assumes "queue behind, wait for current head's timer" is always an acceptable delay, which was true only because every existing head-holder eventually times out.
**How to avoid:** Explicit test: enqueue Focus, then enqueue Charging — assert Charging becomes head **immediately** (not after any delay), and Focus is in `pending` at index 0 (not appended to the end) so it resumes the instant Charging's own dismiss fires.
**Warning signs:** On-device UAT: with Focus showing, plug in the charger — if the charging pill doesn't appear until an arbitrary delay (or never appears at all), the preemption path is missing.

### Pitfall D: `syncActivityModels()` and `resolve()`'s pattern matches becoming non-exhaustive after adding `.focus`
**What goes wrong:** `syncActivityModels()` (`NotchWindowController.swift:1568-1574`) switches on `transientQueue.head` with exactly `.charging`/`.device`/`nil` cases today — adding `.focus` to the `ActiveTransient` enum makes this switch (and any other exhaustive switch over `ActiveTransient` in the codebase) fail to compile until updated. This is a *good* thing (the compiler catches it), but the planner should budget an explicit task for "grep every exhaustive switch over `ActiveTransient`/`IslandPresentation` and update it" rather than discovering each one ad hoc mid-implementation.
**How to avoid:** `grep -rn "case .charging" Islet/` and `grep -rn "case .device" Islet/` before starting, to enumerate every call site that will need a `.focus` arm (resolver, `syncActivityModels`, `showsSwitcherRow` is unaffected since Focus never reaches the `isExpanded` branches that function checks — but confirm this explicitly during implementation, don't assume).
**Warning signs:** A build failure listing every non-exhaustive switch — treat this as a checklist, not a nuisance.

## Code Examples

### Charging wing pattern to mirror for `focusWings(for:)` (D-10/D-11)
```swift
// Source: Islet/Notch/NotchPillView.swift (existing wings(for:) for ChargingActivity)
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(
        leftWidth: Self.wingsLabelWidth / 2,   // D-10: icon + "Focus" label always shown (no
                                                 // dimmed/negative state — Focus Off has no pill at all, D-09)
        rightWidth: Self.wingsSize.width / 2
    ) {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")   // D-10: macOS's own moon-crescent Focus glyph
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)       // D-11: FIXED color, never accent-tinted
                Text("Focus")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 12)
            Spacer()
            // RIGHT: simple on/off status indicator (D-10) — a filled/dimmed dot or checkmark,
            // NOT the BatteryIndicator (that's Charging/Device-specific)
            Circle().fill(Color.green).frame(width: 8, height: 8)
                .padding(.trailing, 14)
        }
    }
}
```

### Full Disk Access deep link (D-03)
```swift
// Source: derived from Apple's documented x-apple.systempreferences: scheme
// (gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751); VERIFY the exact anchor
// resolves to the Full Disk Access sub-pane on this project's macOS 26/Tahoe dev machine
// before shipping — anchor names have shifted across macOS major versions before.
func openFullDiskAccessSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") else { return }
    NSWorkspace.shared.open(url)
}
```

### `removeAll(where:)` reuse for D-09 (Focus Off = silent disappearance)
```swift
// Source: Islet/Notch/IslandResolver.swift:260-265 (existing method, built for the Phase 6
// D-09 "disabled category's standing splash AND any queued copy must vanish at once" case —
// directly reusable for Focus turning off, no new TransientQueue method needed for THIS part).
transientQueue.removeAll { transient in
    if case .focus = transient { return true }
    return false
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `MRMediaRemote`-style direct `dlopen` for system state (the project's own prior pattern for Now Playing) | Isolate every fragile/private-surface integration behind one protocol/Monitor class | Established since Phase 4 (Now Playing) and reaffirmed by PITFALLS.md for this entire milestone | `FocusModeMonitor` should follow this convention from day one, not retrofit it later |
| `nowplaying-cli`/direct `MRMediaRemoteGetNowPlayingInfo` (broke on macOS 15.4) | N/A for Focus — no direct equivalent broke, but the general lesson (Apple restricts private-surface access over time) applies to Assertions.json too | Ongoing risk, not a past event for THIS specific file | Full Disk Access + an undocumented file is exactly the kind of surface a future macOS could restrict further — isolate it (already recommended above) |

**Deprecated/outdated:** none specific to this phase's detection paths — both `INFocusStatusCenter` and `Assertions.json` are current as of macOS 26/Tahoe (this project's own dev machine), per PITFALLS.md's 2026-07-15 research and this session's corroborating search.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `INFocusStatusCenter.requestAuthorization` will resolve to a non-`.authorized` status for Islet because it lacks (and cannot legitimately add) the Communication Notifications capability | Architecture Patterns §1 | If wrong (i.e., macOS 26 relaxed this gate, or a non-communications app can still get `.authorized` for the generic boolean), the spike would find Path A viable after all — LOW risk to verify (a 5-minute on-device spike settles it either way), but if the planner skips the spike and assumes this without checking, a viable simpler path could be missed |
| A2 | The `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles` anchor correctly opens the Full Disk Access sub-pane on macOS 26/Tahoe | Architecture Patterns §1 / Code Examples | If the anchor is stale for Tahoe, D-03's deep link opens the wrong pane or just Privacy & Security's top level — degrades to "slightly worse UX" (user has one extra click), not a functional break; verify on-device during implementation |
| A3 | `INFocusStatusAuthorizationStatus` has the conventional `.notDetermined`/`.denied`/`.authorized`/`.restricted` case shape | Architecture Patterns §1 | Low risk — if case names differ, this is caught immediately at compile time (Xcode autocomplete/Quick Help), not a silent runtime issue |
| A4 | `TransientQueue.preempt()` (a new method proposed in §5) is the right shape vs. some alternative (e.g. giving `enqueue()` itself a priority parameter) | Architecture Patterns §5 | If the planner prefers a different mechanism, the risk is purely stylistic/maintainability, not correctness — either approach can satisfy D-08 if implemented completely; flagged as an open design choice, not a locked recommendation |

**If this table is empty:** N/A — see above.

## Open Questions

1. **Does `INFocusStatusCenter` actually resolve to `.authorized` for a non-communications macOS app on macOS 26?**
   - What we know: An Apple engineer stated on the official forum that this capability is scoped to apps with Communication Notifications; a media-app developer was explicitly told no.
   - What's unclear: Whether this restriction has loosened by macOS 26 (the forum thread predates this project's OS), or whether the generic `isFocused` boolean (as opposed to per-mode detail) has a lighter authorization bar.
   - Recommendation: This is precisely what the phase's own on-device spike must confirm first — budget under an hour for this specific check before committing to Path B.

2. **Does the exact `x-apple.systempreferences` anchor for Full Disk Access still work unchanged on macOS 26/Tahoe?**
   - What we know: The anchor has changed at least once (pre-Ventura → post-Ventura form); community sources disagree slightly on the current exact string.
   - What's unclear: Whether `com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles` (the most recent form found) is stable on Tahoe specifically.
   - Recommendation: Verify with a one-line manual test (`open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"` from Terminal) during planning/execution, before wiring it into Swift code.

3. **Should `TransientQueue` gain a generic "persistent transient" concept (reusable for future indefinite-duration HUDs), or should Focus's non-self-dismissal be a one-off special case?**
   - What we know: This phase is explicitly framed as proving a reusable pipeline for Phase 39+; a generic mechanism would pay off sooner.
   - What's unclear: Whether Phase 39 (Volume/Brightness) or later phases actually need another indefinite-duration transient, or whether Focus is a one-off.
   - Recommendation: Planner's call — a `var isPersistent: Bool` computed property on `ActiveTransient` (Architecture Patterns §4, option 2) is the more reusable shape and is barely more code than the one-off `removeAll(where:)`-based approach; lean toward the reusable form given this phase's explicit pipeline-proving goal, but either satisfies HUD-05 itself.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `Intents` framework | Path A (`INFocusStatusCenter`) | ✓ (system framework, always present on macOS 12+) | macOS 26/Tahoe (dev machine) | N/A — availability of the *framework* isn't the risk; authorization is (see Open Question 1) |
| Full Disk Access grant | Path B | Unknown — must be checked fresh per install; the dev machine may already have FDA granted to other tools, which would MASK a fresh-install bug (PITFALLS.md's own warning sign) | — | Test explicitly on a state where Islet itself has never been granted FDA, not just "some tool has it" |
| `x-apple.systempreferences:` URL scheme | D-03 deep link | ✓ (standard macOS mechanism) | macOS 26/Tahoe | Fallback: plain text instructions to navigate manually if the deep link's anchor proves stale |

**Missing dependencies with no fallback:** none — both paths are reachable from this machine; the open question is authorization/grant outcome, not framework/tool absence.

**Missing dependencies with fallback:** Full Disk Access grant itself has no fallback (by design — D-04 says the feature goes silently inert without it, which IS the fallback).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `Islet.xcodeproj` (generated by `project.yml` via XcodeGen) — no separate test config |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (per project memory: `xcodebuild test` hangs because tests host the full `Islet.app`, which boots `NSPanel`/MediaRemote/IOBluetooth — use `build` as the automated gate, route actual test execution to manual Cmd-U in Xcode) |
| Full suite command | Manual Cmd-U in Xcode (per project memory `xcodebuild-test-headless-hang`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HUD-05 | `resolve()` returns `.focus` when Focus transient is active and NOT expanded | unit | Cmd-U → `IslandResolverTests` (new test methods) | ❌ Wave 0 — extend existing `IslandResolverTests.swift` |
| HUD-05 | `resolve()` does NOT return `.focus` when expanded — falls through to Tray/Calendar/Weather/Home normally | unit | Cmd-U → `IslandResolverTests` | ❌ Wave 0 |
| HUD-05 | Focus transient survives past `activityDuration` (3s) with no Charging/Device event (Pitfall B) | unit/integration | Cmd-U → new `NotchWindowController`-adjacent test or a `TransientQueue`-level test if the non-self-dismissal logic is expressed there | ❌ Wave 0 — this is the single most important new test this phase adds |
| HUD-05 | Charging/Device preempts an already-standing Focus head immediately; Focus resumes once Charging/Device clears (Pitfall C, D-08) | unit | Cmd-U → new `TransientQueue`/`IslandResolverTests` test | ❌ Wave 0 |
| HUD-05 | Focus Off (while head or while pending) removes it silently, no separate HUD moment (D-09) | unit | Cmd-U → exercise `removeAll(where:)` with a `.focus` predicate | ❌ Wave 0 (mirrors existing Charging/Device disable-in-Settings test if one exists — check `ActivitySettingsTests.swift`) |
| HUD-05 | Fresh install, FDA never granted (or `INFocusStatusCenter` denied) → no crash, no spin, feature silently inert | manual-only (justified: requires a real un-granted TCC state, not fabricatable in XCTest) | — | On-device UAT checkpoint |
| HUD-05 | Settings toggle shows correct status hint (D-05: "Permission needed" vs. "Active") | unit (pure string/state logic) + manual (visual) | Cmd-U → new test in `ActivitySettingsTests.swift` for the pure state→hint mapping function, if one is introduced | ❌ Wave 0 (only if the mapping is factored into a pure function — recommended, mirrors `nowPlayingHealthGate`'s shape) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-clean gate; per-project convention, not full test run)
- **Per wave merge:** Manual Cmd-U in Xcode for the full `IsletTests` suite, per project memory
- **Phase gate:** Full suite green (manual Cmd-U) + the on-device spike checkpoint (Path A/B go-no-go) + the fresh-install-no-FDA UAT checkpoint, before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] New test methods in `IsletTests/IslandResolverTests.swift` covering the `.focus` `where`-guard, the non-self-dismissal timing behavior, and the preemption behavior — no new test FILE needed, extend the existing one (mirrors how Charging/Device tests already live there)
- [ ] New test methods in `IsletTests/ActivitySettingsTests.swift` for the Focus toggle key + permission-status mapping, if a pure mapping function is introduced (recommended)
- [ ] No new test framework/config needed — `IsletTests` target already exists and is wired

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | N/A — no user auth in this app |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes (narrowly) | Full Disk Access is itself an OS-level access-control grant; Islet's job is only to request it correctly-scoped and degrade silently on denial (D-04) — no app-level access control to build |
| V5 Input Validation | Yes | `Assertions.json` is untrusted-shape external data (an Apple-internal file whose schema isn't a public contract) — parse defensively (optional-chained `Codable`/`JSONSerialization`, never force-unwrap), exactly as this codebase already does for `EKEvent.title` in `CalendarService.swift` |
| V6 Cryptography | No | N/A — no crypto in this feature |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Requesting Full Disk Access "just in case" broader than needed | Elevation of Privilege (over-broad grant) | Request/explain FDA specifically and only in the context of the Focus feature (already flagged in PITFALLS.md's Security Mistakes table); never request it at launch/onboarding (D-02 already enforces this) |
| Malformed/adversarial `Assertions.json` content causing a crash | Denial of Service | Defensive parsing (see Input Validation row above) — a malformed file must degrade to "no state change," never crash or spin |
| A revoked-mid-session FDA grant causing a naive retry-loop to hammer a now-inaccessible file | Denial of Service (self-inflicted) | Mirror the existing `CGEventTap` re-enable-loop safety lesson from PITFALLS.md's Security Mistakes table: check grant status before continuing to poll; stop cleanly (don't spin) if a read starts failing where it previously succeeded |

## Sources

### Primary (HIGH confidence)
- This repository's own source, read directly: `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchWindowController.swift` (lines ~1500-1600 specifically), `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift`, `Islet/ActivitySettings.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Notch/NotchPillView.swift`, `IsletTests/IslandResolverTests.swift`, `project.yml`, `Islet/Islet.entitlements` — the resolver/controller architecture findings (§4/§5, Pitfalls B/C/D) are derived entirely from this direct read, not from external sources.
- `.planning/research/PITFALLS.md` (v1.6, 2026-07-15) — Pitfall 2 (Focus/DND detection), Pitfall 6 (resolver-no-exceptions rule), Integration Gotchas / Technical Debt / Security Mistakes tables, itself sourced from a direct 2026 read of Droppy's shipping `DNDManager.swift`.

### Secondary (MEDIUM confidence)
- [developer.apple.com/forums/thread/682143](https://developer.apple.com/forums/thread/682143) — official Apple Developer Forums thread confirming `INFocusStatusCenter`'s Communication Notifications capability gate (Apple engineer's own reply) and the KVO/polling limitation.
- [developer.apple.com/documentation/usernotifications/implementing-communication-notifications](https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications) — confirms Communication Notifications' intended scope (real messaging/calling apps).
- [gist.github.com/drewkerr/0f2b61ce34e2b9e3ce0ec6a92ab05c18](https://gist.github.com/drewkerr/0f2b61ce34e2b9e3ce0ec6a92ab05c18) — community-maintained `Assertions.json` structure reference, cross-checked against PITFALLS.md's independent Droppy-source-derived description (both agree on `storeAssertionRecords` as the detection key).
- [gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751](https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751) — community-maintained `x-apple.systempreferences:` URL scheme reference for Full Disk Access/Accessibility/Bluetooth panes.

### Tertiary (LOW confidence)
- None used as the basis for a load-bearing claim in this document — all findings above were corroborated by at least one MEDIUM+ source or this repository's own code.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, both paths use only Apple system frameworks already reachable from this unsandboxed app.
- Architecture (resolver/timing gaps, §2/§4/§5): HIGH — read directly from this repository's own current source, not inferred.
- Architecture (detection-path API specifics): MEDIUM — cross-verified across 2+ independent sources per claim, but the exact `INFocusStatusAuthorizationStatus` case names and the exact FDA deep-link anchor string could not be pulled from Apple's own (JS-rendered) doc pages this session and should be confirmed on-device/in-Xcode during the spike.
- Pitfalls: HIGH for the resolver/timing pitfalls (code-verified); MEDIUM for the detection-path pitfalls (matches PITFALLS.md's own MEDIUM-HIGH rating, corroborated further this session).

**Research date:** 2026-07-17
**Valid until:** ~30 days for the resolver/architecture findings (stable, code-verified, won't drift). ~7-14 days for the `INFocusStatusCenter`/FDA-deep-link specifics (Apple has been known to adjust FDA anchor strings and Focus-related API scoping across point releases) — re-verify the exact anchor and authorization outcome on-device at execution time regardless of this document's age.
