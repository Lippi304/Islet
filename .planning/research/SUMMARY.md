# Project Research Summary

**Project:** Islet — v1.1 "Trial & Paid Release" milestone
**Domain:** Trial-period + one-time-purchase licensing (Polar.sh) + real Developer-ID notarization, bolted onto an already-shipped native macOS notch/Dynamic-Island utility
**Researched:** 2026-07-05
**Confidence:** MEDIUM-HIGH

## Executive Summary

This milestone adds monetization to an already-working app, not a new product. Islet ships a 3-day silent trial, a €7.99 one-time purchase via Polar.sh, Keychain-cached license validation, a hard functionality lockout on trial expiry, and real Developer-ID notarized distribution (replacing the existing dry-run release pipeline). The domain is well-trodden: comparable indie Mac utilities (BetterDisplay, Rectangle Pro, CleanShot X) all use the same shape — silent trial start, Settings-pane license entry, browser-handoff checkout, Paddle/Polar-style validation. Islet's own codebase already contains the two architectural precedents this milestone needs to reuse rather than reinvent: a protocol-isolation pattern for fragile external dependencies (`NowPlayingService`) and a single-arbiter visibility function (`updateVisibility()`) that all new gating logic must compose into as one more AND term, not a second show/hide call site.

The recommended approach: build trial-state persistence and the lockout gate first, entirely stubbed (no network), because that touches the most sensitive existing file (`NotchWindowController`); wire the Settings license-entry UI against a fake `LicenseService` second; swap in the real `PolarLicenseService` (URLSession + Keychain) third; and treat real notarization as a fourth, functionally-independent track that only needs two shell-script variables filled in. Trial/license state must live in the Keychain (not UserDefaults/plist), because UserDefaults is trivially reset via `defaults delete` — the single most common mistake in indie macOS trial implementations — while Keychain items on a non-sandboxed macOS app survive app deletion and reinstall for free. Polar.sh's customer-portal `/activate` and `/validate` endpoints are explicitly designed to be called unauthenticated from a native client using the license key itself as the credential; the one hard rule is never to embed Polar's secret organization API token in the shipped binary, and to always use dashboard-generated Checkout Links (not the authenticated Checkout Sessions API) for the buy flow.

The three biggest risks, in order of consequence: (1) a naive license-validate call that hard-fails on transient network errors at the exact moment a paying customer just completed checkout — this must distinguish "invalid key" from "couldn't reach the server" and retry/support-path accordingly; (2) real Developer-ID notarization failing because the vendored `MediaRemoteAdapter.framework` isn't set to "Embed & Sign" or hardened-runtime entitlements are wrong — mitigated by local `codesign --verify --deep --strict` and `spctl --assess` pre-flight before ever calling `notarytool submit`; and (3) a mid-session abrupt lockout (trial expires or re-check flips state while the island is expanded/mid-interaction) feeling hostile in an app whose whole value proposition is polish — mitigated by deferring enforcement application to the next natural UI transition point rather than yanking state synchronously.

## Key Findings

### Recommended Stack

No new frameworks or SDKs are needed beyond what Apple already ships. All HTTP calls to Polar.sh go through plain `URLSession` + `async/await` + `Codable` (Polar has no official Swift SDK — confirmed by search; only JS/PHP SDKs exist, and adding a networking dependency like Alamofire for ~2 API calls total is unjustified). Trial-start date and validated license state are cached in the Keychain (`Security` framework, `kSecClassGenericPassword`), which needs zero new entitlements since the app is already intentionally non-sandboxed for the MediaRemote/perl bridge. Real notarization reuses the already-wired `xcrun notarytool`/`stapler` pipeline from the dry-run phase — the only change is real Developer-ID credentials (an App Store Connect API key is the recommended auth method, stored once via `notarytool store-credentials` into the login keychain, never in the repo).

**Core technologies:**
- **URLSession + Codable (async/await)**: all Polar.sh REST calls — no SDK exists, dependency-free and sufficient for the tiny call volume
- **Security framework (Keychain Services)**: trial-start date + license state persistence — survives reinstall, no sandbox entitlement needed
- **`xcrun notarytool` / `stapler`**: already the correct tool (not deprecated `altool`); this milestone only supplies real credentials, not new tooling

### Expected Features

**Must have (table stakes / P1):**
- Silent trial-start timestamp persisted on first launch, with an explicit one-time "your 3-day trial has started" welcome moment (near-mandatory given the hard-lockout decision, since Islet has no main window and a user could otherwise never see a warning before lockout)
- Days-remaining indicator + "Buy Now" button + manual license-key entry field, all in the existing Settings window
- License key validation against Polar's `/validate` (and `/activate` if using activation limits)
- Hard lockout when trial is expired and no valid license is present — the app's explicit product decision, stricter than every comparable app found (BetterDisplay/Rectangle Pro/CleanShot X all use soft locks or undocumented behavior)

**Should have (differentiators, v1.x fast-follow):**
- Deep-link auto-fill of the license key after checkout (`islet://license?checkout_id=...`) — a documented Polar mechanism, removes manual copy-paste, but must degrade gracefully to manual paste
- Last-day nudge notification before lockout — mitigates hard-lockout backlash

**Defer (v2+):**
- Activation-limit / multi-device management UI (Polar supports it natively, add only if key-sharing becomes an observed problem)
- Periodic "phone home" re-validation purely for refund/chargeback detection (must fail open if attempted; not needed for a one-time purchase model)
- Subscription billing, in-app/embedded checkout, hardware fingerprinting, custom account system — all explicitly out of scope and would contradict the chosen one-time-purchase, account-less model

### Architecture Approach

Islet already has the two precedents this milestone must reuse: protocol-isolation for fragile externals (mirror `NowPlayingService` → new `LicenseService` protocol + `PolarLicenseService` conformer) and single-arbiter visibility (`updateVisibility()`'s `shouldShow(...)` AND-chain gains one more term, `isLicensed`, rather than a second hide/show call site anywhere else). A new `Islet/Licensing/` group mirrors the existing pure-seam/thin-glue split: `TrialLogic.swift` (pure, unit-tested), `TrialManager.swift` (UserDefaults/Keychain glue + one-shot expiry `DispatchWorkItem`, no polling), `LicenseState.swift` (plain `@Published` holder), `LicenseService` protocol, `PolarLicenseService.swift` (the one file that talks to `api.polar.sh` and Keychain). `NotchWindowController` and `SettingsView` stay in sync via the existing `UserDefaults.didChangeNotification`/`defaultsObserver` mechanism already used for `ActivitySettings` — no new shared-object DI style needed. Trial-start date lives in UserDefaults (low-stakes if tampered); the actual license key, `activation_id`, and last-validated timestamp live in Keychain (tamper-sensitive, survives reinstall).

**Major components:**
1. `TrialLogic` / `TrialManager` — pure trial-status classification + UserDefaults timestamp glue + one-shot expiry timer (no recurring polling, matching the codebase's existing idle-CPU discipline)
2. `LicenseState` / `LicenseService` protocol / `PolarLicenseService` — plain published state holder + protocol-isolated Polar.sh HTTP client and Keychain read/write, with an explicit main-thread hop (URLSession callbacks are NOT main-thread by default, unlike the existing `NowPlayingMonitor` wrapper)
3. `NotchWindowController` (modified) — adds `isLicensed` as one more AND term in the existing `shouldShow(...)` gate; owns the shared `LicenseState`; schedules/tears down the one-shot expiry work item
4. `SettingsView` (modified) — new License section (key entry, Activate button, status/days-remaining label) alongside existing sections
5. `scripts/release.sh` (modified, 2-line change) — real `DEVELOPER_ID`/`NOTARY_PROFILE` values replace dry-run placeholders; structurally unchanged

### Critical Pitfalls

1. **Trial state stored only in UserDefaults/plist** — trivially reset via `defaults delete`; use Keychain as source of truth (survives reinstall on non-sandboxed macOS), with "earliest known date wins" reconciliation if UserDefaults is also mirrored.
2. **License validation hard-fails on transient network errors at first-purchase moment** — the highest-consequence failure since it hits paying customers at peak purchase-regret risk; distinguish 4xx invalid-key from network/5xx errors, retry with backoff, never lock out a key the user just paid for, keep a visible support contact.
3. **Offline-cached license state as a plain flippable boolean** — trivially flipped via `defaults write`; cache in Keychain with key/timestamp binding, re-validate opportunistically (not never, not every launch).
4. **Notarization failure from incorrectly-signed nested `MediaRemoteAdapter.framework` or wrong hardened-runtime entitlements** — set "Embed & Sign" (not "Embed Without Signing"), sign innermost-first, avoid `codesign --deep` for the release build, and run `codesign --verify --deep --strict` + `spctl --assess` locally before ever calling `notarytool submit`.
5. **Mid-session abrupt lockout** — re-validation/expiry firing while the island is expanded or mid-drag must defer enforcement to the next natural UI transition, animated in the app's existing spring/morph language, not an instant yank or system alert.
6. **Checkout-to-license-key handoff friction for an LSUIElement (Dock-icon-less) app** — no obvious "come back to the app" affordance after browser checkout; mitigate with a menu-bar icon state cue, one-click-reachable license entry, and (as enhancement) a deep-link redirect rather than relying solely on email round-trip.

## Implications for Roadmap

Based on combined research, the architecture doc's suggested build order is well-reasoned (de-risk the highest-blast-radius integration point first, defer live network dependency) and should become the roadmap's phase backbone.

### Phase 1: Trial + Lockout Gate (stubbed license state)
**Rationale:** Touches the most sensitive existing file (`NotchWindowController`'s proven single-arbiter `updateVisibility()`), so it should be built and stabilized before any other new code touches that file again. No live network dependency needed yet — a manually-settable stub `LicenseState` is sufficient to prove the gate.
**Delivers:** `TrialLogic` (pure, unit-tested), `TrialManager` (UserDefaults+Keychain glue, one-shot expiry `DispatchWorkItem`), `LicenseState` model, `isLicensed` AND-term wired into `shouldShow(...)`, first-launch welcome moment.
**Addresses:** Trial-start persistence, days-remaining computation, hard lockout mechanism (table stakes P1 features).
**Avoids:** Pitfall 1 (UserDefaults-only trial storage), Pitfall 3 groundwork (Keychain as source of truth), Anti-Pattern 1 (second show/hide site), Anti-Pattern 3 (polling for expiry).

### Phase 2: License-Entry Settings UI (stubbed LicenseService)
**Rationale:** Exercises the full UI state machine (idle → validating → success/failure) against a fake in-memory `LicenseService` before live network flakiness can confound UI bugs.
**Delivers:** New "License" section in `SettingsView` (key entry field, Activate button, status label, days-remaining display, Buy Now button opening a placeholder URL).
**Addresses:** Table-stakes license entry UI, Buy Now button, days-remaining indicator.
**Avoids:** Pitfall 6 groundwork (one-click reachability from menu bar), Pitfall 5 groundwork (UI state awareness before wiring real async validation).

### Phase 3: Real Polar.sh Integration
**Rationale:** First point live Polar.sh product/API credentials are actually needed; swaps the stub `LicenseService` for `PolarLicenseService` behind the same protocol with zero UI or `TrialManager` wiring changes.
**Delivers:** `PolarLicenseService` (URLSession calls to `/activate` and `/validate`, Keychain read/write, explicit main-thread hop), Checkout Link wired to the real Buy Now button, retry/error-differentiation logic.
**Uses:** URLSession + Codable, Security/Keychain (from STACK.md addendum).
**Implements:** `LicenseService` protocol pattern (from ARCHITECTURE.md), mirrors `NowPlayingService`'s isolation discipline.
**Avoids:** Pitfall 2 (hard-fail on transient network errors), Pitfall 3 (flippable boolean cache), Pitfall 6 (checkout handoff friction), Anti-Pattern 4 (assuming URLSession completion runs on main).

### Phase 4: Real Notarization
**Rationale:** Functionally independent of Phases 1-3 (touches only two shell-script variables and requires only the already-purchased Developer ID credentials); the architecture doc explicitly notes this can run in parallel with or after the licensing work without blocking it. Bundled into this milestone for business reasons (no Gatekeeper warning on a paid product's first launch), not technical dependency.
**Delivers:** Real Developer ID Application cert verified locally, App Store Connect API key generated and stored via `notarytool store-credentials`, `scripts/release.sh` placeholders filled, `MediaRemoteAdapter.framework` confirmed "Embed & Sign," full pre-flight `codesign --verify --deep --strict` + `spctl --assess` + clean-account Gatekeeper test.
**Avoids:** Pitfall 4 (nested-framework signature/entitlement rejection) — budget 2-3 notarization iteration cycles, not one-shot success.

### Phase Ordering Rationale

- Phases 1→2→3 follow the "pure seam before live glue" discipline already established in this codebase for `PowerActivity`→`PowerSourceMonitor` and `NowPlayingPresentation`→`NowPlayingMonitor` — de-risk the classification/gating logic against a stub before introducing network flakiness as a confound.
- The hard-lockout gate (Phase 1) must exist and be tested before license validation (Phase 3) touches it, since the lockout is a boolean AND of both — building them out of order risks a launch-blocking bug that locks out legitimate trial users.
- Notarization (Phase 4) has zero code coupling to licensing and can be sequenced flexibly, but should not be treated as a footnote — its own pitfalls (nested-framework signing) need a dedicated phase with iteration budget.
- Deep-link auto-fill and last-day nudge notification (both P2 differentiators) are deliberately excluded from the phase list above — they layer on top of a working manual-paste flow and belong in a v1.x fast-follow, not this milestone's core phases, per FEATURES.md's explicit "Add After Validation" bucket.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Real Polar.sh Integration):** API error-response taxonomy beyond the documented `granted/revoked/disabled` statuses is thin in official docs (LOW-MEDIUM confidence per PITFALLS.md); verify actual error shapes and rate-limit behavior against the real (production, not sandbox) API during implementation.
- **Phase 4 (Real Notarization):** The Individual-vs-Team API key `--issuer` flag distinction (Xcode 26+) is MEDIUM-HIGH confidence, not officially doc-confirmed (Apple's TN3147 page did not render during research) — re-check the actual error message if a 401 appears.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Trial + Lockout Gate):** Directly mirrors existing, verified codebase patterns (pure-seam/thin-glue split, single-arbiter visibility, one-shot `DispatchWorkItem` idiom) — architecture is HIGH confidence, spot-checked against actual source files.
- **Phase 2 (License-Entry Settings UI):** Standard SwiftUI `Form`/`Section` pattern already used elsewhere in `SettingsView.swift`.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Polar.sh API shape verified directly against current official docs (fetched 2026-07-05); Keychain/notarytool patterns verified against man pages and multiple corroborating secondary sources; a couple of Apple doc pages (Keychain storage guide, TN3147) didn't render via fetch tooling and are flagged inline as needing a manual spot-check |
| Features | MEDIUM-HIGH | Patterns cross-verified across three comparable apps (BetterDisplay, Rectangle Pro, CleanShot X); Polar.sh mechanics confirmed against official docs; some competitor specifics are community-report quality (GitHub wikis, community discussions), not vendor-confirmed |
| Architecture | HIGH on integration points | Verified by directly reading the actual Islet codebase files (not inferred) — `NotchWindowController.swift`, `NowPlayingMonitor.swift`, `SettingsView.swift`, etc.; MEDIUM on the offline-grace-period duration, which is explicitly flagged as a product decision, not an architecture fact |
| Pitfalls | MEDIUM-HIGH | Notarization/codesign mechanics and macOS Keychain behavior are HIGH confidence (well-documented, official sources); Polar.sh-specific operational details (rate limits, offline guidance, error taxonomy) are MEDIUM, filled in with general licensing-industry patterns that are LOW-MEDIUM but directionally solid |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Offline-grace-period duration** (how long a cached Keychain validation is trusted before requiring re-validation): explicitly flagged in ARCHITECTURE.md as a product decision, not resolved by research — needs a concrete number decided during roadmap/phase planning.
- **Polar license-key activation-limit defaults**: dashboard UI defaults for the license-key benefit weren't independently confirmed beyond docs text — verify when configuring the Polar product/benefit.
- **Polar API error taxonomy**: full error-response shapes beyond `granted/revoked/disabled` and 404/422 aren't fully documented — build the retry/error-differentiation logic (Pitfall 2) defensively and verify against the real API during Phase 3.
- **Individual vs. Team notarytool API key `--issuer` behavior**: MEDIUM-HIGH confidence only, Apple's own TN3147 migration page didn't render during research — re-verify during Phase 4 if a 401 error appears.
- **Whether Polar's checkout supports a post-purchase redirect/deep-link out of the box** vs. requiring a small serverless relay to resolve `checkout_id` → license key safely (since the org-level secret token can't ship in the app) — this affects whether the P2 deep-link differentiator is feasible without a backend; investigate before committing to it in a v1.x fast-follow.

## Sources

### Primary (HIGH confidence)
- `polar.sh/docs/api-reference/customer-portal/license-keys/{validate,activate}` — fetched directly 2026-07-05; endpoint shape, no-auth-for-desktop-clients guarantee
- `polar.sh/docs/features/checkout/links` — Checkout Links vs. authenticated Checkout Sessions API distinction
- Apple Developer Docs — notarization process, `notarytool`, `LSUIElement`, custom URL scheme handling
- Direct reads of the actual Islet codebase (`NotchWindowController.swift`, `NowPlayingMonitor.swift`, `PowerSourceMonitor.swift`, `SettingsView.swift`, `AppDelegate.swift`, `scripts/release.sh`, `project.yml`)
- `keith.github.io/xcode-man-pages/notarytool.1.html` — official man page mirror, flag semantics

### Secondary (MEDIUM confidence)
- BetterDisplay GitHub wiki + support discussions — 14-day trial, Paddle-based Settings > Pro pattern, soft-lock "Trial Expired" state
- Rectangle Pro Community discussion #154 — Paddle-based purchase/activation flow, 3-device limit, self-service recovery portal
- CleanShot X buy/pricing/FAQ pages — License Manager portal pattern
- Faisal Bin Ahmed, "All the wrong ways to persist in-app purchase status" — UserDefaults-vs-Keychain distinction
- Keygen.sh offline-licensing model docs; Stanislav Katkov Polar.sh Go implementation notes

### Tertiary (LOW-MEDIUM confidence)
- LicenseSeat's competitor critique of Polar's license-key feature (bolt-on, no device fingerprinting) — directional caution flag, not gospel given vendor-competitor incentive
- WebSearch-aggregated community reports on trial-lockout variance (soft vs. hard lock) — confirms no single dominant convention, not a systematic survey
- Individual-vs-Team notarytool API key `--issuer` behavior — corroborated by `@electron/notarize` README and forum reports, but Apple's own TN3147 page didn't render during research

---
*Research completed: 2026-07-05*
*Ready for roadmap: yes*
