---
status: resolved
trigger: "Wetter-Spalte in der Islet-Notch bleibt komplett leer (nur Uhrzeit + Kalender werden angezeigt), obwohl Ortungsdienste für Islet in den Systemeinstellungen bereits erlaubt sind (kein Prompt erschien beim Start)"
created: 2026-07-08T13:44:39.000Z
updated: 2026-07-08T16:53:00.000Z
---

## Current Focus
<!-- OVERWRITE on each update - always reflects NOW -->

hypothesis: LOCATION LAYER IS FULLY RESOLVED (confirmed by fresh clean-relaunch log: a real
  CLLocation at 53.55N/13.26E was obtained and handed to WeatherKit). The remaining failure is
  ONE LAYER DEEPER and entirely external to this codebase: Apple's own
  https://weatherkit.apple.com/v3/token endpoint rejects Islet's JWT token request with a flat
  HTTP 401 (`invalidJWTResponse`, `WDSJWTAuthenticatorServiceListener.Errors Code=2`), even though
  the JWT was built and cryptographically signed successfully by the local
  com.apple.weatherkit.authservice daemon using the correct bundleId (com.lippi304.islet) and Team
  ID (R7AGU84UX7). This is a server-side/Apple Developer Portal configuration gap, not a local
  code/entitlement/Info.plist bug — all of those are independently confirmed correct (see prior
  Evidence). Per multiple independent web/forum sources with this EXACT error signature, the single
  most common root cause is: WeatherKit capability was only confirmed/checked on the App ID's
  "Capabilities" tab, but NOT also on the separate "App Services" section/tab in the same App ID
  edit page in developer.apple.com — WeatherKit must be checked+saved on BOTH for the backend JWT
  auth service to actually authorize the App ID; Xcode's own "+Capability" automatic-signing button
  frequently only touches the Capabilities side. 14-02-SUMMARY.md's own record of the human
  checkpoint only says the user "confirmed WeatherKit capability enabled on the App ID" — it never
  mentions checking the App Services tab, making this the leading (but unverified without portal
  access) candidate. Secondary candidate: genuine backend propagation delay (community reports
  range from "instant" to several hours after first enabling); this is possible but less commonly
  reported as the cause for a JWT-endpoint-level 401 specifically (as opposed to REST-API-level 401
  responses with a "NOT_ENABLED" reason body, which propagation delay explains more often).
test: This cannot be tested/fixed from the codebase — it requires the user to inspect and act on
  developer.apple.com/account (Certificates, Identifiers & Profiles > Identifiers > com.lippi304.islet
  App ID). See checkpoint below for exact steps.
expecting: If the App Services tab was never checked/saved, checking+saving it should resolve the
  401 (may take a few minutes to propagate). If both tabs are already correctly checked, the leading
  remaining explanation is a propagation delay — retry after 30-60 min, escalating to several hours
  if still failing.
next_action: AWAITING human action on developer.apple.com (see checkpoint below) — user must check
  the App ID's WeatherKit status on BOTH the Capabilities and App Services tabs/sections, re-save,
  wait, and retry a fresh on-device build+launch, then report the new log output (or success).
reasoning_checkpoint:
  status: "SUPERSEDED — the location-entitlement hypothesis below is now CONFIRMED CORRECT (fresh
    clean-relaunch log shows a real CLLocation obtained and passed to WeatherKit), kept here for
    the record. Investigation has moved one layer deeper; see Current Focus above and the new
    Evidence entry for the current (WeatherKit JWT auth 401) hypothesis, which is NOT yet
    fixable from this codebase — it requires human action in the Apple Developer Portal, so no
    new reasoning_checkpoint/fix_and_verify cycle applies until that action is taken and retested."
  hypothesis: "Islet requests Location access via CLLocationManager.requestWhenInUseAuthorization()/requestLocation() but Islet.entitlements lacked com.apple.security.personal-information.location. Under Hardened Runtime, tccd's prompting policy requires this entitlement to even process kTCCServiceLocation requests; without it, tccd silently refuses the whole handshake — no TCC IPC line is logged for the Islet process, LocationProvider's D-01 contract settles nil, refreshWeather() never fires WeatherKitService, and the weather column stays empty with no visible error."
  confirming_evidence:
    - "Checkpoint's live log capture (predicate includes process == \"Islet\", which caught Bluetooth's TCC IPC regardless of subsystem) shows ZERO \"(TCC) TCCAccessRequest() IPC\" lines for Location anywhere, while the identical mechanism for Bluetooth in the same Islet process/session produced two clear IPC lines followed by a TCC-approved line — direct evidence the Location request path never reaches the same tccd IPC stage that Bluetooth reaches."
    - "Islet/Islet.entitlements (read directly before this fix) contained only disable-library-validation, weatherkit, and calendars — no location key. This is the exact same gap pattern already proven in the resolved calendar-perm-no-dialog session, where tccd's own log literally read: 'Prompting policy for hardened runtime; service: kTCCServiceCalendar requires entitlement com.apple.security.personal-information.calendars but it is missing' — a general, documented Hardened Runtime TCC-gating mechanism, not calendar-specific."
    - "Apple's own documentation confirms com.apple.security.personal-information.location exists as a real Boolean entitlement key (developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.location), parallel to the personal-information.calendars key already fixed for Calendar."
    - "project.yml confirms NSLocationWhenInUseUsageDescription IS present in Info.plist (ruling out the Info.plist-only theory) and LocationProvider.swift only calls requestWhenInUseAuthorization()/requestLocation() (no Always-authorization code path), consistent with a WhenInUse-scoped kTCCServiceLocation request being gated the same hardened-runtime way as Calendar's kTCCServiceCalendar."
    - "CONFIRMED THIS CYCLE: fresh clean-relaunch log shows CLLocation(+53.55005112,+13.26251191) obtained and handed to WeatherService — the location layer works end-to-end now. Necessary but NOT sufficient: WeatherKit's own JWT auth to weatherkit.apple.com/v3/token now fails with a 401, one layer deeper (see new Evidence entry)."
  falsification_test: "If this were NOT the cause, adding the entitlement, rebuilding, and retesting would still show zero TCC IPC lines for Location and no functional change in the weather column. Instead, after the fix, a live log capture during app launch/notch-expand should show Location's TCCAccessRequest() IPC lines appear (mirroring the Bluetooth pattern), and/or CLLocationManager's didUpdateLocations should fire with a real CLLocation, populating BasicOutfitState.weather and the weather column."
  fix_rationale: "Adding the entitlement addresses the actual gate tccd enforces before it will even process a Location request — not a workaround around symptoms (retry loops, re-prompting, tccutil resets alone) which don't touch this entitlement check. This exactly mirrors the calendar fix's fix_rationale."
  blind_spots: "Have NOT independently confirmed whether the pre-existing 'Allowed' row for Islet in System Settings > Privacy & Security > Location Services is stale — moot now, since a real CLLocation was obtained. NEW blind spot: cannot access developer.apple.com myself to directly inspect whether WeatherKit is checked on the App ID's App Services tab (vs. only Capabilities) or whether a pending Program License Agreement update exists — this is the single largest unresolved unknown and is why this cycle ends in a human-action checkpoint rather than a fix."
tdd_checkpoint: null

## Symptoms
<!-- Written during gathering, then immutable -->

expected: With Location already authorized for Islet, expanding the idle island should show a LEFT weather column (animated icon + temperature), populated via LocationProvider -> WeatherKitService -> BasicOutfitState.weather -> NotchPillView.weatherColumn.
actual: Only time + calendar show; the weather column never appears at all, on a fresh Clean Build Folder + Cmd-R rebuild, with Location permission already granted (no OS prompt shown, confirmed pre-existing grant in System Settings > Privacy & Security > Location Services).
errors: None surfaced to the UI — by design (D-01 in WeatherService.swift / LocationProvider.swift), every failure path (permission denial, location fetch failure, WeatherKit fetch failure) settles completion(nil) silently with no error UI, so the symptom is identical for "correctly denied" and "broken entitlement/fetch."
reproduction: Build+run Islet via Xcode (Cmd-R), expand the notch (hover/click) with no media playing. Weather column absent; time+calendar column present.
started: First on-device attempt at Phase 14 Plan 14-05's Task 1 checkpoint (this session) — 14-02/14-03/14-04 only structurally/headlessly verified this path, per 14-02-SUMMARY.md's explicit deferral of the real on-device fetch to 14-05.

## Eliminated
<!-- APPEND only - prevents re-investigating after /clear -->

- hypothesis: Location permission was never actually granted / needs a fresh prompt
  evidence: User confirmed in System Settings > Privacy & Security > Location Services that Islet is already listed and allowed; no OS prompt appeared on launch, consistent with a pre-existing grant (not a denial, which would also produce no prompt but WOULD show as "denied" in Settings).
  timestamp: 2026-07-08 (this session)
- hypothesis: outfitState/@Published binding or SwiftUI rendering is broken for the weather column specifically
  evidence: Not yet fully ruled out, but the calendar column (same BasicOutfitState/@Published pattern, same NotchPillView 3-column layout) renders correctly, making a rendering-layer-only bug for just the weather half unlikely — same struct, same view file, same binding mechanism. NotchPillView.swift:201 confirms weatherColumn is only skipped when `outfit.weather == nil` — no extra filtering condition (e.g. no `category != .unknown` guard) that could silently drop a valid non-nil glance.
  timestamp: 2026-07-08 (this session)
- hypothesis: WeatherKit entitlement/capability isn't actually propagated into the signed+provisioned binary the user is running (i.e. 14-02's Developer Portal capability enablement never made it into the real build artifact)
  evidence: Inspected the most recently built Debug product (DerivedData/Islet-dnqqxjhrqzcdrvcmdlvlqorickdh/Build/Products/Debug/Islet.app, built 2026-07-08 15:31) directly with `codesign -d --entitlements - --xml` — the embedded entitlements DO include `com.apple.developer.weatherkit = true` alongside the calendars and disable-library-validation entitlements. Additionally decoded Contents/embedded.provisionprofile with `security cms -D` — the profile's Entitlements dict ALSO lists `com.apple.developer.weatherkit = true`, confirming the App ID capability enabled in 14-02 has propagated into a real, currently-installed provisioning profile (Apple Development: niklas.lippert2005@gmail.com, team R7AGU84UX7). Note: an OLDER artifact at ./build/export/Islet.app (a notarized Developer-ID-signed release/archive build, unrelated to this Cmd-R debug run) has ZERO embedded entitlements — this is a stale distribution-build artifact from a different signing identity, not evidence of a problem with the current Debug build the user is testing.
  timestamp: 2026-07-08 (this session)

## Evidence
<!-- APPEND only - facts discovered during investigation -->

- timestamp: 2026-07-08 (this session)
  checked: Islet/Weather/WeatherService.swift, Islet/Location/LocationProvider.swift, Islet/Notch/BasicOutfitState.swift, Islet/Notch/NotchWindowController.swift (startOutfitRefresh/refreshWeather/refreshCalendar), Islet/Notch/NotchPillView.swift (weatherColumn)
  found: |
    Wiring reads as structurally correct end-to-end: startOutfitRefresh() (called once, line 335)
    -> locationProvider.requestOnce (sets lastLocation, then calls refreshWeather()) +
    refreshCalendar() (immediate, no location dependency) -> a repeating 900s Timer re-runs both.
    refreshWeather() guards on `lastLocation` being non-nil, then calls
    weatherService.fetchCurrent(...) { self?.outfitState.weather = glance }. LocationProvider's
    requestOnce checks manager.authorizationStatus and calls requestLocation() for
    .authorizedAlways/.authorized, else settles nil immediately (D-01). No obvious logic bug
    found by static reading alone.
  implication: The break is very likely a runtime-only failure (either CLLocationManager never
    calling back, or WeatherKit's live fetch throwing) that static code reading cannot surface —
    matches exactly why 14-05 exists as an on-device-only checkpoint per VALIDATION.md.
- timestamp: 2026-07-08 (this session)
  checked: 14-02-SUMMARY.md (WeatherKit signing/entitlement setup plan)
  found: |
    WeatherKit capability was enabled on the com.lippi304.islet App ID in the Apple Developer
    portal and real Team ID (R7AGU84UX7) signing was wired in — but the summary explicitly states
    this only proves the setup is "syntactically/structurally correct" and defers "full on-device
    runtime verification of an actual WeatherKit fetch" to 14-05 (i.e., this exact checkpoint).
  implication: A live-fetch-only failure (e.g. entitlement not yet propagated, provisioning
    profile mismatch, or a WeatherKit auth/quota issue) was explicitly anticipated as possible
    and unverified until now.
- timestamp: 2026-07-08 (this session, orchestrator checkpoint analysis)
  checked: |
    ~30s live `log stream` capture (predicate: subsystem contains "com.apple.locationd" or
    subsystem contains "weather" or process == "Islet") spanning an Islet relaunch
    (old PID 26314 quit, new PID 26396 launched) and a notch expand.
  found: |
    Zero "(TCC) TCCAccessRequest() IPC" lines for Location tied to the Islet process anywhere
    in the capture, despite the predicate's `process == "Islet"` clause catching Bluetooth's
    identical IPC pattern for the same process/session cleanly:
      16:09:26.529 A  Islet[26396:1d1fb] (TCC) TCCAccessRequest() IPC
      16:09:28.143 A  Islet[26396:1d1fb] (TCC) TCCAccessRequest() IPC
      16:09:28.143 Df Islet[26396:1d1fb] [com.apple.bluetooth:IOBluetooth] TCC is approved
    All CLLocationManager/locationd lines present in the capture belong to unrelated system
    processes (duetexpertd, SecurityPrivacyExtension, PerfPowerServices, airportd) — none
    reference Islet at all.
  implication: |
    The Location request never reaches the same tccd IPC stage that Bluetooth reaches for the
    identical process — strong evidence the request is being rejected/blocked before an IPC
    round-trip even starts, consistent with the Hardened Runtime "Prompting policy" gate already
    proven for Calendar in the resolved calendar-perm-no-dialog session.
- timestamp: 2026-07-08 (this session)
  checked: Islet/Islet.entitlements (direct read, pre-fix) and Apple's Security Entitlements docs (WebSearch)
  found: |
    Pre-fix, Islet.entitlements contained only com.apple.security.cs.disable-library-validation,
    com.apple.developer.weatherkit, and com.apple.security.personal-information.calendars —
    no location-related key. Confirmed via developer.apple.com/documentation/bundleresources/
    entitlements/com.apple.security.personal-information.location that
    `com.apple.security.personal-information.location` is a real, documented Boolean entitlement
    key controlling Location Services access, parallel in structure/naming to
    personal-information.calendars (already proven to gate kTCCServiceCalendar's hardened-runtime
    prompting policy in the resolved calendar bug).
  implication: |
    Same gap, same mechanism, same fix pattern as the calendar bug — missing
    personal-information.location entitlement is the most probable reason tccd never proceeds
    with a Location TCC IPC round-trip for Islet.
- timestamp: 2026-07-08 (this session)
  checked: Islet/Location/LocationProvider.swift and project.yml (INFOPLIST_KEY_NSLocationWhenInUseUsageDescription)
  found: |
    LocationProvider only calls manager.requestWhenInUseAuthorization() (never requestAlways...),
    and project.yml confirms NSLocationWhenInUseUsageDescription is present with correct German
    text. This rules out "missing Info.plist usage-description key" as the cause and confirms the
    request is scoped to WhenInUse — consistent with kTCCServiceLocation being gated by the same
    hardened-runtime entitlement check regardless of WhenInUse vs. Always scope (the entitlement
    key itself has no separate WhenInUse/Always variant — Apple docs list only the one
    personal-information.location key).
  implication: |
    Confirms the fix target is exactly personal-information.location (singular key, not a
    WhenInUse-specific variant), and that the Info.plist side of the setup was already correct
    — the entitlement was the sole missing piece on the code-signing side.
- timestamp: 2026-07-08 (this session)
  checked: Fix build — added personal-information.location to Islet.entitlements, ran
    `xcodebuild -scheme Islet -configuration Debug build`, then `codesign -d --entitlements -`
    on the freshly built Islet.app (DerivedData/Islet-dnqqxjhrqzcdrvcmdlvlqorickdh, binary
    mtime 16:14:38, ~30s after the build command completed)
  found: |
    Embedded entitlements now read: application-identifier, developer.team-identifier,
    developer.weatherkit, security.cs.disable-library-validation, security.get-task-allow,
    security.personal-information.calendars, AND security.personal-information.location = true
    — all four resource-access keys (weatherkit, calendars, location, plus disable-library-
    validation) are present in the actual signed binary the user will run next.
  implication: |
    Fix is embedded and self-verified at the code-signing level, exactly mirroring how the
    calendar fix was self-verified before human confirmation. Matches the calendar bug's
    verification pattern precisely.
- timestamp: 2026-07-08 (this session)
  checked: User's prior report that Islet already shows as "Allowed" in System Settings >
    Privacy & Security > Location Services, despite zero TCC IPC activity in the log — reasoned
    by analogy to the calendar bug's stale-vs-fresh TCC state discussion
  found: |
    This is inconsistent with the "request never reaches tccd" theory taken at face value — in
    the calendar case, before the entitlement was added, tccd's own log showed it rejecting the
    request at the "Prompting policy" stage BEFORE any TCC access row could be created, and the
    app never appeared in Settings at all pending the fix. If the same gate applies to Location,
    Islet showing as "Allowed" already is unexpected and suspicious — most likely explanations:
    (a) a stale TCC row from an earlier build/signing-identity iteration of Islet that predates
    the current DerivedData build and was never invalidated (TCC.db rows are keyed by bundle id
    and can persist across rebuilds even when the current build's hardened-runtime entitlement
    check would otherwise block a NEW request), or (b) the user is recalling the macOS-wide
    "Location Services" master toggle (which is a system switch, not a per-app row) rather than
    an actual Islet-specific entry. Either way, a stale/ambiguous pre-existing row could cause
    CLLocationManager.authorizationStatus to report .authorized/.authorizedWhenInUse from cached
    state while the live IPC round-trip that would actually deliver a location still silently
    fails under the entitlement gate — exactly explaining "shows Allowed, but no weather" as two
    independently-stale/broken layers (a cached authorization status vs. a blocked live request).
  implication: |
    Recommend the user run `tccutil reset Location com.lippi304.islet` (or remove Islet's row
    via System Settings > Privacy & Security > Location Services > the "-" button, if present,
    then relaunch) BEFORE retesting, so a fresh authorization handshake with the now-correctly-
    entitled binary is forced, rather than relying on a possibly-stale cached grant.
- timestamp: 2026-07-08 (this session, continuation after checkpoint reporting new regression)
  checked: |
    Full working-tree `git diff` across the repo (not just Islet.entitlements) after the
    checkpoint reported a broader regression (ONLY time visible, zero dialogs/IPC for Location,
    Calendar, AND Bluetooth).
  found: |
    Islet/Notch/NotchWindowController.swift was ALSO modified in the working tree — uncommitted,
    undocumented, not part of this debug session's intended change (files_changed only ever
    listed Islet.entitlements). Line 31 read:
      private var panel: NotchPanel?   private var observer: NSObjectProtocol?
    Two property declarations merged onto a single line with no `;` separator between them —
    invalid Swift syntax. Directly reproduced by running
    `xcodebuild -scheme Islet -configuration Debug build`, which failed with:
      "error: consecutive declarations on a line must be separated by ';'"
    at exactly that line/column. This is a genuine, deterministic compile failure, not a
    runtime/TCC issue.
  implication: |
    This single, well-understood cause fully explains the "regression across three unrelated
    permission subsystems" the checkpoint asked about — no separate signing-identity theory or
    Console.app crash-log investigation was needed. If the user's Xcode build failed (as it must
    have, deterministically, given this syntax error) and they did not notice/read the build
    error banner, Cmd-R would NOT launch a new process at all. Whatever they observed in the
    notch (time only) was almost certainly a STALE Islet process already running from earlier in
    the session — which would trivially explain zero fresh TCC IPC lines for Location, Calendar,
    or Bluetooth, and zero permission dialogs, since no new launch (and thus no new permission
    requests) actually occurred. Fixed by splitting the line back into two separate declarations;
    rebuild now succeeds (BUILD SUCCEEDED) and the location/calendars/weatherkit entitlements were
    re-confirmed present in the fresh binary via codesign. The origin of this corruption is
    unexplained (not an intentional edit by this debug session) but is now resolved regardless.

- timestamp: 2026-07-08 (this session, checkpoint response — fresh clean-relaunch log)
  checked: |
    User-provided fresh live log capture from a properly relaunched Islet (Location Services
    confirmed ON in System Settings, build fixed, freshly-relaunched process, no build errors).
  found: |
    Location layer WORKS end-to-end now: a real CLLocation (+53.55005112,+13.26251191, plausible
    for the user's region) was obtained and handed to WeatherService:
      "Encountered an error when fetching weather data subset; location=<+53.55005112,+13.26251191>
      ... error=WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors 2"
    But the fetch itself fails one layer deeper, at WeatherKit's own JWT auth handshake:
      com.apple.weatherkit.authservice: "Signed successfully" -> builds JWT token request to
      https://weatherkit.apple.com/v3/token with {"bundleId":"com.lippi304.islet"} -> Apple's
      server responds "Status Code: 401" -> "JWT Response not successful" ->
      "Failed to generate token witherror: invalidJWTResponse(...Status Code: 401...)" ->
      Islet process itself logs "Failed to generate jwt token for: com.apple.weatherkit.authservice
      with error: ...WDSJWTAuthenticatorServiceListener.Errors Code=2".
    The bundleId sent (com.lippi304.islet) exactly matches the App ID enabled in the Apple
    Developer portal per 14-02-SUMMARY.md, and Team ID R7AGU84UX7 signing is confirmed correct —
    ruling out a bundle-ID-mismatch or wrong-signing-identity cause.
  implication: |
    The Location-entitlement fix is CONFIRMED CORRECT and complete — necessary but not sufficient.
    The actual remaining blocker is one layer further down the stack: Apple's own WeatherKit auth
    backend (weatherkit.apple.com/v3/token) is rejecting Islet's correctly-built, correctly-signed
    JWT request with a flat 401. This is entirely server-side / Apple Developer Portal state and
    cannot be diagnosed or fixed further by reading/editing this codebase.
- timestamp: 2026-07-08 (this session, WebSearch research on the 401/invalidJWTResponse signature)
  checked: |
    Web research on "WeatherKit v3/token 401 invalidJWTResponse" and
    "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors 2" against Apple Developer Forums
    threads (707494, 811225, 807586, 733771) and a dedicated troubleshooting article
    (anupdsouza.com/blog/weatherkit-jwt-auth-error), plus 14-02-SUMMARY.md's record of the
    original human checkpoint.
  found: |
    Multiple independent sources report this EXACT error signature (JWT built+signed fine locally,
    Apple's own token endpoint returns 401) as most commonly caused by one specific, easy-to-miss
    Developer Portal gap: on the App ID's edit page at developer.apple.com (Certificates,
    Identifiers & Profiles > Identifiers > the App ID), WeatherKit must be checked AND SAVED on
    BOTH the "Capabilities" list AND a separate "App Services" section within the same page — not
    just one. Community reports explicitly state Xcode's own automatic "+Capability" signing button
    frequently only touches the Capabilities side, silently leaving App Services unchecked, which
    produces precisely this JWT-endpoint-level 401 (as distinct from a REST-API-level 401 with a
    "NOT_ENABLED" reason body, which is more often propagation delay). Cross-checked against
    14-02-SUMMARY.md line 53: the ONLY thing the original human checkpoint recorded was "user
    confirmed WeatherKit capability enabled on the com.lippi304.islet App ID" — it never mentions
    an App Services tab/section, making an unchecked App Services entry the leading, currently
    unverified (no portal access from this environment) candidate.
    Secondary candidate (less commonly reported for this specific JWT-level failure, more common
    for REST-API 401s): backend propagation delay after first enabling a capability — community
    reports range from immediate to a few hours, no source specifically confirms 24-48h for this
    JWT-endpoint failure mode.
  implication: |
    Actionable next step is entirely portal-side (see checkpoint below); no further local
    code/config change is justified until the user confirms App Services status, since guessing at
    additional local changes without portal visibility risks masking the real gap or wasting cycles
    on a problem this session cannot observe directly.

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: |
  TWO STACKED ROOT CAUSES, one now fully resolved and confirmed, one still open and external:

  LAYER 1 (RESOLVED, CONFIRMED): Under ENABLE_HARDENED_RUNTIME=YES, macOS's tccd enforces the same
  entitlement-gated "Prompting policy for hardened runtime" for kTCCServiceLocation as it does for
  kTCCServiceCalendar (already proven in the resolved calendar-perm-no-dialog session): it will not
  process/prompt a Location access request unless the requesting app's code signature declares
  com.apple.security.personal-information.location. Islet/Islet.entitlements declared
  disable-library-validation, weatherkit, and calendars, but never location. Fixed by adding the
  entitlement. CONFIRMED WORKING this cycle via a fresh clean-relaunch log: a real CLLocation
  (+53.55005112,+13.26251191) was obtained and handed to WeatherService.

  LAYER 2 (OPEN, EXTERNAL TO THIS CODEBASE): With Location now working, the weather column is still
  empty because WeatherKit's own JWT auth handshake fails. Islet's local com.apple.weatherkit.
  authservice daemon correctly builds and signs a JWT token request (bundleId com.lippi304.islet,
  Team ID R7AGU84UX7 — both confirmed correct), but Apple's own
  https://weatherkit.apple.com/v3/token endpoint rejects it with a flat HTTP 401
  (invalidJWTResponse / WDSJWTAuthenticatorServiceListener.Errors Code=2). This is a server-side
  rejection by Apple's WeatherKit backend — not a local code, entitlement, Info.plist, or
  signing-identity issue (all independently verified correct). Per web research, the leading
  candidate is that WeatherKit was only checked on the App ID's "Capabilities" list in the Apple
  Developer Portal but not also on the separate "App Services" section (14-02-SUMMARY.md's original
  checkpoint only recorded confirming the Capabilities-side checkbox); a less likely secondary
  candidate is a backend propagation delay after first enabling the capability.
fix: |
  1. Added `com.apple.security.personal-information.location` = true to Islet/Islet.entitlements
     (CONFIRMED WORKING this cycle — Location layer fully resolved).
  2. SEPARATE, unrelated build-breaking regression fixed in a prior cycle: restored
     Islet/Notch/NotchWindowController.swift line 31 from a corrupted single-line merge of two
     property declarations back into two separate lines.
  3. LAYER 2 (WeatherKit JWT auth 401) has NO local fix — it requires human action on
     developer.apple.com. No code/config change in this repo can resolve a server-side 401 from
     Apple's own auth backend. See checkpoint below for the exact portal-side action to take.
verification: |
  Fix #1 CONFIRMED this cycle via fresh clean-relaunch log: real CLLocation obtained and handed to
  WeatherService (Location layer fully verified end-to-end).
  Fix #2 self-verified in prior cycle: BUILD SUCCEEDED, entitlements re-confirmed present.
  Fix #3 (Layer 2) CONFIRMED: user checked the App ID's edit page and found WeatherKit was indeed
  checked only under "Capabilities" but NOT under the separate "App Services" section, exactly as
  the web research predicted. User checked+saved WeatherKit on App Services too, waited a few
  minutes, then Clean Build Folder + Cmd-R + expanded the notch. Human-confirmed on-device: all
  three columns now render correctly — weather ("21°C", cloud icon), time+date ("16:50, Wed 8.
  Jul"), and calendar ("Tomorrow — France ... 22:00"). Session fully resolved.
files_changed:
  - Islet/Islet.entitlements
  - Islet/Notch/NotchWindowController.swift
