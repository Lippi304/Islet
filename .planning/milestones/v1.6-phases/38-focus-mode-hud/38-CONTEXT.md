# Phase 38: Focus Mode HUD - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

A research spike first confirms which detection mechanism is used to know when the user's Focus/Do Not Disturb mode toggles on or off — `INFocusStatusCenter`'s public boolean signal (preferred) vs. polling the undocumented `~/Library/DoNotDisturb/DB/Assertions.json` behind a manual Full Disk Access grant (fallback). Once confirmed, the feature is built as the first genuinely new `ActiveTransient` case in this milestone (alongside today's `.charging`/`.device`), proving the "new pure Activity type → Monitor → resolver case → wing view" pipeline cheaply before Phase 39 attempts the same pipeline under real private-API risk (Volume/Brightness OSD suppression). Generic on/off state only — no named-mode detection ("Work Focus" vs. "Sleep") anywhere; that's explicitly out of scope per REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### Detection & Permission UX
- **D-01:** The Focus Mode feature as a whole (regardless of which detection path the spike lands on) sits behind ONE Settings toggle, off by default — an opt-in feature, not something enabled automatically. Users who don't care about it never see any permission ask.
- **D-02:** Whatever authorization the winning detection path needs is only requested at the moment the user switches the Settings toggle on — not during onboarding, not lazily on first Focus trigger. This applies uniformly to BOTH paths: the lightweight `INFocusStatusCenter.requestAuthorization` TCC-style prompt (if that path wins the spike) and the manual Full Disk Access explanation+deep-link flow (if the `Assertions.json` fallback is needed). One consistent mental model for the user regardless of which technical path won.
- **D-03:** If Full Disk Access is the path needed, the in-app explanation (shown when the toggle is switched on) includes a deep link that opens System Settings → Privacy & Security → Full Disk Access directly, via the `x-apple.systempreferences:` URL scheme — not just text instructions to navigate there manually.
- **D-04:** If the user declines/never grants the needed permission, Islet accepts this silently — no re-ask, no nag, no periodic re-check popup. Mirrors the project's existing Calendar/Weather degrade convention (silent, no retry). The toggle stays on but the feature is inert.
- **D-05:** The Settings toggle shows a persistent status hint reflecting the REAL permission state — e.g. "Permission needed — tap to grant" vs. "Active" — not a bare on/off switch with no feedback. This is what makes D-04's silent-inertness acceptable: the user isn't left guessing why nothing happens.

### HUD Persistence & Interaction
- **D-06:** The Focus HUD is a persistent `ActiveTransient` state (same behavioral shape as Charging/Device today) — it shows "Focus On" for the entire duration Focus is active and dismisses the instant Focus turns off. NOT a brief toast like the song-change toast. This is deliberate: giving the new `ActiveTransient` case real state to arbitrate is the actual point of this phase (pipeline-proving), not a cosmetic detail.
- **D-07:** Unlike Charging/Device (which take over the ENTIRE expanded view — "transient wins even over expanded" in `IslandResolver`), Focus is scoped to **collapsed-pill-only** takeover. Hovering to expand the island while Focus is active works completely normally — Tray/Calendar/Weather/Now-Playing all remain accessible as usual; Focus state simply isn't shown once expanded. Rationale: Focus sessions can run for hours, and blocking the entire expanded island for that whole duration (as a literal Charging/Device-style full takeover would) is a real UX cost Charging/Device don't have (those are brief, self-limiting states). This is a genuinely new behavior class for `IslandResolver` — a transient that wins in the collapsed pill but does NOT participate in the `isExpanded` branch's transient-wins-over-expanded shortcut — not a resolver bypass (still routes through the resolver, per ROADMAP Success Criterion #4, just with a narrower win condition than the existing two transients).
- **D-08:** Priority: Charging/Device outrank Focus. If Focus is active and a Charging/Device event fires, Charging/Device wins the collapsed pill (interrupts Focus's pill); Focus's pill reappears automatically once Charging/Device clears, if Focus is still on. Mirrors the existing precedent of Now-Playing yielding to Charging/Device.
- **D-09:** "Focus Off" has no separate visible HUD moment — the "Focus On" pill simply disappears the instant Focus turns off (same pattern as Charging's wing disappearing on unplug, not a "Not Charging" pill). No toast-style "Focus Off" confirmation flash.

### Visual Design
- **D-10:** Reuses Phase 36's established Droppy-pill wing language: LEFT = Focus icon (macOS's own moon-crescent Focus glyph) + "Focus" text label. RIGHT = a simple on/off status indicator. Visually consistent with the rest of the Phase 36 HUD restyle suite — no new visual language invented for this HUD.
- **D-11:** Icon/label color is FIXED, not accent-tinted — follows Phase 36's precedent for universal system-level states (Charging's bolt/battery) rather than the accent-tinted treatment used for Bluetooth's device glyph. Focus On should read consistently regardless of the user's chosen accent theme.

### Descope Fallback
- **D-12:** If the spike finds NEITHER detection path viable/shippable (INFocusStatusCenter's boolean unreliable AND the Assertions.json/FDA path judged too invasive), HUD-05 is descoped cleanly — same clean-abandonment precedent as Phase 37: no Settings toggle shipped, no half-built UI, REQUIREMENTS.md updated to drop it. The phase's actual goal (proving the new-`ActiveTransient`-pipeline pattern once) is still considered achieved as long as the spike got far enough to build and validate the pipeline against whichever path showed real signal during the spike itself — the final ship/no-ship call on the user-facing feature is separate from the pipeline validation.

### Claude's Discretion
- Exact poll interval for the `Assertions.json` fallback path, if used (PITFALLS.md flags this as a tunable idle-CPU/responsiveness tradeoff — must stay well above the 0.1–0.5s range Droppy uses, per the project's existing timer-hygiene convention established for the Calendar countdown HUD's own pitfall).
- Exact SwiftUI mechanism for the new "collapsed-only, not expanded" resolver behavior (D-07) — e.g. a new field on `ActiveTransient`/a new resolver parameter distinguishing collapsed-scope vs. full-scope transients — planner's call on the cleanest way to express this without duplicating the existing switch-statement structure.
- Naming of the new `FocusActivity`/`FocusModeMonitor` types and the new `ActiveTransient` case.
- Whether the Settings toggle for Focus Mode HUD lives in the existing Theming/Activity-toggles section of Settings or gets its own row — implementation detail, not a product decision.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 38: Focus Mode HUD" — Goal and Success Criteria (spike-first ordering, generic on/off only, silent FDA-denial degrade, resolver routing requirement).
- `.planning/REQUIREMENTS.md` line 55 (HUD-05) — requirement text, explicitly excludes named-mode detection.
- `.planning/REQUIREMENTS.md` line 94 and "Out of Scope" table — confirms no confirmed public read path exists for named Focus modes; only the legacy binary DND flag is reliably readable.

### Pitfalls research — READ BEFORE THE SPIKE
- `.planning/research/PITFALLS.md` Pitfall 2 (lines 51-71) — the authoritative research on Focus/DND detection: why `INFocusStatusCenter` is scoped to communication apps and doesn't expose a per-mode toggle stream (but its generic boolean may still be sufficient for this phase's generic on/off scope — that's exactly what the spike must confirm); the `Assertions.json`/Full Disk Access fallback mechanics; the "no programmatic TCC prompt for Full Disk Access" fact that grounds D-01–D-05 above; poll-interval guidance for the fallback path.
- `.planning/research/PITFALLS.md` Pitfall 6 (lines 142-161) — "every new HUD type enqueues through `IslandResolver`, no exceptions" — directly relevant to D-07's new collapsed-only-transient behavior: it must still be a resolver-arbitrated rule, not a view-layer bypass.
- `.planning/research/PITFALLS.md` "Looks Done But Isn't" checklist (line 235) — "Focus Mode HUD: Often missing the 'Full Disk Access denied' path entirely — verify a fresh, ungranted install doesn't crash, spin, or silently poll forever."
- `.planning/research/PITFALLS.md` Integration Gotchas table (line 202) — Full Disk Access has no programmatic prompt; must design an explicit "please grant this manually" step.

### Resolver architecture this phase extends
- `Islet/Notch/IslandResolver.swift:71-75` — the `ActiveTransient` enum (currently `.charging`/`.device` only) — the new `.focus` case goes here.
- `Islet/Notch/IslandResolver.swift:90-104` — `resolve(...)`'s `switch activeTransient` block and its D-04 comment ("transient wins even over expanded") — D-07 above requires this to become non-uniform across transient kinds (Focus wins collapsed-only); read this whole function before planning the resolver change.
- `Islet/Notch/IslandResolver.swift:104-105` — existing D-02 rank comments (`.charging` rank 1, `.device` rank 2) — D-08 above needs a rank 3 (or equivalent) added for Focus, below both existing transients.

### Phase 36 visual precedent this phase reuses
- `.planning/phases/36-cosmetic-restyles-signature-animation/36-CONTEXT.md` — D-01 through D-04 (Droppy-pill layout: icon+label LEFT, status RIGHT; fixed-vs-accent-tinted color convention) — D-10/D-11 above directly reuse this established language.
- `Islet/Notch/NotchPillView.swift` — `wings(for:)` (~L1919-1938, Charging) and `deviceWings(for:)` (~L2036-2059, Bluetooth) — the exact restyled wing code from Phase 36 to pattern-match for the new Focus wing.

### Existing permission-degrade precedent
- `Islet/Calendar/CalendarService.swift` (around line 106-127) — "silent degrade, no retry/nag" convention already established for Calendar/Weather permission denial — D-04 above extends this exact convention to Focus Mode.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift` — existing Monitor-protocol pattern; the new `FocusModeMonitor` should follow the same shape (isolated behind one protocol, per PITFALLS.md's repeated "isolate behind one protocol" mitigation for anything Apple might restrict further).
- `ActivitySettings.swift` — existing `@AppStorage`-backed activity toggle pattern (used for Charging/Device/Now-Playing toggles today) — the new Focus Mode Settings toggle (D-01) should follow this same shape.

### Established Patterns
- `IslandResolver.swift`'s "one pure arbiter" principle (PITFALLS.md Pitfall 6) — every new HUD type must route through `IslandResolver`/`TransientQueue`, no view-layer `@State` bypass, even for D-07's new collapsed-only behavior.
- Silent-degrade-on-permission-denial convention (`CalendarService.swift`) — D-04 extends this to Focus.
- Phase 36's Droppy-pill wing visual language — D-10/D-11 extend this to Focus.

### Integration Points
- New `.focus(FocusActivity)` case (or similar) added to `ActiveTransient` enum (`IslandResolver.swift:71-75`).
- `resolve(...)`'s transient-handling switch (`IslandResolver.swift:90-104`) needs to distinguish "wins collapsed + expanded" (Charging/Device, unchanged) from "wins collapsed only" (Focus, new) — this is the one genuinely new piece of resolver logic this phase introduces.
- New `FocusModeMonitor` (protocol + concrete implementation chosen by the spike) feeding the resolver, following the existing Monitor pattern.
- New Settings toggle + permission-status subtitle (D-01/D-05), likely in the existing Theming/Activity-toggles section of `SettingsView.swift`.

</code_context>

<specifics>
## Specific Ideas

- No visual reference image was supplied for this HUD — it's a direct application of Phase 36's already-approved Droppy-pill wing language (icon+label left, status right), using macOS's own system moon-crescent Focus glyph as the icon.
- "Focus On"/"Focus Off" text wording is locked verbatim from ROADMAP Success Criterion #2 — not open to rephrasing. In practice only "Focus On" ever renders as visible text (D-09: "Focus Off" is a silent disappearance, not its own displayed state).

</specifics>

<deferred>
## Deferred Ideas

- **Named/labeled Focus Mode detection** ("Work Focus", "Sleep", etc.) — explicitly out of scope per REQUIREMENTS.md's own Out of Scope table; only revisit if a future spike finds a reliable read path beyond the legacy binary DND flag.
- **Re-checking/re-prompting for permission periodically** — considered and explicitly rejected (D-04) in favor of the silent-degrade convention; not something to build even as a future toggle.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned 0 matches for this phase.

</deferred>

---

*Phase: 38-Focus Mode HUD*
*Context gathered: 2026-07-17*
