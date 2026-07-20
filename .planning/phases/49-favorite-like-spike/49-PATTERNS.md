# Phase 49: Favorite/Like — Spike - Pattern Map

**Mapped:** 2026-07-20
**Files analyzed:** 3 (2 config, 1 Swift source — spike touches no new files, only modifies existing ones)
**Analogs found:** 3 / 3

This is a spike phase. No new files are created; RESEARCH.md's "Recommended Project Structure" lists three MODIFY targets. All three have direct, strong analogs already in the codebase — no "no analog found" entries this phase.

## Correction to RESEARCH.md's file list

RESEARCH.md names `Islet.xcodeproj/project.pbxproj` as a MODIFY target for `INFOPLIST_KEY_NSAppleEventsUsageDescription`. **This project uses xcodegen** (confirmed: `project.yml` exists at repo root and contains the exact same `INFOPLIST_KEY_*` block that appears in `project.pbxproj`, with a comment at `project.yml:54` referencing `INFOPLIST_KEY_*` synthesis). `project.pbxproj` is a generated artifact — hand-editing it directly will be silently overwritten the next time someone runs `xcodegen generate`. **The real edit target is `project.yml`**, not `project.pbxproj`. Flag this for the planner: Task should target `project.yml`, then run `xcodegen generate` (or whatever this project's regen step is) to regenerate `project.pbxproj`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Islet/Islet.entitlements` | config | N/A (static plist) | itself (existing entitlements) | exact — same file, additive key |
| `project.yml` (xcodegen source; NOT `project.pbxproj`) | config | N/A (static build settings) | itself (existing `INFOPLIST_KEY_*` block, `project.yml:91-124`) | exact — same file, additive key, matches existing German-string convention |
| `Islet/Notch/NowPlayingMonitor.swift` (throwaway spike hook) | service (temp instrumentation) | request-response (fire-and-forget command send) | `Islet/AppDelegate.swift`'s `#if DEBUG` debug-menu block (lines 223-261) for the *wiring convention*; `NowPlayingMonitor.swift` itself (lines 94-96, `togglePlayPause()`) for the *pass-through call convention* | exact for both halves |

## Pattern Assignments

### `Islet/Islet.entitlements` (config)

**Analog:** itself — read in full (17 lines), additive change only.

**Current full content** (`Islet/Islet.entitlements:1-17`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.disable-library-validation</key>
	<true/>
	<key>com.apple.developer.weatherkit</key>
	<true/>
	<key>com.apple.security.personal-information.calendars</key>
	<true/>
	<key>com.apple.security.personal-information.location</key>
	<true/>
	<key>com.apple.developer.usernotifications.communication</key>
	<true/>
</dict>
</plist>
```

**Pattern to add** (RESEARCH.md Pitfall C, Code Examples): insert a new `<key>`/`<true/>` pair before `</dict>`, matching the existing flat `<key>...</key><true/>` style used by every other entitlement in this file — no nesting, no comments inside the plist itself:
```xml
	<key>com.apple.security.automation.apple-events</key>
	<true/>
```
No auth/error-handling/validation pattern applies — this is a static declarative plist, not code.

---

### `project.yml` (xcodegen source of truth — NOT `project.pbxproj`)

**Analog:** itself, `INFOPLIST_KEY_*` block at `project.yml:91-124` (same file the change belongs in).

**Existing convention** (`project.yml:93-115`, German-language usage-description strings, each preceded by a phase-numbered comment explaining why the key exists):
```yaml
        # Phase 6 / DEV-01 — A1 VERDICT RESOLVED: on macOS 26 the FIRST IOBluetooth API call
        # (register(forConnectNotifications:)) requires this usage key — without it the app HARD
        # CRASHES ("attempted to access privacy-sensitive data without a usage description"),
        # which also took down the test runner. The key is therefore REQUIRED (not speculative).
        # German string to match the app's user-facing locale (cf. "Now Playing nicht verfügbar").
        INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "Islet zeigt eine kurze Mitteilung in der Notch, wenn ein Bluetooth-Gerät wie deine AirPods verbunden oder getrennt wird."
        ...
        # Phase 38 / HUD-05 (38-09 gap closure) — same class of gap as the Bluetooth key above:
        # INFocusStatusCenter.requestAuthorization/.authorizationStatus HARD CRASHES without this
        # key ("attempted to access privacy-sensitive data without a usage description").
        INFOPLIST_KEY_NSFocusStatusUsageDescription: "Islet zeigt eine kurze Mitteilung in der Notch an, wenn du deinen Fokus- oder Nicht-stoeren-Status aenderst."
```

**Pattern to add**: one new `INFOPLIST_KEY_NSAppleEventsUsageDescription` line inside the same `settings.base` block, with a `# Phase 49 / ...` comment following the exact same style (phase number, requirement ID, one-sentence why), and a German-language user-facing string matching the existing tone ("Islet [does X], wenn du [Y]"):
```yaml
        # Phase 49 — Automation (Apple Events) usage key: required alongside the
        # com.apple.security.automation.apple-events entitlement (Islet.entitlements) before
        # Islet's own binary can send any AppleScript/Apple Event under hardened runtime.
        INFOPLIST_KEY_NSAppleEventsUsageDescription: "Islet nutzt diese Berechtigung, um den Titel deiner aktuellen Musik zu erkennen und als Favorit zu markieren."
```
(Exact wording is Claude's/planner's discretion at execute time — match tone, not text, of the existing strings.)

**After editing `project.yml`**: regenerate `project.pbxproj` via this project's xcodegen step (check for a `Makefile`/script target, e.g. `xcodegen generate`, before assuming the raw CLI invocation) — do not hand-edit `project.pbxproj`'s `INFOPLIST_KEY_*` lines (`project.pbxproj:765-772` and the duplicate Release block `926-933`) directly, they will be overwritten.

**Same key must land in the generated pbxproj Debug AND Release blocks** — `project.yml`'s single `settings.base` entry (not `settings.configs.Debug`/`settings.configs.Release`) already fans out to both, matching how `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` etc. currently appear identically at both `project.pbxproj:765` (Debug) and `:926` (Release) from the same single `project.yml` source line — no special per-config handling needed.

---

### `Islet/Notch/NowPlayingMonitor.swift` (throwaway spike hook)

**Analog 1 (wiring/lifecycle convention):** `Islet/AppDelegate.swift` lines 223-261 — the project's own established `#if DEBUG`-gated, NSStatusItem-menu throwaway testing-seam pattern (used for license/trial debug overrides, D-08/D-09).

**Debug menu wiring pattern** (`Islet/AppDelegate.swift:223-240`):
```swift
    #if DEBUG
    // D-08: the sole testing seam for the license/trial gate — 3 stub-flip
    // actions, no shortened-trial-length action (D-09). Fully absent from
    // Release builds.
    private func setupDebugMenu() {
        debugStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        debugStatusItem.button?.title = "🐞"

        let debugMenu = NSMenu()
        debugMenu.addItem(withTitle: "Debug: Force Expired",
                          action: #selector(debugForceExpired), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Debug: Force Licensed",
                          action: #selector(debugForceLicensed), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Debug: Reset Trial",
                          action: #selector(debugResetTrial), keyEquivalent: "")
        for item in debugMenu.items { item.target = self }
        debugStatusItem.menu = debugMenu
    }
```

**Action-method pattern** (`Islet/AppDelegate.swift:242-260`):
```swift
    @objc private func debugForceExpired() {
        UserDefaults.standard.set(LicenseState.DebugOverride.forceExpired.rawValue,
                                   forKey: LicenseState.debugOverrideKey)
    }
    ...
    #endif
```
`setupDebugMenu()` is called once from AppDelegate's own launch path at `AppDelegate.swift:153` (inside an unrelated `#if DEBUG` block at line 152-154).

**Analog 2 (pass-through call convention into MediaController):** `Islet/Notch/NowPlayingMonitor.swift` lines 94-96 — the existing thin pass-through pattern this spike's `likeTrack()` hook must mirror exactly:
```swift
    // NOW-02 — transport rides the EXISTING child's stdin (no re-spawn):
    func togglePlayPause() { controller.togglePlayPause() }
    func nextTrack()       { controller.nextTrack() }
    func previousTrack()   { controller.previousTrack() }
```
`controller` is `private nonisolated(unsafe) let controller = MediaController()` (`NowPlayingMonitor.swift:56`) — already holds the live `MediaController` instance with an active session, exactly what RESEARCH.md's Code Example needs (`controller.likeTrack()`).

**Recommended spike hook placement** (per RESEARCH.md's own Code Example, `NowPlayingMonitor.swift`, mirroring the two analogs above): add a `#if DEBUG`-only method on `NowPlayingMonitor` (or `NowPlayingService` protocol, temp-extended) alongside `togglePlayPause()`, NSLog-marked per this project's Phase 22 precedent:
```swift
    #if DEBUG
    // TEMP — Phase 49 spike scaffold. Exercises the real MRMediaRemoteSendCommand(kMRLikeTrack)
    // send against whatever is currently playing. Remove/replace once go/no-go is recorded.
    func spikeLikeCurrentTrack() {
        NSLog("SPIKE likeTrack() sending kMRLikeTrack")
        controller.likeTrack()
    }
    #endif
```
Wire it from `NotchWindowController`'s existing `nowPlayingMonitor: NowPlayingService?` property (`NotchWindowController.swift:212`, populated by `startNowPlayingMonitor()` at line 644-646) via a new debug-menu item in `AppDelegate.swift`'s existing `setupDebugMenu()` (same `#if DEBUG` block, same `debugMenu.addItem(...)` + `@objc` action-method shape as `debugForceExpired()` etc.) — this reuses the *one* existing throwaway-instrumentation seam in the app rather than inventing a second one (keyboard shortcut, per RESEARCH.md's more generic suggestion, is unnecessary when this exact menu convention already exists and is one line away).

**Error handling pattern:** N/A for the `likeTrack()` hook itself (fire-and-forget command, no return value to branch on — the spike's job is visual confirmation in Music.app/Spotify.app, not programmatic error handling).

**Error handling pattern for the TCC-trigger hook** (Success Criterion #4, `NSAppleScript` path — RESEARCH.md's own Code Example, no closer in-repo analog exists since this is the first AppleScript call in the project): use the exact `errorDict[NSAppleScript.errorNumber]` branching RESEARCH.md already specifies (`-1728` vs `-1743`) — this is genuinely new code with no existing analog to copy from; RESEARCH.md's own example is the pattern to use verbatim.

---

## Shared Patterns

### `#if DEBUG`-gated throwaway instrumentation, NSLog-marked
**Source:** `Islet/AppDelegate.swift:223-261` (debug menu), general project convention referenced in RESEARCH.md as "Phase 22 precedent" (`NotchWindowController.swift:324`, `:414` — throwaway `#if DEBUG` spike scaffolding, later superseded)
**Apply to:** Both spike hooks in `NowPlayingMonitor.swift` (`spikeLikeCurrentTrack()` for SC#1, the TCC-trigger method for SC#4) — wrap in `#if DEBUG`, `NSLog("SPIKE ...")`-prefix every log line, and wire via `AppDelegate`'s existing debug-menu status item rather than a new UI surface.

### Config changes go through `project.yml`, never hand-edited into `project.pbxproj`
**Source:** `project.yml` (repo root) — confirmed as xcodegen source of truth; `project.pbxproj`'s `INFOPLIST_KEY_*` block (lines 765-772, 926-933) is generated output.
**Apply to:** The `INFOPLIST_KEY_NSAppleEventsUsageDescription` addition — edit `project.yml:91-124`'s block, then regenerate. Do not touch `project.pbxproj` directly.

### German-language, one-sentence, user-facing usage-description strings
**Source:** every existing `INFOPLIST_KEY_NS*UsageDescription` value in `project.yml:98-115` (Bluetooth, Location, Calendars, Reminders, InputMonitoring, FocusStatus)
**Apply to:** The new `NSAppleEventsUsageDescription` string — same tone/length/language as the six existing entries.

## No Analog Found

None. All three spike-touched files (entitlements plist, xcodegen config, `NowPlayingMonitor.swift`) have exact-match analogs already in the codebase (the file itself, for the two config files; `AppDelegate.swift`'s debug-menu block + `NowPlayingMonitor.swift`'s own pass-through methods, for the Swift hook).

The only genuinely-new code with no in-repo analog is the `NSAppleScript` `-1728`/`-1743` error-branching call (Success Criterion #4) — this is the first AppleScript/Apple Events call anywhere in the project. RESEARCH.md's own Code Example (Success Criterion #4 section) is the pattern of record here since no closer source exists; it already matches this project's `errorDict`-based Swift idiom style.

## Metadata

**Analog search scope:** `Islet/`, `Islet.xcodeproj/`, repo root (`project.yml`, `Islet.entitlements`)
**Files scanned:** `Islet.entitlements`, `project.yml`, `project.pbxproj` (targeted grep + offset reads), `NowPlayingMonitor.swift` (full read), `AppDelegate.swift` (targeted reads around `#if DEBUG` blocks), `NotchWindowController.swift` (targeted grep for `NowPlayingMonitor`/`NowPlayingService` wiring)
**Pattern extraction date:** 2026-07-20
