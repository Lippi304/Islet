# Phase 26: Onboarding Flow - Context

**Gathered:** 2026-07-11
**Status:** Ready for planning

<domain>
## Phase Boundary

First-time users see a proper first-launch carousel — Welcome → Trial/License-Key/Buy choice → Permissions pre-explanation → Done — replacing today's passive `isFirstLaunch` → `openSettings()` branch in `AppDelegate.swift`. Visual/informational steps render inside the real expanded notch panel (matching the Droppy reference's "onboarding lives in the expanded island" pattern); any step needing actual keyboard focus or a real system permission grant hands off to the existing focusable Settings window. The flow is a forced single pass — once started it always reaches its own Done screen, no early-exit escape hatch — and shows exactly once via a persisted flag.

Out of scope for this phase: any gesture/feature tutorial screen (explicitly rejected, matches Droppy image 3 rejection), Settings' own sidebar redesign (Phase 27), calendar full view (Phase 28), any new permission beyond Bluetooth/Calendar/Location (Input Monitoring for drag-in is Phase 24's own lazy-ask, unrelated to this flow).

</domain>

<decisions>
## Implementation Decisions

### Permission-request sequencing
- **D-01:** Today, `NotchWindowController.start()` calls `startBluetoothMonitor()` (gated by the Device activity toggle) and unconditionally calls `startOutfitRefresh()` (Location + Calendar) immediately at launch — both fire real system permission prompts silently, before any onboarding UI exists. On a genuinely fresh install, Phase 26 must gate these calls so they don't fire until the onboarding permissions step is reached. On every later launch (onboarding already completed), behavior stays exactly as today — eager, no gating.
- **D-02:** The permissions step has one row per permission (Bluetooth, Calendar, Location/Weather), each with its own independent Continue/Grant button that fires that one system prompt — not a single "Continue" that fires all three back-to-back. User-paced, matches the Droppy reference screenshot.
- **D-03:** If a permission is denied or skipped, its row shows a quiet "not granted" state and the flow continues regardless — no error dialog, no blocking. Matches the codebase's existing silent-degrade convention (`LocationProvider` D-01, Phase 24 D-07/D-12). No re-ask/nudge affordance inside onboarding itself — a denied/skipped permission is activated later via Settings (see D-07).

### Trial/license/buy screen semantics
- **D-04:** `TrialManager.recordFirstLaunchIfNeeded()` already silently starts the 3-day trial before any onboarding UI renders. The 2nd onboarding screen (between Welcome and Permissions) is purely informational about that already-running trial ("Your 3-day trial has started") plus two real alternates: "Enter License Key" and "Buy Now". There is no active trial-vs-buy choice upfront — changing `TrialManager`'s auto-start timing is out of this phase's scope.
- **D-05:** The license-key entry and Buy Now flow reuse the existing `LicenseState`/Settings UI (key-entry field with idle/validating/success/failure states, live Polar.sh checkout) rather than a new onboarding-only view — zero new validation logic.

### Onboarding host & post-flow routing
- **D-06 (LOCKED):** Visual/informational steps (Welcome/hero, permission one-line explanations) render **inside the real expanded notch panel** — not a separate window, not embedded in Settings — matching Droppy's reference (onboarding carousel lives in the expanded island with Next/Back navigation at the bottom corners).
- **D-07 (LOCKED):** `NotchPanel.canBecomeKey`/`canBecomeMain` are hard-locked `false` (a load-bearing focus-safety invariant preserved through Phases 1, 2, and 23) — the real notch panel structurally cannot accept keyboard focus, so it can never host a working text field. Any onboarding step that needs actual typed input (license-key entry) or an actual system-permission grant that requires the user to flip a toggle in System Settings opens the **existing focusable Settings window**, scrolled/navigated to the right section, then flow returns to the notch. This is the same pattern for both the license-key step and any permission the user chose to skip during onboarding and later wants to grant — both route through Settings.
- **D-08:** After onboarding reaches Done (or a step within it is skipped through to Done), the flow closes straight to menu-bar idle — no auto-open of Settings afterward. The notch island is already live in the background per D-01's gating.
- **D-09 (LOCKED):** "Skippable/dismissible" (ONBOARD-03) means **per-step** skip only:
  1. Welcome/hero screen — nothing to decide, just Next (inherently "skippable" in that there's no real choice to make).
  2. Trial/License/Buy screen — informational per D-04, with real Enter-Key/Buy-Now alternates; not entering a key or buying just means "stay on trial," which is itself a valid path forward (no explicit skip button needed beyond just tapping Next).
  3. Permissions screen — each row can be individually skipped (no Grant tap) per D-02/D-03, activated later via Settings per D-07.
  There is **no early-exit/close affordance** for the flow as a whole — once started, it always reaches its own Done screen before the island returns to normal idle behavior. Exact flow order, confirmed: **Welcome → Trial/License/Buy choice → Permissions → Done** (matches ROADMAP's stated order exactly).

### Inline Launch-at-Login toggle (beyond the 3 locked requirements)
- **D-10:** The Done screen includes one additional inline toggle: Launch at Login, defaulting to its current live `SMAppService.mainApp` state (mirrors Settings' existing toggle exactly, same underlying state — not a separate/duplicate flag). Mirrors Droppy's 4th onboarding screen (opt-in toggles). Explicitly requested by the user beyond ONBOARD-01/02/03's literal wording — small, scoped addition, not a new capability.

### Claude's Discretion
- Exact visual treatment of the notch-hosted onboarding steps (how Welcome/permissions content lays out inside the expanded island shape, Next/Back button placement/styling) — informed by Droppy's reference screenshots described in `.planning/research/inspiration/notes.md`, exact SwiftUI layout is research/planner judgment.
- Exact mechanism for routing from the notch-hosted flow to the Settings window and back (e.g., how the flow "remembers" to resume/complete after a Settings round-trip for license entry or a skipped permission) — not discussed with the user, needs research/planning to resolve against the existing `NotificationCenter`-based `openIsletSettings` bridge already used by `AppDelegate.openSettings()`.
- Exact persisted-flag mechanism and key name for "onboarding shown once" (likely `@AppStorage`/`UserDefaults`, mirroring `TrialManager`'s Keychain-backed pattern only if tamper-resistance actually matters here — probably does not, since onboarding isn't a security gate).
- Whether/how a permission skipped during onboarding and later granted via Settings gets reflected back into any onboarding-adjacent UI state (likely nothing needed — Settings' existing permission-status display, if any, already reflects live system state).
- Exact Info.plist/system-prompt wording is already locked via existing `project.yml` usage-description keys (Bluetooth, Location, Calendar) — no new keys needed for this phase's 3 permissions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` §Onboarding — ONBOARD-01 (carousel replacing passive Settings-only flow), ONBOARD-02 (permissions pre-explanation, one-line reason + real system prompt per permission, in sequence), ONBOARD-03 (shows once, skippable/dismissible, no gesture tutorial)
- `.planning/ROADMAP.md` §"Phase 26: Onboarding Flow" — Goal, Depends on (none), 4 Success Criteria, explicit flow order (hero → trial/license-key/buy choice → permissions pre-explanation → done)

### Design reference (Droppy competitor app)
- `.planning/research/inspiration/notes.md` §"Onboarding flow (images 1-4)" — the direct visual/behavioral reference: image 1 (hero screen), image 2 (permissions pre-explanation, one-line reason before system prompt — the exact pattern D-02 implements), image 3 (gesture tutorial — explicitly rejected, do not build), image 4 (opt-in toggles incl. Launch at Login — the direct precedent for D-10). User's live description in this discussion (not separately saved as files) adds that Droppy's carousel renders inside the expanded island itself with Next/Back at the bottom corners — the source of D-06.

### Existing code this phase replaces/modifies
- `Islet/AppDelegate.swift` `applicationDidFinishLaunching` — the `isFirstLaunch` branch (lines 77-89) currently auto-opens Settings; this phase replaces that branch with routing into the new notch-hosted onboarding flow instead. `TrialManager.shared.recordFirstLaunchIfNeeded()` (line 29) stays untouched — its silent trial-auto-start timing is explicitly preserved per D-04.
- `Islet/Notch/NotchWindowController.swift` `start()` (~line 315) — where `startBluetoothMonitor()` (line 477, ~line 392 call site, gated by `activityEnabled(ActivitySettings.deviceKey)`) and `startOutfitRefresh()` (line 492, unconditional, calls `locationProvider.requestOnce` + `refreshCalendar()`) are invoked; D-01 requires gating these on first-launch-not-yet-onboarded state.
- `Islet/Location/LocationProvider.swift` `requestOnce()` — the existing D-01 (its own, unrelated numbering) silent-degrade completion pattern this phase's D-03 explicitly mirrors.
- `Islet/Notch/NotchPanel.swift` lines 35-36 (`canBecomeKey`/`canBecomeMain` both `false`) — the hard constraint behind D-06/D-07's split-hosting decision.
- Settings license UI (Phase 11/12, `LicenseState`, the key-entry field with idle/validating/success/failure states, Buy Now → Polar.sh checkout) — reused as-is per D-05, exact file(s) to be located by research (not read in this discussion).
- `project.yml` — `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`, `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`, `INFOPLIST_KEY_NSCalendarsUsageDescription`/`NSCalendarsFullAccessUsageDescription` — already present, no new Info.plist keys needed for this phase's 3 permissions (Input Monitoring's key is Phase 24's, unrelated).
- Settings' existing Launch-at-Login toggle (`SMAppService.mainApp`, Phase 0/APP-01) — the toggle D-10's inline onboarding copy mirrors; exact file to be located by research.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchPillView.swift` / `NotchShape.swift` — the shared shape/material every collapsed/expanded/wings/toast state already renders through via `matchedGeometryEffect`. The notch-hosted onboarding steps (D-06) are a new presentation state riding the same shape identity, not a new window/shape mechanism.
- Existing Settings license UI (Phase 11/12) — directly reused per D-05, no new validation/checkout logic.
- `NotificationCenter`-based `.openIsletSettings` bridge (`AppDelegate.openSettings()`) — the likely mechanism for the notch→Settings handoff (D-07), already proven for the menu-bar → Settings path.
- `activityEnabled(ActivitySettings.deviceKey)` gating pattern already used for `startBluetoothMonitor()` — the natural place to add the first-launch-not-yet-onboarded gate (D-01) without disturbing later-launch behavior.

### Established Patterns
- **Single arbiter, no parallel state machine** (`syncClickThrough()` in `NotchWindowController`) — any new onboarding-active state must route through this existing single decision point, not a parallel flag (same architecture-risk note carried forward from Phase 22/24's drag-state discussions).
- **Silent no-op / silent degrade for edge cases** — established across Phase 19/20/21/24 and `LocationProvider` D-01; this phase's D-03 (permission denial) and general "no error dialogs" framing follow the same convention.
- **`@AppStorage`-persisted one-time flags** — mirrors how activity toggles and other Settings state already persist; the "onboarding shown once" flag likely follows this existing idiom (Claude's Discretion, see above).

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` — the sole call site being restructured (replacing the `isFirstLaunch` → `openSettings()` branch).
- `NotchWindowController.start()` — the gating point for D-01's deferred permission-triggering calls.
- The existing Settings window/scene — the hand-off target for license entry and permission re-grant (D-07), not a new window.

</code_context>

<specifics>
## Specific Ideas

- Droppy's onboarding renders inside the expanded notch/island itself (not a floating separate app window) — Welcome screen with Next button, back-and-forth navigation via bottom-corner Next/Back buttons, permissions explanations shown directly in that same expanded-island context. This is the direct visual/architectural reference for D-06.
- Droppy's exact 4-step order (hero → permissions pre-explanation → gesture tutorial [rejected] → opt-in toggles) maps to Islet's confirmed order: Welcome → Trial/License/Buy choice → Permissions → Done (with Launch-at-Login folded into Done per D-10), skipping Droppy's gesture-tutorial step entirely.

</specifics>

<deferred>
## Deferred Ideas

None beyond what's already captured as Claude's Discretion above — discussion stayed within phase scope. (Gesture/feature tutorial screens remain explicitly out of scope project-wide, not just this phase — see PROJECT.md Out of Scope.)

</deferred>

---

*Phase: 26-Onboarding-Flow*
*Context gathered: 2026-07-11*
