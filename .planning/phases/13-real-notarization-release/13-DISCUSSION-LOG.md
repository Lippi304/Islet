# Phase 13: Real Notarization & Release - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-07
**Phase:** 13-real-notarization-release
**Areas discussed:** Clean-machine Gatekeeper test, Product name lock-in, Notary credential setup

---

## Clean-machine Gatekeeper test

| Option | Description | Selected |
|--------|-------------|----------|
| Same-Mac simulation | Set com.apple.quarantine on the built DMG on this Mac, then run spctl --assess + actually double-click-open it — matches Phase 0 (D-04) | ✓ |
| I have a real second Mac | Physically transfer the stapled DMG to another Mac and open it fresh there | |
| Fresh macOS user account here | Create a new local user account on this Mac and open the DMG from there | |

**User's choice:** Same-Mac simulation (Recommended)
**Notes:** No second Mac or fresh account needed — mirrors Phase 0's D-04 plan.

---

## Product name lock-in

| Option | Description | Selected |
|--------|-------------|----------|
| Lock in 'Islet' now | Drop the TBD flag — bundle ID, display name, and website already all say "Islet" | ✓ |
| Keep it a placeholder | Ship this release still under "Islet" mechanically but leave the name formally undecided | |

**User's choice:** Lock in 'Islet' now (Recommended)
**Notes:** PROJECT.md's Key Decisions table "Product name TBD" row should be updated at the next transition/evolution point.

---

## Notary credential setup

| Option | Description | Selected |
|--------|-------------|----------|
| Keep app-specific password | Already fully documented and scripted — one keychain profile, no .p8 key file | ✓ |
| Switch to API key | App Store Connect API key (issuer ID + key ID + .p8 file) — more setup, unverified --issuer behavior | |

**User's choice:** Keep app-specific password (Recommended)
**Notes:** Confirms the plan already written in docs/RELEASE.md; moots the STATE.md blocker note about --issuer flag behavior (API-key-only concern).

---

## Claude's Discretion

- Exact `DEVELOPER_ID` identity string retrieval (`security find-identity -v -p codesigning`) — a data-fetch step, not a decision.
- Keeping filled-in placeholder values directly in `scripts/release.sh` rather than moving to env vars/gitignored config — neither value is a secret.

## Deferred Ideas

None — discussion stayed within phase scope.
