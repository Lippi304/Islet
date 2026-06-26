# Gatekeeper block — local demonstration (Phase 0)

This shows that the **un-notarized, ad-hoc-signed** Islet build produced by
`scripts/release.sh` is **rejected by Gatekeeper** — and explains exactly what
real notarization (Phase 6) will change.

## Why this is done locally (no second Mac)

Gatekeeper only blocks apps that arrive with the **`com.apple.quarantine`**
attribute (i.e. "downloaded from the internet"). The proper test is to download
the app onto a *different, clean* Mac. We don't have a second Mac (decision
**D-04**), so we reproduce the exact same check **on this machine** by:

1. manually adding the `com.apple.quarantine` attribute (simulating a download), and
2. asking Gatekeeper for its verdict with `spctl --assess` (a **read-only**
   assessment — nothing is disabled; `spctl --master-disable` is removed on
   modern macOS and is not used here).

## The build under test

- `dist/Islet.dmg` — 64 KB, built by `scripts/release.sh` (Phase-0 dry run).
- The app inside is **ad-hoc signed** (`codesign -dvv` → `Signature=adhoc`),
  **not** Developer-ID signed and **not** notarized (the script printed
  `SKIPPING notarize + staple — placeholders not filled (Phase 6 step).`).

## The commands (re-runnable)

```bash
# 1. Simulate "downloaded from the internet" by adding the quarantine attribute:
xattr -w com.apple.quarantine \
  "0081;$(printf '%x' $(date +%s));Islet;00000000-0000-0000-0000-000000000000" \
  dist/Islet.dmg

# 2. Confirm the attribute is present:
xattr -p com.apple.quarantine dist/Islet.dmg

# 3. Ask Gatekeeper for its verdict on the DMG (install assessment):
spctl --assess --type install -vvv dist/Islet.dmg ; echo "exit=$?"

# 4. And on the .app (execute assessment):
spctl --assess --type execute -vvv build/export/Islet.app ; echo "exit=$?"
```

## Actual output captured on this machine (macOS 26 "Tahoe", Xcode 26.6)

```
$ xattr -p com.apple.quarantine dist/Islet.dmg
0081;6a3ebacd;Islet;00000000-0000-0000-0000-000000000000

$ spctl --assess --type install -vvv dist/Islet.dmg ; echo "exit=$?"
dist/Islet.dmg: rejected
source=no usable signature
exit=3

$ spctl --assess --type execute -vvv build/export/Islet.app ; echo "exit=$?"
build/export/Islet.app: rejected
exit=3
```

Both assessments return **`rejected`** with a **non-zero exit code (3)**. The DMG
reports `source=no usable signature`.

## Interpretation

`rejected` is the **expected and correct** result here. An **ad-hoc** signature
(`codesign --sign -`) is *not* a Gatekeeper-acceptable signature: it carries no
Developer-ID identity and no notarization ticket, so Gatekeeper refuses to vouch
for it. In other words: the protective control **works** — an un-notarized build
is correctly blocked rather than silently trusted.

## What real notarization will change (deferred — Phase 6)

This is the Phase-0 success-criterion #3 carry-over (decisions **D-01 / D-02**).
Once an Apple Developer account exists, the two placeholders in
`scripts/release.sh` (`DEVELOPER_ID`, `NOTARY_PROFILE`) are filled and the
**same script** is re-run. It will then:

- sign with a real **Developer ID Application** certificate + hardened runtime,
- submit to Apple with `xcrun notarytool submit --wait`, and
- **staple** the notarization ticket with `xcrun stapler staple`.

After that, the same `spctl --assess` command returns:

```
dist/Islet.dmg: accepted
source=Notarized Developer ID
```

and a quarantined copy **opens with no Gatekeeper warning, even offline** (thanks
to the stapled ticket). See `docs/RELEASE.md` for the exact Phase-6 steps.

## Beginner caveat

Gatekeeper's quarantine check fires on the **first GUI launch** (double-clicking
the `.dmg`/`.app` in Finder shows the "unidentified developer / cannot be opened"
dialog). The `spctl --assess` command above gives the same verdict
**headlessly** (no dialog), which is why we use it to capture the result here.

---
*Phase 0 — APP-04 (release dry run + local Gatekeeper demonstration). Real
notarization + clean-Mac open carry to Phase 6 (D-01/D-02/D-04).*
