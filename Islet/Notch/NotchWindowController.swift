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
// shown ONLY via the single focus-safe order-front-regardless call. This file uses NO
// focus-stealing show/activate call (no key-and-order-front, no app activation, no make-key),
// so clicking the island never activates Islet or steals focus from the foreground app.
//
// @MainActor because it touches AppKit windows + the global monitor handler runs on main.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var observer: NSObjectProtocol?

    // Pattern 6 (ISL-05) — fullscreen lives on its OWN Space, so entering/exiting true
    // fullscreen fires activeSpaceDidChange; didActivateApplication catches the fullscreen
    // kinds (fullscreen video / QuickLook) that may not take a dedicated Space (A6). Both
    // re-run the ONE visibility decision. Stored as tokens so deinit can remove them from
    // NSWorkspace.shared.notificationCenter (NOT the default center — that would no-op).
    private var spaceObserver: NSObjectProtocol?
    private var appActivateObserver: NSObjectProtocol?

    // D-10 (ISL-05) — the SINGLE fullscreen-hide gating flag. Default true ships the hide.
    // Phase 6 (APP-03) will flip `let`→`var` and wire a preferences toggle to THIS property —
    // it is the only seam, so build NO preferences UI / stored-defaults read here.
    private let hideInFullscreen = true

    // ISL-03/04 — the SwiftUI-facing interaction state. This controller DRIVES it: the
    // monitor/timer/click callbacks mutate `phase` inside withAnimation(.spring(...)).
    private let interaction = NotchInteractionState()

    // The global pointer monitor + the pending grace-delay collapse (Pattern 1 / Pattern 3).
    private var mouseMonitor: Any?
    private var graceWorkItem: DispatchWorkItem?

    // WR-01: the pointer-in-hot-zone edge, tracked from RAW geometry — NOT derived from
    // `interaction.isHovering` (which is true for BOTH .hovering AND .expanded, so a
    // re-entry while expanded would never read as an enter edge and never cancel the
    // pending grace collapse, letting the island collapse out from under the pointer).
    // Reset in updateVisibility's hide branch so it can't go stale across a hide/show cycle.
    private var pointerInZone = false

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
        updateVisibility()

        // ISL-06 / D-05: re-evaluate on EVERY screen-config change (plug/unplug, resolution,
        // lid open/close). One notification covers all four.
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Pitfall 6: this can fire several times / mid-transition. Hop to the next
            // main-loop turn so NSScreen.screens has fully settled; the routine is
            // idempotent so extra calls are harmless.
            DispatchQueue.main.async { self?.updateVisibility() }
        }

        // Pattern 6 (ISL-05): fullscreen enter/exit and Space switches feed the SAME single
        // visibility decision. activeSpaceDidChange fires when an app takes/leaves its
        // fullscreen Space; didActivateApplication catches fullscreen-video / QuickLook kinds
        // that may not migrate Spaces (A6). NSWorkspace notifications already arrive on the
        // main queue settled, so no next-run-loop hop is needed here (updateVisibility is
        // idempotent regardless). Removed from the workspace center in deinit.
        let wc = NSWorkspace.shared.notificationCenter
        spaceObserver = wc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateVisibility() }
        appActivateObserver = wc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateVisibility() }

        // Pattern 1 (focus-safe core): a GLOBAL monitor observes COPIES of .mouseMoved
        // events posted to OTHER apps — it never consumes them, never activates Islet, and
        // its handler runs on the MAIN thread (safe to touch AppKit / @Published directly).
        // We watch ONLY .mouseMoved (no keyboard mask) to minimise the privacy surface.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handlePointer(at: NSEvent.mouseLocation)
        }
    }

    // The built-in display's CURRENT descriptor, or nil when the built-in has dropped out
    // (clamshell). nil is NOT fullscreen — isTrueFullscreen maps nil→false and the no-target
    // branch of shouldShow owns the clamshell hide. Rebuilt on EVERY visibility re-eval so a
    // fullscreen-induced safe-area collapse on the built-in is observed live (Pattern 6).
    private func currentBuiltin() -> ScreenDescriptor? {
        NSScreen.screens.map { $0.descriptor }.first { $0.isBuiltin }
    }

    // Pattern 7 (ISL-05) — the ONE visibility decision and the SOLE show/hide site. The
    // Phase-1 clamshell/display-target signal (selectTargetScreen) AND the Phase-2 fullscreen
    // signal (isTrueFullscreen) converge through the single shouldShow AND; there is no second
    // hide/show call anywhere in the file (Pitfall 5 — a double show/hide site would race
    // the clamshell and fullscreen observers into flicker / stuck state). Idempotent: every
    // observer (didChangeScreenParameters, activeSpaceDidChange, didActivateApplication) calls
    // ONLY this; safe to call repeatedly.
    private func updateVisibility() {
        // Build descriptors from live screens, then pick via the pure resolver.
        let descriptors = NSScreen.screens.map { $0.descriptor }
        let target = selectTargetScreen(from: descriptors)               // Phase-1: built-in present + notched
        // Phase-2 (Q3 fix): the RUNTIME fullscreen signal now comes from CGS managed
        // display spaces — it reports the built-in's CURRENT space type, so it observes
        // ANOTHER app's fullscreen (which a background agent's safe area never reflects).
        // The old safe-area predicate isTrueFullscreen(builtin:) is superseded as the live
        // signal (kept only as a pure heuristic / its tests); see FullscreenSpaceProbe.swift.
        let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

        if shouldShow(hasTarget: target != nil,
                      hideInFullscreen: hideInFullscreen,
                      isFullscreen: fullscreen),
           let target {
            positionAndShow(on: target)
        } else {
            // The ONLY hide call in the file (single path). Covers BOTH clamshell/external-only
            // (no target → D-04 never relocate) AND true fullscreen (D-09 hide, no ghost bar).
            panel?.orderOut(nil)
            hotZone = nil
            // WR-01: the hot-zone is gone, so the pointer is by definition no longer in it.
            // Clearing this here prevents a stale `true` from suppressing the next enter edge
            // after a show, which would skip the haptic + grace-cancel on re-entry.
            pointerInZone = false
        }
    }

    // The frame + show body, extracted from the old resolveAndPosition. Makes NO hide
    // decision (that is updateVisibility's job alone); it only computes the frame and shows.
    private func positionAndShow(on target: ScreenDescriptor) {
        guard let collapsedFrame = notchFrame(screenFrame: target.frame,
                                              safeAreaTop: target.safeAreaTop,
                                              auxLeftWidth: target.auxLeftWidth,
                                              auxRightWidth: target.auxRightWidth,
                                              widthFudge: 4)
        else { return }

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
        // WR-01: the enter/exit edge is about the POINTER being in the zone, so track it
        // against an explicit `pointerInZone` flag — NOT against `interaction.isHovering`,
        // which is true for BOTH .hovering AND .expanded. Deriving the edge from the phase
        // hid re-entries while .expanded (the cancel-on-re-entry guarantee then only held
        // while .hovering), letting the grace timer collapse the island under the pointer.
        if inside && !pointerInZone {
            pointerInZone = true
            handleHoverEnter()          // cancels the pending grace collapse inside
        } else if !inside && pointerInZone {
            pointerInZone = false
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

        // A quick re-entry cancels a pending grace-delay collapse (Pattern 3).
        graceWorkItem?.cancel()
        graceWorkItem = nil

        // D-01: hover gives an affordance but NEVER expands — nextState turns .collapsed
        // into .hovering only. The spring drives the bounce/scale in NotchPillView.
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .pointerEntered)
        }

        // Pitfall 3: make the pill hit-testable so the follow-up click can land. Centralised
        // so the click-through state always reflects pointerInZone + phase (WR-02).
        syncClickThrough()
    }

    // WR-02 (Pitfall 3 / D-07): the SINGLE place that decides `ignoresMouseEvents`. The
    // window must swallow clicks (be interactive) while the pointer is in the hot-zone OR
    // the island is expanded, and pass them through otherwise. Centralising this means no
    // transition can leave the flag stale — previously only the grace work item restored
    // `true`, so a toggle-shut click followed by a pointer-exit (which schedules no grace
    // timer) left the collapsed/idle window swallowing clicks over the notch band until the
    // next hover cycle. Called after EVERY phase/pointer mutation (enter, grace-elapsed,
    // click). The panel stays `.nonactivatingPanel` + never-key (D-04); `ignoresMouseEvents`
    // is the ONLY flag toggled at runtime.
    private func syncClickThrough() {
        let interactive = pointerInZone || interaction.isExpanded
        panel?.ignoresMouseEvents = !interactive
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
            self.syncClickThrough()
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
        // WR-02: a toggle-shut click (.expanded → .collapsed) schedules NO grace timer, so
        // without this the window would keep swallowing clicks until the next hover cycle.
        // Re-deriving from pointerInZone + phase keeps click-through correct on every click
        // (expand → interactive, toggle-shut while still in zone → still interactive until
        // exit, toggle-shut already out → pass-through).
        syncClickThrough()
    }

    deinit {
        // The screen-parameters observer lives on the DEFAULT center; the two fullscreen
        // observers live on NSWorkspace's OWN center — removing a workspace observer from the
        // default center is a silent no-op leak, so each is removed from its respective center.
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        let wc = NSWorkspace.shared.notificationCenter
        if let o = spaceObserver { wc.removeObserver(o) }
        if let o = appActivateObserver { wc.removeObserver(o) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        graceWorkItem?.cancel()
    }
}
