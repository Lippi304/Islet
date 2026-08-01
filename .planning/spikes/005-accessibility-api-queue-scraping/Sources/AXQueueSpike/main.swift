import ApplicationServices
import AppKit
import Foundation

// Spike 005: can the visible "Playing Next" (Music.app) or "Queue" (Spotify)
// panel be read via the Accessibility API? Unlike AppleScript's sdef, there is
// no static dictionary for AX trees — this is a live-only test from the start.

func isTrusted() -> Bool {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(opts)
}

func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
    var value: AnyObject?
    let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
    guard err == .success else { return nil }
    return value as? String
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    var value: AnyObject?
    let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    guard err == .success, let arr = value as? [AXUIElement] else { return [] }
    return arr
}

var textNodeCount = 0

func dump(_ element: AXUIElement, depth: Int, maxDepth: Int) {
    guard depth <= maxDepth else { return }
    let role = stringAttr(element, kAXRoleAttribute as String) ?? "?"
    let title = stringAttr(element, kAXTitleAttribute as String)
    let value = stringAttr(element, kAXValueAttribute as String)
    let desc = stringAttr(element, kAXDescriptionAttribute as String)

    let text = [title, value, desc].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
    if !text.isEmpty {
        textNodeCount += 1
        print(String(repeating: "  ", count: depth) + "[\(role)] \(text)")
    } else if depth < 4 {
        print(String(repeating: "  ", count: depth) + "[\(role)]")
    }

    for child in children(element) {
        dump(child, depth: depth + 1, maxDepth: maxDepth)
    }
}

guard isTrusted() else {
    print("""
    Accessibility permission not granted.
    A system prompt should appear (or check System Settings > Privacy & Security >
    Accessibility) — grant access to this terminal / binary, then re-run.
    """)
    exit(1)
}

let args = CommandLine.arguments
let bundleID = args.count > 1 ? args[1] : "com.apple.Music"
let maxDepth = args.count > 2 ? (Int(args[2]) ?? 14) : 14

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
    print("No running app with bundle id \(bundleID). Launch it first (and open its queue/Up Next panel).")
    exit(1)
}

print("Dumping accessibility tree for \(app.localizedName ?? bundleID) (pid \(app.processIdentifier)), maxDepth=\(maxDepth)\n")
let axApp = AXUIElementCreateApplication(app.processIdentifier)

// Chromium/Electron apps lazily build their AX tree; this documented attribute
// forces full construction (used by tools like Hammerspoon for Chrome/Electron).
let manualAccessibilityResult = AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
if manualAccessibilityResult == .success {
    print("Set AXManualAccessibility=true (Chromium full-tree hint) — succeeded.")
} else {
    print("AXManualAccessibility not settable on this app (error \(manualAccessibilityResult.rawValue)) — likely not Chromium-based, or attribute unsupported.")
}

var windowsValue: AnyObject?
AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
let windows = (windowsValue as? [AXUIElement]) ?? []
print("Found \(windows.count) window(s).")

for (i, window) in windows.enumerated() {
    let title = stringAttr(window, kAXTitleAttribute as String) ?? "(untitled)"
    print("\n=== Window \(i): \(title) ===")
    dump(window, depth: 0, maxDepth: maxDepth)
}

print("\n--- \(textNodeCount) text-bearing elements found across \(windows.count) window(s). ---")
