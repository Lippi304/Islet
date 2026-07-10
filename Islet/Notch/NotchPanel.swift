import AppKit

// ISL-02 / D-07 — the borderless, non-activating overlay window.
//
// This is the ONLY AppKit window in the app (everything visible is SwiftUI hosted
// inside it). It is configured ONCE in `init`; in particular `.nonactivatingPanel`
// is set in the styleMask at init and never toggled later (AppKit does not fully
// re-apply activation behavior post-init — see RESEARCH Anti-patterns).
final class NotchPanel: NSPanel, NSDraggingDestination {
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
        level = .statusBar                // above normal windows; see A2 — Plan 03 tunes vs the Tahoe menu bar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] // ISL-02: all Spaces, above fullscreen-aux
        registerForDraggedTypes([.fileURL]) // Phase 22 spike (A1) — see 22-RESEARCH.md Recommended Spike; registration is permanent, the overrides below are throwaway
    }
    // A non-activating overlay must NEVER take focus (D-07):
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // SPIKE — throwaway, 22-03 Task 1 replaces this block with the real closure-forwarding architecture. Do not build production logic on top of this.
    // NOTE: NSDraggingDestination is an @objc optional protocol delivered via an NSObject
    // category, NOT superclass members -- Swift requires explicit ": NSDraggingDestination"
    // conformance (added on the class line above) for these to compile; they satisfy protocol
    // requirements, not `override` a superclass implementation (plan's "no conformance needed"
    // premise was incorrect for Swift -- see 22-01-SUMMARY.md deviations).
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSLog("SPIKE draggingEntered fired")
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        NSLog("SPIKE draggingExited fired")
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NSLog("SPIKE performDragOperation fired, urls: \(sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) ?? [])")
        return true
    }
}
