import Foundation

// Phase 14 / WEATHER-01 + CAL-01 — the SEPARATE @Published data holder, mirroring
// NowPlayingState.swift's minimal published-holder shape (NotchPillView.swift's usage
// contract). No methods, no timers, no fetch logic: the controller (14-04) is the only
// writer, the view is the only reader.
@MainActor
final class BasicOutfitState: ObservableObject {
    @Published var weather: WeatherGlance?
    @Published var calendar: CalendarGlance?
}
