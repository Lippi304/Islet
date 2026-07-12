---
phase: 27-settings-sidebar-redesign
plan: 04
subsystem: settings
tags: [swiftui, navigationsplitview, appkit, on-device-uat, checkpoint]

requires: ["27-02", "27-03"]
provides:
  - "Verified full Debug + Release build with zero dead references to the deleted single-value accent/material symbols"
  - "On-device UAT approval covering all 4 sidebar sections, live theming, and section-switch state sync (SETTINGS-01, VISUAL-03)"
  - "Working Settings window open path (menu bar icon) — .defaultLaunchBehavior(.suppressed) removed"
  - "Working sidebar navigation — List(selection:) replaced with a plain Button-based row implementation"
affects: []

tech-stack:
  added: []
  patterns:
    - "AppKit-owned NSWindow was tried as a fix for a SwiftUI Window(id:) creation bug, then reverted after it broke NavigationSplitView's List selection — documents that NavigationSplitView/List selection depends on genuine Scene hosting"
    - "Plain Button rows (selection set directly on tap) as a robust replacement for List(selection:) when List's native row-selection routing is unreliable"

key-files:
  created: []
  modified:
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/AppDelegate.swift
    - Islet/IsletApp.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/SettingsView.swift

key-decisions:
  - "Removed .defaultLaunchBehavior(.suppressed) from the Settings Window(id:) scene — on-device diagnostic instrumentation (printing NSApp.windows at click time) proved it prevented the scene's NSWindow from being created at all, not merely hidden, so the notification-bridge listener living inside that window's own content never existed to receive the open request."
  - "Tried replacing the SwiftUI Window(id:) scene with an AppKit-owned NSWindow (NSHostingController-backed) to sidestep Scene-lifecycle ambiguity entirely. This fixed the open bug but broke NavigationSplitView's sidebar List selection (confirmed: Toggle/Button controls in the same window worked, but no sidebar click ever changed `selection`). Reverted to the Scene-hosted Window(id:) design once this was discovered, keeping only the .suppressed removal."
  - "List(SidebarSection.allCases, selection: $selection) never registered a single click on-device, across 3 separate attempts (Scene-hosted window, AppKit-hosted window, .listStyle(.sidebar) + .contentShape(Rectangle()) on the row Label) — confirmed via an .onChange(of: selection) diagnostic print that never fired. Root cause not conclusively identified (suspected macOS 26 / Xcode 26.6 List-selection regression, since the code was textbook-correct SwiftUI). Replaced List with a plain VStack of Buttons (each setting `selection` directly, with manual selected-row highlighting) — the same primitive already proven reliable elsewhere in this exact window."

requirements-completed: [SETTINGS-01, VISUAL-03]

duration: ~3h (majority spent in on-device checkpoint debugging across 3 distinct on-device-reported bugs)
completed: 2026-07-13
---

# Phase 27 Plan 04: Integration & Verification Summary

**Full build gate + dead-reference grep sweep passed, followed by an extensive on-device UAT checkpoint that surfaced and fixed 2 real regressions (Settings window never opening; sidebar navigation completely unresponsive) neither of which any automated check could have caught — both required live on-device interaction to discover.**

## Performance

- **Duration:** ~3h total, dominated by iterative on-device checkpoint debugging
- **Tasks:** 2 completed (Task 1 auto; Task 2 checkpoint:human-verify, required 3 fix-and-retest rounds before approval)

## Accomplishments
- Task 1: Debug + Release builds both green; dead-reference grep sweep passed after removing leftover unused `activityAccent`/`ActivityAccentKey` scaffolding from Plan 01 that Plan 02 never actually deleted
- Task 2 on-device UAT: user reported Settings would not open via the menu bar icon at all — root-caused via diagnostic instrumentation (printing `NSApp.windows` at click time) to `.defaultLaunchBehavior(.suppressed)` preventing the `Window(id: "settings")` scene's `NSWindow` from ever being created, so its notification-bridge listener had nothing to receive the open request
- First fix attempt (AppKit-owned `NSWindow` via `NSHostingController`, bypassing the SwiftUI Scene) resolved the open bug but introduced a new one: the `NavigationSplitView` sidebar's `List` selection stopped responding to clicks entirely. Reverted to the Scene-hosted design, keeping only the evidence-backed fix (dropping `.defaultLaunchBehavior(.suppressed)`)
- After reverting, the sidebar was STILL completely unresponsive — confirmed via a second diagnostic (`.onChange(of: selection)`) that `List(selection:)` never registered a single click regardless of hosting mechanism, `.listStyle(.sidebar)`, or `.contentShape(Rectangle())` on the row content
- Replaced `List(selection:)` with a plain `VStack` of `Button` rows (manual selection state + manual highlight styling) — the same primitive already proven reliable elsewhere in the same window (Toggle/Button in the General section worked throughout) — user confirmed this fixed sidebar navigation
- Full 10-step on-device UAT walkthrough (sidebar sections, live material-style switching, independent per-element accent swatches, About section, rapid section-switch state sync, quit/relaunch persistence, window sizing) approved by user

## Task Commits

1. **Task 1: Full build gate + dead-reference grep sweep** — `8a9c1b1` (fix, dead code removal)
2. **Task 2: On-device UAT** — multiple fix commits across the checkpoint's debugging rounds:
   - `128ee63` — `.defaultSize` on Settings window scene (superseded; window still never created)
   - `e989482` — AppKit-owned `NSWindow` replacing the SwiftUI Scene (fixed open bug, broke sidebar selection — reverted)
   - `73aa999` — revert to Scene-hosted `Window(id:)`, drop `.defaultLaunchBehavior(.suppressed)` (the actual open-bug fix that survived)
   - `3415412` — replace `List(selection:)` sidebar with plain `Button` rows (the actual sidebar-selection fix)

_Note: this plan's Task 2 required significantly more iteration than a typical checkpoint — see Deviations below._

## Files Created/Modified
- `Islet/ActivitySettings.swift` — dead `activityAccent`/`ActivityAccentKey` scaffolding removed (Task 1)
- `Islet/Notch/NotchPillView.swift` — one stale comment reference updated (Task 1)
- `Islet/AppDelegate.swift` — `hideSettingsWindowOnLaunch()`/`openSettings()` unchanged from pre-plan state after the full revert-and-fix cycle
- `Islet/IsletApp.swift` — `Window(id: "settings")` scene retained; `.defaultLaunchBehavior(.suppressed)` removed
- `Islet/Notch/NotchWindowController.swift` — one comment corrected to not imply a removed-then-restored scene reference
- `Islet/SettingsView.swift` — sidebar `List(selection:)` replaced with a `VStack` of `Button` rows

## Decisions Made
See `key-decisions` in frontmatter — all three are genuine architectural findings from live on-device debugging, not planning-time choices.

## Deviations from Plan

**Major deviation (Rule 2/3 — significant, user-facing bugs found during the mandated on-device checkpoint, not anticipated by the plan):** Task 2's on-device UAT surfaced two real regressions that no automated build/grep check could catch:

1. Settings never opened via the menu bar icon at all (root cause: `.defaultLaunchBehavior(.suppressed)`, added in an earlier phase for a different bug, silently prevented the Settings window from ever being created).
2. Once that was fixed, the sidebar navigation (the core deliverable of Plan 27-03 / SETTINGS-01) was completely unresponsive to clicks — `List(selection:)` never registered a single click regardless of 3 different fix attempts, ultimately requiring replacement with a hand-rolled `Button`-based sidebar.

Both were root-caused using targeted temporary diagnostic `print()` instrumentation (removed before the final commits) rather than static reasoning alone, after initial fix attempts based on plausible-but-wrong static analysis failed to resolve the symptoms on-device. This is exactly the failure mode `checkpoint:human-verify` gates exist to catch — both bugs would have shipped invisibly past every build/grep gate in this plan.

## Issues Encountered

The `List(selection:)` sidebar-selection failure's root cause was not conclusively identified (the SwiftUI code was textbook-correct); a specific macOS 26 / Xcode 26.6 List-selection regression is suspected but unconfirmed. The Button-based replacement resolves the symptom robustly regardless of the underlying cause.

## User Setup Required

None — all fixes are code-level and already verified on-device by the user (full 10-step UAT approved).

## Next Phase Readiness

Phase 27 (Settings Sidebar Redesign) is functionally complete and on-device verified. No further plans in this phase.

---
*Phase: 27-settings-sidebar-redesign*
*Completed: 2026-07-13*

## Self-Check: PASSED
