import AppKit
import SwiftUI

// ISL-06 — owns the overlay panel and keeps it on the correct display.
//
// It uses the PURE seam from Plan 01 (selectTargetScreen + notchFrame) for all the
// math/selection, so this file is just AppKit glue: build descriptors from the live
// screens, pick + position, and re-run on every screen-configuration change. The
// routine is idempotent, so firing it extra times is harmless.
//
// @MainActor because it touches AppKit windows, which are main-thread-only.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var observer: NSObjectProtocol?

    func start() {
        resolveAndPosition()
        // ISL-06 / D-05: re-evaluate on EVERY screen-config change (plug/unplug,
        // resolution, lid open/close). One notification covers all four.
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Pitfall 6: this can fire several times / mid-transition. Hop to the
            // next main-loop turn so NSScreen.screens has fully settled; the
            // routine is idempotent so extra calls are harmless.
            DispatchQueue.main.async { self?.resolveAndPosition() }
        }
    }

    private func resolveAndPosition() {
        // Build descriptors from live screens, then pick via the pure resolver.
        let descriptors = NSScreen.screens.map { $0.descriptor }
        guard
            let target = selectTargetScreen(from: descriptors),
            let frame = notchFrame(screenFrame: target.frame,
                                   safeAreaTop: target.safeAreaTop,
                                   auxLeftWidth: target.auxLeftWidth,
                                   auxRightWidth: target.auxRightWidth,
                                   widthFudge: 4)
        else {
            // No built-in notched screen → clamshell / external-only / non-notch.
            // D-04: HIDE entirely; NEVER relocate to an external display.
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? NotchPanel(contentRect: frame)
        if self.panel == nil {
            panel.contentView = NSHostingView(rootView: NotchPillView())
            self.panel = panel
        }
        panel.setFrame(frame, display: true)   // reposition for resolution / display changes
        panel.orderFrontRegardless()           // show WITHOUT activating the app — the focus-safe show call (D-07)
    }

    deinit {
        if let o = observer { NotificationCenter.default.removeObserver(o) }
    }
}
