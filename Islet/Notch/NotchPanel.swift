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
        // Phase 2: ignoresMouseEvents is now CONDITIONAL (RESEARCH Pattern 1). It STARTS
        // true (idle = fully click-through, D-07), and NotchWindowController flips it to
        // false ONLY while the pointer is inside the pill hot-zone so the SwiftUI content
        // can receive the expand click WITHOUT activating Islet (.nonactivatingPanel +
        // canBecomeKey==false makes that focus-safe). It is restored to true whenever the
        // island is collapsed and the pointer is out (Pitfall 3). The style mask is NEVER
        // toggled at runtime — only this single flag is.
        ignoresMouseEvents = true
        // Gap-closure (30-04): every hover interaction up to this point (notch expand-on-hover)
        // was driven by a manual global NSEvent monitor, never native window events — so this
        // was never needed before. D-05's TransportButton.onHover is the first native SwiftUI
        // `.onHover` in the app; without acceptsMouseMovedEvents the window never receives
        // mouseMoved, so `.onHover` can never fire even while the window is click-through-off.
        acceptsMouseMovedEvents = true
        level = .statusBar                // above normal windows; see A2 — Plan 03 tunes vs the Tahoe menu bar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] // ISL-02: all Spaces, above fullscreen-aux
    }
    // A non-activating overlay must NEVER take focus (D-07):
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
