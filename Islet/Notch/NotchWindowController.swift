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
    //
    // Phase 6 note: charging is no longer the RENDER driver — the resolver's TransientQueue is.
    // chargingState is kept as the model the standing-% tick mutates (and so the view's
    // @ObservedObject still re-renders an in-place % update inside the same wings case).
    private let chargingState = ChargingActivityState()

    // Phase 6 / DEV-01/DEV-02 (Plan 04) — the SEPARATE device-splash model (clone of
    // chargingState). The BluetoothMonitor lifts a DeviceReading, the pure deviceActivity(from:)
    // maps it, and handleDevice publishes it here for the view to bind to; the RENDER decision
    // still comes from the resolver's queue head.
    private let deviceState = DeviceActivityState()

    // Phase 6 / COORD-01 / D-05 — the @Published carrier of the resolver's verdict. The view
    // observes this; the controller writes it (inside the spring) on every state change via
    // renderPresentation(). This is the ONE place the rendered presentation is set.
    private let presentationState = IslandPresentationState()

    // Phase 6 / COORD-01 / D-03 — the bounded, de-duped SEQUENTIAL transient queue (pure value
    // from IslandResolver.swift). Its `head` feeds `resolve(activeTransient:)`; charging + device
    // splashes enqueue here and play one-after-another off the SINGLE one-shot dismiss below.
    private var transientQueue = TransientQueue()

    // Phase 6 / DEV-01 — the LIVE IOBluetooth connect/disconnect monitor (clone of powerMonitor).
    // Constructed + started in start() ONLY when the device toggle is on (D-09 prefer stop);
    // held as a plain optional so toggle-off / deinit can stop() + release it.
    private var bluetoothMonitor: BluetoothMonitor?

    // Phase 6 / 05 D-04 — the device-splash debounce/burst-suppression state threaded into the
    // PURE shouldShowDeviceSplash(...) predicate (no clock inside it; the controller passes `now`
    // + these dictionaries). deviceLastShown debounces reconnect flaps; deviceSuppressedAtLaunch
    // would hold the at-launch/wake connect burst (left empty for v1 — the on-device A2 verdict
    // that would seed it is a deferred carry-over; the debounce alone already bounds the queue).
    private var deviceLastShown: [String: TimeInterval] = [:]
    private var deviceSuppressedAtLaunch: Set<String> = []
    private let deviceDebounce: TimeInterval = 3.0   // mirror activityDuration (discretion seed)

    // Phase 6 fix (post-checkpoint) — the set of addresses we currently believe are CONNECTED.
    // IOBluetooth re-delivers connection events for an already-connected device (the
    // CoreBluetooth connectionEventDidOccur bridge fires repeatedly), which made a stable
    // headphone splash perpetually instead of once. We splash ONLY on a genuine connect/disconnect
    // EDGE: a connect for an address already in this set is ignored; a disconnect only splashes if
    // the address was tracked as connected. Mirrors a debounced "is this a new state" gate.
    private var connectedDeviceAddresses: Set<String> = []

    // The instant the BluetoothMonitor started. Devices already connected at launch fire a connect
    // BURST the moment we register; within this grace window those are RECORDED as connected but NOT
    // splashed (the user did not just connect them — 05 D-04 at-launch suppression). A genuine
    // connect after the window splashes normally. Reset whenever the monitor (re)starts.
    private var bluetoothStartedAt: Date?
    private let deviceLaunchGrace: TimeInterval = 4.0

    // The one-shot post-connect battery re-read (the HFP battery can arrive after the connect
    // edge). A single DispatchWorkItem — cancelled/replaced per connect, torn down in deinit.
    private var deviceBatteryWork: DispatchWorkItem?

    // Phase 6 / APP-03 — the last accent index applied to the hosting view. UserDefaults posts
    // didChangeNotification for EVERY defaults write (incl. unrelated keys / Launch-at-Login), so
    // the controller only re-hosts the view (to re-inject the Environment accent) when THIS value
    // actually changed — avoids needless re-hosting churn. Seeded lazily on the first apply.
    private var appliedAccentIndex: Int?

    // Phase 6 / APP-03 / D-09 — the UserDefaults observer token. Flipping an activity toggle (or
    // the accent swatch) posts UserDefaults.didChangeNotification; the controller re-reads the
    // keys to start/stop the matching monitor, flush any standing/queued transient of a disabled
    // category, and re-inject the accent. Removed in deinit.
    private var defaultsObserver: NSObjectProtocol?

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

    // While EXPANDED the keep-open region is the WHOLE expanded island, NOT the tiny collapsed
    // pill — otherwise moving the pointer DOWN onto the transport controls reads as "left the
    // hot-zone" and the grace timer collapses the island out from under the pointer (no time to
    // press pause/skip). Set alongside hotZone on every resolve; handlePointer uses this while
    // the island is expanded. nil until the first successful resolve.
    private var expandedZone: CGRect?

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

        // CHG-01 / CHG-02 (Plan 03 / Phase 6 D-09): register the LIVE IOKit power-source
        // notification ONLY if the Charging toggle is on (prefer stop → idle CPU ~0% when off).
        // It emits the initial reading once (seeded WITHOUT a splash via didSeedInitialPower)
        // and then fires on every plug/unplug → handlePower on main. Event-driven, no poll.
        if activityEnabled(ActivitySettings.chargingKey) { startPowerMonitor() }

        // Phase 4 / NOW-01/02/03 (Plan 04 / Phase 6 D-09): construct + start the LIVE MediaRemote
        // bridge ONLY if the Now Playing toggle is on. start() opens ONE persistent `loop` child
        // that emits the current session immediately (NOW-03 restart survival). runHealthCheck is
        // the D-12 launch probe. When the toggle is off the perl child is never spawned (idle CPU).
        if activityEnabled(ActivitySettings.nowPlayingKey) { startNowPlayingMonitor() }

        // Phase 6 / DEV-01 (D-09): register the LIVE IOBluetooth connect/disconnect monitor ONLY
        // if the Devices toggle is on. Mirrors the power monitor's construction; handleDevice
        // feeds the pure device seam → the transient queue. (On-device BT UAT is the deferred
        // carry-over; the wiring is code-complete.)
        if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }

        // Phase 6 / APP-03 / D-09: observe UserDefaults so flipping a toggle (or the accent
        // swatch) live-applies — start/stop the affected monitor, flush its standing/queued
        // transient, re-inject the accent, and re-render. UserDefaults posts on the thread that
        // mutated it; @AppStorage from the SettingsView runs on main, so hop to main to be safe.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.handleSettingsChanged() }

        // Phase 6: seed the first rendered presentation from the resolver (idle until an
        // activity fires) so the view starts from the single-arbiter verdict, not a stale value.
        renderPresentation()
    }

    // MARK: - Phase 6: toggle-gated monitor lifecycle (D-09 prefer stop, Pitfall 5 idempotent)

    // Read an activity toggle from UserDefaults. Defaults to TRUE (D-07 all default ON) when the
    // key is absent — the SettingsView @AppStorage uses the same default, so a fresh install
    // shows everything.
    private func activityEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    // Idempotent start: only constructs/starts if not already running (Pitfall 5 — never
    // double-register an IOPS source on a fast toggle on/off/on).
    private func startPowerMonitor() {
        guard powerMonitor == nil else { return }
        didSeedInitialPower = false              // re-seed: the re-enable reading must not splash
        let monitor = PowerSourceMonitor { [weak self] reading in self?.handlePower(reading) }
        powerMonitor = monitor
        monitor.start()
    }

    private func startNowPlayingMonitor() {
        guard nowPlayingMonitor == nil else { return }
        let np = NowPlayingMonitor(
            onSnapshot: { [weak self] snap, art in self?.handleNowPlaying(snap, art) },
            onTerminated: { [weak self] in self?.handleAdapterTerminated() })   // D-13
        nowPlayingMonitor = np
        np.start()
        np.runHealthCheck { [weak self] healthy in
            guard let self else { return }
            self.nowPlayingState.isHealthy = healthy   // D-12
            self.renderPresentation()
        }
    }

    private func startBluetoothMonitor() {
        guard bluetoothMonitor == nil else { return }
        // Reset the edge-tracking state and stamp the start so the at-launch connect burst of
        // already-connected devices is recorded-but-not-splashed (deviceLaunchGrace window).
        connectedDeviceAddresses.removeAll()
        bluetoothStartedAt = Date()
        let bt = BluetoothMonitor { [weak self] reading in self?.handleDevice(reading) }
        bluetoothMonitor = bt
        bt.start()
    }

    // The built-in display's CURRENT descriptor, or nil when the built-in has dropped out
    // (clamshell). nil is NOT fullscreen — isTrueFullscreen maps nil→false and the no-target
    // branch of shouldShow owns the clamshell hide. Rebuilt on EVERY visibility re-eval so a
    // fullscreen-induced safe-area collapse on the built-in is observed live (Pattern 6).
    private func currentBuiltin() -> ScreenDescriptor? {
        NSScreen.screens.map { $0.descriptor }.first { $0.isBuiltin }
    }

    // MARK: - Phase 6: the single arbiter (resolver) + its render

    // COORD-01 / D-05 — compute what the island should render via the PURE resolver. Settings
    // are applied BEFORE the resolver (D-09): a disabled Now Playing forces `.none` so the
    // ambient glance disappears live; charging/device are excluded by stopping their monitors
    // (so they never enqueue a transient). The queue's `head` is the active transient (rank 1/2);
    // the resolver falls through to the now-playing wings / idle pill when no transient stands.
    private func currentPresentation() -> IslandPresentation {
        let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
        let np = npEnabled ? nowPlayingState.presentation : .none   // D-09 disabled NP → forced .none
        return resolve(activeTransient: transientQueue.head,
                       nowPlaying: np,
                       nowPlayingHealthy: nowPlayingState.isHealthy,
                       isExpanded: interaction.isExpanded)
    }

    // Write the resolver's verdict to the @Published carrier the view observes. The CALLER owns
    // the spring wrapper (so the morph is attached AT the originating mutation, D-08) — this just
    // assigns. Every head/expanded/now-playing mutation ends by calling this + updateVisibility().
    private func renderPresentation() {
        presentationState.presentation = currentPresentation()
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
            expandedZone = nil
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
        // While expanded, the WHOLE expanded island (the panel union, padded) keeps it open so
        // the pointer can reach the transport controls without tripping the grace-collapse.
        expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)

        let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
        if self.panel == nil {
            // Phase 6 / D-11 — host the view with the persisted accent injected on the
            // `\.activityAccent` Environment value (read by the 3 lively leaf elements). The view
            // observes presentationState (the resolver's verdict) for the single-arbiter render.
            let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
            appliedAccentIndex = index
            panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index))
            self.panel = panel
        }
        panel.setFrame(panelFrame, display: true) // reposition for resolution / display changes
        panel.orderFrontRegardless()                 // show WITHOUT activating the app — focus-safe (D-07)
    }

    // Pattern 1: every .mouseMoved tick hit-tests the GLOBAL pointer against the hot-zone.
    // No coordinate conversion — both `point` and `hotZone` are global bottom-left (Pitfall 6).
    private func handlePointer(at point: CGPoint) {
        // While expanded, the keep-open region is the full expanded island so the pointer can
        // travel down to the transport controls without reading as a hot-zone exit (which would
        // collapse the island after the grace delay). Collapsed/hovering use the small pill zone.
        let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
        guard let zone = activeZone else { return }
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
                // Phase 6: a grace-collapse from .expanded flips `isExpanded` false — re-resolve
                // inside the spring so an expanded-media island morphs back to the ambient glance.
                self.renderPresentation()
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
            // Phase 6: expand/collapse flips `isExpanded`, a resolver input — re-resolve inside
            // the SAME spring so the island morphs between the wings/expanded presentation cases.
            renderPresentation()
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
            // Phase 6 / D-02 rank 1: ENQUEUE the charging transient instead of setting the model
            // directly as the render driver. If it becomes the head NOW, re-resolve (inside the
            // spring, D-08) → render + the SINGLE updateVisibility() (fullscreen gate) + arm the
            // ~3s one-shot dismiss that advances the queue. If a transient already stands it is
            // enqueued behind it (D-03 sequential) and plays when the head's ~3s elapses.
            chargingState.activity = activity   // keep the model in sync (the % tick mutates it)
            let changed = transientQueue.enqueue(.charging(activity))
            if changed {
                withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                    renderPresentation()
                }
                updateVisibility()           // Pattern 6 — the SOLE show/hide site (fullscreen gate)
                scheduleActivityDismiss()    // D-09 — the ~3s one-shot that advances the queue
            }
        } else if next != nil, case .charging = transientQueue.head {
            // A pure % tick while a CHARGING splash already stands: update the standing head's %
            // WITHOUT restarting the ~3s timer or re-enqueuing (Pitfall 4). Refresh both the
            // queue head and the model, then re-render so the number updates inside the splash.
            chargingState.activity = next
            if let activity = next { transientQueue.updateHead(.charging(activity)) }
            renderPresentation()
        }
    }

    // D-09 / Pattern 5 / Phase 6 D-03 — the ONE one-shot dismiss, generalized from a single
    // charging splash to the transient QUEUE. A single wake-up that ADVANCES the queue inside the
    // spring, then idles (no recurring timer → idle CPU ~0%). On advance:
    //   • head changed to a NEW transient → re-render + re-arm for the next ~3s (D-03 sequential);
    //   • head cleared (queue empty) → re-render to the ambient state (the resolver falls through
    //     to .nowPlayingWings if playing, else .idle — Pitfall 2 yield-to-wings, NOT to empty).
    // Re-scheduling cancels any pending one. Clears the per-category @Published model when its
    // transient leaves the head so a later in-place % tick can't touch a dismissed splash.
    private func scheduleActivityDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            _ = self.transientQueue.advance()             // D-03 — promote next pending or clear
            self.syncActivityModels()                     // drop the model for whatever left the head
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.renderPresentation()                 // next splash, or ambient (Pitfall 2)
            }
            self.updateVisibility()                       // the SOLE show/hide site (fullscreen gate)
            if self.transientQueue.head != nil {
                self.scheduleActivityDismiss()            // re-arm the ~3s for the next transient
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + activityDuration, execute: work)
    }

    // Keep the per-category @Published models in step with the queue head: whichever category is
    // NOT the current head has no standing splash, so clear its model (so a stale % tick or a
    // view binding can't resurrect a dismissed splash). The head's own model is left as-is.
    private func syncActivityModels() {
        switch transientQueue.head {
        case .charging: deviceState.activity = nil
        case .device:   chargingState.activity = nil
        case nil:       chargingState.activity = nil; deviceState.activity = nil
        }
    }

    // Phase 6 / DEV-01 / DEV-02 — a live IOBluetooth connect/disconnect lands here (already on
    // main; BluetoothMonitor's callback runs on the main run loop). It mirrors handlePower:
    //   1. The PURE shouldShowDeviceSplash(...) predicate gates BEFORE the queue (05 D-04
    //      reconnect-flap debounce + at-launch burst suppression) — T-06-09 DoS mitigation: a
    //      flapping device can't flood the queue because this gate drops repeats within `debounce`.
    //   2. The PURE deviceActivity(from:) maps the (UNTRUSTED, T-05-01) reading → a bounded
    //      DeviceActivity (name already clamped to a plain String by deviceLabel).
    //   3. ENQUEUE as a rank-2 transient (D-02): show immediately if no transient stands, else
    //      play after the current one (D-03 sequential). On a head change → render (in the spring)
    //      + the SINGLE updateVisibility() (fullscreen gate) + arm the shared ~3s dismiss.
    private func handleDevice(_ reading: DeviceReading) {
        let now = Date().timeIntervalSinceReferenceDate

        // EDGE detection (post-checkpoint fix): IOBluetooth re-fires connection events for an
        // already-connected device (the CoreBluetooth bridge fires connectionEventDidOccur
        // repeatedly), which previously made a stable headphone splash perpetually. Splash ONLY on
        // a genuine connect/disconnect EDGE, keyed by address. Without an address we cannot dedup,
        // so a nameless/addressless phantom event is dropped (it must not splash).
        guard let addr = reading.address else { return }
        if reading.connected {
            guard !connectedDeviceAddresses.contains(addr) else { return }   // already connected → no repeat splash
            connectedDeviceAddresses.insert(addr)
            // 05 D-04 at-launch suppression: a device already connected when the monitor started is
            // recorded as connected above but does NOT splash (the user did not just connect it).
            if let started = bluetoothStartedAt,
               Date().timeIntervalSince(started) < deviceLaunchGrace { return }
        } else {
            // Disconnect edge: only splash if we actually had it tracked as connected.
            guard connectedDeviceAddresses.remove(addr) != nil else { return }
        }

        // Secondary flap debounce (05 D-04): drop a repeat edge for the same address within ~3s.
        guard shouldShowDeviceSplash(address: addr,
                                     connected: reading.connected,
                                     now: now,
                                     lastShown: deviceLastShown,
                                     debounce: deviceDebounce,
                                     suppressedAtLaunch: deviceSuppressedAtLaunch)
        else { return }                                   // 05 D-04 — debounced
        deviceLastShown[addr] = now

        guard let activity = deviceActivity(from: reading) else { return }
        deviceState.activity = activity                   // keep the model in sync with the head
        let changed = transientQueue.enqueue(.device(activity))   // D-02 rank 2 / D-03 sequential
        if changed {
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                renderPresentation()
            }
            updateVisibility()                            // Pattern 6 — the SOLE show/hide site
            scheduleActivityDismiss()                     // shared ~3s one-shot (advances the queue)
            // The HFP battery indicator can arrive a beat after the connect notification, so the
            // splash may open with the connection sign; refresh it shortly after so the battery
            // appears within the ~3s glance (no-op if the battery was already present / unchanged).
            if reading.connected { scheduleDeviceBatteryRefresh(address: addr) }
        }
    }

    // Bounded POLL for the just-connected device's battery: the HFP AT+IPHONEACCEV value often
    // lands a second or two AFTER the connect notification, so a single re-read can miss it. Re-read
    // every ~0.6s; the moment a level arrives (and the device is still the standing head) update the
    // head in place (no dismiss re-arm — like a charging % tick) so the BatteryIndicator replaces the
    // connection sign live, then stop. Bounded to ~6 attempts (~3.6s) and naturally ends when the
    // device splash advances off the head. ONE work item, cancelled/replaced per connect + in deinit.
    private func scheduleDeviceBatteryRefresh(address: String, attempt: Int = 0) {
        deviceBatteryWork?.cancel()
        guard attempt < 6 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Stop once the device is no longer the standing splash (advanced / dismissed).
            guard case .device(.connected(let name, let glyph, let old))? = self.transientQueue.head else { return }
            if let monitor = self.bluetoothMonitor,
               let fresh = monitor.battery(forAddress: address), fresh != old {
                let updated = DeviceActivity.connected(name: name, glyph: glyph, battery: fresh)
                self.deviceState.activity = updated
                self.transientQueue.updateHead(.device(updated))
                withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                    self.renderPresentation()
                }
                return   // got a level — stop polling
            }
            self.scheduleDeviceBatteryRefresh(address: address, attempt: attempt + 1)   // retry
        }
        deviceBatteryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    // MARK: - Phase 6: hosting view + live settings application (APP-03 / D-09 / D-11)

    // Build the SwiftUI root with the accent injected on the Environment (D-11). Extracted so the
    // initial host AND the live accent re-apply (applyAccentIfChanged) share ONE construction.
    // accent(for:) clamps an out-of-range index to the neutral default (T-06-11 — never crashes).
    private func makeRootView(accentIndex: Int) -> some View {
        NotchPillView(interaction: interaction, charging: chargingState,
                      nowPlaying: nowPlayingState,
                      presentationState: presentationState,
                      onClick: { [weak self] in self?.handleClick() },
                      // NOW-02: transport rides the EXISTING persistent child's stdin via the
                      // monitor — no re-spawn, no focus steal.
                      onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
                      onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
                      onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() })
            .environment(\.activityAccent, ActivitySettings.accent(for: accentIndex))
    }

    // APP-03 / D-09 — a UserDefaults write (toggle flip or accent swatch) lands here on main.
    // It (1) starts/stops each monitor to match its toggle (prefer stop, idle CPU), flushing any
    // standing/queued transient of a category turned off (Pitfall 3), (2) re-injects the accent if
    // it changed (D-11), then (3) re-renders + routes through the single updateVisibility().
    private func handleSettingsChanged() {
        // Charging
        if activityEnabled(ActivitySettings.chargingKey) {
            startPowerMonitor()
        } else if powerMonitor != nil {
            powerMonitor?.stop(); powerMonitor = nil
            lastActivity = nil; didSeedInitialPower = false
            flushTransients(.charging)
        }

        // Devices
        if activityEnabled(ActivitySettings.deviceKey) {
            startBluetoothMonitor()
        } else if bluetoothMonitor != nil {
            bluetoothMonitor?.stop(); bluetoothMonitor = nil
            deviceLastShown.removeAll()
            flushTransients(.device)
        }

        // Now Playing — stop the perl child on disable (RESEARCH Open Q3: prefer a clean restart);
        // re-enabling start()s + re-runs the health check, mirroring launch. While disabled,
        // currentPresentation() forces nowPlaying → .none so the ambient glance disappears live.
        if activityEnabled(ActivitySettings.nowPlayingKey) {
            startNowPlayingMonitor()
        } else if nowPlayingMonitor != nil {
            nowPlayingMonitor?.stop(); nowPlayingMonitor = nil
            mediaDismissWorkItem?.cancel()
            nowPlayingState.presentation = .none
            nowPlayingState.artwork = nil
        }

        applyAccentIfChanged()

        // Re-render the resolver verdict (a forced-.none Now-Playing or a flushed transient may
        // have changed it) and route through the SOLE show/hide site.
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            renderPresentation()
        }
        updateVisibility()
    }

    // Pitfall 3 — drop a category's standing head AND any pending copy from the queue when its
    // activity is toggled off, then clear its @Published model. Rebuilds the queue without that
    // category so a disabled splash can't keep showing or wake up later. The shared dismiss
    // timer keeps running for whatever head remains (or is cancelled by the empty-head render).
    private enum TransientCategory { case charging, device }
    private func flushTransients(_ category: TransientCategory) {
        let matches: (ActiveTransient) -> Bool = { t in
            switch (t, category) {
            case (.charging, .charging), (.device, .device): return true
            default: return false
            }
        }
        transientQueue.removeAll(where: matches)
        switch category {
        case .charging: chargingState.activity = nil
        case .device:   deviceState.activity = nil
        }
        if transientQueue.head == nil { dismissWorkItem?.cancel() }
    }

    // D-11 — re-host the view (re-injecting the Environment accent) only when the persisted index
    // actually changed, so unrelated defaults writes don't churn the hosting view.
    private func applyAccentIfChanged() {
        let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
        guard index != appliedAccentIndex else { return }
        appliedAccentIndex = index
        if let panel { panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index)) }
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
            renderPresentation()            // Phase 6: now-playing is a resolver input — re-resolve
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
                self.renderPresentation()                   // Phase 6: re-resolve to ambient/idle
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
        nowPlayingState.isHealthy = false   // D-13: "nicht verfügbar" only on the NEXT expand
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            nowPlayingState.presentation = .none
            nowPlayingState.artwork = nil
            renderPresentation()            // Phase 6: re-resolve (isHealthy already flipped)
        }
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
        // Phase 6 / APP-03: the UserDefaults toggle/accent observer lives on the DEFAULT center.
        if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        graceWorkItem?.cancel()

        // CHG-01 (security T-03-06): remove the IOPS run-loop source so the context pointer
        // (which holds this controller) can't be used after free, and cancel the pending ~3s
        // dismiss. Mirrors the observer-removal + graceWorkItem?.cancel() discipline above.
        if let powerMonitor { powerMonitor.stop() }
        dismissWorkItem?.cancel()

        // Phase 6 / DEV-01 (security T-06-12): tear the IOBluetooth monitor down — unregister the
        // class connect token + every per-device disconnect token so no OS-held token outlives
        // the owner. Mirrors powerMonitor.stop()'s owner-driven teardown.
        bluetoothMonitor?.stop()
        deviceBatteryWork?.cancel()

        // Phase 4 (security T-04-12): terminate the persistent MediaRemote child so no orphaned
        // perl / MediaRemoteAdapter process leaks after the controller dies, and cancel the
        // pending D-06/D-07 dismiss. Mirrors the powerMonitor.stop() + dismissWorkItem discipline.
        nowPlayingMonitor?.stop()
        mediaDismissWorkItem?.cancel()
    }
}
