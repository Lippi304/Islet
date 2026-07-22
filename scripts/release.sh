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
# Apple Developer Team ID (matches project.yml's DEVELOPMENT_TEAM) — needed by
# -exportArchive's ExportOptions.plist below so Xcode knows which team to pull
# a Developer ID distribution profile from.
TEAM_ID="R7AGU84UX7"
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
# Step 2+3: Export + sign the .app for distribution.
# ----------------------------------------------------------------------------
# If DEVELOPER_ID is still the placeholder, we AD-HOC sign ("Sign to Run
# Locally", identity "-") — fine for local testing but NOT Gatekeeper-valid
# (D-03). We pull the .app straight out of the archive with `ditto` (NOT a
# recursive copy — ditto preserves the symlinks inside an .app/.framework
# bundle that a plain recursive copy would corrupt and thereby break the code
# signature) and ad-hoc sign it directly; no distribution profile is needed
# for a local dry run.
if [ "${DEVELOPER_ID}" = "__DEVELOPER_ID__" ]; then
  echo "-> No Developer ID set: AD-HOC signing for local dry-run (D-03)."
  ditto "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"
  # NOTE: no `--deep` — it is deprecated and mis-signs nested code once we embed
  # frameworks (MediaRemoteAdapter, Sparkle) in later phases. codesign signs the
  # app bundle correctly without it.
  #
  # `--entitlements` is REQUIRED here too (see the real-signing branch's comment
  # below for why) — Xcode's own archive-time signature already carries the
  # entitlements, but re-signing with `codesign` does not preserve them unless
  # told to; without this flag the local dry-run app would silently be missing
  # Location/WeatherKit/Calendar/Automation, masking the exact bug this fixes.
  codesign --force --entitlements Islet/Islet.entitlements --sign - "${APP_PATH}"
else
  echo "-> Exporting for Developer ID distribution via xcodebuild -exportArchive."
  # CRITICAL: do NOT pull the .app out of the archive with `ditto` and re-sign
  # it by hand with plain `codesign` here. A raw `xcodebuild archive` picks
  # whatever profile "Automatic" signing considers best for local iteration —
  # in practice a "Mac Team Provisioning Profile" (Xcode's development-flavored
  # automatic profile), NOT one valid for Developer ID (non-App-Store)
  # distribution. `codesign --sign` re-signs the CODE but never touches/swaps
  # the embedded `Contents/embedded.provisionprofile` resource file, so that
  # wrong-flavored profile silently rides along untouched. For most
  # entitlements this doesn't matter, but "managed capability" entitlements
  # like WeatherKit and Communication Notifications ARE checked by AMFI
  # against the embedded profile at every launch — and a profile that's the
  # wrong type/signing-identity for it makes AMFI kill the process at spawn
  # time with Error Domain=AppleMobileFileIntegrityError Code=-413 "No
  # matching profile found", even though `codesign --verify` and
  # `spctl --assess` both report the app as perfectly valid (confirmed the
  # hard way shipping v1.2: static verification passed, notarization
  # succeeded, but the app could not actually launch for any user).
  #
  # `xcodebuild -exportArchive` with `method: developer-id` is the officially
  # correct distribution path: Xcode selects/generates a genuine
  # "Mac Team Direct Provisioning Profile" (the Developer-ID/direct-
  # distribution flavor) for this Team ID, embeds it correctly, and re-signs
  # the whole bundle — including nested frameworks (MediaRemoteAdapter,
  # Sparkle, and Sparkle's own nested Autoupdate/Updater.app/XPC services) —
  # with the Developer ID certificate, Hardened Runtime, and a secure
  # timestamp, all in one Apple-blessed step. This replaces the old hand-
  # rolled "sign every nested Sparkle binary explicitly" codesign loop
  # entirely; -exportArchive's own signing pipeline handles nested code
  # correctly without the `--deep` mis-signing problems that loop worked
  # around.
  EXPORT_OPTIONS_PLIST="build/ExportOptions.plist"
  cat > "${EXPORT_OPTIONS_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST
  rm -rf "${EXPORT_DIR}"
  xcodebuild -exportArchive -archivePath "${ARCHIVE_PATH}" -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" -allowProvisioningUpdates
fi
# Sanity-check the signature is well-formed before we package it.
codesign --verify --verbose "${APP_PATH}"
# Guard against ever repeating the entitlements-loss bug that used to hide
# this exact problem: fail loudly if the signed app doesn't actually carry
# the WeatherKit entitlement (a stand-in check for "entitlements survived
# signing" — this key is a canary because it's easy to grep for and always
# expected to be present).
if ! codesign -d --entitlements - "${APP_PATH}" 2>/dev/null | grep -q "com.apple.developer.weatherkit"; then
  echo "ERROR: signed app is missing entitlements (WeatherKit canary check failed)." >&2
  echo "Location/WeatherKit/Calendar/Automation would silently stop working. Aborting." >&2
  exit 1
fi
# Guard against the AMFI/provisioning-profile mismatch that shipped in v1.2
# (silent at the codesign/spctl level, fatal at actual launch time): launch
# the freshly-signed .app for real and confirm the process survives briefly,
# instead of trusting only static signature verification.
echo "-> Launch-testing the signed app before packaging (catches AMFI profile mismatches static checks miss)..."
"${APP_PATH}/Contents/MacOS/${APP_NAME}" &
LAUNCH_TEST_PID=$!
sleep 2
if ps -p "${LAUNCH_TEST_PID}" > /dev/null 2>&1; then
  echo "-> Launch test passed (pid ${LAUNCH_TEST_PID} stayed alive)."
  kill "${LAUNCH_TEST_PID}" 2>/dev/null || true
else
  wait "${LAUNCH_TEST_PID}" 2>/dev/null
  LAUNCH_TEST_EXIT=$?
  echo "ERROR: signed app failed to launch (exit ${LAUNCH_TEST_EXIT}) — aborting before packaging/notarizing a broken build." >&2
  echo "Check 'log show --last 2m --predicate process==\"amfid\"' for the AMFI denial reason." >&2
  exit 1
fi

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
# NOT necessarily "${VOL_NAME}" — if a volume with that name is already
# mounted (e.g. the user has a previously-downloaded Islet.dmg open in
# Finder), macOS silently mounts this one as "${VOL_NAME} 1" instead. Using
# the wrong (stale) disk name here makes Finder bind to that OTHER volume,
# which doesn't have this run's freshly-generated .background folder and
# fails with "(-10006)". Always derive the actual mounted name.
MOUNTED_VOL_NAME=$(basename "${MOUNT_POINT}")

# Finder positions icons and sets the background picture via AppleScript —
# the standard technique every hand-rolled (non-create-dmg) release script
# uses; `osascript` is part of macOS, no extra tooling needed.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${MOUNTED_VOL_NAME}"
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

# ----------------------------------------------------------------------------
# Step 7: Regenerate docs/appcast.xml so Sparkle's "Check for Updates" has a
# real entry for this release once you upload ${DMG_PATH} to the matching
# GitHub Release (tag v<MARKETING_VERSION>) and push this file.
# ----------------------------------------------------------------------------
GITHUB_REPO="Lippi304/Islet"
MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | sed -E 's/.*"([0-9.]+)".*/\1/')
GENERATE_APPCAST=$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path "*artifacts/sparkle/Sparkle/bin/generate_appcast" -print -quit 2>/dev/null || true)
if [ -z "${GENERATE_APPCAST}" ]; then
  echo "--------------------------------------------------------------"
  echo "WARNING: Sparkle's generate_appcast tool was not found under DerivedData —"
  echo "docs/appcast.xml was NOT updated. Build the project in Xcode at least once"
  echo "(so SPM resolves the Sparkle package), then re-run this script."
  echo "--------------------------------------------------------------"
else
  APPCAST_STAGING=$(mktemp -d)
  cp "${DMG_PATH}" "${APPCAST_STAGING}/"
  "${GENERATE_APPCAST}" \
    --download-url-prefix "https://github.com/${GITHUB_REPO}/releases/download/v${MARKETING_VERSION}/" \
    -o docs/appcast.xml \
    "${APPCAST_STAGING}"
  rm -rf "${APPCAST_STAGING}"
  echo "-> Wrote docs/appcast.xml for v${MARKETING_VERSION} — commit and push this file,"
  echo "   and upload ${DMG_PATH} to the v${MARKETING_VERSION} GitHub Release, for Sparkle"
  echo "   updates to work (SUFeedURL points at this file via raw.githubusercontent.com)."
fi
