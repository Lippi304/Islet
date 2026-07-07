# Phase 13: Real Notarization & Release - Pattern Map

**Mapped:** 2026-07-07
**Files analyzed:** 2 (both modified, none new)
**Analogs found:** 2 / 2 (both are self-analogs — the file already contains its own completion pattern)

This phase has no new files and no Swift source changes. Both target files are
existing, well-commented artifacts that already document exactly what needs to
change. The "analog" for each edit is the file's own surrounding structure —
there is nothing else in the repo to model this on, and nothing else is needed.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `scripts/release.sh` | config (shell script, credential placeholders) | batch (build pipeline) | itself — placeholder-fill design already built for this exact edit | exact (self-contained) |
| `.planning/PROJECT.md` (Key Decisions table) | docs/config (planning table row) | CRUD (update one row) | itself — existing "Product name TBD" row + adjacent resolved-decision rows | exact (self-contained) |

## Pattern Assignments

### `scripts/release.sh` (config, batch)

**Analog:** itself, lines 21-29 (the placeholder block) + lines 72-82, 97-100, 121-124, 136-153 (the six conditional branches keyed on whether placeholders are filled)

**The only required edit** — replace the two placeholder values (lines 21-24):
```bash
# >>> FILL THESE IN AT PHASE 6 (leave as-is for the Phase-0 dry run) >>>
DEVELOPER_ID="__DEVELOPER_ID__"     # e.g. "Developer ID Application: Your Name (TEAMID)"
NOTARY_PROFILE="__NOTARY_PROFILE__" # e.g. "islet-notary"  (see docs/RELEASE.md)
# <<< FILL THESE IN AT PHASE 6 <<<
```
becomes (values obtained via `security find-identity -v -p codesigning` for
`DEVELOPER_ID`, and whatever name was used in
`xcrun notarytool store-credentials "<name>" --apple-id ... --team-id ...` for
`NOTARY_PROFILE`, per D-03/docs/RELEASE.md):
```bash
DEVELOPER_ID="Developer ID Application: <Real Name> (<TEAMID>)"
NOTARY_PROFILE="islet-notary"
```

**Nothing else in the script changes.** All six `if [ "${DEVELOPER_ID}" = "__DEVELOPER_ID__" ]` /
`[ "${NOTARY_PROFILE}" = "__NOTARY_PROFILE__" ]` branches (lines 72, 97, 121, 136,
142) already flip correctly the moment both values are real strings — this is
the script's existing self-describing design (see header comment lines 8-19).
Per CONTEXT.md's Claude's-Discretion note, committing the real values directly
in the script (no env-var indirection, no gitignored config) is correct since
neither value is secret: `NOTARY_PROFILE` is a keychain lookup key, and
`DEVELOPER_ID` is a public certificate string.

**Verification pattern already encoded in the script** (lines 155-164, D-01):
```bash
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${DMG_PATH}"
spctl --assess -vvv --type install "${DMG_PATH}"
```
D-01 (same-Mac Gatekeeper simulation) adds one manual step NOT in the script —
tag the DMG with quarantine before re-running `spctl`, then physically
double-click to open it:
```bash
xattr -w com.apple.quarantine "0081;$(printf '%x' $(date +%s));Safari;" dist/Islet.dmg
spctl --assess -vvv --type install dist/Islet.dmg
open dist/Islet.dmg   # then double-click Islet.app inside — confirm no "unidentified developer" warning
```

---

### `.planning/PROJECT.md` (docs, table-row update — D-02)

**Scope note:** this pattern is informational only. 13-01-PLAN.md's objective
explicitly excludes this edit from Phase 13 build scope (it's deferred to a
future `/gsd-transition`/milestone-close step) — do not apply this pattern as
an in-phase task target.

**Analog:** itself, line 152 — the immediately-preceding row shows the exact
resolved-decision phrasing convention this project uses:
```
| Real Developer-ID notarization deferred until a paid Apple Developer account exists ($99/yr) | Explicit budget constraint (CLAUDE.md); dry-run pipeline proves the mechanics without the cost | Accepted, formally overridden in `06-VERIFICATION.md` — revisit before any public v1.0 release |
```

**Row to update** (line 144, currently):
```
| Product name TBD | "Notch" is a working title only; real name decided closer to release | — Still pending — decide before public release |
```
Follow the same three-column convention (Decision / Rationale / Outcome) to
mark it resolved, e.g.:
```
| Product name TBD | "Notch" is a working title only; real name decided closer to release | ✓ Resolved Phase 13 — "Islet" is final; bundle ID, display name, and website already reflect it |
```
This is an evolution/transition-time edit per D-02 (not a build task) — apply
the same `✓ Resolved ...` / `✓ Phase N ...` style already used by every other
closed row in the table (lines 139-143, 145-151, 153-155).

## Shared Patterns

None — this phase touches two independent, unrelated files (a shell script and
a markdown table); there is no cross-cutting code pattern to share between
them.

## No Analog Found

None. Both files already contain, in their own existing text, the exact
pattern the edit must follow — no external codebase search was needed or
useful (ladder rung 2: reuse what's already here).

## Metadata

**Analog search scope:** `scripts/release.sh`, `docs/RELEASE.md`, `.planning/PROJECT.md` (read in full — all ≤ 165 lines, single-pass reads, no re-reads)
**Files scanned:** 3 read, 2 identified as edit targets
**Pattern extraction date:** 2026-07-07
