import Foundation

// Phase 28 / CALVIEW-04 — the single source of truth for which of Home/Tray/Calendar is
// active. Mirrors Islet/Shelf/ShelfViewState.swift's exact shape: a plain published holder,
// no methods, no timers. Plan 03's `resolve(...)` extension and NotchPillView's switcher pill
// both reference this type; defined here (not in Plan 03) so Plan 03 doesn't forward-declare it.
enum SelectedView: Equatable {
    case home
    case tray
    case calendar
}

final class ViewSwitcherState: ObservableObject {
    @Published var selectedView: SelectedView = .home
}
