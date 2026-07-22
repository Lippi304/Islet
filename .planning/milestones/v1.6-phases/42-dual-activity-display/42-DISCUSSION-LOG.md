# Phase 42: Dual-Activity Display - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-18
**Phase:** 42-Dual-Activity Display
**Areas discussed:** Primary/Secondary-Zuordnung, Secondary-Bubble Design, Transient-Verhalten, Tap/Klick auf die Secondary-Bubble

---

## Primary/Secondary-Zuordnung

| Option | Description | Selected |
|--------|-------------|----------|
| Countdown = primary | Continues Phase 41 D-01 ranking; Now-Playing moves to secondary instead of being fully suppressed | ✓ |
| Now-Playing = primary | Reverses D-01 | |
| Reihenfolge des Auftretens | Whoever appeared first stays primary | |

**User's choice:** Countdown = primary.

**Follow-up — D-01's fate:** Asked whether Phase 41 D-01 (Countdown fully suppresses Now-Playing) is replaced or kept as a fallback. User's free-text response: "Es geht darum das ja musik eigentlich von allem überspielt wird aber eben die musik als diese extra runde pille aufklappt rechts davon als kreis." (Music is normally overridden by everything else, but specifically here it appears as an extra round pill/circle to the right.) Interpreted and confirmed: D-01 is superseded — Now-Playing is no longer invisible when Countdown is active, it renders as the round secondary bubble instead.

**Confirmation question:** Is the round-circle-to-the-right shape general for ANY secondary activity, or Now-Playing-specific? User confirmed: general shape, not music-specific.

| Option | Description | Selected |
|--------|-------------|----------|
| 2-Eintrags-Tabelle reicht | Only Countdown/Now-Playing exist today; table form (not if/else) is enough prep | ✓ |
| Sonstiges | User has other activity pairs in mind | |

**User's choice:** 2-entry table is sufficient (YAGNI for hypothetical third activities).

| Option | Description | Selected |
|--------|-------------|----------|
| Nein, unverändert | Single-activity case stays exactly as today, secondary is nil | ✓ |
| Ja, etwas soll anders sein | Something should change | |

**User's choice:** Unchanged — no empty-bubble state.

**Notes:** D-01/D-02/D-03/D-04 in CONTEXT.md capture this area.

---

## Secondary-Bubble Design

| Option | Description | Selected |
|--------|-------------|----------|
| Album-Cover (rund zugeschnitten) | Real artwork, circularly cropped | ✓ |
| Generic Music-Icon | Simple SF Symbol instead | |

**User's choice:** Album cover, circularly cropped.

| Option | Description | Selected |
|--------|-------------|----------|
| Kleiner als die Pille (~24-28pt) | Reads clearly as secondary | ✓ |
| Gleiche Höhe wie die Pille (32pt) | Visually equal weight | |

**User's choice:** Smaller (~24-28pt).

| Option | Description | Selected |
|--------|-------------|----------|
| Kleiner sichtbarer Spalt | Two distinct shapes with a gap | ✓ |
| Direkt anliegend/überlappend | Fused single-object look | |

**User's choice:** Small visible gap.

| Option | Description | Selected |
|--------|-------------|----------|
| Morph wie die Haupt-Pille (eigener Namespace) | Same spring morph, own matchedGeometryEffect id | ✓ |
| Einfaches Fade-in/-out | Simpler but breaks the morph-everything feel | |

**User's choice:** Morph via its own matchedGeometryEffect namespace, consistent with the rest of the project.

**Notes:** D-05 through D-09 in CONTEXT.md capture this area.

---

## Transient-Verhalten (Charging/Device/Focus/OSD)

| Option | Description | Selected |
|--------|-------------|----------|
| Verdrängt beide komplett | Transient wins the entire display, no secondary remnant, matches D-04 precedent | ✓ |
| Ersetzt nur Primary, Secondary bleibt | Secondary bubble stays alongside the transient | |

**User's choice:** Transient suppresses both slots entirely.

| Option | Description | Selected |
|--------|-------------|----------|
| Gleichzeitig | Both morph back at the same instant | |
| Pille zuerst, Kreis leicht verzögert | Staggered two-step reveal | ✓ |

**User's choice:** Staggered — primary pill first, secondary bubble morphs in slightly after.

| Option | Description | Selected |
|--------|-------------|----------|
| Identisch für alle 4 | One rule for Charging/Device/Focus/OSD, no per-type special case | ✓ |
| Sonstiges | One transient type should behave differently | |

**User's choice:** Identical suppression rule across all 4 transient types.

**Notes:** D-10/D-11 in CONTEXT.md capture this area.

---

## Tap/Klick auf die Secondary-Bubble

| Option | Description | Selected |
|--------|-------------|----------|
| Expandiert zur jeweiligen Ansicht | Tapping opens that activity's own view, same as tapping it as primary would today | ✓ |
| Tut nichts (inert) | Only the primary pill is tappable | |
| Tauscht Primary/Secondary | Tapping swaps which activity is primary | |

**User's choice:** Expands to that activity's own view — the bubble is a real, independent tap target.

| Option | Description | Selected |
|--------|-------------|----------|
| Komplett passiv | No hover effect, consistent with Phase 41 D-08 | ✓ |
| Leichte Hervorhebung beim Hover | Slight highlight affordance on hover | |

**User's choice:** Fully passive — no hover effect.

**Notes:** D-12/D-13 in CONTEXT.md capture this area.

---

## Claude's Discretion

- Exact pixel values for the bubble diameter (within ~24-28pt), the gap width, and the stagger delay duration — left to research/planning, to be tuned against real on-device measurement per the project's established convention.
- Whether the ranking table is a literal tuple/array structure or a small dedicated function — implementation detail, only the "explicit ordered table, not scattered conditionals" requirement is locked.

## Deferred Ideas

None — discussion stayed fully within the phase's Countdown+Now-Playing, two-slot scope. Generalizing beyond two concurrent activities is already explicitly out of scope per REQUIREMENTS.md, not raised as new scope here.
