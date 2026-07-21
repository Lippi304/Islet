# Milestones

## v1.8 Settings Redesign & Island Navigation (Shipped: 2026-07-21)

**Phases completed:** 3 phases (51-53), 7 plans, 17 tasks, 48 phase commits, 48 files changed (+6.3k/-229 lines)

**Key accomplishments:**

- `SettingsView.swift` split from a single crowded General tab into a 7-section `NavigationSplitView` sidebar (Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About) with uniform `ScrollView` wrapping — fixing the Weather/Diagnostics scroll-cutoff bug — plus an on-device UAT-driven window widen (520→600pt) for Appearance picker clipping.
- New top-edge switcher layout: `SelectedView`/`ActivitySettings` gained a `SwitcherLayout` enum and 4 independent per-slot `@AppStorage` keys, `NotchPillView` renders 4 icons flanking the camera cutout using the real notch-cutout-gap formula, and a new Settings "Switcher" section wires it all together, fully hidden on displays without a physical notch.
- Full 403-test XCTest suite + Release build confirmed green across all landed plans, and the user approved the complete on-device walkthrough on real notched hardware ("Klappt alles wunderbar"), closing SWITCH-03/SWITCH-04.
- Idle-island hover-to-resume preview reusing the live Now Playing wings' layout (album art left, right slot for status) with click-to-resume via the existing `togglePlayPause()` transport call and a D-03 inferred-timeout failure text, gated behind an on-device-confirmed spike of the resume-of-a-stopped-session open question.
- On-device UAT (Debug + Release) approved all 4 ROADMAP Phase 53 success criteria, closing RESUME-01/RESUME-02 — with one live design correction: the hover-preview's right slot ships a static play glyph instead of the originally-shipped bouncing equalizer bars, since animated bars while nothing was playing read as misleading (D-02 superseded).
- The milestone's one open technical question — whether `NowPlayingMonitor`/MediaRemote can resume a non-active track — was verified empirically early in Phase 53 rather than assumed, de-risking the rest of the phase.

---

## v1.6 Liquid Glass & System HUD Suite (Shipped: 2026-07-19)

**Phases completed:** 8 phases (35-42), 43 plans, 191 phase commits, 185 files changed (+28.5k/-244 lines)

**Key accomplishments:**

- Replaced the shared background material across the collapsed pill, expanded island, and every activity wing with a shader-based "Liquid Glass" look — 4 rounds of on-device UAT remediation (opaque grey → uniformly bright → washed-out silvery → approved), then pivoted to SwiftUI's native `.glassEffect()` on macOS 26+ after a post-completion regression, keeping the custom Metal shader stack as the `<26` fallback.
- Shipped 5 new/restyled collapsed-state system HUDs (Bluetooth/Charging Droppy-pill restyles, Focus Mode, Volume/Brightness, Update-available) plus a redesigned equalizer and a static rainbow-gradient onboarding signature heading.
- Genuine native-OSD suppression for Volume/Brightness key presses, reversing an initial "unreliable" spike finding: `.cghidEventTap` (HID-level) works where `.cgSessionEventTap` (session-level) didn't — Islet now self-drives real system volume/brightness/mute with a per-type kill-switch fallback, confirmed zero transport-key regressions across all 4 media keys on real hardware.
- Real Sparkle 2 auto-update integration; the update-available indicator was redesigned mid-phase from a collapsed-pill badge to a menu-bar status-item dot after on-device UAT root-caused its tap-dispatch bug to a click-through hot-zone gap — the same fragility class later independently re-found and fixed in the Dual-Activity Display phase.
- A live-minute Calendar Countdown HUD with its own persistent timer, and a new dual-activity display concept (`IslandResolver.resolveSecondary()`) showing a secondary bubble alongside the main pill when two top-priority activities are live at once — its tap-to-expand interaction was redesigned live during on-device UAT to hover-reveal play/pause, by explicit user decision.
- Phase 37 (Drop-Session Summary Chip) was fully implemented then abandoned after on-device UAT found its Tray-close trigger essentially never fires in real usage — all code reverted via `git revert`, HUD-07 dropped from scope rather than shipped as dead weight.

**Known Gaps**

- HUD-07 (Drop-Session Summary Chip) not shipped — see above; dropped from v1.6's requirement set by explicit user decision, not carried forward.

---

## v1.3 Notch Shelf (Shipped: 2026-07-11)

**Phases completed:** 3 phases (19-21), 5 plans, 12 tasks

**Key accomplishments:**

- Pure Foundation-only ShelfItem/ShelfLogic/ShelfFileStore/ShelfCoordinator stack — real FileManager session-temp copy-in on add and delete-on-removal wired through a thin coordinator, zero persistence path, zero AppKit/SwiftUI/IslandResolver coupling.
- Shelf strip renders inside the expanded island (file-type icons, per-item trash, delete-all trash) as a conditionally-taller extension of the existing blobShape, with a regression test proving SHELF-09's transient-outranks-expanded gating needed zero new resolver code.
- `NotchWindowController` now owns a real `ShelfCoordinator`, routes tap/delete/clear-all through it with the D-04 missing-file guard, reserves the panel's window height for the shelf band unconditionally, and hand-seeds 3 real on-disk sample files in DEBUG builds.
- Scoped `syncClickThrough()`'s hit-test to the actual visible blob rect (`visibleContentZone()`) instead of the full static panel, closing the invisible 56pt click-swallowing band under an empty shelf, and extracted a single `resyncShelfViewState(animated:)` helper so shelf delete/clear-all animate with the standard spring instead of snapping instantly.
- Drag-out shipped: a shelf item can be dragged onto Finder or any other app via `.onDrag` + `NSItemProvider(contentsOf:)`, with a drag-pin keeping the island open for the gesture's duration and a UAT-discovered auto-prune for items whose backing file vanished externally.

### Known Gaps

- **SHELF-01, SHELF-02 (drag-in) — not shipped.** Phase 22 spiked successfully (AppKit drag delivery does reach a click-through `NSPanel`) but then hit a second, separate blocker on-device twice: dragging never reached `NotchPanel` at all (`draggingEntered` never fired) even after restoring the working spike's `draggingUpdated(_:)` handler — root cause never identified. Rather than continue debugging incrementally, the user chose to abandon the current `NotchPanel`/`NotchWindowController` architecture in favor of a broader redesign (see v1.4). SHELF-01/02 carry forward as requirements into v1.4; Phase 22's pure seams (22-02) remain merged and reusable, Phase 22's debugging worktree is preserved for reference (see STATE.md).

---

## v1.2 Now Playing Polish (Shipped: 2026-07-09)

**Phases completed:** 2 phases, 3 plans, 9 tasks

**Key accomplishments:**

- hasPlayedSinceLaunch flag + nowPlayingLaunchGate pure helper gate the ambient Now Playing wings glance until a real Play is observed this Islet session — on-device verified and approved.
- Pure, unit-tested Foundation-only detection/suppression seam for the song-change toast (TrackToast + songChangeToastContent + songChangeToastGate) plus the NOW-06 Settings toggle — no user-observable behavior ships yet, this locks the contracts Plan 02 wires against.
- Wires Plan 01's pure seam end-to-end: handleNowPlaying detects a genuine song change, gates it through songChangeToastGate, drives an independent ~2s auto-dismiss timer, and NotchPillView renders it as the existing wings capsule growing a small fading text row underneath (title — artist), refined over 5 on-device feedback rounds to match a DynamicLake-style reference.

---

## v1.1 Trial & Paid Release (Shipped: 2026-07-08)

**Phases completed:** 4 phases, 11 plans

**Key accomplishments:**

- Tamper-resistant 3-day trial: start timestamp persisted to the Keychain (survives `defaults delete` and reinstall), a one-time first-launch notice, and a hard lockout (no pill, no activities) at expiry that unlocks at the next natural UI transition rather than an abrupt yank.
- License Settings UI proven end-to-end against a fake in-memory `LicenseService` — days-remaining display, Buy Now, and an idle→validating→success/failure activation state machine — before any live network call existed.
- Swapped the stub for a real `PolarLicenseService`: live Polar.sh checkout in the default browser, online key validation with a strict HTTP→verdict mapping that never hard-locks a key just paid for on a transient network error, and Keychain-cached validated state so the app keeps working fully offline afterward.
- Real Developer-ID sign → notarize → staple pipeline replacing the v1.0 dry-run placeholders — fixed two real bugs along the way (embedded frameworks need explicit re-signing before the outer `.app`; `notarytool` requires a zip/pkg/dmg, not a raw `.app`). `spctl --assess` confirmed accepted, no Gatekeeper warning on first launch.
- Also shipped in the same window, ahead of formal milestone scope: a weather + calendar + date glance (Phase 14) in the expanded idle view, on-device verified — needs its own requirement IDs captured at the next milestone.

**Known deferred items at close:** Phase 02's 8 pending UAT scenarios + its verification gap (pre-existing since v1.0 close); CR-01 CGS Space leak on quit and WR-01..04 code-review findings (pre-existing since v1.0/v1.0.1 close) — see STATE.md Deferred Items.

---

## v1.0.1 Pre-Release Polish (Shipped: 2026-07-04)

**Phases completed:** 3 phases, 9 plans (4 executed with code, 4 conditional no-ops, 1 precondition-skipped)

**Known deferred items at close:** 3 (see STATE.md Deferred Items — pre-existing Phase 2 UAT/verification gaps, carried over unchanged from v1.0 close, unrelated to Phases 7-9)

**Key accomplishments:**

- Extended the Now Playing pure seam, monitor, and state to carry playback position, then rendered a display-only progress bar (accent-filled capsule track + m:ss labels) in the expanded island — gliding continuously while playing, frozen while paused, zero tap-to-seek.
- On-device UAT caught a pause-transition backward-flash bug; fixed via a drift-corrected freeze estimate (`resolvePublishedPosition`), then closed a NaN/Infinity crash risk found in code review. 141/141 tests green, on-device re-verified and approved.
- Built a DEBUG-only CGS event 106/107 timing probe and ran the on-device D-05 trigger matrix across all 3 fullscreen-entry methods — found the candidate signal never fires cross-process, disproving it with concrete on-device evidence rather than reasoning alone.
- Reverted all exploratory Phase-8 code byte-for-byte and wrote a rigorous root-cause escalation report (`08-ESCALATION.md`), surfacing an explicit scope decision to the user rather than silently shipping a partial fix.
- Added a dedicated max-level private CGS Space (`CGSSpace.swift`) that the notch panel joins once at creation, additive to the existing `.canJoinAllSpaces` behavior — eliminated the fullscreen-enter island flash entirely, confirmed on-device across all 3 trigger methods with zero regressions across an 8-item checklist.
- One non-blocking follow-up (CR-01: the new CGS Space leaks in WindowServer on normal app quit) identified in code review and tracked as backlog rather than blocking the milestone.

---

## v1.0 v1.0 MVP (Shipped: 2026-07-02)

**Phases completed:** 7 phases, 34 plans, 55 tasks

**Key accomplishments:**

- Islet now exists as a runnable menu-bar-only background agent: no Dock icon, a monochrome SF-Symbol status item with a "Settings…" / "Quit Islet" dropdown, and a (placeholder) Settings window — built in Swift 5 mode against the macOS 14.0 floor with bundle id com.lippi304.islet.
- The Settings window now has a working "Launch Islet at login" toggle wired to SMAppService.mainApp (status-driven, reverts on failure) and a version label reading 1.0 (1) — and the menu-bar agent now behaves correctly: closing/hiding the Settings window no longer quits it, and the window no longer auto-opens on launch.
- A single commented `scripts/release.sh` runs archive→sign→hdiutil-dmg→notarize→staple, with Developer-ID/notary steps gated behind two clearly-marked placeholders and an ad-hoc fallback that skips notarization cleanly — runnable now, unchanged at Phase 6.
- `scripts/release.sh` ran end-to-end to produce an ad-hoc-signed `dist/Islet.dmg` (notarize/staple cleanly skipped), and the local Gatekeeper block was demonstrated and recorded: the quarantined, un-notarized build is `rejected` by `spctl --assess` — with the real Phase-6 notarization carry-over documented.
- IsletTests XCTest target plus two pure, fully-unit-tested seams — NotchGeometry (ISL-01: hasNotch/notchSize/notchFrame with the +4 fudge and AppKit coordinate flip) and DisplayResolver (ISL-06: built-in-notched selection by property, nil for clamshell/non-notch) — that Plan 02 wires NSScreen against.
- A running, focus-safe, click-through notch overlay: a borderless non-activating `NotchPanel` (all-Spaces, `.statusBar` level) hosting a static black `NotchShape` pill via `NSHostingView`, positioned on the built-in notched display through Plan 01's pure seam (`selectTargetScreen` + `notchFrame`, widthFudge 4), re-resolved on every `didChangeScreenParametersNotification` (hides in clamshell), and wired into `AppDelegate` at launch.
- All four MANUAL-only Phase-1 criteria signed off on real macOS 26 notch hardware with zero code changes: the pill hugs the notch over the menu bar (A2 → `.statusBar` ships), stays above all windows across Spaces with no focus theft / full click-through (ISL-02 / D-07), tracks the built-in display and hides+recovers across clamshell (ISL-06 / A3), and ships near-invisible and static in release (ISL-07).
- Four pure, unit-tested logic seams — expandedNotchFrame geometry (ISL-04), the hover/click/grace nextState machine + NotchInteractionState (ISL-03), and isTrueFullscreen + the unified shouldShow visibility decision (ISL-05) — established RED→GREEN before any AppKit/SwiftUI wiring exists.
- The static Phase-1 pill becomes a Dynamic-Island morph: collapsed and expanded blobs share one `matchedGeometryEffect(id: "island")` on a single `@Namespace`, bound to `NotchInteractionState`, with a compact date/time placeholder as the expanded target and a hover-scale bounce — no cross-fade, no Core Animation, no internal animation driver.
- The static morph view becomes the live Alcove interaction: a global NSEvent `.mouseMoved` monitor hit-tests the pointer against the pill hot-zone and drives the pure `nextState` machine — hover fires a trackpad haptic + bounce without expanding (D-01), a click expands with the spring morph (D-02), pointer-leave collapses after a 0.4s grace delay that a re-entry cancels (D-03) — while `ignoresMouseEvents` is flipped false only inside the hot-zone and the panel is shown only via `orderFrontRegardless()`, so clicking the island never activates Islet or steals focus and clicks outside pass through (D-04).
- The island now hides on true (native) fullscreen of the built-in display and auto-restores on exit, driven at runtime by a CGS managed-display-spaces probe (current-space type==4) fed into a single unified updateVisibility() — replacing the safe-area heuristic that a background agent could never observe.
- Pure, unit-tested power→presentation seam (PowerReading → ChargingActivity, clamped, nil-on-no-battery, category-transition splash debounce) plus a separate ChargingActivityState model and a wingsFrame geometry extension — the contracts every later Phase-3 wave implements against.
- The visual half of the charging splash: a flat, wide WINGS / Alcove layout in `NotchPillView` (status symbol left, ONE filling `battery.100percent[.bolt]` glyph + numeric % right) that renders whenever a `ChargingActivity` is published and takes D-11 precedence over the expanded island — driven purely by the Plan-01 `ChargingActivityState`, sharing the `id:"island"` morph, and driving no animation/timer/IOKit itself.
- The system glue that makes the charging splash live: a `PowerSourceMonitor` registers an IOKit `IOPSNotificationCreateRunLoopSource`, recovers self via the context pointer and hops to main, and `NotchWindowController` maps each plug/unplug through the pure Plan-01 seam into the published `ChargingActivityState` — showing the wings splash for ~3s through the single `updateVisibility()` (so it's hidden in fullscreen) with no polling timer. On-device UAT passed after two product-tuning changes: the splash is now CONNECT-ONLY (no unplug animation) and the wings are sized to the measured notch (305×32).
- MediaRemoteAdapter SPM package wired (Embed & Sign, pinned by revision) plus a TDD'd Foundation-only NowPlayingPresentation seam locking the D-01 source allowlist and the playing/paused/none classification (D-11 ≠ D-12).
- The single isolated MediaRemote bridge (`NowPlayingMonitor`) consuming ONE persistent adapter stream, lifting payloads into the Plan-01 pure seam, exposing transport, and synthesizing the D-12/D-13 health-state machine — plus the `@Published NowPlayingState` model (presentation + pre-decoded artwork + orthogonal isHealthy) that Plans 03/04 consume.
- `NotchPillView` extended with every visible now-playing surface — the collapsed glance wings (album art left / animated equalizer bars right), the expanded controls layout (art · title/artist · bars top-right · ⏪ ⏯ ⏩), the idle-CPU-safe `EqualizerBars` that animates only while playing, the D-12 "nicht verfügbar" view, and the D-14 charging > expanded > media-wings > collapsed precedence chain — all wired for transport callbacks and ready for Plan 04 to drive with the live monitor.
- `NotchWindowController` now owns and drives the full now-playing stack — it constructs `NowPlayingMonitor` against the live MediaRemote stream, maps each snapshot through the pure `NowPlayingPresentation` seam into the `@Published NowPlayingState`, routes every change through the single `updateVisibility()` gate, runs a launch-time health check (D-12) and mid-session-death clear (D-13), wires the expanded ⏪ ⏯ ⏩ buttons to the live Spotify / Apple Music session (NOW-02), dismisses the paused glance after ~15s and exits promptly on stop (D-06/D-07) via one-shot work items, keeps the charging splash precedence (D-14), and tears the perl child down in `deinit`. Verified on-device by the user across the full UAT.
- Pure Foundation-only IslandResolver — a single ranked reduce(...) reducer (Charging > Device > Now Playing) plus a bounded, de-duped, sequential TransientQueue — the single arbiter (D-05) for COORD-01, covered by 14 fast TDD unit tests.
- Completes the device-activity quartet Phase 5 left blocked — a @Published DeviceActivityState, a thin idempotent-start/full-teardown IOBluetooth BluetoothMonitor feeding the existing pure DeviceReading seam, and a deviceWings connect/disconnect view branch — bringing DEV-01/DEV-02 to code-complete and giving the resolver its third real input. The throwaway BluetoothSpike + DEBUG_BT_SPIKE path is removed.
- 1. [Rule 3 - Blocking] Reworded the Accent comment to satisfy the no-`ColorPicker` grep
- Wired Wave 1 into the live app: the view renders ONE `IslandPresentation` (no precedence if-chain), the controller is the single arbiter (queue + handleDevice + BluetoothMonitor + live toggles + accent), and — after on-device UAT — the connected Bluetooth device's real battery % is read from `IOBluetoothDevice.batteryPercentSingle` and shown in a compact battery indicator reused by the charging glance.
- v1 ships as a dry-run notarizable build: project.yml bumped to 0.1, `scripts/release.sh` produced `dist/Islet.dmg` unchanged and exited clean with the SKIP banner, and the Now Playing launch health check was re-confirmed healthy on-device — closing out APP-04.
- Fixed a matchedGeometryEffect-breaking un-animated model commit in the charging-splash yield-back and forwarded the missing accent argument to the charging BatteryIndicator; on-device human-verify confirmed both, plus a live-requested bolt-icon color tweak (yellow → green).
- Five confirmed correctness bugs in the transient-queue/device-battery-refresh controller layer fixed: nil-address device drop, battery-poll identity race, dismiss-timer re-arm gap, missed promoted-device battery refresh, and a stale isHealthy flag that could show "nicht verfügbar" for a disabled Now Playing.
- Three confirmed Now-Playing reliability bugs fixed in the controller/glue layer: a launch-time health-check race that could silently overwrite a stream-proven healthy flag back to false, hover not pausing the paused-media 15s auto-dismiss (unlike the existing charging-splash hover-pause), and duplicate `.paused` emissions restarting that countdown indefinitely.
- Task 1 — Finding 9 + Finding 10 (dead code deletion):
- Scoped the island's tap-to-toggle gesture off the expanded media view's transport button row and added a pure isSameTrack(_:_:) helper so previously-loaded album art is retained across a same-track nil-artwork callback instead of flickering to the placeholder.
- Deleted the dead `TrackSnapshot.hasArtwork` field and introduced a `NowPlayingService` protocol seam so `NotchWindowController` no longer holds the concrete `NowPlayingMonitor` class directly, closing CLAUDE.md's explicit MediaRemote isolation mandate.
- Task 3 is a `checkpoint:human-verify` gate.
- Fixed a battery-poll identity desync (WR-1: device splash could show one device's name with another device's battery %) and an over-eager dismiss-timer reset (WR-2: an unrelated toggle could silently extend a standing splash's on-screen time) — both closed with pure, unit-tested logic in IslandResolver.swift and wired into NotchWindowController.swift.

---
