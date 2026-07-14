import XCTest
import CoreLocation
@testable import Islet

// Phase 33 / WEATHER-01/02 — proves the extended WeatherService protocol seam (combined
// fetchCurrentAndForecast + resolvePlaceName). Mirrors LocationServiceTests.swift's
// in-memory-fake-conformer pattern: no real WeatherKit/CLGeocoder I/O executes during this
// test run.
final class WeatherServiceTests: XCTestCase {

    // In-memory fake conforming to WeatherService — no real WeatherKit/CLGeocoder I/O.
    private final class FakeWeatherService: WeatherService {
        private(set) var fetchCurrentAndForecastCallCount = 0
        private(set) var lastFetchCompletion: ((WeatherGlance?, [DailyForecast]?) -> Void)?

        private(set) var resolvePlaceNameCallCount = 0
        private(set) var lastGeocodeCompletion: ((String?) -> Void)?

        func fetchCurrentAndForecast(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?, [DailyForecast]?) -> Void) {
            fetchCurrentAndForecastCallCount += 1
            lastFetchCompletion = completion
        }

        func resolvePlaceName(for location: CLLocation, completion: @escaping (String?) -> Void) {
            resolvePlaceNameCallCount += 1
            lastGeocodeCompletion = completion
        }
    }

    // (a) Pitfall 1's "one call, not two" contract: a synthetic WeatherGlance + [DailyForecast]
    // round-trips through lastFetchCompletion, and exactly one invocation was made.
    func testFetchCurrentAndForecastRoundTripsAndCallsExactlyOnce() {
        let fake = FakeWeatherService()
        var receivedGlance: WeatherGlance?
        var receivedForecast: [DailyForecast]?

        fake.fetchCurrentAndForecast(latitude: 52.5, longitude: 13.4) { glance, forecast in
            receivedGlance = glance
            receivedForecast = forecast
        }

        let syntheticGlance = WeatherGlance(category: .sunny,
                                            temperature: Measurement(value: 20, unit: .celsius),
                                            high: Measurement(value: 24, unit: .celsius),
                                            low: Measurement(value: 15, unit: .celsius))
        let syntheticForecast = [DailyForecast(date: Date(),
                                               category: .cloudy,
                                               high: Measurement(value: 22, unit: .celsius),
                                               low: Measurement(value: 14, unit: .celsius))]
        fake.lastFetchCompletion?(syntheticGlance, syntheticForecast)

        XCTAssertEqual(receivedGlance, syntheticGlance)
        XCTAssertEqual(receivedForecast, syntheticForecast)
        XCTAssertEqual(fake.fetchCurrentAndForecastCallCount, 1)
    }

    // (b) resolvePlaceName's completion round-trips a synthetic place-name string.
    func testResolvePlaceNameRoundTripsSyntheticName() {
        let fake = FakeWeatherService()
        var receivedName: String?

        fake.resolvePlaceName(for: CLLocation(latitude: 52.5, longitude: 13.4)) { name in
            receivedName = name
        }

        fake.lastGeocodeCompletion?("Berlin")

        XCTAssertEqual(receivedName, "Berlin")
        XCTAssertEqual(fake.resolvePlaceNameCallCount, 1)
    }

    // (c) resolvePlaceName's completion delivering nil round-trips nil — the "Local"
    // substitution itself is a Plan 33-02 view-layer concern, verified on-device there.
    func testResolvePlaceNameRoundTripsNilOnFailure() {
        let fake = FakeWeatherService()
        var receivedName: String? = "not yet nil"

        fake.resolvePlaceName(for: CLLocation(latitude: 52.5, longitude: 13.4)) { name in
            receivedName = name
        }

        fake.lastGeocodeCompletion?(nil)

        XCTAssertNil(receivedName)
    }
}
