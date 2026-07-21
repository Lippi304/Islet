#!/usr/bin/env bash
set -euo pipefail
# `set -euo pipefail` makes the script SAFE for a beginner:
#   -e  exit immediately if any command fails (don't barrel on after an error)
#   -u  treat use of an unset variable as an error (catches typos)
#   -o pipefail  if any command in a pipe fails, the whole pipe fails

# ============================================================================
# Islet release pipeline:  archive -> sign -> dmg -> notarize -> staple
# ----------------------------------------------------------------------------
# PHASE 0: runs end-to-end EXCEPT real notarization (Apple Developer account is
# deferred — D-01). With the placeholders below unfilled, the script signs
# AD-HOC for local testing and SKIPS notarize/staple with a clear message.
#
# PHASE 6: fill in the two PLACEHOLDER variables below, then re-run this script
# UNCHANGED to produce a real notarized + stapled DMG.
#
# See docs/RELEASE.md for a plain-language walkthrough of every step.
# ============================================================================

# >>> FILL THESE IN AT PHASE 6 (leave as-is for the Phase-0 dry run) >>>
DEVELOPER_ID="6F5264EF72441E588C7A54CCEA26C40028B6AEDF"
NOTARY_PROFILE="islet-notary"
# <<< FILL THESE IN AT PHASE 6 <<<
#
# SECURITY: NOTARY_PROFILE is just a NAME that points at credentials stored in
# your macOS keychain (created once via `xcrun notarytool store-credentials`).
# No Apple ID, password, or app-specific password ever appears in this file or
# in the repo. See docs/RELEASE.md.

# --- Configuration: names and output paths the pipeline uses -----------------
SCHEME="Islet"                            # the Xcode scheme created in Plan 01
APP_NAME="Islet"                          # the app/product display name (D-07)
VOL_NAME="Islet"                          # the name of the mounted DMG volume
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"  # where xcodebuild puts the archive
EXPORT_DIR="build/export"                  # where we copy the exported .app
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"   # the .app we sign and ship
DMG_DIR="build/dmgroot"                    # a clean staging folder for the DMG
DIST_DIR="dist"                            # final distributable artifacts live here
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"     # the disk image users download (D-05)

# ----------------------------------------------------------------------------
# Step 1: Clean previous output, then archive a Release build.
# ----------------------------------------------------------------------------
# Start from a clean slate so stale files can't sneak into the release.
rm -rf build dist
mkdir -p "${EXPORT_DIR}" "${DIST_DIR}"

# `xcodebuild archive` compiles a Release build and bundles it (plus debug
# symbols) into an .xcarchive — the same thing Xcode's Product > Archive makes.
xcodebuild -scheme "${SCHEME}" -configuration Release \
  -destination 'generic/platform=macOS' -allowProvisioningUpdates \
  archive -archivePath "${ARCHIVE_PATH}"

# ----------------------------------------------------------------------------
# Step 2: Pull the built .app out of the archive.
# ----------------------------------------------------------------------------
# The finished .app lives inside the archive at Products/Applications. We copy
# it out with `ditto` (NOT a recursive copy): ditto preserves the symlinks
# inside an .app/.framework bundle, which a plain recursive copy would corrupt
# and thereby break the code signature.
ditto "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"

# ----------------------------------------------------------------------------
# Step 3: Sign the .app.
# ----------------------------------------------------------------------------
# If DEVELOPER_ID is still the placeholder, we AD-HOC sign ("Sign to Run
# Locally", identity "-") — fine for local testing but NOT Gatekeeper-valid
# (D-03). Once a real Developer ID is set, we sign for distribution with the
# Hardened Runtime (`--options runtime`) and a secure `--timestamp`; both are
# MANDATORY for notarization to succeed later (Pitfall 4).
if [ "${DEVELOPER_ID}" = "__DEVELOPER_ID__" ]; then
  echo "-> No Developer ID set: AD-HOC signing for local dry-run (D-03)."
  # NOTE: no `--deep` — it is deprecated and mis-signs nested code once we embed
  # frameworks (MediaRemoteAdapter, Sparkle) in later phases. codesign signs the
  # app bundle correctly without it.
  codesign --force --sign - "${APP_PATH}"
else
  echo "-> Signing with Developer ID + hardened runtime."
  # Sign nested frameworks first (inside-out). codesign does not recurse into
  # embedded frameworks and --deep is deprecated/unreliable, so each embedded
  # framework needs the real Developer ID + secure timestamp explicitly —
  # otherwise notarization rejects the ad-hoc signature Xcode's archive step
  # applied to it.
  #
  # Sparkle.framework additionally bundles its OWN nested executable code
  # (Autoupdate, Updater.app, two XPC services) that codesign does NOT sign
  # just by signing the outer Sparkle.framework bundle — each is its own
  # separate code-signing unit. Found the hard way: the first real (non-dry-run)
  # notarization submission was rejected with "not signed with a valid Developer
  # ID certificate" / "signature does not include a secure timestamp" for all 4
  # of these nested binaries, even though Sparkle.framework itself signed fine.
  # Sign every nested unit explicitly, deepest-first, before the framework itself.
  SPARKLE_FRAMEWORK="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
  if [ -d "${SPARKLE_FRAMEWORK}" ]; then
    SPARKLE_VERSIONED="${SPARKLE_FRAMEWORK}/Versions/B"
    for nested in \
      "${SPARKLE_VERSIONED}/Autoupdate" \
      "${SPARKLE_VERSIONED}/Updater.app/Contents/MacOS/Updater" \
      "${SPARKLE_VERSIONED}/Updater.app" \
      "${SPARKLE_VERSIONED}/XPCServices/Downloader.xpc" \
      "${SPARKLE_VERSIONED}/XPCServices/Installer.xpc"; do
      if [ -e "${nested}" ]; then
        codesign --force --options runtime --timestamp \
          --sign "${DEVELOPER_ID}" "${nested}"
      fi
    done
  fi
  if [ -d "${APP_PATH}/Contents/Frameworks" ]; then
    find "${APP_PATH}/Contents/Frameworks" -maxdepth 1 -name "*.framework" -print0 |
      while IFS= read -r -d '' framework; do
        codesign --force --options runtime --timestamp \
          --sign "${DEVELOPER_ID}" "${framework}"
      done
  fi
  codesign --force --options runtime --timestamp \
    --sign "${DEVELOPER_ID}" "${APP_PATH}"
fi
# Sanity-check the signature is well-formed before we package it.
codesign --verify --verbose "${APP_PATH}"

# ----------------------------------------------------------------------------
# Step 3b: Notarize + staple the .app itself (only when both placeholders are
# filled) — Apple's standard two-staple flow for DMG distribution.
# ----------------------------------------------------------------------------
# `stapler` does not recurse into disk images: stapling only the DMG (Step 6
# below) leaves NO local ticket on the .app once a user drags it out of the
# DMG, which can block/delay Gatekeeper on first launch while offline. So we
# notarize + staple the .app HERE, before Step 4 copies it into the DMG
# staging folder — the STAPLED .app is what ends up inside the DMG. The DMG
# itself still gets its own separate notarize+staple pass in Step 6 (a DMG is
# a distinct artifact from the .app it contains).
if [ "${DEVELOPER_ID}" != "__DEVELOPER_ID__" ] && [ "${NOTARY_PROFILE}" != "__NOTARY_PROFILE__" ]; then
  # notarytool only accepts a .zip/.pkg/.dmg for submission (not a raw .app
  # directory) — ditto -c -k --keepParent zips it while preserving the bundle
  # structure notarization needs to inspect.
  APP_ZIP="${EXPORT_DIR}/${APP_NAME}.zip"
  ditto -c -k --keepParent "${APP_PATH}" "${APP_ZIP}"
  xcrun notarytool submit "${APP_ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
  rm -f "${APP_ZIP}"
  # Stapling attaches the ticket to the original .app bundle, not the zip.
  xcrun stapler staple "${APP_PATH}"
fi

# ----------------------------------------------------------------------------
# Step 4: Build the .dmg with hdiutil — styled as a standard drag-to-install
# window (app icon, an arrow, and an Applications-folder shortcut), matching
# what every other macOS app's DMG looks like.
# ----------------------------------------------------------------------------
# hdiutil ships with macOS (no extra install needed — we deliberately avoid the
# uninstalled `create-dmg`). We stage the signed (and, once real credentials
# exist, already-stapled) .app plus an /Applications symlink into a clean
# folder with `ditto` (keeps the app bundle's internal symlinks intact), build
# a temporary READ-WRITE image so Finder can position icons and set a
# background picture, then convert that to the final compressed (UDZO)
# read-only image users actually download.
DMG_WINDOW_WIDTH=540   # must match scripts/generate-dmg-background.swift
DMG_WINDOW_HEIGHT=380  # must match scripts/generate-dmg-background.swift
APP_ICON_X=140         # must match scripts/generate-dmg-background.swift
APPLICATIONS_ICON_X=400 # must match scripts/generate-dmg-background.swift
ICON_Y=190             # must match scripts/generate-dmg-background.swift
RW_DMG_PATH="build/${APP_NAME}-rw.dmg"

rm -rf "${DMG_DIR}" && mkdir -p "${DMG_DIR}/.background"
ditto "${APP_PATH}" "${DMG_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_DIR}/Applications"
swift "$(dirname "$0")/generate-dmg-background.swift" "${DMG_DIR}/.background/background.png"

# `-fs HFS+` (not APFS) — Finder's classic icon-position/background-picture
# AppleScript below is the well-established HFS+ idiom; -size is generous
# padding over the actual content so hdiutil never fails on a too-tight image.
rm -f "${RW_DMG_PATH}"
hdiutil create -volname "${VOL_NAME}" -srcfolder "${DMG_DIR}" \
  -fs HFS+ -format UDRW -size 100m "${RW_DMG_PATH}"

MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG_PATH}")
MOUNT_POINT=$(echo "${MOUNT_OUTPUT}" | grep -E '^/dev/' | grep '/Volumes/' | awk -F'\t' '{print $NF}' | tail -1)
if [ -z "${MOUNT_POINT}" ]; then
  echo "ERROR: could not determine DMG mount point from hdiutil attach output:" >&2
  echo "${MOUNT_OUTPUT}" >&2
  exit 1
fi

# Finder positions icons and sets the background picture via AppleScript —
# the standard technique every hand-rolled (non-create-dmg) release script
# uses; `osascript` is part of macOS, no extra tooling needed.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${VOL_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 400 + ${DMG_WINDOW_WIDTH}, 100 + ${DMG_WINDOW_HEIGHT} + 40}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to file ".background:background.png"
    set position of item "${APP_NAME}.app" of container window to {${APP_ICON_X}, ${ICON_Y}}
    set position of item "Applications" of container window to {${APPLICATIONS_ICON_X}, ${ICON_Y}}
    close
    open
    -- Finder does not reliably persist the window bounds set above across
    -- this close/reopen (a well-known quirk of this scripting technique) —
    -- re-apply them now so the size that ships in the DMG is the one an end
    -- user actually sees, not Finder's remembered/default window size.
    set the bounds of container window to {400, 100, 400 + ${DMG_WINDOW_WIDTH}, 100 + ${DMG_WINDOW_HEIGHT} + 40}
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "${MOUNT_POINT}" -quiet

hdiutil convert "${RW_DMG_PATH}" -format UDZO -ov -o "${DMG_PATH}"
rm -f "${RW_DMG_PATH}"

# ----------------------------------------------------------------------------
# Step 5: Sign the .dmg itself (only when a real Developer ID is set).
# ----------------------------------------------------------------------------
# The disk image is a separate file from the app inside it, so it gets its own
# signature. Ad-hoc signing the DMG adds no value, so we skip it in dry-run.
if [ "${DEVELOPER_ID}" != "__DEVELOPER_ID__" ]; then
  codesign --force --options runtime --timestamp \
    --sign "${DEVELOPER_ID}" "${DMG_PATH}"
fi

# ----------------------------------------------------------------------------
# Step 6: Notarize + staple the DMG — DEFERRED to Phase 6 (D-01/D-02).
# ----------------------------------------------------------------------------
# This is the second half of Apple's standard two-staple flow (the .app was
# already notarized+stapled in Step 3b above): the DMG is a distinct artifact
# and needs its own ticket so Gatekeeper accepts the downloaded disk image
# itself, not just the app inside it.
# If EITHER placeholder is still unfilled, we cannot notarize, so we STOP here
# cleanly (exit 0 = success) with a loud, unmistakable message. This guarantees
# a Phase-0 dry-run DMG can never be confused with a real shippable release.
if [ "${DEVELOPER_ID}" = "__DEVELOPER_ID__" ] || [ "${NOTARY_PROFILE}" = "__NOTARY_PROFILE__" ]; then
  # The signing-state description depends on which placeholder(s) are still
  # unfilled: if DEVELOPER_ID itself is unset, the app was only ad-hoc signed;
  # if DEVELOPER_ID IS set but NOTARY_PROFILE is not, the app was actually
  # signed with the real Developer-ID certificate (Step 3 branches on this
  # already) — the banner must not claim "ad-hoc" in that case.
  if [ "${DEVELOPER_ID}" = "__DEVELOPER_ID__" ]; then
    SIGN_DESC="ad-hoc signed, NOT notarized"
  else
    SIGN_DESC="signed with Developer ID ${DEVELOPER_ID}, NOT notarized — NOTARY_PROFILE still unfilled"
  fi
  echo "--------------------------------------------------------------"
  echo "SKIPPING notarize + staple — placeholders not filled (Phase 6 step)."
  echo "Phase-0 dry run complete: ${DMG_PATH} (${SIGN_DESC})."
  echo "To finish at Phase 6: fill DEVELOPER_ID + NOTARY_PROFILE, re-run this script."
  echo "--------------------------------------------------------------"
  exit 0
fi

# ---- Phase 6 real run (these execute only once placeholders are filled) ----
# Upload the DMG to Apple's notary service and WAIT for the verdict. The
# credentials come from the keychain profile NAME — never from this file.
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
# Attach ("staple") the notarization ticket to the DMG so Gatekeeper accepts it
# even offline, without re-contacting Apple.
xcrun stapler staple "${DMG_PATH}"
# Confirm Gatekeeper's verdict — expect: accepted, "Notarized Developer ID".
spctl --assess -vvv --type install "${DMG_PATH}"
echo "-> Notarized + stapled DMG ready: ${DMG_PATH}"
