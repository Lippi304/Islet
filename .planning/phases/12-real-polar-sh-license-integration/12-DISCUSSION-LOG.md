# Phase 12: Real Polar.sh License Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 12-real-polar-sh-license-integration
**Areas discussed:** Re-validation & Revocation, Device/Activation Limit, Buy Now Target & Polar Setup, Network-Error Behavior & Retry

---

## Re-validation & Revocation

| Option | Description | Selected |
|--------|-------------|----------|
| Validate once, then trust forever | One online validation → Keychain cache → never re-check. Simplest, never locks a paying customer, satisfies "fully offline". Refunds/revoked keys not detected. | ✓ |
| Periodically re-check online | Silent re-validation when online; lock only on explicit revoke, never on network error. Catches refund abuse, more complexity + higher lockout risk. | |

**User's choice:** Validate once, then trust forever.
**Notes:** Accepted tradeoff — refund/revocation detection deferred; fine for a €7.99 hobby app.

---

## Device / Activation Limit

| Option | Description | Selected |
|--------|-------------|----------|
| No limit / validate-only | Key only validated; unlimited Macs per license. Customer-friendly, simple; weak copy-protection. | ✓ |
| Polar activation limit (N devices) | Use Polar activations, e.g. 3 devices/license. Some copy-protection, adds activation handling + a "limit reached" error case. | |

**User's choice:** No limit / validate-only.
**Notes:** Use Polar *validation*, not *activation*. Can be tightened later.

---

## Buy Now Target & Polar Setup

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, Produkt + Checkout-Link existieren | €7.99 product created in Polar; checkout URL available. | ✓ |
| Noch nicht eingerichtet | Polar account/product missing. | |
| Teilweise / unsicher | Account present, product/link/validation access unclear. | |

**User's choice:** Product + checkout link exist.
**Notes:** Buy Now stays unchanged — keeps pointing at `https://lippi304.xyz/projects/islet/buy` (redirects to the real Polar checkout). No UI/URL change this phase. Organization ID provided: `952bfc3a-c29b-4024-bf2e-deded1be5908` (found in Polar → Settings → Organization → "Identifier"). Validation to use the customer-portal validate endpoint (no embedded secret).

---

## Network-Error Behavior & Retry

| Option | Description | Selected |
|--------|-------------|----------|
| Clear message + manual Retry | `.invalidKey` vs `.unreachable` split; Retry button on unreachable; validated key never locked by a network error. Transparent. | ✓ |
| Automatic background retry | App retries silently; less UI, more opaque to the user. | |

**User's choice:** Clear message + manual Retry.
**Notes:** First-time activation needs network; if offline at first activation → unreachable + Retry (unavoidable). Cached (already-validated) key is never locked by network failures.

## Claude's Discretion

- Exact Keychain item schema for the validated license.
- How the `organization_id` is embedded (constant vs build setting).
- URLSession config, timeouts, JSON model shapes (research-informed).

## Deferred Ideas

- Periodic online re-validation + refund/revocation detection (Polar `revoked`/`refunded`).
- Device / activation limits (Polar "activations", N-device caps).
