# Project Research Summary

**Project:** Islet — macOS notch-overlay app
**Domain:** Native macOS system-utility / Live-Activities overlay (Swift 5, SwiftUI+AppKit)
**Milestone:** v1.10 "Live Activities Suite" — 9 new HUDs/activities + Settings-grid redesign
**Researched:** 2026-07-23
**Confidence:** MEDIUM-HIGH

## Executive Summary

v1.10 adds 9 heterogeneous Live Activities (Meeting-HUD, Download-Progress, Timer/Pomodoro, Quick Notes/Obsidian export, Quick Actions bar, Menübar-Overflow, Caps Lock HUD, Update-Activity restyle, Coding-Progress) plus a Settings-grid redesign to an already-mature, non-sandboxed notch app. This is not greenfield work: every recommendation traces directly to a pattern the codebase already proves out (`*Monitor` isolation, the `IslandResolver`/`TransientQueue` two-tier arbiter, `ActivitySettings`'s flat `@AppStorage` key convention, the HUD/wings transient-splash visual language). Zero new third-party dependencies are required — every feature is covered by a public Apple framework, an already-accepted private-API risk tier (CGS/SkyLight, matching the existing `CGSSpace.swift`), or a one-line shell-out to an Apple-shipped CLI.

The recommended approach is "foundation first, ascending risk after": ship the Settings-grid redesign before any new feature (it's fully derivable from the 9 *existing* activities and prevents another ad-hoc-Settings regression like the one v1.8 already had to fix), then sequence the 9 features from cheapest/most-certain (Caps Lock, Update restyle, Timer) to hardest/least-precedented (Meeting-HUD, Menübar-Overflow, Coding-Progress). Two features carry real detection uncertainty and must NOT be planned like the other seven: Meeting-HUD (no public API for "is a call active" — heuristic-based, proxy signals only) and Menübar-Overflow (must reposition other processes' `NSStatusItem`s via an undocumented technique, requiring its own Accessibility-permission flow with no precedent in this codebase). Both are explicitly flagged for a pre-planning research/spike phase, mirroring the project's own successful precedent from v1.6's Volume/Brightness OSD-suppression spike.

The dominant risk is not any single feature but the *aggregate* pressure 9 new activities put on the existing `IslandResolver`/`TransientQueue` arbiter: it was hand-tuned for ~6 cases and a 2-deep queue, and blindly inserting new cases "wherever feels right" risks silently reordering precedence for already-shipped activities (the exact WR-1/WR-2 class of defect this project already hit once). This must be resolved with one explicit, reviewed priority table before/alongside the Settings-Redesign phase, not decided piecemeal per feature phase. A second cross-cutting risk is the Settings-grid migration itself silently flipping an existing user's currently-ON toggle if new-vs-existing default logic gets inverted — mitigate with an explicit per-key checklist and an upgrade-simulating regression test, not just a fresh-install check.

## Key Findings

### Recommended Stack

No new SPM dependencies. Every one of the 9 features maps to a public Apple framework (`UserNotifications`, `FSEvents`/`DispatchSourceFileSystemObject`, CoreAudio `kAudioDevicePropertyMute`/`...IsRunningSomewhere`, `NSWorkspace`, `NSAppleScript`/System Events, `NSEvent` global monitors, `UNUserNotificationCenter`), a `Process` shell-out to an Apple-shipped CLI (`pmset displaysleepnow`, `CGSession -suspend`), or the same private CGS/SkyLight tier the project already accepts for `CGSSpace.swift` (Menübar-Overflow, verified directly against Ice's open-source implementation). Follow the existing `Monitor`-per-feature pattern for every new system-surface integration, isolating fragile/private surface exactly like `NowPlayingMonitor` does for MediaRemote.

**Core technologies:**
- CoreAudio `kAudioDevicePropertyMute` (input device) — system-wide mic mute; shared by Meeting-HUD and Quick Actions bar, identical technique to the existing volume-HUD call
- `DispatchSourceFileSystemObject` / `FSEventStreamCreate` — file/folder watching for Download-Progress and Coding-Progress; first FSEvents-family usage in the codebase, right-sized per case (single file vs. directory)
- Private CGS/SkyLight (`CGSMainConnectionID`, `CGSGetScreenRectForWindow`) + synthetic `CGEvent` drag — Menübar-Overflow's chevron mechanism, verified against Ice's actual source, same risk tier as existing `CGSSpace.swift`
- Claude Code hooks (`PostToolUse` matcher `TodoWrite`, `Stop`, `SessionStart/End`) — Coding-Progress data source, official/stable API surface
- `NSAppleScript` / System Events, `Process` shell-outs (`pmset`, `CGSession -suspend`) — Quick Actions bar's dark-mode/display-sleep/screen-lock actions

### Expected Features

**Must have (table stakes):**
- Meeting-HUD: call presence (Zoom/Teams native apps only, not Meet) + running timer + system-wide mute toggle
- Download-Progress: presence + completion signal in `~/Downloads` (not guaranteed exact %)
- Timer/Pomodoro: start/pause/reset, visible countdown, completion alert
- Quick Notes: reliable append-only capture to a user-chosen Obsidian vault file
- Quick Actions bar: ~8 reliable default actions (mic mute, display sleep, dark mode, screen lock, caffeinate, empty trash, launch app/URL; DND/Focus best-effort only)
- Menübar-Overflow: one chevron, click-to-toggle hide/show of other apps' icons
- Caps Lock HUD: on/off flash, event-driven
- Update-Activity: cosmetic reskin of existing Sparkle HUD
- Coding-Progress: todo completion fraction from Claude Code hooks, requires documented user setup step

**Should have (differentiators, in-scope stretch):**
- Quick Actions: drag-to-reorder configurable grid
- Download-Progress: click-through to Finder, multi-download stacking

**Defer (v2+):**
- Meeting-HUD true in-app mute reflection (no reliable technique exists)
- Google Meet browser-tab detection (needs a browser extension, out of scope)
- Menübar-Overflow always-hidden section, hover/scroll reveal, auto-rehide
- Coding-Progress multi-session switcher
- Full custom action-scripting for Quick Actions

### Architecture Approach

The codebase already has exactly two precedented resolver "tiers" that cover all 9 new features cleanly: **Tier A** (`ActiveTransient`/`TransientQueue` — discrete-arrival activities needing de-dup/forced-eviction, e.g. Caps Lock, Download-Progress, Meeting-HUD, Timer/Pomodoro) and **Tier B** (ambient, resolved directly in `resolve()`'s ambient branch, e.g. Coding-Progress — gets Charging/Device preemption for free). Three features (Quick Actions bar, Menübar-Overflow, Update-Activity restyle) sit entirely outside the resolver. One small, load-bearing generalization is required and must not be missed: `TransientQueue.preempt()`/`ActiveTransient.isPersistent` is currently hardcoded to a single `.focus` case and must generalize to "any persistent transient" the moment Timer/Pomodoro (the second persistent case) is added — attribute this work to whichever of Pomodoro/Meeting-HUD ships first.

**Major components:**
1. `IslandResolver.swift` (pure, Foundation-only) — the single ranking authority; gains 4 new Tier-A cases + 1 new Tier-B parameter + the `preempt()` generalization
2. New `*Monitor` files (`MeetingMonitor`, `DownloadMonitor`/`FileWatcher`, `CapsLockMonitor`, Coding-Progress file watcher) — one per fragile/system-integration seam, isolating risk exactly like `NowPlayingMonitor`
3. `ActivityCardSpec` static array + `ActivityCardPreview` enum — replaces ad-hoc Settings sections with a flat, non-plugin data model feeding the same `NotchPillView` render path used for live HUDs
4. Shared cross-feature helpers: one `MicMuteController` (Meeting-HUD + Quick Actions), one `FileWatcher` utility (Download-Progress + Coding-Progress)

### Critical Pitfalls

1. **Meeting-HUD call-detection heuristics silently break on Zoom/Teams UI updates** — no public API exists; isolate all app-specific string/window matching behind one `MeetingMonitor` file, treat as a dedicated spike with go/no-go gate before build, and explicitly separate "call detection" (hard, fragile) from "system mic mute" (tractable, CoreAudio).
2. **Menübar-Overflow forgets Accessibility permission and other apps' anti-hiding behavior** — read Ice's actual source for its exact mechanism rather than reinventing; test permission-denied (must degrade visibly, never silently), display-sleep/wake, and Dock-relaunch cycles explicitly before shipping.
3. **9 new competing signals crowd `IslandResolver`/`TransientQueue` without an explicit priority decision, silently reordering existing precedence** — produce one reviewed priority table for all new + existing activities before/alongside the Settings-Redesign phase; re-derive whether `maxDepth = 2` still holds with 6+ transient-shaped candidates.
4. **Settings-grid migration flips an existing user's currently-ON toggle, or a new v1.10 key wrongly inherits the "default true" majority pattern** — every new key defaults `false` explicitly (matching the `focusKey` precedent); regression-test against a pre-seeded (upgrade-simulating) UserDefaults domain, not just fresh install.
5. **FSEvents-based Download-Progress double-fires on browser temp-file/rename patterns** — this is genuinely new infrastructure (zero FSEvents precedent in the codebase today); match known temp-file suffixes (`.crdownload`/`.download`/`.part`), debounce, and correlate create+rename as one logical download.

## Implications for Roadmap

Based on combined research, the milestone brief's own proposed order holds up well against the architecture and pitfalls research, with two explicit refinements folded in.

### Phase 1: Settings-Redesign (foundation)
**Rationale:** The `ActivityCardSpec` array abstraction is already fully derivable from the 9 *existing* activities alone — no new feature needs to be built first to "discover" the shape. Doing this first avoids repeating the exact ad-hoc-Settings-growth mistake v1.8 already had to fix.
**Delivers:** Flat `ActivityCardSpec` array + `ActivityCardPreview` enum replacing `SettingsView.swift`'s grid, ported against the ~9 existing activities only; the explicit reviewed priority table for all future new activities' resolver precedence.
**Addresses:** No FEATURES.md item directly — cross-cutting infrastructure.
**Avoids:** Pitfall 3 (resolver crowding without a priority decision), Pitfall 4 (silent toggle-default regression on upgrade).

### Phase 2: Caps Lock HUD + Update-Activity restyle
**Rationale:** Cheapest possible pairing — Caps Lock is the simplest new Monitor (direct `NSEvent.addGlobalMonitorForEvents` precedent already in the codebase), Update-restyle is pure styling with zero new subsystem. Validates the new "one Settings card per phase" habit before harder features land.
**Delivers:** Event-driven Caps Lock on/off HUD (Tier A, self-elapsing/OSD-shaped); reskinned Sparkle update HUD.
**Uses:** `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` (event-driven, not polling — Pitfall 9).
**Implements:** New Tier-A `ActiveTransient` case; no resolver change for Update restyle (existing case, view swap only).

### Phase 3: Download-Progress
**Rationale:** First genuinely new system-integration seam (FSEvents-style watching, zero prior precedent) but self-elapsing Tier-A with no persistence-generalization concern — a good place to prove the `FileWatcher` pattern once before Coding-Progress reuses it.
**Delivers:** Live progress/activity signal for `~/Downloads`, completion detection via temp-file/rename correlation.
**Addresses:** FEATURES.md Download-Progress (presence + completion, not guaranteed exact %).
**Avoids:** Pitfall 5 (double-fire on browser temp-file patterns) — needs its own short spike even though not explicitly flagged in PROJECT.md.

### Phase 4: Timer/Pomodoro
**Rationale:** No Monitor at all (pure app-owned state) but this is the phase that must carry the `TransientQueue.preempt()`/`ActiveTransient.isPersistent` generalization, since Pomodoro is the second persistent-transient case and the simpler of the two remaining ones to validate the generalized path against (no detection uncertainty layered on top).
**Delivers:** Countdown/Pomodoro HUD reusing the existing HUD/wings transient-splash + Now Playing progress-bar visual language almost entirely.
**Implements:** The resolver generalization flagged in Architecture research (load-bearing, not optional).

### Phase 5: Meeting-HUD
**Rationale:** Needs its own dedicated research/spike (call + mic-status detection) before planning, per the same discipline as v1.6's OSD-suppression spike; reuses the now-generalized preempt path from Phase 4.
**Delivers:** Zoom/Teams-only call presence + timer + system-wide mute toggle (first interactive control inside a collapsed-only HUD — a second, independent risk axis from the detection mechanism).
**Addresses:** FEATURES.md Meeting-HUD table stakes (native apps only, no Google Meet, system-wide mute only).
**Avoids:** Pitfall 1 (fragile window-title/process heuristics) — isolate in one `MeetingMonitor` file.

### Phase 6: Quick Notes + Obsidian export
**Rationale:** Reuses the Clipboard History UI/persistence shell heavily, but must resolve a real design conflict first: `SelectedView` today has exactly 4 cases and Phase 52's top-edge switcher hardcodes exactly 4 slot keys — adding a 5th tab needs a decision before coding starts.
**Delivers:** In-notch expanded-view capture UI + atomic append-with-timestamp to a user-chosen `.md` file.
**Avoids:** Pitfall 7 (non-atomic append corrupting real Obsidian vault content) — use `FileHandle.seekToEndOfFile()`, never read-modify-write-whole-file.

### Phase 7: Quick Actions bar
**Rationale:** Static row, zero resolver coupling, lowest remaining technical risk; sequenced after Quick Notes mainly because final button selection needs a product decision, not a dependency.
**Delivers:** Configurable ~8-action grid (mic mute, display sleep, dark mode, screen lock, caffeinate, empty trash, launch app/URL, DND best-effort).
**Uses:** Shared `MicMuteController` with Meeting-HUD (Pitfall 8 — do not build the CoreAudio mute helper twice).
**Avoids:** Pitfall 8 (assuming one AppleScript/Automation mechanism covers all 4+ actions — each has a genuinely different first-use TCC path).

### Phase 8: Menübar-Overflow
**Rationale:** Fully isolated from `NotchWindowController`/`IslandResolver` — could in principle be built in parallel with anything above — but the `NSStatusItem` reordering mechanism deserves its own feasibility spike before committing, given it's the highest-novelty feature in the milestone and requires a first-of-kind Accessibility permission flow.
**Delivers:** One chevron, click-to-toggle hide/show of other apps' menu-bar icons (MVP subset of Ice's feature set only).
**Avoids:** Pitfall 2 (undocumented technique + forgotten Accessibility permission + other apps fighting back) — read Ice's actual source before planning, not a general description of it.

### Phase 9: Coding-Progress
**Rationale:** Reuses the FSEvents/`DispatchSourceFileSystemObject` pattern already proven once in Phase 3, so building it last among the file-watching features means the watching mechanism is de-risked before this phase's own hook-contract research.
**Delivers:** Ambient-tier (Tier B) todo-completion-fraction readout fed by a Claude Code hook script the user installs once.
**Addresses:** FEATURES.md Coding-Progress (single most-recent session, documented external setup step required).
**Avoids:** Pitfall 6 (stale/orphaned status file on unclean exit) — needs an explicit `lastUpdated` field + staleness timeout, decided in this phase's own flagged research step.

### Phase Ordering Rationale

- Foundation-first (Settings-Redesign) avoids retrofitting an ad-hoc Settings UI onto the first 1-2 features, a mistake this project already paid for once in v1.8.
- Ascending technical risk (Caps Lock/Update → Download-Progress → Timer → Meeting-HUD → Quick Notes → Quick Actions → Menübar-Overflow → Coding-Progress) means every hard-detection feature (Meeting-HUD, Menübar-Overflow) gets its dedicated spike/go-no-go gate after cheaper infrastructure (FileWatcher, the resolver generalization, shared MicMuteController) already exists and is proven.
- Shared-infrastructure dependencies drive two orderings directly: Download-Progress before Coding-Progress (both need `FileWatcher`, prove it once), and Timer/Pomodoro before Meeting-HUD (both need the `preempt()`/`isPersistent` generalization, validate it on the simpler case first).
- This ordering directly avoids Pitfall 3 (resolver crowding) by resolving the priority table up front, and Pitfall 4 (Settings migration regression) by locking the default-OFF convention in the foundation phase before any new key is added.

### Research Flags

Phases likely needing deeper research/spike during planning:
- **Phase 5 (Meeting-HUD):** no public API for call-state detection; heuristic-only, needs on-device validation against real Zoom/Teams before build (already flagged in PROJECT.md).
- **Phase 8 (Menübar-Overflow):** undocumented `NSStatusItem` repositioning technique + first-of-kind Accessibility permission flow; needs a source-level read of Ice before planning.
- **Phase 9 (Coding-Progress):** hook-event choice and file-format/staleness-timeout contract need to be settled before build (already flagged in PROJECT.md).
- **Phase 3 (Download-Progress):** not explicitly flagged in PROJECT.md but PITFALLS.md recommends a short spike anyway — first FSEvents usage in the codebase, temp-file/rename correlation has real edge cases.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Settings-Redesign):** shape fully derivable from existing code, no unknowns.
- **Phase 2 (Caps Lock + Update restyle):** direct precedent already in the codebase for both.
- **Phase 4 (Timer/Pomodoro):** pure app state, near-total reuse of existing HUD chrome.
- **Phase 6 (Quick Notes):** well-understood file-append mechanics; only the 4-slot switcher conflict needs a design decision, not research.
- **Phase 7 (Quick Actions bar):** each action's mechanism is individually well-documented; the work is per-action TCC-prompt testing, not open research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Ice's mechanism and Claude Code hooks verified against primary sources (actual source code / official docs); Meeting-HUD detection and `CGSession -suspend` are inherently best-effort/community-pattern, correctly flagged as such |
| Features | MEDIUM-HIGH | Grounded in official Claude Code docs, Ice's README/community writeups, and Droppy's own marketing copy confirming Coding-Progress and Caps Lock as real shipped reference-app features; Meeting-HUD and Menübar-Overflow carry genuine implementation uncertainty, explicitly flagged for phase-specific research |
| Architecture | HIGH | Based on direct reading of the current codebase (`IslandResolver.swift`, `NotchWindowController.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `AppDelegate.swift`, representative Monitors) — not inferred, verified against real code |
| Pitfalls | MEDIUM-HIGH | Grounded in direct reads of the same core files plus project history (`PROJECT.md`'s record of prior real on-device bugs); private-API claims about Ice's exact mechanism are LOW-MEDIUM until re-verified against Ice's live source during the Menübar-Overflow spike |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Meeting-HUD call detection:** no confirmed working technique exists yet — the recommended heuristic (process-running + mic-active) is a documented community pattern, not a verified Islet-specific spike result. Must be validated on real hardware during Phase 5's dedicated research step before any build work.
- **Menübar-Overflow's exact private mechanism:** Ice's precise technique is inferred from its public source files (`Bridging.swift`, `MenuBarItemManager.swift`) but not independently re-verified live during this research pass; re-confirm on-device (including Accessibility-permission-denied and sleep/wake/Dock-relaunch behavior) before committing to an implementation approach in Phase 8.
- **`SelectedView`/top-edge-switcher 4-slot conflict (Quick Notes):** genuinely unresolved design question, not a technical unknown — must be decided at Phase 6's planning step (grow the switcher's slot model vs. reach Quick Notes some other way).
- **`TransientQueue.maxDepth = 2`:** unexamined against 6+ new transient-shaped candidates; re-derive whether the bound still holds as part of Phase 1's priority-table work, rather than leaving it implicit.
- **Google Meet support:** deliberately out of scope for v1.10 (no reliable native signal without a browser extension) — confirm this exclusion is explicitly documented in REQUIREMENTS.md so it isn't silently expected later.

## Sources

### Primary (HIGH confidence)
- Direct reads of the current Islet codebase: `IslandResolver.swift`, `NotchWindowController.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `AppDelegate.swift`, `FocusModeMonitor.swift`, `ClipboardMonitor.swift`, `Islet.entitlements`, `project.pbxproj`
- `.planning/PROJECT.md` — milestone goal, requirement history, per-phase shipped-scope notes v1.0–v1.9
- `jordanbaird/Ice` GitHub repository (`Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift`, `Ice/Bridging/Bridging.swift`) — MIT license, fetched directly
- `code.claude.com/docs/en/hooks` and `code.claude.com/docs/en/agent-sdk/todo-tracking` — official Anthropic documentation, current as of research date

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread confirming `kAudioDevicePropertyDeviceIsRunningSomewhere` reliability (built-in/wired mics only, not Bluetooth)
- `gist.github.com/henrik/38a7a76a217552d8f4fc672535fe91c5` (Zoom mute-toggle AppleScript proof-of-concept)
- OS X Daily / community confirmations that `CGSession -suspend` still works through Sonoma/Sequoia
- Podfeet Podcasts and GitHub issue discussions corroborating Ice's chevron/Cmd-drag UX
- `getdroppy.app` marketing copy confirming Coding-Progress and Caps Lock as real shipped reference-app features
- `MeetingBar` (leits/MeetingBar) and `do-not-disturb-cli` (sindresorhus) corroborating process/audio-based detection as the ecosystem norm for both Meeting-HUD and DND/Focus toggling

### Tertiary (LOW confidence)
- General macOS platform knowledge on FSEvents temp-file/rename patterns and Apple Events per-target-app TCC authorization — training-data-based, not independently re-verified this pass; flagged for spike-time verification
- Ice's exact underlying private-API mechanism for Menübar-Overflow — inferred from public source, not independently re-verified live; flagged for the Menübar-Overflow phase's own research step

---
*Research completed: 2026-07-23*
*Ready for roadmap: yes*
