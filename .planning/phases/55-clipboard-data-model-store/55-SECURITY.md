---
phase: 55
slug: clipboard-data-model-store
status: verified
threats_open: 0
asvs_level: 1
created: 2026-07-22
---

# Phase 55 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|----------------|
| None crossed in this phase | `ClipboardItem`/`ClipboardStore` are pure, synchronous, in-memory Foundation types — no network, no `NSPasteboard`, no `FileManager`, no Keychain, no external input. `append(_:)`'s only caller this phase is a unit test constructing values inline. | None |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-55-01 | Information Disclosure | Future: `ClipboardMonitor` (Phase 57) | accept | `ClipboardStore` has no awareness of where its input originates and cannot itself distinguish sensitive from non-sensitive content — excluding `org.nspasteboard.ConcealedType`/`TransientType` copies (PRIV-01) is Phase 57's responsibility, not this phase's | closed |
| T-55-02 | Denial of Service (self-inflicted, low severity) | `ClipboardStore.append(_:)` — unbounded per-item content size | accept | CONTEXT.md D-03: no size cap or truncation on individual items, by explicit user choice ("revisit only if this becomes a real problem in practice"). The 30-item cap (D-01) still bounds item *count*; only per-item *size* is unbounded | closed |
| T-55-03 | Tampering (encryption at rest) | Future: `ClipboardFileStore` (Phase 56) | accept | `ClipboardStore` never touches disk this phase — no plaintext-at-rest exposure exists yet to mitigate. PRIV-02 (CryptoKit AES-GCM encryption) is Phase 56's responsibility | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

No package-manager installs occurred in this phase (zero new dependencies, Foundation-only) — the Package Legitimacy Gate does not apply.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-55-01 | T-55-01 | Pasteboard-content filtering (concealed/transient types) is out of scope until Phase 57's `ClipboardMonitor` exists — this phase has no pasteboard access at all | user (via CONTEXT.md domain boundary) | 2026-07-22 |
| R-55-02 | T-55-02 | Unbounded per-item content size is a deliberate simplification (D-03); item *count* is still capped at 30 (D-01) | user (via CONTEXT.md D-03) | 2026-07-22 |
| R-55-03 | T-55-03 | No disk I/O exists in this phase — encryption-at-rest is Phase 56's `ClipboardFileStore` responsibility | user (via PLAN.md scope boundary) | 2026-07-22 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-22 | 3 | 3 | 0 | /gsd-secure-phase (user-confirmed accept-all) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-22
