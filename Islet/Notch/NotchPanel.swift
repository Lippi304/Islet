import AppKit

// ISL-02 / D-07 — the borderless, non-activating overlay window.
//
// This is the ONLY AppKit window in the app (everything visible is SwiftUI hosted
// inside it). It is configured ONCE in `init`; in particular `.nonactivatingPanel`
// is set in the styleMask at init and never toggled later (AppKit does not fully
// re-apply activation behavior post-init — see RESEARCH Anti-patterns).
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel], // borderless + never activates the app (D-07)
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear          // transparent window; the pill draws the black
        hasShadow = false                 // no drop shadow around the notch
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false      // keep the object alive across show/hide
        ignoresMouseEvents = true         // Phase 1: fully click-through (D-07); Phase 2 makes this conditional
        level = .statusBar                // above normal windows; see A2 — Plan 03 tunes vs the Tahoe menu bar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] // ISL-02: all Spaces, above fullscreen-aux
    }
    // A non-activating overlay must NEVER take focus (D-07):
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
