# Phase 12: Real Polar.sh License Integration - Research

**Researched:** 2026-07-05
**Domain:** Polar.sh customer-portal license-key validation over URLSession; Keychain-cached offline entitlement (native macOS Swift)
**Confidence:** HIGH

## Summary

Phase 12 replaces the Phase-11 `StubLicenseService` with a real `PolarLicenseService`
behind the unchanged `LicenseService` protocol. The single hardest question — the exact
Polar validate contract — is now **confirmed against both the official API reference and the
Polar server source**: the call is `POST https://api.polar.sh/v1/customer-portal/license-keys/validate`,
takes a JSON body of `{ "key": ..., "organization_id": ... }`, requires **no authentication
token** (D-06 is CORRECT — no secret ships in the app), and returns a `ValidatedLicenseKey`
JSON object with a `status` field on HTTP 200.

The decisive finding for the error taxonomy (LIC-02 / success criterion 4): in the Polar
server, a key that is **not-found, revoked, disabled, expired, or condition-mismatched all
raise the same `ResourceNotFound` → HTTP 404** [CITED: github.com/polarsource/polar server/polar/license_key/service.py].
This makes the mapping clean and unambiguous: **404 (and 422) → `.invalidKey`**; **URLSession
transport error, timeout, or a 5xx server error → `.unreachable`**. A revoked key and a
never-existed key are indistinguishable to the client — which is fine, because D-01
("validate once, then trust forever") means the app only ever cares about the one-time
`200 + status:"granted"` verdict.

**Primary recommendation:** Implement `PolarLicenseService.activate(key:completion:)` as a
single `URLSession.shared.dataTask` POST with a `Codable` request/response, a ~15s timeout,
strict HTTP-status → error mapping (see Pitfall 2), and a **main-thread completion hop**
(existing contract). On `.success`, persist a small `Codable` record (validated key + license
id + status + timestamp) into a new `KeychainLicenseStore` (service `com.lippi304.islet.license`),
mirroring `KeychainTrialStore`. On launch, a present granted record short-circuits
`LicenseState` to `.licensed` **without any network call** — read once, cache in memory
(mirror `TrialManager.cachedStartDate`) to avoid the Keychain-prompt-flood bug.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 — Validate once, then trust forever.** After ONE successful online validation,
  persist the validated state in the Keychain and NEVER re-check online. Refunds/revoked keys
  are NOT detected post-validation (accepted tradeoff for a €7.99 hobby app).
- **D-02 — No device limit; validate-only.** Use Polar's *validation* (not *activation*).
  Do NOT implement activations / activation limits. Key works on unlimited Macs.
- **D-03 — Buy Now stays unchanged.** Keeps pointing at `https://lippi304.xyz/projects/islet/buy`
  (redirects to real Polar checkout). LIC-01 already satisfied by existing `buyNowButton`;
  no UI/URL change this phase.
- **D-04 — Clear split + manual retry.** `.invalidKey` = "key not recognized" (distinct
  message); `.unreachable` = "server not reachable" + manual **Retry** button. A key with a
  present Keychain cache is NEVER locked out by a network error. First-time activation needs a
  network round-trip; if offline, show unreachable + Retry. No silent auto-retry.
- **D-05 — Organization ID (non-secret):** `952bfc3a-c29b-4024-bf2e-deded1be5908`. Embedded
  in the app, sent client-side in the validate call. NOT a secret.
- **D-06 — No embedded API secret.** Use the customer-portal validate endpoint
  (`POST /v1/customer-portal/license-keys/validate` with `organization_id` + `key`); needs no
  organization access token. **CONFIRMED by research** (see Standard Stack / Endpoint Contract).
- **D-07 — Validated state persists in the Keychain**, mirroring `KeychainTrialStore` (own
  service, e.g. `com.lippi304.islet.license`). NEVER UserDefaults; NOT a trivially-flippable
  persisted bool (honor T-11-02). Exact schema is the planner's call, research-informed.

### Claude's Discretion
- Exact Keychain item schema/shape for the validated license (D-07).
- How `organization_id` is embedded (constant vs build setting).
- URLSession configuration, timeout values, and JSON model shapes.

### Deferred Ideas (OUT OF SCOPE)
- Periodic online re-validation + refund/revocation detection (Polar `revoked`/`refunded`).
- Device / activation limits (Polar "activations", N-device caps).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIC-01 | Buy Now → Polar checkout | Already satisfied (D-03); no code change. Verified: `buyNowButton` in `SettingsView.swift` opens the redirect URL. No Polar API involvement in this phase. |
| LIC-02 | Validate once online → Keychain cache → works offline | Endpoint contract + error taxonomy confirmed (Standard Stack). Keychain schema mirrors `KeychainTrialStore` (Architecture Patterns). Offline-after-first-validation = present Keychain record short-circuits `LicenseState` with zero network call. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| License-key online validation | Network client (`PolarLicenseService`) | — | The one fragile external dependency; quarantined behind the `LicenseService` protocol (mirrors `NowPlayingService`). Callers hold the protocol type only. |
| HTTP → verdict mapping | Network client | — | HTTP-status → `.invalidKey`/`.unreachable` decision lives entirely inside the service; `SettingsView` sees only a `Result`. |
| Offline entitlement persistence | Keychain store (`KeychainLicenseStore`) | In-memory cache | Keychain is the trusted store (survives reinstall/`defaults delete`); in-memory cache keeps it off the hover/click hot path. |
| Entitlement source of truth | `LicenseState` | — | Existing single arbiter; reads the persisted license once at launch, exposes `isEntitled`. |
| Purchase (Buy Now) | UI (`SettingsView`) → default browser | — | No API call; just opens the redirect URL. Already built (D-03). |

## Standard Stack

### Core — no third-party packages

This phase adds **zero external dependencies**. Everything is Apple-first-party:

| Framework | Purpose | Why Standard |
|-----------|---------|--------------|
| Foundation `URLSession` | The single POST to Polar; `URLRequest`, `dataTask`, timeouts | The canonical native HTTP client. A €7.99 app making one JSON POST does not warrant Alamofire or the `@polar-sh/sdk` (which is TypeScript-only anyway). [CITED: developer.apple.com/documentation/foundation/urlsession] |
| Foundation `Codable` / `JSONEncoder` / `JSONDecoder` | Model the request + `ValidatedLicenseKey` response | Standard Swift JSON. Decode only the fields you need; extra JSON keys are ignored automatically. |
| `Security` (`SecItem*`) | Keychain cache | Already the project's proven pattern (`KeychainTrialStore`). Mirror it. |

**Installation:** None. No `File > Add Package Dependencies`. Do not add the Polar SDK.

**Note on the Polar SDKs:** `@polar-sh/sdk` (npm/TypeScript) and `polar-js` exist but are
**not for Swift** — there is no official Polar Swift SDK. Hand-rolling one `URLSession` call
is the correct approach here, and is exactly what the "customer-portal, public-client,
no-auth" endpoint design intends (it is meant to be called directly from desktop/mobile apps).
[CITED: polar.sh/docs/api-reference/customer-portal/license-keys/validate — "can be safely used on a public client, like a desktop application"]

### Endpoint Contract (THE critical deliverable)

**Confirmed against** [CITED: polar.sh/docs/api-reference/customer-portal/license-keys/validate]
**and** [CITED: github.com/polarsource/polar server/polar/license_key/service.py].

| Property | Value |
|----------|-------|
| Method | `POST` |
| Path | `/v1/customer-portal/license-keys/validate` |
| Production base host | `https://api.polar.sh` → full URL `https://api.polar.sh/v1/customer-portal/license-keys/validate` |
| Sandbox base host | `https://sandbox-api.polar.sh` (dashboard `https://sandbox.polar.sh`) |
| **Auth** | **NONE.** No `Authorization` header, no access token. "This endpoint doesn't require authentication and can be safely used on a public client." D-06 CONFIRMED. |
| Required header | `Content-Type: application/json` (and set `Accept: application/json`) |

> There is a **separate** server-side endpoint `POST /v1/license-keys/validate` that DOES
> require an organization access token. **Do NOT use it** — it would force shipping a secret.
> Use the **`customer-portal`** path exactly as D-06 specifies.

**Request body** (`LicenseKeyValidate`) — send only two fields for validate-only (D-02):

```json
{
  "key": "<the pasted license key>",
  "organization_id": "952bfc3a-c29b-4024-bf2e-deded1be5908"
}
```

| Field | Type | Required | Phase 12 use |
|-------|------|----------|--------------|
| `key` | string | **Yes** | The trimmed pasted key |
| `organization_id` | string (UUID4) | **Yes** | D-05 constant |
| `activation_id` | UUID4 | No (nullable) | **OMIT** — no activations (D-02) |
| `benefit_id` | UUID4 | No (nullable) | OMIT |
| `customer_id` | UUID4 | No (nullable) | OMIT |
| `increment_usage` | integer ≥0 | No (nullable) | OMIT — validate-only, don't consume usage |
| `conditions` | object (≤50 pairs) | No | OMIT — no device conditions (D-02) |

**Success response — HTTP 200** (`ValidatedLicenseKey`). Model only the load-bearing fields;
Codable ignores the rest:

| Field | Type | Model in Swift? | Meaning |
|-------|------|-----------------|---------|
| `status` | enum `granted`\|`revoked`\|`disabled` | **YES** | The entitlement gate. Only `granted` reaches a 200 in practice (see below), but check it defensively. |
| `id` | UUID4 | YES | License-key id; persist for reference/support |
| `key` | string | YES | Echo of the full key |
| `display_key` | string | optional | Masked key (e.g. `****-XXXX`) — nice for UI, not required |
| `expires_at` | datetime, nullable | optional | Null for a one-time perpetual purchase; persist if present |
| `organization_id`, `customer_id`, `customer`, `benefit_id`, `limit_activations`, `usage`, `limit_usage`, `validations`, `last_validated_at`, `activation` | various | NO | Not needed for validate-once entitlement; leave out of the Swift model |

Minimal Swift response model:

```swift
private struct ValidatedLicenseKey: Decodable {
    let id: String
    let key: String
    let status: String        // "granted" | "revoked" | "disabled"
    let expiresAt: String?    // CodingKeys: "expires_at"
}
```

**Error / non-valid responses** [CITED: server/polar/license_key/service.py]:

| Condition | HTTP | Server raise | Maps to |
|-----------|------|--------------|---------|
| Key not found | **404** | `ResourceNotFound("License key not found")` | `.invalidKey` |
| Key status ≠ granted (revoked/disabled) | **404** | `ResourceNotFound("License key is no longer active.")` | `.invalidKey` |
| Key expired | **404** | `ResourceNotFound("License key has expired.")` | `.invalidKey` |
| Activation conditions mismatch | **404** | `ResourceNotFound("License key does not match required conditions")` (N/A — we send no conditions) | `.invalidKey` |
| Usage limit exceeded | **400** | `BadRequest(...)` (N/A — validate-only, no `increment_usage`) | `.invalidKey` (defensive) |
| Malformed request body | **422** | `ValidationError` (array of `{loc,msg,type}`) | `.invalidKey` (this is our bug, but surface as invalid) |
| Polar 5xx / gateway error | 500–504 | — | **`.unreachable`** (retryable — do NOT lock out) |
| Offline / DNS / TLS / timeout | — | `URLError` from URLSession | **`.unreachable(String)`** |

**Key insight:** because revoked/disabled/expired all collapse to 404, the client cannot and
need not distinguish them — under D-01 the only thing that matters is the one-time
`200 + status == "granted"`. Treat any 200 whose `status != "granted"` as `.invalidKey` too
(belt-and-suspenders; the server should never send it).

### License-key status taxonomy (D-01 entitlement rule)

| Polar status | Meaning | Counts as "entitled"? |
|--------------|---------|-----------------------|
| `granted` | Active, purchased, valid | **YES** — the only status that yields a 200 the app trusts |
| `revoked` | Auto-revoked on subscription cancel/refund | No — but returns 404, never reaches the app as a 200 |
| `disabled` | Manually disabled by the org (you) | No — returns 404 |

Under D-01, the app validates once; a later revoke/disable is deliberately **not** detected
(deferred). Entitlement = "we once saw a 200 granted verdict for this key" → persisted forever.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled URLSession | Polar SDK | No Swift SDK exists; the TS SDK is irrelevant. Adding any HTTP lib is overkill for one POST. |
| `customer-portal/.../validate` (no auth) | `/v1/license-keys/validate` (auth) | The authed endpoint forces shipping an org token — a credential leak. D-06 rejects it. |
| Store validated key in Keychain | Store signed token | Polar's validate response is unsigned; no offline-verifiable cryptographic proof exists. Keychain ACL + code signing is the practical boundary (documented tradeoff). |

## Package Legitimacy Audit

No external packages are installed in this phase (Foundation + Security only).

| Package | Registry | Disposition |
|---------|----------|-------------|
| (none) | — | N/A — first-party Apple frameworks only |

**Packages removed due to slopcheck [SLOP] verdict:** none installed. (Note: slopcheck flagged
a hypothetical `polar-sh` PyPI name as [SLOP]/non-existent — confirming there is no Python/Swift
Polar package to install; the correct integration is a raw HTTP call, not a package.)

## Architecture Patterns

### System Architecture Diagram

```
[User pastes key in SettingsView]
            │ activate(key:completion:)
            ▼
   ┌──────────────────────┐        POST /v1/customer-portal/license-keys/validate
   │ PolarLicenseService  │ ─────────────────────────────────────────────► [api.polar.sh]
   │ (LicenseService)     │        body { key, organization_id }
   │  - URLSession POST   │ ◄─────────────────────────────────────────────
   │  - map HTTP → verdict│        200 {status:"granted",...} | 404 | 422 | 5xx | URLError
   └──────────┬───────────┘
              │ Result<Void, LicenseActivationError>  (on MAIN thread)
      ┌───────┴────────┐
   .success            .failure(.invalidKey | .unreachable)
      │                        │
      ▼                        ▼
[persist record]        [SettingsView shows
 KeychainLicenseStore     "not recognized" | "unreachable + Retry"]
      │
      ▼
[LicenseState.sessionActivated = true → status .licensed]
      │
      ▼
[NotchWindowController.updateVisibility()]   ← existing single visibility arbiter

        ── App launch (offline path, no network) ──
[LicenseState first read] → KeychainLicenseStore.read() (cached in memory after 1st read)
        granted record present? → status .licensed → isEntitled = true
```

### Recommended Project Structure
```
Islet/Licensing/
├── LicenseService.swift        # EXISTING protocol + LicenseActivationError (unchanged)
├── PolarLicenseService.swift   # NEW — replaces StubLicenseService as the wired conformer
├── KeychainLicenseStore.swift  # NEW — mirrors KeychainTrialStore (service com.lippi304.islet.license)
├── LicenseState.swift          # EDIT — read persisted license once at launch → .licensed
├── TrialManager.swift          # unchanged (pattern donor)
└── LicenseState/Store wiring in AppDelegate / SettingsView (existing call site)
```

### Pattern 1: URLSession validate with strict error mapping + main-thread hop
**What:** One `dataTask` POST; branch on `URLError` vs `HTTPURLResponse.statusCode`; always
complete on main.
**When to use:** The entire `activate(key:)` body.
```swift
// Source: developer.apple.com/documentation/foundation/urlsession/datatask
// + Polar contract (polar.sh/docs/api-reference/customer-portal/license-keys/validate)
func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void) {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)   // T-11-03: opaque input
    func finish(_ r: Result<Void, LicenseActivationError>) {
        DispatchQueue.main.async { completion(r) }                      // CONTRACT: main thread
    }
    guard let url = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/validate"),
          let body = try? JSONEncoder().encode(ValidateRequest(key: trimmed,
                            organizationID: "952bfc3a-c29b-4024-bf2e-deded1be5908"))
    else { return finish(.failure(.invalidKey)) }

    var req = URLRequest(url: url, timeoutInterval: 15)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.httpBody = body

    session.dataTask(with: req) { data, response, error in
        if let error = error {                        // offline/timeout/TLS → retryable
            return finish(.failure(.unreachable(error.localizedDescription)))
        }
        guard let http = response as? HTTPURLResponse else {
            return finish(.failure(.unreachable("No HTTP response")))
        }
        switch http.statusCode {
        case 200:
            guard let data = data,
                  let v = try? JSONDecoder().decode(ValidatedLicenseKey.self, from: data),
                  v.status == "granted"
            else { return finish(.failure(.invalidKey)) }
            return finish(.success(()))
        case 404, 422, 400:                           // not found/revoked/disabled/expired/malformed
            return finish(.failure(.invalidKey))
        default:                                      // 5xx etc. → retryable, never lock out (D-04)
            return finish(.failure(.unreachable("Server error \(http.statusCode)")))
        }
    }.resume()
}
```

### Pattern 2: KeychainLicenseStore (mirror KeychainTrialStore)
**What:** Same `SecItem*` upsert shape as `KeychainTrialStore`, new service, storing a
`Codable` record (not a bool).
```swift
// Source: existing Islet/Licensing/TrialManager.swift (KeychainTrialStore) — proven pattern
struct KeychainLicenseStore {
    private let service = "com.lippi304.islet.license"
    private let account = "validatedLicense"
    // read() -> LicenseRecord? ; write(record) -> Bool ; delete()
    // value = JSONEncoder().encode(LicenseRecord)   (NOT a bool — honors T-11-02)
    // kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock  (mirror trial store)
}
struct LicenseRecord: Codable {   // what to persist (D-07)
    let key: String               // the validated key (proof-of-purchase, not a flippable bool)
    let licenseID: String         // Polar license-key id
    let status: String            // "granted"
    let validatedAt: Date
}
```
**Entitlement rule on read:** a present record with `status == "granted"` → `.licensed`.

### Anti-Patterns to Avoid
- **Reading the Keychain on the hot path.** `LicenseState.status` is read on every hover/
  click/drag via `updateVisibility()`. An uncached live Keychain read there caused a
  macOS authorization-prompt FLOOD on ad-hoc-signed dev builds (project memory 2401 /
  TrialManager comment lines 88–96). **Read the license record ONCE, cache it in memory**
  (mirror `TrialManager.cachedStartDate` / `hasCachedStartDate`).
- **Persisting a bare `Bool`.** Violates T-11-02 (trivially-flippable bypass). Store the
  `Codable` record instead.
- **Mapping a 5xx or timeout to `.invalidKey`.** Would lock out a paid key on a Polar outage
  — directly violates D-04. Non-2xx that isn't 400/404/422 → `.unreachable`.
- **Blocking the main thread on the network call.** Use the async `dataTask`; only the final
  `completion` hops to main.
- **Sending `activation_id`/`increment_usage`/`conditions`.** That turns validate into
  activation/usage-consumption behavior — contradicts D-02.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP client / retry / JSON | Custom socket or 3rd-party lib | `URLSession` + `Codable` | One POST; native tools cover it, no dependency to notarize/embed. |
| Retry logic | Auto-retry loop | Manual Retry button (D-04) | Transparency requirement; user drives retry. |
| Offline entitlement proof | Custom crypto/license signing | Keychain-persisted record | Polar's response is unsigned; there's no offline-verifiable signature to build against. Keychain ACL is the practical boundary. |
| Keychain glue | New `SecItem` design | Copy `KeychainTrialStore` | Proven in-project; identical single-item upsert shape. |

**Key insight:** the whole point of Polar's *customer-portal* (public, no-auth) endpoint is
that a thin direct client call is the intended integration — no SDK, no backend.

## Common Pitfalls

### Pitfall 1: Locking out a paid key on a transient network failure
**What goes wrong:** A 500 from Polar or a Wi-Fi blip maps to `.invalidKey`, telling a paying
user their key is fake.
**Why it happens:** Coarse "any non-200 = invalid" branching.
**How to avoid:** Only 400/404/422 → `.invalidKey`. `URLError` and 5xx → `.unreachable`
(retryable). And once a Keychain record exists, launch never calls the network at all (D-01).
**Warning signs:** Test with airplane mode + a Charles/Proxyman-forced 503.

### Pitfall 2: Keychain authorization-prompt flood (already hit once in this project)
**What goes wrong:** Repeated live Keychain reads on the hover/click hot path trigger a storm
of macOS "allow access" prompts on non-Developer-ID-signed builds.
**Why it happens:** `LicenseState` is read far more often than "once at launch".
**How to avoid:** Cache the license record in memory after the first read (mirror
`TrialManager`'s `cachedStartDate`/`hasCachedStartDate`). Keep both write and delete paths in
sync with the cache.
**Warning signs:** Any Keychain call inside a code path reachable from `updateVisibility()`.

### Pitfall 3: Completion delivered off the main thread
**What goes wrong:** `SettingsView` mutates SwiftUI `@State`/`LicenseState` from a URLSession
background thread → runtime purple warnings / UI races.
**Why it happens:** `URLSession` completion handlers run on a background queue.
**How to avoid:** Wrap every `completion(...)` in `DispatchQueue.main.async` (contract from
`LicenseService.swift` header).
**Warning signs:** Main-thread-checker warnings when activating.

### Pitfall 4: Sending activation/usage fields turns validate into consumption
**What goes wrong:** Including `increment_usage` or `activation_id` mutates server state /
counts against limits, contradicting the validate-only, unlimited-devices posture.
**Why it happens:** Copy-pasting an "activate" example instead of "validate".
**How to avoid:** Body is exactly `{ key, organization_id }`. Nothing else.

### Pitfall 5: Using the wrong (authed) validate endpoint
**What goes wrong:** Using `/v1/license-keys/validate` (server endpoint) forces an
`Authorization: Bearer <org token>` header — a shipped secret.
**How to avoid:** Use the **`customer-portal`** path. It's designed for public clients and
takes no token (D-06 confirmed).

## Code Examples

### Request model + CodingKeys (snake_case bridge)
```swift
// Source: Polar LicenseKeyValidate schema (polar.sh/docs/api-reference/.../validate)
private struct ValidateRequest: Encodable {
    let key: String
    let organizationID: String
    enum CodingKeys: String, CodingKey {
        case key
        case organizationID = "organization_id"
    }
}
```

### Injectable session seam (for tests)
```swift
// Protocol seam so tests inject a fake network without hitting api.polar.sh
protocol HTTPSession { 
    func perform(_ request: URLRequest,
                 completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}
final class PolarLicenseService: LicenseService {
    private let session: HTTPSession
    init(session: HTTPSession = URLSessionHTTP()) { self.session = session }
    // ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Server-side `/v1/license-keys/validate` + org token | `customer-portal/license-keys/validate`, no auth, public-client-safe | Polar customer-portal API | Lets desktop apps validate with zero shipped secret (enables D-06). |

**Deprecated/outdated:** none relevant. Polar's API is versioned under `/v1`; the
customer-portal license-key endpoints are current as of 2026.

## Runtime State Inventory

Not a rename/refactor/migration phase — this is additive (new service + new Keychain item).
One near-adjacent item worth noting for the planner:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | NEW Keychain item, service `com.lippi304.islet.license`, account `validatedLicense`. Does not exist yet. | Create on first successful validation. |
| Secrets/env vars | `organization_id` `952bfc3a-...` is NON-secret (D-05) — embed as a constant; no `.env`, no SOPS. | None. |
| Build artifacts | `StubLicenseService` is REPLACED as the wired conformer. Its file may remain for tests, but the app must construct `PolarLicenseService` at the call site. | Rewire the injection point (AppDelegate/SettingsView). |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Revoked/disabled/expired keys return **404** (not 200 with status, not 403). Sourced from Polar server code, not the public reference. | Endpoint Contract | LOW — even if some return 200-with-non-granted-status or 403, the recommended mapping already treats 200/`status != granted` → `.invalidKey` and 403 falls into the default → `.unreachable`. Consider mapping 403 → `.invalidKey` too for safety. |
| A2 | A malformed body yields **422** (FastAPI/Pydantic default). Not directly tested on this endpoint. | Error table | LOW — 422 is mapped to `.invalidKey`; a wrong guess only mislabels an internal bug. |
| A3 | A Polar 5xx should be treated as retryable `.unreachable`. Inference, not an official statement. | Pitfall 1 | LOW — safest possible default (never lock out a paid key, D-04). |

**Note:** A1 is the highest-value claim; the planner should include a manual on-device
verification step that pastes the real purchased key (supplied live by the user) to confirm
the 200/granted happy path, and pastes a garbage key to confirm the 404→`.invalidKey` path.

## Open Questions (RESOLVED)

1. **Does a 200 ever carry `status: "revoked"`/`"disabled"`, or is it always 404?**
   - What we know: server source raises `ResourceNotFound` (404) for non-granted.
   - What's unclear: whether any edge path returns 200 with a non-granted status.
   - **RESOLVED:** already handled — the 200 branch requires `status == "granted"`, so
     either behavior is safe. No planning blocker. (Plan 12-02 requires `status == "granted"`.)

2. **Should 403 map to `.invalidKey` or `.unreachable`?**
   - What we know: WebSearch surfaced a generic Polar `NotPermitted` 403 pattern, but the
     validate endpoint's documented codes are 200/404/422.
   - **RESOLVED:** planner's call — 12-02 routes 403 via `default → .unreachable` (safer for
     D-04: never falsely rejects a paid key, always retryable). It effectively never fires on
     this no-auth endpoint. Conscious decision, confirmed by plan-checker Advisory 2.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Network access to `api.polar.sh` | First-time validation | ✓ (runtime) | — | Offline → `.unreachable` + Retry (by design, D-04) |
| Foundation `URLSession` | HTTP | ✓ | macOS 14+ SDK | — |
| `Security` framework | Keychain | ✓ | macOS SDK | — |
| Apple Developer ID signing | Prompt-free Keychain access | ✗ during dev (ad-hoc) | — | Dev builds may see Keychain prompts; cache-after-first-read mitigates; fully resolved by Phase 13 signing |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** first-time offline → unreachable + manual Retry (spec'd).

## Validation Architecture

`nyquist_validation` is enabled. **Important project constraint (memory 2380 / 2401 / xcodebuild
hang):** `xcodebuild test` HANGS in this project because tests are hosted in the full `Islet.app`
(boots NSPanel/MediaRemote/IOBluetooth). The practical CI gate is **`xcodebuild build`**; the
actual unit-test RUN is routed to **manual Cmd-U in Xcode**. Design the phase so the network +
Keychain logic is unit-testable with pure fakes (no real I/O), so Cmd-U runs fast and headless
paths never touch `api.polar.sh` or the real Keychain.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing — `LicenseServiceTests.swift`, `TrialManagerTests.swift`) |
| Config file | Islet.xcodeproj scheme test action |
| Quick run command | `xcodebuild build -scheme Islet -configuration Debug` (the gate; test RUN is manual Cmd-U) |
| Full suite command | Manual: Xcode → Cmd-U (headless `xcodebuild test` hangs — do NOT use in CI) |

### Testable seams (design for these)
- **Inject the network:** `PolarLicenseService(session: HTTPSession)` — a `FakeHTTPSession`
  returns canned `(Data, HTTPURLResponse, Error)` triples. No real request.
- **Inject the Keychain:** a `LicenseStore` protocol (like `KeychainStore`) with an in-memory
  `FakeLicenseStore`. Real `SecItem*` verified on-device only.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated (Cmd-U) | File |
|--------|----------|-----------|-------------------|------|
| LIC-02 | 200 `granted` → `.success` | unit | `FakeHTTPSession` returns 200 + granted JSON → assert `.success` | ❌ Wave 0 (`PolarLicenseServiceTests.swift`) |
| LIC-02 | 200 non-granted / malformed JSON → `.invalidKey` | unit | fake 200 + `status:"revoked"` / garbage body | ❌ Wave 0 |
| LIC-02 | 404 → `.invalidKey` | unit | fake 404 → assert `.failure(.invalidKey)` | ❌ Wave 0 |
| LIC-02 / SC4 | URLError (offline) → `.unreachable` | unit | fake `URLError(.notConnectedToInternet)` → `.unreachable` | ❌ Wave 0 |
| LIC-02 / SC4 | 500 → `.unreachable` (NOT invalid) | unit | fake 500 → assert `.unreachable` (never `.invalidKey`) | ❌ Wave 0 |
| LIC-02 | completion delivered on main thread | unit | assert `Thread.isMainThread` inside completion | ❌ Wave 0 |
| LIC-02 | request body = `{key, organization_id}` only | unit | `FakeHTTPSession` captures `httpBody`, decode + assert no activation fields | ❌ Wave 0 |
| LIC-02 / SC3 | present granted record → `.licensed` with NO network call | unit | `FakeLicenseStore` seeded; `FakeHTTPSession` asserts it is never called at launch | ❌ Wave 0 |
| LIC-02 | successful validate persists a granted `LicenseRecord` | unit | assert `FakeLicenseStore.write` called with granted record | ❌ Wave 0 |
| LIC-02 / SC3 | offline-after-first-validation end-to-end (real Keychain, real network, airplane mode) | manual on-device | Xcode run: validate real key → quit → airplane mode → relaunch → island visible | manual |
| LIC-01 | Buy Now opens Polar checkout | manual | click Buy Now → browser opens checkout | manual |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (compile gate).
- **Per wave merge:** Cmd-U in Xcode (full XCTest) + `build`.
- **Phase gate:** Cmd-U green + manual on-device (real key paste, airplane-mode relaunch, Buy
  Now) before `/gsd:verify-work`. Also gate a **Release** build (`-configuration Release`) —
  project memory: Release-only crashes (library validation) don't appear in Debug.

### Wave 0 Gaps
- [ ] `PolarLicenseServiceTests.swift` — covers all LIC-02 unit rows above.
- [ ] `FakeHTTPSession` + `FakeLicenseStore` test doubles (shared fixtures).
- [ ] `LicenseStore` protocol seam + in-memory fake (mirror `KeychainStore`).
- [ ] Extend `LicenseStateTests` (if present) for "present granted record → .licensed, no network".

## Security Domain

`security_enforcement` not explicitly disabled → included.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Endpoint is intentionally unauthenticated (public client). No credentials to protect. |
| V3 Session Management | no | No sessions. |
| V4 Access Control | partial | Entitlement gate = presence of a granted Keychain record. Boundary is Keychain ACL + Developer-ID code signing (Phase 13), NOT cryptography (response is unsigned) — documented tradeoff. |
| V5 Input Validation | yes | Pasted key is opaque untrusted input (T-11-03): trim + JSON-encode only; never interpolate into a URL/shell/log. Sent as a JSON body value (no injection surface). |
| V6 Cryptography | no | No hand-rolled crypto. Transport security is TLS via `https://api.polar.sh` (URLSession validates certs by default — do not disable ATS). |
| V7 Error Handling / Logging | yes | Never log the full license key (T-11-03). Log only outcome/status codes. |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Trivially-flippable entitlement bool | Elevation of Privilege | Persist a `Codable` record, not a bool; store in Keychain not UserDefaults (T-11-02). |
| Lockout of a paid key on transient failure | Denial of Service (to the user) | 5xx/URLError → `.unreachable` (retryable); cached record never re-validated (D-01/D-04). |
| License key leaked via logs | Information Disclosure | Treat key as secret input; never log it; `display_key` only in UI if shown. |
| MITM on validate call | Tampering | HTTPS + default ATS cert validation; do not add exceptions for `api.polar.sh`. |
| Shipped org access token | Information Disclosure | Avoided by design — customer-portal endpoint needs no token (D-06); org_id is non-secret (D-05). |

## Project Constraints (from CLAUDE.md)

- Native macOS, Swift + SwiftUI/AppKit; **Swift 5 language mode** on the Xcode 26 / Swift 6.3
  toolchain (avoid strict-concurrency churn — keep the URLSession completion-handler style, not
  forced `async/await` actor isolation).
- **Un-sandboxed, direct-notarized** distribution (Phase 13). No App Store constraints.
- First-time-builder audience: keep the implementation to one readable URLSession call + one
  Keychain store; accompany the important code with explanation.
- Build machine is macOS 26 / Xcode 26 — verify Release build too (library-validation crash
  history).
- Do not add third-party dependencies where a tiny first-party surface suffices (CLAUDE.md:
  "adding a dependency isn't worth it").

## Sources

### Primary (HIGH confidence)
- polar.sh/docs/api-reference/customer-portal/license-keys/validate — endpoint path, method,
  no-auth confirmation, request fields, `ValidatedLicenseKey` response, `status` enum, 404/422.
- github.com/polarsource/polar — `server/polar/license_key/service.py` validate method:
  `ResourceNotFound` (404) for non-granted/expired/not-found; `BadRequest` (400) for usage.
- polar.sh/docs/integrate/sandbox — production `api.polar.sh` vs sandbox `sandbox-api.polar.sh`.
- Islet/Licensing/{LicenseService,LicenseState,TrialManager}.swift — protocol seam, main-thread
  contract, `KeychainTrialStore` pattern, Keychain-cache hot-path lesson.
- Apple developer docs — `URLSession`, `SecItem*`.

### Secondary (MEDIUM confidence)
- polar.apidocumentation.com — license-keys benefit overview; auto-revoke on subscription cancel.
- npmjs.com/package/@polar-sh/sdk, github.com/polarsource/polar-js — confirm no Swift SDK exists.

### Tertiary (LOW confidence)
- WebSearch results on generic Polar 403 `NotPermitted` pattern (Open Question 2) — flagged.

## Metadata

**Confidence breakdown:**
- Standard stack / endpoint contract: HIGH — dual-sourced (official reference + server code).
- Error taxonomy: HIGH on 404/422/200; the exact 403 behavior is the one soft spot (A1/Q2),
  mitigated by a safe default mapping.
- Architecture / Keychain pattern: HIGH — mirrors proven in-project `KeychainTrialStore`.
- Pitfalls: HIGH — two of them are documented project incidents (prompt flood, Release crash).

**Research date:** 2026-07-05
**Valid until:** ~2026-08-05 (Polar API is stable/versioned; re-verify the validate contract
after any major Polar API announcement or a macOS point release).
