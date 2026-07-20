import Foundation

// Phase 14 / WEATHER-01 + CAL-01 — the SEPARATE @Published data holder, mirroring
// NowPlayingState.swift's minimal published-holder shape (NotchPillView.swift's usage
// contract). No methods, no timers, no fetch logic: the controller (14-04) is the only
// writer, the view is the only reader.
@MainActor
final class BasicOutfitState: ObservableObject {
    @Published var weather: WeatherGlance?
    @Published var calendar: CalendarGlance?
    // Phase 33 / WEATHER-01/02 — same controller-only-writer/view-only-reader contract as
    // weather/calendar above. forecast is only meaningfully read when the extended-forecast
    // toggle is on; locationName resolves via reverse-geocode, nil while pending/on failure.
    @Published var forecast: [DailyForecast]?
    @Published var locationName: String?
    // Phase 33 / WEATHER-01/02 — same controller-only-writer/view-only-reader contract as
    // forecast above. Populated unconditionally regardless of the Medium/Large Settings
    // choice; the view layer decides what to render.
    @Published var hourlyForecast: [HourlyForecast]?
}
