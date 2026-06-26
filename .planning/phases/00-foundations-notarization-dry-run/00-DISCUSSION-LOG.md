# Phase 0: Foundations & Notarization Dry Run - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 0-Foundations & Notarization Dry Run
**Areas discussed:** Apple Developer Account & Notarization Scope, macOS Deployment Floor, App Identity, Menu & Settings Placeholder

---

## Apple Developer Account & Notarization Scope

### Account timing
| Option | Description | Selected |
|--------|-------------|----------|
| Jetzt holen | Account ($99/yr) now, full notarize→staple→second-Mac dry run in Phase 0 | |
| Aufschieben | Build Phase 0 locally signed, stage + document the notarize script, run later | ✓ |

**User's choice:** Defer — "den würde ich erst holen wenn alles soweit funktioniert und ich mir sicher bin, dass ich das so veröffentlichen möchte."

### Phase-0 "done" definition (given deferral)
| Option | Description | Selected |
|--------|-------------|----------|
| Reframe as prepared-not-executed | Local signed build + .dmg + full script w/ placeholders + local Gatekeeper demo; real notarization + 2nd-Mac test → Phase 6 | ✓ |
| Mark blocked | Hold Phase 0 until account exists | |
| Other | User explains | |

**User's choice:** Accept the reframe.

### Local signing approach
| Option | Description | Selected |
|--------|-------------|----------|
| Ad-hoc / Sign to Run Locally | `codesign -s -`, simplest, runs on this Mac | ✓ |
| Personal-Team dev cert | Free Xcode personal team cert, closer to real but still not Developer ID | |
| Du entscheidest | Claude's discretion | |

**User's choice:** Ad-hoc / "Sign to Run Locally".

### Second Mac for clean Gatekeeper test
| Option | Description | Selected |
|--------|-------------|----------|
| Ja | Second clean Mac available | |
| Nein / Simulation | Verify Gatekeeper via quarantine-flag simulation on this Mac | ✓ |
| Später | Decide later | |

**User's choice:** No second Mac — use quarantine-flag simulation.

### Packaging format
| Option | Description | Selected |
|--------|-------------|----------|
| .dmg | Pretty disk image like real apps | ✓ |
| .zip | Simpler, enough for the dry run | |
| Du entscheidest | Claude's discretion | |

**User's choice:** `.dmg`.

**Notes:** The deferral means Phase 0 SC#3 (clean second-Mac open) is intentionally a documented carry-over to Phase 6, not a Phase 0 blocker.

---

## macOS Deployment Floor

| Option | Description | Selected |
|--------|-------------|----------|
| 14.0 (Sonoma) | Max reach; Now Playing only ≥15.4, fallback below (CLAUDE.md recommendation) | ✓ |
| 15.0 (Sequoia) | Newer SwiftUI APIs, small gap to 15.4 | |
| 15.4 | Same threshold as Now Playing; no half-working experience, less reach | |

**User's choice:** 14.0 (Sonoma).
**Notes:** Now Playing (Phase 4) requires 15.4+ and uses the NOW-03 "unavailable" fallback below that; SMAppService needs only 13+.

---

## App Identity

### Working name
Presented name ideas (island metaphor / form / optics): Isla, Islet, Atoll, Cay, Perch, Ridge, Crest, Lumen, Glint, Slate. Flagged "Onyx" as a collision with the OnyX Mac utility. Picker offered: Isla / Islet / Atoll / Perch.

| Option | Selected |
|--------|----------|
| Isla | |
| Islet | ✓ |
| Atoll | |
| Perch | |

**User's choice:** Islet.

### Bundle identifier
**User's choice:** `com.lippi304.islet` (user specified the `com.lippi304.<name>` scheme; name resolved to "islet").

---

## Menu & Settings Placeholder

### Launch-at-login toggle home / what "Settings…" opens
| Option | Description | Selected |
|--------|-------------|----------|
| Minimal Settings window now | SwiftUI window with launch-at-login toggle + version label; menu = Settings… + Quit Islet | ✓ |
| Dropdown only | Launch-at-login as a menu checkbox, no window | |
| Both | Toggle in menu AND settings window | |

**User's choice:** Minimal Settings window now (matches APP-01/02; base Phase 6 extends).

### Menu-bar icon
| Option | Description | Selected |
|--------|-------------|----------|
| Monochrome SF Symbol template | Capsule/notch-like symbol, swappable | ✓ |
| Letter "I" / dot placeholder | Simple placeholder | |
| Du entscheidest | Claude's discretion | |

**User's choice:** Monochrome SF Symbol template.

---

## Claude's Discretion

- `SMAppService` registration details, exact SF Symbol, app/version number scheme, build-script repo
  location, Xcode `.gitignore`, hardened-runtime flag in the script, minimal entitlements
  (un-sandboxed), placeholder `.app` icon.

## Deferred Ideas

- Real notarization (`notarytool submit` + `stapler staple`) + clean-second-Mac Gatekeeper test →
  Phase 6 release, once the Apple Developer account is purchased.
