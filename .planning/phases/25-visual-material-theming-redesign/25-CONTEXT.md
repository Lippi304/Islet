# Phase 25: Visual/Material Theming Redesign - Context

**Gathered:** 2026-07-11
**Status:** Ready for planning

<domain>
## Phase Boundary

The collapsed pill, expanded island, and activity wings share one black-to-transparent vertical-gradient material (opaque/solid black nearest the physical notch, increasingly transparent toward the bottom edge) instead of today's flat `Color.black` fill, animated with a fluid, deliberately slow, gently-bouncy (overshoot-and-settle) open/collapse feel. Touches only the shared shell chrome (`NotchPillView`'s shape/fill + `NotchWindowController`'s spring constants) — does NOT touch any individual activity's content rendering (Now Playing, Charging/Battery, Clock/Calendar idle glance, shelf). Those keep their current views, layout, and existing accent tinting (equalizer bars, charging glyph, device icon) completely unchanged inside the new chrome.

**VISUAL-03 (Theming Settings section, per-element accent colors, alternate app icon variants) is descoped from this phase** — see Decisions below. Only VISUAL-01 (gradient material) and VISUAL-02 (animation feel) are actually built here.

Out of scope for this phase: any new navigation/view-switcher UI (belongs to Phase 28), any Settings changes, any activity content changes, any new color/theming customization.

</domain>

<decisions>
## Implementation Decisions

### Gradient material (VISUAL-01)
- **D-01:** Pure black → transparent, no grey tint mixed in (user explicitly confirmed "no" when asked about a lighter grey vs. pure black gradient).
- **D-02:** The gradient stays opaque/near-opaque for most of the shape's height — it should NOT reach near-full transparency. Only the bottom edge fades down to roughly ~50% opacity (Droppy reference screenshot: long solid black stretch, mild transparency only right at the very bottom). This is meaningfully less transparent than a generic "fade to 0%" gradient — err toward "still reads as a solid black shape" over "see-through."
- **D-03 (LOCKED, reconsidered from Phase 25's own ROADMAP wording):** The existing per-element accent tinting on activity content (equalizer bars, charging glyph, device battery icon — Phase 6 D-11) is UNTOUCHED by this phase either way, since that's activity-content rendering, already out of scope. But beyond that, this phase introduces NO new color — text/icons on the new gradient chrome stay pure white, nothing tinted.

### Theming settings (VISUAL-03) — DESCOPED
- **D-04 (needs a follow-up ROADMAP/REQUIREMENTS edit — not yet applied):** User wants accent-color customization and the new Theming Settings section left out of Phase 25 entirely — "erstmal wirklich nur volle weiße Schrift nehmen nichts anders farbig." Claude asked whether VISUAL-03 should be deferred to a later phase or cut outright; the user did not explicitly resolve that question before ending discussion (moved on to describe animation instead). Default assumption (reversible, matches this project's established "carry forward, never silently delete" convention): **defer VISUAL-03 to a future phase** (candidate home: Phase 27 Settings Sidebar Redesign, which already needs a "System (Theming)" sidebar section per the Droppy reference) rather than deleting it. **Before planning Phase 25, confirm this assumption with the user and update REQUIREMENTS.md's Phase 25 requirement list (drop VISUAL-03) and the Traceability table (move VISUAL-03 to Phase 27 or a new phase) accordingly** — this CONTEXT.md alone does not edit those files.
- Practical effect on this phase's requirement coverage: only VISUAL-01 and VISUAL-02 are delivered by Phase 25's plans.

### Animation feel (VISUAL-02)
- **D-05:** Deliberately slow, not snappy — the slowness itself is what should read as "ultra fluid" even on a 60Hz (non-ProMotion) display. Explicitly slower than the current `response: 0.35` spring in `NotchWindowController.swift`.
- **D-06:** A real overshoot-and-settle bounce — the shape grows slightly LARGER than its actual target size, then springs back down to the correct size — not just a smooth ease-in. Applies to both the hover-widen transition and the full click-to-expand transition (the user described both the same way; no asymmetry was requested between them).
- **D-07:** Exact spring numbers (response/dampingFraction or equivalent) are Claude's discretion — tune via on-device iteration, matching this project's established pattern (e.g. Phase 18's 5-round on-device toast tuning). Current values (0.35 / 0.65) are the "too fast, not enough overshoot" reference point to move away from, not a starting point to preserve.

### Shape refinements
- **D-08:** The expanded blob's bottom-corner radius should be noticeably MORE rounded than today's `bottomCornerRadius: 20` (used by `mediaExpanded`/`expandedIsland`/`mediaUnavailable` in `NotchPillView.swift`) — reference: Droppy's expanded view reads distinctly "prall"/rounder at the bottom. Exact value is Claude's discretion / on-device tuning; direction is "significantly rounder," not a specific pt value.
- **D-09 (confirmed, no change needed):** The existing top-corner "flowing merge into the screen edge" look (the notch shape goes straight down, then sharply curves outward and blends into the screen's top edge) is ALREADY implemented via `NotchShape.swift`'s quad-curve top-corner technique (`topCornerRadius`, ISL-01 from Phase 1). User confirmed this already matches the Droppy reference they pointed to — preserve as-is; only the `topCornerRadius` numeric value is open to minor on-device tuning, no new shape mechanism needed.
- **D-10 (confirmed, no change needed):** The collapsed pill's position under the physical camera/notch is already correct — no change.
- **D-11 (confirmed, no change needed):** The collapsed media-glance layout (album art LEFT, animated equalizer bars RIGHT — `mediaWingsRow` in `NotchPillView.swift`) must be preserved exactly as-is; this phase only changes the shape's material/fill, never its content layout. The user referenced Droppy's now-playing screenshot only to confirm Islet's own existing layout already matches what they want, not to request a layout change. Whether this glance is triggered by hover vs. click is an interaction/functional question, explicitly out of scope for this design-only phase (already governed by the locked D-02 Alcove hover/click model from Phase 2 — not reopened here).

### Claude's Discretion
- Exact gradient stop positions/percentages (where along the height the ~50% floor is reached) — tune on-device against D-02's "long opaque stretch, mild fade only near the very bottom" description.
- Exact spring response/damping values (D-07).
- Exact bottom-corner-radius value (D-08).
- Exact `topCornerRadius` tuning if any (D-09).
- Whether the gradient is implemented as a SwiftUI `LinearGradient` fill on `NotchShape`, a `.mask`, or another mechanism — technical implementation, not discussed with the user.
- Whether the material appearance is per-corner-radius-shape (pill vs. wings vs. expanded blob use different `NotchShape` radius configs today) needs any special-casing for the gradient to read consistently across all three, or whether one shared gradient definition just works — research/planner judgment call.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` §Visual Redesign — VISUAL-01 (gradient material), VISUAL-02 (animation), VISUAL-03 (Theming section — **descoped from this phase, see D-04; REQUIREMENTS.md itself has not yet been edited to reflect this and needs a follow-up pass before/at planning**)
- `.planning/ROADMAP.md` §"Phase 25: Visual/Material Theming Redesign" — Goal, Depends on (none), 5 Success Criteria (note: Success Criterion #3, the Theming Settings section, is also affected by D-04's descope)

### Design reference (Droppy competitor app, shown live during this discussion)
- `.planning/research/inspiration/notes.md` — general Droppy reference notes from earlier v1.4 scoping; user's overall take there ("loves the interaction/animation feel — wie ein 360Hz Monitor, very smooth, sometimes deliberately slow, which reads as premium") is the SAME framing repeated and sharpened in this discussion (D-05/D-06).
- **Screenshots shown during this discussion were NOT saved as files** (image-cache directory was not accessible from the shell) — described in full instead: (1) Droppy's expanded Now Playing view with a very rounded bottom edge and a 3-icon Home/Tray/Grid switcher pill underneath (informs D-08 bottom-radius direction; switcher itself deferred, see below); (2)+(3) Droppy's collapsed/empty-tray states showing the flowing top-corner-into-screen-edge silhouette (confirms D-09 already matches); (4) a close crop of Droppy's expanded view specifically illustrating the black-to-~50%-transparent gradient depth (D-02); (5) a close crop of the 3-icon switcher pill alone (deferred, see below). If pixel-exact reference is needed later, ask the user to re-share these Droppy screenshots.

### Existing code this phase modifies
- `Islet/Notch/NotchPillView.swift` — `collapsedFill` (flat `Color.black`/DEBUG red), `blobShape()`'s `.fill(Color.black)`, `wingsShape()`'s `.fill(Color.black)`, `mediaWingsOrToast`'s own `.fill(Color.black)` — all four fill sites need the shared gradient. `bottomCornerRadius` values passed into `NotchShape` at each call site (20 for expanded/media/unavailable, 6 for wings) — D-08 raises the expanded ones.
- `Islet/Notch/NotchShape.swift` — the quad-curve `topCornerRadius`/`bottomCornerRadius` shape (D-09 confirms no mechanism change, preserve).
- `Islet/Notch/NotchWindowController.swift` — `springResponse: Double = 0.35` / `springDamping: Double = 0.65` (line ~264-265), used at every `withAnimation(.spring(response:dampingFraction:))` call site across the hover/click/grace-collapse state machine (D-05/D-06/D-07 target these).

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchShape.swift` — the asymmetric quad-curve pill shape (topCornerRadius/bottomCornerRadius as plain `CGFloat` stored properties, SwiftUI-`Shape`-animatable) is the single shape every collapsed/expanded/wings state already renders through via `matchedGeometryEffect(id: "island")`. The gradient fill is a `.fill(...)` swap on this same shape — no new shape needed.
- `Islet/Notch/NotchWindowController.swift` `springResponse`/`springDamping` — the ONE pair of constants driving every spring in the app (11 call sites all read the same two `private let`s). Changing these two values changes the feel everywhere at once — no per-call-site drift to worry about.

### Established Patterns
- **Single shared morph identity** (`matchedGeometryEffect(id: "island", in: ns)`) — every presentation state (collapsed, wings, expanded, toast) renders through the SAME shape identity so SwiftUI morphs one shape rather than cross-fading. The gradient fill must work correctly at every interpolated frame of that morph, not just at rest states.
- **View drives no animation itself** (D-08 from Phase 1/ISL) — `NotchPillView` is purely declarative; all spring wrapping happens in `NotchWindowController`. The gradient fill is static per-frame (SwiftUI already animates shape/frame changes); no separate animation logic needed for the material itself, only for D-05/D-06's spring tuning.
- **On-device iterative tuning is normal in this project** — Phase 7, Phase 18 (5 rounds), Phase 20/21/23 UAT all refined exact numeric/visual values after an initial implementation, not before. D-07/D-08's "Claude's discretion, tune on-device" follows this established convention rather than blocking on precise numbers now.

### Integration Points
- `NotchPillView`'s 4 fill sites (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) are the only integration points for the gradient material.
- `NotchWindowController`'s `springResponse`/`springDamping` constants are the only integration point for the animation feel change.

</code_context>

<specifics>
## Specific Ideas

- Droppy (competitor app, screenshots shown live in this discussion) is the direct visual reference for: gradient depth (long opaque stretch, ~50% floor only at the very bottom — NOT near-fully transparent), and the general "ultra fluid, deliberately slow, premium" animation character.
- The rounded-bottom + flowing-top-corner silhouette from Droppy's screenshots essentially already matches Islet's own `NotchShape` design (D-09) — this phase is refining an existing correct foundation, not building a new shape mechanism.
- A 3-icon Home/Tray/[third-view] switcher pill appeared in multiple Droppy screenshots the user referenced — explicitly flagged by the user as a "for later" idea, not part of this phase (see Deferred below).

</specifics>

<deferred>
## Deferred Ideas

- **3-icon view-switcher pill (Home / Tray / third view)** — a small rounded capsule below the main island with 3 tappable icon buttons to switch between "surfaces" (Home glance, Tray/shelf, and a third view). User explicitly wants this eventually but flagged it as "later," not part of Phase 25's material/animation-only scope. This is a new navigation capability, not a material question. **Likely home: Phase 28 (Calendar Full View)**, whose own Success Criterion #1 already implies "a third view alongside Home and Tray" — the switcher pill is probably how Phase 28 will need to let users move between those views. Visual reference: rounded capsule, positioned below the main island, matching whatever black-gradient material this phase ships, 3 icon-only buttons (no labels) with the active one highlighted. Surface this explicitly when discussing Phase 28.
- **VISUAL-03 (Theming Settings section, per-element accent colors, app icon variants)** — descoped from Phase 25 (see D-04). Not re-deferred here since it's already a formal requirement — needs a REQUIREMENTS.md/ROADMAP.md edit to relocate it (candidate: fold into Phase 27 Settings Sidebar Redesign, which already needs a "System (Theming)" section) rather than losing track of it as a loose idea.

</deferred>

---

*Phase: 25-Visual-Material-Theming-Redesign*
*Context gathered: 2026-07-11*
