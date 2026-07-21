# Releasing Islet — a beginner's guide

This explains how `scripts/release.sh` turns the app into a downloadable
`.dmg`, and what is left to do later. You do **not** need to understand every
command — just know what to run and which two blanks to fill in eventually.

---

## What this is

`scripts/release.sh` is the **one script** that builds a distributable disk
image (`dist/Islet.dmg`). It runs in two situations:

- **Now (Phase 0)** — no Apple Developer account yet. The script signs the app
  **ad-hoc** (good enough to test locally) and **skips** the Apple
  "notarization" steps. This proves the whole pipeline works on a hello-world
  build, so nothing is left to discover at ship time.
- **Later (Phase 6)** — once you buy the $99/yr Apple Developer Program
  account (deferred on purpose — decision **D-01**), you fill in two blanks at
  the top of the script and run **the exact same script** to produce a real,
  Apple-blessed download.

The script is heavily commented — open it and read along.

---

## Run the Phase-0 dry run

From the repo root:

```bash
bash scripts/release.sh
```

What you should see:

1. Xcode archives a Release build.
2. The app is copied out and **ad-hoc signed** (you'll see a line like
   `-> No Developer ID set: AD-HOC signing for local dry-run (D-03).`).
3. A disk image is created at `dist/Islet.dmg`, styled like a normal macOS
   installer window: the Islet icon, an arrow, and an Applications-folder
   shortcut to drag it into — built via `scripts/generate-dmg-background.swift`
   (a plain AppKit-drawn background image, no extra tools) plus a Finder
   AppleScript step in `scripts/release.sh` that positions the icons. If you
   ever need to change the window size or icon positions, the 5 constants are
   duplicated at the top of both files with a comment pointing at the other —
   keep them in sync.
4. A loud message tells you notarize/staple were **SKIPPED** because the
   placeholders aren't filled, and that the DMG is **NOT notarized**.

That skipped message is intentional: it makes sure a dry-run DMG can never be
mistaken for a real, shippable release.

---

## The two placeholders to fill at Phase 6

Open `scripts/release.sh`. Near the top, between the `>>> FILL THESE IN >>>`
markers, are two variables. They are the **only** things you change:

### 1. `DEVELOPER_ID`

The code-signing certificate that says "this app is really from you." It looks
like:

```
Developer ID Application: Your Name (TEAMID1234)
```

You get it after enrolling in the Apple Developer Program and creating a
"Developer ID Application" certificate (Xcode → Settings → Accounts → Manage
Certificates, or on the Apple Developer website). Paste the full string between
the quotes.

### 2. `NOTARY_PROFILE`

A **name** that points at your saved Apple notary login — stored safely in the
macOS keychain, **never in this repo**. You create it **once** with this exact
command (copy it verbatim, then change the email and team id to yours):

```bash
xcrun notarytool store-credentials "islet-notary" \
  --apple-id "you@example.com" \
  --team-id  "TEAMID1234"
```

It will prompt you for an **app-specific password**. That is a one-off password
you generate at <https://appleid.apple.com> → **Sign-In & Security** →
**App-Specific Passwords** — **not** your real Apple ID password.

After that, set the script's variable to the same name:

```bash
NOTARY_PROFILE="islet-notary"
```

> **Security:** the script only ever references this **profile name**. Your
> Apple ID, team id, and app-specific password live in the keychain, and must
> **never** be committed to the repository.

Once both placeholders are filled, run `bash scripts/release.sh` again — the
notarize and staple steps now execute and you get a real notarized DMG.

---

## What notarization changes

- **Before** (today's ad-hoc build): if you download it, macOS Gatekeeper
  blocks it as an **"unidentified developer."** An ad-hoc signature is not a
  Gatekeeper-acceptable signature.
- **After** a real Developer-ID sign + `xcrun notarytool` + `xcrun stapler
  staple`: `spctl --assess` reports `accepted, Notarized Developer ID`, and a
  downloaded copy opens with **no warning** — even offline, because the
  notarization ticket is "stapled" onto the DMG.

This is the Phase-0 success-criterion **#3** carry-over (decision **D-02**):
the *real* notarized, clean-machine open is deliberately finished at Phase 6,
because the paid Apple account is deferred until you're ready to ship.

---

## Local Gatekeeper demo (Plan 04)

There is no second Mac to test a "clean download" on (decision **D-04**), so
Plan 04 demonstrates the Gatekeeper **block** locally on this Mac by tagging the
DMG with the `com.apple.quarantine` attribute (`xattr`) and asking for the
verdict with `spctl --assess`. The expected result and the exact commands are
documented in the **Plan 04 SUMMARY** (`00-04-SUMMARY.md`).

---

## Sparkle Auto-Update (Phase 40)

Islet checks for updates using [Sparkle](https://sparkle-project.org/), the standard
auto-update framework for directly-distributed (non-App-Store) Mac apps. This section
explains the moving parts and the two things that still need to happen before a real
release ships.

### The EdDSA signing key — Keychain only, never in the repo

Sparkle verifies every downloaded update with an EdDSA (ed25519) signature before
installing it, so a compromised download host can never silently push a malicious
update. This works via a **keypair**:

- The **private key** signs each release you publish. It was generated once on this
  machine by Sparkle's own `generate_keys` tool and lives **only in this machine's
  login Keychain** — it is never written to a file, never committed to the repo, and
  must never be copied onto the Vercel or GitHub hosts that serve the app or the
  appcast.
- The **public key** (`SUPublicEDKey` in `project.yml`) is safe to ship inside the app
  — it can only *verify* signatures, not create them.

If you ever set up Islet on a **new** machine to cut releases, you either need to
export/import this Keychain item to the new machine, or (only if truly necessary —
see the warning below) generate a brand-new keypair there.

> **Never rotate the EdDSA keypair and the Developer ID code-signing identity in the
> same release.** Doing both at once breaks Sparkle's trust chain for every existing
> install — those users' apps can no longer verify anything signed by the new key, and
> they have no way to auto-update out of that state; they'd have to manually
> redownload. Regenerate the EdDSA keypair only if it is truly compromised, and never
> alongside a signing-identity change.

### The feed URL

`project.yml`'s `SUFeedURL` (merged via `Islet/Info-Sparkle.plist`, see below) points
directly at this repo, served for free via `raw.githubusercontent.com` — no separate
hosting account needed (the original plan of a dedicated Vercel domain was descoped as
unnecessary complexity for a hobby project):

```
https://raw.githubusercontent.com/Lippi304/Islet/main/docs/appcast.xml
```

`scripts/release.sh`'s Step 7 regenerates `docs/appcast.xml` automatically at the end
of every release run (via Sparkle's `generate_appcast` tool, which also signs the new
entry with the EdDSA private key from Keychain). After a release: **commit and push
`docs/appcast.xml`**, and **upload the matching `dist/Islet.dmg` to that version's
GitHub Release** (`gh release upload vX.Y dist/Islet.dmg`) — both must exist at the
enclosure URL the appcast points at, or existing installs' "Check for Updates" will
fail or 404.

### Versioning stays manual (D-04)

Sparkle compares `sparkle:shortVersionString`/`sparkle:version` in the appcast against
the app's own `CFBundleShortVersionString`/`CFBundleVersion` (driven by `project.yml`'s
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`). This phase adds no new release-cadence
process — keep bumping those two values by hand per the project's existing convention
before cutting a release.

### Testing the update flow before a real feed exists

`docs/appcast-mock.xml` is a hand-authored fake appcast describing one newer version
(`99.0`) with a placeholder, non-functional signature — it is never shipped inside the
app and never referenced by any Info.plist key. To manually exercise the "an update was
found" flow locally, temporarily point Sparkle at this file with a local `file://` URL
override (see `40-03-PLAN.md` for the exact on-device verification steps) instead of
editing the real `SUFeedURL`.

### Where the 3 Sparkle Info.plist keys actually live

`SUFeedURL`, `SUPublicEDKey`, and `SUEnableAutomaticChecks` are **not** recognized by
Xcode's `INFOPLIST_KEY_*` build-setting synthesis mechanism (that mechanism only knows
about Apple's own well-known keys, like `NSCameraUsageDescription` — third-party keys
like Sparkle's are silently dropped). They are instead merged in via XcodeGen's `info:`
feature on the `Islet` target in `project.yml`, which generates
`Islet/Info-Sparkle.plist` — a normal derived/generated file, regenerated by
`xcodegen generate` every time, not meant to be hand-edited directly. Change the
Sparkle-related values in `project.yml`, not in `Info-Sparkle.plist` itself.
