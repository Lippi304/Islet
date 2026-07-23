# Pitfalls Research — v1.10 Live Activities Suite

**Domain:** Adding 9 new Live Activities/HUDs + a Settings-grid redesign to an existing native macOS notch-overlay app (Islet)
**Researched:** 2026-07-23
**Confidence:** MEDIUM-HIGH (grounded in direct reads of `IslandResolver.swift`, `TransientQueue`, `ActivitySettings.swift`, `Islet.entitlements`, `FocusModeMonitor.swift`, `project.pbxproj` INFOPLIST_KEY_* entries, `ClipboardMonitor.swift`; private-API claims are WebSearch-verified where noted, LOW confidence flagged where not)

## Critical Pitfalls

### Pitfall 1: Meeting-HUD call/mic detection built on window-title or process-name heuristics that silently break on app updates

**What goes wrong:**
Detecting "is Zoom/Meet/Teams in an active call" has no public, documented API. The typical hobbyist approach — polling `NSWorkspace.runningApplications` + `CGWindowListCopyWindowInfo` window titles for strings like "Zoom Meeting" or a meeting-timer-shaped title — breaks silently the moment Zoom/Teams change window title format (they do this often, and Teams' web-based Electron shell is worse than Zoom's native one). Meet running inside a browser tab has essentially no reliable native signal at all beyond browser-extension-level hooks, which this project has no browser extension to install.

**Why it happens:**
This is the same class of problem the project already hit with Focus Mode (`INFocusStatusCenter` looked like a dead end per pre-research, but on-device turned out `.authorized` — the working API only revealed itself by spiking on real hardware, not by reading docs). Meeting-HUD has no equivalent "Path A" candidate that is even semi-documented — it's window-title scraping or nothing, which is inherently version-fragile because it depends on third-party UI strings Islet does not control.

**How to avoid:**
- Treat this exactly like v1.6's Volume/Brightness OSD suppression and v1.6 Focus: a dedicated research/spike phase BEFORE planning, not folded into a build phase, with an explicit go/no-go gate on real hardware — this is already flagged in `PROJECT.md`.
- Scope down first: process-running detection (is Zoom/Teams/Meet-in-browser frontmost, or does the process exist) is nearly free and low-risk; "in an active call" (not just "app open") requires window-title matching per app, each app its own fragile adapter — mirrors `NowPlayingMonitor`'s "one file per fragile system surface" pattern. Isolate ALL three app-specific heuristics behind one `MeetingMonitor` file so a Zoom UI change is a one-file patch, not a scattered regression.
- Mic-mute-state detection is a SEPARATE, more tractable problem from call detection — CoreAudio's default-input-device mute/volume state IS a documented, stable API (unlike call detection). Do not conflate "can I tell if Zoom is muted" (hard, app-specific, no public state) with "can I tell if the SYSTEM mic is muted" (tractable, CoreAudio). Decide explicitly which one the feature actually needs — if it's "Zoom's in-call mute," that is much harder than reading system mic mute state, and the two states can disagree (Zoom can mute inside its own app without touching the system input).
- Do not promise per-app "genuine call in progress" reliability in REQUIREMENTS.md until the spike confirms which signal actually exists on-device; write the requirement as "best-effort, degrades to app-open-only if call-state detection isn't reliable" rather than a hard guarantee.

**Warning signs:**
Any implementation plan for Meeting-HUD that ships without first running on real Zoom/Meet/Teams calls on the dev machine and confirming the exact strings/APIs used. A plan that assumes CGWindowListCopyWindowInfo titles are stable across app versions without a spike.

**Phase to address:** The dedicated Meeting-HUD research/spike phase (already flagged in PROJECT.md) — must run and produce a go/no-go before the Meeting-HUD build phase is planned.

---

### Pitfall 2: Menübar-Overflow moves other apps' `NSStatusItem`s off-screen using an undocumented technique, forgetting Accessibility permission and other apps' own layout assumptions

**What goes wrong:**
Ice's "hide behind a chevron" mechanic works by reordering/repositioning OTHER apps' status items in the shared system menu bar — this requires manipulating `NSStatusItem` objects Islet does not own, via private/undocumented mechanisms (commonly: moving the item's window off-screen, or using private window-server-level tricks similar to what Ice itself uses). Two forgotten pieces are near-universal in reimplementations of this technique: (1) **Accessibility (`AXIsProcessTrusted`) permission** is required to enumerate/reposition other apps' menu-bar windows — without it the feature silently does nothing, with no error, which looks like "it's just broken" rather than "permission not granted"; (2) some third-party menu-bar apps actively detect and fight being hidden (poll their own window position, snap back), causing a visible flicker war with Islet.

**Why it happens:**
Reimplementing Ice's MVP without reading Ice's actual source for exactly which private mechanism it uses (there are at least two known general approaches: repositioning the item's backing `NSWindow` off the visible menu bar strip, vs. actually reordering items in the shared menu bar's private layout) leads to guessing an approach that either doesn't survive a Dock relaunch / display resolution change, or requires entitlements/permissions never requested.

**How to avoid:**
- Before planning, read Ice's actual source (MIT-licensed, referenced in PROJECT.md) for its exact mechanism rather than reinventing from a general description — Ice is the closest thing to a documented spec this feature has, and reading real working Swift code is worth more than a general summary of "how menu bar hiding apps work."
- Confirm on-device whether `AXIsProcessTrusted()` gating is actually required for the chosen mechanism (it may not be, depending on which private technique Ice uses) — if it is, `NSAccessibilityUsageDescription` in Info.plist plus a clear in-app prompt directing the user to System Settings → Privacy & Security → Accessibility is mandatory, and the feature must degrade visibly (not silently) when permission is denied/revoked.
- Test against System Settings' own menu-bar-icon-hiding items (Control Center, Wi-Fi, Battery) which macOS itself may already manage specially and could be unmovable or behave differently from third-party items.
- Test the "snap back" case explicitly: pick 2-3 real menu-bar apps installed on the dev machine (e.g. whatever's already running) and confirm hidden icons stay hidden across a few seconds, not just at the instant of hiding.
- Scope confirmation: PROJECT.md explicitly limits this to "one hide tier, icons stay in the menu bar, do NOT move into the notch" — resist scope creep toward Ice's fuller feature set (always-hidden tier, hotkeys, menu-bar theming) which was explicitly excluded.

**Warning signs:**
A plan that doesn't cite Ice's actual source file/technique by name. No Accessibility-permission-denied state considered in the UI-SPEC. No test against a currently-running third-party menu-bar app that itself actively repositions on interval (some do).

**Phase to address:** Menübar-Overflow phase — needs its own short research/spike step reading Ice's source before planning, per the same discipline already applied to Meeting-HUD and Coding-Progress in PROJECT.md.

---

### Pitfall 3: 9 new competing signals crowd `IslandResolver`/`TransientQueue` without an explicit priority-tier decision per feature, silently reordering existing precedence

**What goes wrong:**
`IslandResolver.resolve()` is a hand-ordered sequence of `if`/`switch` branches with hard-coded precedence (Charging > Device > Focus > OSD > [expanded branch] > CalendarCountdown > NowPlaying-ambient > idle), and `TransientQueue` is a bounded 2-deep FIFO shared across ALL transient-kind activities (`ActiveTransient` enum: charging/device/focus/osd today). Every new transient-style HUD (Caps Lock, Meeting-HUD call-state changes, Timer/Pomodoro alerts, Download-Progress-complete, Quick Actions feedback) is a candidate to become a 5th+ case in `ActiveTransient`/`IslandPresentation`, and each one added without deciding its exact rank relative to the existing 4 risks silently changing behavior for existing users (e.g. a Caps Lock toggle mid-charging-splash either interrupts it, queues behind it, or is dropped — which one happens depends on where in the `switch` it's inserted, and getting this wrong is invisible until on-device testing, exactly like the WR-1/WR-2 defects this project already hit and fixed in Phase 6's gap-closure).
Additionally, `TransientQueue.maxDepth = 2` was tuned for a world with 2 transient kinds (Charging, Device) plus persistent Focus/self-elapsing OSD. With up to 6-7 new potential transient-shaped events (Caps Lock changes rapidly if a user is a fast typer toggling it, Timer alerts, Quick-Action feedback flashes), a burst of unrelated transients can now genuinely fill/overflow the 2-deep bound in normal use, silently dropping a legitimate notification (`removeFirst()` on overflow, per the existing `enqueue` implementation) — this was a non-issue at 2 kinds and becomes a real one at 6+.

**Why it happens:**
The resolver is deliberately a flat ordered structure ("D-05: the single ranking authority") rather than a generic priority-table (a decision the codebase's own comments call out at `resolveSecondary`'s "deliberately NOT a generic priority-resolution engine" note) — this was fine at today's small N but does not automatically scale; every new case is a manual insertion point someone has to consciously reason about relative to all existing cases, and it's easy to just append near the bottom without checking whether that changes precedence for something already shipped (e.g. accidentally ranking Timer above Focus when Focus was deliberately made `isPersistent` to never be silently pre-empted except by the explicit `preempt()` path for Charging/Device).

**How to avoid:**
- Before the Settings-Redesign foundation phase's implementation, or right after it, produce ONE explicit priority table for ALL 9 new activities relative to the 6 existing `IslandPresentation`/`ActiveTransient` cases (Charging, Device, Focus, OSD, NowPlaying-ambient, CalendarCountdown) — a literal ranked list reviewed by the user, not inferred later from wherever a case happens to land in a `switch`. This becomes the single source of truth the resolver's ordering is checked against in code review.
- Explicitly classify each new activity as one of: (a) a genuine new `ActiveTransient` case competing for the FIFO head (Caps Lock toggle, Timer alert, Quick-Action feedback) — these need the preempt-vs-persistent decision Focus already required; (b) a new ambient/ongoing case parallel to CalendarCountdown/NowPlaying (Download-Progress bar while downloading, Meeting-HUD call timer, Coding-Progress) — these need a decision about whether they can coexist as a `SecondaryActivity` bubble (Phase 42's dual-activity mechanism, currently scoped to exactly ONE pairing) or must displace the primary; (c) a Settings/menu-only feature with NO resolver participation at all (Menübar-Overflow, Quick Notes capture UI, Quick Actions bar) — these should be kept OUT of `IslandResolver` entirely, avoiding needless resolver growth.
- Re-derive whether `maxDepth = 2` is still correct given the new transient-shaped candidates; if more than 2 kinds can genuinely be in-flight together in normal use (e.g. Caps Lock + Timer + Quick-Action-feedback all within a few seconds), either raise the bound deliberately (with a test asserting the new bound) or, better, confirm each new transient is rare/human-paced enough (like Focus/Charging/Device already are) that collision is still rare — don't just leave the bound unexamined.
- Extend `secondaryPairings`' "ordered table walked generically" pattern (already explicitly designed for exactly this kind of extension per its own comment) rather than hand-rolling new if/else precedence chains per new ambient activity.
- Reuse the existing regression-test shape: `IslandResolver` and `TransientQueue` are pure/Foundation-only and unit-tested in milliseconds (per the file's own header) — every new case needs the same coverage discipline (WR-1/WR-2-class identity-match and dismiss-timer tests) before it's considered done, not just visual on-device approval.

**Warning signs:**
A PR/phase that adds a new `IslandPresentation`/`ActiveTransient` case without a corresponding update to a written priority table. Any `switch` insertion "near the bottom" with a comment like "doesn't matter much" — precedence always matters once two features can be live at once. On-device testing that only exercises the new feature in isolation, never combined with an existing transient (Charging/Device/Focus) firing at the same moment.

**Phase to address:** Foundation-adjacent — either folded into the Settings-Redesign foundation phase (since it already touches all activities generically) or its own short "Resolver Integration Plan" step before any individual new-HUD phase begins. Each individual feature phase's plan should reference and update the shared table rather than deciding precedence locally.

---

### Pitfall 4: Settings-grid migration silently flips an existing user's currently-ON toggle by reusing/colliding an `@AppStorage` key, or by getting the "new activities default OFF" rule backwards for an activity that already shipped

**What goes wrong:**
The existing `ActivitySettings` enum has an established, load-bearing convention: every existing toggle key defaults to `true` (ON) EXCEPT `focusKey`, which is explicitly called out in a comment as "the ONE activity toggle in this codebase that defaults OFF... every sibling toggle above defaults true." A generic Settings-grid redesign that iterates "all activities" and applies one blanket default policy risks two distinct failure modes: (1) applying "new = OFF" logic to an EXISTING key by accident (e.g. if the grid's generic activity-list model re-derives defaults from a lookup table that mis-scopes an existing key as "new"), silently flipping an existing user's currently-ON Charging/Device/NowPlaying/CalendarCountdown/OSD-suppression/auto-update toggle to OFF on upgrade; (2) the inverse — a genuinely new v1.10 activity accidentally inheriting the "default true" convention used by 5 of 6 existing keys instead of the explicitly-required "default OFF" rule from PROJECT.md, because that's the majority pattern already in the file and easy to copy-paste without noticing Focus is the deliberate exception.
A second, more subtle risk: `@AppStorage` reads with `UserDefaults.standard.object(forKey:) != nil` to detect "has this user already set a value" (the exact pattern `migrateLegacyAccentIfNeeded` already uses for the accent-key migration) is easy to get backwards for a BRAND NEW key — for a key that has literally never existed before v1.10, `object(forKey:) == nil` is true for EVERY user (existing and new alike), so it cannot be used to distinguish "existing user, key never touched, should get the true legacy default" from "new key, should get the OFF default" — that distinction only matters for migrating something that changes representation (like the accent index did), not for genuinely new keys, where the risk is instead a copy-paste of the wrong hardcoded default boolean into `@AppStorage(wrappedValue: ...)`.

**How to avoid:**
- Do NOT introduce a generic "activity list model" that computes defaults programmatically from an activity's metadata (e.g. "if `isNewInV1_10 { false } else { true }`) unless that classification is unit-tested against the literal existing key list — prefer the current codebase's actual pattern instead: each key keeps its own explicit `@AppStorage(wrappedValue: true/false, key)` at its declaration site, exactly matching today's `ActivitySettings.swift` style, so a reviewer can eyeball each new key's default in isolation rather than trust an inferred rule.
- Write a single explicit checklist mapping the 8 EXISTING keys (`chargingKey`, `nowPlayingKey`, `songChangeToastKey`, `deviceKey`, `calendarCountdownKey`, `focusKey`, `osdSuppressionKey`, `autoUpdateCheckKey`) to their CURRENT default, and confirm the Settings-grid redesign phase's plan states explicitly "unchanged" for every one of them — this is a two-minute check that prevents an entire class of silent regression.
- For every genuinely new key (Caps Lock, Download-Progress, Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions, Menübar-Overflow, Coding-Progress, Update-restyle-if-it-gets-a-new-key), default explicitly to `false`, matching Focus's established precedent and PROJECT.md's explicit "new activities default OFF" instruction — write this as a locked decision in the Settings-Redesign phase's CONTEXT.md, not left to each individual feature phase to re-decide inconsistently.
- Regression-test coverage: add a test (mirroring the project's existing unit-test discipline) that asserts, for a UserDefaults suite with NO keys ever set (simulating a fresh existing-user upgrade, i.e. before migration logic runs), each of the 8 existing keys reads its historically-correct default and each of the ~9 new keys reads `false`.
- Watch for accidental key collisions: any new key string must not match an existing one (e.g. don't reuse `"activity.device"`-shaped naming carelessly) — the project's convention (`"activity.<name>"`) makes near-collisions plausible if a new feature is casually named "Device Overflow" or similar; grep the full existing key list before naming new ones.

**Warning signs:**
A Settings-grid redesign PR that removes or restructures the individual `static let ...Key = "..."` declarations into a data-driven array/dictionary without a 1:1 test asserting every existing key's default is unchanged. Any new `@AppStorage` default of `true` for a v1.10-only feature. QA that only checks the grid renders correctly, never checks an EXISTING install's actual toggle states survive the upgrade (requires testing with a UserDefaults domain that already has legacy values set, not a fresh install).

**Phase to address:** Settings-Redesign (foundation) phase — this is explicitly the phase PROJECT.md names as carrying this exact risk ("new activities default OFF — risk of accidentally flipping existing users' currently-ON defaults during the migration"). Verification must include an on-device or simulated "upgrade from v1.9" check, not just a fresh-install check.

---

### Pitfall 5: FSEvents-based Download-Progress reacts to partial/temporary files, not the finished download, and double-fires on browser-specific write patterns

**What goes wrong:**
Browsers write downloads as a `.crdownload` (Chrome), `.download` (Safari), or `.part` (Firefox) temp file, then rename it to the final filename on completion — sometimes with an additional intermediate write-flush. A naive FSEvents watcher on `~/Downloads` treating EVERY create/modify event as "a new download in progress" will: (a) show a progress HUD for the temp file's growth, then get a SECOND separate creation event for the renamed final file, double-triggering the HUD or losing track of "this is the same download, now finished"; (b) fire on totally unrelated Downloads-folder activity (a file dragged in manually, an app writing a log there, Finder creating `.DS_Store`) which was never a "download" at all; (c) miss genuinely large downloads' true completion if it only watches for a creation event and never correlates the create with a later rename/modify settling event.
No file-watching (FSEvents or otherwise) exists anywhere in this codebase yet — `ClipboardMonitor` uses pasteboard `changeCount` polling, not FSEvents, so this is genuinely new infrastructure with no in-project precedent to copy from, unlike most of the other 8 features which extend an existing `*Monitor` pattern.

**Why it happens:**
FSEvents' API reports raw filesystem events, not application-level intent ("a download started/finished") — that inference has to be built by the app, and the naive version (react to any Downloads-folder event) is what most tutorials show, without covering the temp-file-suffix and rename-correlation cases that make it robust.

**How to avoid:**
- Track downloads by matching against the well-known browser temp-file suffixes (`.crdownload`, `.download`, `.part`, plus any others discovered during the spike) — a file matching one of these is "in progress"; its rename to a suffix-free name (or disappearance of the temp file paired with appearance of a same-stem final file) is "complete."
- Debounce: FSEvents can coalesce or fire multiple events in a tight burst for a single logical write; batch events within a short window (e.g. 200-500ms) before updating UI state, mirroring the project's existing debounce discipline elsewhere (e.g. `FocusModeMonitor`'s deliberate polling interval choice, `NotchWindowController`'s `deviceLastShown` flap-suppression pattern) rather than reacting to every raw callback.
- Ignore dotfiles (`.DS_Store`) and non-download-shaped events explicitly (an allowlist of "looks like an active download" beats a denylist of "known noise").
- Choose the FSEvents API's coalescing/latency flags deliberately, not just defaults — the choice affects whether individual file-level rename/create events are visible at all versus only directory-level "something changed here" events, which is the difference between "read a specific file's actual growth" and "poll the whole folder's file list."
- Isolate this behind one new `DownloadMonitor`-style file (matching the project's `*Monitor` convention) so a future macOS FSEvents API change or browser temp-file-naming change is a one-file patch.

**Warning signs:**
A Download-Progress HUD that flickers/duplicates for a single real download. A HUD that fires for unrelated Downloads-folder file drops (test explicitly: drag a random file into Downloads manually and confirm nothing happens). No handling for a download that's paused/resumed by the browser (temp file stops growing, then resumes) — decide explicitly whether the HUD should show "stalled" or just keep showing the last-known progress.

**Phase to address:** Download-Progress phase — since this introduces FSEvents to the codebase for the first time, budget for a short spike/research step even though PROJECT.md didn't flag one explicitly (unlike Meeting-HUD/Coding-Progress) — the temp-file-suffix-and-rename-correlation logic is exactly the kind of "looks simple, has real edge cases" risk the other flagged research steps exist to catch.

---

### Pitfall 6: Coding-Progress file-watch has no defined behavior for a stale/orphaned status file when Claude Code exits uncleanly

**What goes wrong:**
The mechanism (a Claude Code hook script writes a local status file, Islet file-watches it) has an inherent lifecycle gap already called out in the milestone context: if Claude Code crashes, the terminal is force-closed, or a session simply ends without a defined "session ended" hook firing, the status file is left on disk with its LAST-WRITTEN content (e.g. "3 of 5 todos done" or "running tests") — Islet's file-watcher has no signal that the process producing that state is gone, so the HUD keeps showing stale progress indefinitely, potentially for hours or until the next session overwrites it. Additionally, since Claude Code sessions can run in ANY project directory the user has open, and the milestone context says "session-local to this Mac" (not scoped to a specific project), a SECOND concurrent Claude Code session in a different terminal/project writing to the same status file will clobber the first session's state with no way for Islet to know two sessions exist — the HUD can end up showing the wrong session's progress, or flicker between two sessions' writes.

**Why it happens:**
File-based IPC has no built-in liveness signal — a file's mtime changing means "something wrote to it," not "the writer is still alive." Without an explicit heartbeat or PID-liveness check, "no update in N seconds" is the only available signal, and choosing N wrong either flickers away real (just slow) progress or leaves stale state visible too long.

**How to avoid:**
- Include a timestamp (or the writing process's PID) in the status file's own content, not just relying on filesystem mtime (mtime survives file-copy/backup operations and can be misleading; an explicit `lastUpdated` field the hook writes is more direct and testable).
- Islet's watcher applies an explicit staleness timeout: if no update arrives within a threshold tuned to realistic Claude Code turn latency (a few tens of seconds, not milliseconds — determine the right number empirically during the spike, since a too-short timeout will flicker the HUD away mid-turn while Claude is genuinely still "thinking"), the HUD auto-clears back to idle rather than showing frozen stale data forever.
- If a session-end-shaped hook event exists in Claude Code's hook system (check during the already-planned research step — PROJECT.md flags "hook-event choice" as an open question), prefer writing an explicit "session ended, clear now" terminal state over relying purely on the staleness timeout — use the timeout as the fallback safety net for the unclean-exit case specifically, not the primary mechanism.
- Decide and document the concurrent-session behavior explicitly rather than leaving it implicit: either (a) last-write-wins is acceptable (simplest, matches "session-local to this Mac" scope, document as a known limitation) or (b) the status file includes a session/PID identifier and Islet ignores writes from a session other than the most-recently-active one — pick (a) unless the spike shows concurrent sessions are common enough to matter; don't silently ship undefined clobbering behavior without at least a one-line documented decision.
- File writes from the hook script should be atomic (write-to-temp-then-rename, same principle as Pitfall 7 below) so Islet's watcher never reads a half-written JSON/status file mid-write.

**Warning signs:**
A Coding-Progress HUD still showing "running" 20 minutes after the terminal was closed. No `lastUpdated` field in the status file format. No test/manual check for "kill -9 the Claude Code process mid-session, confirm the HUD clears within a reasonable time."

**Phase to address:** Coding-Progress phase — PROJECT.md already flags this phase needs "a short research step (hook-event choice, file format/IPC)"; the staleness-timeout and file-format-with-timestamp decisions belong in that research step's output, not deferred to implementation-time improvisation.

---

## Moderate Pitfalls

### Pitfall 7: Quick Notes/Obsidian export loses data or corrupts the target file via non-atomic appends, and silently fails if the vault folder isn't re-selected after a permission change

**What goes wrong:**
The app is explicitly NOT sandboxed (`ENABLE_APP_SANDBOX = NO` confirmed in `project.pbxproj`), so this is NOT an App Sandbox security-scoped-bookmark problem in the traditional sense — but macOS's user-level file-access permission model (the "Islet would like to access files in your Documents/Desktop/removable volumes" TCC prompt) still applies to protected folders even for non-sandboxed apps, and an Obsidian vault commonly lives under `~/Documents` or a custom folder the user picks via an open panel. Two distinct correctness risks beyond permissions: (1) a naive "read whole file, append text, write whole file back" approach is not atomic — if Islet crashes or the disk hiccups mid-write, the entire notes file (potentially containing months of the user's real Obsidian notes, not just Islet's own additions) can be truncated or corrupted, which is a far worse failure mode than losing one Islet-only feature's data; (2) if the vault folder is on an external/network volume, or the user revokes folder access after granting it once, a silent write failure (a swallowed error) means the user believes notes are being captured when they aren't.

**Why it happens:**
"Append a line to a file" looks trivial and often IS trivial for files an app owns exclusively — but this file is inside the user's actual Obsidian vault, a real, valuable, externally-edited document (Obsidian itself may have the file open and be watching it), raising the stakes on any write-corruption bug well above the project's other purely-app-owned data (Shelf, Clipboard History).

**How to avoid:**
- Use `FileHandle`'s seek-to-end + write rather than read-modify-write-whole-file; if a "write to temp + rename" pattern is used instead (safer against partial writes), make sure it's a rename WITHIN the same volume/directory (cross-volume renames aren't atomic) and that Obsidian's own file-watcher won't choke on rapid create+delete+rename cycling (Obsidian reloads notes on external file change — a "new" Obsidian-invisible-rename outside of Obsidian's own recognized pattern can be visually disruptive, e.g. Obsidian briefly showing the note as deleted/recreated).
- Prefer `FileHandle.seekToEndOfFile()` + `write(_:)` for the append-only case specifically (matches "simple append-with-timestamp" from PROJECT.md's own scoping) — this is both simpler and safer than a full read-modify-write cycle since it never touches bytes that already exist on disk.
- Request folder access via `NSOpenPanel` (user explicitly picks the vault folder once, standard non-sandboxed folder-picker flow) and persist the path; on first write after a relaunch, verify the path still resolves and is writable, and surface a clear "Obsidian vault folder not found — please re-select" UI state rather than a silent no-op if the folder moved/was deleted/access was revoked.
- Do not attempt any vault-wide read/parse (PROJECT.md explicitly scopes this to "no vault read access needed") — resist the temptation to add "smart" features like note-linking or vault-structure awareness that would require broader access than the locked scope.
- Test with Obsidian actually open and the target note actually visible in Obsidian's editor during a write, to confirm Obsidian's own external-change reload behaves acceptably (it generally does for simple appends, but this needs an on-device check per the project's stated "trust on-device verification over assumption" pattern from its own history).

**Phase to address:** Quick Notes + Obsidian export phase — the atomic-append and folder-permission-revoked cases should be explicit acceptance criteria in that phase's plan, not left implicit.

---

### Pitfall 8: Quick Actions bar assumes AppleScript/System Events automation works identically to today's usage, missing that some actions (mic mute, display sleep, screen lock) have no clean public API and need different mechanisms per action

**What goes wrong:**
The existing entitlement `com.apple.security.automation.apple-events` plus `NSAppleEventsUsageDescription` ("Islet fragt diese Berechtigung an, um den aktuellen Titel als Favorit zu markieren") is already present and used for ONE specific narrow purpose (favoriting a track, likely a Music.app AppleScript call). A Quick Actions bar bundling "mic mute, display sleep, dark mode, screen lock" is not one uniform mechanism — each action has a genuinely different implementation path: dark mode has a clean, stable AppleScript/System Events toggle; screen lock has a few known but semi-informal mechanisms; display sleep has its own IOKit-level call distinct from screen lock; system mic mute has no single official toggle and is often done via CoreAudio's default input device volume/mute property (this OVERLAPS with Meeting-HUD's own mic-state need — worth sharing one CoreAudio-mic-mute helper between the two features rather than building it twice).
Assuming all 4 actions can reuse the existing AppleScript/System-Events entitlement and pattern risks silent failures for the 2-3 actions that actually need a different mechanism entirely: macOS's Apple-Events permission is per-target-app, not global, even under one entitlement, so the user already having approved Islet→Music does NOT mean Islet→System Events is pre-approved — that's a fresh TCC prompt the first time it fires.

**Why it happens:**
The existing favorite-track precedent makes AppleScript automation look like an already-solved, reusable pattern, but macOS's Apple Events authorization is granted per (source app, target app) pair — easy to forget when reasoning from "we already have the entitlement."

**How to avoid:**
- Enumerate each of the 4 (or however-many-are-finalized) Quick Actions' actual implementation mechanism individually during phase planning, not assumed uniform — expect: dark mode via System Events AppleScript (new per-target permission prompt likely, even with the existing entitlement/Info.plist key already present); screen lock via a documented-enough mechanism (research needed — verify the current macOS version's working approach, this changes across major OS versions); display sleep via an IOKit-level call or `pmset`-style mechanism; mic mute via CoreAudio (share with Meeting-HUD's own needed mic-state code).
- Test the FIRST-USE permission-prompt flow for each action explicitly on-device — a Quick Action button that silently no-ops the first time because an Apple-Events prompt appeared and was dismissed/ignored (non-activating panel means the app can't easily surface a modal prompt for the user to notice) needs a defined UX (e.g. detect the failure and show an inline "permission needed" state on the button itself, matching the existing Focus/OSD "Permission needed — tap to grant" hint convention already established in `ActivitySettings.focusPermissionStatusHint`).
- Given the non-activating, click-through, never-steals-focus panel architecture, confirm each action's permission dialog (which macOS itself presents, outside Islet's control) doesn't get lost behind the panel's z-order or the click-through hit-testing — this is a real risk given the codebase's own history of click-through hit-test bugs (CR-01).

**Phase to address:** Quick Actions bar phase — final action selection happens at phase-planning time per PROJECT.md; the per-action mechanism research belongs in that same planning step, and should explicitly note which actions share code with Meeting-HUD's mic-mute detection.

---

### Pitfall 9: Caps Lock HUD polls the modifier-key state on a naive tight timer, burning idle CPU/battery in a project that has repeatedly had to retrofit idle-CPU gating after the fact

**What goes wrong:**
Reading modifier-key state "continuously" without deliberate throttling is exactly the kind of thing this codebase has already had to walk back once: the Now Playing equalizer bars needed explicit "idle-CPU-gated" treatment as an on-device UAT fix (Phase 4), and `FocusModeMonitor` deliberately polls at 2.5s (not sub-second) specifically because "Focus toggles are a deliberate human action, not something needing sub-second responsiveness" — the same reasoning applies even MORE strongly to Caps Lock, but the naive approach (a global key/flags event monitor, left permanently active) is actually the CORRECT approach here since Caps Lock genuinely needs an event-driven signal (there's no polling interval that both feels instant and doesn't waste CPU) — the risk is the opposite direction from the other monitors: building this as a naive fixed-interval poll (checking modifier flags every 100ms "to feel responsive") wastes CPU for no benefit when a global event monitor delivers the state change instantly and at zero idle cost.

**Why it happens:**
Polling is the "obvious" pattern already used elsewhere in the codebase (Focus, and PowerSourceMonitor's IOKit poll noted as a sibling), so it's tempting to copy that shape reflexively without recognizing Caps Lock specifically has a genuine event-driven API (`NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` or a CGEventTap on flagsChanged) that both the project's OWN Volume/Brightness precedent (HID-level event tap) and Apple's own API surface make available — unlike Focus, which genuinely has no push/KVO signal (confirmed by the code comment: "`focusStatus` is not KVO/`@objc dynamic`").

**How to avoid:**
- Use `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` (session-level; sufficient for reading Caps Lock's boolean toggle, unlike the Volume/Brightness OSD-suppression case which specifically needed HID-level interception to also SUPPRESS the native OSD — Caps Lock HUD only needs to READ the state and show its own HUD, not suppress anything native, so it doesn't need the heavier HID-level machinery Volume/Brightness required) — confirm this during a brief phase-planning check rather than assuming HID-level access is required by analogy to Volume/Brightness.
- If a global event monitor requires Accessibility/Input Monitoring permission (verify during planning — `NSInputMonitoringUsageDescription` already exists in Info.plist for the existing drag-in feature, may already cover this or may need its own distinct usage string), reuse the existing permission-hint UI convention rather than inventing a new one.
- Explicitly avoid a polling-timer implementation for this feature; if research during planning finds no clean global-monitor path works reliably, treat that as a genuine finding worth a short spike (mirroring Volume/Brightness's own history of "session-level didn't work, needed HID-level") rather than defaulting straight to a timer poll as the fallback.

**Warning signs:** Any Caps Lock implementation using a Timer/DispatchSourceTimer at a sub-second interval to poll modifier flags. Energy Impact in Activity Monitor rising measurably from Islet at idle once this feature ships.

**Phase to address:** Caps Lock HUD phase — likely low-risk/low-research per PROJECT.md's phase ordering (early, "ascending effort"), but this specific mechanism choice should be a one-line decision recorded in that phase's plan, not left implicit.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Meeting-HUD ships with window-title string matching hardcoded per app version | Fast to build, unblocks the feature | Breaks silently on the next Zoom/Teams UI update, no compile-time signal | Acceptable for v1.10 ship IF isolated in one `MeetingMonitor` file (one-file patch later) and the spike explicitly documents which strings/versions were tested |
| Menübar-Overflow uses the simplest working private technique found, without matching Ice's exact implementation | Faster to ship an MVP | May be less robust than Ice's (which has presumably been hardened by its own user base over time) against edge cases Ice already solved | Acceptable only if the chosen technique is verified on-device across a display-sleep/wake and a Dock-relaunch cycle first — never acceptable to ship untested against those two common state changes |
| Coding-Progress skips the concurrent-multi-session-safe design (last-write-wins) | Much simpler file format, faster to ship | A user running two Claude Code sessions gets confusing/wrong HUD state | Acceptable given PROJECT.md's explicit "session-local to this Mac" scoping — but must be documented as a known limitation, not silently unhandled |
| Quick Notes append uses simple `FileHandle` seek-to-end without a lock/mutex against concurrent Islet-internal writes | Simpler code | Two rapid Quick-Note captures in immediate succession could theoretically interleave-write | Acceptable — Islet is single-process and the UI can only realistically originate one capture at a time; not acceptable if a background/hook-driven writer is ever added to the same file |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| `IslandResolver`/`TransientQueue` | Adding a new `ActiveTransient` case and inserting it into the `switch` "wherever feels right" | Update one shared priority table first (Pitfall 3), then place the case to match it exactly, with a unit test asserting the new precedence |
| `ActivitySettings` `@AppStorage` keys | Copy-pasting an existing key's `default: true` pattern for a new v1.10 feature | Every new key defaults `false` explicitly (Pitfall 4), matching the `focusKey` precedent, confirmed against a written per-key default checklist |
| CoreAudio mic-mute state | Building it twice — once for Meeting-HUD, once for Quick Actions' mic-mute button | Share one CoreAudio mic-mute helper/monitor between both features (Pitfall 8) |
| macOS Apple Events / TCC per-target-app permissions | Assuming the existing `com.apple.security.automation.apple-events` entitlement + `NSAppleEventsUsageDescription` covers ALL future AppleScript targets | Each new automation TARGET (System Events, etc.) triggers its own first-use TCC prompt regardless of the shared entitlement — test each target's first-use flow individually (Pitfall 8) |
| FSEvents (Download-Progress, and any future Coding-Progress file-watch variant) | Reacting to every raw filesystem event as a meaningful state change | Debounce + filter to known-relevant file patterns before updating UI (Pitfall 5) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Caps Lock HUD polling instead of event-driven monitoring | Measurable idle CPU/Energy Impact increase in Activity Monitor | Use a global flags-changed event monitor, not a timer (Pitfall 9) | Immediately at ship, not a "scale" issue — this is a from-day-one correctness/battery issue |
| `TransientQueue.maxDepth = 2` unexamined against 6+ new transient-shaped activities | A legitimate notification silently dropped (oldest pending entry evicted) during a burst of unrelated activity (e.g. Caps Lock toggled twice while a Timer alert also fires) | Re-derive the bound explicitly for the new activity count (Pitfall 3) | Breaks the moment 3+ transient-shaped activities can genuinely coincide in normal use, which v1.10 makes plausible for the first time |
| Menu-bar icon repositioning polling other apps' status items on a tight timer to detect them re-appearing/fighting back | CPU usage rises with each additional hidden third-party menu-bar app | Use event-driven detection where possible rather than a tight poll loop across all hidden items | Breaks (noticeably) once a user hides several menu-bar apps at once |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Coding-Progress status file readable/writable by any local process without validation | Low risk (local-machine-only, no secrets expected in a todo-progress status file) but a malformed/adversarial file could crash the watcher if parsed unsafely | Parse defensively (matches the project's own "silent-degrade convention" already used in `FocusModeMonitor`/`LocationProvider` — malformed input is "no data this tick," never a crash) |
| Obsidian vault write path stored in UserDefaults as a plain string with no re-validation | A stale/moved path could cause writes to land in an unexpected location if the path is later reused for something else without re-verifying it still points at the same, user-approved folder | Re-verify the stored path resolves to the same folder on each write session, not just at initial pick time (Pitfall 7) |
| Quick Actions automating screen lock / display sleep exposed with no confirmation step | A misclick on a Quick Action button locks the screen or sleeps the display mid-task, unlike mic-mute/dark-mode which are easily reversible | Screen lock and display sleep specifically may warrant a distinct visual weight/confirmation affordance vs. the reversible actions — a UX decision, not just a technical one, worth raising during that phase's UI-SPEC |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Meeting-HUD or Coding-Progress showing confidently-wrong state (e.g. "Zoom call active" when it's not, stale Coding-Progress) | Erodes trust in ALL of Islet's HUDs, not just the broken one, because the user can't tell which HUDs are reliable | Prefer "shows nothing" over "shows wrong" for any signal with meaningful uncertainty — matches the codebase's existing "silent degrade" convention used for Focus/Location |
| Settings-grid overview showing all 9+8 activities with zero visual distinction between "needs a permission grant" and "just needs a toggle flip" | User enables a permission-gated activity (Meeting-HUD, Caps Lock if it needs Input Monitoring, Menübar-Overflow if it needs Accessibility) and sees nothing happen, no explanation | Reuse the existing `focusPermissionStatusHint`/`osdPermissionStatusHint` "Active" / "Permission needed — tap to grant" pattern uniformly across every new permission-gated activity in the grid, not just the two that already have it |
| Quick Actions bar buttons that silently fail on first use due to an unhandled TCC prompt | User taps a button, nothing visibly happens, taps again, still nothing — no feedback loop to know a system permission dialog appeared and was missed | Detect the failure path per action and surface an inline permission-needed state (Pitfall 8) |

## "Looks Done But Isn't" Checklist

- [ ] **Meeting-HUD:** Often missing — reliability across a Zoom/Teams UI update; verify the detection strings/APIs were actually tested on the CURRENT installed version of each app, and re-check after any app auto-update during development.
- [ ] **Menübar-Overflow:** Often missing — Accessibility-permission-denied state, and survival across display-sleep/wake and Dock relaunch; verify by explicitly testing revoke-then-relaunch and a sleep/wake cycle with icons hidden.
- [ ] **Settings-grid redesign:** Often missing — a regression test proving EVERY existing toggle's default is unchanged for an upgrading (not fresh-install) user; verify with a UserDefaults domain pre-seeded with legacy values, not just a clean simulator/fresh-install run.
- [ ] **Download-Progress:** Often missing — correlation between a browser's temp-file and its final renamed file as ONE logical download, not two events; verify by watching a real multi-second download in Chrome/Safari/Firefox and confirming exactly one HUD lifecycle (start→progress→complete), not a flicker or double-trigger.
- [ ] **Coding-Progress:** Often missing — a defined staleness timeout and tested unclean-exit recovery; verify by `kill -9`-ing an active Claude Code session and confirming the HUD clears within the documented timeout, not indefinitely.
- [ ] **Quick Notes/Obsidian export:** Often missing — atomic append verified against a crash/interrupt mid-write, and a re-select-folder UX for a moved/inaccessible vault path; verify by forcibly interrupting a write (e.g. kill the app mid-append in a debug build) and confirming the existing vault content isn't corrupted.
- [ ] **Quick Actions bar:** Often missing — per-action first-use TCC-prompt handling for actions that need a NEW target-app authorization beyond the existing entitlement; verify each action individually on a machine/user account where none of the automation prompts have been pre-approved.
- [ ] **Caps Lock HUD:** Often missing — confirmation it's event-driven, not polling; verify via Activity Monitor's Energy Impact column at idle before/after the feature ships.
- [ ] **IslandResolver integration (all 9 features collectively):** Often missing — a written, reviewed priority table covering all new + existing activities together; verify a code-review checklist item exists requiring this table be updated whenever a new `ActiveTransient`/`IslandPresentation` case is added.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Meeting-HUD breaks after a Zoom/Teams UI update | LOW | Isolated in one `MeetingMonitor` file per the isolation discipline (Pitfall 1) — patch the string/heuristic in that one file, no architectural change needed |
| Settings-grid migration silently flipped an existing toggle | MEDIUM | Ship a one-time forced-migration patch that re-reads a pre-upgrade backup/known-good default if detectable, or at minimum a release note + in-app one-time notice telling affected users to re-check Settings; costly because silent data-loss-of-preference erodes trust even after the fix |
| `TransientQueue` overflow drops a legitimate notification under real-world load | LOW | Bump `maxDepth` and add the missing regression test (Pitfall 3) — a small, well-isolated, already-pure/unit-tested component |
| Menübar-Overflow's chosen private technique stops working after a macOS update | MEDIUM-HIGH | Re-spike against Ice's current source (which the community keeps updated against new macOS versions) rather than debugging from scratch — treat Ice's repo as a living reference to re-sync against, not a one-time read |
| Coding-Progress status file format needs to change (e.g. adding a `lastUpdated` field after the fact) | LOW | File format is entirely internal (hook script + Islet both under this project's control), a version bump/field addition is a coordinated two-sided change with no external migration concern |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| Pitfall 1 (Meeting-HUD private-API fragility) | Meeting-HUD research/spike phase (already flagged in PROJECT.md) | On-device test against real, currently-installed Zoom/Meet/Teams; go/no-go decision documented before build phase starts |
| Pitfall 2 (Menübar-Overflow private technique + permissions) | Menübar-Overflow phase, with its own short research/spike step reading Ice's source first | On-device test: hide an icon, sleep/wake, relaunch Dock, revoke Accessibility permission — all 3 must degrade visibly, never silently |
| Pitfall 3 (Resolver/Queue crowding) | Settings-Redesign foundation phase OR a dedicated short "Resolver Integration Plan" step before the first new-HUD build phase | Written priority table exists and is referenced by every subsequent feature phase's plan; unit tests cover new-case precedence |
| Pitfall 4 (Settings migration silently flips existing toggles) | Settings-Redesign foundation phase | Regression test against a pre-seeded (upgrade-simulating) UserDefaults domain, not just fresh-install |
| Pitfall 5 (FSEvents correctness for Download-Progress) | Download-Progress phase | On-device test with real multi-second downloads in 2+ browsers, confirming single-lifecycle HUD behavior |
| Pitfall 6 (Coding-Progress stale state) | Coding-Progress research phase (already flagged in PROJECT.md) | On-device kill-9 test confirms HUD clears within documented timeout |
| Pitfall 7 (Obsidian append atomicity) | Quick Notes + Obsidian export phase | Interrupt-mid-write test confirms existing vault content isn't corrupted; folder-moved/revoked UX verified |
| Pitfall 8 (Quick Actions per-action mechanism + TCC) | Quick Actions bar phase (final action list decided at phase-planning time per PROJECT.md) | Each action's first-use permission flow tested individually on an unapproved account/machine |
| Pitfall 9 (Caps Lock polling vs event-driven) | Caps Lock HUD phase | Activity Monitor Energy Impact check at idle before/after shipping |

## Sources

- Direct code read: `/Users/lippi304/conductor/workspaces/notch/algiers/Islet/Notch/IslandResolver.swift` (HIGH confidence — primary source for resolver/queue architecture claims)
- Direct code read: `/Users/lippi304/conductor/workspaces/notch/algiers/Islet/ActivitySettings.swift` (HIGH confidence — primary source for existing @AppStorage key defaults and migration pattern)
- Direct code read: `/Users/lippi304/conductor/workspaces/notch/algiers/Islet/Notch/FocusModeMonitor.swift` (HIGH confidence — primary source for the Focus-Mode private-API precedent and polling-vs-event-driven reasoning)
- Direct code read: `/Users/lippi304/conductor/workspaces/notch/algiers/Islet/Islet.entitlements` and `Islet.xcodeproj/project.pbxproj` INFOPLIST_KEY_* entries (HIGH confidence — confirms app is NOT sandboxed, existing usage-description strings, existing entitlements)
- Direct code read: `/Users/lippi304/conductor/workspaces/notch/algiers/Islet/Clipboard/ClipboardMonitor.swift` (HIGH confidence — confirms no FSEvents precedent exists yet in this codebase, only pasteboard changeCount polling)
- Project history: `/Users/lippi304/conductor/workspaces/notch/algiers/.planning/PROJECT.md` (HIGH confidence — primary source for prior real on-device-only bugs referenced throughout: Focus Mode's undocumented entitlement need, Volume/Brightness HID-level requirement, WR-1/WR-2 resolver defects, Phase 4 equalizer idle-CPU gating, CR-01 click-through bug class)
- Ice (open-source menu-bar-icon-hiding tool) as the named MVP reference for Menübar-Overflow — MEDIUM confidence claims about its general technique (based on general knowledge of how such tools typically operate: repositioning/moving NSStatusItem windows, requiring Accessibility permission); the actual mechanism should be re-verified against Ice's current real source during that phase's research step rather than relied on from this summary alone (LOW-MEDIUM confidence on exact mechanism specifics without a live source read)
- General macOS platform knowledge (FSEvents temp-file/rename patterns, Apple Events per-target-app TCC authorization, CoreAudio mic-mute API, global flags-changed event monitoring) — MEDIUM confidence, training-data-based platform behavior not independently re-verified via Context7/official docs in this research pass; flag for spike-time verification per each phase's own already-planned research steps

---
*Pitfalls research for: v1.10 Live Activities Suite (Islet, native macOS notch-overlay app)*
*Researched: 2026-07-23*
