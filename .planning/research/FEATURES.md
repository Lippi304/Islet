# Feature Research

**Domain:** macOS notch-overlay live-activities app — v1.10 "Live Activities Suite" (9 new HUDs/activities + Settings redesign)
**Researched:** 2026-07-23
**Confidence:** MEDIUM-HIGH (grounded in official Claude Code hooks docs, Ice's GitHub README/community writeups, Droppy's own marketing copy, and standard CoreAudio/AppleScript/FSEvents references; two features — Meeting-HUD and Menübar-Overflow — carry real implementation uncertainty flagged below for phase-specific deep research)

## Feature-by-Feature Behavior Notes

### 1. Meeting-HUD (Zoom/Meet/Teams call timer + mute)

**Expected behavior:** while a video call is active, the notch shows a call timer (elapsed mm:ss) and a one-tap mute toggle, similar in spirit to the already-shipped Now Playing activity.

**The hard problem:** there is no unified public macOS API for "is a call currently active" across Zoom, Google Meet, and Teams. Zoom and Teams are native apps (bundle IDs `us.zoom.xos`, `com.microsoft.teams2`) whose *presence* is trivially detectable via `NSWorkspace.runningApplications`, but their *in-call* state is not exposed. Google Meet runs inside a browser tab — realistically undetectable without a browser extension, so it should not be promised at MVP. The standard community workaround (confirmed via search — this is how tools like MeetingBar and various "on-air" menu-bar apps behave) is to combine (a) target-app-running with (b) the microphone-in-use signal (`kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device, from CoreAudio's `AudioHardware.h`) as a corroborating heartbeat. Mic-alone is a false-positive magnet (fires for Voice Memos, dictation, etc.), so gating on "target app running AND mic active" is the pragmatic MVP signal.

**Mute toggle:** cannot reliably reach into Zoom/Teams's own in-call mute state (no public API/AppleScript dictionary support for it). The realistic MVP is a **system-wide hardware mute** via `AudioObjectSetPropertyData` with `kAudioDevicePropertyMute` on the input device — mutes for every app simultaneously, which behaves correctly as long as the user is only in one call context at a time (true for almost all real usage).

**Table stakes:** call presence detected + timer counts up + shows in the island via the existing priority arbiter.
**Differentiator (defer):** mute reflecting the actual in-app mute state (not just system mic) — no known reliable technique; do not commit to this for v1.10.
**Complexity:** HIGH — the only "detection" feature among the 9 with no clean API; proxy-signal based, will need on-device tuning to avoid false positives/negatives.
**Dependency on existing Islet subsystems:** reuses `IslandResolver` priority arbitration and the "isolate risky integration behind one protocol" pattern already proven with `NowPlayingMonitor`/`BluetoothMonitor` — a new `MeetingMonitor` should follow the identical isolation discipline. Its mute action also overlaps with the Quick Actions bar's mic-mute action (same CoreAudio call) — build one shared `MicMuteController` used by both.
**Confidence:** MEDIUM — detection strategy is a documented community pattern, not an Apple-sanctioned API; flag for phase-specific research before implementation, especially false-positive tuning.

### 2. Download-Progress (Downloads-folder progress bar)

**Expected behavior:** a file appearing/growing in `~/Downloads` shows a live progress indicator in the notch; completion (browser renames the temp file to its final name) collapses it into a brief "done" state.

**The hard problem:** true percentage-complete requires knowing total expected bytes, which isn't reliably available at the filesystem layer for all browsers' partial-download conventions (Safari, Chrome `.crdownload`, Firefox `.part` all differ). The robust, low-risk approach: watch `~/Downloads` via a `DispatchSource`-based directory watcher (the modern idiomatic Swift approach over raw FSEvents C bindings) for temp-extension file creation, track its growing size for an "activity" pulse, and treat the **rename-to-final-filename event** as the completion signal (100%) rather than trying to compute a true percentage in all cases.

**Table stakes:** notch shows *something is downloading* and clears/confirms on completion; never blocks or interferes with the actual download.
**Differentiator:** click-through to reveal in Finder; multiple concurrent downloads shown as a small stacked list.
**Anti-feature:** pause/resume/cancel control — not exposed to third-party apps by the OS without a browser extension; explicitly out of scope.
**Complexity:** MEDIUM — folder watching itself is simple stdlib territory; the percentage-accuracy edge cases are the real cost, so scope MVP to presence + completion rather than exact %.
**Dependency:** new `FolderWatcher` utility — build it generically enough to also serve Coding-Progress (#9), which needs the same "watch a path, react to changes" primitive. Reuses existing HUD/wings + `IslandResolver` for presentation.
**Confidence:** MEDIUM-HIGH on the watching mechanism, LOW on percentage precision across all browsers — flag as a scoping decision for REQUIREMENTS.md (presence-only vs. best-effort %).

### 3. Timer/Pomodoro (countdown/focus session)

**Expected behavior:** user sets a duration, notch shows a live countdown (collapsed glance = mm:ss + shrinking ring/bar), expanded view offers pause/reset/add-time, and completion fires a HUD splash + system notification/sound. Pomodoro mode adds work/break cycling with a session counter.

**Table stakes:** start/pause/reset, visible countdown, completion alert.
**Differentiator:** Pomodoro work/break presets with session counting; auto-enabling macOS Focus Mode during a work session is a stretch — no public API for it (only AppleScript/Shortcuts-CLI workarounds, same reliability caveat as the DND action in Quick Actions bar), flag as v2.
**Complexity:** LOW-MEDIUM — the simplest of the 9 features. Pure local state (a `Task`/`Timer`-driven countdown), zero external system integration required for the core loop.
**Dependency:** the **heaviest reuse** of any new feature — directly reuses the existing HUD/wings transient-splash pattern (start/complete moments, same visual language as Charging) and the expanded-view live-progress pattern already shipped for Now Playing's progress bar (Phase 7, PBAR-01). Should be the cheapest of the 9 to build precisely because its chrome already exists end-to-end.
**Confidence:** HIGH.

### 4. Quick Notes + Obsidian export

**Expected behavior:** a fast-entry capture UI (menu-bar flyout, mirroring the existing Clipboard History submenu), typed note gets appended — timestamped — to one fixed `.md` file inside a user-chosen Obsidian vault folder, selected once via a folder/file picker.

**Table stakes:** append-only (never overwrites/corrupts the file), creates the file if it doesn't exist yet, works even if Obsidian.app itself is closed (it's just a plain text file — this is in fact how the real Obsidian ecosystem does lightweight external capture: Obsidian's own `obsidian://` URI scheme and community tools like Raycast's Obsidian extension favor plain file/URI writes over requiring the "Local REST API" community plugin).
**Differentiator (defer):** "daily note" mode (append to `YYYY-MM-DD.md` instead of one fixed file), tag autocomplete pulled from the existing vault, Markdown formatting shortcuts.
**Anti-feature:** building against Obsidian's Local REST API plugin as a hard dependency — raises the bar for users who just want folder-drop simplicity; plain file append is the standard lightweight pattern.
**Complexity:** LOW-MEDIUM. The capture UI and history list should be near-identical to Clipboard History's existing flyout submenu and "recent items" treatment (possibly extending the same Cmd+0-9 quick-recall convention). The one genuinely new piece: append-to-external-file (`FileHandle.seekToEndOfFile()` + write) and a one-time folder/file picker whose selection is persisted (Islet is not App-Sandboxed given its existing private-API usage, so this is a plain stored path, not a security-scoped-bookmark dance).
**Dependency:** STRONG reuse of the Clipboard History subsystem's UI shell and persistence-service pattern. Open question to resolve in REQUIREMENTS.md: does the local quick-notes history need the same at-rest encryption Clipboard History uses, or is that overkill for notes destined for a plaintext vault file anyway?
**Confidence:** HIGH on the UX/reuse story, MEDIUM on Obsidian-specific conventions (no single canonical timestamp format — needs a UX decision, not a technical unknown).

### 5. Quick Actions bar (configurable action buttons)

**Expected behavior:** a small grid/row of tappable action buttons live in the notch, user-configurable (which actions, what order).

**Sensible default action catalog** (cross-referenced against how existing macOS menu-bar utilities implement each):

| Action | Trigger mechanism | Reliability |
|---|---|---|
| Mic mute/unmute | CoreAudio `AudioObjectSetPropertyData` with `kAudioDevicePropertyMute`, scope Input, on default input device | HIGH — documented HAL property, works for built-in/wired mics; Bluetooth mic mute has had version-specific quirks (worked around by also setting volume, per community fixes) |
| Display sleep now | Shell out to `pmset displaysleepnow`, or `IOPMSleepSystem`/`CGDisplaySleep` at a lower level | HIGH — `pmset` shell-out is the simplest, no private API risk |
| Dark/Light mode toggle | AppleScript via `osascript`/`NSAppleScript`: `tell application "System Events" to tell appearance preferences to set dark mode to not dark mode` | HIGH — documented, standard AppleScript dictionary hook |
| Screen lock | Launch `CGSession -suspend` as a subprocess | HIGH — long-standing, widely used lightweight lock trick |
| Do Not Disturb / Focus toggle | No stable public API. Two realistic paths: (a) `shortcuts run "<name>"` requiring the user to pre-create a matching Shortcuts.app shortcut — extra setup burden; (b) simulate the Option-click on the Control Center clock via Accessibility/CGEvent — brittle, breaks if the user has removed that menu item | LOW-MEDIUM — flag as "best effort," the one default action genuinely at risk; even the community `do-not-disturb-cli` npm tool relies on undocumented mechanisms, confirming there's no clean answer here |
| Caffeinate / keep-awake toggle | Launch/kill a `caffeinate` subprocess | HIGH — trivial and reliable |
| Empty Trash | `NSWorkspace` / `FileManager` trash API | HIGH |
| Launch app or open URL | `NSWorkspace.open` | HIGH |

**Differentiator:** user-configurable/reorderable action grid (drag to reorder — mirrors Droppy's "customize your shelf" philosophy), per-action custom icon/label, keyboard-shortcut binding.
**Anti-feature:** a full custom scripting/AppleScript-editor action builder — scope creep; ship a fixed catalog (~8-10 actions) with enable/reorder toggles instead.
**Complexity:** MEDIUM overall. Individually, each trigger is LOW complexity (mostly one-liner Process/AppleScript/CoreAudio calls); the actual MEDIUM cost is the configurable-grid chrome (layout, drag-reorder, persisted selection/order) — not the triggers themselves.
**Dependency:** new UI component, but persistence should reuse the existing Settings `@AppStorage` pattern (matches how the 3 activity toggles + accent palette already persist). Shares the mic-mute primitive with Meeting-HUD (#1) — build once, use from both.
**Confidence:** HIGH on 7 of 8 default actions, MEDIUM-LOW specifically on DND/Focus.

### 6. Menübar-Overflow (Ice-style MVP)

**Ice's actual UX flow** (verified against Ice's GitHub README and multiple independent writeups — jordanbaird/Ice, github.com/jordanbaird/Ice):

- The menu bar is divided by chevron-shaped **separator items** into up to three sections: **visible** (right of the main chevron, always shown), **hidden** (between the main and a second, smaller chevron), and **always-hidden** (left of the small chevron — a second section only revealed via right-click → "Show the Always-Hidden Section").
- Users move icons between sections using the **standard macOS Cmd-drag** gesture for repositioning menu-bar items — the same OS-native mechanism used to reorder any menu-bar icon manually. Ice doesn't invent a new drag system; it plants draggable chevron/separator items that define where the visible/hidden boundary sits, and other apps' icons get dragged across that boundary the normal way.
- The chevron is itself a real menu-bar item and can be Cmd-dragged left/right to move the boundary.
- **Clicking the (visible) chevron reveals/hides the hidden section** — items slide in/out. This click-to-toggle interaction is the specific behavior this milestone's "Ice-style MVP" targets.
- Ice also supports hover-to-reveal, scroll/swipe-to-reveal, click-on-empty-menu-bar-area, and auto-rehide-after-delay — all configurable in Settings → General. These are explicitly **not** part of this milestone's scope (chevron-click only).

**Complexity:** HIGH — the most technically novel feature of the 9. Unlike the other 8 (which wrap documented or semi-documented single-app APIs), this feature must reposition/hide **other processes' own UI elements** (their `NSStatusItem`s), which macOS does not expose a public API for. The general approach known-open-source menu-bar managers use (Ice, Bartender, Hidden Bar) is to insert their own status items at controlled positions and exploit the fact that `NSStatusItem`s maintain stable left-to-right ordering, then move the *boundary* item and toggle other items' effective visibility by shifting them off the visible menu-bar strip — a technique that (a) requires Accessibility permission, (b) has known per-macOS-version fragility, and (c) has documented incompatibilities with some aggressively-redrawing menu-bar apps. This is a materially higher-risk feature than the rest of the milestone.
**Table stakes for the MVP:** one chevron, click toggles reveal/hide of everything behind it; other apps' icons remain their real icon (not re-skinned), genuinely absent from the visible strip when hidden.
**Differentiator (explicitly deferred per milestone scope):** always-hidden second section, hover/scroll-to-reveal, auto-rehide timer, menu-bar tint/shape customization.
**Dependency on existing Islet subsystems:** **none** — this is the one feature that doesn't touch the notch at all; it's a standalone menu-bar subsystem. It also requires a **new Accessibility permission request flow**, distinct from Islet's existing WeatherKit/EventKit/Bluetooth TCC prompts — no precedent to reuse.
**Confidence:** MEDIUM-HIGH on Ice's user-facing UX (well corroborated across multiple independent sources), LOW-MEDIUM on the exact underlying implementation mechanism (Ice's precise private-API technique isn't published in one authoritative document — inferred from the known constraints of the problem and community discussion). **Recommend flagging this feature for its own dedicated phase-level research spike before implementation begins**, given it's both the highest-complexity and least-precedented feature in the milestone.

### 7. Caps Lock ON/OFF indicator HUD

**Expected behavior:** toggling Caps Lock briefly flashes a HUD splash (same transient wings/pill pattern as Charging) showing an on/off glyph, auto-dismissing after ~1-2s. macOS has no native Caps Lock OSD to suppress (unlike Volume/Brightness, which already required native-OSD-suppression work) — this is presentation-only, no interception problem.

**Detection:** `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`, checking `event.modifierFlags.contains(.capsLock)` — a fully public, simple, well-known API.
**Table stakes:** distinguishing on-triggered vs off-triggered state (different icon) is effectively required for a sane MVP, not really a stretch differentiator.
**Complexity:** LOW — alongside Timer, the simplest feature in the milestone.
**Dependency:** pure reuse of the existing HUD/wings transient-splash pattern + `IslandResolver` priority slot; no new subsystem beyond the `NSEvent` monitor itself.
**Confidence:** HIGH.

### 8. Update-Activity restyle (cosmetic reskin)

**Expected behavior:** the already-shipped Sparkle update-available HUD gets a new SwiftUI layout matching Droppy's look — leading icon, "Update" label, trailing rounded version-number pill/badge — with identical trigger logic.

**Complexity:** LOW — explicitly a visual-only task; no new subsystem, no new permission, Sparkle plumbing untouched.
**Dependency:** 100% reuse of existing update-detection code; only the `View` changes.
**Confidence:** HIGH — no material unknowns, light research only as scoped.

### 9. Coding-Progress (live Claude Code CLI session in the notch)

**Expected behavior:** while a Claude Code CLI session is running, the notch shows todo-list completion fraction (e.g., "3/7"), falling back to a status text when no todo list exists yet.

**How Claude Code actually exposes this** (verified against the official hooks reference, code.claude.com/docs/en/hooks): Claude Code supports lifecycle **hooks** — user-configured shell commands (in `.claude/settings.json` or `~/.claude/settings.json`) that fire on events like `PostToolUse`, `Stop`, `SessionStart`, `SessionEnd`, receiving a JSON payload on **stdin**. The `TodoWrite` tool — the mechanism Claude Code itself uses internally to track its task list — can be matched via `PostToolUse` with `matcher: "TodoWrite"`; the payload's `tool_input.todos` is an array of `{content, status, activeForm}` objects with `status` ∈ `{pending, in_progress, completed}` — exactly the fraction Islet needs. Fallback status text can come from the `Stop` hook's `last_assistant_message` field, or a generic "Claude is working…" from `SessionStart`/`UserPromptSubmit`.

**Integration path:** ship a small hook script (bash/Python, distributed with Islet or generated by its Settings UI) that the user adds to their own Claude Code settings; on each matched hook event it writes the current todos JSON to a well-known local file (e.g. `~/Library/Application Support/Islet/coding-progress.json`), which Islet's monitor tails via the same folder-watcher primitive needed for Download-Progress (#2) — a genuine shared-infrastructure opportunity, build one `FileWatcher` utility, not two.

**This is a confirmed real reference-app feature, not speculative:** Droppy's own marketing page explicitly advertises "an AI coding companion that surfaces activity from Claude Code, Cursor, and Codex directly in the notch."

**Table stakes:** shows completion fraction while a session has an active todo list; clears/times out when the session goes idle or ends (`SessionEnd` can clear state).
**Differentiator (defer):** per-project session identification (cwd shown), multi-session queue/switcher when more than one Claude Code session runs concurrently, live-streaming `last_assistant_message` as scrolling status text.
**Complexity:** MEDIUM. The hook mechanism itself is simple and Anthropic-supported/stable; the real cost is (a) a **required user setup step** — installing the hook into their own Claude Code config, a genuine onboarding UX problem worth flagging separately in REQUIREMENTS.md, (b) the file-based IPC bridge between the hook's short-lived shell process and the always-running Islet app, and (c) deciding which session wins the notch slot when multiple Claude Code sessions run concurrently (recommend: most-recently-active, consistent with the existing priority-arbiter's "most relevant wins" philosophy).
**Dependency:** shares the new `FileWatcher` utility with Download-Progress; reuses `IslandResolver` for priority slotting and the progress-bar visual language already shipped for Now Playing (PBAR-01).
**Confidence:** MEDIUM-HIGH on the hooks mechanism (verified against official current docs), MEDIUM on end-to-end wiring since it's the only feature in this milestone that requires the user to perform an external configuration step outside Islet itself.

---

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Meeting-HUD: call presence + timer | Core promise of the feature name | HIGH | Zoom/Teams native apps only at MVP; Google Meet (browser) unsupported |
| Download-Progress: activity + completion signal | Core promise of the feature name | MEDIUM | Presence/completion, not necessarily exact % |
| Timer: countdown + completion alert | Table stakes for any timer feature | LOW-MEDIUM | Reuses existing HUD chrome almost entirely |
| Quick Notes: reliable append-only capture | Data-loss risk if it ever overwrites | LOW-MEDIUM | Reuses Clipboard History UI/persistence pattern |
| Quick Actions: the ~8 reliable default actions | "Quick actions" implies zero-setup usefulness | MEDIUM | DND/Focus is the one unreliable default, ship as best-effort |
| Menübar-Overflow: chevron hide/show | This IS the feature, per Ice reference | HIGH | Requires new Accessibility permission flow |
| Caps Lock: on/off flash | Simple, expected parity with Volume/Brightness HUD | LOW | No native OSD to suppress, unlike Volume/Brightness |
| Update-Activity: visual match to Droppy | Explicitly scoped as cosmetic | LOW | No new subsystem |
| Coding-Progress: completion fraction | Core promise, confirmed real in Droppy | MEDIUM | Requires one-time user hook setup |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Meeting-HUD: true in-app mute reflection | Feels "real" instead of a system-wide side effect | HIGH | No known reliable technique — do not commit for v1.10 |
| Quick Actions: drag-to-reorder configurable grid | Matches Droppy's "customize your shelf" philosophy | MEDIUM | Persist via existing `@AppStorage` pattern |
| Quick Notes: daily-note mode, tag autocomplete | Matches native Obsidian workflows more closely | MEDIUM | Explicitly out of this milestone's fixed-file scope |
| Menübar-Overflow: always-hidden section, hover/scroll reveal, auto-rehide | Full Ice parity | HIGH | Explicitly deferred by milestone scope |
| Coding-Progress: multi-session switcher, live status streaming | Useful for power users running parallel sessions | MEDIUM | Defer to v1.x |
| Timer: Pomodoro presets + Focus Mode auto-enable | Matches dedicated Pomodoro apps | LOW (presets) / HIGH (Focus API) | Focus enable has no public API — same reliability issue as DND action |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Full Obsidian Local REST API integration | Feels "properly integrated" | Requires user to install/keep running a separate Obsidian community plugin — raises the bar past what "quick capture" should need | Plain append to a user-chosen `.md` file — the lightweight pattern real Obsidian quick-capture tools already use |
| Per-app in-call mute control (Zoom/Teams internal state) | Feels more precise than a system-wide mute | No public API/AppleScript surface exists; would require fragile, app-version-specific Accessibility hacks | System-wide CoreAudio input mute — correct behavior for the overwhelmingly common single-call case |
| Download pause/resume/cancel control | Feels like a "real" download manager | Not exposed to third-party apps by the OS without a browser extension | Show progress/completion only; leave control to the browser |
| Full custom action-scripting sandbox for Quick Actions | Maximum flexibility | Scope creep — becomes a mini Shortcuts.app; huge surface for bugs and support burden | Fixed catalog of ~8-10 pre-built, well-tested actions with enable/reorder toggles |
| Full Ice feature parity in one milestone (tint/shape, multiple hidden sections, all reveal triggers) | "Might as well build the whole thing" | Menübar-Overflow is already the highest-risk feature in the milestone; scope creep here directly threatens the whole milestone timeline | MVP = one chevron, click-to-toggle only; everything else is v1.x |
| Promising Google Meet call detection at MVP | Meeting-HUD should "just work" for any video call | Meet runs in a browser tab; no filesystem/process signal identifies it without a browser extension | Scope Meeting-HUD to native Zoom/Teams apps only; document Meet as unsupported |

## Feature Dependencies

```
[Meeting-HUD] ──shares──> [MicMuteController] <──shares── [Quick Actions bar: mic-mute action]
[Meeting-HUD] ──reuses──> [IslandResolver priority arbiter] (existing)
[Meeting-HUD] ──reuses pattern──> [NowPlayingMonitor/BluetoothMonitor isolation discipline] (existing)

[Download-Progress] ──shares infra──> [FileWatcher/FolderWatcher utility] <──shares infra── [Coding-Progress]

[Quick Notes] ──reuses──> [Clipboard History: flyout submenu UI + persistence pattern] (existing)

[Timer/Pomodoro] ──reuses heavily──> [HUD/wings transient pattern] (existing, same as Charging)
[Timer/Pomodoro] ──reuses heavily──> [Now Playing expanded-view + progress-bar pattern] (existing, PBAR-01)

[Caps Lock] ──reuses──> [HUD/wings transient pattern] (existing, same as Charging)

[Update-Activity restyle] ──reuses──> [existing Sparkle update-detection + HUD view] (view swap only)

[Coding-Progress] ──reuses──> [Now Playing progress-bar visual language] (existing, PBAR-01)
[Coding-Progress] ──requires──> [User configures a Claude Code hook outside Islet] (external setup step, unique to this feature)

[Menübar-Overflow] ──requires──> [New Accessibility permission flow] (no existing precedent)
[Menübar-Overflow] ──independent of──> [notch/IslandResolver subsystem entirely] (operates on the menu bar, not the notch)

[Quick Actions bar] ──requires──> [Settings @AppStorage persistence pattern] (existing, same as activity toggles/accent palette)

[Timer/Pomodoro: Focus Mode auto-enable] ──conflicts with reliability of──> [Quick Actions: DND toggle] (both blocked by the same "no public Focus API" gap)
```

### Dependency Notes

- **Download-Progress and Coding-Progress should share one `FileWatcher` utility:** both need "watch a path, react to changes" — building it once (generic over file vs. directory) avoids two near-duplicate subsystems.
- **Meeting-HUD and Quick Actions bar share `MicMuteController`:** both ultimately call the same CoreAudio `kAudioDevicePropertyMute` primitive on the input device — build once, invoke from both call sites, avoid divergent mute-state bugs.
- **Menübar-Overflow has zero reuse from existing Islet subsystems** — it's the one feature that doesn't live in the notch at all, and it needs a permission flow (Accessibility) Islet has never requested before. Treat it as its own isolated phase with its own research spike, not something to bundle casually alongside the other 8.
- **Timer/Pomodoro has the highest reuse ratio of the 9** — nearly all of its visual chrome already exists (transient HUD splash + expanded live-progress view), making it the cheapest to build despite being a "new feature."
- **Coding-Progress is the only feature requiring action outside the app itself** (the user must add a hook to their own Claude Code settings) — this is a genuine onboarding/documentation requirement, not just an engineering task, and should get its own requirement line in REQUIREMENTS.md distinct from the build work.
- **DND/Focus toggling (Quick Actions) and Focus-Mode auto-enable (Timer differentiator) share the same underlying gap:** macOS has no public API for either; both routes (Shortcuts CLI, Accessibility-simulated clock click) are best-effort. Don't let this become a blocking dependency for either feature — ship both with DND/Focus explicitly documented as "best effort."

## MVP Definition

### Launch With (v1.10)

All 9 are milestone-scoped, but realistic build-order by risk (cheapest/most certain first):

- [ ] Caps Lock indicator — trivial, pure reuse of existing HUD pattern
- [ ] Update-Activity restyle — trivial, view-only
- [ ] Timer/Pomodoro (core countdown, no Focus-Mode auto-enable) — near-total reuse of existing chrome
- [ ] Quick Notes + Obsidian export (fixed-file append only, no daily-note mode) — strong reuse of Clipboard History
- [ ] Quick Actions bar (fixed 8-action catalog, DND best-effort) — medium cost, mostly config-UI work
- [ ] Download-Progress (presence + completion signal, not guaranteed exact %)
- [ ] Meeting-HUD (Zoom/Teams native apps only, system-wide mute only, no Google Meet)
- [ ] Coding-Progress (single most-recent session, requires documented user hook setup)
- [ ] Menübar-Overflow (one chevron, click-to-toggle only — recommend its own dedicated research/planning phase given its novelty)

### Add After Validation (v1.x)

- [ ] Menübar-Overflow: always-hidden second section, hover/scroll reveal, auto-rehide timer — once the MVP chevron mechanism is proven stable across macOS versions
- [ ] Meeting-HUD: true per-app in-call mute reflection — only if a reliable technique is found
- [ ] Quick Notes: daily-note mode, tag autocomplete
- [ ] Coding-Progress: multi-session switcher, live status streaming
- [ ] Quick Actions: user-added custom actions

### Future Consideration (v2+)

- [ ] Google Meet browser-tab call detection — needs a browser extension, out of native-app scope entirely
- [ ] Menübar-Overflow: menu-bar tint/shape/border customization — full Ice feature parity, not core to Islet's identity
- [ ] Timer: Focus Mode auto-enable — blocked on the same missing public API as DND toggle; revisit if Apple ever ships one

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Caps Lock indicator | MEDIUM | LOW | P1 |
| Update-Activity restyle | LOW (cosmetic) | LOW | P1 |
| Timer/Pomodoro | HIGH | LOW-MEDIUM | P1 |
| Quick Notes + Obsidian export | HIGH | MEDIUM | P1 |
| Quick Actions bar | HIGH | MEDIUM | P1 |
| Download-Progress | MEDIUM | MEDIUM | P2 |
| Meeting-HUD | HIGH | HIGH | P2 |
| Coding-Progress | MEDIUM-HIGH (niche but core to this user's own dev workflow) | MEDIUM-HIGH | P2 |
| Menübar-Overflow | MEDIUM | HIGH | P3 — recommend isolating as its own phase |

**Priority key:**
- P1: Cheapest, most-certain wins — build first, establishes confidence and shared infra (FileWatcher, MicMuteController) other features need
- P2: Real value, real technical risk — schedule after P1 infra exists, budget time for detection-signal tuning
- P3: Highest novelty/risk relative to value — treat as its own dedicated phase with a pre-implementation research spike, not bundled casually with the rest

## Competitor Feature Analysis

| Feature | Droppy (explicit reference) | Ice (explicit reference) | Our Approach |
|---------|------------------------------|---------------------------|--------------|
| Caps Lock indicator | Confirmed shipped: "visual confirmation in your notch when Caps Lock is active" | N/A | Match Droppy's transient-flash pattern, reuse existing HUD/wings chrome |
| Update-Activity visual style | Built-in update notifications; general aesthetic is icon + label + pill-shaped metadata (per milestone brief's own description) | N/A | Reskin existing Sparkle HUD to icon + "Update" + version pill |
| Coding-Progress | Confirmed shipped: "an AI coding companion that surfaces activity from Claude Code, Cursor, and Codex directly in the notch" | N/A | Scope to Claude Code only at v1.10 (not Cursor/Codex); hook-based, file-watched |
| HUD philosophy | "Files, clipboard history, notifications, and HUDs" consolidated into one spot; hand-tuned spring-based motion consistency across all HUD types | N/A | Islet already has this consistency via `IslandResolver` + shared HUD/wings pattern — new features should slot into it, not invent new motion languages |
| Menu-bar overflow hide/show | N/A | Confirmed: chevron-separated visible/hidden/always-hidden sections, Cmd-drag to move icons, click/hover/scroll to reveal, auto-rehide | MVP subset only: one chevron, click-to-toggle; defer always-hidden section and non-click reveal triggers |

## Sources

- [Ice/README.md at main · jordanbaird/Ice](https://github.com/jordanbaird/Ice/blob/main/README.md) — HIGH confidence, official repo README
- [GitHub - jordanbaird/Ice: Powerful menu bar manager for macOS](https://github.com/jordanbaird/Ice) — HIGH confidence, official repo
- [Ice is a Strong Contender to Replace Bartender App - Podfeet Podcasts](https://www.podfeet.com/blog/2024/06/ice-bartender-replacement/) — MEDIUM confidence, independent writeup corroborating chevron/Cmd-drag UX
- [How to control which section apps are assigned to? · Issue #42 · jordanbaird/Ice](https://github.com/jordanbaird/Ice/issues/42) — MEDIUM confidence, community discussion of section mechanics
- [Droppy — Your all-in-one Mac productivity companion](https://getdroppy.app/) — MEDIUM confidence, vendor marketing copy, but explicitly confirms Coding-Progress and Caps Lock as real shipped features (grounds the milestone's reference-app claims)
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks) — HIGH confidence, official Anthropic documentation (fetched directly, current)
- [Todo Lists - Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/todo-tracking) — HIGH confidence, official docs, confirms `TodoWrite` schema (`content`/`status`/`activeForm`)
- [Detect when (internal or external) microphone is being used - Apple Developer Forums](https://developer.apple.com/forums/thread/741026) — MEDIUM confidence, official Apple forum discussion of `kAudioDevicePropertyDeviceIsRunningSomewhere`
- [Silently mute the mic input via AppleScript – The Robservatory](https://robservatory.com/silently-mute-the-mic-input-via-applescript/) — MEDIUM confidence, corroborates CoreAudio mute approach
- [do-not-disturb-cli - GitHub](https://github.com/sindresorhus/do-not-disturb-cli) — MEDIUM confidence, corroborates the lack of a clean public API for DND/Focus toggling
- [MeetingBar - GitHub](https://github.com/leits/MeetingBar) — MEDIUM confidence, corroborates process/calendar-based call detection as the ecosystem norm, not a unified call-state API
- [Watching for file changes on macOS – alexwlchan](https://alexwlchan.net/2026/watch-files-on-macos/) — MEDIUM confidence, corroborates `DispatchSource` as the modern idiomatic approach over raw FSEvents
- [DispatchSource: Detecting changes in files and folders in Swift](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift) — MEDIUM confidence, implementation pattern reference

---
*Feature research for: macOS notch-overlay live-activities app, milestone v1.10 "Live Activities Suite"*
*Researched: 2026-07-23*
