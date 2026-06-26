# Feature Research

**Domain:** Native macOS notch / "Dynamic Island" utility app (Alcove / DynamicLake class)
**Researched:** 2026-06-26
**Confidence:** HIGH (feature landscape, verified across 4 reference apps) / MEDIUM (per-feature complexity estimates — informed by open-source implementations but unbuilt)

---

## Reference Apps Surveyed

| App | Positioning | Source model | Price | Key takeaway for us |
|-----|-------------|--------------|-------|---------------------|
| **Alcove** (tryalcove.com) | "Just the Dynamic Island, nothing more" — polished, minimal | Closed, Swift 6, direct-notarized | ~$17 one-time | The **quality bar** for animations + the v1 feature scope to match. Deliberately omits tray/mirror/calendar. |
| **DynamicLake Pro** (dynamiclake.com) | Workflow/function maximalist | Closed | ~$17 | The **breadth catalog** — shows the long tail (calls, messaging, file actions, conversion). Mostly anti-features for v1. |
| **TheBoringNotch** (github.com/TheBoredTeam/boring.notch) | Open-source community island | GPL-3.0, Swift 98% + SwiftUI | Free | The **implementation reference** — read its code for MediaRemote, shelf, HUD. Its roadmap = our feature checklist. |
| **Notchy** (notchy.dev) | Free maximalist, SwiftUI, ~0% CPU | Closed, free | Free | Shows the **table-stakes minimum** a free app already nails (now playing, shelf, HUDs, AirPods, timer). Raises the floor. |

**Cross-cutting reality check:** Now Playing, a hover-expand island, system HUD replacement, a file shelf, and AirPods/battery activities now appear in *every* one of these apps — including the free ones. That means several of these are **table stakes, not differentiators**, even though they feel ambitious to a beginner. The project's stated v1 (island + now playing + charging + device-connect) maps almost exactly onto the table-stakes set, which is the right call.

---

## Feature Landscape

### Table Stakes (Users Expect These — missing = they uninstall)

| Feature | Why Expected | Complexity (beginner) | Notes |
|---------|--------------|------------------------|-------|
| **Island overlay: expand on hover, collapse on idle** | This *is* the product. A static black bar isn't "Dynamic Island." | **MEDIUM** | Borderless `NSWindow`, `.statusBar`/`.screenSaver` window level, ignores-mouse-events except hover zone, `NSScreen.safeAreaInsets`/`auxiliaryTopLeftArea` to find notch geometry. The window/positioning is the single highest-risk foundation task — get it right first. |
| **Smooth expand/collapse animation** | Alcove's whole reputation is the animation. Janky = "cheap knockoff." | **MEDIUM–HIGH** | SwiftUI `matchedGeometryEffect` + spring animations; the *feel* (rounded-corner morph that mirrors the notch radius) is what separates polished from amateur. Budget real iteration time here. |
| **Now Playing: album art + title/artist** | Top reason people install these apps. | **MEDIUM** | Needs MediaRemote — see the **critical pitfall below (macOS 15.4 lockdown)**. Album art arrives as image data you render in the island. |
| **Now Playing: play / pause / skip controls** | A media display you can't control is half a feature. | **MEDIUM** | Same MediaRemote channel sends play/pause/next/prev commands. Low *additional* cost once metadata works. |
| **Multi-app source detection (Apple Music, Spotify, browser, etc.)** | Users expect it to "just know" what's playing regardless of app. | **LOW (free with MediaRemote)** | MediaRemote is system-wide — it reports whatever app owns Now Playing, so you get Spotify/Safari/Music for free without per-app integrations. This is a hidden win. |
| **Now Playing: seek / scrub bar + elapsed time** | Present in Alcove, Notchy, Boring. Expected on the expanded view. | **MEDIUM** | Position + duration come from MediaRemote; seek command also supported. Drag interaction adds UI cost. |
| **Charging / battery live activity** | A v1 core requirement; present in DynamicLake, Notchy, Alcove. | **LOW–MEDIUM** | IOKit power source notifications (`IOPSNotificationCreateRunLoopSource`) fire on plug/unplug; show animation + % for a few seconds, then collapse. No private API, no entitlement issues — a *safe* early win. |
| **AirPods / Bluetooth connect & disconnect activity** | Expected since iPhone does it; in Notchy, DynamicLake. | **MEDIUM** | `IOBluetooth` connect/disconnect notifications for the event; reading AirPods *battery %* needs extra Bluetooth permission and is finickier — split these (event = easy, battery readout = harder). |
| **Volume / brightness HUD replacement** | Every competitor replaces these; users notice the ugly default. | **MEDIUM–HIGH** | Must *hide* the system HUD (defaults write / overlay trick) AND intercept volume/brightness key events to show your own. Fiddly and OS-version-sensitive — a classic "looks simple, isn't" feature. Defer past v1. |
| **Drag-and-drop file shelf** | Standard in Boring, Notchy, DynamicLake, NotchNook. | **MEDIUM–HIGH** | Drop target on the island, hold file promises, drag back out. NSItemProvider / file promises + temp storage. Reference: NotchDrop (open source). Defer to a later phase. |
| **Menu-bar item + settings/preferences window** | Users need to quit, configure, launch-at-login. | **LOW** | `MenuBarExtra` (SwiftUI). Non-negotiable plumbing; trivial but must exist. |
| **Launch at login** | Background utilities are expected to persist. | **LOW** | `SMAppService` (modern API). |
| **Quiet by default / unobtrusive when idle** | A notch app that's always animating is annoying. | **LOW (design discipline)** | Collapsed state must be near-invisible; only react to real events. This is a design rule, not code. |

### Differentiators (Competitive Advantage — earn loyalty)

| Feature | Value Proposition | Complexity (beginner) | Notes |
|---------|-------------------|------------------------|-------|
| **"Feels exactly like iPhone Dynamic Island" animation polish** | This is THE differentiator vs. free clones — Alcove's entire moat. | **HIGH** | Not a feature, a *quality level*: matched corner radius, spring physics, content morph, no flicker. Worth disproportionate effort because it's the one thing free apps fail at. |
| **Audio waveform / visualizer on album art** | Alcove + Boring signature look; makes Now Playing feel alive. | **MEDIUM–HIGH** | Real audio-tap visualizers need audio capture (hard); most apps fake a *decorative animated* waveform synced loosely to playback. Do the fake version — looks great, low risk. |
| **Color-adaptive UI from album art** | Boring's "magical color effects" — island tints to match the cover. | **MEDIUM** | Extract dominant color from artwork (`NSImage` average/quantize) and tint accents. Cheap, high visual payoff. |
| **Duo / multi-widget view** | Alcove shows two activities at once instead of switching. | **MEDIUM** | A layout choice; meaningful only after ≥2 activity types exist. |
| **Countdown / Pomodoro timer as a live activity** | In v1's later scope; Notchy + DynamicLake have it. | **LOW–MEDIUM** | A timer is pure SwiftUI + `Timer`; the value is rendering it *as an island activity*. Good "first feature the user can build mostly themselves" because it has no private-API risk. |
| **Sneak-peek (brief auto-expand on track change)** | Boring's "sneak peek" — glance without hovering. | **LOW** | Auto-expand for ~2s on a Now Playing change, then collapse. Cheap delight once the island + now playing exist. |
| **Per-event customization (which activities show, durations, theme)** | Power users expect to tune notch apps. | **MEDIUM** | Grows naturally; don't over-build settings before features exist. |

### Anti-Features (Tempting, but DO NOT build for v1 — especially as a beginner)

| Feature | Why Requested / Appealing | Why Problematic for v1 | Alternative |
|---------|---------------------------|-------------------------|-------------|
| **Messaging / notification mirroring (iMessage, WhatsApp, Slack)** | DynamicLake has it; feels "complete." | No clean API; needs Notification-Center scraping/accessibility hacks, fragile, privacy-loaded, per-app breakage. Huge effort, high maintenance. | Out of scope (already in PROJECT.md). Revisit only post-PMF. |
| **Calls / FaceTime / phone integration (DynaCall)** | Looks impressive. | Requires Continuity/CallKit-adjacent hooks that aren't public; brittle. | Skip entirely. |
| **Calendar + weather glance** | Notchy/DynamicLake/Boring all have it. | EventKit permissions + weather API + widget layout = a whole side-project that doesn't touch the core island value. | Defer to v2; it's additive, not foundational. |
| **Audio/video/image conversion, zip/unzip (DynamicLake "DynaConvert")** | Bundled-utility appeal. | Totally unrelated to the island; a kitchen-sink trap. | Never (out of product scope). |
| **Clipboard history manager** | Boring + Notchy ship it. | Separate product domain; storage, search, privacy. Scope creep. | Defer indefinitely. |
| **Camera mirror / teleprompter** | Boring + Notchy have it. | Camera permission, AVFoundation, layout — unrelated to island value. | Defer to v2 at earliest. |
| **Non-notch Mac / external-display "floating pill"** | DynamicLake + Notchy support it; bigger market. | Doubles the window-positioning/geometry complexity — the hardest part of the app — before the core even works. | Already out of scope in PROJECT.md. Hold the line. |
| **Synced lyrics (LRCLIB)** | Notchy's standout. | Network calls, sync logic, an extra dependency. Polish, not core. | v2 differentiator candidate, not v1. |
| **Mac App Store distribution** | Discoverability. | MediaRemote is a private API → guaranteed rejection. | Direct notarized download (already decided). |
| **Real audio-tap visualizer** | "True" waveform from actual audio. | Audio capture is genuinely hard + permission-heavy. | Ship a *decorative* animated waveform; visually indistinguishable to users. |

---

## Feature Dependencies

```
[Notch geometry detection]
    └──requires──> nothing (FOUNDATION — do first)
        └──enables──> [Island overlay window]
                          └──requires──> [Notch geometry detection]
                          └──enables──> [Expand/collapse + animation]
                                            └──enables──> EVERY activity below

[Expand/collapse + animation]
    └──enables──> [Charging activity]        (IOKit — independent data source)
    └──enables──> [Device-connect activity]  (IOBluetooth — independent data source)
    └──enables──> [Now Playing display]      (MediaRemote-adapter — independent data source)
                      └──enables──> [Play/pause/skip controls]
                      └──enables──> [Seek/scrub bar]
                      └──enhances──> [Waveform / color-adaptive UI / sneak-peek]
    └──enables──> [Timer activity]           (no external dependency — pure SwiftUI)

[System HUD replacement] ──requires──> [Island overlay] + system-HUD suppression (separate, fiddly)
[File shelf]            ──requires──> [Island overlay] + drag-drop plumbing (separate domain)

[Now Playing] ──depends critically on──> [mediaremote-adapter subprocess] (macOS 15.4+ workaround)
```

### Dependency Notes

- **Everything requires notch geometry + the overlay window.** This is the only true blocker; until the island reliably renders and animates over the physical notch, no activity can ship. Treat it as Phase 1 and over-invest in getting it solid.
- **The three activity data sources are independent of each other.** Charging (IOKit), device-connect (IOBluetooth), and Now Playing (MediaRemote-adapter) don't depend on one another — once the island exists, they can be built in any order or in parallel. Order them by *risk*, easiest-and-safest first.
- **Charging is the lowest-risk activity** (public IOKit API, simple plug/unplug event) — ideal as the *first* activity after the island, to prove the activity pattern end-to-end before tackling the harder MediaRemote path.
- **Now Playing carries the only architectural landmine** (the 15.4 adapter subprocess) — isolate it behind a clean interface so the rest of the app doesn't depend on its internals.
- **Timer has zero external dependencies** — it's the best candidate for the beginner to implement themselves to learn the activity/UI pattern.
- **HUD replacement and file shelf are separable sub-projects**, each with their own non-trivial OS-integration cost; neither blocks the core, so both belong in later phases.

---

## MVP Definition

### Launch With (v1) — matches PROJECT.md core, validated as correct

- [ ] **Notch geometry + borderless overlay window** — without this nothing else is possible. (FOUNDATION)
- [ ] **Expand-on-hover / collapse-on-idle with polished spring animation** — this *is* the product's value; the quality bar is Alcove.
- [ ] **Charging activity (plug/unplug animation + battery %)** — lowest-risk activity; proves the live-activity pattern. (IOKit)
- [ ] **Now Playing display (album art + title/artist) + play/pause/skip** — top install driver; multi-app source detection comes free. (MediaRemote-adapter)
- [ ] **Device-connected activity (AirPods/Bluetooth connect/disconnect event)** — completes the "reacts to my life" feel. (IOBluetooth)
- [ ] **Menu-bar item + minimal settings + launch-at-login** — required plumbing.

### Add After Validation (v1.x)

- [ ] **Seek/scrub bar + sneak-peek auto-expand** — trigger: Now Playing is solid and users want deeper control.
- [ ] **Color-adaptive tint + decorative waveform** — trigger: core stable, time to chase Alcove-level polish.
- [ ] **Countdown/Pomodoro timer activity** — trigger: good "user-built" feature; no API risk.
- [ ] **AirPods per-bud battery %** — trigger: connect event works and users ask for battery readout.

### Future Consideration (v2+)

- [ ] **Volume/brightness/battery HUD replacement** — defer: fiddly OS-HUD suppression, version-sensitive; high effort vs. island core.
- [ ] **Drag-and-drop file shelf (+ AirDrop)** — defer: separate drag-drop domain; reference NotchDrop when tackled.
- [ ] **Synced lyrics, calendar/weather glance, clipboard, camera mirror** — defer: additive, unrelated to core island value.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Notch overlay window + geometry | HIGH (enabling) | MEDIUM | **P1** |
| Expand/collapse animation polish | HIGH | HIGH | **P1** |
| Charging activity | HIGH | LOW–MEDIUM | **P1** |
| Now Playing (art + metadata + controls) | HIGH | MEDIUM (+ adapter risk) | **P1** |
| Device-connect activity | MEDIUM–HIGH | MEDIUM | **P1** |
| Menu bar + settings + launch-at-login | MEDIUM (required) | LOW | **P1** |
| Seek/scrub bar | MEDIUM | MEDIUM | **P2** |
| Sneak-peek auto-expand | MEDIUM | LOW | **P2** |
| Color-adaptive tint | MEDIUM | MEDIUM | **P2** |
| Decorative waveform | MEDIUM | MEDIUM | **P2** |
| Timer activity | MEDIUM | LOW–MEDIUM | **P2** |
| AirPods per-bud battery % | MEDIUM | MEDIUM–HIGH | **P2/P3** |
| HUD replacement (vol/bright) | MEDIUM | HIGH | **P3** |
| File shelf + AirDrop | MEDIUM–HIGH | HIGH | **P3** |
| Lyrics / calendar / clipboard / mirror | LOW–MEDIUM | HIGH | **P3** |

---

## Suggested Build Order (tuned for a first-time programmer)

1. **Plumbing skeleton** — menu-bar app (`MenuBarExtra`), launch-at-login (`SMAppService`), empty settings. *Why first:* tiny, no risk, teaches the app lifecycle and gives a runnable thing on day one.
2. **The island window** — borderless always-on-top `NSWindow` positioned over the notch using `NSScreen` safe-area/notch geometry; collapsed black pill that ignores mouse events except a hover zone. *Highest-risk foundation — do it before any activity.*
3. **Expand/collapse animation** — get the spring morph from pill → expanded panel feeling right against the Alcove bar. Iterate until smooth; this is where polish is won or lost.
4. **Charging activity** — first real live activity. Public IOKit power notifications, plug/unplug animation + %. *Chosen first because it's the safest data source* and proves the activity → island rendering loop end-to-end.
5. **Now Playing** — integrate `ungive/mediaremote-adapter` (BSD-3, bundle the Perl script + framework, run as subprocess, parse JSON over stdout). Album art + title/artist first, then play/pause/skip. *Isolate behind a clean Swift interface* because of the 15.4 fragility.
6. **Device-connected activity** — `IOBluetooth` connect/disconnect event (skip per-bud battery for now).
7. **Polish pass** — sneak-peek auto-expand, color-adaptive tint, decorative waveform, seek bar. Ship v1.
8. *(Later phases)* — timer → file shelf → HUD replacement.

---

## Competitor Feature Analysis

| Feature | Alcove | DynamicLake Pro | TheBoringNotch (OSS) | Notchy (free) | Our v1 Approach |
|---------|--------|------------------|----------------------|---------------|-----------------|
| Hover-expand island | Yes (gestures + hover) | Yes | Yes | Yes (+ pill on non-notch) | **Yes** — match Alcove's feel |
| Now Playing art + controls | Yes (+ waveform, seek, volume) | Yes (DynaMusic) | Yes (visualizer) | Yes (+ lyrics) | **Yes** — art + controls + seek |
| Multi-app source detection | Yes | Yes | Yes (MediaRemoteAdapter) | Yes | **Yes** (free via adapter) |
| Charging/battery activity | Yes | Yes | Roadmap | Yes | **Yes** (IOKit) |
| AirPods/Bluetooth connect | (devices notif) | Yes | Roadmap | Yes (+per-bud battery) | **Yes** event; battery later |
| Volume/brightness HUD | Yes | Yes | Yes | Yes | **v2** (defer) |
| File shelf + AirDrop | No (deliberate) | Yes (DynaClip) | Yes | Yes | **Later phase** |
| Timer | No | Yes | No | Yes (Pomodoro) | **v1.x** |
| Lyrics / calendar / clipboard / mirror | No | Some | Some | Yes (many) | **Out of scope v1** |
| Non-notch / external display | No | Yes | No | Yes | **Out of scope** (decided) |
| Distribution | Direct notarized | Direct | OSS / direct | Direct | **Direct notarized** |

**Read of the field:** Alcove proves that doing *only* the core island + Now Playing + activities + HUDs, but doing it beautifully, is a viable ~$17 product. Notchy/DynamicLake prove the maximalist long tail exists but is mostly noise relative to the core. The project's instinct — match Alcove's polish on a focused core, defer the DynamicLake long tail — is the correct strategy and is reflected in the build order above.

---

## Critical Pitfall Flag (for PITFALLS.md / requirements)

**MediaRemote is locked down on macOS 15.4+.** Since macOS 15.4, Apple's `mediaremoted` daemon enforces an entitlement check; apps loading `MediaRemote.framework` directly get `nil`/denied for Now Playing. Direct framework calls **no longer work** on current macOS. The proven workaround (used by TheBoringNotch and others) is **`ungive/mediaremote-adapter`** (BSD-3-Clause): bundle a Perl script + helper framework and run `/usr/bin/perl mediaremote-adapter.pl <framework> <command>` as a **subprocess** (the `com.apple.perl` bundle ID is entitled), streaming JSON (metadata, base64 album art, position) over stdout, and sending play/pause/skip/seek back. This means Now Playing requires **subprocess management + JSON parsing**, not a simple framework call — the single biggest hidden complexity in v1. Confirmed across ungive/mediaremote-adapter, nowplaying-cli issue #28, LyricFever issue #94, and TheBoringNotch's dependency notes. **HIGH confidence.**

---

## Sources

- Alcove — tryalcove.com; alternativeto.net/software/alcove/about (Now Playing: album art, waveform, seek bar, volume via gesture/click/hover; battery/device/focus notifications; vol+brightness HUDs; Duo view; ~$17 one-time; Swift 6; Henrik Ruscon)
- DynamicLake Pro — dynamiclake.com (DynaMusic, DynaGlance calendar+weather, DynaCall, notifications, DynaClip file shelf + AirDrop, DynaDrop, timer, battery alerts, conversion, non-notch support)
- TheBoringNotch — theboring.name; github.com/TheBoredTeam/boring.notch (Swift/SwiftUI, GPL-3.0; music visualizer, color effects, file shelf via NotchDrop, HUD replacement, clipboard, camera; **MediaRemoteAdapter** dependency; roadmap: charging indicator, Bluetooth live activity, HUD, weather)
- Notchy — notchy.dev (SwiftUI, free, ~0% CPU; Now Playing + scrub + LRCLIB lyrics; file shelf; vol/brightness HUDs; AirPods per-bud battery + audio switcher; Pomodoro timer + Focus integration; teleprompter; clipboard; calendar; many utilities; floating pill on non-notch)
- raphaeljourney.com/blogs/best-notch-apps-macbook; getseam.app/blog/boring-notch-alternatives (positioning/pricing comparison)
- **MediaRemote 15.4 lockdown:** github.com/ungive/mediaremote-adapter; feedback-assistant/reports issue #637; kirtan-shah/nowplaying-cli issue #28; aviwad/LyricFever issue #94
- Battery/IOKit & Bluetooth: blog.brightcoding.dev Boring Notch writeup; macrumors battery/IOKit thread

---
*Feature research for: native macOS notch / Dynamic Island utility app*
*Researched: 2026-06-26*
