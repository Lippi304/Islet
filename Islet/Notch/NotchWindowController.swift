import AppKit
import SwiftUI

// ISL-03 / ISL-06 — owns the overlay panel, keeps it on the correct display, and drives
// the FOCUS-SAFE Alcove interaction (Plan 02-03).
//
// Display math/selection stays in the PURE Phase-1 seams (selectTargetScreen + notchFrame)
// and the pure Plan 02-01 seams (nextState + expandedNotchFrame). This file is the small
// AppKit GLUE that turns OS pointer events into those pure events:
//   • a GLOBAL NSEvent .mouseMoved monitor hit-tests the pointer against the pill hot-zone
//     (no coordinate conversion — NSEvent.mouseLocation and panel.frame are BOTH global,
//     bottom-left, unflipped — Pitfall 6),
//   • hover-ENTER fires a trackpad haptic + a `.pointerEntered` bounce WITHOUT expanding
//     (D-01) and makes the panel hit-testable so a click can land,
//   • a CLICK feeds `.clicked` → `.expanded` with the spring morph (D-02),
//   • hover-EXIT schedules a grace-delay collapse that a quick re-entry cancels (D-03),
//   • `ignoresMouseEvents` is flipped false ONLY while the pointer is in the hot-zone and
//     restored to true deterministically whenever the island is collapsed and the pointer
//     is out (Pitfall 3), so clicks OUTSIDE the pill always pass through.
//
// FOCUS-SAFE (D-04, carries Phase-1 D-07 / threat T-02-06): the panel stays
// `.nonactivatingPanel` + `canBecomeKey/Main == false` (set once in NotchPanel.init) and is
// shown ONLY via `orderFrontRegardless()`. This file uses NO focus-stealing show/activate
// call (no key-and-order-front, no app activation, no make-key), so clicking the island
// never activates Islet or steals focus from the foreground app.
//
// @MainActor because it touches AppKit windows + the global monitor handler runs on main.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var observer: NSObjectProtocol?

    // ISL-03/04 — the SwiftUI-facing interaction state. This controller DRIVES it: the
    // monitor/timer/click callbacks mutate `phase` inside withAnimation(.spring(...)).
    private let interaction = NotchInteractionState()

    // The global pointer monitor + the pending grace-delay collapse (Pattern 1 / Pattern 3).
    private var mouseMonitor: Any?
    private var graceWorkItem: DispatchWorkItem?

    // The pill hot-zone in GLOBAL screen coords. It is the COLLAPSED pill frame padded a
    // few px so the tiny notch band is easy to target. Recomputed on every resolve so it
    // tracks display/resolution/clamshell changes. nil until the first successful resolve.
    private var hotZone: CGRect?

    // The expanded island size seed. Read from the view so the window frame and the SwiftUI
    // content can never drift to different expanded sizes (Plan 05 tunes it in one place).
    private let expandedSize = NotchPillView.expandedSize

    // A few px of slop around the collapsed pill so the hot-zone is comfortable to enter.
    private let hotZonePadding: CGFloat = 6

    // D-03 grace delay (within the 0.3–0.5s window). One place for Plan 05 to tune.
    private let graceDelay: TimeInterval = 0.4

    // The spring applied at every phase mutation (ISL-04 / D-07). Snappy with a slight
    // bounce. The two seeds live here so Plan 05 tunes the feel in ONE place; each mutation
    // site spells out `withAnimation(.spring(response:dampingFraction:))` so the animation
    // is provably attached AT the state change (the view itself drives no animation, D-08).
    private let springResponse: Double = 0.35
    private let springDamping: Double = 0.65

    #if DEBUG
    // A1 probe seam (Pitfall 1): the monitor returns a non-nil token even when the OS gated
    // it behind Accessibility and never actually fires. Logging ONCE on the first hover lets
    // Plan 05 confirm on-device whether the global .mouseMoved monitor fires unprompted on
    // Tahoe. If it does NOT, the ready fallback is an NSTrackingArea on the hosting view
    // (RESEARCH Pattern 1b, permission-free). DEBUG-only: the pointer location is NEVER
    // logged in release (privacy / threat T-02-07 — .mouseMoved mask only, no keyboard).
    private var didLogFirstHover = false
    #endif

    func start() {
        resolveAndPosition()

        // ISL-06 / D-05: re-evaluate on EVERY screen-config change (plug/unplug, resolution,
        // lid open/close). One notification covers all four.
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Pitfall 6: this can fire several times / mid-transition. Hop to the next
            // main-loop turn so NSScreen.screens has fully settled; the routine is
            // idempotent so extra calls are harmless.
            DispatchQueue.main.async { self?.resolveAndPosition() }
        }

        // Pattern 1 (focus-safe core): a GLOBAL monitor observes COPIES of .mouseMoved
        // events posted to OTHER apps — it never consumes them, never activates Islet, and
        // its handler runs on the MAIN thread (safe to touch AppKit / @Published directly).
        // We watch ONLY .mouseMoved (no keyboard mask) to minimise the privacy surface.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handlePointer(at: NSEvent.mouseLocation)
        }
    }

    private func resolveAndPosition() {
        // Build descriptors from live screens, then pick via the pure resolver.
        let descriptors = NSScreen.screens.map { $0.descriptor }
        guard
            let target = selectTargetScreen(from: descriptors),
            let collapsedFrame = notchFrame(screenFrame: target.frame,
                                            safeAreaTop: target.safeAreaTop,
                                            auxLeftWidth: target.auxLeftWidth,
                                            auxRightWidth: target.auxRightWidth,
                                            widthFudge: 4)
        else {
            // No built-in notched screen → clamshell / external-only / non-notch.
            // D-04: HIDE entirely; NEVER relocate to an external display.
            panel?.orderOut(nil)
            hotZone = nil
            return
        }

        // Pattern 4 / Pitfall 4: size the PANEL to the EXPANDED frame UP FRONT (the extra
        // area is transparent → invisible) so the SwiftUI spring morph never clips or jumps
        // mid-animation. The collapsed pill sits flush at the top of this larger window.
        let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: expandedSize)

        // The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
        hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)

        let panel = self.panel ?? NotchPanel(contentRect: expandedFrame)
        if self.panel == nil {
            panel.contentView = NSHostingView(
                rootView: NotchPillView(interaction: interaction,
                                        onClick: { [weak self] in self?.handleClick() })
            )
            self.panel = panel
        }
        panel.setFrame(expandedFrame, display: true) // reposition for resolution / display changes
        panel.orderFrontRegardless()                 // show WITHOUT activating the app — focus-safe (D-07)
    }

    // Pattern 1: every .mouseMoved tick hit-tests the GLOBAL pointer against the hot-zone.
    // No coordinate conversion — both `point` and `hotZone` are global bottom-left (Pitfall 6).
    private func handlePointer(at point: CGPoint) {
        guard let zone = hotZone else { return }
        let inside = zone.contains(point)
        // `isHovering` is true while .hovering OR .expanded; the enter/exit transitions are
        // about the POINTER being in the zone, so track that explicitly against the phase.
        let wasInside = interaction.isHovering
        if inside && !wasInside {
            handleHoverEnter()
        } else if !inside && wasInside {
            handleHoverExit()
        }
    }

    // D-01 hover-ENTER: haptic + a `.pointerEntered` bounce, NO expand. Make the panel
    // hit-testable so the follow-up click can land, and cancel any pending collapse.
    private func handleHoverEnter() {
        #if DEBUG
        if !didLogFirstHover {
            didLogFirstHover = true
            print("hover tick — global mouse monitor fired (A1 probe)") // never logs the location
        }
        #endif

        // D-01: trackpad "you're in" haptic. defaultPerformer respects device/user prefs and
        // no-ops on non-Force-Touch trackpads.
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        // Make the pill interactive so the SwiftUI content can receive the expand click.
        panel?.ignoresMouseEvents = false

        // A quick re-entry cancels a pending grace-delay collapse (Pattern 3).
        graceWorkItem?.cancel()
        graceWorkItem = nil

        // D-01: hover gives an affordance but NEVER expands — nextState turns .collapsed
        // into .hovering only. The spring drives the bounce/scale in NotchPillView.
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .pointerEntered)
        }
    }

    // D-03 hover-EXIT: feed `.pointerExited` (the pure machine DEFERS — it stays hovering/
    // expanded) and schedule the grace-delay collapse. A re-entry before it fires cancels it.
    private func handleHoverExit() {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .pointerExited)
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Only collapse if the pointer is STILL outside (re-entry would have cancelled).
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
            }
            // Pitfall 3: restore click-through deterministically once collapsed + pointer out.
            if !self.interaction.isHovering && !self.interaction.isExpanded {
                self.panel?.ignoresMouseEvents = true
            }
        }
        graceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
    }

    // D-02 CLICK-to-expand: the ONLY path to `.expanded`. Wired from NotchPillView's
    // onTapGesture; runs the pure `.clicked` transition inside the spring. The panel is
    // already non-activating + never key, so this never steals focus (D-04).
    private func handleClick() {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .clicked)
        }
    }

    deinit {
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        graceWorkItem?.cancel()
    }
}
