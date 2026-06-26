# Pitfalls Research

**Domain:** Native macOS notch / "Dynamic Island" overlay utility (now-playing via private MediaRemote, charging & device activities, borderless overlay, direct-notarized distribution)
**Researched:** 2026-06-26
**Confidence:** HIGH on overlay-window, geometry, signing/notarization, permissions, and performance pitfalls (verified against Apple docs + real TheBoringNotch bug reports). MEDIUM-HIGH on MediaRemote (private API, fast-moving — verified current via the adapter project and 15.4 breakage reports, but Apple can change it again).

> This file assumes the chosen stack (Swift + SwiftUI in an `NSPanel`, `mediaremote-adapter`, IOKit power, IOBluetooth, direct-notarized) and the spine-first build order from `ARCHITECTURE.md`. It does **not** repeat the stack/architecture rationale — it covers what goes *wrong* and how to detect it early. Phase numbers refer to the suggested build order in `ARCHITECTURE.md` / `FEATURES.md` (0 = agent shell, 1 = empty island, 2 = geometry, 3 = hover/expand, 4 = Now Playing, 5 = charging, 6 = Bluetooth, 7 = priority resolver, 8 = settings/launch-at-login, then v1 ships).

---

## Critical Pitfalls

### Pitfall 1: Calling MediaRemote directly — silent `nil` on macOS 15.4+

**What goes wrong:**
The classic approach — `dlopen` `MediaRemote.framework` and call `MRMediaRemoteGetNowPlayingInfo` / register for now-playing notifications — returns `nil` and fires no events on macOS 15.4 and every release after (including macOS 26 Tahoe). The app compiles, runs, and shows *nothing* in Now Playing with no error. A beginner can lose days assuming their parsing code is broken when the API simply refused them.

**Why it happens:**
Since macOS 15.4, the `mediaremoted` daemon enforces an entitlement check: only processes whose bundle ID starts with `com.apple.` (Apple's own apps) are granted Now Playing access. A normal notarized app is not entitled, so the daemon denies it. Training data, old blog posts, and most Stack Overflow answers predate this and still show the direct `dlopen` recipe — which now fails silently.

**How to avoid:**
- Use **`mediaremote-adapter`** from day one (already the chosen stack). It runs `/usr/bin/perl` — which reports the entitled `com.apple.perl`-style bundle ID — to load a helper framework and stream Now Playing JSON over stdout.
- Bundle **three things**: `mediaremote-adapter.pl`, `MediaRemoteAdapter.framework` (bundled but **NOT linked** against your target — it is loaded by the perl process, not your app), and optionally the test client. Putting the framework in "Link Binary With Libraries" instead of just copying it into Resources is a common misconfiguration.
- Never write a code path that calls MediaRemote symbols inside your own process.

**Warning signs:**
- Now Playing view is empty while music plays, with no crash and no log output.
- The adapter subprocess exits immediately, or its stdout is empty.
- You find yourself reading old (pre-2025) tutorials that say "just link MediaRemote."

**Phase to address:**
Phase 4 (Now Playing). Flag at planning time so the adapter is the *only* approach ever attempted.

---

### Pitfall 2: Treating the MediaRemote adapter as permanent / not isolating it

**What goes wrong:**
Now Playing breaks after a macOS point release because Apple tightened the daemon again, or the adapter's "API may experience breaking changes across minor revisions" (the maintainer's own warning). If MediaRemote calls and JSON-parsing are smeared across SwiftUI views and the state object, the fix touches a dozen files and the beginner has no idea where to start.

**Why it happens:**
The whole mechanism is a private-API workaround on borrowed time. The convenience of "just read the track title here in the view" leaks the fragile dependency everywhere. There is no public, stable Now Playing API for third-party apps on macOS as of 2026 (tracked in feedback-assistant report #637 — still open).

**How to avoid:**
- Put **all** Now Playing behind one `NowPlayingService` protocol (already the architecture's rule). The rest of the app sees only clean `NowPlayingInfo` structs and command methods (`play()`, `pause()`, `next()`, `seek()`). Swapping the backend = editing one file.
- Add a **health check** at launch using the adapter's `test` command: exit code `0` = functional; any other code = broken. If it fails, show a graceful "Now Playing unavailable on this macOS version" state instead of an empty island.
- Pin a known-good adapter version; don't auto-bump it blindly. Re-test Now Playing after **every** macOS update (treat each macOS release as a regression event for this feature only).

**Warning signs:**
- The adapter `test` exit code is non-zero after a macOS update.
- Now Playing worked yesterday and is empty today with no code change — suspect a macOS update first.
- You see `MRMediaRemote`/JSON-parsing code outside `Services/NowPlaying/`.

**Phase to address:**
Phase 4 (build it isolated). Add the launch-time health check in Phase 4 and re-verify in Phase 8 before shipping. Note in the roadmap as a permanent maintenance line item.

---

### Pitfall 3: The island doesn't hide for full-screen apps (or hides the window-control bar)

**What goes wrong:**
You watch a movie or use a full-screen app and the black island floats on top of it, or — the inverse bug — when the island collapses in full-screen, the traffic-light window-control bar stays visible and never disappears. Both are *real, repeatedly reported* TheBoringNotch bugs (issues #396, #803, #426, #764). This is the single most common "looks done in a window, broken in real use" failure for notch apps.

**Why it happens:**
Full-screen apps occupy their own Space and (on a notch Mac) the menu-bar/notch region is normally black and unused in full-screen. An always-on-top panel with the wrong `collectionBehavior`/level keeps drawing there. Detecting "am I in a true full-screen app right now?" is non-trivial — there are multiple full-screen modes (native full-screen, QuickLook full-screen, video full-screen) and they don't all signal the same way.

**How to avoid:**
- Use `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` and window level `.statusBar` — but **also** actively observe full-screen state and hide/show the panel. Don't rely on collection behavior alone.
- Observe `NSWorkspace.shared.notificationCenter` active-app changes and the frontmost window's full-screen state; when a covering full-screen app is frontmost on the notch display, hide the panel; restore it when it isn't.
- Give the user a per-app or global "hide in full-screen" toggle (default: hide), because users disagree on the desired behavior.
- Test against: native full-screen apps, full-screen video (YouTube/IINA), QuickLook, and Mission Control.

**Warning signs:**
- The island is visible over a full-screen video.
- A ghost window-control bar lingers at the top after collapsing.
- It "works" only because you've only tested in windowed mode.

**Phase to address:**
Phase 1–2 (window + geometry) for the basic plumbing; harden full-screen handling explicitly in Phase 3 (hover/expand state machine) — do **not** defer it to "polish," it is a core correctness requirement.

---

### Pitfall 4: Island appears on the wrong display (multi-monitor / external display)

**What goes wrong:**
With an external monitor connected, the island renders on the external (notch-less) screen, or on the built-in screen but at the wrong coordinates, or disappears entirely when you close the lid (clamshell). TheBoringNotch issues #313 and #749 are exactly this: "notch displayed on the second screen," "not visible because it's on the second screen."

**Why it happens:**
`NSScreen.main` is the screen with the **key window / focus**, not the built-in notch display — so it changes as you move focus between monitors. Developers grab `NSScreen.main`, assume it's the notch laptop screen, and position there. Screen configuration also changes at runtime (plug/unplug monitor, clamshell, resolution change) and code that positions once at launch never recovers.

**How to avoid:**
- Find the notch display **explicitly**: iterate `NSScreen.screens`, pick the one whose `safeAreaInsets.top > 0` (that's the notch). Never trust `NSScreen.main` for placement.
- Recompute geometry and reposition on `NSApplication.didChangeScreenParametersNotification` (owned by `AppDelegate`/`NotchGeometry` per the architecture).
- Handle the **no-notch-screen-available** case (lid closed / external-only): hide the island rather than crash or float on the external display. (v1 targets notch Macs, but clamshell with an external monitor is a normal usage of a notch Mac.)

**Warning signs:**
- The island jumps screens when you click a window on the other monitor.
- It vanishes or mis-positions after plugging in a monitor or closing the lid.
- Your placement code references `NSScreen.main`.

**Phase to address:**
Phase 2 (geometry). Make "survives screen changes / external display / clamshell" an explicit Phase-2 success criterion, not an afterthought.

---

### Pitfall 5: Code signing / notarization failures on the first release (the `--deep` trap + un-notarizable nesting)

**What goes wrong:**
First notarization attempt is rejected, or the app launches fine on the dev machine but on someone else's Mac Gatekeeper says "app is damaged / can't be opened." For this app it's worse than average because of the **bundled, unsigned `MediaRemoteAdapter.framework` and the perl script** — embedded code that must be signed correctly or notarization fails / Gatekeeper kills it.

**Why it happens:**
- Hardened Runtime not enabled (notarization requires `--options runtime`).
- Using `codesign --deep` (widely copied from the internet, explicitly discouraged by Apple) — it signs nested code in the wrong order and with the wrong identity. You must sign **inside-out / bottom-up**: embedded frameworks first, then the app bundle.
- The app-specific password used for `notarytool` belongs to a different Apple ID than the one that owns the `Developer ID Application` certificate.
- Using the deprecated `altool` instead of `notarytool`.
- Forgetting to `stapler staple` the result, so the app fails Gatekeeper on machines that are offline or hit a slow notarization-ticket lookup.

**How to avoid:**
- Enable **Hardened Runtime** in the target's Signing & Capabilities.
- Sign **bottom-up**: sign `MediaRemoteAdapter.framework` (and any embedded binary) with `--options runtime --timestamp` first, then sign the `.app`. **Never** use `--deep`.
- Use `xcrun notarytool store-credentials` once, with an app-specific password generated under the **same** Apple ID that owns the Developer ID cert.
- `notarytool submit --wait`, then `xcrun stapler staple` the `.dmg`/`.app`.
- When notarization is rejected, read the JSON log (`notarytool log <submission-id>`) — it names the exact file/issue.
- For a beginner: script the whole sign→notarize→staple flow once and reuse it; don't run the commands by hand each time.

**Warning signs:**
- "The binary is not signed with a valid Developer ID certificate" or "code object is not signed at all" in the notary log (usually the embedded framework).
- App opens on your Mac but "is damaged" on a friend's Mac.
- You typed `--deep` anywhere.

**Phase to address:**
Phase 8 / pre-release. Do **one** full signing+notarization dry-run *before* any feature is finished (a "hello world" notarized build) so the toolchain is proven early — a beginner discovering signing problems on launch day is a classic disaster. Add a dedicated "first notarization spike" task in the roadmap.

---

### Pitfall 6: Polling the system instead of using event/notification sources (battery drain)

**What goes wrong:**
The app uses a repeating `Timer` to poll "is the charger plugged in?", "what's playing?", "is a device connected?" every second. CPU sits at a few percent constantly, the fans spin on a quiet desktop, battery drains, and reviewers call it a "battery hog" — the opposite of the "~0% CPU when idle" bar that Notchy and TheBoringNotch (<2% CPU) set. For a *menu-bar utility that runs all day*, this is reputation-killing.

**Why it happens:**
Polling is the obvious thing for a beginner ("just check repeatedly"). The correct push-based APIs (run-loop notification sources, registered callbacks) are less obvious and macOS-specific.

**How to avoid:**
- **Power:** use `IOPSNotificationCreateRunLoopSource` (fires on plug/unplug/level change) — do not poll `IOPSCopyPowerSourcesInfo` on a timer.
- **Bluetooth:** use `IOBluetoothDevice.register(forConnectNotifications:)` / per-device disconnect notifications — event-driven, no polling.
- **Now Playing:** the adapter **streams** updates over stdout; consume the stream, don't repeatedly invoke the perl command.
- The only legitimate timers are short, self-terminating ones (e.g. the ~3s transient-activity auto-collapse, or a user-facing countdown timer) — never a long-lived "watch the system" timer.
- Profile idle CPU with Activity Monitor / Instruments; target near-0% when the island is collapsed and nothing is happening.

**Warning signs:**
- Idle CPU > ~1% with the island collapsed.
- Energy Impact shows the app high in Activity Monitor's Energy tab.
- You wrote `Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)` to read system state.

**Phase to address:**
Each service phase (5 power, 6 Bluetooth) and Phase 4 (consume the adapter stream). Make "no long-lived polling timers; idle CPU ~0%" a success criterion for each.

---

## Moderate Pitfalls

### Pitfall 7: Click-through vs. interaction conflicts (you can't click the desktop, or you can't click the island)

**What goes wrong:**
Either the transparent panel swallows all clicks in the menu-bar region (you can't click the menu bar or desktop around the island), or the panel ignores mouse events entirely and you can't hover/click the island itself. The window also steals focus from the app you're using when clicked (because it wasn't made non-activating).

**Why it happens:**
A borderless panel is rectangular and opaque to the event system even when visually transparent. `ignoresMouseEvents` is all-or-nothing on the window. The morphing island changes size, so a fixed hit area is wrong half the time.

**How to avoid:**
- Use an `NSPanel` with `.nonactivatingPanel` style + `becomesKeyOnlyIfNeeded = true` so clicking the island never steals focus from the active app.
- Toggle `ignoresMouseEvents` by state: when collapsed/idle, only the small pill region should be interactive (let clicks pass through everywhere else); when expanded, the expanded frame is interactive. Drive this from `IslandState`.
- Keep the interactive hit area in lockstep with the animated frame — when the window resizes for the expanded view, the event region must resize too.

**Warning signs:**
- Clicking near the notch activates/deactivates other apps unexpectedly.
- You can't click the menu bar items behind/around the island.
- Hover doesn't trigger expansion, or the island is "dead" to clicks.

**Phase to address:**
Phase 3 (hover/expand + interaction). Test clicking *around* and *on* the island in both states.

---

### Pitfall 8: Retina / coordinate-math and notch-geometry mismatches

**What goes wrong:**
The island is a few points off-center over the physical notch, or its corner radius doesn't match the hardware notch, or it's mis-sized on different MacBook models. A verified real gotcha: on some models `safeAreaInsets.top` (e.g. 32) does **not** equal `menuBarHeight` (e.g. 36) — they're different quantities, and naive math that assumes they're equal mis-positions the panel.

**Why it happens:**
- AppKit's coordinate system is **bottom-left origin** (y grows upward), unlike most UI frameworks; off-by-the-screen-height errors are common.
- Notch width/corner radius differ across MacBook Air vs Pro (14"/16") models; hardcoding one model's numbers breaks others.
- Mixing points and pixels (Retina backing scale) when you shouldn't, or vice versa.
- Conflating menu-bar height with safe-area inset.

**How to avoid:**
- Derive the notch rectangle from `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` — the **gap between them is the real notch width** on *this* machine — instead of hardcoding pixel values per model.
- Use `safeAreaInsets.top > 0` only as the *"has a notch"* test, not as a layout constant; don't assume it equals menu-bar height.
- Work in AppKit points and respect the bottom-left origin; convert carefully when bridging to SwiftUI.
- Match the island's corner radius to the notch by deriving it from the detected geometry, not a magic number.

**Warning signs:**
- Island is visibly off-center or has a different corner radius than the notch.
- It looks right on your MacBook but a tester with a different model reports misalignment.
- Layout math subtracts/adds the wrong screen dimension and the island appears at the bottom.

**Phase to address:**
Phase 2 (geometry). If possible, sanity-check the math on at least one other MacBook model before relying on it.

---

### Pitfall 9: Permission prompts and TCC surprises (Accessibility, Bluetooth, Automation, "Background Activity")

**What goes wrong:**
- Features silently do nothing because a TCC permission was never granted (or was reset).
- An unexpected "App Background Activity" / login-item notification appears the first time the app auto-starts, confusing/alarming the user (a real reported surprise with SMAppService auto-start).
- Permissions that worked stop working after the app is **re-signed** (different signature → macOS treats it as a new app and forgets granted permissions). This bites repeatedly during development as the app is rebuilt.

**Why it happens:**
macOS TCC ties granted permissions to the app's code signature/bundle identity; changing it invalidates grants. Some sources (e.g. global event monitors for hover, or AppleScript fallbacks) require Accessibility/Automation consent. TCC databases can also reset on reboot in some configurations.

**How to avoid:**
- Prefer designs that need **no** special permission: charging (IOKit) and Bluetooth connect events (IOBluetooth) and the adapter Now Playing path generally don't need Accessibility. Avoid AppleScript/Automation fallbacks that trigger Automation prompts.
- If a permission *is* needed, request it with a clear, just-in-time explanation and a button that deep-links to the right System Settings pane; never expect the user to find it.
- Keep a **stable bundle identifier** and (once you have a Developer ID) a stable signing identity so permission grants survive rebuilds. During early dev, expect to re-grant after signing changes — and know `tccutil reset <Service> <bundleID>` clears stale state.
- Make launch-at-login an explicit opt-in toggle (default OFF) via `SMAppService` to reduce the "why did this start itself?" surprise.

**Warning signs:**
- A feature works once, then stops after a rebuild/re-sign.
- The user reports a scary background-activity or login-item prompt.
- You're reaching for AppleScript and a permission dialog appears.

**Phase to address:**
Phase 8 (settings + launch-at-login) for the SMAppService toggle and any permission UX. But *avoid* permission-heavy approaches starting in Phases 4–6 (choose APIs that don't need TCC).

---

### Pitfall 10: Scope creep — building the DynamicLake long tail before the core island is solid

**What goes wrong:**
A beginner, excited by the reference apps, starts on the file shelf, HUD replacement, lyrics, calendar, or non-notch support before the core island + Now Playing + activities actually feel polished. The project balloons, nothing reaches "Alcove-quality," and motivation collapses. (FEATURES.md already flags most of these as anti-features for v1.)

**Why it happens:**
The maximalist apps (DynamicLake, Notchy) make the long tail look like table stakes. Each extra feature is individually appealing. The hardest, least glamorous work (window/geometry/full-screen correctness, animation polish) has no visible payoff until late.

**How to avoid:**
- Hold the line on the v1 scope in PROJECT.md: island + Now Playing + charging + device-connect + plumbing. Everything else is explicitly later.
- Use the spine-first build order: ship a *visible, runnable* thing at each step (empty island → geometry → hover → one feature) before adding the next.
- Judge "done" against the Alcove polish bar on the **core**, not against DynamicLake's feature count.

**Warning signs:**
- You're writing drag-and-drop / EventKit / clipboard code before Now Playing is solid.
- The animation still feels janky but you're adding a new activity type.
- The TODO list is growing faster than features are finishing.

**Phase to address:**
Roadmap/planning level — enforce via phase gates. Don't open later-phase features until the v1 core passes its success criteria.

---

### Pitfall 11: Animation that morphs vs. cross-fades (the difference between "Alcove-quality" and "cheap clone")

**What goes wrong:**
Expand/collapse cross-fades or pops instead of *morphing*; the pill doesn't grow smoothly into the panel; album art jumps instead of sliding. The app technically works but feels like a knockoff — failing the project's single most important differentiator.

**Why it happens:**
Treating expanded and collapsed as separate views that swap, instead of one continuous view tree whose layout animates. Skipping `matchedGeometryEffect`. Creating/destroying windows per state (an architecture anti-pattern) which kills animation continuity. Mismatched spring parameters.

**How to avoid:**
- One panel, one root view, state-driven content (the architecture's Pattern 1). Never create/destroy windows to switch content.
- Use a shared `@Namespace` + `matchedGeometryEffect` so shapes/art *morph* between layouts.
- Animate the **panel frame** in lockstep with the SwiftUI content (window resizes as the content grows), driven from `IslandState`.
- Budget real iteration time on spring `response`/`dampingFraction` — polish is found here, not in one pass.

**Warning signs:**
- Expand looks like a fade or a jump-cut, not a grow.
- The window's edge is visible "catching up" to the content during animation.
- Side-by-side with Alcove it looks obviously cheaper.

**Phase to address:**
Phase 3 (animation), revisited in Phase 7 (polish). Flag as needing design iteration, not a single task.

---

## Minor Pitfalls

### Pitfall 12: Swift 6 strict-concurrency errors derailing a beginner

**What goes wrong:**
Confusing `Sendable` / actor-isolation compile errors appear that have nothing to do with the feature being built — especially around services calling back into the main-actor `IslandState`, or IOKit/Bluetooth callbacks arriving off the main thread.

**Why it happens:**
Xcode 16 defaults toward Swift 6 strict concurrency; system callbacks (run-loop sources, IOBluetooth selectors, adapter stdout reads) arrive on background threads and must hop to the main actor to touch `@Published` UI state.

**How to avoid:**
- Start in **Swift 5 language mode** (stack decision) to defer strict-concurrency.
- Always marshal service callbacks onto the main actor before mutating `IslandState` (`MainActor`/`DispatchQueue.main`).
- Migrate to Swift 6 mode deliberately, later, when the app is stable.

**Warning signs:** Compile errors mentioning `Sendable`, actor isolation, or "capture of non-Sendable" unrelated to your actual logic.

**Phase to address:** Phase 0 (project setup — set the language mode). Reinforce in each service phase (main-actor hop).

---

### Pitfall 13: Debugging native crashes / off-main-thread UI updates without a method

**What goes wrong:**
The app crashes with a terse stack trace, or the UI freezes/glitches because state is mutated off the main thread. A beginner stares at a crash log with no idea where to look.

**Why it happens:**
SwiftUI requires main-thread state mutation; system callbacks aren't on the main thread. Native crash logs are denser than scripting-language errors.

**How to avoid:**
- Centralize the main-thread hop in the service-to-state boundary (one place to get right).
- Learn the basics: reproduce → read the crash's top frames → set a breakpoint → check the Thread navigator for "not on main thread" purple runtime warnings (Xcode flags these).
- Keep services thin so crashes have a small surface to live in.

**Warning signs:** Purple main-thread runtime warnings in Xcode; intermittent UI glitches; crashes inside SwiftUI update code triggered by a callback.

**Phase to address:** Phases 4–6 (where async system callbacks first appear).

---

### Pitfall 14: Distinguishing "AC connected" from "actively charging" (and Macs/states with no battery info)

**What goes wrong:**
The charging activity fires on the wrong event — e.g. shows "charging" when the adapter is plugged in but the battery is already full (not charging), or misreads battery %.

**Why it happens:**
"Plugged in" (`IOPSCopyExternalPowerAdapterDetails` non-nil) and "charging" (`kIOPSIsChargingKey`) are different facts; conflating them produces a wrong animation.

**How to avoid:** Read the specific IOKit keys for the specific fact you're displaying; decide explicitly what the charging activity should show (plugged-in splash vs. actively-charging vs. full).

**Warning signs:** "Charging" animation when the battery is at 100% and not charging; battery % off by a lot.

**Phase to address:** Phase 5 (power/charging).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Reading IOKit / MediaRemote directly inside a SwiftUI view | Fewer files, "just works" in a demo | View re-runs leak resources; can't test; when MediaRemote breaks, damage is smeared across UI | **Never** — services must own all system access |
| Hardcoding notch width / corner radius / one model's pixel values | Looks perfect on your MacBook today | Breaks on other models and external displays; silent misalignment | Never for shipping; OK only as a throwaway probe |
| Positioning once at launch via `NSScreen.main` | Simple | Wrong screen, breaks on monitor plug/clamshell/focus change | Never |
| Polling the system on a repeating timer | Trivially obvious to write | Constant CPU, battery drain, "battery hog" reputation | Never for system state; OK only for short self-terminating timers |
| Using `codesign --deep` | One command signs everything | Wrong nested signing → notarization rejection / Gatekeeper "damaged" | Never (Apple-discouraged) |
| Skipping the launch-time adapter health check | Less code | Empty island with no explanation when Apple breaks MediaRemote | Only in the very first prototype |
| Letting `IslandState` also fetch data (god object) | One place for everything | Becomes unmaintainable; decisions + data tangled | Never — decisions in state, data in services |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **MediaRemote (via adapter)** | Linking `MediaRemoteAdapter.framework` into the app target; calling MediaRemote symbols in-process | Bundle the framework (copy, **not** link) + the perl script; load it via the `/usr/bin/perl` subprocess; consume streamed stdout JSON |
| **MediaRemote (lifecycle)** | Assuming it works forever; no version monitoring | Launch-time `test` exit-code check; isolate behind `NowPlayingService`; re-verify after every macOS update |
| **IOKit power** | Polling on a timer; conflating "plugged in" with "charging" | `IOPSNotificationCreateRunLoopSource` callback; read the specific keys (`kIOPSIsChargingKey`, capacity keys); handle no-battery state |
| **IOBluetooth** | Using Core Bluetooth (wrong abstraction) for system paired-device events; polling | `register(forConnectNotifications:)` + per-device disconnect notifications; unregister to stop |
| **NSScreen geometry** | Using `NSScreen.main`; positioning once; hardcoding model values | Find screen with `safeAreaInsets.top > 0`; derive width from `auxiliaryTop*Area`; recompute on `didChangeScreenParametersNotification` |
| **Code signing** | `--deep`; wrong-account app-specific password; forgetting hardened runtime; not stapling | Sign bottom-up with `--options runtime --timestamp`; matched-account password; `notarytool ... --wait` then `stapler staple` |
| **SMAppService** | Auto-enabling at first launch (surprise background-activity prompt) | Explicit opt-in toggle, default OFF, with a clear label |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Long-lived polling timers for system state | Idle CPU > ~1%, fans, battery drain, high Energy Impact | Event/notification sources only (IOKit run-loop, IOBluetooth notifications, adapter stream) | Immediately — it's an all-day background app |
| Re-invoking the adapter perl command per update | Process-spawn overhead, latency, CPU spikes | Spawn once, consume the long-lived stdout stream | As soon as music plays continuously |
| Re-decoding album art every render | UI hitches when expanded; memory churn | Decode artwork once on change, cache the `NSImage`; fill in async (art lags metadata) | When tracks change frequently |
| Animating by recreating the window/view per state | Flicker, dropped frames, lost morph | One window + one root view; animate frame + content together | The first time you switch activities live |
| Heavy work on the main thread in a callback | Beachballs / dropped animation frames | Do parsing/decoding off-main; hop to main only to set `@Published` | Under real multi-source activity |

## Security / Robustness Mistakes

(Desktop-utility-specific — there's no server or user data store here.)

| Mistake | Risk | Prevention |
|---------|------|------------|
| Trusting adapter stdout JSON without validation | Malformed/partial JSON crashes the parser or the app | Defensive parsing; tolerate missing fields (art especially); never force-unwrap adapter output |
| Shipping with the App Sandbox enabled | Breaks the perl-subprocess MediaRemote bridge and some IOKit/IOBluetooth access | Ship **un-sandboxed**, hardened-runtime, notarized (App-Store-incompatible anyway, by design) |
| Unstable bundle ID / ad-hoc signature in releases | TCC permissions reset for users on each update; Gatekeeper friction | Stable bundle ID + consistent Developer ID signing |
| Bundling an unsigned helper framework/script | Notarization rejection; Gatekeeper "damaged" | Sign every embedded binary bottom-up before signing the app |
| Auto-updating the adapter blindly | A new adapter version could break Now Playing in the field | Pin a known-good version; test before bumping |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Island always animating / never quiet | Distracting; feels broken | Near-invisible collapsed state; only react to real events; transient activities auto-collapse (~3s) |
| Island floats over full-screen video | Ruins media viewing; feels intrusive | Detect full-screen and hide (with a user toggle) |
| Stealing focus when clicked | Interrupts the user's current app | Non-activating panel (`becomesKeyOnlyIfNeeded`) |
| No way to quit / configure | Looks like malware that can't be removed | `MenuBarExtra` with Quit + Settings from day one (Phase 0) |
| Surprise login-item / background prompt | Alarms the user, looks shady | Launch-at-login opt-in, default OFF, clearly labeled |
| Empty Now Playing with no explanation when API breaks | User thinks the whole app is broken | Health-check the adapter; show an explicit "unavailable on this macOS" state |
| Two activities fight for the island simultaneously | Flicker / jarring switching | Priority resolver + transient queue (architecture Pattern 2) |

## "Looks Done But Isn't" Checklist

- [ ] **Overlay window:** Often missing full-screen hide — verify it hides over native full-screen, full-screen video, and QuickLook; verify no lingering window-control bar.
- [ ] **Geometry:** Often missing multi-display/clamshell handling — verify it stays on the *built-in notch* screen after plugging in a monitor, closing the lid, and changing resolution; verify on a second MacBook model if possible.
- [ ] **Now Playing:** Often missing the health check and isolation — verify the adapter `test` exit code is checked at launch and all MediaRemote code lives in one service; verify album art loads asynchronously (it lags).
- [ ] **Interaction:** Often missing click-through correctness — verify you can click the desktop/menu bar *around* the island and that clicking the island doesn't steal focus.
- [ ] **Charging:** Often missing the plugged-in vs. charging vs. full distinction — verify the right animation for each state and a no-battery fallback.
- [ ] **Performance:** Often missing idle efficiency — verify idle CPU ~0% and no long-lived polling timers (Activity Monitor Energy tab).
- [ ] **Signing:** Often missing correct nested signing — verify a notarized build opens cleanly on a *different* Mac (not just yours), embedded framework signed, stapled.
- [ ] **Permissions/login:** Often missing graceful permission UX — verify launch-at-login is opt-in and any needed permission has a clear prompt that survives a rebuild/re-sign.
- [ ] **Concurrency:** Often missing main-thread discipline — verify no purple "not on main thread" runtime warnings when callbacks fire.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| MediaRemote broken by a macOS update | LOW (if isolated) / HIGH (if smeared) | Update/swap the adapter version behind `NowPlayingService`; if no fix exists, show "unavailable" state and ship other features. Cost is LOW *only because* of isolation — that's why isolation is mandatory. |
| Island on wrong display / mispositioned | LOW–MEDIUM | Replace `NSScreen.main` with the `safeAreaInsets.top > 0` screen; add `didChangeScreenParametersNotification` recompute |
| Notarization rejected | MEDIUM | Read `notarytool log`; re-sign bottom-up with hardened runtime; remove `--deep`; verify app-specific password account matches cert |
| Permissions reset on every rebuild | LOW | Stabilize bundle ID + signing identity; `tccutil reset` to clear stale entries during dev |
| Battery-drain complaints | MEDIUM | Replace polling timers with notification/run-loop sources; profile with Instruments Energy Log |
| Island floats over full-screen | MEDIUM | Add explicit full-screen observation + hide/restore; don't rely on collection behavior alone |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Direct MediaRemote `nil` (P1) | Phase 4 | Now Playing shows real data; adapter (not in-process MediaRemote) is the only path |
| Adapter fragility / not isolated (P2) | Phase 4 (build), re-check Phase 8 | All MR code in `NowPlayingService`; launch-time `test` exit-code check present |
| Full-screen not hidden (P3) | Phase 1–2 plumbing, Phase 3 hardening | Hidden over native/video/QuickLook full-screen; no ghost control bar |
| Wrong-display placement (P4) | Phase 2 | Stays on notch screen after monitor plug / clamshell / focus change |
| Signing/notarization failure (P5) | Phase 0 dry-run spike + Phase 8 release | Notarized build opens on a *different* Mac; embedded framework signed; stapled |
| Polling battery drain (P6) | Phases 4/5/6 | Idle CPU ~0%; no long-lived polling timers |
| Click-through/focus conflict (P7) | Phase 3 | Can click around + on island; no focus stealing |
| Coordinate/geometry math (P8) | Phase 2 | Centered, correct corner radius; checked on ≥1 other model |
| Permission/TCC/login surprises (P9) | Phase 8 (avoid permission-heavy APIs in 4–6) | Opt-in login item; permissions survive re-sign; clear prompts |
| Scope creep (P10) | Planning / phase gates | v1 core passes success criteria before later features open |
| Cross-fade vs. morph animation (P11) | Phase 3, polish Phase 7 | Side-by-side morph quality vs. Alcove; window frame animates with content |
| Swift 6 concurrency (P12) | Phase 0 (language mode) | Builds cleanly; callbacks hop to main actor |
| Native crash / off-main UI (P13) | Phases 4–6 | No purple main-thread warnings; reproducible crash workflow understood |
| Charging vs. plugged-in vs. full (P14) | Phase 5 | Correct state shown; no-battery fallback |

## Sources

- ungive/mediaremote-adapter — current (2026) MediaRemote workaround: 15.4 `mediaremoted` entitlement check, perl `/usr/bin/perl` bundle-ID trick, bundle (not link) the framework, `test` exit-code health check, maintainer warning that the API may break across minor revisions: https://github.com/ungive/mediaremote-adapter — **HIGH** (canonical project; verified via fetch 2026-06-26)
- aviwad/LyricFever issue #94 — `MRMediaRemoteGetNowPlayingInfo` returns nil on recent macOS: https://github.com/aviwad/LyricFever/issues/94 — **MEDIUM-HIGH**
- feedback-assistant/reports #637 — request for a public Now Playing API (still open; confirms no stable alternative): https://github.com/feedback-assistant/reports/issues/637 — **MEDIUM-HIGH**
- TheBoringNotch issue #396 — notch does not disappear on fullscreen: https://github.com/TheBoredTeam/boring.notch/issues/396 — **HIGH** (real domain bug)
- TheBoringNotch issue #803 — not hiding in full screen (entire screen): https://github.com/TheBoredTeam/boring.notch/issues/803 — **HIGH**
- TheBoringNotch issue #426 — notch shouldn't show in Quick Look full screen: https://github.com/TheBoredTeam/boring.notch/issues/426 — **HIGH**
- TheBoringNotch issue #313 / #749 — hide on non-notch display / island on wrong (second) screen: https://github.com/TheBoredTeam/boring.notch/issues/313 — **HIGH**
- Apple — Resolving common notarization issues (hardened runtime, nested signing, `--deep` discouraged): https://developer.apple.com/documentation/security/resolving-common-notarization-issues — **HIGH**
- Apple — Signing Mac software with Developer ID: https://developer.apple.com/developer-id/ — **HIGH**
- rsms — macOS distribution: code signing, notarization, quarantine (sign bottom-up, avoid `--deep`): https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5 — **MEDIUM-HIGH**
- Apple — `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets — **HIGH**
- The Swift Den — `safeAreaInsets`/menu-bar height mismatch (32 vs 36) coordinate gotcha: https://www.answeroverflow.com/m/1145112887048810606 — **MEDIUM**
- nilcoalescing — launch-at-login with SMAppService: https://nilcoalescing.com/blog/LaunchAtLoginSetting/ — **MEDIUM-HIGH**
- robinebers/openusage issue #607 — confusing "App Background Activity" alert on SMAppService auto-start: https://github.com/robinebers/openusage/issues/607 — **MEDIUM**
- Michael Tsai / Recoursive — resetting TCC, permissions tied to signature, reset on reboot: https://mjtsai.com/blog/2023/02/09/resetting-tcc/ — **MEDIUM**

---
*Pitfalls research for: native macOS notch / Dynamic Island utility app*
*Researched: 2026-06-26*
