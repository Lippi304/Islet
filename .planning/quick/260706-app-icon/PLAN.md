---
type: quick
slug: app-icon
date: 2026-07-06
---

# Quick Task: App-Icon einbauen

## Description

Das fertige App-Icon aus `brand/islet/` in den Xcode Asset-Catalog einbauen und als Islet-App-Icon aktivieren.

## Context

- Der Nutzer hat das Icon selbst erstellt und unter `brand/islet/` abgelegt (untracked).
- `brand/islet/AppIcon.appiconset/` enthält bereits ein vollständiges macOS-AppIcon-Set: 10 PNGs (16–512pt, @1x/@2x) plus eine `Contents.json`, die die Dateinamen referenziert.
- Das Projekt-Catalog `Islet/Assets.xcassets/AppIcon.appiconset/` hatte bisher nur eine leere `Contents.json` ohne PNGs → Icon-Slot war leer.
- Build-Verdrahtung ist bereits vorhanden: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` (project.yml + pbxproj).
- Gehört NICHT zu Phase 12 (reine Polar.sh-Lizenz-Integration) — eigenständige Quick-Task.

## Tasks

1. 10 PNGs + die dateinamen-tragende `Contents.json` aus `brand/islet/AppIcon.appiconset/` nach `Islet/Assets.xcassets/AppIcon.appiconset/` kopieren.
2. `brand/` als Source-of-Truth der Brand-Assets ins Repo aufnehmen (war untracked).
3. Debug-Build als Gate: `actool` muss das Icon fehlerfrei packen.

## Acceptance Criteria

- [ ] `Islet/Assets.xcassets/AppIcon.appiconset/` enthält alle 10 PNGs + korrekte Contents.json.
- [ ] `xcodebuild ... build` (Debug) läuft grün durch (actool packt AppIcon ohne Warnung/Fehler).
- [ ] `brand/` ist committed.
