# Notch — Dynamic Island for Mac

> Working title. Final product name is TBD (see Key Decisions).

## What This Is

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities. **Shipped in v1.0/v1.0.1:** now-playing media controls with working transport and a progress bar, a charging activity, a Bluetooth/AirPods device-connected activity, and a minimal settings window with three activity toggles + accent theming — all arbitrated by a single priority resolver so activities coexist gracefully. **Shipped in v1.1:** Islet is now a real, sellable product — a tamper-resistant 3-day free trial with hard lockout, a one-time €7.99 purchase via Polar.sh (live checkout, online validation, offline-capable Keychain cache), and a genuinely Developer-ID-notarized release pipeline. **Also shipped (ahead of formal milestone scope):** a weather + calendar + date glance in the expanded idle view. **Shipped in v1.2:** the Now Playing glance no longer appears at launch for an already-paused track (only a real Play does it), and genuine song changes show a brief fading title+artist toast with its own Settings toggle. **Shipped in v1.3:** a session-only drag-and-drop file shelf — files can be staged in a horizontally-scrolling strip below the expanded island and dragged back out to Finder/other apps — though dragging files *in* by dropping them onto the collapsed island is not yet working (blocked, carried into v1.4). **Shipped in v1.4:** a rebuilt panel architecture that resolved the drag-in blocker, a first-launch onboarding flow, a frosted/glossy visual redesign with per-element accent theming and a sidebar-based Settings window, and a 4-view switcher pill (Home/Tray/Calendar/Weather) below the expanded island — Home now shows Now Playing controls whenever something is playing (falling back to the idle glance otherwise), Tray is a dedicated full-files view, Calendar is a month-grid + day-list view with quick-add, and Weather shows enlarged current conditions. System HUD replacement and a countdown timer remain planned for a future milestone, not yet built.

It is for Mac users who love the iPhone Dynamic Island and want it on their MacBook without paying for the existing closed-source apps (Alcove, DynamicLake). Built by a first-time programmer with the goal of a polished, possibly sellable product down the line.

## Core Value

The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island. If everything else is cut, that core island experience must work. Still the right priority after v1.1 — the paywall and notarization work protects and monetizes the core experience without changing it.

## Current State

**v1.10 Live Activities Suite shipped 2026-07-30** (Phases 59-63, 65, see `.planning/milestones/v1.10-ROADMAP.md`). 16 of 27 v1.10 requirements shipped and on-device verified: the Droppy-style Settings grid replacing ad-hoc Activities rows (Phase 59), a Caps Lock HUD + restyled Update HUD (Phase 60), a live Download-Progress indicator via FSEvents (Phase 61), a Timer/Pomodoro HUD that generalized `TransientQueue`'s persistent-transient concept (Phase 62), a Meeting-HUD with real Zoom/Teams call detection + system mic mute (Phase 63, verified retroactively at milestone close), and a configurable 8-slot Quick Actions bar (Phase 65). **Known gaps, carried forward not descoped:** Phase 64 (Quick Notes) has 3 unfixed major UAT bugs; Phase 66 (Menübar-Overflow) is paused after 3 consecutive on-device NO-GOs; Phase 67 (Coding-Progress) was never started. A stale-requirements bug was also caught and fixed at close (MENUBAR-01/02/03 had been incorrectly marked Complete).

**v1.9 Clipboard History shipped 2026-07-23** (Phases 55-58, see `.planning/milestones/v1.9-ROADMAP.md`). 7 of 7 v1.9 requirements (CLIP-01/02/03/04/05, PRIV-01/02) shipped and on-device verified. Islet's menu-bar dropdown now has a "Clipboard History" flyout submenu (revised live during Phase 58's on-device UAT from the originally-planned inline list, D-15 REVISED) listing recent text/image copies most-recent-first, click-to-restore with no auto-paste, Cmd+0-9 instant restore via a hybrid keyDown monitor (works even before the submenu is opened), and a destructive-confirm "Delete All History" that really deletes on disk. History persists AES-GCM-encrypted at rest (Phase 56) and the underlying `ClipboardMonitor` correctly excludes password-manager concealed-type copies (Phase 57). Two real on-device-only bugs (invisible menu rows from a missing `NSHostingView` frame, stuck SwiftUI hover state) were found and fixed during Phase 58 UAT — neither was catchable by the build or unit tests.

**v1.8 Settings Redesign & Island Navigation shipped 2026-07-21** (Phases 51-53, see `.planning/milestones/v1.8-ROADMAP.md`). 6 of 6 v1.8 requirements shipped and on-device verified. Settings is now a scrollable 7-section sidebar (Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About), fixing the Weather/Diagnostics scroll-cutoff bug. Users can opt into a compact top-edge switcher layout (4 icons flanking the camera cutout, user-configurable left/right placement) as an alternative to the default below-island pill. Hovering the idle island after a track has played this session now previews it (album art + a static play glyph, superseded from an originally-planned bouncing-equalizer visual after on-device UAT found animated bars misleading when nothing was actually playing) and clicking it resumes playback via the existing transport call, with clear feedback when resume genuinely isn't possible.

**v1.6 Liquid Glass & System HUD Suite shipped 2026-07-19** (Phases 35-42, see `.planning/milestones/v1.6-ROADMAP.md`). 11 of 12 v1.6 requirements shipped and on-device verified — HUD-07 (Drop-session summary chip) was abandoned after on-device UAT found its Tray-close trigger essentially never fires under normal use, and dropped from scope. Islet now has a shader-based "Liquid Glass" background material (with a native macOS 26 `.glassEffect()` fast path), five new/restyled collapsed-state system HUDs (Bluetooth/Charging restyles, Focus Mode, Volume/Brightness with genuine native-OSD suppression, Update-available via real Sparkle 2 integration, Calendar Countdown), a redesigned equalizer + onboarding signature heading, and a new dual-activity display concept (a secondary bubble alongside the main pill when two top-priority activities are live at once — e.g. Calendar Countdown + Now Playing). See Requirements → Validated below for the full per-phase breakdown.

**v1.3 Notch Shelf shipped 2026-07-11 with a known gap** (Phases 19-21, see `.planning/milestones/v1.3-ROADMAP.md`). 7 of 9 v1.3 requirements shipped and on-device verified: the shelf data model, the full shelf view (icons, per-item/delete-all trash, click-to-open, correct gating), and drag-out to Finder/other apps. **SHELF-01/02 (drag-in) did not ship** — Phase 22 spiked successfully (AppKit drag delivery does reach a click-through `NSPanel`) but then failed on-device twice for an unidentified reason (`draggingEntered` never fired despite a working spike using the same technique). Rather than keep debugging incrementally, the user chose to redesign the underlying `NotchPanel`/`NotchWindowController` architecture — this becomes the anchor of v1.4, alongside new scope inspired by a competitor app ("Droppy," found on Reddit): a first-launch onboarding flow, a visual/material redesign, and a full-screen calendar view. See `.planning/research/inspiration/notes.md` for the reference material. SHELF-01/02 carry forward as requirements into v1.4.

**v1.2 Now Playing Polish shipped 2026-07-09** (Phases 17-18, see `.planning/milestones/v1.2-ROADMAP.md`). All 3 v1.2 requirements (NOW-04, NOW-05, NOW-06) shipped and on-device verified. The Now Playing glance no longer fires at launch for a merely-paused track, and genuine song changes surface a brief title+artist toast (independent 2s dismiss, its own Settings toggle) — both refined through on-device iteration.

**v1.1 Trial & Paid Release shipped 2026-07-08** (Phases 10-13, see `.planning/milestones/v1.1-ROADMAP.md`). All 7 v1.1 requirements (TRIAL-01/02/03, LIC-01/02/03, DIST-01) shipped and verified on-device. Islet is now a genuinely distributable, sellable product: real Developer-ID signing/notarization, a Keychain-backed tamper-resistant trial with hard lockout, and live Polar.sh purchase + offline-capable validation.

**Also shipped ahead of formal milestone scope (Phase 14, weather/calendar/date; Phase 15/16, architecture refactor):** the `expandedIdle` glance shows live weather (WeatherKit), the next calendar event (EventKit), and the date alongside the time readout, in a 3-column layout that degrades silently on permission denial — still needs its own requirement IDs (WEATHER-01, CAL-01, OUTFIT-01) captured whenever a milestone formally covers it. Phase 15/16 were pure architecture cleanup (DI seams, DeviceCoordinator extraction), zero product-behavior change.

## Next Milestone Goals

v1.11 (Droppy-Inspired Polish Round 2) started 2026-07-30 — see "Milestone In Progress" below. Still open for a future milestone after v1.11 closes: v1.10's own 3 carried-forward gaps (Phase 64 Quick Notes gap-closure, Phase 66 Menübar-Overflow revisit, Phase 67 Coding-Progress), v1.7 (Interaction & Calendar Polish, paused mid-milestone — Phase 49 Favorite/Like spike aborted after weak on-device results, Phase 50 undecided), Phase 68/69 (App Switcher, Claude Session Usage — both still `[To be planned]`), and 2 remaining planted seeds from the 2026-07-26 session (folder-preview rank 1, cable-info rank 2 — see `.planning/seeds/`). Other standing candidates: gesture-based swipe navigation, Animation Speed presets (ARCH-P1), alternate app icon variants (still Out of Scope below until picked up).

<details>
<summary>v1.10 Live Activities Suite — original scope (shipped 2026-07-30, known gaps)</summary>

**Goal:** Add a suite of new Live Activities/HUDs inspired by Droppy and Ice, plus a Droppy-style Settings grid overview to manage them all — most new activities default OFF rather than opinionated-on.

**Outcome:** Shipped 2026-07-30 with 6/9 phases (59-63, 65) — 16/27 requirements. Phase 63 (Meeting-HUD) was formally goal-backward verified at the close itself (never run at phase-execution time); its 3 post-UAT code-review fixes were accepted as code-verified without a live re-test. Phase 64 (Quick Notes), Phase 66 (Menübar-Overflow, paused after 3 on-device NO-GOs), and Phase 67 (Coding-Progress, never started) did **not** ship — carried forward as Active requirements, not descoped. A pre-existing REQUIREMENTS.md staleness bug was also caught and fixed at close: MENUBAR-01/02/03 had been marked Complete despite Phase 66 never actually working. See Requirements → Validated above for the shipped-phase breakdown and `.planning/milestones/v1.10-ROADMAP.md`/`.planning/milestones/v1.10-REQUIREMENTS.md` for the full archive.

Phase 70 (File Tray Convert Button — a queued backlog idea, not part of v1.10's own Phase 59-67 scope) shipped the same day (2026-07-30), on-device verified after 5 UAT bugs plus 1 code-review fix — a previous session incorrectly treated finishing Phase 70 as completing v1.10; corrected during this milestone's actual close-out.

**Target features:**
- **Settings-Redesign (foundation)** — Droppy-style grid overview of all Live Activities (mini pill preview + title + description + toggle), built generically for existing AND new activities. New activities default OFF.
- **Caps Lock HUD** — ON/OFF indicator, same collapsed-HUD pattern as Bluetooth/Charging.
- **Update-Activity restyle** — the existing Sparkle update HUD reskinned to the Droppy look.
- **Download-Progress** — watches the Downloads folder (FSEvents), shows a progress bar in the notch.
- **Timer/Pomodoro** — countdown/focus session startable from the notch, live in the collapsed pill.
- **Meeting-HUD** — detects an active Zoom/Meet/Teams call, shows a call timer + mute toggle directly in the notch. Needs a short research/spike step (reliable call + mic-status detection), similar in kind to v1.6's Volume/Brightness OSD suppression research.
- **Quick Notes + Obsidian export** — quick text capture in the notch (parallel to Clipboard History but for typed notes); simple append-with-timestamp into a fixed .md file in a user-chosen Obsidian vault folder, no vault read access needed.
- **Quick Actions bar** — configurable buttons in the notch (e.g. mic mute, display sleep, dark mode, screen lock — final selection at phase-planning time).
- **Menübar-Overflow (Ice-style MVP)** — a chevron icon in the menu bar reveals/hides a drag-in group of overflow menu-bar icons. Icons stay in the menu bar itself (do NOT move into the notch). One hide tier only — no "always-hidden"/hotkey tier, no menu-bar theming, no hotkeys (unlike full Ice).
- **Coding-Progress** — shows live progress of a running Claude Code session in the notch. Mechanism: a Claude Code hook script writes status to a local file that Islet watches. Display combines todo-list progress (X of Y done) when Claude is running a todo list, falling back to the current status text otherwise. Claude Code only (not ChatGPT), session-local to this Mac. Needs a short research step (hook-event choice, file format/IPC).

**Key context:**
- Reference apps for this milestone: **Droppy** (HUD settings grid, Update-Activity look, Caps Lock indicator) and **Ice** (open-source menu-bar-icon-hiding tool, MIT-licensed — Menübar-Overflow reimplements its "hide behind a chevron" mechanic as an MVP, not its full feature set).
- Proposed phase order is foundation-first, then ascending effort: Settings-Redesign → Caps Lock + Update restyle → Download-Progress → Timer/Pomodoro → Meeting-HUD → Quick Notes/Obsidian → Quick Actions bar → Menübar-Overflow → Coding-Progress. Not locked — confirmed loosely with the user during brainstorming, final order set at roadmap time.
- All 9 features were scoped via a `superpowers:brainstorming` session (not `/gsd-discuss-milestone`) — mechanism/depth for the ambiguous items (Coding-Progress data source, Obsidian export depth, Menübar-Overflow scope) was already clarified with the user before this milestone was created; no need to re-ask those at requirements time unless something doesn't add up.

<details>
<summary>v1.5 Home Focus & Widget Redesign — original scope (shipped 2026-07-28)</summary>

**Goal:** Declutter Home to music-only, consolidate all file-drop behavior into Tray (with a Droppy-style Drop/AirDrop/Mail destination choice), redesign Weather as an iOS-widget-style card, widen/enlarge the Tray file layout, and give the expanded-state notch silhouette an outward-flaring top edge.

**Outcome:** 6/6 phases shipped — Phase 29 (SHAPE-01, NotchShape flare), Phase 30 (HOME-01/02/03, Home music-only), Phase 31 (TRAY-01, shelf consolidation to Tray-only), Phase 32 (TRAY-05, Tray Widening) shipped 2026-07-14; Phase 33 (WEATHER-01/02, Weather widget redesign) and Phase 34 (TRAY-02/03/04, Quick Action Destination Picker) shipped 2026-07-15. All 6 phases already had their own on-device UAT checkpoints completed and approved at the time — the milestone's formal closing ceremony (MILESTONES.md entry, git tag) was simply never run until 2026-07-28, over two weeks after the actual work was done; PROJECT.md's own status line had gone stale in the meantime, incorrectly claiming Phase 33's UAT was still pending. See Requirements → Validated above for the full per-phase breakdown and `.planning/MILESTONES.md` for the archived summary.

**Target features:**
- Home shows ONLY Now Playing — live controls while something plays, cover+title (no live controls) for the last-played track while paused/stopped; the time/weather/calendar glance is fully removed from Home (Weather and Calendar already have their own switcher tabs).
- File shelf/Tray becomes the sole home for file drops — the additive shelf-strip-reveal on other tabs (Home/Calendar/Weather) is removed. Dropping a file from any tab opens a Droppy-style Quick Action picker with destination choices: Drop (stage into Tray, existing behavior), AirDrop, Mail — reference: Droppy's "Quick Action Layout" screenshot.
- Tray view widened with larger file icons so more files are visible side-by-side, matching Droppy's file-forward layout.
- Weather redesigned as an iOS-widget-style card (location, condition icon, current temp, H/L) — a compact widget is the default; a Settings toggle switches to an extended widget adding a multi-day forecast strip (requires a new WeatherKit forecast call, previously deferred in Phase 28 — now explicitly requested). Reference screenshot captured showing target layout (Local / 16° Cloudy H:24 L:15 / 6-day forecast row).
- NotchShape gains an outward flare transition into the top screen edge, applied ONLY to the expanded state — the idle/collapsed pill silhouette is explicitly unchanged (stays flush/straight into the edge as today).

See `.planning/research/inspiration/notes.md` for the Droppy reference material (additional Quick-Action and widget reference screenshots captured during v1.5 discussion — see discussion log once written).

<details>
<summary>v1.6 Liquid Glass & System HUD Suite — original scope (shipped 2026-07-19)</summary>

**Goal:** Give Islet an edgier "Liquid Glass" material look and a suite of new Droppy-style collapsed-state system HUDs, plus a new dual-activity display concept for when two top-priority activities are live at once.

**Target features:**
- **Liquid Glass material** — glossier, blurred/frosted (not glass-clear) background material replacing the current gradient material, across expanded + collapsed island. User supplies reference implementation code during the relevant phase.
- **Music equalizer bars redesign** — new visual design for the Now Playing bars. User supplies reference implementation code during the relevant phase.
- **Onboarding signature heading** — the first onboarding page's "Welcome to Islet" text is replaced by a static rainbow-gradient signature-style script heading (originally a live reveal animation, descoped per D-14 — see Phase 36 below); scoped to that one page only, the app's regular font is untouched.
- **New collapsed-state system HUDs (Droppy-style):**
  - Volume HUD — replaces (suppresses) the native macOS volume OSD
  - Brightness HUD — replaces (suppresses) the native macOS brightness OSD
  - Focus Mode HUD — shows when the user toggles Focus/Do Not Disturb
  - Update-available HUD — paired with a real Sparkle auto-update integration (net-new to the project)
  - Bluetooth/AirPods HUD — restyle of the existing Device-Connected activity in the Droppy look
  - Charging HUD — restyle of the existing Charging activity in the Droppy look
  - Drop-session summary chip — after closing the Shelf/Tray following a drop session, briefly shows "N files saved"
  - Calendar countdown HUD — starting 1 hour before a calendar event, the collapsed pill shows a live minutes-countdown (calendar icon left, event time right)
- **Dual-activity display (new resolver concept)** — when two top-priority activities are live simultaneously (e.g. calendar countdown + now playing), the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning; generalizes beyond just Calendar+Music to any two competing top-priority activities. Extends today's single-winner `IslandResolver`.

**Key context:**
- Volume/Brightness OSD suppression and Focus Mode detection are technical unknowns similar in kind to the MediaRemote precedent (undocumented/private-API territory) — good candidates for a research phase before planning.
- User will supply custom reference code for the Liquid Glass material and the equalizer bars redesign during their respective phases.

**Outcome:** 11/12 requirements shipped (HUD-07 dropped — Phase 37 abandoned after on-device UAT found its Tray-close trigger essentially never fires in normal use). Volume/Brightness OSD suppression, initially found unreliable in Phase 39's spike, was later proven working via a gap-closure plan using `.cghidEventTap`. See Requirements → Validated above for the full per-phase breakdown and `.planning/milestones/v1.6-ROADMAP.md` for the archived roadmap.

</details>

</details>

</details>

## Milestone In Progress (Parallel): v1.7 (Interaction & Calendar Polish)

**Goal:** Fix a set of real-usage interaction and layout bugs surfaced since v1.4-v1.6 shipped — no new features, pure polish. Started 2026-07-19 while v1.4 and v1.5 both remain open in parallel (explicit user decision).

**Status:** Paused, not shipped. 6/8 phases complete (43-48, including Phase 48 Audio Output Switcher — UI Wiring, on-device approved). Phase 46 (Calendar Quick-Add Improvements) actually shipped all 3 requirements (CALVIEW-05/06/07) on-device-confirmed 2026-07-19 — REQUIREMENTS.md had gone stale showing 06/07 as still Pending, corrected 2026-07-28. Phase 49 (Favorite/Like Spike) was paused by the user after Plans 01-02 showed weak results (SC#1 like-effect-not-observed; SC#2 Apple Music `loved` broken via AppleScript in all 4 states tested) — reconfirmed 2026-07-28: staying paused, the user declined to run the remaining Spotify PKCE checkpoint (Plan 03's script was already built, just never verified on-device). No revisit trigger, matching Phase 66's precedent — not a formal drop, just not being pursued right now. Phase 50 (Favorite/Like Implementation) stays blocked on Phase 49 as a direct consequence.

**Target features:**
- **Drag-detection hardening** — the `DragApproachDetector`/Quick Action picker auto-expand currently false-triggers on an ordinary click on the island, not just a real external file drag approaching it; must only fire on a genuine inbound file drag. The Quick Action picker (the during-drag view) should render at the exact same width as the real Tray view.
- **Tray/Island width** — the island widens so all file icons in the Tray fit without visual squeeze; per-file icon/button sizes stay unchanged.
- **View-switcher transition fix** — switching tabs (Home/Tray/Calendar/Weather) currently makes the island briefly disappear and rebuild instead of morphing fluidly straight to the new content's size; includes the glitch where a large→small transition (Calendar → Tray) briefly renders behind the switcher pill buttons.
- **Calendar quick-add improvements:**
  - A date+time picker: Events get a start/end time range, Reminders get a single time.
  - Default date = the calendar day the user tapped. Default time = the next full hour if that day is today, otherwise 00:00.
  - The add-event button moves from the right edge (currently visually clipped) to the left, next to the day-list divider.
  - More padding/margin around calendar event rows; the island grows a few pt wider and gains extra height to accommodate.

**Key context:**
- All 4 items are regressions/rough edges in already-shipped features (Phase 24/34 drag-in + Quick Action picker, Phase 28 calendar view + Phase 32 Tray widening, Phase 28's view switcher) — no new domain research needed, scoped directly from user report.
- The view-switcher "disappear and rebuild" symptom suggests the tab-switch is doing a hard content swap rather than a continuous `matchedGeometryEffect` morph — worth investigating the switcher's presentation-state wiring at plan time.

<details>
<summary>v1.8 Settings Redesign & Island Navigation — original scope (shipped 2026-07-21)</summary>

**Goal:** Fix the crowded, non-scrollable Settings window and add two new interaction options for how the app is navigated — a compact top-edge switcher placement and a hover-to-resume affordance on the idle island. Started 2026-07-21 while v1.4, v1.5, and v1.7 all remain open in parallel (explicit user decision).

**Target features:**
- **Settings scroll fix + reorganization** — the Settings window's General tab currently overflows with no way to scroll to the cut-off content (Weather/Diagnostics sections below the fold are unreachable); fix the scrolling bug and split General's crowded content into new dedicated sidebar sections (e.g. Activities, Appearance, Fullscreen, Weather, Diagnostics) instead of one long list.
- **Configurable switcher placement** — in addition to today's switcher-pill-below-the-expanded-island (the default), add an alternate compact layout: 4 small icons at the very top edge of the expanded island, 2 to the left of the camera/notch and 2 to the right. Default split is Home+Tray left, Calendar+Weather right, but which icon goes on which side is user-configurable in Settings, not fixed.
- **Hover-to-resume on the idle island** — hovering the collapsed island when nothing is currently playing expands it the same way it does for an active Now Playing session (album art left, equalizer bars right), showing the last track played this app session; clicking it resumes that track if still possible. Reuses the hover-reveals-affordance / tap-toggles-playback interaction pattern already shipped for the Phase 42 dual-activity secondary bubble.

**Key context:**
- All 3 items are UI/UX polish and new interaction affordances on top of already-shipped subsystems (Settings sidebar from Phase 27, the view switcher from Phase 28/45, the secondary-bubble pattern from Phase 42) — no new external API or domain research expected.
- "Last played this session" is scoped to not persist across app relaunch (explicit user decision) — nothing shown if nothing has played yet since Islet launched.
- Resuming a past track depends on what MediaRemote/the adapter actually supports outside an active session — worth a quick technical check during phase planning rather than assumed.

**Outcome:** 6/6 requirements shipped. The hover-preview's visual (RESUME-01) was superseded mid-UAT (D-02): the originally-planned bouncing equalizer bars were replaced with a static play glyph after on-device testing found animated bars misleading while nothing was playing. See Requirements → Validated below for the full per-phase breakdown and `.planning/milestones/v1.8-ROADMAP.md` for the archived roadmap.

</details>

<details>
<summary>v1.9 Clipboard History — original scope (shipped 2026-07-23)</summary>

**Goal:** Islet replaces the user's third-party CopyClip tool — clicking the menu-bar status icon shows a clipboard history of recent text and image copies, alongside the existing Settings/Check for Updates/Quit entries.

**Target features:**
- Menu-bar status-item dropdown gains a clipboard history section listing the last ~20-30 copied items (text and images), oldest entries automatically evicted once the cap is reached.
- Clicking an entry copies it back onto the system pasteboard (no auto-paste into the frontmost app — matches CopyClip's own behavior, confirmed by the user against a CopyClip screenshot).
- History persists across app relaunch and machine reboot (unlike the existing session-only file Shelf — an explicit, deliberate difference).
- Copies marked sensitive by the source app (the `org.nspasteboard.ConcealedType`/`TransientType` convention password managers use) are never captured.
- A "Delete All History" action clears the list from the menu.
- No search/filter UI in v1.9 — explicitly deferred.

**Key context:**
- Reference: user's installed CopyClip app (screenshot captured during milestone discussion) — status-icon dropdown listing recent clips by preview text, `⌘0`-`⌘9` quick-select, "Delete All History" and "Preferences…" entries below the list.
- This is additive to the existing menu-bar status item (Settings…/Check for Updates/Quit from Phase 0/40) — explicitly NOT a new Island/notch view or switcher tab (user confirmed during discussion).
- Needs its own pasteboard-monitoring seam (likely polling `NSPasteboard.general.changeCount`, matching how `DragApproachDetector` already polls pasteboard state for drag detection) — no existing subsystem does this today.

**Outcome:** 7/7 requirements shipped. Phase 58 (Menu Wiring & UI Assembly) closed with a live on-device design amendment (D-15 REVISED — flyout submenu instead of an inline list, for more visible entries at once) and two on-device-only bugs found and fixed (zero-size menu rows, stuck hover highlight). See Requirements → Validated above for the full per-phase breakdown and `.planning/milestones/v1.9-ROADMAP.md` for the archived roadmap.

</details>

## Milestone In Progress: v1.11 (Droppy-Inspired Polish Round 2)

**Goal:** Ship the 4 remaining Droppy-inspired ideas from the 2026-07-29 brainstorming session, in the user's own stated priority order — no new domain research expected, these are UI redesigns/additions to existing subsystems.

**Status:** Started 2026-07-30. Roadmap defined (4 phases mapped to 8 requirements, see `.planning/ROADMAP.md`). **Phase 71 (Island Corner Rounding, SHAPE-02/SHAPE-03) shipped 2026-07-30** — wing-state HUD corner radii bumped 12/6 → 16/8 across all `wingsShape()`/`mediaWingsOrToast()`/`resumePreviewWings()` call sites, plus a DEBUG-only "Corner Radius" Wing Tuner axis. On-device UAT surfaced and fixed two real app freezes (content painting outside the notch silhouette once radii grew; an unclamped corner-radius nudge producing a self-intersecting shape) and a code-review Critical finding (the freeze-fix's clamp only covered one geometry axis — resolved by moving the clamp into `NotchShape.path(in:)` itself so it protects every caller against both axes). **Phase 72 (Calendar Redesign, CALVIEW-08/CALVIEW-09) shipped 2026-07-31** — two-column expanded Calendar view (month grid left, agenda right), red today/selected badge swap, weekday header row, real EventKit update/delete wired through `CalendarService`. On-device UAT drove a live scope revision: the originally-planned whole-month day-grouped agenda (D-01/D-02) was reverted back to single-day (today/selected only) after the user found it didn't feel right live, and 5 new hover affordances were added instead (D-13 Month/Year picker popover, white hover rings/borders on day cells, chevrons, event rows, and the Add button) — see `72-CONTEXT.md` for the full supersession record. Code review found 3 non-blocking warnings (stale month-fetch race, missing end>start validation on event edit, empty-id `ForEach` collision risk) tracked in `72-REVIEW.md`. 2 remaining target features (timer redesign, music Next Up queue) not yet started.

**Target features:**
- **Island corner rounding** — more rounded corners on the collapsed-wide (wings) island state (`wingsShape()` in `NotchPillView.swift`), plus a new DEBUG-only live-tuning nudge axis for corner radius (same pattern as the existing Wing Tuner).
- **Calendar redesign (Droppy-inspired)** — widen + redesign the expanded Calendar view (Phase 28, already shipped) to be a true 1:1 visual clone of macOS's native Calendar app: month grid left, agenda list right.
- **Timer redesign** — remove Pomodoro mode entirely from the code (including any persisted state/settings tied to it), replace timer setup with a ruler/slider duration picker (confirmed unit: minutes) + Start Timer button + sound toggle.
- **Music "Next Up" queue** — expand a "Next Up" list (next 5 songs: art/title/artist) from the Now Playing view's existing 3-dots/list-icon affordance.

**Key context:**
- All 4 have detailed reference screenshots and locked/near-locked decisions already captured in their seed files (`.planning/seeds/island-corner-rounding.md`, `calendar-redesign-droppy.md`, `timer-slider-redesign.md`, `music-next-up-queue.md`).
- Timer redesign is the riskiest of the four (removes existing Pomodoro state, not just additive) — flagged in its seed as likely needing its own careful discuss-phase pass.
- Calendar redesign carries an explicit "wirklich 1:1" pixel-fidelity bar, higher than most prior visual work in this project.
- Proposed order follows the seeds' own ranking: corner-rounding → calendar → timer → music queue.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

**Foundation (Phase 0 — APP-01, APP-02, APP-04):**

- [x] Menu-bar background agent shell — Islet runs as an LSUIElement agent (no Dock icon) with a status-item menu (Settings…, Quit Islet) and a Settings window. (Phase 0)
- [x] Launch-at-login — SMAppService.mainApp toggle in Settings, driven by the live system state. (Phase 0)
- [x] Release/notarization toolchain proven end-to-end as a re-runnable `scripts/release.sh` (ad-hoc dry run; the real Developer-ID notarize/staple + clean-Mac open is the documented Phase-6 carry-over). (Phase 0)

**The Empty Island (Phase 1 — ISL-01, ISL-02, ISL-06, ISL-07):**

- [x] Static black pill rendered exactly over the physical notch (matching width + corner radius) by a borderless, non-activating, click-through `NSPanel` hosting a SwiftUI pill — `.statusBar` level confirmed to win over the macOS 26 menu bar; verified on-device. (Phase 1)
- [x] Stays above all windows and across all Spaces; never steals focus; clicks pass through. (Phase 1)
- [x] Positions on the correct built-in display through external-monitor / resolution / clamshell changes — hides in clamshell, recovers on lid-open. (Phase 1)
- [x] Idle pill is near-invisible and completely static in release config. (Phase 1)

**Hover, Expand & Fullscreen Hardening (Phase 2 — ISL-03, ISL-04, ISL-05):**

- [x] The pill morphs collapsed↔expanded via a single `matchedGeometryEffect` spring (Alcove-quality, no cross-fade); the idle pill drives no animation. (Phase 2 — ISL-04)
- [x] Focus-safe interaction: a CLICK expands the island, hovering gives a haptic + bounce affordance without expanding (D-02 Alcove model), and pointer-away collapses after a ~0.4s grace; the non-activating panel never steals focus. (Phase 2 — ISL-03)
- [x] Hides/yields in true fullscreen via the private CGS managed-display-spaces signal — the NSScreen safe-area heuristic proved unusable from a background agent; native fullscreen verified on-device (8 further on-device UAT items tracked in 02-HUMAN-UAT.md; a 1-frame enter-transition flash is a deferred polish item). (Phase 2 — ISL-05)

**Charging Activity (Phase 3 — CHG-01):**

- [x] Live charging splash — plugging in the power cable shows the Alcove-style "wings" splash (a filling battery glyph + %) beside the notch for ~3s then collapses, driven by an event-driven IOKit power-source notification (no polling clock); routed through the single visibility gate so it stays hidden in true fullscreen; on-device verified. (Phase 3 — CHG-01)
  - **Connect-only (CHG-02 descoped):** by on-device decision the activity fires only on plug-in; unplugging deliberately shows nothing. CHG-02's original "brief on-battery indication on unplug" is intentionally dropped. (Phase 3)

**Now Playing (Phase 4 — NOW-01, NOW-02, NOW-03):**

- [x] Live media in the island — album art, title, and artist for the playing app (Spotify / Apple Music allowlist) as a collapsed glance (art + animated equalizer wings) and an expanded view; on-device verified. (Phase 4 — NOW-01)
- [x] Working transport from the expanded island — play/pause, next, previous act on the live session via the persistent adapter child, focus-safe (non-activating panel, no re-spawn). (Phase 4 — NOW-02)
- [x] Survives restart and degrades gracefully — launch-time health check; when the MediaRemote API is blocked or the source drops, the island clears state and shows "Now Playing nicht verfügbar" instead of crashing or sitting empty. All MediaRemote access is isolated behind a single `NowPlayingMonitor` (one-file swap if Apple breaks it), consuming the streamed output (not re-spawning) with main-thread callbacks. (Phase 4 — NOW-03)
  - **On-device UAT polish:** expanded layout reserves a 32pt notch/camera top-clearance; 5 random center-out equalizer bars (idle-CPU-gated); media glance wings 290pt (narrower than the 305pt charging wings); the expanded island stays open while the pointer is on the transport controls. (Phase 4)

**Priority Resolver, Settings & v1 Ship (Phase 6 — COORD-01, DEV-01, DEV-02, APP-03, APP-04):**

- [x] Single priority arbiter — a pure `IslandResolver` ranks Charging > Device > Now Playing through a bounded, de-duped `TransientQueue`; activities enqueue and play sequentially without overlap or glitching (WR-1/WR-2 identity-match and dismiss-timer defects closed in gap-closure plan 06-13, confirmed by code read + 131/131 tests + independent code review). (Phase 6 — COORD-01)
- [x] Device-connected activity — Bluetooth device / AirPods connect/disconnect splash with battery %, event-driven via a thin `BluetoothMonitor`; folded in from Phase 5's blocked device quartet (Phase 5 formally marked superseded by Phase 6 at v1.0 close). (Phase 6 — DEV-01, DEV-02)
- [x] Settings window — three independent activity toggles (Charging/Device/Now Playing, default ON) + curated accent palette, persisted via `@AppStorage`, survives restart. (Phase 6 — APP-03)
- [x] Release pipeline dry run — `scripts/release.sh` archive→sign→dmg→notarize→staple proven end-to-end in dry-run mode; real notarize/staple gated behind a paid Apple Developer account (not yet purchased, documented override). (Phase 6 — APP-04)

_v1.0 core feature set is code-complete and fully human-verified — all 4 on-device checks in `06-HUMAN-UAT.md` passed 2026-07-02, no issues. Milestone shipped._

**Now Playing Progress Bar (Phase 7 — PBAR-01):**

- [x] Display-only playback progress bar in the expanded Now Playing view — elapsed/total m:ss labels flanking an accent-filled capsule track, gliding continuously while playing and frozen while paused, zero tap-to-seek. On-device UAT caught and fixed a pause-transition backward-flash bug (stale MediaRemote sample corrected via a drift-extrapolated freeze); a post-execution code review then closed a NaN/Infinity crash risk in the same view. 141/141 tests green, on-device re-verified and approved. (Phase 7 — PBAR-01)

**Fullscreen-Enter Flash — Window/Space Architecture Retry (Phase 9 — FS-01):**

- [x] Fullscreen-enter island flash eliminated as a genuine root-cause fix — a dedicated, max-level private CGS Space (`CGSSpace.swift`) that the notch panel joins once at creation, additive alongside the existing `.canJoinAllSpaces` collection behavior (no per-Space auto-join race left to fire). On-device verified across all 3 trigger methods (green-button, menu bar, fullscreen video) with zero regressions across the full checklist (hover/click-expand, click-through, multi-Space visibility, display/clamshell repositioning, fullscreen hide/restore, lock-screen/sleep-wake). Closed Phase 8's escalation on the first wave of a 5-wave conditional chain — Candidate B (`SLSManagedDisplayIsAnimating` poll) and the terminal escalation report were never needed. (Phase 9 — FS-01)
  - **Known follow-up (non-blocking):** code review found the dedicated CGS Space leaks on app quit — `AppDelegate.quit()` calls `NSApp.terminate(nil)` without tearing down `NotchWindowController`, so its `deinit` (and the Space's `CGSHideSpaces`/`CGSSpaceDestroy` teardown) never runs. Doesn't affect the flash fix or fullscreen behavior; recommended fix via `/gsd-quick` before shipping.

**Trial & Lockout Gate (Phase 10 — TRIAL-01, TRIAL-02, LIC-03):**

- [x] Tamper-resistant 3-day trial — start timestamp persisted to the Keychain, survives `defaults delete` and reinstall; a one-time first-launch notice tells the user the trial has started; hard lockout (no pill, no activities) when expired and unlicensed, unlocking at the next natural UI transition rather than an abrupt yank. On-device verified. (Phase 10)

**License Settings UI (Phase 11 — TRIAL-03):**

- [x] Settings shows trial days remaining, a Buy Now button, and a key-entry field with idle/validating/success/failure states, proven against a stubbed `LicenseService` before any live network call existed. (Phase 11)

**Real Polar.sh License Integration (Phase 12 — LIC-01, LIC-02):**

- [x] Live Polar.sh checkout from Buy Now; real online key validation with a strict HTTP→verdict mapping that distinguishes a transient network error from an actually-invalid key (never hard-locks a key just paid for); validated state cached in the Keychain so the app keeps working fully offline afterward. On-device verified. (Phase 12)

**Real Notarization & Release (Phase 13 — DIST-01):**

- [x] `scripts/release.sh` produces a real Developer-ID signed, notarized, and stapled `.dmg` — no ad-hoc/placeholder signing remains; `spctl --assess` reports accepted, no Gatekeeper warning on first launch. Two real bugs fixed along the way: embedded frameworks need explicit re-signing before the outer `.app` (`codesign` doesn't recurse), and `notarytool` requires a zip/pkg/dmg, not a raw `.app`. (Phase 13)

_v1.1 (Trial & Paid Release) is code-complete and fully human-verified — all 7 requirements shipped and on-device tested. Milestone shipped 2026-07-08._

**Basic Outfit: Weather + Calendar + Date (Phase 14 — pending formal requirement IDs):**

- [x] `expandedIdle` glance shows live weather (icon + temperature via WeatherKit), the next relevant calendar event (EventKit), and the date in a 3-column layout alongside the existing time readout; only the weather icon animates per condition category; any column degrades silently to absent on permission denial. On-device verified (WeatherKit end-to-end, permission-denial omission, live event advancement, idle-CPU check). Executed ahead of formal milestone scope — capture as WEATHER-01/CAL-01/OUTFIT-01 in the next milestone's REQUIREMENTS.md. (Phase 14)

**NotchWindowController Device Coordinator Extraction (Phase 16 — D-01, D-02, D-03, informal IDs sourced from 16-CONTEXT.md):**

- [x] The 9-field device-splash bookkeeping and its 3 stateful methods extracted out of `NotchWindowController` into an independently-testable `DeviceCoordinator`, behind a narrow 2-method `ActivityCoordinator` protocol; `BluetoothMonitor`'s own construction/start/stop/deinit lifecycle stays untouched and directly owned by the controller (D-01/D-02). Zero product behavior change proven both by 9 new unit tests covering Pitfalls 1-8 and by a mandatory on-device Bluetooth verification checklist — all 4 D-03 scenarios (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion) passed on real hardware. First proof of the coordinator-extraction shape, ahead of repeating it for Charging/NowPlaying/Outfit. (Phase 16)

**Now Playing Launch Gating (Phase 17 — NOW-04):**

- [x] Islet stays idle at launch when an allowlisted player reports a paused/loaded track — only a transition into actively-playing triggers the Now Playing glance. On-device verified. (Phase 17)

**Song-Change Toast (Phase 18 — NOW-05, NOW-06):**

- [x] On a genuine track change (not the first track after launch), the island briefly grows a small fading text row under the existing collapsed wings glance showing the new title and artist for ~2s, then collapses back — suppressed during charging/device activities and while manually expanded, rapid skips replace content in place rather than re-triggering. Design iterated on-device across 5 rounds (initial full-blob render → shrink → structural redesign to a minimal fade-in row under the unchanged wings → centered text → independent 2s duration) before user approval; final shape deviates from the phase's original UI-SPEC.md draft, which was updated to match. (Phase 18)
- [x] Settings toggle for the song-change toast, Activities tab next to the existing Now Playing toggle, default on. (Phase 18)

_v1.2 (Now Playing Polish) is code-complete and on-device verified — both phases (17, 18) shipped 2026-07-09._

**Shelf Data Model (Phase 19 — SHELF-08):**

- [x] The shelf's core data and lifecycle contracts (`ShelfItem`, `ShelfLogic`, `ShelfFileStore`, `ShelfCoordinator`) exist as pure, Foundation-only, unit-tested logic with no persistence path whatsoever — a cleared or relaunched shelf is provably empty by construction. Zero coupling to `IslandResolver`/`TransientQueue`; the shelf is its own independent axis. Post-review hardening: `deleteSessionCopy` now validates its delete target lives under the shelf's own temp root (was an unvalidated recursive parent-directory delete), and a rejected duplicate append no longer orphans its just-made session-temp copy. (Phase 19)

**Shelf View (Phase 20 — SHELF-03, SHELF-04, SHELF-05, SHELF-07, SHELF-09):**

- [x] The expanded island renders a horizontally-scrolling shelf strip below whatever else is showing (Now Playing, idle glance, etc.) whenever it has content — each item shows a file-type icon with its own trash icon, a single "delete all" trash clears everything at once, clicking an item opens it in its default app, and the strip is suppressed while a Charging or Device wings splash is actively showing. On-device UAT closed a click-through regression (CR-01: an invisible 56pt band under an empty shelf was silently swallowing clicks) by scoping `syncClickThrough()`'s hit-test to the actual visible blob rect instead of the full static panel. (Phase 20)

**Drag-Out (Phase 21 — SHELF-06):**

- [x] A shelf item can be dragged out of the expanded island onto Finder or any other app via `.onDrag` + `NSItemProvider(contentsOf:)` (copy semantics — the item stays in the shelf, default system drag preview, silent no-op on a vanished backing file). The island pins open for the duration of the drag (best-effort `.leftMouseUp` release monitor + a 20s safety-net fallback) and resumes normal hover/grace-collapse promptly once the drag ends. On-device UAT surfaced and fixed two gaps beyond the original plan: the shelf strip was invisible because `NotchPillView.body`'s outer container frame hadn't grown to match `blobShape`'s Phase-20 shelf-height addition (commit `3b38f33`), and — added at explicit user request during UAT, beyond the original D-02 scope — a shelf item whose backing file is deleted externally is now auto-pruned on expand instead of sitting inert until manually trashed (commit `dfbde2d`). (Phase 21)

**Shell Parity Rewrite (Phase 23 — ARCH-01):**

- [x] `NotchPanel`/`NotchWindowController` reconstructed in place with zero behavioral regression — the Phase-22 `NSDraggingDestination` drag scaffold is fully removed (with a `testPanelHasNoDraggingDestinationResidue` regression guard), and every other line (positioning, hover/click/grace-collapse, fullscreen hiding, the CR-01 click-through fix, multi-Space visibility) was re-verified against the pre-rewrite implementation and found to already match byte-for-byte — 2 files touched project-wide, `IslandResolver.swift`/`DeviceCoordinator.swift`/`Islet/Shelf/` show zero diff. Closed out via a blocking human on-device UAT checkpoint (20 items incl. the CR-01 hover→expand→move-down trace) the user explicitly approved. Clears the architectural prerequisite for Phase 24 (Drag-In). (Phase 23)

**Drag-In (Phase 24 — SHELF-01, SHELF-02):**

- [x] Files dropped onto the collapsed island are accepted and land in the shelf — carried forward from v1.3 as the milestone's anchor requirement after two unexplained on-device failures blocked it there. A DEBUG-only global-monitor spike first confirmed `NSPasteboard(name: .drag)` changeCount deltas reliably detect a real Finder-initiated inbound drag; production `DragApproachDetector` monitors then auto-expand the island and land the item in the shelf. (Phase 24 — SHELF-01)
- [x] The original file is never relocated by the drop — a session `CGEventTap`-based `DropInterceptTap` intercepts the drag before Finder's own default-move behavior can act on it, closing a data-loss gap found during on-device UAT (the click-through panel wasn't intercepting the real drag session, so the Desktop underneath performed its own file move). Round-2 on-device UAT approved after a follow-up fix for the drag cursor staying stuck. (Phase 24 — SHELF-02)

**Visual/Material Theming Redesign (Phase 25 — VISUAL-01, VISUAL-02):**

- [x] Shared black-to-transparent vertical gradient material (`islandMaterial`) replaces flat black fills across the collapsed pill, expanded island, and all activity wings; expanded-blob bottom corner radius raised 20→32pt for a rounder, more Dynamic-Island-like silhouette. Pure rendering-value change confined to `NotchPillView.swift`/`NotchWindowController.swift` — no new files/types, individual activity content untouched. (Phase 25 — VISUAL-01)
- [x] Spring animation retuned (response 0.35→0.6, damping 0.65→0.62) for a slower, single-overshoot morph matching the iPhone Dynamic Island's characteristic bounce, applied uniformly through the existing shared spring constants. (Phase 25 — VISUAL-02)
- On-device UAT (7-point checklist: gradient depth, pure black, corner roundness, spring feel, no morph artifacts, rapid hover-enter/exit, activity-content regression) passed on first attempt on real notch hardware — the documented `NotchShape.swift` `animatableData` contingency was not needed. VISUAL-03 (Settings theming section) intentionally out of this phase, carried to Phase 27.

**Settings Sidebar Redesign + Theming (Phase 27 — SETTINGS-01, VISUAL-03):**

- [x] `SettingsView` restructured from a 3-tab `TabView` into a `NavigationSplitView` sidebar (General/Workspace/System/About), every existing control relocated verbatim, no section-switch state staleness. (Phase 27 — SETTINGS-01)
- [x] New System (Theming) section: a Gradient/Solid Black material-style picker plus 3 independent per-element accent pickers (Now Playing/Charging/Device), replacing the single shared accent index; live-applies to the pill/expanded island/wings via the existing UserDefaults-observer re-host pipeline. A one-time migration seeds the 3 new keys from the legacy single accent so existing users' accent choice carries forward. (Phase 27 — VISUAL-03)
- On-device UAT checkpoint found and fixed 2 real regressions that no automated build/grep check could catch: Settings not opening at all via the menu bar icon (`.defaultLaunchBehavior(.suppressed)` silently prevented the Settings `Window(id:)` scene from ever being created), and the sidebar navigation being completely unresponsive to clicks (`List(selection:)` never registered a click regardless of 3 fix attempts; replaced with a plain `Button`-based row implementation). Both root-caused via targeted diagnostic instrumentation rather than static reasoning alone. Full 10-step on-device walkthrough approved. (Phase 27)

**Calendar Full View (Phase 28 — CALVIEW-01, CALVIEW-02, CALVIEW-03, CALVIEW-04):**

- [x] Month-grid + selected-day event list calendar view (EventKit), quick-add for both Events and Reminders (Reminders permission requested lazily on first use) without leaving the island; a switcher pill below the expanded island for navigating between views. (Phase 28 — CALVIEW-01/02/03/04)
- [x] **User-amended beyond the original locked design, confirmed on-device during the checkpoint:** the switcher grew from the originally-planned 3 icons (Home/Tray/Calendar) to 4 (Home/Tray/Calendar/Weather); "Home" now conditionally shows Now-Playing controls when something is playing and the idle date/time glance otherwise (previously the idle glance was unconditional — a deliberate reversal of the "don't copy Droppy's music-default" research note, re-decided by the user live on-device); Tray became its own dedicated files-only resolver case (`.trayExpanded`) rather than the originally-planned additive shelf-strip-under-Home approach, to match the Droppy reference exactly. All three amendments are recorded with rationale in `28-CONTEXT.md`/`28-UI-SPEC.md`, not silent drift. (Phase 28)
- [x] Weather tab shows enlarged current conditions only (category + temperature, reusing the existing `WeatherGlance` data) — no forecast/hourly data was added; a real multi-day forecast would need a new WeatherKit call and data model, deliberately left as an open follow-up rather than built without asking. (Phase 28)
- Shipped after 6 rounds of on-device UAT (camera-notch clipping, switcher hidden during media playback, resolver precedence blocking Calendar/Weather during playback, calendar grid density vs. the Droppy reference, a switcher-pill position-jump causing misclicks, and a SwiftUI `.buttonStyle(.plain)` hit-test gap on the switcher icons) plus a post-approval code-review-and-fix pass that closed 2 further critical bugs (a click-through phantom band reintroduced by the dedicated Tray view; quick-add silently targeting a stale month after navigation) and 4 quality warnings. (Phase 28)

_v1.4 (Architecture Redesign) shipped 2026-07-28 — all 6 phases (23-28) complete, both outstanding verification items confirmed (`28-HUMAN-UAT.md`'s CR-01/CR-02 on-device re-tests, and a since-discovered `27-VERIFICATION.md` Cmd-U confirmation gap for `ActivitySettingsTests`/`DiagnosticReportTests`). Tagged `v1.4`. See `.planning/MILESTONES.md`._

**NotchShape Flare (Phase 29 — SHAPE-01):**

- [x] Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) shows a visibly larger, smoother top-corner radius than the collapsed pill and media toast — shipped as a plain `topCornerRadius` value bump (6→24 at the blob, 6→12 at wings) at the 2 existing call sites, not a new shape mechanism. `NotchShape.swift` itself ends byte-identical to its pre-Phase-29 form. (Phase 29)
- **Superseded during on-device UAT, not silent drift:** the plan's original `topFlareWidth` geometry design (and 3 further redesigns — concave sweep, shoulder bulge, centered notch dip) were built and each rejected on-device across ~17 iterative rounds in a single session, before the user supplied a tight reference crop showing the effect was just a bigger corner radius all along. All experimental geometry was reverted; see `29-01-SUMMARY.md`'s "What Was Actually Shipped" section before touching `NotchShape`/`NotchPillView` again. (Phase 29)

**Home Music-Only (Phase 30 — HOME-01, HOME-02, HOME-03):**

- [x] Home's old time/weather/calendar idle glance is fully deleted — the resolver now classifies Home's no-media state into `.homeLastPlayed` (real last-played track + transport, gated on `hasPlayedSinceLaunch`) or `.homeEmpty` (music-note icon, "Nothing Playing" placeholder). Live playback shows title/artist/artwork with all 3 real transport buttons. (Phase 30)
- [x] Transport buttons gained a D-05 rounded-rectangle hover background (settled at 0.40 white opacity after an on-device A/B comparison) and the media display's camera clearance was bumped 32→42pt after the user confirmed a minor overlap with the physical camera cutout. (Phase 30)
- On-device UAT's first pass found the D-05 hover never appeared at all — root cause was `NotchPanel.init` never setting `acceptsMouseMovedEvents`, so the window never received native `mouseMoved` events for SwiftUI's first-ever native `.onHover` in this codebase (every prior hover interaction used a manual global `NSEvent` monitor instead). Fixed in gap-closure Plan 30-04, re-verified, user typed "approved". (Phase 30)

**Shelf Consolidation to Tray-Only (Phase 31 — TRAY-01):**

- [x] The additive shelf-strip-reveal on Home/Calendar/Weather is removed; file-shelf content is visible only on the Tray tab — `shelfStripVisible` is a shared hardcoded-`false` gate wired into all 5 non-Tray `blobShape` call sites, `visibleContentZone()`'s click-through geometry simplified to match, and `trayFullView`'s own `shelfRow(_:)` path is unaffected. (Phase 31)
- Implementation shipped ahead of formal planning via quick task 260714-3k6; this phase added a regression test (initially insufficient — code review caught it testing an empty shelf, unable to distinguish a hard-coded `false` from empty-shelf `false`; fixed to seed a non-empty shelf) and ran the on-device CR-01-class hover→expand→move-down click-through trace, user-approved with zero regressions. Clears `visibleContentZone()` to be touched only once by Phase 32 (Tray Widening). (Phase 31)

**Tray Widening (Phase 32 — TRAY-05):**

- [x] Tray widened to 650pt with 40x40pt file tiles, kept in sync across 4 separate geometry points (SwiftUI render, outer frame, AppKit panel reservation, click-through zone) that all have to move together for a floating panel with no native layout system tying them to one source of truth. (Phase 32)
- On-device UAT required 11 gap-closure rounds — width narrowed twice (840→750→650pt) before it read right against real hardware, plus a root-cause fix for `ScrollView(.horizontal)`'s content-centering behavior, which had been silently defeating top-clearance padding for 4 rounds until it was diagnosed directly rather than patched around. (Phase 32)

**Weather Widget Redesign (Phase 33 — WEATHER-01, WEATHER-02):**

- [x] Weather tab always shows a Medium widget (existing header plus a new hourly forecast row, up to 6 chips); a Settings "Weather Style" Medium/Large segmented control live-switches to Large, adding a daily forecast list (4 rows: weekday/icon/low/gradient range-bar/high) — a 1:1 clone of the iOS Weather widget's two size classes. `WeatherService` now fetches `.current`/`.hourly`/`.daily` in one combined WeatherKit call. (Phase 33)
- **Structural fix affecting every `blobShape` caller, not just Weather:** on-device UAT (6 gap-closure rounds) found `blobShape`'s `.overlay` never clipped its content to `NotchShape` — any content taller than the base height painted straight through onto whatever sat behind the floating panel. Added `.clipShape(shape)`, verified non-regressive for Home/Tray/Calendar since their content already fit within bounds. (Phase 33)

**Quick Action Destination Picker (Phase 34 — TRAY-02, TRAY-03, TRAY-04):**

- [x] Dragging a file into the island's accept region shows a Drop/AirDrop/Mail picker DURING the drag (dragEntered edge), with live per-button hover highlighting and release-on-target selection — replaces the click-based picker rejected during on-device UAT. `computeQuickActionButtonFrames(card:)` (pure geometry, unit-tested) plus controller-side hit-testing in `NotchWindowController` drive the whole interaction; no `Button(action:)` taps involved. (Phase 34)
- [x] Choosing Drop stages the file(s) into Tray (TRAY-03); choosing AirDrop/Mail invokes `NSSharingService` directly with zero window-activation code, re-confirmed on real hardware (TRAY-04). Dragging back out before releasing discards the pending file(s) with no orphaned session copy (D-13b/Pitfall 6 fix). (Phase 34)
- Shipped after a full replan: the original click-based implementation (Wave 1 of the original 34-01/34-02) passed code but was rejected in on-device UAT, then rebuilt as the drag-target model described above and re-verified on-device (7/7 checkpoint checks passed). Code review flagged one carried-forward critical issue (CR-01: synchronous main-thread file copy on drag-enter, no debounce) as a non-blocking fast-follow — see `34-REVIEW.md`. (Phase 34)

**Liquid Glass Material (Phase 35 — GLASS-01):**

- [x] The shared background material (collapsed pill, expanded island, all 3 activity wings) replaced by a dark, frosted "Liquid Glass" look — a solid dark frost layer masks a warped `.ultraThinMaterial` backdrop, revealed only as a narrow, chromatic-fringed rim-light right at the rounded edge (`liquidGlassEffectLayer` in `NotchPillView.swift`, `LiquidGlassShader.metal`/`.swift`). Applied as a modifier on the existing shape node at all 4 fill sites, preserving `matchedGeometryEffect` morph continuity. Settings' Theming picker gained a 3rd "Liquid Glass" segment as the new default (D-06); the Settings window itself gets a calmer, non-distorted variant of the same look, gated on that same style choice. (Phase 35)
- Shipped after 4 rounds of on-device UAT rejection/remediation — round 1 (opaque base, no visible transparency), round 2 (raw vibrancy material read as uniformly bright, no dark tint), round 3 (unmasked chromatic-fringe/white-wash screen-blending washed the dark frost center back toward grey), round 4 (masked those layers to the same rim falloff the frost layer already uses — approved). Post-approval code review found and fixed one carried-forward critical issue (Settings window background wasn't gated on the user's material choice) plus two maintainability warnings — see `35-REVIEW.md`. (Phase 35)

**Cosmetic Restyles & Signature Animation (Phase 36 — HUD-01, HUD-02, EQ-01, ONBOARD-04):**

- [x] Bluetooth/AirPods (HUD-01) and Charging (HUD-02) collapsed wing HUDs restyled to the Droppy-pill look — a left-wing icon+label shown only in the positive state, independent left/right wing-flank sizing so a wide label never stretches the opposite flank; `DeviceCoordinator`/`BluetoothMonitor`/IOKit power monitor unchanged. Charging's trigger condition was corrected from the raw IOKit `isCharging` flag to `isOnAC && !isCharged`, since macOS "Optimized Battery Charging" routinely leaves the literal flag false while genuinely charging. (Phase 36)
- [x] Now Playing equalizer bars (EQ-01) redesigned to the Skiper25 reference — thinner bars, wider gaps, fixed white color, periodic-reroll-and-spring motion replacing the old continuous sine wave, idle-CPU gate preserved; mandatory Skiper UI attribution added to Settings. (Phase 36)
- [x] Onboarding signature heading (ONBOARD-04) — scope-pivoted mid-execution (D-14): the originally planned live stroke-reveal animation was replaced with a static, non-animated "Meet Islet" heading in Dancing Script Bold, "Meet" in a blue→purple→pink gradient and "Islet" in an orange→yellow→green gradient, mirroring Droppy's own static rainbow-gradient onboarding heading. The pivot followed real font-licensing risk (the reference's original font, Lastoria Bold, is all-rights-reserved, not legally shippable in a paid product) plus repeated stroke-weight/clipping friction with the animated approach; body subtext below it untouched. (Phase 36)
- Code review found no blockers; one open, non-blocking warning carried forward: the widened Charging/Connected wing labels may extend past the existing tap hot-zone (on-device tap test confirmed no regression — see `36-REVIEW.md` WR-02). (Phase 36)

**Focus Mode HUD (Phase 38 — HUD-05):**

- [x] A generic on/off Focus/Do Not Disturb HUD — `FocusModeMonitor` polls `INFocusStatusCenter.focusStatus.isFocused` every 2.5s (Path A, confirmed reachable via an on-device spike over the research-predicted Assertions.json/FDA fallback), driving a collapsed-pill wing (icon-only left flank, dot+"On"-label right flank, redesigned live on-device from the original icon+label/bare-dot spec). Opt-in Settings toggle, default OFF, with a manual permission-status hint popover. (Phase 38)
- On-device UAT found and fixed two hidden-requirement gaps beyond `authorizationStatus == .authorized`: a missing `NSFocusStatusUsageDescription` Info.plist key that hard-crashed at first `INFocusStatusCenter` access, and a missing Communication Notifications entitlement without which `isFocused` silently resolves to `false` forever (not nil) — both undetected until 38-09's actual functional read against live state, not just an authorization check. All 4 ROADMAP Success Criteria confirmed; 9/9 plans shipped including gap-closure. (Phase 38)

**Volume & Brightness HUD (Phase 39 — HUD-03, HUD-04):**

- [x] Volume and Brightness key presses show a Droppy-pill HUD (icon + fill-bar wing) via a pure `OSDActivity` model ranked into a dedicated collapsed-only `IslandResolver` tier, reading live levels from CoreAudio/DisplayServices. (Phase 39 — HUD-03/HUD-04)
- [x] Native system OSD suppression — reversed from 39-01's initial "unreliable" spike finding: a `.cgSessionEventTap` failed to suppress the notch-integrated OSD, but gap-closure plan 39-08 found `.cghidEventTap` (HID-level, before the Window Server session layer) works, matching `dannystewart/volumeHUD`'s proven technique. Islet now self-drives real system volume/brightness/mute via `AudioObjectSetPropertyData`/`DisplayServicesSetBrightness` whenever a press is swallowed, with a per-type kill switch that falls back to passthrough if a self-drive write ever fails — the Settings suppression toggle is now a real control, not the originally-shipped no-op. Zero transport-key regressions across all 4 media keys on-device. (Phase 39)
- A genuinely reusable lesson from a 16-round on-device layout debugging saga: `.offset()`/`.position()` both silently misbehave for content placed inside `wingsShape`'s content `ZStack`; the fix was a plain `HStack(spacing: 0)` with fixed-width `Color.clear` spacers for excluded regions — the same pattern every other wing already used. See STATE.md decision log (39-07) for the full diagnostic record. (Phase 39)

**Update-Available HUD & Sparkle Integration (Phase 40 — HUD-06):**

- [x] Real Sparkle 2.9.4 auto-update integration (`SPUStandardUpdaterController`, generated EdDSA keypair) — tapping an available update triggers Sparkle's own standard install/progress dialog, not a custom in-notch flow. (Phase 40 — HUD-06)
- [x] The update-available indicator was redesigned mid-phase from a collapsed-pill corner badge to a small red dot on the menu-bar status-item icon, after on-device UAT root-caused the badge's tap-dispatch bug to a click-through hot-zone gap in `NotchWindowController` (the same fragility class later re-found and fixed in Phase 42's own hot-zone work) — the status-item dot sidesteps the whole click-through-zone bug class by construction. `UpdateAvailableState.swift` and the pill badge overlay were deleted. Release-archive launch confirmed crash-free under Hardened Runtime with the embedded Sparkle.framework. (Phase 40)

**Calendar Countdown HUD (Phase 41 — HUD-08):**

- [x] Starting 1 hour before a calendar event, the collapsed pill shows a live minute-countdown (calendar icon left, mm:ss right, recoloring orange→red together from one shared per-tick `TimelineView` value) via a dedicated, event-driven `CalendarCountdownMonitor` with its own one-shot-deadline timer — ambient only, never touches `TransientQueue`. Ranked ahead of Now-Playing wings in `IslandPresentation`. Default-ON Settings toggle, no permission surface (reads through the existing EventKit service layer). (Phase 41 — HUD-08)
- On-device UAT found and fixed a real-hardware-only bug: the countdown text's leading digit rendered under the physical camera housing until the wing's right flank was widened from `wingsSize.width/2` to `wingsLabelWidth/2`, reusing the existing label-clearing constant `deviceWings` already established rather than a new magic number. (Phase 41)

**Dual-Activity Display (Phase 42 — DUAL-01):**

- [x] When Calendar Countdown and Now Playing are both live, the collapsed island shows the countdown pill plus a small round secondary bubble (real album art) instead of one activity strictly winning — additive `IslandResolver.resolveSecondary()` extension, `IslandPresentation`/`resolve()` untouched. Primary/secondary pairing is expressed as a genuine small ordered table (per locked decision D-03), scoped to today's 2 activity kinds. (Phase 42)
- [x] Tapping/hovering the bubble was redesigned live during on-device UAT: hovering darkens the bubble and reveals a play/pause glyph matching current playback state; tapping toggles play/pause directly via the existing `NowPlayingMonitor.togglePlayPause()` — this supersedes the original plan's tap-to-expand/no-hover design (D-12/D-13), by explicit user decision, not scope drift. (Phase 42)
- Code review found no blockers; one warning (hardcoded hot-zone offset) was fixed post-review since it duplicated the exact fragility class that caused the Phase 40-03 badge-tap regression — see `42-REVIEW.md`/`42-VERIFICATION.md`. Three smaller warnings (duplicated launch-gate derivation, a missing `deinit` cancel, hover-state view scoping) remain as non-blocking backlog. (Phase 42)

**Drag Detection Hardening (Phase 43 — DRAG-01):**

- [x] The island's auto-expand / Quick Action destination picker only fires on a genuine external file drag approaching it — an ordinary click or hover on the collapsed/expanded island never triggers it. Fixed via `isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:)`, a pasteboard-change-count gate wired into `recheckDragAcceptRegion`'s auto-expand arm branch. (Phase 43 — DRAG-01)
- On-device UAT of the fix took 4 rounds and found 2 further real regressions no build/unit-test gate could see: the island got permanently stuck expanded after discarding a drag (the auto-collapse grace-timer only fires from `.mouseMoved`-driven hover-exit, which never occurs during an active OS drag session), and even after that was fixed, resolving the Quick Action picker still briefly flashed the underlying Home/Now-Playing/Tray content before collapsing. Both closed by adding a dedicated `.dismissed` state-machine event (immediate `expanded → collapsed`, no grace defer) and a shared `dismissExpandedImmediately()` helper consolidating all 4 picker-resolution paths (Drop, AirDrop, Mail, discard). See `43-02-SUMMARY.md` for the full round-by-round record. (Phase 43)

**Tray & Quick Action Width Alignment (Phase 44 — TRAY-06, DRAG-02):**

- [x] The Quick Action picker's panel reservation, click-through content size, and `blobShape` call all switched from a hardcoded 420×117pt box to the real Tray's actual 650×189pt footprint — closing the visible size mismatch between the during-drag preview and the landed Tray state. (Phase 44)
- On-device UAT (6 rounds) found and fixed 5 real bugs beyond the build-verified geometry: button overflow past the card's curved edges, a hover hit-test anchored to the wrong edge, excess picker height, a Tray-height mismatch, and clipped empty-state text — ending with the picker and Tray sharing one exact height/width footprint by explicit user design. (Phase 44)

**View Switcher Morph Fix (Phase 45 — SWITCH-01, SWITCH-02):**

- [x] Tab switches (Home/Tray/Calendar/Weather) morph continuously with no disappear/rebuild flicker and no large→small behind-buttons z-order glitch. Root cause was `presentationSwitch` calling `blobShape` from 6 textually-distinct case branches — SwiftUI's structural-identity model treats a case change as remove+insert, not update. Fixed by collapsing all 6 switcher-row cases into one shared `tabContentView` call site (`tabWidth`/`tabHeight` computed properties, content-only inner switch), giving every case one continuous view identity for `matchedGeometryEffect` to morph across. On-device 12-pairwise-transition sweep (both directions) plus an interrupted-mid-morph-tap retarget check confirmed the fix with zero regressions. (Phase 45 — SWITCH-01, SWITCH-02)

**Calendar Quick-Add Improvements (Phase 46 — CALVIEW-05, CALVIEW-06, CALVIEW-07):**

- [x] Quick-add gained a real Starts/Ends/Due `DatePicker` UI with day-aware defaults (next full hour if today, else 00:00) and a Start→End 1-hour auto-follow that survives repeated Start edits but correctly stops following after a manual End edit. Real picked dates wired into `CalendarService.createEvent`/`createReminder`. (Phase 46 — CALVIEW-05)
- [x] The "+ Add" trigger moved from the previously-clipped right edge to the day-list column's left edge, popover opening trailing so it never overlaps the month grid. (Phase 46 — CALVIEW-06)
- [x] Day-list rows gained more padding/margin; Calendar got its own 472×220 size (independent of the shared switcher-tab constant) to fit the roomier rows without clipping. (Phase 46 — CALVIEW-07)
- On-device UAT confirmed all 3 requirements working exactly as specified in a single ~15min pass, no code changes needed. **Note:** REQUIREMENTS.md's checkboxes/traceability table showed CALVIEW-06/07 as still Pending until 2026-07-28 — same stale-documentation pattern found and fixed elsewhere this session (Phase 24/27/29/30/32/33), not a real gap. (Phase 46)

**Audio Output Switcher — Pure Seam + Monitor (Phase 47 — infrastructure, no requirements formally scoped):**

- [x] `AudioOutputPresentation`'s device value type, sort/reorder logic, and `AudioOutputMonitor` (event-driven CoreAudio glue enumerating real output devices via `kAudioHardwarePropertyDevices`, confirm-after-set default-output switching, guarded per-device volume-control detection) built and proven correct in isolation before any UI touches them — mirrors this project's own pure-seam-first precedent (Phase 19/22-01/24-01/38-01/39-01). (Phase 47)
- On-device manual Cmd-U spike surfaced and fixed a real HAL "wrong data size" bug in `resolveDeviceID`'s UID-translation call, then re-verified clean: stable UIDs across a Bluetooth reconnect, a confirmed-after-set default-output switch, and `hasVolumeControl` results recorded for built-in/Bluetooth/USB/external-monitor devices — the authoritative input Phase 48's slider UI builds on. (Phase 47)

**Audio Output Switcher — UI Wiring (Phase 48 — OUTPUT-01, OUTPUT-02, OUTPUT-03, OUTPUT-04):**

- [x] An absolute-set CoreAudio volume write path plus 4 new controller-owned `@Published` output-panel fields, with `AudioOutputMonitor` started unconditionally and its live device-list callback wired into `presentationState`. (Phase 48 — OUTPUT-04)
- [x] The output-switcher panel restructured so the active device's row itself IS the draggable volume bar (a `Capsule` track/fill as the row's own background) instead of a standalone slider above a checkmarked list — full-white-vs-dimmed text opacity is the sole active-device signal. (Phase 48 — OUTPUT-01, OUTPUT-02, OUTPUT-03)
- [x] Real CoreAudio-backed toggle/select/drag handlers close the loop end to end; all 4 ROADMAP Phase 48 Success Criteria confirmed on real hardware against the row-as-volume-bar UI after a two-round on-device UAT that found and fixed a choppy volume-drag animation bug. (Phase 48 — OUTPUT-01, OUTPUT-03, OUTPUT-04)

**Settings Reorganization & Scroll Fix (Phase 51 — SETTINGS-02, SETTINGS-03):**

- [x] `SettingsView` restructured from Phase 27's sidebar into a 7-case `SidebarSection` (Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About), every section wrapped in its own `ScrollView` so previously-cut-off content (Weather, Diagnostics) is fully reachable — no setting lost or duplicated during the split. (Phase 51 — SETTINGS-02, SETTINGS-03)
- On-device UAT drove one further fix beyond the original plan: the Settings window widened 520→600pt after the Appearance accent picker was found clipped at the original width. (Phase 51)

**Top-Edge Switcher Layout & Placement Config (Phase 52 — SWITCH-03, SWITCH-04):**

- [x] Users can switch between the default pill-below-the-island switcher and an alternate top-edge layout — 4 icons flanking the camera cutout (2 left, 2 right), rendered via a new `topEdgeSwitcherRow` reusing the same notch-cutout-gap geometry `NotchGeometry` already established. `blobShape`/`totalHeight`'s height math was fixed at all 3 call sites so switching layouts doesn't double-count or drop the pill row's height. (Phase 52 — SWITCH-03)
- [x] Which icon appears on which side is independently configurable per slot via 4 new `@AppStorage` keys, wired into a new Settings "Switcher" sidebar section, fully hidden on displays without a physical camera notch. (Phase 52 — SWITCH-04)
- Shipped after a full 403-test regression suite + Release build passed and the user approved the complete on-device walkthrough ("Klappt alles wunderbar") — fit/clearance/live-reorder all confirmed on real notched hardware. (Phase 52)

**Hover-to-Resume Idle Preview (Phase 53 — RESUME-01, RESUME-02):**

- [x] Hovering the collapsed island after a track has played this session (then stopped/paused/quit) shows that track's album art and, on the right, a static play glyph — shipped as a view-local branch off `.idle` in `NotchPillView` (Claude's Discretion) rather than a new `IslandResolver` case, keeping `IslandResolver.swift`/`IslandResolverTests.swift` untouched. (Phase 53 — RESUME-01)
- [x] Clicking the preview calls the existing `togglePlayPause()` transport directly, in place (no expansion to Home), with an inferred-failure timeout showing "Wiedergabe nicht möglich" when resume genuinely isn't possible — confirmed on-device that `togglePlayPause()` resumes a merely-paused session but not a fully-quit one, for both Spotify and Apple Music. (Phase 53 — RESUME-02)
- **Superseded mid-UAT (D-02):** the preview's right slot was originally spec'd as bouncing `EqualizerBars` identical to the live-playing glance; on real hardware, animated bars while nothing was actually playing read as misleading, so it now shows a static `play.fill` glyph instead. Confirmed on-device (Debug + Release) after the fix. (Phase 53)

**Clipboard Data Model + Store (Phase 55 — no formal REQ-ID, infrastructure phase):**

- [x] `ClipboardItem` (associated-value `Kind` enum, text/image) and `ClipboardStore` (append/evict-at-cap FIFO/dedupe-move-to-top/clear) shipped as pure, Foundation-only value types/functions, fully unit-tested, with zero AppKit/`NSPasteboard`/`IslandResolver`/`TransientQueue` coupling — establishing the contract before any pasteboard-polling or disk-I/O code was touched (Phase 19/47/49 pure-seam-first precedent). (Phase 55)

**Encrypted Persistence (Phase 56 — CLIP-04, PRIV-02):**

- [x] Clipboard history persists to disk encrypted at rest — `ClipboardFileStore` (AES-GCM/CryptoKit, JSON-index + separate image files under Application Support) with the key stored device-only in Keychain via `KeychainClipboardKeyStore`. On-device kill-and-restart proof: seeded 3 items, confirmed the on-disk index is unreadable ciphertext with no plaintext trace, fully killed and relaunched the process, all 3 items reloaded with matching IDs/content. (Phase 56)
- Code review flagged one unresolved CRITICAL follow-up not required by this phase's own success criteria: `ClipboardFileStore`'s index/image writes aren't atomic, so a crash mid-write can silently truncate the index and the next save's orphan-sweep would then delete previously-saved images — worth fixing before Phase 57 wires in a live, higher-frequency writer. See `56-REVIEW.md`.

**Pasteboard Monitor — Spike (Phase 57 — PRIV-01):**

- [x] `ClipboardMonitor` detects a genuine copy via a `changeCount` diff and correctly classifies it as text or image, verified on real hardware; content marked `org.nspasteboard.ConcealedType`/`TransientType` (the password-manager convention) is never captured, verified on-device against a real concealed-type source; a restored item's own pasteboard write is not re-ingested as a duplicate (self-capture guard); macOS's pasteboard-access privacy prompt, if it appears, is handled with a one-time in-app explanation rather than a crash or repeated re-prompt. (Phase 57 — PRIV-01)
- Code review WR-01: added a "Stop Clipboard Monitor" debug action to fulfill the monitor's `stop()` teardown contract, which had no caller. (Phase 57)

**Menu Wiring & UI Assembly (Phase 58 — CLIP-01, CLIP-02, CLIP-03, CLIP-05):**

- [x] Clicking the menu-bar status icon shows a "Clipboard History" flyout submenu (revised live from the originally-planned inline list, D-15 REVISED — the user asked for a submenu on-device mid-UAT to see more entries at once) listing recent text/image copies most-recent-first, alongside Settings…/Check for Updates…/Quit, oldest entries evicted past the cap. (Phase 58 — CLIP-01)
- [x] Clicking any entry restores it to the system pasteboard with no auto-paste into the frontmost app. (Phase 58 — CLIP-02)
- [x] The first 10 entries are selectable via Cmd+0-9, working instantly right after opening the menu — not only once the submenu itself is hovered open — via a hybrid local `NSEvent` keyDown monitor installed while the top-level menu is tracking (submenu-nested `NSMenuItem` keyEquivalents don't fire while the submenu is closed, so this couldn't rely on keyEquivalents alone). (Phase 58 — CLIP-03)
- [x] "Delete All History" shows a destructive-confirm dialog (red Delete button); once confirmed, both the in-memory store and the on-disk encrypted index are actually cleared, not just hidden from the menu. (Phase 58 — CLIP-05)
- Two real on-device-only bugs found and fixed during Phase 58's on-device UAT, neither catchable by build or unit tests: (1) menu rows were inserted correctly but rendered at zero size because the `NSHostingView` assigned to `menuItem.view` never had an explicit `.frame` set; (2) SwiftUI's `.onHover` unreliably delivers `mouseExited` during `NSMenu`'s tracking-mode run loop, leaving a row's hover highlight stuck on — fixed with a native `NSTrackingArea`-backed container view instead. See `58-01-SUMMARY.md`/`58-02-SUMMARY.md`.

**Settings-Redesign (Phase 59 — SETTINGS-04, SETTINGS-05):**

- [x] Settings' Activities section is one Droppy-style grid of Live-Activity cards (existing + new) — mini live-preview + title + description + on/off toggle per card, replacing the old ad-hoc per-activity rows. Every new v1.10 activity defaults OFF; every pre-existing activity's toggle state survives the upgrade unchanged, verified against a pre-seeded UserDefaults domain. A resolver-priority doc table now covers every v1.10 activity's `IslandResolver`/`TransientQueue` rank. (Phase 59)

**Caps Lock HUD + Update-Activity Restyle (Phase 60 — CAPS-01, UPDATE-01):**

- [x] Caps Lock on/off shows an event-driven HUD (`NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`, no polling lag), auto-dismissing after ~1-2s; the existing Sparkle update-available HUD is reskinned to the Droppy look (leading icon, "Update" label, trailing version pill) with unchanged trigger/tap-to-install behavior. Both register as Phase 59 grid cards, default OFF. (Phase 60)

**Download-Progress (Phase 61 — DL-01, DL-02):**

- [x] `DownloadMonitor` (FSEvents) shows a live "downloading" indicator when a file lands in ~/Downloads, clearing to a brief "done" state once the browser's temp file is renamed to its final name — presence + completion signal only, no exact percentage. `DownloadCoordinator` correlates matched temp-file suffixes (`.crdownload`/`.download`/`.part`) so concurrent downloads don't double-fire. First genuinely new file-watching subsystem this milestone, reused unmodified by nothing yet (Phase 67/Coding-Progress was meant to reuse this pattern but was never started). (Phase 61)

**Timer/Pomodoro (Phase 62 — TIMER-01, TIMER-02, TIMER-03, TIMER-04):**

- [x] Countdown/Pomodoro HUD startable from the notch — live mm:ss countdown, expanded pause/reset/add-time controls, a completion splash + notification sound on zero, and a Pomodoro mode cycling work/break durations with a session counter. Generalized `TransientQueue.preempt()`/`ActiveTransient.isPersistent` beyond the original single-`.focus`-case hardcode — proven here first (no detection risk) before Phase 63 (Meeting-HUD) reused the same generalized path. (Phase 62)

**Meeting-HUD (Phase 63 — MEET-01, MEET-02, MEET-03):**

- [x] `MeetingMonitor` (process-running + mic-active heuristic, isolated in one file) confirmed GO on-device before the full HUD was built; a real Zoom/Teams call with an active mic shows a live call-timer HUD, tapping its mute control toggles the system-wide mic mute via a shared `MicMuteController` (also reused unmodified by Phase 65's Quick Actions bar), and Google Meet (browser) correctly shows nothing — documented limitation, not silently missing. D-05a (discovered mid-UAT): nothing interrupts a standing call, not just Charging/Device as originally planned. (Phase 63)
  - **Verified at milestone close, not at phase execution:** `/gsd:verify-work 63` was never run when the phase's plans finished — closed retroactively during the v1.10 close-out. All 4 ROADMAP success criteria independently re-verified against the codebase plus a fresh full-suite run (582 tests, 7 pre-existing failures, 0 in Meeting-HUD). 3 post-UAT code-review fixes (CR-01 mid-call mute refresh, CR-02/CR-03 queue-drop semantics, WR-05 click-through re-sync) are code-verified/test-green but were never re-confirmed live on hardware — user explicitly accepted this rather than run a 3rd on-device UAT round. See `63-VERIFICATION.md`.

**Quick Actions Bar (Phase 65 — QACTION-01, QACTION-02, QACTION-03):**

- [x] A configurable, up-to-8-slot row of quick actions (mic mute/unmute, display sleep, dark/light mode toggle, screen lock, Do Not Disturb toggle, caffeinate/keep-awake toggle, empty Trash, launch app/open URL) — enabled and reordered from a Settings popover, fires instantly from the notch with no further expansion. Mic-mute reuses Phase 63's `MicMuteController` verbatim (no duplicated CoreAudio helper). (Phase 65 — QACTION-01, QACTION-02)
- [x] Do Not Disturb/Focus toggle is honest best-effort: no public write API exists on macOS, so it invokes a user-created Shortcut and always re-reads `INFocusStatusCenter` before/after, showing a visible red failure state rather than silently no-op'ing. (Phase 65 — QACTION-03)
- On-device UAT found and fixed 2 real bugs no build/unit-test gate could see: (1) the DND action only checked `FocusModeMonitor.isAuthorized`, which was previously granted only via the unrelated Phase-38 Focus HUD Settings toggle — a user who never touched that toggle got a permanent, unexplained failure flash; fixed by having the action request authorization itself. (2) A single Shortcut using Apple's "Set Focus" action can only be built as one-way (Turn On or Turn Off, no native toggle) — the app now reads its own "before" state and picks between two fixed one-way Shortcuts ("Islet Focus On"/"Islet Focus Off") instead of requiring the user to build conditional logic inside the Shortcuts app. (Phase 65)
- Post-execution code review found 1 critical (`visibleContentZone()` missing a dedicated `.quickActionsBarExpanded` branch, reopening the codebase's own documented click-swallowing dead-zone bug class) — fixed live, mirroring the existing `.trayExpanded` branch. 4 warnings/2 info items (switcher-icon enable-gating, DND failure-flash staleness, missing pure-function tests, a flaky authorization-dependent test, private-API risk note, `@MainActor` consistency) remain open as non-blocking backlog — see `65-REVIEW.md`. (Phase 65)

### Active

<!-- Current scope. Building toward these. All are hypotheses until shipped. -->

_v1.5 (Home Focus & Widget Redesign) shipped 2026-07-28 — all 11 requirements across 6 phases (29-34), all already on-device-verified since 2026-07-15. Tagged `v1.4` and `v1.5` together in this session's close-out. See `.planning/MILESTONES.md`._
_v1.7 (Interaction & Calendar Polish) — see "Milestone In Progress (Parallel): v1.7" above. Phases 43-48 (Drag Detection Hardening, Tray & Quick Action Width Alignment, View Switcher Morph Fix, Calendar Quick-Add — partial (CALVIEW-05 shipped, 06/07 pending), Audio Output Switcher pure-seam + UI wiring) shipped/code-complete. Remaining: Phase 46's CALVIEW-06/07, then a decision on Phase 49/50 (Favorite/Like, paused)._

- [ ] **NOTES-01/02/03** (Phase 64, Quick Notes + Obsidian Export): implementation exists but 3 major on-device UAT bugs are unfixed (no keyboard focus on popover open, delete button unclickable once the history list is scrolled, empty-state popover doesn't close), plus 2 user-approved scope changes never built (vault-file delete, file browser/switcher). Carried forward from v1.10 at its 2026-07-30 close. Needs `/gsd:plan-phase 64 --gaps`.
- [ ] **MENUBAR-01/02/03/04** (Phase 66, Menübar-Overflow): PAUSED after 3 consecutive on-device NO-GOs across two mechanisms (private CGS enumeration, then public `NSStatusItem` chevron+spacer) — even the reference app (Ice.app) failed identically on the third attempt. Root cause unconfirmed (possible macOS 27 "Golden Gate"/Developer Mode regression, untestable without a macOS 26 downgrade). Carried forward from v1.10 at its 2026-07-30 close, no revisit trigger set.
- [ ] **CODE-01/02/03/04** (Phase 67, Coding-Progress): never started. Carried forward from v1.10 at its 2026-07-30 close — not blocked, simply not reached before Phase 70 (a queued backlog idea) was worked ahead of it.

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Macs without a physical notch / simulated island on external displays — keeps v1 simpler; only notch Macs targeted for now
- Mac App Store distribution — Now Playing relies on Apple's private MediaRemote API, which is not allowed on the App Store; distribution will be direct + notarized (the same path Alcove/DynamicLake use)
- Messaging/notification mirroring (iMessage, WhatsApp, Slack), FaceTime/phone-call integration — DynamicLake-style extras deferred until the core island is solid. (Calendar/weather glance shipped in Phase 14 — no longer out of scope.)
- Cross-platform (Windows/Linux) — this is a macOS-native product

## Context

- **Builder experience:** The user is a complete beginner at programming. In the GSD workflow, Claude writes the implementation code and explains the important parts; the user steers, runs/tests, and handles setup steps. Approach favors a working result the user can later maintain and extend.
- **Reference apps (the bar to match/beat):**
  - **Alcove** (tryalcove.com) — visual/Dynamic-Island-focused: now-playing with album art + waveform + seek bar + volume via hover/gesture, volume/brightness/battery HUDs, live activities, heavy customization. Polished animations.
  - **DynamicLake Pro** (dynamiclake.com, ~$16.90) — function/workflow-focused: DynaMusic (media), DynaGlance (calendar+weather), DynaCall (calls), notifications (iMessage/WhatsApp/Slack), DynaClip (file shelf w/ AirDrop), DynaDrop (drag-drop actions), timer, AirPods/Bluetooth connect, also runs on non-notch Macs.
  - **Free/open-source references to study:** TheBoringNotch (open source, theboring.name) and Notchy (notchy.dev) — useful for seeing how the notch overlay + MediaRemote integration is done.
- **Design north star:** A mix of both — as polished as Alcove, as functional/tidy as DynamicLake.
- **Setup status:** MacBook with notch + Xcode already installed. No Apple Developer account yet (only needed later for notarization/selling).
- **v1.0 codebase state (shipped 2026-07-02):** ~4,500 LOC Swift across 7 phases (176 files touched total), 131 passing unit tests (`IsletTests`). Every threat register across the project's plans is dispositioned (mitigate/accept), verified in `06-SECURITY.md`.
- **v1.0.1 codebase state (shipped 2026-07-04):** +2 phases, 141 passing unit tests (`IsletTests`, up from 131). The fullscreen-enter island flash — previously accepted as permanent window-server-timing debt — is now genuinely fixed via a dedicated CGS Space (Phase 9).
- **v1.1 codebase state (shipped 2026-07-08, includes Phase 14):** ~6,900 LOC Swift, 185 passing unit tests (`IsletTests`, up from 141). Added Keychain-backed trial/license persistence, `PolarLicenseService`, a real Developer-ID notarization pipeline, and WeatherKit/EventKit services behind their own protocol seams. A real Apple Developer account and paid Polar.sh integration are now live (no more placeholders).
- **v1.3 codebase state (shipped 2026-07-11, includes Phases 15/16 architecture refactor + Phase 17/18 v1.2 + Phase 19-21 shelf):** ~9,200 LOC Swift, 261 passing unit tests (up from 185 at v1.1 close). Added the session-only shelf stack (`ShelfItem`/`ShelfLogic`/`ShelfFileStore`/`ShelfCoordinator`), its full view (icons, trash, click-to-open, gating), and outbound drag-to-Finder — all with zero persistence and zero coupling to `IslandResolver`/`TransientQueue`. Phase 22 (drag-in) code remains on disk but unshipped: 22-01 (spike) and 22-02 (pure seams) are merged; 22-03's `NotchPanel`/`NotchWindowController` wiring is not, and the debugging worktree with the failed attempts is preserved separately for reference (see STATE.md).
- **Known technical debt carried into next milestone planning:**
  - Four non-blocking code-review findings from `06-REVIEW.md`: inconsistent charging/device wing accent-tinting (WR-01), accent-change view-tree rehost breaking `matchedGeometryEffect` continuity (WR-02), a missing `withAnimation` wrapper on the Now-Playing health-check callback (WR-03), and a low-probability `BluetoothMonitor` data race (WR-04).
  - WR-01/WR-02 (Phase 9, info): `CGSSpace.swift` has no validation of CGS private-API return values, and assumes an `Int`/`Int32` width fits `CGSSpaceSetAbsoluteLevel`'s one passed value. Low severity.
  - Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised — pre-existing, unrelated to v1.0/v1.0.1/v1.1 close; tracked in `STATE.md` Deferred Items.
  - Pre-existing (v1.0-era): `xcodebuild test` hangs in non-interactive/sandboxed environments due to a Bluetooth TCC-authorization wait in `BluetoothMonitor` (also affects the full `Islet.app`'s WeatherKit/MediaRemote/IOBluetooth boot as of Phase 14 — gate on `xcodebuild build`, route test runs to manual Cmd-U). Logged in `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`.
  - Two non-blocking code-review findings from `15-REVIEW.md` (pre-existing behavior, not new regressions): `KeychainLicenseStore`/`SettingsView` can show "License activated" while silently swallowing a Keychain write failure (WR-01); `LocationProvider.requestOnce` would silently drop a first caller's completion under a hypothetical concurrent second call, currently unreachable (WR-02).
  - Two non-blocking code-review findings from `16-REVIEW.md` (pre-existing behavior, carried through the extraction verbatim): `DeviceCoordinator`'s post-connect battery-refresh retry checks device *shape*, not identity, and silently depends on two independently-maintained magic-number caps (`TransientQueue.maxDepth` and a hardcoded `> 2`) staying in lockstep — benign today, but could misattribute a battery reading to the wrong device if either cap changes independently later (WR-1); `deviceSuppressedAtLaunch` is a dead parameter, always an empty `Set` pending a deferred A2 on-device seed (WR-2).

## Constraints

- **Tech stack**: Native macOS — Swift + SwiftUI/AppKit — Web/Electron can't cleanly do a borderless notch overlay, MediaRemote integration, or HUD replacement; both reference apps are native
- **Platform**: macOS on Apple-silicon notch MacBooks only (v1) — narrows scope and avoids non-notch edge cases
- **API**: Now Playing depends on the private MediaRemote framework — works but blocks Mac App Store; plan for direct notarized distribution
- **Builder skill**: First-time programmer — phases must include a setup/foundations ramp; explanations accompany the important code; avoid unnecessary complexity
- **Distribution**: Direct download, code-signed + notarized — requires an Apple Developer account ($99/yr) before any public release (not needed for local development)
- **Budget**: Hobby/personal budget — no paid services assumed beyond the eventual Developer account

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native Swift (SwiftUI/AppKit), not Electron/web | Only native can render a borderless notch overlay + use MediaRemote + replace HUDs; both reference apps are native | ✓ v1.0 shipped — validated, no framework wall hit |
| Target only notch Macs in v1 | Removes simulated-island/non-notch complexity; user has a notch MacBook | ✓ v1.0 shipped |
| Focused v1 (island + Now Playing + charging/device activity) before shelf/HUDs/timer | Beginner project — get something polished and working early, then expand | ✓ v1.0 shipped — scope held, file shelf/HUDs/timer correctly deferred to v1.1+ |
| Direct notarized distribution, not Mac App Store | MediaRemote is a private API → App Store rejection; direct sale is the proven path (Alcove/DynamicLake) | ✓ Pipeline proven (dry-run) — real notarization blocked on Apple Developer account purchase |
| Design = polished (Alcove) + functional (DynamicLake) blend | User likes both and wants to match their quality | ✓ v1.0 shipped — spring morph + accent theming delivered |
| Product name TBD | "Notch" is a working title only; real name decided closer to release | — Still pending — decide before public release |
| Island opens on CLICK; hover only gives a haptic + bounce affordance (D-02) | Alcove model — prevents accidental expansion when the pointer merely passes over the notch | ✓ Phase 2 |
| Fullscreen detected via private CGS managed-display-spaces (current-space type==4), not NSScreen safe-area | A background agent's safe area never reflects another app's fullscreen; CGS Spaces is permission-free and reference-app-proven | ✓ Phase 2 |
| Charging activity is connect-only (plug-in animates; unplug shows nothing) | On-device UAT call — only the connect moment should animate; an unplug cue felt unnecessary | ✓ Phase 3 (CHG-02 descoped) |
| Charging "wings" sized to the measured notch (179×32 pt → wings 305×32, flush height) | Notch measured live via NSScreen safeAreaInsets + auxiliary top areas; matching the height avoids overhang, width tuned on-device | ✓ Phase 3 |
| All MediaRemote access isolated behind one `NowPlayingMonitor`/`NowPlayingService` protocol, with a launch-time health check | The private-API bridge (`mediaremote-adapter`) is the single most likely thing Apple disrupts; isolation makes a future break a one-file swap | ✓ Phase 4, hardened in Phase 6 (06-11 protocol extraction) |
| Phase 5 (device-connected activity) scope folded into Phase 6 rather than executed standalone | Phase 6's priority-resolver work needed the device input anyway; building it once inside Phase 6 avoided rework | ✓ v1.0 shipped — DEV-01/DEV-02 delivered via 06-02/06-04; Phase 5 formally marked superseded |
| Single pure `IslandResolver` (ranked reduce) + bounded `TransientQueue` as the ONE arbiter for all activity priority | Prevents scattered if-chains across the view/controller layer; keeps priority logic testable in isolation | ✓ Phase 6 — 14+ unit tests, WR-1/WR-2 defects found and closed in gap-closure |
| Real Developer-ID notarization deferred until a paid Apple Developer account exists ($99/yr) | Explicit budget constraint (CLAUDE.md); dry-run pipeline proves the mechanics without the cost | Accepted, formally overridden in `06-VERIFICATION.md` — revisit before any public v1.0 release |
| FS-01 scoped as a full root-cause elimination, not a best-effort/partial reduction | v1.0's reactive `orderOut` approach was already confirmed insufficient; a partial mitigation would just re-accumulate the same polish debt | ✓ Phase 9 — Phase 8's candidate disproven and honestly escalated rather than shipping a partial fix; Phase 9 achieved a genuine fix |
| Phase 9's Candidate C (dedicated max-level CGS Space) implemented as ADDITIVE, not a replacement of `.canJoinAllSpaces` | The only variant with real shipping precedent in researched reference apps (`Ebullioscopic/Atoll`, `TheBoredTeam/boring.notch`); removing `.canJoinAllSpaces` deferred as a separate, never-combined follow-up | ✓ Phase 9 — resolved FS-01 on the first wave, zero regressions on-device |
| v1.0.1 (not v1.1) for the progress-bar + flash-fix milestone | App not yet publicly released — continuing under the v1.0 line rather than bumping to v1.1 until an actual release happens | ✓ Shipped 2026-07-04 — next milestone now free to become v1.1 |
| v1.1 bundled the paywall with real notarization in one milestone, not split | Shipping a paywall without real notarization means every paying customer's first launch is a Gatekeeper warning — a broken first impression for something just paid for; explicit user call | ✓ v1.1 shipped 2026-07-08 |
| Phase order within v1.1: Trial/lockout (10) → Settings UI on a stub (11) → real Polar.sh (12) → notarization (13) | De-risked the single-arbiter `shouldShow(...)` and the UI state machine before live network flakiness was introduced; notarization is functionally independent, sequenced last for release-readiness only | ✓ v1.1 shipped — no rework needed when the stub was swapped for the real service |
| Trial-start and license state stored in the Keychain, not UserDefaults/plist | UserDefaults-only trial storage is trivially reset via `defaults delete` — research pitfall | ✓ Phase 10 — verified on-device (survives `defaults delete` + reinstall) |
| License validation distinguishes "invalid key" (4xx) from "couldn't reach the server" (network/5xx) | Highest-consequence pitfall identified in research — a hard lock on a key someone just paid for would hit customers at peak purchase-regret risk | ✓ Phase 12 — strict HTTP→verdict split + Retry, verified on-device |
| Phase 14 (weather/calendar/date) executed inside the v1.1 working window but excluded from the v1.1 milestone close | Its requirements (WEATHER-01/CAL-01/OUTFIT-01) were never part of v1.1's Milestone Goal or REQUIREMENTS.md — closing v1.1 as Phases 10-13 keeps the archive accurate to what was actually scoped | Phase 14 stays on the live ROADMAP as completed, unarchived work — formal requirement capture deferred to next milestone |
| Song-change toast: skip (not queue/interrupt) when Charging/Device splash is active; suppress entirely while manually expanded; rapid skips restart the timer in place rather than queueing each one | Mirrors existing `resolve()` precedence and `TransientQueue.updateHead()`/Phase 17 D-03 gate precedents rather than inventing new queueing logic | ✓ Phase 18 — all three rules verified on-device |
| Toast design iterated on-device across 5 rounds to a minimal fading text row under the unchanged wings capsule, with its own independent ~2s dismiss (not the shared 3.0s `activityDuration`) | User's on-device feedback overrode the pre-execution 18-UI-SPEC.md draft each round; final shape ships shorter and simpler than originally speced | ✓ Phase 18 — approved after round 5, UI-SPEC updated to match |
| v1.3 phase order 19→20→21→22 (model → view → drag-out → drag-in) with the drag-in risk isolated in the final phase | Pure-seam-first is this project's established convention; isolating the one genuinely uncertain integration point (drag delivery through the click-through `NSPanel`) meant a spike/iteration there wouldn't block the rest of the feature | ✓ Phases 19-21 shipped clean; Phase 22 isolation worked exactly as intended — the failure stayed contained to Phase 22 |
| v1.3 closed as shipped-with-a-known-gap rather than left permanently open | SHELF-01/02 (drag-in) blocked twice on-device with an unidentified root cause; leaving v1.3 open indefinitely while pursuing a broader architecture redesign would misrepresent what actually shipped (data model, view, drag-out are real, verified, and independently valuable) | ✓ v1.3 shipped 2026-07-11 — SHELF-01/02 carried forward as requirements into v1.4 |
| Phase 22 drag-in abandoned in favor of a NotchPanel/NotchWindowController architecture redesign, rather than continuing incremental debugging | Two on-device UAT failures with `draggingEntered` never firing, root cause unidentified even after restoring the 22-01 spike's exact working technique — explicit user call to stop debugging blind and reconsider the window/panel architecture more broadly (referencing TheBoringNotch/DynamicNotchKit) | ✓ Phase 23 shipped 2026-07-11 — shell rebuilt with zero behavioral regression, on-device UAT approved; Phase 24 can now retry drag-in on the reproven shell |
| v1.4 scope expanded beyond the architecture redesign to include Droppy-inspired onboarding, visual redesign, and a calendar view — but explicitly NOT gesture-based swipe navigation | User found a competitor app ("Droppy") on Reddit during v1.3's blocked window; gestures would touch the same event-delivery layer that just failed and was deliberately kept out of scope until the architecture redesign proves itself first | Pending — v1.4 scoping in progress |
| Phase 25 (Visual/Material Theming) executed ahead of Phase 24 (Drag-In) in numeric order | Pure rendering-value change with no dependency on the architecture redesign's drag-in outcome — could ship independently without blocking or being blocked | ✓ Phase 25 shipped 2026-07-11 — gradient material + spring retune, on-device UAT approved |
| Minimum macOS deployment target raised 14.0 → 15.0 (revises Phase 0's original D-06 "macOS 14.0 floor") | Phase 26 on-device UAT found Settings re-opening at launch via AppKit's own window-state restoration (independent of app logic, surfaced by repeated Xcode Stop/Cmd-R cycles during testing); the fix is `.defaultLaunchBehavior(.suppressed)` (macOS 15+ only), and SwiftUI's `SceneBuilder` has no `if #available`/type-eraser path to keep it optional — pre-release project, dev hardware is already macOS 26, explicit user approval | ✓ Phase 26 — `project.yml` updated (all 5 deploymentTarget/MACOSX_DEPLOYMENT_TARGET entries), clean rebuild verified |
| "Home" shows Now-Playing controls when something is playing, idle glance otherwise — reverses the original v1.4 research note ("keep the idle default, don't copy Droppy's music-default") | User re-decided live on-device during Phase 28's checkpoint, after finding the original design made Now-Playing an unreachable, switcher-blocking override rather than a selectable state; explicitly confirmed via an orchestrator clarifying question before implementation, not a silent drift | ✓ Phase 28 — resolver precedence rewritten so explicit Tray/Calendar/Weather selection always wins, Now-Playing only wins on Home |
| Switcher pill expanded from the originally-locked 3 icons (Home/Tray/Calendar, D-01) to 4 (adds Weather) | User's own on-device request mid-checkpoint, after the 3-icon design already shipped through 3 rounds of UAT; Weather reuses existing current-conditions data only — no new WeatherKit forecast call was added without asking first | ✓ Phase 28 — `SelectedView`/`IslandPresentation` both gained a `.weather`/`.weatherExpanded` case |
| Tray became its own dedicated files-only resolver case (`.trayExpanded`) instead of the originally-planned additive shelf-strip-under-Home approach | User's on-device comparison against Droppy's actual Tray page, which shows only files, never glance content underneath; the original additive design (Phase 20/28 D-02) was kept for auto-reveal-on-drop from OTHER tabs, which stays unbroken | ✓ Phase 28 — `forcedByTray` removed as dead code once Tray had its own presentation case |
| Liquid Glass material pivoted to SwiftUI's native `.glassEffect()` on macOS 26+, with the custom Metal shader stack (D-01–D-19) kept as the <26 fallback | A round-5 post-completion regression (flat grey rim) surfaced after 4 rounds of shader-based on-device UAT remediation already got GLASS-01 approved; native `.glassEffect()` matched the target look with far less shader-tuning risk going forward | ✓ Phase 35 — D-20, both paths shipped |
| Phase 37 (Drop-Session Summary Chip) abandoned rather than redesigned | The chip's Tray-close trigger requires an explicit close action, but in real usage the Island stays open showing dropped files and isn't closed right away — the trigger essentially never fires under normal use; user decided the feature isn't worth keeping | ✓ All 3 implementation plans reverted via `git revert`, HUD-07 dropped from the v1.6 requirement set |
| Focus Mode detection uses `INFocusStatusCenter` Path A (polled `isFocused`), not the Assertions.json/FDA fallback (Path B) | An on-device spike confirmed Path A reaches `.authorized`; Path B needs a manual, unprompted Full Disk Access grant with zero automatic TCC prompt — worse UX for the same generic on/off signal | ✓ Phase 38 — shipped, though `isFocused` also silently required the undocumented Communication Notifications entitlement beyond authorization, found only via 38-09's actual functional read |
| Volume/Brightness native OSD suppression re-attempted and shipped via `.cghidEventTap`, reversing Phase 39's own initial "unreliable" spike finding | `.cgSessionEventTap` (session-level) didn't suppress the notch-integrated OSD on this hardware, but `.cghidEventTap` (HID-level, before the Window Server session layer) does, confirmed via `dannystewart/volumeHUD`'s (MIT) proven technique | ✓ Phase 39 gap-closure (39-08) — zero transport-key regressions across all 4 media keys on real hardware |
| Update-available indicator redesigned from a collapsed-pill corner badge to a menu-bar status-item dot | On-device UAT root-caused the badge's tap-dispatch bug to a click-through hot-zone gap in `NotchWindowController` — the status-item dot is always fully clickable by construction, sidestepping the whole click-through-zone bug class rather than patching the geometry | ✓ Phase 40 — `UpdateAvailableState.swift` and the pill badge overlay deleted |
| Dual-activity secondary bubble's interaction redesigned live from tap-to-expand/no-hover (locked D-12/D-13) to hover-reveal play/pause | User's explicit on-device UAT round-3 decision, not scope drift — hovering darkens the bubble and reveals a play/pause glyph, tapping toggles playback directly via the existing `NowPlayingMonitor` | ✓ Phase 42 — see `42-04-SUMMARY.md`/`42-CONTEXT.md` supersession notes |
| Hover-to-resume preview (Phase 53) shipped as a view-local branch off `.idle` in `NotchPillView`, not a new `IslandResolver` case | `IslandResolver.resolve()` has exactly one call site; threading a new hover-flag parameter through it plus new resolver-test coverage was a larger diff for a purely presentational affordance the phase's own discussion left to discretion | ✓ Phase 53 — `IslandResolver.swift`/`IslandResolverTests.swift` confirmed untouched |
| Resume-preview's right-slot visual superseded from bouncing `EqualizerBars` (D-02) to a static `play.fill` glyph | On-device UAT (53-02) found animated bars while nothing was actually playing misrepresented playback state — user flagged it live ("macht gar keinen Sinn das die bars sich dann im idle zustand bewegen") | ✓ Phase 53 — both Debug and Release re-verified green after the fix |
| v1.9 phase order 55→56→57→58 (data model → encrypted persistence → pasteboard-monitor spike → menu wiring) | Mirrors this project's own pure-seam-first/system-glue-second/assembly-last convention (Phase 19-21 Shelf, Phase 47-48 Audio Output); encryption established from day one rather than retrofitted, the one on-device-only spike isolated so it can't destabilize the proven pure work | ✓ v1.9 shipped 2026-07-23 — no rework needed across phase boundaries |
| Clipboard history rows moved from an inline top-of-menu list to a flyout submenu behind a single "Clipboard History" anchor (D-15 REVISED) | User's live on-device request during Phase 58 UAT, to see more entries at once; Cmd+0-9 kept working instantly via a hybrid `menuWillOpen`/`menuDidClose`-scoped NSEvent keyDown monitor, since submenu key equivalents don't fire while the submenu is closed | ✓ Phase 58 — approved on-device, CLIP-03 unaffected |
| v1.4 closed via a lightweight ceremony (MILESTONES.md entry + git tag + this file's evolution review) instead of the standard `/gsd-complete-milestone` archival flow | This project runs v1.4/v1.5/v1.7/v1.10 open in parallel by design; the standard flow's archival step deletes `REQUIREMENTS.md` wholesale, which would have destroyed the still-live v1.5/v1.7/v1.10 sections since v1.4 no longer has its own section there | ✓ v1.4 shipped 2026-07-28, tagged `v1.4` — ROADMAP.md/REQUIREMENTS.md left untouched |
| Phase 66 (Menübar-Overflow) paused rather than descoped after a third consecutive NO-GO | Even real Ice.app's own mechanism stopped working on this exact machine — the reference implementation itself is broken, not just Islet's port of it; user still wants the feature but declined a full macOS 26 downgrade just to test the Developer-Mode hypothesis | ✓ Phase 66 paused 2026-07-28, no revisit trigger — see `66-CONTEXT.md` third revision |
| v1.5 closed via the same lightweight ceremony as v1.4, discovered to already be fully done | A milestone-by-milestone clean-up pass found all 6 v1.5 phases were code-complete and on-device-verified since 2026-07-14/15, contradicting this file's own stale status line ("Phase 33 UAT pending") — the closing ceremony had simply never been run, and 4 of 6 phases were missing Validated entries too | ✓ v1.5 shipped 2026-07-28, tagged `v1.5` — ROADMAP.md/REQUIREMENTS.md left untouched |
| v1.10 closed as Phases 59-63/65 rather than the originally-scoped 59-67 | A prior session incorrectly treated finishing Phase 70 (a standalone backlog phase, not part of v1.10's own 59-67 range) as completing v1.10; the actual `/gsd-complete-milestone` run found Phase 63 unverified, Phase 64 had 3 unfixed major UAT bugs, Phase 66 was paused, and Phase 67 was never started — closing on inflated scope would have misrepresented what actually shipped | ✓ v1.10 shipped 2026-07-30, tagged `v1.10` — 64/66/67 carried forward as Active requirements, not descoped |
| Phase 63 (Meeting-HUD) verified retroactively at milestone close via `/gsd:verify-work`, its 3 post-UAT code-review fixes accepted without a live re-test | The phase's own plans never triggered the orchestrator-level verify-work gate; rather than block the whole milestone on a 4th on-device UAT round for edge-case fixes already code-verified and test-green, the user chose to accept them as-is | ✓ Phase 63 verified 2026-07-30 — `63-VERIFICATION.md`, user override recorded |
| MENUBAR-01/02/03 corrected from Complete to Not delivered in REQUIREMENTS.md at v1.10 close | Found stale during the close's requirements audit — Phase 66 never actually shipped (3 consecutive on-device NO-GOs, including the reference app Ice.app itself failing) despite the traceability table claiming Complete | ✓ Corrected 2026-07-30, archived accurately in `v1.10-REQUIREMENTS.md` |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-31 — Phase 72 (Calendar Redesign, second phase of v1.11) shipped: CALVIEW-08/CALVIEW-09 complete, goal-backward verified 9/9, code review clean (3 non-blocking warnings tracked in `72-REVIEW.md`). On-device UAT drove a live scope revision — the whole-month day-grouped agenda (original D-01/D-02) was reverted to single-day after the user's live reaction, with 5 new hover-affordance decisions (D-13-D-17) added instead; recorded in `72-CONTEXT.md`. Phase 71 (Island Corner Rounding, first phase of v1.11) shipped 2026-07-30: SHAPE-02/SHAPE-03 complete, goal-backward verified 4/4, code review clean after one Critical finding fixed (corner-radius clamp centralized in `NotchShape.path(in:)`). Milestone v1.11 (Droppy-Inspired Polish Round 2) started via `/gsd-new-milestone`, scoped to the 4 remaining Droppy-inspired ideas from the 2026-07-29 brainstorming session (island-corner-rounding, calendar-redesign-droppy, timer-slider-redesign, music-next-up-queue). v1.10 (Live Activities Suite) formally closed 2026-07-30 via `/gsd-complete-milestone`, corrected from its originally-scoped Phases 59-67 down to Phases 59-63/65 (16/27 requirements). A prior session had incorrectly treated Phase 70 (a standalone backlog phase, not part of v1.10) as completing the milestone. At close: Phase 63 (Meeting-HUD) was retroactively goal-backward verified (PASS, 3 post-UAT fixes accepted without live re-test, user override recorded); Phase 64 (Quick Notes) was found to have 3 unfixed major on-device UAT bugs plus 2 unbuilt approved scope changes and carried forward; Phase 66 (Menübar-Overflow, already paused) and Phase 67 (Coding-Progress, never started) also carried forward. A stale REQUIREMENTS.md bug was caught and fixed (MENUBAR-01/02/03 had been marked Complete despite Phase 66 never shipping). Archived to `.planning/milestones/v1.10-ROADMAP.md`/`.planning/milestones/v1.10-REQUIREMENTS.md`, tagged `v1.10`. v1.4 (Architecture Redesign) and v1.5 (Home Focus & Widget Redesign) both formally shipped 2026-07-28 in an earlier clean-up session — see prior Key Decisions rows for that session's detail. v1.9 (Clipboard History) shipped and archived to `.planning/milestones/v1.9-ROADMAP.md`/`.planning/milestones/v1.9-REQUIREMENTS.md` (Phases 55-58, 7/7 requirements). v1.7 (Interaction & Calendar Polish) remains open in parallel (explicit user decision) — paused at Phase 49 (Favorite/Like spike aborted, Phase 50 undecided) with Phases 43-48 shipped/code-complete and Phase 46's CALVIEW-06/07 still pending. v1.8 (Settings Redesign & Island Navigation) shipped 2026-07-21, archived to `.planning/milestones/v1.8-ROADMAP.md`/`.planning/milestones/v1.8-REQUIREMENTS.md`.*
