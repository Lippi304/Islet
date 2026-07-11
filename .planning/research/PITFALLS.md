# Pitfalls Research

**Domain:** Rewriting a shipped macOS notch-overlay app's core window/panel architecture (`NotchPanel`/`NotchWindowController`) and layering onboarding, settings-redesign, Material theming, and a new EventKit-write calendar view on top of it — Islet v1.4 "Architecture Redesign"
**Researched:** 2026-07-11
**Confidence:** MEDIUM-HIGH — grounded directly in this project's own phase history (PROJECT.md Key Decisions, Phase 22's two on-device UAT failures, Phase 9's fullscreen-flash escalation chain, current source at `Islet/Notch/NotchPanel.swift`/`NotchWindowController.swift`/`CalendarService.swift`/`SettingsView.swift`/`AppDelegate.swift`, and the abandoned debugging worktree `agent-a9e6341bfc04601a5`). The drag-registration mystery itself remains genuinely unresolved even after two rounds of on-device debugging by this project — flagged LOW confidence on any single explanation, MEDIUM-HIGH confidence on the ranked-candidate methodology below.

## Critical Pitfalls

### Pitfall 1: The `draggingEntered` mystery — rebuilding the SAME AppKit drag-destination bug into the new architecture

**What goes wrong:**
`NSDraggingDestination.draggingEntered` fires reliably in a minimal throwaway spike (22-01) registered directly on `NotchPanel`, but silently stops firing entirely (not a geometry/positioning miss — confirmed via a diagnostic `print` at the very top of the override that never printed) once the exact same registration is wired into the permanent `NotchWindowController` architecture (22-03), even after the one documented difference the team found (a missing `draggingUpdated` override) was restored. **True root cause is still unknown** (`.planning/STATE.md` Blockers/Concerns, 2026-07-10 entry).

**Why it happens — ranked candidate analysis (grounded in a direct diff of the confirmed-working vs. confirmed-failing code, both read in full this session):**

| Candidate | Status | Evidence |
|---|---|---|
| Registration timing relative to `orderFrontRegardless()`/becoming key | **RULED OUT** | `registerForDraggedTypes([.fileURL])` is the last line of `NotchPanel.init` in BOTH the working spike (22-01) and the failing build (22-03) — always called before the panel is ever shown, identical in both runs. |
| `ignoresMouseEvents` toggling clearing drag-destination registration | **NOT RULED OUT, but never isolated** | Both runs exercise `syncClickThrough()`'s normal hover-driven toggling identically (same `NotchWindowController` code path in both cases) — so it's compatible with, but not proven by, either result. **Nobody ever ran the specific isolating test:** start a drag with the pointer already resting inside the hot-zone (so `ignoresMouseEvents` is already `false` from ordinary hover) vs. starting from cold/outside (matching 22-01's own spike protocol). If the former works and the latter doesn't, this candidate is confirmed. |
| Dedicated CGS Space (`CGSSpace.swift`, Phase 9) routing drag events to a different process/target | **WEAKENED** | `notchSpace.windows.insert(panel)` in `positionAndShow()` is unconditional and byte-identical in both the 22-01 spike run and the 22-03 failing run — present in the case that WORKED, so it cannot by itself explain the regression. Still worth a controlled A/B during the rewrite (see prevention) since it's a genuinely unusual private-API window/Space configuration with no external precedent found. |
| `NSHostingView` intercepting drag delegate calls before the panel sees them | **WEAKENED** | The SwiftUI content-view hierarchy (`panel.contentView = NSHostingView(rootView: makeRootView(...))`) is unchanged between the 22-01 and 22-03 test sessions — no `.onDrop` was ever added anywhere in the SwiftUI tree (Pattern 1 in `22-RESEARCH.md` was chosen: AppKit-direct registration on the panel, never SwiftUI `.onDrop`), so there is no competing SwiftUI-level registration to intercept anything, in either run. |
| A competing `NSView`'s own drag registration silently taking priority | **WEAKENED**, same reasoning as above — no new subview or its own `registerForDraggedTypes` call was introduced anywhere between the two test sessions. |
| **NEW LEAD (this research's own finding, not previously tested in isolation):** `draggingEnded(_:)` is implemented in the failing 22-03 build (`onDraggingEnded` closure + override) and was **never present** in the confirmed-working 22-01 spike (which implemented exactly 4 methods: `draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation` — no `draggingEnded`). After the team's one fix attempt (restoring `draggingUpdated`), the 22-03 build's protocol-conformance shape was `draggingEntered` + `draggingUpdated` + `draggingExited` + `draggingEnded` + `performDragOperation` — **five** methods, one more than the working spike, and it *still* failed a second on-device retest. This `draggingEnded` delta is the **one concrete, unexplained, never-isolated code-shape difference remaining** between "confirmed reliably working" and "confirmed failing twice." | **LEADING CANDIDATE FOR THE REWRITE TO TEST FIRST** | `git log` in the preserved debugging worktree (`agent-a9e6341bfc04601a5`, commits `326804d`→`d1245e8`) shows only `draggingUpdated` was ever toggled as a variable; `draggingEnded` was added in the very first 22-03 commit and never removed or isolated. |

**How to avoid (for the rewrite):**
1. **Before writing any production drag-in code in the new architecture**, re-run 22-01's *exact* 4-method spike shape (`draggingEntered`/`draggingUpdated`/`draggingExited`/`performDragOperation`, NSLog bodies, no closures, no `draggingEnded`) verbatim against the NEW `NotchPanel`/`NotchWindowController` shell, on-device, before adding anything else. This re-establishes the known-good baseline on the new architecture instead of assuming it carries over.
2. **Change exactly one variable per on-device test** (this is the discipline the original debugging skipped — it changed "closures + `draggingEnded` + missing `draggingUpdated`" all at once in 22-03's first attempt, then only tested restoring one of those three variables). Test order once the 4-method baseline passes: (a) add closures WITHOUT `draggingEnded` — confirm still works; (b) THEN add `draggingEnded` alone — if this is where it breaks, the hypothesis above is confirmed and `draggingEnded` should simply not be implemented (route its cleanup responsibility through `draggingExited`/`performDragOperation` instead, both of which AppKit guarantees fire).
3. Independently, as a separate single-variable test: verify drag delivery starting from a COLD pointer (outside hot-zone, `ignoresMouseEvents == true`) vs. a WARM pointer (already hovering, `ignoresMouseEvents == false`) — isolates the `ignoresMouseEvents` candidate that was never cleanly tested.
4. Do not reuse code from the abandoned worktree (`/Users/lippi304/conductor/repos/notch/.claude/worktrees/agent-a9e6341bfc04601a5`, branch `worktree-agent-a9e6341bfc04601a5`) by copy-paste — it is preserved for reference only and contains the exact untested-variable-combination that failed twice.

**Warning signs:**
`draggingEntered` never fires (not even a `print`/`NSLog` at its very top line) despite ordinary hover/click working fine in the same running build — this exact symptom, observed twice already, means the bug is NOT geometry/positioning and re-debugging hot-zone math is wasted effort.

**Phase to address:**
The window-shell rewrite phase (the first phase of v1.4), as its own isolated, bisection-style spike sub-task — before SHELF-01/02 drag-in functionality is re-attempted on the new architecture, and before any other phase (onboarding, settings, theming, calendar) begins, since all of them build on `NotchPanel`/`NotchWindowController`.

---

### Pitfall 2: The rewrite silently breaks one of four milestones' worth of on-device-verified interaction behavior

**What goes wrong:**
`NotchWindowController.swift` is currently 1,378 lines and is the SINGLE arbiter for: the hover/click/grace state machine (`nextState`), click-through hit-testing (`syncClickThrough()`, `hotZone`/`expandedZone`/`pointerInZone`), fullscreen hide/show via the dedicated CGS Space, multi-Space visibility, drag-out pinning (Phase 21), and (attempted) drag-in pinning (Phase 22). A "redesign" that touches this file risks silently regressing behavior that took 4 separate on-device-verified milestones and TWO already-documented regression classes to get right — without any automated safety net, since (per `.planning/STATE.md` project memory `xcodebuild-test-headless-hang`) the full interactive behavior is not testable headlessly at all.

**Why it happens:**
A "clean rewrite informed by TheBoringNotch/DynamicNotchKit" naturally tempts starting from those reference apps' simpler window-setup patterns and re-adding Islet-specific behavior afterward — but Islet's own hard-won fixes (the CR-01 click-swallowing regression, the WR-01 edge-detection discipline, Phase 9's CGS-Space fullscreen fix) are NOT generic patterns those reference apps needed to solve, so they are exactly the kind of thing a fresh rewrite forgets to re-derive.

**How to avoid:**
- Before touching `NotchPanel.swift`/`NotchWindowController.swift`, write characterization tests that lock the CURRENT pure-function contracts as an explicit regression net: `nextState(_:_:)`'s full transition table, `syncClickThrough()`'s two-branch logic (expanded → `visibleContentZone()`, collapsed → `pointerInZone`, literally ONE `ignoresMouseEvents =` write site in the whole file), and the hot-zone/expanded-zone geometry math in `NotchGeometry.swift`. These already exist in `InteractionStateTests.swift`/`NotchPanelTests.swift` — audit for coverage gaps before the rewrite starts, not after.
- Treat CR-01 (`cr01-clickthrough-or-defeat-gotcha`: `syncClickThrough()`'s expanded branch must stay a pure `visibleContentZone()` check, never OR'd with `pointerInZone`) as a locked invariant the rewrite must re-encode structurally (e.g., a single grep-able function), not just remember to avoid.
- Sequence the rewrite so ordinary hover/click/collapse/fullscreen/multi-Space behavior is on-device re-verified BEFORE any new drag-in/onboarding/theming work is layered on top — mirrors this project's own established convention (Phase 22's isolate-the-riskiest-integration-last pattern) but applied to the base layer itself first.

**Warning signs:**
Any PR/plan for this phase that does not explicitly re-run the Phase 2 UAT checklist (`02-HUMAN-UAT.md`, hover/click/grace/fullscreen — already has 8 unexercised scenarios carried as project debt) plus Phase 9's fullscreen checklist plus CR-01/WR-01 regression checks.

**Phase to address:**
The window-shell rewrite phase — make full-checklist on-device re-verification a phase-gate, not an afterthought.

---

### Pitfall 3: The rewrite drops or half-copies Phase 9's private-API CGS Space fullscreen fix

**What goes wrong:**
The fullscreen-enter flash was only genuinely fixed (not just reduced) by a **dedicated, max-level private CGS Space** (`Islet/Notch/CGSSpace.swift`, 86 lines) that the panel joins ONCE at creation, ADDITIVE to `.canJoinAllSpaces` — arrived at only after Phase 8's first candidate was disproven and escalated. Neither TheBoringNotch's nor DynamicNotchKit's basic reference architecture is guaranteed to include this exact private-API trick (it's specific to a genuine, hard-won root-cause fix, not "how you normally set up an NSPanel"), so a rewrite that pattern-matches those references for the window setup risks silently NOT carrying this file's exact wiring over, reintroducing the flash bug that already cost a 5-wave escalation to close.

**Why it happens:**
Reference-app-driven rewrites copy the parts that are visible/obvious in the reference (styleMask, level, collectionBehavior) and miss the parts that are invisible until you specifically hit the bug they fix (the CGS Space join has no user-visible effect except eliminating a 1-frame flash during a specific fullscreen-enter transition).

**How to avoid:**
Explicitly re-verify `CGSSpace.swift`'s join call is present and additive (not a replacement of `.canJoinAllSpaces`) in the new `NotchPanel`/`NotchWindowController`, and re-run all 3 documented fullscreen trigger methods (green-button, menu bar, fullscreen video) on-device as part of the rewrite's gate — do not assume "the window still shows up in fullscreen" is sufficient; the specific defect was a 1-frame flash, not total non-functionality. Also: the rewrite is a natural point to finally close the known non-blocking leak (`CGSHideSpaces`/`CGSSpaceDestroy` teardown never runs because `AppDelegate.quit()` doesn't tear down `NotchWindowController` before `NSApp.terminate`) — cheap to fix while the window lifecycle code is already being touched, expensive to remember later.

**Warning signs:**
A 1-frame black/white flash on entering fullscreen via any of the 3 trigger methods; the CGS Space's private-API return values still going unvalidated (a pre-existing WR-01/WR-02 finding from `06-REVIEW.md`, carried forward — worth actually fixing during a rewrite rather than carrying forward a third time).

**Phase to address:**
The window-shell rewrite phase.

---

### Pitfall 4: The onboarding carousel races or duplicates the existing first-launch trial/license hook

**What goes wrong:**
Today, `AppDelegate.applicationDidFinishLaunching` calls `TrialManager.shared.recordFirstLaunchIfNeeded()` (line 29) BEFORE anything else, and on a genuinely fresh install (`isFirstLaunch == true`) it skips the normal "hide Settings on launch" behavior and instead auto-opens the existing tabbed Settings window directly (lines 77-84: `didHideSettingsAtLaunch = true; ... self?.openSettings()`). This is the EXACT seam the new onboarding carousel must replace. A carousel built as a second, independently-triggered flow (its own new `hasSeenOnboarding` flag, checked separately from `isFirstLaunch`) risks: both the carousel AND the old direct-to-Settings behavior firing on the same launch, or the trial-start Keychain write firing correctly (it's idempotent — `TrialManager.swift`: `guard trialStartDate() == nil else { return false }`) while the ONBOARDING UI itself never resolves whether it's "seen" correctly, showing every launch or never at all.

**Why it happens:**
"Restyle an existing flow into a first-run sequence" reads as a UI-layer change, but the actual trigger point lives in `AppDelegate`, not in any SwiftUI view — it's easy to build the new onboarding UI correctly in isolation and wire it to a brand-new flag without noticing the existing `isFirstLaunch` branch already owns this exact moment.

**How to avoid:**
Build the onboarding carousel as a direct replacement for the `if isFirstLaunch { ... openSettings() }` branch (line 77-84) — not a parallel gate. Consume `isFirstLaunch`/`LicenseState.shared.status` as read-only inputs exactly like `SettingsView.swift` already does (`@State` mirrored from a non-observable singleton, since `LicenseState` is intentionally NOT `ObservableObject` per its own file comment). Never call `TrialManager.shared.recordFirstLaunchIfNeeded()` a second time from the onboarding flow — it's already called once, in `AppDelegate`, before the onboarding window would even be created.

**A second, separate risk in the same phase — the permissions pre-explanation screen has no existing hook to attach to:** every permission today (Calendar via `EKEventStore.requestFullAccessToEvents()` in `CalendarService.swift`, Bluetooth via `IOBluetoothDevice.register`, Location, WeatherKit) is requested LAZILY, at first actual use inside its own service — never during app launch. Adding a front-loaded "explain, then request" onboarding screen is a genuine behavior change, not just a visual one, and has a real failure mode: `CalendarService`'s existing contract is "settle `nil` on denial — never retry, never re-prompt" (D-03 comment, `CalendarService.swift` line 18). If the onboarding screen fires `requestFullAccessToEvents()` before the user has any context for why (because it's the very first screen after install, not tied to actually opening the calendar view), and the user reflexively denies it, the existing no-retry contract means the feature is **permanently, silently degraded** for that install with no other path to re-prompt in the app today.

**How to avoid (permissions screen specifically):**
Lock, as an explicit phase decision (not left to per-file discretion): does the onboarding permissions screen make the REAL system permission calls itself (risking irreversible early denial, per the no-retry contracts already baked into `CalendarService`/other services), or is it purely educational text with the real lazy-request-at-first-use behavior preserved unchanged? Given every existing permission consumer in this codebase already commits to "no retry, no re-prompt," the safer default is the latter.

**Warning signs:**
Settings window and onboarding carousel both appearing on the same first launch; a permission denied during onboarding silently disabling a feature the user never got to actually try.

**Phase to address:**
The onboarding-flow phase — explicitly read and modify `AppDelegate.swift` lines 25-94 as the integration point, and treat the permissions-screen behavior-vs-education question as a locked discuss-phase decision.

---

### Pitfall 5: Settings sidebar redesign drops the license-state refocus re-sync, per split-out child view

**What goes wrong:**
`SettingsView.swift`'s `licenseStatus` is deliberately NOT backed by `@AppStorage`/`ObservableObject` — it's a plain `@State` manually re-read on `.onAppear` AND `.onChange(of: appearsActive)` (lines 148-157), because "the user can flip license/login-item state behind the app's back" (referenced as a prior research pitfall in the file's own comments). Splitting the current single flat `Form` into multiple sidebar-section child views (General/Appearance/Activities-equivalent, per the Droppy-inspired `NavigationSplitView` redesign) means EACH new child view that reads `LicenseState.shared.status` or `LaunchAtLogin.isEnabled` needs its OWN copy of this exact re-sync discipline — or license/login-item state goes stale the moment a user switches sidebar sections without the whole Settings window losing/regaining app focus (switching sections does NOT trigger `appearsActive` to change, only leaving/returning to the app does).

**Why it happens:**
A sidebar/`NavigationSplitView` refactor is naturally framed as "split one view into several," which reads as a pure layout change — but this file's re-sync logic is currently anchored to the WHOLE WINDOW's lifecycle events (`onAppear`/`appearsActive`), not to any individual section, so decomposing the view without also decomposing (or hoisting) that re-sync logic is an easy, silent drop.

**How to avoid:**
Hoist the `licenseStatus`/`launchAtLogin` re-sync logic (the `.onAppear`/`.onChange(of: appearsActive)` block) to the new top-level `NavigationSplitView` container, not to each individual sidebar-destination child view, so it fires once regardless of which section is selected — mirrors the existing single-Form file's actual intent more faithfully than duplicating it per-section. Separately: continue reading `@AppStorage` keys via the shared `ActivitySettings.*Key` constants (already the pattern — `ActivitySettings.chargingKey`/`nowPlayingKey`/etc., also read directly by `NotchWindowController`) in every new child view, never a locally-redeclared string literal, or toggle state silently desyncs between Settings and the controller.

**Warning signs:**
License/trial countdown or the login-item toggle showing stale state after switching sidebar sections (without leaving the app); a toggle in a new sidebar section that doesn't actually affect runtime behavior (silent key-string drift).

**Phase to address:**
The Settings-redesign phase.

---

### Pitfall 6: Frosted/Material theming looks different (or breaks) because Islet's panel is PERMANENTLY unfocused, and its behavior mid-spring-morph is unverified

**What goes wrong:**
SwiftUI `Material`/glass effects are documented to visually degrade (flatten to a simpler blur, lose vibrancy layers) when the hosting window/app is not the frontmost/focused app. `NotchPanel` hardcodes `canBecomeKey`/`canBecomeMain` to `false` (lines 36-37) and the app is a non-activating `LSUIElement` agent that, by design, NEVER becomes the focused/active app. This means Islet's Material theming will ALWAYS render in the "unfocused" state every other app only hits occasionally — a theming decision eyeballed in a normal focused Xcode preview or a test window will look richer than what the shipped, always-unfocused overlay actually displays. Separately: no source found (in this research or the project's own prior research) confirms whether SwiftUI `Material` composites correctly and without artifacts DURING the existing `matchedGeometryEffect` spring-morph animation between collapsed pill and expanded shapes — this is a genuinely untested interaction.

**Why it happens:**
Design/theming work is naturally prototyped and reviewed in a normal, focused SwiftUI canvas/preview or a plain test window — not in the specific non-activating, never-focused panel configuration this app actually ships in.

**How to avoid:**
Prototype and visually approve every Material/glass choice directly inside `NotchPanel`'s real runtime configuration (non-activating, `ignoresMouseEvents` toggling, never-focused) on-device — never trust a SwiftUI preview or a normal test window for this decision. Explicitly on-device-test the chosen Material during an active collapse↔expand spring-morph, not just in static collapsed/expanded end-states — given this project's own history (Phase 18's 5-round on-device toast redesign, Phase 20's shelf-height/frame mismatch caught only on-device), budget for multiple on-device visual iteration rounds as the default expectation for this phase, not the exception.

**Warning signs:**
Material looking flat/opaque/"just a blur" instead of frosted-with-depth when actually running (vs. how it looked in Xcode preview); visible artifacts, tearing, or a hard cross-fade instead of a smooth material transition during the expand/collapse spring.

**Phase to address:**
The visual/Material redesign phase — treat "verified live on-device, mid-animation, in the real never-focused panel" as the actual acceptance criterion, not "compiles and looks right in preview."

---

### Pitfall 7: Widening `CalendarService`'s protocol seam for write access breaks the existing read-only glance consumer, and Reminders needs a permission Islet has never requested

**What goes wrong:**
`protocol CalendarService { func fetchUpcoming(completion:) }` (`Islet/Calendar/CalendarService.swift`) has exactly ONE method and ONE conformer (`EventKitService`), consumed today by the `expandedIdle` glance's next-event display (Phase 14). Adding month-view fetching + event/task creation for the new full calendar view means widening this seam — if done by editing the single existing method's signature or by adding new gating logic that both old and new call paths route through, it risks changing the ALREADY-SHIPPED, on-device-verified glance behavior (its explicit D-03 contract: "settle `nil` on Calendar access denial — never retry, never re-prompt"). Separately: if the Droppy-inspired "New Task" quick-add creates Reminders rather than Calendar events, that is a **completely separate EventKit authorization scope** (`EKEntityType.reminder`, its own `NSRemindersUsageDescription` Info.plist key) from what Islet has ever requested — `project.yml` today only declares `NSCalendarsUsageDescription` (line 57), nothing for Reminders. This is the exact class of gap Phase 14's own verification already found and fixed once for Calendar/Location/WeatherKit entitlements (`STATE.md`: "14-05 found and fixed two Hardened-Runtime entitlement gaps").

**Why it happens:**
"Expand an existing service's protocol seam" reads as additive, but a single-method protocol with a single conformer has no established precedent in this codebase for how a SECOND consumer with different requirements (write vs. read, month-range vs. next-event) should compose without changing the first consumer's behavior; and "add a calendar view" naturally reads as "more Calendar work," obscuring that Reminders is a distinct EventKit entity type with its own independent permission prompt and Info.plist key.

**How to avoid:**
Add new methods to `CalendarService` (or a new adjacent protocol) rather than modifying `fetchUpcoming`'s existing signature or behavior; keep the D-03 no-retry-no-reprompt contract scoped exactly to the existing glance consumer, and let the new calendar view have its own explicit permission-and-retry UX if the product wants one (a full calendar view plausibly SHOULD offer a "Grant Access" retry button where the passive glance should not — a real, explicit design decision, not something to inherit by accident). Before writing any Reminders code, confirm the actual Droppy-inspired "New Task" behavior targets Calendar events vs. Reminders — if Reminders, add `NSRemindersUsageDescription` to `project.yml` and treat it as a brand-new permission flow with its own on-device verification, not an extension of the existing Calendar grant.

**Warning signs:**
The existing `expandedIdle` next-event glance changing behavior (extra prompts, different denial handling) as a side effect of calendar-view work; a Reminders-backed quick-add silently failing with no permission prompt ever appearing (missing Info.plist key, not a code bug).

**Phase to address:**
The calendar full-view phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Copying the abandoned worktree's 22-03 drag-in code wholesale into the new architecture instead of re-deriving it via isolated spikes | Saves re-writing ~150 lines of already-drafted handler code | Carries forward the exact untested-variable-combination that failed twice on-device — the new architecture inherits an unexplained bug instead of a validated one | Never — always re-validate the minimal spike shape first on the new window/panel classes |
| Skipping characterization tests for `nextState`/`syncClickThrough` before starting the rewrite, to "move faster" | Rewrite starts sooner | Any behavior drift in 4 milestones of on-device-verified hover/click/fullscreen/multi-Space quirks is invisible until the NEXT on-device pass, potentially re-discovered one regression at a time (mirrors this project's own CR-01, which had to be found and re-fixed twice) | Only acceptable if the phase plan already schedules a full on-device UAT re-pass immediately after, with the same checklist Phase 2/9 originally used |
| Making the onboarding permissions screen fire real system prompts immediately (simplest to build) rather than deferring to first actual use | Simpler onboarding code, one obvious place for all prompts | Permanently degrades a feature for any user who reflexively denies a prompt they had no immediate context for, given every existing service's own "never re-prompt" contract | Never, given this codebase's existing no-retry precedent — unless a retry UX is added everywhere at the same time |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|--------------|-----------------|-------------------|
| `NSDraggingDestination` on a non-activating, click-through `NSPanel` | Assuming the documented Apple contract ("`draggingEntered`'s return value is reused if `draggingUpdated` isn't implemented") holds on this exact panel configuration — it didn't, empirically, in 22-03 | Treat every `NSDraggingDestination` method-set change as needing its own on-device re-verification on this specific panel shape; don't trust the documented contract alone |
| EventKit (Calendar vs. Reminders) | Treating "add calendar write access" as one permission bump | Calendar events (`.event`) and Reminders (`.reminder`) are separate `EKEntityType`s with separate authorization prompts and separate Info.plist usage-description keys; verify which one a feature actually needs before assuming the existing `NSCalendarsUsageDescription` grant covers it |
| `mediaremote-adapter` private-framework bridge (existing, unrelated to this milestone but sharing the "private/undocumented API" risk class) | N/A for this milestone, but the same discipline applies: isolate any new undocumented-behavior dependency (CGS Space, drag delivery on this panel shape) behind one clearly-labeled seam so a future macOS update's breakage is a one-file fix, per this project's own established `NowPlayingMonitor` precedent | Apply the same "one seam, one file" isolation to whatever the drag-registration mystery's eventual fix turns out to be |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Material/glass rendering re-composited every animation frame during the spring-morph without profiling | Visible frame drops or stutter specifically during expand/collapse, worse than the current opaque-pill baseline | Profile the chosen Material against the existing spring timing on-device before considering the theming phase done; multiple stacked blur/material layers are a known performance cost (per general SwiftUI Material guidance) | Noticeable on the actual notch hardware target even at v1 scale — this is a single-window, single-user app, so the risk is animation smoothness, not backend scale |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Onboarding permissions screen requesting real Calendar/Bluetooth/Location access before the user has any feature context | Permanent, silent feature degradation for users who reflexively deny (no retry path exists anywhere in this codebase today) | Default the permissions screen to educational-only; keep real requests lazy/at-first-use as today, unless a retry UX is deliberately added everywhere at once (Pitfall 4) |
| Adding Reminders write access without a distinct `NSRemindersUsageDescription` entitlement | App silently fails to prompt at all (not a crash, not an error — just nothing happens), indistinguishable from a code bug during on-device testing | Add the Reminders Info.plist key explicitly if Reminders (not Calendar events) is the actual quick-add target; verify via a fresh on-device install, not just Debug-build re-runs which may retain a prior grant |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Onboarding carousel appearing on top of / racing with the existing direct-to-Settings first-launch behavior | Confusing double-window flash, or the user never sees the intended onboarding at all | Replace the `isFirstLaunch` branch in `AppDelegate.swift` outright (Pitfall 4) — one first-launch entry point, not two |
| Sidebar Settings redesign losing the license/login-item refocus re-sync per section | User sees a stale trial countdown or login-item toggle until they leave and return to the app | Hoist re-sync to the `NavigationSplitView` container (Pitfall 5) |
| Theming approved only in Xcode preview, never in the real always-unfocused panel | Shipped Material looks flatter/cheaper than what was approved during design review | On-device visual approval is the actual gate, not preview (Pitfall 6) |

## "Looks Done But Isn't" Checklist

- [ ] **Drag-in feature:** Often "looks done" once `draggingEntered` fires once in a spike — verify it *still* fires after every subsequent architectural addition (closures, `draggingEnded`, CGS Space involvement), one variable at a time, not just once at the start.
- [ ] **Window-shell rewrite:** Often "looks done" once ordinary hover/click/expand works — verify fullscreen hide/restore (all 3 trigger methods), multi-Space visibility, and the CR-01 click-through regression class are ALL separately re-checked on-device, not inferred from basic interaction working.
- [ ] **Onboarding carousel:** Often "looks done" once the carousel UI itself renders correctly — verify it actually REPLACES (not races) the existing `isFirstLaunch` → `openSettings()` branch, and that a second launch never re-shows it.
- [ ] **Settings sidebar redesign:** Often "looks done" once the sidebar navigates correctly — verify every `@AppStorage` toggle still round-trips through the SAME `ActivitySettings` key constants, and license/login-item state stays live across section switches without leaving the app.
- [ ] **Calendar write access:** Often "looks done" once a task can be created in Debug — verify on a genuinely fresh install (not a Debug build retaining a prior Calendar grant) that the correct permission (Calendar vs. Reminders) actually prompts at all.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| `draggingEntered` mystery resurfaces on the new architecture | LOW (if the isolated-spike discipline from Pitfall 1 was followed) / HIGH (if not) | Revert to the last confirmed-working minimal method-set, re-add one variable at a time with an on-device check after each, exactly as this pitfall's prevention describes — do not attempt to debug the fully-composed failing state directly, as the original two attempts already tried and failed that way |
| A hover/click/fullscreen regression is found after the rewrite ships | MEDIUM | Re-run the specific Phase 2 (`02-HUMAN-UAT.md`) or Phase 9 fullscreen checklist item that regressed to pin down which exact change broke it, then check it against the CR-01/WR-01 patterns first — most prior regressions in this codebase were exactly these two classes |
| Onboarding permissions screen already shipped and users are hitting permanent denial | MEDIUM | Add an explicit "Grant Access" retry entry point in Settings (doesn't exist today for any permission) — a real product gap this milestone should probably close regardless, given the new onboarding screen makes early denial more likely, not less |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| `draggingEntered` mystery (Pitfall 1) | Window-shell rewrite phase, first sub-task | Isolated-spike, one-variable-at-a-time on-device re-test log, before any drag-in production code |
| Regressing 4 milestones of verified interaction behavior (Pitfall 2) | Window-shell rewrite phase | Full Phase 2 + Phase 9 + CR-01/WR-01 checklist re-run on-device before phase close |
| Dropping/half-copying the CGS Space fullscreen fix (Pitfall 3) | Window-shell rewrite phase | All 3 documented fullscreen trigger methods re-tested on-device; CGS Space teardown-on-quit leak optionally closed in the same pass |
| Onboarding racing the existing first-launch hook (Pitfall 4) | Onboarding-flow phase | Fresh-install test confirms exactly one first-launch UI path fires, never both; second launch never re-shows onboarding |
| Permissions screen front-loading irreversible denials (Pitfall 4) | Onboarding-flow phase | Explicit locked decision (educational vs. real-request) captured in that phase's CONTEXT.md before implementation |
| Settings redesign losing license refocus re-sync (Pitfall 5) | Settings-redesign phase | Manual test: switch sidebar sections without leaving the app, confirm license/login-item state is still live |
| Material theming looking wrong only in the real never-focused panel (Pitfall 6) | Visual/Material redesign phase | On-device visual approval in the real `NotchPanel` runtime, including mid-spring-morph, not Xcode preview |
| CalendarService widening breaking the existing glance / missing Reminders permission (Pitfall 7) | Calendar full-view phase | Existing `expandedIdle` glance re-verified unchanged; fresh-install test confirms the correct (Calendar vs. Reminders) permission prompt actually appears |

## Sources

- `.planning/PROJECT.md` — full Key Decisions table (Phase 1, 2, 9 window/panel decisions; v1.3/v1.4 milestone context)
- `.planning/STATE.md` — Blockers/Concerns (Phase 22 22-03 abort entry, 2026-07-10/11)
- `.planning/phases/22-drag-in/22-RESEARCH.md`, `22-CONTEXT.md`, `22-01-SUMMARY.md`, `22-02-SUMMARY.md`, `22-03-PLAN.md`, `22-DISCUSSION-LOG.md`, `22-PATTERNS.md` — full phase history, including the on-device spike verdicts and the superseded/replanned hot-zone decisions
- Abandoned debugging worktree `/Users/lippi304/conductor/repos/notch/.claude/worktrees/agent-a9e6341bfc04601a5` (branch `worktree-agent-a9e6341bfc04601a5`, commits `326804d`..`d1245e8`) — read directly to diff the confirmed-working spike against the confirmed-failing build
- `Islet/Notch/NotchPanel.swift`, `Islet/Notch/NotchWindowController.swift` (1,378 lines), `Islet/Notch/CGSSpace.swift`, `Islet/Notch/NotchGeometry.swift` — current on-disk source, read in full
- `Islet/Calendar/CalendarService.swift`, `Islet/SettingsView.swift`, `Islet/AppDelegate.swift`, `Islet/Licensing/TrialManager.swift`, `Islet/Licensing/LicenseState.swift` — current on-disk source, read in full/targeted
- `.planning/research/inspiration/notes.md` — Droppy competitor reference (onboarding carousel, permissions pre-explanation, sidebar Settings, Theming section, calendar full view)
- `project.yml` — confirms `NSCalendarsUsageDescription` present, no Reminders usage-description key
- philz.blog, "The Curious Case of NSPanel's Nonactivating Style Mask Flag" (MEDIUM confidence — confirms a real, separate AppKit `NSPanel` state-desync bug class exists in this exact style-mask family, though specific to keyboard focus post-init `setStyleMask:` changes, not directly the drag-delivery mystery; ruled inapplicable here since Islet never changes `styleMask` after init, but corroborates that this panel configuration is a documented source of undocumented AppKit behavior)
- WebSearch: SwiftUI `Material`/`glassEffect` behavior on non-focused/floating `NSPanel` windows (MEDIUM confidence, multiple sources agree Material can degrade when the app is not frontmost)
- WebSearch: EventKit macOS 14+ full-access vs. write-only vs. Reminders-separate-scope permission model, `requestFullAccessToEvents`/`requestWriteOnlyAccessToEvents` (MEDIUM-HIGH confidence, Apple Developer documentation + WWDC23 session corroboration)

---
*Pitfalls research for: Islet v1.4 Architecture Redesign — window/panel rewrite, onboarding, settings redesign, Material theming, calendar view*
*Researched: 2026-07-11*
