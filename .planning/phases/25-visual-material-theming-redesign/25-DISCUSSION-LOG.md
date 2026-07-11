# Phase 25: Visual/Material Theming Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-11
**Phase:** 25-Visual-Material-Theming-Redesign
**Areas discussed:** Gradient depth/opacity, Theming/accent-color scope, Animation feel, Shape corner radii, (redirected) view switcher

---

## Format note

The user asked to describe the desired look/feel freely (with reference screenshots) instead of answering structured multiple-choice questions. Claude's initial `AskUserQuestion` attempt (4 options: gradient floor, theming scope, accent scope, icon variants) was rejected by the user in favor of this free-text walkthrough. The areas below reflect the actual free-text exchange, not the original option set.

---

## Gradient depth / opacity (VISUAL-01)

**Claude's original options (rejected before discussion):** near-fully transparent bottom / translucent floor (~25-35%) / let Claude tune on-device.

**User's actual answer (via Droppy reference screenshot):** The shape stays opaque/near-opaque for most of its height; only the very bottom fades to roughly ~50% opacity. Explicitly NOT near-fully transparent — reads as "still a solid black shape," not glassy.

**Notes:** Confirmed as pure black → transparent, no grey tint, when Claude asked directly at the end of the discussion ("reines Schwarz→Transparent oder ein leichter Grauton mit rein?" → "Ne so passt alles jetzt").

---

## Theming / accent-color scope (VISUAL-03)

**User's actual answer:** Drop it for this phase entirely — "Akzentfarben/Themes würde ich rauslassen und erstmal wirklich nur volle weiße Schrift nehmen nichts anders farbig." No new Theming Settings section, no per-element accent colors, no icon variants in Phase 25.

**Notes:** Claude asked whether this should be deferred to a later phase or cut outright from the roadmap. The user did not explicitly answer this before moving on to describe animation feel — CONTEXT.md defaults to "defer to a later phase" (reversible) and flags this as needing explicit confirmation + a REQUIREMENTS.md/ROADMAP.md edit before Phase 25 planning proceeds.

---

## Animation feel (VISUAL-02)

**User's actual answer:** Ultra fluid, deliberately slow (not snappy) — the slowness itself is what should read as smooth even on a 60Hz display. On both hover-widen and full click-expand, the shape should slightly overshoot its target size, then spring back to the correct size (real bounce-and-settle, not just easing). Explicitly slower/more pronounced than the current 0.35s/0.65-damping spring.

**Notes:** No asymmetry requested between hover-widen and full-expand — described the same way for both.

---

## Shape corner radii

**User's actual answer:** The expanded island's bottom corners should be noticeably more rounded than today ("geil abgerundet unten," referencing Droppy). The existing top-corner "flowing merge into the screen edge" (NotchShape's quad-curve) already matches what the user wants — confirmed, not a change request, just a design-language validation.

---

## (Redirected) 3-icon view switcher

**What came up:** The user described wanting a 3-icon Home/Tray/[third view] switcher pill below the island, referencing multiple Droppy screenshots, and initially called it a "later" idea before then asking for it to "come along too."

**Claude's redirect:** This is a new navigation capability, not a material/animation question — out of scope for Phase 25. Likely belongs to Phase 28 (Calendar Full View), whose Success Criterion #1 already implies a 3-view Home/Tray/Calendar switcher. Captured as a deferred idea with the visual reference (rounded capsule below the island, matching gradient material, 3 icon-only buttons) for that future discussion. User accepted the redirect without objection.

---

## Claude's Discretion

- Exact gradient stop positions/percentages.
- Exact spring response/damping values for the slower, more-bouncy feel.
- Exact bottom-corner-radius value for the expanded blob.
- Exact `topCornerRadius` tuning, if any.
- Technical mechanism for the gradient fill (LinearGradient vs. mask vs. other).
- Whether the gradient needs special-casing across the pill/wings/expanded blob's differing corner-radius configs, or one shared definition suffices.

## Deferred Ideas

- 3-icon Home/Tray/[third view] switcher pill — see above; likely Phase 28.
- VISUAL-03 (Theming Settings, per-element accent colors, app icon variants) — descoped from Phase 25; needs relocation to a future phase (candidate: Phase 27) via a REQUIREMENTS.md/ROADMAP.md edit, not just a loose note.
