import WeatherKit
import CoreLocation

// Phase 14 / WEATHER-01, extended Phase 33 / WEATHER-01/02 — the WeatherKit fetch SEAM
// (D-01/D-06), mirroring LicenseService.swift's protocol-isolation convention: a
// fragile/replaceable external is quarantined behind ONE `AnyObject` protocol with a
// single `final class` conformer. A future WeatherKit API change becomes a one-file swap,
// never a call-site rewrite.
//
// CONTRACT — `completion` is ALWAYS delivered on the MAIN thread (mirrors
// LicenseService.swift's file-header contract).
//
// Phase 33: `fetchCurrentAndForecast` replaces the old single-dataset `fetchCurrent` with
// ONE combined `weather(for:including: .current, .daily)` call — current conditions and the
// multi-day forecast never cost two separate WeatherKit requests. `resolvePlaceName` reverse-
// geocodes the same `CLLocation` already used for the weather fetch (no new permission ask).

/// One day's forecast entry from the `.daily` WeatherKit dataset.
struct DailyForecast: Equatable, Identifiable {
    var id: Date { date }
    let date: Date
    let category: WeatherCategory
    let high: Measurement<UnitTemperature>
    let low: Measurement<UnitTemperature>
}

/// The classified weather glance the render layer consumes. `temperature` is WeatherKit's own
/// `Measurement<UnitTemperature>` — no manual Celsius/Fahrenheit conversion here; the render
/// layer formats it locale-aware via `.formatted()`, mirroring the existing time/date
/// formatters' locale-aware convention in `Islet/Notch/NotchPillView.swift`. `high`/`low` come
/// from today's `.daily` entry alongside the `.current` dataset in the same combined fetch.
struct WeatherGlance: Equatable {
    let category: WeatherCategory
    let temperature: Measurement<UnitTemperature>
    let high: Measurement<UnitTemperature>?
    let low: Measurement<UnitTemperature>?
}

/// One hour's forecast entry from the `.hourly` WeatherKit dataset — no high/low, hourly
/// exposes a single `.temperature` per entry (unlike `DailyForecast`'s high/low pair).
struct HourlyForecast: Equatable, Identifiable {
    var id: Date { date }
    let date: Date
    let category: WeatherCategory
    let temperature: Measurement<UnitTemperature>
}

protocol WeatherService: AnyObject {
    /// Fetch current conditions (with today's high/low), the multi-day forecast, and the
    /// hourly forecast in a single combined WeatherKit request.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `(nil, nil, nil)` on any permission denial or fetch failure (D-01) — never retries;
    ///   the coarse refresh timer built in 14-04 is the only re-attempt mechanism.
    func fetchCurrentAndForecast(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?, [DailyForecast]?, [HourlyForecast]?) -> Void)

    /// Reverse-geocode a location into a place name.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `nil` on any error, nil placemarks, or empty locality (D-02) — the "Local"
    ///   fallback substitution itself is a view-layer concern.
    func resolvePlaceName(for location: CLLocation, completion: @escaping (String?) -> Void)
}

final class WeatherKitService: WeatherService {
    private let service = WeatherKit.WeatherService.shared
    private let geocoder = CLGeocoder()

    func fetchCurrentAndForecast(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?, [DailyForecast]?, [HourlyForecast]?) -> Void) {
        Task {
            do {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                let (current, hourly, daily) = try await service.weather(for: location, including: .current, .hourly, .daily)
                let today = daily.first   // Forecast<DayWeather> is a RandomAccessCollection; .first is "today"
                let glance = WeatherGlance(category: WeatherCategory.from(current.condition),
                                           temperature: current.temperature,
                                           high: today?.highTemperature,
                                           low: today?.lowTemperature)
                let forecast = daily.map { day in
                    DailyForecast(date: day.date,
                                  category: WeatherCategory.from(day.condition),
                                  high: day.highTemperature,
                                  low: day.lowTemperature)
                }
                let hourlyForecast = hourly.map { hour in
                    HourlyForecast(date: hour.date,
                                   category: WeatherCategory.from(hour.condition),
                                   temperature: hour.temperature)
                }
                await MainActor.run { completion(glance, forecast, hourlyForecast) }
            } catch {
                // D-01: no retry inside this call — silent omission on any thrown error.
                await MainActor.run { completion(nil, nil, nil) }
            }
        }
    }

    func resolvePlaceName(for location: CLLocation, completion: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            // D-02 convention: any error, nil placemarks, or an empty locality settles nil —
            // never a blank field, never an error string, never a retry. The "Local"
            // placeholder substitution itself is a view-layer concern (Plan 33-02).
            let locality = placemarks?.first?.locality
            let name = (locality?.isEmpty ?? true) ? nil : locality
            DispatchQueue.main.async { completion(name) }   // completion contract: always main thread
        }
    }
}
