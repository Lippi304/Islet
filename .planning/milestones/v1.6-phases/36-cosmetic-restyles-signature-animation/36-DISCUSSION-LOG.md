# Phase 36: Cosmetic Restyles & Signature Animation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-16
**Phase:** 36-cosmetic-restyles-signature-animation
**Areas discussed:** Bluetooth/Charging HUD layout, Equalizer bars visual design, Onboarding signature animation

---

## Bluetooth/Charging HUD Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Reskin the split-wing chrome | Keep left-icon/right-status wing structure and camera gap, refresh chrome to match Droppy's pill language | ✓ |
| Something else | User has a different structural idea | |

**User's choice:** Reskin the split-wing chrome (recommended).
**Notes:** The camera-notch split is a hard physical constraint — confirmed this isn't negotiable before asking.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep icon-only | No text, matches today's minimal footprint | |
| Add short status text | e.g. "Connected"/"Charging" next to the icon | ✓ |
| Something else | Different content idea | |

**User's choice:** Add short status text.

| Option | Description | Selected |
|--------|-------------|----------|
| Widen the wing that gets the label | Icon+label share the right wing (Claude's initial guess) | (initially) ✓ |
| Label on the left, status glyph stays right | Left wing gets icon+text, right stays icon-only | |
| Something else | Different arrangement | |

**User's choice:** Initially "Widen the wing that gets the label" (right wing) — **superseded** once the user supplied real Droppy screenshots.
**Notes:** User pasted 3 Droppy screenshots showing the label actually sits on the LEFT (icon+text), with the RIGHT wing showing only the value/indicator (green ring for AirPods, green battery+% for Charging). This directly contradicted Claude's initial guess and was corrected via a follow-up confirmation question. Screenshots saved as `reference-droppy-airpods-pill.png` and `reference-droppy-volume-charging-pills.png`.

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, links Icon+Text, rechts Wert (wie Droppy) | Confirms label-left/value-right layout for both activities | ✓ |
| Anders | Different split | |

**User's choice:** Ja, links Icon+Text, rechts Wert (wie Droppy).

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed green for connected/charging | Not accent-tinted, matches Droppy exactly | ✓ |
| Dim to icon-only when disconnected/not-charging | No text label in negative state, matches today's D-03 dimming | ✓ |
| Anders | Different color/negative-state idea | |

**User's choice:** Both recommended options (multiSelect).
**Notes:** Droppy's screenshots only showed positive states; negative-state behavior was inferred/confirmed as "keep it minimal, no text."

---

## Equalizer Bars Visual Design

| Option | Description | Selected |
|--------|-------------|----------|
| Ich schicke ein Referenzbild/Screenshot | User attaches an image | |
| Ich beschreibe es in Worten | User describes verbally | |

**User's choice:** Neither directly — user instead supplied a URL: `https://skiper-ui.com/v1/skiper25` (Skiper UI "Music toggle btn" component).
**Notes:** WebFetch redirected to context-mode; `ctx_fetch_and_index` retrieved the static page (component described as "Interactive music player with animated waveform visualization... clickable button that plays/pauses... smooth spring animations") but not the actual source (behind a JS-interactive "view source" button). Found and fetched the underlying shadcn registry JSON directly (`https://skiper-ui.com/r/skiper25.json`) via `ctx_execute`, which contained the full `skiper25.tsx` source.

| Option | Description | Selected |
|--------|-------------|----------|
| Nur visueller Stil (empfohlen) | Bars stay decorative, no new tap interaction — matches EQ-01's view-layer-only scope | ✓ |
| Auch tippbar machen (Play/Pause) | New interaction, scope creep | |

**User's choice:** Nur visueller Stil (empfohlen) — after Claude flagged that Skiper25 is architecturally a toggle button and EQ-01 is scoped as view-layer only.
**Notes:** User's initial free-text response actually proposed the tappable/toggle idea (plus a broader hover-to-widen-island-with-transient-HUDs concept) — redirected per scope guardrail and captured as deferred ideas rather than acted on.

| Option | Description | Selected |
|--------|-------------|----------|
| Andere Balkenform (nicht Kapsel) | Different bar shape | |
| Andere Balkenzahl/Abstand | Different count/spacing | |
| Andere Bewegungsart (Spring statt Sinus) | Springier motion instead of sine wave | |
| Anders — ich beschreibe es genauer | Free-form | ✓ |

**User's choice:** "Anders" — user asked to port the Skiper25 bars exactly as shown in the link, staying white.
**Notes:** This superseded the multi-select options above once the user clarified they wanted Skiper25's exact bars, not a menu of independent tweaks.

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, genau so (empfohlen) | Lock the extracted target values: 1pt bars, rounded-full, ~4pt gap, 4-14pt height, white, springy ~100ms-reroll motion | ✓ |
| Anders — ich beschreibe es | A detail should differ | |

**User's choice:** Ja, genau so (empfohlen).
**Notes:** Values were extracted directly from the fetched `skiper25.tsx` source (bars=5, `w-[1px]`, `gap-1`, `h-[18px]` container, height = `Math.max(4, height * 14)` where height ∈ [0.2, 1.0], color = `bg-foreground`, spring stiffness 300/damping 10, 100ms reroll interval).

---

## Onboarding Signature Animation

| Option | Description | Selected |
|--------|-------------|----------|
| "Islet" (empfohlen) | Just the product name | |
| "Meet Islet" (heutiger Text) | Today's full heading | ✓ |
| Anders | Different wording | |

**User's choice:** "Meet Islet" — user's first free-text reply actually supplied the full Signature component source instead of picking, then confirmed "Meet Islet" over "Islet" when asked again directly.

| Option | Description | Selected |
|--------|-------------|----------|
| Orange (App-Akzent, empfohlen) | Consistent with existing design system | ✓ |
| Regenbogen-Farbverlauf | Colorful gradient, new palette for one screen | |

**User's choice:** Orange (App-Akzent, empfohlen) — user had floated a rainbow gradient in their original free-text message but picked orange when given the explicit choice.

| Option | Description | Selected |
|--------|-------------|----------|
| Ich habe die Font-Datei und liefere sie | User provides the .otf directly | |
| Keine Font-Datei — Ersatz recherchieren | Researcher finds a libre substitute | |

**User's choice:** Neither directly — user pointed to the componentry.fun docs/registry install command (`npx shadcn@latest add @componentry/signature`), which itself instructs downloading `LastoriaBoldRegular.otf`.
**Notes:** Claude fetched the font directly (`https://www.componentry.fun/LastoriaBoldRegular.otf`, confirmed live, 177816 bytes, valid OTF) and inspected its embedded metadata: `Typeface © Abo Daniel 2019. All Rights Reserved.` — flagged as an unverified commercial license risk for a paid product and surfaced as an explicit follow-up question.

| Option | Description | Selected |
|--------|-------------|----------|
| Lizenzfreie Skript-Schrift als Ersatz suchen (empfohlen) | Find a guaranteed-commercial-use substitute | |
| Ich habe/besorge eine kommerzielle Lizenz für La storia | User handles licensing themselves | |
| Mir ist das Risiko bewusst — trotzdem verwenden | Conscious risk acceptance | |

**User's choice:** None selected directly — user replied "Das hier ist alles opensource aber irgendwie" (uncertain) and attached a screenshot of componentry.fun's docs page showing the required font download instruction.
**Notes:** Not treated as a confident license confirmation. Captured in CONTEXT.md as an explicit FLAGGED RISK (D-12) that the researcher/planner must resolve before shipping — not silently accepted, not silently substituted.

| Option | Description | Selected |
|--------|-------------|----------|
| Untertext bleibt unverändert (empfohlen) | Only the heading changes | ✓ |
| Anders | Subtext also changes | |

**User's choice:** Untertext bleibt unverändert (empfohlen).

---

## Claude's Discretion

- Exact SwiftUI mechanism for the equalizer bars' periodic-reroll-plus-spring animation, as long as the idle-CPU gate (zero clock while paused) is preserved.
- Exact SwiftUI mechanism for per-glyph vector path extraction and `.trim(from:to:)`-based stroke reveal for the signature animation (Core Text `CTFontCreatePathForGlyph` is the natural analog to `opentype.js`).
- Whether Skiper UI's free-tier attribution requirement needs a visible in-app credit.

## Deferred Ideas

- Equalizer bars becoming tappable to toggle play/pause (inspired by Skiper25 being a toggle button) — new interaction, out of EQ-01's view-layer-only scope.
- A broader concept raised in the same exchange: the collapsed island only widens on hover, transient volume/brightness-style HUD content fades in/out, Now Playing stays the primary/default content with bars on the right of the hover-widened state. Overlaps Phase 39 (Volume & Brightness HUD) and general hover/resolver behavior — not Phase 36's restyle-only scope. Flag for the user when Phase 38/39 come up.
- Possible in-app credit for Skiper UI's free-tier license requirement.
