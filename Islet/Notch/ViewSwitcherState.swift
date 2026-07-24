import Foundation

// Phase 28 / CALVIEW-04 — the single source of truth for which of Home/Tray/Calendar/Weather is
// active. Mirrors Islet/Shelf/ShelfViewState.swift's exact shape: a plain published holder,
// no methods, no timers. Plan 03's `resolve(...)` extension and NotchPillView's switcher pill
// both reference this type; defined here (not in Plan 03) so Plan 03 doesn't forward-declare it.
// 28-04 round 4 (user-confirmed scope expansion) — `.weather` added as the 4th tab, appended
// after `.calendar` (Home/Tray/Calendar/Weather order, no reordering of the existing three).
// Phase 52 / SWITCH-03/04 — String/Hashable/CaseIterable added so this type is
// @AppStorage-compatible (per-slot top-edge switcher placement config) and usable directly
// in `ForEach(_:id: \.self)`. Additive/behavior-preserving: existing call sites compare via
// `==`, none pattern-match on `.rawValue`.
// Phase 62-04 UAT design revision (item 6) — `.timer` added as a 5th case. NOT one of
// the 4 user-configurable slots (orderedSlotIcons below is untouched, still exactly 4
// params): Timer renders as a FIXED 5th icon appended after the configurable slots in
// both switcherRow/topEdgeSwitcherRow (NotchPillView.swift), gated on the same
// `timerEnabled` flag the old Home "Start Timer" button used. SettingsView.swift's 4
// slot dropdowns list Home/Tray/Calendar/Weather explicitly (never `.allCases`), so this
// addition does not make Timer assignable to a configurable slot.
enum SelectedView: String, Equatable, Hashable, CaseIterable {
    case home
    case tray
    case calendar
    case weather
    case timer
}

// Phase 52 / D-03 — the ONE shared left-to-right ordering projection: both the pill's
// switcherRow and the top-edge switcher row call this so there is exactly one place that
// turns 4 independent slot values into an ordered array. No dedup/validation — duplicate
// slot assignments are intentionally allowed.
func orderedSlotIcons(leftOuter: SelectedView,
                      leftInner: SelectedView,
                      rightInner: SelectedView,
                      rightOuter: SelectedView) -> [SelectedView] {
    [leftOuter, leftInner, rightInner, rightOuter]
}

final class ViewSwitcherState: ObservableObject {
    @Published var selectedView: SelectedView = .home
}
