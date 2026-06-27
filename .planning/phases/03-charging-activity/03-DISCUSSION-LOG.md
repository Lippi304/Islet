# Phase 3: Charging Activity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 3-charging-activity
**Areas discussed:** Darstellungsform, Lade-Visual & Animation, Zustände & Info, Dauer & Interaktion

---

## Darstellungsform (Presentation form)

| Option | Description | Selected |
|--------|-------------|----------|
| Wings / Alcove | Content flanks the physical notch: symbol left, % right, pill widens but stays flat. Most authentic DI look; new layout direction vs the downward morph | ✓ |
| Drop-down Blob | Island morphs down to the compact expanded area (reuses Phase-2 morph), symbol + % centered. Consistent & simplest | |
| Breitere Pille | Pill just gets slightly wider, symbol + % inline, no expansion. Most subtle | |

**User's choice:** Wings / Alcove-Stil.
**Notes:** Most authentic Dynamic-Island look; accepted that it is a new sideways layout
direction vs the existing downward morph. Sets the skeleton for Phase 4 (Now Playing).

---

## Lade-Visual & Animation (Charge visual & animation)

| Option | Description | Selected |
|--------|-------------|----------|
| Filling battery glyph + % | Battery icon that fills to level, number alongside | ✓ |
| Ring/arc around % | Apple-Watch-style circular progress around the percentage | |
| Numeric only | Just the number, no graphic | |

**User's choice:** Filling battery glyph + %.

| Option | Description | Selected |
|--------|-------------|----------|
| Lively | Wings slide out + battery fills once + brief glow/pulse on bolt. Closest to Alcove | ✓ |
| Subtle | Gentle fade-in + slight scale, no extra pulse | |
| You decide | Tune springs/duration on-device | |

**User's choice:** Lively appearance.

---

## Zustände & Info (States & info)

| Option | Description | Selected |
|--------|-------------|----------|
| One consistent battery glyph that switches | Bolt (charging) → full/green at 100% → plain battery (no bolt) on unplug. Clear & uniform | ✓ |
| Per-state mini-scenes | Charging=bolt+fill, Full="Fully Charged"+check, On-battery=own gesture. More expressive, more work | |
| Minimal | Just bolt on/off + %; full = bolt off at 100%, on-battery = same image via unplug | |

**User's choice:** One consistent battery glyph that switches.

| Option | Description | Selected |
|--------|-------------|----------|
| Percentage only | Simple & robust; time-to-full / wattage maybe v2 | ✓ |
| % + time to full | e.g. "~1:20 to full" (estimate can fluctuate) | |
| % + adapter wattage | e.g. "67W" | |

**User's choice:** Percentage only.

---

## Dauer & Interaktion (Duration & interaction)

| Option | Description | Selected |
|--------|-------------|----------|
| ~3 seconds | Long enough to read, short enough not to annoy | ✓ |
| ~2 seconds | Very short & subtle | |
| ~4-5 seconds | Stays up longer | |
| You decide | Tune on-device | |

**User's choice:** ~3 seconds.

| Option | Description | Selected |
|--------|-------------|----------|
| Hover holds open, click informational | Auto-dismiss pauses on hover, resumes after pointer leaves; click does nothing special | ✓ |
| Click dismisses immediately | Manual dismiss on click | |
| Nothing | Splash runs its time, hover/click ignored | |

**User's choice:** Hover holds open; click is informational only.

| Option | Description | Selected |
|--------|-------------|----------|
| Charging splash takes brief precedence | User just physically plugged in → island shows feedback, then returns | ✓ |
| User-open state stays | Charging waits/ignored until the user closes the island | |
| You decide | Rare edge case, simplest sane solution | |

**User's choice:** Charging splash takes brief precedence.

## Claude's Discretion

- The "activity" abstraction / mechanism (how a programmatic transient state lives alongside the
  `InteractionPhase` machine) — recommended charging-specific with a clean seam, no general resolver.
- IOKit wiring (IOPS APIs, run-loop source, main-thread hop).
- Exact wings geometry, SF Symbols, colors, spring/duration tuning, optional checkmark at 100%.
- The pure power-state→presentation mapping seam (TDD).

## Deferred Ideas

- Time-to-full / adapter wattage in the splash → v2.
- Click-to-open battery detail panel → not v1.
- General multi-activity priority resolver → Phase 6 (COORD-01).
- Per-state mini-scenes → dropped for the consistent glyph.
- Low-battery warning / battery HUD → out of scope.
- Charging-activity settings toggle + accent/theme → Phase 6 (APP-03).
