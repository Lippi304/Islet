import SwiftUI

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
    // CR-01 fix (28-REVIEW.md) — mirrors NotchWindowController.visibleContentZone()'s own
    // isTrayPresentation exclusion: trayFullView renders with shelfVisible: false (its content
    // IS the files view), so it never actually grows by shelfRowHeight. This outer frame is
    // currently harmless to leave un-excluded (the panel is already reserved to the max union
    // height), but drifting from the click-through math here is exactly the failure class CR-01
    // closes — keep both frames in lockstep.
    private var isTrayPresentation: Bool {
        if case .trayExpanded = presentation { return true }
        return false
    }
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

    // Phase 14 / WEATHER-01 / CAL-01 — the SEPARATE @Published outfit model (weather +
    // calendar), mirroring nowPlaying/presentationState's ownership contract: the controller
    // (14-04) is the only writer, this view only RENDERS whatever is published. No default
    // value — the controller always owns and injects a real instance (same non-defaulted
    // convention as `nowPlaying`/`presentationState`).
    @ObservedObject var outfit: BasicOutfitState

    // Phase 20 / SHELF-03 — the SEPARATE @Published shelf model, mirroring nowPlaying/
    // presentationState/outfit's existing ownership contract: the controller (Plan 20-02) always
    // owns and injects a real instance, never defaulted. This view only RENDERS whatever is
    // published — no ShelfCoordinator, no file I/O.
    @ObservedObject var shelfViewState: ShelfViewState

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

    // NOW-02 — the transport callbacks, plain closures mirroring `onClick`. The view stays
    // AppKit-free + focus-safe: a button tap only REPORTS the intent; NotchWindowController
    // (Plan 04) owns the closures and forwards them to NowPlayingMonitor.togglePlayPause()/
    // nextTrack()/previousTrack() (which ride the existing persistent perl child's stdin).
    // Defaulted to no-ops so the DEBUG #Previews build without a controller.
    var onTogglePlayPause: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

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

    // Phase 28 / CALVIEW-01/02 — the switcher-pill and calendar-navigation callbacks, plain
    // closures mirroring the onboarding callbacks above: the view stays AppKit/EventKit-free,
    // only REPORTS intent. NotchWindowController (Plan 04) owns these. Defaulted to no-ops so
    // the DEBUG #Previews build without a controller.
    var onSwitcherSelect: (SelectedView) -> Void = { _ in }
    var onCalendarMonthChange: (Int) -> Void = { _ in }
    var onCalendarDaySelect: (Date) -> Void = { _ in }
    // Phase 28 / CALVIEW-03 — the quick-add report closure (Task 3): (kind, title) forwarded
    // unmodified, no EventKit/EKEventStore code in this view file.
    var onQuickAdd: (QuickAddKind, String) -> Void = { _, _ in }

    // The single shared morph identity (D-07): the collapsed and expanded blobs both
    // morph against this one geometry group via matchedGeometryEffect(id: "island").
    @Namespace private var ns

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
    static let expandedSize = CGSize(width: 360, height: 144)

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

    // SHAPE-01 (v1.5, Phase 29) — FINAL corrected design (see NotchShape.swift's doc comment and
    // 29-CONTEXT.md's "Post-D-01/D-05 implementation detour and final confirmation"): `topFlareWidth`
    // is the width of the narrow, centered camera-notch DIP — the wide sides stay flush with the
    // true screen edge exactly like before Phase 29, and only this centered band dips down. The
    // SAME absolute value every covered presentation uses (D-05), regardless of its own full width
    // (360pt Home/Tray/Calendar/Weather blob vs. 290pt Charging/Device wings). Round-2 on-device
    // tuning feedback ("the transition needs to kick in earlier and stretch further outward, right
    // now it's minimal/too small") widened this from the physical-camera-accurate 179pt to a more
    // stylized, deliberately larger value that reads clearly at both call-site widths without
    // dominating either. The dip is a pure inward recess (no outward overflow), so no panel-frame
    // or SwiftUI-content-root widening is needed for this design.
    static let topFlareWidth: CGFloat = 220

    // DIAGNOSTIC — REVERT AFTER THIS TEST. Gates the stroke-outline + on-screen value-dump
    // probes re-added in `blobShape()` below (same technique that broke open the earlier
    // frame-width bug this phase hit) — proves definitively whether the centered-notch dip
    // geometry is actually rendering with the expected values before assuming the plain black
    // fill is "just too subtle."
    static let diagnosticStrokeOutline = true

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
    static let cameraClearance: CGFloat = 32

    // 28-04 round 5 (on-device UAT, real Droppy reference screenshots) — the month-grid cell
    // size/gap, shrunk from round 4's 28×28pt/4pt (which round 4's own comment admitted were
    // NOT Droppy-accurate — no real notch-overlay screenshot existed at the time). Two genuine
    // Droppy screenshots now confirm small, tight, numeral-only cells, with the grid column
    // taking a SMALLER fraction of the pill's width than the day-list column gets. Shrinking
    // these two constants both matches the reference visually AND automatically frees width
    // for `dayListColumn` (an HStack sibling with no fixed width of its own — the grid's own
    // intrinsic width is exactly what LazyVGrid claims, so a smaller grid leaves more remainder
    // for the list).
    static let calendarCellSize: CGFloat = 18
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

    var body: some View {
        // Fixed expanded-sized container; the pill sits flush at the TOP edge and the
        // expanded content grows DOWNWARD from the notch (RESEARCH Pattern 4: panel is
        // sized to the expanded frame so the morph never clips).
        ZStack(alignment: .top) {
            // Phase 6 / COORD-01 / D-05 — the SINGLE arbiter. The view no longer DECIDES
            // precedence (the old `charging > expanded > media-wings > collapsed` if-chain is
            // gone); the controller's pure `resolve(...)` reducer picks ONE `IslandPresentation`
            // and the body just renders it with this switch, mapping each case to the existing
            // private helper. Charging/Device are the rank-1/2 transient splashes (D-02); the
            // controller's queue advances off the single ~3s one-shot dismiss and the resolver
            // falls through to `.nowPlayingWings`/`.idle` so a transient "returns to the wings,
            // not to empty" (D-02 yield-to-ambient). The expanded media-health axis (D-12) rides
            // on the `.nowPlayingExpanded(_, healthy:)` flag.
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
            case .nowPlayingExpanded(let p, true):
                mediaExpanded(p, art: nowPlaying.artwork)                        // NOW-01/02 controls (healthy)
            case .nowPlayingExpanded(_, false):
                mediaUnavailable                                                 // D-12 "nicht verfügbar"
            case .expandedIdle:
                expandedIsland                                                   // D-11 date/time (healthy, no media)
            case .calendarExpanded:
                calendarFullView                                                 // Phase 28 / CALVIEW-01: month grid + day list
            case .weatherExpanded:
                weatherFullView                                                  // 28-04 round 4: current-conditions full view
            case .trayExpanded:
                trayFullView                                                     // 28-04 round 5: dedicated files-only Tray view
            case .idle:
                collapsedIsland                                                  // idle pill
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
        .frame(width: isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width,
               height: isOnboardingPresentation
                   ? Self.onboardingSize.height
                   : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
                       + ((shelfViewState.isVisible && !isTrayPresentation) ? Self.shelfRowHeight : 0)
                       + (showsSwitcherRow ? Self.switcherRowHeight : 0),
               alignment: .top)
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

    // COLLAPSED — the existing black notch pill (D-08 idle-static). Keeps the
    // Phase-1 dev affordance: DEBUG shows a visible red tint + a small downward
    // offset so a first-time builder can SEE width/radius/position over the real
    // notch (D-02); RELEASE ships pure black so it merges with the hardware notch.
    private var collapsedIsland: some View {
        // D-01: size from the REAL measured notch the controller published; fall back to the
        // static 200x38 seed when no notch is measured (non-notch / external display / previews).
        let size = interaction.collapsedNotchSize ?? Self.collapsedSize
        return NotchShape()
            .fill(collapsedFill)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: size.width, height: size.height)
            // D-01 (visual half): a subtle "you're in" bounce on hover only — never
            // when expanded. The controller drives this via its spring wrapper at the
            // state mutation. The haptic + the real pointer monitor are Plan 03.
            .scaleEffect(interaction.isHovering && !interaction.isExpanded ? 1.06 : 1.0)
            .offset(y: devOffset)
            .onTapGesture { onClick() }
    }

    // EXPANDED — the same black blob grown to the compact expanded size. Phase 14 / D-07:
    // the placeholder date/time readout is now a 3-column glance — weather LEFT, time+date
    // CENTER, calendar RIGHT — per UI-SPEC.md's Spacing Scale. The blob carries the SAME
    // matchedGeometryEffect id so SwiftUI morphs the single shape from the collapsed pill to
    // here (no cross-fade). Either side column is simply absent (not an error state) when its
    // `outfit` field is nil (D-01/D-03/D-04); default (centered) overlay alignment is correct
    // here — this ~40pt-tall content needs no camera-clearance pin, unlike mediaExpanded's
    // 84-100pt content (UI-SPEC.md explicitly corrects RESEARCH.md's `.padding(.top, 32)`).
    private var expandedIsland: some View {
        // 28-04 round 5 — alignment: .top + .padding(.top, 32) added so Home's content sits at
        // the SAME camera-clearance-pinned position as every other switcher-row presentation
        // (mediaExpanded/calendarFullView/weatherFullView's existing convention), now that
        // `blobShape` grows Home's content box to the shared `switcherContentHeight` (see that
        // constant's doc comment) — centering here would just leave a bigger, uneven gap above
        // the glance instead of a consistent gap below it, above the switcher row.
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top, shelfItems: shelfViewState.items,
                  shelfVisible: shelfViewState.isVisible, showSwitcher: true) {
            HStack(spacing: 0) {
                if let weather = outfit.weather {
                    weatherColumn(weather)
                }
                Spacer()
                centerColumn
                Spacer()
                if let calendarGlance = outfit.calendar {
                    calendarColumn(calendarGlance)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, Self.cameraClearance)   // camera/notch clearance — matches mediaExpanded's convention
        }
    }

    // Phase 28 / CALVIEW-01/02 (28-UI-SPEC.md "Calendar full view") — the month grid + day
    // list. Reuses blobShape exactly like expandedIsland (same 360pt width, same
    // expandedSize.height base) with the switcher row always shown (this presentation IS one of
    // the two showsSwitcherRow cases). Month grid LEFT, day list RIGHT, a thin divider between —
    // both read through Plan 01's pure `daysInMonth(for:)`/`events(on:events:)` functions, never
    // a re-implementation (RESEARCH.md Anti-Pattern: no Date()/Date.now threaded into month math).
    private var calendarFullView: some View {
        // 28-04 on-device UAT bugfix — `alignment: .top` (was default `.center`). The month
        // grid's real content is taller than expandedSize.height; centering it in that box
        // spilled the overflow equally above AND below, and the ABOVE half rendered under the
        // camera notch. Top-pinning (mirrors mediaExpanded's `alignment: .top` +
        // `.padding(.top, 32)` convention) makes the island grow DOWNWARD only, same as every
        // other expanded presentation. 28-04 round 5 — the explicit `height:` override is gone:
        // `blobShape` now applies the shared `switcherContentHeight` box UNCONDITIONALLY
        // whenever `showSwitcher` is true (see that constant's doc comment), so this call site
        // no longer needs its own per-case height.
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top,
                  shelfItems: shelfViewState.items,
                  shelfVisible: shelfViewState.isVisible, showSwitcher: true) {
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
            .padding(.top, Self.cameraClearance)   // camera/notch clearance — matches mediaExpanded's convention
        }
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
    private var monthGridColumn: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { onCalendarMonthChange(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(calendarViewState.visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { onCalendarMonthChange(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.calendarCellSize), spacing: Self.calendarCellGap), count: 7),
                      spacing: Self.calendarCellGap) {
                ForEach(Array(daysInMonth(for: calendarViewState.visibleMonth).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isSelected = Calendar.current.isDate(day, inSameDayAs: calendarViewState.selectedDay)
                        let isToday = Calendar.current.isDateInToday(day)
                        let hasEvents = calendarViewState.monthEvents.map { !events(on: day, events: $0).isEmpty } ?? false
                        ZStack(alignment: .bottom) {
                            Text(day, format: .dateTime.day())
                                .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: Self.calendarCellSize, height: Self.calendarCellSize)
                                .background(Circle().fill(Color.white.opacity(isSelected ? 0.18 : 0)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(isToday && !isSelected ? 0.6 : 0), lineWidth: 1))
                            if hasEvents {
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 2, height: 2)
                                    .offset(y: -1)
                            }
                        }
                        .frame(width: Self.calendarCellSize, height: Self.calendarCellSize)
                        .onTapGesture { onCalendarDaySelect(day) }
                    } else {
                        Color.clear.frame(width: Self.calendarCellSize, height: Self.calendarCellSize)   // leading pad cell — no view
                    }
                }
            }
        }
    }

    // RIGHT column — the selected day's event list. `dayEvents == nil` (monthEvents not yet
    // fetched) renders nothing — NEVER the empty state (Pitfall 4: distinguishes loading from a
    // confirmed-zero-events day so CALVIEW-02's "No events today" never flashes before the
    // first EventKit fetch settles).
    private var dayListColumn: some View {
        let dayEvents = calendarViewState.monthEvents.map { events(on: calendarViewState.selectedDay, events: $0) }
        return VStack(alignment: .trailing, spacing: 4) {
            // CALVIEW-03 — the "+ Add" trigger, top-right of the day-list column
            // (28-UI-SPEC.md Layout Contract).
            HStack {
                Spacer()
                QuickAddPopover(onSubmit: onQuickAdd)
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

    // The scrollable event rows, reusing `calendarColumn`'s exact title/color-dot/time
    // convention (T-14-06 MANDATORY: `.lineLimit(1)`/`.truncationMode(.tail)` on untrusted
    // EventKit titles). `ScrollView(.vertical)` so >3-4 rows scroll instead of overflowing the
    // 144pt content box (28-UI-SPEC.md Layout Contract "Day-list scroll").
    // 28-04 round 4 visual pass — each row now sits in a subtle rounded card
    // (Color.white.opacity(0.06) + 8pt corner radius), matching Droppy's own ubiquitous
    // rounded-card container language (every Droplet/setting row in the reference screenshots
    // is a rounded translucent card) — purely additive per-row styling, no height/scroll math
    // changed.
    private func dayEventsList(_ dayEvents: [EventInput]) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(dayEvents.enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: event.colorRed, green: event.colorGreen, blue: event.colorBlue))
                            .frame(width: 6, height: 6)
                        Text(event.title)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Text(event.start, format: .dateTime.hour().minute())
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
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
    private var weatherFullView: some View {
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top, shelfItems: shelfViewState.items,
                  shelfVisible: shelfViewState.isVisible, showSwitcher: true) {
            Group {
                if let weather = outfit.weather {
                    weatherFullContent(weather)
                } else {
                    weatherFullUnavailable
                }
            }
            .padding(.top, Self.cameraClearance)   // camera/notch clearance — matches mediaExpanded's convention
        }
    }

    // The populated state: icon + temperature + a plain category label, centered, reusing
    // `weatherIcon(for:)`'s exact SF Symbol mapping and the same locale-aware
    // `.formatted(.measurement(...))` temperature string `weatherColumn` already uses (no
    // manual Celsius/Fahrenheit conversion here either).
    private func weatherFullContent(_ weather: WeatherGlance) -> some View {
        VStack(spacing: 8) {
            weatherIcon(for: weather.category)
                .font(.system(size: 44))
            Text(weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(weatherCategoryLabel(weather.category))
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
    private var trayFullView: some View {
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top, shelfItems: [],
                  shelfVisible: false, showSwitcher: true) {
            Group {
                if shelfViewState.items.isEmpty {
                    trayEmptyState
                } else {
                    shelfRow(shelfViewState.items)
                }
            }
            .padding(.top, Self.cameraClearance)   // camera/notch clearance — matches mediaExpanded's convention
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // The empty state — mirrors `calendarEmptyState`'s tone/structure (heading + secondary
    // body line) rather than `mediaUnavailable`/`weatherFullUnavailable`'s single-line "nicht
    // verfügbar" style, since an empty shelf is a normal empty collection (like an empty
    // inbox), not a degraded/blocked feature.
    private var trayEmptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
            Text("No files yet")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Drag files onto the notch to add them here.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32,
                  width: Self.onboardingSize.width, height: Self.onboardingSize.height, shelfItems: [],
                  shelfVisible: false) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    onboardingStepContent(step)
                    Spacer(minLength: 0)
                }
                .padding(.top, Self.cameraClearance)         // camera-clearance floor, matches mediaExpanded's convention
                .padding(.horizontal, 28)  // screen content padding (round 2, Droppy comparison)
                // Round 3 — reserves room below the centered content so it never visually
                // overlaps the nav row overlay pinned below it.
                .padding(.bottom, Self.navRowReservedHeight)

                onboardingNavRow(step)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
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
            Text("Meet Islet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
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

    private func navCircleButton(systemName: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white)
                .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
                .background(Circle().fill(filled ? Color.white : Color.clear))
                .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // The shared chip style (Grant, Enter License Key, Buy Islet) — reuses the existing
    // RoundedRectangle + Color.white.opacity(0.12) in-chrome control convention rather than
    // inventing a new button primitive (26-UI-SPEC.md Button/chip style). Round 2: Back/
    // Next/Finish moved off this style onto navCircleButton above; this remains the style
    // for the inline Grant/License/Buy actions, unchanged.
    private func chipButton(_ label: String, fontSize: CGFloat = 14, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
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
                                           @ViewBuilder content: () -> Content) -> some View {
        let hasShelf = shelfVisible
        let baseWidth = width ?? Self.expandedSize.width
        let baseHeight = showSwitcher ? Self.switcherContentHeight : (height ?? Self.expandedSize.height)
        let totalHeight = baseHeight
            + (showSwitcher ? Self.switcherRowHeight : 0)
            + (hasShelf ? Self.shelfRowHeight : 0)
        let shape = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius, topFlareWidth: Self.topFlareWidth)
        // DIAGNOSTIC — REVERT AFTER THIS TEST: mirrors NotchShape.path(in:)'s own
        // `min(desiredNotchDepth, rect.height / 2)` clamp so the on-screen label below shows
        // the ACTUAL depth this call site's rect permits, not just the source constant.
        let diagNotchDepth = min(CGFloat(14), totalHeight / 2)
        return shape
            .fill(islandFill)
            .frame(width: baseWidth, height: totalHeight)
            .matchedGeometryEffect(id: "island", in: ns)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    content()
                        .frame(width: baseWidth, height: baseHeight, alignment: alignment)
                    if showSwitcher {
                        switcherRow
                    }
                    if hasShelf {
                        shelfRow(shelfItems)
                            .transition(.opacity)
                    }
                }
            }
            // DIAGNOSTIC — REVERT AFTER THIS TEST: a bright lime stroke traced on the EXACT
            // SAME `shape` instance used for the fill above, so any dip in the actual geometry
            // shows up unmistakably even if the plain black fill doesn't read as different.
            .overlay(
                Group {
                    if Self.diagnosticStrokeOutline {
                        shape.stroke(Color(red: 0.2, green: 1.0, blue: 0.2), lineWidth: 2)
                    }
                }
            )
            // DIAGNOSTIC — REVERT AFTER THIS TEST: on-screen dump of the actual computed
            // geometry values feeding NotchShape at render time for this call site — proves
            // the code path is reached with the values we expect, independent of any
            // fill/stroke rendering quirk.
            .overlay(alignment: .bottomTrailing) {
                if Self.diagnosticStrokeOutline {
                    Text("notch: w=\(Int(Self.topFlareWidth)) depth=\(String(format: "%.1f", diagNotchDepth)) rect=\(Int(baseWidth))x\(Int(totalHeight))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .padding(4)
                        .background(Color.black.opacity(0.75))
                        .padding(4)
                }
            }
            // D-05: this single ancestor gesture already covered content's own empty space
            // before this phase; it now ALSO covers the switcher/shelf rows' empty space "for
            // free" — only ShelfItemView's own scoped tap/trash gestures and the switcher's own
            // Button taps intercept before it.
            .onTapGesture { onClick() }
    }

    // Phase 28 / CALVIEW-01 (28-UI-SPEC.md "Switcher pill") — the Home/Tray/Calendar/Weather
    // switcher, reusing `navCircleButton` verbatim (same circular nav-button visual language as
    // onboarding's Back/Next/Finish). `filled:` marks whichever icon matches
    // `viewSwitcherState.selectedView`; each tap only REPORTS intent via `onSwitcherSelect` — no
    // precedence re-deciding here (Pattern 3: the resolver stays the single arbiter).
    // 28-04 round 4 (user-confirmed scope expansion) — Weather appended as the 4th icon, after
    // Calendar (Home/Tray/Calendar/Weather order, existing three left untouched).
    private var switcherRow: some View {
        HStack(spacing: 8) {
            navCircleButton(systemName: "house.fill",
                             filled: viewSwitcherState.selectedView == .home,
                             action: { onSwitcherSelect(.home) })
            navCircleButton(systemName: "tray.fill",
                             filled: viewSwitcherState.selectedView == .tray,
                             action: { onSwitcherSelect(.tray) })
            navCircleButton(systemName: "calendar",
                             filled: viewSwitcherState.selectedView == .calendar,
                             action: { onSwitcherSelect(.calendar) })
            navCircleButton(systemName: "cloud.sun.fill",
                             filled: viewSwitcherState.selectedView == .weather,
                             action: { onSwitcherSelect(.weather) })
        }
        .frame(height: Self.switcherRowHeight)
    }

    // Phase 20 / SHELF-03/05 — the horizontally-scrolling shelf strip: per-item icon+caption+
    // trash (ShelfItemView), then a far-right delete-all trash icon. No `.onTapGesture` is
    // attached to this container itself — D-05 falls out for free via blobShape's own trailing
    // ancestor gesture (see above).
    private func shelfRow(_ items: [ShelfItem]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {   // item-gap, UI-SPEC
                ForEach(items, id: \.id) { item in
                    ShelfItemView(item: item,
                                  onTap: { onShelfItemTap(item) },
                                  onDelete: { onShelfItemDelete(item.id) },
                                  onDragStarted: { onShelfItemDragStarted() })
                }
                Button(action: onShelfClearAll) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear shelf")
            }
            .padding(.horizontal, 16)   // row-padding, UI-SPEC
        }
        .scrollIndicators(.never)
        .frame(height: Self.shelfRowHeight)
    }

    // Finding 12 — the shared flat-strip skeleton `wings(for:)` and `deviceWings(for:)` each
    // repeated: NotchShape → .fill → .matchedGeometryEffect → .frame → .overlay(content sized
    // the same). Their size constants were already numerically identical (290×32, the
    // post-checkpoint "one uniform width" decision), so this collapses them into the single
    // `wingsSize`. Each caller supplies only its own distinct HStack content.
    // Phase 18 round 3: `mediaWingsOrToast` no longer routes through this helper — its bottom
    // corner radius and height must vary with the toast, so it builds its own NotchShape
    // directly (see that function's comment) rather than the always-flat 6/6 this returns.
    private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 6, topFlareWidth: Self.topFlareWidth)   // flatter than the downward blob
        return shape
            .fill(islandFill)
            .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            .matchedGeometryEffect(id: "island", in: ns)
            .overlay(
                content()
                    .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            )
            // Finding 15 (06-10): both remaining wing glances (wings(for:), deviceWings(for:))
            // share this one tap-to-toggle through the shared helper.
            .onTapGesture { onClick() }
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
        return wingsShape {
            HStack(spacing: 0) {
                Image(systemName: "bolt.fill")                       // D-05 status symbol LEFT (charging cue)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))
                    .padding(.leading, 12)
                Spacer()                                             // clears the physical camera bridge
                BatteryIndicator(level: percent, accent: chargingAccent)     // RIGHT — same indicator as the device glance
                    .padding(.trailing, 14)
            }
        }
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
        let height = Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)
        NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
            .fill(islandFill)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.wingsSize.width, height: height)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    mediaWingsRow(p, art: nowPlaying.artwork)
                    if let toast {
                        toastTextRow(toast)
                            .transition(.opacity)
                    }
                }
            }
            // Finding 15 (06-10) precedent: the shared tap-to-toggle, same as wingsShape's
            // callers — no buttons live in this content, so one ancestor gesture is safe.
            .onTapGesture { onClick() }
    }

    // Row 1 — the collapsed media glance content, UNCHANGED from before this phase (D-02):
    // album art LEFT, animated equalizer bars RIGHT, same paddings. Factored out of the old
    // `mediaWings(_:art:)` (which used to also own the `wingsShape` wrapper) so
    // `mediaWingsOrToast` can size the combined shape itself; the visual output is identical.
    private func mediaWingsRow(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
        let isPlaying = isPlayingFor(presentation)
        return HStack(spacing: 0) {
            artThumbnail(art, side: Self.wingsSize.height - 8, corner: 6)  // LEFT wing
                .padding(.leading, 22)   // inset from the outer notch edge (user request)
            Spacer()                                            // clears the physical camera bridge
            EqualizerBars(isPlaying: isPlaying, tint: nowPlayingAccent)  // RIGHT wing — D-02 bars (D-11 accent)
                .padding(.trailing, 24)  // inset from the outer notch edge (user request)
        }
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
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
    private func deviceWings(for activity: DeviceActivity) -> some View {
        let glyph: DeviceGlyph
        let isConnected: Bool
        let battery: Int?
        switch activity {
        case .connected(_, let g, let b): glyph = g; isConnected = true;  battery = b
        case .disconnected(_, let g):     glyph = g; isConnected = false; battery = nil
        }
        let iconOpacity = isConnected ? 1.0 : 0.5   // D-03: disconnected dims the icon
        return wingsShape {
            HStack(spacing: 0) {
                Image(systemName: deviceSymbol(for: glyph))   // LEFT wing — device glyph (D-02)
                    .symbolRenderingMode(.hierarchical)
                    // D-11 (Phase 6): the device glyph picks up the persisted accent. The
                    // D-03 disconnected-dimming rides on top as opacity, so a disconnected
                    // device still reads as dimmed regardless of the accent hue.
                    .foregroundStyle(deviceAccent.opacity(iconOpacity))
                    .padding(.leading, 12)
                Spacer()                                      // clears the physical camera bridge
                deviceTrailing(isConnected: isConnected, battery: battery)   // RIGHT wing
                    .padding(.trailing, 14)
            }
        }
    }

    // RIGHT wing of the device glance: the battery indicator when the device reports a level
    // (DEV-01), otherwise the connection sign. Battery is rendered GREEN (with the indicator's
    // amber/red low-battery cue) regardless of the accent — a battery reads as a battery; the
    // accent still tints the device GLYPH on the left.
    @ViewBuilder
    private func deviceTrailing(isConnected: Bool, battery: Int?) -> some View {
        if isConnected, let battery {
            BatteryIndicator(level: battery)
        } else {
            Image(systemName: isConnected ? "checkmark" : "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isConnected ? deviceAccent : Color.white.opacity(0.5))
        }
    }

    // Phase 14 / D-07 — CENTER column of the expandedIdle 3-column glance: time (large,
    // semibold) over date (small, secondary grey). Fully static (D-05) — no TimelineView, no
    // animation attached to either Text.
    private var centerColumn: some View {
        VStack(spacing: 2) {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // Phase 14 / WEATHER-01 / D-06 — LEFT column: the animated category icon over the
    // (static, D-05) temperature, formatted locale-aware via `.formatted()` (no manual
    // Celsius/Fahrenheit conversion, mirroring the file header contract in WeatherService.swift).
    private func weatherColumn(_ weather: WeatherGlance) -> some View {
        VStack(spacing: 4) {
            weatherIcon(for: weather.category)
                .font(.system(size: 20))
            Text(weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 90)
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

    // Phase 14 / CAL-01 / D-07 — RIGHT column: Today/Tomorrow label, the event title + the
    // event's own calendar-color dot, and the start time. `.lineLimit(1)` + `.truncationMode(
    // .tail)` on the title is MANDATORY (V5 — T-14-06 mitigation): EKEvent.title is untrusted
    // external data from subscribed/shared calendars.
    private func calendarColumn(_ glance: CalendarGlance) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(glance.isToday ? "Today" : "Tomorrow")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Text(glance.title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Circle()
                    .fill(Color(red: glance.colorRed, green: glance.colorGreen, blue: glance.colorBlue))
                    .frame(width: 6, height: 6)
            }
            Text(glance.startDate, format: .dateTime.hour().minute())
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(width: 100, alignment: .trailing)
    }

    // D-02 — map the device glyph to an SF Symbol name. All chosen names are valid SF Symbols; a
    // wrong name would only fall back gracefully (cosmetic — Pitfall 7). `.generic` covers mice,
    // keyboards, controllers, and unknown devices with a neutral radiowaves glyph.
    private func deviceSymbol(for glyph: DeviceGlyph) -> String {
        switch glyph {
        case .airpods:    return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpods.max"
        case .headphones: return "headphones"
        case .beats:      return "beats.headphones"
        case .generic:    return "dot.radiowaves.left.and.right"
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
    private func mediaExpanded(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
        let isPlaying = isPlayingFor(presentation)
        let meta = titleArtist(presentation)
        // alignment: .top + .padding(.top, 32) pins the content to the camera-clearance
        // band: nothing renders under the physical notch/camera. (Default .overlay CENTERS,
        // which with ~84pt content in a 128pt blob would leave only ~22pt top clearance —
        // not enough to clear the 32pt camera band. Top-pinning makes the clearance exact.)
        return blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top, shelfItems: shelfViewState.items,
                          shelfVisible: shelfViewState.isVisible, showSwitcher: true) {
                VStack(spacing: 6) {
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
                        EqualizerBars(isPlaying: isPlaying, tint: nowPlayingAccent)   // D-11 accent on the bars
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
                        transportButton("backward.fill", action: onPrevious)        // ⏪
                        Spacer()
                        transportButton("playpause.fill", action: onTogglePlayPause) // ⏯
                        Spacer()
                        transportButton("forward.fill", action: onNext)             // ⏩
                        Spacer()
                        Color.clear.frame(width: 28, height: 28)   // reserved Repeat slot (D-09, not built)
                    }
                }
                .padding(.top, Self.cameraClearance)        // notch/camera clearance — content starts below the band
                .padding(.bottom, 12)     // room for the bottomCornerRadius:20 curve
                .padding(.horizontal, 19) // +5pt inset (user request): art/bars off the outer edge
            }
    }

    // A single transport button (NOW-02). `.buttonStyle(.plain)` so the tap fires without
    // system chrome; the closure is the only thing that leaves the view (focus-safe).
    private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // D-12 — the "Now Playing nicht verfügbar" health state (adapter blocked/dead). Same
    // expanded blob shape so the island still morphs; a single centered message. Distinct
    // from D-11 (.none + healthy → date/time): isHealthy is the orthogonal axis.
    private var mediaUnavailable: some View {
        // 28-04 round 5 — alignment: .top + .padding(.top, 32), same reasoning as
        // expandedIsland's own round-5 change (both are shorter than the shared
        // switcherContentHeight box now that blobShape applies it uniformly).
        blobShape(topCornerRadius: 6, bottomCornerRadius: 32, alignment: .top, shelfItems: shelfViewState.items,
                  shelfVisible: shelfViewState.isVisible, showSwitcher: true) {
            Text("Now Playing nicht verfügbar")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, Self.cameraClearance)
        }
    }

    // D-01 ships pure black (merges with the hardware notch → idle-invisible);
    // D-02 shows a visible tint during development so a first-time builder can
    // confirm width / radius / position over the real notch.
    private var collapsedFill: AnyShapeStyle {
        #if DEBUG
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

// D-02/D-03/D-04/D-05 — the decorative equalizer bars (the FIRST and ONLY continuous
// animation in the app). Synthetic/decorative, NOT audio-reactive (D-03). The heights
// animate up/down on a repeatForever autoreversing animation driven by a single `animate`
// flag bound to `isPlaying`.
//
// ⚠️ THE IDLE-CPU TRAP (D-04 / Pitfall 5): the `.animation(...)` MUST be CONDITIONAL on
// `isPlaying`. When not playing it passes a FINITE `.default` animation — NOT a left-on
// `.repeatForever`. A `.repeatForever` left attached keeps SwiftUI's render loop / display
// link alive even when the bars look static, so idle CPU never returns to ~0. Swapping to a
// finite animation when paused removes the repeating clock entirely (verified on-device in
// Plan 04 UAT via `sample` / Energy idle).
struct EqualizerBars: View {
    let isPlaying: Bool                 // D-04: the SINGLE gate
    var tint: Color = .white
    private static let barCount = 5     // discretion: 3–5

    // Per-bar RANDOM profile, seeded ONCE per view IDENTITY via @State's initial-value
    // expression (held stable for the view's lifetime; re-renders don't reshuffle it).
    // @State's initial value evaluates exactly once per identity — NOT once per struct
    // construction — which is what actually delivers this stability: a plain stored `let`
    // does NOT, because SwiftUI reconstructs the struct (re-running its init) on every
    // parent re-render. Each bar oscillates between its OWN random low/high height on its
    // OWN random period + phase offset, so the bars pulse INDEPENDENTLY (random-looking)
    // instead of a uniform left-to-right sweep.
    @State private var profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] = EqualizerBars.makeProfiles()

    // Fixed box, CENTER-anchored: each bar is vertically centered and grows OUTWARD from the
    // middle (both up AND down) as its height changes — not pinned to a bottom baseline. The
    // fixed height keeps the group from resizing/jumping, and reads the SAME in the expanded
    // view as in the collapsed wing.
    private let boxHeight: CGFloat = 16

    // internal (not private): EqualizerBarsTests.swift calls this directly to sanity-check
    // the extracted factory — `private` is file-scoped and would not compile from another
    // file even under @testable import.
    static func makeProfiles() -> [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] {
        (0..<barCount).map { _ in
            (low: CGFloat.random(in: 3...6),
             high: CGFloat.random(in: 10...16),
             period: Double.random(in: 0.55...1.05),   // seconds per full up-down cycle
             phase: Double.random(in: 0...1))          // 0..1 of a cycle → bars out of sync
        }
    }

    // TIME-DRIVEN (not @State-driven) so the loop is IMMUNE to ambient withAnimation(.spring)
    // transactions — e.g. the hover spring the controller runs, which previously overrode the
    // state-based repeatForever and FROZE the bars on hover. TimelineView(.animation, paused:
    // !isPlaying) ticks each frame while playing and STOPS entirely when paused (no clock → idle
    // CPU ~0, D-04 / Pitfall 5). Each bar's height is a sine of the frame time, so a hover
    // re-render can't interrupt it.
    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<Self.barCount, id: \.self) { i in
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.5, height: height(i, at: t))
                }
            }
            .frame(height: boxHeight)
        }
    }

    // Per-bar height from the frame time: an independent sine (own period + phase) between low and
    // high while playing; the settled low height when paused (so paused bars are flat + clock-free).
    private func height(_ i: Int, at t: TimeInterval) -> CGFloat {
        let p = profiles[i]
        guard isPlaying else { return p.low }
        let frac = sin((t / p.period + p.phase) * 2 * .pi) * 0.5 + 0.5   // 0...1
        return p.low + (p.high - p.low) * frac
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
    let onSubmit: (QuickAddKind, String) -> Void

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
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing) {
            quickAddContent
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
            Button(action: {
                // WR-03 fix (28-REVIEW.md) — a trimmed-empty title silently created a
                // blank-titled EKEvent/EKReminder; guard here too (belt-and-suspenders with
                // .disabled below, which covers the visible affordance).
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                onSubmit(kind, trimmedTitle)
                title = ""
                isShowing = false
            }) {
                Text(kind == .event
                     ? "Add Event"
                     : "Add Reminder")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
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
        .frame(width: 220)
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
    // Phase 14: demonstrates the D-07 3-column layout — weather left, calendar right.
    let outfit = BasicOutfitState()
    outfit.weather = WeatherGlance(category: .rain, temperature: Measurement(value: 14, unit: .celsius))
    outfit.calendar = CalendarGlance(title: "Team Sync", startDate: .now, isToday: true,
                                      colorRed: 0.2, colorGreen: 0.5, colorBlue: 0.9)
    // Phase 6: `.expandedIdle` → the D-11 date/time (expanded, healthy, no media).
    return NotchPillView(interaction: state,
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.expandedIdle),
                         outfit: outfit,
                         shelfViewState: ShelfViewState(),
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
                         onboardingState: OnboardingViewState(),
                         viewSwitcherState: ViewSwitcherState(),
                         calendarViewState: CalendarViewState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
#endif
