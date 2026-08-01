import SwiftUI
import AppKit   // Phase 33 / WEATHER-02 (D-08) — NSColor.blended(withFraction:of:) for temperatureColor

// ISL-04 / D-07 — the Dynamic-Island MORPH.
//
// The Phase-1 static pill becomes a collapsed↔expanded morph driven by
// `NotchInteractionState.isExpanded`. Both the collapsed pill and the expanded
// blob carry the SAME `matchedGeometryEffect(id: "island", in: ns)` on ONE shared
// namespace (`ns` below), so SwiftUI MORPHS the single black shape (corner radius +
// frame interpolate) instead of cross-fading two views (D-07: no cross-fade).
//
// This is the VIEW LAYER only. It drives NO animation itself — no internal animation
// wrapper, no clock/scheduler, no appear-hook animation. Plan 03's controller wraps the
// state mutation in a spring animation (response 0.35, dampingFraction 0.65) and SwiftUI
// animates the dependent matchedGeometryEffect/scaleEffect automatically. That keeps the
// idle/collapsed pill provably static (D-08): no driving clock here.
struct NotchPillView: View {
    // Plan 03 owns the instance and injects it via
    // `NSHostingView(rootView: NotchPillView(interaction: state))`.
    @ObservedObject var interaction: NotchInteractionState

    // Phase 4 / NOW-01/02 — the SEPARATE @Published media model (Plan 02). The controller
    // (Plan 04) owns it: the monitor lifts MediaRemote payloads → presentation/artwork and
    // drives `isHealthy` from the D-12 launch probe + D-13 mid-death. This view only RENDERS
    // whatever is published — no MediaRemote, no animation of its own EXCEPT the deliberately
    // isPlaying-gated equalizer bars below. Declared BEFORE onClick (non-defaulted ahead of a
    // defaulted parameter) so the controller call reads
    // `NotchPillView(interaction:nowPlaying:onClick:...)`.
    //
    // NOTE (Phase 6 / D-05): the view no longer READS `nowPlaying.presentation` /
    // `interaction.isExpanded` to DECIDE which branch to render — the controller's resolver
    // does that and hands the answer in via `presentation` below. `nowPlaying.artwork` is still
    // read for the media cases (the resolver passes only the presentation enum, not the NSImage),
    // so `nowPlaying` stays @ObservedObject so an artwork mutation re-renders the same case. The
    // PRECEDENCE decision is gone.
    @ObservedObject var nowPlaying: NowPlayingState

    // Phase 6 / COORD-01 / D-05 — the SINGLE arbiter's verdict, published. The controller
    // computes it via `resolve(activeTransient:nowPlaying:nowPlayingHealthy:isExpanded:)` (the
    // pure IslandResolver) and writes `presentationState.presentation` inside its spring; this
    // @ObservedObject re-renders the body — ONE `switch` over the enum, no precedence `if`-chain.
    // A small published model (mirroring charging/nowPlaying) avoids re-hosting on every change.
    @ObservedObject var presentationState: IslandPresentationState
    // Convenience so the body + previews read a plain enum.
    private var presentation: IslandPresentation { presentationState.presentation }
    // Phase 26 bugfix (26-04 on-device UAT round 1) — the outer body frame needs this to
    // grow to onboardingSize.height instead of expandedSize.height (see body's .frame below).
    private var isOnboardingPresentation: Bool {
        if case .onboarding = presentation { return true }
        return false
    }
    // Phase 32 / TRAY-05 — mirrors isOnboardingPresentation's exact shape so the outer body
    // frame below can branch to the wider/shorter traySize/trayContentHeight box.
    private var isTrayPresentation: Bool {
        if case .trayExpanded = presentation { return true }
        return false
    }
    // Quick task 260715-vsd — mirrors isOnboardingPresentation/isTrayPresentation's exact
    // shape so the outer body frame below can branch to the wider calendarWidth box.
    private var isCalendarPresentation: Bool {
        if case .calendarExpanded = presentation { return true }
        return false
    }
    // Quick task 260714-3k6 (anticipates ROADMAP Phase 31 / TRAY-01) — the additive shelf-strip
    // reveal under Home/Calendar/Weather/Now-Playing is gone: the shelf only ever renders inside
    // the dedicated Tray view (trayFullView draws it directly via shelfRow(_:) with its own
    // shelfVisible: false, unaffected by this gate). One named boolean instead of 5 separate
    // `shelfVisible: shelfViewState.isVisible` call sites, so a future change only touches one
    // line — matches the file's existing single-source-of-truth convention (e.g. cameraClearance,
    // switcherContentHeight).
    //
    // internal (not private): NotchPillViewTests.swift asserts this directly (Phase 31/TRAY-01
    // regression lock) — `private` is file-scoped and would not compile from another file even
    // under @testable import (see EqualizerBars.makeProfiles() for the same precedent).
    var shelfStripVisible: Bool { false }
    // Phase 28 / CALVIEW-01 (28-UI-SPEC.md "Visibility") — the switcher pill shows only when
    // the island is expanded AND no time-sensitive activity (Charging/Device splash, Now-
    // Playing wings glance) is being shown, mirroring SHELF-09's suppression precedent.
    // WR-01 fix (28-REVIEW.md) — this used to hand-duplicate NotchWindowController's own copy
    // of the same case list (each file's comment noted it "mirrors" the other, but nothing
    // enforced that). Both now call the single shared `showsSwitcherRow(for:)` in
    // IslandResolver.swift so the render and click-through geometry can never desync again.
    private var showsSwitcherRow: Bool {
        Islet.showsSwitcherRow(for: presentation)
    }

    // Phase 45 / SWITCH-01/SWITCH-02 — the per-case width/height for the 6 switcher-row
    // tabs, computed as plain CGFloat values (not a branched View) so Task 2's single
    // `tabContentView` call site can hand ONE `blobShape` call the right size regardless
    // of which tab is active — mirroring the existing "compute a value, don't branch the
    // View" precedent already proven at `body`'s own outer `.frame` ternary above.
    // internal (not private): NotchPillViewTests.swift asserts these directly (regression
    // lock), same testability precedent as `shelfStripVisible`.
    var tabWidth: CGFloat {
        switch presentation {
        case .calendarExpanded: return Self.calendarWidth * resolvedWidthScale
        case .trayExpanded: return Self.traySize.width * resolvedWidthScale
        default: return Self.expandedSize.width * resolvedWidthScale
        }
    }

    var tabHeight: CGFloat {
        switch presentation {
        case .calendarExpanded: return Self.calendarContentHeight * resolvedDepthScale
        case .trayExpanded: return Self.trayContentHeight * resolvedDepthScale
        case .weatherExpanded: return (weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight) * resolvedDepthScale
        // Phase 62-04 UAT round 3 fix (item A) — Countdown's box is now mode-aware/compact
        // (was sharing Pomodoro's tall reservation, leaving a big empty gap below Countdown's
        // single chip grid). Reuses calendarContentHeight (220) rather than a new constant —
        // close enough to Countdown's own real content height (camera clearance + segmented +
        // one chip grid + button row) and an already-proven-safe value. Site 2/3
        // (NotchWindowController's positionAndShow/visibleContentZone) intentionally stay
        // reserved at the taller timerSetupContentHeight unconditionally — they have no
        // visibility into this view-local timerSetupMode, and over-reserving is the safe
        // direction (mirrors OUTPUT-01's own accepted "static reservation, slightly taller
        // than needed sometimes" trade-off) — Site 1 alone decides the actually-visible height.
        case .timerSetup: return (timerSetupMode == .countdown ? Self.calendarContentHeight : Self.timerSetupContentHeight) * resolvedDepthScale
        // Phase 65 / QACTION-02 (Plan 05 Task 2) — the Quick Actions bar's own dedicated
        // content height, matching every sibling switcher-tab presentation's explicit branch
        // (never falls through to `default:`, which is Home-shaped, not grid-shaped).
        case .quickActionsBarExpanded: return Self.quickActionsBarContentHeight * resolvedDepthScale
        default: return (Self.homeContentHeight + (presentationState.outputPanelOpen ? Self.outputPanelExtraHeight : 0)) * resolvedDepthScale
        }
    }

    // Phase 52 / SWITCH-03 (D-06, RESEARCH.md Pitfall 1) — extracted from body's outer `.frame`
    // height ternary, same "compute a value, don't branch the View" precedent as tabWidth/
    // tabHeight above. Byte-identical branch structure to the ternary it replaces, except each
    // `+ Self.switcherRowHeight` term is now ALSO gated on `switcherLayout == .pill`: the pill
    // row itself never renders in top-edge mode (mirrors blobShape's showsPillRow), so this
    // outer window-frame reservation must shrink in lockstep or NotchWindowController's
    // visibleContentZone() click-through geometry disagrees with what's actually visible.
    // internal (not private): NotchPillViewTests.swift asserts this directly, same testability
    // precedent as tabWidth/tabHeight.
    var totalHeight: CGFloat {
        isTrayPresentation
            ? Self.trayContentHeight * resolvedDepthScale + (switcherLayout == .pill ? Self.switcherRowHeight * resolvedDepthScale : 0)
            : (isOnboardingPresentation
                ? Self.onboardingSize.height
                : (showsSwitcherRow ? Self.switcherContentHeight * resolvedDepthScale : Self.expandedSize.height * resolvedDepthScale)
                    + (showsSwitcherRow && switcherLayout == .pill ? Self.switcherRowHeight * resolvedDepthScale : 0))
    }

    // Phase 14 / WEATHER-01 / CAL-01 — the SEPARATE @Published outfit model (weather +
    // calendar), mirroring nowPlaying/presentationState's ownership contract: the controller
    // (14-04) is the only writer, this view only RENDERS whatever is published. No default
    // value — the controller always owns and injects a real instance (same non-defaulted
    // convention as `nowPlaying`/`presentationState`).
    @ObservedObject var outfit: BasicOutfitState

    // Phase 33 / WEATHER-01/02 (D-03/D-04/D-05) — the Settings "Weather Style" Medium/Large
    // selector, read directly via @AppStorage (same shared UserDefaults key SettingsView
    // writes) so this view re-renders live the moment the user flips it — no relaunch, no
    // controller round-trip needed for the render decision itself (the controller still owns
    // the panel-geometry side of this same key, see NotchWindowController's positionAndShow/
    // visibleContentZone). Medium is always the safe floor default (D-04).
    @AppStorage(ActivitySettings.weatherStyleKey) private var weatherStyle: WeatherStyle = .medium

    // Phase 52 / SWITCH-04 — the 4 top-edge/pill slot assignments, one independent @AppStorage
    // key per slot (never a single encoded array). Default split: Home+Tray left, Calendar+
    // Weather right — byte-identical to today's hardcoded switcherRow order (D-03 zero
    // regression). Mirrors weatherStyle's declaration style directly above.
    @AppStorage(ActivitySettings.switcherSlotLeftOuterKey) private var slotLeftOuter: SelectedView = .home
    @AppStorage(ActivitySettings.switcherSlotLeftInnerKey) private var slotLeftInner: SelectedView = .tray
    @AppStorage(ActivitySettings.switcherSlotRightInnerKey) private var slotRightInner: SelectedView = .calendar
    @AppStorage(ActivitySettings.switcherSlotRightOuterKey) private var slotRightOuter: SelectedView = .weather

    // Phase 52 / SWITCH-03 (D-06) — the switcher layout mode: today's pill-below-the-island
    // (default) or the alternate top-edge row. Corrupted/unknown stored values fall back to
    // .pill, mirroring weatherStyle's `?? .medium`-equivalent @AppStorage default convention.
    @AppStorage(ActivitySettings.switcherLayoutKey) private var switcherLayout: SwitcherLayout = .pill

    // Phase 67.1-02 / D-07/D-08 — the two manual scale-offset sliders, additive deltas from
    // the live auto-detected scale (NotchGeometry.resolvedIslandScale), never absolute scales.
    @AppStorage(ActivitySettings.islandWidthScaleOffsetKey) private var islandWidthScaleOffset: Double = 0
    @AppStorage(ActivitySettings.islandDepthScaleOffsetKey) private var islandDepthScaleOffset: Double = 0

    // Quick task 260728-wg7 — DEBUG-only "Wing Tuner" live-nudge storage, mirroring the
    // islandWidthScaleOffset/islandDepthScaleOffset live-tuning mechanism above. Always-0 at
    // rest; only ever mutated from AppDelegate's debug menu.
    #if DEBUG
    @AppStorage(ActivitySettings.debugWingLeadingNudgeKey) private var debugWingLeadingNudge: Double = 0
    @AppStorage(ActivitySettings.debugWingTrailingNudgeKey) private var debugWingTrailingNudge: Double = 0
    @AppStorage(ActivitySettings.debugWingMarginNudgeKey) private var debugWingMarginNudge: Double = 0
    @AppStorage(ActivitySettings.debugWingGapNudgeKey) private var debugWingGapNudge: Double = 0
    @AppStorage(ActivitySettings.debugWingCornerRadiusNudgeKey) private var debugWingCornerRadiusNudge: Double = 0
    @AppStorage(ActivitySettings.debugWingHeightNudgeKey) private var debugWingHeightNudge: Double = 0

    // Phase 72.1 / D-05 — OSD Counter Tuner storage (roll speed only; the opacity-ramp storage
    // was reverted by quick task 260731-61m), same always-0-at-rest contract as the Wing Tuner
    // keys above.
    @AppStorage(ActivitySettings.debugOSDRollSpeedNudgeKey) private var debugOSDRollSpeedNudge: Double = 0

    // Phase 72.1.1 / GLASS-01 — Liquid Glass Tuner storage, same always-0-at-rest contract as
    // the Wing/OSD Tuner keys above. Scaffolding only for Plan 72.1.1-03's full-surface work.
    @AppStorage(ActivitySettings.debugGlassTintNudgeKey) private var debugGlassTintNudge: Double = 0
    @AppStorage(ActivitySettings.debugGlassGlossNudgeKey) private var debugGlassGlossNudge: Double = 0
    @AppStorage(ActivitySettings.debugGlassLegacyEdgeOpacityNudgeKey) private var debugGlassLegacyEdgeOpacityNudge: Double = 0
    @AppStorage(ActivitySettings.debugGlassLegacyCenterOpacityNudgeKey) private var debugGlassLegacyCenterOpacityNudge: Double = 0
    @AppStorage(ActivitySettings.debugGlassLegacyBorderWidthNudgeKey) private var debugGlassLegacyBorderWidthNudge: Double = 0

    // Quick task 260801 — Switcher Tuner storage, same always-0-at-rest contract as the
    // Wing/OSD/Glass Tuner keys above.
    @AppStorage(ActivitySettings.debugSwitcherSizeNudgeKey) private var debugSwitcherSizeNudge: Double = 0
    @AppStorage(ActivitySettings.debugSwitcherContentOffsetNudgeKey) private var debugSwitcherContentOffsetNudge: Double = 0
    #endif

    // Always-compiled read points so every wing function can call these unconditionally.
    // Release branch always returns 0 -> `+ wingLeadingNudge` etc. is a no-op `+ 0` literal
    // in Release builds, zero behavior change.
    private var wingLeadingNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingLeadingNudge)
        #else
        return 0
        #endif
    }
    private var wingTrailingNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingTrailingNudge)
        #else
        return 0
        #endif
    }
    private var wingMarginNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingMarginNudge)
        #else
        return 0
        #endif
    }
    private var wingGapNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingGapNudge)
        #else
        return 0
        #endif
    }
    private var wingCornerRadiusNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingCornerRadiusNudge)
        #else
        return 0
        #endif
    }
    private var wingHeightNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugWingHeightNudge)
        #else
        return 0
        #endif
    }

    // Phase 72.1 / D-05 — always-compiled OSD Counter Tuner read point (roll speed only; the
    // opacity-ramp nudges were reverted by quick task 260731-61m). Double, not CGFloat: this
    // feeds a spring `response` value.
    private var osdRollSpeedNudge: Double {
        #if DEBUG
        return debugOSDRollSpeedNudge
        #else
        return 0
        #endif
    }

    // Phase 72.1.1 / GLASS-01 — always-compiled Liquid Glass Tuner read points. Release branch
    // always returns 0, matching wingLeadingNudge's zero-Release-cost contract. Not yet
    // referenced by any call site — Plan 72.1.1-03 is the first consumer.
    private var glassTintNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugGlassTintNudge)
        #else
        return 0
        #endif
    }
    private var glassGlossNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugGlassGlossNudge)
        #else
        return 0
        #endif
    }
    private var glassLegacyEdgeOpacityNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugGlassLegacyEdgeOpacityNudge)
        #else
        return 0
        #endif
    }
    private var glassLegacyCenterOpacityNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugGlassLegacyCenterOpacityNudge)
        #else
        return 0
        #endif
    }
    private var glassLegacyBorderWidthNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugGlassLegacyBorderWidthNudge)
        #else
        return 0
        #endif
    }

    // Quick task 260801 — always-compiled Switcher Tuner read points, same zero-Release-cost
    // contract as every other nudge above. switcherSizeNudge shifts navCircleDiameter for the
    // switcher row's icons only (other navCircleButton callers — onboarding nav, Timer setup —
    // pass no diameter override and stay byte-identical); resolvedCameraClearance feeds every
    // `.padding(.top, ...)` call site that used to read `Self.cameraClearance` directly, so one
    // nudge shifts every switcher-row tab's content down/up together.
    private var switcherSizeNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugSwitcherSizeNudge)
        #else
        return 0
        #endif
    }
    private var switcherContentOffsetNudge: CGFloat {
        #if DEBUG
        return CGFloat(debugSwitcherContentOffsetNudge)
        #else
        return 0
        #endif
    }
    private var resolvedCameraClearance: CGFloat { Self.cameraClearance + switcherContentOffsetNudge }

    // Phase 62 / TIMER-01 (D-01) — the Timer/Pomodoro activity toggle (Settings default OFF,
    // per v1.10's own "new activities default OFF" convention). Read directly here, same
    // existing-key/existing-pattern as switcherLayout above — the switcher's 5th Timer icon is gated
    // on this with zero controller-side plumbing needed.
    @AppStorage(ActivitySettings.timerKey) private var timerEnabled = false

    // Phase 62 / TIMER-01 (D-01..D-05) — the duration/mode picker's local UI state, now
    // rendered under the dedicated `.timerSetup` switcher tab (Phase 62-04 UAT revision,
    // item 6) rather than an inline Home overlay -- visibility is driven by
    // `presentation == .timerSetup`, no local presented-flag needed anymore. Never reaches a
    // controller closure directly — only the validated Int minute values passed to
    // onStartCountdown/onStartPomodoro do (T-62-04).
    @State private var timerSetupMode: TimerMode = .countdown
    @State private var countdownMinutes = 10
    @State private var isCountdownCustomSelected = false
    @State private var countdownCustomText = ""
    @State private var workMinutes = 25
    @State private var isWorkCustomSelected = false
    @State private var workCustomText = ""
    @State private var breakMinutes = 5
    @State private var isBreakCustomSelected = false
    @State private var breakCustomText = ""
    @State private var timerValidationMessage: String? = nil

    // Phase 52 / SWITCH-03/04 (D-03) — the ONE shared left-to-right ordering both switcherRow
    // (pill) and topEdgeSwitcherRow (top-edge) read; calls Plan 52-01's shared orderedSlotIcons(...)
    // free function so there is exactly one place that turns 4 independent slot values into an
    // ordered array. internal (not private): NotchPillViewTests.swift asserts this directly, same
    // testability precedent as shelfStripVisible/tabWidth/tabHeight.
    var orderedSlotViews: [SelectedView] {
        orderedSlotIcons(leftOuter: slotLeftOuter, leftInner: slotLeftInner,
                          rightInner: slotRightInner, rightOuter: slotRightOuter)
    }

    // Phase 20 / SHELF-03 — the SEPARATE @Published shelf model, mirroring nowPlaying/
    // presentationState/outfit's existing ownership contract: the controller (Plan 20-02) always
    // owns and injects a real instance, never defaulted. This view only RENDERS whatever is
    // published — no ShelfCoordinator, no file I/O.
    @ObservedObject var shelfViewState: ShelfViewState

    // Phase 65 / QACTION-02 (interfaces) — the SEPARATE @Published DND/Focus failure-flash
    // model, mirroring outfit's/shelfViewState's ownership contract exactly: the controller
    // (Plan 65-07/08) always owns and injects a real instance, never defaulted. This view only
    // RENDERS quickActionsBarFeedback.lastFailedAction (see quickActionsBarContent below).
    @ObservedObject var quickActionsBarFeedback: QuickActionsBarFeedbackState

    // Phase 26 / ONBOARD-01 — the SEPARATE @Published onboarding-permissions model,
    // mirroring nowPlaying/presentationState/outfit/shelfViewState's existing ownership
    // contract: the controller (Plan 26-04) always owns and injects a real instance, never
    // defaulted. This view only RENDERS whatever is published — no permission-request logic.
    @ObservedObject var onboardingState: OnboardingViewState

    // Phase 28 / CALVIEW-01/04 — the SEPARATE @Published switcher-selection model, mirroring
    // shelfViewState/onboardingState's existing ownership contract: the controller (Plan 04)
    // always owns and injects a real instance, never defaulted. This view only RENDERS whatever
    // is published and reports taps via onSwitcherSelect — no precedence re-deciding here (the
    // resolver's `resolve(...)` is still the single arbiter, Pattern 3).
    @ObservedObject var viewSwitcherState: ViewSwitcherState
    // Phase 28 / CALVIEW-01/02 — the SEPARATE @Published calendar-view model, same ownership
    // contract. This view only RENDERS visibleMonth/selectedDay/monthEvents.
    @ObservedObject var calendarViewState: CalendarViewState

    // Phase 27 / VISUAL-03 / D-06/D-08 — the controller injects 3 INDEPENDENT per-element
    // accents on the hosting view via `.environment(\.nowPlayingAccent, …)` /
    // `\.chargingAccent` / `\.deviceAccent`, replacing the single shared accent key this
    // view used before this phase. Each tints ONLY its own lively leaf element (now-playing
    // equalizer/progress bar, charging glyph, device icon) — the black island and the expanded
    // chrome stay untinted (D-10), and changing one element's accent never affects the other
    // two. All 3 default to `.white` (the EnvironmentKey default) so previews render the
    // neutral look before the controller wires a swatch.
    @Environment(\.nowPlayingAccent) private var nowPlayingAccent
    @Environment(\.chargingAccent) private var chargingAccent
    @Environment(\.deviceAccent) private var deviceAccent
    // Phase 27 / VISUAL-03 — the island material look (Gradient vs Solid Black), read here so
    // `islandFill` below can branch per-user-preference at all 4 fill sites.
    @Environment(\.islandMaterialStyle) private var materialStyle

    // D-02 — the CLICK-to-expand callback. The view stays AppKit-free: it only reports
    // "the pill was tapped" via this plain closure. NotchWindowController owns the
    // closure and runs the focus-safe `nextState(_, .clicked)` mutation inside its spring
    // animation wrapper, so the expand path + the spring tuning live in one place (the
    // controller), not scattered in the view. Defaults to a no-op so the DEBUG #Previews
    // (and any unit construction) build without a controller.
    var onClick: () -> Void = {}

    // Phase 60 / UPDATE-01 — the Update wing's per-wing tap override (wingsShape's `onTap`
    // param), mirroring `onClick`'s exact declaration style. Triggers Sparkle's install flow
    // instead of the universal expand-to-Home. Defaults to a no-op so DEBUG #Previews build
    // without a controller.
    var onUpdateTap: () -> Void = {}

    // Phase 63 / MEET-02 (D-09) — the Meeting wing's mute-icon tap callback, mirroring
    // `onUpdateTap`'s exact declaration style. NOT a wingsShape `onTap` override: unlike Update
    // (whose WHOLE wing is tappable), this fires from a nested `.onTapGesture` on the mute icon
    // subregion ALONE, while the wing's own background is an explicit no-op (D-10). Plan 63-04
    // wires it to MicMuteController.toggleSystemInputMute(). Defaults to a no-op so DEBUG
    // #Previews build without a controller.
    var onMuteTap: () -> Void = {}

    // Phase 65 / QACTION-02 — the Quick Actions bar's tile tap callback, mirroring
    // `onMuteTap`'s exact declaration style. The Int is the CAPTURED 0-7 slot index (not the
    // filtered configured-tiles position) — needed so the controller (Plan 65-07) can resolve
    // the matching per-slot launch-target key for `.launch` taps without re-deriving
    // orderedQuickActionsBarSlots itself. Defaults to a no-op so the DEBUG #Previews build
    // without a controller.
    var onQuickActionTap: (QuickActionsBarCatalog.Action, Int) -> Void = { _, _ in }

    // Phase 42 / DUAL-01 (D-12, SUPERSEDED 2026-07-19 — live user decision during Plan 42-04
    // Task 3's on-device UAT) — the secondary bubble's tap callback, mirroring `onClick`'s
    // exact declaration style. Originally wired to expand to Now-Playing (D-12); now repurposed
    // to toggle play/pause directly (see `secondaryBubble(_:)` and
    // `NotchWindowController.handleSecondaryTap()`). Defaults to a no-op so the DEBUG #Previews
    // build without a controller.
    var onSecondaryTap: () -> Void = {}

    // Phase 53 / RESUME-02 — the hover-preview's dedicated resume-tap callback. NOT a reuse
    // of `onClick` (which expands to Home, violating D-01) and NOT a literal passthrough of
    // `onSecondaryTap` (semantically a distinct call site, per 53-RESEARCH.md Pitfall 4) —
    // NotchWindowController wires this to handleResumeTap(), whose body calls
    // togglePlayPause() and starts the D-03 inferred-failure timeout watch. Defaults to a
    // no-op so #Previews still build without a controller.
    var onResumeTap: () -> Void = {}

    // NOW-02 — the transport callbacks, plain closures mirroring `onClick`. The view stays
    // AppKit-free + focus-safe: a button tap only REPORTS the intent; NotchWindowController
    // (Plan 04) owns the closures and forwards them to NowPlayingMonitor.togglePlayPause()/
    // nextTrack()/previousTrack() (which ride the existing persistent perl child's stdin).
    // Defaulted to no-ops so the DEBUG #Previews build without a controller.
    var onTogglePlayPause: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

    // Phase 48 / OUTPUT-01/02/03 — the output-panel callbacks, plain closures mirroring the
    // transport callbacks above: the view stays AppKit/CoreAudio-free, only REPORTS intent.
    // NotchWindowController (Plan 48-03) owns these and forwards them to setSystemVolume(_:)/
    // setDefaultOutput(uid:)/presentationState.outputPanelOpen writes. Defaulted to no-ops so
    // the DEBUG #Previews build without a controller.
    var onToggleOutputPanel: () -> Void = {}
    var onSelectOutputDevice: (AudioOutputDevice) -> Void = { _ in }
    var onVolumeChange: (Float) -> Void = { _ in }

    // Phase 20 / SHELF-04/05 — the shelf-item callbacks, plain closures mirroring the transport
    // callbacks above: the view stays AppKit-free, only REPORTS intent. NotchWindowController
    // (Plan 20-02) owns these and forwards them to ShelfCoordinator/NSWorkspace. Defaulted to
    // no-ops so the DEBUG #Previews build without a controller.
    var onShelfItemTap: (ShelfItem) -> Void = { _ in }
    var onShelfItemDelete: (UUID) -> Void = { _ in }
    var onShelfClearAll: () -> Void = {}
    // Phase 21 / SHELF-06 — the drag-started signal, forwarded from ShelfItemView so the
    // controller can pin the island open for the duration of a shelf-item drag (D-03).
    var onShelfItemDragStarted: () -> Void = {}

    // Phase 26 / ONBOARD-01 — the onboarding carousel's callbacks, plain closures mirroring
    // the shelf-item callbacks above: the view stays AppKit-free, only REPORTS intent.
    // NotchWindowController (Plan 26-04) owns these and forwards them to the real
    // OnboardingFlow/permission-request/Settings-hop/finish logic. Defaulted to no-ops so the
    // DEBUG #Previews build without a controller.
    var onOnboardingNext: () -> Void = {}
    var onOnboardingBack: () -> Void = {}
    var onOnboardingGrant: (OnboardingPermission) -> Void = { _ in }
    var onOnboardingOpenSettings: () -> Void = {}
    var onOnboardingFinish: () -> Void = {}
    // Phase 54 / D-12 — replay-only cancel; wired to replayCloseButton below, only ever
    // rendered when onboardingState.isReplay is true.
    var onOnboardingCancel: () -> Void = {}

    // Phase 28 / CALVIEW-01/02 — the switcher-pill and calendar-navigation callbacks, plain
    // closures mirroring the onboarding callbacks above: the view stays AppKit/EventKit-free,
    // only REPORTS intent. NotchWindowController (Plan 04) owns these. Defaulted to no-ops so
    // the DEBUG #Previews build without a controller.
    var onSwitcherSelect: (SelectedView) -> Void = { _ in }
    var onCalendarMonthChange: (Int) -> Void = { _ in }
    var onCalendarDaySelect: (Date) -> Void = { _ in }
    // Phase 72-04 (D-13) — the month/year label popover's "jump to month" report closure,
    // mirroring onCalendarDaySelect's exact "report an absolute Date, no math in the view"
    // shape (NOT a delta like onCalendarMonthChange — the picker already knows the exact
    // target month/year, so there is nothing to compute here).
    var onCalendarMonthYearSelect: (Date) -> Void = { _ in }
    // Phase 28 / CALVIEW-03 — the quick-add report closure (Task 3): (kind, title) forwarded
    // unmodified, no EventKit/EKEventStore code in this view file.
    // Phase 46 / CALVIEW-05 — widened to carry the picked Start/Due (Date) and End (Date?,
    // Event only) out of QuickAddPopover; not yet wired to the controller in this plan (that's
    // Plan 46-02 Task 1) — the default no-op closure keeps every #Preview referencing
    // NotchPillView compiling unmodified in the meantime.
    var onQuickAdd: (QuickAddKind, String, Date, Date?) -> Void = { _, _, _, _ in }
    // Phase 72 / CALVIEW-08 (D-07/D-08/D-09) — the agenda event row's edit/delete report-intent
    // closures, matching onQuickAdd's exact defaulted-no-op style so every #Preview referencing
    // NotchPillView keeps compiling unmodified. NotchWindowController (Plan 04) owns these,
    // forwarding to CalendarService.updateEvent/deleteEvent.
    var onEventEdit: (String, String, Date, Date) -> Void = { _, _, _, _ in }
    var onEventDelete: (String) -> Void = { _ in }

    // Phase 62 / TIMER-01..04 (D-08) — the expanded-control-row callbacks, plain closures
    // mirroring the shelf-item/onboarding callbacks above: the view stays state-free, only
    // REPORTS intent. NotchWindowController (Plan 62-04) owns these and forwards them to
    // TimerActivityState's pause/resume/reset/addMinute/stop. Defaulted to no-ops so the
    // DEBUG #Previews build without a controller.
    var onTimerPauseResume: () -> Void = {}
    var onTimerReset: () -> Void = {}
    var onTimerAddTime: () -> Void = {}
    var onTimerStop: () -> Void = {}
    // Phase 62 / TIMER-01 (D-01..D-05, T-62-04) — the Start Timer setup picker's start
    // callbacks, forwarding ONLY the validated Int SECOND value(s) — never the raw TextField
    // text (parseCustomDurationSeconds(_:) runs before either of these is ever called).
    // Phase 62-04 UAT round 5 feature (item I) — widened from whole minutes to whole
    // seconds so the picker can express sub-minute custom durations ("30s"); preset chips
    // (still minute-granular) convert at the call site (startTimerSetup() below, `* 60`).
    var onStartCountdown: (Int) -> Void = { _ in }
    var onStartPomodoro: (Int, Int) -> Void = { _, _ in }

    // Phase 34 / TRAY-02 (D-09 fallback) — AirDrop/Mail dim + disable only if Plan 02 Task 3's
    // on-device spike finds no working invocation path; default `true` per 34-RESEARCH.md's
    // HIGH-confidence finding that no fallback is needed. Drop is never disabled (TRAY-03
    // carries no such risk, D-09).
    var airDropAvailable: Bool = true
    var mailAvailable: Bool = true

    // The single shared morph identity (D-07): the collapsed and expanded blobs both
    // morph against this one geometry group via matchedGeometryEffect(id: "island").
    @Namespace private var ns

    // Debug session `liquid-glass-anim-missing`, round 5 (2026-08-01) — round 4's
    // `glassTransitionActive`/`.onChange(of: presentation)` shader-swap machinery lived here
    // (removed; see `liquidGlassEffectLayer` for the full round-1..4 history and why on-device
    // it changed nothing — the fallback legacy shader is JUST as GPU/Metal-shader-composited as
    // native `.glassEffect()`, so swapping between them was never going to matter). Round 5's
    // fix instead gives the glass overlay a `.matchedGeometryEffect(id: "island", in: ns,
    // isSource: false)` FOLLOWER tag — same id/namespace the outer shape already uses as the
    // (isSource: true, default) LEADER — so the glass content continuously tracks the shape's
    // own animated frame every tick, instead of only being told the shape's CURRENT resolved
    // size once at each insertion. No new state, no timers, no fallback renderer swap.

    // Size seeds (D-06: expanded is only modestly larger than the notch). Plan 03
    // sizes the panel to `expandedSize` up front (via expandedNotchFrame) so the
    // morph never clips mid-animation, and passes the SAME expandedSize so the
    // window matches this content. Tunable on-device in Plan 05.
    // D-01 — this is now the FALLBACK seed ONLY. The collapsed pill's real size comes from the
    // measured notch published on `interaction.collapsedNotchSize` (see collapsedIsland). This
    // 200x38 is used solely when no notch is measured — an external / non-notch display, or the
    // DEBUG #Previews which construct the view with a nil measured size — the same nil-propagating
    // contract the geometry layer already uses.
    static let collapsedSize = CGSize(width: 200, height: 38)
    // Height fits the tallest expanded content WITH a top notch-clearance band. The island
    // is pinned top-flush to the screen edge, so the top 32pt sits UNDER the physical camera/
    // notch band (== wingsSize.height, the measured notch height on this machine). The
    // mediaExpanded content must therefore START below that band or the camera cuts off the
    // title (on-device UAT). Height math:
    //   32 (top notch clearance — nothing renders under the camera)
    // + 100 (mediaExpanded content: HStack art 40 + spacing 6 + progress row 20 + spacing 6
    //         + transport row 28)
    // + 12 (bottom inset — room for the bottomCornerRadius:20 curve)
    // = 144.
    // The panel window (expandedNotchFrame) and the SwiftUI content frame both derive from
    // THIS one value, so the island actually GROWS taller (expands further), not just shifts
    // content in a fixed box. mediaExpanded pins its content to the top with .padding(.top,32)
    // so the clearance lands exactly at the camera band.
    // Quick task 260714-3k6 — width bumped 360 -> 420 (+60pt / ~17%) per user feedback that the
    // panel read too narrow for its content. 420 reuses the width already established for
    // onboardingSize below (no new magic number). Height unchanged — the "too tall" complaint
    // is the shelf-strip gating fixed separately (see shelfStripVisible), not a geometry issue.
    static let expandedSize = CGSize(width: 420, height: 144)

    // CHG-01 / Pattern 4 — the flat wings (Alcove sideways) seed. Single source of truth:
    // Plan 03 feeds this SAME size into NotchGeometry.wingsFrame so the panel frame matches
    // this content (no runtime resize). Tuned on-device against the MEASURED notch (179×32 pt
    // on this machine): the 32 pt height matches the notch so the strip sits flush and never
    // overhangs below it, and the 305 pt CHARGING width leaves room for the battery glyph + %.
    // The panel is sized to the UNION with the 360-wide expanded frame, so this only sizes the
    // visible black strip, never the window. The pure wingsFrame tests build their own size,
    // so this constant tunes freely.
    // Post-checkpoint (user request): ONE uniform 290 pt width across all three wing glances
    // (charging, media, device) so the island reads consistently regardless of activity.
    static let wingsSize = CGSize(width: 290, height: 32)

    // SHAPE-02 (Phase 71) — wing-state base corner radii, scaled up 4/3x from the original
    // 12/6 pair (16 = 12*4/3, 8 = 6*4/3), preserving the 2:1 top:bottom ratio. Sum (24) stays
    // under the 25.6pt depth-scale-floor wings height (32 * 0.8 minimum depthScale).
    static let wingBaseTopCornerRadius: CGFloat = 16
    static let wingBaseBottomCornerRadius: CGFloat = 8

    // Round N (HUD-01/HUD-02 label-clip fix) — 290pt isn't wide enough once a "Charging"/
    // "Connected" text label sits next to the left icon. The wings strip is centered over the
    // PHYSICAL notch cutout (measured 179pt wide on this machine, see wingsSize comment above);
    // only the ~55pt flanks on either side of that cutout are actually visible pixels — anything
    // drawn further in renders UNDER the camera housing and is invisible (same root cause
    // BatteryIndicator's doc comment already called out for the % number). Measured with the
    // real system font/symbols this app uses (12pt semibold rounded "Connected" ≈ 63.5pt, widest
    // device glyph "airpodspro" ≈ 20pt): the left content needs ≈100pt of flank, so the total
    // strip must grow to ≈179 + 2×~110 ≈ 400pt to keep the full label clear of the cutout, with
    // a small margin. Only used for the LABEL-bearing positive states (isCharging/isConnected);
    // the negative/dimmed icon-only states keep the original 290 (unchanged, already correct).
    // Stays comfortably under expandedSize.width (420), so the already-unioned panel frame needs
    // no changes. Tune further on-device if the real notch width differs from the 179pt seed.
    //
    // Round N+1 (post-77ecd18 checkpoint, user request) — this value used to widen the WHOLE
    // symmetric wingsShape frame (both flanks equally), which over-widened the right flank
    // (BatteryIndicator/ring/xmark) even though only the left (icon+label) content needed the
    // extra room. `wings(for:)`/`deviceWings(for:)` now pass `wingsLabelWidth / 2` as ONLY the
    // `leftWidth` half; `rightWidth` always stays `wingsSize.width / 2` (its content never grows).
    // See wingsShape's alignmentGuide for how the two halves size independently while staying
    // centered on the physical notch.
    static let wingsLabelWidth: CGFloat = 400

    // Phase 42 / DUAL-01 (D-05/D-07/D-08) — the secondary bubble's size + gap from the
    // primary pill. 24pt is the bottom of UI-SPEC's 24-28pt range (subordinate to the 32pt
    // wing/pill height, D-07); 8pt is the `sm` 8-point-scale gap token (visible, non-touching
    // separation, D-08). Small geometry constants get tuned on-device against real hardware —
    // same precedent as wingsSize/wingsLabelWidth above (Phase 39/41) — so both are tunable in
    // Plan 42-04's checkpoint.
    static let secondaryBubbleDiameter: CGFloat = 24
    static let secondaryBubbleGap: CGFloat = 8

    // WR-03 gap closure (42-REVIEW.md) — the bubble's center offset from the notch center,
    // derived from the named constants above instead of repeated as a bare literal (`220`) at
    // both this file's own render site and NotchWindowController's click-through hot-zone math.
    // A future on-device tune of wingsLabelWidth/secondaryBubbleGap now updates BOTH sites from
    // this single source, closing the exact desync class CR-01/CR-02 (28-REVIEW.md) already hit.
    static var secondaryBubbleCenterOffset: CGFloat {
        wingsLabelWidth / 2 + secondaryBubbleGap + secondaryBubbleDiameter / 2
    }

    // Phase 63 / MEET-02 (Plan 04, D-09) — meetingWings' two locked 63-UI-SPEC.md Spacing-Scale
    // values, hoisted to statics for the exact same WR-03 reason as secondaryBubbleCenterOffset
    // above: NotchWindowController.collapsedInteractiveZone() must widen the collapsed
    // click-through hot-zone to the mute icon's REAL rendered screen position, and repeating the
    // number there as a bare literal is the CR-01/CR-02 desync class this file already fixed once.
    //   margin 20 — the "short, icon-adjacent" camera-clearance class (downloadWings/plain
    //     countdownWings), NOT capsLockWings'/Pomodoro's 65.
    //   rightContentWidth 84 — mm:ss text box 60 + 4pt gap + 20pt mute icon.
    // Quick task 260729-0zh — fixes the documented no-op: reuses the existing Wing Tuner Margin
    // nudge key (debugWingMarginNudgeKey) so the Meeting wing's Margin axis actually moves the
    // rendered icon AND the click-through zone together, since both read this single property.
    static var meetingWingMargin: CGFloat {
        #if DEBUG
        return 20 + UserDefaults.standard.double(forKey: ActivitySettings.debugWingMarginNudgeKey)   // +20 reverted per user request, back to original
        #else
        return 20
        #endif
    }
    static let meetingWingRightContentWidth: CGFloat = 84
    // WR-05 (63-REVIEW.md) — the mute icon's OWN width, hoisted for the same reason as the two
    // above: the click-through zone must now cover just the icon's footprint rather than the
    // whole 104pt band out to it, or a standing call HUD makes that entire strip of menu bar
    // unclickable for the call's full (potentially hours-long) duration. meetingWings(for:)
    // asserts this still equals its locally-derived width.
    static let meetingMuteIconWidth: CGFloat = 20

    // How far past the raw notch cutout's trailing edge the mute icon's own far edge sits. Read by
    // BOTH meetingWings(for:)'s render math and collapsedInteractiveZone()'s widen, so a future
    // on-device retune of either constant above moves the rendered icon and the clickable region
    // together. (The wing's 12pt trailingPad sits OUTSIDE this offset — it is padding after the
    // icon, not part of the icon's footprint.)
    static var meetingMuteIconTrailingEdgeOffset: CGFloat {
        meetingWingMargin + meetingWingRightContentWidth
    }

    // 39-07 gap closure ROUND 9 — RETRACTED. This constant (formerly `cameraSafeZoneLeadingInset =
    // 100`) was derived from an on-device DEBUG-only ruler and treated as "the real camera boundary
    // in local coordinates" — but it was measuring a CONFOUNDED quantity, not pure camera occlusion:
    // 3 rounds built on it (7, 8, and this one) each still failed on real hardware in ways the
    // constant alone couldn't explain (getting SMALLER/more hidden each round despite the formula
    // being internally self-consistent every time). Root cause: this file already has a PROVEN,
    // live-measured source of the real notch geometry — `interaction.collapsedNotchSize` (published
    // by `NotchWindowController.positionAndShow()` from `notchSize(...)`, the exact unfudged cutout
    // macOS reports — see `collapsedIsland` below, which already sizes the idle pill to this EXACT
    // value and is proven correct simply by existing/shipping: a wrong value there would show up
    // immediately as a black pill that doesn't match the physical notch, or a broken click-through
    // hot-zone). `osdWings(for:)` now reads that live value directly instead of a hardcoded/
    // empirically-guessed constant — see that function's own ROUND 9 comment for the corrected
    // derivation.

    // Phase 25 / VISUAL-01 (D-01/D-02) — the shared black-to-transparent vertical gradient
    // material. Single source of truth for every fill site below (collapsedFill, blobShape,
    // wingsShape, mediaWingsOrToast) so the collapsed pill, expanded island, and all activity
    // wings render the SAME material, matching the iPhone Dynamic Island look. Pure black only
    // (D-01: no grey mixed in) with a long opaque stretch and only a ~50% floor at the very
    // bottom edge (D-02: never `.clear`) — starting values, tuned on-device in Task 3.
    private static let gradientMaterial = LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.65),
            .init(color: .black.opacity(0.5), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    // Phase 27 / VISUAL-03 (D-06) — the flat Solid Black alternative material, selected via
    // the Theming preference instead of the gradient above.
    private static let solidBlackMaterial = Color.black
    // Phase 27 / VISUAL-03 (D-06) — the single source of truth all 4 fill sites below read:
    // branches Gradient vs Solid Black per `materialStyle`, type-erased via AnyShapeStyle since
    // the two branches (LinearGradient vs Color) are not the same concrete ShapeStyle type.
    private var islandFill: AnyShapeStyle {
        switch materialStyle {
        case .gradient: return AnyShapeStyle(Self.gradientMaterial)
        case .solidBlack: return AnyShapeStyle(Self.solidBlackMaterial)
        // Phase 72.1.1 Plan 03 on-device UAT (D-01 gap-closure, RESOLVED) — must NOT be the
        // literal `Color.clear` constant: on-device testing hung hover-to-expand entirely, TWICE
        // (commits 96b8a3b, eab8a24), while 0.01 and this 0.0001 value both worked fine — no
        // hang at either nonzero alpha, only at exactly 0.0. That gap (fine at 0.01, fine at
        // 0.0001, hangs only at literal 0.0) rules out "amount of transparency"/rendering-cost as
        // the cause; it points at SwiftUI (or `.glassEffect()`'s own backing implementation)
        // special-casing the literal `Color.clear` value/type as "nothing to render" and skipping
        // a real backing layer for `.glassEffect()` to composite against — a genuinely nonzero
        // alpha, however small, avoids whatever that special case is. `0.0001` is visually
        // indistinguishable from true transparency and is the settled value — do not swap this
        // back to `Color.clear` without a fix for the underlying special-case behavior.
        case .liquidGlass: return AnyShapeStyle(Color.black.opacity(0.0001))
        }
    }

    // Phase 35 / GLASS-01 (D-01/D-03/D-04/D-12/D-13/D-14/D-15, supersedes D-02/D-10/D-11) —
    // the Liquid Glass warp + chromatic-fringe overlay, applied at all 4 island-shell fill
    // sites immediately after their existing `.frame(...)`. Renders nothing unless
    // `.liquidGlass` is selected, so `.gradient`/`.solidBlack` are pixel-identical to before
    // this plan. `.allowsHitTesting(false)` (D-03) keeps this decorative-only, never
    // intercepting the shape's own tap/drag gestures — mirrors this project's CR-01
    // click-through precedent.
    //
    // Round-3 layering order (D-12/D-13/D-14/D-15, supersedes round 2's D-10/D-11): the
    // warped `.ultraThinMaterial` backdrop sits at the BACK of the ZStack with no opacity
    // ramp of its own — round 2's mistake was ramping this layer's alpha directly, which
    // reads as uniformly bright since the material has no inherent dark tint. In FRONT of
    // it sits a solid dark frost layer (`Self.gradientMaterial`, the same D-12 base
    // `islandFill`'s `.liquidGlass` branch returns), whose own alpha is ramped by the
    // SAME `liquidGlassEdgeOpacity` colorEffect/falloff round 2 used — near-opaque toward
    // the center (D-15: allowed as dark as `.solidBlack`), thin/transparent right at the
    // rounded edge (D-12/D-13/D-14) — masking the material everywhere except a narrow rim.
    // The 3 chromatic-fringe passes, `.saturation`, `.overlay(Color.white.opacity(...))`,
    // `.clipShape`, and `.allowsHitTesting(false)` are all unchanged from before this plan.
    //
    // Round-4 addendum (D-16/D-17/D-18, `35-CONTEXT.md`): round 3 was rejected on-device
    // ("immer noch so komisch silbern") — root cause, the 3 `.blendMode(.screen)` fringe
    // passes and the trailing white-wash overlay composited across the WHOLE shape with no
    // masking of their own, so they washed the frost layer's dark center toward grey
    // regardless of how dark that frost was tuned. D-16 masks all 4 of those layers to the
    // SAME `liquidGlassEdgeOpacity` falloff the frost layer already uses, via the new
    // `rimMask` Shader below (identical function, inverted mask-only arguments: full
    // visibility at the rim, fully invisible at the interior) — they now fade to invisible
    // by the frost's dark center instead of lightening it. D-17: the white-wash overlay is
    // masked, not removed — it now reads as a rim highlight. D-18: the rim band itself is
    // not widened — `rimMask` reuses `parameters.borderWidth`/`parameters.blurWidth` verbatim,
    // identical to the frost layer's own band.
    //
    // Reuses the exact `liquidGlassEdgeOpacity` Metal function already shipped in Plan
    // 35-06/35-09, called with mask-only literal arguments (`edgeOpacity: 1.0,
    // centerOpacity: 0.0`) instead of the frost's own `parameters.edgeOpacity`/
    // `parameters.centerOpacity` — same underlying `liquidGlassEdgeFalloff` curve (t=0 at
    // the shape boundary, t=1 at the interior), opposite consumer-side intent: "fully
    // visible at rim, invisible at center" rather than the frost's "invisible at rim,
    // opaque at center". Zero `.metal`/`LiquidGlassParameters` changes.
    // WR-01 (35-REVIEW.md): shared by the frost layer's own edge-opacity ramp
    // and liquidGlassRimMask below — both call the same Metal function with
    // the same 5-argument prefix, differing only in the trailing edge/center
    // opacity values. Centralizing the argument list here means a future
    // shader-signature change only needs updating in one place; a Metal
    // [[stitchable]] argument-order mismatch fails silently at runtime, not
    // at compile time, so keeping the two call sites hand-synced was a risk.
    private func liquidGlassOpacityShader(
        shape: NotchShape, size: CGSize, parameters: LiquidGlassParameters,
        edgeOpacity: CGFloat, centerOpacity: CGFloat
    ) -> Shader {
        Shader(
            function: .init(library: .default, name: "liquidGlassEdgeOpacity"),
            arguments: [
                .float2(size), .float(shape.topCornerRadius), .float(shape.bottomCornerRadius),
                .float(parameters.borderWidth), .float(parameters.blurWidth),
                .float(edgeOpacity), .float(centerOpacity)
            ]
        )
    }

    private func liquidGlassRimMask(shape: NotchShape, size: CGSize, parameters: LiquidGlassParameters) -> Shader {
        liquidGlassOpacityShader(shape: shape, size: size, parameters: parameters, edgeOpacity: 1.0, centerOpacity: 0.0)
    }

    // Round-5's `LiquidGlassRimRingShape`/`liquidGlassRimBandWidth` (confined the native
    // glass to a narrow rim band) were removed in Phase 72.1.1 Plan 03 (D-01) once the
    // native branch below was scaled back to the bare full `shape` — this was their only
    // consumer; see comments at the native branch and NotchShape.swift for the still-live
    // `topCornerRadius`/`bottomCornerRadius` convention they used to reference.

    // Debug session `liquid-glass-grey-rim-regression` (round 3, 2026-07-16) — user
    // reviewed callstack/liquid-glass (a wrapper around Apple's real Liquid Glass API)
    // and explicitly pivoted away from continuing to hand-tune the custom Metal shader
    // approximation below. On macOS 26.0+ this now renders the REAL system Liquid Glass
    // material via SwiftUI's native `.glassEffect(_:in:)` (Apple docs confirm signature
    // `glassEffect(_ glass: Glass = .regular, in shape: S, isEnabled: Bool = true)`,
    // available macOS 26.0+/iOS 26.0+). `.regular.tint(...)` keeps it reading dark/
    // near-black per D-15's "allowed as dark as .solidBlack" intent — exact tint alpha
    // is a starting point, same on-device-tunable convention as every constant in
    // LiquidGlassShader.swift. Below macOS 26.0, the existing hand-tuned shader stack
    // (warp distortion + frost + 3 chromatic-fringe screen-blend passes + rim mask) is
    // UNCHANGED as the fallback — both branches type-check regardless of the machine's
    // actual OS version (Swift compiles all `#available` branches unconditionally), and
    // this build machine runs macOS 26 (Tahoe) so the native branch is what actually
    // executes here.
    @ViewBuilder
    private func liquidGlassEffectLayer(shape: NotchShape, size: CGSize, parameters: LiquidGlassParameters) -> some View {
        if materialStyle == .liquidGlass {
            if #available(macOS 26.0, *) {
                // Debug session `liquid-glass-black-during-transition`, round 2 — reverted the
                // GlassEffectContainer + .glassEffectID("islandRim", in: ns) cross-case morph
                // attempt (bc04457/f107faa follow-up). On-device it made the ENTIRE island read
                // as uniform frosted glass (not just the rim) at all times, a worse regression
                // than the original momentary flat-black-during-transition bug it targeted.
                // Apple's docs say GlassEffectContainer should only style views tagged
                // `.glassEffect(...)`, but wrapping the whole `presentationSwitch` in one
                // empirically broke the rim-only clipping to `LiquidGlassRimRingShape`. Reverted
                // to the bare, per-call-site `.glassEffect(_:in:)` at the time.
                //
                // Phase 72.1.1 Plan 03 (D-01) — scaled the glass region from the round-2
                // `LiquidGlassRimRingShape` rim ring back to the bare full `shape`, superseding
                // round 2's rim-only scope note above (that regression was about container
                // SCOPE, not the shape's own extent — the narrow container scope from Plan 01 is
                // kept, only the `in:` shape argument changes here). Tint deepened to
                // `0.7 + glassTintNudge` (Plan 72.1.1-02's live nudge) so the wider surface still
                // reads dark per D-15, and a tunable specular top-highlight stroke layered above
                // makes the full surface read as glossy glass rather than flat tinted material.
                // Phase 72.1.1 Plan 03 on-device UAT (D-01 gap-closure) — DROPPED the explicit
                // `.frame(width: size.width, height: size.height)` this `Color.clear` used to
                // carry. `size` is a plain computed CGSize (baseWidth/totalHeight etc., freshly
                // recomputed per call site), never itself driven through `matchedGeometryEffect`
                // — a hardcoded `.frame()` here SNAPPED this layer straight to that static target
                // size every render instead of tracking the outer `.overlay()`'s parent frame
                // (which SwiftUI proposes at the PARENT's live, matchedGeometryEffect-animated
                // size at every intermediate animation tick). Root cause of the on-device finding
                // that the collapse<->expand size morph turned into a plain cross-fade once the
                // glass region grew to cover the whole shape (Task 1): the defect existed since
                // Plan 01 too, just invisible on a thin rim. Removing the explicit frame lets
                // `Color.clear` inherit `.overlay()`'s default sizing (fills whatever size the
                // base shape resolves to at each moment), the same way the sibling specular
                // highlight stroke below already does with no frame of its own.
                // Phase 72.1.1 Plan 03 on-device UAT (D-01 gap-closure, saturation, RESOLVED) —
                // `Glass` exposes exactly 3 static styles (`.regular`/`.clear`/`.identity`,
                // confirmed via SwiftUICore's own textual .swiftinterface, SDK MacOSX26.5) and
                // only 2 modifiers (`.tint(_:)`/`.interactive(_:)`) — no saturation/vibrancy knob
                // anywhere in the public API, so the color-boost Apple's Liquid Glass applies to
                // backdrop content isn't independently tunable from this app. `.clear` (tested
                // on-device against `.regular`) is the user-approved style — confirmed look is
                // acceptable as-is.
                //
                // Debug session `liquid-glass-anim-missing`, round 2 (2026-08-01) — removed the
                // `GlassEffectContainer` + `.glassEffectID("islandGlass", in: glassNS)` pairing
                // Plan 01/03 above had added. Two independently-instantiated containers
                // (collapsedIsland's vs blobShape's) never coexist in the tree, so the
                // documented glassEffectID morph never actually engaged — on-device this was
                // confirmed pure dead weight (zero observable change with it removed). Bare
                // `.glassEffect()` now inherits `.overlay()`'s live per-frame parent size like
                // any other view, same as Gradient/Solid Black already do.
                //
                // Round 3 (2026-08-01) — tried Apple's fully-documented mechanism instead:
                // merged `.idle` into the 8-case switcher-row arm and wrapped that merged arm's
                // REAL CONTENT (not just this decorative layer) in one shared, persisting
                // `GlassEffectContainer`. On-device this was WORSE than round 2's hard-cut
                // baseline: the entire expanded Home view's content stopped rendering (only 4
                // small glyphs stayed visible), AND the previously-fine OSD wing-to-wing
                // animation broke too. Reverted in full — GlassEffectContainer/glassEffectID is
                // now a confirmed dead end at every scope tried (whole body, whole
                // presentationSwitch, and this narrower 2-case merge) and should not be
                // retried.
                //
                // Round 4 (2026-08-01, REVERTED round 5) — tried sidestepping the native glass
                // compositor entirely during the transition by swapping to
                // `legacyLiquidGlassEffectLayer`. On-device this changed nothing: the legacy
                // shader is JUST as Metal/GPU-shader-composited (`.distortionEffect`/
                // `.colorEffect`) as native `.glassEffect()` is — swapping between two
                // GPU-shader-backed renderers was never going to fix anything, since NEITHER
                // participates in the outer shape's `matchedGeometryEffect`-driven insert/remove
                // morph on its own. Removed the `glassTransitionActive` state/timer/onChange
                // entirely (see `ns`'s declaration comment above).
                //
                // Round 5 (2026-08-01) — the outer shape's OWN `matchedGeometryEffect(id:
                // "island", in: ns)` (isSource: true, default) is PROVEN to smoothly bridge the
                // collapsed<->home insert/remove morph (that's why Gradient/Solid Black, whose
                // only visible content IS that shape's plain fill, already animate perfectly).
                // The glass overlay never carried any tag of its own in that same system — every
                // round 1-4 fix instead reached for Apple's SEPARATE glassEffectID/
                // GlassEffectContainer morph mechanism, confirmed a dead end at every scope tried
                // (round 2/3 Eliminated entries). Tagging this content as a FOLLOWER
                // (`isSource: false`) in the SAME "island" id/`ns` namespace the shape already
                // uses lets it continuously track the shape's own already-working animated frame
                // every tick, instead of only snapping to the newly-inserted branch's static
                // resolved size.
                // Debug session `liquid-glass-release-black` (2026-08-01) — root cause of a
                // Debug-vs-Release rendering divergence (Release showed near-opaque black,
                // Debug showed correctly translucent glass): glassTintNudge/glassGlossNudge are
                // `#if DEBUG`-gated by design (dev-tool-only nudges, see their declaration
                // comment) — they'd been live-tuned to tintNudge=-0.7/glossNudge=+0.2 on-device
                // and confirmed looking right in Debug, but never baked into these literals nor
                // reset, so Release silently fell back to the stale pre-tuning 0.7/0.15 base
                // values (the Debug build was reading the tuned UserDefaults nudge; Release
                // always reads 0). D-15 (Phase 72.1.1, "tint deepened to 0.7 ... reads dark")
                // is SUPERSEDED by this on-device re-tuning — confirmed by the user's own
                // side-by-side comparison, Debug's untinted-clear look is the intended one now.
                ZStack {
                    Color.clear
                        .glassEffect(.clear.tint(Color.black.opacity(0.0 + glassTintNudge)), in: shape)
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35 + glassGlossNudge), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1.5
                        )
                        .clipShape(shape)
                }
                .allowsHitTesting(false)
                .matchedGeometryEffect(id: "island", in: ns, isSource: false)
            } else {
                legacyLiquidGlassEffectLayer(shape: shape, size: size, parameters: parameters)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func legacyLiquidGlassEffectLayer(shape: NotchShape, size: CGSize, parameters: LiquidGlassParameters) -> some View {
        if materialStyle == .liquidGlass {
            // Phase 72.1.1 Plan 03 (D-01) — LiquidGlassParameters.collapsed/.expanded are
            // `static let` and cannot read `@AppStorage`-backed instance properties directly
            // (see this file's own islandWidthScaleOffset convention). Nudges are applied here,
            // at the read site, into a local tunedParameters value consumed by everything below
            // instead of the raw `parameters` argument.
            let tunedParameters = LiquidGlassParameters(
                borderWidth: parameters.borderWidth + glassLegacyBorderWidthNudge,
                blurWidth: parameters.blurWidth,
                distortionScale: parameters.distortionScale,
                redOffset: parameters.redOffset,
                greenOffset: parameters.greenOffset,
                blueOffset: parameters.blueOffset,
                saturation: parameters.saturation,
                backgroundOpacity: parameters.backgroundOpacity,
                edgeOpacity: parameters.edgeOpacity + glassLegacyEdgeOpacityNudge,
                centerOpacity: parameters.centerOpacity + glassLegacyCenterOpacityNudge,
                fringeOpacity: parameters.fringeOpacity
            )
            let shaders = liquidGlassChannelShaders(
                size: size,
                topCornerRadius: shape.topCornerRadius,
                bottomCornerRadius: shape.bottomCornerRadius,
                parameters: tunedParameters
            )
            let rimMask = liquidGlassRimMask(shape: shape, size: size, parameters: tunedParameters)
            ZStack {
                shape.fill(.ultraThinMaterial)
                    .distortionEffect(
                        shaders.base,
                        maxSampleOffset: CGSize(width: abs(tunedParameters.distortionScale), height: abs(tunedParameters.distortionScale))
                    )
                shape.fill(Self.gradientMaterial)
                    .colorEffect(
                        liquidGlassOpacityShader(
                            shape: shape, size: size, parameters: tunedParameters,
                            edgeOpacity: tunedParameters.edgeOpacity, centerOpacity: tunedParameters.centerOpacity
                        )
                    )
                shape.fill(Color.red.opacity(tunedParameters.fringeOpacity))
                    .distortionEffect(
                        shaders.red,
                        maxSampleOffset: CGSize(
                            width: abs(tunedParameters.distortionScale) + tunedParameters.redOffset,
                            height: abs(tunedParameters.distortionScale) + tunedParameters.redOffset
                        )
                    )
                    .colorEffect(rimMask)
                    .blendMode(.screen)
                shape.fill(Color.green.opacity(tunedParameters.fringeOpacity))
                    .distortionEffect(
                        shaders.green,
                        maxSampleOffset: CGSize(
                            width: abs(tunedParameters.distortionScale) + tunedParameters.greenOffset,
                            height: abs(tunedParameters.distortionScale) + tunedParameters.greenOffset
                        )
                    )
                    .colorEffect(rimMask)
                    .blendMode(.screen)
                shape.fill(Color.blue.opacity(tunedParameters.fringeOpacity))
                    .distortionEffect(
                        shaders.blue,
                        maxSampleOffset: CGSize(
                            width: abs(tunedParameters.distortionScale) + tunedParameters.blueOffset,
                            height: abs(tunedParameters.distortionScale) + tunedParameters.blueOffset
                        )
                    )
                    .colorEffect(rimMask)
                    .blendMode(.screen)
            }
            .saturation(tunedParameters.saturation)
            .overlay(Color.white.opacity(tunedParameters.backgroundOpacity).colorEffect(rimMask))
            .clipShape(shape)
            .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }

    // Phase 18 / NOW-05 — post-checkpoint ROUND 3 (on-device feedback, supersedes round 2's
    // standalone `toastSize` blob below): the user rejected a separate replacement shape and
    // asked for the EXISTING wings glance to stay pixel-identical, with a small text row
    // fading in BELOW it in ONE continuous shape (DynamicLake reference, "leicht weiter nach
    // unten expandieren und den titel mit Sänger rein faden" — expand slightly further down
    // and fade the title+artist in). 32pt is enough for one ~12pt text line plus padding;
    // added to wingsSize.height (32) the combined shape is only ~64pt tall total — modestly
    // taller than the plain wings, nowhere near expandedSize's 144pt or even round 2's 56pt-
    // tall standalone blob.
    static let toastExtraHeight: CGFloat = 32

    // Phase 20 / SHELF-03 — the shelf row's own height. Box math (20-UI-SPEC.md Layout Notes):
    // 28pt icon (matches transportButton's established 28x28 touch size) + 2pt icon-gap + ~11pt
    // caption line + ~7.5pt top/bottom padding x2 ~= 56pt. SINGLE SOURCE OF TRUTH: Plan 20-02's
    // NotchWindowController.positionAndShow panel-sizing math must read from THIS constant, never
    // re-derive it.
    static let shelfRowHeight: CGFloat = 56

    // Phase 28 / CALVIEW-01 (28-UI-SPEC.md Layout Contract "Switcher pill") — the
    // Home/Tray/Calendar switcher's own reserved row height, appended below `blobShape`'s
    // content the same architectural way as `shelfRowHeight` (independent, coexisting growth —
    // see `blobShape`'s `showSwitcher` parameter below). A starting point for on-device tuning.
    static let switcherRowHeight: CGFloat = 44

    // WR-02 fix (28-REVIEW.md) — every switcher-row-showing presentation pins its content below
    // this same measured camera/notch clearance value via `.padding(.top, ...)`; was a bare `32`
    // literal repeated at 7 call sites, unlike shelfRowHeight/switcherRowHeight/
    // switcherContentHeight above, which are already named constants for exactly this reason —
    // a single tuning pass updates every consumer.
    // Gap-closure (30-04): +10pt over the original 32 (two on-device tuning rounds, +5pt each),
    // per user confirmation of a minor overlap with the physical camera in mediaExpanded's
    // art/title/transport content.
    static let cameraClearance: CGFloat = 42

    // Quick task 260801 — baked-in confirmed on-device Switcher Tuner content-offset values,
    // split by view group after live on-device comparison (mediaContent/"Music Play expanded"
    // needed more clearance than the switcher-row tab group did). `+ switcherContentOffsetNudge`
    // stays appended at each call site so both bases remain independently live-tunable, same
    // convention as wingMarginNudge reused across every wing's own base margin constant.
    // resolvedCameraClearance (below) stays the shared base for every other switcher-row tab
    // not called out by name in this on-device pass (Home empty/unavailable states, Timer,
    // Quick Action picker, onboarding).
    static let mediaExpandedClearance: CGFloat = cameraClearance + 24   // 66 — mediaContent
    static let switcherTabClearance: CGFloat = cameraClearance + 12     // 54 — Calendar/Quick Actions/Weather/Tray

    // Quick task 260801 — baked-in confirmed on-device Switcher Tuner size value: user confirmed
    // Pill and Top Edge switcher icons should match each other, sized smaller than every other
    // navCircleButton caller (onboarding nav, Timer controls) — kept as its OWN constant per the
    // tuner's own print-value guidance ("switcher-only override"), navCircleDiameter untouched.
    static let switcherIconDiameter: CGFloat = navCircleDiameter - 9   // 27

    // 28-04 round 5 (on-device UAT, real Droppy reference screenshots) — the month-grid cell
    // size/gap, shrunk from round 4's 28×28pt/4pt (which round 4's own comment admitted were
    // NOT Droppy-accurate — no real notch-overlay screenshot existed at the time). Two genuine
    // Droppy screenshots now confirm small, tight, numeral-only cells, with the grid column
    // taking a SMALLER fraction of the pill's width than the day-list column gets. Shrinking
    // these two constants both matches the reference visually AND automatically frees width
    // for `dayListColumn` (an HStack sibling with no fixed width of its own — the grid's own
    // intrinsic width is exactly what LazyVGrid claims, so a smaller grid leaves more remainder
    // for the list).
    // 72-02 (D-11) — bumped from 18 to 22 to match reference-macos-calendar-widgets.png's larger
    // day-number glyphs, without colliding with the has-events dot or the cell edge.
    static let calendarCellSize: CGFloat = 22
    static let calendarCellGap: CGFloat = 2

    // 28-04 round 5 (on-device UAT, misclick/notch-close bug fix) — RENAMED from
    // `calendarContentHeight` (28-04 rounds 1-4) and now the ONE shared content-box height for
    // EVERY switcher-row-showing presentation (Home/Tray/Calendar/Weather/NowPlaying), not just
    // Calendar. Root cause this fixes: `blobShape`'s `content()` slot used to size to a
    // PER-CASE height (144pt for Home/Weather/NowPlaying, 266pt for Calendar), and the switcher
    // row is stacked immediately AFTER `content()` in the same VStack — so its ON-SCREEN Y
    // POSITION shifted by ~122pt depending on which tab was active, and a click landing where
    // the switcher USED to be (before the layout reflow settled) could miss it entirely, reading
    // as empty space and collapsing the island instead of switching tabs. Giving every
    // switcher-row presentation this ONE fixed content height makes the switcher pill's screen
    // position PERFECTLY CONSTANT across every tab switch — `blobShape` (below) applies this
    // UNCONDITIONALLY whenever `showSwitcher` is true, so no call site needs its own per-case
    // height override anymore (Home/Tray/Weather/NowPlaying's shorter content simply top-aligns
    // with empty transparent space below it, the SAME `alignment: .top` convention already used
    // everywhere in this file).
    // Box math (round 5, recomputed for the shrunk calendar grid above — the tallest content
    // this constant must fit):
    //   32  (top notch clearance, matches mediaExpanded's .padding(.top, 32) convention)
    // + 20  (month/year header row: chevrons + 13pt semibold label)
    // +  8  (monthGridColumn's own VStack spacing between header and grid)
    // + 118 (WORST CASE 6-row day grid at the round-5 cell size: `daysInMonth(for:)` can pad up
    //        to 6 leading empty cells + 31 real days = 37 cells / 7 columns = 6 rows;
    //        6*calendarCellSize + 5*calendarCellGap = 6*18 + 5*2 = 118)
    // + 18  (bottom inset — room for the bottomCornerRadius:32 curve)
    // = 196.
    // Unlike `expandedSize`, this is a CONTENT height only (excludes switcher/shelf rows,
    // which `blobShape`/`body`'s outer `.frame` still add on top of this — same convention as
    // `expandedSize.height` itself never including those rows).
    static let switcherContentHeight: CGFloat = 196

    // Quick task 260715-vsd gap-closure round 5 — Tray (trayContentHeight, 145) and Weather
    // (weatherMediumContentHeight/weatherLargeContentHeight) already prove that a
    // switcher-row presentation does NOT need to share switcherContentHeight's 196pt: each
    // has its own shorter, content-hugging height override with no reported misclick
    // regression across Phase 32/33's extensive on-device UAT. Home's three sub-states
    // (homeEmptyState/mediaExpanded/mediaUnavailable) get the same treatment here — ONE
    // shared height so the switcher row's Y position stays constant across THOSE three
    // specifically (starting/pausing music must not visibly jump the switcher while sitting
    // on the Home tab), sized to mediaExpanded's real content (the tallest of the three:
    // cameraClearance 42 + art/title/bars row ~40 + spacing 6 + progress bar ~14 + spacing 6
    // + transport row ~32 + bottom padding 12 ≈ 152), with a safety margin since exact SwiftUI
    // row heights aren't measurable from source alone.
    static let homeContentHeight: CGFloat = 170

    // Phase 62-04 UAT design revision (item 5) — the Timer tab's duration/mode picker box.
    // The original inline-in-Home picker used homeContentHeight (170) and badly overflowed
    // for Pomodoro (segmented control + Work section + Break section + button row), rendering
    // past the island edge into the desktop/menu bar behind it (UAT screenshot). Rough content
    // budget for the worst case (Pomodoro): cameraClearance 42 + segmented ~28 + spacing 12 +
    // ("Work" label 14 + spacing 4 + 2-row chip grid ~74) + spacing 8 + ("Break" label 14 +
    // spacing 4 + 2-row chip grid ~74) + spacing 12 + button row 36 ≈ 322, +margin. Countdown
    // mode has slack by comparison — a harmless, deliberate trade-off (one shared box height,
    // same convention switcherContentHeight itself already established for its 6 tabs).
    static let timerSetupContentHeight: CGFloat = 340

    // Phase 48 / OUTPUT-01/02/03 (CR-01 geometry three-site rule, Site 1) — the extra height
    // `tabHeight`'s default case adds when the output panel is open. Plan 48-02's original 140
    // was a rough first-pass estimate (its own fudge math, not the real per-row layout) and left
    // a large empty gap below the panel for the common 2-3 device case — on-device UAT after
    // ship confirmed this. Retuned here using the EXACT layout math instead of a fudge factor:
    // mediaContent's outer VStack(spacing: 6) adds one 6pt gap before the panel; outputPanel's
    // own VStack(spacing: 4) holds N device rows (exactly one outputActiveRowHeight=32 row plus
    // (N-1) outputInactiveRowHeight=28 rows, with (N-1) 4pt gaps between them) — i.e.
    // `6 + 32 + (N-1) * 32`. N=2:70 N=3:102 N=4:134. Tuned as a single static reservation (no
    // dynamic per-N sizing — see below) to the common 2-3 device case (102 + buffer), matching
    // the "size once, tune on-device" convention `homeContentHeight` itself already established.
    // NOT made dynamic on `presentationState.outputDevices.count`: traced whether
    // `positionAndShow()` (Site 2) re-runs when the device list changes live while the panel is
    // open (AudioOutputMonitor -> handleAudioOutputDevicesChanged, Plan 48-01/48-04) — it does
    // NOT; that handler only writes `presentationState.outputDevices`/volume fields, it never
    // calls `resolveAndPosition()`/`positionAndShow()`. Site 1 here is a reactive SwiftUI
    // computed property (updates instantly), but Site 2's NSPanel window frame is a plain func
    // result cached until the next unrelated positionAndShow() trigger — a per-N dynamic value
    // would desync Site 1 from Site 2's actual window bounds the moment a device connects/
    // disconnects while the panel is open (content sized for the NEW count, physical window
    // still sized for the OLD count), reintroducing exactly the click-swallowing regression
    // class CR-01 exists to prevent. A single static reservation avoids that risk entirely, at
    // the cost of a taller-than-needed panel for N>=4 (rare in practice) or up to ~4-8pt
    // remaining gap for N<=3 (accepted). Plan 48-03 mirrors this exact
    // `presentationState.outputPanelOpen` read at Site 2 (`positionAndShow`) and Site 3
    // (`visibleContentZone()`) — see 48-02-PLAN.md's threat model T-48-05.
    static let outputPanelExtraHeight: CGFloat = 120

    // Phase 48 / OUTPUT-01 (D-10..D-13, row-as-volume-bar redesign) — the active device row's
    // full height (row IS the bar, not a separate slider element) and the plain-text inactive
    // row's height. First-pass values, tune on-device.
    static let outputActiveRowHeight: CGFloat = 32
    static let outputInactiveRowHeight: CGFloat = 28

    // Phase 26 / ONBOARD-01 (26-UI-SPEC.md "Panel & Layout Contract") — a single fixed panel
    // size used for ALL 4 onboarding steps, no per-step resize (same "size once, never
    // mid-animation" convention that added wingsSize/toastExtraHeight as sibling constants
    // rather than resizing expandedSize itself).
    // Round 2 on-device UAT (Droppy comparison): widened from 360 to 400 for breathing room
    // around the new pill-shaped permission rows, and grown from 240 to 300 — the original
    // 240 didn't actually fit the Permissions step's heading + 3 rows + nav without squeezing
    // the bottom nav row (the reported "Back/Next partially cut off" was this, not a repeat
    // of the earlier clipping bug).
    // Round 3 on-device UAT: another +20pt/+20pt iteration (400x300 -> 420x320) to give the
    // now-vertically-centered content and the pinned nav row more room to breathe. Still ONE
    // fixed size for all 4 steps, and still a "for now" number, not a final one.
    static let onboardingSize = CGSize(width: 420, height: 320)

    // Phase 32 / TRAY-05 (D-03/D-04) — the widened Tray presentation. `traySize.width` is the
    // value actually consumed by every call site below; `traySize.height` is kept only for
    // CGSize-shape symmetry with expandedSize/onboardingSize and is never read. Gap-closure
    // (on-device UAT round 2: 840 -> 750; round 3: 750 -> 650, "mach breite auf 650pt mal" —
    // both per user request, narrowed each round). `trayContentHeight` is D-06/D-08's ONE
    // shared content-box height for both the empty and non-empty Tray states (unlike
    // switcherContentHeight, this is deliberately SHORTER — content-hugging, not the shared
    // 196pt box): cameraClearance (42) + trayShelfRowTopInset (10) + trayShelfRowHeight (70) +
    // ~16pt bottom margin.
    // Quick task 260715-vsd gap-closure round 2 — 128 -> 133. trayEmptyState's icon->text gap
    // grew +5pt (4pt -> 9pt) in round 1; this tightly content-hugging box (unlike the generous
    // switcherContentHeight box) wasn't grown to match, so the taller content pushed its
    // subtitle text down into the switcher row's own space. +5pt here restores the same
    // buffer that existed before round 1's spacing change.
    // Quick task 260715-vsd gap-closure round 4 — 133 -> 145. Combined with trayEmptyState's
    // spacing: 0 (was 2), gives a much larger, unambiguous gap before the switcher row —
    // round 3's more conservative +5pt/spacing:2 pairing was confirmed too subtle to read as
    // different once the real blocker (unreachable trayEmptyState, see debug session
    // tray-spacing-fix-not-applying) was fixed and the view became visible for the first time.
    static let traySize = CGSize(width: 650, height: 144)
    // Phase 44 UAT gap-closure (round 4) — explicit user override: "Können wir die File Tray
    // genauso so groß machen wie die Ablage zum reinziehen jetzt ist. Die Höhe will ich genauso
    // bei beiden." Ties trayContentHeight directly to quickActionPickerContentHeight (117) so the
    // two can never drift apart again.
    // Code review (44-REVIEW.md WR-02) corrected this comment's original math: `shelfRow`'s
    // OUTERMOST modifier is `.frame(height: rowHeight)` (line ~2029) — `trayShelfRowTopInset` is
    // applied INSIDE that already-height-fixed ScrollView (`.padding(.top, topInset)` on the
    // inner HStack), so it shifts content within the fixed 70pt row rather than adding external
    // height, unlike trayEmptyState's own top padding which genuinely does stack on top of
    // cameraClearance. Real total for a populated Tray: cameraClearance(42) +
    // trayShelfRowHeight(70) = 112, which fits inside 117 with ~5pt to spare — no clipping risk
    // from this constant. Round 6 on-device UAT approved a populated shelf at this height,
    // consistent with this corrected math.
    static let trayContentHeight: CGFloat = quickActionPickerContentHeight

    // Quick task 260715-vsd — the Calendar-only width override. calendarFullView's own
    // `.padding(.horizontal, 16)` is 8pt short of the 24pt wall-inset every NotchShape edge
    // curves in at (this file's own documented convention — see mediaExpanded's
    // `.frame(maxWidth: 322)` comment); combined with `calendarFullView`'s 4% content
    // scale-down, the extra +40pt width gives the right-aligned "+ Add" trigger enough
    // clearance from that curve to render fully inside the visible shape.
    static let calendarWidth: CGFloat = 472
    // Phase 46-02 / CALVIEW-07 (D-08/D-11) — a DEDICATED Calendar-only content height,
    // replacing the shared `switcherContentHeight` (196, unchanged below — Home/Weather/default
    // still read it via `homeContentHeight`/their own case, per `trayContentHeight`'s own
    // per-tab-override precedent). This is a directional starting point, not a final-tuned
    // number: it accounts for `dayEventsList`'s bumped row padding/spacing (D-09) needing a
    // little more vertical room than the 196pt box gave; tune on-device in Plan 46-03 if the
    // real rendered padding bump needs more or less.
    static let calendarContentHeight: CGFloat = 220
    // Gap-closure (on-device UAT round 3) — the shared `shelfRowHeight` (56, sized for the
    // OTHER shelfRow callers' 28x28pt icons) is too short for Tray's 40x40pt icons (Task 3):
    // 40 (icon) + 2 (VStack spacing) + ~13 (9pt filename line, incl. SF Pro Text leading) = ~55pt
    // with ZERO top/bottom breathing room, so the filename clipped past the black shape's own
    // bottom edge (no `.clipped()` on shelfRow, so SwiftUI just let it render past its frame).
    // A dedicated Tray-only override, following the same `height:`-override-wins pattern this
    // plan already uses for trayContentHeight vs switcherContentHeight — `shelfRowHeight` itself
    // stays untouched so Home/Calendar/Weather's dormant (TRAY-01-gated) shelf strip, still
    // built around the original 28x28pt icon size, is unaffected. Sized to fit ~55pt of content
    // + trayShelfRowTopInset (10) = 65pt, with margin (round 8: reverted from rounds 4-5's
    // ever-growing 70/85 — those were compensating for a centering bug in shelfRow's ScrollView,
    // not a real space shortage; now that round 8 fixed the actual centering bug, 70 is enough).
    static let trayShelfRowHeight: CGFloat = 70
    // Gap-closure (on-device UAT round 4-8) — "die files gucken immernoch aus der Island raus".
    // cameraClearance (42) alone clears NotchShape's topCornerRadius (24) with margin, so the
    // curve itself wasn't the culprit. Root cause (found via round 6-7's on-device debug-border
    // diagnostic): `shelfRow`'s `ScrollView(.horizontal)` vertically CENTERS its content by
    // default once an ancestor forces its cross-axis frame taller than the content itself — so
    // rounds 4-5's growing `topInset` just grew the content that then got re-centered, netting
    // out to nearly the same visible gap every time (confirmed: the shape/switcher row visibly
    // grew, but the icon's own position relative to the row's top never moved). Round 8 fixed
    // the actual centering bug (see shelfRow's own comment, `.frame(maxHeight: .infinity,
    // alignment: .top)`), so `topInset` is now a real, linear, un-fought gap — walked back down
    // to a modest, sane value once the underlying mechanism was actually fixed.
    static let trayShelfRowTopInset: CGFloat = 10

    // Phase 33 / WEATHER-01/02 (D-03/D-08) — Weather's two dedicated content heights, mirroring
    // `trayContentHeight`'s "shorter, content-hugging override wins over switcherContentHeight"
    // precedent exactly. Medium is now ALWAYS an explicit height (D-03 — no more nil-falls-
    // through-to-switcherContentHeight case now that the hourly row is a permanent floor);
    // Large adds the daily range-bar list below it. Box math (starting point — flagged for
    // on-device tuning, same as every other constant in this file's history):
    //   Medium: 42 (cameraClearance) + 44 (icon) + 8 (spacing) + 32 (temp) + 8 (spacing)
    // + 16 (location/H-L label lines) + 16 (rowTopPadding) + 53 (hourly chip stack)
    // + 16 (bottom inset) ~= 289, rounded to 290.
    //   Large: Medium's 290 + 12 (dailySectionGap) + 4 daily rows * ~20pt (single-line height at
    // the round-2 12pt font, now that dailyForecastRow's weekday/low/high Texts carry
    // `.lineLimit(1)`) + 3 gaps * 6pt ~= 290 + 12 + 80 + 18 = 400, + 10 margin = 410. Round 3's
    // 480 was sized to hedge against the (since-fixed) overflow/clip bugs — round 5 UAT confirmed
    // the daily list itself renders correctly and compactly now, just with a big empty gap above
    // the switcher row from that leftover margin. `blobShape` clips its content to the island
    // shape (see that function), so any future under-estimate here is a silent crop, not a leak.
    static let weatherMediumContentHeight: CGFloat = 290
    static let weatherLargeContentHeight: CGFloat = 410
    // D-07/D-09 — starting chip/row counts, tune only if they visibly crowd on-device.
    // largeDailyRowCount dropped 5 -> 4 in round 1 UAT gap-closure (more compact Large, see above).
    static let hourlyChipCount = 6
    static let largeDailyRowCount = 4

    // Phase 65 / QACTION-02 (65-UI-SPEC.md Spacing Scale) — the ONE dedicated content height
    // for `.quickActionsBarExpanded`, mirroring `trayContentHeight`/`calendarContentHeight`'s
    // own per-tab-override precedent (a plain `tabHeight` branch, not a fall-through to the
    // Home-shaped `default:` case). Box math: cameraClearance (42) + row 1 tile (36) + row gap
    // (16) + row 2 tile (36) + bottom pad (16) + 4pt rounding slack = 150.
    static let quickActionsBarContentHeight: CGFloat = 150

    // Phase 44 UAT gap-closure (round 2) — quickActionButton() previously used
    // `.frame(maxWidth: .infinity)`, so on the new 650pt-wide picker card (Plan 44-01) the 3
    // chips flex-filled far wider than their pre-Phase-44 size, which broke D-06's "buttons stay
    // the same size" contract and read as loose/sprawled on-device. Fixed at the old flush-edge
    // 420pt-box chip width -- (420 - 2*16 gap) / 3 = 129.33, rounded to 130 -- so the 3 chips now
    // render at their original size and cluster centered in the wider card instead of stretching.
    // computeQuickActionButtonFrames(card:) in DragDropSupport.swift must mirror this exact value
    // for its hit-test math (this codebase's own geometry N-site rule).
    static let quickActionButtonWidth: CGFloat = 130
    // Phase 44 UAT gap-closure (round 2) — hoisted out of a duplicated local `let` inside
    // computeQuickActionButtonFrames(card:) so the hit-test math and the height math below derive
    // from ONE source instead of two copies of the same magic number silently drifting apart
    // (exactly the class of bug round 2 just fixed for the vertical anchor).
    static let quickActionButtonRowHeight: CGFloat = 59   // icon 22 + gap 8 + label ~13 + vPadding 2x8
    // Phase 44 UAT gap-closure (round 3) — "zu viel Rand": D-03/D-05 originally locked the
    // picker's height to the full Tray footprint (trayContentHeight + switcherRowHeight = 189) so
    // the picker would never look smaller than the real landed Tray box (DRAG-02's whole point).
    // On-device, the empty space below the button row (the picker never renders switcher-row
    // content, D-06) read as too much margin, so per explicit user override this round, height no
    // longer matches Tray -- only width (traySize.width, D-04) still does. Reverts to the exact
    // same box-math the original (deleted in round 1) `quickActionPickerContentHeight` used --
    // cameraClearance(42) + buttonRowHeight(59) + bottomMargin(16) = 117 -- now derived from named
    // constants instead of a bare comment, so the three geometry sites (NotchWindowController's
    // frame reservation + contentSize branch, NotchPillView's blobShape call) can't drift from the
    // button row's actual rendered position ever again.
    static let quickActionPickerContentHeight: CGFloat = cameraClearance + quickActionButtonRowHeight + 16

    // Debug session `liquid-glass-black-during-transition` — extracted verbatim out of
    // `body` so it can be wrapped in a GlassEffectContainer (macOS 26+) without
    // duplicating the switch for the pre-26 fallback branch.
    // Phase 6 / COORD-01 / D-05 — the SINGLE arbiter. The view no longer DECIDES
    // precedence (the old `charging > expanded > media-wings > collapsed` if-chain is
    // gone); the controller's pure `resolve(...)` reducer picks ONE `IslandPresentation`
    // and the body just renders it with this switch, mapping each case to the existing
    // private helper. Charging/Device are the rank-1/2 transient splashes (D-02); the
    // controller's queue advances off the single ~3s one-shot dismiss and the resolver
    // falls through to `.nowPlayingWings`/`.idle` so a transient "returns to the wings,
    // not to empty" (D-02 yield-to-ambient). The expanded media-health axis (D-12) rides
    // on the `.nowPlayingExpanded(_, healthy:)` flag.
    @ViewBuilder
    private var presentationSwitch: some View {
        switch presentation {
        case .onboarding(let step):
            // Phase 26 / ONBOARD-01 / D-09 — the forced-flow onboarding carousel
            // (highest priority, resolve(...) puts it first). Plan 26-04 wires the
            // closures below to real controller behavior.
            onboardingCarousel(step)
        case .charging(let a):
            wings(for: a)                                                    // D-02 rank 1 transient
        case .device(let d):
            deviceWings(for: d)                                              // D-02 rank 2 transient
        case .nowPlayingWings(let p):
            mediaWingsOrToast(p)                                             // D-02 collapsed media glance / Phase 18 toast
        case .calendarCountdown(let activity):
            countdownWings(for: activity)  // Phase 41 / HUD-08: ambient, D-01 always wins over nowPlayingWings
        // Phase 45 / SWITCH-01/SWITCH-02 — these 6 cases used to each call `blobShape`
        // independently (6 distinct structural subtrees -> SwiftUI remove+insert on tab
        // switch, the root cause of the disappear/rebuild flicker + dual-switcherRow
        // z-order glitch). Grouping them into ONE case arm to `tabContentView`, which
        // makes the SINGLE remaining `blobShape` call for all 6, gives every case one
        // continuously-identified subtree so `matchedGeometryEffect` morphs it directly.
        case .nowPlayingExpanded, .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .timerSetup, .quickActionsBarExpanded:
            tabContentView
        case .quickActionPicker(let pendingDrop):
            quickActionPickerView(pendingDrop: pendingDrop)                  // Phase 34 / TRAY-02: destination picker
        // Phase 62 / TIMER-01..04 (62-03 Task 2, Pattern 4): the FIRST transient with its OWN
        // dedicated expanded presentation — NOT grouped into tabContentView's switcher-row arm
        // above, since .timerExpanded shows no switcher row (D-08's controls take exclusive
        // priority).
        case .timerExpanded(let activity): timerExpandedContent(for: activity)
        case .focus(let activity): focusWings(for: activity)                 // D-02 rank 3 transient (38-04)
        case .osd(let activity): osdWings(for: activity)                    // Phase 39 / HUD-03/HUD-04: rank 4 transient (39-02)
        case .downloadProgress(let activity): downloadWings(for: activity)  // Phase 61 / DL-01/DL-02: rank 5 transient (61-03)
        case .capsLock(let activity): capsLockWings(for: activity)          // Phase 60 / CAPS-01: rank 6 transient
        case .updateAvailable(let activity): updateWings(for: activity)     // Phase 60 / UPDATE-01: rank 7 transient
        // Phase 62 / TIMER-01/03 (62-03 Task 1): collapsed pill live countdown + completion
        // splash. .timerExpanded is handled by its own dedicated arm above (Pattern 4, placed
        // right after .quickActionPicker), not grouped here.
        case .timer(let activity): timerWings(for: activity)  // Phase 62 / TIMER-01/03: rank 9 transient (62-01)
        case .meeting(let activity): meetingWings(for: activity)  // Phase 63 / MEET-01: rank 3 transient (D-05), collapsed-only always (D-10)
        case .idle:
            idleOrResumePreview                                              // idle pill / Phase 53 hover-resume preview
        }
    }

    // Phase 45 / SWITCH-01/SWITCH-02 — the SINGLE `blobShape` call site shared by all 6
    // switcher-row `IslandPresentation` cases (was 6 independent calls, one per case arm
    // above). `tabWidth`/`tabHeight` (plain CGFloat properties, not a branched View) size
    // it per-case; the trailing closure's inner switch dispatches to the content-only
    // producers, so `switcherRow` (inside `blobShape`) is instantiated exactly once
    // regardless of which tab is active — this is what gives `matchedGeometryEffect` one
    // continuous subtree to morph across instead of tearing down and rebuilding.
    private var tabContentView: some View {
        blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
                  width: tabWidth, height: tabHeight, shelfItems: shelfViewState.items,
                  shelfVisible: shelfStripVisible, showSwitcher: true,
                  switcherLayout: switcherLayout) {
            switch presentation {
            case .nowPlayingExpanded(let p, true):
                mediaContent(p, art: nowPlaying.artwork)
            case .nowPlayingExpanded(_, false):
                mediaUnavailableContent
            case .homeLastPlayed:
                // Phase 30 / HOME-02 (D-04): synthesize a .paused presentation from the
                // sticky last-played snapshot and feed the SAME mediaContent(_:art:) the
                // live state uses -- no second parallel view.
                mediaContent(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                                      artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                             art: nowPlaying.lastKnownTrack?.artwork)
            case .homeEmpty:
                homeEmptyContent
            case .calendarExpanded:
                calendarContent
            case .weatherExpanded:
                weatherContent
            case .trayExpanded:
                trayContent
            // Phase 62-04 UAT design revision (item 6) — Timer's OWN dedicated tab, no
            // longer an inline overlay gated on Home's 3 sub-states.
            case .timerSetup:
                timerSetupPicker
            // Phase 65 / QACTION-02 (Plan 05 Task 2) — the Quick Actions bar's own content.
            case .quickActionsBarExpanded:
                quickActionsBarContent
            default:
                EmptyView()   // unreachable — presentationSwitch only routes here for the 8 cases above
            }
        }
    }

    var body: some View {
        // Fixed expanded-sized container; the pill sits flush at the TOP edge and the
        // expanded content grows DOWNWARD from the notch (RESEARCH Pattern 4: panel is
        // sized to the expanded frame so the morph never clips).
        ZStack(alignment: .top) {
            // Debug session `liquid-glass-black-during-transition`, round 2 — reverted the
            // GlassEffectContainer wrapping tried here (see liquidGlassEffectLayer for why):
            // on-device it made the whole island read as uniform frosted glass instead of just
            // the rim, a worse regression than the momentary flat-black-during-transition bug
            // it was meant to fix. Back to rendering presentationSwitch directly.
            presentationSwitch

            // Phase 42 / DUAL-01 (D-05/D-08/D-09) — the secondary bubble, composed as a SIBLING
            // to presentationSwitch, never a case inside it (presentationSwitch's own switch
            // above is untouched). `resolveSecondary` (Plan 42-01) guarantees this only ever
            // mounts when `presentation == .calendarCountdown`, whose wing always renders with a
            // fixed `rightWidth: Self.wingsLabelWidth / 2` (200pt) — so the bubble's center sits
            // at `Self.secondaryBubbleCenterOffset` (WR-03 gap closure: wingsLabelWidth/2(200) +
            // secondaryBubbleGap(8) + secondaryBubbleDiameter/2(12) = 220pt), right of the
            // shared notch center (x=0 in this ZStack's local space, the same origin every other
            // shape's own `.alignmentGuide(HorizontalAlignment.center)` pins to). `.offset(x:)`
            // CONFIRMED working in THIS specific top-level ZStack by on-device UAT (Plan 42-04
            // Task 3) — unlike the documented 39-07 failure inside `wingsShape`'s OWN nested
            // content ZStack, x-offset renders correctly here.
            //
            // Plan 42-04 Task 3 on-device UAT round 1 fix — the outer `ZStack(alignment: .top)`
            // top-aligns BOTH this bubble and `countdownWings` (the only wing `resolveSecondary`
            // ever pairs it with, rendered via `wingsShape` at a fixed `Self.wingsSize.height`
            // band) to the SAME origin. With no y-offset, the bubble's top edge — not its
            // center — sat flush with the wing's top edge, reading as "pinned to the top edge"
            // instead of centered on the wing's vertical midline (42-UI-SPEC.md "Vertical
            // alignment: Centered on the primary pill's vertical midline"). `secondary` never
            // coexists with `isExpanded` (resolveSecondary only fires from resolve()'s
            // ambient/collapsed branch, never the expanded one — see IslandResolver.swift), so
            // the wing's height is always exactly `Self.wingsSize.height`; no isExpanded gating
            // needed for this offset.
            if let secondary = presentationState.secondary {
                secondaryBubble(secondary)
                    .offset(x: Self.secondaryBubbleCenterOffset, y: (Self.wingsSize.height - Self.secondaryBubbleDiameter) / 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // Phase 21 bugfix (SHELF-06 UAT) — this outer container's height was still the
        // pre-Phase-20 constant, so blobShape's own +shelfRowHeight growth (for
        // expandedIsland/mediaExpanded/mediaUnavailable) was clipped away by THIS frame
        // before ever reaching the screen, even though the AppKit panel itself was sized
        // correctly (visibleContentZone() already used this same hasShelf math for its
        // own, unrelated click-through purpose — that duplication is what let this drift).
        // Phase 26 bugfix (26-04 on-device UAT round 1) — the SAME regression class hit
        // onboardingCarousel: its blobShape grows to onboardingSize.height (240) but this
        // outer frame stayed clamped to expandedSize.height (144), clipping off the
        // bottomCornerRadius curve (squared-off look) and the bottom nav row (Next
        // unreachable) alike. Mirrors the shelf fix exactly — grow this frame for the
        // `.onboarding` case too. Round 2: also branches WIDTH now that onboardingSize is
        // wider than expandedSize (400 vs 360).
        // 28-04 round 5 — replaced the old `isCalendarPresentation`-only branch with
        // `showsSwitcherRow` directly: EVERY switcher-row presentation (not just Calendar) now
        // reserves the shared `switcherContentHeight` box, matching `blobShape`'s own internal
        // height logic below so this outer frame never clips a shape that grew to match. Still
        // unlike onboarding — non-onboarding cases stack the shelf/switcher row additions on
        // top, since (unlike onboarding) their blobShape calls pass real `shelfItems`/
        // `showSwitcher`.
        // SHAPE-01 (Phase 29) — the flare sweep stays entirely within each presentation's own
        // rect (no outward overflow past rect.minX/rect.maxX), so this outer frame needs no
        // extra margin for it, unlike the earlier shoulder-bulge detour.
        // Phase 32 / TRAY-05 — a third isTrayPresentation branch ahead of the isOnboarding
        // fallback, mirroring Pattern 2 exactly (Phase 21 shelf / Phase 26 onboarding round 1):
        // this outer frame must grow/shrink in lockstep with blobShape's own height ternary
        // below, or the wider/shorter Tray content clips or leaves a stale gap. Tray still
        // shows the switcher row (showsSwitcherRow), so + switcherRowHeight is unchanged.
        .frame(width: isTrayPresentation ? Self.traySize.width * resolvedWidthScale : (isCalendarPresentation ? Self.calendarWidth * resolvedWidthScale : (isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width * resolvedWidthScale)),
               height: totalHeight,
               alignment: .top)
        // Phase 32 / TRAY-05 gap-closure (on-device UAT round 1) — root cause of "notch renders
        // far left, hit-zone doesn't match": the AppKit panel/hosting view is now sized to the
        // UNION of every presentation's frame (up to traySize.width=650, positionAndShow()'s
        // panelFrame), but every OTHER presentation still asks for its own narrower fixed width
        // above (420 or less). NSHostingView proposes its own (now up to 650pt) bounds to this
        // root view; a `.frame(width:...)` box smaller than that proposal renders pinned to the
        // view's origin (AppKit top-left) instead of centered, while hotZone/expandedZone/
        // visibleContentZone() are computed from the CORRECT centered geometry (NotchGeometry
        // centers every frame on collapsed.midX) — so clicks land where the invisible, correctly-
        // centered zone is, not where the visually left-shifted content actually renders. Before
        // this phase every union member shared the same 420pt width, so this mismatch never
        // existed. Centering this fixed-size box within the full (up to 650pt) canvas here makes
        // the RENDERED position match the geometry the panel/click-through math already assumes,
        // for every presentation (D-07's top-pinning is preserved via `alignment: .top`).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Debug session `liquid-glass-anim-missing`, round 4's `.onChange(of: presentation)`
        // shader-swap trigger lived here — REVERTED round 5 (see `liquidGlassEffectLayer`'s
        // native branch for the current fix: a `matchedGeometryEffect(isSource: false)` follower
        // tag on the glass overlay itself, no state/timer needed at this level anymore).
        // Finding 15 fix (06-10): the tap-to-toggle gesture no longer lives at this
        // container level. A single ancestor .onTapGesture here would sit ABOVE the
        // transport Buttons nested inside mediaExpanded, and SwiftUI's gesture
        // resolution between an ancestor TapGesture and a descendant Button is not
        // guaranteed — tapping play/pause/skip could also toggle collapse/expand.
        // Instead, .onTapGesture { onClick() } is scoped INDIVIDUALLY onto every
        // case except mediaExpanded's button row: collapsedIsland, expandedIsland,
        // mediaUnavailable each carry their own, and all three wing glances get it
        // "for free" via the shared wingsShape(content:) helper. mediaExpanded adds
        // it ONLY to its top (non-button) HStack. This eliminates the ambiguity by
        // construction rather than relying on undocumented SwiftUI gesture priority.
    }

    // Phase 53 / RESUME-01 — VIEW-LOCAL branch off the existing `.idle` case (Claude's
    // Discretion, 53-CONTEXT.md; see this plan's `<objective>` for the full rationale): NOT a
    // new `IslandResolver`/`IslandPresentation` case, since `resolve(...)` has exactly one call
    // site and threading a hover-flag parameter through it (plus new IslandResolverTests
    // coverage) is a larger diff than this purely-presentational hover affordance warrants.
    // `interaction.isHovering` is the EXISTING AppKit-driven hover signal (global `.mouseMoved`
    // monitor against `collapsedInteractiveZone()`) — no new `@State` hover flag is needed.
    @ViewBuilder
    private var idleOrResumePreview: some View {
        if interaction.isHovering, !interaction.isExpanded, nowPlaying.hasPlayedSinceLaunch,
           let track = nowPlaying.lastKnownTrack {
            resumePreviewWings(track)
        } else {
            collapsedIsland
        }
    }

    // COLLAPSED — the existing black notch pill (D-08 idle-static). Keeps the
    // Phase-1 dev affordance: DEBUG shows a visible red tint + a small downward
    // offset so a first-time builder can SEE width/radius/position over the real
    // notch (D-02); RELEASE ships pure black so it merges with the hardware notch.
    private var collapsedIsland: some View {
        // D-01: size from the REAL measured notch the controller published; fall back to the
        // static 200x38 seed when no notch is measured (non-notch / external display / previews).
        let size = interaction.collapsedNotchSize ?? Self.collapsedSize
        // WR-02 (35-REVIEW.md): hoisted so the visible fill and the rim-mask
        // overlay below always share one shape instance, mirroring blobShape/
        // wingsShape's convention — prevents the two from silently drifting
        // apart on a future corner-radius tuning pass.
        let shape = NotchShape()
        return shape
            .fill(collapsedFill)
            // Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED: SwiftUI's
            // matchedGeometryEffect is itself implemented via an internal frame+offset, so it
            // must be applied BEFORE any local `.frame(...)`, not after. Round 1 had this
            // backwards (matched it to blobShape/wingsShape's "canonical" order, which was
            // itself wrong — see round 3 fix on those too): an explicit `.frame` placed BEFORE
            // `.matchedGeometryEffect` overrides the effect's own size interpolation, breaking
            // the size-morph and producing a shape that slides from a stale anchor instead of
            // growing symmetrically from the shared center — read as the diagonal jump/bounce.
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: size.width, height: size.height)
            // 67.1-06 (D-10) root cause: collapsedNotchSize itself was never stale — D10-TRACE
            // confirmed the notification handler and positionAndShow both report the NEW
            // resolution's values on the very first firing, in both switch directions. The
            // mismatch was purely visual: this frame's `size` can ride along on an ambient
            // animation transaction from an unrelated simultaneous state change, letting
            // matchedGeometryEffect interpolate the live-measured hardware notch size instead
            // of snapping. It must never visibly lag behind the real camera cutout.
            .animation(nil, value: size)
            // Phase 35 / GLASS-01 (D-04): collapsed pill uses the subtler .collapsed
            // parameters.
            .overlay(liquidGlassEffectLayer(shape: shape, size: size, parameters: .collapsed))
            // D-01 (visual half): a subtle "you're in" bounce on hover only — never
            // when expanded. The controller drives this via its spring wrapper at the
            // state mutation. The haptic + the real pointer monitor are Plan 03.
            .scaleEffect(interaction.isHovering && !interaction.isExpanded ? 1.06 : 1.0)
            .offset(y: devOffset)
            .onTapGesture { onClick() }
    }

    // Phase 30 / HOME-03 — the empty state: nothing has played this session. Copied verbatim
    // from `trayEmptyState`'s structure (D-09, LOCKED) with the icon/copy swapped (D-10,
    // LOCKED). Same blobShape/showSwitcher convention every other Home/switcher-row
    // presentation uses.
    private var homeEmptyContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
            Text("Nothing Playing")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Start something in Spotify or Music.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        // Quick task 260715-vsd gap-closure round 3 — the dead gap before the switcher row
        // here is `Self.switcherContentHeight` (196) minus this content's own natural
        // height; it is NOT reducible from inside this view (a round-2 Spacer attempt here
        // had zero visual effect, since the switcher row's Y position is fixed by the shared
        // box height alone, not by how content fills it). switcherContentHeight itself is a
        // hard floor: its 196pt is exactly what calendarFullView's worst-case 6-row month
        // grid needs (see that constant's own box-math comment), shared uniformly across
        // every switcher-row tab specifically to keep the switcher pill's on-screen
        // position constant across tab switches (28-04 round 5 misclick-bug fix — a
        // per-tab box height literally used to make people misclick and collapse the
        // island). Shrinking it here would either reintroduce that regression (if done
        // per-case) or risk clipping Calendar (if done globally). Left as a known, deliberate
        // trade-off pending a product decision — flagged to the user rather than guessed at.
        // Quick task 260714-3k6 gap-closure — was a bare `24`, unlike every other
        // switcher-row presentation (mediaExpanded/calendarFullView/weatherFullView/
        // trayFullView), which all clear the camera/notch band via the shared
        // `Self.cameraClearance` (42) constant. The mismatch sat this empty state's icon
        // noticeably higher/closer to the camera than the playing-state view. Matching the
        // same constant here aligns the vertical position with every sibling presentation.
        .padding(.top, resolvedCameraClearance)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // Phase 65 / QACTION-01/02 — the 8 per-slot action assignments, one independent
    // @AppStorage key per position (mirrors slotLeftOuter etc.'s declaration style, D-03: never
    // a single encoded array). Corrupted/unknown stored values fall back to `.none` (the
    // catalog's own unconfigured-slot sentinel).
    @AppStorage(ActivitySettings.quickActionsBarSlot1Key) private var quickActionsBarSlot1: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot2Key) private var quickActionsBarSlot2: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot3Key) private var quickActionsBarSlot3: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot4Key) private var quickActionsBarSlot4: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot5Key) private var quickActionsBarSlot5: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot6Key) private var quickActionsBarSlot6: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot7Key) private var quickActionsBarSlot7: QuickActionsBarCatalog.Action = .none
    @AppStorage(ActivitySettings.quickActionsBarSlot8Key) private var quickActionsBarSlot8: QuickActionsBarCatalog.Action = .none
    // The 8 independent `.launch`-only per-slot targets — only ever read for the accessibility
    // label ("Open {target}"); this view never passes these into a shell/AppleScript call
    // (LaunchAction.swift, Plan 65-03, owns the actual open).
    @AppStorage(ActivitySettings.quickActionsBarSlot1LaunchTargetKey) private var quickActionsBarSlot1LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot2LaunchTargetKey) private var quickActionsBarSlot2LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot3LaunchTargetKey) private var quickActionsBarSlot3LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot4LaunchTargetKey) private var quickActionsBarSlot4LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot5LaunchTargetKey) private var quickActionsBarSlot5LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot6LaunchTargetKey) private var quickActionsBarSlot6LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot7LaunchTargetKey) private var quickActionsBarSlot7LaunchTarget: String = ""
    @AppStorage(ActivitySettings.quickActionsBarSlot8LaunchTargetKey) private var quickActionsBarSlot8LaunchTarget: String = ""

    // Phase 65 / QACTION-02 (D-04) — the D-04 tap-pulse's local, purely-visual state: which
    // slot index (if any) is currently mid-pulse. Local @State, never round-trips through the
    // controller (mirrors timerSetupMode's own local-UI-state precedent above).
    @State private var quickActionsBarPulsingSlot: Int? = nil

    // Phase 65 / QACTION-01/02 (65-UI-SPEC.md) — renders the 8-slot Quick Actions bar: the
    // empty state for 0 configured slots (mirrors homeEmptyContent's icon/heading/body/
    // cameraClearance structure exactly), or a 2-row x 4-column grid for 1-8 configured slots.
    // `configured` is `orderedQuickActionsBarSlots(_:)`'s own filtered array (Plan 65-01's
    // single source of truth for "which slots are actually configured"); `slots.indices.filter`
    // recovers each configured action's ORIGINAL 0-7 slot position (needed for
    // onQuickActionTap's Int param and the .launch accessibility-label lookup) without
    // reordering anything — orderedQuickActionsBarSlots only filters `.none` out, it never
    // reorders (Plan 65-01-SUMMARY.md).
    private var quickActionsBarContent: some View {
        let slots: [QuickActionsBarCatalog.Action] = [
            quickActionsBarSlot1, quickActionsBarSlot2, quickActionsBarSlot3, quickActionsBarSlot4,
            quickActionsBarSlot5, quickActionsBarSlot6, quickActionsBarSlot7, quickActionsBarSlot8,
        ]
        let configured = orderedQuickActionsBarSlots(slots)
        let configuredIndices = slots.indices.filter { slots[$0] != .none }
        let tiles = Array(zip(configuredIndices, configured))

        return Group {
            if configured.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No Actions Configured")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pick up to 8 actions in Settings → Quick Actions.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Self.switcherTabClearance + switcherContentOffsetNudge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 16) {
                    quickActionsBarRow(Array(tiles.prefix(4)))
                    if tiles.count > 4 {
                        quickActionsBarRow(Array(tiles.suffix(from: 4)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, Self.switcherTabClearance + switcherContentOffsetNudge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // One row of up to 4 tiles, evenly distributed via Spacer() across the full content width
    // (65-UI-SPEC.md Spacing Scale exception — NOT a fixed 16/24px gap) so 1-4 configured tiles
    // stay visually centered regardless of exactly how many are configured.
    private func quickActionsBarRow(_ tiles: [(Int, QuickActionsBarCatalog.Action)]) -> some View {
        HStack(spacing: 0) {
            ForEach(tiles, id: \.0) { pair in
                Spacer()
                quickActionsBarTile(index: pair.0, action: pair.1)
            }
            Spacer()
        }
    }

    // A single tile: reuses navCircleButton verbatim for the circle/glyph/outline chrome
    // (PATTERNS.md: "not a new tile/button style"), with the D-04 uniform tap-pulse (scale
    // 1.0->1.15->1.0 + a white 0->0.3->0 opacity flash behind the glyph, spring response 0.15/
    // damping 0.86 — Phase 39-08's OSD level-bar retune, reused verbatim per 65-UI-SPEC.md)
    // layered on as modifiers, not a new button type. `index`/`action` are plain function
    // parameters captured by value at call time (T-65-09's mitigation) — never a shared/mutated
    // loop variable.
    private func quickActionsBarTile(index: Int, action: QuickActionsBarCatalog.Action) -> some View {
        let mapping = quickActionsBarIcon(for: action, slotIndex: index)
        let isPulsing = quickActionsBarPulsingSlot == index
        return ZStack {
            Circle()
                .fill(Color.white.opacity(isPulsing ? 0.3 : 0))
                .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
            navCircleButton(systemName: mapping.systemName, filled: false, tint: mapping.tint) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.86)) {
                    quickActionsBarPulsingSlot = index
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.86)) {
                        if quickActionsBarPulsingSlot == index { quickActionsBarPulsingSlot = nil }
                    }
                }
                onQuickActionTap(action, index)
            }
        }
        .scaleEffect(isPulsing ? 1.15 : 1.0)
        .accessibilityLabel(mapping.accessibilityLabel)
    }

    // The Icon Catalog (65-UI-SPEC.md): default/alternate SF Symbol + state-dependent tint +
    // accessibility label per catalog Action. Live reads are all synchronous, side-effect-free
    // (T-65-10, accepted) — readSystemInputMuted() is MicMuteController.swift's existing
    // top-level free function (Phase 63, unmodified), never duplicated here.
    private func quickActionsBarIcon(
        for action: QuickActionsBarCatalog.Action, slotIndex: Int
    ) -> (systemName: String, tint: Color?, accessibilityLabel: String) {
        switch action {
        case .none:
            return ("questionmark", nil, "")   // unreachable — configured filters .none out
        case .micMute:
            let muted = readSystemInputMuted()
            return (muted ? "mic.slash.fill" : "mic.fill",
                    muted ? .red : nil,
                    muted ? "Unmute Microphone" : "Mute Microphone")
        case .displaySleep:
            return ("moon.zzz.fill", nil, "Sleep Display Now")
        case .darkMode:
            let isDark = DarkModeToggleAction.isDarkMode
            return (isDark ? "sun.max.fill" : "moon.fill", nil,
                    isDark ? "Switch to Light Mode" : "Switch to Dark Mode")
        case .screenLock:
            return ("lock.fill", nil, "Lock Screen")
        case .focusToggle:
            if quickActionsBarFeedback.lastFailedAction == .focusToggle {
                return ("exclamationmark.triangle.fill", .red, "Turn On Do Not Disturb")
            }
            let isOn = FocusToggleAction.isConfirmedOn
            return ("bell.slash.fill", isOn ? .green : nil,
                    isOn ? "Turn Off Do Not Disturb" : "Turn On Do Not Disturb")
        case .caffeinate:
            let isActive = CaffeinateToggleAction.isActive
            return ("cup.and.saucer.fill", isActive ? .green : nil,
                    isActive ? "Allow Mac to Sleep" : "Keep Mac Awake")
        case .emptyTrash:
            return ("trash.fill", nil, "Empty Trash")
        case .launch:
            let target = quickActionsBarLaunchTarget(forSlot: slotIndex)
            return ("arrow.up.forward.app.fill", nil,
                    "Open \(target.isEmpty ? "App/URL" : target)")
        }
    }

    // The matching per-slot launch-target string, resolved by the ORIGINAL 0-7 slot index
    // (never the filtered configured-tiles position) — each `.launch` slot is independently
    // configured (Plan 65-01's 8 quickActionsBarSlot*LaunchTargetKey entries).
    private func quickActionsBarLaunchTarget(forSlot index: Int) -> String {
        switch index {
        case 0: return quickActionsBarSlot1LaunchTarget
        case 1: return quickActionsBarSlot2LaunchTarget
        case 2: return quickActionsBarSlot3LaunchTarget
        case 3: return quickActionsBarSlot4LaunchTarget
        case 4: return quickActionsBarSlot5LaunchTarget
        case 5: return quickActionsBarSlot6LaunchTarget
        case 6: return quickActionsBarSlot7LaunchTarget
        case 7: return quickActionsBarSlot8LaunchTarget
        default: return ""
        }
    }

    // Phase 28 / CALVIEW-01/02 (28-UI-SPEC.md "Calendar full view") — the month grid + day
    // list. Reuses blobShape exactly like expandedIsland (same 360pt width, same
    // expandedSize.height base) with the switcher row always shown (this presentation IS one of
    // the two showsSwitcherRow cases). Month grid LEFT, day list RIGHT, a thin divider between —
    // both read through Plan 01's pure `daysInMonth(for:)`/`events(on:events:)` functions, never
    // a re-implementation (RESEARCH.md Anti-Pattern: no Date()/Date.now threaded into month math).
    private var calendarContent: some View {
        // 28-04 on-device UAT bugfix — `alignment: .top` (was default `.center`). The month
        // grid's real content is taller than expandedSize.height; centering it in that box
        // spilled the overflow equally above AND below, and the ABOVE half rendered under the
        // camera notch. Top-pinning (mirrors mediaExpanded's `alignment: .top` +
        // `.padding(.top, 32)` convention) makes the island grow DOWNWARD only, same as every
        // other expanded presentation. 28-04 round 5 — the explicit `height:` override is gone:
        // `blobShape` now applies the shared `switcherContentHeight` box UNCONDITIONALLY
        // whenever `showSwitcher` is true (see that constant's doc comment), so this call site
        // no longer needs its own per-case height.
        HStack(spacing: 0) {
            monthGridColumn
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .padding(.horizontal, 12)
            dayListColumn
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(.horizontal, 16)
        .padding(.top, Self.switcherTabClearance + switcherContentOffsetNudge)   // Quick task 260801 baked Switcher Tuner value
        // Quick task 260715-vsd — scales the whole padded HStack (month grid, divider, day
        // list + "+ Add" button) inward by 4% from its own center, pulling the Add button
        // further from the curved wall on top of the extra calendarWidth from step 1.
        .scaleEffect(0.96)
    }

    // LEFT column — month/year header (13px semibold) flanked by prev/next chevrons, over a
    // 7-column day grid (round 5: `calendarCellSize`×`calendarCellSize`pt cells,
    // `calendarCellGap`pt gap). Selected day gets a weight bump (semibold vs. regular), matched
    // via `Calendar.current.isDate(_:inSameDayAs:)` — same idiom `nextRelevantEvent`/
    // `calendarColumn` already use elsewhere in this file. Taps only REPORT intent via
    // `onCalendarMonthChange`/`onCalendarDaySelect` (Pattern 3: no navigation math lives in the
    // view).
    // 28-04 round 4 visual pass introduced circular/capsule badges (filled circle = selected,
    // thin ring = today, small dot = has events) as the closest faithful substitute available
    // at the time — no real Droppy calendar/switcher screenshot existed in this project's
    // assets then (all 31 files on disk were Settings screenshots).
    // 28-04 round 5 — two REAL Droppy notch-overlay screenshots (the switcher pill + month
    // grid, this time genuinely showing the feature this file renders) confirmed the round-4
    // circular badges were the right visual language, but the CELL SIZE was wrong: Droppy's
    // grid is small/tight/numeral-only, and gives noticeably MORE width to the day-list column
    // than the grid column — round 4's 28×28pt/4pt was never actually validated against a real
    // reference. Shrunk to `calendarCellSize`/`calendarCellGap` (18pt/2pt) below, which both
    // matches the reference density AND frees width for `dayListColumn` for free (see those
    // constants' own doc comment).
    // 72-02 (D-10) — locale-aware weekday letters for weekdayHeaderRow below, rotated so index 0
    // matches Calendar.current.firstWeekday instead of always Sunday. Foundation Calendar API
    // only — never a hardcoded weekday-letter array (RESEARCH.md Pitfall 2).
    private var rotatedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols   // index 0 = Sunday, always
        let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar.firstWeekday is 1-based
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    // 72-02 (D-10) — net-new weekday-letter header row above the day grid; column-aligned to the
    // LazyVGrid below via the same Self.calendarCellSize/calendarCellGap constants.
    private var weekdayHeaderRow: some View {
        HStack(spacing: Self.calendarCellGap) {
            ForEach(Array(rotatedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.calendarCellSize)
            }
        }
    }

    private var monthGridColumn: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    ChevronHoverButton(systemName: "chevron.left", action: { onCalendarMonthChange(-1) })
                    MonthYearPickerButton(visibleMonth: calendarViewState.visibleMonth, onSubmit: onCalendarMonthYearSelect)
                    ChevronHoverButton(systemName: "chevron.right", action: { onCalendarMonthChange(1) })
                }
                Spacer()
            }
            weekdayHeaderRow
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.calendarCellSize), spacing: Self.calendarCellGap), count: 7),
                      spacing: Self.calendarCellGap) {
                ForEach(Array(daysInMonth(for: calendarViewState.visibleMonth).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isSelected = Calendar.current.isDate(day, inSameDayAs: calendarViewState.selectedDay)
                        let isToday = Calendar.current.isDateInToday(day)
                        let hasEvents = calendarViewState.monthEvents.map { !events(on: day, events: $0).isEmpty } ?? false
                        DayCell(day: day, isSelected: isSelected, isToday: isToday, hasEvents: hasEvents,
                                onTap: { onCalendarDaySelect(day) })
                    } else {
                        Color.clear.frame(width: Self.calendarCellSize, height: Self.calendarCellSize)   // leading pad cell — no view
                    }
                }
            }
        }
    }

    // Phase 72-04 (D-14) — one month-grid day cell, extracted to a local view struct so it can
    // own its own `@State isHovering` (mirrors `EventRow`/`TransportButton`'s established local-
    // hover pattern — a `ForEach`-generated inline view can't hold `@State` itself). Adds a white
    // hover-ring overlay, layered UNDER the existing today/selected red badge overlay so the two
    // never visually compete (a hovered today/selected cell still reads primarily as
    // today/selected; the white ring is a secondary, thinner affordance).
    private struct DayCell: View {
        let day: Date
        let isSelected: Bool
        let isToday: Bool
        let hasEvents: Bool
        let onTap: () -> Void
        @State private var isHovering = false

        var body: some View {
            ZStack(alignment: .bottom) {
                Text(day, format: .dateTime.day())
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: NotchPillView.calendarCellSize, height: NotchPillView.calendarCellSize)
                    .background(Circle().fill(isToday ? Color.red : Color.clear))
                    .overlay(Circle().strokeBorder(isHovering ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1))
                    .overlay(Circle().strokeBorder(isSelected && !isToday ? Color.red : Color.clear, lineWidth: 1.5))
                if hasEvents {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: 2)
                        .offset(y: -1)
                }
            }
            .frame(width: NotchPillView.calendarCellSize, height: NotchPillView.calendarCellSize)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(perform: onTap)
        }
    }

    // Phase 72-04 (D-15) — prev/next month chevron, mirroring `TransportButton`'s exact local-
    // hover pattern (Now Playing's play/skip button hover treatment) but with a CIRCLE background
    // instead of a rounded rectangle, per the user's explicit "circular instead of pill-shaped"
    // decision.
    private struct ChevronHoverButton: View {
        let systemName: String
        let action: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(isHovering ? Color.white.opacity(0.40) : Color.clear))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        }
    }

    // Phase 72-04 (D-13) — the month/year label becomes a popover trigger (mirrors
    // `QuickAddPopover`'s exact chrome: 240pt-wide content, 12pt padding, `.popover` off a plain
    // `Button`) so the user can jump months/years directly instead of only stepping one at a
    // time via the chevrons. Month/Year `Picker`s report a single combined Date on submit —
    // `onSubmit` mirrors `onCalendarDaySelect`'s "report an absolute value, no math in the view"
    // shape (D-13's own closure, `onCalendarMonthYearSelect`).
    private struct MonthYearPickerButton: View {
        let visibleMonth: Date
        let onSubmit: (Date) -> Void
        @State private var isShowing = false
        @State private var pickedMonth = 1
        @State private var pickedYear = 2026

        var body: some View {
            Button(action: { isShowing = true }) {
                Text(visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.red)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowing) {
                popoverContent
            }
            .onChange(of: isShowing) { _, newValue in
                guard newValue else { return }
                let calendar = Calendar.current
                pickedMonth = calendar.component(.month, from: visibleMonth)
                pickedYear = calendar.component(.year, from: visibleMonth)
            }
        }

        private var popoverContent: some View {
            let currentYear = Calendar.current.component(.year, from: Date())
            return VStack(alignment: .leading, spacing: 8) {
                Picker("Month", selection: $pickedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                    }
                }
                Picker("Year", selection: $pickedYear) {
                    ForEach((currentYear - 10)...(currentYear + 10), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                Button(action: {
                    var components = DateComponents()
                    components.year = pickedYear
                    components.month = pickedMonth
                    components.day = 1
                    if let newMonth = Calendar.current.date(from: components) {
                        onSubmit(newMonth)
                    }
                    isShowing = false
                }) {
                    Text("Go")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(width: 240)
        }
    }

    // RIGHT column — the SELECTED DAY's event list (Phase 72-04 revision, D-01/D-02 superseded:
    // the whole-month day-grouped agenda from Plan 72-03 is reverted back to a single-day list —
    // "today" by default, or whichever day is tapped in the month grid, replacing what was shown
    // rather than scrolling a whole-month list — see 72-CONTEXT.md's "Revised 2026-07-31" note).
    // `monthEvents == nil` (not yet fetched) renders nothing — NEVER the empty state (Pitfall 4:
    // distinguishes loading from a confirmed-zero-events day so "No events today" never flashes
    // before the first EventKit fetch settles).
    private var dayListColumn: some View {
        let dayEvents = calendarViewState.monthEvents.map { events(on: calendarViewState.selectedDay, events: $0) }
        return VStack(alignment: .trailing, spacing: 4) {
            // CALVIEW-06 / D-06 — the "+ Add" trigger, LEFT edge of the day-list column, next
            // to the month-grid/day-list divider (was right edge, previously visually clipped).
            HStack {
                QuickAddPopover(onSubmit: onQuickAdd, selectedDay: calendarViewState.selectedDay)
                Spacer()
            }
            Group {
                if let dayEvents {
                    if dayEvents.isEmpty {
                        calendarEmptyState
                    } else {
                        dayEventsList(dayEvents)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // CALVIEW-02 — the explicit empty state (Copywriting Contract: exact strings; bold "+ Add"
    // matches the real quick-add trigger label added in Task 3, "point at the real control").
    // Phase 72-04 revision — reverted to "No events today" (single-day scope, D-01 revised).
    private var calendarEmptyState: some View {
        VStack(spacing: 4) {
            Text("No events today")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            (Text("Tap ") + Text("+ Add").fontWeight(.bold) + Text(" to create one."))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Phase 72-04 revision (D-01/D-02 superseded) — the SELECTED DAY's scrollable event list.
    // Replaces Plan 72-03's whole-month `dayGroupedAgenda`/`ScrollViewReader` jump-to-day
    // mechanism: tapping a grid day now simply REPLACES which day's events render (controller
    // just sets `selectedDay`, no scroll target needed since only one day's events are ever on
    // screen at once). Reuses the same `EventRow` (hover-delete/edit-popover/tooltip from Plan
    // 72-03, D-07/D-08/D-12) unchanged — only the "which day(s) render" mechanism changed.
    private func dayEventsList(_ dayEvents: [EventInput]) -> some View {
        ScrollView(.vertical) {
            // CALVIEW-07 / D-09 — roomier row padding/spacing (was 8h/5v/6-spacing).
            VStack(alignment: .leading, spacing: 8) {
                ForEach(dayEvents, id: \.id) { event in
                    EventRow(
                        event: event,
                        onEdit: onEventEdit,
                        onDelete: { onEventDelete(event.id) }
                    )
                }
            }
        }
        .scrollIndicators(.never)
    }

    // 28-04 round 4 (user-confirmed scope expansion) — the Weather full view. IMPORTANT
    // CAVEAT: `WeatherGlance` (Islet/Weather/WeatherService.swift) only carries CURRENT
    // conditions (category + temperature) — there is no forecast/hourly/multi-day fetch
    // anywhere in this codebase. This view deliberately renders ONLY that existing
    // current-conditions data, styled larger/richer than `weatherColumn`'s small glance —
    // reusing its icon-mapping (`weatherIcon(for:)`) and temperature-formatting exactly rather
    // than reinventing them. A real forecast would need a new WeatherKit call + a new data
    // model — out of scope for this round, flagged back to the user rather than silently built.
    // Content (icon 44 + temp 32 + label ~14, plus the 32pt camera-clearance pin) is much
    // shorter than the shared `switcherContentHeight` box — 28-04 round 5 made THAT box the
    // uniform content height for every switcher-row presentation (see that constant's doc
    // comment), so this shorter content simply top-aligns with empty transparent space below
    // it, above the switcher row; no per-case override was ever needed here.
    // Phase 33 / WEATHER-01/02 (D-03/D-04) — `height:` rides the SAME `blobShape` override
    // mechanism `trayFullView` already uses (Phase 32/TRAY-05's explicit-height-wins fix):
    // Medium is now ALWAYS an explicit height (no more nil-falls-through-to-switcherContentHeight
    // case, D-03's "no Compact-only state" revision) and Large animates to the taller height
    // inside the controller's existing spring — no new animation wrapper, no relaunch.
    private var weatherContent: some View {
        Group {
            if let weather = outfit.weather {
                VStack(spacing: 0) {
                    weatherFullContent(weather)
                    if let hourly = outfit.hourlyForecast {
                        hourlyForecastRow(hourly)
                    }
                    if weatherStyle == .large, let daily = outfit.forecast {
                        dailyForecastList(daily)
                    }
                }
            } else {
                weatherFullUnavailable
            }
        }
        .padding(.top, Self.switcherTabClearance + switcherContentOffsetNudge)   // Quick task 260801 baked Switcher Tuner value
    }

    // The populated state: location name (or "Local" fallback) above the icon, then icon +
    // temperature + category label, then an H/L readout — reusing `weatherIcon(for:)`'s exact
    // SF Symbol mapping and the same locale-aware `.formatted(.measurement(...))` temperature
    // string `weatherColumn` already uses (no manual Celsius/Fahrenheit conversion here
    // either). Phase 33 / WEATHER-01 (D-01/D-02): the location label occupies the SAME slot
    // whether or not `outfit.locationName` has resolved yet (falls back to "Local"), so there
    // is no layout shift once the real name arrives. H/L is appended directly under the
    // category label and omitted entirely (no empty line reserved) when either bound is nil.
    private func weatherFullContent(_ weather: WeatherGlance) -> some View {
        VStack(spacing: 8) {
            Text(outfit.locationName ?? "Local")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
            weatherIcon(for: weather.category)
                .font(.system(size: 44))
            Text(weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(weatherCategoryLabel(weather.category))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
            if let high = weather.high, let low = weather.low {
                Text("H:\(high.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))) L:\(low.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            // Phase 72.1.1 Plan 05 (D-06 Tier 2) — new glass card background (previously
            // no background at all), guarded per the file's existing #available convention.
            // CR-01 fix (72.1.1 review) — also gated on materialStyle == .liquidGlass,
            // matching every other .glassEffect() call site in the codebase.
            if materialStyle == .liquidGlass, #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(.regular.tint(Color.white.opacity(0.06)),
                                 in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Phase 33 / WEATHER-01 (D-07) — the permanent Medium hourly row: a fixed-count HStack of
    // up to `hourlyChipCount` time/icon/temp chips (no ScrollView, locked). Only ever mounted
    // when `weatherFullView` has already confirmed `outfit.hourlyForecast != nil` — this
    // function itself stays a pure render of whatever slice it's handed.
    private func hourlyForecastRow(_ hourly: [HourlyForecast]) -> some View {
        // Phase 33 gap-closure (on-device UAT round 1) — chips previously each claimed an equal
        // `maxWidth: .infinity` slice of the full row width, spreading them edge-to-edge with a
        // lot of dead space between narrow content; sizing each chip to its own content and only
        // centering the resulting cluster reads as "grouped together" instead.
        HStack(spacing: 18) {
            ForEach(Array(hourly.prefix(Self.hourlyChipCount))) { hour in
                VStack(spacing: 4) {
                    Text(hour.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    weatherIcon(for: hour.category)
                        .font(.system(size: 16))
                    Text(hour.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // Phase 33 / WEATHER-02 (D-08) — the Large-only daily forecast list: up to
    // `largeDailyRowCount` weekday/icon/low/range-bar/high rows, one per day. Only ever
    // mounted when `weatherFullView` has already confirmed `weatherStyle == .large &&
    // outfit.forecast != nil` — this function itself stays a pure render of whatever slice
    // it's handed. `span` is floored to guard divide-by-zero on a degenerate flat forecast
    // (T-33-08).
    private func dailyForecastList(_ daily: [DailyForecast]) -> some View {
        let days = Array(daily.prefix(Self.largeDailyRowCount))
        let overallLow = days.map { $0.low.value }.min() ?? 0
        let overallHigh = days.map { $0.high.value }.max() ?? overallLow + 1
        let span = max(overallHigh - overallLow, 0.1)
        // Phase 33 gap-closure (on-device UAT round 1) — tighter row spacing/top padding, on top
        // of the reduced `largeDailyRowCount` (below), makes Large noticeably more compact.
        return VStack(spacing: 6) {
            ForEach(days) { day in
                dailyForecastRow(day, overallLow: overallLow, span: span)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // One Large daily row: weekday label -> icon -> low temp -> a temperature-range gradient
    // bar -> high temp. The bar's fractional position/width is derived from this day's
    // low/high relative to the whole visible forecast's overall low/high (`overallLow`/`span`),
    // so every row's bar is comparable at a glance — mirrors Apple's own Large Weather widget.
    private func dailyForecastRow(_ day: DailyForecast, overallLow: Double, span: Double) -> some View {
        let lowFraction = (day.low.value - overallLow) / span
        let highFraction = (day.high.value - overallLow) / span
        // Phase 33 gap-closure (on-device UAT round 2) — the weekday/low/high Texts sat in
        // fixed-width frames with no line limit; "14°" etc. wrapped onto two lines inside the
        // 30pt-wide low/high columns (numbers rendering above the ° symbol), which silently
        // doubled those rows' real height and is what was still overflowing past the shape's
        // bottom edge even after round 1's height/row-count reduction. `.lineLimit(1)` +
        // slightly wider columns fixes the wrap at the source.
        return HStack(spacing: 6) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 30, alignment: .leading)
            weatherIcon(for: day.category)
                .font(.system(size: 16))
                .frame(width: 22)
            Text(day.low.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 32, alignment: .trailing)
            // Phase 33 gap-closure (on-device UAT round 4) — this bar previously had no width
            // cap, so it (and therefore the whole row) stretched to fill every available pixel,
            // pushing the weekday/high-temp columns right up against NotchShape's real silhouette
            // (its side walls taper inward by `topCornerRadius` for nearly the whole content
            // height — see NotchShape.swift — well past this row's 16pt padding), which is what
            // round 3's new clip then cut off. Capping the bar's width shrinks the row below the
            // available width, so the VStack's default centering leaves real margin on both sides.
            GeometryReader { geo in
                let barWidth = max((highFraction - lowFraction) * geo.size.width, 4)
                let barOffset = lowFraction * geo.size.width
                Capsule()
                    .fill(LinearGradient(colors: [Self.temperatureColor(fraction: lowFraction),
                                                   Self.temperatureColor(fraction: highFraction)],
                                          startPoint: .leading, endPoint: .trailing))
                    .frame(width: barWidth, height: 4)
                    .offset(x: barOffset)
            }
            .frame(width: 110, height: 4)
            Text(day.high.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // Phase 33 / WEATHER-02 (D-08) — a fixed 5-stop temperature gradient (cold blue -> hot
    // red), blended via native AppKit color interpolation (`NSColor.blended(withFraction:of:)`)
    // rather than hand-rolled RGB-component math. Matches the spirit of Apple's Large Weather
    // widget's range bar without needing pixel-exact color stops.
    private static func temperatureColor(fraction: Double) -> Color {
        let stops: [(Double, Color)] = [
            (0.0, .blue),
            (0.25, .mint),
            (0.5, .yellow),
            (0.75, .orange),
            (1.0, .red)
        ]
        let clamped = min(max(fraction, 0.0), 1.0)
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) {
            if clamped >= stops[i].0 && clamped <= stops[i + 1].0 {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        let range = upper.0 - lower.0
        let localFraction = range > 0 ? (clamped - lower.0) / range : 0
        let blended = NSColor(lower.1).blended(withFraction: localFraction, of: NSColor(upper.1)) ?? NSColor(upper.1)
        return Color(nsColor: blended)
    }

    // Plain English label per category — mirrors `calendarEmptyState`'s plain-string
    // convention; no new asset/localization system introduced for 4 fixed strings.
    private func weatherCategoryLabel(_ category: WeatherCategory) -> String {
        switch category {
        case .sunny: return "Sunny"
        case .cloudy: return "Cloudy"
        case .rain: return "Rain"
        case .snow: return "Snow"
        }
    }

    // The unavailable/empty state (no location permission, or the fetch failed/hasn't
    // settled yet) — mirrors `mediaUnavailable`'s "nicht verfügbar" tone/style exactly rather
    // than a blank box.
    private var weatherFullUnavailable: some View {
        Text("Wetter nicht verfügbar")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
    }

    // 28-04 round 5 (user-reported UX gap) — Tray becomes its own dedicated, files-only
    // presentation instead of the previous "select Tray -> force-reveal the small additive
    // shelf strip under whatever Home showed" behavior. Reuses `shelfRow(_:)`/`ShelfItemView`
    // verbatim (Pattern 3: shelf-item rendering is never reinvented) inside a dedicated,
    // camera-clearance-pinned `blobShape` box — the SAME `showSwitcher: true` convention as
    // Calendar/Weather, so it automatically participates in the shared `switcherContentHeight`
    // fix. `shelfVisible: false` is deliberate: this view IS the full files presentation, so
    // the additive shelf strip mechanism (`ShelfViewState.isVisible`, still used to
    // auto-reveal files under Home/Calendar/Weather/NowPlaying per Phase 24) must NOT also
    // append itself a second time below this content.
    private var trayContent: some View {
        // Gap-closure (on-device UAT round 2) — dropped the extra ancestor-level
        // `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` wrapper that
        // used to sit here: it was the ONE structural difference from calendarFullView/
        // weatherFullView's proven pattern (Group{if/else}.padding(.top, cameraClearance),
        // nothing else) and let shelfRow render at its natural/intrinsic (un-stretched)
        // width instead of the full card width, which is what made the file tiles hug the
        // top-left corner instead of sitting inset. shelfRow now self-declares its own
        // `maxWidth: .infinity` (mirrors dayListColumn's precedent), so it fills the
        // available width without needing an ancestor to force it — matching every other
        // switcher-row presentation's structure exactly.
        Group {
            if shelfViewState.items.isEmpty {
                trayEmptyState
            } else {
                // Gap-closure (round 3) — trayShelfRowHeight override, sized for the 40x40pt
                // icons Task 3 grew this row to; the shared shelfRowHeight default (56) was
                // too short and let the filename caption spill past the shape's bottom edge.
                // Gap-closure (round 4/8) — trayShelfRowTopInset gives the icon/delete-badge
                // deterministic clearance from the shape's top edge; round 8 fixed shelfRow's
                // internal centering so this inset actually reaches the icon (see shelfRow's
                // own comment) instead of just growing empty space elsewhere.
                shelfRow(shelfViewState.items, rowHeight: Self.trayShelfRowHeight, topInset: Self.trayShelfRowTopInset)
            }
        }
        .padding(.top, Self.switcherTabClearance + switcherContentOffsetNudge)   // Quick task 260801 baked Switcher Tuner value
    }

    // The empty state — mirrors `calendarEmptyState`'s tone/structure (heading + secondary
    // body line) rather than `mediaUnavailable`/`weatherFullUnavailable`'s single-line "nicht
    // verfügbar" style, since an empty shelf is a normal empty collection (like an empty
    // inbox), not a degraded/blocked feature.
    private var trayEmptyState: some View {
        // Quick task 260715-vsd gap-closure round 4 — trayEmptyState was confirmed
        // UNREACHABLE in every prior round (debug session tray-spacing-fix-not-applying:
        // NotchWindowController.seedDebugShelfItems() re-seeded demo files on every Debug
        // launch, so the shelf was never actually empty). Now that the fix there
        // (one-time UserDefaults seed guard) makes this view reachable, round 3's spacing: 2
        // (only 2pt tighter than the original 4pt) was too subtle a change to read as
        // different. Going further this round: spacing: 0 (icon and title/subtitle block
        // touch directly) PLUS trayContentHeight grown 133 -> 145 (see that constant) for a
        // combined, unmistakably larger gap before the switcher row than any prior round.
        VStack(spacing: 0) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
            VStack(spacing: 4) {
                Text("No files yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Drag files onto the notch to add them here.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        // Phase 44 UAT gap-closure (round 5) — this 24pt top padding was tuned for the old
        // 145pt-tall trayContentHeight box; combined with the Group's own cameraClearance(42)
        // padding in trayFullView, the icon+text block started 66pt down, leaving only ~51pt for
        // ~61pt of content (icon 28 + text block ~33) in the new 117pt box — the title/subtitle
        // ("No files yet" / "Drag files onto...") got pushed past the box's clipped bottom edge.
        // Trimmed to 8pt so the block starts at 50pt total, comfortably inside the shorter box.
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // Phase 34 (UAT revision, D-14/D-15) / 34-UI-SPEC.md Layout & Interaction Contract §1/§3 —
    // the Quick Action Destination Picker: a full-takeover presentation (switcher HIDDEN,
    // showSwitcher: false -- the picker is behaviorally analogous to the Charging/Device wings
    // splash, not a switcher-row tab) -- no file preview, uniformly for single- and multi-file
    // drops (D-14). Mirrors trayFullView's exact blobShape call shape.
    // Phase 70 / D-01 — now a 2-stage card: the main Drop/AirDrop/Mail/Convert row, or (once
    // presentationState.isShowingConvertFormats is set true by the controller, Plan 70-03) the
    // JPG/PNG/HEIC/TIFF format-tile row, swapped in-place inside the SAME blobShape call with
    // NO card resize (Self.traySize.width / Self.quickActionPickerContentHeight unchanged for
    // either stage) — reuses the "Group{if/else}.padding(.top, cameraClearance)" conditional-
    // rendering shape already proven elsewhere in this file.
    private func quickActionPickerView(pendingDrop: PendingDrop) -> some View {
        blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
                  width: Self.traySize.width, height: Self.quickActionPickerContentHeight,
                  shelfItems: [], shelfVisible: false, showSwitcher: false) {
            Group {
                if presentationState.isShowingConvertFormats {
                    formatTileRow()
                } else {
                    quickActionButtonRow(pendingDrop)
                }
            }
                .padding(.top, resolvedCameraClearance)   // camera/notch clearance — matches every other full-view
                // Phase 44 UAT gap-closure (round 1) — quickActionButtonRow() had zero horizontal
                // padding, so its `.frame(maxWidth: .infinity)` chips filled the card edge-to-edge.
                // blobShape's content closure gets the FULL baseWidth with no inset of its own
                // (see blobShape's `content().frame(width: baseWidth, ...)`), so the Drop/Mail chips
                // rendered flush against NotchShape's curved edges and visibly poked past the curve
                // — the file's own documented "24pt wall-inset" convention (see traySize/
                // calendarWidth comment above) was missing here. This did not surface at the old
                // 420pt-wide box because the chips still filled edge-to-edge either way; the wider
                // 650pt box (Plan 44-01) just made the resulting overflow easier to see.
                .padding(.horizontal, 24)
        }
    }

    // Phase 70 / D-02 — the second-step format-tile row (Convert tapped): 4 equal-weight tiles,
    // JPG/PNG/HEIC/TIFF, ALL always enabled (the gate already happened at the main row's Convert
    // chip, D-05). One shared icon ("photo") across all 4 tiles per 70-UI-SPEC.md's resolved
    // Open Question 1 — label text alone differentiates them. Reuses quickActionButton verbatim.
    private func formatTileRow() -> some View {
        HStack(spacing: 16) {
            ForEach(Array(ImageFormat.allCases.enumerated()), id: \.offset) { index, format in
                quickActionButton(icon: "photo", label: format.label, enabled: true,
                                   isHovered: presentationState.hoveredQuickActionButtonIndex == index)
            }
        }
    }

    // Phase 62 / TIMER-01..04 (D-08, Pattern 4) — the dedicated expanded controls: this is the
    // FIRST transient with its own top-level presentationSwitch arm rather than a fallthrough
    // to tabContentView's switcher-row group (no switcher row here, D-08's 4 buttons take
    // exclusive priority). Same call shape as quickActionPickerView() above: one blobShape +
    // content closure, no shelf. isPaused only distinguishes .paused — .running/.completed/
    // .segmentDone all render the "Pause" glyph, though the resolver's own .timerExpanded
    // contract (IslandResolver.swift) only ever hands this function .running/.paused.
    private func timerExpandedContent(for activity: TimerActivity) -> some View {
        let isPaused: Bool
        if case .paused = activity { isPaused = true } else { isPaused = false }
        // Phase 62-04 UAT fix (Bug 2, defensive) — was `.center`, the ONE
        // navCircleButton-using blobShape caller not using `.top` like every sibling
        // (tabContentView/onboardingCarousel); normalized for consistency with the
        // codebase's own "content grows DOWNWARD from the top-pinned notch" convention that
        // visibleContentZone()'s click-through geometry assumes.
        return blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
                          width: Self.expandedSize.width, height: nil,
                          shelfItems: [], shelfVisible: false, showSwitcher: false) {
            VStack(spacing: 20) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let tick = timerTick(for: activity, at: context.date)
                    VStack(spacing: 4) {
                        if let label = timerPillLabel(for: tick.context) {
                            HStack(spacing: 6) {
                                if tick.context.phase == .work {
                                    Circle().fill(Color.green)   // D-07 live-session dot — Work segment only
                                        .frame(width: 6, height: 6)
                                }
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(formatMMSS(tick.remaining))
                            .font(.system(size: 15, weight: .bold, design: .rounded))   // mediaContent's title-size precedent
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                // D-08 — exactly 4 circular icon buttons: Pause/Resume is the ONE filled action
                // (toggles glyph), Reset/Add-Time/Stop stay outlined per navCircleButton's own
                // filled/outlined convention (never chipButton — D-08 excludes that style here).
                // Phase 62-04 UAT round 3 fix (item D) — was `HStack(spacing: 0) { button;
                // Spacer(); button; ... }`, which stretches to fill the FULL content width,
                // spreading the 4 buttons wide AND pinning the outer two flush against the
                // padded edge (reported "too spread out / too close to the pill's outer edge"
                // in BOTH round 1 and round 2). A fixed-spacing row has a natural width of
                // just 4*36 + 3*20 = 204pt, centered by the parent VStack instead of stretched
                // — buttons sit closer together AND naturally clear of the rounded corners.
                HStack(spacing: 20) {
                    navCircleButton(systemName: isPaused ? "play.fill" : "pause.fill", filled: true, action: onTimerPauseResume)
                        .accessibilityLabel(isPaused ? "Resume" : "Pause")
                    navCircleButton(systemName: "arrow.counterclockwise", filled: false, action: onTimerReset)
                        .accessibilityLabel("Reset")
                    navCircleButton(systemName: "plus", filled: false, action: onTimerAddTime)
                        .accessibilityLabel("Add 1 Minute")
                    // Stop is deliberately NOT color-coded red (62-UI-SPEC.md Color section) —
                    // distinguished from Reset/Add-Time by icon glyph only.
                    navCircleButton(systemName: "stop.fill", filled: false, action: onTimerStop)
                        .accessibilityLabel("Stop")
                }
            }
            .padding(.top, resolvedCameraClearance)
            // Phase 62-04 UAT round 3 fix (item D) — was 24, bumped to 32 matching
            // timerSetupPicker's own B/C fix, for the same "too close to the rounded corners"
            // reason (though with the row no longer edge-stretched above, this now only
            // matters for the VStack's own overall box centering, not button placement).
            .padding(.horizontal, 32)
        }
    }

    // Phase 62-04 UAT fix (Bug 1) — root cause: this whole view is hosted inside a
    // `.nonactivatingPanel` (NotchWindowController sets `canBecomeKey`/`canBecomeMain` ==
    // false), so a plain TextField living directly in blobShape's content can NEVER become
    // first responder — the "Custom…" field was un-typeable by construction, not a SwiftUI
    // binding bug. `.popover` opens its own separate, key-capable window — the exact
    // mechanism QuickAddPopover (28-CONTEXT.md, calendar quick-add's title field) already
    // proved works in this same architecture — reused here instead of inventing a new
    // focus-forcing trick. Trigger chip mirrors chipButton's visual style so it reads as
    // just another chip in durationChipsGrid below.
    private struct CustomDurationChip: View {
        @Binding var text: String
        @Binding var isSelected: Bool
        @State private var isShowing = false

        // Phase 62-04 UAT round 5 feature (item I, simplified round 6 — only ":" is a
        // recognized format now) — the chip label mirrors whatever format the user actually
        // typed: "5:30" already self-describes its unit, so only a bare number
        // (plain-minutes shorthand) gets " min" appended for clarity.
        private var displayLabel: String {
            guard isSelected, !text.isEmpty else { return "Custom…" }
            if text.contains(":") { return text }
            return "\(text) min"
        }

        var body: some View {
            Button(action: {
                isSelected = true
                isShowing = true
            }) {
                Text(displayLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.28 : 0.12))
                    )
                    // Phase 62-04 UAT round 3 fix (item F) — matches chipButton's own
                    // selected-state border ring for visual parity between preset and custom chips.
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowing, arrowEdge: .bottom) {
                // Phase 62-04 UAT round 6 feature (item I) — accepts plain minutes ("5") or
                // minutes:seconds ("5:30", or "0:30" for just 30 seconds); parsed by
                // parseCustomDurationSeconds(_:) in startTimerSetup() below. Placeholder
                // doubles as the format hint (this project's usual subtle-placeholder
                // convention, e.g. TextField("1-180", ...) before this same round) — no
                // separate label needed.
                TextField("e.g. 5:30", text: $text)
                    .font(.system(size: 13, design: .rounded))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .padding(12)
            }
        }
    }

    // Phase 62-04 UAT design revision (item 5) — was durationChipsRow's single HStack (read
    // "one cramped row" in the UAT report for Work/Break); a LazyVGrid with 3 flexible
    // columns wraps the same preset+Custom chips into 2 rows instead, with the Custom chip
    // grouped IN the grid (not off to the side in its own trailing slot). Smaller fontSize
    // (12, was 14) matches the "smaller chips" ask. Shared by Countdown/Work/Break exactly
    // like the row helper it replaces.
    private func durationChipsGrid(presets: [Int], selectedMinutes: Binding<Int>,
                                    isCustomSelected: Binding<Bool>, customText: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(presets, id: \.self) { minutes in
                // Phase 62-04 UAT round 3 fix (item F) — a preset chip reads "selected" only
                // when Custom isn't active AND its own value is the current one, so exactly
                // one chip (preset or Custom) is ever highlighted at a time.
                chipButton("\(minutes) min", fontSize: 12,
                           selected: !isCustomSelected.wrappedValue && selectedMinutes.wrappedValue == minutes) {
                    selectedMinutes.wrappedValue = minutes
                    isCustomSelected.wrappedValue = false
                }
                .frame(maxWidth: .infinity)
            }
            CustomDurationChip(text: customText, isSelected: isCustomSelected)
        }
    }

    // Phase 62-04 UAT design revision (item 6) — the duration/mode picker, now the content of
    // its own dedicated `.timerSetup` switcher tab (was an inline Home overlay). T-62-04
    // (threat model, mitigate): every custom-duration entry is validated via
    // parseCustomDurationSeconds(_:) (item I) inside startTimerSetup() below BEFORE
    // onStartCountdown/onStartPomodoro is ever called — the raw text itself never leaves
    // this view.
    private var timerSetupPicker: some View {
        VStack(spacing: 12) {
            Picker("", selection: $timerSetupMode) {
                Text("Countdown").tag(TimerMode.countdown)
                Text("Pomodoro").tag(TimerMode.pomodoro)
            }
            .pickerStyle(.segmented)

            if timerSetupMode == .countdown {
                durationChipsGrid(presets: [5, 10, 20, 30], selectedMinutes: $countdownMinutes,
                                   isCustomSelected: $isCountdownCustomSelected, customText: $countdownCustomText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Work")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    durationChipsGrid(presets: [15, 25, 45, 60], selectedMinutes: $workMinutes,
                                       isCustomSelected: $isWorkCustomSelected, customText: $workCustomText)
                    Text("Break")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    durationChipsGrid(presets: [5, 10, 15, 20], selectedMinutes: $breakMinutes,
                                       isCustomSelected: $isBreakCustomSelected, customText: $breakCustomText)
                }
            }

            if let timerValidationMessage {
                Text(timerValidationMessage)
                    .foregroundStyle(.red)
                    .font(.system(size: 11))
            }

            HStack {
                // Cancel now navigates back to the Home tab (Timer is its own switcher tab,
                // not a dismissable overlay anymore).
                navCircleButton(systemName: "xmark", filled: false) {
                    onSwitcherSelect(.home)
                    timerValidationMessage = nil
                }
                Spacer()
                navCircleButton(systemName: "checkmark", filled: true, action: startTimerSetup)
            }
        }
        .padding(.top, resolvedCameraClearance)
        // Phase 62-04 UAT round 3 fix (items B/C) — was 24, too little clearance from the
        // bottomCornerRadius:32 curve: the X/checkmark buttons (and the Work/Break labels)
        // read as pinned into the rounded corners. 32 gives every element in this column
        // (segmented control, chip grids, labels, X/checkmark row) the same wider inset.
        .padding(.horizontal, 32)
    }

    // Resolves the picker's current selection to validated Int SECOND value(s) and forwards
    // ONLY those to onStartCountdown/onStartPomodoro — an invalid custom entry blocks dismissal
    // and shows the locked validation copy instead (T-62-04).
    // Phase 62-04 UAT round 5 feature (item I) — a preset chip's value is still plain
    // minutes (the chip literally reads "5 min" etc.), converted to seconds here (`* 60`);
    // a custom entry already comes back as seconds from parseCustomDurationSeconds(_:).
    private func startTimerSetup() {
        switch timerSetupMode {
        case .countdown:
            let seconds = isCountdownCustomSelected ? parseCustomDurationSeconds(countdownCustomText) : countdownMinutes * 60
            guard let seconds else {
                timerValidationMessage = "Enter minutes, or m:ss like 5:30."
                return
            }
            onStartCountdown(seconds)
        case .pomodoro:
            let work = isWorkCustomSelected ? parseCustomDurationSeconds(workCustomText) : workMinutes * 60
            let breakSecs = isBreakCustomSelected ? parseCustomDurationSeconds(breakCustomText) : breakMinutes * 60
            guard let work, let breakSecs else {
                timerValidationMessage = "Enter minutes, or m:ss like 5:30."
                return
            }
            onStartPomodoro(work, breakSecs)
        }
        timerValidationMessage = nil
    }

    // UI-SPEC §5 — 4 equal-weight destination chips (Phase 70 adds Convert as the 4th), no
    // button reads as primary. AirDrop/Mail dim + disable per D-09's fallback flags; Drop is
    // never disabled (TRAY-03 carries no such risk). isHovered reads
    // presentationState.hoveredQuickActionButtonIndex (D-11) — the view never computes which
    // button is hovered itself, the controller's release hit-test (Plan 02/70-03) does the
    // actual selection. Convert's `enabled:` is computed fresh, inline, from the current
    // pendingDrop on every render (D-05, 70-RESEARCH.md Pattern 3) — never a stored/threaded
    // Bool, which is exactly the dead-flag bug class airDropAvailable/mailAvailable fell into.
    private func quickActionButtonRow(_ pendingDrop: PendingDrop) -> some View {
        HStack(spacing: 16) {
            quickActionButton(icon: "tray.and.arrow.down.fill", label: "Drop", enabled: true,
                               isHovered: presentationState.hoveredQuickActionButtonIndex == 0)
            quickActionButton(icon: "personalhotspot", label: "AirDrop", enabled: airDropAvailable,
                               isHovered: presentationState.hoveredQuickActionButtonIndex == 1)
            quickActionButton(icon: "envelope.fill", label: "Mail", enabled: mailAvailable,
                               isHovered: presentationState.hoveredQuickActionButtonIndex == 2)
            quickActionButton(icon: "arrow.triangle.2.circlepath", label: "Convert",
                               enabled: pendingDrop.items.allSatisfy { ImageConversionService.isImageFile($0.originalURL) },
                               isHovered: presentationState.hoveredQuickActionButtonIndex == 3)
        }
    }

    // Phase 34 (UAT revision, D-12) — no Button(action:) wrapper anymore: the view no longer
    // decides selection, the controller's release hit-test does (Plan 02). Render-only: fixed
    // 22x22pt icon frame (Pitfall 9 — normalizes Drop/AirDrop/Mail to identical height
    // regardless of each SF Symbol's own glyph bounds), D-11's two-brightness-step fill +
    // slight scale under the live pointer.
    private func quickActionButton(icon: String, label: String, enabled: Bool, isHovered: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .frame(width: 22, height: 22)   // Pitfall 9 fix — fixed icon box, identical height across buttons
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(enabled ? 1.0 : 0.3))   // D-09 disabled dim
        .frame(maxWidth: Self.quickActionButtonWidth)   // Phase 44 gap-closure round 2 — was .infinity, see quickActionButtonWidth's own comment
        .padding(.vertical, 8)   // reused verbatim from chipButton's own .padding(.vertical, 8)
        .background {
            // Phase 72.1.1 Plan 04 (D-06 Tier 1) — glass on macOS 26+, guarded per the
            // file's existing #available convention (see :773 comment); legacy fallback
            // below is the exact pre-existing plain fill, unchanged. Same opacity
            // expression drives both the legacy fill AND the glass tint, so D-11's
            // hover step / D-09's disabled dim are preserved verbatim either way.
            // CR-01 fix (72.1.1 review) — also gated on materialStyle == .liquidGlass,
            // matching every other .glassEffect() call site in the codebase.
            if materialStyle == .liquidGlass, #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(.regular.tint(Color.white.opacity(enabled ? (isHovered ? 0.22 : 0.12) : 0.06)),
                                 in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(enabled ? (isHovered ? 0.22 : 0.12) : 0.06))   // D-11 hover step
            }
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)   // D-11 slight scale
    }

    // Phase 26 / ONBOARD-01 — the notch-hosted onboarding carousel. Same call shape as
    // expandedIsland (blobShape + content closure), shelfItems always empty (D-06: the shelf
    // never shows during onboarding), width/height fixed to onboardingSize for all 4 steps
    // (no per-step resize, 26-UI-SPEC.md Panel & Layout Contract).
    // Round 3 (on-device UAT) — restructured from a single top-down VStack to a
    // ZStack(alignment: .bottom): step content now vertically CENTERS via a Spacer() on
    // both sides (was pinned flush to the top, leaving a large empty gap above the nav row);
    // the nav row is now a SEPARATE overlay layer pinned at a fixed bottom padding, so its Y
    // position is IDENTICAL on every step regardless of how much content sits above it —
    // round 2's flowing VStack made the Permissions step's 3 rows push Back/Next further
    // down than the other 3 steps (the reported cross-step inconsistency, a real bug: nav Y
    // must not depend on sibling content height).
    private func onboardingCarousel(_ step: OnboardingStep) -> some View {
        blobShape(topCornerRadius: 24, bottomCornerRadius: 32,
                  width: Self.onboardingSize.width, height: Self.onboardingSize.height, shelfItems: [],
                  shelfVisible: false) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    onboardingStepContent(step)
                    Spacer(minLength: 0)
                }
                .padding(.top, resolvedCameraClearance)         // camera-clearance floor, matches mediaExpanded's convention
                .padding(.horizontal, 28)  // screen content padding (round 2, Droppy comparison)
                // Round 3 — reserves room below the centered content so it never visually
                // overlaps the nav row overlay pinned below it.
                .padding(.bottom, Self.navRowReservedHeight)

                onboardingNavRow(step)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
            }
        }
        .overlay(alignment: .topTrailing) {
            if onboardingState.isReplay {
                replayCloseButton
            }
        }
    }

    @ViewBuilder
    private func onboardingStepContent(_ step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            onboardingWelcomeStep
        case .trialLicenseBuy:
            onboardingTrialLicenseBuyStep
        case .permissions:
            onboardingPermissionsStep
        case .done:
            OnboardingDoneStep()
        }
    }

    // Round 3 — space reserved below the centered content so it never overlaps the pinned
    // nav row (diameter + its own bottom padding + a small clearance gap).
    private static let navRowReservedHeight: CGFloat = navCircleDiameter + 20 + 16

    // Step 1 — Welcome. Copywriting Contract: exact strings, verbatim. Round 2 (Droppy
    // comparison) — heading/body now centered (was `.leading`); `.frame(maxWidth: .infinity)`
    // makes the VStack claim the full card width so `alignment: .center` centers against the
    // whole card, not just against its own intrinsic width; `.multilineTextAlignment(.center)`
    // centers each wrapped line of the body copy too (VStack alignment alone only centers the
    // text block as a unit).
    private var onboardingWelcomeStep: some View {
        VStack(alignment: .center, spacing: 8) {
            // Round N (ONBOARD-04 signature reveal, D-09/D-10/D-13) — plain heading text
            // replaced by the animated hand-drawn stroke-reveal; body subtext below is
            // byte-identical, untouched.
            SignatureHeading()
            Text("Your notch, upgraded. Now Playing, charging, and a drag-and-drop shelf — always one glance away.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // Step 2 — Trial/License/Buy. D-04: purely informational about the already-running
    // trial; D-05 (LOCKED): both buttons ONLY hand off to Settings — no license logic here.
    // Round 2 (Droppy comparison) — heading/body centered, same convention as Welcome; the
    // CTA row centers as a block underneath (no maxWidth override needed there, it's short).
    private var onboardingTrialLicenseBuyStep: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Your 3-day trial has started")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Enjoy full access for 3 days. Already have a key, or ready to buy?")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                chipButton("Enter License Key", action: onOnboardingOpenSettings)
                chipButton("Buy Islet — €7.99", action: onOnboardingOpenSettings)
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // Step 3 — Permissions. D-02: one row per permission, each with its own independent
    // Grant control. Round 2 (Droppy comparison) — heading/subheading centered (same
    // convention); the permission ROWS stay a left-to-right control list (icon + text +
    // trailing chip needs full width, centering that would be nonsensical), so only the
    // heading/subheading get `alignment: .center` via the parent VStack — the rows-VStack
    // gets an explicit `.frame(maxWidth: .infinity, alignment: .leading)` to keep filling
    // the full width and hugging left internally regardless of the parent's centering.
    private var onboardingPermissionsStep: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("A few permissions")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Grant what you'd like — skip the rest and enable them later in Settings.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                permissionRow(icon: "antenna.radiowaves.left.and.right",
                              label: "Bluetooth",
                              reason: "Detect when your AirPods or headphones connect",
                              granted: onboardingState.bluetoothGranted,
                              onGrant: { onOnboardingGrant(.bluetooth) })
                permissionRow(icon: "calendar",
                              label: "Calendar",
                              reason: "Show your next event right in the island",
                              granted: onboardingState.calendarGranted,
                              onGrant: { onOnboardingGrant(.calendar) })
                permissionRow(icon: "location.fill",
                              label: "Location",
                              reason: "Power live weather in your glance",
                              granted: onboardingState.locationGranted,
                              onGrant: { onOnboardingGrant(.location) })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Round 3 — extra horizontal inset so the pill rows show visible margin against
            // the card edges instead of nearly spanning edge-to-edge (applied AFTER the
            // maxWidth fill, so it insets the already-full-width block on both sides).
            .padding(.horizontal, 8)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // 26-UI-SPEC.md Permission row layout: icon 16px + Label/Reason text block + trailing
    // Grant chip (nil, not yet attempted) / granted-state view (true/false, an attempt
    // settled). D-03: a denial degrades to the SAME quiet grey text a never-asked row would
    // never even reach (the Grant chip stays until an attempt settles the state) — never an
    // error icon or dialog.
    // Round 2 (Droppy comparison) — wrapped in a near-capsule pill background (was a bare
    // HStack with no chrome of its own), matching Droppy's fully-rounded permission rows.
    // Round 3 — text/icon sizes and row padding shrunk slightly (14/12px -> 13/11px,
    // 12/8px padding -> 10/6px), scoped ONLY to these Permissions rows, to leave more
    // visible margin around the 3 pills within the fixed onboardingSize width. This is a
    // deliberate, narrow exception to the shared 14px Label / 12px Body scale used
    // everywhere else in the onboarding carousel (26-UI-SPEC.md Typography) — noted there.
    private func permissionRow(icon: String,
                                label: String,
                                reason: String,
                                granted: Bool?,
                                onGrant: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(reason)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if granted == nil {
                chipButton("Grant", fontSize: 11, action: onGrant)
            } else if granted == true {
                // Round 4 (on-device UAT, Droppy comparison) — checkmark only, "Granted" text
                // label dropped (was redundant next to the icon). D-03 semantics unchanged:
                // this is still the only state that gets an icon at all.
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                // D-03 — deliberately NOT the codebase's existing checkmark/xmark pair (an
                // xmark reads as a failure/error, which D-03 explicitly forbids here); no
                // re-ask affordance inside onboarding, a skipped permission is granted later
                // via Settings.
                Text("Not granted")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        // Round 5 (on-device UAT) — a granted row gets a thin green border + a subtle static
        // glow, ponytail: the STATIC native approximation of the user's pasted web
        // "GlowingShadow" reference (React/CSS `@property` hue-rotating animation) — no
        // TimelineView/Animation loop, no color rotation, just `.overlay` + `.shadow`, matching
        // this app's existing quiet/native visual language (26-PATTERNS.md). nil/false rows are
        // completely untouched (no border, no shadow).
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.green.opacity(granted == true ? 0.5 : 0), lineWidth: 1)
        )
        .shadow(color: .green.opacity(granted == true ? 0.35 : 0), radius: 6)
    }

    // Step 4 (.done) renders via OnboardingDoneStep (below, own file-scope private struct) —
    // its Launch-at-Login @State must be scoped to just this step's lifetime, not a
    // NotchPillView property (which would leak across every other presentation case).

    // Bottom nav row (26-UI-SPEC.md): Back leading (hidden on .welcome), primary CTA
    // trailing. D-09: Back is always enabled, never a validation gate.
    // Round 2 (Droppy comparison) — Back/Next/Finish switched from text chips to icon-only
    // circular buttons (navCircleButton below); both circles share one diameter so the
    // HStack's default center-alignment keeps them vertically centered against each other.
    private func onboardingNavRow(_ step: OnboardingStep) -> some View {
        HStack {
            if step != .welcome {
                navCircleButton(systemName: "arrow.left", filled: false, action: onOnboardingBack)
            }
            Spacer()
            switch step {
            case .welcome, .trialLicenseBuy, .permissions:
                navCircleButton(systemName: "arrow.right", filled: true, action: onOnboardingNext)
            case .done:
                navCircleButton(systemName: "checkmark", filled: true, action: onOnboardingFinish)
            }
        }
        // Round 3 — the top padding that used to separate this row from flowing content above
        // it is gone; onboardingCarousel now positions this row as a fixed-offset overlay, not
        // as the tail of the same VStack, so no internal padding is needed here.
    }

    // Round 2 (Droppy comparison) — the circular Back/Next/Finish nav button: Back is an
    // outlined stroke circle with a left arrow, Next/Finish are a solid white filled circle
    // with an arrow/checkmark icon (Finish uses a checkmark rather than an arrow — same
    // solid-white-circle language, distinct icon for a terminal action; design judgment,
    // not spec-mandated). Replaces the earlier text chip nav per on-device feedback.
    private static let navCircleDiameter: CGFloat = 36

    // Phase 65 / QACTION-02 — `tint` added as an OPTIONAL trailing param (default nil) so every
    // existing call site (onboarding nav, Timer controls, switcher rows) compiles byte-identical
    // and renders unchanged; only quickActionsBarContent's tiles pass a non-nil value, for the
    // green (active) / red (failure) icon-tint states 65-UI-SPEC.md's Icon Catalog requires —
    // states the plain filled/outlined duality alone can't express. Reuses this ONE primitive
    // rather than a parallel button type (PATTERNS.md: "not a new tile/button style").
    // Quick task 260801 — `diameter` defaults to `navCircleDiameter` so every existing caller
    // (onboarding nav, Timer setup, replay-close) compiles byte-identical; only switcherRow/
    // topEdgeSwitcherRow pass an override, to apply the Switcher Tuner's size nudge without
    // touching this shared primitive's other 20+ call sites.
    private func navCircleButton(systemName: String, filled: Bool, tint: Color? = nil, diameter: CGFloat = navCircleDiameter, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint ?? (filled ? Color.black : Color.white))
                .frame(width: diameter, height: diameter)
                .background {
                    // Phase 72.1.1 Plan 04 (D-06 Tier 1) — same guarded-glass convention as
                    // quickActionButton above. filled ? 0 : 0.08 keeps the tint a no-op on the
                    // selected/solid-white circle (that state's own fill already dominates) and
                    // applies a light glass tint only to the unselected/idle circle; the
                    // `filled ? Color.white : Color.clear` selected-state signal itself is
                    // untouched in both branches (T-72.1.1-07).
                    // CR-01 fix (72.1.1 review) — also gated on materialStyle ==
                    // .liquidGlass, matching every other .glassEffect() call site.
                    if materialStyle == .liquidGlass, #available(macOS 26.0, *) {
                        Circle()
                            .fill(filled ? Color.white : Color.clear)
                            .glassEffect(.regular.tint(Color.white.opacity(filled ? 0 : 0.08)), in: Circle())
                    } else {
                        Circle().fill(filled ? Color.white : Color.clear)
                    }
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // Phase 54 / D-12 — replay-only close/X button, top-trailing of the carousel card, shown
    // ONLY during a mid-session onboarding replay (never real first-launch onboarding). Visible
    // across every step of a replay, not gated on step == .done — the carousel has no cancel
    // affordance today and D-12 requires one throughout.
    private var replayCloseButton: some View {
        Button(action: onOnboardingCancel) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    // The shared chip style (Grant, Enter License Key, Buy Islet) — reuses the existing
    // RoundedRectangle + Color.white.opacity(0.12) in-chrome control convention rather than
    // inventing a new button primitive (26-UI-SPEC.md Button/chip style). Round 2: Back/
    // Next/Finish moved off this style onto navCircleButton above; this remains the style
    // for the inline Grant/License/Buy actions, unchanged.
    // Phase 62-04 UAT round 3 fix (item F) — `selected` defaults to false so every existing
    // call site (Grant/License/Buy) renders byte-identical; the Timer duration chips are the
    // only callers passing `true`. Brighter fill + a white border ring mirrors
    // navCircleButton's own filled-vs-outlined selected/unselected duality (the closest
    // existing "this one is chosen" convention in this file) adapted to a rectangular chip.
    private func chipButton(_ label: String, fontSize: CGFloat = 14, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(selected ? 0.28 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(selected ? 0.9 : 0), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // Phase 15 architecture audit item 2 — the shared downward-blob skeleton for
    // expandedIsland/mediaExpanded/mediaUnavailable, mirroring wingsShape(content:)'s
    // precedent (Finding 12): NotchShape → .fill → .matchedGeometryEffect → .frame →
    // .overlay → .onTapGesture. The `alignment` parameter defaults to `.center` (today's
    // plain `.overlay(content())` for expandedIsland/mediaUnavailable); mediaExpanded
    // passes `.top` explicitly to preserve its camera-clearance pinning (default .center
    // would leave only ~22pt top clearance, not enough to clear the 32pt camera band).
    // collapsedIsland is NOT routed through this — DEBUG tint, hover scale, and dev
    // offset make it "not a clean fit" (CONTEXT.md).
    // Phase 18 round 3: the round-2 `size:` parameter (added solely for the now-superseded
    // standalone toast blob) is removed — the toast row is no longer a `blobShape` caller
    // (see `mediaWingsOrToast`), so every remaining caller uses the same `expandedSize`.
    // Phase 20 / SHELF-03/D-01/D-02 — extended with a `shelfItems` parameter: the visible black
    // shape only grows TALLER (by `shelfRowHeight`) when the shelf has content, uniformly across
    // every caller (expandedIsland/mediaExpanded/mediaUnavailable) — no per-branch special-casing.
    // The shelf row is appended BELOW each caller's own content, inside the SAME continuous
    // NotchShape/matchedGeometryEffect (D-07: no second shape, no cross-fade); each caller's own
    // `alignment` still governs ONLY its own content's box, unchanged from before this phase.
    // Phase 26 / ONBOARD-01 — extended with an optional `height` override so
    // onboardingCarousel(_:) can grow the blob to onboardingSize.height without a
    // second shape/fill mechanism. Every existing caller (expandedIsland, mediaExpanded,
    // mediaUnavailable) omits the new parameter and falls back to `Self.expandedSize.height`
    // -- byte-identical behavior to before this change. BOTH the outer shape frame
    // (totalHeight) and the inner content frame (baseHeight) grow together, or the shape
    // would be taller than the content stayed clipped to the old 144pt box.
    // Round 2 (Droppy comparison) — mirrors the same optional-override pattern with a
    // `width` parameter so onboardingCarousel can also widen to onboardingSize.width;
    // every other caller again omits it and falls back to `Self.expandedSize.width`.
    // Phase 28 / CALVIEW-01 (28-UI-SPEC.md Verification Notes) — extended with a `showSwitcher`
    // parameter mirroring `shelfItems`/`hasShelf`'s exact precedent: the switcher row is its OWN
    // independent reserved row (not squeezed into the content box), appended between `content()`
    // and the shelf row so both rows coexist without one clobbering the other's space (content ->
    // switcher -> shelf, top to bottom).
    // 28-04 round 5 (misclick/notch-close bug fix) — `showSwitcher: true` now ALSO forces
    // `baseHeight` to the shared `switcherContentHeight` constant, ignoring any `height:`
    // override a caller passes. Root cause this fixes: the switcher row is stacked immediately
    // AFTER `content()` in the VStack below, so `content()`'s box height directly determines the
    // switcher row's on-screen Y position — when different presentations passed different
    // `height:` values (144pt for Home/Weather/NowPlaying, 266pt for Calendar), the switcher
    // pill visually jumped up/down on every tab switch, and a click landing where it USED to be
    // (before the reflow settled) could miss it and collapse the island instead. Centralizing
    // the height decision HERE (rather than requiring every call site to agree on a value)
    // makes it structurally impossible for a future switcher-row caller to reintroduce the bug.
    private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                           bottomCornerRadius: CGFloat,
                                           alignment: Alignment = .center,
                                           width: CGFloat? = nil,
                                           height: CGFloat? = nil,
                                           shelfItems: [ShelfItem],
                                           shelfVisible: Bool,
                                           showSwitcher: Bool = false,
                                           switcherLayout: ActivitySettings.SwitcherLayout = .pill,
                                           @ViewBuilder content: () -> Content) -> some View {
        let hasShelf = shelfVisible
        let baseWidth = width ?? Self.expandedSize.width
        // Phase 32 / TRAY-05 (RESEARCH.md Pitfall 1) — an explicit `height:` override now wins
        // over the showSwitcher default. Before this reordering, `showSwitcher: true` hard-
        // overrode any `height:` argument, so trayFullView's new trayContentHeight override had
        // zero visual effect. No other showSwitcher: true caller (Home/Calendar/Weather/
        // NowPlaying) passes a `height:` argument, so they all continue falling through the `??`
        // to switcherContentHeight exactly as before.
        let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
        // Phase 52 / SWITCH-03 (D-06, RESEARCH.md Pitfall 1) — `showSwitcher` alone conflates
        // "reserve switcher-sized content height" (baseHeight, untouched above) with "show the
        // pill row itself". showsPillRow splits that second half out: the pill row's own
        // +switcherRowHeight box is added ONLY in pill layout, so top-edge mode's content area
        // keeps baseHeight exactly as pill mode's does, per D-06.
        let showsPillRow = showSwitcher && switcherLayout == .pill
        let totalHeight = baseHeight
            + (showsPillRow ? Self.switcherRowHeight : 0)
            + (hasShelf ? Self.shelfRowHeight : 0)
        let shape = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        return shape
            .fill(islandFill)
            // Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED order:
            // `.matchedGeometryEffect` must precede `.frame` (the effect is itself implemented
            // via an internal frame+offset; a local `.frame` placed before it overrides the
            // effect's own size interpolation). This reverses the file's previous "Phase 15
            // architecture audit item 2" convention, which was backwards — see collapsedIsland.
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: baseWidth, height: totalHeight)
            // Phase 35 / GLASS-01 (D-04): expanded island uses full-strength .expanded parameters.
            .overlay(liquidGlassEffectLayer(shape: shape, size: CGSize(width: baseWidth, height: totalHeight), parameters: .expanded))
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    content()
                        .frame(width: baseWidth, height: baseHeight, alignment: alignment)
                        // Phase 52 / SWITCH-03 (D-04/D-05) — content() already reserves the
                        // cameraClearance band via its own `.padding(.top, resolvedCameraClearance)`
                        // convention, so the top-edge icons render inside that already-reserved
                        // band with zero additional height reservation (D-06 preserved).
                        .overlay(alignment: .top) {
                            if showSwitcher && switcherLayout == .topEdge {
                                topEdgeSwitcherRow
                            }
                        }
                    if showsPillRow {
                        switcherRow
                    }
                    if hasShelf {
                        shelfRow(shelfItems)
                            .transition(.opacity)
                    }
                }
                // Phase 33 gap-closure (on-device UAT round 3) — `.overlay` does not clip its
                // content to the parent's bounds by default; any `content()` taller than its
                // `baseHeight` frame previously painted straight through onto whatever sat behind
                // the panel (the Weather Large daily list rendering over the desktop/other windows
                // instead of on the black island). Every blobShape caller benefits from this same
                // safety net, not just Weather — a well-fitted caller's content is unaffected.
                .frame(width: baseWidth, height: totalHeight, alignment: .top)
                .clipShape(shape)
            }
            // D-05: this single ancestor gesture already covered content's own empty space
            // before this phase; it now ALSO covers the switcher/shelf rows' empty space "for
            // free" — only ShelfItemView's own scoped tap/trash gestures and the switcher's own
            // Button taps intercept before it.
            .onTapGesture { onClick() }
    }

    // Phase 52 / SWITCH-03/04 (D-03) — extracted once so switcherRow (pill) and
    // topEdgeSwitcherRow (top-edge) share the exact same icon/action mapping — one shared
    // source feeds both layouts. Byte-identical to the 4 pairs switcherRow used to hardcode.
    private func icon(for view: SelectedView) -> (systemName: String, action: () -> Void) {
        switch view {
        case .home:     return ("house.fill",     { onSwitcherSelect(.home) })
        case .tray:     return ("tray.fill",      { onSwitcherSelect(.tray) })
        case .calendar: return ("calendar",       { onSwitcherSelect(.calendar) })
        case .weather:  return ("cloud.sun.fill", { onSwitcherSelect(.weather) })
        case .timer:    return ("timer",          { onSwitcherSelect(.timer) })
        case .quickActions: return ("bolt.horizontal.fill", { onSwitcherSelect(.quickActions) })
        }
    }

    // Phase 28 / CALVIEW-01 (28-UI-SPEC.md "Switcher pill") — the Home/Tray/Calendar/Weather
    // switcher, reusing `navCircleButton` verbatim (same circular nav-button visual language as
    // onboarding's Back/Next/Finish). `filled:` marks whichever icon matches
    // `viewSwitcherState.selectedView`; each tap only REPORTS intent via `onSwitcherSelect` — no
    // precedence re-deciding here (Pattern 3: the resolver stays the single arbiter).
    // 28-04 round 4 (user-confirmed scope expansion) — Weather appended as the 4th icon, after
    // Calendar (Home/Tray/Calendar/Weather order, existing three left untouched).
    // Phase 52 / SWITCH-04 (D-03) — the hardcoded 4-button HStack is now a ForEach over
    // orderedSlotViews (always exactly 4 elements — Phase 45 structural-identity rule: no
    // conditional child count, no AnyView), so reassigning a slot reorders this row live.
    private var switcherRow: some View {
        HStack(spacing: 8) {
            ForEach(orderedSlotViews, id: \.self) { view in
                let mapping = icon(for: view)
                navCircleButton(systemName: mapping.systemName,
                                 filled: viewSwitcherState.selectedView == view,
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: mapping.action)
            }
            // Phase 62-04 UAT design revision (item 6) — Timer is a FIXED 5th tab, appended
            // after the 4 user-configurable slots (not one of them — SelectedView.timer is
            // deliberately excluded from orderedSlotIcons/the Settings slot dropdowns).
            // Gated on timerEnabled, mirroring the removed inline "Start Timer" button's own gate.
            if timerEnabled {
                let mapping = icon(for: .timer)
                navCircleButton(systemName: mapping.systemName,
                                 filled: viewSwitcherState.selectedView == .timer,
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: mapping.action)
            }
        }
        .frame(height: Self.switcherRowHeight)
    }

    // Phase 52 / SWITCH-03 (D-04/D-05, RESEARCH.md Pattern 2) — independently resolves the live
    // built-in notched screen (no controller plumbing, mirrors NotchWindowController.
    // currentBuiltin()'s exact pattern) and returns the real camera-cutout width via Plan 52-01's
    // pure NotchGeometry helper below — the correct center-spacer value, never
    // auxLeftWidth + auxRightWidth (RESEARCH.md Pitfall 2). Falls back to 0 (never crashes) when
    // no notched built-in screen is present.
    private var topEdgeCutoutWidth: CGFloat {
        guard let target = selectTargetScreen(from: NSScreen.screens.map { $0.descriptor }) else { return 0 }
        return topEdgeCutoutGap(screenWidth: target.frame.width,
                                safeAreaTop: target.safeAreaTop,
                                auxLeftWidth: target.auxLeftWidth,
                                auxRightWidth: target.auxRightWidth)
    }

    // Phase 67.1-02 / D-05/D-06 — live auto-detected scale from the current built-in screen's
    // width in points, mirroring topEdgeCutoutWidth's exact live-screen-read shape. Falls back
    // to identity 1.0 (never crashes) when no notched built-in screen is present.
    private var autoIslandScale: CGFloat {
        guard let target = selectTargetScreen(from: NSScreen.screens.map { $0.descriptor }) else { return 1.0 }
        return islandAutoScaleFactor(screenWidthPoints: target.frame.width)
    }

    // 67.1-07 (D-13) — expanded state is auto-only going forward; the manual Width/Depth
    // sliders now drive collapsed-state wing content instead via resolvedWingWidthScale/
    // resolvedWingDepthScale (Plan 08).
    private var resolvedWidthScale: CGFloat {
        resolvedIslandScale(auto: autoIslandScale, manualOffset: 0)
    }

    // 67.1-07 (D-13) — see resolvedWidthScale comment above.
    private var resolvedDepthScale: CGFloat {
        resolvedIslandScale(auto: autoIslandScale, manualOffset: 0)
    }

    // 67.1-08 (D-12/D-14): retargets the SAME @AppStorage offsets Plan 07 stopped feeding into
    // resolvedWidthScale/resolvedDepthScale (expanded content, now auto-only) — this drives
    // collapsed-state Live Activity wing content instead. Identical auto+manual mechanism
    // (D-07/D-08: auto default, manual offset from it, 0.8...1.5 clamp) as the property it
    // replaces conceptually; only the TARGET changed, not the math.
    private var resolvedWingWidthScale: CGFloat {
        resolvedIslandScale(auto: autoIslandScale, manualOffset: CGFloat(islandWidthScaleOffset))
    }
    private var resolvedWingDepthScale: CGFloat {
        resolvedIslandScale(auto: autoIslandScale, manualOffset: CGFloat(islandDepthScaleOffset))
    }

    // Phase 52 / SWITCH-03 (D-04/D-05) — the alternate top-edge switcher layout: 4
    // navCircleButtons flanking the camera/notch cutout, 2 left + 2 right, sharing
    // orderedSlotViews/icon(for:) with switcherRow (D-03: one shared ordering source feeds
    // both layouts) so `filled:` selection state falls out for free, identical predicate. Plain
    // HStack(spacing: 0) + Color.clear spacer for the excluded center region — never
    // `.offset`/`.position`, both empirically broken inside this codebase's shape/content stack
    // (Phase 39 lesson, RESEARCH.md Anti-Patterns).
    private var topEdgeSwitcherRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                let leftOuter = icon(for: orderedSlotViews[0])
                navCircleButton(systemName: leftOuter.systemName,
                                 filled: viewSwitcherState.selectedView == orderedSlotViews[0],
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: leftOuter.action)
                let leftInner = icon(for: orderedSlotViews[1])
                navCircleButton(systemName: leftInner.systemName,
                                 filled: viewSwitcherState.selectedView == orderedSlotViews[1],
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: leftInner.action)
            }
            Color.clear.frame(width: topEdgeCutoutWidth)
            HStack(spacing: 8) {
                let rightInner = icon(for: orderedSlotViews[2])
                navCircleButton(systemName: rightInner.systemName,
                                 filled: viewSwitcherState.selectedView == orderedSlotViews[2],
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: rightInner.action)
                let rightOuter = icon(for: orderedSlotViews[3])
                navCircleButton(systemName: rightOuter.systemName,
                                 filled: viewSwitcherState.selectedView == orderedSlotViews[3],
                                 diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                 action: rightOuter.action)
                // Phase 62-04 UAT design revision (item 6) — same fixed 5th Timer icon as
                // switcherRow (pill layout), appended to the right group here since there is
                // no free space near the camera cutout to split it symmetrically.
                if timerEnabled {
                    let timerMapping = icon(for: .timer)
                    navCircleButton(systemName: timerMapping.systemName,
                                     filled: viewSwitcherState.selectedView == .timer,
                                     diameter: Self.switcherIconDiameter + switcherSizeNudge,
                                     action: timerMapping.action)
                }
            }
        }
        .frame(height: Self.cameraClearance)
    }

    // Phase 20 / SHELF-03/05 — the horizontally-scrolling shelf strip: per-item icon+caption+
    // trash (ShelfItemView), then a far-right delete-all trash icon. No `.onTapGesture` is
    // attached to this container itself — D-05 falls out for free via blobShape's own trailing
    // ancestor gesture (see above).
    // Phase 32 / TRAY-05 gap-closure (on-device UAT round 3) — `rowHeight` defaults to the
    // shared `shelfRowHeight` (56, sized for this row's OTHER callers' 28x28pt icons, still
    // untouched) so nothing changes for them; `trayFullView` overrides it with the taller
    // `trayShelfRowHeight` sized for Tray's 40x40pt icons, so the filename caption no longer
    // renders past the black shape's own bottom edge.
    // Round 4-8 — `topInset` defaults to 0 (no change for the other callers); `trayFullView`
    // passes `trayShelfRowTopInset` so the icon/badge get deterministic clearance from the
    // shape's top edge. Root cause found via round 6-7's on-device debug-border/live-value
    // diagnostic (values arrived correctly every round — this was always a pure layout-
    // placement bug, not a wiring bug): a plain `ScrollView(.horizontal)`, once an ancestor
    // forces its cross-axis (vertical) frame taller than its own content, vertically CENTERS
    // that content by default — so every previous round's `topInset` bump just grew the
    // HStack's own natural height, which then got re-centered within the also-grown
    // `rowHeight` box, netting out to roughly the same small centering gap every time (matches
    // exactly what was observed: the shape/switcher row grew, but the icon's position relative
    // to the row's own top never moved). `.frame(maxHeight: .infinity, alignment: .top)` makes
    // the (padded) HStack report that it wants to fill all available height and top-align
    // within it, which removes the "smaller content in a taller box" condition that triggers
    // centering in the first place — `topInset`'s padding is then a real, un-fought linear gap.
    private func shelfRow(_ items: [ShelfItem], rowHeight: CGFloat = Self.shelfRowHeight, topInset: CGFloat = 0) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {   // Phase 32 / TRAY-05: bumped from 10 to match larger tiles, UI-SPEC
                ForEach(items, id: \.id) { item in
                    ShelfItemView(item: item,
                                  onTap: { onShelfItemTap(item) },
                                  onDelete: { onShelfItemDelete(item.id) },
                                  onDragStarted: { onShelfItemDragStarted() })
                }
                Button(action: onShelfClearAll) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))   // Phase 32 / TRAY-05: bumped from 14
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear shelf")
            }
            // Gap-closure (on-device UAT round 10-11) — "die Datei am rand fast genau anliegt
            // und der Name aus der Island rausguckt" (the filename pokes past the shape's edge).
            // ShelfItemView's filename caption is `.frame(maxWidth: 56)`, wider than the 40pt
            // icon above it, so it overhangs 8pt beyond the icon's own bounds on EACH side
            // (was true for the original 28pt icon / 44pt caption too — same 8pt overhang by
            // design, just never visibly clipped before this phase's wider/narrower geometry
            // made it noticeable). Round 10 bumped 16 -> 24 (16 + the 8pt overhang) to give the
            // caption the same real ~16pt clearance the icon itself already had; round 11
            // ("bisschen weiter nach Abstand") bumped again to 32 for more comfortable margin,
            // confirmed still fits comfortably at traySize.width (650) before scrolling kicks in.
            .padding(.horizontal, 32)   // row-padding, UI-SPEC (round 10: 16 -> 24; round 11: 24 -> 32)
            .padding(.top, topInset)   // Phase 32 / TRAY-05 gap-closure round 4 — 0 for shared callers
            .frame(maxHeight: .infinity, alignment: .top)   // round 8 — top-align, see comment above
        }
        .scrollIndicators(.never)
        // Gap-closure (Phase 32 on-device UAT round 2) — self-declares maxWidth: .infinity
        // (mirrors dayListColumn's precedent in calendarFullView) instead of relying on an
        // ancestor to force full width: a ScrollView proposed no width fills its own intrinsic
        // content size, not the available card width, which left this strip pinned to its
        // natural (small) size and left-hugging the corner instead of spanning/insetting
        // properly inside the wider Tray card.
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: rowHeight)
    }

    // Finding 12 — the shared flat-strip skeleton `wings(for:)` and `deviceWings(for:)` each
    // repeated: NotchShape → .fill → .matchedGeometryEffect → .frame → .overlay(content sized
    // the same). Their size constants were already numerically identical (290×32, the
    // post-checkpoint "one uniform width" decision), so this collapses them into the single
    // `wingsSize`. Each caller supplies only its own distinct HStack content.
    // Phase 18 round 3: `mediaWingsOrToast` no longer routes through this helper — its bottom
    // corner radius and height must vary with the toast, so it builds its own NotchShape
    // directly (see that function's comment) rather than the always-flat 6/6 this returns.
    // Round N+1 (post-77ecd18 checkpoint, user request) — the LEFT (icon+label) and RIGHT
    // (battery/ring/xmark) flanks now size INDEPENDENTLY instead of sharing one symmetric
    // `width`. A single width can't express "left grows for a wide label, right stays
    // compact": increasing it grows both edges equally around this view's own geometric
    // center. Instead the view's total width is still `leftWidth + rightWidth`, but the
    // HorizontalAlignment.center guide is overridden to sit at `leftWidth` from the leading
    // edge (not width/2) — the parent `ZStack(alignment: .top)` (body, ~L736) centers every
    // child using THAT guide, so the notch stays pinned at x=leftWidth: leftWidth of pill
    // extends left of the notch, rightWidth extends right, each shrinking/growing on its own.
    private func wingsShape<Content: View>(
        leftWidth: CGFloat = Self.wingsSize.width / 2,
        rightWidth: CGFloat = Self.wingsSize.width / 2,
        depthScale: CGFloat = 1.0,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // 71-REVIEW CR-01 gap closure — the self-intersecting-path freeze this nudge caused is
        // now prevented inside NotchShape.path(in:) itself (scales both radii down together if
        // their sum would exceed the rendered rect), so this call site no longer needs its own
        // clamp — nor do the sibling leading/trailing/margin nudges, which reach the same shape
        // via leftWidth/rightWidth below and were never clamped here either.
        let shape = NotchShape(topCornerRadius: Self.wingBaseTopCornerRadius + wingCornerRadiusNudge, bottomCornerRadius: Self.wingBaseBottomCornerRadius + wingCornerRadiusNudge)   // flatter than the downward blob; smaller radius than blobShape's 24 — wings' 32pt-tall strip can't fit a 24pt top radius alongside an 8pt bottom radius without squeezing the wall to almost nothing (16/8 base, SHAPE-02)
        let size = CGSize(width: leftWidth + rightWidth, height: Self.wingsSize.height * depthScale + wingHeightNudge)
        return shape
            .fill(islandFill)
            // Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED order,
            // see collapsedIsland/blobShape: `.matchedGeometryEffect` must precede `.frame`.
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: size.width, height: size.height)
            // 67.1-06 (D-10) follow-up — same root cause as collapsedIsland: leftWidth/rightWidth
            // (and therefore `size`) for camera-clearance callers (osdWings, capsLockWings) derive
            // from the live-measured `interaction.collapsedNotchSize`, so this frame can ride along
            // on an ambient animation transaction from an unrelated simultaneous state change,
            // letting the camera-clearance geometry visibly lag after a live resolution switch.
            .animation(nil, value: size)
            // Phase 35 / GLASS-01 (D-04): wings use full-strength .expanded parameters.
            .overlay(liquidGlassEffectLayer(shape: shape, size: size, parameters: .expanded))
            // 39-07 gap closure ROUND 11 — `alignment: .leading` added (was implicit `.center`).
            // Root cause found by direct code read, not another guess: `.frame(width:height:)`
            // with no `alignment:` CENTERS `content()` inside this box based on `content()`'s own
            // NATURAL/intrinsic size, not pinned to the box's leading edge. Every existing caller
            // (Charging/Device/Focus wings) builds `content()` as `HStack(spacing: 0) { ...
            // Spacer() ... }` — a `Spacer()` makes the HStack's natural width expand to exactly
            // fill whatever width it's proposed, so its natural size already equals `size.width`
            // and centering was always a no-op for them (confirmed by reading all 3 other call
            // sites before this change — none behave differently under `.leading` vs the old
            // `.center` default, since a child exactly as big as its container can't be
            // off-center in either direction). ROUND 10's OSD content is a `ZStack` with NO
            // `Spacer()`, positioning icon/bar via `.offset(x:)` instead — and `.offset()` is a
            // pure RENDER-TIME transform that does not contribute to a view's reported layout size
            // to its ancestors (standard, documented SwiftUI behavior). That ZStack's natural width
            // is therefore just its widest un-offset child (~90pt, the bar's own fixed frame),
            // nowhere near the real `size.width` (250-300pt+ after ROUND 10's exclusion-zone math)
            // — so the old implicit `.center` was silently shifting the WHOLE ZStack (and every
            // offset computed relative to its origin) rightward by `(size.width - ~90) / 2`,
            // dragging the icon behind the camera and pushing the bar's offset origin far enough
            // right that it rendered outside the visible pill shape entirely. `.leading` pins the
            // ZStack's un-shifted local x=0 to the box's own true leading edge, which is what
            // every one of ROUND 10's `excludedMinX`/`excludedMaxX`-relative offsets already
            // assumed was true.
            // Gap closure (71-02 on-device UAT) — mirrors blobShape's clipShape safety net
            // (line ~2822): SHAPE-02's larger 16/8 corner radii grew the concave top-corner
            // "ear" cutout enough that content sitting near it (album art, wing icons) now
            // painted through onto the desktop instead of stopping at the silhouette. The
            // old 12/6 radii never exposed this — the cutout was too small for any content
            // to reach. Without this, `.overlay` never clips to the parent's bounds by default.
            .overlay(
                content()
                    .frame(width: size.width, height: size.height, alignment: .leading)
                    .clipShape(shape)
            )
            .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
            // Finding 15 (06-10): both remaining wing glances (wings(for:), deviceWings(for:))
            // share this one tap-to-toggle through the shared helper.
            // Phase 60-04: `onTap` is an optional per-wing override — every existing call site
            // omits it (nil) and keeps the universal `onClick()` expand-to-Home behavior; only
            // `updateWings(for:)` passes a non-nil override to trigger Sparkle's install flow.
            .onTapGesture { (onTap ?? onClick)() }
    }

    // CHG-01 / D-01 / D-03 / D-04 / D-05 — the WINGS / Alcove sideways layout: a flat, wide strip
    // flanking the notch. Status symbol LEFT (a bolt — yellow while charging, dim otherwise), the
    // SAME horizontal BatteryIndicator as the device glance on the RIGHT (post-checkpoint user
    // request: one consistent battery element across charging + device). The view drives NO
    // animation (D-08); the controller (Plan 03) wraps the activity mutation in its spring wrapper.
    private func wings(for activity: ChargingActivity) -> some View {
        let isCharging: Bool
        let percent: Int
        switch activity {
        case .charging(let p): isCharging = true;  percent = p
        case .full(let p):     isCharging = false; percent = p
        case .onBattery(let p):isCharging = false; percent = p
        }
        // Quick task 260729-47v Round 6 — migrated OFF the fixed leftWidth/rightWidth halves +
        // flexible Spacer() (260729-3pc Round 5's own simplification, itself inherited from before
        // round 4's camera-clearance fix) onto the SAME notch-cutout-derived margin+cameraBlockWidth
        // formula every other wing already uses (focusWings/deviceWings/osdWings/capsLockWings). User
        // reported Margin (and Leading/Trailing) nudging did nothing here — this was the one
        // remaining wing never converted in round 4; Charging's redesign (round 5) came after round 4
        // and kept the old mechanism. Mirrors focusWings(for:)'s own structure (icon + camera block +
        // fixed-width trailing content), the closest existing analog to this wing's own simple
        // icon+battery layout.
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Quick task 260729-4oi Round 7: baked in from on-device tuning (margin -15, leading +6,
        // trailing +6) — confirms round 6's margin/cameraBlockWidth conversion works.
        // Quick task 260729-54f Round 10: further tuned after the "Charging..." text was added back
        // (margin +25, leading +6, trailing -14).
        let margin: CGFloat = 34 + wingMarginNudge   // +20 reverted per user request, back to original
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2
        let leadingPad: CGFloat = 30 + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // Quick task 260729-4yy Round 9 — user asked for a "Charging..." text back on the right
        // (the battery+bolt icon alone wasn't enough). "Charging..." (11 chars) at 12pt semibold
        // rounded — same estimate-for-known-short-content style as deviceWings' old "Connected"
        // (9 chars) -> 70pt; a couple points wider here for the 2 extra characters.
        let rightContentWidth: CGFloat = 80
        let trailingPad: CGFloat = 16 + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth + rightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Charging camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Charging wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        _ = percent   // no longer displayed — see comment above
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: resolvedWingDepthScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                // Quick task 260729-4oi Round 7: replaced powerplug.fill + separate BatteryIndicator
                // with ONE combined "charging battery" SF Symbol per the user's reference image —
                // SF Symbol name not on-device-verified this round, flag if it renders blank/wrong.
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: iconWidth, height: Self.wingsSize.height * resolvedWingDepthScale, alignment: .center)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                // Quick task 260729-4yy Round 9 — "Charging..." text re-added per user request.
                Text("Charging...")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: rightContentWidth, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // 67.1-10 (D-14) — the ORIGINAL bug that triggered this entire phase amendment: unlike the
    // other 9 wings (osdWings/capsLockWings/etc., Plans 08/09), mediaWingsOrToast never adopted
    // the live-hardware camera-clearance mechanism — it sized itself from a fixed
    // Self.wingsSize.width (290pt) constant with a plain, non-measuring Spacer() for camera
    // clearance. At a non-baseline resolution (1710x1112) the real camera cutout exceeds what
    // that fixed combination naturally reserves, clipping the album art and the 5th equalizer
    // bar. Mirrors osdWings' proven rawNotchHalfWidth+margin pattern (39-07 ROUND 15/16), NOT
    // wingsShape — mediaWingsOrToast builds its own shape/frame directly since its bottom
    // corner radius varies with the song-change toast (see this function's own header comment
    // below). cameraBlockWidth is returned alongside left/right so mediaWingsRow never
    // recomputes the notch-clearance formula independently (single source of truth).
    private func mediaWingContentWidth() -> (left: CGFloat, right: CGFloat, cameraBlockWidth: CGFloat) {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        let margin: CGFloat = 5 + wingMarginNudge   // +20 reverted per user request, back to original
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2   // T-67.1-14: never scaled by wing scale, at any slider position
        let leadingPad = 28 * resolvedWingWidthScale + wingLeadingNudge     // +6 baked in from on-device tuning, all wings, post-SHAPE-02 (was 22), D-14 scaled
        let trailingPad = 34 * resolvedWingWidthScale + wingTrailingNudge    // +10 baked in from on-device tuning, all wings, post-SHAPE-02 (was 24), D-14 scaled
        let artSide = (Self.wingsSize.height - 8) * resolvedWingDepthScale   // album art's square side — scaled with depth; no camera-safety floor on this axis
        let eqBarsWidth: CGFloat = 21   // EqualizerBars' own intrinsic width: 5 * barWidth(1) + 4 * spacing(4) — fixed, content stays fixed size on the width axis
        let left = leadingPad + artSide + cameraBlockWidth / 2
        let right = (leadingPad + artSide + cameraBlockWidth + eqBarsWidth + trailingPad) - left
        return (left, right, cameraBlockWidth)
    }

    // D-02/D-03/D-04/D-05 — the MEDIA glance WINGS: the collapsed now-playing peek.
    // Same flat strip shape + shared morph identity + wingsSize as the charging wings, so
    // SwiftUI morphs the ONE black island between the charging/media/expanded/collapsed
    // states (no cross-fade). Album art on the LEFT wing, the animated equalizer bars on
    // the RIGHT wing. `isPlaying` is derived from the presentation: `.playing` → bars bounce,
    // `.paused` → bars freeze static (D-05). The bars are the ONLY continuous animation in
    // the app and are isPlaying-gated for the idle-CPU guarantee (D-04, see EqualizerBars).
    // Phase 18 / NOW-05 — post-checkpoint ROUND 3 (on-device feedback, supersedes round 2's
    // either/or branch between `mediaWings` and a standalone `songChangeToastView` blob): the
    // user asked for the wings row to stay EXACTLY as it renders today, with a small text row
    // fading in BELOW it in the SAME continuous shape — not a different shape swapped in.
    // This is no longer an if/else between two shapes; it's ONE shape (flat-ish top, a more
    // rounded — blob-like — bottom once the toast row appears) whose height/content grows
    // conditionally. Row 1 is `mediaWingsRow`, byte-for-byte the same HStack the old
    // `mediaWings(_:art:)` rendered (art left, equalizer right) so the collapsed glance is
    // visually unchanged; row 2 (`toastTextRow`) is present only while `songChangeToast` is
    // non-nil and carries `.transition(.opacity)` so it fades in/out under whichever spring
    // the controller is already running when the toast field flips (D-08: the view drives no
    // animation of its own — see NotchWindowController's presentTransientChange/
    // scheduleToastDismiss, which all wrap the mutation in `withAnimation(.spring(...))`).
    @ViewBuilder
    private func mediaWingsOrToast(_ p: NowPlayingPresentation) -> some View {
        let toast = nowPlaying.songChangeToast
        // 67.1-10 (D-14) — replaces the old fixed 290pt constant + a plain flexible spacer:
        // width is now derived from the live camera cutout (mediaWingContentWidth()), never guessed.
        let (leftWidth, rightWidth, cameraBlockWidth) = mediaWingContentWidth()
        let width = leftWidth + rightWidth
        // 67.1-10 (D-14): height now scales with resolvedWingDepthScale, like every other wing.
        let height = Self.wingsSize.height * resolvedWingDepthScale + wingHeightNudge + (toast != nil ? Self.toastExtraHeight : 0)
        // WR-02 (35-REVIEW.md): hoisted so the visible fill and the rim-mask
        // overlay below always share one shape instance — see collapsedIsland.
        let shape = NotchShape(topCornerRadius: Self.wingBaseTopCornerRadius, bottomCornerRadius: toast != nil ? 16 : Self.wingBaseBottomCornerRadius)
        shape
            .fill(islandFill)
            // Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED order:
            // `.matchedGeometryEffect` must precede `.frame` (round 2 had this backwards too,
            // matching the file's previous — wrong — "canonical" convention; see collapsedIsland
            // for the full explanation of why frame-before-effect breaks the size morph).
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: width, height: height)
            // 67.1-10 (D-14) follow-up — same root cause as wingsShape/collapsedIsland: width
            // now derives from the live-measured interaction.collapsedNotchSize, so this frame
            // can ride along on an ambient animation transaction from an unrelated simultaneous
            // state change, letting the camera-clearance geometry visibly lag after a live
            // resolution switch. Mirrors D-10/Plan 06's fix for collapsedIsland/wingsShape.
            .animation(nil, value: CGSize(width: width, height: height))
            // Phase 35 / GLASS-01 (D-04): media wings use full-strength .expanded parameters.
            .overlay(liquidGlassEffectLayer(shape: shape, size: CGSize(width: width, height: height), parameters: .expanded))
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    mediaWingsRow(p, art: nowPlaying.artwork, leftWidth: leftWidth, rightWidth: rightWidth, cameraBlockWidth: cameraBlockWidth)
                    if let toast {
                        toastTextRow(toast)
                            .transition(.opacity)
                    }
                }
                // Gap closure (71-02 on-device UAT) — see wingsShape's identical comment:
                // SHAPE-02's larger top-corner cutout now lets album art paint through onto
                // the desktop without this clip. Explicit frame first so clipShape has the
                // same rect the shape's own path was built against (mirrors blobShape).
                .frame(width: width, height: height, alignment: .top)
                .clipShape(shape)
            }
            // 67.1-10 (D-14): true center — not geometric width/2 — now that leftWidth/rightWidth
            // can be asymmetric; mirrors wingsShape's own alignmentGuide mechanism (line ~3005).
            .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
            // Finding 15 (06-10) precedent: the shared tap-to-toggle, same as wingsShape's
            // callers — no buttons live in this content, so one ancestor gesture is safe.
            .onTapGesture { onClick() }
    }

    // Row 1 — the collapsed media glance content. Album art LEFT, animated equalizer bars
    // RIGHT — visual output unchanged from before this phase (D-02). 67.1-10 (D-14): the
    // old flexible separator element that previously separated them is replaced by an EXPLICIT
    // fixed-width Color.clear block (mirroring osdWings'/capsLockWings' own convention, 39-07 —
    // a flexible separator only correlates with where the camera roughly is, an explicit
    // fixed-width element mechanically cannot be skipped or shrunk). leftWidth/rightWidth/
    // cameraBlockWidth all come from mediaWingContentWidth() via mediaWingsOrToast, the single
    // source of truth — this function recomputes nothing.
    private func mediaWingsRow(_ presentation: NowPlayingPresentation, art: NSImage?, leftWidth: CGFloat, rightWidth: CGFloat, cameraBlockWidth: CGFloat) -> some View {
        let isPlaying = isPlayingFor(presentation)
        return HStack(spacing: 0) {
            artThumbnail(art, side: (Self.wingsSize.height - 8) * resolvedWingDepthScale, corner: 6)  // LEFT wing
                .padding(.leading, 28 * resolvedWingWidthScale + wingLeadingNudge)   // inset from the outer notch edge, +6 baked in post-SHAPE-02, D-14 scaled
            Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block, not a flexible spacer
            EqualizerBars(isPlaying: isPlaying)  // RIGHT wing — EQ-01 bars, fixed white (no accent)
                .padding(.trailing, 34 * resolvedWingWidthScale + wingTrailingNudge)  // inset from the outer notch edge, +10 baked in post-SHAPE-02, D-14 scaled
        }
        .frame(width: leftWidth + rightWidth, height: Self.wingsSize.height * resolvedWingDepthScale)
    }

    // Phase 53 / RESUME-01/RESUME-02 — the idle hover-preview's own wings shape. Mirrors
    // `mediaWingsOrToast`'s scaffold (shape/matchedGeometryEffect/islandFill/
    // liquidGlassEffectLayer) rather than reusing that function directly — it also handles the
    // toast row, which this preview never needs. Success path shows a STATIC play glyph on the
    // right (NOT `mediaWingsRow`/`EqualizerBars`) — D-02 originally called for bouncing bars
    // identical to the live-playing glance, but on-device UAT (53-02) flagged that as
    // confusing: nothing is actually playing yet, so animated bars read as a lie. Superseded
    // D-02: static "play.fill" glyph signals "tap to resume" without implying live playback.
    // Failure path (D-03) replaces ONLY that glyph slot with static failure text, album art
    // stays visible. Quick task 260801-0br round 2 (on-device UAT) superseded D-01: the whole
    // wing now taps like every other collapsed glance (onClick → expand to Home); ONLY the
    // play-icon/failure-text slot has its own onResumeTap tap target.
    // Quick task 260801-0br (Fix #1) — converted from the old hardcoded-Self.wingsSize/
    // Spacer()-based layout to the shared camera-safe, resolution-aware wingsShape formula
    // every sibling wing already uses (modeled on deviceWings(for:), same margin as
    // mediaWingContentWidth() since this is the same "Now Playing" wing family). This was the
    // ONE wing never converted, so it never recomputed on resolution changes and was
    // disconnected from both the Settings Width/Depth sliders and the Wing Tuner nudges.
    private func resumePreviewWings(_ track: LastPlayedTrack) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        let margin: CGFloat = 5 + wingMarginNudge   // matches mediaWingContentWidth()'s own margin — same wing family
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2
        let leadingPad: CGFloat = 28 * resolvedWingWidthScale + wingLeadingNudge
        let trailingPad: CGFloat = 26 * resolvedWingWidthScale + wingTrailingNudge   // -8 baked in from on-device tuning, resume-preview wing only, quick task 260801-0br round 3 (was 34)
        let artSide = (Self.wingsSize.height - 8) * resolvedWingDepthScale
        // Round 2 (on-device UAT) — matches mediaWingContentWidth()'s own eqBarsWidth for the
        // common play-icon case, keeping this wing's margins pixel-identical to the live Now
        // Playing wing; only the rare failure-text case needs the wider 160pt.
        let eqBarsWidth: CGFloat = 21
        let rightContentWidth: CGFloat = nowPlaying.resumePreviewFailed ? 160 : eqBarsWidth
        let leftWidth = leadingPad + artSide + cameraBlockWidth / 2
        let totalWidth = leadingPad + artSide + cameraBlockWidth + rightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Resume preview camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Resume preview wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: resolvedWingDepthScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                artThumbnail(track.artwork, side: artSide, corner: 6)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                Group {
                    if nowPlaying.resumePreviewFailed {
                        Text("Wiedergabe nicht möglich")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: rightContentWidth, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onResumeTap() }
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // Row 2 (round 3, new) — the fading "Title — Artist" line under the wings row. TEXT ONLY:
    // the DynamicLake reference screenshot also shows transport buttons, but the user's own
    // words only asked for "titel mit Sänger" (title with artist) — this phase's scope
    // (18-UI-SPEC.md D-01/D-02) is a PASSIVE toast, so no play/pause/skip here. One combined
    // Text (not a title+artist HStack) so a long string truncates cleanly instead of the
    // artist half getting squeezed off — `.lineLimit(1)` + `.truncationMode(.tail)` bounds
    // untrusted metadata (T-04-09), same discipline as mediaExpanded's title/artist.
    private func toastTextRow(_ toast: TrackToast) -> some View {
        Text("\(toast.title) — \(toast.artist)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 16)
            // Round 4 (on-device feedback): centered, not tucked under the left-side art —
            // was `alignment: .leading` (D-01 left-align superseded, "mittig nicht linksbündig").
            .frame(width: Self.wingsSize.width, height: Self.toastExtraHeight, alignment: .center)
    }

    // DEV-01 / DEV-02 / D-02 / D-03 — the DEVICE connect/disconnect glance WINGS. Same flat strip
    // shape + shared morph identity as the charging/media wings, so SwiftUI MORPHS the ONE black
    // island between the device/charging/media/expanded/collapsed states (no cross-fade).
    //
    // LAYOUT (user request, post-checkpoint): the device GLYPH on the LEFT wing; on the RIGHT a
    // green battery indicator with % when the device reports one (Jabra etc., via
    // IOBluetoothDevice.batteryPercentSingle), else a small CONNECTION SIGN (accent checkmark
    // connected / dimmed xmark on disconnect — D-03). NO device name (drops the untrusted-name
    // render surface, T-05-01). The view drives NO animation (D-08); the controller wraps the
    // mutation in its spring and clears it after ~3s (D-04 dismiss).
    // Quick task 260729-47v Round 6 — hand-drawn Bluetooth bind-rune glyph (vertical spine + two
    // right-pointing "flag" triangles), the standard way to construct this shape from a square of
    // side `s`. Replaces the "dot.radiowaves.left.and.right" SF Symbol stand-in (260729-3pc Round 5)
    // per the user's explicit request + reference image showing the real recognizable Bluetooth logo.
    // Apple's SF Symbols set genuinely has no literal Bluetooth-logo glyph available to third-party
    // apps (re-confirmed this round). FIRST-PASS APPROXIMATION — proportions are not pixel-verified
    // against Apple's/Bluetooth SIG's exact official glyph; flagged in this plan's checkpoint for the
    // user to confirm on real hardware or request tweaks.
    // Quick task 260729-4oi Round 7 — replaced the hand-drawn Path approximation (Round 6) with
    // the user's own supplied reference icon (icons8-bluetooth-48.png, Assets.xcassets/
    // BluetoothGlyph.imageset, template-rendering-intent so it tints via .foregroundStyle like
    // every other wing's SF Symbol icon).
    private func bluetoothGlyph(size s: CGFloat, opacity: Double) -> some View {
        // Quick task 260729-4yy Round 9: inner scale 0.7 -> 0.98 (user: "0.4 nochmal größer", i.e.
        // current size * 1.4 = 0.7 * 1.4 = 0.98) per on-device feedback that the icon read too small.
        Image("BluetoothGlyph")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white.opacity(opacity))
            .frame(width: s * 0.98, height: s * 0.98)
            .frame(width: s, height: s)
    }

    private func deviceWings(for activity: DeviceActivity) -> some View {
        // Quick task 260729-3pc Round 5 — `glyph` no longer read (icon is now a single fixed symbol
        // regardless of device type, see below), so both switch cases drop their `let g` binding.
        let isConnected: Bool
        let battery: Int?
        switch activity {
        case .connected(_, _, let b): isConnected = true;  battery = b
        case .disconnected(_, _):     isConnected = false; battery = nil
        }
        let iconOpacity = isConnected ? 1.0 : 0.5   // D-03: disconnected dims the icon
        // Quick task 260729-2td — migrated from fixed leftWidth/rightWidth halves
        // (isConnected ? wingsLabelWidth/2 : wingsSize.width/2, rightWidth always wingsSize.width/2)
        // to the notch-cutout-derived margin+cameraBlockWidth formula every other wing already uses.
        // User reported Margin nudge did nothing here at all (no margin concept existed). leftWidth
        // still varies with isConnected exactly like before (label only shown when connected), just
        // derived from content widths + the shared camera block instead of two hardcoded halves.
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Starting value: 30 — an estimate chosen to land close to the old fixed footprints
        // (connected: leftWidth 200/rightWidth 145; disconnected: leftWidth 145/rightWidth 145 at
        // widthGrowth=1), not a live-measured value. Re-tune with Wing Tuner's Margin buttons
        // on-device; the checkpoint at the end of this plan is the real verification gate.
        // Quick task 260729-54f Round 10: baked in from on-device tuning after the Bluetooth icon
        // was enlarged (margin -5, leading +4, trailing +6).
        let margin: CGFloat = 25 + wingMarginNudge   // +20 reverted per user request, back to original
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2
        let leadingPad: CGFloat = 22 + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // Quick task 260729-47v Round 6 — "Connected" text removed entirely (see the leading content
        // below, no more conditional label); leftContentWidth no longer varies with isConnected.
        // labelGap/labelWidth locals (only ever sized to reserve room for that text) are removed —
        // nothing else in this function referenced them.
        let leftContentWidth = leadingPad + iconWidth
        // BatteryIndicator's own ~27pt body + 1.2pt spacing + 1.8pt nub (~30pt) — shared across all
        // 3 trailing states (battery, ring, xmark) so the wing's width doesn't jump when a device's
        // battery reading becomes available mid-session, mirroring downloadWings' own "one width
        // regardless of state" comment.
        let trailingContentWidth: CGFloat = 30
        let trailingPad: CGFloat = 30 + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leftContentWidth + cameraBlockWidth / 2
        let totalWidth = leftContentWidth + cameraBlockWidth + trailingContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Device camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Device wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: resolvedWingDepthScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                bluetoothGlyph(size: iconWidth, opacity: iconOpacity)
                    .frame(width: iconWidth, height: Self.wingsSize.height * resolvedWingDepthScale, alignment: .center)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                deviceTrailing(isConnected: isConnected, battery: battery)
                    .frame(width: trailingContentWidth, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // Phase 38 / HUD-05 — the FOCUS collapsed wing. Mechanical reapplication of Phase 36's
    // Droppy-pill wing language (38-UI-SPEC.md "Focus Wing Contract") — no new shape, no new
    // sizing constants. `FocusActivity` has exactly one case (`.on`, D-09: there is no "Focus
    // Off" render), so the label is ALWAYS shown (unlike Charging/Device's conditional-width
    // ternary) and `wingsShape` is called with the label-width half fixed rather than switched
    // on activity state. D-11 (locked): icon + label render in a FIXED white, never
    // deviceAccent/chargingAccent/any theme accent — a universal system-level state should
    // read consistently regardless of the user's chosen accent theme.
    private func focusWings(for activity: FocusActivity) -> some View {
        // Quick task 260729-2td — migrated OFF the fixed-footprint mechanism (260729-0b5's fix:
        // leftWidth/rightWidth held at fixed 118/160 * widthGrowth, margin only replacing an inner
        // Spacer()) onto the SAME notch-cutout-derived margin+cameraBlockWidth formula every other
        // wing already uses (osdWings/capsLockWings/mediaWingContentWidth). User reported Margin
        // nudging moved icon/text but never resized the actual visible island — only deriving
        // leftWidth/rightWidth FROM margin (not holding them constant) fixes that.
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Starting value: 0. Old leftWidth=118 sat almost exactly at "camera half-width (~89.5pt on
        // the dev machine that measured it, per capsLockWings' own comment) + icon(20) + leading
        // pad(14)" ≈ 123.5 — i.e. near-zero slack beyond the bare camera edge (this function's own
        // prior header comment already documented that floor). margin=0 reproduces "no extra
        // clearance beyond the bare floor". This is an ESTIMATE, not live-measured — re-tune with
        // Wing Tuner's Margin buttons on-device; the checkpoint at the end of this plan is the real
        // verification gate, not this number.
        let margin: CGFloat = 20 + wingMarginNudge   // +20 reverted per user request, back to original
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2
        let leadingPad: CGFloat = 24 + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // Circle(8) + gap(4 nominal) + "On" text (2 chars, 12pt semibold rounded, ~20pt) — same
        // estimate-for-known-short-content style as updateWings' labelWidth / meetingWings'
        // elapsedWidth. Not exact; live re-tuning is what the Wing Tuner itself is for.
        let rightContentWidth: CGFloat = 34
        let trailingPad: CGFloat = 26 + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth + rightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Focus camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Focus wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: resolvedWingDepthScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: iconWidth, height: Self.wingsSize.height * resolvedWingDepthScale, alignment: .center)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                HStack(spacing: 4 + wingGapNudge) {
                    Circle().fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("On")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: rightContentWidth, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // Phase 41 / HUD-08 (D-05) — urgency threshold: instant switch at 60s remaining, no
    // gradient/interpolation between orange and red (locked, 41-UI-SPEC.md).
    private func urgencyColor(for eventStart: Date, at now: Date) -> Color {
        eventStart.timeIntervalSince(now) < 60 ? .red : .orange
    }

    // Phase 41 / HUD-08 (D-04) — mm:ss, zero-padded, no hour component (max 59:59 since the
    // countdown only starts 1 hour before the event).
    private func formatMMSS(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // Phase 41 / HUD-08 — calendar icon left / live mm:ss right, mirrors focusWings(for:)'s
    // shape. CRITICAL: both the icon and text colors come from ONE shared `color` computed
    // inside the single TimelineView tick closure below — putting the Image outside the
    // TimelineView (frozen color, never re-renders) and only the Text inside would desync
    // icon/text color, exactly what 41-UI-SPEC.md's Verification Notes warns against.
    private func countdownWings(for activity: CalendarCountdownActivity) -> some View {
        // Quick task 260729-4oi Round 8 — migrated OFF the fixed leftWidth/rightWidth + flexible
        // Spacer() (this wing never had a margin concept, so wingMarginNudge had nothing to attach
        // to) onto the same notch-cutout-derived margin+cameraBlockWidth formula every other wing
        // now uses. Starting margin (20) mirrors timerWings' own plain-Countdown-class margin
        // (short mm:ss digits, no adjacent label) — not live-measured for THIS wing specifically,
        // re-tune with Wing Tuner if the footprint looks off.
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Quick task 260729-4yy Round 9: baked in from on-device tuning (margin +25, leading +6,
        // trailing -18) — confirms round 8's margin/cameraBlockWidth conversion works.
        let margin: CGFloat = 45 + wingMarginNudge   // +20 reverted per user request, back to original
        let cameraBlockWidth = (rawNotchHalfWidth + margin) * 2
        let leadingPad: CGFloat = 26 + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // mm:ss digits — same fixed-content estimate timerWings' own plain-Countdown branch uses.
        let rightContentWidth: CGFloat = 60
        let trailingPad: CGFloat = 12 + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth + rightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Countdown camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Countdown wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: resolvedWingDepthScale) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, activity.eventStart.timeIntervalSince(context.date))
                let color = urgencyColor(for: activity.eventStart, at: context.date)
                HStack(spacing: 0) {
                    Color.clear.frame(width: leadingPad)
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(color)
                        .frame(width: iconWidth, height: Self.wingsSize.height * resolvedWingDepthScale, alignment: .center)
                    Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                    Text(formatMMSS(remaining))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .frame(width: rightContentWidth, alignment: .leading)
                    Color.clear.frame(width: trailingPad)
                }
            }
        }
    }

    // 39-07 gap closure ROUND 9 — TEMPORARY runtime geometry instrumentation (remove once the
    // real fix is confirmed and applied). Three rounds (5, 7, 8) of THEORETICAL local-coordinate
    // derivation have each been wrong on real hardware, even with a self-consistency `assert` —
    // that assert only checks the formula agrees with itself, not that it agrees with reality.
    // This logs the ACTUAL on-screen frame SwiftUI renders for a view, no assumptions involved.
    // `space: .global` reports coordinates relative to the hosting window (top-left origin,
    // y-down, SwiftUI's own convention) — combined with `NotchWindowController`'s own `panel.frame`
    // (AppKit screen coordinates, bottom-left origin, y-up, logged separately at the same moment a
    // key press fires), the two can be reconciled into one absolute-screen-coordinate picture:
    // `screenX = panel.frame.origin.x + globalX` (Y needs an origin flip, panel.frame.height is
    // enough to do that by hand from the printed values). `space: .named("osdWing")` instead
    // reports coordinates relative to the wing's own outer container (set via `.coordinateSpace`
    // below), i.e. the SAME "local x from the wing's own leading edge" space `osdWings(for:)`'s
    // own `trackLeft`/`rightWidth` math assumes — this directly tells us whether that assumption
    // itself is correct, independent of the notch's absolute screen position.
    // ROUND 13 addition — `verdict`: an optional self-check computed FROM the measured frame,
    // in the SAME coordinate space `geo.frame(in:)` reports (no manual conversion needed). Added
    // because a hand cross-reference between this file's `.global` (SwiftUI window-local, top-left
    // origin, y-down) logs and `NotchWindowController`'s screen-coordinate (AppKit, bottom-left
    // origin, y-up) logs is exactly the kind of "two different coordinate systems, subtracted by
    // hand" error that produces misleading conclusions — this codebase has NO existing, proven
    // AppKit-screen <-> SwiftUI-window conversion helper (confirmed by search before writing this),
    // so inventing one just for a diagnostic print is unnecessary complexity for a question that
    // has a simpler, conversion-free answer: compare the icon/bar's measured frame against
    // `excludedMinX`/`excludedMaxX` in the wing's OWN `.named("osdWing")` space — the exact same
    // space those two values are already computed in. The app now prints the pass/fail verdict
    // itself; no one needs to convert or subtract anything by hand.
    private struct OSDFrameLogger: ViewModifier {
        let label: String
        let space: CoordinateSpace
        var verdict: ((CGRect) -> String)? = nil
        func body(content: Content) -> some View {
            #if DEBUG
            content.background(
                GeometryReader { geo in
                    let g = geo.frame(in: space)
                    Color.clear.onAppear {
                        let verdictText = verdict.map { " — \($0(g))" } ?? ""
                        print("[OSD-GEOM] \(label): x=\(String(format: "%.1f", g.minX)) y=\(String(format: "%.1f", g.minY)) w=\(String(format: "%.1f", g.width)) h=\(String(format: "%.1f", g.height))\(verdictText)")
                    }
                }
            )
            #else
            content
            #endif
        }
    }

    // Phase 39 / HUD-03/HUD-04 — the OSD (Volume/Brightness) collapsed wing. Mechanical
    // reapplication of `wingsShape()` + `focusWings`'s icon-only-left-flank convention
    // (39-UI-SPEC.md "OSD Wing Contract") — no new shape wrapper. Unlike Charging/Device,
    // the right wing is a NEW minimal two-layer Capsule fill bar (`OSDLevelBar` below), not
    // `BatteryIndicator` — that component's outline/nub/centered `Text("\(percent)%")` chrome
    // directly conflicts with D-01's "no numeric text anywhere" rule. D-02 (locked): icon +
    // bar are FIXED colors (white icon, green volume / orange brightness bar), never
    // accent-tinted. The view drives NO animation of its own (D-04) — the controller
    // (Plan 39-05) wraps every OSD mutation in its own `withAnimation(.spring(...))`.
    private func osdWings(for activity: OSDActivity) -> some View {
        let percent: Int
        let tint: Color
        let iconName: String
        switch activity {
        case .volume(let p, _):
            percent = p
            tint = Color.green
            // D-03 — driven by the SAME `OSDActivity.isMuted` computed property the bar's
            // fraction below also reads, never a second independently-triggered mute check.
            iconName = activity.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
        case .brightness(let p):
            percent = p
            tint = Color.orange
            iconName = "sun.max.fill"   // no muted-equivalent state for brightness
        }
        // D-03: bar fully drains when muted, else reflects the clamped percent (39-02 already
        // clamps 0...100 before this view ever sees it).
        let fraction = activity.isMuted ? 0.0 : CGFloat(percent) / 100.0
        #if DEBUG
        // 39-07 gap closure ROUND 5 timing instrumentation (temporary, remove once responsiveness
        // is confirmed fixed) — point (d): confirms exactly when SwiftUI actually re-evaluates this
        // view's body for a new fraction, so an on-device Console capture can show whether any lag
        // lives in the tap/dispatch/read path (OSDInterceptor/NotchWindowController) or in SwiftUI's
        // own render pipeline. (Restored in ROUND 7 — was accidentally dropped when ROUND 6's ruler
        // temporarily replaced this whole block; still needed, the timing readout is still pending.)
        print("[OSD-TIMING] d) osdWings body evaluated t=\(String(format: "%.2f", CFAbsoluteTimeGetCurrent() * 1000))ms fraction=\(fraction)")
        #endif
        // 39-07 gap closure ROUND 15 — back to plain sequential `HStack(spacing: 0)` layout, like
        // every OTHER wing (Charging/Focus/Device) already uses, none of which has ever had any of
        // this saga's problems. Rounds 10-14 tried two different SwiftUI "place at an absolute
        // coordinate" primitives in this exact `wingsShape`/`ZStack` context — `.offset(x:)` (round
        // 10-13; on-device evidence showed it never actually moved the bar's real render position:
        // `bar (named osdWing): x=0.0` no matter what `trackLeft` was set to) and `.position(x:y:)`
        // (round 14; on-device evidence showed BOTH icon and bar reporting the ZStack's full
        // `339.0pt` container width instead of their own real 20pt/90pt size, meaning `.position()`
        // pulled them out of normal layout in a way `GeometryReader` couldn't measure correctly
        // either). Two different absolute-placement primitives, two different unexplained failures,
        // in the ONE spot in this codebase that doesn't use plain HStack layout — that's a strong
        // signal to stop fighting the primitive and just use what already works everywhere else.
        //
        // The actual bug the user identified back in ROUND 10 is still fixed here, just expressed
        // differently: instead of a flexible `Spacer()` (leftover space that merely CORRELATES with
        // where the camera roughly is) or an offset/position coordinate calculation, the excluded
        // camera region is now a CONCRETE, explicit `Color.clear.frame(width: cameraBlockWidth)`
        // HStack element — sequential HStack layout adds fixed widths left-to-right with no
        // ambiguity, so the camera block mechanically CANNOT be skipped, shrunk, or miscounted the
        // way a `Spacer()` or a coordinate-math mistake could.
        //
        // THREE DISTINCT ZONES this codebase already models near the notch, kept deliberately
        // separate (do not conflate them, per the user's own explicit request from ROUND 12):
        //   (a) Physical camera cutout — `interaction.collapsedNotchSize` (UNFUDGED, `widthFudge:
        //       0`, the EXACT cutout macOS reports; see `NotchWindowController.positionAndShow()`'s
        //       own D-01 comment). THIS is the only source `cameraBlockWidth` below is built from.
        //   (b) Click/hover hot-zone — `NotchWindowController.hotZone` (padded larger, for a
        //       comfortable click target) — irrelevant to visual rendering, not used here.
        //   (c) Icon-safe-start / bar-safe-start — this function's own responsibility, now simply
        //       "whatever comes immediately before/after the camera-block HStack element."
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // ROUND 16 — margin bump, not another mechanism change. ROUND 15's HStack rebuild is
        // confirmed mechanically CORRECT: the on-device PASS/FAIL verdict showed the bar placed
        // EXACTLY at `excludedMaxX` with zero slack, and `.global` vs `.named("osdWing")` readings
        // agreed for the first time this whole saga (`384.5 - 155.5 = 229.0`, matching the named
        // reading exactly) — the layout mechanism itself is no longer in question. But with the bar
        // sitting exactly AT the computed boundary and zero extra buffer, ~50% of it was still
        // reported hidden — meaning `margin` (8pt, carried forward from ROUND 12) was tuned against
        // the BROKEN `.offset()` mechanism (rounds 10-13), so that reading was measuring noise, not
        // a real signal. This is the first trustworthy margin-insufficiency data point. Bumped
        // generously (8 -> 55, not another small nudge) — per explicit direction, erring toward
        // "plainly more margin than needed" over hunting for an exact minimal value after this much
        // effort already spent chasing precision that turned out to be built on a broken mechanism.
        let margin: CGFloat = 60 + wingMarginNudge   // +20 reverted per user request, back to original
        let notchHalfWidth = rawNotchHalfWidth + margin
        // 67.1-09 (D-14) — resolvedWingWidthScale/resolvedWingDepthScale (Plan 08) scale ONLY the
        // outermost footprint padding here; margin/cameraBlockWidth above (and every content width
        // below) stay completely untouched at every slider position.
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let iconLeadingPad: CGFloat = 30 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        let cameraBlockWidth = notchHalfWidth * 2   // the FULL excluded span, centered on the notch's true center
        let barWidth: CGFloat = 90
        // Quick task 260729-5jc: plain percent number to the right of the bar (no "%" sign).
        let percentGap: CGFloat = 10   // Quick task 260729-5pv: 4 -> 10 per user request
        let percentTextWidth: CGFloat = 22
        let trailingPad: CGFloat = 28 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02 (was 18)
        // `wingsShape`'s `alignmentGuide` pins local x=`leftWidth` to the notch's TRUE center — so
        // `leftWidth` must land exactly at the camera block's own midpoint (icon pad + icon width,
        // then half the camera block), which is what makes the block's fixed width actually line up
        // with the real notch instead of just being "some extra space somewhere in the middle."
        let leftWidth = iconLeadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = iconLeadingPad + iconWidth + cameraBlockWidth + barWidth + percentGap + percentTextWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        // For the PASS/FAIL verdict logging only — not used for positioning (sequential HStack
        // layout makes explicit offset/position math unnecessary; these two values just describe
        // where the camera-block element's own edges land, for a human-readable log).
        let excludedMinX = leftWidth - notchHalfWidth
        let excludedMaxX = leftWidth + notchHalfWidth
        // Runtime self-check (Swift's assert compiles out of Release) — sanity bounds, not a
        // position invariant (sequential HStack layout makes overlap structurally impossible by
        // construction, unlike the offset/position approaches rounds 10-14 tried): the camera block
        // must be a real positive width, and the wing's own footprint must stay inside the
        // ~325pt-per-side safe panel-frame budget established in round 5 (NotchWindowController's
        // unconditional trayFrame union).
        assert(cameraBlockWidth > 0, "OSD camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "OSD wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        #if DEBUG
        print("[OSD-GEOM] ROUND 15 sequential HStack layout: collapsedNotchSize=\(String(describing: interaction.collapsedNotchSize)) notchHalfWidth(+margin)=\(notchHalfWidth) cameraBlockWidth=\(cameraBlockWidth) leftWidth=\(leftWidth) rightWidth=\(rightWidth) totalWidth=\(totalWidth)")
        #endif
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: iconLeadingPad)
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)                         // D-02: never accent-tinted
                    .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                    .modifier(OSDFrameLogger(label: "icon (named osdWing)", space: .named("osdWing"), verdict: { g in
                        g.maxX <= excludedMinX
                            ? "PASS (icon ends at \(String(format: "%.1f", g.maxX)), excludedMinX=\(String(format: "%.1f", excludedMinX)))"
                            : "FAIL (icon ends at \(String(format: "%.1f", g.maxX)), which is PAST excludedMinX=\(String(format: "%.1f", excludedMinX)) by \(String(format: "%.1f", g.maxX - excludedMinX))pt)"
                    }))
                    .modifier(OSDFrameLogger(label: "icon (global)", space: .global))
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                OSDLevelBar(fraction: fraction, tint: tint)
                    .frame(width: barWidth, height: 5)
                    .modifier(OSDFrameLogger(label: "bar (named osdWing)", space: .named("osdWing"), verdict: { g in
                        g.minX >= excludedMaxX
                            ? "PASS (bar starts at \(String(format: "%.1f", g.minX)), excludedMaxX=\(String(format: "%.1f", excludedMaxX)))"
                            : "FAIL (bar starts at \(String(format: "%.1f", g.minX)), which is BEFORE excludedMaxX=\(String(format: "%.1f", excludedMaxX)) by \(String(format: "%.1f", excludedMaxX - g.minX))pt)"
                    }))
                    .modifier(OSDFrameLogger(label: "bar (global)", space: .global))
                Color.clear.frame(width: percentGap)
                DigitRollText(value: percent, rollResponse: 0.30 + osdRollSpeedNudge)
                    .frame(width: percentTextWidth, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
            .coordinateSpace(name: "osdWing")
            .modifier(OSDFrameLogger(label: "wing container (global)", space: .global))
        }
    }

    // Phase 60 / CAPS-01 (D-03) — Caps Lock HUD: icon + label always visible in BOTH states
    // (unlike a status dot, the two distinct text strings alone convey on/off). Keeps the
    // universal onClick() expand-to-Home tap — no onTap override.
    // Post-checkpoint fix (on-device report: leading "C" of "Caps Lock On/Off" rendered under
    // the camera housing) — the original `Spacer()` + static `wingsLabelWidth/2` layout is the
    // SAME mechanism osdWings' comment history (rounds 5-14) documents as fundamentally unable
    // to guarantee clearance: a flexible Spacer() gives no hard guarantee about where content
    // lands relative to the REAL notch, and the static width was tuned for "Connected" (63.5pt),
    // notably shorter than "Caps Lock Off" (13 chars). Rebuilt on osdWings' round-15+ proven
    // mechanism instead: a sequential HStack with an EXPLICIT fixed-width camera-block spacer
    // sized from the LIVE OS-reported notch width (`interaction.collapsedNotchSize`). Margin
    // tuned on-device (measured rawNotchHalfWidth=89.5pt on the test machine): osdWings' own
    // 55pt margin still clipped the wider "Caps Lock Off" string; 65pt is the on-device-confirmed
    // minimum that both clears the camera and keeps the pill's width in line with other wings.
    private func capsLockWings(for activity: CapsLockActivity) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        let margin: CGFloat = 40 + wingMarginNudge   // +20 reverted per user request, back to original
        let notchHalfWidth = rawNotchHalfWidth + margin
        let cameraBlockWidth = notchHalfWidth * 2
        // 67.1-09 (D-14) — see osdWings' own comment above; only the outer padding scales.
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let iconLeadingPad: CGFloat = 26 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        let trailingPad: CGFloat = 12 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02 (was 2)
        let textWidth: CGFloat = 110
        let leftWidth = iconLeadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = iconLeadingPad + iconWidth + cameraBlockWidth + textWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        // Code review WR-02 — same sanity checks osdWings carries for the identical math, so a
        // future wingsShape/notch-width change trips a debug-build assert here too instead of
        // silently clipping (exactly the failure mode this phase's checkpoint spent a round on).
        assert(cameraBlockWidth > 0, "Caps Lock camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Caps Lock wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: iconLeadingPad)
                Image(systemName: "capslock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                Text(activity == .on ? "Caps Lock On" : "Caps Lock Off")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: textWidth, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // Phase 60 / UPDATE-01 (D-04) — Update HUD: icon+"Update" label on the left, a compact
    // UpdateVersionPill on the right. The ONE wing call site passing a non-nil `onTap` override —
    // taps trigger Sparkle's install flow (onUpdateTap) instead of the universal expand-to-Home.
    // On-device report: the old Spacer()-based layout (same fragile mechanism capsLockWings had)
    // left an oversized, unmeasured gap between the version pill and the camera; the first rebuild
    // attempt (margin=65, 70pt content boxes, matching capsLockWings 1:1) was STILL reported too
    // wide. Update's content (short "Update" label, compact version pill) is much closer in scale
    // to osdWings' icon+bar than to Caps Lock's long text — tightened to osdWings' own proven
    // margin=55 and font-metrics-based (not generously-padded) content widths, landing this wing's
    // total width within ~1pt of osdWings' own on-device-confirmed-correct total.
    private func updateWings(for activity: UpdateActivity) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // On-device tuning: 55 -> 30 -> 25 -> 15 (pill clipped at 15) -> back to 30, the last
        // confirmed-clean value. User asked to widen back out for the pill specifically while
        // leaving the "Update" label's own position untouched — since the label sits BEFORE the
        // camera block, its position depends only on leadingPad/iconWidth/gap/labelWidth (kept at
        // this round's tighter values), never on margin/cameraBlockWidth. Only the pill side
        // (margin + pillWidth) needed reverting.
        let margin: CGFloat = 30 + wingMarginNudge   // +20 reverted per user request, back to original
        let notchHalfWidth = rawNotchHalfWidth + margin
        let cameraBlockWidth = notchHalfWidth * 2
        // 67.1-09 (D-14) — see osdWings' own comment above; only the outer padding scales.
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let leadingPad: CGFloat = 18 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        let iconLabelGap: CGFloat = 2 + wingGapNudge
        let labelWidth: CGFloat = 54    // "Update" (6 chars) at 12pt semibold rounded — Quick task 260729-2td: widened, was clipping
        let pillWidth: CGFloat = 52     // UpdateVersionPill ("v1.99"-class content) at 11pt
        let trailingPad: CGFloat = 22 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + iconLabelGap + labelWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + iconLabelGap + labelWidth + cameraBlockWidth + pillWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        // Code review WR-02 — same sanity checks osdWings carries for the identical math.
        assert(cameraBlockWidth > 0, "Update camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Update wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale, onTap: onUpdateTap) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                Color.clear.frame(width: iconLabelGap)
                Text("Update")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: labelWidth, alignment: .leading)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                UpdateVersionPill(version: activity.version)
                    .frame(width: pillWidth, height: Self.wingsSize.height * dScale, alignment: .leading)
                Color.clear.frame(width: trailingPad)
            }
        }
    }

    // Phase 61 gap closure round 3 (post-checkpoint on-device UAT feedback) — the download icon
    // stays fixed on the LEFT in both states; only the RIGHT box swaps content: spinner while
    // in-flight, green checkmark once done. Both states share one identical leftWidth/rightWidth
    // (width math doesn't depend on `activity`, only the inner content does), so there's no width
    // jump when a download completes. Padding is capsLockWings' proven 12/12 (osdWings' 14/20 was
    // sized for a 90pt BAR; our right box is just a 20pt icon). Icons are .monochrome + .bold
    // (was .hierarchical) per "heller und auffälliger" (brighter/more prominent) feedback —
    // hierarchical dims secondary symbol layers, monochrome renders one fully-opaque fill.
    // margin: user reported round 2's osdWings-borrowed 55 as too much dead space to the camera
    // on-device — round 16's own comment on osdWings admits 55 was "plainly more margin than
    // needed" (a deliberate generous overshoot to end that mechanism-debugging saga, never tuned
    // to a minimum), so trimming it for icon-only content isn't fighting a hard floor, it's
    // finding the floor that saga skipped. Round 3 dropped it to 30; round 4 (still reported too
    // wide) drops it again to 20 as the next on-device data point — if this reintroduces a
    // visible gap between the black pill background and the physical camera cutout, or the icon
    // visually creeps toward the camera edge, that's the signal to bump back up.
    // leadingPad/trailingPad: round 4 also asked for MORE breathing room between icon and the
    // pill's own outer edge ("Abstand der icons zum Rand... nach außen") — bumped 12->16. Net
    // effect vs round 3 is still narrower overall (+8pt from padding, -20pt from the margin cut).
    // No onTap override (D-11) — falls through to the universal onClick() expand-to-Home, same
    // as capsLockWings.
    private func downloadWings(for activity: DownloadActivity) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        let margin: CGFloat = 10 + wingMarginNudge   // +20 reverted per user request, back to original
        let notchHalfWidth = rawNotchHalfWidth + margin
        let cameraBlockWidth = notchHalfWidth * 2
        // 67.1-09 (D-14) — see osdWings' own comment above; only the outer padding scales.
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let leadingPad: CGFloat = 26 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        let trailingPad: CGFloat = 32 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth + iconWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Download camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Download wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        // Code review WR-02 — the icon-only redesign (per explicit user request) dropped the
        // visible filename Text entirely, but D-12's `.done(filename:)` payload is still
        // computed and threaded through; surfacing it as a VoiceOver-only accessibility label
        // keeps that data useful instead of dead, without reintroducing any on-screen text.
        let a11yLabel: String
        switch activity {
        case .inProgress: a11yLabel = "Downloading"
        case .done(let filename): a11yLabel = "Download complete: \(filename)"
        }
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale) {
            HStack(spacing: 0) {
                Color.clear.frame(width: leadingPad)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                Group {
                    switch activity {
                    case .inProgress:
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    case .done:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.green)
                    }
                }
                .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                Color.clear.frame(width: trailingPad)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11yLabel)
        }
    }

    // Phase 62 / TIMER-01/TIMER-03 (D-07) — collapsed pill: live mm:ss countdown for
    // running/paused, plus the "Work · Cycle N"/"Break · Cycle N" Pomodoro label (D-07) and a
    // green live-session dot (Work segment only, 62-UI-SPEC.md Color section) when
    // `timerPillLabel(for:)` returns non-nil; a standard-size checkmark + copy for
    // .completed/.segmentDone (Open Question 2, resolved: normal collapsed wing, NOT the 28px
    // homeEmptyContent icon scale). Mirrors downloadWings' margin/leftWidth/rightWidth/assert
    // baseline verbatim (62-UI-SPEC.md Spacing Scale) — only retune on-device in Plan 62-04's
    // checkpoint if content width differs.
    private func timerWings(for activity: TimerActivity) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Phase 62-04 UAT round 6 fix (items E/G, ROOT CAUSE) — rounds 3-5 kept tuning
        // `rightContentWidth`/alignment (the box AFTER the camera block), but the actual
        // clipping was never about that box: `margin: CGFloat = 20` — copied verbatim from
        // downloadWings, whose right side is a single 20pt ICON, never TEXT — was the real
        // bug. capsLockWings hit this EXACT failure class first (a text label, not an icon,
        // next to the camera) and documents the fix in its own on-device-measured history:
        // "osdWings' own 55pt margin still clipped the wider 'Caps Lock Off' string; 65pt is
        // the on-device-confirmed minimum" (rawNotchHalfWidth measured 89.5pt on that test
        // machine). "Work · Cycle 1"/"Break · Cycle 1" is the same class of content
        // (icon/dot + a >10-character label sitting immediately after the camera block) as
        // "Caps Lock Off" -- reusing capsLockWings' own proven 65pt margin (not a new guess)
        // for the Pomodoro-labeled case is the actual fix; plain Countdown (just short mm:ss
        // digits, no adjacent label) keeps the original 20pt margin unchanged, matching
        // round 5's already-approved compact layout (item H).
        let isPomodoro: Bool
        switch activity {
        case .running(_, let ctx), .paused(_, let ctx): isPomodoro = ctx.mode == .pomodoro
        case .segmentDone: isPomodoro = true    // only ever reached for a Pomodoro session
        case .completed: isPomodoro = false     // only ever reached for a plain Countdown session
        }
        // Quick task 260729-4oi Round 8: baked in from on-device tuning (margin -10, leading +4,
        // trailing +10).
        let margin: CGFloat = (isPomodoro ? 55 : 10) + wingMarginNudge   // +20 reverted per user request, back to original
        let notchHalfWidth = rawNotchHalfWidth + margin
        let cameraBlockWidth = notchHalfWidth * 2
        // 67.1-09 (D-14) — see osdWings' own comment above; only the outer padding scales.
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let leadingPad: CGFloat = 26 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // Was 16; trimmed to 12 (matches capsLockWings' own trailingPad exactly) to reclaim
        // a few points of the ~325pt ceiling for the wider Pomodoro margin below — harmless
        // for Countdown (its own budget has plenty of slack either way).
        let trailingPad: CGFloat = 32 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        // Countdown: just the mm:ss digits (up to "999:00", 6 chars, per the 999-minute cap)
        // plus a small breathing margin -- deliberately TIGHT so the Spacer below has little
        // slack to push through (item H).
        // Pomodoro: 144, MEASURED (not guessed) against real NSAttributedString/NSFont
        // metrics for the actual 11pt label / 13pt monospaced-digit fonts used below:
        // dot(6) + gap(2) + "Break · Cycle 12"@11pt (85.9pt, the longest realistic label) +
        // gap(2) + "999:00"@13pt monospaced (47.6pt, the longest realistic digit string) =
        // 143.5pt measured total -- fits with a hair of margin. (A session simultaneously at
        // BOTH the longest label AND longest digits -- e.g. a 999-minute segment that's also
        // reached cycle 12 -- would need ~8+ days of continuous running and is not a
        // realistic combination; even then, the Spacer(minLength: 0) below overflows
        // OUTWARD, never back toward the camera.) Verified against the leftWidth/rightWidth
        // assert below at both the Preview/non-notch fallback width and the real on-device
        // notch width capsLockWings' own history measured (89.5pt) -- both pass with margin.
        let rightContentWidth: CGFloat = isPomodoro ? 144 : 60
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth + rightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Timer camera block width (\(cameraBlockWidth)) must be positive")
        assert(rightWidth < 325 && leftWidth < 325,
               "Timer wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale) {
            Group {
                switch activity {
                case .running, .paused:
                    // CRITICAL (mirrors countdownWings' own desync warning): remaining/context
                    // are both derived from `activity` INSIDE this one TimelineView tick closure
                    // so a live re-render always shows a consistent icon+label+digits triple.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let tick = timerTick(for: activity, at: context.date)
                        let remaining = tick.remaining
                        let timerContext = tick.context
                        let label = timerPillLabel(for: timerContext)
                        HStack(spacing: 0) {
                            Color.clear.frame(width: leadingPad)
                            Image(systemName: "timer")
                                .font(.system(size: 13, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                                .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                            Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                            // Phase 62-04 UAT round 4 fix (items E/G/H) — Spacer(minLength: 0)
                            // replaces the round-3 fixed-width `.trailing` frame; see this
                            // function's own header comment for why. Content hugs the
                            // trailing edge exactly like countdownWings' own
                            // Spacer()+.padding(.trailing) convention, but can never push the
                            // dot back toward the camera even on a width-budget miss.
                            Spacer(minLength: 0)
                            // Phase 62-04 UAT round 6 fix (item G) — the label (not the
                            // digits) shrinks to 11pt and the HStack spacing tightens to 2pt
                            // (was 4pt uniformly) — the exact values the 144pt budget above
                            // was measured against. Digits stay at 13pt (the primary
                            // glanceable value, unchanged).
                            HStack(spacing: 2 + wingGapNudge) {
                                if let label {
                                    if timerContext.phase == .work {
                                        Circle().fill(Color.green)   // D-07 live-session dot — Work segment only, not Break
                                            .frame(width: 6, height: 6)
                                    }
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                Text(formatMMSS(remaining))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                            .fixedSize()
                            Color.clear.frame(width: trailingPad)
                        }
                    }
                case .completed, .segmentDone:
                    HStack(spacing: 0) {
                        Color.clear.frame(width: leadingPad)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))   // standard wing icon size — NOT homeEmptyContent's 28px (Open Question 2)
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.green)
                            .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                        Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                        // Phase 62-04 UAT round 4 fix (items E/G/H) — same Spacer-based
                        // outward alignment as the .running/.paused branch above, for
                        // consistency and the same "safe overflow direction" robustness.
                        Spacer(minLength: 0)
                        Text(completionSplashText(for: activity) ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                        Color.clear.frame(width: trailingPad)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timerAccessibilityLabel(for: activity))
        }
    }

    // Phase 63 / MEET-01/MEET-02 (D-09/D-10/D-12) — collapsed pill: a non-interactive call icon
    // on the left, live mm:ss call duration + the TAPPABLE mute icon on the right. This is the
    // FIRST wing in this codebase with a real interactive sub-region inside it, so two things
    // here are deliberately unlike every other wing:
    //
    //  (1) `onTap: {}` — an EXPLICIT no-op, never `nil`. `wingsShape`'s `(onTap ?? onClick)()`
    //      means a `nil` override falls through to the universal expand-to-Home, which D-10
    //      forbids for Meeting (collapsed-only ALWAYS — the resolver has no expanded counterpart
    //      to fall through TO). Tapping the wing background must do nothing at all.
    //  (2) The mute icon carries its own nested `.onTapGesture` (D-09), which SwiftUI's
    //      deepest-view-first hit-testing consumes before the outer wing gesture ever sees it.
    //      `.contentShape(Rectangle())` first, so the whole 20pt frame is tappable rather than
    //      just the glyph's opaque pixels. Research Assumption A2 flags this as the one thing
    //      with no in-codebase precedent: if Plan 63-04's on-device UAT shows the outer gesture
    //      winning, the documented fallback is
    //      `.highPriorityGesture(TapGesture().onEnded { onMuteTap() })` in its place.
    //
    // Geometry is downloadWings' margin/leftWidth/rightWidth/assert template verbatim
    // (63-UI-SPEC.md Spacing Scale): margin 20, NOT capsLockWings'/Pomodoro-timerWings' 65 —
    // one icon + short mm:ss digits + one icon is the same "short, icon-adjacent" content class
    // as Download/plain-Countdown, not the long-text class. Retune on-device in 63-04 only if
    // content is reported clipped or over-spaced.
    private func meetingWings(for activity: MeetingActivity) -> some View {
        let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
        // Plan 63-04 Task 2 (D-09) — margin and the right-block width now come from the shared
        // statics, so this render and collapsedInteractiveZone()'s click-through widen can never
        // desync. The mute icon's width is DERIVED from the same total rather than restated as a
        // third literal, making the 84pt right block exact by construction.
        let margin = Self.meetingWingMargin
        let notchHalfWidth = rawNotchHalfWidth + margin
        let cameraBlockWidth = notchHalfWidth * 2
        // 67.1-09 (D-14) — see osdWings' own comment above; only the outer padding scales. The
        // locked right-content triple below (elapsedWidth/iconGap/muteIconWidth) is explicitly
        // excluded — scaling any of the three would desync meetingWingRightContentWidth from
        // NotchWindowController's click-through zone (WR-05 invariant).
        let wScale = resolvedWingWidthScale
        let dScale = resolvedWingDepthScale
        let leadingPad: CGFloat = 30 * wScale + wingLeadingNudge   // +6 baked in from on-device tuning, all wings, post-SHAPE-02
        let iconWidth: CGFloat = 20
        // mm:ss text box 60 (timerWings' own non-Pomodoro countdown budget — same digit-count
        // class) + 4 gap + 20 mute icon = meetingWingRightContentWidth (84).
        let elapsedWidth: CGFloat = 60
        let iconGap: CGFloat = 4
        let muteIconWidth = Self.meetingWingRightContentWidth - elapsedWidth - iconGap
        // WR-05 — collapsedInteractiveZone()'s narrowed click-through rect is sized from the
        // static, so the two must agree by construction; this catches a retune of any of the
        // three numbers above that would silently desync the clickable region from the glyph.
        assert(muteIconWidth == Self.meetingMuteIconWidth,
               "Meeting mute icon width (\(muteIconWidth)) must match NotchPillView.meetingMuteIconWidth (\(Self.meetingMuteIconWidth)) — the click-through zone is sized from the static")
        let trailingPad: CGFloat = 30 * wScale + wingTrailingNudge   // +10 baked in from on-device tuning, all wings, post-SHAPE-02
        let leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2
        let totalWidth = leadingPad + iconWidth + cameraBlockWidth
            + Self.meetingWingRightContentWidth + trailingPad
        let rightWidth = totalWidth - leftWidth
        assert(cameraBlockWidth > 0, "Meeting camera block width (\(cameraBlockWidth)) must be positive")
        assert(muteIconWidth > 0,
               "Meeting mute icon width (\(muteIconWidth)) must be positive — meetingWingRightContentWidth was retuned below elapsedWidth + iconGap")
        assert(rightWidth < 325 && leftWidth < 325,
               "Meeting wing footprint (leftWidth=\(leftWidth), rightWidth=\(rightWidth)) must stay inside the ~325pt safe panel-frame budget")
        return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, depthScale: dScale, onTap: {}) {
            // CRITICAL (mirrors countdownWings'/timerWings' own desync warning): the elapsed
            // label is computed INSIDE this one tick closure, never outside it, so a live
            // re-render always shows a consistent icon+digits pair.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = meetingElapsedLabel(callStart: activity.callStart, now: context.date)
                HStack(spacing: 0) {
                    Color.clear.frame(width: leadingPad)
                    Image(systemName: "video.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(width: iconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                        // Purely decorative — "in a call" is already carried by the duration
                        // label below, so this would only add a redundant VoiceOver stop
                        // (63-UI-SPEC.md Accessibility). Note this wing canNOT use
                        // downloadWings' blanket `.accessibilityElement(children: .ignore)`:
                        // that would swallow the mute icon's own interactive element too.
                        .accessibilityHidden(true)
                    Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block — not a flexible Spacer()
                    Text(elapsed)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        // .trailing so the digits hug the 4pt gap before the mute icon (the
                        // "icon-to-value proximity" the xs token is for), rather than floating
                        // in the middle of the 60pt box.
                        .frame(width: elapsedWidth, alignment: .trailing)
                        .accessibilityLabel("Call duration \(elapsed)")
                    Color.clear.frame(width: iconGap)
                    // D-12 — icon swap AND red tint when muted (both, not either): red alone
                    // would be a color-only signal, the swapped glyph carries the state for
                    // anyone who can't rely on hue. `.monochrome` (not `.hierarchical`) so the
                    // interactive glyph reads fully opaque/prominent, matching downloadWings'
                    // own "brighter/more prominent" precedent for a tappable/status glyph.
                    Image(systemName: activity.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(activity.isMuted ? Color.red : Color.white)
                        .frame(width: muteIconWidth, height: Self.wingsSize.height * dScale, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { onMuteTap() }
                        .accessibilityLabel(activity.isMuted ? "Unmute Microphone" : "Mute Microphone")
                    Color.clear.frame(width: trailingPad)
                }
            }
        }
    }

    // Plain (non-@ViewBuilder) helper — a switch-statement doing bare assignment cannot live
    // directly inside a TimelineView content closure (@ViewBuilder tries to build every
    // statement as a View, "type '()' cannot conform to 'View'" for the assignment itself);
    // computing the tuple here and binding it via a single `let` inside the closure sidesteps
    // that. Shared by timerWings(for:) and timerExpandedContent(for:) (both need the identical
    // running/paused → (remaining, context) resolution).
    private func timerTick(for activity: TimerActivity, at date: Date) -> (remaining: TimeInterval, context: TimerContext) {
        switch activity {
        case .running(let deadline, let context):
            return (max(0, deadline.timeIntervalSince(date)), context)
        case .paused(let remaining, let context):
            return (remaining, context)   // stored constant — ignores `date`/the tick
        case .completed, .segmentDone:
            return (0, TimerContext(mode: .countdown, phase: nil, cycle: nil))
        }
    }

    // Claude's Discretion (Task 1) — one-sentence a11y description per activity state; exact
    // wording unspecified by 62-UI-SPEC.md beyond the visible label text above.
    private func timerAccessibilityLabel(for activity: TimerActivity) -> String {
        switch activity {
        case .running(_, let context):
            if let label = timerPillLabel(for: context) { return "Timer running, \(label)" }
            return "Timer running"
        case .paused:
            return "Timer paused"
        case .completed:
            return "Timer complete"
        case .segmentDone(let finishedPhase, _):
            return finishedPhase == .work ? "Work session complete" : "Break complete"
        }
    }

    // RIGHT wing of the device glance: the battery indicator when the device reports a level
    // (DEV-01), a fixed-green status ring when connected with no reported battery, otherwise the
    // disconnected connection sign. Battery is rendered GREEN (with the indicator's amber/red
    // low-battery cue) regardless of the accent — a battery reads as a battery; the accent still
    // tints the device GLYPH on the left.
    // Round N (HUD-01 Droppy restyle, D-02/D-03/D-04) — 3-way branch replaces the old
    // checkmark/xmark ternary: connected+battery-known keeps BatteryIndicator, connected+no-battery
    // now shows a fixed Color.green ring (never deviceAccent, per D-03), disconnected stays the
    // unchanged dimmed xmark.
    @ViewBuilder
    private func deviceTrailing(isConnected: Bool, battery: Int?) -> some View {
        if isConnected, let battery {
            // Quick task 260729-47v Round 6: accent reverted from .white (260729-3pc Round 5) back to
            // .green — same rationale as Charging's revert above, matching exactly.
            BatteryIndicator(level: battery, accent: .green)
        } else if isConnected {
            Circle().strokeBorder(Color.green, lineWidth: 1.5)
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    // Phase 14 / D-06 — static weather icon per user request: no `.symbolEffect`, no
    // animation. Just the SF Symbol with multicolor rendering.
    @ViewBuilder
    private func weatherIcon(for category: WeatherCategory) -> some View {
        switch category {
        case .sunny:
            Image(systemName: "sun.max.fill")
                .symbolRenderingMode(.multicolor)
        case .cloudy:
            Image(systemName: "cloud.fill")
                .symbolRenderingMode(.multicolor)
        case .rain:
            Image(systemName: "cloud.rain.fill")
                .symbolRenderingMode(.multicolor)
        case .snow:
            Image(systemName: "cloud.snow.fill")
                .symbolRenderingMode(.multicolor)
        }
    }


    // Album art thumbnail with the nil → music-note placeholder (Open Question 3 / T-04-11).
    // Non-nil → the pre-decoded NSImage (Plan 02) scaled to fill a rounded square; nil → a
    // neutral-fill rounded square with an SF music.note glyph. Async art fills in for free:
    // when `nowPlaying.artwork` flips from nil to an image, SwiftUI re-renders this branch.
    @ViewBuilder
    private func artThumbnail(_ art: NSImage?, side: CGFloat, corner: CGFloat) -> some View {
        if let art {
            Image(nsImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: side, height: side)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: side * 0.45))
                        .foregroundStyle(.white.opacity(0.7))
                )
        }
    }

    // Phase 42 / DUAL-01 (D-06) — circular sibling of `artThumbnail(_:side:corner:)` above,
    // for the secondary bubble. Same nil → music-note-placeholder structure, `Circle()`
    // instead of `RoundedRectangle`. Async artwork fill-in works identically: when
    // `nowPlaying.artwork` flips from nil to an image, SwiftUI re-renders this branch.
    @ViewBuilder
    private func artThumbnailCircular(_ art: NSImage?, diameter: CGFloat) -> some View {
        if let art {
            Image(nsImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: diameter * 0.45))
                        .foregroundStyle(.white.opacity(0.7))
                )
        }
    }

    // Phase 42 / DUAL-01 (D-05/D-09) — the secondary activity bubble: a round shape, distinct
    // `matchedGeometryEffect` id from the primary pill's "island", so both can be visible and
    // morph independently in the same frame (this file's first two-simultaneous-shape case).
    // Pure render-only consumer of `SecondaryActivity` — never decides primary/secondary
    // precedence itself (that's `resolveSecondary`, Plan 42-01). Currently exactly one case,
    // `.nowPlaying`: the associated `NowPlayingPresentation` carries only title/artist, so the
    // artwork comes from this view's own `nowPlaying.artwork` property instead, the same
    // source `mediaExpanded(p, art: nowPlaying.artwork)` already uses.
    // Debug session `secondary-bubble-hover-playpause` (2026-07-19, live user decision during
    // Plan 42-04 Task 3's on-device UAT) — SUPERSEDES D-12/D-13 (42-CONTEXT.md), scoped strictly
    // to this bubble (no other hover state in this file is affected): hovering now darkens the
    // bubble and reveals a play/pause glyph reflecting the CURRENT playback state, and tapping
    // now toggles play/pause directly instead of expanding to Now-Playing. Only one bubble ever
    // renders at a time (D-04: exactly one secondary slot), so a single instance-level @State
    // bool is enough — unlike TransportButton below, this doesn't need its own private View
    // struct just to get independent per-instance hover state.
    @State private var isSecondaryBubbleHovering = false

    private func secondaryBubble(_ activity: SecondaryActivity) -> some View {
        switch activity {
        case .nowPlaying(let p):
            let isPlaying = isPlayingFor(p)
            return Circle()
                .fill(islandFill)
                // matchedGeometryEffect MUST precede .frame (3x-fixed bug in this file).
                .matchedGeometryEffect(id: "secondaryBubble", in: ns)
                .frame(width: Self.secondaryBubbleDiameter, height: Self.secondaryBubbleDiameter)
                .overlay(secondaryBubbleGlassOverlay)
                .overlay(artThumbnailCircular(nowPlaying.artwork, diameter: Self.secondaryBubbleDiameter))
                // Plan 42-04 Task 3 on-device UAT round 1 fix — user: "es sollte mehr
                // herausstechen" (should stand out more). The bubble's dark islandFill +
                // 0.35-opacity black glass tint read too close to the black pill's own fill,
                // visually merging instead of popping. Reuses this file's existing circular-
                // rim precedent (Circle().strokeBorder(Color.white.opacity(...), lineWidth: 1),
                // see the calendar-day/onboarding-dot markers above) rather than inventing a
                // new visual language — a thin light rim reads as "floating glass bubble"
                // (consistent with the Liquid Glass aesthetic) and separates it from the pill
                // at a glance, on top of the artwork so it stays visible.
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                // Round 2 (supersedes D-12/D-13, see @State decl above) — darken-on-hover +
                // hover-revealed play/pause glyph, reusing the SAME `isPlayingFor(_:)` verdict
                // the equalizer bars elsewhere in this file already derive from `p`.
                .overlay(Circle().fill(Color.black.opacity(isSecondaryBubbleHovering ? 0.45 : 0)))
                .overlay(
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(isSecondaryBubbleHovering ? 1 : 0)
                )
                .onHover { isSecondaryBubbleHovering = $0 }
                // Tap now toggles playback directly (see onSecondaryTap's own decl comment).
                .onTapGesture { onSecondaryTap() }
        }
    }

    // Deviation from plan (Rule 3 — blocking compile issue): `liquidGlassEffectLayer(shape:...)`
    // is typed to the concrete `NotchShape` (its legacy branch reads `shape.topCornerRadius`/
    // `.bottomCornerRadius` directly, and `LiquidGlassRimRingShape` stores a `NotchShape` base),
    // so it cannot accept `Circle()` — genericizing that whole subsystem for one 24pt bubble
    // would be a much bigger diff than this needs. Instead, the bubble applies the SAME native
    // macOS 26 `.glassEffect(.regular.tint(...))` API directly against `Circle()` (which IS
    // generic over `Shape`), filling the whole circle rather than extracting a rim-only band —
    // a full-fill glass tint is the natural look for a shape this small, where a thin rim would
    // be barely visible. No legacy (<26) shader variant exists for the bubble specifically;
    // this build machine runs macOS 26 (Tahoe), matching the rest of this file's precedent that
    // the native branch is what actually executes here (ponytail: legacy-material variant for
    // the bubble is unimplemented — add if a genuinely <26 deployment target is needed later).
    @ViewBuilder
    private var secondaryBubbleGlassOverlay: some View {
        if materialStyle == .liquidGlass {
            if #available(macOS 26.0, *) {
                Color.clear
                    .frame(width: Self.secondaryBubbleDiameter, height: Self.secondaryBubbleDiameter)
                    .glassEffect(.regular.tint(Color.black.opacity(0.35)), in: Circle())
                    .allowsHitTesting(false)
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // Derives the bars' single gate from the presentation: only `.playing` animates.
    // `.paused` and `.none` freeze the bars static (D-05) — no clock runs (D-04).
    private func isPlayingFor(_ presentation: NowPlayingPresentation) -> Bool {
        if case .playing = presentation { return true }
        return false
    }

    // Unpacks the title/artist carried by .playing/.paused; .none yields empty (never
    // rendered — the body only calls this for non-.none presentations).
    private func titleArtist(_ presentation: NowPlayingPresentation) -> (title: String, artist: String) {
        switch presentation {
        case .playing(let t, let a), .paused(let t, let a): return (t, a)
        case .none: return ("", "")
        }
    }

    // NOW-01/NOW-02 / D-08/D-09/D-10 — the EXPANDED media controls layout. Same downward
    // blob shape + shared morph identity + expandedSize as `expandedIsland`, so the island
    // MORPHS into this view (no cross-fade). Layout (matches assets/expanded-layout.png):
    //   • Album art LEFT (rounded square; nil → music.note placeholder).
    //   • Title (bold) + Artist (grey) stacked to the RIGHT of the art — D-10: title+artist
    //     ONLY (no album, no source-app icon). Both are .lineLimit(1)+.truncationMode(.tail)
    //     to BOUND untrusted metadata (T-04-09) — SwiftUI Text is already inert to format
    //     strings, this just stops over-long strings from breaking layout.
    //   • EqualizerBars on the RIGHT, vertically centered against the art row (like the collapsed wing).
    //   • A reserved-height spacer ABOVE the controls where the future seek bar (NOW-04 v2)
    //     will go — D-09: room reserved, bar NOT built.
    //   • A centered control row: a reserved LEFT slot (future Shuffle — D-09, not built),
    //     ⏪ ⏯ ⏩, and a reserved RIGHT slot (future Repeat — D-09, not built). The
    //     Star/favorite is DROPPED entirely (no slot — D-09).
    private func mediaContent(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
        let isPlaying = isPlayingFor(presentation)
        let meta = titleArtist(presentation)
        // alignment: .top + .padding(.top, 32) pins the content to the camera-clearance
        // band: nothing renders under the physical notch/camera. (Default .overlay CENTERS,
        // which with ~84pt content in a 128pt blob would leave only ~22pt top clearance —
        // not enough to clear the 32pt camera band. Top-pinning makes the clearance exact.)
        return VStack(spacing: 6) {
            // Top: art LEFT · title/artist · bars TOP-RIGHT
            HStack(alignment: .top, spacing: 10) {
                artThumbnail(art, side: 40, corner: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(meta.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(meta.artist)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)   // grey (D-10)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                EqualizerBars(isPlaying: isPlaying)   // EQ-01 bars, fixed white (no accent)
                    .frame(height: 40)    // center the bars vertically against the art row (like the collapsed wing) — not top-hanging
            }
            // Finding 15 (06-10): tap-to-toggle scoped ONLY to this non-button top row
            // (art/title/artist/bars) — never to the enclosing VStack or the bottom
            // HStack below, which holds the transport Buttons. This guarantees no tap
            // gesture recognizer sits above the transport buttons' region. Tradeoff:
            // the reserved Shuffle/Repeat placeholder corners no longer toggle collapse.
            .onTapGesture { onClick() }
            // PBAR-01: the D-09 reserved seek-bar spacer is now the real display-only
            // progress bar (elapsed/total labels + accent-filled track).
            ProgressBar(position: nowPlaying.position, isPlaying: isPlaying, tint: nowPlayingAccent)
            // Bottom: centered control row.
            HStack(spacing: 0) {
                Color.clear.frame(width: 28, height: 28)   // reserved Shuffle slot (D-09, not built)
                Spacer()
                TransportButton(systemName: "backward.fill", action: onPrevious)        // ⏪
                Spacer()
                TransportButton(systemName: "playpause.fill", action: onTogglePlayPause) // ⏯
                Spacer()
                TransportButton(systemName: "forward.fill", action: onNext)             // ⏩
                Spacer()
                // Phase 48 / D-08 — was a reserved Repeat slot (never built, dropped here the
                // same way the Star/favorite slot was dropped above); now the real output-
                // switcher toggle. Symmetric tap: opens the panel below, re-tapping closes it.
                TransportButton(systemName: "speaker.wave.2.fill", action: onToggleOutputPanel)
            }
            if presentationState.outputPanelOpen {
                outputPanel(devices: presentationState.outputDevices)
            }
        }
        .padding(.top, Self.mediaExpandedClearance + switcherContentOffsetNudge)        // Quick task 260801 baked Switcher Tuner value
        .padding(.bottom, 12)     // room for the bottomCornerRadius:20 curve (restored to its pre-260715-vsd value —
        // gap-closure round 3 finding: the switcher row's Y position is fixed by the shared
        // `switcherContentHeight` box height alone, NOT by this content's own internal
        // padding — a bottom padding change here cannot move the switcher row closer/
        // further, so rounds 1-2's attempts to "shrink the gap" via this padding had no
        // real effect either way. See homeEmptyState's comment for the actual constraint
        // that governs this box height.)
        // Quick task 260714-3k6 gap-closure round 2 — was `.padding(.horizontal, 26)`
        // (a fix for the round-1 wall-overlap bug: NotchShape's side walls sit at a
        // CONSTANT `topCornerRadius`/24pt inset from each edge, independent of panel
        // width — see NotchShape.swift's addLine calls). At 420pt wide, that padding
        // still let the HStacks' Spacers (the art/title <-> equalizer-bars gap, the
        // transport-button gaps) stretch to fill the full ~368pt remaining width, so
        // the player read as "spread out" rather than the tighter 360pt-era feel.
        // Capping the whole card's width here (322 ~= the OLD 360pt panel's own
        // content width) makes every Spacer-driven gap inside collapse back to that
        // same density, and — being centered by blobShape's own `alignment: .top`
        // outer frame with ~49pt margin each side — automatically clears the 24pt
        // wall inset too, so the separate horizontal padding is no longer needed.
        .frame(maxWidth: 322)
    }

    // D-05 — a single transport button (NOW-02) with a hover-triggered rounded-rectangle
    // background. A plain function can't hold @State, so this is a small private View struct.
    // `.buttonStyle(.plain)` so the tap fires without system chrome; the closure is the only
    // thing that leaves the view (focus-safe). Only the 3 real transport buttons use this —
    // the reserved Shuffle/Repeat placeholder slots stay plain Color.clear frames (not
    // interactive, no hover box).
    private struct TransportButton: View {
        let systemName: String
        let action: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isHovering ? Color.white.opacity(0.40) : Color.clear)
                    )
            }
            .frame(width: 32, height: 32)
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        }
    }

    // Phase 72 / CALVIEW-08 (D-07/D-08/D-12, Pitfall 4) — one agenda event row. Local
    // `@State private var isHovering` mirrors `TransportButton` above exactly — NOT the
    // controller-owned `presentationState.hoveredQuickActionButtonIndex` pattern, since this is
    // an unbounded, refetch-changing `ForEach` list. Reuses the existing rounded-card row visual
    // (color-dot + title + time) plus a hover-reveal trailing trash icon (D-08: immediate
    // delete, no confirm dialog) and a `.help()` full-title tooltip (D-12, native OS tooltip —
    // T-72-05: the untrusted `event.title` only ever renders via a plain `Text`/native tooltip).
    private struct EventRow: View {
        let event: EventInput
        // Phase 72 Task 2 (D-07) — forwards straight into EventEditPopover's own `onSave`
        // signature; the row's tap gesture presents the popover (`isShowingEdit`) rather than
        // calling this directly.
        let onEdit: (String, String, Date, Date) -> Void
        let onDelete: () -> Void
        @State private var isHovering = false
        @State private var isShowingEdit = false
        // CR-01 fix (72.1.1 review) — needed to gate the glass background below on the
        // user's actual Material Style preference, matching every other .glassEffect()
        // call site.
        @Environment(\.islandMaterialStyle) private var materialStyle

        var body: some View {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: event.colorRed, green: event.colorGreen, blue: event.colorBlue))
                    .frame(width: 6, height: 6)
                Text(event.title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(event.title)   // D-12 — full untruncated title, native tooltip only
                Spacer(minLength: 4)
                Text(event.start, format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                // D-08 — its own tappable region so a trash tap never also fires the row's edit
                // tap gesture below.
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                // Phase 72.1.1 Plan 05 (D-06 Tier 2) — glass on macOS 26+, guarded per the
                // file's existing #available convention; legacy fallback below is the exact
                // pre-existing plain fill, unchanged. CR-01 fix (72.1.1 review) — also gated
                // on materialStyle == .liquidGlass, matching every other .glassEffect() call
                // site in the codebase.
                if materialStyle == .liquidGlass, #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.clear)
                        .glassEffect(.regular.tint(Color.white.opacity(0.06)),
                                     in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
            }
            // Phase 72-04 (D-16) — hover outline, distinct from the pre-existing hover-reveal
            // delete icon above (outline only, never a filled background).
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isHovering ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture { isShowingEdit = true }   // D-07 — trash Button above takes tap priority over this
            .popover(isPresented: $isShowingEdit) {
                EventEditPopover(event: event, onSave: onEdit)
            }
        }
    }

    // Phase 48 / OUTPUT-01/02/03 (D-10..D-13, row-as-volume-bar redesign) — the output-switcher
    // panel revealed below the control row when `presentationState.outputPanelOpen` is true
    // (D-08 toggle). There is no separate slider element: the ACTIVE device's row IS the
    // draggable volume bar (D-10), inactive rows are plain dimmed text with no fill (D-11), and
    // full-white-vs-dimmed text opacity is the sole active-device signal (D-12) — no checkmark.
    private func outputPanel(devices: [AudioOutputDevice]) -> some View {
        VStack(spacing: 4) {
            ForEach(devices) { device in
                if device.isDefault {
                    outputVolumeSlider(
                        fraction: presentationState.outputCurrentVolumeFraction,
                        tint: nowPlayingAccent,
                        enabled: presentationState.outputHasVolumeControl,
                        onChange: onVolumeChange
                    ) {
                        HStack(spacing: 6) {
                            Text(device.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)   // D-12: full white, ALWAYS (even when D-13 dims the bar)
                                // Bugfix (48, active-row contrast): `tint` (nowPlayingAccent) can be
                                // any of ActivitySettings.palette's 6 colors, including `.white` —
                                // the app's own DEFAULT accent (defaultAccentIndex = 0). White text
                                // on a white Capsule fill is otherwise invisible. A dark halo behind
                                // the glyphs (stacked twice for a stronger, more outline-like edge
                                // than a single soft shadow) guarantees contrast against any fill
                                // color without touching D-12's white/opacity signal itself.
                                .shadow(color: .black.opacity(0.5), radius: 1.5)
                                .shadow(color: .black.opacity(0.5), radius: 1.5)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 6)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))   // D-12: dimmed — the sole inactive signal
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 6)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: Self.outputInactiveRowHeight)
                    .contentShape(Rectangle())
                    // D-07 — the row's ENTIRE tap behavior; the panel must stay open.
                    .onTapGesture { onSelectOutputDevice(device) }
                }
            }
        }
        // D-02/OUTPUT-03 — animates row-order changes so the newly-selected device visibly
        // slides to the top purely as a result of `devices` changing; no separate
        // reorder-animation code path needed beyond this modifier.
        .animation(.spring(response: 0.15, dampingFraction: 0.86), value: devices)
    }

    // Phase 48 / OUTPUT-01 (D-10/D-13, row-as-volume-bar redesign) — wraps `content()` (the
    // active row's own Text) in the same Capsule track/fill/DragGesture visual the old
    // standalone `OutputVolumeSlider` used, but scoped so the `enabled`-false dimming (D-13)
    // applies ONLY to the Capsule bar layers, never to `content()`'s text. Mirrors
    // `wingsShape<Content: View>`'s established "generic func + trailing @ViewBuilder content:"
    // convention rather than a generic View struct with a stored @ViewBuilder property.
    // UAT gap closure (48-03 Task 3, on-device finding) — the fill's `.animation(value:
    // fraction)` was copied from OSDLevelBar, whose fraction only changes on rare discrete
    // key-press events (a spring there reads as a nice snap). Here `fraction` is instead
    // updated on EVERY DragGesture.onChanged tick (many times/sec, see handleVolumeChange),
    // so each tick retriggered a fresh 150ms spring chasing a moving target — visibly choppy
    // instead of tracking the finger. Only one output row is ever active/draggable at a time
    // (device.isDefault, same "single instance-level @State" reasoning as
    // isSecondaryBubbleHovering above), so one instance-level bool is enough. While actively
    // dragging, the fill snaps immediately (no animation) so it tracks 1:1; once the drag ends
    // the spring is restored for any subsequent non-drag-driven fraction change.
    @State private var isDraggingOutputVolume = false

    // Perf follow-up (48, drag-fluidity polish) — `fraction` (presentationState.
    // outputCurrentVolumeFraction) only updates once handleVolumeChange's setSystemVolume
    // round-trip (multiple synchronous CoreAudio HAL calls) returns, so the fill's redraw rate
    // was capped by HAL latency even after the animation-retrigger fix above. `liveDragFraction`
    // decouples what's RENDERED from what CoreAudio has confirmed: set synchronously from the
    // raw gesture position on every onChanged tick (pure math, always fast), read in place of
    // `fraction` while non-nil, cleared on onEnded so rendering falls back to the real
    // CoreAudio-confirmed value (matters for devices that clamp/quantize, e.g. AirPods' coarse
    // steps).
    @State private var liveDragFraction: CGFloat? = nil
    // Throttles the actual onChange(_:) → setSystemVolume CoreAudio write to ~60fps — the write
    // itself still blocks the main thread with several HAL round-trips per call (unchanged,
    // constraint: setSystemVolume's call sequence stays untouched), so gating how OFTEN it fires
    // keeps gesture-event processing from backing up on a fast drag. The visual fill above no
    // longer depends on this call completing, so throttling it is safe. onEnded always fires one
    // final unthrottled call so the last drag position is never dropped.
    @State private var lastOutputVolumeWriteTime: Date = .distantPast
    private static let outputVolumeWriteInterval: TimeInterval = 1.0 / 60.0

    private func outputVolumeSlider<Content: View>(
        fraction: CGFloat,
        tint: Color,
        enabled: Bool,
        onChange: @escaping (Float) -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // `content()` evaluated here, outside GeometryReader's own @escaping content closure —
        // GeometryReader.init(content:) stores its closure for later evaluation (escaping),
        // which cannot capture the non-escaping `content` parameter directly.
        let rowContent = content()
        let effectiveFraction = liveDragFraction ?? fraction
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Group {
                    Capsule().fill(Color.white.opacity(0.15))                       // empty track
                    Capsule().fill(tint).frame(width: geo.size.width * effectiveFraction)    // filled
                        .animation(isDraggingOutputVolume ? nil : .spring(response: 0.15, dampingFraction: 0.86), value: effectiveFraction)
                }
                .opacity(enabled ? 1 : 0.35)   // D-13: dims the BAR ONLY — never `content()`

                rowContent
                    .padding(.horizontal, 10)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }   // D-13: disabled → drag is a no-op
                        isDraggingOutputVolume = true
                        let clamped = max(0, min(1, Float(value.location.x / geo.size.width)))
                        liveDragFraction = CGFloat(clamped)   // renders immediately, no HAL wait
                        let now = Date()
                        if now.timeIntervalSince(lastOutputVolumeWriteTime) >= Self.outputVolumeWriteInterval {
                            lastOutputVolumeWriteTime = now
                            onChange(clamped)
                        }
                    }
                    .onEnded { value in
                        isDraggingOutputVolume = false
                        if enabled {
                            // Always apply the final position, even if the last tick was throttled.
                            let clamped = max(0, min(1, Float(value.location.x / geo.size.width)))
                            onChange(clamped)
                        }
                        liveDragFraction = nil
                    }
            )
        }
        .frame(height: Self.outputActiveRowHeight)
    }

    // D-12 — the "Now Playing nicht verfügbar" health state (adapter blocked/dead). Same
    // expanded blob shape so the island still morphs; a single centered message. Distinct
    // from D-11 (.none + healthy → date/time): isHealthy is the orthogonal axis.
    private var mediaUnavailableContent: some View {
        // 28-04 round 5 — alignment: .top + .padding(.top, 32), same reasoning as
        // expandedIsland's own round-5 change (both are shorter than the shared
        // switcherContentHeight box now that blobShape applies it uniformly).
        // Quick task 260715-vsd gap-closure round 5 — height: Self.homeContentHeight, same as
        // homeEmptyState/mediaExpanded (see that constant's comment) so the switcher row stays
        // at a constant Y across all three Home sub-states.
        Text("Now Playing nicht verfügbar")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, resolvedCameraClearance)
    }

    // D-01 ships pure black (merges with the hardware notch → idle-invisible);
    // D-02 shows a visible tint during development so a first-time builder can
    // confirm width / radius / position over the real notch.
    //
    // Bugfix (liquid-glass-grey-rim-regression, 2026-07-16): the D-02 red tint predates
    // Phase 35 and was never reconsidered for Liquid Glass. `liquidGlassEffectLayer`
    // (below) composites its dark frost + rim-masked chromatic-fringe layers assuming a
    // dark backdrop (the same `islandFill`/`gradientMaterial` every UAT round was tuned
    // against) — over the red debug tint, the SAME screen-blend-washout mechanism the
    // round-3 UAT rejection diagnosed reappears, reading as a flat grey rim instead of
    // colored fringe. Liquid Glass must see its real fill even in DEBUG; the red tint
    // stays for Gradient/Solid Black where a flat color swap is harmless.
    private var collapsedFill: AnyShapeStyle {
        #if DEBUG
        if materialStyle == .liquidGlass { return islandFill }
        return AnyShapeStyle(Color.red.opacity(0.6))
        #else
        return islandFill
        #endif
    }
    private var devOffset: CGFloat {
        #if DEBUG
        return 8
        #else
        return 0
        #endif
    }
}

// EQ-01 (Phase 36) — the decorative equalizer bars, redesigned to the Skiper25 reference
// motion (reference-skiper25-equalizer.md): instead of a continuous per-bar sine wave, all
// 5 bars reroll to new random target heights roughly every 100ms and spring-animate to each
// new target simultaneously — a snappier, more percussive "jump" feel. Synthetic/decorative,
// NOT audio-reactive.
//
// ⚠️ THE IDLE-CPU TRAP (D-08 / Pitfall 5, preserved verbatim from the prior sine
// implementation): `TimelineView(.animation(paused: !isPlaying))` MUST stay the outer clock
// gate. It ticks each frame while playing and STOPS ENTIRELY when paused — no Timer, no
// running clock — so idle CPU returns to ~0 the instant playback pauses. Do NOT swap this
// for an unconditional `.repeatForever` or a live `Timer`; that was the exact regression
// this struct was originally built to avoid (verified on-device in Plan 04 UAT via `sample`
// / Energy idle).
struct EqualizerBars: View {
    let isPlaying: Bool                 // D-08: the SINGLE gate
    var tint: Color = .white
    private static let barCount = 5     // discretion: 3–5

    // Fixed box, CENTER-anchored: each bar is vertically centered and grows OUTWARD from the
    // middle (both up AND down) as its height changes — not pinned to a bottom baseline. The
    // fixed height keeps the group from resizing/jumping, and reads the SAME in the expanded
    // view as in the collapsed wing.
    private let boxHeight: CGFloat = 16

    // internal (not private): EqualizerBarsTests.swift calls this directly to sanity-check
    // the range/determinism contract — `private` is file-scoped and would not compile from
    // another file even under @testable import (same precedent the old makeProfiles() used).
    //
    // Combines `bar`/`bucket` through a Hasher into one deterministic pseudo-random value
    // mapped into 4...14. `abs()` is required, not optional: Hasher.finalize() returns a
    // signed Int, and Swift's `%` preserves the dividend's sign, so a negative hash would
    // otherwise produce a negative remainder and map below the 4...14 floor.
    static func targetHeight(bar: Int, bucket: Int) -> CGFloat {
        var hasher = Hasher()
        hasher.combine(bucket)
        hasher.combine(bar)
        let bucketed = abs(hasher.finalize()) % 1000
        return 4 + Double(bucketed) / 1000.0 * 10
    }

    // TIME-DRIVEN (not @State-driven) so the loop is IMMUNE to ambient withAnimation(.spring)
    // transactions — e.g. the hover spring the controller runs, which previously overrode a
    // state-based repeatForever and FROZE the bars on hover. TimelineView(.animation, paused:
    // !isPlaying) ticks each frame while playing and STOPS entirely when paused (no clock →
    // idle CPU ~0, D-08 / Pitfall 5). `bucket` increments every ~100ms while playing, and the
    // per-bar `.animation(value: bucket)` springs every bar to its new targetHeight in sync.
    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let bucket = Int(t / 0.1)   // D-07: ~100ms reroll interval
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<Self.barCount, id: \.self) { i in
                    Capsule().fill(tint).frame(width: 1, height: isPlaying ? Self.targetHeight(bar: i, bucket: bucket) : 4)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: bucket)
                }
            }
            .frame(height: boxHeight)
        }
    }
}

// Phase 39 / HUD-03/HUD-04 — the OSD (Volume/Brightness) minimal fill bar: a NEW, deliberately
// tiny two-layer Capsule (empty track + left-anchored fill), reapplying ProgressBar's own
// GeometryReader/Capsule fill technique (below) rather than BatteryIndicator, whose outline/
// nub/centered-text chrome conflicts with D-01's "no numeric text" rule. `fraction` is already
// clamped by the caller (0 when muted, else percent/100); dividing by a fixed 100.0 upstream
// keeps this view's own math bounded even if that changes.
// 39-07 gap closure (post-checkpoint on-device finding): the fill previously had NO
// `.animation()` of its own, relying entirely on the controller's shared
// `withAnimation(.spring(response: 0.6, dampingFraction: 0.62))` wrapper (the SAME slow spring
// used for the pill's own show/hide/shape morph) — during rapid scrubbing this made every level
// update feel sluggish/non-real-time. 39-UI-SPEC.md's own locked D-04 fill-animation row
// specified a bar-dedicated spring (faster than the outer wing-morph spring), applied here scoped
// to just the fill's own width change via `value: fraction`.
// 39-08 gap closure (D-16, post-39-07 on-device feedback): the user found even a SINGLE
// non-held key press still felt slightly delayed — [OSD-TIMING] evidence (39-07-SUMMARY.md)
// already ruled out the backend pipeline (single-digit milliseconds), pointing at this fill's own
// easing curve. Retuned to `response: 0.15, dampingFraction: 0.86` — a starting value (this
// codebase's own convention for first-pass spring constants, to be confirmed on-device): more
// than half the response time, damping moved closer to critically damped (less overshoot), while
// remaining a spring rather than an instant snap, preserving D-04's original "spring, not
// instant snap" intent.
private struct OSDLevelBar: View {
    let fraction: CGFloat
    let tint: Color
    // CR-01 fix (72.1.1 review) — needed to gate the glass fill below on the user's actual
    // Material Style preference, matching every other .glassEffect() call site.
    @Environment(\.islandMaterialStyle) private var materialStyle

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))                       // empty track
                // Phase 72.1.1 Plan 06 (D-07, simplified) — glass on macOS 26+, guarded per the
                // file's existing #available convention (see quickActionButton :2660). `.fill(Color.clear)`
                // is REQUIRED before `.glassEffect()`: a bare Capsule renders opaquely filled with the
                // current foreground style, which would hide the glass entirely. `tint` (green/orange,
                // Phase 39 D-02 locked) passed straight through in both branches, never re-derived.
                // Uses `.clear` (not `.regular`) — same choice as the island shell (:836), made there
                // specifically because `.regular` oversaturates/desaturates its tint color against the
                // backdrop (Plan 03 finding). Here the tint IS the semantic signal (green=volume,
                // orange=brightness), so accurate color reproduction matters even more than on the shell.
                Group {
                    // CR-01 fix (72.1.1 review) — also gated on materialStyle ==
                    // .liquidGlass, matching every other .glassEffect() call site.
                    //
                    // Debug session `liquid-glass-anim-missing`, round 5 (2026-08-01) — this bare
                    // `.glassEffect()` never animated its own `.frame(width:)` fill (the
                    // "OSD-Animation" the level bar's fraction-driven fill is the ONLY animatable
                    // property here, no matchedGeometryEffect/insert-remove involved at all — a
                    // much simpler, isolated case than the collapsed<->home transition). Wrapping
                    // it in its OWN persisting `GlassEffectContainer` (this view's single Capsule
                    // instance never gets torn down/recreated across a fraction change, so the
                    // container itself is always the SAME instance) tests whether ANY
                    // `.glassEffect()` content needs a container to interpolate at all, or only
                    // for cross-instance (insert/remove) morphs — same underlying question as the
                    // main transition, in the cheapest possible isolated form.
                    if materialStyle == .liquidGlass, #available(macOS 26.0, *) {
                        GlassEffectContainer {
                            Capsule().fill(Color.clear).glassEffect(.clear.tint(tint), in: Capsule())
                        }
                    } else {
                        Capsule().fill(tint)
                    }
                }
                .frame(width: geo.size.width * fraction)    // filled (D-02 fixed tint)
                    .animation(.spring(response: 0.15, dampingFraction: 0.86), value: fraction)   // D-16 retuned value
            }
        }
    }
}

// Phase 72.1 / D-04/D-04a/D-04b — replaces the old numeric-text content-transition percent
// Text, which faded/blended digits during rapid key-repeat (confirmed unreadable on-device,
// 72.1-CONTEXT.md D-04). Digits roll/slide via move-edge transitions only — never opacity,
// never a push-style transition — including across digit-COUNT boundary crossings (9<->10,
// 99<->100), where a whole digit position is inserted/removed by ForEach's identity, not just
// its content. Two move-edge transition sites are required for that: the inner Text's own
// id(digit) (in-place digit character swap, e.g. 4->5 at a fixed position) and the outer
// per-digit wrapper (whole-position insert/remove) — without the outer one, SwiftUI falls back
// to its default opacity-fade for the insert/remove, exactly the fade D-04a forbids.
private struct DigitRollText: View {
    let value: Int   // 0...100, already clamped upstream by OSDActivity.swift
    let rollResponse: Double

    // Phase 72.1 gap-closure — a held/repeated volume/brightness key can fire `value`
    // changes faster than any roll animation can finish, leaving a digit permanently
    // stuck mid-.move(edge:.top) transition (never lands, never fades — just hangs).
    // Below this gap, skip the animation entirely: an instant snap is imperceptible at
    // that update rate anyway. Only a change that arrives after a pause (key released,
    // or a single discrete press) gets the roll — ponytail: fixed 120ms threshold,
    // expose as its own DEBUG nudge if on-device testing shows it needs adjusting.
    private static let rapidRepeatThreshold: TimeInterval = 0.12

    @State private var displayValue: Int
    @State private var lastChangeTime = Date.distantPast

    init(value: Int, rollResponse: Double) {
        self.value = value
        self.rollResponse = rollResponse
        _displayValue = State(initialValue: value)
    }

    var body: some View {
        // WR-01 fix: identity must be anchored by place VALUE (from the right), not
        // left-to-right array offset. Offset-based identity made the ones digit appear
        // to "morph" into the tens digit whenever a boundary was crossed (9->10, 99->100),
        // because the old leftmost offset got reused for the new leftmost place. Keying by
        // place value keeps existing places (ones, tens, ...) stable in their own in-place
        // roll, and only ever inserts/removes the newly-appearing/disappearing highest place.
        let digits = Array(String(displayValue))
        let places = digits.enumerated().map { offset, digit in
            (placeValue: digits.count - 1 - offset, digit: digit)
        }
        HStack(spacing: 0) {
            ForEach(places, id: \.placeValue) { place in
                ZStack {
                    Text(String(place.digit))
                        .id(place.digit)
                        .transition(.move(edge: .top))
                }
                .frame(width: 8)
                .clipped()
                .transition(.move(edge: .top))
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)   // D-02: never accent-tinted
        .onChange(of: value) { _, newValue in
            let now = Date()
            let isRapid = now.timeIntervalSince(lastChangeTime) < Self.rapidRepeatThreshold
            lastChangeTime = now
            if isRapid {
                displayValue = newValue
            } else {
                withAnimation(.spring(response: rollResponse, dampingFraction: 0.86)) {
                    displayValue = newValue
                }
            }
        }
    }
}

// Phase 60 / UPDATE-01 — compact trailing pill for updateWings(for:), the version-only
// equivalent of BatteryIndicator's trailing-pill role (D-04: not a BatteryIndicator
// parameterization — no level/fill-bar concept applies to a version string).
struct UpdateVersionPill: View {
    let version: String

    var body: some View {
        Text("v\(version)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
}

// PBAR-01 — the display-only playback progress bar rendered inside mediaExpanded. Mirrors
// EqualizerBars' TimelineView(.animation(paused:)) gate discipline (the load-bearing
// idle-CPU precedent): a ticking clock runs ONLY while playing AND a position is known,
// so a paused or media-less island stays at zero idle CPU. Elapsed/duration text uses the
// SAME secondary-grey styling as the artist text (D-05, never accent-tinted); only the
// filled portion of the bar itself picks up the accent (D-03/D-04). Strictly inert — no
// gesture recognizers anywhere (UI-SPEC.md Interaction Contract, T-07-04).
struct ProgressBar: View {
    let position: PlaybackPosition?
    let isPlaying: Bool
    var tint: Color = .white

    var body: some View {
        TimelineView(.animation(paused: !(isPlaying && position != nil))) { context in
            // CRITICAL: Unix-epoch time (context.date.timeIntervalSince1970) — NOT the
            // 2001-epoch reference date EqualizerBars' own arbitrary sine-phase clock uses.
            // timestampEpochMicros is Unix-epoch-based, so using the other epoch here
            // would offset the elapsed computation by decades.
            let rawElapsed = position.map {
                currentElapsedSeconds($0, isPlaying: isPlaying, now: context.date.timeIntervalSince1970)
            } ?? 0
            let finiteElapsed = rawElapsed.isFinite ? rawElapsed : 0
            let rawTotal = position?.duration ?? 0
            let total = rawTotal.isFinite ? rawTotal : 0
            // Clamp elapsed to total (WR-01): a live extrapolation can briefly exceed the
            // real duration near the end of a track; keep the label in sync with the fill.
            let elapsed = total > 0 ? min(finiteElapsed, total) : finiteElapsed
            // Defensive clamp (T-07-02): a zero/negative duration or an out-of-range
            // elapsed value can never produce a NaN width or an overflowing Capsule frame.
            let fraction = total > 0 ? min(max(elapsed / total, 0), 1) : 0

            HStack(spacing: 6) {
                Text(Self.formatTime(elapsed))
                    .frame(minWidth: 28, alignment: .trailing)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))          // unfilled track (D-03)
                        Capsule().fill(tint).frame(width: geo.size.width * fraction)  // filled (D-03/D-04)
                    }
                }
                .frame(height: 3)   // D-04: thin 3pt line
                Text(Self.formatTime(total))
                    .frame(minWidth: 28, alignment: .leading)
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.secondary)   // D-05: same grey as the artist text, never accent-tinted
            .monospacedDigit()
            // UI-SPEC.md Copywriting Contract: reserve the row's height, fade the content —
            // never a "--:--" placeholder or a layout jump when position is unavailable.
            .opacity(position != nil ? 1 : 0)
        }
        .frame(height: 20)   // UI-SPEC.md Spacing Scale: progress row height
    }

    // Hand-rolled m:ss (no DateComponentsFormatter, per RESEARCH.md's Standard Stack).
    private static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// Phase 28 / CALVIEW-03 — the "+ Add" trigger + its in-panel quick-add popover, factored out
// so its transient @State (isShowing/kind/title) is scoped to just this control's lifetime,
// not a NotchPillView property (which would leak across every other presentation case) — same
// reasoning already documented for OnboardingDoneStep's Launch-at-Login @State below. Reports
// intent via `onSubmit` (kind, title) unmodified — no EventKit/EKEventStore code in this view
// file (T-28-03: the value is only ever assigned to EKEvent.title/EKReminder.title in Plan 04).
private struct QuickAddPopover: View {
    @State private var isShowing = false
    @State private var kind: QuickAddKind = .event
    @State private var title = ""
    // Phase 46 / CALVIEW-05 — the real date+time picker's backing state. `startTime`/`endTime`
    // placeholder values are never user-visible: `.onChange(of: isShowing)` below overwrites
    // them from `defaultQuickAddTime` the moment the popover actually opens (`@State` defaults
    // cannot call an instance method needing `selectedDay`).
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    // D-04 — once the user directly edits End, it stops auto-following Start for the rest of
    // this popover session.
    @State private var endManuallyEdited = false
    // D-04 — distinguishes startRow's own auto-follow write to `endTime` from a genuine user
    // edit, so endRow's onChange doesn't misread its own sibling's write as a manual edit and
    // incorrectly flip endManuallyEdited after just one Start change.
    @State private var isProgrammaticEndUpdate = false
    let onSubmit: (QuickAddKind, String, Date, Date?) -> Void
    let selectedDay: Date
    // Phase 72-04 (D-17) — hover-border state for the trigger button below.
    @State private var isHovering = false

    // The trigger button. `chipButton`'s exact visual convention (RoundedRectangle +
    // Color.white.opacity(0.12) fill, 28-UI-SPEC.md "Quick-add control chrome") — mirrored here
    // rather than called on `NotchPillView` directly, since a sibling file-scope private struct
    // has no access to another type's private instance method.
    var body: some View {
        Button(action: { isShowing = true }) {
            Text("+ Add")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                // D-17 — white hover border, same hover-affordance language as D-14/D-16.
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isHovering ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isShowing, arrowEdge: .trailing) {
            quickAddContent
        }
        // D-07 — seed startTime/endTime fresh every time the popover opens; this is a live
        // system-clock read at a SwiftUI event-handler call site (not inside a pure function),
        // matching CalendarGlance.swift's own documented exception for view-level seeding — not
        // a violation of that file's "no inline Date() in pure logic" rule.
        .onChange(of: isShowing) { _, newValue in
            guard newValue else { return }
            let seed = defaultQuickAddTime(selectedDay: selectedDay, now: Date())
            startTime = seed
            endTime = seed.addingTimeInterval(3600)
            endManuallyEdited = false
        }
    }

    // Event/Reminder choice (D-03, exact user-facing nouns) via the SAME segmented Picker
    // convention SettingsView.swift's Theming material picker already uses verbatim — do not
    // hand-roll a custom toggle. Submit label swaps with `kind` — never a generic "Save".
    private var quickAddContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Type", selection: $kind) {
                Text("Event").tag(QuickAddKind.event)
                Text("Reminder").tag(QuickAddKind.reminder)
            }
            .pickerStyle(.segmented)
            TextField("What's this for?", text: $title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
            if kind == .event {
                startRow
                endRow
            } else {
                dueRow
            }
            Button(action: {
                // WR-03 fix (28-REVIEW.md) — a trimmed-empty title silently created a
                // blank-titled EKEvent/EKReminder; guard here too (belt-and-suspenders with
                // .disabled below, which covers the visible affordance).
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                onSubmit(kind, trimmedTitle, startTime, kind == .event ? endTime : nil)
                title = ""
                isShowing = false
            }) {
                Text(kind == .event
                     ? "Add Event"
                     : "Add Reminder")
                    // Phase 72 / UI-SPEC.md Typography (4-size scale: 10/11/12/13px) — bumped
                    // from 14 to 13 alongside EventEditPopover's new "Save" button below.
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .frame(width: 240)
    }

    // D-01/D-02 — Event's Start row: a labeled compact DatePicker, no separate Date picker
    // (the day comes from `selectedDay`, already fixed by the calendar's own selection).
    private var startRow: some View {
        HStack {
            Text("Starts")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .onChange(of: startTime) { _, newValue in
            // D-04 — Start shifts End to preserve a 1-hour duration until End is edited
            // directly. Setting the suppression flag BEFORE the write lets endRow's onChange
            // recognize this specific write as auto-follow, not a user edit.
            guard !endManuallyEdited else { return }
            isProgrammaticEndUpdate = true
            endTime = newValue.addingTimeInterval(3600)
        }
    }

    // D-01/D-02/D-03 — Event's End row: its own labeled compact DatePicker on its own row, not
    // a side-by-side HStack with Start.
    private var endRow: some View {
        HStack {
            Text("Ends")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .onChange(of: endTime) { _, _ in
            // D-04 — this onChange fires on EVERY write to endTime, including startRow's own
            // programmatic auto-follow write above; without this suppression check, the first
            // Start change would incorrectly flip endManuallyEdited = true and silently kill
            // auto-follow after one use. The flag consumes itself so the very next direct user
            // edit is correctly detected.
            if isProgrammaticEndUpdate {
                isProgrammaticEndUpdate = false
            } else {
                endManuallyEdited = true
            }
        }
    }

    // D-05 — Reminder has no End field at all, not disabled/greyed, just absent.
    private var dueRow: some View {
        HStack {
            Text("Due")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
    }
}

// Phase 72 / CALVIEW-08 (D-07) — the agenda row's edit popover CONTENT, a NEW sibling of
// QuickAddPopover mirroring its exact visual chrome (240pt width, 12pt padding) but Event-only
// (no kind/Type picker — editing a Reminder's due date isn't in this phase's scope). Unlike
// QuickAddPopover, this struct owns no trigger/`isPresented` flag itself — `EventRow` (below)
// already owns the popover's `isPresented` binding (`isShowingEdit`) and presents THIS struct as
// its content, so seeding happens on `.onAppear` (fires exactly once per presentation, the
// content-based-popover equivalent of QuickAddPopover's trigger-owned `.onChange(of: isShowing)`)
// from the tapped EventInput's REAL existing values (never `defaultQuickAddTime`, a new-event
// default). Dismisses itself via the standard SwiftUI `\.dismiss` environment action.
private struct EventEditPopover: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    let event: EventInput
    let onSave: (String, String, Date, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What's this for?", text: $title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
            startRow
            endRow
            Button(action: {
                // Same trimmed-empty-title guard as QuickAddPopover's submit action (T-72-07).
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                onSave(event.id, trimmedTitle, startTime, endTime)
                dismiss()
            }) {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            title = event.title
            startTime = event.start
            endTime = event.end
        }
    }

    // Mirrors QuickAddPopover's startRow/endRow exact DatePicker shape (no auto-follow-on-Start
    // behavior here — both fields are independently pre-filled from the real event already).
    private var startRow: some View {
        HStack {
            Text("Starts")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
    }

    private var endRow: some View {
        HStack {
            Text("Ends")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
    }
}

// Phase 26 / D-10 — the Done step's own small view, factored out so its Launch-at-Login
// @State toggle is scoped to just this step's lifetime, not a NotchPillView property (which
// would leak across every other presentation case). Near-verbatim mirror of
// SettingsView.swift's existing toggle block (lines 67-86) — same underlying
// SMAppService.mainApp state via LaunchAtLogin, no new/duplicate flag.
private struct OnboardingDoneStep: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    // Round 2 (Droppy comparison) — heading/body centered, matching the other 3 steps.
    // Round 4 (on-device UAT) — the toggle is ALSO centered now (was left-pinned, which stuck
    // out relative to the centered text above it); unlike the Permissions rows (a multi-item
    // list that genuinely needs left alignment), this single compact control reads fine centered.
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("You're all set")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Islet is already running in your notch.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Round 4 (on-device UAT) — centered (was .leading, which stuck out relative to
            // the centered heading/body above it); `.fixedSize()` keeps the Toggle at its
            // natural width so `.frame(maxWidth: .infinity, alignment: .center)` centers it
            // as a compact control rather than stretching the switch to the full card width.
            Toggle("Launch Islet at login", isOn: $launchAtLogin)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        let result = try LaunchAtLogin.set(on)
                        if on && LaunchAtLogin.requiresApproval {
                            // macOS needs the user to approve the login item: keep the
                            // toggle ON (pending) to match the System Settings deep-link.
                            launchAtLogin = true
                            LaunchAtLogin.openLoginItemsSettings()
                        } else {
                            // Reflect the TRUE resulting system state.
                            launchAtLogin = result
                        }
                    } catch {
                        // Revert the UI to the real system state on failure.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
// Build-time correctness artifact: proves BOTH layouts compile and render without
// running the app. Each preview constructs a NotchInteractionState, sets the phase,
// and shows the view at the EXPANDED container size (Pitfall 4: an expanded-sized
// container so nothing clips mid-morph) over a light background so the black blob is
// visible. DEBUG-guarded so it never ships in release.
#Preview("Collapsed") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    // Phase 6: the view renders the supplied `presentation` — `.idle` → the collapsed pill.
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.idle),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

#Preview("Expanded") {
    let state = NotchInteractionState()
    state.phase = .expanded
    // Phase 30 / HOME-02: `.homeLastPlayed` → the last-played track rendered through the same
    // mediaExpanded(_:art:) view the live state uses (D-04).
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.homeLastPlayed),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Charging Wings — proves the new sideways branch compiles and renders. A non-nil
// activity makes the D-14 precedence `if` take the wings branch (here regardless of
// the interaction phase). 47% charging → the filling `battery.100percent.bolt` glyph.
#Preview("Charging Wings") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    // Phase 6: `.charging(...)` → the wings splash regardless of interaction phase.
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.charging(.charging(percent: 47))),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Device Wings — proves the device splash branch renders. A connected AirPods reading →
// the glyph + name layout (D-02/D-03). Phase 6 added this case to the single switch.
#Preview("Device Wings") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: 80))),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Secondary Bubble — Phase 42 / DUAL-01: hand-seeds `presentationState.secondary` alongside a
// `.calendarCountdown` primary (the only presentation resolveSecondary ever pairs it with) to
// prove D-05/D-08/D-09: a round bubble to the right of the countdown wing, distinct from and
// not overlapping it, with a visible gap.
#Preview("Secondary Bubble") {
    let interactionState = NotchInteractionState()
    interactionState.phase = .collapsed
    let presentationState = IslandPresentationState(.calendarCountdown(CalendarCountdownActivity(eventStart: Date().addingTimeInterval(1800))))
    presentationState.secondary = .nowPlaying(.playing(title: "Test", artist: "Test"))
    return NotchPillView(interaction: interactionState,
                         nowPlaying: NowPlayingState(),
                         presentationState: presentationState,
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Focus Wings — Phase 38 / HUD-05: proves the new focusWings(for:) branch compiles and
// renders in isolation. `.focus(.on)` is the only reachable presentation (D-09: no "Focus
// Off" render exists).
#Preview("Focus Wings") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.focus(.on)),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Media Wings (playing) — collapsed glance, art LEFT / animated bars RIGHT (D-02). The
// nil artwork falls to the music.note placeholder (Open Q3); `.playing` animates the bars.
#Preview("Media Wings (playing)") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    let np = NowPlayingState()
    np.presentation = .playing(title: "New Rules", artist: "Dua Lipa")
    return NotchPillView(interaction: state,
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingWings(.playing(title: "New Rules", artist: "Dua Lipa"))),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Media Wings (paused) — same glance, bars frozen static (D-05): `.paused` removes the
// repeating animation (idle-CPU guarantee, D-04).
#Preview("Media Wings (paused)") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    let np = NowPlayingState()
    np.presentation = .paused(title: "New Rules", artist: "Dua Lipa")
    return NotchPillView(interaction: state,
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingWings(.paused(title: "New Rules", artist: "Dua Lipa"))),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Media Expanded — D-08 controls layout: art LEFT · title/artist · bars top-right · ⏪⏯⏩.
// Expanded + healthy + non-.none → the mediaExpanded branch. nil art → music.note placeholder.
#Preview("Media Expanded") {
    let state = NotchInteractionState()
    state.phase = .expanded
    let np = NowPlayingState()
    np.presentation = .playing(title: "New Rules", artist: "Dua Lipa")
    return NotchPillView(interaction: state,
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingExpanded(.playing(title: "New Rules", artist: "Dua Lipa"), healthy: true)),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Unavailable — D-12: expanded + isHealthy=false → "Now Playing nicht verfügbar".
#Preview("Unavailable") {
    let state = NotchInteractionState()
    state.phase = .expanded
    let np = NowPlayingState()
    np.isHealthy = false
    return NotchPillView(interaction: state,
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingExpanded(.none, healthy: false)),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Quick Action Picker — Idle (Phase 34 UAT revision, D-14/D-15) — proves the buttons-only
// 117pt picker compiles and renders with no button hovered.
#Preview("Quick Action Picker — Idle") {
    let state = NotchInteractionState()
    state.phase = .expanded
    let item = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/tmp/report.pdf"),
                          localURL: URL(fileURLWithPath: "/tmp/report.pdf"),
                          filename: "report.pdf", addedAt: Date())
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.quickActionPicker(PendingDrop(items: [item]))),
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Quick Action Picker — AirDrop Hovered (Phase 34 UAT revision, D-11) — proves the live
// drag-hover highlight (0.22 fill + 1.04 scale) renders on the AirDrop button.
#Preview("Quick Action Picker — AirDrop Hovered") {
    let state = NotchInteractionState()
    state.phase = .expanded
    let item = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/tmp/report.pdf"),
                          localURL: URL(fileURLWithPath: "/tmp/report.pdf"),
                          filename: "report.pdf", addedAt: Date())
    let presentationState = IslandPresentationState(.quickActionPicker(PendingDrop(items: [item])))
    presentationState.hoveredQuickActionButtonIndex = 1
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: presentationState,
                         outfit: BasicOutfitState(),
                         shelfViewState: ShelfViewState(),
                         quickActionsBarFeedback: QuickActionsBarFeedbackState(),
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
#endif
