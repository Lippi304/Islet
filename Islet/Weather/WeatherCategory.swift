import WeatherKit

// Phase 14 / WEATHER-01 — the PURE WeatherCondition -> WeatherCategory classification seam
// (D-06), mirroring Islet/Notch/DeviceActivity.swift's deviceGlyph(name:classMajor:) pattern.
//
// This is a total, Foundation/WeatherKit-type-only function with NO network call, no
// permission gate, and no async context — it only references the `WeatherCondition` enum
// TYPE, never calls `WeatherService.shared.weather(for:)`. That live/async fetch is built in
// 14-03's `WeatherKitService`, which converts a real fetched condition into one of the 4
// categories here before it ever reaches the render layer. The exhaustive `default: .cloudy`
// fallback means an unlisted/future WeatherCondition case is a cosmetic miscategorization at
// worst, never a compile error or a crash (T-14-01).
enum WeatherCategory: Equatable {
    case sunny, cloudy, rain, snow

    static func from(_ condition: WeatherKit.WeatherCondition) -> WeatherCategory {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .sunny
        case .snow, .heavySnow, .blizzard, .flurries, .sleet, .wintryMix, .blowingSnow, .freezingRain, .freezingDrizzle:
            return .snow
        case .rain, .heavyRain, .drizzle, .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms, .hurricane, .tropicalStorm:
            return .rain
        default:   // partlyCloudy, mostlyCloudy, cloudy, foggy, haze, windy, and any future case
            return .cloudy
        }
    }
}
