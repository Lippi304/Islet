# Phase 11: License Settings UI (Stubbed License Service) - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Islet gains a **License section in the Settings window** that lets the user see their trial/license status and initiate purchase or key entry — exercising the full UI state machine (idle → validating → success/failure) against a **fake in-memory `LicenseService`**, before any live Polar.sh network call exists (that's Phase 12).

This phase delivers **TRIAL-03** (days-remaining visible from Settings) and builds the *placeholder* forms of the Buy-Now and license-entry flows that Phase 12 (LIC-01/LIC-02) will wire to real Polar.sh endpoints.

**Out of scope for this phase:**
- Any real Polar.sh network call, live checkout URL, or online key validation (Phase 12, LIC-01/LIC-02).
- Persisting an activated license across app restarts / offline Keychain cache of a validated license (Phase 12 — the stub activation is in-memory for the session only).
- Real Developer-ID notarization/release (Phase 13, DIST-01).
- The trial-start persistence, first-launch notice, and hard-lockout gate — already delivered in Phase 10 (TRIAL-01/TRIAL-02/LIC-03). This phase only *renders* the state Phase 10 computes.

</domain>

<decisions>
## Implementation Decisions

### License section layout & placement
- **D-01:** **One adaptive `License` section**, not always-visible controls. A single section whose content swaps by `LicenseState.status`:
  - `.trial(daysRemaining:)` → days-remaining line + Buy Now button + license key field/Activate.
  - `.trialExpired` → "3-day trial period expired" message (prominent — Settings is the only visible surface when locked, per Phase 10 D-04) + Buy Now button + license key field/Activate.
  - `.licensed` → "Licensed ✓" confirmation; Buy Now and key field are **hidden** (nothing to buy/enter).
- **D-02:** The License section sits at the **top of the Settings `Form`**, above "Launch Islet at login" / Activities / Accent. Rationale: it's the most important state, and when Settings auto-opens on first launch or when locked (Phase 10 D-05), the license state is the first thing seen.

### Days-remaining display (TRIAL-03)
- **D-03:** During an active trial, show a **countdown only**: e.g. *"2 days left in your trial."* Driven by `LicenseState.status` → `.trial(daysRemaining:)` (already rounds up and clamps to a minimum of 1 via `TrialLogic.trialStatus`). This *replaces* the current end-date-only line (*"Your 3-day trial started — ends …"*) — the countdown satisfies success criterion #1 literally.

### Activate flow + fake validation (state machine)
- **D-04:** Feedback is an **inline status line below the field**: idle (no line) → `⟳ Validating…` → green `✓ License activated` or red `✗ That key wasn't recognized.` The Activate button is **disabled while validating**.
- **D-05:** The fake stub uses a **magic key** rule: a known test key (e.g. `ISLET-DEMO-OK`) validates successfully; every other non-empty input fails. This lets the user deterministically exercise BOTH the success and failure branches on-device (empty input should not trigger a network-ish attempt). The magic key is a stub/DEBUG-documented detail, not a shipped credential.
- **D-06:** The fake "validating" state lasts **~1 second** (simulated round-trip) so the transition is visibly observable — success criterion #3 requires the idle→validating→success/failure transitions to be *observed*, not instant.

### Buy Now button (LIC-01 placeholder)
- **D-07:** Buy Now opens a **placeholder marketing URL — `https://getislet.app`** — in the default browser (real Polar.sh checkout URL lands in Phase 12). Button label: **"Buy Islet — €7.99"** (reads real even as a placeholder; the €7.99 one-time price is locked in REQUIREMENTS.md). Per D-01 the button is hidden in the `.licensed` state.

### Claude's Discretion
- **Successful stub activation flips license state to entitled for the session.** On a successful (magic-key) validation, the stub flips the app to a licensed/entitled state **in-memory for the current session** (persistence across restarts is explicitly Phase 12) and reuses **Phase 10's live-unlock path** so a locked island reappears at the next natural UI transition without an app restart (Phase 10 success criterion #5, Pitfall 5 — no abrupt mid-interaction yank). Whether this is modeled by extending `LicenseState` or by the new `LicenseService` stub feeding into it is a planner/researcher call — but the observable behavior (activate → island unlocks live) is locked.
- **`LicenseService` protocol shape.** This phase introduces the fake stub `LicenseService` the roadmap names. Its exact protocol surface (async validate(key:) returning a result, error taxonomy for the failure line, threading) is left to research/planning — it must be shaped so Phase 12's real `PolarLicenseService` is a drop-in swap (mirrors the `NowPlayingService` protocol-isolation pattern). See `.planning/research/ARCHITECTURE.md`.
- Exact copy/wording, spacing, spinner styling, and SwiftUI control choices within the inline-status pattern (D-04) are Claude's to refine — the UI-phase / planner may produce a UI-SPEC.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` §Trial Period (TRIAL-03) and §Purchase & Licensing (LIC-01, LIC-02, LIC-03) — locked requirement text; note the €7.99 one-time price and the "no embedded org token / no in-app checkout" out-of-scope rows that constrain Buy Now.
- `.planning/ROADMAP.md` §Phase 11: License Settings UI (Stubbed License Service) — goal, the four success criteria, dependency on Phase 10; also §Phase 12 to keep the stub a drop-in swap.
- `.planning/PROJECT.md` §Current Milestone: v1.1 Trial & Paid Release — scope/price rationale.

### Prior-phase decisions this phase renders
- `.planning/phases/10-trial-lockout-gate/10-CONTEXT.md` — D-04 (locked island fully hidden), D-05 (menu-bar click while locked jumps to Settings — this is how success criterion #4 "Settings one click away" is already satisfied), D-07 (the expired-Settings vision this phase builds), and the `LicenseState` stub shape.

### Research (v1.1 milestone)
- `.planning/research/ARCHITECTURE.md` — recommended file layout and the `LicenseService` protocol shape; threading discipline for the future `PolarLicenseService` (shapes the stub protocol now).
- `.planning/research/PITFALLS.md` — Pitfall 4 (DEBUG override gating discipline, mirrored by any test seam), Pitfall 5 (no abrupt mid-session unlock/lockout).

### Existing code (integration points)
- `Islet/SettingsView.swift` — the `Form` to extend; currently renders the trial notice line to be replaced by the adaptive License section.
- `Islet/Licensing/LicenseState.swift` — `LicenseStatus` enum (`.trial(daysRemaining:)`, `.trialExpired`, `.licensed`), `isEntitled`, `trialExpiryDate`, DEBUG override seam.
- `Islet/Licensing/TrialLogic.swift` / `Islet/Licensing/TrialManager.swift` — `daysRemaining` computation and cached trial-start read (the source of the countdown).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LicenseState.shared`** already exposes exactly the three states the adaptive section switches on, plus `isEntitled` and `trialExpiryDate` — the section reads it directly; no new state model needed for display.
- **`SettingsView` `Form`** (width 360, `.padding(20)`) — the License section slots in at the top of the existing Form; follows the established `Section(...)` / `LabeledContent` idiom already used for Activities and Version.
- **`appearsActive` re-sync pattern** in `SettingsView` — the same refocus-driven re-read can keep the days-remaining countdown and license state fresh while the window is open.

### Established Patterns
- **Single-arbiter `updateVisibility()` unlock path** (Phase 10) — a successful activation must funnel through the same live show/hide path, not a new one, so the island reappears smoothly.
- **Protocol-isolation for fragile externals** (`NowPlayingService`) — the fake `LicenseService` should adopt the same shape so Phase 12's real implementation is a one-file swap.
- **DEBUG-gated test seams** (`LicenseState` DEBUG override, Pitfall 4) — any developer affordance for the stub (e.g. documenting the magic key) stays compiled out of Release.

### Integration Points
- New License section in `SettingsView.swift` reads `LicenseState` (display) and drives the new `LicenseService` stub (Activate).
- Successful activation → flips entitled state → triggers `NotchWindowController.updateVisibility()` (Phase 10's arbiter) to live-unlock the island.
- Buy Now → `NSWorkspace.open(placeholderURL)` in the default browser.

</code_context>

<specifics>
## Specific Ideas

- Expired-state Settings must read as the primary call-to-action, not a footnote — when the trial is over the island is fully hidden (Phase 10 D-04), so this section is the *only* thing the user sees. It carries the "3-day trial period expired" message + Buy Now + key field (user's verbatim D-07 vision).
- Activate feedback copy direction: neutral success (*"License activated"*), plain failure (*"That key wasn't recognized."*) — no scary error dialogs.
- Magic test key `ISLET-DEMO-OK` is a naming suggestion for the stub's valid input; the planner may choose the exact literal.

</specifics>

<deferred>
## Deferred Ideas

- **Persisting an activated license across restarts / offline Keychain cache** — belongs to Phase 12 (LIC-02). This phase's stub activation is in-memory for the session.
- **Real Polar.sh checkout URL and online validation** — Phase 12 (LIC-01/LIC-02).
- **Deep-link auto-fill of the license key (`islet://license?...`)** — explicitly v2 (LIC-04), out of scope.
- **Last-day nudge notification before lockout** — v2 (TRIAL-04), out of scope.

</deferred>

---

*Phase: 11-license-settings-ui-stubbed-license-service*
*Context gathered: 2026-07-05*
