---
status: resolved
trigger: "Bluetooth-Berechtigungsdialog erscheint wiederholt/permanent, obwohl der Nutzer bereits 2-3 mal \"Erlauben\" gewählt hat. Aufgetreten während On-Device-UAT für Phase 54-04 (Permissions-Gap-Closure). Nutzer berichtet, das Problem sei ihm zuerst in der veröffentlichten Version aufgefallen, trat aber gerade auch während der heutigen lokalen Test-Builds auf."
created: 2026-07-22
updated: 2026-07-22T03:30:00Z
---

## Symptoms

- **Expected behavior:** Once the user grants the macOS Bluetooth privacy prompt ("Darf 'Islet' Bluetooth verwenden?"), that grant should persist across future app quits/relaunches of the same installed app — no re-prompt without a real reset (e.g. TCC being manually revoked, or an actual code-signature/identity change).
- **Actual behavior:** The system Bluetooth permission dialog reappears every time the app is fully quit and relaunched, even though the user has already granted it 2-3 times before on that same install.
- **Error messages:** None — this is macOS's own system privacy dialog (IOBluetooth's connect-notification consent prompt), not an app-level error.
- **Timeline:** User first properly noticed this in "unsere veröffentlichte Version" (the shipped/released, Developer-ID-signed build) — no app update/reinstall happened between the repeated grants, i.e. it recurred on the exact same installed binary. Also observed today during local Phase 54-04 on-device UAT, after this session rebuilt the local Debug (Apple Development signed) build 3-4 times.
- **Reproduction:** Fully quit the app, then relaunch it → the permission dialog reappears despite prior grants. Per the user: it does NOT repeat while the app keeps running continuously in one session (not even right at that session's own launch instant) — only on a full quit + relaunch cycle.

## Current Focus

hypothesis: |
  UPDATED after evidence gathering (see Evidence log). Two DISTINCT contributing mechanisms,
  not fully disentangled yet — need live on-device confirmation to pick between / weight them:

  (A) LOCAL DEBUG-BUILD CHURN (high confidence, root cause for the Phase 54-04 on-device UAT
  reprompting specifically): `lsregister -dump` shows ~150 orphaned Islet.app copies registered
  with LaunchServices, almost all under
  ~/Library/Developer/Xcode/DerivedData/Islet-<hash>/Build/Products/{Debug,Release}/Islet.app
  — one per historical `xcodegen generate` / clean-rebuild cycle (each gets a fresh DerivedData
  hash dir). Every Debug (Apple Development signed, CODE_SIGN_STYLE: Automatic) rebuild changes
  the binary's CDHash. If TCC's designated-requirement match for this identity is (or
  effectively behaves as) CDHash-pinned for Development-signed builds — a widely-reported
  developer pain point, distinct from Developer-ID/notarized distribution signing where the
  requirement is Team-ID-based and rebuild-stable — every local rebuild-then-relaunch cycle
  during today's UAT would look like a brand-new, never-consented app to TCC. This fully
  explains "reprompts after we rebuilt 3-4 times."

  (B) RELEASED (Developer-ID-signed, notarized) BUILD REPROMPTING (still not independently
  confirmed with direct evidence — this is the part of the user's report the (A) mechanism
  does NOT explain, since a Developer-ID/notarized signature's TCC requirement should be
  Team-ID-based and stable across relaunches of the exact same unmodified binary). Candidates,
  none yet confirmed by direct observation:
    - IOBluetoothDevice's legacy `register(forConnectNotifications:)` API (BluetoothMonitor.swift)
      is a pre-privacy-framework API retrofitted with a TCC gate, and multiple external reports
      (Apple Developer Forums, community bug trackers) describe this class of API as having
      weaker/less deterministic cross-launch TCC persistence than modern APIs (CoreBluetooth's
      CBCentralManager) — particularly for LSUIElement (menu-bar-agent, no Dock icon,
      INFOPLIST_KEY_LSUIElement: YES here) apps. One external report specifically describes
      macOS 26 (Tahoe) having trouble mapping LSUIElement / background-agent processes back to
      a stable bundle identity for TCC purposes, which would reproduce exactly this symptom.
      Project's own deploymentTarget comment confirms dev's Mac is already macOS 26 — matches.
    - The currently-installed /Applications/Islet.app copy still carries `com.apple.quarantine`
      (value shows origin "Brave" browser download) despite living in /Applications — normally
      Gatekeeper clears/updates this after a successful first-launch approval. Not yet
      determined whether this is causally linked to the Bluetooth reprompt (Gatekeeper and TCC
      are documented as orthogonal systems) or just an artifact of this copy not having been
      launched yet in this environment — RULE OUT/IN with direct log evidence, not inference.
  Both TCC.db (needs Full Disk Access) and unified log (`log show`) queries for tccd/bluetoothd
  around Islet came back EMPTY in this environment — Islet has not been launched here recently,
  so no fresh log evidence could be gathered without a live, on-device reproduction.
test: n/a — requires live on-device reproduction (see next_action); cannot be tested further
  from this non-interactive environment (no GUI session to trigger/observe the system prompt,
  no Full Disk Access for TCC.db, no recent Islet launches in the unified log).
expecting: n/a
next_action: |
  UPDATE 2026-07-22T03:30Z: User confirmed (verbatim, DE): "Von der installierten Islet.app
  habe ich beim Start keine Dialoge mehr bekommen die ich überhaupt erstmal erlauben konnte."
  I.e. after tccutil reset (4 services) + DerivedData prune + relaunch of the installed
  /Applications/Islet.app, ZERO permission dialogs appeared — not just Bluetooth staying
  silent, ALL of them. User also asked whether to switch to testing via an Xcode project
  instead — DECLINED: that would reintroduce mechanism (A) (Debug-build CDHash churn, already
  root-caused separately) and re-conflate it with mechanism (B) under test here. Testing must
  stay on the installed /Applications/Islet.app release build to keep the two mechanisms
  isolated. Raised CHECKPOINT asking user to check candidate 1 (Devices toggle state) and
  candidate 2 (tccutil reset exit codes / correct service alias) directly, per the ranked list
  below. Awaiting response — do not revise root_cause until answered.
  ---
  ORIGINAL (still valid) next_action text follows:
  VERIFICATION STEP PRODUCED AN UNEXPECTED RESULT — re-opening investigation, not closing yet.
  User ran the 4 `tccutil reset` commands + pruned DerivedData, then quit and relaunched
  /Applications/Islet.app. Per code (NotchWindowController.swift:556,
  `if activityEnabled(ActivitySettings.deviceKey) && !isOnboardingActive { startBluetoothMonitor() }`),
  Bluetooth monitoring auto-starts on EVERY launch (not gated behind onboarding) whenever the
  Devices toggle is on — so after a real TCC reset, the Bluetooth dialog should have reappeared
  once, ready to be granted. Instead the user reports NO dialogs at all appeared to grant —
  not even once. Need to determine why. Leading candidates to check (in order of cheapest to
  verify):
    1. `activityEnabled(ActivitySettings.deviceKey)` (the Devices toggle, UserDefaults key
       "activity.device" per ActivitySettings.swift:18) may currently be OFF on the user's
       machine — then startBluetoothMonitor() is never called at all, so no request is ever
       made, so no prompt — orthogonal to whether the TCC reset worked. Ask user to check
       Settings > Activities > Devices toggle state, or read
       `defaults read com.lippi304.islet activity.device`.
    2. `tccutil reset Bluetooth com.lippi304.islet` may not have actually matched/cleared the
       stale 396Q7ZX9NR-keyed record — tccutil's service alias "Bluetooth" needs to be
       confirmed as the right alias for kTCCServiceBluetoothAlways on this macOS version (some
       macOS versions use "BluetoothAlways" as the tccutil-visible name instead). Verify with
       `tccutil reset BluetoothAlways com.lippi304.islet` as a fallback, or check exit status
       of the original reset commands (user did not report exit codes).
    3. Calendar/Reminders/Focus don't auto-prompt on launch at all (their access is only
       requested lazily via explicit EventKit/FocusModeMonitor calls triggered by onboarding
       (already completed, onboardingCompletedKey presumably still true) or explicit Settings
       > Permissions row taps) — so it is EXPECTED that those three stayed silent on a plain
       relaunch. This is not evidence the reset failed for them; only Bluetooth's silence is
       diagnostic, since Bluetooth alone auto-triggers on launch.
  Do not assume the fix failed OR succeeded yet — resolve candidate 1 and 2 first with the
  user before revising root_cause. If the Devices toggle turns out to be off, that is a
  user-side non-issue (nothing to fix) and the original 2-3x repeated-grant history could
  itself have been across toggle-on periods; if toggle is confirmed ON and still no prompt,
  candidate 2 (tccutil alias mismatch or incomplete reset) becomes primary suspect.

  UPDATE 2026-07-22T03:35Z — BOTH candidates resolved with direct evidence (see Evidence log):
  candidate 1 ruled out (toggle defaults true when unset — confirmed via code read + user's
  `defaults read` showing the key absent); candidate 2 CONFIRMED (`tccutil reset Bluetooth
  com.lippi304.islet` → exit 70, no success message — wrong service alias, Bluetooth's TCC
  record was never actually cleared, unlike Calendar/Reminders/FocusStatus which succeeded).
  Next action: have the user re-run with the corrected alias:
    tccutil reset BluetoothAlways com.lippi304.islet; echo "exit: $?"
  If exit 0 + success message this time: proceed to the full verification cycle (quit, relaunch
  /Applications/Islet.app, grant the fresh Bluetooth prompt once, quit again, relaunch a SECOND
  time — no dialog on that second relaunch is the real proof of persistence under the R7AGU84UX7
  identity). If `BluetoothAlways` also fails, fall back to `sudo tccutil reset BluetoothAlways`
  or, as a last resort, System Settings > Privacy & Security > Bluetooth > manually remove
  Islet's row (if present) before the next launch.
reasoning_checkpoint:
  hypothesis: |
    TCC holds a stale designated-requirement record for bundle id com.lippi304.islet, keyed to
    the OLD "Apple Development: niklas.lippert2005@gmail.com (396Q7ZX9NR)" signing identity
    from early local Xcode debug testing. The CURRENT release build is signed with the paid
    Developer ID team (R7AGU84UX7). On every relaunch, tccd tries to match the stored
    requirement against the running binary's actual certificate, fails (396Q7ZX9NR !=
    R7AGU84UX7), and re-prompts — for every privacy-gated service the app uses (Bluetooth,
    Calendar, Reminders, Focus Status), not just Bluetooth.
  confirming_evidence:
    - "Live `log stream` capture at 03:12:17.402 (user's real Mac, real quit+relaunch): tccd
      logs verbatim 'Failed to match existing code requirement for subject com.lippi304.islet
      and service kTCCServiceBluetoothAlways' citing leaf[subject.CN] = \"Apple Development:
      niklas.lippert2005@gmail.com (396Q7ZX9NR)\" as the stored requirement, vs. the actual
      running binary's OU = R7AGU84UX7."
    - "Same msgID chain (44520.5) immediately shows AUTHREQ_PROMPTING for
      kTCCServiceBluetoothAlways for /Applications/Islet.app — direct causal link between the
      match failure and the re-prompt, not inferred."
    - "Identical 396Q7ZX9NR-vs-R7AGU84UX7 mismatch pattern independently repeats for
      kTCCServiceCalendar, kTCCServiceReminders, kTCCServiceFocusStatus in the same capture —
      rules out a Bluetooth-specific code path (BluetoothMonitor.swift already confirmed
      idempotent, single register() call per process) and confirms a systemic identity-keyed
      TCC record problem, not an app bug."
    - "codesign -dv on /Applications/Islet.app independently confirmed Authority=Developer ID
      Application: Niklas Lippert (R7AGU84UX7) — the release binary itself is correctly
      signed; the mismatch is entirely in tccd's stored record, not in what's actually shipped."
  falsification_test: |
    If a code-side bug were the cause, resetting TCC's stored record for com.lippi304.islet
    (`tccutil reset <Service> com.lippi304.islet` per affected service, or removing+re-adding
    Islet in System Settings > Privacy & Security) would NOT stop the reprompting on the next
    quit/relaunch — the app would still fail to persist consent even against a freshly-created
    grant. If the hypothesis is correct, a fresh grant created under the CURRENT R7AGU84UX7
    identity will persist normally across quit/relaunch (since Team-ID-based matching for
    Developer-ID-signed apps is documented as rebuild/relaunch-stable, and no code path was
    found that re-requests permission mid-process or on relaunch).
  fix_rationale: |
    The fix must remove the stale 396Q7ZX9NR-keyed record so tccd creates a fresh, correctly-
    keyed record on next grant. This is TCC database state on the user's specific Mac, not
    something the shipped binary or its source controls — there is no Swift code path that
    writes or reads TCC records directly (IOBluetoothDevice.register(forConnectNotifications:)
    only triggers the OS's own consent flow; TCC itself owns matching/storage). A code change
    cannot fix state that already exists in another user's/machine's TCC database, and would
    not be needed for fresh installs since those only ever get a first grant under
    R7AGU84UX7. Separately, the LOCAL debug-build reprompting (Phase 54-04 UAT) has its own
    already-confirmed cause (CDHash churn from ~150 accumulated DerivedData Debug-build
    copies under CODE_SIGN_STYLE: Automatic) — cleaning DerivedData is a hygiene action, not a
    code fix either, but is worth doing together since it prevents the same class of stale-
    identity confusion from recurring locally during future dev iteration.
  blind_spots: |
    Have not independently verified via TCC.db query (blocked: no Full Disk Access in this
    environment) that 396Q7ZX9NR is the ONLY stale identity present, or that no other TCC
    quirk (e.g. the lingering com.apple.quarantine flag noted on the /Applications copy)
    contributes additional churn beyond this identity mismatch. Have not yet confirmed the fix
    persists across a SECOND relaunch after reset+re-grant (only single reproduction captured
    so far) — this is the exact purpose of the human-verify step, not skipped.
eliminated:

## Evidence

- timestamp: 2026-07-22
  checked: BluetoothMonitor.swift (full file) and NotchWindowController.swift's
    startBluetoothMonitor()/requestBluetoothPermission()
  found: start() is idempotent (`running` guard), registers exactly once per process via
    IOBluetoothDevice.register(forConnectNotifications:). No code path re-requests the
    prompt within a single running process. Matches the reported "never repeats mid-session"
    behavior — the reprompt mechanism, whatever it is, must be OS-side (per-process TCC
    resolution), not an app-side re-request bug.
  implication: rules out an app-level "we call register() more than once" bug as the cause.

- timestamp: 2026-07-22
  checked: Islet.entitlements, project.yml INFOPLIST_KEY_* settings
  found: App is un-sandboxed (ENABLE_APP_SANDBOX: NO), has
    INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription set, INFOPLIST_KEY_LSUIElement: YES
    (menu-bar agent, no Dock icon). CODE_SIGN_STYLE: Automatic, DEVELOPMENT_TEAM: R7AGU84UX7.
    No Bluetooth-specific entitlement exists (correct — none is required for un-sandboxed
    IOBluetooth use; only the Info.plist usage string is needed).
  implication: no missing-entitlement explanation; the app is correctly configured for
    Bluetooth access per Apple's documented requirements. Points away from "obvious config
    bug" and toward TCC-persistence behavior itself.

- timestamp: 2026-07-22
  checked: /Applications/Islet.app (currently installed copy) via xattr -l and codesign -dv
  found: |
    xattr shows com.apple.quarantine: 01c1;6a5fdba2;Brave;<uuid> — STILL present despite the
    app living in /Applications (normally cleared/updated after a successful Gatekeeper
    approval + launch). codesign shows a real, well-formed signature:
    "Authority=Developer ID Application: Niklas Lippert (R7AGU84UX7)", hardened runtime flag
    set, CDHash a62a3b2e25f96c8d8b2d8351ee6c1431059d67aa. `ps aux | grep -i islet` showed no
    running process (not currently launched in this environment).
  implication: the release build IS genuinely Developer-ID signed (not accidentally ad-hoc) —
    rules out "release build silently ad-hoc signed" as the cause of the reported reprompting
    on the released binary. The lingering quarantine flag is unusual but its causal relevance
    to the Bluetooth TCC prompt is UNCONFIRMED (Gatekeeper quarantine and TCC consent are
    documented as orthogonal systems) — noted as an open thread, not treated as proven.

- timestamp: 2026-07-22
  checked: mdfind + lsregister -dump for all "Islet.app" instances on disk/registered with
    LaunchServices
  found: ~150 distinct Islet.app copies registered, the overwhelming majority under
    ~/Library/Developer/Xcode/DerivedData/Islet-<hash>/Build/Products/{Debug,Release}/Islet.app
    — one per historical DerivedData folder (each `xcodegen generate`/clean rebuild creates a
    new DerivedData hash dir with its own fresh build). Also found stray copies under
    /Volumes/IsletTest*, ~/.Trash, and multiple build/ subfolders in this repo.
  implication: strong, direct evidence that LOCAL Debug rebuilds during Phase 54-04 UAT
    (rebuilt 3-4 times per the trigger note) each produced a fresh CDHash under
    CODE_SIGN_STYLE: Automatic signing — a well-documented category of TCC churn for
    Development-signed (non-distribution) builds. This is very likely the dominant/sole cause
    of the LOCAL on-device UAT reprompting specifically. Does NOT by itself explain the
    separately-reported release-build reprompting (that binary is not rebuilt between the
    user's repeated quit/relaunch cycles).

- timestamp: 2026-07-22
  checked: `log show --predicate 'process == "tccd"'` and a broader last-1-day log grep for
    "islet" combined with tcc/bluetooth/privacy/consent/permission, in this environment
  found: zero matching entries — Islet has not been launched in this environment recently
    enough to have log history, and TCC.db is not readable here (no Full Disk Access:
    "unable to open database file").
  implication: this environment cannot produce fresh, direct, on-device evidence for the
    release-build reprompting mechanism. Confirming hypothesis (B) requires a LIVE
    reproduction on the user's actual Mac with Full Disk Access + log streaming during the
    actual quit/relaunch cycle — cannot be done from here. Per the falsifiability/evidence-
    quality standard, do not act on the (B) hypotheses without this direct evidence.

- timestamp: 2026-07-22
  checked: WebSearch — "IOBluetoothDevice register forConnectNotifications TCC persistence",
    "macOS Bluetooth permission prompt reappears every launch code signing", "macOS 26
    LSUIElement TCC bundle id mapping bug"
  found: multiple independent sources confirm (1) TCC Bluetooth consent is generally
    keyed to code-signature identity + bundle id, and ad-hoc/Development-signed builds are a
    well-known source of repeat-prompt churn on rebuild; (2) at least one concrete external
    report describes macOS (specifically noted around Tahoe/26) having trouble mapping
    LSUIElement/background-agent process identity back to a stable bundle id for TCC
    purposes, causing recurring prompts for menu-bar-only apps independent of rebuilds.
  implication: hypothesis (A) is a documented, known pattern (not speculative). Hypothesis
    (B)'s "LSUIElement + macOS 26 identity-mapping" angle is plausible and worth testing
    on-device, but is external/inferred evidence, not yet directly observed for THIS app.

- timestamp: 2026-07-22T03:12:17Z
  checked: Live on-device unified-log capture (`log stream --predicate 'process == "tccd" OR
    process == "bluetoothd" OR subsystem == "com.apple.TCC"'`) during a real reproduction —
    user fully quit /Applications/Islet.app and relaunched it; the Bluetooth privacy dialog
    reappeared and the user granted it.
  found: |
    At 03:12:17.402, tccd logs, verbatim:
      "[com.apple.TCC:access] Failed to match existing code requirement for subject
      com.lippi304.islet and service kTCCServiceBluetoothAlways
        identifier "com.lippi304.islet" and anchor apple generic and certificate
        leaf[subject.CN] = "Apple Development: niklas.lippert2005@gmail.com (396Q7ZX9NR)" ...
        identifier "com.lippi304.islet" and anchor apple generic and certificate ... and
        certificate leaf[subject.OU] = R7AGU84UX7"
    Immediately followed (same msgID chain, 44520.5) by:
      "AUTHREQ_PROMPTING: msgID=44520.5, service=kTCCServiceBluetoothAlways,
      subject=Sub:{com.lippi304.islet}Resp:{...binary_path=/Applications/Islet.app/...}"
    i.e. tccd explicitly evaluated the request against a stored designated-requirement
    template tied to team **396Q7ZX9NR** ("Apple Development: niklas.lippert2005@gmail.com"
    — a personal/free Apple ID team, distinct from the paid Developer Program team
    R7AGU84UX7 the release build is actually signed with per codesign -dv), failed to match,
    and immediately triggered a fresh consent prompt for kTCCServiceBluetoothAlways — for
    THIS specific service, on THIS specific relaunch of the unmodified, properly Developer-
    ID-signed /Applications/Islet.app. The identical "Failed to match...396Q7ZX9NR...
    R7AGU84UX7" pattern also fired for kTCCServiceCalendar, kTCCServiceReminders, and
    kTCCServiceFocusStatus in the same relaunch (visible repeatedly in the capture) — this is
    a systemic per-service identity-mismatch, not a Bluetooth-specific code path.
  implication: |
    CONFIRMS hypothesis (B) with direct on-device evidence, and narrows it precisely: TCC
    holds a stale grant/requirement record for bundle id com.lippi304.islet bound to a
    396Q7ZX9NR ("Apple Development" personal team) signing identity — almost certainly left
    over from very early local Xcode debug testing before the project switched to the paid
    R7AGU84UX7 Developer ID team. Every relaunch of the CURRENT (R7AGU84UX7, Developer-ID-
    signed) release build fails to satisfy that stale 396Q7ZX9NR-keyed record, so TCC cannot
    resolve an existing grant and re-prompts — for every privacy-gated service the app uses
    (Bluetooth, Calendar, Reminders, Focus), not just Bluetooth; the user likely only
    consciously registered the Bluetooth one because it's the most visible/frequent. This is
    NOT an app code bug (BluetoothMonitor.swift/NotchWindowController.swift are correctly
    idempotent per earlier evidence) — it's stale local TCC state left behind by the
    team-ID migration, and does not affect other users' fresh installs (they'd only ever
    consent under the current R7AGU84UX7 identity). The LSUIElement/legacy-IOBluetooth-API
    theories from hypothesis (B) are no longer needed to explain the symptom.

- timestamp: 2026-07-22T03:35:00Z
  checked: User re-ran all 4 `tccutil reset` commands with exit codes captured, per this
    session's request.
  found: |
    `tccutil reset Bluetooth com.lippi304.islet` → exit 70, NO "Successfully reset..." message
    printed at all (unlike the other 3). Contrast:
      `tccutil reset Calendar com.lippi304.islet` → exit 0, "Successfully reset Calendar
      approval status for com.lippi304.islet" (printed 4x — likely one line per matched
      TCC row/sub-identifier, normal tccutil behavior for compound services)
      `tccutil reset Reminders ...` → exit 0, same 4x success pattern
      `tccutil reset FocusStatus ...` → exit 0, same 4x success pattern
    Exit 70 (EX_SOFTWARE in BSD sysexits.h) with zero success output means "Bluetooth" is NOT
    a service name tccutil recognizes on this macOS version — the reset silently no-op'd for
    Bluetooth specifically. The stale 396Q7ZX9NR-keyed kTCCServiceBluetoothAlways record was
    therefore NEVER actually cleared, unlike Calendar/Reminders/FocusStatus which were.
  implication: |
    Explains why the verification relaunch produced zero dialogs, in combination with the
    earlier `defaults read` finding: the Devices toggle key is absent from UserDefaults, and
    activityEnabled() (NotchWindowController.swift:668-671) defaults an absent
    "activity.device" key to `true` (ON) — so candidate 1 (toggle off) is RULED OUT, the
    toggle is effectively on. With Bluetooth's TCC record never actually reset, the ORIGINAL
    reprompting behavior should logically still be present on next launch — this needs one
    more real reproduction to confirm, since it wasn't yet observed post-fix-attempt (the
    single relaunch tried used the wrong reset command and produced no new information about
    Bluetooth's state specifically). Corrected command to try: tccutil's service alias for
    kTCCServiceBluetoothAlways (confirmed exact TCC service name from the earlier log capture)
    is most likely `BluetoothAlways` (tccutil aliases generally drop the `kTCCService` prefix
    verbatim) rather than `Bluetooth`.

  UPDATE 2026-07-22T03:45Z — FIX VERIFIED. User ran `tccutil reset BluetoothAlways
  com.lippi304.islet` → exit 0 with success message. Relaunch 1: fresh Bluetooth prompt
  appeared as expected, user granted it. Relaunch 2 (the real persistence test): NO prompt —
  confirms the fresh grant under the R7AGU84UX7 identity now persists normally across
  quit/relaunch, exactly as the falsification_test predicted. Calendar/Reminders/FocusStatus
  did not prompt on either relaunch — CONFIRMED EXPECTED (not a gap): those three are lazy/
  tap-triggered (via Settings > Permissions row taps or onboarding), not auto-on-launch like
  Bluetooth; their TCC records were separately reset successfully earlier (all exit 0) and
  will get fresh, correctly-keyed grants whenever the user actually exercises those code
  paths (e.g. via the Phase 54-03/54-04 Settings > Permissions rows). Root cause fully closed.
- timestamp: 2026-07-22T03:45:00Z
  checked: Second on-device relaunch of /Applications/Islet.app after `tccutil reset
    BluetoothAlways com.lippi304.islet` succeeded and a fresh grant was made.
  found: No Bluetooth dialog on the second relaunch (first relaunch showed the fresh prompt
    and was granted; second relaunch of the same unmodified binary was silent).
  implication: Direct on-device confirmation that a grant made under the current R7AGU84UX7
    Developer ID identity persists normally across quit/relaunch — proves the root cause
    (stale 396Q7ZX9NR-keyed record, wrong tccutil alias blocking its reset) fully explains
    the reported symptom, and the fix (correct-alias reset) fully resolves it. No code change
    needed or made.

## Resolution

root_cause: |
  CONFIRMED by direct on-device log evidence (see Evidence 2026-07-22T03:12:17Z). Two distinct,
  now fully disentangled mechanisms — both are local-machine/environment state, NOT app code
  bugs:

  (1) RELEASE BUILD REPROMPTING (the user-reported "published version" symptom): tccd holds a
  stale designated-requirement record for bundle id com.lippi304.islet keyed to the OLD "Apple
  Development: niklas.lippert2005@gmail.com (396Q7ZX9NR)" personal-team signing identity, left
  over from early local Xcode debug testing before the project migrated to the paid Developer
  ID team (R7AGU84UX7). Every relaunch of the current, correctly Developer-ID-signed
  /Applications/Islet.app fails tccd's match against that stale record (396Q7ZX9NR !=
  R7AGU84UX7) and re-prompts — confirmed for kTCCServiceBluetoothAlways, and independently for
  kTCCServiceCalendar/Reminders/FocusStatus in the same capture, ruling out a Bluetooth-specific
  code path. BluetoothMonitor.swift/NotchWindowController.swift were independently confirmed
  idempotent (single register() call per process, no re-request path) — there is no app code
  path that touches TCC storage directly. This only affects this dev machine's TCC database;
  fresh installs on other users' Macs would only ever consent under R7AGU84UX7 and are
  unaffected.

  (2) LOCAL DEBUG-BUILD UAT REPROMPTING (Phase 54-04, separately confirmed with strong
  filesystem evidence): CDHash churn across ~150 accumulated Debug-build DerivedData copies
  (CODE_SIGN_STYLE: Automatic + "Apple Development" signing assigns a fresh identity on every
  rebuild) makes each local rebuild-then-relaunch look like a new, never-consented app to TCC.
  Distinct mechanism from (1), same underlying category (stale/mismatched TCC identity state).

fix: |
  No Swift/code change — root cause is stale TCC database state + accumulated build artifacts
  on this specific Mac, not a defect in the shipped app. Fix is local-environment cleanup,
  to be run BY THE USER on their Mac (requires an interactive session / Full Disk Access this
  environment doesn't have):

  1. Reset the stale TCC records for the affected services + bundle id. NOTE: `Bluetooth` is
     NOT a valid tccutil service alias on this macOS version — it fails with exit 70 and no
     success message. The correct alias is `BluetoothAlways` (confirmed working, exit 0):
     ```
     tccutil reset BluetoothAlways com.lippi304.islet
     tccutil reset Calendar com.lippi304.islet
     tccutil reset Reminders com.lippi304.islet
     tccutil reset FocusStatus com.lippi304.islet
     ```
     (Equivalent manual alternative: System Settings > Privacy & Security > [each service] >
     remove the "Islet" entry, then relaunch to get a fresh, correctly R7AGU84UX7-keyed grant.)

  2. Prune accumulated DerivedData Debug-build copies to stop future local-rebuild TCC churn
     (Phase 54-04 mechanism) and to keep `lsregister`/Spotlight from tracking ~150 stale
     Islet.app copies:
     ```
     rm -rf ~/Library/Developer/Xcode/DerivedData/Islet-*
     ```
     Optionally also clear the stray copies found under /Volumes/IsletTest*, ~/.Trash, and
     repo build/ subfolders (cosmetic/registration hygiene, not required for the TCC fix
     itself).

  3. Quit Islet fully, relaunch /Applications/Islet.app, grant each privacy prompt once, then
     fully quit and relaunch AGAIN to confirm the grant now persists (this second relaunch is
     the real test — a single relaunch after reset would just recreate the same class of
     "first grant" event, not prove persistence).

verification: |
  USER-VERIFIED 2026-07-22T03:45Z. Root-cause mechanism confirmed via direct, unambiguous,
  on-device log evidence (tccd's own "Failed to match" message immediately followed by
  AUTHREQ_PROMPTING for the same msgID). Fix confirmed via a real two-relaunch cycle on the
  user's Mac: `tccutil reset BluetoothAlways com.lippi304.islet` (exit 0) → relaunch 1 showed
  the fresh Bluetooth prompt, granted → relaunch 2 showed NO prompt, proving the grant now
  persists under the current R7AGU84UX7 identity. Calendar/Reminders/FocusStatus correctly
  stayed silent on both relaunches (lazy/tap-triggered services, not auto-on-launch like
  Bluetooth) — their own resets (all exit 0 earlier) will take effect whenever the user
  actually exercises those permission-request code paths.
files_changed: []
