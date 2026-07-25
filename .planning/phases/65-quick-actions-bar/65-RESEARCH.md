# Phase 65: Quick Actions Bar - Research

**Researched:** 2026-07-26
**Domain:** macOS system control APIs (CoreAudio, IOKit, AppKit, Apple Events/AppleScript, private frameworks) + this codebase's existing switcher-tab/Settings-card architecture
**Confidence:** MEDIUM-HIGH (mechanism-by-mechanism — see Metadata table; two of eight actions carry genuine platform uncertainty, which is the point of QACTION-03)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Bar placement
- **D-01:** Quick Actions is a new switcher-tab presentation, joining the existing catalog of assignable slot types (Home/Weather/Calendar/Tray) rather than becoming a dedicated always-visible strip or being merged into Home. It becomes a 5th option in Phase 52's existing per-slot dropdown catalog — the switcher row's 4-slot layout math (`switcherRowHeight`, slot count) is unchanged; this is purely a catalog addition, not a structural resize. Resolves the reserved "relationship unclear, rank TBD" comment in `IslandResolver.swift`.

### Settings config UI
- **D-02:** The bar's own internal action slots are configured via per-slot dropdown pickers — the same UI mechanism Phase 52 (SWITCH-03/04) already built for the switcher row (`orderedSlotIcons`, independent `@AppStorage` per slot). One dropdown per bar position, each choosing a catalog action or "none." Not a drag-reorder checklist — no such component exists in this codebase today, and the dropdown pattern is already proven.

### Bar capacity
- **D-03:** The bar is fixed at ~8 total slots, matching the roadmap's literal "~8-action row." The multiple independent launch slots (D-05) share this same fixed pool — configuring more launchers means giving up other catalog actions, the bar does not grow past 8 or become scrollable.

### Tap feedback
- **D-04:** A brief icon pulse/flash animation confirms every tap, uniformly across all actions — not left to per-action discretion. Actions with their own visible state (mute icon, dark-mode icon) may additionally swap their icon, but the pulse confirms the tap registered even for one-shot actions (empty Trash, caffeinate) that have no other visible effect on the bar itself.

### Launch action
- **D-05:** "Launch app/open URL" is not a single fixed catalog entry — the user can configure multiple independent launch slots, each bound to its own app or URL. These launch slots draw from the same fixed 8-slot pool (D-03), not an unbounded addition.

### Claude's Discretion
- Exact SF Symbols/icons for each catalog action.
- Exact pulse/flash animation timing and visual style (D-04).
- DND/Focus action's exact failure-state visual treatment (QACTION-03 requires visibility, not silence, but the specific look — icon strike-through, brief error color, disabled state — is unspecified; not discussed in this session, resolve during UI-spec).
- Naming of the new `IslandPresentation`/switcher-slot case for Quick Actions.
- Technical mechanism for each non-mute action (display sleep, dark mode, screen lock, DND, caffeinate, empty Trash, launch app/URL) — research/planning task, only the mic-mute mechanism is locked (reuses `MicMuteController`).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- "Quick Action disabled state has no controller gate" (`2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) — matched Phase 65 by keyword ("quick action") but is actually about Phase 34's unrelated drag-drop AirDrop/Mail destination picker (`handleDragApproachEnd()`'s dead `enabled:` gate), not this phase's Settings-configured action bar. Left unfolded; still open against Phase 34's code if ever revisited.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QACTION-01 | Settings lets the user enable/reorder a Quick Actions bar shown in the notch, choosing from a fixed catalog: mic mute/unmute, display sleep now, dark/light mode toggle, screen lock, Do Not Disturb toggle (best-effort), caffeinate/keep-awake toggle, empty Trash, launch app/open URL | Standard Stack table (per-action mechanism), Architecture Patterns (System Architecture Diagram, Recommended Project Structure), Don't Hand-Roll (`ActivityCardData`/`slotOptions` reuse), Pitfall 5 (Timer-precedent trap) |
| QACTION-02 | Tapping an enabled Quick Action performs it immediately without expanding the notch any further than the action bar itself | Architecture Patterns (System Architecture Diagram — resolver branch + per-action helper dispatch), Validation Architecture (resolver unit tests) |
| QACTION-03 | The Do Not Disturb/Focus action is documented as best-effort (no stable public macOS API) — a failure is visible to the user, not silently swallowed | Pattern 2 (Read-back verification), Standard Stack (`INFocusStatusCenter` read-back row), Pitfall 4 (two separate Focus features), Open Question 1 (exact mechanism + setup UX) |
</phase_requirements>

## Summary

Quick Actions Bar is primarily an **integration** phase, not a from-scratch feature: 6 of the 8 catalog actions have solid, well-documented (if occasionally private-API) mechanisms, one (`mic mute`) is a pure reuse of existing code, and the whole Settings/switcher-tab scaffolding this phase needs (per-slot dropdown catalog, `SelectedView` enum, `ActivityCard` "Coming Soon" flip, `IslandPresentation` case + `resolve()` branch, `showsSwitcherRow`) is an exact structural clone of patterns Phases 52/59/62 already built and this session verified by reading the live code.

The two hard problems are screen lock (no public API — must use a private `login.framework` symbol via `dlopen`/`dlsym`, confirmed by community consensus but unconfirmed on very recent macOS) and Do Not Disturb/Focus (no public *write* API exists at all — confirmed by this session's web research — but this codebase already has a public, working, entitled *read* API (`INFocusStatusCenter`, Phase 38's `FocusModeMonitor`) that can verify whether a best-effort toggle attempt actually took effect, which is the exact mechanism QACTION-03's "failure visible, not silent" requirement needs).

Every entitlement this phase's hardest actions need — `com.apple.security.automation.apple-events` (AppleScript control of System Events/Finder), `com.apple.security.cs.disable-library-validation` (dlopen of a private framework), `com.apple.developer.usernotifications.communication` (INFocusStatusCenter) — is **already present** in `Islet/Islet.entitlements` `[VERIFIED: local file read]`. This phase needs zero entitlement/re-signing changes.

**Primary recommendation:** Build Quick Actions as a 5th catalog entry in the existing switcher-slot dropdown system (per CONTEXT.md D-01/D-02, verified against live code), give each of the 8 action primitives its own small isolated helper file (mirroring `MicMuteController.swift`'s one-fragile-surface-per-file convention), and make the DND/Focus action's helper read back `INFocusStatusCenter` after every toggle attempt to honestly report success/failure — never assume success just because the write call didn't throw.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Quick Actions bar UI (8-slot row, tap targets, pulse feedback) | Frontend (SwiftUI, NotchPillView) | — | Pure rendering + local closures, same tier as every other `IslandPresentation` case |
| Settings enable/reorder UI (per-slot dropdowns) | Frontend (SwiftUI, SettingsView) | — | Exact clone of Phase 52's switcher-slot dropdown pattern |
| Mic mute/unmute | System (CoreAudio via existing `MicMuteController.swift`) | — | Reused verbatim per Phase 63 D-04 lock; no new tier touched |
| Display sleep now | System (`pmset` CLI via `Process`) | — | Thin OS-process wrapper, no in-app state |
| Dark/light mode toggle | System (AppleScript/Apple Events to System Events) | Frontend (read via `NSApp.effectiveAppearance` for icon state) | Write needs Apple Events (System tier); read is in-process AppKit |
| Screen lock | System (private `login.framework` symbol via `dlopen`) | — | No public API exists; isolated helper, private-API risk contained to one file |
| Do Not Disturb/Focus toggle | System (best-effort external trigger) + System (read-back verification via `INFocusStatusCenter`) | Frontend (failure-state UI) | Write and read are two DIFFERENT APIs on two different tiers of confidence — must not be conflated |
| Caffeinate/keep-awake toggle | System (IOKit `IOPMAssertionCreateWithName`) | — | Public, documented, in-process — no child process needed |
| Empty Trash | System (AppleScript to Finder) | — | Avoids TCC/Full-Disk-Access complexity of direct `~/.Trash` file deletion |
| Launch app/open URL | System (`NSWorkspace.shared.open`) | Frontend (`NSOpenPanel` app picker + URL text field for config) | Public AppKit API; config UI is frontend-only |

## Standard Stack

No new external packages. This phase uses only Apple system frameworks already linked in the project: `CoreAudio`/`AudioToolbox` (existing), `IOKit`, `Intents`, `AppKit`, `Foundation` (`NSAppleScript`), `Darwin`/`dlfcn.h` (`dlopen`/`dlsym`). `[VERIFIED: local codebase read]`

### Core (per-action mechanism)

| Action | Mechanism | API / Command | Confidence |
|--------|-----------|----------------|------------|
| Mic mute/unmute | Reuse | `toggleSystemInputMute()` / `readSystemInputMuted()` in `Islet/Notch/MicMuteController.swift` | HIGH `[VERIFIED: local codebase read]` |
| Display sleep now | Shell out | `Process` launching `/usr/bin/pmset displaysleepnow` | HIGH `[VERIFIED: local `man pmset`]` |
| Dark/light mode toggle (write) | AppleScript/Apple Events | `NSAppleScript(source: "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")` | MEDIUM `[CITED: multiple community sources, cross-verified]` |
| Dark/light mode (read, for icon state) | AppKit | `NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])` | HIGH `[ASSUMED — well-known public API, not independently re-verified this session]` |
| Screen lock | Private framework via dlopen | `dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)` then `dlsym(..., "SACLockScreenImmediate")`, `@convention(c) () -> Void` | MEDIUM `[CITED: albertopasca.it + multiple corroborating community sources; unconfirmed on very recent macOS]` |
| DND/Focus toggle (write, best-effort) | Shortcuts CLI | `/usr/bin/shortcuts run "<user-created shortcut name>"` invoking a Shortcut built with Apple's "Set Focus" action | MEDIUM `[CITED: community sources, 2024-2025]` — see Open Questions |
| DND/Focus read-back (verify) | `Intents` framework | `INFocusStatusCenter.default.focusStatus.isFocused` (already used by `Islet/Notch/FocusModeMonitor.swift`) | HIGH `[VERIFIED: local codebase, confirmed working on-device per Phase 38 SUMMARY]` |
| Caffeinate/keep-awake toggle | IOKit power assertions | `IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertionID)` / `IOPMAssertionRelease(assertionID)` | HIGH `[CITED: Apple sample code + widespread developer usage]` |
| Empty Trash | AppleScript to Finder | `NSAppleScript(source: "tell application \"Finder\" to empty the trash without warns before emptying")` | MEDIUM-HIGH `[CITED: MacScripter community, cross-verified across multiple sources]` |
| Launch app/open URL | AppKit | `NSWorkspace.shared.open(url)` (URL or app bundle path); config via `NSOpenPanel` (`allowedContentTypes = [.application]`) mirroring `quickNotesVaultPickerView`'s existing folder-picker pattern | HIGH `[VERIFIED: NSWorkspace.shared.open already used at 5+ call sites in this codebase]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Screen lock via `login.framework` dlopen | `CGSession -suspend` (bundled `/System/Library/CoreServices/Menu Extras/User.menu/.../CGSession`) | **Rejected** — multiple sources agree this stopped working as of macOS Big Sur; do not use |
| Screen lock via `login.framework` dlopen | AppleScript keystroke `Cmd+Ctrl+Q` via System Events | Needs Accessibility grant for System Events (separate, stronger TCC gate than Automation alone) AND the user must have that shortcut assigned (off by default); community reports it broke intermittently across Ventura point releases. Viable as a documented fallback, not primary. |
| DND toggle via Shortcuts CLI | UI-scripting (simulate clicking Control Center → Focus button via System Events) | **Rejected as primary** — extremely fragile to Control Center layout/localization changes, needs Accessibility permission; multiple community reports of breakage across OS updates |
| Empty Trash via AppleScript | Direct `FileManager` deletion of `~/.Trash` contents | **Rejected** — items whose *origin* was a TCC-protected folder (Desktop/Documents/Downloads) can retain protected-folder provenance even after being moved to Trash on some macOS versions, causing silent partial failures; routing through Finder (which already holds the necessary rights) avoids this entirely |
| Caffeinate via IOKit assertion | Shell out to `/usr/bin/caffeinate -d &` and kill on toggle-off | IOKit assertion is in-process (no child-process lifecycle to manage, no zombie risk if the app crashes mid-assertion — the assertion dies with the process automatically), and is the same mechanism apps like Amphetamine/KeepingYouAwake use |

**Installation:** None — no new dependencies, no `Package.swift`/SPM changes, no new entitlements.

## Package Legitimacy Audit

Not applicable — this phase adds zero external packages. All mechanisms use Apple system frameworks (`CoreAudio`, `IOKit`, `Intents`, `AppKit`, `Foundation`) already linked in the Xcode project, or shell out to Apple-shipped system binaries (`pmset`, `shortcuts`). No `npm`/`pip`/`cargo`/SPM install step exists for this phase, so slopcheck/registry verification does not apply.

## Architecture Patterns

### System Architecture Diagram

```
Settings (SettingsView.swift)
  │
  ├─ "Quick Actions" ActivityCard (isComingSoon: false, flip from Phase 59 placeholder)
  │     └─ onOptionsTap → popover: 8× Picker("Slot N", selection: $slotN) { catalog options }
  │           (mirrors quickNotesVaultPickerView's popover shape — NOT a drag-reorder list)
  │
  └─ Switcher "Icon Placement" section (existing, Phase 52)
        └─ slotOptions ForEach — GAINS a 5th Label(...).tag(SelectedView.quickActions) line
              (existing 4 dropdowns list Home/Tray/Calendar/Weather explicitly, never .allCases —
               Quick Actions joins that explicit list, same as Timer was deliberately EXCLUDED from it)

User taps a switcher slot showing Quick Actions icon
  │
  ▼
ViewSwitcherState.selectedView = .quickActions
  │
  ▼
IslandResolver.resolve(..., selectedView: .quickActions, ...)
  │  (new branch: if selectedView == .quickActions { return .quickActionsBarExpanded })
  ▼
NotchPillView renders quickActionsBarContent for case .quickActionsBarExpanded
  │  (ForEach over up to 8 configured slots, each backed by its own @AppStorage action-ID key)
  ▼
User taps one action button
  │
  ├─ pulse/flash animation fires immediately (D-04, uniform across all 8 actions)
  ▼
Per-action isolated helper executes (one seam per action, mirroring MicMuteController.swift):
  ├─ MicMuteController.toggleSystemInputMute()               [reuse, Phase 63]
  ├─ DisplaySleepAction.sleepNow()                             [Process → pmset]
  ├─ DarkModeToggleAction.toggle()                             [NSAppleScript → System Events]
  ├─ ScreenLockAction.lockNow()                                [dlopen → SACLockScreenImmediate]
  ├─ FocusToggleAction.toggle(then: verifyAndReport)           [shortcuts CLI, THEN read INFocusStatusCenter]
  ├─ CaffeinateToggleAction.toggle()                           [IOPMAssertionCreateWithName/Release]
  ├─ EmptyTrashAction.empty()                                  [NSAppleScript → Finder]
  └─ LaunchAction.launch(target)                               [NSWorkspace.shared.open]
```

### Recommended Project Structure

```
Islet/Notch/
├── MicMuteController.swift          # existing, Phase 63 — reused verbatim, NOT touched
├── QuickActionsBar/                 # NEW — one file per action helper, mirrors the
│   ├── DisplaySleepAction.swift     # existing one-fragile-surface-per-file convention
│   ├── DarkModeToggleAction.swift
│   ├── ScreenLockAction.swift
│   ├── FocusToggleAction.swift      # isolates the ONE genuinely uncertain mechanism
│   ├── CaffeinateToggleAction.swift
│   ├── EmptyTrashAction.swift
│   ├── LaunchAction.swift
│   └── QuickActionCatalog.swift     # the fixed 8-entry enum + per-slot @AppStorage keys
├── IslandResolver.swift             # + 1 new IslandPresentation case, + 1 resolve() branch
├── ViewSwitcherState.swift          # + .quickActions case on SelectedView
└── NotchPillView.swift              # + quickActionsBarContent view, + icon(for:) branch
```

### Pattern 1: One fragile/uncertain system surface per file

**What:** Every action that touches a fragile or undocumented macOS surface gets its own tiny, isolated file — never bundled into a shared "SystemActions" god-file.
**When to use:** Any of the 8 action mechanisms below, especially Screen Lock (private API) and Focus toggle (no public API at all).
**Example:**
```swift
// Source: mirrors Islet/Notch/MicMuteController.swift's existing header-comment convention
// ONE fragile system surface, ONE file — if SACLockScreenImmediate ever breaks/moves,
// this is the only file that needs to change.
import Darwin

enum ScreenLockAction {
    static func lockNow() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",
            RTLD_LAZY
        ) else { return }
        guard let sym = dlsym(handle, "SACLockScreenImmediate") else { return }
        typealias LockFn = @convention(c) () -> Void
        let lock = unsafeBitCast(sym, to: LockFn.self)
        lock()
    }
}
```

### Pattern 2: Read-back verification for best-effort actions (QACTION-03)

**What:** For the ONE action with no public write API (DND/Focus), never assume the write succeeded just because the shell-out didn't throw. Re-read the public, already-integrated `INFocusStatusCenter` state after a short delay and compare against the expected new state.
**When to use:** FocusToggleAction only — every other action either has a synchronous return value to check (`toggleSystemInputMute() -> Bool?`) or a fire-and-forget system call whose success is safe to assume (`pmset`, `NSWorkspace.open`).
**Example:**
```swift
// Source: builds on Islet/Notch/FocusModeMonitor.swift's existing INFocusStatusCenter usage
enum FocusToggleAction {
    static func toggle(shortcutName: String, onResult: @escaping (Bool) -> Void) {
        guard FocusModeMonitor.isAuthorized else { onResult(false); return }
        let before = INFocusStatusCenter.default.focusStatus.isFocused ?? false

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", shortcutName]
        do {
            try task.run()
        } catch {
            onResult(false)   // shortcut missing / shortcuts CLI unavailable — visible failure
            return
        }
        task.terminationHandler = { _ in
            // Give Focus state a moment to settle, then read back via the SAME public
            // API Phase 38's FocusModeMonitor already uses — never trust the exit code alone.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let after = INFocusStatusCenter.default.focusStatus.isFocused ?? before
                onResult(after != before)
            }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Naming any new type/case with a bare "QuickAction" prefix:** `Islet/Notch/QuickActionSharingService.swift` and `IslandPresentation.quickActionPicker(PendingDrop)` are Phase 34's UNRELATED drag-and-drop-to-AirDrop/Mail destination picker. This session confirmed via `IsletTests/QuickActionSharingServiceTests.swift` and `IslandResolver.swift`'s own header comment. Name this phase's new case `.quickActionsBarExpanded` (or similar), never bare `.quickAction*`.
- **Assuming Focus/DND write succeeded because the AppleScript/CLI call returned without error:** No public write API exists; a "successful" shell invocation of a missing/misconfigured Shortcut can still silently no-op. Always verify via `INFocusStatusCenter` read-back (Pattern 2).
- **Deleting `~/.Trash` contents directly via `FileManager`:** provenance-tracked TCC protection on some files can cause silent partial failures. Route through Finder via AppleScript instead.
- **Building a new drag-reorder component for Settings:** CONTEXT.md D-02 already locks per-slot dropdowns (Phase 52's proven pattern) — no drag-reorder component exists in this codebase and building one would be new, unrequested UI infrastructure.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| System-wide mic mute | A new CoreAudio helper | `Islet/Notch/MicMuteController.swift` (verbatim) | Phase 63 D-04 lock; a second implementation would be a second surface to keep in sync with the Meeting-HUD's |
| Keep-awake / caffeinate | Spawning/killing a `caffeinate` child process | `IOPMAssertionCreateWithName`/`IOPMAssertionRelease` (IOKit, public, in-process) | Public documented API, no process lifecycle management, assertion dies automatically with the app if it crashes |
| Focus/DND state detection | A new polling mechanism reading `~/Library/DoNotDisturb/DB/Assertions.json` | `INFocusStatusCenter.default.focusStatus.isFocused` (already wired in `FocusModeMonitor.swift`) | Phase 38 already discovered and integrated the ONLY working public read path on this dev machine (macOS 26/Tahoe); the Assertions.json/Full-Disk-Access fallback was explicitly rejected as Path B |
| Switcher-slot catalog dropdown UI | A new picker/dropdown component | `slotOptions` `@ViewBuilder` + `Picker(..., selection:)` pattern (`SettingsView.swift`) | Exact existing mechanism; Quick Actions is "just" a 5th `Label(...).tag(...)` line |
| Settings card with "enable" toggle + options button | A new card component | `ActivityCardData`/`ActivityCard` (`Islet/ActivityCard.swift`) — already has an `isComingSoon` placeholder card wired for exactly this activity (`quickActionsKey`, `productivityCards`) | Phase 59 pre-built the card and the `@AppStorage` key; this phase flips `isComingSoon: false` and wires `onOptionsTap` |

**Key insight:** Almost nothing in this phase is a genuinely new UI mechanism — it is 8 small system-call helpers plumbed into scaffolding three prior phases (52, 59, 63) already built and left placeholders for. The research risk is concentrated entirely in the 8 action mechanisms' macOS-version reliability, not in this codebase's architecture.

## Common Pitfalls

### Pitfall 1: Naming collision with Phase 34's unrelated "Quick Action" feature
**What goes wrong:** A new type/case named `QuickAction*` silently shadows or gets confused with `QuickActionSharingService.swift` / `IslandPresentation.quickActionPicker(PendingDrop)`, which is Phase 34's drag-drop-to-AirDrop/Mail destination picker — a completely different feature that predates this phase.
**Why it happens:** Both features use the literal phrase "quick action" (Phase 34's UI-SPEC calls its destination picker exactly that), and CONTEXT.md's own deferred-todos section already flagged a todo that matched this phase by keyword search but was actually about Phase 34.
**How to avoid:** Prefix every new type with `QuickActionsBar` (not bare `QuickAction`), e.g. `QuickActionsBarCatalog`, `.quickActionsBarExpanded`.
**Warning signs:** `grep -rn "QuickAction" Islet/` returning hits in files this phase didn't touch.

### Pitfall 2: Assuming a shell-out or AppleScript call's lack of a thrown error means success
**What goes wrong:** `NSAppleScript.executeAndReturnError` and `Process.run()` can both "succeed" (no Swift-level throw) while the underlying system action silently no-ops — e.g., TCC denial returns an `errorDict` (not a thrown Swift error) with `errAEEventNotPermitted` (-1743), and a missing Shortcut name still lets `shortcuts run` exit — these must be checked explicitly.
**Why it happens:** `NSAppleScript`'s error reporting is an `NSDictionary` out-parameter, not a throwing function — trivially easy to leave unchecked, especially since this exact -1743 code and pattern is only exercised today in a `#if DEBUG` spike (`NowPlayingMonitor.swift`'s `spikeTriggerAutomationPrompt`), not in shipped code.
**How to avoid:** Always check the `errorDict` return from `executeAndReturnError`, and for the Focus/DND action specifically, verify via `INFocusStatusCenter` read-back (Pattern 2) rather than trusting the call's return path at all.
**Warning signs:** Dark Mode toggle / Empty Trash "succeeding" silently while the system state visibly doesn't change on a machine where Automation permission was denied.

### Pitfall 3: Screen lock's private API may not survive every macOS point release
**What goes wrong:** `SACLockScreenImmediate` is undocumented; multiple sources agree the previously-standard `CGSession -suspend` technique broke outright as of Big Sur, and this session found no direct confirmation `SACLockScreenImmediate` has been tested on Sonoma/Sequoia (confirmed working through Monterey per available sources).
**Why it happens:** Private frameworks carry zero API stability guarantee across OS versions.
**How to avoid:** Isolate to its own file (Pattern 1) so a future breakage is a one-file fix; consider guarding the `dlopen`/`dlsym` calls to fail silently (return without crashing) rather than force-unwrapping, mirroring `MicMuteController.swift`'s "any guard failure → safe default, never crash" discipline. Manually test screen lock on the actual target macOS version before shipping (this is exactly the kind of claim this codebase's own conventions treat as needing on-device verification, not just research).
**Warning signs:** A future macOS update silently making the tap a no-op with no crash and no error — pair this action with the SAME tap-pulse/icon-swap feedback every other action gets (D-04) so at least a "nothing happened" outcome is not entirely invisible, though true failure detection (mirroring Focus's read-back) is not possible here since there's no public "is the screen locked" read API to verify against.

### Pitfall 4: Confusing Islet's TWO separate Focus-related features
**What goes wrong:** Phase 38 already shipped a "Focus Mode" ambient HUD (`FocusActivity`, `activity.focus` key, `focusPermissionExplanationView` in Settings) that DETECTS and displays Focus/DND state. Phase 65's Quick Actions DND toggle is a DIFFERENT feature that ATTEMPTS TO CHANGE that state — the two are easy to conflate since they read the same underlying `INFocusStatusCenter` authorization.
**Why it happens:** Same TCC authorization bucket (`INFocusStatusCenter.default.authorizationStatus`), same permission-explanation-popover UX convention.
**How to avoid:** The Quick Actions DND helper should call `FocusModeMonitor.isAuthorized` / `FocusModeMonitor.requestAuthorization(completion:)` (the EXISTING static entry points) rather than duplicating authorization-request logic — but it does NOT need Phase 38's `activity.focus` toggle to be ON; these are independent settings gates that happen to share one OS-level permission.
**Warning signs:** A plan task that gates the Quick Actions DND slot's availability on `ActivitySettings.focusKey` rather than `ActivitySettings.quickActionsKey` — these must stay decoupled.

### Pitfall 5: Timer's precedent for "who owns the switcher-slot catalog" is the OPPOSITE of this phase's own decision
**What goes wrong:** `SelectedView.timer` is deliberately EXCLUDED from the 4 configurable switcher slots (it's a fixed 5th tab, gated on `timerEnabled`, per Phase 62-04's own header comment in `ViewSwitcherState.swift`). A plan that copies Timer's exact mechanism for Quick Actions would build a FIXED extra tab, contradicting CONTEXT.md D-01's explicit "5th option in the per-slot dropdown catalog" (i.e., user-assignable to any of the 4 existing slots, replacing e.g. Weather in that slot — not a fixed always-there 5th icon).
**Why it happens:** Timer is the most recent, freshest precedent in the file and looks superficially similar ("new activity gets a new switcher-tab").
**How to avoid:** Add `.quickActions` to `slotOptions`' explicit list (4 `Label(...).tag(...)` lines becomes 5), NOT to `orderedSlotIcons`'s fixed-4-param signature and NOT as an unconditional append in `switcherRow`/`topEdgeSwitcherRow` the way `timerEnabled` is.
**Warning signs:** `orderedSlotIcons`'s signature growing a 5th parameter, or Quick Actions appearing in the switcher row regardless of what the 4 slot dropdowns are set to.

## Code Examples

### Caffeinate/keep-awake toggle (public IOKit API)
```swift
// Source: Apple sample code pattern (IOPMLib.h), cross-verified against community usage
// (Amphetamine/KeepingYouAwake-style apps)
import IOKit.pwr_mgt

final class CaffeinateToggleAction {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func toggle() {
        if isActive {
            IOPMAssertionRelease(assertionID)
            isActive = false
        } else {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Islet Quick Actions — keep awake" as CFString,
                &assertionID
            )
            isActive = (result == kIOReturnSuccess)
        }
    }
}
```

### Empty Trash without a confirmation dialog
```swift
// Source: MacScripter community pattern, cross-verified; mirrors NowPlayingMonitor.swift's
// existing NSAppleScript + errorDict error-checking discipline
func emptyTrash(completion: @escaping (Bool) -> Void) {
    let script = NSAppleScript(source:
        "tell application \"Finder\" to empty the trash without warns before emptying")
    var errorDict: NSDictionary?
    script?.executeAndReturnError(&errorDict)
    completion(errorDict == nil)
}
```

### Dark/light mode toggle
```swift
// Source: cross-verified against multiple community sources (forums.macrumors.com,
// techearl.com, MacScripter); reuses this codebase's existing errorDict pattern
func toggleDarkMode(completion: @escaping (Bool) -> Void) {
    let script = NSAppleScript(source:
        "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
    var errorDict: NSDictionary?
    script?.executeAndReturnError(&errorDict)
    completion(errorDict == nil)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `CGSession -suspend` for screen lock | Private `login.framework` `SACLockScreenImmediate` via dlopen | Broke as of macOS Big Sur (2020) | Any research/blog post recommending `CGSession -suspend` for a NEW build should be treated as stale |
| `~/Library/Preferences/.../doNotDisturb` plist toggling for DND | No reliable direct-write mechanism at all; Shortcuts "Set Focus" action (Monterey+) is the closest sanctioned automation surface | Focus rewrite, macOS Monterey (2021) | Any pre-2021 DND-toggle tutorial is obsolete |

**Deprecated/outdated:** `CGSession -suspend` (screen lock) — do not use. Direct plist manipulation for DND (pre-Monterey Notification Center) — do not use, Focus's internal storage has moved multiple times since.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])` correctly reflects live system-wide appearance for icon-state purposes | Standard Stack | Low — well-known, stable public AppKit API; worst case is a stale icon until next poll/redraw, not a functional failure |
| A2 | `SACLockScreenImmediate` continues to work on the target macOS version(s) this app ships to (confirmed only through Monterey in available sources) | Standard Stack, Pitfall 3 | Medium — if broken, screen lock silently no-ops; MUST be manually verified on-device on the actual target OS before this phase is considered done, per this codebase's own "on-device verification over research assumption" convention (see Phase 38's Path A/Path B substitution precedent) |
| A3 | `/usr/bin/shortcuts run "<name>"` is an acceptable best-effort DND mechanism despite requiring one-time user setup (creating a Shortcut with "Set Focus") | Standard Stack, Open Questions | Medium — if the user-setup friction is unacceptable, this needs to be re-discussed; CONTEXT.md did not resolve the exact DND mechanism (left as "Claude's Discretion... research/planning task") |
| A4 | Finder's `empty the trash without warns before emptying` AppleScript syntax is current/correct (not deprecated Finder-dictionary syntax) | Code Examples | Low-Medium — worst case this specific clause fails and falls back to the plain `empty trash` (which may show the OS confirmation dialog, violating QACTION-02's "no unrelated activity interrupts it") — verify with a live Script Editor test before implementation |

## Open Questions

1. **Exact DND/Focus best-effort mechanism and its required user setup**
   - What we know: No public write API exists (confirmed by web research and cross-referenced against this codebase's own Phase 38 finding that even the *read* API took a spike to discover). Shortcuts CLI invoking a "Set Focus" Shortcut is the most current (2024-2025) community-recommended automation surface.
   - What's unclear: Whether requiring the user to pre-build a Shortcut (extra setup step, not mentioned anywhere in CONTEXT.md) is acceptable, versus attempting the more fragile UI-scripting/keystroke-simulation route that needs no separate user setup but is far less reliable and needs Accessibility permission.
   - Recommendation: Plan should treat "no Shortcut configured yet" as the QACTION-03 failure state itself (visible, not silent) — tapping the DND slot before setup shows the failure/setup-needed treatment (per CONTEXT.md's "Claude's Discretion: DND/Focus action's exact failure-state visual treatment"), with a Settings-side hint on how to create the required Shortcut. This turns an awkward setup requirement into the exact UX the requirement already demands.

2. **Screen lock's real-world reliability on the actual shipping macOS version(s)**
   - What we know: Community sources confirm `SACLockScreenImmediate` worked through at least Monterey; no source in this session's research confirmed or denied Sonoma/Sequoia/Tahoe.
   - What's unclear: Direct behavior on whatever macOS version(s) this app currently targets.
   - Recommendation: Manual on-device verification task, mirroring Phase 38's own Path A/Path B on-device-spike precedent — do not treat this research as sufficient to skip a manual test.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `pmset` (Apple-shipped CLI) | Display sleep now | ✓ | System-shipped, confirmed via local `man pmset` | — |
| `caffeinate`/IOKit `IOPMLib` | Keep-awake toggle | ✓ | System framework, confirmed via local `man caffeinate` | — |
| `shortcuts` CLI (Apple-shipped, Monterey+) | DND/Focus best-effort toggle | Not directly probed this session (assume present — ships with macOS since Monterey) | — | AppleScript/UI-scripting fallback (lower reliability, documented above) |
| `login.framework` (private, system-shipped) | Screen lock | Not directly probed (path exists on all supported macOS versions per community consensus) | — | AppleScript keystroke simulation (documented above, lower reliability) |
| `com.apple.security.automation.apple-events` entitlement | Dark mode toggle, Empty Trash | ✓ | Already present in `Islet/Islet.entitlements` | — |
| `com.apple.security.cs.disable-library-validation` entitlement | Screen lock (dlopen private framework) | ✓ | Already present in `Islet/Islet.entitlements` | — |
| `com.apple.developer.usernotifications.communication` entitlement | DND/Focus read-back via `INFocusStatusCenter` | ✓ | Already present in `Islet/Islet.entitlements`; already proven working on-device by Phase 38 | — |

**Missing dependencies with no fallback:** None identified.
**Missing dependencies with fallback:** Screen lock and DND toggle each have a documented (lower-reliability) fallback mechanism if their primary mechanism fails on-device.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (existing) |
| Config file | `Islet.xcodeproj` (scheme-driven, no separate test config file) |
| Quick run command | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` (swap in new/relevant test class) |
| Full suite command | `xcodebuild test -project Islet.xcodeproj -scheme Islet` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QACTION-01 | `resolve(selectedView: .quickActions)` returns `.quickActionsBarExpanded`; slot dropdowns persist independently via `@AppStorage` | unit | `xcodebuild test ... -only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 (new test cases to add to existing file) |
| QACTION-02 | Tapping a configured action slot fires the action's helper and nothing else (no unrelated `resolve()` branch triggered) | unit (pure resolver) + manual (real system call side effects) | `xcodebuild test ... -only-testing:IsletTests/IslandResolverTests`; manual on-device tap-through for each of the 8 actions | ❌ Wave 0 |
| QACTION-03 | DND/Focus toggle's read-back comparison (`before != after` → success/failure) is a pure, testable function | unit | New `IsletTests/FocusToggleActionTests.swift`, mirroring `MicMuteControllerTests.swift`'s pure-function-testing shape | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests`
- **Per wave merge:** `xcodebuild test -project Islet.xcodeproj -scheme Islet`
- **Phase gate:** Full suite green before `/gsd:verify-work`, PLUS a manual on-device pass tapping all 8 configured actions once (system-call side effects — screen lock, dark mode, DND — cannot be meaningfully asserted by XCTest alone, matching this codebase's existing precedent of manual spike files like `MeetingMonitorManualSpike.swift`/`AudioOutputMonitorManualSpike.swift` for exactly this class of untestable system integration).

### Wave 0 Gaps
- [ ] New test cases in `IsletTests/IslandResolverTests.swift` covering the `.quickActions`/`.quickActionsBarExpanded` resolver branch
- [ ] New `IsletTests/FocusToggleActionTests.swift` — pure before/after comparison logic (the ONE piece of the DND action that's meaningfully unit-testable; the actual `shortcuts run` call and `INFocusStatusCenter` read are both system-integration, tested manually)
- [ ] Consider a `QuickActionsBarManualSpike.swift` (mirrors existing `*ManualSpike.swift` files) to exercise all 8 real system calls on-device during development, kept `#if DEBUG`-gated like `NowPlayingMonitor.swift`'s `spikeTriggerAutomationPrompt`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | This phase has no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Single-user local desktop app; no multi-user access boundary |
| V5 Input Validation | Yes (launch app/URL action only) | The user-configured URL/app-path for the "launch" slot must be validated as a well-formed `URL` before `NSWorkspace.shared.open` — never pass raw unchecked user text directly into a shell or AppleScript string (avoids AppleScript/command injection if a future action mechanism shells out with the value interpolated). Mirrors `quickNotesVaultFolderPath`'s existing "only ever comes from NSOpenPanel's own return value... never user-typed text" discipline (T-64-07) — the launch-URL config should similarly prefer a picker/validated URL over raw free-text where feasible. |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| AppleScript/command injection via a user-configured launch URL or app path fed unsanitized into a shell string | Tampering | Never build a shell command or AppleScript source string via string interpolation of user input; use `Process` with `arguments: [...]` (array form, no shell interpretation) or `URL(string:)` + `NSWorkspace.shared.open`, never `Process`+`/bin/sh -c "\(userInput)"` |
| Private-API screen lock symbol resolution failing silently and giving a false sense of security ("I tapped lock, therefore the screen is locked") | — (not a STRIDE category, but a correctness/trust concern) | Pair the tap with the SAME visible pulse-feedback every action gets (D-04) so at minimum the user knows the tap registered even if the lock call itself can't be verified to have succeeded (no public "is locked" read API exists to check against) |

## Sources

### Primary (HIGH confidence)
- Local codebase reads: `Islet/Notch/MicMuteController.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/SettingsView.swift`, `Islet/ActivityCard.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/QuickActionSharingService.swift`, `Islet/Islet.entitlements`, `IsletTests/*.swift`
- Local `man pmset` and `man caffeinate` output (this session, this machine)

### Secondary (MEDIUM confidence)
- MacRumors Forums, techearl.com, MacScripter — AppleScript dark-mode-toggle syntax (cross-verified across 3+ sources)
- MacScripter — Finder "empty the trash without warns before emptying" syntax
- albertopasca.it, Timac blog, multiple Stack Overflow/community threads — `SACLockScreenImmediate` private API
- Multiple community sources (Automators Talk, HeyFocus blog, GitHub `macos-focus-mode`) — Shortcuts CLI as the current DND/Focus best-effort mechanism
- Apple sample code references (via search) — `IOPMAssertionCreateWithName` usage pattern

### Tertiary (LOW confidence)
- None flagged — every claim above was either verified locally or cross-referenced across 2+ independent sources

## Metadata

**Confidence breakdown:**
- Standard stack (6 of 8 actions: mic mute, display sleep, caffeinate, launch app/URL, dark mode read, empty trash): HIGH — public/documented APIs or verbatim reuse of existing code
- Standard stack (screen lock, DND/Focus write): MEDIUM — private API / no-API-exists-at-all, community-consensus mechanisms, explicitly flagged for on-device verification
- Architecture (Settings/switcher-tab integration): HIGH — every seam this phase touches was read directly from the live codebase this session, not inferred from CONTEXT.md's summary alone
- Pitfalls: HIGH — the naming-collision and Timer-precedent pitfalls were discovered by directly reading and cross-referencing live code, not speculation

**Research date:** 2026-07-26
**Valid until:** 30 days for the architecture/integration findings (stable, locally-verified code); screen lock and DND mechanisms should be treated as needing re-verification at implementation time regardless of date, since both are explicitly version-fragile by nature
