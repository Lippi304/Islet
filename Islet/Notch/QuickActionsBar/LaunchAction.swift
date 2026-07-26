import AppKit

// Phase 65 Plan 03 / QACTION-01 — Launch App/URL, AppKit passthrough only. Security Domain V5:
// `resolvedURL(from:)` is the ONE validation chokepoint (mirrors SettingsView.swift's
// quickNotesVaultPickerView discipline — a stored string is only ever a validated file path or
// a well-formed URL, never string-interpolated into a shell/AppleScript command).
enum LaunchAction {
    static func launch(target: String) {
        guard let url = resolvedURL(from: target) else { return }
        NSWorkspace.shared.open(url)
    }

    static func resolvedURL(from target: String) -> URL? {
        if target.isEmpty { return nil }
        if FileManager.default.fileExists(atPath: target) {
            return URL(fileURLWithPath: target)
        }
        guard let url = URL(string: target), url.scheme != nil else { return nil }
        return url
    }
}
