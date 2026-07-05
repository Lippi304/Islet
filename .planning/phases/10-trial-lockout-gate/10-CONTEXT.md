# Phase 10: Trial & Lockout Gate - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Islet enforces a real, tamper-resistant 3-day trial with a hard functionality lockout — proven end-to-end using a manually-settable stub license state, with no live Polar.sh network dependency (that's Phase 12). This phase delivers TRIAL-01 (Keychain-backed silent trial start), TRIAL-02 (one-time first-launch notice), and LIC-03 (hard lockout gate wired into the existing single-arbiter `shouldShow(...)`).

Out of scope for this phase: the actual License Settings UI content (days-remaining display, Buy Now button, license-entry field — that's Phase 11, TRIAL-03), and any real Polar.sh network call (Phase 12, LIC-01/LIC-02).

</domain>

<decisions>
## Implementation Decisions

### First-launch trial notice (TRIAL-02)
- **D-01:** No island-native animated card, no native macOS notification (`UNUserNotificationCenter`) for the trial start. The download/marketing page is what tells the user "3-day trial" before they even download — the in-app moment doesn't need to re-sell that.
- **D-02:** TRIAL-02's "one-time explicit notice" is satisfied by the existing Settings window auto-opening exactly once on first launch, showing a short line like "Your 3-day trial started — ends [date]". Reuses the existing window (from v1.0's `SettingsView.swift`) rather than introducing a new alert/notification/island-transient type.
- **D-03:** This auto-open happens on first launch **regardless** of whether the built-in display is currently the notch target (clamshell/external-only at that moment) — Settings is an ordinary window, not tied to island visibility. Do not add an observer/wait for the island to become visible before showing it.

### Locked-state behavior (LIC-03)
- **D-04:** When trial expired / no valid stub license, the island itself is fully hidden (no pill, no activities, no expansion) — per the locked Phase 10 success criteria, this reuses the exact same hide path as the existing clamshell/fullscreen-hide branch in `updateVisibility()` (`panel?.orderOut(nil)`), not a new visual state.
- **D-05:** Clicking the menu-bar status item while locked jumps straight to Settings (skips the normal "Settings…/Quit Islet" dropdown) — there's nothing else useful to do until a key is entered. This is a small, explicit modification to the existing status-item click handler, gated on the same license/trial state Phase 10 introduces.
- **D-06:** The menu-bar icon itself does NOT change appearance (no dimming, no badge) between trial/expired/licensed states. Simplest option — the only signals are: island presence/absence, and what Settings shows when opened.
- **D-07 (user's described end-to-end vision, informs Phase 11 too):** On expiry, opening Settings should show an explicit "3-day trial period expired" message with a link to the website (where the user buys the full version) and a field to paste the license key received from Polar. **Phase 10 itself does not need to build this content** (TRIAL-03/LIC-01/LIC-02 are Phase 11/12) — it only needs to expose the license/trial state (e.g. via the shared `LicenseState`/stub) that Phase 11 will read to render exactly this.

### Debug/testing seam (cross-cutting, TRIAL-01/LIC-03)
- **D-08:** Add a DEBUG-only menu item (or submenu) to force the stub license state — e.g. "Debug: Force Expired" / "Debug: Force Licensed" / "Debug: Reset Trial" — so trial/expired/licensed states can be flipped instantly while running from Xcode. Must not appear/compile into release builds (mirrors the existing `#if DEBUG` discipline already used elsewhere in `NotchWindowController.swift`, e.g. the A1 hover-probe log).
- **D-09:** Explicitly NOT building a shortened DEBUG trial length — the debug menu item is the sole testing seam; no separate fast-countdown mode.

### Storage mechanism (locked by REQUIREMENTS.md — not re-discussed, flagged for planner awareness)
- **D-10:** Trial start date persists to the **Keychain** (`kSecClassGenericPassword`), not UserDefaults — this is locked by TRIAL-01 ("not trivially reset via `defaults delete` or reinstalling") and matches research `PITFALLS.md` Pitfall 1. Note: `.planning/research/ARCHITECTURE.md` Recommendation 4 (line ~171) argues UserDefaults is acceptable for the trial date specifically ("not a secret, low stakes") — that recommendation is **superseded** by the locked TRIAL-01 requirement and PITFALLS.md's explicit guidance. The planner should follow Keychain for the trial-start timestamp, not ARCHITECTURE.md's Recommendation 4 table on this one specific row.
- **D-11:** The `isLicensed` gate is added as a new AND-term inside `NotchWindowController`'s existing `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` predicate in `updateVisibility()` — the single arbiter, no second show/hide site. Matches the already-established Pattern 7 discipline in that file.
- **D-12:** Trial expiry is detected via a single one-shot `DispatchWorkItem` scheduled at the exact computed expiry instant (mirrors the file's existing four one-shot-timer idiom: `dismissWorkItem`, `graceWorkItem`, `mediaDismissWorkItem`, `deviceBatteryWork`) — no polling/recurring timer.
- **D-13:** Lockout enforcement defers to the next natural UI transition, never an abrupt mid-interaction yank — already a locked Phase 10 success criterion (research `PITFALLS.md` Pitfall 5).

### Claude's Discretion
- Exact Keychain item attributes (`kSecAttrAccount` naming, `kSecAttrAccessible` level) — research recommends `kSecAttrAccessibleAfterFirstUnlock`; planner/executor can finalize.
- Exact wording of the first-launch Settings notice text and the DEBUG menu item labels/placement.
- Whether the DEBUG menu items live under the existing status-item menu or a separate DEBUG-only menu — implementation detail.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` §Trial Period (TRIAL) and §Purchase & Licensing (LIC-03) — locked requirement text for TRIAL-01, TRIAL-02, LIC-03
- `.planning/ROADMAP.md` §Phase 10: Trial & Lockout Gate — goal, success criteria, dependency note
- `.planning/PROJECT.md` §Current Milestone: v1.1 Trial & Paid Release, §Key Decisions — trial/licensing scope and the "why bundled with notarization" rationale

### Research (v1.1 milestone)
- `.planning/research/ARCHITECTURE.md` — full recommended file layout (`TrialLogic.swift`, `TrialManager.swift`, `LicenseState.swift`, `LicenseService` protocol), Recommendation 1 (gate lives in `updateVisibility()`), Recommendation 4 (UserDefaults vs Keychain split — see D-10 above for the one superseded row), threading discipline for the future `PolarLicenseService` (Phase 12, not this phase but shapes the protocol shape now)
- `.planning/research/PITFALLS.md` — Pitfall 1 (trial-state storage, Keychain not UserDefaults), Pitfall 5 (abrupt mid-session lockout)
- `.planning/research/SUMMARY.md` — overall milestone synthesis and phase ordering rationale

### Existing code (integration points)
- `Islet/Notch/NotchWindowController.swift` — `updateVisibility()` (~line 421) and `shouldShow(...)` are where the `isLicensed` AND-term is added; `start()` (~line 241) is where the trial-expiry one-shot timer and first-launch Settings auto-open get wired in; existing one-shot `DispatchWorkItem` idiom (`dismissWorkItem`, `graceWorkItem`, etc.) to mirror
- `Islet/AppDelegate.swift` — status-item menu / click handling lives here; where the "jump straight to Settings when locked" behavior (D-05) and the first-launch Settings auto-open (D-02) attach
- `Islet/SettingsView.swift` — existing Settings window to reuse for the first-launch notice; no License section content needed yet (Phase 11)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsView.swift` + existing Settings window plumbing — reused as-is for the first-launch trial notice (D-02); no new window type needed.
- The one-shot `DispatchWorkItem` pattern already used 4× in `NotchWindowController.swift` — the trial-expiry timer follows the identical shape (store as property, cancel in `deinit`, `DispatchQueue.main.asyncAfter`).
- `#if DEBUG` gating already used in `NotchWindowController.swift` (the A1 hover-probe log) — same discipline applies to the new debug menu item (D-08).

### Established Patterns
- Single-arbiter `shouldShow(...)` AND-chain in `updateVisibility()` — the ONE place all show/hide logic converges (Pattern 7, ISL-05). The `isLicensed` term is additive to this, not a new gate elsewhere.
- Protocol-isolation for fragile externals (`NowPlayingService`) — the same shape (`LicenseService` protocol) is planned for Phase 12's Polar.sh integration; Phase 10 only needs a manually-settable stub conforming to whatever shape is chosen, per research `ARCHITECTURE.md`.

### Integration Points
- `NotchWindowController.start()` — trial-expiry timer scheduling + first-launch check.
- `AppDelegate` status-item click handling — locked-state Settings jump (D-05) and first-launch Settings auto-open (D-02).
- `UserDefaults.didChangeNotification` observer already in `NotchWindowController` (`handleSettingsChanged`) — the existing live-update mechanism the license/trial state can piggyback on later (per `ARCHITECTURE.md` Recommendation 3), though Phase 10's stub may not need this yet.

</code_context>

<specifics>
## Specific Ideas

User's own description of the end-to-end vision (verbatim intent, translated): the download/marketing page advertises "3-day trial" with a download button. After downloading, the app works normally through the trial. When the trial runs out, opening the app just shows Settings with a "3-day trial period expired" message, a link to the website (to buy the full version), and a field to paste in the license key obtained from Polar. This phase builds the mechanism (trial start persistence + hard lockout + one-time first-launch Settings notice + DEBUG testing seam); the actual expired-state Settings content described here is Phase 11's job (TRIAL-03) built against this phase's stub license state.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The user's described "expired Settings screen with buy link + license field" is not deferred exactly — it's already correctly scoped to Phase 11 per the existing roadmap, and is noted above as input for that phase.

</deferred>

---

*Phase: 10-Trial & Lockout Gate*
*Context gathered: 2026-07-05*
