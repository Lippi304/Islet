import Foundation

// Phase 64 (D-05) — pure string builders producing the exact day-heading /
// bullet-with-time / 2-space-indented-continuation shape locked in
// 64-CONTEXT.md. No FileHandle/AppKit — plain String splitting/joining is
// sufficient for this fixed, simple shape.
enum QuickNotesFormatter {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func isoDate(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func formatEntry(text: String, at date: Date) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let time = timeFormatter.string(from: date)
        guard let first = lines.first else {
            return "- \(time) \n"
        }
        var result = "- \(time) \(first)"
        for line in lines.dropFirst() {
            result += "\n  \(line)"
        }
        result += "\n"
        return result
    }
}
