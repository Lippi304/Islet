import AppKit
import SwiftUI
import CoreLocation
import CoreBluetooth

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
    #if DEBUG
    // 39-07 gap closure ROUND 9 — TEMPORARY: the REAL, already-computed physical notch frame
    // (AppKit screen coordinates, bottom-left origin, y-up), captured from `positionAndShow()`'s
    // own `collapsedFrame` (this file's existing, canonical source of the notch's real on-screen
    // bounds — reused here, not re-derived) so `handleOSDKeyPress` can log it alongside
    // NotchPillView's SwiftUI-side `.global`-space frame logs for the SAME key press, giving one
    // consistent, ground-truth picture instead of another theoretical model.
    private var debugLastCollapsedFrame: CGRect?
    #endif

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

    // Phase 26 / ONBOARD-01 — the SEPARATE @Published onboarding-permissions model
    // NotchPillView's Permissions step observes, mirroring shelfViewState's ownership
    // contract. Plan 26-04 wires the real permission-request writes; this plan only needs
    // the property to exist so makeRootView's non-defaulted onboardingState param compiles.
    private let onboardingState = OnboardingViewState()

    // Phase 28 / CALVIEW-01/02/04 — the SEPARATE @Published switcher-selection + calendar-view
    // models NotchPillView's switcher pill and calendarFullView observe, mirroring
    // shelfViewState/onboardingState's ownership contract. Plan 04 wires the real
    // controller behavior (data fetch, permission requests, panel geometry); this plan (28-03)
    // only needs the properties to exist so makeRootView's non-defaulted params compile.
    private let viewSwitcherState = ViewSwitcherState()
    private let calendarViewState = CalendarViewState()

    // Phase 20 / SHELF-04/05/07 — owns the real Phase-19 append/remove/clear + disk-IO seam.
    // No `start()`-time construction needed (unlike deviceCoordinator, ShelfCoordinator has no
    // `[weak self]`-capturing closures to bind).
    private let shelfCoordinator = ShelfCoordinator()

    // Phase 34 / TRAY-02 (Pitfall 5) — the CONTROLLER-owned pending-drop state. `resolve(...)`
    // itself is pure and has no memory across calls, so the fact that a drop is awaiting a
    // Drop/AirDrop/Mail choice must live HERE, read fresh on every currentPresentation() call —
    // mirrors TransientQueue's own head/pending split, where the controller (not the resolver)
    // persists state across time. Set on a real drop (handleDragApproachEnd), cleared by
    // handleQuickActionDrop/finishQuickActionSharing/discardPendingDrop.
    private var pendingDrop: PendingDrop?

    // Phase 34 / TRAY-04 — the isolated NSSharingService seam (Plan 01). No window-activation
    // code lives here or in the service itself (D-08).
    private let quickActionSharingService = QuickActionSharingService()

    // Phase 34 (UAT revision, Pattern 3) — the Quick Action picker's 3 destination buttons' live
    // global frames, pure arithmetic (computeQuickActionButtonFrames). Recomputed once per
    // positionAndShow() call, exactly like expandedZone/dragLandingMaxY's own "recomputed every
    // show, read every tick" lifecycle — never recomputed per-tick itself, only hit-tested.
    private var quickActionButtonFrames: [CGRect] = []

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

    // Phase 27 / VISUAL-03 — the last theme applied to the hosting view: 3 independent
    // per-element accent indices plus the material style. UserDefaults posts
    // didChangeNotification for EVERY defaults write (incl. unrelated keys / Launch-at-Login), so
    // the controller only re-hosts the view (to re-inject the Environment values) when ANY of
    // these 4 actually changed — avoids needless re-hosting churn. Seeded lazily on the first apply.
    private struct AppliedTheme: Equatable {
        var nowPlaying: Int
        var charging: Int
        var device: Int
        var materialStyle: ActivitySettings.MaterialStyle
    }
    private var appliedTheme: AppliedTheme?

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

    // Phase 38 / HUD-05 (Plan 05) — the LIVE Focus/DND poll monitor. Constructed + started in
    // start() ONLY when the Focus toggle is on AND permission is already granted (D-04), mirroring
    // powerMonitor/bluetoothMonitor's toggle-gated idempotent-start discipline. Held as a plain
    // stored property so the nonisolated deinit can call its stop() (nonisolated func stop()).
    private var focusModeMonitor: FocusModeMonitor?

    // Phase 41 / HUD-08 — the LIVE Calendar Countdown monitor. Constructed + started in start()
    // ONLY when the toggle is on (default ON, D-03) — unlike Focus, there is no separate
    // permission-authorized gate to check, Calendar access is already resolved lazily inside
    // CalendarService.
    private var calendarCountdownMonitor: CalendarCountdownMonitor?
    // Phase 41 / HUD-08 — controller-owned state read fresh on every currentPresentation() call;
    // the pure resolver has no memory across calls (mirrors pendingDrop's shape, not
    // nowPlayingState.presentation's separate-ObservableObject shape).
    private var calendarCountdownActivity: CalendarCountdownActivity?

    // Phase 39 / HUD-03/HUD-04 (D-06) — the LIVE OSD key-press detector. Unlike EVERY
    // toggle-gated monitor above (powerMonitor/bluetoothMonitor/nowPlayingMonitor/
    // focusModeMonitor), this one starts UNCONDITIONALLY in start() — the Volume/Brightness
    // HUD itself requires no toggle and no permission; only native-OSD SUPPRESSION is
    // opt-in (ActivitySettings.osdSuppressionKey), read fresh inside the interceptor's own
    // `suppressionArmed` closure. Held as a plain stored property so the nonisolated deinit
    // can call its stop(), mirroring focusModeMonitor's own teardown discipline.
    private var osdInterceptor: OSDInterceptor?
    // Phase 39 / HUD-03/HUD-04 — `BrightnessReader` loads DisplayServices.framework's function
    // pointer once at construction (see BrightnessReader.init); resolved once as a stored
    // instance (mirrors licenseState's stored-instance pattern), never re-constructed per key
    // press. `readSystemVolume()` has no equivalent stored state — it is called directly inline.
    private let brightnessReader = BrightnessReader()

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
    // Phase 42 / DUAL-01 (D-11) — the secondary bubble's staggered-reveal one-shot, mirroring
    // dismissWorkItem's own cancel-then-reschedule discipline. Only used on a fresh nil→non-nil
    // transition; a nil target or an already-non-nil update never touches this.
    private var secondaryRevealWorkItem: DispatchWorkItem?
    private static let secondaryStaggerDelay: TimeInterval = 0.15   // UI-SPEC's locked starting value
    private let activityDuration: TimeInterval = 3.0   // D-09 single tuning seed
    private let songToastDuration: TimeInterval = 2.0   // song-change toast auto-dismiss (round 5, on-device request: 1s shorter than the shared activityDuration, toast-only)
    // Phase 39 / HUD-03/HUD-04 (D-10) — deliberately separate from the shared activityDuration
    // above, never consolidated: Volume/Brightness dismisses faster than Charging/Device/Focus.
    private let osdActivityDuration: TimeInterval = 1.5

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

    // Phase 21 / SHELF-06 / D-03 — the shelf-item drag pin: while true, handleHoverExit's
    // graceWorkItem defers the collapse. Released via BOTH a best-effort early signal
    // (dragReleaseMonitor, a .leftMouseUp global monitor mirroring mouseMonitor's .mouseMoved
    // idiom, armed only for the duration of an active drag) AND a guaranteed 20s safety net
    // (dragPinSafetyNetWorkItem) so the pin can never outlive a real drag gesture indefinitely.
    private var isDraggingShelfItem = false
    private var dragPinSafetyNetWorkItem: DispatchWorkItem?

    // Phase 26 / ONBOARD-01/ONBOARD-03 (D-01/D-09) — the launch-time onboarding gate state,
    // computed once at the top of start(isFirstLaunch:) from Plan 26-01's pure
    // shouldShowOnboarding(...)/shouldSeedOnboardingCompletedForExistingUser(...) gates.
    // onboardingStep feeds resolve(...)'s forced-flow precedence (IslandResolver.swift);
    // isOnboardingActive gates the Bluetooth/Location/Calendar permission-triggering calls
    // this same start() would otherwise fire eagerly (RESEARCH.md Pitfall 2).
    private(set) var onboardingStep: OnboardingStep?
    private var isOnboardingActive = false
    private let dragPinSafetyNetDuration: TimeInterval = 20.0
    private var dragReleaseMonitor: Any?

    // Phase 24 / SHELF-01 / SHELF-02 — the production DragApproachDetector monitors,
    // superseding Plan 24-01's throwaway #if DEBUG spike (A1 confirmed: 24-01-SUMMARY.md).
    // NOT DEBUG-gated — SHELF-01/02 must work in Release builds. Mirror mouseMonitor's own
    // always-on arm-in-start()/disarm-in-deinit shape exactly.
    private var dragApproachMonitor: Any?
    private var dragEndMonitor: Any?
    private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount

    // Phase 24 / SHELF-01 / SHELF-02 — the drag-approach edge-tracked flag, mirroring
    // pointerInZone's own edge-tracking discipline immediately below: armed on a genuine
    // pasteboard-changeCount-confirmed drag entering the accept region, disarmed
    // unconditionally at every .leftMouseUp (handleDragApproachEnd's literal first action) so
    // a geometrically-ambiguous Escape-cancel can never leave the island stuck expanded.
    private var isDragApproaching = false

    // WR-01: the pointer-in-hot-zone edge, tracked from RAW geometry — NOT derived from
    // `interaction.isHovering` (which is true for BOTH .hovering AND .expanded, so a
    // re-entry while expanded would never read as an enter edge and never cancel the
    // pending grace collapse, letting the island collapse out from under the pointer).
    // Reset in updateVisibility's hide branch so it can't go stale across a hide/show cycle.
    private var pointerInZone = false

    // CR-01 — the last raw GLOBAL pointer position handlePointer observed. syncClickThrough()
    // itself receives no point parameter, so it needs this to hit-test against
    // visibleContentZone() (the actual visible-blob rect, narrower than expandedZone).
    private var lastPointerLocation: CGPoint = .zero

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

    // Phase 24 / SHELF-01 / SHELF-02 (D-02c) — the new landing-margin boundary: a drag must be
    // at or below this Y to land, keeping the accept region clear of the literal top screen
    // edge. Set alongside hotZone/expandedZone in positionAndShow(), cleared alongside them in
    // updateVisibility()'s hide branch so it can't go stale across a hide/show cycle (mirrors
    // expandedZone's own stated discipline). nil until the first successful resolve.
    private var dragLandingMaxY: CGFloat?

    // The expanded island size seed. Read from the view so the window frame and the SwiftUI
    // content can never drift to different expanded sizes (Plan 05 tunes it in one place).
    private let expandedSize = NotchPillView.expandedSize

    // A few px of slop around the collapsed pill so the hot-zone is comfortable to enter.
    private let hotZonePadding: CGFloat = 6

    // Phase 24 / SHELF-01 / SHELF-02 (D-01/D-02c) — a small buffer clearing only the literal
    // 0px top screen edge / Mission-Control hot corner (Phase 22's original concern), NOT the
    // whole collapsed-pill height. On-device Task 3 UAT found 40 excluded the ENTIRE pill body
    // (topPinnedFrame puts the pill's Y range in [screenTop-32, screenTop]), making it
    // geometrically impossible to drop directly on the pill — corrected to match
    // hotZonePadding's own small-buffer scale; the pill/shelf area is the intended drop target.
    // Feeds dragLandingMaxY (positionAndShow's `target.frame.maxY - dragLandingMargin`).
    private let dragLandingMargin: CGFloat = 4

    // D-03 grace delay (within the 0.3–0.5s window). One place for Plan 05 to tune.
    private let graceDelay: TimeInterval = 0.4

    // The spring applied at every phase mutation (ISL-04 / D-07). Snappy with a slight
    // bounce. The two seeds live here so Plan 05 tunes the feel in ONE place; each mutation
    // site spells out `withAnimation(.spring(response:dampingFraction:))` so the animation
    // is provably attached AT the state change (the view itself drives no animation, D-08).
    private let springResponse: Double = 0.6
    private let springDamping: Double = 0.62

    #if DEBUG
    // A1 probe seam (Pitfall 1): the monitor returns a non-nil token even when the OS gated
    // it behind Accessibility and never actually fires. Logging ONCE on the first hover lets
    // Plan 05 confirm on-device whether the global .mouseMoved monitor fires unprompted on
    // Tahoe. If it does NOT, the ready fallback is an NSTrackingArea on the hosting view
    // (RESEARCH Pattern 1b, permission-free). DEBUG-only: the pointer location is NEVER
    // logged in release (privacy / threat T-02-07 — .mouseMoved mask only, no keyboard).
    private var didLogFirstHover = false
    #endif

    // Phase 24 / SHELF-01 / SHELF-02 (D-10) — the production drop-interception tap, closing the
    // gap Plan 24-02's Task 3 UAT surfaced (Finder's Desktop relocating the original dragged
    // file). Lazily constructed on the FIRST real drag-approach edge (D-11), not at app launch —
    // see recheckDragAcceptRegion(). Supersedes Plan 24-03 Task 1's throwaway #if DEBUG spike
    // (A5/A7/A6 all confirmed on-device: 24-03-SUMMARY.md).
    private var dropInterceptTap: DropInterceptTap?

    func start(isFirstLaunch: Bool) {
        // Phase 26 / ONBOARD-01/ONBOARD-03 (D-01, RESEARCH.md Pitfall 2) — the launch-time
        // onboarding gate, computed FIRST from Plan 26-01's pure functions before any
        // permission-triggering monitor is touched below. A stored flag always wins; a
        // genuinely fresh install (isFirstLaunch, no stored flag) shows onboarding, while an
        // existing pre-Phase-26 user (no stored flag, NOT first launch) is grandfathered —
        // seeded completed so they are never gated.
        let storedCompleted = UserDefaults.standard.object(forKey: ActivitySettings.onboardingCompletedKey) as? Bool
        if shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: isFirstLaunch, onboardingCompletedStored: storedCompleted) {
            UserDefaults.standard.set(true, forKey: ActivitySettings.onboardingCompletedKey)
        }
        let shouldShow = shouldShowOnboarding(isFirstLaunch: isFirstLaunch, onboardingCompletedStored: storedCompleted)
        if shouldShow {
            onboardingStep = .welcome
            isOnboardingActive = true
        }

        // Phase 16 / D-02 — constructed here (not at declaration) so the [weak self]-capturing
        // closures bind a fully-initialised self, mirroring powerMonitor/nowPlayingMonitor's
        // own start()-time construction.
        deviceCoordinator = DeviceCoordinator(
            queueHead: { [weak self] in self?.transientQueue.head },
            enqueue: { [weak self] t in
                // Phase 38 / HUD-05 (D-08): a Device transient must PREEMPT a standing Focus head
                // exactly like handlePower(_:)'s charging branch above.
                guard let self else { return false }
                if case .focus = self.transientQueue.head { return self.transientQueue.preempt(t) }
                return self.transientQueue.enqueue(t)
            },
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

        // Phase 24 / SHELF-01 / SHELF-02 — arm the production DragApproachDetector monitors.
        // Always-on for the controller's whole lifetime (not session-scoped like
        // dragReleaseMonitor), mirroring mouseMonitor's own shape exactly.
        dragApproachMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.handleDragApproachTick()
        }
        dragEndMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.handleDragApproachEnd()
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
        if activityEnabled(ActivitySettings.deviceKey) && !isOnboardingActive { startBluetoothMonitor() }

        // Phase 38 / HUD-05 (D-02/D-04): auto-start ONLY if permission was already granted in a
        // prior session — this line never triggers a permission request itself (the request lives
        // in Plan 38-06's SettingsView code, at the moment the toggle is switched on).
        if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized { startFocusModeMonitor() }

        // Phase 41 / HUD-08 (D-03): default-ON toggle, no permission gate to check.
        if activityEnabled(ActivitySettings.calendarCountdownKey) { startCalendarCountdownMonitor() }

        // Phase 39 / HUD-03/HUD-04 (D-06): UNCONDITIONAL start — mirrors startOutfitRefresh()'s
        // own unconditional-start precedent below. Unlike every toggle-gated monitor above, OSD
        // detection is NOT gated behind an activityEnabled(...) check: the Volume/Brightness HUD
        // itself requires no toggle and no permission, only native-OSD suppression is opt-in
        // (read fresh inside the interceptor's own suppressionArmed closure).
        startOSDInterceptor()

        // Phase 14 / WEATHER-01 / CAL-01: start the outfit (weather + calendar) coarse-refresh
        // cycle. Unconditional — unlike the toggle-gated monitors above, this phase has no
        // Settings toggle of its own (out of scope for 14-04). Phase 26 / D-01: deferred while
        // onboarding is active — Location/Calendar are among the permission-triggering calls
        // this launch-time gate defers until the Permissions step (Plan 26-04) explicitly
        // grants them.
        if !isOnboardingActive { startOutfitRefresh() }

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
        // Safe to run synchronously here: this call already predates Phase 26 (Phase 6) and
        // its outcome for a non-onboarding launch is `.idle`/whatever the resolver computes
        // from already-quiescent state — it never raced SwiftUI's own launch-time update pass.
        renderPresentation()

        // Phase 26 / ONBOARD-01 (D-09) round-7 fix (on-device crash: "Publishing changes from
        // within view updates", trapped by Xcode's SwiftUI Runtime Issue breakpoint right at
        // this file's `panel.contentView = NSHostingView(...)` construction). Root cause:
        // `start()` runs synchronously inside `AppDelegate.applicationDidFinishLaunching`,
        // which itself fires WHILE SwiftUI's own App/Scene graph (IsletApp.swift's `body`)
        // is still mid-setup for launch -- mutating `@Published` state synchronously in
        // that window races SwiftUI's own in-flight update transaction. (Plan 27-04: the
        // Settings window IsletApp.swift originally referenced here was later replaced by
        // an AppKit-owned NSWindow in AppDelegate — see AppDelegate.showSettingsWindow() —
        // but this race is about the App struct's own Scene-graph setup in general, not
        // specifically that removed scene, so the fix below still applies.)
        // `interaction.phase = .expanded` was the ONE new mutation Phase
        // 26 added directly to this synchronous launch path (every other mutation here, like
        // `renderPresentation()` above, predates this phase and was never in this exact
        // reentrant position). Hopping to the next main run-loop turn is the standard,
        // understood fix for AppDelegate-triggered ObservableObject mutations racing SwiftUI's
        // App-lifecycle setup -- NOT a blind wrapper: it is scoped to exactly the two calls
        // that didn't exist before this phase, letting `applicationDidFinishLaunching` (and
        // SwiftUI's own launch-time transaction) fully return first. The onboarding CARD
        // itself is unaffected -- `renderPresentation()` above already set
        // `presentationState.presentation = .onboarding(.welcome)` synchronously, since the
        // resolver's onboarding-first precedence doesn't depend on `interaction.isExpanded`
        // at all; only the collapse-guard/click-through side effects that DO depend on
        // `interaction.isExpanded` are deferred by a single run-loop tick (imperceptible).
        if isOnboardingActive {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.interaction.phase = .expanded
                self.syncClickThrough()
            }
        }

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
    // shows everything. EXCEPTION: Phase 38-08 (CR-01 gap closure) — ActivitySettings.focusKey
    // defaults to FALSE, matching SettingsView.swift's `@AppStorage(ActivitySettings.focusKey)
    // private var focusEnabled = false` (the one activity toggle documented in
    // ActivitySettings.swift:19-22 to default OFF). Without this exception, a fresh/toggle-OFF
    // install with prior INFocusStatusCenter authorization would silently auto-start Focus
    // monitoring on relaunch.
    private func activityEnabled(_ key: String) -> Bool {
        let defaultValue = (key == ActivitySettings.focusKey) ? false : true
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
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

    // Phase 38 / HUD-05 — idempotent start, mirrors startPowerMonitor()'s exact shape.
    private func startFocusModeMonitor() {
        guard focusModeMonitor == nil else { return }
        let monitor = FocusModeMonitor { [weak self] isFocused in self?.handleFocusChange(isFocused) }
        focusModeMonitor = monitor
        monitor.start()
    }

    // Phase 41 / HUD-08 — idempotent start, mirrors startFocusModeMonitor()'s exact shape.
    private func startCalendarCountdownMonitor() {
        guard calendarCountdownMonitor == nil else { return }
        let monitor = CalendarCountdownMonitor(calendarService: calendarService) { [weak self] activity in
            self?.handleCalendarCountdownChange(activity)
        }
        calendarCountdownMonitor = monitor
        monitor.start()
    }

    // Phase 38-08 / HUD-05 gap closure (CR-02/WR-02): called by SettingsView's Focus
    // permission "Continue" button once FocusModeMonitor.requestAuthorization's completion
    // resolves `true` — the one event that previously had no path to actually start the
    // monitor. Re-runs the exact same start-gate handleSettingsChanged() already uses at
    // launch/UserDefaults-change, so a successful grant starts polling immediately without
    // requiring an undocumented toggle-off/on or app relaunch.
    func focusPermissionGranted() {
        handleSettingsChanged()
    }

    // Phase 39 / HUD-03/HUD-04 (D-06) — idempotent start, mirrors startFocusModeMonitor()'s
    // exact shape. Called UNCONDITIONALLY from start() (no activityEnabled gate) — see the
    // call site's own comment for why.
    private func startOSDInterceptor() {
        guard osdInterceptor == nil else { return }
        let interceptor = OSDInterceptor(
            suppressionArmed: { [weak self] in
                (self?.activityEnabled(ActivitySettings.osdSuppressionKey) ?? false)
                    && OSDInterceptor.isAccessibilityTrusted
            },
            onKeyPress: { [weak self] kind in self?.handleOSDKeyPress(kind) },
            brightnessReader: brightnessReader
        )
        osdInterceptor = interceptor
        interceptor.start()
    }

    // Phase 14 / WEATHER-01 / CAL-01 — idempotent start (mirrors startPowerMonitor/
    // startBluetoothMonitor's `guard ... == nil` convention): requests the device location
    // ONCE (D-01 — never re-requested on refresh, only cached in `lastLocation`), fetches
    // calendar immediately (no location dependency), then arms the 15-minute coarse refresh
    // (well under WeatherKit's 500k/month quota per RESEARCH.md).
    // Phase 26 / ONBOARD-01 — split out of startOutfitRefresh() so Plan 26-04's Permissions-row
    // Grant handler can call the location request independently, exactly like
    // startBluetoothMonitor()/refreshCalendar() already are.
    private func startLocationOnce() {
        locationProvider.requestOnce { [weak self] location in
            self?.lastLocation = location
            self?.refreshWeather()
            // Phase 33 / WEATHER-01 (D-01/D-02) — resolve the place name ONCE per location
            // fetch (mirrors this same one-shot discipline), not re-resolved on every 15-minute
            // refreshWeather() tick.
            if let location {
                self?.weatherService.resolvePlaceName(for: location) { [weak self] name in
                    self?.outfitState.locationName = name
                }
            }
            // Phase 26 / ONBOARD-02 (D-03) — reflect the real outcome for the Permissions row.
            // Harmless to set on every call, not just from onboarding — unread once inactive.
            self?.onboardingState.locationGranted = (location != nil)
        }
    }

    private func startOutfitRefresh() {
        guard outfitRefreshTimer == nil else { return }
        startLocationOnce()
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
        // Phase 33 / WEATHER-01/02: fetchCurrent was removed from WeatherService in favor of
        // the combined fetchCurrentAndForecast (Pitfall 1 — one call, not two). `weather`,
        // `forecast`, and `hourlyForecast` are written atomically from this SAME completion
        // callback — all populated unconditionally regardless of the Settings weatherStyle
        // choice; NotchPillView alone decides what to RENDER (weatherStyle gates rendering,
        // not fetching).
        weatherService.fetchCurrentAndForecast(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude) { [weak self] glance, forecast, hourly in
            self?.outfitState.weather = glance
            self?.outfitState.forecast = forecast
            self?.outfitState.hourlyForecast = hourly
        }
    }

    private func refreshCalendar() {
        calendarService.fetchUpcoming { [weak self] glance in
            self?.outfitState.calendar = glance
            // Phase 26 / ONBOARD-02 (D-03) — reflect the real outcome for the Permissions row.
            // Harmless to set on every call, not just from onboarding — unread once inactive.
            self?.onboardingState.calendarGranted = (glance != nil)
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
    private func currentPresentation() -> (presentation: IslandPresentation, secondary: SecondaryActivity?) {
        let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
        let np = npEnabled ? nowPlayingState.presentation : .none   // D-09 disabled NP → forced .none
        // Gap-closure fix (Finding 5): gate the health flag through the same npEnabled switch as
        // `np` above — a disabled Now Playing must be INVISIBLE to the resolver (forced neutral),
        // not silently degraded to "nicht verfügbar" from a stale `false` left over from before
        // the toggle.
        let healthy = nowPlayingHealthGate(enabled: npEnabled, isHealthy: nowPlayingState.isHealthy)
        let presentation = resolve(activeTransient: transientQueue.head,
                       nowPlaying: np,
                       nowPlayingHealthy: healthy,
                       hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch,
                       isExpanded: interaction.isExpanded,
                       selectedView: viewSwitcherState.selectedView,
                       onboardingStep: onboardingStep,
                       pendingDrop: pendingDrop,
                       calendarCountdown: calendarCountdownActivity)
        // Phase 42 / DUAL-01 — the SAME launch-gated `np` resolve()'s own ambient branch applies
        // internally (D-01/NOW-04) is applied here too, so a track that hasn't launch-gated
        // through never populates the secondary bubble either (42-RESEARCH.md Pitfall 1: never
        // two independent computations of the same live facts).
        let gatedNp = nowPlayingLaunchGate(hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch, nowPlaying: np)
        let secondary = resolveSecondary(primary: presentation, nowPlaying: gatedNp)
        return (presentation, secondary)
    }

    // Write the resolver's verdict to the @Published carrier the view observes. The CALLER owns
    // the spring wrapper (so the morph is attached AT the originating mutation, D-08) — this just
    // assigns `presentation` immediately, inheriting whatever animation context the caller
    // already established. `secondary` follows D-11's 3-way rule: (a) nil → cancel any pending
    // stagger, clear immediately, same animation context, no stagger on the way out; (b) fresh
    // nil→non-nil transition → stagger the reveal ~150ms behind the primary pill via its own
    // DispatchWorkItem (mirrors scheduleActivityDismiss's cancel-then-schedule shape); (c) a
    // content update while already non-nil (e.g. track change with both still live) → assign
    // directly in the caller's own animation context, no stagger.
    private func renderPresentation() {
        let next = currentPresentation()
        presentationState.presentation = next.presentation
        if next.secondary == nil {
            secondaryRevealWorkItem?.cancel()
            presentationState.secondary = nil
        } else if presentationState.secondary == nil {
            secondaryRevealWorkItem?.cancel()
            let value = next.secondary
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                    self.presentationState.secondary = value
                }
            }
            secondaryRevealWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.secondaryStaggerDelay, execute: work)
        } else {
            presentationState.secondary = next.secondary
        }
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
            dragLandingMaxY = nil
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
        #if DEBUG
        debugLastCollapsedFrame = collapsedFrame   // 39-07 gap closure ROUND 9 — see stored property doc comment
        #endif

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
        // conditionally, exactly matching the panel's reserved height. This is intentional and
        // PERMANENT (not a temporary state to later condition) — the CR-01 click-through
        // regression this unconditional reservation caused is fixed separately, by scoping the
        // hit-test in syncClickThrough()/visibleContentZone() to the actual visible blob rect,
        // NOT by resizing the panel. See visibleContentZone() below.
        // Phase 28 / CALVIEW-01 — the switcher row is reserved in this UNION exactly like
        // shelfRowHeight was added in Phase 20: unconditionally, so the panel never needs a
        // live resize when the switcher row first appears (the visible black shape still only
        // grows into it conditionally, per NotchPillView.body's own frame math).
        // 28-04 round 5 — reserves `NotchPillView.switcherContentHeight` (the ONE shared
        // content-box height every switcher-row presentation now uses — see that constant's
        // doc comment) instead of the old `expandedSize.height`, so this single union member
        // covers Home/Tray/Calendar/Weather/NowPlaying uniformly. The separate `calendarFrame`
        // union member from rounds 1-4 is gone: a calendar-only reservation is no longer taller
        // than every other switcher-row presentation's own (now-shared) reservation.
        // SHAPE-01 (v1.5, Phase 29) — the flare is just a larger `topCornerRadius` at the outer
        // top corners (NotchPillView.swift's blobShape()/wingsShape() call sites), which stays
        // entirely within each presentation's own rect (no overflow past expandedSize.width/
        // wingsSize.width), so this panel-frame reservation needs no extra margin.
        let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                               expandedSize: CGSize(width: expandedSize.width,
                                                                     height: NotchPillView.switcherContentHeight + NotchPillView.shelfRowHeight + NotchPillView.switcherRowHeight))

        // CHG-01 / Pattern 4: the wings extend SIDEWAYS, so the panel must also cover the
        // flat wings strip. Size the panel ONCE to the UNION of the downward-expanded and the
        // sideways-wings frames so BOTH the Phase-2 expand AND the Phase-3 wings fit without
        // any runtime panel resize (resizing mid-activity would race the morph + hot-zone math).
        let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
        // Phase 26 / ONBOARD-01/02 — the panel is sized once, up front, to the union of every
        // possible content size (mirrors how `wings` was added as a second union member in
        // Phase 3) so the onboarding card's real 240pt height is never resized mid-activity.
        let onboardingFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: NotchPillView.onboardingSize)
        // Phase 32 / TRAY-05 (RESEARCH.md Pitfall 2) — the panel must reserve space for the
        // widened Tray content up front too, mirroring onboardingFrame's precedent exactly.
        // Without this, the 650pt SwiftUI content clips to the old ~420pt panel edge on the
        // real screen (invisible in Xcode Previews, which render NotchPillView standalone with
        // no panel constraint).
        let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                           expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                                 height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
        // Phase 33 / WEATHER-01/02 (D-03/D-04/D-10, geometry three-site rule) — the panel must
        // reserve space for the Weather card up front too, mirroring trayFrame/onboardingFrame's
        // precedent exactly. Included UNCONDITIONALLY (same static-upper-bound approach trayFrame
        // already uses) — this is a reservation-only union member; NotchPillView's blobShape
        // `height:` override alone decides whether the VISIBLE shape actually grows into it.
        // Reserves weatherLargeContentHeight (the taller of the two tiers): a single static
        // upper-bound reservation still suffices because Large's content strictly contains
        // Medium's, so no second entry is needed here for Medium (D-10) — the two-tier
        // distinction is enforced at blobShape's height ternary and visibleContentZone's
        // branch below, both of which must agree with this reservation.
        let weatherExpandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                                       expandedSize: CGSize(width: expandedSize.width,
                                                                             height: NotchPillView.weatherLargeContentHeight + NotchPillView.switcherRowHeight))
        // Phase 34 / TRAY-02 (geometry three-site rule) — reserve space for the Quick Action
        // picker up front too, mirroring trayFrame/weatherExpandedFrame's precedent exactly. NO
        // switcherRowHeight addend — the picker is a full-takeover blob that never shows the
        // switcher row (D-01).
        let quickActionPickerFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                                         expandedSize: CGSize(width: expandedSize.width,
                                                                               height: NotchPillView.quickActionPickerContentHeight))
        // Phase 34 (UAT revision, Pattern 3) — the 3 destination buttons' live global frames,
        // computed once per positionAndShow() alongside quickActionPickerFrame itself.
        quickActionButtonFrames = computeQuickActionButtonFrames(card: quickActionPickerFrame)
        let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame).union(weatherExpandedFrame).union(quickActionPickerFrame)

        // The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
        hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
        // While expanded, the WHOLE expanded island (the panel union, padded) keeps it open so
        // the pointer can reach the transport controls without tripping the grace-collapse.
        expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
        dragLandingMaxY = target.frame.maxY - dragLandingMargin

        let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
        if self.panel == nil {
            // Phase 27 / VISUAL-03 — host the view with the persisted theme (3 per-element
            // accents + material style) injected on the Environment. The view observes
            // presentationState (the resolver's verdict) for the single-arbiter render.
            let theme = currentTheme()
            appliedTheme = theme
            panel.contentView = NSHostingView(rootView: makeRootView(theme: theme))
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

    // Phase 24 / SHELF-01 / SHELF-02 — every .leftMouseDragged tick during a real OS drag
    // session. Tracks a genuine pasteboard content change (Pattern 1/Pitfall 2 — an ordinary
    // window-move/text-select drag never touches NSPasteboard(name: .drag)) purely to keep
    // dragPasteboardChangeCount current; geometry is polled UNCONDITIONALLY on every tick
    // (there is no draggingUpdated equivalent for a global monitor, Pattern 2).
    private func handleDragApproachTick() {
        let pasteboard = NSPasteboard(name: .drag)
        let count = pasteboard.changeCount
        if count != dragPasteboardChangeCount {
            dragPasteboardChangeCount = count
        }
        recheckDragAcceptRegion()
        // Phase 34 UAT revision (D-11/Pitfall 8) — live per-button hover hit-test while a picker
        // is showing, published ONLY on change (never unconditionally every tick — dozens of
        // ticks/second during a real drag would otherwise re-render the picker for no visual
        // change).
        if pendingDrop != nil {
            let hit = quickActionButtonFrames.firstIndex { $0.contains(NSEvent.mouseLocation) }
            if hit != presentationState.hoveredQuickActionButtonIndex {
                presentationState.hoveredQuickActionButtonIndex = hit
            }
        } else if presentationState.hoveredQuickActionButtonIndex != nil {
            presentationState.hoveredQuickActionButtonIndex = nil
        }
    }

    // Edge-tracks isDragApproaching exactly like pointerInZone's shape in handlePointer(at:).
    // Entering the accept region auto-expands the island via the existing pure .dragEntered
    // transition (D-04); leaving it again is a silent no-op — the normal grace-collapse timer
    // resumes on its own.
    //
    // Bugfix (Task 3 on-device UAT, round 2): the collapsed-origin gate (D-09 — only allow
    // ARMING while still collapsed) must NOT also gate the exit/sustain check. Auto-expand sets
    // interaction.isExpanded = true as its own side effect, so if `!interaction.isExpanded`
    // were part of the exit condition, the very NEXT .leftMouseDragged tick after arming would
    // read as "outside" regardless of pointer position and immediately disarm
    // isDragApproaching — leaving handleDragApproachEnd()'s guard to bail out on every real
    // drop. `!interaction.isExpanded` therefore appears ONLY in the rising-edge arm condition
    // below; the exit condition depends purely on geometry.
    private func recheckDragAcceptRegion() {
        let point = NSEvent.mouseLocation
        let geometryInside = isWithinDragAcceptRegion(point, zone: expandedZone, maxY: dragLandingMaxY)
        if geometryInside && !isDragApproaching && !interaction.isExpanded {
            isDragApproaching = true
            graceWorkItem?.cancel()
            graceWorkItem = nil
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                interaction.phase = nextState(interaction.phase, .dragEntered)
                // Phase 34 UAT revision (D-10) — populate pendingDrop HERE, same edge as the
                // auto-expand, not at release (handleDragApproachEnd). The session-copy MECHANISM
                // itself is UNCHANGED (ShelfFileStore.makeSessionCopy) — only the call-site moved,
                // so the picker's first-ever render already reflects the populated pendingDrop.
                let urls = fileURLs(from: NSPasteboard(name: .drag))
                if !urls.isEmpty {
                    var items: [ShelfItem] = []
                    for url in urls {
                        let id = UUID()
                        guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
                        items.append(ShelfItem(id: id, originalURL: url, localURL: localURL, filename: url.lastPathComponent, addedAt: Date()))
                    }
                    if !items.isEmpty { pendingDrop = PendingDrop(items: items) }
                }
                renderPresentation()
            }
            // Phase 24 / SHELF-01 / SHELF-02 (D-10/D-11) — lazily construct the drop-interception
            // tap on the FIRST real drag-approach edge, not at app launch. Idempotent start() is
            // safe to call on every subsequent edge too.
            if dropInterceptTap == nil {
                dropInterceptTap = DropInterceptTap(
                    shouldSwallow: { [weak self] in self?.isDragApproaching ?? false },
                    onIntercept: { [weak self] in self?.handleDragApproachEnd() }
                )
            }
            dropInterceptTap?.start()
        } else if !geometryInside && isDragApproaching {
            isDragApproaching = false
            // Phase 34 UAT revision (D-13b, Pitfall 6) — MUST discard pendingDrop here too now
            // that its lifetime starts at dragEntered instead of release: without this, dragging
            // back out before releasing leaves pendingDrop set (the picker never disappears) and
            // re-entering overwrites it, leaking the first session-copied temp file on disk.
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                discardPendingDrop()
                renderPresentation()
            }
        }
    }

    // Phase 24 / SHELF-01 / SHELF-02 — every .leftMouseUp, real drag-drop or ordinary click
    // alike. The guard makes an ordinary click (which fires .leftMouseUp constantly) a
    // harmless idempotent no-op, and unconditionally clearing the flag next means a
    // geometrically-ambiguous Escape-cancel can never leave the island stuck expanded (T-24-04).
    private func handleDragApproachEnd() {
        guard isDragApproaching else { return }
        isDragApproaching = false

        // Phase 34 UAT revision (D-12/D-13) — a picker is already showing (pendingDrop was set
        // at dragEntered, Task 1). Route by WHICH button the release point falls in; the
        // handlers themselves are the SAME unchanged handleQuickActionDrop/AirDrop/Mail. Once
        // D-10 always populates pendingDrop at dragEntered for any real file drag, a release with
        // pendingDrop == nil is correctly a no-op by construction (a non-file drag, or an
        // already-discarded pending drop) — no release-time item-building fallback is reintroduced
        // here (34-RESEARCH.md Open Question 2).
        let point = NSEvent.mouseLocation
        if pendingDrop != nil {
            if let hit = quickActionButtonFrames.firstIndex(where: { $0.contains(point) }) {
                switch hit {
                case 0: handleQuickActionDrop()
                case 1: handleQuickActionAirDrop()
                case 2: handleQuickActionMail()
                default: break
                }
            } else {
                // D-13: released inside the picker card but not on a button — discard.
                withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                    discardPendingDrop()
                    renderPresentation()
                }
            }
            presentationState.hoveredQuickActionButtonIndex = nil
        }
        // Pitfall 3 — pointerInZone/lastPointerLocation/syncClickThrough() go stale during ANY
        // OS drag session; re-sync unconditionally, mirroring endShelfItemDrag()'s own final line.
        handlePointer(at: NSEvent.mouseLocation)
    }

    // MARK: - Phase 34 / TRAY-02/03/04 — Quick Action Destination Picker handlers

    // TRAY-03 — "Drop": stage the pending item(s) into the shelf exactly as the old
    // unconditional-stage path did, switch the active view to Tray, and close the picker.
    // Mirrors handleSwitcherSelect's own closing withAnimation/syncClickThrough sequence.
    private func handleQuickActionDrop() {
        for item in pendingDrop?.items ?? [] {
            shelfCoordinator.append(item)
        }
        resyncShelfViewState()
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            viewSwitcherState.selectedView = .tray
            pendingDrop = nil
            renderPresentation()
        }
        syncClickThrough()
    }

    // Shared close-out for the AirDrop/Mail paths (T-34-08): these items were NEVER handed to
    // shelfCoordinator, so nothing else will ever clean up their session-temp copies — this is
    // the ONE place that does, whether the share succeeded or failed (QuickActionSharingService
    // calls onFinish either way).
    private func finishQuickActionSharing() {
        for item in pendingDrop?.items ?? [] {
            ShelfFileStore.deleteSessionCopy(at: item.localURL)
        }
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            pendingDrop = nil
            renderPresentation()
        }
    }

    // TRAY-04 — "AirDrop": hand the pending item(s) to the isolated NSSharingService seam.
    // No window-activation code anywhere in this call chain (D-08).
    private func handleQuickActionAirDrop() {
        guard let pendingDrop else { return }
        quickActionSharingService.share(pendingDrop.items.map { $0.localURL }, via: .sendViaAirDrop) { [weak self] in
            self?.finishQuickActionSharing()
        }
    }

    // TRAY-04 — "Mail": identical shape to AirDrop, composeEmail destination.
    private func handleQuickActionMail() {
        guard let pendingDrop else { return }
        quickActionSharingService.share(pendingDrop.items.map { $0.localURL }, via: .composeEmail) { [weak self] in
            self?.finishQuickActionSharing()
        }
    }

    // D-06/D-07 — dismissing the picker WITHOUT choosing a destination discards the pending
    // file(s): no silent auto-default to Drop, no orphaned session-temp file. Wired into BOTH
    // dismiss paths (handleHoverExit's grace-elapsed collapse, handleClick's toggle-shut) below.
    private func discardPendingDrop() {
        guard pendingDrop != nil else { return }
        for item in pendingDrop?.items ?? [] {
            ShelfFileStore.deleteSessionCopy(at: item.localURL)
        }
        pendingDrop = nil
    }

    // Pattern 1: every .mouseMoved tick hit-tests the GLOBAL pointer against the hot-zone.
    // No coordinate conversion — both `point` and `hotZone` are global bottom-left (Pitfall 6).
    private func handlePointer(at point: CGPoint) {
        // CR-01 — stash the raw pointer location for syncClickThrough()/visibleContentZone(),
        // which need it but receive no point parameter themselves.
        lastPointerLocation = point

        // While expanded, the keep-open region is the full expanded island so the pointer can
        // travel down to the transport controls without reading as a hot-zone exit (which would
        // collapse the island after the grace delay). Collapsed/hovering use the small pill zone.
        let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : collapsedInteractiveZone()
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

        // CR-01 — visibleContentZone()'s boundary (toggled by the shelf's item count) sits
        // INSIDE expandedZone and is never itself crossed by the enter/exit edge detection
        // above, so re-scope the click-through hit-test on every raw pointer tick while
        // expanded, not just at the coarser expandedZone enter/exit edges.
        if interaction.isExpanded {
            syncClickThrough()
        }
    }

    // Phase 42 / DUAL-01 (T-42-07) — 42-02's on-device spike confirmed "passes through": the
    // plain `hotZone` (sized to the small collapsed pill) does NOT cover wing-tier-adjacent
    // content, the same mechanism as the Phase 40-03 badge-tap regression. Returns `hotZone`
    // UNCHANGED for every case except when a secondary bubble is actually showing, in which case
    // it widens the TRAILING (right) edge out to cover the bubble's own real screen position —
    // bounded to an exact, code-reviewed constant tied 1:1 to 42-03's shipped `.offset(x: 220)`
    // bubble-center positioning (never an open-ended region, T-42-07).
    private func collapsedInteractiveZone() -> CGRect? {
        guard let hotZone else { return nil }
        guard presentationState.secondary != nil else { return hotZone }
        let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
        let bubbleFarEdge = collapsedFrame.midX + 220
            + NotchPillView.secondaryBubbleDiameter / 2 + hotZonePadding
        guard bubbleFarEdge > hotZone.maxX else { return hotZone }
        return CGRect(x: hotZone.minX, y: hotZone.minY,
                      width: bubbleFarEdge - hotZone.minX, height: hotZone.height)
    }

    // CR-01 — the actual VISIBLE-content rect, narrower than expandedZone (which is the
    // padded static panel union, used only for the keep-open grace decision).
    // Quick task 260714-3k6 (anticipates ROADMAP Phase 31 / TRAY-01) — the shelf-band
    // reservation this used to mirror (NotchPillView.blobShape's `hasShelf ? shelfRowHeight :
    // 0` conditional) is gone: the shelf strip no longer renders under any non-Tray
    // presentation (NotchPillView.shelfStripVisible is always false there), so there is no
    // shelf-height term left to mirror for the click-through math. nil if the panel hasn't
    // been shown yet.
    private func visibleContentZone() -> CGRect? {
        guard let hotZone else { return nil }
        let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
        let switcherRowShowing = showsSwitcherRow(for: presentationState.presentation)
        let switcherHeight = switcherRowShowing ? NotchPillView.switcherRowHeight : 0
        // Phase 26 / ONBOARD-01/02 — the onboarding card renders at its own taller fixed size
        // (onboardingSize vs. the 144pt expandedSize), independent of shelf state (onboarding's
        // shelf is always empty, D-06). Scoping this branch to ONLY the geometry
        // visibleContentZone() measures keeps syncClickThrough()'s own interactive-value logic
        // untouched (CR-01 discipline — see 26-PATTERNS.md).
        // 28-04 round 5 — every switcher-row-showing presentation (Home/Tray/Calendar/Weather/
        // NowPlaying) now shares ONE content height (`NotchPillView.switcherContentHeight`),
        // reusing the SAME `switcherRowShowing` boolean already computed above — the old
        // `isCalendarActive`-only branch from rounds 1-4 is gone.
        // Phase 32 / TRAY-05 (RESEARCH.md Pitfall 3, CR-01 discipline) — a third branch for
        // .trayExpanded, checked ahead of the default case (same ordering as isOnboardingActive
        // above). No new stored `isTrayActive` bool: unlike onboarding (a forced multi-step flow
        // tracked outside the resolver), presentationState.presentation already carries this
        // directly. Must land in the same commit as Task 1's blobShape/positionAndShow changes —
        // a size change here that isn't mirrored breaks click-through.
        let contentSize: CGSize
        if isOnboardingActive {
            contentSize = NotchPillView.onboardingSize
        } else if case .trayExpanded = presentationState.presentation {
            contentSize = CGSize(width: NotchPillView.traySize.width,
                                 height: NotchPillView.trayContentHeight + switcherHeight)
        } else if case .weatherExpanded = presentationState.presentation {
            // Phase 33 / WEATHER-01/02 (geometry three-site rule) — must mirror NotchPillView's
            // blobShape `height:` override and positionAndShow's weatherExpandedFrame exactly,
            // or the CR-01/WR-02 click-swallowing/dead-zone regression class comes back (see
            // this function's own doc comment on Pitfall 3). The branch is now UNCONDITIONAL
            // (D-03 — Medium is always the floor, no more boolean gate); `UserDefaults.standard.
            // string(forKey:)` is read directly here (NOT `activityEnabled(_:)`, which defaults
            // an absent key to true) — a corrupted/absent weatherStyleKey falls back to `.medium`,
            // exactly like NotchPillView's own @AppStorage default.
            let style = ActivitySettings.WeatherStyle(rawValue: UserDefaults.standard.string(forKey: ActivitySettings.weatherStyleKey) ?? "") ?? .medium
            contentSize = CGSize(width: expandedSize.width,
                                 height: (style == .large ? NotchPillView.weatherLargeContentHeight : NotchPillView.weatherMediumContentHeight) + switcherHeight)
        } else if case .quickActionPicker = presentationState.presentation {
            // Phase 34 / TRAY-02 (CR-01 geometry three-site rule) — must mirror
            // positionAndShow's quickActionPickerFrame reservation and NotchPillView's
            // quickActionPickerView height exactly, or the click-swallowing/dead-zone
            // regression class comes back. No switcherHeight addend (D-01 full-takeover,
            // no switcher row).
            contentSize = CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight)
        } else if case .calendarExpanded = presentationState.presentation {
            // Quick task 260715-vsd (geometry three-site rule) — must mirror
            // calendarFullView's new `blobShape(width: NotchPillView.calendarWidth)` override,
            // or the CR-01 click-swallowing/dead-zone regression class comes back.
            contentSize = CGSize(width: NotchPillView.calendarWidth,
                                 height: NotchPillView.switcherContentHeight + switcherHeight)
        } else {
            contentSize = CGSize(width: expandedSize.width,
                                 height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
        }
        let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: contentSize)
        return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
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

    // WR-02 (Pitfall 3 / D-07): the SINGLE place that decides `ignoresMouseEvents`. While
    // collapsed/hovering, the window swallows clicks iff the pointer is in the hot-zone; while
    // expanded, see the CR-01 note below. Centralising this means no transition can leave the
    // flag stale — previously only the grace work item restored `true`, so a toggle-shut click
    // followed by a pointer-exit (which schedules no grace timer) left the collapsed/idle window
    // swallowing clicks over the notch band until the next hover cycle. Called after EVERY
    // phase/pointer mutation (enter, grace-elapsed, click). The panel stays `.nonactivatingPanel`
    // + never-key (D-04); `ignoresMouseEvents` is the ONLY flag toggled at runtime.
    // CR-01: while expanded, the panel is STATICALLY sized to the max shelf reservation
    // (positionAndShow, unchanged) — interactivity requires the pointer to sit inside
    // visibleContentZone() (the actual visible blob rect), independent of the broader
    // pointerInZone/expandedZone keep-open tracking. Without this, the reserved-but-invisible
    // shelf band (56pt, empty by default) silently swallowed clicks meant for the app underneath
    // the notch.
    private func syncClickThrough() {
        let interactive: Bool
        if interaction.isExpanded {
            // CR-01 fix-2: `pointerInZone` tracks the BROAD `expandedZone` (padded panel union,
            // used only for the keep-open grace decision) — it stays true for the whole time the
            // pointer sits anywhere in that zone, including over the invisible reserved shelf
            // band. ORing it in here defeated visibleContentZone()'s narrowing entirely. Only
            // visibleContentZone() (the actual visible blob rect) may grant interactivity while
            // expanded.
            interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
        } else {
            interactive = pointerInZone
        }
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
            // Phase 21 / SHELF-06 / D-03 — defer the collapse while a shelf-item drag is in
            // flight; endShelfItemDrag() re-invokes handleHoverExit() once the drag ends.
            guard !self.isDraggingShelfItem else { return }
            // Phase 26 / ONBOARD-01 (D-09) — a forced onboarding session must never grace-collapse.
            guard !self.isOnboardingActive else { return }
            // Only collapse if the pointer is STILL outside (re-entry would have cancelled).
            withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
                self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
                // Phase 6: a grace-collapse from .expanded flips `isExpanded` false — re-resolve
                // inside the spring so an expanded-media island morphs back to the ambient glance.
                self.renderPresentation()
                // Phase 34 / TRAY-02 (D-06/D-07) — a grace-collapse while a picker is showing is
                // a dismiss-without-choosing: discard the pending file(s), no silent auto-stage.
                if !self.interaction.isExpanded { self.discardPendingDrop() }
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
        // Phase 26 / ONBOARD-01 (D-09) — a stray tap on the onboarding card's background (which
        // still bubbles up to blobShape's ancestor .onTapGesture) is a no-op during onboarding;
        // the Next/Back/Grant/Finish buttons are real SwiftUI Buttons that already intercept
        // their own taps before this ancestor gesture fires.
        guard !isOnboardingActive else { return }
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
            // Phase 21 follow-up (UAT feedback) — an item whose backing file was deleted
            // externally is otherwise stuck inert until manually trashed. Pruned right as
            // the shelf becomes visible so the user never sees a dead item, not just after
            // a failed drag attempt.
            if !wasExpanded && interaction.isExpanded && !shelfCoordinator.pruneMissingFiles().isEmpty {
                resyncShelfViewState()
            }
            // Phase 6: expand/collapse flips `isExpanded`, a resolver input — re-resolve inside
            // the SAME spring so the island morphs between the wings/expanded presentation cases.
            renderPresentation()
            // Phase 34 / TRAY-02 (D-06/D-07) — a toggle-shut click while a picker is showing is
            // a dismiss-without-choosing: discard the pending file(s), no silent auto-stage.
            if !interaction.isExpanded { discardPendingDrop() }
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

    // Phase 42 / DUAL-01 (D-12, SUPERSEDED 2026-07-19 — live user decision during Plan 42-04
    // Task 3's on-device UAT) — this used to expand to the Now-Playing/Home media view (D-12).
    // No caller besides `makeRootView`'s `onSecondaryTap` wiring exists, so it's repurposed here
    // rather than adding a second closure: tapping the bubble now toggles play/pause directly via
    // the SAME `nowPlayingMonitor.togglePlayPause()` the transport row's play/pause button already
    // calls (see `onTogglePlayPause` in `makeRootView`) — no expand, no view-switch.
    private func handleSecondaryTap() {
        nowPlayingMonitor?.togglePlayPause()
    }

    // Phase 28 / CALVIEW-01/02/04 — routes through the SAME `calendarService` property
    // refreshCalendar() already uses (never a second EventKitService instance, CALVIEW-04's
    // single-EKEventStore structural check).
    private func refreshCalendarMonth() {
        calendarService.fetchMonth(containing: calendarViewState.visibleMonth) { [weak self] events in
            self?.calendarViewState.monthEvents = events
        }
    }

    // Phase 28 / CALVIEW-01 — wired from NotchPillView's switcher pill taps. 28-04 round 5:
    // Tray became its OWN resolver case (`.trayExpanded`, IslandResolver.swift), replacing the
    // earlier "force-reveal the additive shelf strip under Home" reconciliation — the
    // `ShelfViewState.forcedByTray` flag this used to set is gone (dead once Tray got a real
    // resolver case: selecting Tray now always resolves to `.trayExpanded`, so no OTHER
    // presentation's additive shelf strip could ever observe a `forcedByTray` flag anyway).
    // Phase 24's auto-reveal-on-drop is untouched — it still reads purely off
    // `ShelfViewState.isVisible`'s `!items.isEmpty` half. Pitfall 4 resets the calendar to
    // today/this-month on every Calendar selection so a stale prior month never flashes (D-07:
    // today selected by default on open).
    private func handleSwitcherSelect(_ view: SelectedView) {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            viewSwitcherState.selectedView = view
            if view == .calendar {
                calendarViewState.selectedDay = Date()
                calendarViewState.visibleMonth = Date()
                calendarViewState.monthEvents = nil
            }
            renderPresentation()
        }
        syncClickThrough()
        if view == .calendar {
            refreshCalendarMonth()
        }
    }

    // Phase 28 / CALVIEW-01 (D-08) — prev/next month navigation. Clears monthEvents before the
    // fetch settles (Pitfall 4 — avoids showing the OLD month's events under the NEW month's
    // grid for one frame); guards against a nil Calendar.date(byAdding:) result rather than
    // crashing on a calendar-arithmetic edge case.
    private func handleCalendarMonthChange(_ delta: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: calendarViewState.visibleMonth) else { return }
        calendarViewState.visibleMonth = newMonth
        // CR-02 fix (28-REVIEW.md) — `selectedDay` must stay inside the newly-visible month.
        // Left untouched, a stale selectedDay from before navigating (typically "today", seeded
        // when Calendar opened) silently outlived the month change; handleQuickAdd(_:title:)
        // unconditionally reads selectedDay, so quick-add could create an event/reminder on a
        // day in a different, no-longer-displayed month with zero error or confirmation.
        if !Calendar.current.isDate(calendarViewState.selectedDay, equalTo: newMonth, toGranularity: .month) {
            calendarViewState.selectedDay = newMonth   // keep selection inside the visible month
        }
        calendarViewState.monthEvents = nil
        refreshCalendarMonth()
    }

    // Phase 28 / CALVIEW-01 — day selection only changes which day's events render; no
    // shape/size change, so no spring animation is needed.
    private func handleCalendarDaySelect(_ day: Date) {
        calendarViewState.selectedDay = day
    }

    // Phase 28 / CALVIEW-03 — quick-add for both Event and Reminder, routed through the SAME
    // shared CalendarService (CALVIEW-04). Event defaults to a 1-hour duration starting at the
    // selected day (no time picker exists per the UI-SPEC's Copywriting Contract) and refreshes
    // the month afterward so it appears in the day list immediately; Reminder has no rendering
    // surface in this phase (CALVIEW-03 is create-only for reminders), so no refresh is needed.
    private func handleQuickAdd(_ kind: QuickAddKind, title: String) {
        let day = calendarViewState.selectedDay
        switch kind {
        case .event:
            calendarService.createEvent(title: title, start: day, end: day.addingTimeInterval(3600)) { [weak self] _ in
                self?.refreshCalendarMonth()
            }
        case .reminder:
            calendarService.createReminder(title: title, dueDate: day) { _ in }
        }
    }

    // MARK: - Phase 26 / ONBOARD-01/02/03 — onboarding session handlers

    // ONBOARD-01 (D-09) — the ONLY path Next/Back use. Mirrors handleClick's own
    // withAnimation(...) { mutate; renderPresentation() } shape.
    private func advanceOnboarding(_ event: OnboardingEvent) {
        guard let step = onboardingStep else { return }
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            onboardingStep = nextOnboardingStep(step, event)
            renderPresentation()
        }
    }

    // ONBOARD-02 (D-02/D-03) — each row's Grant calls the SAME existing permission-request
    // function every other feature already uses (never a second/duplicate request call); the
    // outcome is read into onboardingState by that function's own completion closure.
    private func grantOnboardingPermission(_ permission: OnboardingPermission) {
        switch permission {
        case .bluetooth:
            startBluetoothMonitor()
            // IOBluetoothDevice.register has no completion callback, so a one-shot delayed
            // status read is the pragmatic, minimal way to reflect the real TCC outcome
            // without hand-rolling a new permission API (T-26-06, accepted: worst case the
            // row briefly shows a stale/neutral state for ~1s, purely cosmetic).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.onboardingState.bluetoothGranted = (CBManager.authorization == .allowedAlways)
            }
        case .calendar:
            refreshCalendar()
        case .location:
            startLocationOnce()
        }
    }

    // D-05 — the onboarding carousel's license-key/Buy hop, duplicating AppDelegate's own
    // 3-line openSettings() body since NotchWindowController has no reference to AppDelegate.
    private func openOnboardingSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openIsletSettings, object: nil)
        NSApp.windows.first { $0.identifier?.rawValue == "settings" }?.makeKeyAndOrderFront(nil)
    }

    // ONBOARD-01/03 (D-08/D-09) — persists completion, collapses the island back to normal
    // idle, and starts whatever start(isFirstLaunch:) deferred while onboarding was active
    // (startBluetoothMonitor()/startOutfitRefresh() are both idempotent, safe even if a
    // permission was already granted mid-onboarding).
    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: ActivitySettings.onboardingCompletedKey)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            isOnboardingActive = false
            onboardingStep = nil
            interaction.phase = nextState(interaction.phase, .clicked)
            renderPresentation()
        }
        updateVisibility()
        syncClickThrough()
        if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }
        startOutfitRefresh()
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
            // 36-01 on-device UAT round 2 previously added a 0.6s settle re-poll here, guessing
            // `kIOPSIsChargingKey` just needed a beat to settle after physical connect. Round 3's
            // on-device trace disproved that: the flag stayed false for the ENTIRE session
            // (Optimized Battery Charging, not a transient race — see PowerActivity.swift). Since
            // the classification no longer reads `isCharging` at all (it keys off `isOnAC` +
            // `isCharged`, both of which flip immediately and reliably on physical connect), the
            // settle re-poll has no remaining purpose and is removed — classify and enqueue
            // directly, same as every other transition.
            //
            // Phase 6 / D-02 rank 1: ENQUEUE the charging transient instead of setting the model
            // directly as the render driver. If it becomes the head NOW, re-resolve (inside the
            // spring, D-08) → render + the SINGLE updateVisibility() (fullscreen gate) + arm the
            // ~3s one-shot dismiss that advances the queue. If a transient already stands it is
            // enqueued behind it (D-03 sequential) and plays when the head's ~3s elapses.
            chargingState.activity = activity   // keep the model in sync (the % tick mutates it)
            // Phase 38 / HUD-05 (D-08): a standing Focus head never self-elapses (isPersistent),
            // so Charging must PREEMPT it immediately rather than queue behind it indefinitely.
            // Every other head shape (nil, .charging, .device) behaves exactly like plain enqueue.
            let changed: Bool
            if case .focus = transientQueue.head {
                changed = transientQueue.preempt(.charging(activity))
            } else {
                changed = transientQueue.enqueue(.charging(activity))
            }
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

    // Phase 38 / HUD-05 — the live Focus/DND change lands here (already on main; the monitor's
    // callback hopped). Focus NEVER preempts (D-08 is one-directional, only Charging/Device
    // preempt Focus): a plain enqueue correctly becomes head immediately if nothing stands, or
    // correctly queues behind an already-standing Charging/Device head. Turning Focus off flushes
    // it silently (D-09), reusing the exact same removeAll(where:) mechanism the Charging/Device
    // disable-in-Settings path already uses.
    private func handleFocusChange(_ isFocused: Bool) {
        if isFocused {
            guard let activity = focusActivity(from: true) else { return }
            let changed = transientQueue.enqueue(.focus(activity))
            if changed {
                presentTransientChange()
            }
        } else {
            // 38-09 gap closure — mirrors handleSettingsChanged's render tail, flushTransients never renders itself
            flushTransients(.focus)
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                renderPresentation()
            }
            updateVisibility()
        }
    }

    // Phase 41 / HUD-08 — the live Calendar Countdown change lands here (already on main; the
    // monitor's callback hopped). This is the ENTIRE function body: it never touches
    // transientQueue.enqueue/preempt, flushTransients, or scheduleActivityDismiss (Pitfall 5 —
    // the countdown is ambient, not an ActiveTransient); it only mutates the plain stored
    // property currentPresentation() reads fresh on every call.
    private func handleCalendarCountdownChange(_ activity: CalendarCountdownActivity?) {
        calendarCountdownActivity = activity
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            renderPresentation()
        }
        updateVisibility()
    }

    // Phase 39 / HUD-03/HUD-04 — the live OSD key press lands here (already on main; the
    // interceptor's callback already hopped). Builds the OSDActivity from a fresh hardware
    // read, then branches on the CURRENT head:
    //   • a standing .osd head (D-09/D-12) — covers BOTH a same-activity scrub (Volume held
    //     down) AND a cross-activity Volume<->Brightness swap, since both are the SAME `.osd`
    //     category regardless of inner case: updateHead in place, spring-animate the render,
    //     then explicitly RE-ARM the dismiss timer (the one deliberate divergence from
    //     Charging's %-tick branch, which does NOT re-arm — a scrub must keep resetting the
    //     1.5s window for as long as the key keeps repeating).
    //   • no standing .osd head — mirrors the existing D-13 Focus-preemption shape exactly
    //     (handlePower's charging branch above): preempt a standing Focus head, else plain
    //     enqueue; presentTransientChange() already wraps the spring + arms the dismiss, so no
    //     separate re-arm is needed on this branch.
    private func handleOSDKeyPress(_ kind: OSDKeyKind) {
        #if DEBUG
        // 39-07 gap closure ROUND 5 timing instrumentation (temporary, remove once responsiveness
        // is confirmed fixed) — point (c) entry: this runs INSIDE OSDInterceptor's main.async
        // closure (via the onKeyPress capture), so comparing this timestamp to OSDInterceptor's own
        // point (b) logs shows the actual main-queue scheduling delay end-to-end.
        let debugEntry = CFAbsoluteTimeGetCurrent()
        print("[OSD-TIMING] c) handleOSDKeyPress entered t=\(String(format: "%.2f", debugEntry * 1000))ms kind=\(kind)")
        // ROUND 9 ground-truth geometry — the REAL physical notch frame (AppKit screen coords,
        // bottom-left origin, y-up) and the REAL panel window frame (same coordinate system),
        // logged at the exact moment a key press fires so they can be cross-referenced against
        // NotchPillView's own "[OSD-GEOM]" SwiftUI-side (.global, top-left/y-down, window-relative)
        // logs for the SAME press: screenX = panel.frame.origin.x + globalX (Y needs a manual
        // origin flip using panel.frame.height, done by hand from the printed values).
        if let f = debugLastCollapsedFrame {
            print("[OSD-GEOM] REAL notch frame (screen coords): x=\(String(format: "%.1f", f.minX)) y=\(String(format: "%.1f", f.minY)) w=\(String(format: "%.1f", f.width)) h=\(String(format: "%.1f", f.height))")
        } else {
            print("[OSD-GEOM] REAL notch frame: nil (positionAndShow hasn't run yet)")
        }
        if let p = panel?.frame {
            print("[OSD-GEOM] panel frame (screen coords): x=\(String(format: "%.1f", p.minX)) y=\(String(format: "%.1f", p.minY)) w=\(String(format: "%.1f", p.width)) h=\(String(format: "%.1f", p.height))")
        }
        #endif
        let activity: OSDActivity
        switch kind {
        case .volume:
            #if DEBUG
            let debugReadStart = CFAbsoluteTimeGetCurrent()
            #endif
            let (percent, muted) = readSystemVolume()
            #if DEBUG
            let debugReadEnd = CFAbsoluteTimeGetCurrent()
            print("[OSD-TIMING] c) readSystemVolume() took \(String(format: "%.2f", (debugReadEnd - debugReadStart) * 1000))ms, percent=\(percent) muted=\(muted)")
            #endif
            activity = osdVolumeActivity(percent: percent, hardwareMuted: muted)
        case .brightness:
            // Silent-degrade (Plan 39-03/39-04's Int? contract): a failed brightness read
            // produces NO HUD at all for this press, never a fabricated 0%.
            #if DEBUG
            let debugReadStart = CFAbsoluteTimeGetCurrent()
            #endif
            guard let percent = brightnessReader.readBrightness() else { return }
            #if DEBUG
            let debugReadEnd = CFAbsoluteTimeGetCurrent()
            print("[OSD-TIMING] c) readBrightness() took \(String(format: "%.2f", (debugReadEnd - debugReadStart) * 1000))ms, percent=\(percent)")
            #endif
            activity = osdBrightnessActivity(percent: percent)
        }

        if case .osd = transientQueue.head {
            transientQueue.updateHead(.osd(activity))
            #if DEBUG
            // Point (d) trigger: the mutation that should cause NotchPillView's osdWings(for:) body
            // to re-evaluate with the new fraction — compare this timestamp to NotchPillView's own
            // "[OSD-TIMING] d) osdWings body evaluated" log to isolate SwiftUI's own render latency.
            print("[OSD-TIMING] c) about to mutate presentation (updateHead path) t=\(String(format: "%.2f", CFAbsoluteTimeGetCurrent() * 1000))ms")
            #endif
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                renderPresentation()
            }
            scheduleActivityDismiss()   // D-09 — re-arm on every press while an .osd head stands
        } else {
            let changed: Bool
            if case .focus = transientQueue.head {
                changed = transientQueue.preempt(.osd(activity))
            } else {
                changed = transientQueue.enqueue(.osd(activity))
            }
            if changed {
                #if DEBUG
                print("[OSD-TIMING] c) about to mutate presentation (enqueue/preempt path) t=\(String(format: "%.2f", CFAbsoluteTimeGetCurrent() * 1000))ms")
                #endif
                presentTransientChange()
            }
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
        // Phase 38 / HUD-05 (D-06): a Focus head never self-elapses -- skip arming the uniform 3s
        // timer entirely while it stands. Every call site (presentTransientChange(), this
        // work item's own advance-then-re-arm branch, flushTransients(_:)'s promoted-survivor
        // re-arm) inherits this correctly with zero per-site changes.
        guard let head = transientQueue.head, !head.isPersistent else { return }
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
        // Phase 39 / HUD-03/HUD-04 (D-10 / T-39-05-01) — the ONE change to this function: the
        // duration is now computed from the CURRENT head's category rather than hardcoded to
        // the shared activityDuration, so an .osd head gets its own separate, shorter window
        // without touching Charging/Device/Focus's existing 3.0s timing. Reads the SAME `head`
        // snapshot the guard above already gated on (never re-reads transientQueue.head), so no
        // new race window is introduced. Every other line (the guard above, the
        // DispatchWorkItem body, the re-arm-on-advance branch) is unchanged — this same
        // computation applies correctly to whatever category becomes the NEW head after
        // advance() too.
        let duration: TimeInterval = {
            if case .osd = head { return osdActivityDuration }
            return activityDuration
        }()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // Keep the per-category @Published models in step with the queue head: whichever category is
    // NOT the current head has no standing splash, so clear its model (so a stale % tick or a
    // view binding can't resurrect a dismissed splash). The head's own model is left as-is.
    private func syncActivityModels() {
        switch transientQueue.head {
        case .charging: break
        case .device:   chargingState.activity = nil
        case .focus:    chargingState.activity = nil   // Phase 38 / HUD-05: not charging -- no standing charging splash
        case .osd:      chargingState.activity = nil   // Phase 39 / HUD-03/HUD-04: not charging -- no standing charging splash
        case nil:       chargingState.activity = nil
        }
    }

    // MARK: - Phase 6: hosting view + live settings application (APP-03 / D-09 / D-11)

    // Phase 27 / VISUAL-03 — the single read-site for all 4 theming preferences (T-27-05: only
    // assembles raw ints/the material style here; the actual accent(for:) clamp happens once,
    // inside makeRootView, never here). Called from exactly 2 sites: initial panel creation and
    // applyAccentIfChanged — no second raw UserDefaults read site for these keys (Pitfall 3).
    private func currentTheme() -> AppliedTheme {
        AppliedTheme(
            nowPlaying: UserDefaults.standard.integer(forKey: ActivitySettings.nowPlayingAccentKey),
            charging: UserDefaults.standard.integer(forKey: ActivitySettings.chargingAccentKey),
            device: UserDefaults.standard.integer(forKey: ActivitySettings.deviceAccentKey),
            // T-27-04: a missing/corrupted stored string falls back to .gradient.
            materialStyle: ActivitySettings.MaterialStyle(
                rawValue: UserDefaults.standard.string(forKey: ActivitySettings.materialStyleKey) ?? ""
            ) ?? .gradient
        )
    }

    // Build the SwiftUI root with the theme injected on the Environment (D-11). Extracted so the
    // initial host AND the live re-apply (applyAccentIfChanged) share ONE construction.
    // accent(for:) clamps an out-of-range index to the neutral default (T-06-11 — never crashes).
    private func makeRootView(theme: AppliedTheme) -> some View {
        NotchPillView(interaction: interaction,
                      nowPlaying: nowPlayingState,
                      presentationState: presentationState,
                      outfit: outfitState,
                      shelfViewState: shelfViewState,
                      onboardingState: onboardingState,
                      viewSwitcherState: viewSwitcherState,
                      calendarViewState: calendarViewState,
                      onClick: { [weak self] in self?.handleClick() },
                      onSecondaryTap: { [weak self] in self?.handleSecondaryTap() },
                      // NOW-02: transport rides the EXISTING persistent child's stdin via the
                      // monitor — no re-spawn, no focus steal.
                      onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
                      onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
                      onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() },
                      onShelfItemTap: { [weak self] item in self?.handleShelfItemTap(item) },
                      onShelfItemDelete: { [weak self] id in self?.handleShelfItemDelete(id) },
                      onShelfClearAll: { [weak self] in self?.handleShelfClearAll() },
                      onShelfItemDragStarted: { [weak self] in self?.beginShelfItemDrag() },
                      onOnboardingNext: { [weak self] in self?.advanceOnboarding(.next) },
                      onOnboardingBack: { [weak self] in self?.advanceOnboarding(.back) },
                      onOnboardingGrant: { [weak self] permission in self?.grantOnboardingPermission(permission) },
                      onOnboardingOpenSettings: { [weak self] in self?.openOnboardingSettings() },
                      onOnboardingFinish: { [weak self] in self?.finishOnboarding() },
                      onSwitcherSelect: { [weak self] view in self?.handleSwitcherSelect(view) },
                      onCalendarMonthChange: { [weak self] delta in self?.handleCalendarMonthChange(delta) },
                      onCalendarDaySelect: { [weak self] day in self?.handleCalendarDaySelect(day) },
                      onQuickAdd: { [weak self] kind, title in self?.handleQuickAdd(kind, title: title) })
            .environment(\.nowPlayingAccent, ActivitySettings.accent(for: theme.nowPlaying))
            .environment(\.chargingAccent, ActivitySettings.accent(for: theme.charging))
            .environment(\.deviceAccent, ActivitySettings.accent(for: theme.device))
            .environment(\.islandMaterialStyle, theme.materialStyle)
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

        // Phase 38 / HUD-05 — Focus. Mirrors the Charging/Devices toggle-off pattern exactly:
        // stop the poll timer, release it, and flush any standing/queued Focus splash (D-09).
        if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized {
            startFocusModeMonitor()
        } else if focusModeMonitor != nil {
            focusModeMonitor?.stop(); focusModeMonitor = nil
            flushTransients(.focus)
        }

        // Phase 41 / HUD-08 — Calendar Countdown. Mirrors the Charging/Devices toggle-off
        // pattern exactly: stop the monitor, release it, clear the ambient state, re-render.
        if activityEnabled(ActivitySettings.calendarCountdownKey) {
            startCalendarCountdownMonitor()
        } else if calendarCountdownMonitor != nil {
            calendarCountdownMonitor?.stop()
            calendarCountdownMonitor = nil
            calendarCountdownActivity = nil
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                renderPresentation()
            }
            updateVisibility()
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
    private enum TransientCategory { case charging, device, focus, osd }
    private func flushTransients(_ category: TransientCategory) {
        let oldHead = transientQueue.head
        let matches: (ActiveTransient) -> Bool = { t in
            switch (t, category) {
            case (.charging, .charging), (.device, .device), (.focus, .focus), (.osd, .osd): return true
            default: return false
            }
        }
        transientQueue.removeAll(where: matches)
        switch category {
        case .charging: chargingState.activity = nil
        case .device:
            deviceCoordinator.clearPendingBatteryPolls()   // Finding 4 — drop any pending battery polls too
        case .focus: break   // Phase 38 / HUD-05: no separate @Published model to clear -- Focus's state lives entirely in the resolver's IslandPresentation
        // Phase 39 / HUD-03/HUD-04 — defensive completeness only: nothing currently calls
        // flushTransients(.osd) since Plan 39-06's Settings toggle never stops the interceptor
        // (D-06), but the exhaustive switch must compile. No separate @Published model to clear
        // -- OSD's state lives entirely in the resolver's IslandPresentation (mirrors .focus).
        case .osd: break
        }
        guard transientQueue.head != oldHead else { return }   // WR-2 — untouched head, no timer reset
        dismissWorkItem?.cancel()
        if transientQueue.head != nil {
            deviceCoordinator.activityPromoted()   // Finding 4 — cover a device promoted here
            scheduleActivityDismiss()                 // Finding 3 — fresh window for the promoted transient
        }
    }

    // D-11 — re-host the view (re-injecting the Environment theme) only when any of the 4
    // persisted theming preferences actually changed, so unrelated defaults writes don't churn
    // the hosting view. Name kept as applyAccentIfChanged (this codebase's "extend, don't
    // duplicate the pipeline" convention) even though it now covers all 4 preferences.
    private func applyAccentIfChanged() {
        let theme = currentTheme()
        guard theme != appliedTheme else { return }
        appliedTheme = theme
        if let panel { panel.contentView = NSHostingView(rootView: makeRootView(theme: theme)) }
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
            // Plan 30-02 / HOME-02: capture the sticky last-played track for Home's
            // .homeLastPlayed state. Runs BEFORE the artwork nil-clear branch below (Pitfall 1)
            // so it always sees the same `art`/`p` the artwork logic is about to consume.
            // `art ?? nowPlayingState.artwork` mirrors the artwork-latency fallback documented
            // just below (a momentarily-nil `art` for the same track keeps whatever's showing).
            // Never cleared on .paused/.none — lastKnownTrack is deliberately independent of
            // nowPlayingState.artwork's own clear-on-.none behavior (D-08).
            if case .playing(let title, let artist) = p {
                nowPlayingState.lastKnownTrack = LastPlayedTrack(title: title, artist: artist,
                                                                  artwork: art ?? nowPlayingState.artwork)
            }
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

    // WR-01/WR-02/CR-01 — the SINGLE place that resyncs shelfViewState.items from the
    // coordinator. Live user mutations (delete/clear-all) animate with the controller's
    // standard spring (WR-01); the DEBUG launch seed passes animated: false (nothing visible
    // yet to animate from). Either way, syncClickThrough() is called unconditionally
    // afterward (NOT updateVisibility() — there is no panel resize under strategy (b), just a
    // cheap boolean recompute) so the click-through hit-test immediately reflects the new item
    // count via visibleContentZone(), even before the pointer next moves (CR-01).
    private func resyncShelfViewState(animated: Bool = true) {
        let newItems = shelfCoordinator.logic.items
        if animated {
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                shelfViewState.items = newItems
            }
        } else {
            shelfViewState.items = newItems
        }
        syncClickThrough()
    }

    // SHELF-04 — removes just the tapped item + its session-temp copy (ShelfCoordinator.remove),
    // then resyncs the published mirror the view observes.
    private func handleShelfItemDelete(_ id: UUID) {
        shelfCoordinator.remove(id: id)
        resyncShelfViewState()
    }

    // SHELF-05 / D-03 — clears every item + every session-temp copy instantly (no confirmation
    // dialog), then resyncs the published mirror.
    private func handleShelfClearAll() {
        shelfCoordinator.clear()
        resyncShelfViewState()
    }

    // Phase 21 / SHELF-06 / D-03 — pins the island open for the duration of a shelf-item drag:
    // cancels any pending grace-collapse, arms the guaranteed 20s safety net, and arms the
    // best-effort early-release monitor (mirrors Pattern 1's .mouseMoved global monitor).
    private func beginShelfItemDrag() {
        isDraggingShelfItem = true
        graceWorkItem?.cancel()
        graceWorkItem = nil

        dragPinSafetyNetWorkItem?.cancel()
        let safetyNet = DispatchWorkItem { [weak self] in self?.endShelfItemDrag() }
        dragPinSafetyNetWorkItem = safetyNet
        DispatchQueue.main.asyncAfter(deadline: .now() + dragPinSafetyNetDuration, execute: safetyNet)

        if dragReleaseMonitor == nil {
            dragReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                self?.endShelfItemDrag()
            }
        }
    }

    // Phase 21 / SHELF-06 / D-03 — idempotent (the safety net and the mouseUp monitor may both
    // eventually fire, in either order; only the first call has any effect). Tears down the
    // per-drag monitor (minimal always-on observation surface) and, only if the pointer is
    // already outside the hot zone, re-invokes handleHoverExit() so the island resumes its
    // normal grace-collapse countdown at the next natural transition (D-13-style).
    private func endShelfItemDrag() {
        guard isDraggingShelfItem else { return }
        isDraggingShelfItem = false
        dragPinSafetyNetWorkItem?.cancel()
        dragPinSafetyNetWorkItem = nil
        if let m = dragReleaseMonitor { NSEvent.removeMonitor(m) }
        dragReleaseMonitor = nil
        // WR-01: pointerInZone is only kept fresh by the .mouseMoved monitor, which doesn't fire
        // during an OS drag session — re-sample the live pointer instead of trusting the frozen
        // flag, so a drag dropped outside the zone actually schedules the collapse.
        handlePointer(at: NSEvent.mouseLocation)
    }

    #if DEBUG
    // Pitfall 5 — real, on-disk sample files (not fabricated ShelfItem structs with synthetic
    // URLs) so icon lookup + click-to-open are realistic ahead of Phase 22's real drag-in.
    // DEBUG-only: compiled out of Release entirely.
    private func seedDebugShelfItems() {
        // Debug-tray-not-updating fix (2026-07-16) — this used to reseed unconditionally on
        // EVERY launch, so shelfViewState.items was never empty in a Debug build, which made
        // trayFullView's `shelfViewState.items.isEmpty` branch (-> trayEmptyState) permanently
        // unreachable and silently hid any change made to that view. One-time seed only, so the
        // shelf's empty/non-empty state goes back to normal user control (drag-in / Clear All).
        let seededKey = "IsletDebugShelfSeeded"
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

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
        resyncShelfViewState(animated: false)
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
        // Phase 24 / SHELF-01 / SHELF-02 — tear down the production DragApproachDetector monitors.
        if let m = dragApproachMonitor { NSEvent.removeMonitor(m) }
        if let m = dragEndMonitor { NSEvent.removeMonitor(m) }
        graceWorkItem?.cancel()

        // Phase 21 / SHELF-06 (T-21-03): in case the controller deallocates mid-drag (e.g. app
        // quit during a drag), cancel the safety net and remove the early-release monitor.
        dragPinSafetyNetWorkItem?.cancel()
        if let m = dragReleaseMonitor { NSEvent.removeMonitor(m) }

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

        // Phase 38 / HUD-05: tear down the Focus poll timer — mirrors bluetoothMonitor?.stop()'s
        // owner-driven teardown discipline exactly.
        focusModeMonitor?.stop()

        // Phase 41 / HUD-08: tear down the Calendar Countdown monitor — mirrors
        // focusModeMonitor?.stop()'s owner-driven teardown discipline exactly.
        calendarCountdownMonitor?.stop()

        // Phase 39 / HUD-03/HUD-04: tear down the OSD key-press event tap — mirrors
        // focusModeMonitor?.stop()'s owner-driven teardown discipline exactly.
        osdInterceptor?.stop()

        // Phase 24 / SHELF-01 / SHELF-02 (D-10): tear down the drop-interception tap — mirrors
        // bluetoothMonitor?.stop()'s owner-driven teardown discipline exactly.
        dropInterceptTap?.stop()

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
