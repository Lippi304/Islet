import AppKit
import SwiftUI
import CoreLocation

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

    // FS-01 (Phase 9, Candidate C, additive) — the dedicated max-level CGS Space the panel
    // joins ALONGSIDE its unchanged `.canJoinAllSpaces` collectionBehavior (NotchPanel.swift is
    // untouched by this). 2147483647 == Int32.max, matching both verified reference
    // implementations. Owned directly here (not a separate singleton type) — this app has
    // exactly one panel, per 09-CONTEXT.md's Claude's-Discretion allowance.
    private let notchSpace = CGSSpace(level: 2147483647)

    // Pattern 6 (ISL-05) — fullscreen lives on its OWN Space, so entering/exiting true
    // fullscreen fires activeSpaceDidChange; didActivateApplication catches the fullscreen
    // kinds (fullscreen video / QuickLook) that may not take a dedicated Space (A6). Both
    // re-run the ONE visibility decision. Stored as tokens so deinit can remove them from
    // NSWorkspace.shared.notificationCenter (NOT the default center — that would no-op).
    private var spaceObserver: NSObjectProtocol?
    private var appActivateObserver: NSObjectProtocol?

    // D-10 (ISL-05) — the SINGLE fullscreen-hide gating flag. Default true ships the hide.
    // Quick task 260709-glz (APP-03) wired the seam: read fresh (no caching) on every
    // updateVisibility() call, matching licenseState.isEntitled's convention two properties
    // below.
    private var hideInFullscreen: Bool {
        activityEnabled(ActivitySettings.hideInFullscreenKey)
    }

    // Phase 10 / D-11 (LIC-03) — the live entitlement source consumed as the new dominant
    // AND-term in shouldShow(...). Read fresh on every updateVisibility() call (no caching);
    // the Keychain-backed trial/DEBUG-override logic lives entirely in LicenseState (Plan 01).
    private let licenseState = LicenseState.shared

    // Phase 10 / D-13 — idle-state guard flag: true when a license-driven hide is OWED but was
    // deferred because the pointer was mid-hover or the island was mid-expansion. Applied at the
    // next natural transition (handleHoverExit's grace-elapsed collapse or a handleClick
    // toggle-shut), never synchronously mid-interaction.
    private var pendingLockoutHide = false

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

    // Phase 6 / COORD-01 / D-05 — the @Published carrier of the resolver's verdict. The view
    // observes this; the controller writes it (inside the spring) on every state change via
    // renderPresentation(). This is the ONE place the rendered presentation is set.
    private let presentationState = IslandPresentationState()

    // Phase 20 / SHELF-03 — the SEPARATE @Published shelf model NotchPillView's shelf row
    // observes. The controller is the ONLY writer — every mutation below resyncs `.items` from
    // `shelfCoordinator.logic.items` (mirrors nowPlayingState/outfitState's own ownership contract).
    private let shelfViewState = ShelfViewState()

    // Phase 20 / SHELF-04/05/07 — owns the real Phase-19 append/remove/clear + disk-IO seam.
    // No `start()`-time construction needed (unlike deviceCoordinator, ShelfCoordinator has no
    // `[weak self]`-capturing closures to bind).
    private let shelfCoordinator = ShelfCoordinator()

    // Phase 14 / WEATHER-01 / CAL-01 — the SEPARATE @Published outfit model the expandedIdle
    // 3-column glance observes (Plan 04). Held behind their PROTOCOL types (never the concrete
    // class), mirroring `nowPlayingMonitor: NowPlayingService?`'s existing convention — a future
    // WeatherKit/EventKit API change becomes a one-file swap. `lastLocation` caches the one-shot
    // coordinate (D-01): a MacBook rarely changes location meaningfully within a session, so the
    // coarse refresh timer reuses it instead of re-prompting/re-requesting location every cycle.
    private let outfitState = BasicOutfitState()
    private let weatherService: WeatherService = WeatherKitService()
    private let calendarService: CalendarService = EventKitService()
    private let locationProvider: LocationService = LocationProvider()
    private var outfitRefreshTimer: Timer?
    private var lastLocation: CLLocation?

    // Phase 6 / COORD-01 / D-03 — the bounded, de-duped SEQUENTIAL transient queue (pure value
    // from IslandResolver.swift). Its `head` feeds `resolve(activeTransient:)`; charging + device
    // splashes enqueue here and play one-after-another off the SINGLE one-shot dismiss below.
    private var transientQueue = TransientQueue()

    // Phase 6 / DEV-01 — the LIVE IOBluetooth connect/disconnect monitor (clone of powerMonitor).
    // Constructed + started in start() ONLY when the device toggle is on (D-09 prefer stop);
    // held as a plain optional so toggle-off / deinit can stop() + release it.
    private var bluetoothMonitor: BluetoothMonitor?

    // Phase 16 / D-02 — the extracted device-splash bookkeeping now lives in DeviceCoordinator
    // (Plan 16-01), wired here via reach-back closures (TransientQueue is a value type, so the
    // coordinator can't hold a reference to it). Constructed in start() (so the [weak self]
    // closures bind a fully-initialised self, mirroring powerMonitor/nowPlayingMonitor's own
    // convention) and held as a plain (implicitly-unwrapped) stored property — NOT `lazy` — so
    // the nonisolated deinit can call deviceCoordinator?.cancelPendingWork() directly: a `lazy
    // var`'s synthesized getter is itself actor-isolated and cannot be read from a nonisolated
    // deinit context, unlike a plain stored field (T-16-03, deviation from the plan's literal
    // "lazy var" wording — see 16-02-SUMMARY.md). Effectively non-optional after start() runs;
    // its bookkeeping simply sits idle when the Devices toggle is off, exactly as the old fields did.
    private var deviceCoordinator: DeviceCoordinator!

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
    private var nowPlayingMonitor: NowPlayingService?

    // D-06 (15s paused linger) / D-07 (stop cue) — the one-shot media auto-dismiss. A single
    // DispatchWorkItem mirroring dismissWorkItem (NOT a recurring timer): one wake-up then idle,
    // so CPU stays ~0% while a paused/stopped glance lingers. Resuming playback cancels it.
    private var mediaDismissWorkItem: DispatchWorkItem?
    private let pausedTimeout: TimeInterval = 15.0   // D-06 single tuning seed

    // Phase 18 / NOW-05 (D-03) — the song-change toast's own one-shot ~3s auto-dismiss,
    // fully independent of mediaDismissWorkItem (T-18-05). Mirrors scheduleMediaDismiss's
    // cancel-then-reschedule discipline exactly.
    private var toastDismissWorkItem: DispatchWorkItem?

    // D-09 / Pattern 5 — the ~3s one-shot auto-dismiss. A single DispatchWorkItem mirroring
    // graceWorkItem (NOT a recurring timer): one wake-up then idle, so CPU stays ~0% while a
    // splash stands. Hover cancels it; pointer-leave reschedules it.
    private var dismissWorkItem: DispatchWorkItem?
    private let activityDuration: TimeInterval = 3.0   // D-09 single tuning seed
    private let songToastDuration: TimeInterval = 2.0   // song-change toast auto-dismiss (round 5, on-device request: 1s shorter than the shared activityDuration, toast-only)

    // Phase 10 / D-12 — the best-effort ONE-SHOT proactive expiry re-check, mirroring the exact
    // property + cancel-then-reschedule + deinit-cancel idiom already used 4x in this file
    // (dismissWorkItem/graceWorkItem/mediaDismissWorkItem/DeviceCoordinator's own work item). NOT a polling loop
    // (Pitfall 1): the authoritative check is the wall-clock licenseState.isEntitled read inside
    // updateVisibility(), which already re-runs on every existing screen/space/app-activate
    // notification — this timer only nudges that check right at the computed expiry instant so
    // the lockout doesn't wait for the next incidental trigger.
    private var trialExpiryWorkItem: DispatchWorkItem?

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

    // Phase 15 / P15-ITEM5 — mirrors the shown/hidden branch of updateVisibility() so the
    // outfit-refresh timer can gate on it (D-06): true only while the island is actually
    // visible (panel shown), false while hidden (fullscreen or expired trial).
    private var isCurrentlyVisible = false

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
        // Phase 16 / D-02 — constructed here (not at declaration) so the [weak self]-capturing
        // closures bind a fully-initialised self, mirroring powerMonitor/nowPlayingMonitor's
        // own start()-time construction.
        deviceCoordinator = DeviceCoordinator(
            queueHead: { [weak self] in self?.transientQueue.head },
            enqueue: { [weak self] t in self?.transientQueue.enqueue(t) ?? false },
            updateHead: { [weak self] t in self?.transientQueue.updateHead(t) },
            presentTransientChange: { [weak self] in self?.presentTransientChange() },
            renderPresentation: { [weak self] in self?.renderPresentation() },
            batteryForAddress: { [weak self] addr in self?.bluetoothMonitor?.battery(forAddress: addr) }
        )

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

        // Phase 14 / WEATHER-01 / CAL-01: start the outfit (weather + calendar) coarse-refresh
        // cycle. Unconditional — unlike the toggle-gated monitors above, this phase has no
        // Settings toggle of its own (out of scope for 14-04).
        startOutfitRefresh()

        // Phase 20 / SHELF-03/04/05/07 (Pitfall 5) — DEBUG-only hand-seed of real, on-disk sample
        // shelf items so the shelf strip is visually verifiable ahead of Phase 22's real drag-in.
        // Never compiles into Release.
        #if DEBUG
        seedDebugShelfItems()
        #endif

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

        // Phase 10 / D-12: arm the best-effort one-shot proactive expiry re-check.
        scheduleTrialExpiryCheck()
    }

    // Phase 10 / D-12 — schedules the single one-shot re-check of updateVisibility() at the
    // computed trial-expiry instant. Best-effort only: DispatchQueue.main.asyncAfter deadlines
    // are Mach-time-based and pause during system sleep, so a multi-day timer can fire LATE
    // relative to wall-clock expiry (never early) — the authoritative check remains the
    // wall-clock licenseState.isEntitled read inside updateVisibility() (T-10-06, accepted).
    private func scheduleTrialExpiryCheck() {
        trialExpiryWorkItem?.cancel()
        guard let expiry = licenseState.trialExpiryDate, expiry > Date() else { return }
        let work = DispatchWorkItem { [weak self] in self?.updateVisibility() }
        trialExpiryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + expiry.timeIntervalSinceNow, execute: work)
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
            // Finding 6: this one-shot probe races the PERSISTENT stream (handleNowPlaying sets
            // isHealthy = true on every real emission). If the stream already proved the bridge
            // alive before this probe's own 3s timeout settles false, the stale timeout must
            // never overwrite that true — handleNowPlaying/handleAdapterTerminated remain the
            // SOLE authority for flipping the flag back to false on an ACTUAL stream death
            // (mirrors PowerSourceMonitor's single-source-of-truth discipline: no second,
            // independently-racing probe for the same state).
            guard healthy || !self.nowPlayingState.isHealthy else { return }
            self.nowPlayingState.isHealthy = healthy   // D-12
            self.renderPresentation()
        }
    }

    private func startBluetoothMonitor() {
        guard bluetoothMonitor == nil else { return }
        // Reset the edge-tracking state and stamp the start so the at-launch connect burst of
        // already-connected devices is recorded-but-not-splashed (DeviceCoordinator's launch-grace window).
        deviceCoordinator.started(at: Date())
        let bt = BluetoothMonitor { [weak self] reading in self?.deviceCoordinator.handle(reading) }
        bluetoothMonitor = bt
        bt.start()
    }

    // Phase 14 / WEATHER-01 / CAL-01 — idempotent start (mirrors startPowerMonitor/
    // startBluetoothMonitor's `guard ... == nil` convention): requests the device location
    // ONCE (D-01 — never re-requested on refresh, only cached in `lastLocation`), fetches
    // calendar immediately (no location dependency), then arms the 15-minute coarse refresh
    // (well under WeatherKit's 500k/month quota per RESEARCH.md).
    private func startOutfitRefresh() {
        guard outfitRefreshTimer == nil else { return }
        locationProvider.requestOnce { [weak self] location in
            self?.lastLocation = location
            self?.refreshWeather()
        }
        refreshCalendar()
        outfitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            // Phase 15 / P15-ITEM5 (D-06) — skip the fetch entirely while hidden (fullscreen or
            // expired trial); updateVisibility()'s hidden-to-visible edge resumes it on the next show.
            guard let self, self.isCurrentlyVisible else { return }
            self.refreshWeather()
            self.refreshCalendar()
        }
    }

    // D-01: no cached location means no attempt, ever — never re-request here (that's
    // startOutfitRefresh's one-shot job alone).
    private func refreshWeather() {
        guard let loc = lastLocation else { return }
        weatherService.fetchCurrent(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude) { [weak self] glance in
            self?.outfitState.weather = glance
        }
    }

    private func refreshCalendar() {
        calendarService.fetchUpcoming { [weak self] glance in
            self?.outfitState.calendar = glance
        }
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
        // Gap-closure fix (Finding 5): gate the health flag through the same npEnabled switch as
        // `np` above — a disabled Now Playing must be INVISIBLE to the resolver (forced neutral),
        // not silently degraded to "nicht verfügbar" from a stale `false` left over from before
        // the toggle.
        let healthy = nowPlayingHealthGate(enabled: npEnabled, isHealthy: nowPlayingState.isHealthy)
        return resolve(activeTransient: transientQueue.head,
                       nowPlaying: np,
                       nowPlayingHealthy: healthy,
                       hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch,
                       isExpanded: interaction.isExpanded)
    }

    // Write the resolver's verdict to the @Published carrier the view observes. The CALLER owns
    // the spring wrapper (so the morph is attached AT the originating mutation, D-08) — this just
    // assigns. Every head/expanded/now-playing mutation ends by calling this + updateVisibility().
    private func renderPresentation() {
        presentationState.presentation = currentPresentation()
    }

    // Finding 11 — consolidates the identical enqueue-render-dismiss triplet that handlePower
    // and handleDevice each hand-rolled: spring-wrap renderPresentation(), call the sole
    // updateVisibility(), (re)arm the shared ~3s dismiss. Not used by scheduleActivityDismiss's
    // own DispatchWorkItem body — its advance-branch conditionally re-arms rather than
    // unconditionally scheduling, so it correctly stays distinct (calling this here would
    // double-arm the dismiss).
    private func presentTransientChange() {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            // Phase 18 / NOW-05 (RESEARCH.md Pitfall 5, D-02) — a toast already showing must
            // clear the instant a NEW transient interrupts it, or it could reappear once the
            // interrupting splash ends. This function runs ONLY at the exact moment
            // transientQueue.head transitions nil -> non-nil, so this single insertion covers
            // both the charging and device interruption paths. No-op when no toast is showing.
            if nowPlayingState.songChangeToast != nil {
                toastDismissWorkItem?.cancel()
                nowPlayingState.songChangeToast = nil
            }
            renderPresentation()
        }
        updateVisibility()
        scheduleActivityDismiss()
    }

    // Pattern 7 (ISL-05) — the ONE visibility decision and the SOLE show/hide site. The
    // Phase-1 clamshell/display-target signal (selectTargetScreen) AND the Phase-2 fullscreen
    // signal (isTrueFullscreen) converge through the single shouldShow AND; there is no second
    // hide/show call anywhere in the file (Pitfall 5 — a double show/hide site would race
    // the clamshell and fullscreen observers into flicker / stuck state). Idempotent: every
    // observer (didChangeScreenParameters, activeSpaceDidChange, didActivateApplication) calls
    // ONLY this; safe to call repeatedly.
    private func updateVisibility() {
        // Phase 15 / P15-ITEM5 (D-06) — captured before any early return/branch so the
        // hidden-to-visible transition below can detect the edge and resume outfit refresh.
        let wasVisible = isCurrentlyVisible

        // Phase 10 / D-13 — idle-state guard: a license-driven hide must never abruptly yank the
        // island out from under an active hover/expansion. If the pointer is in the hot-zone or
        // the island is expanded, defer the hide (set pendingLockoutHide) and leave panel/hotZone/
        // expandedZone/pointerInZone completely untouched this call — the deferred hide is applied
        // at the next natural transition (handleHoverExit's grace-elapsed collapse or a
        // handleClick toggle-shut, both of which re-invoke updateVisibility()).
        let midInteraction = pointerInZone || interaction.isExpanded
        if !licenseState.isEntitled && midInteraction {
            pendingLockoutHide = true
            return
        }
        if pendingLockoutHide {
            pendingLockoutHide = false
        }

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
                      isFullscreen: fullscreen,
                      isLicensed: licenseState.isEntitled),
           let target {
            isCurrentlyVisible = true
            positionAndShow(on: target)
            // Phase 15 / P15-ITEM5 (D-06) — a hidden-to-visible transition resumes outfit data
            // immediately instead of waiting up to 15 minutes for the next timer tick.
            if !wasVisible {
                refreshWeather()
                refreshCalendar()
            }
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
            isCurrentlyVisible = false
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

        // D-01 — publish the VISIBLE collapsed pill size from the SAME measured notch, but
        // UNFUDGED (widthFudge: 0 == exactly the cutout macOS reports). The fudge split is
        // deliberate: the transparent WINDOW / hot-zone above keeps its 4pt overlap so the
        // morph coverage + pointer target sit seamlessly over the hardware edges, while the
        // black pill uses the unfudged size so no black spills past the physical notch — a
        // clean idle merge. nil (non-notch / degenerate) leaves the view on its 200x38 fallback.
        interaction.collapsedNotchSize = notchSize(screenWidth: target.frame.width,
                                                   safeAreaTop: target.safeAreaTop,
                                                   auxLeftWidth: target.auxLeftWidth,
                                                   auxRightWidth: target.auxRightWidth,
                                                   widthFudge: 0)

        // Pattern 4 / Pitfall 4: size the PANEL to the EXPANDED frame UP FRONT (the extra
        // area is transparent → invisible) so the SwiftUI spring morph never clips or jumps
        // mid-animation. The collapsed pill sits flush at the top of this larger window.
        // Phase 20 / SHELF-03: the panel reserves the shelf band UNCONDITIONALLY (transparent
        // when empty) so the window is never live-resized when the shelf gains its first item —
        // the VISIBLE black shape (NotchPillView.blobShape) still only grows into that space
        // conditionally, exactly matching the panel's reserved height.
        let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                               expandedSize: CGSize(width: expandedSize.width,
                                                                     height: expandedSize.height + NotchPillView.shelfRowHeight))

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
            // FS-01 (Candidate C, additive) — join the dedicated max-level Space exactly ONCE,
            // here at panel creation (never re-synced per show/hide cycle, RESEARCH.md
            // Anti-Patterns). collectionBehavior above is unaffected.
            notchSpace.windows.insert(panel)
        }
        if panel.frame != panelFrame {
            panel.setFrame(panelFrame, display: true) // reposition for resolution / display changes
        }
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
        // Finding 7: mediaDismissWorkItem below mirrors the SAME hover-pause discipline for the
        // D-06 paused-media linger — safe to call unconditionally (a no-op via optional
        // chaining when nothing is pending).
        dismissWorkItem?.cancel()
        mediaDismissWorkItem?.cancel()

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
            // Phase 10 / D-13: this is the natural-transition recheck the idle-state guard
            // depends on — the pointer has just left AND the grace-elapsed collapse has just
            // finished, so a previously-deferred pendingLockoutHide now applies here.
            self.updateVisibility()
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
        // Finding 7: symmetric resume for the D-06 paused-media linger — only re-arm when a
        // paused glance is genuinely standing (mirrors handleNowPlaying's own .paused gating).
        if case .paused = nowPlayingState.presentation {
            scheduleMediaDismiss(after: pausedTimeout)
        }
    }

    // D-02 CLICK-to-expand: the ONLY path to `.expanded`. Wired from NotchPillView's
    // onTapGesture; runs the pure `.clicked` transition inside the spring. The panel is
    // already non-activating + never key, so this never steals focus (D-04).
    private func handleClick() {
        let wasExpanded = interaction.isExpanded
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .clicked)
            // Phase 18 / NOW-05 (RESEARCH.md Pitfall 5, D-04) — a toast already showing must
            // clear the instant the user manually expands, or it could reappear once the
            // expanded card collapses. Fires only on the expand transition (never a toggle-shut
            // click, since wasExpanded would already be true there). No-op when no toast shows.
            if !wasExpanded && interaction.isExpanded && nowPlayingState.songChangeToast != nil {
                toastDismissWorkItem?.cancel()
                nowPlayingState.songChangeToast = nil
            }
            // Phase 6: expand/collapse flips `isExpanded`, a resolver input — re-resolve inside
            // the SAME spring so the island morphs between the wings/expanded presentation cases.
            renderPresentation()
        }
        // Phase 10 / D-13: this is the OTHER natural-transition recheck the idle-state guard
        // depends on — a toggle-shut click (.expanded → .collapsed) applies any previously
        // deferred pendingLockoutHide right away instead of waiting for a hover-exit.
        if !interaction.isExpanded {
            updateVisibility()
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
                presentTransientChange()     // Finding 11 — shared render/visibility/dismiss triplet
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
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.syncActivityModels()                 // drop the model for whatever left the head
                self.renderPresentation()                 // next splash, or ambient (Pitfall 2)
            }
            self.updateVisibility()                       // the SOLE show/hide site (fullscreen gate)
            if self.transientQueue.head != nil {
                self.deviceCoordinator.activityPromoted()  // Finding 4 — cover a device promoted here
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
        case .charging: break
        case .device:   chargingState.activity = nil
        case nil:       chargingState.activity = nil
        }
    }

    // MARK: - Phase 6: hosting view + live settings application (APP-03 / D-09 / D-11)

    // Build the SwiftUI root with the accent injected on the Environment (D-11). Extracted so the
    // initial host AND the live accent re-apply (applyAccentIfChanged) share ONE construction.
    // accent(for:) clamps an out-of-range index to the neutral default (T-06-11 — never crashes).
    private func makeRootView(accentIndex: Int) -> some View {
        NotchPillView(interaction: interaction,
                      nowPlaying: nowPlayingState,
                      presentationState: presentationState,
                      outfit: outfitState,
                      shelfViewState: shelfViewState,
                      onClick: { [weak self] in self?.handleClick() },
                      // NOW-02: transport rides the EXISTING persistent child's stdin via the
                      // monitor — no re-spawn, no focus steal.
                      onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
                      onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
                      onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() },
                      onShelfItemTap: { [weak self] item in self?.handleShelfItemTap(item) },
                      onShelfItemDelete: { [weak self] id in self?.handleShelfItemDelete(id) },
                      onShelfClearAll: { [weak self] in self?.handleShelfClearAll() })
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
            deviceCoordinator.reset()
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
            nowPlayingState.position = nil
        }

        // Phase 18 / NOW-06 (Pitfall 4) — turning the toast toggle off must clear an in-flight
        // toast live, not just gate future triggers, mirroring the nowPlayingKey branch above.
        if !activityEnabled(ActivitySettings.songChangeToastKey), nowPlayingState.songChangeToast != nil {
            toastDismissWorkItem?.cancel()
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                nowPlayingState.songChangeToast = nil
            }
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
    // category so a disabled splash can't keep showing or wake up later.
    //
    // Gap-closure fix (Finding 3 — dismiss-timer not re-armed on promotion): ALWAYS cancel the old
    // timer first, then re-arm a FRESH ~3s window if removeAll(where:) promoted a survivor to head
    // — the old code only cancelled when the head went to nil, so a promoted survivor silently
    // inherited the flushed transient's stale, partially-elapsed timer instead of a full window.
    //
    // Gap-closure fix (WR-2 — over-eager dismiss-timer reset): the above (Finding 3) over-corrected
    // by ALWAYS cancelling/re-arming whenever any head remained — even when the surviving head was
    // never touched by this category's removal at all (e.g. flushing Charging while an unrelated
    // Device splash already stands). `oldHead` is captured BEFORE removeAll(where:) runs; the
    // dismiss-timer cancel/re-arm block below is now gated on `transientQueue.head != oldHead`, so
    // an untouched standing splash's already-running ~3s countdown is left exactly as it was.
    private enum TransientCategory { case charging, device }
    private func flushTransients(_ category: TransientCategory) {
        let oldHead = transientQueue.head
        let matches: (ActiveTransient) -> Bool = { t in
            switch (t, category) {
            case (.charging, .charging), (.device, .device): return true
            default: return false
            }
        }
        transientQueue.removeAll(where: matches)
        switch category {
        case .charging: chargingState.activity = nil
        case .device:
            deviceCoordinator.clearPendingBatteryPolls()   // Finding 4 — drop any pending battery polls too
        }
        guard transientQueue.head != oldHead else { return }   // WR-2 — untouched head, no timer reset
        dismissWorkItem?.cancel()
        if transientQueue.head != nil {
            deviceCoordinator.activityPromoted()   // Finding 4 — cover a device promoted here
            scheduleActivityDismiss()                 // Finding 3 — fresh window for the promoted transient
        }
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
        // Finding 8: capture the OUTGOING presentation before it's overwritten below, so the
        // .paused branch can debounce a repeated identical emission (the documented artwork-
        // latency re-emission case) instead of restarting the 15s countdown on every callback.
        let previous = nowPlayingState.presentation
        // Bugfix (on-device UAT, Task 3): capture the OUTGOING position too, BEFORE it's
        // overwritten below — resolvePublishedPosition needs the last known-good playing
        // position to compute a drift-corrected freeze across a play→pause transition.
        let previousPosition = nowPlayingState.position

        // A healthy stream callback means the bridge is alive — a successful emission after a
        // prior drop restores the D-12 flag so the next expand shows media, not "nicht verfügbar".
        nowPlayingState.isHealthy = true

        // Phase 18 / NOW-05 (Pitfall 2) — capture the PRE-mutation hasPlayedSinceLaunch value
        // before the line below overwrites it, mirroring how `previous`/`previousPosition` are
        // captured before their own overwrites just above. The toast's genuine-change check
        // needs the pre-callback value so the very first track after launch never toasts.
        let hadPlayedSinceLaunch = nowPlayingState.hasPlayedSinceLaunch

        // Phase 17 / NOW-04 — D-01/D-02: first real Play observed this Islet run lifts the launch
        // gate permanently. Set BEFORE the render call below so the triggering snapshot itself
        // isn't gated — do NOT move into the post-render `switch p` block further down (it runs
        // AFTER the render call in this same invocation and would gate this very snapshot). No
        // `if !hasPlayedSinceLaunch` guard needed: reassigning true is idempotent, mirroring the
        // unconditional isHealthy assignment just above.
        if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }

        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            nowPlayingState.presentation = p
            // PBAR-01: lift the raw duration/elapsed/timestamp/rate fields into the pure
            // PlaybackPosition value inside the SAME spring block as `presentation`.
            // Bugfix (on-device UAT, Task 3): resolve through resolvePublishedPosition rather
            // than trusting the incoming snapshot verbatim — a play→pause transition's
            // snapshot can carry a stale elapsedTimeMicros, which would otherwise render a
            // brief backward flash before a later corrected snapshot arrives.
            nowPlayingState.position = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                                  incoming: p, incomingPosition: playbackPosition(from: snapshot),
                                                                  now: Date().timeIntervalSince1970)
            // 06-10 Finding 16: a nil `art` no longer unconditionally overwrites the artwork.
            // Album art can arrive a beat after metadata (documented latency), so a nil
            // callback for the SAME track (isSameTrack(previous, p)) retains whatever's
            // already showing instead of flickering back to the placeholder. A genuine track
            // change or a stop (p == .none) still clears it, exactly as before.
            if let art {
                nowPlayingState.artwork = art
            } else if p == .none || !isSameTrack(previous, p) {
                nowPlayingState.artwork = nil
            }
            renderPresentation()            // Phase 6: now-playing is a resolver input — re-resolve

            // Phase 18 / NOW-05 (D-02/D-03/D-04) — the song-change toast. Sits inside this SAME
            // spring block so its appearance animates together with the rest of this callback's
            // mutation. Both pure checks (Pitfall 3) are evaluated BEFORE any mutation to
            // nowPlayingState.songChangeToast or scheduling the dismiss — never schedule then
            // suppress. Deliberately never touches resolve(...)/IslandPresentation — see Plan
            // 01's <objective> "Deviation from RESEARCH.md" note.
            if songChangeToastGate(activeTransient: transientQueue.head, isExpanded: interaction.isExpanded,
                                    toastEnabled: activityEnabled(ActivitySettings.songChangeToastKey)),
               let toast = songChangeToastContent(previous: previous, current: p, hasPlayedSinceLaunch: hadPlayedSinceLaunch) {
                nowPlayingState.songChangeToast = toast
                scheduleToastDismiss()
            }
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
            // Finding 8: only (re)arm on a GENUINE transition into paused (or a paused→paused
            // change to a different track) — a repeat emission of the identical .paused value
            // must not restart the countdown, or the glance could stick on-screen indefinitely.
            if previous != p {
                scheduleMediaDismiss(after: pausedTimeout)
            }
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
                self.nowPlayingState.position = nil
                self.renderPresentation()                   // Phase 6: re-resolve to ambient/idle
            }
            self.updateVisibility()   // re-evaluate the single show/hide site
        }
        mediaDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // Phase 18 / NOW-05 (D-03) — the toast's own one-shot ~3s auto-dismiss. Mirrors
    // scheduleMediaDismiss exactly: cancel any pending item, create a SINGLE DispatchWorkItem
    // that clears ONLY the toast field (orthogonal to presentation/artwork/position — no
    // re-resolve or visibility recheck needed), and asyncAfter it. One wake-up then idle.
    private func scheduleToastDismiss() {
        toastDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.nowPlayingState.songChangeToast = nil
            }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + songToastDuration, execute: work)
    }

    // D-13 mid-session child death (already on main). The adapter emitted at least once and
    // then died — clear the glance to idle and flip the health flag so the NEXT expand shows
    // "nicht verfügbar" (no mid-session splash, no crash, no empty render).
    private func handleAdapterTerminated() {
        nowPlayingState.isHealthy = false   // D-13: "nicht verfügbar" only on the NEXT expand
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            nowPlayingState.presentation = .none
            nowPlayingState.artwork = nil
            nowPlayingState.position = nil
            renderPresentation()            // Phase 6: re-resolve (isHealthy already flipped)
        }
        mediaDismissWorkItem?.cancel()
        updateVisibility()
    }

    // MARK: - Phase 20 / SHELF-04/05/07 — shelf item handlers

    // SHELF-07 / D-04 — the guard precedes the side effect: a vanished local copy (the user
    // deleted/moved it out from under the shelf) is a silent no-op, never a dialog or crash, and
    // the item stays in the shelf.
    private func handleShelfItemTap(_ item: ShelfItem) {
        guard shouldOpenShelfItem(fileExists: FileManager.default.fileExists(atPath: item.localURL.path)) else { return }
        NSWorkspace.shared.open(item.localURL)
    }

    // SHELF-04 — removes just the tapped item + its session-temp copy (ShelfCoordinator.remove),
    // then resyncs the published mirror the view observes.
    private func handleShelfItemDelete(_ id: UUID) {
        shelfCoordinator.remove(id: id)
        shelfViewState.items = shelfCoordinator.logic.items
    }

    // SHELF-05 / D-03 — clears every item + every session-temp copy instantly (no confirmation
    // dialog), then resyncs the published mirror.
    private func handleShelfClearAll() {
        shelfCoordinator.clear()
        shelfViewState.items = shelfCoordinator.logic.items
    }

    #if DEBUG
    // Pitfall 5 — real, on-disk sample files (not fabricated ShelfItem structs with synthetic
    // URLs) so icon lookup + click-to-open are realistic ahead of Phase 22's real drag-in.
    // DEBUG-only: compiled out of Release entirely.
    private func seedDebugShelfItems() {
        let seedDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("IsletShelfSeed", isDirectory: true)
        try? FileManager.default.createDirectory(at: seedDir, withIntermediateDirectories: true)

        let seeds: [(name: String, contents: String)] = [
            ("Report.pdf", "seed pdf placeholder"),
            ("Photo.jpg", "seed jpg placeholder"),
            ("Notes.txt", "seed txt placeholder"),
        ]
        for seed in seeds {
            let source = seedDir.appendingPathComponent(seed.name)
            guard (try? Data(seed.contents.utf8).write(to: source)) != nil else { continue }
            let id = UUID()
            guard let localURL = try? ShelfFileStore.makeSessionCopy(of: source, id: id) else { continue }
            let item = ShelfItem(id: id, originalURL: source, localURL: localURL, filename: seed.name, addedAt: Date())
            shelfCoordinator.append(item)
        }
        shelfViewState.items = shelfCoordinator.logic.items
    }
    #endif

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
        deviceCoordinator?.cancelPendingWork()

        // Phase 4 (security T-04-12): terminate the persistent MediaRemote child so no orphaned
        // perl / MediaRemoteAdapter process leaks after the controller dies, and cancel the
        // pending D-06/D-07 dismiss. Mirrors the powerMonitor.stop() + dismissWorkItem discipline.
        nowPlayingMonitor?.stop()
        mediaDismissWorkItem?.cancel()

        // FS-01 (Candidate C, additive): leave the dedicated max-level Space, mirroring the
        // owner-driven teardown discipline above (powerMonitor/bluetoothMonitor/nowPlayingMonitor).
        if let panel { notchSpace.windows.remove(panel) }

        // Phase 10 / D-12: cancel the best-effort proactive expiry re-check — a mere nudge, not
        // the authoritative check (that's the wall-clock read inside updateVisibility()).
        trialExpiryWorkItem?.cancel()

        // Phase 14 / WEATHER-01 / CAL-01: stop the 15-min coarse-refresh timer. No persistent
        // LocationProvider/service teardown needed — neither holds an OS-level registration
        // outside the one-shot requestLocation() call, unlike the IOKit/IOBluetooth/MediaRemote
        // monitors above.
        outfitRefreshTimer?.invalidate()
    }
}
