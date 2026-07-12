import Foundation
import Darwin

// Quick task 260708-u47 — a point-in-time diagnostic SNAPSHOT for bug reports, not a
// logging system: no persistent file, no background collection, nothing runs unless the
// user clicks "Save Diagnostic Report…" in Settings. Kept as a pure, testable seam
// (internal access, no `private`) mirroring NowPlayingPresentation.swift's convention —
// everything the assembly logic needs is a parameter except the handful of one-line
// system calls that are inherently untestable inputs (timestamp, version, OS, hardware).
enum DiagnosticReport {

    // The ONLY place LicenseStatus becomes user-facing text for this feature. Never
    // formats a raw license key — there isn't one on LicenseStatus to leak; keep it that way.
    static func licenseSummary(for status: LicenseStatus) -> String {
        switch status {
        case .trial(let daysRemaining):
            return daysRemaining == 1
                ? "Trial (1 day remaining)"
                : "Trial (\(daysRemaining) days remaining)"
        case .trialExpired:
            return "Trial expired"
        case .licensed:
            return "Licensed"
        }
    }

    // Reads `hw.model` via sysctlbyname's two-call pattern: size first, then fetch into
    // an allocated buffer. Never force-unwraps — "unknown" on any failure.
    static func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "unknown"
        }
        return String(cString: buffer)
    }

    static func text(licenseStatus: LicenseStatus, launchAtLogin: Bool, chargingEnabled: Bool,
                      nowPlayingEnabled: Bool, deviceEnabled: Bool,
                      nowPlayingAccentIndex: Int, chargingAccentIndex: Int, deviceAccentIndex: Int,
                      nowPlayingHealthy: Bool?) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let bridgeLine: String
        switch nowPlayingHealthy {
        case .some(true):
            bridgeLine = "available"
        case .some(false):
            bridgeLine = "unavailable (MediaRemote bridge not responding)"
        case .none:
            bridgeLine = "unknown (island not running)"
        }

        return """
        Islet Diagnostic Report
        Generated: \(timestamp)

        App Version: \(SettingsView.versionString)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Hardware Model: \(hardwareModel())
        License: \(licenseSummary(for: licenseStatus))
        Launch at Login: \(launchAtLogin ? "on" : "off")

        Activities:
        Charging: \(chargingEnabled ? "on" : "off")
        Now Playing: \(nowPlayingEnabled ? "on" : "off")
        Devices: \(deviceEnabled ? "on" : "off")
        Now Playing Accent: \(nowPlayingAccentIndex)
        Charging Accent: \(chargingAccentIndex)
        Device Accent: \(deviceAccentIndex)

        Now Playing bridge: \(bridgeLine)
        """
    }
}
