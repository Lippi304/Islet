---
status: awaiting_human_verify
trigger: "Wenn ich Islet in Xcode stoppe, bleibt gelegentlich eine alte Session/Instanz von Islet im Hintergrund geöffnet (nicht wirklich beendet), sodass ich sie manuell über das Menüleisten-Icon beenden muss, bevor ich neu starten kann."
created: 2026-07-19
updated: 2026-07-19
---

## Symptoms

- **Expected behavior:** Stopping Islet in Xcode (Cmd-.) fully terminates the running instance, so the next Cmd-R launches a single fresh process.
- **Actual behavior:** Occasionally, after stopping in Xcode, an old Islet instance stays alive in the background (menu-bar icon still present/duplicated) and must be quit manually via the menu-bar item before the app can be used normally again.
- **Error messages:** None reported by the user.
- **Timeline:** User reports this has "always" been the case (schon immer) — not a recent regression.
- **Reproduction:** No clear pattern identified by the user — happens randomly (zufällig, kein klares Muster), not tied to a specific action, activity, or fast stop/restart cycle.

## Current Focus

hypothesis: CONFIRMED — Xcode's Stop button does not reliably terminate LSUIElement/background-agent apps (documented Apple Developer Forums bug, thread 47777); combined with Islet having zero single-instance guard, a surviving old debug process and a freshly Cmd+R'd new process coexist, producing the duplicated/stuck menu-bar icon.
test: n/a — fix applied (single-instance guard at launch), verified via headless build; on-device Xcode stop/restart cycling requires human verification.
expecting: n/a
next_action: User deferred dedicated verification (2026-07-19) — will confirm organically while stopping/restarting Islet across upcoming phase work rather than doing a dedicated test pass now. Revisit via `/gsd:debug continue old-islet-instance-stays-open` once the user reports back (either "confirmed" or a repro of the old behavior still occurring).
reasoning_checkpoint:
  hypothesis: "Islet's Info.plist sets LSUIElement=YES (menu-bar agent, no Dock icon). Apple Developer Forums thread 47777 documents that Xcode's Stop button does not always fully kill LSUIElement/background apps — the debugged process can survive Stop, running invisibly (no Dock icon, no visible window) except for its still-live NSStatusItem in the menu bar. Islet's AppDelegate/IsletApp.swift perform zero single-instance detection (confirmed absent in this project's own prior debug session on 2026-07-16, tray-spacing-fix-not-applying.md, Evidence entry: 'No single-instance guard exists anywhere in the app'). So when Xcode Stop fails to kill the old process (known-intermittent, matches the user's 'no clear pattern, happens randomly' report) and the user hits Cmd+R again, two live Islet processes coexist, each with its own NSStatusItem — the user sees a duplicated icon and must manually quit the stale one via its own menu."
  confirming_evidence:
    - "Apple Developer Forums thread 47777 ('Xcode stop app does not kill it') — corroborates exactly this failure mode for background/agent apps stopped from Xcode, with the documented workaround being 'manually quit before rerunning' (matches the user's actual current workaround)."
    - "Prior debug session on this same codebase (.planning/debug/resolved/tray-spacing-fix-not-applying.md) directly reads AppDelegate.swift/IsletApp.swift and states: 'No single-instance guard exists anywhere in the app (no NSRunningApplication check for an existing bundle identifier, no explicit kill-prior-instance logic)' — confirmed again by this session's own read of both files (AppDelegate.applicationDidFinishLaunching creates the status item/panel/menu unconditionally, no existence check)."
    - "Islet is LSUIElement (per CLAUDE.md project setup instructions), which is exactly the app category the forum thread describes as affected — a normal foreground/Dock app stopped from Xcode does not exhibit this."
  falsification_test: "If Xcode's Stop reliably and immediately killed every Islet process (verifiable via `ps aux | grep Islet` returning nothing within ~1s of clicking Stop, tested across many repeated stop/restart cycles), the hypothesis would be refuted — the duplication would have to come from elsewhere (e.g. a genuine relaunch trigger). This was not directly reproduced in this environment (no interactive Xcode/GUI session available here); the fix instead makes the specific failure mode irrelevant by having every launch self-heal any leftover instance, so it holds regardless of exactly how often/why Xcode's Stop itself misbehaves."
  fix_rationale: "Root cause is Xcode/macOS's known unreliable termination of background agent apps, which is outside Islet's control to fix directly. The correct root-cause-level mitigation within the app's own control is a single-instance guard: force-terminate any other running process sharing Islet's bundle identifier as the very first action in applicationDidFinishLaunching, before the new instance creates its own status item/panel. This makes every fresh launch self-healing — regardless of why or how often Xcode's Stop leaves a stale process behind, the next launch always converges to exactly one running Islet, eliminating the manual-quit step entirely. This is a fix at the mechanism level (instance uniqueness), not a workaround for one specific symptom."
  blind_spots: "Cannot reproduce the intermittent Xcode-Stop-fails-to-kill behavior directly in this non-interactive environment — relying on the documented Apple Developer Forums report plus the code-level absence of any instance guard as converging evidence, not a live repro. forceTerminate() on the stale NSRunningApplication is not verified on-device in this session (no GUI available); it is the standard, documented API for exactly this purpose (immediate SIGKILL-equivalent, does not depend on the target process's run loop responding), so a hang in the old process should not block the new instance either way."

## Evidence

- timestamp: 2026-07-19T00:00:00Z
  checked: Islet/AppDelegate.swift and Islet/IsletApp.swift in full
  found: applicationDidFinishLaunching unconditionally creates statusItem, menu, and NotchWindowController on every launch with no check for an already-running Islet process. LSUIElement (agent, no Dock icon) confirmed as the project's intended app category per CLAUDE.md setup instructions.
  implication: Nothing in Islet's own code would detect or clean up a second simultaneously-running instance; any process-lifecycle flakiness elsewhere (Xcode Stop, crash, etc.) is free to leave a stale instance running forever until manually quit.

- timestamp: 2026-07-19T00:01:00Z
  checked: .planning/debug/resolved/tray-spacing-fix-not-applying.md (prior unrelated debug session on this same codebase, 2026-07-16)
  found: That session's Evidence section explicitly notes "No single-instance guard exists anywhere in the app (no NSRunningApplication check for an existing bundle identifier, no explicit 'kill prior instance' logic)" — raised as a lead, then not pursued because it wasn't the root cause of that (different) bug.
  implication: Independent confirmation, from an earlier unrelated investigation of this exact codebase, that the instance-guard gap is real and pre-existing — not something introduced recently, consistent with the user's "always been the case" timeline.

- timestamp: 2026-07-19T00:02:00Z
  checked: Web search — "Xcode stop button menu bar agent app LSUIElement process still running after stop debugger"
  found: Apple Developer Forums thread 47777 ("Xcode stop app does not kill it and makes debugger...") documents this exact failure mode for background-activity/agent apps stopped via Xcode's Stop button, with "manually quit before rerunning" as the reported workaround — matching the user's current manual workaround exactly.
  implication: The intermittent, patternless "old instance survives Stop" behavior is a known Xcode/macOS limitation for LSUIElement apps, not a bug introduced by Islet's own code — but Islet's total lack of a single-instance guard is what turns that known Xcode quirk into a persistent, user-visible duplicate-icon problem requiring manual cleanup.

## Eliminated

## Resolution

root_cause: |
  Xcode's Stop button is documented (Apple Developer Forums thread 47777) to not always
  reliably terminate LSUIElement/background-agent macOS apps — the debugged process can
  survive Stop and keep running invisibly (no Dock icon) with its NSStatusItem still live
  in the menu bar. Islet has zero single-instance guard anywhere in its launch code
  (AppDelegate.applicationDidFinishLaunching unconditionally creates a new status item,
  menu, and notch panel on every launch with no check for an already-running instance —
  independently confirmed both by direct code reading in this session and by a prior,
  unrelated debug session on 2026-07-16). So whenever Xcode's Stop leaves an old process
  alive (intermittent, matching the user's "no clear pattern" report), the next Cmd+R
  produces a second live instance with its own duplicate menu-bar icon, requiring manual
  quit of the stale one.
fix: |
  Added a single-instance guard as the very first action in
  AppDelegate.applicationDidFinishLaunching: force-terminate any other running process
  sharing Islet's bundle identifier before this instance creates its own status item/panel.
  This makes every launch self-healing regardless of why/how often Xcode's Stop leaves a
  stale process behind.
verification: |
  Self-verified: `xcodebuild -scheme Islet -configuration Debug build` succeeded with the
  fix applied. On-device Xcode stop/restart cycling verification requires the user (GUI-only
  step, no interactive Xcode session available in this environment).
files_changed:
  - Islet/AppDelegate.swift
