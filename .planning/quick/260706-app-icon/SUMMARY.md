---
type: quick
slug: app-icon
date: 2026-07-06
status: complete
---

# Quick Task Summary: App-Icon einbauen

## What was done

Das vom Nutzer erstellte App-Icon aus `brand/islet/` wurde in den Xcode Asset-Catalog eingebaut und als Islet-App-Icon aktiviert.

## Changes

1. **Icon-Assets kopiert** — 10 PNGs (16/32/128/256/512pt, je @1x/@2x) + die dateinamen-tragende `Contents.json` aus `brand/islet/AppIcon.appiconset/` nach `Islet/Assets.xcassets/AppIcon.appiconset/`. Vorher enthielt das Projekt-Set nur eine leere `Contents.json` ohne PNGs → Icon-Slot war leer.
2. **`brand/` ins Repo aufgenommen** — war untracked; ist jetzt die Source-of-Truth für die Brand-Assets (`.icns`, `.ico`, `.svg`, roh-PNGs, `AppIcon.appiconset`).

Keine Build-Setting-Änderung nötig: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` war bereits in `project.yml` und `pbxproj` gesetzt.

## Verification

Debug-Build (`xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`) → **BUILD SUCCEEDED**.

Im gebauten `Islet.app`-Bundle bestätigt:
- `Contents/Resources/Assets.car` (217 KB) — kompiliertes AppIcon
- `Contents/Resources/AppIcon.icns` (46 KB)
- `Info.plist`: `CFBundleIconName = AppIcon`, `CFBundleIconFile = AppIcon`

## Notes

- Gehört NICHT zu Phase 12 (reine Polar.sh-Lizenz-Integration) — eigenständige Quick-Task.
- Optischer Endcheck (Icon im Dock/Finder/About-Panel) ist eine visuelle On-Device-Bestätigung, die der Nutzer beim nächsten App-Start selbst sieht — technisch ist das Icon korrekt eingebettet.
