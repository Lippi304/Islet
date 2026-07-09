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

    // Phase 14 / WEATHER-01 / CAL-01 — the SEPARATE @Published outfit model (weather +
    // calendar), mirroring nowPlaying/presentationState's ownership contract: the controller
    // (14-04) is the only writer, this view only RENDERS whatever is published. No default
    // value — the controller always owns and injects a real instance (same non-defaulted
    // convention as `nowPlaying`/`presentationState`).
    @ObservedObject var outfit: BasicOutfitState

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
                mediaWingsOrToast(p)                                             // D-02 collapsed media glance / Phase 18 toast
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
        blobShape(topCornerRadius: 6, bottomCornerRadius: 20) {
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
        }
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
    private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                           bottomCornerRadius: CGFloat,
                                           alignment: Alignment = .center,
                                           @ViewBuilder content: () -> Content) -> some View {
        NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
            .overlay(alignment: alignment) { content() }
            .onTapGesture { onClick() }
    }

    // Finding 12 — the shared flat-strip skeleton `wings(for:)`, `mediaWings(_:art:)`, and
    // `deviceWings(for:)` each repeated: NotchShape → .fill → .matchedGeometryEffect → .frame
    // → .overlay(content sized the same). Their size constants were already numerically
    // identical (290×32, the post-checkpoint "one uniform width" decision), so this collapses
    // them into the single `wingsSize`. Each caller supplies only its own distinct HStack content.
    private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flatter than the downward blob
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            .overlay(
                content()
                    .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            )
            // Finding 15 (06-10): all three wing glances (wings(for:), mediaWings(_:art:),
            // deviceWings(for:)) share this one tap-to-toggle through the shared helper.
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
                BatteryIndicator(level: percent, accent: accent)     // RIGHT — same indicator as the device glance
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
    // Phase 18 / NOW-05 — branches the `.nowPlayingWings` case between the toast (when a
    // genuine song change is being announced) and the normal collapsed media glance,
    // mirroring `deviceTrailing(isConnected:battery:)`'s exact @ViewBuilder if/else shape.
    @ViewBuilder
    private func mediaWingsOrToast(_ p: NowPlayingPresentation) -> some View {
        if let toast = nowPlaying.songChangeToast {
            songChangeToastView(toast)
        } else {
            mediaWings(p, art: nowPlaying.artwork)
        }
    }

    // Phase 18 / NOW-05 — the song-change toast's render: an expanded downward blob (centered,
    // per 18-UI-SPEC.md) showing the new track's title+artist as text for ~3s. Reuses
    // blobShape's default `.center` alignment (not `.top` — that's mediaExpanded's
    // camera-clearance need, not this content's) and inherits its `.onTapGesture { onClick() }`.
    private func songChangeToastView(_ toast: TrackToast) -> some View {
        blobShape(topCornerRadius: 6, bottomCornerRadius: 20) {
            VStack(spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(toast.artist)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 16)
        }
    }

    private func mediaWings(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
        let isPlaying = isPlayingFor(presentation)
        return wingsShape {
            HStack(spacing: 0) {
                artThumbnail(art, side: Self.wingsSize.height - 8, corner: 6)  // LEFT wing
                    .padding(.leading, 22)   // inset from the outer notch edge (user request)
                Spacer()                                            // clears the physical camera bridge
                EqualizerBars(isPlaying: isPlaying, tint: accent)  // RIGHT wing — D-02 bars (D-11 accent)
                    .padding(.trailing, 24)  // inset from the outer notch edge (user request)
            }
        }
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
                    .foregroundStyle(accent.opacity(iconOpacity))
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
                .foregroundStyle(isConnected ? accent : Color.white.opacity(0.5))
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
        return blobShape(topCornerRadius: 6, bottomCornerRadius: 20, alignment: .top) {
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
                    // Finding 15 (06-10): tap-to-toggle scoped ONLY to this non-button top row
                    // (art/title/artist/bars) — never to the enclosing VStack or the bottom
                    // HStack below, which holds the transport Buttons. This guarantees no tap
                    // gesture recognizer sits above the transport buttons' region. Tradeoff:
                    // the reserved Shuffle/Repeat placeholder corners no longer toggle collapse.
                    .onTapGesture { onClick() }
                    // PBAR-01: the D-09 reserved seek-bar spacer is now the real display-only
                    // progress bar (elapsed/total labels + accent-filled track).
                    ProgressBar(position: nowPlaying.position, isPlaying: isPlaying, tint: accent)
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
        blobShape(topCornerRadius: 6, bottomCornerRadius: 20) {
            Text("Now Playing nicht verfügbar")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
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
                         outfit: BasicOutfitState())
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
                         outfit: outfit)
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
                         outfit: BasicOutfitState())
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
                         outfit: BasicOutfitState())
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
                         outfit: BasicOutfitState())
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
                         outfit: BasicOutfitState())
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
                         outfit: BasicOutfitState())
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
                         outfit: BasicOutfitState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
#endif
