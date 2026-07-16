# Phase 36: Cosmetic Restyles & Signature Animation - Context

**Gathered:** 2026-07-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Three independent, pure view-layer restyles, all rendering inside Phase 35's Liquid Glass material — zero resolver/monitor/data changes:
1. Bluetooth/AirPods and Charging collapsed-wing HUDs get the Droppy-pill visual language (HUD-01, HUD-02).
2. The Now Playing equalizer bars get a new visual/animation design (EQ-01).
3. The onboarding flow's first page heading is replaced by a handwritten-signature-style reveal animation (ONBOARD-04).

</domain>

<decisions>
## Implementation Decisions

### Bluetooth/Charging HUD Layout (HUD-01, HUD-02)
- **D-01:** The camera-notch split is a hard physical constraint, not a style choice — Islet's collapsed wings MUST keep flanking the camera bump (left wing / gap / right wing). Droppy's reference shows one continuous capsule only because Droppy isn't physically anchored to a notch. This restyle is a chrome reskin of the existing split-wing structure (`wings(for:)` for Charging, `deviceWings(for:)` for Bluetooth in `NotchPillView.swift`), not a structural rebuild.
- **D-02:** Add short text labels next to the icon (today's wings are icon-only). Confirmed via user-supplied real Droppy screenshots (saved as `reference-droppy-airpods-pill.png` and `reference-droppy-volume-charging-pills.png` in this phase dir) that the label sits on the **LEFT** with the icon, and the **RIGHT** wing carries only the value/status indicator — this superseded an earlier (wrong) assumption that the label would go on the right.
  - Bluetooth: LEFT = device glyph + "Connected" text (when connected). RIGHT = green ring/status indicator when no battery% is known; the existing battery% display (`deviceTrailing`, `BatteryIndicator`) stays as-is when a device does report one — Droppy's screenshot doesn't show a battery-reporting device, so it doesn't contradict keeping that existing Islet feature.
  - Charging: LEFT = bolt icon + "Charging" text (only while actively charging). RIGHT = the existing `BatteryIndicator` + percentage — already green while charging, already matches the Droppy reference, no change needed there.
- **D-03:** The right-side positive-state indicator (green ring / green battery) is a **fixed green**, not accent-tinted — matches Droppy exactly and reads as a universal "active/good" color independent of the user's accent theme. This does not change the LEFT icon's existing color behavior (bolt: green-while-charging/dimmed-white-otherwise per today's code; device glyph: accent-tinted).
- **D-04:** Negative states (disconnected / not charging / full) dim to icon-only, no text label — same as today's D-03 dimming precedent (50% opacity). Droppy's screenshots only show positive states, so this negative-state behavior is inferred/confirmed by the user as "keep it minimal," not copied from a reference.

### Equalizer Bars Visual Design (EQ-01)
- **D-05:** Reference is Skiper UI's "Music toggle btn" (skiper25), a shadcn/framer-motion component (`https://skiper-ui.com/v1/skiper25`). Full source captured in `reference-skiper25-equalizer.md` (fetched directly from the shadcn registry JSON, since the site's own "view source" button is JS-interactive and unreachable via plain fetch).
- **D-06 (scope guard):** Skiper25 is architecturally a play/pause TOGGLE BUTTON that morphs into bars on click — but EQ-01 is scoped as pure view-layer with zero data/monitor/interaction changes (ROADMAP.md). Only the bar rendering/animation VISUAL is in scope; making the bars tappable to control playback is explicitly deferred (see Deferred Ideas).
- **D-07 (locked target values, extracted from the actual `skiper25.tsx` source):**
  - 5 bars (unchanged from today's `EqualizerBars.barCount`)
  - Each bar ~1pt wide (was 2.5pt), fully rounded ends (`Capsule()`, unchanged shape primitive)
  - ~4pt gap between bars (was 2pt)
  - Height range ~4–14pt (close to today's 3–16pt range but should be retuned to match)
  - Color: solid white / `.foregroundStyle` — explicitly NO gradient or accent tint (this differs from the current `tint` parameter which picks up `nowPlayingAccent` — the new bars are always white regardless of accent)
  - **Animation feel (the core visual change):** every ~100ms, reroll ALL bars to new random target heights simultaneously and spring-animate each to its target (source values: stiffness 300, damping 10) — a snappier, more percussive "jump to target" motion, replacing today's smooth continuous per-bar sine wave with independent period/phase.
  - Paused state: bars snap to a flat low height (unchanged contract — bars are flat and clock-free when not playing).
- **D-08 (non-negotiable carry-over constraint):** The existing idle-CPU guarantee (D-04 from Phase 4/18 — `TimelineView(.animation(paused: !isPlaying))`, zero clock while paused) MUST be preserved. The web reference's `setInterval`-based reroll is a technique to reimplement idiomatically in SwiftUI (e.g. a periodic reroll of `@State` target heights driving `.animation(.spring(...), value:)`), not to port literally — planner's call on exact mechanism, per `reference-skiper25-equalizer.md`.

### Onboarding Signature Animation (ONBOARD-04)
- **D-09:** Text to animate: **"Meet Islet"** (today's full heading), not just the shorter "Islet" — user's explicit final choice.
- **D-10:** Reference is componentry.fun's "Signature" component (`npx shadcn@latest add @componentry/signature`) — a per-character SVG glyph-path stroke reveal (`pathLength` 0→1, framer-motion), staggered per character, ~1.5s duration, ease-in-out, mask-filled once each stroke completes. Full source captured in `reference-signature-component.md`.
- **D-11:** Color is the app's existing **orange accent** — not the rainbow-gradient alternative the user first mentioned. Consistent with the rest of the design system rather than introducing a new palette for one screen.
- **D-12 (FLAGGED RISK — must be resolved before shipping, not Claude's Discretion):** The reference technique depends on a script font, `LastoriaBoldRegular.otf`, hosted at `https://www.componentry.fun/LastoriaBoldRegular.otf` (confirmed live/valid during this discussion). The font's own embedded metadata reads `© Abo Daniel 2019. All Rights Reserved.` — componentry.fun requiring the download does not itself grant a commercial license, and the user's own response when asked directly was uncertain, not a confirmed license. Islet is a paid product (€7.99). **Researcher/planner must verify the font's actual commercial-use terms before it ships**, and have a libre (e.g. OFL-licensed) script/handwriting font ready as a substitute if commercial use can't be confirmed. See `reference-signature-component.md` for full detail.
- **D-13:** The body subtext below the heading ("Your notch, upgraded. Now Playing, charging, and a drag-and-drop shelf — always one glance away.") is completely unchanged — same text, font, timing. Only the heading itself is replaced by the signature animation. This is a deliberate, narrow scope match to ONBOARD-04's own wording ("scoped to that one page only, the rest of the app's typography is unaffected").

### Post-36-04 pivot: static rainbow-gradient heading replaces the reveal animation

- **D-14 (supersedes D-09/D-10/D-11 execution, not the underlying text choice):** After several
  in-session rounds of Plan 36-04 implementation friction — D-12's font-licensing swap
  (Lastoria → Dancing Script Bold), then multiple stroke-weight recalibrations (0.22 mask ratio →
  6.16pt → 1.75pt) still not reading right, plus general Canvas/TimelineView/`.trim()` complexity
  for a single onboarding screen — the user made an explicit, direct scope-pivot decision: **drop
  the stroke-reveal animation entirely.** Quote (German): "Lass uns keine Unterschrift Animation
  machen sondern einfach wie bei Droppy eben so eine Unterschrift Textart einfach in Regenbogen
  Farbverlauf" ("Let's not do a signature animation, just a signature-style font like Droppy's,
  simply with a rainbow gradient").
- New reference precedent: Droppy's own onboarding heading ("meet droppy") — a completely static,
  non-animated two-word script-font heading, each word filled with its own distinct multi-color
  gradient sweep ("meet" blue→purple→pink, "droppy" orange→yellow→green).
- **What stays locked:** D-09's text ("Meet Islet"), D-12's font substitute (Dancing Script Bold,
  OFL-licensed, still the only safe choice), D-13 (body subtext untouched).
- **What's superseded:** D-10's stroke-reveal mechanism (Core Text glyph-path extraction +
  `.trim(from:to:)` animation + `TimelineView` clock) and D-11's single fixed-orange color are
  replaced by two `Text` views (one per word) with a `LinearGradient` `.foregroundStyle` each —
  "Meet" as blue→purple→pink, "Islet" as orange→yellow→green. Fully static, no animation, no
  per-frame clock, no idle-CPU concern (T-36-07 no longer applies — there is no clock to leak).
  The glyph-path extraction infra from Plan 36-03 (`glyphPaths`/`totalWidth`) is no longer used
  and was removed along with it in this pivot; `loadSignatureFont`/font registration is reused
  as-is since the font itself is unchanged.

### Claude's Discretion
- Exact SwiftUI mechanism for the equalizer bars' periodic-reroll-plus-spring animation (D-08) — any idiomatic approach that preserves the idle-CPU gate is acceptable.
- Exact SwiftUI mechanism for extracting per-glyph vector paths for the signature animation (Core Text `CTFontCreatePathForGlyph` is the natural analog to `opentype.js`, but the planner should confirm this during research) and for animating `.trim(from:to:)` per glyph with the staggered-delay/ease-in-out contract from D-10.
- Whether the Skiper UI attribution requirement (free-tier license, see `reference-skiper25-equalizer.md`) needs a visible credit somewhere in the app (e.g. About screen) — flag during planning if not already covered elsewhere.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### HUD-01/HUD-02 (Bluetooth/Charging restyle)
- `.planning/phases/36-cosmetic-restyles-signature-animation/reference-droppy-airpods-pill.png` — user-supplied Droppy screenshot showing the AirPods "Connected" pill (icon+label left, green ring right) and Volume/Brightness HUD grid context.
- `.planning/phases/36-cosmetic-restyles-signature-animation/reference-droppy-volume-charging-pills.png` — user-supplied Droppy screenshot showing the exact Charging pill ("Charging" label left, green battery+64% right) alongside Volume/Brightness pills.
- `.planning/research/inspiration/notes.md` — broader Droppy reference context (note: the numbered image references in this file do NOT reliably match the actual `inspiration/*.png` filenames — verify visually rather than trusting the numbering).
- `Islet/Notch/NotchPillView.swift` — `wings(for:)` (~L1919-1938, Charging), `deviceWings(for:)` (~L2036-2059, Bluetooth), `deviceTrailing` (~L2065-2074) — the exact code to restyle.

### EQ-01 (Equalizer bars)
- `.planning/phases/36-cosmetic-restyles-signature-animation/reference-skiper25-equalizer.md` — full Skiper25 source + extracted target values + license note. **Read this before writing any bar animation code.**
- `Islet/Notch/NotchPillView.swift` — `EqualizerBars` struct (~L2330-2391) — the exact code to redesign; also see `ProgressBar` (~L2400+) which shares the `TimelineView(.animation(paused:))` idle-CPU pattern that must be preserved.

### ONBOARD-04 (Signature animation)
- `.planning/phases/36-cosmetic-restyles-signature-animation/reference-signature-component.md` — full Signature component source + font license risk + SwiftUI porting notes. **Read this before writing any animation code, and resolve the font-license flag (D-12) before shipping.**
- `Islet/Notch/NotchPillView.swift` — `onboardingWelcomeStep` (~L1480-1491) — the exact code to modify. `.planning/phases/26-onboarding-flow/26-UI-SPEC.md` §Typography (San Francisco `.rounded` system font throughout) — the signature animation is a deliberate, scoped exception to this; the body subtext below it is NOT exempt (D-13).

### Roadmap & requirements
- `.planning/ROADMAP.md` §"Phase 36: Cosmetic Restyles & Signature Animation" (lines 639-650) — Success Criteria.
- `.planning/REQUIREMENTS.md` — HUD-01, HUD-02, EQ-01, ONBOARD-04 definitions.
- `.planning/PROJECT.md` §"Current Milestone: v1.6" — confirms the equalizer bars and Liquid Glass material were the two items awaiting user-supplied references; equalizer reference is now supplied (D-05).

### Prior-phase precedent this phase renders inside/depends on
- `.planning/phases/35-liquid-glass-material/35-CONTEXT.md` — the Liquid Glass material (D-20/D-20a native `.glassEffect()` rim pivot) all three restyles must render correctly inside; no changes to that material are in scope here.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BatteryIndicator` (used by both `wings(for:)` and `deviceTrailing`) — already renders a green battery+percentage matching the Droppy Charging reference; no change needed for the Charging right-wing.
- `wingsShape` helper — shared flat-strip shape wrapper already used by charging/device/media wings; the restyle should extend this, not replace it.
- `EqualizerBars.makeProfiles()` — internal (not private) precisely so `EqualizerBarsTests.swift` can call it directly under `@testable import`; the new bar-height-generation logic should follow the same testability precedent.

### Established Patterns
- Idle-CPU gating via `TimelineView(.animation(paused: !isPlaying))` is a load-bearing, twice-precedented pattern (`EqualizerBars`, `ProgressBar`) — any new animation timing must plug into this same discipline, not add an unconditional clock.
- Fixed (non-accent) colors are already used elsewhere for meaning-carrying state (e.g. charging bolt = green while charging) — D-03/D-04's "green independent of accent" decision is consistent with this existing convention, not a new one.
- Round-numbered inline comments throughout `NotchPillView.swift` (e.g. "Round 2 (Droppy comparison)...") document a history of prior Droppy-driven restyle rounds — follow this same comment convention when implementing.

### Integration Points
- All three restyles are pure view-body changes inside `NotchPillView.swift` — no `DeviceCoordinator`, `BluetoothMonitor`, IOKit power monitor, `NowPlayingState`, or `OnboardingFlow` (reducer) changes are needed or in scope.

</code_context>

<specifics>
## Specific Ideas

- HUD-01/02: exact Droppy screenshots supplied and saved to this phase dir (see canonical_refs) — match colors/label wording/layout from those images, not from `inspiration/notes.md`'s (unreliable) numbering.
- EQ-01: exact Skiper25 source captured (see `reference-skiper25-equalizer.md`) — bar count, width, gap, height range, and the springy 100ms-reroll animation feel are all locked to specific extracted values, not vague direction.
- ONBOARD-04: exact Signature component source captured (see `reference-signature-component.md`) — text "Meet Islet", orange accent color, per-character stroke-reveal technique are all locked.

</specifics>

<deferred>
## Deferred Ideas

- **Equalizer bars become tappable to toggle play/pause** — inspired by Skiper25 being a toggle button, not just a passive visualizer. New interaction, out of EQ-01's pure-view-layer scope for Phase 36. Revisit as its own idea/phase if wanted.
- **Broader "hover-to-widen island with transient HUD-style content" concept** raised in the same exchange (collapsed island only widens on hover; volume/brightness-style transient content fades in/out; Now Playing stays the primary/default content with bars on the right of the hover-widened state) — this overlaps Phase 39 (Volume & Brightness HUD) and general resolver/hover-behavior scope, not Phase 36's restyle-only mandate. Flag for the user when Phase 38/39 come up.
- **Skiper UI attribution** — if the free-tier license requirement (see `reference-skiper25-equalizer.md`) needs a visible in-app credit, that's a small addition to scope during planning, not decided here.

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope during discussion.

</deferred>

---

*Phase: 36-Cosmetic Restyles & Signature Animation*
*Context gathered: 2026-07-16*
