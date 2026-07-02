# Requirements: Notch — Dynamic Island for Mac

**Defined:** 2026-07-02
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island.

## v1.0.1 Requirements

Pre-release polish for the still-unreleased v1.0 build. Each maps to roadmap phases.

### Now Playing Progress Bar (PBAR)

- [ ] **PBAR-01**: User sees a horizontal progress bar in the expanded Now Playing view showing playback position, with elapsed/remaining time labels (e.g. "1:23 / 3:45"); updates smoothly while playing, holds still while paused; no tap-to-seek

### Fullscreen Stability (FS)

- [ ] **FS-01**: Entering true fullscreen shows no visible island flash at any point during or after the transition

## v2 Requirements

Deferred to a future release (v1.0 backlog, unchanged).

### Later Features

- **SHELF-01**: File shelf — drag-and-drop tray at the notch to temporarily hold files, then drag them back out / share / AirDrop
- **HUD-01**: System HUDs — replace the default volume / brightness / battery overlays with notch-based HUDs
- **TMR-01**: Timer — start and watch a countdown timer as a live activity in the island
- **DIST-01**: Real Developer-ID notarization (pending Apple Developer account purchase)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Tap-to-seek on the progress bar | Adds interaction/gesture complexity for a display-only polish milestone; revisit later if desired |
| Best-effort/partial fullscreen-flash reduction | FS-01 is scoped as a full elimination outcome, not a partial mitigation — the phase investigates until it's actually gone or escalates if genuinely impossible |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PBAR-01 | TBD | Pending |
| FS-01 | TBD | Pending |

**Coverage:**
- v1.0.1 requirements: 2 total
- Mapped to phases: 0
- Unmapped: 2 ⚠️ (pending roadmap creation)

---
*Requirements defined: 2026-07-02*
*Last updated: 2026-07-02 after initial definition*
