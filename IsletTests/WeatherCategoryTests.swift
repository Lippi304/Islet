import XCTest
@testable import Islet

// Phase 14 / WEATHER-01: the PURE WeatherCondition -> WeatherCategory classification seam
// (D-06). Like DeviceActivity's deviceGlyph(name:classMajor:), this is a total, exhaustive
// mapping — every WeatherKit.WeatherCondition case (including any unlisted/future one) maps
// to exactly one of 4 categories via a `default:` fallback, so this is unit-tested
// deterministically without any network call or permission gate.
final class WeatherCategoryTests: XCTestCase {

    func testClearMapsToSunny() {
        XCTAssertEqual(WeatherCategory.from(.clear), .sunny)
    }

    func testRainMapsToRain() {
        XCTAssertEqual(WeatherCategory.from(.rain), .rain)
    }

    func testSnowMapsToSnow() {
        XCTAssertEqual(WeatherCategory.from(.snow), .snow)
    }

    func testCloudyMapsToCloudy() {
        XCTAssertEqual(WeatherCategory.from(.cloudy), .cloudy)
    }

    func testFoggyUnlistedCaseFallsBackToCloudy() {
        // D-06 fail-safe: an unlisted/miscellaneous case must never crash — it falls into
        // the exhaustive `default: .cloudy` bucket.
        XCTAssertEqual(WeatherCategory.from(.foggy), .cloudy)
    }
}
