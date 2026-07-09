# Requirements: Notch — Dynamic Island for Mac (Islet)

**Defined:** 2026-07-09
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.

## v1.2 Requirements

Requirements for the "Now Playing Polish" milestone. Each maps to roadmap phases.

### Now Playing

- [ ] **NOW-04**: User does not see the Now Playing glance at Islet launch if the detected player only has a paused/loaded track — the glance appears only once the user actually presses Play
- [ ] **NOW-05**: User sees a brief (~3s) toast with the new track's title when playback switches to a genuinely different song (not on the very first track detected after launch), then the island returns to the compact glance
- [ ] **NOW-06**: User can toggle the song-change toast on/off in Settings (Activities tab, next to the existing Now Playing toggle)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| File shelf, System HUDs, Timer | Deferred large features, not part of this milestone's scope |
| Repeating DeviceCoordinator extraction for Charging/NowPlaying/Outfit | Architecture cleanup, not part of this milestone's scope |
| CR-01 (CGS Space leak on quit) | Pre-existing non-blocking bug, not part of this milestone's scope |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NOW-04 | TBD | Pending |
| NOW-05 | TBD | Pending |
| NOW-06 | TBD | Pending |

**Coverage:**
- v1.2 requirements: 3 total
- Mapped to phases: 0
- Unmapped: 3 ⚠️

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-09 after initial definition*
