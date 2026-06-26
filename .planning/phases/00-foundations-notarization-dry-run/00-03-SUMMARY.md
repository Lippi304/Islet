---
phase: 00-foundations-notarization-dry-run
plan: 03
subsystem: infra
tags: [codesign, notarytool, stapler, hdiutil, gatekeeper, dmg, release, bash, gitignore]

# Dependency graph
requires:
  - phase: 00-foundations-notarization-dry-run
    provides: "Plan 01 defines the Islet scheme / bundle id the release script targets (script reads only the scheme name + output paths, no Swift source)"
provides:
  - "scripts/release.sh — re-runnable archive→sign→dmg→notarize→staple pipeline with placeholder-gated Developer-ID/notary steps and an ad-hoc fallback"
  - ".gitignore — ignores build/, DerivedData/, dist/, *.xcuserstate (Xcode + release artifacts)"
  - "docs/RELEASE.md — beginner-facing guide to the dry run and the deferred Phase-6 notarization steps"
affects: [00-04 (runs release.sh + Gatekeeper demo), phase-6-release (fills the two placeholders and runs real notarization)]

# Tech tracking
tech-stack:
  added: []  # all first-party macOS CLI tools (xcodebuild, codesign, hdiutil, notarytool, stapler) — no new dependencies
  patterns:
    - "Placeholder-gated release script: Developer-ID + keychain notary-profile name are __PLACEHOLDER__ vars at the top; unchanged script runs ad-hoc now and notarized at Phase 6"
    - "ditto (not cp -r) for staging .app bundles into the DMG to preserve framework symlinks"
    - "No secrets in repo: script references a keychain NOTARY_PROFILE name only (created via notarytool store-credentials)"

key-files:
  created:
    - "scripts/release.sh"
    - ".gitignore"
    - "docs/RELEASE.md"
  modified: []

key-decisions:
  - "Used hdiutil (UDZO) for the DMG — create-dmg is not installed; hdiutil ships with macOS (RESEARCH open question 2)"
  - "Ad-hoc fallback signs with codesign --sign - and exits 0 after a loud SKIP message so a dry-run DMG can never be mistaken for a shippable release (D-02/D-03, threat T-00-08)"
  - "Real notarize+staple steps are written but gated behind both placeholders — deferred to Phase 6 per D-01"

patterns-established:
  - "Release script self-detects unfilled placeholders and degrades to ad-hoc + skip rather than failing"
  - "Hardened runtime + --timestamp on every Developer-ID codesign call (mandatory for notarization — Pitfall 4)"

requirements-completed: [APP-04]

# Metrics
duration: 3min
completed: 2026-06-26
---

# Phase 00 Plan 03: Release pipeline + .gitignore + RELEASE.md Summary

**A single commented `scripts/release.sh` runs archive→sign→hdiutil-dmg→notarize→staple, with Developer-ID/notary steps gated behind two clearly-marked placeholders and an ad-hoc fallback that skips notarization cleanly — runnable now, unchanged at Phase 6.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-26T13:40:06Z
- **Completed:** 2026-06-26T13:42:56Z
- **Tasks:** 3
- **Files modified:** 3 (all created)

## Accomplishments
- Wrote `scripts/release.sh`: the full, commented sign→dmg→notarize→staple pipeline with placeholder-gated Developer-ID + keychain notary-profile variables and an ad-hoc (`codesign --sign -`) fallback that SKIPS notarize/staple with a loud message (Phase-0 dry run; real run is the Phase-6 carry-over).
- Added `.gitignore` covering Xcode build output (`build/`, `DerivedData/`, `*.xcuserstate`, `xcuserdata/`) and the release-artifact `dist/` folder, plus `.DS_Store`.
- Wrote `docs/RELEASE.md`: a first-time-programmer guide to the Phase-0 dry run, the two Phase-6 placeholders, the `notarytool store-credentials` keychain setup, and what notarization changes.

## Script step order (scripts/release.sh)

1. **Config + placeholders** — `DEVELOPER_ID` and `NOTARY_PROFILE` default to `__DEVELOPER_ID__` / `__NOTARY_PROFILE__`; all output paths derived from `APP_NAME=Islet`.
2. **Clean + archive** — `rm -rf build dist`; `xcodebuild -scheme Islet -configuration Release archive`.
3. **Export** — `ditto` the `.app` out of `Products/Applications` (not `cp -r`).
4. **Sign the app** — ad-hoc (`codesign --force --deep --sign -`) when no Developer ID, else `codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID"`; then `codesign --verify`.
5. **Build the DMG** — `ditto` stage into `build/dmgroot`, then `hdiutil create -volname Islet -format UDZO -ov dist/Islet.dmg`.
6. **Sign the DMG** — only when a real Developer ID is set.
7. **Notarize gate** — if either placeholder is unfilled: print SKIP message, `exit 0`. Otherwise run `xcrun notarytool submit --keychain-profile --wait`, `xcrun stapler staple`, `spctl --assess`.

## Placeholder / ad-hoc-fallback design

- The two variables the user fills at Phase 6 are `DEVELOPER_ID` (e.g. `"Developer ID Application: Your Name (TEAMID)"`) and `NOTARY_PROFILE` (e.g. `"islet-notary"`, a keychain credential name).
- While either is at its `__PLACEHOLDER__` default the script signs ad-hoc and exits 0 after the SKIP banner — never fails, never produces a DMG that looks shippable.
- The same script, unchanged, performs a real notarized build once both placeholders are filled. See `docs/RELEASE.md`.

## Task Commits

1. **Task 1: Add the Xcode-artifact .gitignore** — `81416de` (chore)
2. **Task 2: Write the re-runnable scripts/release.sh** — `eb0fc0c` (feat)
3. **Task 3: Write docs/RELEASE.md** — `357150f` (docs)

## Files Created/Modified
- `scripts/release.sh` (executable, mode 100755) — the full release pipeline with placeholders + ad-hoc fallback.
- `.gitignore` — ignores Xcode build output and the `dist/` release folder.
- `docs/RELEASE.md` — beginner guide to the dry run and the deferred Phase-6 notarization.

## Decisions Made
- `hdiutil`/UDZO for the DMG (create-dmg absent on this machine); noted as a Phase-6 polish option in RELEASE.md.
- Ad-hoc path exits 0 with a loud SKIP banner instead of erroring, so the dry-run artifact is unmistakably non-shippable (mitigates threat T-00-08).
- Real notarize+staple lines are present but gated — deferred to Phase 6 (D-01), not run here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Reworded two comments so the script body never contains the literal `cp -r`**
- **Found during:** Task 2 (release.sh)
- **Issue:** The plan's commented sections referenced `cp -r` inside explanatory text (e.g. "NOT `cp -r`"). The acceptance criterion / verifier asserts the script does NOT contain `cp -r` for staging; a literal `grep "cp -r"` would false-positive on the teaching comments.
- **Fix:** Rephrased the two comments to "a recursive copy" / removed the literal token while preserving the teaching point. The actual staging commands already used `ditto`.
- **Files modified:** scripts/release.sh
- **Verification:** `grep -q "cp -r" scripts/release.sh` now returns no match; `grep -q "ditto"` still matches; `bash -n` passes.
- **Committed in:** eb0fc0c (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing-critical/verifier-alignment).
**Impact on plan:** Comment-only rewording to satisfy the negative-grep acceptance criterion; behavior unchanged, no scope creep.

## Issues Encountered
- The SECURITY comment in `release.sh` line 28 ("No Apple ID, password, or app-specific password ever appears in this file…") and the `docs/RELEASE.md` "app-specific password" guidance both legitimately contain the word "password." These are explicit T-00-06 mitigation/disclaimer text, not plaintext secrets — no real credential, Apple ID, or Team ID value is present (only `you@example.com` / `TEAMID1234` example placeholders). Kept intentionally.

## User Setup Required
None for Phase 0. At Phase 6 the user must: enroll in the Apple Developer Program, create a Developer ID Application certificate, run `xcrun notarytool store-credentials "islet-notary" --apple-id … --team-id …`, then fill the two placeholders in `scripts/release.sh`. Full instructions in `docs/RELEASE.md`.

## Next Phase Readiness
- Plan 04 can now run `bash scripts/release.sh` against the finished app to produce `dist/Islet.dmg` and perform the local quarantine + `spctl --assess` Gatekeeper demo (D-04).
- Plan 04 depends on the built Islet app existing (Plans 01/02). This plan (03) had no source-code dependency and is complete.
- Real notarization remains the documented Phase-6 carry-over (D-01/D-02).

## Self-Check: PASSED

- FOUND: scripts/release.sh
- FOUND: .gitignore
- FOUND: docs/RELEASE.md
- FOUND: .planning/phases/00-foundations-notarization-dry-run/00-03-SUMMARY.md
- FOUND commits: 81416de, eb0fc0c, 357150f

---
*Phase: 00-foundations-notarization-dry-run*
*Completed: 2026-06-26*
