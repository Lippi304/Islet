# Phase 12: Real Polar.sh License Integration - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver real license purchase + validation against Polar.sh. Swap the Phase-11
`StubLicenseService` for a real `PolarLicenseService` behind the **existing**
`LicenseService` protocol — no UI changes, no `TrialManager` changes, no protocol
changes. Concretely (LIC-01, LIC-02):

- **Buy Now** opens the real Polar.sh checkout (already wired via the existing
  redirect page — see decisions; no button change needed).
- Pasting a purchased key validates it **once online** against Polar.sh, then the
  validated state is **cached in Keychain** so the app works **fully offline**
  afterward.
- A transient network error is distinguishable from an actually-invalid key and
  never locks out a key the user already paid for.

Out of scope (own phases / deferred): notarization/signing (Phase 13), periodic
re-validation / refund-revocation detection, device activation limits.
</domain>

<decisions>
## Implementation Decisions

### Re-validation & Revocation (D-01)
- **D-01:** **Validate once, then trust forever.** After ONE successful online
  validation, persist the validated state in the Keychain and NEVER re-check
  online. Directly satisfies "fully offline afterward" (LIC-02 / success criterion 3).
  Accepted tradeoff: refunds / revoked keys are NOT detected post-validation —
  acceptable for a €7.99 hobby app; revocation handling is a deferred future option.

### Device / Activation Limit (D-02)
- **D-02:** **No device limit — validate-only.** Use Polar's license-key
  *validation* (not *activation*), so a key works on unlimited Macs. Customer-friendly
  and simple; weak copy-protection is an accepted tradeoff at this price point and can
  be tightened later. Do NOT implement Polar "activations" / activation limits.

### Buy Now Target (D-03)
- **D-03:** **Buy Now stays unchanged** — it keeps pointing at
  `https://lippi304.xyz/projects/islet/buy`, which redirects to the real Polar.sh
  checkout. LIC-01 is already satisfied by the existing `buyNowButton` in
  `SettingsView.swift`; **no UI/URL change in this phase**.

### Network-Error Behavior & Retry (D-04)
- **D-04:** **Clear split + manual retry.** Surface `.invalidKey` as a specific
  "key not recognized" message, distinct from `.unreachable` ("server not reachable")
  which offers a **manual Retry button**. A key that was already validated (Keychain
  cache present) is **NEVER** locked out by a network error. First-time activation
  requires a network round-trip; if offline at first activation, show the unreachable
  state + Retry (validation cannot happen offline the first time — unavoidable).
  No silent auto-retry (transparency for the user).

### Polar Configuration (D-05)
- **D-05:** **Organization ID (non-secret):** `952bfc3a-c29b-4024-bf2e-deded1be5908`.
  Embedded in the app and sent client-side in the validate call. NOT a secret.
- **D-06:** **No embedded API secret.** Use the customer-portal validate endpoint
  (`POST /v1/customer-portal/license-keys/validate` with `organization_id` + `key`),
  which needs no organization access token — so no secret ships in the distributed app
  (avoids a credential leak). The researcher MUST confirm the exact endpoint, request,
  and response shape against the live Polar API.

### Keychain Cache (D-07)
- **D-07:** The validated-license state persists in the **Keychain**, mirroring the
  `KeychainTrialStore` pattern (its own service, e.g. `com.lippi304.islet.license`) —
  NEVER UserDefaults, and NOT a trivially-flippable persisted bool (honor T-11-02).
  Exact schema (store the key vs a validated flag + metadata) is the planner's call,
  informed by research.

### Claude's Discretion
- Exact Keychain item schema/shape for the validated license (D-07).
- How the `organization_id` is embedded (constant vs build setting) — planner's call.
- URLSession configuration, timeout values, and JSON model shapes (research-informed).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The seam to replace (Phase 11 output)
- `Islet/Licensing/LicenseService.swift` — the `LicenseService` protocol +
  `LicenseActivationError` (`.invalidKey`, `.unreachable(String)`). `PolarLicenseService`
  is a one-file drop-in; **completion is ALWAYS delivered on the main thread** (contract).
- `Islet/Licensing/LicenseState.swift` — the single entitlement source of truth
  (`sessionActivated`, `status`, `isEntitled`). Phase 12 needs a **persisted** validated
  state, not just the in-memory session flag.

### Keychain pattern to mirror
- `Islet/Licensing/TrialManager.swift` — `KeychainStore` protocol seam +
  `KeychainTrialStore` (service `com.lippi304.islet.trial`, `SecItem*` calls). Copy this
  shape for the license cache (D-07).

### Requirements
- `.planning/REQUIREMENTS.md` — LIC-01 (Buy Now → Polar checkout), LIC-02 (validate once
  online → Keychain cache → offline). LIC-03 (lockout) is Phase 10, already built.

### External (researcher to fetch + pin exact shapes)
- Polar.sh API docs — customer-portal license-key **validate** endpoint
  (`POST /v1/customer-portal/license-keys/validate`), request/response, error taxonomy
  (`granted` / `revoked` / `disabled`), and how "invalid key" vs "transport error" is
  distinguishable. Confirm no access token is required for the validate call.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LicenseService` protocol + `LicenseActivationError` — already model both `.invalidKey`
  and `.unreachable(String)`; PolarLicenseService drops in with ZERO protocol change.
- `KeychainTrialStore` / `KeychainStore` protocol — reusable Keychain glue pattern for
  the validated-license cache (injectable seam → unit-testable with a fake store).
- `SettingsView.swift` activation state machine (idle → validating → success/failure) +
  `buyNowButton` — already built in Phase 11; Phase 12 only changes the SERVICE behind it.

### Established Patterns
- Protocol-isolation of fragile externals (mirrors `NowPlayingService`/`NowPlayingMonitor`):
  quarantine the network dependency behind ONE `AnyObject` protocol, callers hold the
  protocol type only.
- Completion-on-main-thread contract — the URLSession path MUST hop back to main before
  calling `completion` (SettingsView mutates SwiftUI `@State`/`LicenseState` without a
  manual main-hop).
- Keychain (not UserDefaults) is the trusted persistence store; entitlement truth is never
  a trivially-flippable persisted bool (T-11-02 / Phase 10 pitfalls).

### Integration Points
- `PolarLicenseService.activate(key:completion:)` replaces `StubLicenseService` — same
  protocol, same call site in `SettingsView`.
- Validated state flows into `LicenseState` (persisted via new Keychain store) → `isEntitled`
  → `NotchWindowController.updateVisibility()` (the existing single visibility arbiter).
</code_context>

<specifics>
## Specific Ideas

- Polar organization ID is known and provided: `952bfc3a-c29b-4024-bf2e-deded1be5908`.
- A real purchased **license key** exists for testing but is intentionally NOT recorded in
  planning docs (a real credential). The user supplies it live at the **manual on-device
  verification** step (paste into Settings → Activate).
- Price point: €7.99 one-time purchase (drives the "customer-friendly, low copy-protection"
  posture in D-01/D-02).
</specifics>

<deferred>
## Deferred Ideas

- **Periodic online re-validation + refund/revocation detection** (Polar `revoked`/`refunded`
  handling) — deliberately out of scope for v1 per D-01; a future enhancement.
- **Device / activation limits** (Polar "activations", N-device caps) — deferred per D-02.

None of these block Phase 12 — discussion stayed within the LIC-01/LIC-02 scope.
</deferred>

---

*Phase: 12-real-polar-sh-license-integration*
*Context gathered: 2026-07-05*
