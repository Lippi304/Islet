---
status: resolved
trigger: "Kalender-Permission Dialog erscheint nicht; requestFullAccessToEvents() gibt silently false zurück, authorizationStatus bleibt notDetermined, App taucht nach Neustart weiterhin nicht in Systemeinstellungen > Datenschutz > Kalender auf"
created: 2026-07-08T13:24:44.000Z
updated: 2026-07-08T13:41:00.000Z
---

## Current Focus
<!-- OVERWRITE on each update - always reflects NOW -->

hypothesis: CONFIRMED — root cause found via live tccd log inspection (see reasoning_checkpoint below).
test: n/a — confirmed by direct system log evidence.
expecting: n/a
next_action: Add `com.apple.security.personal-information.calendars` = true to Islet/Islet.entitlements, rebuild, relaunch, verify a real TCC prompt appears.
reasoning_checkpoint:
  hypothesis: "Islet requests Calendar access with ENABLE_HARDENED_RUNTIME=YES but Islet.entitlements lacks com.apple.security.personal-information.calendars. Under Hardened Runtime, tccd's prompting policy requires this entitlement to even display kTCCServiceCalendar's consent dialog; without it, tccd silently refuses to prompt — the request never surfaces a dialog, never creates a TCC access row, and authorizationStatus stays notDetermined forever."
  confirming_evidence:
    - "Direct log line (via `/usr/bin/log show --last 30m --predicate 'process == \"tccd\"' --style compact`, filtered for `lippi304`): `E tccd[28306:20f85a] [com.apple.TCC:access] Prompting policy for hardened runtime; service: kTCCServiceCalendar requires entitlement com.apple.security.personal-information.calendars but it is missing for accessing={TCCDProcess: identifier=com.lippi304.islet, pid=82887, ...}, requesting={TCCDProcess: identifier=com.apple.calaccessd, ...}`"
    - "Same log capture shows an identical pattern for a different service moments earlier: `kTCCServiceAppleEvents requires entitlement com.apple.security.automation.apple-events but it is missing` for the same process — confirms this is a general hardened-runtime entitlement-gating mechanism, not a one-off."
    - "Read Islet/Islet.entitlements directly: only contains com.apple.security.cs.disable-library-validation and com.apple.developer.weatherkit — no calendars key present. Matches codesign -d --entitlements - output on the built Debug app (application-identifier, team-identifier, weatherkit, disable-library-validation, get-task-allow only)."
    - "tccd itself is actively processing other apps' requests in the same log window (Xnapper/ScreenCapture, Xcode/ibtool, bluetoothd) — rules out a broken/stuck tccd daemon or corrupted TCC.db as the cause."
    - "Bundle id (com.lippi304.islet), Team ID (R7AGU84UX7, real Apple Development cert, not ad-hoc), Info.plist NSCalendarsUsageDescription/NSCalendarsFullAccessUsageDescription keys, and LSUIElement=true were all verified correct — ruling out signing/plist misconfiguration as the cause."
  falsification_test: "If the entitlement were NOT the cause, adding it and rebuilding would still show no prompt and no new tccd log line. Instead we expect the tccd log to show the request reaching the normal AUTHREQ_RESULT/prompt path (not the 'Prompting policy for hardened runtime ... missing' branch) after the fix."
  fix_rationale: "Adding the entitlement addresses the actual gate tccd enforces before it will show a Calendar prompt at all — not a workaround around symptoms (retry loops, NSApp.activate hacks, tccutil resets) which were correctly eliminated in the prior session since none of them touch this entitlement check."
  blind_spots: "Have not yet rebuilt+relaunched to observe the actual prompt appear (pending user verification step). Minimal standalone repro app's own entitlements/hardened-runtime setting were not independently re-verified — it likely also lacked this entitlement while having hardened runtime on, or Xcode's default entitlements file for a fresh project doesn't request Calendar by default either, which would explain identical silent failure there too."
tdd_checkpoint: null

## Symptoms
<!-- Written during gathering, then immutable -->

expected: Hovering the expanded island (or otherwise triggering CalendarService/EventKitService) should show the standard macOS "Islet would like access to your calendar" TCC prompt, then after granting, the app appears in System Settings > Privacy & Security > Calendars with events populated in the outfit glance.
actual: No system dialog ever appears — neither on first launch, nor after multiple full app restarts, nor after a full system reboot. EKEventStore.authorizationStatus is 0/.notDetermined before the request; requestFullAccessToEvents(completion:) returns granted=false with no error surfaced. The app itself never appears as a row in System Settings > Privacy & Security > Calendars, even to be manually toggled.
errors: |
  Console shows repeated CoreSpotlight donation failures (unrelated candidate noise, but logged alongside):
  {CSInlineDonation[async]: "com.lippi304.islet" delete-domains:1}: Failed to request donation Error Domain=CSIndexErrorDomain Code=-1000 "Failed to request donation" UserInfo={NSDebugDescription=Failed ...}
  No explicit EventKit/TCC error is printed — the request just silently resolves to false/notDetermined.
reproduction: Launch Islet (both via Xcode debugger and standalone Finder double-click tested), trigger the calendar-glance code path (hover/expand island to run CalendarService.fetchUpcoming), observe no OS permission dialog and authorizationStatus stuck at notDetermined.
started: First observed during Phase 14 (outfit/weather/calendar glance) implementation; never worked from the first attempt — not a regression from previously-working state.

## Eliminated
<!-- APPEND only - prevents re-investigating after /clear -->

- hypothesis: Missing NSCalendarsFullAccessUsageDescription in Info.plist causes silent failure
  evidence: Key was confirmed added to Info.plist; minimal standalone EventKit test app built with the same key still reproduces identical silent failure (authorizationStatus never changes, no prompt).
  timestamp: 2026-07-08 (previous session)
- hypothesis: LSUIElement (agent app / no Dock icon) blocks the TCC prompt from being presented
  evidence: NSApp.activate(ignoringOtherApps:) workaround added and tested — no effect. Minimal test app (not LSUIElement-encumbered in the same way) still failed identically, pointing away from LSUIElement as sole cause.
  timestamp: 2026-07-08 (previous session)
- hypothesis: App is present in System Settings but just needs manual enabling
  evidence: User checked both System Settings > Privacy & Security > Calendars and > Automation — app does not appear in either list at all (nothing to toggle).
  timestamp: 2026-07-08 (previous session)
- hypothesis: A restricted Calendar-app profile or MDM/VPN configuration profile is blocking access
  evidence: User confirmed Calendar.app itself is not restricted, and Settings > VPN & Device Management shows no MDM profile installed.
  timestamp: 2026-07-08 (previous session)
- hypothesis: Debugger-attached process state interferes with the TCC prompt flow
  evidence: Tested launching Islet standalone (no Xcode debugger attached, no lldb) — identical silent failure.
  timestamp: 2026-07-08 (previous session)
- hypothesis: Stuck calaccessd/tccd daemon state (cleared only by full reboot)
  evidence: User performed a full system restart and retested — still no dialog, still not listed in System Settings. This session's job is to determine what's next now that reboot did NOT fix it.
  timestamp: 2026-07-08 (this session)
- hypothesis: Build/signing identity mismatch (bundle id, Team ID, ad-hoc vs real cert, DerivedData path oddity)
  evidence: codesign -dv on the built Debug app shows correct bundle id com.lippi304.islet, TeamIdentifier=R7AGU84UX7, signed with a real "Apple Development" certificate (not ad-hoc), Info.plist has both NSCalendarsUsageDescription and NSCalendarsFullAccessUsageDescription with correct German text, LSUIElement=true. All consistent with project.yml. Signing/identity is not the cause.
  timestamp: 2026-07-08 (this session)
- hypothesis: TCC.db corruption or broken/stuck tccd daemon (not just needing a reboot, but genuinely malfunctioning)
  evidence: Live tccd log capture (`/usr/bin/log show --last 30m --predicate 'process == "tccd"'`) shows tccd actively and successfully processing TCC requests for many other apps (Xnapper/ScreenCapture, Xcode/ibtool, bluetoothd) in the same time window. tccd is healthy; the issue is a deliberate policy rejection specific to Islet's missing entitlement, not daemon malfunction.
  timestamp: 2026-07-08 (this session)

## Evidence
<!-- APPEND only - facts discovered during investigation -->

- timestamp: 2026-07-08 (previous session)
  checked: Islet Release build entitlements
  found: WeatherKit capability/entitlement present; no explicit com.apple.security entitlement related to Calendar (none is actually required for EventKit outside the sandbox, but noted as a data point since the app is unsandboxed)
  implication: Entitlements are not obviously misconfigured for Calendar specifically, but signing identity/provisioning has not yet been cross-checked against what TCC would key off of.
- timestamp: 2026-07-08 (previous session)
  checked: Minimal standalone EventKit test app (fresh target, correct Info.plist key) launched directly
  found: Reproduces the exact same silent failure as Islet — authorizationStatus stays notDetermined, no prompt, no System Settings entry
  implication: Root cause is very likely NOT specific to Islet's code/config — it is either a system-wide/user-account TCC state issue or something common to how these dev-signed apps are being built/run (e.g. ad-hoc signing identity, Team ID, or DerivedData path characteristics that TCC treats specially).
- timestamp: 2026-07-08 (this session)
  checked: project.yml build settings and built app's codesign/entitlements/Info.plist output
  found: ENABLE_HARDENED_RUNTIME=YES is set for the Islet target (required later for notarization); built app entitlements (codesign -d --entitlements -) contain only com.apple.application-identifier, com.apple.developer.team-identifier, com.apple.developer.weatherkit, com.apple.security.cs.disable-library-validation, com.apple.security.get-task-allow. No Calendar-related entitlement present. Islet/Islet.entitlements source file confirms the same (only disable-library-validation + weatherkit keys).
  implication: Hardened Runtime + missing personal-information.calendars entitlement is a strong candidate for silently blocking the TCC prompt at the policy-check stage, before any dialog or System Settings row is ever created.
- timestamp: 2026-07-08 (this session)
  checked: Live tccd process log via `/usr/bin/log show --last 30m --predicate 'process == "tccd"' --style compact`, filtered for `lippi304`/`islet`
  found: |
    Direct hit — tccd explicitly logs why it refuses to prompt:
    `E tccd[28306:20f85a] [com.apple.TCC:access] Prompting policy for hardened runtime; service: kTCCServiceCalendar requires entitlement com.apple.security.personal-information.calendars but it is missing for accessing={TCCDProcess: identifier=com.lippi304.islet, pid=82887, ...}, requesting={TCCDProcess: identifier=com.apple.calaccessd, ...}`
    An analogous line appears for kTCCServiceAppleEvents requiring com.apple.security.automation.apple-events, also missing for the same process — same mechanism, different service.
    tccd is simultaneously processing successful TCC requests for several unrelated apps in the same log window (Xnapper, Xcode/ibtool, bluetoothd) — the daemon itself is healthy.
  implication: ROOT CAUSE CONFIRMED. Under Hardened Runtime, tccd enforces an entitlement-gated "prompting policy": without com.apple.security.personal-information.calendars declared in the app's entitlements, tccd refuses to present the Calendar consent dialog at all. This is why no dialog ever appears, why reboot didn't help (not a daemon/db state issue), and why the app never appears in System Settings (no TCC access row is ever created since the request is rejected before that point). Note: important reminder — `log` is a zsh shell builtin that shadows `/usr/bin/log`; must invoke via full path or `command log` or it errors with "too many arguments".

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: |
  Under ENABLE_HARDENED_RUNTIME=YES (required for later notarization), macOS's tccd
  enforces an entitlement-gated "prompting policy" for privacy-sensitive TCC services:
  it will not present the Calendar consent dialog to the user unless the requesting
  app's code signature declares com.apple.security.personal-information.calendars.
  Islet/Islet.entitlements only declared com.apple.security.cs.disable-library-validation
  and com.apple.developer.weatherkit — the Calendar entitlement was never added. tccd
  therefore silently refused every request at the policy-check stage (confirmed via live
  tccd log: "Prompting policy for hardened runtime; service: kTCCServiceCalendar requires
  entitlement com.apple.security.personal-information.calendars but it is missing").
  This explains all observed symptoms: no dialog ever appears, reboot doesn't help
  (not a daemon/DB state issue), and the app never appears in System Settings > Privacy
  & Security > Calendars (no TCC access row is ever created since the request is
  rejected before that point).
fix: Added `com.apple.security.personal-information.calendars` = true to Islet/Islet.entitlements.
verification: |
  Self-verified: `xcodebuild -scheme Islet -configuration Debug build` succeeded, and
  `codesign -d --entitlements -` on the freshly built Debug Islet.app now shows
  com.apple.security.personal-information.calendars = true embedded in the code
  signature (confirmed present alongside application-identifier, team-identifier,
  weatherkit, disable-library-validation, get-task-allow).
  Human-confirmed: after Clean Build Folder + rebuild, the system Calendar consent
  dialog appeared immediately on launch (no hover/expand of the notch even required).
files_changed:
  - Islet/Islet.entitlements
