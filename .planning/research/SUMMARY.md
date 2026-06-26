# Project Research Summary

**Project:** Notch — Dynamic Island for Mac (working title; final name TBD)
**Domain:** Native macOS notch / "Dynamic Island" overlay utility (Alcove / DynamicLake class)
**Researched:** 2026-06-26
**Confidence:** HIGH on stack, features, architecture, and most pitfalls; MEDIUM on the one fragile dependency (Now Playing via private MediaRemote).

## Executive Summary

This is a native macOS background utility that paints a borderless, always-on-top "island" over the physical notch and reacts to system events — now-playing media, charging, and Bluetooth device connections in v1. Every credible reference app (Alcove, DynamicLake, the open-source TheBoringNotch and Notchy) converges on the exact same shape, so the build is not a design gamble — it's a well-trodden path. **The recommended stack is one line: Swift + SwiftUI (with a thin AppKit shell), minimum macOS 14.0, distributed as a direct download that is Developer-ID-signed and notarized — never the Mac App Store.** The architecture is equally settled: a menu-bar agent (no Dock icon) owns *one* borderless `NSPanel` hosting *one* SwiftUI view tree; a single `IslandState` object decides what shows; and independent services (power, Bluetooth, now-playing) push facts *up* into that state. Features are leaves you bolt onto this spine one at a time, which is exactly what a beginner needs — you can ship a visible-but-empty island before any feature exists.

The single highest-risk dependency, and the thing that must shape the whole roadmap, is **Now Playing**. Apple locked down the private MediaRemote framework in macOS 15.4: direct `dlopen` + `MRMediaRemoteGetNowPlayingInfo` now returns `nil` silently for any non-Apple app. The proven workaround is the **`mediaremote-adapter`** project, which runs `/usr/bin/perl` (an Apple-entitled bundle ID) as a subprocess to load a helper framework and stream now-playing JSON over stdout. This forces four non-negotiable rules: (1) the framework is **bundled, not linked**; (2) a **launch-time health check** (the adapter's `test` exit code) gates a graceful "unavailable" state; (3) all of it is **isolated behind one `NowPlayingService`** so a future Apple change is a one-file fix; and (4) this is *why* the App Store is off the table and notarized direct distribution is mandatory. Treat each macOS release as a regression event for this feature only.

Beyond MediaRemote, the risks are about *correctness that hides until real use*: the island must **hide for full-screen apps** (movies, full-screen video, QuickLook) and must render on the **built-in notch display only** across monitor plug/unplug and clamshell — both are core requirements, **not polish**, and both are heavily evidenced by real bug reports in TheBoringNotch. Performance discipline (event/notification sources, never polling timers) keeps idle CPU near 0% as users expect from an all-day background app. The strategy that falls out of all four research files is identical and opinionated: **match Alcove's polish on a deliberately focused core, defer the DynamicLake long tail, and prove the signing/notarization toolchain on day one with a hello-world dry run before any feature is finished.**

## Key Findings

### Recommended Stack

Build a **menu-bar (LSUIElement "agent") app in Swift + SwiftUI**, hosted inside a borderless, non-activating `NSPanel` floating at `.statusBar` level across all Spaces and over full-screen apps. Drop into AppKit *only* for the window shell, the menu-bar item, event monitors, and IOKit/IOBluetooth glue — keep that surface tiny and build ~95% of the visible app in SwiftUI. Animate the expand/collapse with SwiftUI `spring` + `matchedGeometryEffect` (this is *the* Dynamic-Island morph). Distribute via direct download, Developer-ID-signed with hardened runtime, notarized with `notarytool` (not `altool`). See STACK.md for full detail.

**Core technologies:**
- **Swift 6.x toolchain in Swift 5 *language mode*** — the native first-party language; Swift 5 mode dodges the strict-concurrency compile errors that derail beginners (migrate to Swift 6 later).
- **SwiftUI (macOS 14 SDK)** — all island UI and animation; declarative, live previews, and the spring/matched-geometry morph for free.
- **AppKit (`NSPanel`, `NSStatusItem`, `NSHostingView`, event monitors)** — the borderless non-activating overlay window that SwiftUI cannot create alone.
- **`mediaremote-adapter` (ungive, BSD-3; Swift wrapper ejbills)** — the *only* working Now Playing path on macOS 15.4+; bundle the framework + perl script, do **not** link.
- **IOKit power sources (`IOPSCopyPowerSourcesInfo` + `IOPSNotificationCreateRunLoopSource`)** — charging/battery state, public and stable.
- **IOBluetooth connect/disconnect notifications** — AirPods/device events; legacy but the correct tool (Core Bluetooth is the wrong abstraction here).
- **`notarytool` + `codesign --options runtime` + `stapler`** — the release toolchain; `SMAppService` for launch-at-login; Sparkle for updates later.

**Minimum deployment target: macOS 14.0 (Sonoma).** No Apple Developer account needed for local dev — only for notarization/release ($99/yr).

### Expected Features

The reality check across four reference apps: now-playing, a hover-expand island, system HUDs, a file shelf, and AirPods/charging activities now appear in *every* one — including the free ones. So several "ambitious" items are **table stakes, not differentiators**. The project's stated v1 maps almost exactly onto the table-stakes set, which is the correct call. See FEATURES.md.

**Must have (table stakes — v1):**
- Island overlay: expand on hover, collapse on idle (this *is* the product).
- Smooth spring/morph expand-collapse animation (Alcove's whole reputation).
- Now Playing: album art + title/artist, plus play/pause/skip — multi-app source detection (Spotify/Music/browser) comes *free* via MediaRemote.
- Charging / battery live activity (IOKit) — lowest-risk activity, a safe early win.
- AirPods / Bluetooth connect-disconnect activity (IOBluetooth event; per-bud battery later).
- Menu-bar item + minimal settings + launch-at-login — required plumbing.

**Should have (competitive differentiators — v1.x):**
- "Feels exactly like iPhone Dynamic Island" animation polish — the real moat vs free clones (a quality level, not a feature).
- Seek/scrub bar + sneak-peek auto-expand on track change.
- Color-adaptive tint from album art + a *decorative* (faked) waveform — high visual payoff, low risk.
- Countdown/Pomodoro timer activity — zero API risk; ideal "first feature the beginner builds themselves."

**Defer (v2+):**
- Volume/brightness/battery HUD replacement — fiddly OS-HUD suppression, version-sensitive.
- Drag-and-drop file shelf + AirDrop — separate drag-drop domain (reference NotchDrop).
- Synced lyrics, calendar/weather glance, clipboard manager, camera mirror, non-notch/external-display pill.

**Anti-features (do NOT build — confirmed cuts):** messaging/notification mirroring (no clean API), calls/FaceTime integration, file/media conversion utilities, real audio-tap visualizer (use the decorative fake), and Mac App Store distribution (MediaRemote guarantees rejection). Non-notch support is explicitly out — it doubles the hardest part (geometry) before the core works.

### Architecture Approach

One sentence captures it: **a background agent owns one always-on-top borderless panel glued over the notch; that panel hosts one SwiftUI view tree; one `IslandState` object decides what shows; independent services watch the system and push facts up into that state; the view just renders what the state says.** Data flows one way *up* (system -> service -> state -> view); the *only* downward path is a user command (tap pause -> service -> system), and even that loops back up via a system notification rather than optimistically updating the UI. This keeps the gnarly system APIs quarantined in services and the SwiftUI readable — exactly the "build the spine, then bolt on feature-leaves" property a beginner needs. All three open-source references (TheBoringNotch, DynamicNotch, DynamicNotchKit) independently converge on this, so it's the de-facto standard. See ARCHITECTURE.md.

**Major components:**
1. **Overlay Window layer** (`NotchPanel` + `NotchWindowController` + `NotchGeometry`) — the borderless non-activating `NSPanel`, positioned over the notch via `NSScreen.safeAreaInsets`/`auxiliaryTop*Area`, recomputed on screen-config change. Knows nothing about music or battery.
2. **`IslandState` (the brain)** — one `ObservableObject` holding presentation (`.idle`/`.expanded`/`.activity(kind)`), hover flags, and the priority resolver that arbitrates which activity wins and for how long.
3. **Services layer** (`NowPlayingService`, `PowerService`, `BluetoothService`) — each owns one system source, converts raw data to a clean domain struct, pushes it into `IslandState`. Each is independently buildable/replaceable; new features (timer, shelf, HUD) = new service + view + one enum case.

### Critical Pitfalls

1. **MediaRemote returns silent `nil` on macOS 15.4+** — direct framework calls fail with no error; a beginner can lose days. Use `mediaremote-adapter` from day one (bundle, **not** link, the framework + perl script); never call MediaRemote symbols in-process.
2. **Treating the adapter as permanent / not isolating it** — Apple can break it again, and the maintainer warns of breaking changes across minor revisions. Put *all* of it behind `NowPlayingService`, add a launch-time `test`-exit-code **health check** with a graceful "unavailable" state, pin a known-good version, and re-test after every macOS update.
3. **Island doesn't hide for full-screen apps (or leaves a ghost control bar)** — the single most common "works in a window, broken in real use" failure (TheBoringNotch issues #396/#803/#426/#764). Collection behavior alone is insufficient; actively observe full-screen state and hide/show the panel; test native full-screen, full-screen video, and QuickLook. **Core correctness, not polish.**
4. **Island on the wrong display / mis-positioned** (TheBoringNotch #313/#749) — `NSScreen.main` follows focus, not the notch. Find the notch screen explicitly (`safeAreaInsets.top > 0`), recompute on `didChangeScreenParametersNotification`, and handle the clamshell/external-only case by hiding.
5. **Code signing / notarization failure on first release** — worse here because of the bundled `MediaRemoteAdapter.framework` + perl script. Enable hardened runtime, sign **bottom-up** (embedded frameworks first), **never** `--deep`, use a `notarytool` app-specific password from the *same* Apple ID as the Developer ID cert, then `stapler staple`. Run a **hello-world notarization dry run before any feature is finished.**
6. **Polling the system instead of using event/notification sources** — a repeating `Timer` to check power/playing/devices burns CPU all day and earns a "battery hog" reputation. Use `IOPSNotificationCreateRunLoopSource`, IOBluetooth connect notifications, and the adapter's streamed stdout; target idle CPU ~0%.

(Moderate/minor pitfalls in PITFALLS.md: click-through vs interaction conflicts, Retina/coordinate math and `safeAreaInsets` != menu-bar-height, TCC permission resets on re-sign, scope creep, cross-fade-vs-morph animation, Swift 6 concurrency, off-main-thread UI updates, "AC connected" vs "actively charging.")

## Implications for Roadmap

The three research files that touch ordering (FEATURES, ARCHITECTURE, PITFALLS) all propose the *same* spine-first build order, and it should be the roadmap's backbone. Two things must be hoisted out of "later/polish" and treated as first-class: a **Phase-0 notarization dry-run spike**, and **full-screen-hide + multi-display correctness** as core success criteria of the window/geometry phases.

### Phase 0: Foundations & Notarization Dry Run
**Rationale:** A beginner discovering signing problems on launch day is a classic disaster; prove the whole toolchain on a hello-world build *before* features exist. Also set Swift 5 language mode here to avoid concurrency noise.
**Delivers:** A runnable `MenuBarExtra` agent (LSUIElement, Quit works) that has been **signed -> notarized -> stapled** end-to-end and opens cleanly on a *second* Mac.
**Addresses:** Menu-bar + quit plumbing (table stakes).
**Avoids:** Pitfall 5 (signing/notarization), Pitfall 12 (Swift 6 concurrency).

### Phase 1: The Empty Island (Window + Geometry)
**Rationale:** The overlay window is the highest-risk, most macOS-specific foundation and the only true blocker — nothing renders until it's solid. Build and test "a black pill sits exactly on my notch" in total isolation.
**Delivers:** A borderless non-activating `NotchPanel` showing a static rounded black pill, correctly sized/centered on the notch and surviving monitor plug/unplug, clamshell, and resolution change.
**Uses:** AppKit `NSPanel`, `NSScreen.safeAreaInsets`/`auxiliaryTop*Area`, `NSHostingView`.
**Implements:** Overlay Window layer + `NotchGeometry`.
**Avoids:** Pitfall 4 (wrong display — make "stays on the built-in notch screen" an explicit success criterion), Pitfall 8 (coordinate/geometry math), and the *plumbing* for Pitfall 3 (full-screen `collectionBehavior`/level).

### Phase 2: Hover, Expand & the Morph Animation
**Rationale:** The expand/collapse feel is the product's core differentiator (the Alcove bar) and exercises the state-driven single-view-tree pattern before any real data. Full-screen hide is hardened here because it's an interaction/state concern.
**Delivers:** `IslandState` (.idle/.expanded), hover detection, a spring/`matchedGeometryEffect` morph from pill to panel (placeholder content), correct click-through, and active full-screen hide/show.
**Implements:** `IslandState` skeleton, Pattern 1 (one window/one root view).
**Avoids:** Pitfall 3 (full-screen hide — **core, not polish**), Pitfall 7 (click-through/focus), Pitfall 11 (morph vs cross-fade). Flag for *design iteration*, not a one-shot.

### Phase 3: Now Playing (the core value, the fragile dependency)
**Rationale:** Intentionally the first real feature — it's the top install driver *and* it exercises the full up-and-down data path that every later feature reuses. Its fragility is contained from the start.
**Delivers:** Integrate `mediaremote-adapter` (bundle framework + perl, spawn subprocess, consume streamed JSON); album art + title/artist, then play/pause/skip. Launch-time health check + "unavailable" fallback.
**Uses:** `mediaremote-adapter`, `NowPlayingService` behind a clean protocol.
**Avoids:** Pitfall 1 (silent nil — adapter only), Pitfall 2 (isolation + health check), Pitfall 6 (consume the stream, don't re-spawn), Pitfall 13 (main-actor hop on stdout reads).

### Phase 4: Charging Activity
**Rationale:** Lowest-risk activity (public IOKit, simple plug/unplug) — but ordered *after* Now Playing so the transient/priority machinery has a real ambient state (music) to arbitrate against.
**Delivers:** Plug/unplug transient splash + battery %, auto-collapsing back to ambient.
**Uses:** IOKit power + `IOPSNotificationCreateRunLoopSource`; `PowerService`.
**Avoids:** Pitfall 6 (no polling), Pitfall 14 ("AC connected" vs "actively charging" vs "full").

### Phase 5: Device-Connected Activity
**Rationale:** Reuses the transient pattern from Phase 4; near-identical small addition once the wiring exists. Skip per-bud battery for v1.
**Delivers:** AirPods/Bluetooth connect-disconnect splash.
**Uses:** IOBluetooth connect/disconnect notifications; `BluetoothService`.
**Avoids:** Pitfall 6 (event-driven, no polling), and using Core Bluetooth (wrong abstraction).

### Phase 6: Priority Resolver + Settings + Launch-at-Login -> v1 ships
**Rationale:** Arbitration can only be tuned once all three sources exist. Settings/launch-at-login is the last required plumbing. Re-verify the Now Playing health check and run the real release notarization here.
**Delivers:** Tuned priority/transient durations so media + charging + device coexist; `MenuBarExtra` settings; `SMAppService` opt-in (default OFF); production sign/notarize/staple.
**Implements:** Pattern 2 (priority resolver), `SettingsStore`.
**Avoids:** Pitfall 9 (TCC/login-item surprise — opt-in, stable bundle ID), re-checks Pitfall 2 and Pitfall 5.

### Later Phases (post-v1, each = new Service + View + ActivityKind case, spine untouched)
- **Polish pass:** sneak-peek auto-expand, color-adaptive tint, decorative waveform.
- **Timer** activity (zero API risk; good beginner-built feature).
- **File shelf** + AirDrop (separate drag-drop domain).
- **HUD replacement** (volume/brightness — fiddly OS-HUD suppression).

### Phase Ordering Rationale

- **Dependencies:** Everything requires notch geometry + the overlay window, so that's Phases 0–2 with zero private APIs — the beginner gets a real on-screen island and learns the window/state/view loop before touching anything fragile.
- **Risk ordering:** The three activity data sources are mutually independent; they're ordered by risk — Now Playing first because it's the core value *and* exercises the full data path, then the safe IOKit/IOBluetooth transients reuse that proven path.
- **Pitfall avoidance:** The notarization dry run is pulled to Phase 0 (not launch day); full-screen-hide and multi-display correctness are baked into Phases 1–2 as success criteria (not deferred to polish); polling is banned per-service.

### Research Flags

Phases likely needing deeper research (`/gsd-research-phase`) during planning:
- **Phase 1 (Window + Geometry):** the borderless `NSPanel` config, all-Spaces/full-screen collection behavior, and exact notch-geometry math (`auxiliaryTop*Area`, `safeAreaInsets` != menu-bar height, multi-display) are the trickiest macOS-specific surface and benefit from a focused implementation-pattern dive.
- **Phase 3 (Now Playing):** the `mediaremote-adapter` integration is version-fragile and the highest-uncertainty area — verify the current adapter version against the installed macOS at planning time, confirm the bundle-not-link setup and the `test` health-check contract.
- **Phase 6 release / notarization (and the Phase-0 spike):** the exact bottom-up signing sequence for the embedded framework + perl script warrants a checked, scripted recipe.

Phases with standard, well-documented patterns (likely skip research-phase):
- **Phase 0 (MenuBarExtra agent + Swift language mode):** trivial, well-documented plumbing.
- **Phase 2 (SwiftUI spring/matchedGeometryEffect):** standard SwiftUI; the work is *design iteration*, not research.
- **Phases 4–5 (IOKit power + IOBluetooth):** public, stable APIs with clear Apple docs; the architecture already names the exact calls.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Swift/SwiftUI/AppKit, NSPanel approach, and notarized distribution verified against Apple docs and four reference apps (incl. two open-source). Only the MediaRemote adapter is MEDIUM within the stack. |
| Features | HIGH | Feature landscape cross-verified across Alcove, DynamicLake, TheBoringNotch, Notchy; per-feature *complexity* estimates are MEDIUM (informed by OSS but unbuilt). |
| Architecture | HIGH | Reverse-engineered from three convergent open-source apps + Apple AppKit/IOKit docs; MEDIUM only on the Now Playing integration (private, version-fragile). |
| Pitfalls | HIGH | Verified against Apple docs and real TheBoringNotch bug reports (full-screen, multi-display, signing); MEDIUM-HIGH on MediaRemote (fast-moving but confirmed current via the adapter project and 15.4 breakage reports). |

**Overall confidence:** HIGH — with one explicitly-tracked MEDIUM-confidence dependency (Now Playing/MediaRemote) that is mitigated by isolation, a health check, and per-macOS-release re-testing.

### Gaps to Address

- **MediaRemote longevity is unknowable.** Mitigation is structural, not predictive: isolate behind `NowPlayingService`, ship a launch-time health check + graceful fallback, pin a known-good adapter version, and treat each macOS update as a Now-Playing regression event. Verify the adapter against the *currently installed* macOS at Phase-3 planning.
- **DynamicNotchKit vs. custom `NSPanel`** is an open decision. It accelerates transient notifications but is not built for an always-visible compact pill. Decide at Phase-1 planning — prototype-with-it then graduate, or roll the panel directly.
- **macOS 14.0 vs 15.0 floor** is a minor, near-zero-cost call (14.0 recommended for wider reach). Confirm before Phase 0.
- **Geometry on a single model.** All math derives from one MacBook; if a second model (Air vs 14"/16" Pro) is available, sanity-check notch width/corner radius before relying on it (Phase 2).
- **AirPods per-bud battery readout** is finickier (extra Bluetooth permission) and intentionally split out of v1's connect-event feature; revisit only if users ask.

## Sources

### Primary (HIGH confidence)
- Apple Developer docs — `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea`, `nonactivatingPanel` style mask, `MenuBarExtra`, `IOBluetoothUserNotification` / `register(forConnectNotifications:)`, IOKit power-source charging detection (Dev Forums #128048), notarization / `notarytool` / "Resolving common notarization issues" (hardened runtime, sign bottom-up, `--deep` discouraged), `SMAppService` launch-at-login.
- TheBoringNotch — github.com/TheBoredTeam/boring.notch — primary open-source reference (SwiftUI, macOS 14+, uses mediaremote-adapter); real domain bug reports for full-screen (#396/#803/#426/#764) and multi-display (#313/#749).
- DynamicNotch (jackson-storm) and DynamicNotchKit (MrKai77) — convergent architecture references (one container, SwiftUI-hosted, queue-driven presentation state machine).
- Reference apps surveyed — Alcove (tryalcove.com), DynamicLake Pro (dynamiclake.com), Notchy (notchy.dev) — feature landscape, positioning, pricing, distribution model.

### Secondary (MEDIUM confidence)
- `ungive/mediaremote-adapter` (BSD-3, v0.7.x) + Swift wrapper `ejbills/mediaremote-adapter` — the 15.4 `mediaremoted` entitlement check, `/usr/bin/perl` bundle-ID trick, bundle-not-link, `test` exit-code health check, and the maintainer's own breaking-change warning. (Private-API workaround, version-fragile.)
- MediaRemote 15.4 lockdown corroboration — nowplaying-cli issue #28, LyricFever issue #94, feedback-assistant report #637 (open request for a public Now Playing API).
- SwiftUI floating-panel / NSPanel pattern articles (fazm.ai, Itsuki, gaitatzis) and matchedGeometryEffect Dynamic-Island tutorials (Design+Code) — borderless non-activating overlay recipe + the spring/matched-geometry morph.
- rsms macOS distribution gist (sign bottom-up, avoid `--deep`); nilcoalescing SMAppService launch-at-login; BluetoothConnector (real IOBluetooth usage).

### Tertiary (LOW confidence)
- The Swift Den — `safeAreaInsets` (32) vs menu-bar height (36) coordinate mismatch — single source, useful caution to verify at Phase 2.
- openusage issue #607 (confusing "App Background Activity" SMAppService prompt) and Michael Tsai on TCC resets — single-source UX/permission cautions for Phase 6.

---
*Research completed: 2026-06-26*
*Ready for roadmap: yes*
