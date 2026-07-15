# Project Research Summary

**Project:** Islet v1.6 — Liquid Glass & System HUD Suite
**Domain:** Native macOS notch-overlay utility (Dynamic Island clone) — material redesign + system HUD suite, extending an existing shipped app
**Researched:** 2026-07-15
**Confidence:** MEDIUM overall (HIGH on codebase integration facts and Sparkle; MEDIUM on Liquid Glass; LOW-MEDIUM on Volume/Brightness OSD suppression and Focus Mode detection — both undocumented/private-API territory)

## Executive Summary

This milestone adds a Liquid Glass material redesign plus 7 new HUD-style features (Volume, Brightness, Focus Mode, Update-available, Bluetooth/Charging restyles, Drop-session summary chip, Calendar countdown, and a dual-activity "main pill + secondary bubble" display) on top of Islet's existing, well-proven single-arbiter architecture (`IslandResolver`/`TransientQueue`/`IslandPresentation`). All four research streams converge on the same conclusion: this is **not** a uniform bucket of "8 new HUDs" — each feature has a genuinely different risk profile and a different-shaped integration into the existing codebase, and the roadmap must reflect that rather than treating them as interchangeable phases.

Two features carry real, undocumented-API risk that could fail to ship as scoped: **Volume/Brightness OSD suppression** (via `CGEventTap` — achievable, proven by the reference app Droppy, but with a confirmed macOS-Tahoe-specific regression mode where the wrong tap variant breaks transport keys system-wide) and **Focus Mode detection** (no supported API exists; the only working path polls an undocumented file gated behind a manual, unprompted Full Disk Access grant — a real UX cost that may not be acceptable). Both should get a dedicated research/spike phase before any UI is built around them, exactly as this project's own established pattern (Phase 22 drag-in spike, Phase 8→9 fullscreen escalation) already prescribes. The remaining features are lower-risk: Liquid Glass is pure SwiftUI/AppKit composition (risk is self-inflicted — this project already broke `matchedGeometryEffect` continuity once doing exactly this class of change), Sparkle is a well-trodden integration with known sharp edges around LSUIElement focus behavior, and the dual-activity display is a pure architecture problem (no private APIs) best solved as an **additive** `secondary: SecondaryActivity?` field rather than reshaping the single load-bearing `IslandPresentation` enum.

The clear throughline across all four docs: **classify each of the 8 features by its actual display semantics** (pure restyle / new transient / one-shot toast / orthogonal badge / ambient single-winner / dual-slot) and route each through the *simplest existing pattern* that already fits, rather than uniformly bolting all of them onto `IslandResolver` as new cases. Sequencing should front-load the zero-risk restyles and the material redesign, prove the "new transient case" pattern once cheaply (Focus Mode, before Volume/Brightness), isolate the two genuine unknowns as spikes, and land the dual-activity display last, after its two flagship inputs (Now Playing, Calendar countdown) are independently stable.

## Key Findings

### Recommended Stack

No new core stack — this milestone extends the existing SwiftUI/AppKit/IOKit/mediaremote-adapter baseline documented in `CLAUDE.md`. New additions are narrowly scoped:

**Core additions:**
- **`.glassEffect()`/`NSGlassEffectView`** (macOS 26.0+) — Apple's real Liquid Glass material; requires raising the deployment target from 15.0→26.0 if the user's reference code targets it. Fallback: layered `.ultraThinMaterial` + gradient stroke borders on the current 15.0 floor if not.
- **`CGEventTap` on `NX_SYSDEFINED` events** — intercept volume/brightness hardware keys before the system OSD renders; requires **Accessibility** permission (not just Input Monitoring), and must use `.cgSessionEventTap` (not the annotated variant, which breaks transport keys on Tahoe).
- **`DisplayServices.framework`** (private) — the only reliable way to set brightness on Apple Silicon; `CoreDisplay` alone doesn't work.
- **`INFocusStatusCenter`** (public, boolean-only) for a generic on/off Focus signal — the only viable path is otherwise polling an undocumented, Full-Disk-Access-gated file (`~/Library/DoNotDisturb/DB/Assertions.json`), confirmed broken on Tahoe for named-mode detail.
- **Sparkle 2.9.4** via SPM — standard auto-update framework for direct-distributed, notarized apps; needs the same `disable-library-validation` re-signing treatment already established for `MediaRemoteAdapter.framework`.
- **Pure SwiftUI composition** (`ZStack`, `.overlay`, a second `matchedGeometryEffect` namespace, `Text(timerInterval:)`) covers the dual-activity bubble and countdown text — no new library needed.

### Expected Features

**Must have (table stakes):** Bluetooth/AirPods HUD restyle, Charging HUD restyle (both zero-risk pure view-layer reskins of already-shipped activities), Liquid Glass material redesign (sets the visual bar every other feature renders inside), Volume HUD, Brightness HUD (Droppy-parity headline features, but the OSD-suppression half is the milestone's hardest unknown).

**Should have (differentiators):** Focus Mode HUD (generic on/off only — do not commit to named-mode detection), Update-available HUD + real Sparkle (ship Sparkle's standard alert UI first; a custom in-notch driver is a stretch goal), Onboarding signature animation, Calendar countdown HUD (data already exists via EventKit from Phase 28; needs its own non-shared timer shape), Music equalizer bars redesign, Dual-activity display (the single most architecturally novel item — sequence last).

**Defer / anti-features:** Named/labeled Focus Mode ("Work Focus" vs generic) — no verified read path exists on current macOS. Full custom Sparkle install/progress UI as notch-native HUD — disproportionate plumbing for "tell the user an update exists." The undocumented `EnableSystemBanners` Control-Center-wide defaults toggle for OSD suppression — too broad/unverified/reversible-by-Apple to depend on; use event-tap consumption instead.

### Architecture Approach

Islet's existing architecture is a single pure arbiter (`IslandResolver.resolve()`) ranking activities (Charging > Device > NowPlaying) into a bounded, deduped `TransientQueue`, with `IslandPresentation` as the one enum every render/click-through site switches over. The critical finding: **the 7 new HUDs are NOT architecturally uniform** — they split into three shapes that must be handled differently:

**Major components / treatment by shape:**
1. **Pure restyles** (Bluetooth, Charging) — zero resolver change, view-layer only.
2. **New rare/discrete transients** (Focus, and eventually Volume/Brightness) — new `ActiveTransient` cases mirroring `PowerActivity`'s pure-seam shape; Volume/Brightness additionally need `TransientQueue.updateHead()` (not `enqueue()`) for scrub-tick continuity, since they're high-frequency unlike Charging/Device.
3. **Orthogonal, non-resolver state** — Update-available (a `@Published` badge flag, not a queue participant, since it has no expiry), Drop-session summary chip (reuses the already-shipped Phase-18 song-change-toast pattern), Calendar countdown (ambient single-winner tier, its own 30s local re-derive timer, NOT the shared `activityDuration`).
4. **Dual-activity display** — additive `secondary: SecondaryActivity?` field and a new `resolveSecondary()` function scoped to only fire during ambient/idle states, explicitly NOT a reshape of `IslandPresentation` (reshaping it would touch every exhaustive switch site simultaneously — the exact CR-01/CR-02 failure class this project has already hit).

Build order across all four research docs converges on 6 waves: (1) Liquid Glass + cosmetic restyles, (2) low-risk toast/transient patterns proven cheaply (drop-session chip, Focus Mode), (3) Volume/Brightness spike, (4) Sparkle (independent, any time after wave 1), (5) Calendar countdown as single-winner, (6) dual-activity display last.

### Critical Pitfalls

1. **Wrong `CGEventTap` variant breaks transport keys on Tahoe** — use `.cgSessionEventTap`, never the annotated variant; explicitly test all 4 transport keys + volume/brightness on-device after wiring the tap; requires Accessibility permission, not just Input Monitoring.
2. **Focus Mode detection has no supported API** — the only working path (Assertions.json polling) requires a manual, unprompted Full Disk Access grant with zero automatic TCC prompt; must design an explicit onboarding step and a silent-degrade fallback if denied; confirm UX acceptability via spike before committing scope.
3. **Custom Liquid Glass material can re-break `matchedGeometryEffect` continuity (WR-02 recurrence)** — apply the new material as a modifier on the *existing* shape node that already carries the `matchedGeometryEffect` id, never as a new sibling/wrapper view; re-run the Phase-25 7-point on-device UAT checklist as a hard merge gate.
4. **Dual-activity resolver extension races two independently-updating activities** — keep the "one pure arbiter" principle: a single reduce pass producing `(primary, secondary)`, not two independent resolver paths; use distinct `matchedGeometryEffect` namespaces per slot, not shared ids.
5. **Bypassing `IslandResolver` for "simple" HUDs reintroduces the exact scattered-priority bug class the resolver was built to prevent** — every new HUD type, no exceptions, routes through the resolver/`TransientQueue` or an already-established orthogonal pattern (toast/badge); write the full cross-HUD priority table before splitting work across phases.
6. **Sparkle's default alert UI conflicts with Islet's "never steals focus" design principle in an LSUIElement app** — verify current Sparkle 2.x CHANGELOG behavior explicitly rather than trusting older tutorials; decide up front whether to suppress Sparkle's UI in favor of a custom in-notch update HUD.

## Implications for Roadmap

Based on research, suggested phase structure (6 waves, mapped to phases):

### Phase 1: Liquid Glass Material
**Rationale:** Every other new HUD/wing view in this milestone renders inside this material — building it first means new HUDs inherit it for free instead of retrofitting N+1 call sites.
**Delivers:** Extended `islandFill`/material seam (`ActivitySettings.MaterialStyle` gains `.liquidGlass`), single shared definition across pill/expanded/wings.
**Uses:** `.glassEffect()`/`NSGlassEffectView` (macOS 26+) or materials/gradient-border fallback (15+) — deployment-target decision flagged for `/gsd:discuss-phase`.
**Avoids:** Pitfall 4 (`matchedGeometryEffect` continuity break) — apply as a modifier on the existing shape node; hard-gate on the Phase-25-style 7-point on-device UAT checklist.

### Phase 2: Cosmetic Restyles (Bluetooth, Charging, Equalizer bars, Onboarding animation)
**Rationale:** Zero resolver risk, zero new dependencies, low-stakes proof points for the new visual language rendering correctly inside the new material.
**Delivers:** Pure view-layer redesigns of already-shipped activities; can parallelize with Phase 1 or follow immediately after.
**Addresses:** Bluetooth/Charging HUD restyle (table stakes), Music equalizer bars redesign, Onboarding signature animation (differentiators).

### Phase 3: Drop-Session Summary Chip
**Rationale:** Reuses the already-shipped Phase-18 song-change-toast pattern exactly — good low-stakes proof this orthogonal-state pattern generalizes, and surfaces its one real prerequisite (a "shelf session" boundary concept that doesn't exist today) explicitly rather than discovering it mid-phase.
**Delivers:** A lightweight session start/end tracking addition to `ShelfViewState`/`ShelfCoordinator`, plus the chip itself as a one-shot orthogonal toast.
**Implements:** Non-resolver, `@Published` one-shot field pattern (Integration Point 2, "orthogonal toast" shape).

### Phase 4: Focus Mode HUD (research spike + implementation)
**Rationale:** The FIRST genuinely new `ActiveTransient` case — lower technical risk than Volume/Brightness (read-only detection, no OSD suppression, no scrub-tick handling) — proves the full "new pure Activity type → Monitor → resolver case → wing view" pipeline once, cheaply, before the harder Wave 5 problem.
**Delivers:** `FocusActivity.swift` (pure seam), `FocusModeMonitor.swift` (isolated behind its own protocol), generic on/off HUD only.
**Avoids:** Pitfall 2 (Full Disk Access UX risk) — dedicated spike first to confirm feasibility/UX acceptability; explicit fallback design if rejected.

### Phase 5: Volume/Brightness HUD (dedicated research spike, then implementation)
**Rationale:** Highest technical-risk item in the milestone (private/undocumented APIs, confirmed OS-version-specific regression mode) — isolate as its own spike before committing to full `ActiveTransient` wiring, mirroring this project's own Phase-22/Phase-8→9 precedent.
**Delivers:** `SystemHUDMonitor`/`SystemHUDSuppressing` protocol, `VolumeActivity`/`BrightnessActivity` pure seams, scrub-tick handling via `TransientQueue.updateHead()`.
**Avoids:** Pitfall 1 (wrong tap variant breaks transport keys) — mandatory on-device test of all 4 transport keys + volume/brightness before shipping; Accessibility permission gating.

### Phase 6: Sparkle Auto-Update
**Rationale:** Independent of everything else in this milestone; can interleave anywhere after Phase 1.
**Delivers:** `SPUStandardUpdaterController` in `AppDelegate`, "Check for Updates…" menu item, optional orthogonal `updateAvailable` badge reusing the toast/badge pattern from Phase 3.
**Avoids:** Pitfall 3 (Sparkle/LSUIElement focus conflicts) — verify current Sparkle 2.x CHANGELOG behavior; explicit decision on suppressing Sparkle's default alert UI.

### Phase 7: Calendar Countdown HUD
**Rationale:** Data already exists (EventKit, Phase 28) — this de-risks the timer/data pipeline in isolation as a single-winner ambient feature, before Phase 8's dual-slot mechanism needs it as a proven input.
**Delivers:** `CalendarCountdown.swift` pure seam, a gated one-shot-rescheduling timer (NOT the shared `activityDuration`), ambient single-winner resolver wiring.
**Avoids:** Pitfall 7 (perpetual polling timer / idle-wakeup regression) — schedule to the next actual minute boundary, verify via Activity Monitor's Idle Wake Ups column.

### Phase 8: Dual-Activity Display (main pill + secondary bubble)
**Rationale:** The highest-risk, most architecturally novel change — depends on BOTH Now Playing (shipped) and Calendar Countdown (Phase 7) already being independently stable, so this phase only has to solve "how do two correct signals combine," not "is this new signal even correct."
**Delivers:** Additive `SecondaryActivity` enum + `resolveSecondary()` function (scoped to ambient/idle states only), new `secondary` field on `IslandPresentationState`, `SecondaryBubbleView`.
**Avoids:** Pitfall 5 (two-slot races, geometry-namespace collisions) — single ordered reduce pass, distinct `matchedGeometryEffect` namespaces per slot, combinatorial promotion/demotion test coverage.

### Phase Ordering Rationale

- **Material first, restyles second:** re-skinning is cheap once, expensive eight times — every subsequent HUD phase inherits the finished material for free.
- **Low-risk transient pattern proven before high-risk one:** Focus Mode (Phase 4) establishes the "new `ActiveTransient` case" pipeline end-to-end at low cost before Volume/Brightness (Phase 5) attempts the same pipeline under a genuine private-API/regression risk.
- **Ambient single-winner before dual-slot:** Calendar Countdown (Phase 7) must exist and be independently correct before Dual-Activity (Phase 8) can combine it with Now Playing — building both simultaneously means debugging two new things through one new rendering path at once.
- **Sparkle floats independently:** no architectural coupling to any other phase; scheduled wherever convenient after Phase 1.
- **Avoids the resolver-bypass pitfall structurally:** every phase above explicitly states which existing pattern (resolver transient / orthogonal toast / ambient single-winner) each feature routes through, preventing the "simple HUD skips the arbiter" anti-pattern from Pitfall 6.

### Research Flags

Needs research (`/gsd:plan-phase --research-phase <N>`):
- **Phase 4 (Focus Mode):** No supported API; Full Disk Access UX and Assertions.json reliability must be spiked on-device before scope is locked.
- **Phase 5 (Volume/Brightness):** Private/undocumented `CGEventTap`/`DisplayServices` APIs, confirmed macOS-Tahoe-specific regression risk; needs a dedicated feasibility spike before any UI work.
- **Phase 1 (Liquid Glass):** MEDIUM confidence on whether `.glassEffect()` vs. a materials-composition fallback applies — depends on user-supplied reference code not yet reviewed; flag for `/gsd:discuss-phase` to resolve the deployment-target decision early.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Cosmetic restyles):** Pure view-layer changes to already-shipped activities, zero new mechanism.
- **Phase 3 (Drop-session chip):** Reuses the already-shipped Phase-18 toast pattern verbatim.
- **Phase 6 (Sparkle):** Well-documented official integration path; normal feature-phase research (read current docs), not a spike.
- **Phase 7 (Calendar countdown):** Data source already shipped; timer-hygiene convention already established elsewhere in the codebase (`EqualizerBars`).
- **Phase 8 (Dual-activity):** No private APIs; pure architecture/discipline problem, well-scoped by this research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | HIGH for Sparkle/SwiftUI composition (official docs, GitHub API-verified latest release); MEDIUM for Liquid Glass (Apple docs confirm API existence/availability, but exact visual-parity technique depends on unreviewed reference code); LOW-MEDIUM for HUD suppression and Focus detection (private/undocumented APIs, community-sourced) |
| Features | MEDIUM | HIGH on codebase-integration facts (direct source reads); MEDIUM on private-API HUD techniques (community-verified via a live open-source reference app, not Apple-documented) |
| Architecture | HIGH | All findings grounded in direct reads of the current codebase's actual resolver/controller/view files; MEDIUM only on the two novel technical unknowns (OSD suppression, Focus detection feasibility), which are explicitly flagged as out of scope for architecture and deferred to a spike |
| Pitfalls | MEDIUM-HIGH | Grounded in the actual open-source code of the reference app (Droppy) this milestone is modeled on, plus Sparkle's official docs/issues and this project's own prior WR-01/WR-02 incident history |

**Overall confidence:** MEDIUM — high confidence on architecture/integration and Sparkle; the two private-API items (Volume/Brightness OSD suppression, Focus Mode detection) are the genuine unknowns that could change scope after their spikes.

### Gaps to Address

- **Liquid Glass reference code not yet reviewed by research** — whether the user's supplied reference targets `.glassEffect()` (macOS 26+, requires deployment-target bump) or a materials/gradient composition (15+, no bump) is unresolved; surface explicitly in `/gsd:discuss-phase` for Phase 1.
- **Named/labeled Focus Mode detection has no verified read path on the project's actual target OS (Tahoe)** — scope Phase 4 to generic on/off only; do not plan named-mode UI without a confirming spike.
- **Volume/Brightness OSD suppression's Accessibility-permission UX and transport-key-safety are unverified beyond a reference app's own shipped code** — must be independently confirmed on this project's own dev machine during the Phase 5 spike, not assumed transferable.
- **Dual-activity display's exact promotion/demotion rules are not yet specified as data** — Phase 8 planning must produce an explicit ordered rule table (not scattered conditionals) before implementation, per Pitfall 5's guidance.
- **Update-available HUD's UI shape (badge vs. custom in-notch driver) is an open design decision**, not just a technical one — Phase 6 should default to Sparkle's standard alert + a simple badge, revisiting a custom `SPUUserDriver` only if that proves insufficient on-device.

## Sources

### Primary (HIGH confidence)
- Direct codebase reads (this repository, 2026-07-15): `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/DeviceCoordinator.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/AppDelegate.swift`, `Islet/Calendar/CalendarService.swift`, `.planning/PROJECT.md`
- Apple Developer Documentation — `NSGlassEffectView` (macOS 26.0+ availability), `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, `INFocusStatusCenter`/Communication Notifications, `addGlobalMonitorForEvents` (Accessibility vs. Input Monitoring), Energy Efficiency Guide (timer coalescing)
- GitHub API — confirmed Sparkle 2.9.4 as current release (2026-07-03)
- Sparkle official docs (`sparkle-project.org/documentation/`) — SPM support, `SPUUpdater`/`SPUUserDriver`, LSUIElement handling, EdDSA signing

### Secondary (MEDIUM confidence)
- Droppy (`github.com/1of1Adam/Droppy`, live source read directly) — `MediaKeyInterceptor.swift` (CGEventTap technique, Tahoe transport-key regression), `DNDManager.swift` (Assertions.json polling, Full Disk Access requirement), `AutoUpdater.swift` (built custom updater, informational only)
- DEV Community / Klarity Blog — `.glassEffect()` API shape and pre-26 materials-composition fallback technique
- SlimHUD, dannystewart/volumeHUD, MonitorControl discussions — OSD-suppression precedent and community-known Control-Center-defaults workaround (explicitly flagged as not to use)
- sindresorhus/do-not-disturb — confirms legacy DND CFPreferences key/notification mechanism, does not cover named Focus modes
- SwiftUI Lab — `matchedGeometryEffect` id/namespace collision failure modes
- Apple HIG / Dynamic Island multi-activity coverage (iOS precedent) — validates the "compact pill + detached bubble" framing for dual-activity display

### Tertiary (LOW confidence)
- `alexdelorenzo.dev` reverse-engineering of CoreDisplay/DisplayServices — single source, Apple Silicon brightness-control caveat
- WebSearch synthesis on `NX_SYSDEFINED` event decode — inherently undocumented territory, multiple independent implementations agree but no canonical source

---
*Research completed: 2026-07-15*
*Ready for roadmap: yes*
