import Foundation

// Phase 65 Plan 03 / QACTION-01 — Empty Trash, via Finder's own AppleScript dictionary
// exclusively. Per RESEARCH.md Anti-Patterns: never delete ~/.Trash contents directly via
// FileManager — provenance-tracked TCC protection can cause silent partial failures on some
// macOS versions. Same errorDict-gated completion contract as DarkModeToggleAction.
enum EmptyTrashAction {
    static func empty(completion: @escaping (Bool) -> Void) {
        let script = NSAppleScript(source:
            "tell application \"Finder\" to empty the trash without warns before emptying")
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)
        completion(errorDict == nil)
    }
}
