# Phase 54: Permissions Overview & Onboarding Replay - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Settings gains a new "Permissions" sidebar section listing the app's 5 user-facing
TCC-gated permissions with a live per-permission status, tappable to grant/re-request
where possible; and a "Replay Onboarding" button in the existing About section that
re-shows the full onboarding carousel as a pure display replay (no persisted-state
change). This phase does not change what any permission is used for — it only adds a
way to review and re-trigger permission grants after first launch, prompted directly by
a real user report: after installing v1.1, the user expected (and could not find) a way
to review already-granted permissions and re-request ones they'd denied.

</domain>

<decisions>
## Implementation Decisions

### Which permissions are shown
- **D-01:** Exactly 5 permissions are listed: Location (WeatherKit), Calendar+Reminders
  (as ONE combined row, even though they are 2 separate TCC entries under the hood),
  Bluetooth, Focus, and Input Monitoring.
- **D-02:** Automation/Apple Events is explicitly EXCLUDED from this rollup — it backs
  the paused/never-shipped Favorite/Like feature (Phase 49/50 aborted after weak spike
  results). Showing a permission for a feature that doesn't visibly exist yet would
  confuse users. Revisit if/when Phase 50 is picked back up.
- **D-03:** Input Monitoring IS included despite having no official "is granted" read
  API on macOS — use a best-effort check (research during planning should confirm the
  most reliable available technique, e.g. `IOHIDCheckAccess` or an equivalent
  undocumented-but-commonly-used check). Best-effort status beats omitting it entirely.

### Status model
- **D-04:** Each permission shows a 3-state status, not just binary: **granted** /
  **denied** (actively refused) / **not yet asked** (never prompted). This distinction
  drives D-05/D-06's different tap behaviors below — collapsing to 2 states would lose
  the information needed to know whether a native re-prompt is even possible.

### Tap-to-act behavior (per status)
- **D-05:** Tapping a permission in **denied** state deep-links directly to that
  permission's specific System Settings > Privacy & Security pane (e.g. via
  `x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices`-
  style URLs) — macOS does not allow an app to re-trigger its own native permission
  dialog once a user has actively denied it, so System Settings is the only real path.
  Research during planning should confirm the exact deep-link URL scheme constant for
  each of the 5 permissions (some, like Input Monitoring, may need
  `Privacy_ListenEvent` or similar — verify per-permission, don't assume one pattern
  fits all).
- **D-06:** Tapping a permission in **not yet asked** state triggers the normal native
  system permission dialog directly (calls the same `requestAuthorization`/
  `requestAccess`-style API each underlying service already uses) — no need to route
  through System Settings when a live prompt is actually available.
- Tapping a permission already **granted** has no action (or, at Claude's discretion,
  could simply do nothing / show a checkmark with no tap target).

### Replay Onboarding
- **D-07:** The button re-shows Phase 26's full existing onboarding carousel (Welcome →
  Trial/License/Buy → Permissions → Done) via `OnboardingFlow`/`OnboardingViewState` —
  not a new "permissions-only" partial mode. Reuses what already exists; no new
  onboarding-subset UI needed.
- **D-08:** Replaying is a PURE DISPLAY ACTION — it does NOT reset
  `hasCompletedOnboarding`/`isFirstLaunch` or any other persisted onboarding-related
  flag. If the user backs out mid-replay, the app must be left in exactly the same
  state as before the replay started (no half-onboarded state, no altered trial/license
  gating behavior).
- **D-09:** The "Replay Onboarding" button stays in the existing **About** section
  (matches ARCH-P2's original scoping exactly) — NOT moved into the new Permissions
  section, even though the permissions step is the part most likely to be replayed.

### Placement & presentation
- **D-10:** New dedicated top-level Settings sidebar section named "Permissions",
  alongside the existing 7 sections from Phase 51 (Activities/Appearance/Fullscreen/
  Weather/Diagnostics/Workspace/About) — not folded into an existing section.
- **D-11:** Each of the 5 permissions renders as its own row: name/icon on the left,
  a status indicator on the right (e.g. green check / red X / grey "?", exact glyphs at
  Claude's discretion), the whole row tappable per D-05/D-06. Not a single collapsed
  "X of Y granted" summary line with a drill-down — the per-row list is always visible.
- A top-of-section "X of Y granted" summary row is still expected (matches ARCH-P2's
  literal wording) — it just sits ABOVE the always-visible per-row list, not as a
  collapsed/expandable gate to it.

### Claude's Discretion
- Exact SF Symbol/glyph choices for the 3 status states.
- Whether a granted-permission row is tappable at all (no-op) or fully inert.
- Exact deep-link URL constants per permission (research at planning time — do not
  guess/hardcode without verifying against current macOS System Settings anchor names).
- Best-effort Input Monitoring status-check technique (document the chosen approach's
  known limitations, since no official API exists).

### Reviewed Todos (not folded)
- `2026-07-19-calendar-month-grid-polish.md` — Calendar grid UI polish, unrelated to
  permissions; stays deferred for its own future phase.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — click-through
  flicker bug, unrelated; stays deferred.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — Quick Action
  picker gating gap, unrelated; stays deferred.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement definition
- `.planning/REQUIREMENTS.md` (v2 Requirements → "Architecture Redesign Polish (carried
  from v1.4)" section) — ARCH-P2's original one-line scope: *"Permissions Overview — X
  of Y granted" rollup row in Settings + a "Replay onboarding" button in About*.
- `.planning/PROJECT.md` (Next Milestone Goals, Key Decisions) — confirms ARCH-P2 was a
  standing backlog candidate, never previously scoped into an active phase.

### Prior phase precedent this phase builds on
- `.planning/phases/51-settings-reorganization-scroll-fix/` (Phase 51 — the 7-section
  Settings sidebar this phase adds an 8th section to) — read `51-01-SUMMARY.md` for the
  exact `SidebarSection` pattern to extend.
- `.planning/phases/26-onboarding-flow/` (Phase 26 — the existing onboarding carousel
  this phase replays verbatim) — read its SUMMARY.md(s) for `OnboardingFlow`/
  `OnboardingViewState`'s current shape.
- `.planning/phases/38-focus-mode-hud/` (Phase 38 — `INFocusStatusCenter` authorization
  pattern, the one permission here with a live re-request API already implemented once).

### Existing code (unmodified architecture this phase extends)
- `Islet/SettingsView.swift` — existing ad-hoc permission popovers to mirror/generalize:
  `showFocusPermissionExplanation` (~line 42/423), `showOSDPermissionExplanation`
  (~line 51/459); `weatherSection` (~line 390) is a display-only picker, not a
  permission control, and is NOT the thing this phase modifies.
- `Islet/Location/LocationProvider.swift` — `CLLocationManager`/`authorizationStatus`
  (line 28), the Location status source.
- `Islet/Calendar/CalendarService.swift` — wraps `EKEventStore` (line 50), the
  Calendar+Reminders status source.
- `Islet/Notch/FocusModeMonitor.swift` — `INFocusStatusCenter.default.authorizationStatus`
  (line 60/70) and `.requestAuthorization` (line 78) — the one permission with an
  already-proven live re-request call to mirror for D-06.
- Bluetooth: `BluetoothMonitor` (project-wide search needed at planning time — no
  explicit `authorizationStatus` check was found during discussion's codebase scout;
  research must confirm how/whether Bluetooth authorization is currently readable at
  all, or whether IOBluetooth requires a different detection approach).
- `project.yml` (INFOPLIST_KEY_NS*UsageDescription block, ~lines 96-119) — the 6 actual
  Info.plist usage-description keys currently configured (Bluetooth, Location, Calendar,
  Calendar-Full-Access, Reminders, Reminders-Full-Access, Input Monitoring, Focus
  Status, Apple Events) — confirms exactly which permissions genuinely exist to surface.
- `Islet/Islet.entitlements` — the corresponding entitlements; note
  `com.apple.security.automation.apple-events` exists here (D-02 explicitly excludes
  surfacing it in this phase's rollup regardless).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 51's `SidebarSection` enum/switch pattern (`Islet/SettingsView.swift`) — the
  exact shape a new "Permissions" case should follow.
- `FocusModeMonitor`'s `requestAuthorization` call — the one existing precedent for a
  live in-app permission re-request (D-06).
- Phase 26's `OnboardingFlow`/`OnboardingViewState` — reused verbatim for Replay
  Onboarding (D-07), no new onboarding code needed.

### Established Patterns
- Ad-hoc permission-explanation popovers already exist for Focus and OSD
  (`show*PermissionExplanation` bools in `SettingsView.swift`) — this phase generalizes
  that shape into a structured list rather than one-off booleans per permission.

### Integration Points
- New Settings sidebar section reads live authorization status from each of:
  `CLLocationManager`, `EKEventStore`, Bluetooth's current detection mechanism (TBD at
  planning), `INFocusStatusCenter`, and a best-effort Input Monitoring check — none of
  these require new monitor classes, just read-only status queries from existing
  service wrappers already used elsewhere in the app.

</code_context>

<specifics>
## Specific Ideas

User's own words prompting this phase: after downloading and installing v1.1, expected
to be able to "nochmal alle [Berechtigungen] sieht die man gegeben hat und die man noch
geben kann die man erst denied hat" (see all permissions already granted, and be able to
grant ones previously denied) — directly maps to D-04's 3-state model and D-05/D-06's
tap-to-act behavior.

</specifics>

<deferred>
## Deferred Ideas

None beyond the 3 reviewed-but-not-folded todos listed above under Decisions.

</deferred>

---

*Phase: 54-permissions-overview-onboarding-replay*
*Context gathered: 2026-07-21*
