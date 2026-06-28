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

    // CHG-01 / Pattern 2 — the SEPARATE charging-splash model (Plan 01). The controller
    // (Plan 03) reads IOPS, maps via powerActivity(from:), and sets `.activity` inside its
    // spring animation wrapper; this view only RENDERS whatever activity is published.
    // It is deliberately NOT a NotchInteractionState phase, so the Phase-2 gesture machine
    // stays untouched and D-11 precedence is a one-line `if` in the body below.
    // Declared BEFORE onClick (a non-defaulted parameter ahead of a defaulted one) so the
    // controller call reads `NotchPillView(interaction:charging:onClick:)`.
    @ObservedObject var charging: ChargingActivityState

    // Phase 4 / NOW-01/02 — the SEPARATE @Published media model (Plan 02). The controller
    // (Plan 04) owns it: the monitor lifts MediaRemote payloads → presentation/artwork and
    // drives `isHealthy` from the D-12 launch probe + D-13 mid-death. This view only RENDERS
    // whatever is published — no MediaRemote, no animation of its own EXCEPT the deliberately
    // isPlaying-gated equalizer bars below. Declared BEFORE onClick (non-defaulted ahead of a
    // defaulted parameter) so the controller call reads
    // `NotchPillView(interaction:charging:nowPlaying:onClick:...)`.
    //
    // NOTE (Phase 6 / D-05): the view no longer READS `charging.activity` /
    // `interaction.isExpanded` / `nowPlaying.presentation` to DECIDE which branch to render —
    // the controller's resolver does that and hands the answer in via `presentation` below.
    // `nowPlaying.artwork` is still read for the media cases (the resolver passes only the
    // presentation enum, not the NSImage), and `charging`/`nowPlaying` are still @ObservedObject
    // so an artwork/standing-% mutation re-renders the same case. The PRECEDENCE decision is gone.
    @ObservedObject var nowPlaying: NowPlayingState

    // Phase 6 / COORD-01 / D-05 — the SINGLE arbiter's verdict, published. The controller
    // computes it via `resolve(activeTransient:nowPlaying:nowPlayingHealthy:isExpanded:)` (the
    // pure IslandResolver) and writes `presentationState.presentation` inside its spring; this
    // @ObservedObject re-renders the body — ONE `switch` over the enum, no precedence `if`-chain.
    // A small published model (mirroring charging/nowPlaying) avoids re-hosting on every change.
    @ObservedObject var presentationState: IslandPresentationState
    // Convenience so the body + previews read a plain enum.
    private var presentation: IslandPresentation { presentationState.presentation }

    // Phase 6 / D-11 / Pattern 4 — the persisted accent the controller injects on the hosting
    // view via `.environment(\.activityAccent, …)`. It tints ONLY the three lively leaf
    // elements (charging filling glyph, equalizer bars, device icon); the black island and the
    // expanded chrome stay untinted (D-10). Defaults to `.white` (the EnvironmentKey default)
    // so previews render the neutral look before the controller wires a swatch.
    @Environment(\.activityAccent) private var accent

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

    // The single shared morph identity (D-07): the collapsed and expanded blobs both
    // morph against this one geometry group via matchedGeometryEffect(id: "island").
    @Namespace private var ns

    // Size seeds (D-06: expanded is only modestly larger than the notch). Plan 03
    // sizes the panel to `expandedSize` up front (via expandedNotchFrame) so the
    // morph never clips mid-animation, and passes the SAME expandedSize so the
    // window matches this content. Tunable on-device in Plan 05.
    static let collapsedSize = CGSize(width: 200, height: 38)
    // Height fits the tallest expanded content WITH a top notch-clearance band. The island
    // is pinned top-flush to the screen edge, so the top 32pt sits UNDER the physical camera/
    // notch band (== wingsSize.height, the measured notch height on this machine). The
    // mediaExpanded content must therefore START below that band or the camera cuts off the
    // title (on-device UAT). Height math:
    //   32 (top notch clearance — nothing renders under the camera)
    // + 84 (mediaExpanded content: HStack art 40 + spacing 6 + seek spacer 4 + spacing 6
    //        + transport row 28)
    // + 12 (bottom inset — room for the bottomCornerRadius:20 curve)
    // = 128.
    // The panel window (expandedNotchFrame) and the SwiftUI content frame both derive from
    // THIS one value, so the island actually GROWS taller (expands further), not just shifts
    // content in a fixed box. mediaExpanded pins its content to the top with .padding(.top,32)
    // so the clearance lands exactly at the camera band.
    static let expandedSize = CGSize(width: 360, height: 128)

    // CHG-01 / Pattern 4 — the flat wings (Alcove sideways) seed. Single source of truth:
    // Plan 03 feeds this SAME size into NotchGeometry.wingsFrame so the panel frame matches
    // this content (no runtime resize). Tuned on-device against the MEASURED notch (179×32 pt
    // on this machine): the 32 pt height matches the notch so the strip sits flush and never
    // overhangs below it, and the 305 pt CHARGING width leaves room for the battery glyph + %.
    // The panel is sized to the UNION with the 360-wide expanded frame, so this only sizes the
    // visible black strip, never the window. The pure wingsFrame tests build their own size,
    // so this constant tunes freely.
    // Post-checkpoint (user request): ONE uniform 295 pt width across all three wing glances
    // (charging, media, device) so the island reads consistently regardless of activity.
    static let wingsSize = CGSize(width: 295, height: 32)
    static let mediaWingsSize = CGSize(width: 295, height: 32)
    static let deviceWingsSize = CGSize(width: 295, height: 32)

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
            case .charging(let a):
                wings(for: a)                                                    // D-02 rank 1 transient
            case .device(let d):
                deviceWings(for: d)                                              // D-02 rank 2 transient
            case .nowPlayingWings(let p):
                mediaWings(p, art: nowPlaying.artwork)                           // D-02 collapsed media glance
            case .nowPlayingExpanded(let p, true):
                mediaExpanded(p, art: nowPlaying.artwork)                        // NOW-01/02 controls (healthy)
            case .nowPlayingExpanded(_, false):
                mediaUnavailable                                                 // D-12 "nicht verfügbar"
            case .expandedIdle:
                expandedIsland                                                   // D-11 date/time (healthy, no media)
            case .idle:
                collapsedIsland                                                  // idle pill
            }
        }
        .frame(width: Self.expandedSize.width,
               height: Self.expandedSize.height,
               alignment: .top)
        // D-02: a CLICK on the pill expands it (the controller runs nextState(_, .clicked)
        // inside its spring animation wrapper). The controller only makes the panel hit-testable
        // (ignoresMouseEvents = false) while the pointer is in the pill hot-zone, so the
        // only taps that reach here are taps on the island itself.
        .onTapGesture { onClick() }
    }

    // COLLAPSED — the existing black notch pill (D-08 idle-static). Keeps the
    // Phase-1 dev affordance: DEBUG shows a visible red tint + a small downward
    // offset so a first-time builder can SEE width/radius/position over the real
    // notch (D-02); RELEASE ships pure black so it merges with the hardware notch.
    private var collapsedIsland: some View {
        NotchShape()
            .fill(collapsedFill)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.collapsedSize.width, height: Self.collapsedSize.height)
            // D-01 (visual half): a subtle "you're in" bounce on hover only — never
            // when expanded. The controller drives this via its spring wrapper at the
            // state mutation. The haptic + the real pointer monitor are Plan 03.
            .scaleEffect(interaction.isHovering && !interaction.isExpanded ? 1.06 : 1.0)
            .offset(y: devOffset)
    }

    // EXPANDED — the same black blob grown to the compact expanded size, with a
    // small date/time readout. The blob carries the SAME matchedGeometryEffect id so
    // SwiftUI morphs the single shape from the collapsed pill to here (no cross-fade).
    private var expandedIsland: some View {
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
            .overlay(
                // D-05: Phase-2 placeholder only — real activity content arrives Phase 3+.
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            )
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
        return NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flatter than the downward blob
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            .overlay(
                HStack(spacing: 0) {
                    Image(systemName: "bolt.fill")                       // D-05 status symbol LEFT (charging cue)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isCharging ? Color.yellow : Color.white.opacity(0.6))
                        .padding(.leading, 12)
                    Spacer()                                             // clears the physical camera bridge
                    BatteryIndicator(level: percent)                     // RIGHT — same indicator as the device glance
                        .padding(.trailing, 14)
                }
                .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            )
    }

    // D-02/D-03/D-04/D-05 — the MEDIA glance WINGS: the collapsed now-playing peek.
    // Same flat strip shape + shared morph identity + wingsSize as the charging wings, so
    // SwiftUI morphs the ONE black island between the charging/media/expanded/collapsed
    // states (no cross-fade). Album art on the LEFT wing, the animated equalizer bars on
    // the RIGHT wing. `isPlaying` is derived from the presentation: `.playing` → bars bounce,
    // `.paused` → bars freeze static (D-05). The bars are the ONLY continuous animation in
    // the app and are isPlaying-gated for the idle-CPU guarantee (D-04, see EqualizerBars).
    private func mediaWings(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
        let isPlaying = isPlayingFor(presentation)
        return NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flat strip, matches charging wings
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.mediaWingsSize.width, height: Self.mediaWingsSize.height)
            .overlay(
                HStack(spacing: 0) {
                    artThumbnail(art, side: Self.mediaWingsSize.height - 8, corner: 6)  // LEFT wing
                        .padding(.leading, 10)
                    Spacer()                                            // clears the physical camera bridge
                    EqualizerBars(isPlaying: isPlaying, tint: accent)  // RIGHT wing — D-02 bars (D-11 accent)
                        .padding(.trailing, 14)
                }
                .frame(width: Self.mediaWingsSize.width, height: Self.mediaWingsSize.height)
            )
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
        return NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flat strip, matches charging/media wings
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.deviceWingsSize.width, height: Self.deviceWingsSize.height)
            .overlay(
                HStack(spacing: 0) {
                    Image(systemName: deviceSymbol(for: glyph))   // LEFT wing — device glyph (D-02)
                        .symbolRenderingMode(.hierarchical)
                        // D-11 (Phase 6): the device glyph picks up the persisted accent. The
                        // D-03 disconnected-dimming rides on top as opacity, so a disconnected
                        // device still reads as dimmed regardless of the accent hue.
                        .foregroundStyle(accent.opacity(iconOpacity))
                        .padding(.leading, 12)
                    Spacer()                                      // clears the physical camera bridge
                    deviceTrailing(isConnected: isConnected, battery: battery)   // RIGHT wing
                        .padding(.trailing, 14)
                }
                .frame(width: Self.deviceWingsSize.width, height: Self.deviceWingsSize.height)
            )
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
                .foregroundStyle(isConnected ? accent : Color.white.opacity(0.5))
        }
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
        return NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
            // .top alignment + .padding(.top, 32) pins the content to the camera-clearance
            // band: nothing renders under the physical notch/camera. (Default .overlay CENTERS,
            // which with ~84pt content in a 128pt blob would leave only ~22pt top clearance —
            // not enough to clear the 32pt camera band. Top-pinning makes the clearance exact.)
            .overlay(alignment: .top) {
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
                        EqualizerBars(isPlaying: isPlaying, tint: accent)   // D-11 accent on the bars
                            .frame(height: 40)    // center the bars vertically against the art row (like the collapsed wing) — not top-hanging
                    }
                    // D-09: reserved vertical room for the future seek bar (NOT built — NOW-04 v2).
                    Spacer(minLength: 0).frame(height: 4)
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
                .padding(.top, 32)        // notch/camera clearance — content starts below the band
                .padding(.bottom, 12)     // room for the bottomCornerRadius:20 curve
                .padding(.horizontal, 14)
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
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
            .overlay(
                Text("Now Playing nicht verfügbar")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            )
    }

    // D-01 ships pure black (merges with the hardware notch → idle-invisible);
    // D-02 shows a visible tint during development so a first-time builder can
    // confirm width / radius / position over the real notch.
    private var collapsedFill: Color {
        #if DEBUG
        return Color.red.opacity(0.6)
        #else
        return Color.black
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
    @State private var animate = false

    // Per-bar RANDOM profile, generated ONCE at init and held stable for the view's
    // lifetime (re-renders don't reshuffle it). Each bar oscillates between its OWN random
    // low/high height on its OWN random duration + start delay, so the bars pulse
    // INDEPENDENTLY (random-looking) instead of a uniform left-to-right sweep.
    private let profiles: [(low: CGFloat, high: CGFloat, duration: Double, delay: Double)]

    // Fixed box, CENTER-anchored: each bar is vertically centered and grows OUTWARD from the
    // middle (both up AND down) as its height changes — not pinned to a bottom baseline. The
    // fixed height keeps the group from resizing/jumping, and reads the SAME in the expanded
    // view as in the collapsed wing.
    private let boxHeight: CGFloat = 16

    init(isPlaying: Bool, tint: Color = .white) {
        self.isPlaying = isPlaying
        self.tint = tint
        self.profiles = (0..<Self.barCount).map { _ in
            (low: CGFloat.random(in: 3...6),
             high: CGFloat.random(in: 10...16),
             duration: Double.random(in: 0.30...0.60),
             delay: Double.random(in: 0...0.35))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                Capsule()
                    .fill(tint)
                    .frame(width: 2.5, height: animate ? profiles[i].high : profiles[i].low)
                    // ⚠️ IDLE-CPU TRAP (D-04 / Pitfall 5): the repeatForever is attached ONLY
                    // while isPlaying. When not playing a FINITE .default runs once and leaves
                    // NO repeating clock → idle CPU returns to ~0.
                    .animation(isPlaying
                        ? .easeInOut(duration: profiles[i].duration)
                            .repeatForever(autoreverses: true)
                            .delay(profiles[i].delay)
                        : .default,
                        value: animate)
            }
        }
        .frame(height: boxHeight)
        .onChange(of: isPlaying) { playing in animate = playing }
        .onAppear { animate = isPlaying }
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
                         charging: ChargingActivityState(),
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.idle))
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

#Preview("Expanded") {
    let state = NotchInteractionState()
    state.phase = .expanded
    // Phase 6: `.expandedIdle` → the D-11 date/time (expanded, healthy, no media).
    return NotchPillView(interaction: state,
                         charging: ChargingActivityState(),
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.expandedIdle))
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
                         charging: ChargingActivityState(),
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.charging(.charging(percent: 47))))
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
                         charging: ChargingActivityState(),
                         nowPlaying: NowPlayingState(),
                         presentationState: IslandPresentationState(.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: 80))))
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
                         charging: ChargingActivityState(),
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingWings(.playing(title: "New Rules", artist: "Dua Lipa"))))
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
                         charging: ChargingActivityState(),
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingWings(.paused(title: "New Rules", artist: "Dua Lipa"))))
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
                         charging: ChargingActivityState(),
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingExpanded(.playing(title: "New Rules", artist: "Dua Lipa"), healthy: true)))
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
                         charging: ChargingActivityState(),
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingExpanded(.none, healthy: false)))
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
#endif
