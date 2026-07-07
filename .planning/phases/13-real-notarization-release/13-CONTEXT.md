# Phase 13: Real Notarization & Release - Context

**Gathered:** 2026-07-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the real Developer-ID sign → notarize → staple release pipeline (DIST-01),
replacing the two remaining placeholders in the already-working `scripts/release.sh`
(`DEVELOPER_ID`, `NOTARY_PROFILE`). The script's full mechanics (archive, sign, dmg,
notarize, staple, `spctl` assessment) were already built and dry-run-proven in Phase 0;
this phase is about supplying real credentials and verifying the resulting `.dmg`
passes Gatekeeper.

Out of scope: any application feature work (Phases 10-12, already complete); Sparkle
auto-update; DMG visual polish (background/icon layout) beyond the existing plain
`hdiutil` image; App Store distribution (never in scope — private MediaRemote API).

</domain>

<decisions>
## Implementation Decisions

### Clean-machine Gatekeeper verification (D-01)
- **D-01:** **Same-Mac simulation**, matching Phase 0's D-04 plan — no second Mac or
  fresh user account. Verify by manually applying `com.apple.quarantine` to the built
  `.dmg` (mirroring how a browser download would tag it), then running
  `spctl --assess -vvv --type install` AND actually double-clicking to open it, to
  confirm no "unidentified developer" Gatekeeper warning appears. This is the real
  verification method for success criterion #3 — no second machine is being sourced.

### Product name lock-in (D-02)
- **D-02:** **"Islet" is now the final product name** — the "Product name TBD" flag in
  PROJECT.md's Key Decisions table is resolved as of this phase. Bundle ID
  (`com.lippi304.islet`), display name, and website already all say "Islet"; no rename
  work is needed. (Note for downstream: PROJECT.md's Key Decisions table should be
  updated to reflect this — an evolution/transition-time edit, not a Phase 13 build task.)

### Notary credential auth method (D-03)
- **D-03:** **App-specific password**, not an App Store Connect API key — confirms the
  plan already written in `docs/RELEASE.md`: one-time
  `xcrun notarytool store-credentials "islet-notary"` storing the Apple ID + team ID +
  app-specific password in the local keychain. `release.sh` only ever references the
  profile NAME (`NOTARY_PROFILE`), never a raw credential — nothing secret is committed
  to the repo. This also moots the STATE.md blocker note about `--issuer` flag behavior
  (that only applies to the API-key auth path, which is not being used).

### Claude's Discretion
- The exact `DEVELOPER_ID` identity string (e.g. `"Developer ID Application: Name (TEAMID)"`)
  is obtained by running `security find-identity -v -p codesigning` once the certificate
  exists in Keychain Access — a data-fetching step for the user to run and report back
  during planning/execution, not a decision to make now.
- Whether the filled-in `DEVELOPER_ID`/`NOTARY_PROFILE` values are committed directly into
  `scripts/release.sh` (as the script's existing placeholder-fill design already assumes)
  is left as-is — neither value is a secret (profile name is a keychain lookup key; the
  identity string is not sensitive), so no extra indirection (env vars, gitignored config)
  is needed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing release pipeline (the thing being finished, not rebuilt)
- `scripts/release.sh` — full archive → sign → dmg → notarize → staple flow, already
  written and dry-run-proven; the ONLY changes needed are filling `DEVELOPER_ID` and
  `NOTARY_PROFILE` (lines 22-23) and re-running unchanged (per its own Phase-6/13 comment
  header).
- `docs/RELEASE.md` — plain-language walkthrough already documenting the exact
  `xcrun notarytool store-credentials` app-specific-password setup (D-03) and the
  Phase-0 same-Mac Gatekeeper simulation note (D-01).
- `project.yml` — `CODE_SIGN_STYLE: Automatic`, `CODE_SIGN_IDENTITY: "-"` (dev/Debug stays
  ad-hoc; unaffected by this phase — `release.sh` re-signs the exported `.app` explicitly
  after archiving), `CODE_SIGN_ENTITLEMENTS: Islet/Islet.entitlements`.
- `Islet/Islet.entitlements` — currently only `com.apple.security.cs.disable-library-validation`
  (required for the embedded `MediaRemoteAdapter.framework` under Hardened Runtime, per
  the resolved v1.1 quick-task `260705-mzj`); Hardened Runtime itself is applied via
  `codesign --options runtime` in `release.sh`, not via this entitlements file.

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` §Distribution (DIST-01) — locked requirement text.
- `.planning/ROADMAP.md` §Phase 13 — goal + 3 success criteria (real Developer-ID sign,
  real notarize+staple with no errors, `spctl --assess` "accepted" / no Gatekeeper warning
  on open).
- `.planning/PROJECT.md` §Key Decisions — "Product name TBD" row (resolved by D-02) and
  "Real Developer-ID notarization deferred until a paid Apple Developer account exists"
  row (the account has since been purchased, per PROJECT.md "Current State").

### Prior-phase decisions this phase completes
- `.planning/phases/00-foundations-notarization-dry-run/00-CONTEXT.md` — D-01 through D-05:
  the account-deferral decision (now resolved), the dry-run definition of "done," ad-hoc
  local signing, the no-second-Mac Gatekeeper plan (D-04, reaffirmed here as D-01), and
  the `.dmg` artifact format choice.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/release.sh` — the entire pipeline is already correct and idempotent; branches
  cleanly on whether `DEVELOPER_ID`/`NOTARY_PROFILE` are still placeholders. No script
  rewrite needed, only credential fill-in.
- `docs/RELEASE.md` — already has the exact `xcrun notarytool store-credentials` command
  and app-specific-password guidance ready to follow.

### Established Patterns
- Ad-hoc signing stays the Debug/dev default (`project.yml`); only the release script's
  manual `codesign --sign "${DEVELOPER_ID}"` step (after archiving) uses the real identity
  — no changes to Xcode project signing settings are needed.

### Integration Points
- None new — this phase touches only `scripts/release.sh` placeholder values and the
  local keychain notary profile; no Swift source changes.

</code_context>

<specifics>
## Specific Ideas

- The Gatekeeper "clean" test must include an actual double-click-to-open, not just
  `spctl --assess` output — success criterion #3 explicitly says "opening it... shows no
  warning."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-real-notarization-release*
*Context gathered: 2026-07-07*
