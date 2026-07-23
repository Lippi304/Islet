# Stack Research

**Domain:** macOS notch-overlay app — 9 new Live Activities/HUDs (v1.10 "Live Activities Suite")
**Researched:** 2026-07-23
**Confidence:** MEDIUM-HIGH (mixed — see per-feature notes; Ice mechanism and Claude Code hooks verified against primary sources, Meeting-HUD mute detection is inherently best-effort)

This is **not** a greenfield stack doc — it covers only what's new for v1.10's 9 features. Nothing here touches the existing validated stack (Swift 5/SwiftUI+AppKit, MediaRemote via `NowPlayingMonitor`, WeatherKit, EventKit, IOKit `PowerSourceMonitor`, CoreBluetooth/IOBluetooth `BluetoothMonitor`, CoreAudio+DisplayServices volume/brightness OSD suppression via `.cghidEventTap`, INFocusStatusCenter, Sparkle 2.9.4, CryptoKit/Keychain, `NSPasteboard.changeCount` polling, private CGS Space APIs). See `PROJECT.md` for that baseline.

## Headline Finding

**Zero new third-party/SPM dependencies are needed for this entire milestone.** Every one of the 9 features is covered by a public Apple framework, a private-but-already-accepted-risk-category API (CGS/SkyLight, matching the project's existing `CGSSpace.swift`/OSD-suppression precedent), or a one-line shell-out to an Apple-shipped CLI tool. This matches the project's existing `Monitor`-per-feature pattern (`NowPlayingMonitor`, `PowerSourceMonitor`, `BluetoothMonitor`) — every new feature below should get its own single-purpose `XxxMonitor.swift`, isolating any private/undocumented surface the same way `NowPlayingMonitor` isolates MediaRemote.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `UserNotifications` (`UNUserNotificationCenter`) | macOS 15+ (stable since 10.14) | Pomodoro-session-complete local alert | Public, standard local-notification API; one-time authorization prompt, same TCC-consent pattern the app already handles for Calendar/EventKit |
| Core Services `FSEvents` (`FSEventStreamCreate`) | macOS 15+ (stable, unchanged since 10.5) | Watch `~/Downloads` for new/growing files (Download-Progress) | Public C API, correct tool for a whole **directory** where many files appear/disappear |
| `DispatchSourceFileSystemObject` (GCD, `.write` event mask on an open fd) | macOS 15+ | Watch a **single** local status file for changes (Coding-Progress) | Public, kqueue-based, lower-latency and simpler than spinning up an `FSEventStream` for one known file — right-sized tool vs. FSEvents (see Alternatives) |
| `NSOpenPanel` + `FileManager` | AppKit, macOS 15+ | Let user pick their Obsidian vault folder once; append timestamped text | Standard folder-picker + plain file I/O; **no security-scoped bookmarks needed** — Islet is not App-Sandboxed (direct notarized distribution, not App Store), so a plain saved path in `UserDefaults` keeps working across relaunches |
| CoreAudio `kAudioDevicePropertyMute` on the **default input** device | macOS 15+ | System-wide mic-mute toggle (Quick Actions bar, and recommended stand-in for Meeting-HUD's "mute toggle" — see below) | Identical technique to the existing volume-HUD `AudioObjectSetPropertyData` call, just targeted at the input device instead of output — zero new API surface |
| CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` | macOS 15+ | Detect "mic is actively in use by *some* process" (Meeting-HUD call-active signal) | Public, documented `AudioHardware.h` selector; no Accessibility/Screen-Recording permission. Known limitation: reliable for built-in/wired mics, **not reliable for Bluetooth mics** (reports success but stays "inactive") |
| `NSWorkspace.runningApplications` (bundle-ID match) | AppKit | Identify *which* app is likely in a call (`us.zoom.xos`, `com.microsoft.teams2`) | Public, zero-permission process enumeration — pairs with the CoreAudio signal above to distinguish "Zoom is running AND mic is hot" from "some random app has the mic" |
| Private CGS/SkyLight connection APIs (`CGSMainConnectionID`, `CGSGetScreenRectForWindow`, `CGWindowListCopyWindowInfo`) + synthetic `CGEvent` mouse-drag posted to `.cgSessionEventTap` | macOS 15+, undocumented | Menübar-Overflow: read other apps' `NSStatusItem` window frames and reposition them | This is **exactly** what Ice does (verified from Ice's own source, see below) — same private-API risk tier the project already accepts for `CGSSpace.swift` fullscreen handling |
| `NSAppleScript` running `tell application "System Events" to tell appearance preferences to set dark mode to (not dark mode)` | macOS 15+ | Dark-mode toggle (Quick Actions bar) | No public Swift API exists to flip system-wide appearance for *other* apps (`NSApp.appearance` only affects your own app). First use triggers a one-time **Automation** consent prompt for "Islet wants to control System Events" — a lighter TCC category than Accessibility |
| `Process` shelling out to `/usr/bin/pmset displaysleepnow` | macOS 15+ | Display-sleep Quick Action | Public CLI, no permission prompt, no private framework |
| `Process` shelling out to `CGSession -suspend` (`/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`) | macOS 15+ | Screen-lock Quick Action | No public Swift lock-screen API exists (confirmed absence via open Apple Developer Forums threads). `CGSession -suspend` is the de-facto standard used by "lock screen now" utilities; still works through Sonoma/Sequoia. Undocumented **path to an Apple-shipped binary**, not a private framework symbol — lower risk than CGS linking but flag as unsupported |
| `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` | AppKit | Caps Lock ON/OFF state (continuous) | Requires Input Monitoring TCC — **already granted**, because the existing `.cghidEventTap` volume/brightness key interception requires the identical permission. Zero marginal permission cost |
| Claude Code **hooks** (`~/.claude/settings.json`, `type: "command"`) | Claude Code (current CLI) | Coding-Progress data source | See dedicated section below |

### Supporting Libraries

**None.** No SPM package additions are needed for any of the 9 features — deliberately, per the ladder: every capability above is stdlib/system-framework or a `Process` shell-out to something Apple already ships.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Node.js (already a hard dependency of Claude Code itself) | Runtime for the Coding-Progress hook script | Do **not** add a `jq`/Python dependency to the hook script — every machine running Claude Code already has Node.js installed to run `claude` itself. A ~15-line Node script (`process.stdin` → `JSON.parse` → transform → `fs.writeFileSync`) needs zero extra install step |

## Feature-by-Feature Detail

### 1. Meeting-HUD

**Call-active detection (no Accessibility, no Screen Recording):**
Combine two zero-permission public signals:
1. `NSWorkspace.shared.runningApplications` contains a known meeting-app bundle ID (`us.zoom.xos`, `com.microsoft.teams2` for New Teams / `com.microsoft.teams` for Classic Teams).
2. CoreAudio's default input device reports `kAudioDevicePropertyDeviceIsRunningSomewhere == true`.

Both true → call timer starts. This is a **heuristic**, not a true call-state API (neither Zoom nor Teams expose one publicly) — MEDIUM confidence, standard practice among the third-party menu-bar Zoom-status tools found in research (SwiftBar/xbar Zoom plugins, "zoom-mute-status" utilities), all of which rely on process + audio-state polling for the same reason.

**Google Meet is a browser tab, not a process** — there is no reliable app-identity signal for it without reading browser tab titles (Accessibility) or a browser extension (new integration surface, out of scope this milestone). Recommendation: ship Zoom + Teams detection only for v1.10; treat "mic hot but no known meeting app running" as a generic, unlabeled "Call in progress" fallback rather than trying to name Meet specifically, or drop Meet from v1.10 scope entirely and flag as a known gap.

**Mute state — this is the part that genuinely needs a permission:**
- Reading/toggling Zoom's or Teams' *in-call* mute state requires `tell application "System Events" ... process "zoom.us" ...` GUI-scripting (confirmed from a working public reference script — see Sources) — driving another app's UI via System Events **requires Accessibility permission**, not just Automation. This is a heavier tier than the Automation-only prompt used for dark-mode toggling above.
- **Recommendation (ship this first):** don't chase precise in-call mute state. Show/toggle the **system-wide mic mute** (`kAudioDevicePropertyMute` on the input device — same property listed for the Quick Actions bar) as the Meeting-HUD's "mute" control. It's not literally "am I muted inside Zoom," but muting the OS input device makes you inaudible in *any* call regardless of app, and needs zero extra permission.
- **If per-app mute readout is explicitly wanted later:** technically possible via Accessibility-gated GUI scripting for Zoom (has a stable, scriptable "Meeting" menu); Teams' Electron menu structure is less consistently scriptable and would need its own spike. Flag as a MEDIUM-confidence, Accessibility-permission-cost follow-up, not v1.10 baseline.

### 2. Download-Progress

`FSEventStreamCreate` watching `~/Downloads` (public API). First access to `~/Downloads` triggers macOS's automatic "Files and Folders → Downloads Folder" TCC consent prompt (standard since Catalina, applies regardless of App Sandbox status) — expect and handle this the same way EventKit/WeatherKit permission prompts are already handled elsewhere in the app.

For an actual **progress fraction** (not just "a file appeared"): Safari (and some other downloaders) write the extended attribute `com.apple.progress.fractionCompleted` (0.0–1.0) on the in-progress temp file — this is literally the mechanism Finder itself reads to draw its native download progress bars. Read it where present. Fall back to watching partial-file naming conventions (`.crdownload` for Chrome, `.download` for Safari's older mechanism, `.part` for Firefox) and reporting indeterminate/spinner progress when no fraction attribute exists, since raw byte-growth alone doesn't give a total size.

### 3. Timer/Pomodoro

No new stack question beyond `UserNotifications` for the completion alert — pure Swift/SwiftUI state + `Timer`/`DispatchSourceTimer`, same shape as every other collapsed-pill HUD already in the app.

### 4. Quick Notes + Obsidian export

`NSOpenPanel` (folder mode) once to pick the vault folder, persist the path, then plain `FileHandle`/`String(contentsOf:)` append-with-timestamp to a fixed `.md` file. No sandboxing, so no security-scoped bookmark machinery needed. If the chosen folder lives under `~/Documents` or `~/Desktop`, expect the same one-time Files-and-Folders TCC prompt as Download-Progress.

### 5. Quick Actions bar

Four buttons, four independent public/quasi-public techniques, no shared new library:
- Mic mute → `kAudioDevicePropertyMute` (input device) — reuse existing CoreAudio pattern.
- Display sleep → `Process` → `pmset displaysleepnow`.
- Dark mode → `NSAppleScript` → System Events appearance toggle (Automation consent, one-time).
- Screen lock → `Process` → `CGSession -suspend` (undocumented Apple-shipped binary, no Accessibility needed).

### 6. Menübar-Overflow (Ice-style MVP)

**Verified directly from Ice's open-source implementation** (`jordanbaird/Ice`, MIT, files: `Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift`, `Ice/Bridging/Bridging.swift`):

- Every `NSStatusItem` is backed by a real, private, per-owning-process window at the menu-bar window level. Ice enumerates and reads their frames via **private CGS/SkyLight calls** — `CGSMainConnectionID()` for a connection handle, then `CGSGetScreenRectForWindow(connection, windowID, &rect)` for each item's on-screen frame (`Bridging.swift` also wraps `CGSGetWindowCount`, `CGSCopySpacesForWindows`, `CGSEventIsAppUnresponsive` — the exact same private-framework territory as this project's own `CGSSpace.swift`).
- Ice does **not** use any private "move this window" or "hide this item" API. Instead it **synthesizes a real mouse drag**: a `CGEvent(.leftMouseDown)` at the item's current position followed by a `CGEvent(.leftMouseUp)` at the target position, posted via `.post(tap: .cgSessionEventTap)` and targeted at the item-owning process's PID (`event.postToPid`). This is literally automating the built-in Cmd-drag "rearrange menu bar icons" gesture macOS already supports natively — no new system capability, just scripted use of an existing one.
- "Hiding" an item = dragging it to sit left/right of one of Ice's own reference `NSStatusItem`s that act as boundary markers for a "hidden section" — the item is still technically present in the menu bar, just positioned off past the visible edge / behind the chevron item. There is no true "hide" call; it's pure positional bookkeeping plus Ice's own always-visible chevron/divider item.
- Ice posts to `.cgSessionEventTap` (not `.cghidEventTap`) for these synthetic drags — worth noting since this project has specifically proven `.cghidEventTap` superior to `.cgSessionEventTap` for OSD-suppression reliability. Menu-bar item drags are a different use case (targeted at a specific owning PID, not global HID interception), so `.cgSessionEventTap` is likely correct here and shouldn't be assumed broken by the earlier finding — but worth a quick on-device confirmation during the phase, same spirit as the OSD-suppression spike.
- Risk tier: identical to this project's existing CGS-Space private-API acceptance. Flag explicitly as private/undocumented, same as MediaRemote/CGS/OSD suppression.

### 7. Caps Lock HUD

`NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`, checking `event.modifierFlags.contains(.capsLock)`. Requires Input Monitoring — **already granted** via the existing `.cghidEventTap` volume/brightness interception, so this ships with zero new permission friction. (A raw `.cghidEventTap` keyboard tap would also work and is marginally lower-level, but `NSEvent`'s global monitor is simpler and sufficient for a state readout that doesn't need to consume/suppress the event — no OSD-suppression-style consumption is needed here since there's no native Caps Lock OSD to fight.)

### 8. Update-Activity restyle

Cosmetic only — reskins the existing Sparkle 2.9.4 HUD. No new stack. (Per milestone brief, skipped from deeper research.)

### 9. Coding-Progress

**Hook events available** (Claude Code hooks reference, verified against official docs at `code.claude.com/docs/en/hooks`, current as of this research): `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, plus many more granular ones (`SubagentStart`/`SubagentStop`, `PreCompact`, `SessionEnd`, etc.) not needed here.

**Event → display mapping:**
- **Todo-list completion fraction** → `PostToolUse` with matcher `TodoWrite`. The hook receives `tool_input` on stdin, and for the `TodoWrite` tool `tool_input.todos` **is** the full new todo array (`{id, content, status: "pending"|"in_progress"|"completed"}` per item) — this is the tool's own input schema, not something the hook has to infer. The hook script computes `completed / total` directly from this array and writes it to the status file. This is the single richest, most direct signal available — no polling or transcript-parsing needed.
- **Fallback status text** (no active todo list) → `UserPromptSubmit` ("thinking / working on: <first line of prompt>"), generic `PreToolUse`/`PostToolUse` on any other tool (`tool_name` + a short summary of `tool_input`, e.g. "Editing App.swift"), `Notification` (Claude is waiting on permission or user input — good "needs attention" state), `Stop` (turn finished — good "idle" state), `SessionStart`/`SessionEnd` (session boundaries, clear the HUD).

**IPC format — two different watch mechanisms for two different shapes, matching the right-tool-per-case note above:**
- A single hook script (Node.js, see Development Tools) registered for all the events above in `~/.claude/settings.json`, each invocation reading its event's JSON from stdin and writing one small JSON status object — e.g. `~/.claude/islet-status.json`: `{ "event": "PostToolUse", "sessionId": "...", "timestamp": "...", "todos": {"completed": 3, "total": 7}, "statusText": "Editing App.swift" }` — overwritten atomically (write to temp file, `rename()`) on every hook firing.
- Islet watches that **single file** with `DispatchSourceFileSystemObject` (open fd, `.write` event mask) rather than `FSEventStreamCreate` — simpler, lower-latency, right-sized tool since there's exactly one file to watch (contrast with Download-Progress, a genuinely multi-file directory, where FSEvents is the right call).
- Scoped "session-local to this Mac" per the milestone brief — a single global status file (last-write-wins) is sufficient; no need for a per-session file registry.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `DispatchSourceFileSystemObject` for the Coding-Progress status file | `FSEventStreamCreate` for the same file | If the hook script ever needs to watch a *directory* of per-session files instead of one global file (e.g. multi-session support later) |
| CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` + process check for Meeting-HUD | Accessibility-gated System Events GUI scripting for precise in-call state | Only if the user explicitly wants per-app-accurate mute/call state badly enough to accept an Accessibility prompt — treat as a v1.11+ enhancement, not baseline |
| `CGSession -suspend` for screen lock | `pmset displaysleepnow` + "require password immediately after sleep" | If the user is fine with display-sleep-triggers-lock behavior (gentler on running apps) instead of a hard immediate lock — `CGSession` is preferred here because it locks unconditionally regardless of the user's own password-timeout setting |
| Node.js for the hook script | `jq`/bash, or Python 3 | Only if you want the hook script trivially readable by a non-JS-familiar contributor — Node has zero install cost here since Claude Code itself requires it |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| A new SPM package for any of the 9 features | Every capability is covered by a system framework or a CLI shell-out; adding a dependency here is pure surface area for zero benefit | The public/private APIs listed above |
| Full Accessibility permission for Meeting-HUD v1 | Big, scary system prompt, only buys precise per-app mute state that most users won't notice is "wrong" if it's actually just system mic mute | System-wide `kAudioDevicePropertyMute`, see Meeting-HUD section |
| `FSEventStreamCreate` for the Coding-Progress single status file | Wrong-sized tool — FSEvents is directory-tree-oriented and adds unnecessary latency/complexity for watching one known file | `DispatchSourceFileSystemObject` |
| Screen-Recording-permission-based approaches (e.g. reading browser tab titles via window capture) for Google Meet detection | Screen Recording is one of the heaviest, most user-alarming TCC prompts on macOS — wildly disproportionate for "is there a Meet call" | Ship Meet out of scope for v1.10, or accept the generic unlabeled "call in progress" fallback from the mic-hot heuristic |

## Stack Patterns by Variant

**If a future feature needs to read another app's on-screen menu content (not just move status items):**
- Expect to need Accessibility permission (System Events GUI scripting), not just Automation — Automation alone (used for the dark-mode toggle here) only lets you *invoke* commands another app has explicitly scripted for, not read/click arbitrary UI.

**If Meeting-HUD is later extended to browser-based Meet:**
- Will need either a browser extension (new, separate integration surface — likely a bigger scoping conversation) or Accessibility-based tab-title reading. Don't reach for Screen Recording.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| CGS/SkyLight private symbols (`CGSMainConnectionID`, `CGSGetScreenRectForWindow`) | macOS 15.0+ | Same private framework the project already links against for `CGSSpace.swift`; Ice (targeting current macOS releases per its own release notes) uses the identical symbols, giving independent confirmation they're still present/functional on current macOS |
| `kAudioDevicePropertyDeviceIsRunningSomewhere` / `kAudioDevicePropertyMute` | macOS 15.0+ | Long-stable `AudioHardware.h` selectors, unchanged across recent macOS versions, same header family as the existing volume-HUD calls |
| Claude Code hooks JSON schema | Current Claude Code CLI (as of this research) | Hook event list is actively growing (30 events found in current docs vs. the 6 named in the milestone brief) — the 6 named events are stable/foundational and unlikely to be removed, but re-check `code.claude.com/docs/en/hooks` at phase-planning time in case field names shifted |

## Sources

- `jordanbaird/Ice` GitHub repository, `Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift` and `Ice/Bridging/Bridging.swift` (fetched directly, MIT license) — HIGH confidence, primary source, exact mechanism confirmed by reading the actual implementation
- `code.claude.com/docs/en/hooks` — official Claude Code hooks reference — HIGH confidence for event list and general JSON-input/stdout-control mechanism; TodoWrite `tool_input.todos` shape is HIGH confidence from the TodoWrite tool's own well-established input schema (not explicitly spelled out on the generic hooks page, cross-checked against how `PostToolUse`/`tool_input` is documented to mirror the tool's actual call arguments)
- Apple Developer Forums thread "Detect when (internal or external) microphone is being used" — MEDIUM confidence, confirms `kAudioDevicePropertyDeviceIsRunningSomewhere` works for built-in/wired mics, unreliable for Bluetooth
- `gist.github.com/henrik/38a7a76a217552d8f4fc672535fe91c5` (Zoom mute-toggle AppleScript proof-of-concept) — MEDIUM confidence, confirms the System-Events-GUI-scripting technique and that it targets Zoom's own "Meeting" menu, not a native Zoom AppleScript dictionary
- OS X Daily, "Lock the Mac Desktop from the Command Line" + multiple current community confirmations — MEDIUM confidence that `CGSession -suspend` still works through Sonoma/Sequoia; no official Apple API exists (confirmed absence via Apple Developer Forums threads asking the same question with no official answer)
- `com.apple.progress.fractionCompleted` extended attribute — MEDIUM confidence, community-documented Finder/NSProgress convention, not an official Apple doc page but widely and consistently described the same way across multiple independent sources
- Apple `AudioHardware.h` / CoreAudio property selectors — HIGH confidence, same API family already in production use in this project

---
*Stack research for: macOS notch-overlay Live Activities Suite (v1.10)*
*Researched: 2026-07-23*
