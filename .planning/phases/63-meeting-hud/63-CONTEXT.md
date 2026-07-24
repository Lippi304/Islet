# Phase 63: Meeting-HUD - Context

**Gathered:** 2026-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

While a native Zoom or Teams call is active with the microphone on, the notch shows a call-timer HUD (elapsed mm:ss) with a working system-wide mute toggle. This is the milestone's first feature with genuine call-detection uncertainty (no public API for "is a call active") — it needs its own on-device detection spike with a documented go/no-go before the full HUD is built, reusing the persistent-transient path Phase 62 just generalized (`TransientQueue.preempt()` / `ActiveTransient.isPersistent`).

**Requirements (locked via REQUIREMENTS.md, not re-discussed here):**
- **MEET-01:** While Zoom or Teams (native app) is running AND the microphone is active, the notch shows a call-timer HUD (elapsed mm:ss).
- **MEET-02:** Tapping the Meeting-HUD's mute control toggles the system-wide microphone mute (not the in-app mute state) via a shared `MicMuteController`.
- **MEET-03:** Google Meet (browser-based) is explicitly not detected in v1.10 — documented as a known limitation, not silently missing.

**Out of scope (locked in REQUIREMENTS.md "Out of Scope"):**
- True per-app in-call mute state (Zoom/Teams' own internal mute) — no public API/AppleScript surface exists; system-wide CoreAudio input mute is used instead.
- Google Meet call detection — runs in a browser tab, no filesystem/process signal identifies it without a browser extension.

</domain>

<decisions>
## Implementation Decisions

### Detection (locked by prior research, not re-asked)
- **D-01:** Detection heuristic = target app running (`NSWorkspace.runningApplications`, bundle IDs `us.zoom.xos` / `com.microsoft.teams2` / `com.microsoft.teams`) AND microphone in use (`kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device, CoreAudio `AudioHardware.h`). Source: `.planning/research/FEATURES.md` §1, `.planning/research/SUMMARY.md`. Classic Teams (`com.microsoft.teams`) added during plan-phase 63 — still coexists alongside new Teams in the wild (2026-07-24 plan-phase clarification).
- **D-02:** Mute mechanism = system-wide hardware mute via `AudioObjectSetPropertyData` with `kAudioDevicePropertyMute` on the input device, NOT any Zoom/Teams-specific API. Source: `.planning/research/FEATURES.md` §1.
- **D-03:** Detection risk isolated behind one `MeetingMonitor` file (mirrors `NowPlayingMonitor`/`BluetoothMonitor` isolation discipline) with an on-device spike + documented go/no-go before the full HUD is built — same shape as Phase 24's drag-in spike and Phase 47's audio pure-seam-first precedent.
- **D-04:** Mute action shares a new `MicMuteController` with the future Quick Actions bar (Phase 65) — build the CoreAudio mute primitive once, invoke from both call sites.

### Priority rank
- **D-05:** A live call is **high priority** in the `IslandResolver`/`TransientQueue` stack — it preempts Focus, OSD, Download-Progress, Caps Lock, Update-Available, and Timer. Only Charging and Device (physical hardware events) outrank it. New rank slot lands directly after `.device`, before `.focus`, in both `IslandPresentation` and `ActiveTransient` (`Islet/Notch/IslandResolver.swift` — the existing "Meeting HUD (Phase 63) — rank TBD" reserved comment at line 88 resolves to this rank). Reasoning (user-stated): being mid-call is as urgent as a hardware event; other transient HUDs (a 2s Caps Lock flash, an Update pill) shouldn't interrupt or hide the mute control while a call is live.
- **D-06:** Meeting-HUD is a **persistent transient** (`isPersistent == true` while the call is active) — reuses Phase 62's generalized `ActiveTransient.isPersistent`/`TransientQueue.preempt()` path exactly as intended (this is the second persistent case after Timer, and the reason Phase 62 generalized it ahead of a hardcoded `.focus`-only check).

### Trigger sensitivity
- **D-07:** Show trigger is **immediate** — the HUD appears the instant "Zoom/Teams running AND mic active" becomes true, no debounce/grace period. User explicitly chose immediate over a multi-second debounce despite the false-positive risk research flagged (e.g., testing mic in Zoom's own settings before joining a call) — accepted as a known tradeoff, not a target for the spike to "fix" unless on-device testing shows it's actually disruptive.
- **D-08:** Hide/dismiss trigger is **immediate**, symmetric with D-07 — when the mic goes inactive or the app quits, the HUD disappears right away, no lingering dismiss window (unlike Caps Lock/Charging's brief auto-dismiss — those are deliberately different because they're one-shot notifications, not a live status like the call timer).

### Collapsed interaction
- **D-09:** The mute control is **directly tappable inline on the collapsed HUD** — no expand-then-tap step. This is the first collapsed HUD in the codebase with an actual tap target embedded in it (every prior collapsed-only HUD — Charging, Caps Lock, Download-Progress — is pure display, zero interactivity). Planning/research must scope the collapsed hot-zone widening needed to cover just the mute icon's tap area, distinct from the existing wings-level hover/click zones.
- **D-10:** Meeting-HUD is **collapsed-only, always** — no `.meetingExpanded` presentation case. Tapping anywhere on the HUD other than the mute icon does nothing (or is a future concern, not this phase). This deliberately deviates from Timer's Pattern 4 (dedicated expanded controls) — user chose the simpler, smaller-scope shape.

### Visual design
- **D-11 (Claude's discretion):** Call-active icon (camera vs. phone vs. other SF Symbol) — pick during UI-spec, consistent with the existing wings icon style (Charging's battery glyph, Caps Lock's caps-arrow).
- **D-12 (Claude's discretion):** Mute-button visual state (icon swap only vs. icon swap + red-when-muted color signal) — pick during UI-spec, consistent with existing wing state-color precedent (e.g. OSD HUD urgency coloring).
- **D-13:** Timer format is **plain mm:ss always**, rolling past 59:59 for calls over an hour (e.g. "75:32") — explicitly NOT switching to h:mm:ss past the 1-hour mark. Matches Timer/Pomodoro's existing format exactly; no new formatting branch needed.

### Claude's Discretion
- Exact SF Symbol for the call-active icon (D-11).
- Exact mute-button visual treatment — icon-only vs. icon+color (D-12).
- Spike methodology/tooling for validating the detection heuristic on real hardware, and the specific go/no-go criteria — mirrors Phase 24/47's spike-first precedent, mechanism is a technical call.
- Exact mechanism for generalizing `ActiveTransient.isPersistent`'s case-matching to include the new `.meeting` case (already-generalized per Phase 62, this is just wiring in the new case).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research (mechanism + risk, done ahead of this milestone)
- `.planning/research/SUMMARY.md` — overall v1.10 build order and shared-infrastructure map; Meeting-HUD flagged as one of two features needing a dedicated pre-planning spike (the other is Menübar-Overflow).
- `.planning/research/FEATURES.md` §1 (lines 9-21) — Meeting-HUD's detection heuristic, mute mechanism, table stakes, and confidence rating in full detail.
- `.planning/research/PITFALLS.md` — Pitfall 1 (fragile window-title/process heuristics — isolate in `MeetingMonitor`), Pitfall 8 (shared `MicMuteController`, don't build the mute helper twice).

### Prior phase precedent (architecture this phase depends on)
- `.planning/phases/62-timer-pomodoro/62-CONTEXT.md` — the persistent-transient generalization Meeting-HUD depends on and directly reuses (D-06 above); also documents the "sub-state-persistent" pattern from Phase 61 as the closest analog for a running/ended distinction, if that shape turns out useful during planning.
- `.planning/phases/61-download-progress/61-CONTEXT.md` — closest existing precedent for a persistent-transient sub-state split (`.inProgress` persistent, `.done` not).

### Codebase (exact integration points, verified by reading the live file)
- `Islet/Notch/IslandResolver.swift:88` — the reserved "Meeting HUD (Phase 63) — rank TBD" comment this phase's D-05 resolves.
- `Islet/Notch/IslandResolver.swift:123-151` — `ActiveTransient` enum + `isPersistent` computed property, already generalized past the single `.focus` case (Phase 62); Meeting-HUD adds a `.meeting` case here per D-06.
- `Islet/Notch/IslandResolver.swift:339-390` — `TransientQueue` struct, `preempt(_:)` — already generalized to check `currentHead.isPersistent` for ANY persistent case, not just `.focus`; no further generalization needed, just correct case-matching for the new `.meeting` transient.
- `Islet/Notch/AudioOutputMonitor.swift` — existing CoreAudio integration pattern (output-device side) to mirror for the new input-device mute primitive; no existing input-mute code exists yet in this codebase (grep confirmed zero hits for `kAudioDevicePropertyMute`/`MicMuteController`).

No external specs beyond the above — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `IslandResolver.swift`'s generalized `ActiveTransient.isPersistent` / `TransientQueue.preempt()` (Phase 62) — Meeting-HUD is the second persistent-transient case and can wire straight in without touching the generalization logic itself.
- `AudioOutputMonitor.swift` — established CoreAudio monitoring pattern (property listeners, device-property reads) to mirror for the new mic-mute primitive, even though it targets the output side today.
- Existing collapsed-HUD wings pattern (Charging/Caps Lock/Download-Progress) for the visual shell — Meeting-HUD's collapsed pill reuses this, but is the first to need an actual tap target inside it.

### Established Patterns
- Spike-first, risk-isolated-last: Phase 22→24 (drag-in), Phase 38→39 (Focus Mode before Volume/Brightness), Phase 47→48 (pure seam before UI wiring) — Meeting-HUD's detection spike (D-03) follows this same convention before the full HUD build.
- One `*Monitor` file per fragile/system-integration seam (`NowPlayingMonitor`, `BluetoothMonitor`, now `MeetingMonitor`) — isolates risk, one-file swap if the heuristic breaks.
- Shared helper reuse across features before either ships (`MicMuteController` used by both Meeting-HUD, this phase, and Quick Actions bar, Phase 65) — build once at first use.

### Integration Points
- `IslandResolver.swift` — new `.meeting(MeetingActivity)` case in both `IslandPresentation` and `ActiveTransient`, ranked per D-05, `isPersistent` per D-06.
- New `MeetingMonitor.swift` — process-running + mic-active detection, isolated per D-03.
- New `MicMuteController` (shared, first built here) — system-wide input mute primitive per D-02/D-04.
- `NotchWindowController` — wiring for the new collapsed-HUD case + the new inline-tappable mute hot-zone (D-09), following the existing wings-handler pattern.
- Settings — a new Live-Activity card (SETTINGS-04 grid pattern, Phase 59), defaulting OFF per SETTINGS-05 (every new v1.10 activity defaults OFF).

</code_context>

<specifics>
## Specific Ideas

No specific visual/reference-app screenshots supplied for Meeting-HUD (unlike Droppy references used elsewhere this milestone) — user deferred both icon choice and mute-state color treatment to Claude's discretion (D-11, D-12).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (True in-app mute reflection and Google Meet support were already out-of-scope items from REQUIREMENTS.md, not new deferrals from this discussion.)

</deferred>

---

*Phase: 63-Meeting-HUD*
*Context gathered: 2026-07-24*
