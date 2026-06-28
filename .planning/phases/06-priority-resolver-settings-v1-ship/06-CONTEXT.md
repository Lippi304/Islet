# Phase 6: Priority Resolver, Settings & v1 Ship - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 closes out v1 with three jobs:

1. **Priority Resolver (COORD-01):** All activity sources coexist under **one** ranked
   policy instead of today's ad-hoc per-pair `if`-ordering, so overlapping events never
   overlap/glitch and transient events yield back to the ambient state.
2. **Settings + accent (APP-03):** A minimal settings window lets the user toggle which
   activities show and pick an accent color, persisting across restarts.
3. **v1 ship:** Re-verify the Now Playing launch-time health check and run the
   sign → notarize → staple release pipeline (production-complete; real Developer-ID run is
   a carry-over — see D-15).

**Scope note — Phase 5 device wiring is finished INSIDE this phase.** Phase 5 paused with
only the pure `DeviceActivity.swift` seam + tests built (Waves 2-3 blocked on a Bluetooth
test device). Because the resolver must coordinate **three** real activity inputs, Phase 6
builds the remaining device pieces (`DeviceActivityState`, the `BluetoothMonitor`, the
device wings view branch). This is **not new scope** — it completes already-scoped v1
requirements DEV-01/DEV-02 that got blocked. Only the **on-device Bluetooth verification**
stays deferred until a test device is available (carry-over, like the Phase-5 spike).

**In scope:** the unified priority/queue resolver; finishing the device activity wiring;
the three activity on/off toggles + accent palette in Settings (with persistence); the
production release run (dry-run) + Now-Playing health re-check.

**Explicitly NOT in this phase:**
- New activity types (timer, file shelf, HUDs) → later milestones.
- Light/dark island or a tinted (non-black) island → rejected (D-11); island stays black to
  preserve the seamless notch illusion.
- Master "pause all" switch, per-activity duration settings, sneak-peek toggle, source-allowlist
  widening → not v1 (D-08; sneak-peek/allowlist remain Phase-4-deferred v2 items).
- On-device Bluetooth UAT and the real Developer-ID notarize/staple + clean-second-Mac open →
  carry-overs (D-01 device verification, D-15 release), done when the hardware/account exist.
</domain>

<decisions>
## Implementation Decisions

### Priority resolver — ranking & coexistence (COORD-01)
- **D-01:** **Finish the device activity wiring in Phase 6.** Build `DeviceActivityState`
  (@Published model), the thin `BluetoothMonitor` (IOBluetooth connect/disconnect, main-hop,
  deinit teardown), and the device wings view branch — completing Phase-5 Waves 2-3 so the
  resolver has **three real inputs**. Reuse the Phase-5 decisions verbatim (05-CONTEXT D-01…D-07:
  all-devices, glyph-by-name, dimmed disconnect, burst-suppression/debounce, ~3s dismiss).
  **Defer only** the on-device Bluetooth verification (no test device) — code-complete now,
  UAT when hardware is available. Wire it behind the same single `updateVisibility()` gate.
- **D-02:** **One ranked resolver replaces the ad-hoc per-pair ordering.** Priority rank:
  **Charging > Device > Now Playing.** Now Playing is the **ambient baseline**; charging and
  device are **transient ~3s splashes** that briefly win, then the island returns to the
  highest-priority ambient state (now-playing wings if playing, else idle pill). This
  generalizes Phase-3 D-11 / Phase-4 D-14 / Phase-5 D-05 into a single policy.
- **D-03:** **Collision = short sequential queue.** If a second transient splash arrives while
  one is showing, **enqueue it** — show splash A for its ~3s, then splash B for its ~3s. Not
  drop-the-loser, not interrupt-with-latest. Keep the queue **bounded and de-duped** (don't
  stack many copies of the same activity; a sensible small depth) so it can't back up — exact
  depth/dedup rule is Claude's discretion, but it must stay simple (no over-engineering).
- **D-04:** **Transient wins briefly over a user-expanded island** (generalize Phase-3 D-11):
  if the user has the island click-expanded and a charging/device event fires, the splash shows
  its brief feedback, then returns to the open/ambient state. User interaction is **not** a
  protected higher rank.
- **D-05:** Resolver is the **single arbiter of which presentation renders** — the goal is to
  replace the scattered precedence `if`-chain in `NotchPillView` + the per-handler logic in
  `NotchWindowController` with one clear, ideally **pure/testable** ranking+queue seam (mirrors
  the Phase 1-5 pure-seam discipline). Exact shape (enum-of-active-activity vs a resolver
  function over the three @Published states) is Claude's discretion — keep it the ONE place
  priority lives, routed through the single `updateVisibility()`.

### Settings — activity toggles (APP-03)
- **D-06:** **Three independent on/off toggles:** Charging, Now Playing, Device — one switch
  each, maximum user control.
- **D-07:** **All default ON.** Fresh install shows everything; the user disables what they
  don't want.
- **D-08:** **Pure on/off only for v1.** No master "pause all" switch, no per-activity duration
  setting. Toggles live in the existing `SettingsView` Form (alongside Launch-at-Login + Version).
- **D-09:** **Persist across restarts** (success criterion 2). Mechanism = `@AppStorage` /
  `UserDefaults` (Claude's discretion). Toggling **applies live** — turning an activity off
  immediately suppresses its splash without a restart. Whether "off" also stops the underlying
  monitor (vs just suppressing display) is Claude's discretion; prefer not registering the
  source when off to keep idle CPU ~0%.

### Settings — accent / theme (APP-03)
- **D-10:** **Accent color only — no theme system.** The island **stays black** (no light/dark
  mode, no tinted island variant) to preserve the seamless notch blend.
- **D-11:** **The accent tints the lively active elements:** the charging bolt/battery glyph,
  the Now-Playing equalizer bars, and the device icon — the small colored accents. It does
  **not** restyle the expanded-view chrome (transport buttons / title) in v1.
- **D-12:** **Curated palette (~5-6 colors), default = neutral / system color.** Apple-style
  preset swatches, not a free ColorPicker. Persisted like the toggles (D-09). Exact palette
  (which 5-6 colors) and the default swatch are Claude's discretion + on-device taste.

### v1 ship (release + health re-check)
- **D-13:** **Product name stays `Islet`** for v1 (current bundle name). A different/public
  name is deferred (PROJECT.md "name TBD closer to release" — still deferred past this private v1).
- **D-14:** **Version `0.1` / `0.x`** — this is a private first release; `1.0` is reserved for
  the later public/sellable launch.
- **D-15:** **No Apple Developer account yet → release runs as a DRY-RUN.** Phase 6 builds the
  release process to production-complete (the Phase-0 `scripts/release.sh` runs unchanged: its
  Developer-ID/notary steps stay placeholder-gated, the ad-hoc fallback exits 0 with the loud
  SKIP banner — D-01/D-02/D-03 from Phase 0). The **real** Developer-ID sign → notarize → staple
  + clean-**second-Mac** open (success criterion 3) is a **carry-over**, done once the $99/yr
  account exists. Keep the DMG via **`hdiutil` (UDZO)** — no `create-dmg` / Homebrew dependency.
- **D-16:** **Re-verify the Now Playing launch-time health check** as part of the ship gate
  (success criterion 3) — confirm the `NowPlayingMonitor` health check + "nicht verfügbar"
  fallback still pass on the current installed macOS (treat each macOS update as a regression
  event per the Phase-4 blocker).

### Claude's Discretion
- The resolver's exact shape (pure ranking/queue function over the three @Published states vs an
  active-activity enum) and the queue depth/dedup rule — keep it the ONE priority site, simple,
  testable, routed through `updateVisibility()`.
- The persistence keys/structure (`@AppStorage` vs a small settings model) and whether a disabled
  activity stops its monitor or just suppresses display (prefer stop, for idle CPU).
- The exact 5-6 accent swatches + the default, and how the accent color threads into the existing
  views (charging glyph / equalizer bars / device icon).
- Device-activity specifics inherited from 05-CONTEXT (name→SF-Symbol map, burst/debounce
  mechanism, disconnect dimming) — already Claude's discretion there.
- Spring/duration tuning (start from the Phase-2 seeds: response ≈ 0.35, damping ≈ 0.65).
- The pure-logic TDD seam for the resolver (rank + queue) and the device edge predicate (already
  built) — unit-tested in ms; IOBluetooth + AppKit/SwiftUI wiring verified on-device (BT UAT deferred).

### Folded Todos
(None — no pending todos matched this phase.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Priority resolver — the code it unifies + the per-pair decisions it generalizes
- `Islet/Notch/NotchPillView.swift` — the current **precedence `if`-chain** (`charging > expanded >
  media-wings > collapsed`, D-14 comment ~line 104-120) that the resolver replaces/centralizes;
  add the **device wings branch** here. Shared `wings(for:)` + `wingsSize` (305×32) skeleton.
- `Islet/Notch/NotchWindowController.swift` — `handlePower` / `handleNowPlaying` + the **single
  `updateVisibility()`** show/hide site + the `graceWorkItem` one-shot `DispatchWorkItem` dismiss
  (the ~3s template + the queue's timing source). Add `handleDevice` + the resolver/queue here.
- `.planning/phases/03-charging-activity/03-CONTEXT.md` — **D-11** (charging briefly wins, then
  returns) — generalized by D-02/D-04.
- `.planning/phases/04-now-playing/04-CONTEXT.md` — **D-14** (charging-vs-media brief precedence,
  return to wings not empty); the ambient now-playing baseline the resolver ranks lowest.
- `.planning/phases/05-device-connected-activity/05-CONTEXT.md` — **D-01…D-07** (the device
  activity spec to FINISH in Phase 6) + **D-05** (device-vs-now-playing brief precedence).

### Device activity wiring to complete (Phase-5 Waves 2-3)
- `Islet/Notch/DeviceActivity.swift` — the pure seam + tests already built (Phase-5 Tasks 1-2);
  add the `@Published` `DeviceActivityState` + thin `BluetoothMonitor` mirroring the templates below.
- `Islet/Notch/PowerActivity.swift` / `ChargingActivityState.swift` / `PowerSourceMonitor.swift` —
  the canonical pure-seam + @Published model + thin event-monitor (main-hop, deinit teardown)
  **triple to clone** for the device monitor.
- `Islet/Notch/NowPlayingPresentation.swift` / `NowPlayingState.swift` / `NowPlayingMonitor.swift`
  — the second instance of the same pattern; confirms the convention.
- `CLAUDE.md` → **"Bluetooth / AirPods connect events"** — IOBluetooth
  `register(forConnectNotifications:selector:)` + per-device `register(forDisconnectNotification:)`;
  IOBluetooth (legacy but correct), NOT Core Bluetooth; un-sandboxed → entitlement low-friction.
- `Islet/Notch/BluetoothSpike.swift` + the `#if DEBUG_BT_SPIKE` block in `Islet/AppDelegate.swift`
  — the throwaway spike to **remove** once the real monitor lands (and the `NSBluetoothAlwaysUsageDescription`
  key in `project.yml` is added ONLY if the deferred A1 verdict says it's required).

### Settings + accent (APP-03)
- `Islet/SettingsView.swift` — the existing `Form` (Launch-at-Login + Version); add the three
  activity toggles + the accent palette here. `@AppStorage`/`UserDefaults` persistence.
- `Islet/LaunchAtLogin.swift` — the existing settings-persistence/system-state pattern to mirror.
- `Islet/Notch/NotchPillView.swift` (+ charging glyph / equalizer bars / device icon subviews) —
  where the accent color threads in (D-11).

### v1 ship (release + health)
- `scripts/release.sh` + `docs/RELEASE.md` — the Phase-0 pipeline (sign→dmg→notarize→staple,
  placeholder-gated Developer-ID/notary, hdiutil UDZO DMG, ad-hoc SKIP fallback). Runs unchanged
  for the D-15 dry-run.
- `Islet/Notch/NowPlayingMonitor.swift` — the launch-time health check + "nicht verfügbar"
  fallback to re-verify (D-16).
- `project.yml` (XcodeGen) — version/build (D-14), bundle name `Islet` (D-13); run
  `xcodegen generate` after adding sources. SPM `MediaRemoteAdapter.framework` = Embed & Sign.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 6: Priority Resolver, Settings & v1 Ship"** (goal + 3 success criteria).
- `.planning/REQUIREMENTS.md` — **COORD-01** (resolver), **APP-03** (settings + accent); plus the
  carried DEV-01/DEV-02 (device wiring finished here), APP-04 (notarized distribution — dry-run carry-over).
- `.planning/PROJECT.md` — vision (as polished as Alcove), Key Decisions, out-of-scope; "name TBD" (D-13).
- `.planning/STATE.md` — the Phase-5 BT-spike resume instructions (the device UAT to run when a device exists).

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Two complete activity "quartets" exist** (Power: seam+state+monitor+view-branch; NowPlaying:
  same) — the device monitor + the resolver mirror these. The pure `DeviceActivity` seam is already
  built; Phase 6 adds its `@Published` state + IOBluetooth monitor + view wing.
- **`NotchWindowController`** already coordinates charging + media via `handlePower` /
  `handleNowPlaying` through the **single `updateVisibility()`** + the `graceWorkItem` one-shot
  dismiss. The resolver + `handleDevice` + the splash queue plug in here.
- **`NotchPillView`** holds the precedence `if`-chain (D-14) + shared `wings(for:)` skeleton
  (`wingsSize` 305×32) — extend with the device wing and centralize priority via the resolver.
- **`SettingsView`** is a small SwiftUI `Form` with a working live-system-state pattern
  (Launch-at-Login) — the activity toggles + accent palette slot straight in.

### Established Patterns
- Small AppKit surface + SwiftUI via `NSHostingView`; `@Published`/`ObservableObject` into SwiftUI;
  **Swift-5 language mode**; un-sandboxed; **macOS-14 floor**.
- **TDD seam**: pure logic (the resolver rank+queue; the device edge predicate) unit-tested; the
  IOBluetooth + AppKit/SwiftUI + release wiring verified on-device.
- **One-shot `DispatchWorkItem`** for timed collapse — never a repeating timer (no-polling / idle
  CPU ~0%); the splash queue reuses this timing, not a clock.
- **Single `updateVisibility()`** is the sole show/hide site — the resolver routes through it so
  fullscreen + clamshell hide stay free.
- `project.yml` (XcodeGen) auto-discovers new `.swift` under `Islet/` — `xcodegen generate` after adding.

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` → `NotchWindowController.start()` already creates the
  power + now-playing monitors; the IOBluetooth registration + the device state wire in there.
- All three activity callbacks **hop to main** before touching `@Published`/AppKit; **deinit tears
  down** every registration (IOBluetooth notifications, the adapter child, the IOPS source).
- The resolver reads the three @Published states + the settings toggles (a disabled activity is
  excluded from ranking) and feeds the one rendered presentation through `updateVisibility()`.
- Accent color flows from settings persistence into the charging glyph / equalizer bars / device icon.

</code_context>

<specifics>
## Specific Ideas

- **One priority site, no scattered ifs:** the user wants the three activities to "coexist
  without overlapping or glitching" — the intent is a single, clear ranked policy
  (Charging > Device > Now Playing) with a short queue for simultaneous transients, not more
  ad-hoc per-pair special-casing.
- **Accent = the small living color:** the island is and stays black; the accent is the pop of
  color on the bolt, the equalizer bars, the device glyph — the Apple-style "alive" detail.
  Curated swatches, not a rainbow picker.
- **Private v1, not the public launch:** ship as `Islet` 0.x via the existing dry-run pipeline;
  the real notarized/sold build comes once the Developer account is in place.

</specifics>

<deferred>
## Deferred Ideas

- **On-device Bluetooth UAT** (DEV-01/DEV-02 verification + the A1 permission-key verdict) → run
  when a Bluetooth test device is available; the device code ships code-complete in Phase 6 (D-01).
- **Real Developer-ID notarize/staple + clean-second-Mac open** (success criterion 3 / APP-04) →
  carry-over once the $99/yr Apple Developer account exists (D-15).
- **Public product name + 1.0 version** → deferred to the later sellable launch (D-13/D-14).
- **Master "pause all" switch, per-activity duration settings, free ColorPicker, light/dark or
  tinted island, accent on expanded-view chrome** → considered and cut for v1 (D-08/D-10/D-11/D-12).
- **Sneak-peek toggle + source-allowlist widening** (Phase-4 v2 items) → still v2, not folded here.
- **create-dmg prettier installer** → optional polish, not v1 (D-15 keeps hdiutil).

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)

</deferred>

---

*Phase: 06-priority-resolver-settings-v1-ship*
*Context gathered: 2026-06-28*
