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

    // CHG-01 / Pattern 2 — the SEPARATE charging-splash model the wings layout observes
    // (NOT a NotchInteractionState phase, so the Phase-2 gesture machine stays untouched).
    // Plan 03 drives it: the IOKit power-source events below set `.activity` inside
    // withAnimation(.spring) and the ~3s dismissWorkItem clears it.
    private let chargingState = ChargingActivityState()

    // Phase 4 / NOW-01/02 — the SEPARATE @Published media model the media wings + expanded
    // controls observe (Plan 02). Created here so the view has a live instance to bind to;
    // Plan 04 wires the NowPlayingMonitor to drive its presentation/artwork/isHealthy
    // (start() + runHealthCheck + onSnapshot/onTerminated) and applies the spring on mutation.
    // Until then it stays .none/healthy → the view shows the existing collapsed/date-time states.
    let nowPlayingState = NowPlayingState()

    // CHG-01 / CHG-02 (Plan 03) — the LIVE IOKit power-source monitor. Event-driven
    // (IOPSNotificationCreateRunLoopSource), no polling clock. Each plug/unplug hops to
    // main and lands in handlePower. Constructed + started in start() (so the [weak self]
    // closure binds a fully-initialised self) and held as a plain stored property so the
    // nonisolated deinit can call powerMonitor?.stop() (mirroring graceWorkItem teardown).
    private var powerMonitor: PowerSourceMonitor?

    // Phase 4 / NOW-01/02/03 (Plan 04) — the LIVE MediaRemote bridge that drives
    // nowPlayingState. Constructed + started in start() (so the [weak self] callbacks bind a
    // fully-initialised self) and held as a plain stored property so the nonisolated deinit can
    // call nowPlayingMonitor?.stop() — terminating the persistent perl child (no orphaned
    // process, T-04-12), mirroring powerMonitor's lifecycle exactly.
    private var nowPlayingMonitor: NowPlayingMonitor?

    // D-06 (15s paused linger) / D-07 (stop cue) — the one-shot media auto-dismiss. A single
    // DispatchWorkItem mirroring dismissWorkItem (NOT a recurring timer): one wake-up then idle,
    // so CPU stays ~0% while a paused/stopped glance lingers. Resuming playback cancels it.
    private var mediaDismissWorkItem: DispatchWorkItem?
    private let pausedTimeout: TimeInterval = 15.0   // D-06 single tuning seed

    // D-09 / Pattern 5 — the ~3s one-shot auto-dismiss. A single DispatchWorkItem mirroring
    // graceWorkItem (NOT a recurring timer): one wake-up then idle, so CPU stays ~0% while a
    // splash stands. Hover cancels it; pointer-leave reschedules it.
    private var dismissWorkItem: DispatchWorkItem?
    private let activityDuration: TimeInterval = 3.0   // D-09 single tuning seed

    // Pitfall 4 — the last classified activity, for the category-transition debounce
    // (shouldTriggerSplash). A pure % tick within the same category updates a standing
    // splash WITHOUT re-firing / restarting the dismiss timer.
    private var lastActivity: ChargingActivity?

    // The launch reading seeds lastActivity WITHOUT firing a splash (the user did not just
    // plug in). The first handlePower call sets this flag + lastActivity and returns; only
    // subsequent calls run the transition logic — "no splash unless a change".
    private var didSeedInitialPower = false

    // CHG-01 / Pattern 4 — the flat, wide wings seed (single-sourced from the view, matching
    // the Plan-01 wingsFrame test seed). The panel is sized to the UNION of the expanded
    // (downward) and wings (sideways) frames so neither is ever resized mid-animation.
    private let wingsSize = NotchPillView.wingsSize

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

        // CHG-01 / CHG-02 (Plan 03): register the LIVE IOKit power-source notification. It
        // emits the initial reading once (seeded WITHOUT a splash via didSeedInitialPower)
        // and then fires on every plug/unplug → handlePower on main. Event-driven, no poll.
        let monitor = PowerSourceMonitor { [weak self] reading in self?.handlePower(reading) }
        powerMonitor = monitor
        monitor.start()

        // Phase 4 / NOW-01/02/03 (Plan 04): construct + start the LIVE MediaRemote bridge,
        // mirroring the powerMonitor construction. start() opens ONE persistent `loop` child
        // that emits the current session immediately (NOW-03 restart survival: a relaunch
        // re-reads whatever is playing right now). Every track update hops to main inside the
        // wrapper and lands in handleNowPlaying; a mid-session child death lands in
        // handleAdapterTerminated (D-13). runHealthCheck is the D-12 launch probe that flips
        // isHealthy=false if the private-MediaRemote bridge is blocked on THIS macOS.
        let np = NowPlayingMonitor(
            onSnapshot: { [weak self] snap, art in self?.handleNowPlaying(snap, art) },
            onTerminated: { [weak self] in self?.handleAdapterTerminated() })   // D-13
        nowPlayingMonitor = np
        np.start()
        np.runHealthCheck { [weak self] healthy in self?.nowPlayingState.isHealthy = healthy }   // D-12
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

        // CHG-01 / Pattern 4: the wings extend SIDEWAYS, so the panel must also cover the
        // flat wings strip. Size the panel ONCE to the UNION of the downward-expanded and the
        // sideways-wings frames so BOTH the Phase-2 expand AND the Phase-3 wings fit without
        // any runtime panel resize (resizing mid-activity would race the morph + hot-zone math).
        let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
        let panelFrame = expandedFrame.union(wings)

        // The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
        hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)

        let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
        if self.panel == nil {
            panel.contentView = NSHostingView(
                rootView: NotchPillView(interaction: interaction, charging: chargingState,
                                        nowPlaying: nowPlayingState,
                                        onClick: { [weak self] in self?.handleClick() },
                                        // NOW-02: transport rides the EXISTING persistent child's
                                        // stdin via the monitor — no re-spawn, no focus steal.
                                        onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
                                        onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
                                        onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() })
            )
            self.panel = panel
        }
        panel.setFrame(panelFrame, display: true) // reposition for resolution / display changes
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

        // D-10: hover PAUSES the charging-splash auto-dismiss. While the pointer sits on the
        // wings the ~3s is cancelled; handleHoverExit reschedules it once the pointer leaves.
        dismissWorkItem?.cancel()

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

        // D-10: once the pointer leaves a STANDING charging splash, resume the ~3s
        // auto-dismiss (handleHoverEnter cancelled it on entry). No-op when no splash stands.
        // Click stays informational (D-10): the existing handleClick → expand is untouched and
        // .clicked is never routed into the activity model.
        if chargingState.activity != nil {
            scheduleActivityDismiss()
        }
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

    // CHG-01 / CHG-02 — the live power event lands here (already on main; the monitor's
    // callback hopped). Maps the raw reading to a presentation via the PURE Plan-01 seam,
    // gates re-display to category transitions (Pitfall 4), and routes the splash through the
    // SINGLE updateVisibility() so it inherits the fullscreen / clamshell hide for free.
    private func handlePower(_ reading: PowerReading) {
        let next = powerActivity(from: reading)   // pure (Plan 01); nil on no-battery → no splash

        // The launch reading must NOT pop a splash (the user did not just plug in). Seed
        // lastActivity from the very first callback and return before the transition logic.
        guard didSeedInitialPower else {
            didSeedInitialPower = true
            lastActivity = next
            return
        }

        let fire = shouldTriggerSplash(previous: lastActivity, next: next)   // Pitfall 4 — category change only
        lastActivity = next

        if fire, let activity = next {
            // D-07: the spring is attached AT the mutation (the view drives no animation, D-08).
            // D-11 precedence (charging briefly wins over a user-expanded island) is rendered
            // by the view's if-ordering; here we only publish the activity.
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                chargingState.activity = activity
            }
            updateVisibility()           // Pattern 6 — the SOLE show/hide site (fullscreen gate)
            scheduleActivityDismiss()    // D-09 — the ~3s one-shot collapse
        } else if next != nil, chargingState.activity != nil {
            // A pure % tick while a splash already stands: update the % WITHOUT restarting the
            // ~3s timer or re-triggering the entrance (Pitfall 4). No animation wrapper — the
            // number just refreshes inside the standing splash.
            chargingState.activity = next
        }
    }

    // D-09 / Pattern 5 — schedule the ~3s one-shot collapse. Mirrors handleHoverExit's
    // DispatchWorkItem exactly: a single wake-up that clears the activity inside the spring,
    // then idles (no recurring timer → idle CPU ~0%). Re-scheduling cancels any pending one.
    private func scheduleActivityDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.chargingState.activity = nil    // collapse the wings
            }
            self.updateVisibility()                  // re-evaluate the single show/hide site
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + activityDuration, execute: work)
    }

    // Phase 4 / NOW-01/02/03 — a live media update lands here (already on main; the wrapper
    // hopped → A2: no second hop). Mirrors handlePower: maps the raw snapshot through the PURE
    // Plan-01 seam, publishes presentation + artwork inside the spring (Pitfall 6 — the
    // animation is attached AT the mutation; the view drives no animation except the gated
    // bars), routes show/hide through the SINGLE updateVisibility() gate (so media inherits the
    // fullscreen + clamshell hide for free), and arms/cancels the D-06/D-07 one-shot dismiss.
    private func handleNowPlaying(_ snapshot: TrackSnapshot?, _ art: NSImage?) {
        let p = nowPlayingPresentation(from: snapshot)   // pure (Plan 01) — D-01 allowlist + .playing/.paused/.none

        // A healthy stream callback means the bridge is alive — a successful emission after a
        // prior drop restores the D-12 flag so the next expand shows media, not "nicht verfügbar".
        nowPlayingState.isHealthy = true

        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            nowPlayingState.presentation = p
            nowPlayingState.artwork = art   // nil → Plan 03 placeholder; async art fills on a later callback
        }
        updateVisibility()   // Pattern 7 — the SOLE show/hide site (inherits fullscreen / clamshell)

        // D-06 / D-07 timeout scheduling via the one-shot helper (no recurring timer):
        switch p {
        case .playing:
            // The glance stands while playing — cancel any pending paused/stop dismiss.
            mediaDismissWorkItem?.cancel()
        case .paused:
            // D-06: a paused glance lingers, then exits to the idle pill after ~15s. A resume
            // (.playing) before then cancels this via the .playing branch above.
            scheduleMediaDismiss(after: pausedTimeout)
        case .none:
            // D-07: stop / no media. The pure seam has no distinct "stopping" state (only
            // .playing/.paused/.none), so the prompt exit IS the just-applied spring-out above
            // (the glance collapses to the idle pill in one ~0.35s spring — distinct from, and
            // far faster than, the 15s pause linger). Nothing further to schedule; just cancel
            // any pending paused-dismiss so a leftover 15s timer can't fire over the idle pill.
            // (Chosen over a redundant 0.5s work item that would re-clear an already-cleared
            // presentation — documented in 04-04-SUMMARY.)
            mediaDismissWorkItem?.cancel()
        }
    }

    // D-06 / D-07 — schedule the one-shot media dismiss. Mirrors scheduleActivityDismiss
    // exactly: cancel any pending item, create a SINGLE DispatchWorkItem that clears the media
    // glance inside the spring then re-runs the single visibility gate, and asyncAfter it. One
    // wake-up then idle — NO recurring timer (idle CPU ~0%).
    private func scheduleMediaDismiss(after seconds: TimeInterval) {
        mediaDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.nowPlayingState.presentation = .none   // collapse the media glance
                self.nowPlayingState.artwork = nil
            }
            self.updateVisibility()   // re-evaluate the single show/hide site
        }
        mediaDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // D-13 mid-session child death (already on main). The adapter emitted at least once and
    // then died — clear the glance to idle and flip the health flag so the NEXT expand shows
    // "nicht verfügbar" (no mid-session splash, no crash, no empty render).
    private func handleAdapterTerminated() {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            nowPlayingState.presentation = .none
            nowPlayingState.artwork = nil
        }
        nowPlayingState.isHealthy = false   // D-13: "nicht verfügbar" only on the NEXT expand
        mediaDismissWorkItem?.cancel()
        updateVisibility()
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

        // CHG-01 (security T-03-06): remove the IOPS run-loop source so the context pointer
        // (which holds this controller) can't be used after free, and cancel the pending ~3s
        // dismiss. Mirrors the observer-removal + graceWorkItem?.cancel() discipline above.
        if let powerMonitor { powerMonitor.stop() }
        dismissWorkItem?.cancel()

        // Phase 4 (security T-04-12): terminate the persistent MediaRemote child so no orphaned
        // perl / MediaRemoteAdapter process leaks after the controller dies, and cancel the
        // pending D-06/D-07 dismiss. Mirrors the powerMonitor.stop() + dismissWorkItem discipline.
        nowPlayingMonitor?.stop()
        mediaDismissWorkItem?.cancel()
    }
}
