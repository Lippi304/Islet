import Foundation

// Phase 65 / QACTION-01/QACTION-02 (D-01/D-03) — the fixed 8-slot Quick Actions bar catalog.
// Naming rule (RESEARCH.md Pitfall 1 / UI-SPEC Verification Notes): every type in this file is
// prefixed `QuickActionsBar*` — never bare `QuickAction*`, which collides with Phase 34's
// existing `QuickActionSharingService`/`IslandResolver.swift`'s unrelated
// `IslandPresentation.quickActionPicker(PendingDrop)` case.
//
// Mirrors `Islet/Notch/ViewSwitcherState.swift`'s exact shape: a plain `String, CaseIterable`
// enum plus one small pure ordering-projection function — no persistence, no side effects, no
// AppKit/SwiftUI imports.
enum QuickActionsBarCatalog {
    // `.none` is the "unconfigured slot" sentinel — mirrors `WeatherStyle`'s `?? .medium`
    // fallback-to-safe-default convention, NOT an Optional. An unconfigured/corrupted slot
    // always parses to (or falls back to) `.none`, never crashes.
    enum Action: String, CaseIterable, Equatable {
        case none
        case micMute
        case displaySleep
        case darkMode
        case screenLock
        case focusToggle
        case caffeinate
        case emptyTrash
        case launch
    }
}

// The ONE place that turns the 8 independent slot values into the ordered, empty-filtered
// array later plans render (mirrors `orderedSlotIcons`'s single-source-of-truth role). D-03:
// the underlying storage stays 8 independent AppStorage keys — never a single encoded array —
// this is only a runtime projection over the 8 already-read values.
func orderedQuickActionsBarSlots(_ slots: [QuickActionsBarCatalog.Action]) -> [QuickActionsBarCatalog.Action] {
    slots.filter { $0 != .none }
}
