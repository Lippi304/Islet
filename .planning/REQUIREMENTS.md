# Requirements: Notch — Dynamic Island for Mac (Islet)

**Defined:** 2026-07-09
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island.

## v1.3 Requirements — Notch Shelf

Drag-and-drop file shelf: a session-only staging area for files, appended below the island's expanded view. Standard `NSItemProvider` drag & drop, no private API.

### File Shelf

- [ ] **SHELF-01**: User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view
- [ ] **SHELF-02**: Drop target shows "hot"/targeted visual feedback while a file is being dragged over, before release
- [ ] **SHELF-03**: Shelf strip is appended below whatever else is showing expanded (Now Playing, idle glance, etc.) whenever it has content, and scrolls horizontally with unbounded capacity
- [ ] **SHELF-04**: Each shelf item shows a file-type icon with its own small trash icon for individual removal
- [ ] **SHELF-05**: A single "delete all" trash icon on the far right clears the entire shelf at once
- [ ] **SHELF-06**: User can drag a shelf item back out to Finder or any other app
- [ ] **SHELF-07**: Clicking a shelf item opens it in its default application
- [ ] **SHELF-08**: Shelf content is purely session-temporary — cleared on manual delete, app restart, or Mac restart; never persisted to disk
- [ ] **SHELF-09**: Shelf is suppressed while a Charging or Device wings splash is actively showing, reappearing once the splash dismisses

## v2 Requirements

Deferred to a future milestone, not in this roadmap.

### File Shelf Polish

- **SHELF-P1**: Real QuickLook thumbnails instead of generic file-type icons
- **SHELF-P2**: Drag-out lift/shrink animation
- **SHELF-P3**: Non-empty-shelf badge on the collapsed pill
- **SHELF-P4**: Drop-triggered action picker (DynaDrop-style: AirDrop/convert/share-link)

### Other candidates (not yet scoped)

- WEATHER-01, CAL-01, OUTFIT-01 — formalize the already-shipped Phase 14 weather/calendar/date glance as requirements
- System HUD replacement (volume/brightness)
- Countdown timer

## Out of Scope

| Feature | Reason |
|---------|--------|
| Persisted/cross-restart shelf retention or iCloud sync | Contradicts the explicit session-only requirement |
| Fixed low item cap | Unbounded scroll chosen instead |
| Folder spring-loading (auto-navigating into dropped folder contents) | Folders are just one shelf item, not a container to browse |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELF-01 | TBD | Pending |
| SHELF-02 | TBD | Pending |
| SHELF-03 | TBD | Pending |
| SHELF-04 | TBD | Pending |
| SHELF-05 | TBD | Pending |
| SHELF-06 | TBD | Pending |
| SHELF-07 | TBD | Pending |
| SHELF-08 | TBD | Pending |
| SHELF-09 | TBD | Pending |

**Coverage:**
- v1.3 requirements: 9 total
- Mapped to phases: 0
- Unmapped: 9 ⚠️ (roadmap not yet created)

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-09 after initial v1.3 definition*
