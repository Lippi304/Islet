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
3. A disk image is created at `dist/Islet.dmg`.
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
