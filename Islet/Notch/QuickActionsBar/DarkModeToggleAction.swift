import AppKit

// Phase 65 Plan 03 / QACTION-01 — Dark/Light Mode toggle, this codebase's ONE existing
// AppleScript+errorDict call site (NowPlayingMonitor.swift's spikeTriggerAutomationPrompt())
// is the proven pattern: never assume success from the mere absence of a thrown Swift error —
// TCC denial (-1743, errAEEventNotPermitted) surfaces only via `errorDict`, never a Swift throw.
enum DarkModeToggleAction {
    static func toggle(completion: @escaping (Bool) -> Void) {
        let script = NSAppleScript(source:
            "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)
        completion(errorDict == nil)
    }

    // Pure AppKit read (RESEARCH.md Assumptions Log A1) — used by Plan 65-05's icon-swap.
    static var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
