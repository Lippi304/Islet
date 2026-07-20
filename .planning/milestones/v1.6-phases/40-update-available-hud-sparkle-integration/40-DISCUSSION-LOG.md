# Phase 40: Update-Available HUD & Sparkle Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 40-Update-Available HUD & Sparkle Integration
**Areas discussed:** Release feed & signing readiness, Badge visual placement, Check-for-updates cadence, Badge dismiss lifecycle

---

## Release feed & signing readiness

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Releases | STACK.md's zero-cost pick — appcast + generate_appcast tool, feed hosted on the existing public repo | |
| Own domain/host | If the user already has or plans a website for Islet | initial free-text pointed here (Vercel) |
| Decide later | Placeholder SUFeedURL, real hosting finalized later | |

**User's choice (free text):** "Also ich habe ja eine eigene Website die über Vercel gepusht ist, wir können das gerne darüber direkt machen und nicht extra über GitHub oder so."
**Notes:** Follow-up asked whether BOTH the appcast and the binaries should live on Vercel, or just the feed (binaries via GitHub Releases). User asked Claude to recommend. Claude recommended splitting: appcast.xml (tiny) on Vercel, .dmg/.zip binaries on GitHub Releases (Vercel hobby-plan bandwidth risk for repeated large-file downloads; GitHub Releases has no such limit). User confirmed the split. → **D-01/D-02** in CONTEXT.md.

| Question | Options | Selected |
|--------|-------------|----------|
| EdDSA signing key | Generate now (recommended) / Defer until first real release | **Generate now** |
| End-to-end test scope | Wiring only (recommended) / Full pipeline test with real published release | **Wiring only** |
| Other release/signing decisions | No — defaults are fine / Something specific | **No — defaults are fine** |

---

## Badge visual placement

| Question | Options | Selected |
|--------|-------------|----------|
| Collapsed-pill badge location | Small dot/icon in a corner (recommended) / Only visible when idle / Separate element beside capsule | **Small dot/icon in a corner** |
| Visible in expanded view? | Collapsed-only (recommended) / Also visible expanded | **Collapsed-only** |
| Badge color/style | Accent color, theming convention (recommended) / Fixed standalone color | **Accent color** |
| Hover tooltip text? | Icon only (recommended) / Icon + hover tooltip | **Icon only** |

**Notes:** All four questions landed on the recommended option — no pushback, no follow-up needed.

---

## Check-for-updates cadence

| Question | Options | Selected |
|--------|-------------|----------|
| Automatic background checks vs manual-only | Manual only for now (recommended) / Automatic from the start | **Automatic from the start** |
| Settings toggle for automatic checks | No dedicated toggle — core function (recommended) / Dedicated Settings toggle | **Dedicated Settings toggle** |
| Check interval | Sparkle default ~24h (recommended) / Custom interval | **Sparkle default ~24h** |
| Toggle default state | Default ON (recommended) / Default OFF (opt-in) | **Default ON** |

**Notes:** User deviated from Claude's recommendation on the first two questions (chose automatic-from-start over manual-first, and a dedicated toggle over none) — both captured as explicit decisions (D-09/D-11), not defaults.

---

## Badge dismiss lifecycle

| Question | Options | Selected |
|--------|-------------|----------|
| Badge clears on tap vs persists until installed | Persist until really installed (recommended) / Clear immediately on tap | **Persist until really installed** |
| Custom dismiss path beyond Sparkle's dialog | No custom dismiss (recommended) / Yes, custom X button | **No custom dismiss** |

**Notes:** Both recommended options confirmed without pushback.

---

## Claude's Discretion

- Exact SwiftUI shape/size/corner of the badge dot — no existing precedent to match exactly.
- Placement of the new automatic-checks Settings toggle within `SettingsView.swift` (existing Theming/Activity section vs. its own row).
- Exact appcast.xml route/structure on the Vercel site (static file vs. API route) — decided at planning/research time.

## Deferred Ideas

- Standing up the real, live appcast.xml on Vercel + cutting the first real signed GitHub release — release-prep work for whenever the first real update-eligible version ships, not this phase.
- A fully custom `SPUUserDriver` replacing Sparkle's standard dialog with an in-notch install flow — explicitly out of scope per REQUIREMENTS.md/research; revisit only if the badge+standard-dialog combo proves insufficient after shipping.
