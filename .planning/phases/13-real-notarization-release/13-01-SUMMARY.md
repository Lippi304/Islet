---
phase: 13-real-notarization-release
plan: 01
subsystem: infra
tags: [codesign, notarytool, gatekeeper, xcodebuild, hdiutil]

requires:
  - phase: 00-foundations-notarization-dry-run
    provides: dry-run-proven scripts/release.sh (archive→sign→dmg→notarize→staple flow, ad-hoc placeholders)
provides:
  - Real Developer-ID signed, notarized, and stapled release pipeline (DIST-01 complete)
  - Fixed notarytool submission bug (raw .app dirs must be zipped first)
  - Fixed nested-framework signing bug (embedded frameworks need explicit re-signing, not --deep)
affects: [release, distribution, future-phases-touching-scripts/release.sh]

tech-stack:
  added: []
  patterns: ["inside-out codesign of embedded frameworks before the outer .app", "ditto -c -k --keepParent zip for notarytool submission"]

key-files:
  created: []
  modified: [scripts/release.sh]

key-decisions:
  - "DEVELOPER_ID stored as the SHA-1 identity hash (not the 'Developer ID Application: Name (TEAMID)' string) — equally valid for codesign --sign and unambiguous"
  - "Same-Mac Gatekeeper simulation (D-01): xattr quarantine tag + spctl --assess + manual double-click, no second Mac needed"

patterns-established:
  - "Nested embedded frameworks must be explicitly re-signed with the real Developer ID before the outer .app — codesign does not recurse and --deep is deprecated/unreliable"

requirements-completed: [DIST-01]

duration: ~35min
completed: 2026-07-08
---

# Phase 13: Real Notarization & Release Summary

**scripts/release.sh now produces a genuinely Developer-ID signed, Apple-notarized, stapled .dmg — confirmed Gatekeeper-clean via quarantine-tag simulation and a real double-click open.**

## Performance

- **Duration:** ~35 min (credential setup + 3 pipeline iterations to find and fix 2 real bugs)
- **Completed:** 2026-07-08
- **Tasks:** 3/3 (1 human-action checkpoint, 1 automated, 1 human-verify checkpoint)
- **Files modified:** 1 (`scripts/release.sh`)

## Accomplishments
- Real `DEVELOPER_ID`/`NOTARY_PROFILE` credentials filled in; no ad-hoc/placeholder signing remains.
- Found and fixed two real bugs surfaced only by a live (non-dry-run) pipeline run:
  1. `notarytool submit` rejects a raw `.app` directory — needs a `.zip`/`.pkg`/`.dmg`.
  2. Embedded `MediaRemoteAdapter.framework` kept Xcode's ad-hoc archive signature — notarization
     rejected it until explicitly re-signed with the real Developer ID before the outer `.app`.
- `dist/Islet.dmg` notarized + stapled (both the `.app` and the `.dmg` get their own ticket, per
  Apple's two-staple flow), verified via `spctl --assess` on a synthetically quarantine-tagged copy,
  and confirmed via a real double-click open showing no Gatekeeper "unidentified developer" warning.

## Task Commits

1. **Task 1: Obtain Developer ID certificate + notary profile** — human checkpoint, no commit (credentials live only in local keychain, per D-03).
2. **Task 2: Fill credentials, run pipeline, fix notarization bugs** — `88e84aa` (feat)
3. **Task 3: Confirm no Gatekeeper warning on double-click** — human-verify checkpoint, confirmed by user; no commit.

## Files Created/Modified
- `scripts/release.sh` — credentials filled; added zip-before-submit and nested-framework-signing fixes.

## Decisions Made
- Used the SHA-1 identity hash as `DEVELOPER_ID` rather than the `"Developer ID Application: Name (TEAMID)"` string — both are valid `codesign --sign` arguments; the hash is unambiguous.

## Deviations from Plan

### Auto-fixed Issues

**1. [Real-run gap] notarytool rejects raw .app submission**
- **Found during:** Task 2 (first live pipeline run)
- **Issue:** `xcrun notarytool submit "${APP_PATH}"` failed — notarytool only accepts .zip/.pkg/.dmg, not a bare .app directory. The dry-run-proven script never exercised this path for real.
- **Fix:** Zip the .app with `ditto -c -k --keepParent` before submission, submit the zip, then staple the original .app (stapling targets the .app, not the zip).
- **Files modified:** `scripts/release.sh`
- **Verification:** Re-ran pipeline; submission succeeded, reached `notarytool` processing.
- **Committed in:** `88e84aa`

**2. [Real-run gap] Embedded framework fails notarization (ad-hoc signature)**
- **Found during:** Task 2 (second live pipeline run — notarization returned "Invalid" with two errors on `MediaRemoteAdapter`: not signed with a valid Developer ID, no secure timestamp)
- **Issue:** Xcode's archive step ad-hoc-signs embedded frameworks; the script's outer `codesign --sign "${DEVELOPER_ID}"` (deliberately without `--deep`) never re-signed the nested framework, so it kept Xcode's ad-hoc signature.
- **Fix:** Explicitly enumerate and re-sign every `*.framework` under `Contents/Frameworks` with the real Developer ID + hardened runtime + secure timestamp, before signing the outer `.app` (inside-out order, per Apple's own guidance).
- **Files modified:** `scripts/release.sh`
- **Verification:** Re-ran pipeline; notarization returned "Accepted" for both the `.app` and the `.dmg`; `spctl --assess` reported "accepted"/"Notarized Developer ID"; manual double-click open showed no Gatekeeper warning.
- **Committed in:** `88e84aa`
