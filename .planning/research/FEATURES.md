# Feature Research — v1.6 Liquid Glass & System HUD Suite

**Domain:** macOS notch-overlay "Dynamic Island" utility (Islet) — material redesign + system HUD suite
**Researched:** 2026-07-15
**Confidence:** MEDIUM (HIGH on codebase-integration facts, MEDIUM on private-API HUD techniques — community-verified, not Apple-documented)

## Existing Architecture This Milestone Must Integrate With

Confirmed by reading the current codebase directly (not assumed):

- **`IslandResolver.swift`** — the single pure `resolve(...)` reducer. Ranks `Charging > Device > NowPlaying`, transients (`ActiveTransient`: `.charging`/`.device`) flow through `TransientQueue` (bounded depth 2, deduped, sequential — never overlapping). `IslandPresentation` is a closed enum switched on everywhere (view render + click-through geometry via `showsSwitcherRow`).
- **`TransientQueue`** — FIFO, `maxDepth = 2`, `enqueue`/`advance`/`updateHead`/`removeAll(where:)`. Every new transient-style HUD (Volume, Brightness, Focus, Update, Bluetooth-restyle, Charging-restyle) is a candidate to become a **new `ActiveTransient` case**, not a parallel mechanism — this queue already solves "two things happen at once, show sequentially" for exactly this problem.
- **`activityDuration = 3.0`** in `NotchWindowController.swift` — the single shared auto-dismiss timer (`DispatchQueue.main.asyncAfter`), used today for Charging/Device wings. New HUDs reusing this constant get "the same feel for free"; per-HUD custom durations (e.g. Calendar countdown must NOT auto-dismiss after 3s) need their own timer, a deliberate divergence from the shared pattern.
- **`ActivitySettings.swift`** — single source of truth for `@AppStorage` keys, shared verbatim between `SettingsView` and the controller. Each of the 8 new HUDs needs its own toggle key here (mirroring `chargingKey`/`deviceKey`/`nowPlayingKey`), following the established default-ON convention.
- **`ShelfViewState.swift`** — `isVisible: Bool { !items.isEmpty }` is the ONLY shelf-visibility signal that exists today. **There is no "session" concept and no "shelf closed" event anywhere in the codebase.** This is a concrete, confirmed gap (see Drop-Session Summary Chip below).
- **`showsSwitcherRow(for:)`** — a WR-01-fixed single shared function both the view and the controller's click-through geometry call; any new `IslandPresentation` case must be added here too or it silently reintroduces the CR-01-class click-through bug (documented project memory: `cr01-clickthrough-or-defeat-gotcha`).

## Feature Landscape

### Table Stakes (users expect these, given the milestone's Droppy-parity framing)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Bluetooth/AirPods HUD (restyle) | Already shipped as Device-Connected activity — this is a pure visual reskin, not new capability | LOW | Zero new data/monitor work. `DeviceCoordinator`/`BluetoothMonitor` untouched; only `DeviceActivity`'s rendered view changes to the Droppy pill look + adopts Liquid Glass material. Safe to ship independently of every other HUD. |
| Charging HUD (restyle) | Same — already shipped, purely visual | LOW | Same shape as Bluetooth restyle: `ChargingActivity` view redesign only, `TransientQueue`/IOKit monitor untouched. Two nearly-identical low-risk phases, natural pairing. |
| Liquid Glass material redesign | Sets the whole app's visual bar; every other HUD in this milestone renders inside this material, so sequencing it first avoids re-skinning 8 features twice | MEDIUM | Touches shared rendering surfaces (`islandMaterial`, `MaterialStyle` enum in `ActivitySettings.swift`) used by pill + expanded + all wings — a "blast radius" change like Phase 25 (Visual/Material Theming), which the codebase history shows was successfully isolated to 2 files with zero behavior change. User supplies reference code, lowering design-decision risk; execution risk is in visual regression across every existing activity. |
| Volume HUD | Droppy's headline system-HUD feature; users comparing against Droppy/Alcove will look for this first | HIGH | Two separable problems: (1) reading the live volume value on change — LOW complexity via a `CGEventTap`/media-key monitor (`NX_KEYTYPE_SOUND_UP/DOWN/MUTE`), a well-precedented technique. (2) **suppressing the native system OSD so both don't show at once** — the hard, undocumented part (see Anti-Features/Pitfalls below). Ship (1) even if (2) proves infeasible; a redundant-but-present native OSD is a worse UX than no custom HUD, so (2) is not optional for a *good* result, just for a *shippable* one. |
| Brightness HUD | Same category as Volume, users expect the pair together | HIGH | Same two-part shape as Volume (key interception + OSD suppression via `NX_KEYTYPE_BRIGHTNESS_UP/DOWN`). Should share the bulk of its implementation with Volume HUD (one generic "OSD replacement" subsystem, two thin front-ends) rather than being built as a fully separate feature — avoids duplicating the risky suppression logic. |

### Differentiators (Droppy has these; genuinely sets Islet apart from a "just Now Playing" notch app)

| Feature | Value Proposition | Complexity | Notes |
|---------|--------------------|------------|-------|
| Focus Mode HUD | Visually confirms a Focus/DND toggle the user just made system-wide — no other notch competitor studied in this project's research does this cleanly | HIGH | Detection is undocumented: community precedent (`sindresorhus/do-not-disturb`) reads `CFPreferencesGetAppBooleanValue("doNotDisturb", "com.apple.notificationcenterui")` and observes the distributed notification `"com.apple.notificationcenterui.dndprefs_changed"` — **this only reliably reports the legacy binary DND flag; modern named Focus modes (Work/Personal/Sleep) are not guaranteed to surface via the same key on current macOS.** Confirm on real hardware early; do not assume the label text ("Work Focus" vs generic "Focus On") is obtainable — may have to ship a generic "Focus enabled/disabled" pill rather than a named-mode pill. |
| Update-available HUD + real Sparkle | Net-new capability (auto-update didn't exist before); pairs directly with distribution maturity already invested in (notarization pipeline exists since v1.1) | HIGH | Two coupled parts: (a) adding Sparkle 2 (`SPUUpdater`/`SPUStandardUpdaterController`) is a well-trodden, HIGH-confidence integration (official docs). (b) making the *notification* appear as a notch HUD instead of Sparkle's native alert window requires implementing a custom `SPUUserDriver` (not just a delegate) — Sparkle's default UI is a full permission/progress/install alert flow; the custom driver protocol has several required methods (permission request, download progress, ready-to-install, relaunch) that all need *some* UI even if minimal. Scope risk: doing (a) with default Sparkle UI is LOW complexity and could ship as a fallback if the custom-HUD driver proves too deep for this milestone. |
| Onboarding signature animation | Pure delight/polish moment, first-impression differentiator, scoped to exactly one screen | MEDIUM | Standard technique: `CTFontCreatePathForGlyph` (or a hand-authored `Path`/SVG-imported signature asset) driven by `.trim(from:0, to:progress)` + `.stroke`, animated via `TimelineView` or a simple `withAnimation` on `progress`. Coordinate-system gotcha (Core Text glyph paths need a per-glyph Y-flip transform to match SwiftUI's Shape coordinate space) is well-documented in tutorials — LOW technical risk, mostly visual-tuning time. Fully independent of every other v1.6 feature — safe to build/ship standalone. |
| Calendar countdown HUD | Most "smart"/context-aware HUD in the set — genuinely differentiates from a generic HUD-replacement utility toward an assistant-like feel | MEDIUM | Data already exists (`EventKit` integration shipped in Phase 28's Calendar view) — this is a NEW trigger/presentation on top of existing data, not a new data source. Complexity is in the **timer shape**, not the data: needs a live per-minute tick while the pill is showing (unlike every other transient here, it must NOT auto-dismiss after 3s — it should persist/update continuously from T-60min until the event starts or is dismissed by a higher-priority transient). This breaks the "one shared `activityDuration`" assumption and needs its own update loop, closer in shape to the Now Playing progress bar's continuous-glide pattern (Phase 7) than to the Charging/Device splash pattern. |
| Music equalizer bars redesign | Visual differentiator on the single most-viewed live activity (Now Playing) | LOW-MEDIUM | Pure view-layer change to the existing bars component; user supplies reference design. No data/monitor/resolver touch — same "safe to isolate" shape as the Charging/Bluetooth restyles. Independent of Liquid Glass but likely sequenced to render correctly inside the new material once both exist. |
| Dual-activity display (main pill + secondary bubble) | The single most structurally novel feature in this milestone — extends the resolver's core "one winner" model, which is the app's oldest and most load-bearing architectural decision (`COORD-01`, Phase 6) | HIGH | Apple's own Dynamic Island precedent (iOS, HIG-documented, MEDIUM-HIGH confidence, multiple corroborating sources) resolves exactly this with a **compact pill (leading+trailing) + a small detached "minimal" bubble** for a second concurrent Live Activity — validates the milestone's own "main pill + secondary bubble" framing as the right shape, not a novel invention. Implementation-wise this means: `resolve(...)` (or a new sibling reducer) must return a *pair* (primary presentation + optional secondary summary) instead of today's single `IslandPresentation`, and `TransientQueue`/`ActiveTransient` need a second concurrent slot rather than remaining strictly sequential for this one case. This is the highest-risk architecture change in the milestone — recommend it lands LAST, after every individual HUD already exists as a single-winner presentation, so the two-slot extension has real cases to test against rather than being built speculatively. |

### Anti-Features (things this research flags as looking good but not worth building as scoped)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Named/labeled Focus Mode HUD ("Work Focus", "Sleep", "Do Not Disturb" distinctly) | Droppy's screenshot shows a generic "Focus Mode" toggle line, but a "smarter" version showing the *actual* mode name feels more premium | The only community-verified read path (`doNotDisturb` CFPreferences key) is confirmed to expose the legacy binary DND flag; there is no confirmed public-or-quasi-public path to the specific named Focus mode on current macOS as of this research. Building UI that assumes a mode name is available risks a phase stalling on an unverified technical unknown | Ship the generic "Focus Mode On/Off" pill Droppy itself shows; treat named-mode detection as a stretch goal only if a research phase confirms a working read path on the actual dev machine |
| Full custom Sparkle install/progress UI inside the notch (download progress bar, relaunch countdown, etc., all HUD-native) | "Everything should be Droppy-styled, including the whole update flow" | Sparkle's `SPUUserDriver` protocol requires handling roughly 10 callback points (permission request, download start/progress, extraction, ready-to-install, installing, relaunching); replicating all of them as bespoke notch UI is a disproportionate amount of net-new plumbing for a feature whose actual job is "tell the user an update exists" | Ship only the "update available" *notification* as a notch HUD (tap it to trigger Sparkle's own standard install dialog/progress); this satisfies the milestone's actual stated need ("Update-available HUD paired with real Sparkle") without rebuilding Sparkle's entire UI surface |
| True volume/brightness OSD suppression via the undocumented `defaults write com.apple.controlcenter EnableSystemBanners -bool false` toggle, shipped silently with no fallback | It is the one community-known trick that reportedly disables the native banner on current macOS | It is an undocumented system-wide user-default toggle on Apple's own Control Center domain, not a per-app entitlement — it changes system behavior outside just Islet's own window, is unverified in this research beyond community forum discussion (MEDIUM confidence, not Apple docs), and could silently break/reverse on any macOS point release without warning | Treat OSD suppression as a flagged research spike, not an assumed-solved dependency; design Volume/Brightness HUD's phase plan with an explicit fallback ("HUD shows alongside the native OSD, duplicated but not broken") if suppression proves unreliable on the actual dev machine |

## Feature Dependencies

```
Liquid Glass material
    └──renders-under──> every HUD/activity view in this milestone (all 8 HUDs, equalizer bars, restyles)
        (sequencing note: NOT a hard blocker — each HUD can be built against today's gradient
         material and re-skinned once Liquid Glass lands, mirroring how Phase 25's material
         swap touched only rendering, not logic. But building it FIRST avoids re-touching 8 views.)

Bluetooth HUD restyle ──requires──> nothing new (DeviceCoordinator/BluetoothMonitor already shipped)
Charging HUD restyle  ──requires──> nothing new (existing IOKit monitor already shipped)

Volume HUD
    └──requires──> "OSD replacement subsystem" (key interception + suppression spike)
Brightness HUD
    └──requires──> same "OSD replacement subsystem" (shares the suppression mechanism with Volume)

Focus Mode HUD ──requires──> Focus/DND detection spike (CFPreferences + distributed notification read)
    └──partially-blocks──> "named mode" stretch goal (unverified, likely descoped to generic on/off)

Update-available HUD ──requires──> Sparkle 2 integration (net-new dependency, standard SPM add)
    └──requires──> a minimal custom SPUUserDriver (or: fallback to default Sparkle alert UI)

Calendar countdown HUD ──requires──> EventKit data (ALREADY SHIPPED, Phase 28)
    └──requires──> its own continuous per-minute timer (does NOT reuse shared `activityDuration`)

Drop-session summary chip ──requires──> a NEW "shelf session" concept that DOES NOT EXIST TODAY
    (ShelfViewState.isVisible is purely !items.isEmpty; there is no tracked "session began /
     session ended" boundary, and no "Tray was just closed" event — closing today means either
     isExpanded flipping false while selectedView == .tray, or switching selectedView away from
     .tray. Both are observable in NotchWindowController but NEITHER is currently captured as a
     discrete event.)

Dual-activity display (main pill + secondary bubble)
    └──requires──> IslandResolver extended to a two-slot model (HIGH-risk architecture change)
    └──best-informed-by──> at least 2 real single-winner HUD cases already shipped
                            (e.g. Calendar countdown + Now Playing, the milestone's own example)
```

### Dependency Notes

- **Bluetooth/Charging restyles have ZERO new dependencies** — they are the lowest-risk, most independently-shippable items in the whole milestone. Good candidates for the very first phase or for parallelizing alongside the Liquid Glass material work.
- **Volume + Brightness should be ONE phase's worth of shared plumbing**, not two independent builds — the interception technique (media-key event tap) and the suppression technique (OSD banner defeat) are identical in shape between the two; only the read source (display-brightness services vs CoreAudio) differs.
- **Drop-session summary chip is the one target feature this research found to have a genuine, unbuilt prerequisite.** It cannot be built as "just another HUD restyle" — it needs a small new piece of state (session start/end tracking) added to `ShelfViewState`/`ShelfCoordinator` or the controller before the chip itself has anything to trigger on. Flag this explicitly for the roadmap: either (a) add a lightweight `ShelfCoordinator` session boundary as a first task within this feature's phase, or (b) approximate it by triggering the chip off the existing `isVisible` transition from `true→false` (simpler, but conflates "closed after a drop session" with "shelf emptied by deleting the last item," which may not be the same UX moment Droppy shows).
- **Calendar countdown HUD conflicts in *shape* (not logic) with the shared `activityDuration` pattern.** Every existing transient (Charging, Device) auto-dismisses after a fixed 3s. A countdown HUD that must stay live and ticking for up to 60 minutes needs its own persistent timer, closer to the Now Playing progress bar's continuous-glide mechanism (Phase 7) than to `TransientQueue`'s fire-and-forget model. This is a genuine architectural fork the roadmap should call out, not an oversight to fix later.
- **Dual-activity display should be sequenced LAST among the HUD-adding phases.** It is explicitly framed in the milestone goal as generalizing "beyond just Calendar+Music to any two competing top-priority activities" — building it before at least two concrete competing HUDs exist (e.g., Calendar countdown HUD + Now Playing) means designing the two-slot resolver extension against a hypothetical rather than a real collision case, which this codebase's own conventions (pure-seam-first, `resolve()` as the single arbiter) argue against.
- **Liquid Glass is not a hard blocker for the HUD phases**, but re-skinning is cheaper once, not eight times — recommend it early but not necessarily strictly first if sequencing pressure exists elsewhere (e.g., de-risking the Volume/Brightness OSD-suppression unknown sooner).

## MVP Definition (for this milestone, not the whole product)

### Launch With (v1.6 core)

- [ ] Liquid Glass material — every other visual feature in this milestone renders inside it
- [ ] Bluetooth HUD restyle — zero-risk, proves the new Droppy-pill visual language on a real activity
- [ ] Charging HUD restyle — same, second proof point
- [ ] Drop-session summary chip (with its session-boundary prerequisite built first) — the only feature this research found to have a genuine missing dependency; worth surfacing to the user/roadmap explicitly rather than discovering it mid-phase

### Add After Validation (rest of v1.6, sequenced by risk)

- [ ] Music equalizer bars redesign — independent, low-risk, user-supplied reference
- [ ] Onboarding signature animation — independent, low-risk, purely additive
- [ ] Calendar countdown HUD — needs its own timer shape, but data already exists
- [ ] Update-available HUD + Sparkle — net-new dependency; consider shipping with Sparkle's own default alert UI first, custom HUD-native driver as a stretch
- [ ] Volume HUD, Brightness HUD — HIGH complexity, genuine private-API unknowns; treat as a combined research spike before committing to a full phase plan
- [ ] Focus Mode HUD — generic on/off only; named-mode detection is unverified, do not commit to it without an on-device spike first

### Future Consideration (beyond v1.6)

- [ ] Named/labeled Focus Mode detection — only if a future spike finds a reliable read path
- [ ] Full custom Sparkle install/progress flow rendered entirely as notch HUD — current milestone only needs the "available" notification, not the whole install UX
- [ ] Dual-activity display generalized to 3+ concurrent activities — the milestone explicitly scopes this to exactly two; a third-slot model is out of scope until two-slot ships and is validated on real usage

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Liquid Glass material | HIGH | MEDIUM | P1 |
| Bluetooth HUD restyle | MEDIUM | LOW | P1 |
| Charging HUD restyle | MEDIUM | LOW | P1 |
| Music equalizer bars redesign | MEDIUM | LOW-MEDIUM | P1 |
| Onboarding signature animation | LOW-MEDIUM | MEDIUM | P2 |
| Drop-session summary chip | MEDIUM | MEDIUM (session-tracking prerequisite) | P1 |
| Calendar countdown HUD | HIGH | MEDIUM | P2 |
| Update-available HUD + Sparkle | HIGH (product maturity) | HIGH | P2 |
| Volume HUD | HIGH | HIGH (unverified suppression) | P2/spike-first |
| Brightness HUD | HIGH | HIGH (shares Volume's unknown) | P2/spike-first |
| Focus Mode HUD | MEDIUM | HIGH (unverified named-mode) | P2/spike-first, generic-only |
| Dual-activity display | HIGH (architectural novelty) | HIGH | P3 — sequence last |

**Priority key:**
- P1: Low-risk, high-confidence, independently shippable this milestone
- P2: Real value but carries a genuine technical unknown or new dependency — needs its own spike/research before a full phase plan
- P3: Sequence last — depends on other phases existing first to be well-designed rather than speculative

## Individual HUD Assessment (all 8, per the quality gate)

| # | HUD | Table stakes / Differentiator | Complexity | Key dependency |
|---|-----|-------------------------------|------------|-----------------|
| 1 | Volume HUD | Table stakes (Droppy has it, Alcove has it) | HIGH | New "OSD replacement subsystem" (media-key tap + undocumented suppression) |
| 2 | Brightness HUD | Table stakes | HIGH | Same subsystem as #1 |
| 3 | Focus Mode HUD | Differentiator | HIGH | Focus/DND detection spike; named-mode likely unavailable |
| 4 | Update-available HUD | Differentiator (net-new capability) | HIGH | Sparkle 2 integration + custom `SPUUserDriver` (or default-alert fallback) |
| 5 | Bluetooth/AirPods HUD | Table stakes (pure restyle) | LOW | None — `DeviceCoordinator` already shipped |
| 6 | Charging HUD | Table stakes (pure restyle) | LOW | None — IOKit monitor already shipped |
| 7 | Drop-session summary chip | Differentiator | MEDIUM | Missing "shelf session" boundary concept — must be added first |
| 8 | Calendar countdown HUD | Differentiator | MEDIUM | EventKit data already shipped; needs its own non-`activityDuration` timer |

## Sources

- Codebase read directly (HIGH confidence): `Islet/Notch/IslandResolver.swift`, `Islet/ActivitySettings.swift`, `Islet/Shelf/ShelfViewState.swift`, `Islet/Notch/NotchWindowController.swift` (grep-confirmed `activityDuration`/`selectedView`/`trayExpanded` sites), `.planning/PROJECT.md`.
- [dannystewart/volumeHUD](https://github.com/dannystewart/volumeHUD) — confirms media-key interception + a "did volume actually change" safety check pattern (MEDIUM confidence, implementation details not fully public).
- [AlexPerathoner/SlimHUD](https://alexperathoner.github.io/SlimHUD/) — precedent for a general volume/brightness/keyboard-backlight HUD replacement app (MEDIUM).
- [MonitorControl discussion #1873](https://github.com/MonitorControl/MonitorControl/discussions/1873) — community-verified `defaults write com.apple.controlcenter EnableSystemBanners -bool false` OSD-suppression workaround on macOS Tahoe (MEDIUM — forum-sourced, undocumented by Apple).
- [sindresorhus/do-not-disturb](https://github.com/sindresorhus/do-not-disturb) — confirms `CFPreferencesGetAppBooleanValue("doNotDisturb", "com.apple.notificationcenterui")` + distributed notification `"com.apple.notificationcenterui.dndprefs_changed"` as the working legacy-DND read/observe mechanism; explicitly does not work sandboxed (MEDIUM-HIGH, source read directly).
- Apple Developer Forums thread 729475, "Programmatic Activation and Deactivation of Focus Mode" — corroborates that named-Focus-mode access is an open community question, not a solved/documented API (MEDIUM).
- [Sparkle official docs — Customizing Sparkle](https://sparkle-project.org/documentation/customization/), [SPUUpdaterDelegate reference](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUpdaterDelegate.html) — confirms Sparkle 2's `SPUUpdater`/custom `SPUUserDriver` as the modern path to fully custom update UI, superseding the deprecated `SUUpdater`/`SUUpdaterDelegate` (HIGH — official docs).
- SwiftUI handwriting-animation tutorials (Medium "How to Animate Handwriting in SwiftUI", SwiftUISnippets "Converting Font to Shape in SwiftUI") — confirm `CTFontCreatePathForGlyph` + `.trim`/`.stroke` as the standard technique, including the Core-Text-vs-SwiftUI coordinate-flip gotcha (MEDIUM, multiple tutorials agree).
- Apple Human Interface Guidelines coverage of Dynamic Island multi-activity behavior (Infinum "Start Designing for Dynamic Island and Live Activities", Canopas "Integrating Live Activity and Dynamic Island") — confirms the real iOS precedent for "compact pill + detached minimal bubble" when two Live Activities compete, directly validating this milestone's "main pill + secondary bubble" framing (MEDIUM-HIGH, multiple sources agree, though iOS not macOS).

---
*Feature research for: Islet v1.6 (Liquid Glass & System HUD Suite)*
*Researched: 2026-07-15*
