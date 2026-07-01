---
phase: 06-priority-resolver-settings-v1-ship
plan: 12
subsystem: release-pipeline
tags: [release, notarization, scripts]
dependency-graph:
  requires: []
  provides: [app-level-staple, accurate-dry-run-banner]
  affects: [scripts/release.sh]
tech-stack:
  added: []
  patterns: [gated-notarize-staple-block]
key-files:
  created: []
  modified:
    - scripts/release.sh
decisions:
  - "Notarize+staple the .app immediately after Step 3's codesign (before Step 4 copies it into the DMG staging folder), reusing the exact same DEVELOPER_ID/NOTARY_PROFILE placeholder gate as the existing DMG-level block — Apple's standard two-staple flow for DMG distribution."
  - "SIGN_DESC variable computed inside the existing SKIP-banner if-block: preserves the exact original 'ad-hoc signed, NOT notarized' text when DEVELOPER_ID is unfilled, and introduces a new distinct message when DEVELOPER_ID is filled but NOTARY_PROFILE is not."
metrics:
  duration: "~15 min"
  completed: 2026-07-01
---

# Phase 6 Plan 12: Release pipeline app-staple + accurate dry-run banner Summary

One-liner: Stapled the exported .app before DMG packaging (Apple's two-staple flow) and made the dry-run SKIP banner's signing-state text reflect whether DEVELOPER_ID was actually filled in.

## What Was Built

Two targeted, surgical fixes to `scripts/release.sh` (Phase-0 gap-closure findings 17 and 18), plus a checkpoint task that runs the actual dry-run pipeline to confirm zero regression.

**Task 1 — App-level notarize + staple (Finding 17):**
Added a new gated block immediately after Step 3's `codesign --verify --verbose "${APP_PATH}"`,
before Step 4 copies the .app into the DMG staging folder:

```bash
if [ "${DEVELOPER_ID}" != "__DEVELOPER_ID__" ] && [ "${NOTARY_PROFILE}" != "__NOTARY_PROFILE__" ]; then
  xcrun notarytool submit "${APP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
fi
```

This is the SAME two-placeholder gate as the existing Step 6 DMG-level block, so it stays a
no-op in the current dry-run environment (no Developer-ID account yet — D-15 carry-over
unchanged) and only activates once both placeholders are filled at the real Phase-6 run. The
existing Step 6 DMG-level `xcrun notarytool submit "${DMG_PATH}"` / `xcrun stapler staple
"${DMG_PATH}"` block is untouched — the DMG still gets its own separate notarize+staple pass,
per Apple's documented requirement that a DMG is a distinct artifact from the .app inside it.

**Task 2 — Accurate dry-run banner (Finding 18):**
Replaced the hardcoded `"(ad-hoc signed, NOT notarized)"` echo inside Step 6's SKIP block with a
computed `SIGN_DESC` variable:
- `DEVELOPER_ID` still the placeholder → `"ad-hoc signed, NOT notarized"` (unchanged text, exact
  regression-safe match).
- `DEVELOPER_ID` filled but `NOTARY_PROFILE` still the placeholder → new distinct message:
  `"signed with Developer ID ${DEVELOPER_ID}, NOT notarized — NOTARY_PROFILE still unfilled"`.

**Task 3 — Checkpoint: dry-run pipeline verification (automation performed by executor):**
Per the automation-first checkpoint policy, the executor ran `bash scripts/release.sh` directly
(no user CLI action required) and captured full output. Results:

1. Exit code 0. Confirmed via background task output (`EXIT_CODE=0`).
2. SKIP banner text is byte-for-byte unchanged from before this plan:
   `Phase-0 dry run complete: dist/Islet.dmg (ad-hoc signed, NOT notarized).` — regression-safe,
   confirms the placeholder-unfilled branch of the new `SIGN_DESC` logic produces identical output
   to the old hardcoded string.
3. `dist/Islet.dmg` exists after the run (635889 bytes, confirmed via `ls -la`).
4. `grep -n "notarytool\|stapler" <full run log>` returned **zero matches** — confirms BOTH the new
   .app-level block and the existing DMG-level block stayed gated off in dry-run; neither
   `xcrun notarytool` nor `xcrun stapler` was invoked.
5. Item 4 of the checkpoint's `<how-to-verify>` (real notarized .app/DMG verification via
   `spctl --assess`) is N/A — no Apple Developer account exists yet (D-15 carry-over, unchanged
   by this plan).

The generated `dist/Islet.dmg` and `build/` artifacts are gitignored (confirmed in `.gitignore`)
and were not committed — consistent with the existing repo convention that these are
regenerated, not tracked.

## Deviations from Plan

None — plan executed exactly as written. Two-commit split (one per task) matches the plan's task
structure; Task 3's automation was performed directly by the executor per the checkpoint
protocol's automation-first policy (users never run CLI commands — the executor ran the dry-run
and gathered all evidence needed for the human-verify confirmation).

## Known Stubs

None.

## Threat Flags

None — this plan's own `<threat_model>` (T-06-20, disposition: accept) already covers the only
change: an additional notarize+staple invocation reusing the existing keychain-profile-name
mechanism. No new secret handling, no new network call type, no new trust boundary introduced.

## Self-Check

- `scripts/release.sh` exists and contains both fixes: FOUND (verified via grep, see below).
- Commit `1022a62` (Task 1: app-level notarize+staple): FOUND in `git log`.
- Commit `d7f86f7` (Task 2: accurate dry-run banner): FOUND in `git log`.
- `dist/Islet.dmg` produced by the live dry-run: FOUND (635889 bytes).

## Self-Check: PASSED

## Checkpoint Status

**Task 3 is a `checkpoint:human-verify` gate.** All automation has been performed and all
evidence gathered (items 1-3 of `<how-to-verify>` PASS; item 4 is N/A per the plan's own
allowance). Per GSD checkpoint protocol, this plan pauses here for explicit human confirmation
("approved") before the plan is considered fully complete. See the CHECKPOINT REACHED message
returned alongside this SUMMARY for full details.
