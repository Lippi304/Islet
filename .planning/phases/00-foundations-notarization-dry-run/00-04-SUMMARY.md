---
phase: 00-foundations-notarization-dry-run
plan: 04
subsystem: infra
tags: [release, dmg, gatekeeper, spctl, quarantine, codesign, adhoc, notarization-dry-run]

# Dependency graph
requires:
  - phase: 00-foundations-notarization-dry-run
    provides: "Plan 03 scripts/release.sh + Plans 01/02 the finished Islet app (the script archives the Islet scheme)"
provides:
  - "Verified end-to-end Phase-0 release dry run: scripts/release.sh produces dist/Islet.dmg (ad-hoc, notarize/staple skipped)"
  - "docs/GATEKEEPER-DEMO.md — recorded quarantine + spctl --assess block (real output) and the Phase-6 notarization carry-over"
affects: [phase-6-release (fills the two placeholders, runs real notarization + clean-Mac open)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Local Gatekeeper demonstration: com.apple.quarantine via xattr + read-only spctl --assess (no second Mac, D-04)"

key-files:
  created:
    - "docs/GATEKEEPER-DEMO.md"
  modified:
    - ".gitignore (repaired — see Deviations)"
  runtime-artifacts:
    - "dist/Islet.dmg (git-ignored; produced by the script, not committed)"

key-decisions:
  - "Did NOT run real notarization (no Apple Developer account — D-01); confirmed the script's skip path fires"
  - "Demonstrated the Gatekeeper BLOCK locally via quarantine + spctl --assess (D-04, no second Mac); spctl --master-disable is removed and not used"

patterns-established:
  - "spctl --assess is the headless way to read Gatekeeper's verdict; rejected == correct for ad-hoc/un-notarized"

requirements-completed: [APP-04]

# Metrics
duration: ~15min
completed: 2026-06-26
---

# Phase 00 Plan 04: Release dry-run + local Gatekeeper demonstration Summary

**`scripts/release.sh` ran end-to-end to produce an ad-hoc-signed `dist/Islet.dmg` (notarize/staple cleanly skipped), and the local Gatekeeper block was demonstrated and recorded: the quarantined, un-notarized build is `rejected` by `spctl --assess` — with the real Phase-6 notarization carry-over documented.**

## Accomplishments
- Ran `bash scripts/release.sh`: **ARCHIVE SUCCEEDED** → ad-hoc sign (`Signature=adhoc`, "No Developer ID set: AD-HOC signing") → `hdiutil` DMG → printed `SKIPPING notarize + staple — placeholders not filled (Phase 6 step).` and exited 0. No real notarization attempted (D-01).
- Verified artifacts: `dist/Islet.dmg` (64 KB) exists; `build/export/Islet.app` is valid ad-hoc-signed (`codesign --verify` passes, `Signature=adhoc`).
- Ran the local Gatekeeper demo (quarantine + `spctl --assess`) and captured the **real** verdict on this macOS 26 machine:
  - `dist/Islet.dmg: rejected` / `source=no usable signature` / exit 3
  - `build/export/Islet.app: rejected` / exit 3
- Wrote `docs/GATEKEEPER-DEMO.md` with the why-local rationale (D-04), the four re-runnable commands, the actual captured output, the interpretation (rejected == correct for ad-hoc), and what real notarization changes at Phase 6.
- Human checkpoint (Task 3): user **approved** — DMG present, demo doc correct, matches the D-02 definition of done.

## Task Commits
1. **Tasks 1+2 (run release.sh + Gatekeeper demo + GATEKEEPER-DEMO.md)** — `8f5700d` (feat). (dist/Islet.dmg is git-ignored — a runtime artifact, not committed.)
2. **.gitignore repair** — `(committed separately)` fix(00-04).

## Deviations from Plan

**1. [Bug fix — 00-03 carry-over] Repaired .gitignore so build/ and dist/ are actually ignored**
- **Found during:** Task 1 verification — `git status` showed `build/` and `dist/` as untracked; `git check-ignore` confirmed they were NOT ignored.
- **Root cause:** The 00-03 `.gitignore` used inline trailing comments (`build/    # comment`). Git only treats `#` as a comment at the START of a line, so the `# comment` became part of the pattern and matched nothing. The 00-03 verify only `grep`'d for substring presence, so it passed despite the patterns being broken.
- **Fix:** Rewrote `.gitignore` with bare patterns and full-line comments; verified with `git check-ignore -q` that `build/`, `dist/`, `DerivedData/`, and `dist/Islet.dmg` are all ignored.
- **Impact:** Restores the APP-04 must-have "dist/ is git-ignored" (and prevents the 64 KB DMG / build output from being accidentally committed).

**2. [Environment note] hdiutil deprecation warning on macOS 26**
- `hdiutil create` printed a deprecation warning ("use 'diskutil image create' instead") on macOS 26 but **still produced the DMG successfully**. Left as-is for Phase 0 (the script matches RESEARCH Pattern 4); migrating to `diskutil image create` is a noted Phase-6 polish option.

**Total deviations:** 1 bug fix (gitignore), 1 environment note. No scope creep.

## User Setup Required
None for Phase 0. Phase 6: enroll in the Apple Developer Program, fill `DEVELOPER_ID` + `NOTARY_PROFILE` in `scripts/release.sh`, re-run (see docs/RELEASE.md), and open on a clean second Mac.

## Next Phase Readiness
- Phase 0 release toolchain is proven end-to-end as a re-runnable script. The real notarization + clean-Mac open are the documented Phase-6 carry-over (D-01/D-02/D-04).

## Self-Check: PASSED

- FOUND: docs/GATEKEEPER-DEMO.md (spctl --assess, quarantine, rejected, D-04, notarization-change all present)
- VERIFIED: dist/Islet.dmg produced (64 KB, ad-hoc); script printed SKIPPING notarize + staple
- VERIFIED: .gitignore now ignores build/ + dist/ (git check-ignore)
- FOUND commit: 8f5700d

---
*Phase: 00-foundations-notarization-dry-run*
*Completed: 2026-06-26*
