# Phase 39: Volume & Brightness HUD - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

An on-device research spike first confirms whether `.cgSessionEventTap` (never the annotated variant) can intercept volume/brightness `NX_SYSDEFINED` events and suppress the native macOS OSD without breaking any of the 4 media transport keys — the milestone's single highest-risk item, isolated as its own spike-then-implement phase per this project's own Phase 22/Phase 8→9 precedent. Once confirmed (or the fallback is chosen), Volume and Brightness HUDs are built as two new `ActiveTransient` cases sharing one OSD-replacement subsystem, reusing the "new pure Activity type → Monitor → resolver case → wing view" pipeline Phase 38 proved for Focus Mode. If suppression proves unreliable on-device, the HUD still ships — shown alongside the native OSD rather than replacing it — per the ROADMAP's own explicit fallback language. The undocumented `EnableSystemBanners` Control-Center-wide defaults toggle is never used.

</domain>

<decisions>
## Implementation Decisions

### Level-Indicator Visual Style
- **D-01:** Both HUDs use the Droppy-style filled-bar layout from the user's own reference screenshot (`reference-droppy-volume-charging-pills.png`, saved during Phase 36): icon on the LEFT wing, a horizontal filled progress bar on the RIGHT wing. No numeric percentage text anywhere. This is a deliberate divergence from Phase 36's icon+label convention (Charging/Device/Focus) — a continuous level reads better as a bar than as text, and the user has an exact visual reference for it.
- **D-02:** Bar color is FIXED, not accent-tinted, matching the reference exactly: Volume bar = green, Brightness bar = orange/yellow. The icon is also fixed white/system color (never accent-tinted) — consistent with Phase 36's D-03/D-11 precedent that universal system-level states don't pick up the user's accent theme.
- **D-03:** Volume HUD swaps `speaker.wave.fill`-class icon to `speaker.slash.fill` when muted (0% or hardware mute), with the bar fully drained — matches the native macOS OSD's own muted-state treatment, avoids "muted" and "quiet" looking identical.
- **D-04:** The bar fill animates with a spring (not an instant snap) when the level changes — consistent with the project's established "liquid island" spring-animation feel used everywhere else (Charging %, Focus wing morphs).

### Accessibility Permission UX
- **D-05:** OSD suppression sits behind ONE Settings toggle, OFF by default — mirrors Focus Mode's D-01 exactly. Accessibility (system-wide event-tap capability) is a significantly scarier-sounding permission than Focus's `INFocusStatusCenter` ask, so it stays opt-in.
- **D-06:** Showing the HUD itself does NOT require Accessibility — only actively SUPPRESSING the native OSD does. If the toggle is on but Accessibility is denied/never granted, the HUD still shows, alongside the native system OSD (not a dead/inert feature) — this is the same behavior as the ROADMAP's "suppression proves unreliable" fallback, just triggered by permission-denial instead of a suppression bug.
- **D-07:** If Accessibility is granted later (in System Settings) while Islet is already running with the toggle on, suppression must start automatically — no relaunch, no toggling the Settings switch off/on again. Reuse `DropInterceptTap`'s existing 5s health-check-timer pattern (already built for exactly this class of problem: detect a non-working tap, attempt to (re)install it).
- **D-08:** The Settings toggle includes an explanation + a deep-link to System Settings → Privacy & Security → Accessibility via the `x-apple.systempreferences:` URL scheme when switched on — same pattern as Focus Mode's Full-Disk-Access deep-link (D-03 in `38-CONTEXT.md`). One consistent permission-request mental model across the app.

### Scrubbing & Auto-Dismiss Timing
- **D-09:** Unlike `TransientQueue.updateHead()`'s existing behavior for Charging's % ticks (value updates in place WITHOUT re-arming the dismiss timer), Volume/Brightness's dismiss timer MUST reset on every key press — matches the native OSD's "stays up while you keep pressing" feel. This requires a new `updateHead` variant or an additional parameter distinguishing "refresh only" (Charging) from "refresh + re-arm" (Volume/Brightness) — planner's call on the cleanest way to express this without breaking Charging's existing contract.
- **D-10:** Volume/Brightness use their own shorter auto-dismiss duration — **1.5 seconds** — rather than the shared 3s `activityDuration` constant used by Charging/Device/Focus. This is a second, deliberately different magic number; do not consolidate it into the shared constant.
- **D-11:** Volume/Brightness are scoped **collapsed-pill-only**, same as Focus (Phase 38 D-07) — NOT a full expanded-island takeover like Charging/Device. Hovering to expand the island while adjusting volume/brightness works completely normally; the level indicator simply isn't shown once expanded.

### Volume↔Brightness↔Focus Priority
- **D-12:** Volume and Brightness instantly replace each other (cross-category, not same-category) — pressing Brightness while Volume's HUD is still showing immediately swaps to Brightness, it does NOT queue behind Volume the way Charging/Device dedup today. Mirrors the native macOS OSD, which only ever shows the most recent key's HUD. Both categories should be modeled so this "instant mutual replace" falls out naturally (e.g., as sub-cases of one shared `ActiveTransient` case) rather than as two independent cases requiring bespoke cross-category logic — see Claude's Discretion below.
- **D-13:** Rank order: Charging (1) → Device (2) → Focus (3) → Volume/Brightness (4, new, shared rank). Volume/Brightness are below Focus, but since Focus is `isPersistent` (never self-elapses) and `TransientQueue.advance()` only promotes a queued item when the current head elapses, a plain `enqueue()` behind Focus would mean Volume/Brightness NEVER show while Focus is active (queued forever). To avoid that, Volume/Brightness must use Phase 38's existing `TransientQueue.preempt()` mechanism against a standing Focus head too (not just Charging/Device) — they briefly interrupt Focus's pill for their ~1.5s duration, then Focus's pill automatically restores, exactly like Charging/Device already do (Phase 38 D-08).

### Claude's Discretion
- Whether Volume and Brightness are modeled as one shared `ActiveTransient` case with an inner enum (e.g., `.osd(OSDActivity)` where `OSDActivity` is `.volume(Int)`/`.brightness(Int)`) or as two separate cases — planner's call on the cleanest way to satisfy D-12's "instant mutual replace" requirement and the ROADMAP's "one shared OSD-replacement subsystem" language without duplicating logic. A single shared case makes `updateHead`'s existing same-category-replace semantics apply for free; two separate cases need new cross-category replace logic.
- Exact mechanism for reading the live system volume/brightness LEVEL (not just detecting a key press) — this project has no existing CoreAudio/DisplayServices code to reuse; the spike/research phase should confirm the reading API (e.g., `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` for volume; brightness reading is less standardized on Apple Silicon internal displays — this needs research, not a product decision).
- Naming of the new `VolumeActivity`/`BrightnessActivity` (or shared `OSDActivity`) types and the new Monitor/interceptor types (e.g. `VolumeHUDInterceptor`/`OSDInterceptor`, per PITFALLS.md's "isolate behind one protocol" guidance).
- Whether the Settings toggle for OSD suppression lives in its own row or alongside Focus's existing permission-gated toggles — implementation detail.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 39: Volume & Brightness HUD" — Goal and Success Criteria (spike-first ordering, `.cgSessionEventTap`-only mandate, `updateHead()` scrubbing requirement, `EnableSystemBanners` prohibition).
- `.planning/REQUIREMENTS.md` lines 53-54 (HUD-03, HUD-04) — requirement text, explicit fallback language ("falls back to showing alongside the native OSD if suppression proves unreliable").
- `.planning/REQUIREMENTS.md` line 95 (Out of Scope table) — confirms `EnableSystemBanners` is unverified beyond community forum reports and risks a confirmed Tahoe regression class; must not ship unconditionally.

### Pitfalls research — READ BEFORE THE SPIKE
- `.planning/research/PITFALLS.md` Pitfall 1 (lines 25-48) — the authoritative research on volume/brightness OSD suppression: the annotated-tap-vs-session-tap distinction, the confirmed Tahoe transport-key-breakage regression, the Accessibility (not Input Monitoring) permission requirement, the main-thread-contention double-HUD bug and its fix, the tap-disabled-re-enable-loop safety fix, the Caps Lock/TSM crash fix.
- `.planning/research/PITFALLS.md` Risk-Tier Summary table (lines 9-17) — Volume/Brightness HUD suppression rated HIGH risk, "needs a spike before committing scope."
- `.planning/research/PITFALLS.md` "Shortcuts That Will Bite" table (line 191) — using `.cgAnnotatedSessionEventTap` "because a tutorial shows it" is listed as "Never — always use `.cgSessionEventTap`".
- `.planning/research/PITFALLS.md` Integration Gotchas table (line 201) — CGEventTap requires Accessibility (`.defaultTap`), not just Input Monitoring, to actually consume/suppress the event.
- `.planning/research/PITFALLS.md` Pitfall 6 / Integration Gotchas (line 205) — "every new HUD type enqueues through `IslandResolver`, no exceptions" — applies to Volume/Brightness exactly as it did to Focus.
- `.planning/research/PITFALLS.md` Sources section (line 267) — `Droppy/MediaKeyInterceptor.swift` is the primary reference implementation for the suppression technique itself.

### Resolver architecture this phase extends
- `Islet/Notch/IslandResolver.swift:72-76` — the `ActiveTransient` enum (currently `.charging`/`.device`/`.focus`) — new Volume/Brightness case(s) go here (see Claude's Discretion on shared-vs-separate-case shape).
- `Islet/Notch/IslandResolver.swift:83-88` — `ActiveTransient.isPersistent` — Focus is the only persistent case today; Volume/Brightness must NOT be persistent (they self-elapse via D-10's 1.5s timer).
- `Islet/Notch/IslandResolver.swift:105-123` — `resolve(...)`'s `switch activeTransient` block, including the Phase 38 `.focus(let f) where !isExpanded` collapsed-only branch — D-11 requires the same shape for Volume/Brightness, and D-13 requires a new rank 4 below Focus.
- `Islet/Notch/IslandResolver.swift:231-298` — `TransientQueue` struct: `enqueue()`, `preempt()` (built in Phase 38 specifically for "a transient must interrupt a persistent Focus head rather than queue behind it forever" — D-13 above reuses this exact mechanism), `updateHead()` (currently same-category-only, no timer re-arm — D-09 needs a variant of this), `removeAll(where:)`.

### CGEventTap precedent already in this codebase (NOT Droppy's — this project's own)
- `Islet/Notch/DropInterceptTap.swift` — the exact `.cgSessionEventTap`/`.headInsertEventTap`/`.defaultTap` pattern already proven in Islet: `AXIsProcessTrustedWithOptions` permission request, `CGEvent.tapCreate` with a silent-no-op-on-nil-tap fallback (D-12 in that file's own comments — mirrors D-06 above), the 5s health-check-timer re-install pattern (D-07 above reuses this directly), idempotent `start()`/`stop()` lifecycle mirroring `BluetoothMonitor.swift`.

### Phase 38 precedent this phase directly extends
- `.planning/phases/38-focus-mode-hud/38-CONTEXT.md` — D-01 (opt-in toggle), D-03 (deep-link pattern), D-04 (silent degrade on permission denial), D-07 (collapsed-only scoping), D-08 (preempt-then-restore against Focus) — every one of these is directly reused/mirrored by D-05 through D-11 and D-13 above.

### Phase 36 visual precedent this phase partially diverges from
- `.planning/phases/36-cosmetic-restyles-signature-animation/36-CONTEXT.md` — D-01 through D-04 (Droppy-pill icon+label convention, fixed-vs-accent-tinted color rule) — D-01/D-02 above intentionally diverge from the icon+label layout (bar instead) while keeping the fixed-color rule.
- `.planning/phases/36-cosmetic-restyles-signature-animation/reference-droppy-volume-charging-pills.png` — the user-supplied Droppy Settings screenshot showing the exact bar-style Volume/Brightness pill preview this phase's visual design (D-01/D-02) is modeled on.
- `Islet/Notch/NotchPillView.swift` — `wingsShape(leftWidth:rightWidth:content:)` (~L1929), `wings(for:)` (Charging, ~L1959), `focusWings(for:)` (~L2151) — the exact wing-wrapper and icon+label patterns to pattern-match against for the new bar-based wing (note: this phase's bar layout is a NEW content shape inside the existing `wingsShape` wrapper, not a reuse of the icon+label HStack pattern itself).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/DropInterceptTap.swift` — the ONLY existing CGEventTap in this codebase; its permission-request, tap-creation, health-check, and lifecycle patterns should be mirrored (not reinvented) for the new Volume/Brightness interceptor.
- `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift`, `Islet/Notch/FocusModeMonitor.swift` — existing Monitor-protocol pattern for the new level-reading monitor(s).
- `Islet/Notch/IslandResolver.swift`'s `TransientQueue.preempt()` — already built in Phase 38 for exactly the "interrupt a persistent Focus head" problem D-13 needs solved again.
- `ActivitySettings.swift` — existing `@AppStorage`-backed toggle pattern (D-05).

### Established Patterns
- `IslandResolver.swift`'s "one pure arbiter" principle — every new HUD type routes through `IslandResolver`/`TransientQueue`, no view-layer bypass.
- Silent-degrade-on-permission-denial convention, refined by D-06 above: the HUD half degrades gracefully (still shows) even when the suppression half is denied — a partial degrade, not the Focus-style total-inert degrade, because only half the feature needs the permission.
- Phase 36's fixed-vs-accent-tinted color convention — extended by D-02 to the new bar fill colors.

### Integration Points
- No existing code reads live system volume or brightness levels — this is new surface area (see Claude's Discretion above on the reading API).
- New case(s) added to `ActiveTransient` enum, NOT persistent (unlike Focus).
- `resolve(...)`'s transient-handling switch needs a 4th tier (collapsed-only, below Focus) alongside the existing Charging/Device (full-takeover) and Focus (collapsed-only) tiers.
- `TransientQueue` needs: (a) a timer-re-arming variant of `updateHead()` for same-category scrubbing (D-09), (b) cross-category instant-replace between Volume and Brightness (D-12), (c) `preempt()` reuse against Focus (D-13).
- New Settings toggle + permission-status hint + deep-link (D-05/D-06/D-08), likely near Focus's existing toggle in `SettingsView.swift`.

</code_context>

<specifics>
## Specific Ideas

- The exact visual reference for this phase already exists: `reference-droppy-volume-charging-pills.png` (saved during Phase 36's discussion) shows Droppy's own Settings-panel preview of its Volume (green bar) and Brightness (orange/yellow bar) HUD pills — D-01/D-02 above are a direct application of that reference, not a fresh design.
- 1.5 seconds is the pinned auto-dismiss duration (D-10) — a deliberately different value from the shared 3s used by Charging/Device/Focus.

</specifics>

<deferred>
## Deferred Ideas

None raised during this discussion — stayed within phase scope throughout.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned 0 matches for this phase.

</deferred>

---

*Phase: 39-Volume & Brightness HUD*
*Context gathered: 2026-07-17*
