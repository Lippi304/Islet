import WeatherKit
import CoreLocation

// Phase 14 / WEATHER-01 — the WeatherKit fetch SEAM (D-01/D-06), mirroring
// LicenseService.swift's protocol-isolation convention: a fragile/replaceable external
// is quarantined behind ONE `AnyObject` protocol with a single `final class` conformer.
// A future WeatherKit API change becomes a one-file swap, never a call-site rewrite.
//
// CONTRACT — `completion` is ALWAYS delivered on the MAIN thread (mirrors
// LicenseService.swift's file-header contract).

/// The classified weather glance the render layer consumes. `temperature` is WeatherKit's own
/// `Measurement<UnitTemperature>` — no manual Celsius/Fahrenheit conversion here; the render
/// layer formats it locale-aware via `.formatted()`, mirroring the existing time/date
/// formatters' locale-aware convention in `Islet/Notch/NotchPillView.swift`.
struct WeatherGlance: Equatable {
    let category: WeatherCategory
    let temperature: Measurement<UnitTemperature>
}

protocol WeatherService: AnyObject {
    /// Fetch the current weather glance for a coordinate.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `nil` on any permission denial or fetch failure (D-01) — never retries; the
    ///   coarse refresh timer built in 14-04 is the only re-attempt mechanism.
    func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void)
}

final class WeatherKitService: WeatherService {
    private let service = WeatherKit.WeatherService.shared

    func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void) {
        Task {
            do {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                let weather = try await service.weather(for: location)
                let glance = WeatherGlance(category: WeatherCategory.from(weather.currentWeather.condition),
                                           temperature: weather.currentWeather.temperature)
                await MainActor.run { completion(glance) }
            } catch {
                // D-01: no retry inside this call — silent omission on any thrown error.
                await MainActor.run { completion(nil) }
            }
        }
    }
}
