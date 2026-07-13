import Foundation

// Phase 28 / CALVIEW-04 — the single source of truth for which of Home/Tray/Calendar/Weather is
// active. Mirrors Islet/Shelf/ShelfViewState.swift's exact shape: a plain published holder,
// no methods, no timers. Plan 03's `resolve(...)` extension and NotchPillView's switcher pill
// both reference this type; defined here (not in Plan 03) so Plan 03 doesn't forward-declare it.
// 28-04 round 4 (user-confirmed scope expansion) — `.weather` added as the 4th tab, appended
// after `.calendar` (Home/Tray/Calendar/Weather order, no reordering of the existing three).
enum SelectedView: Equatable {
    case home
    case tray
    case calendar
    case weather
}

final class ViewSwitcherState: ObservableObject {
    @Published var selectedView: SelectedView = .home
}
