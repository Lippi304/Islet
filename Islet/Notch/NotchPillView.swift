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

    // D-02 — the CLICK-to-expand callback. The view stays AppKit-free: it only reports
    // "the pill was tapped" via this plain closure. NotchWindowController owns the
    // closure and runs the focus-safe `nextState(_, .clicked)` mutation inside its spring
    // animation wrapper, so the expand path + the spring tuning live in one place (the
    // controller), not scattered in the view. Defaults to a no-op so the DEBUG #Previews
    // (and any unit construction) build without a controller.
    var onClick: () -> Void = {}

    // The single shared morph identity (D-07): the collapsed and expanded blobs both
    // morph against this one geometry group via matchedGeometryEffect(id: "island").
    @Namespace private var ns

    // Size seeds (D-06: expanded is only modestly larger than the notch). Plan 03
    // sizes the panel to `expandedSize` up front (via expandedNotchFrame) so the
    // morph never clips mid-animation, and passes the SAME expandedSize so the
    // window matches this content. Tunable on-device in Plan 05.
    static let collapsedSize = CGSize(width: 200, height: 38)
    static let expandedSize = CGSize(width: 360, height: 72)

    // CHG-01 / Pattern 4 — the flat, WIDE wings (Alcove sideways) seed. Single source of
    // truth: Plan 03 feeds this SAME size into NotchGeometry.wingsFrame so the panel frame
    // matches this content (no runtime resize), and it matches the 360×40 seed the Plan-01
    // wingsFrame tests assert against.
    static let wingsSize = CGSize(width: 360, height: 40)

    var body: some View {
        // Fixed expanded-sized container; the pill sits flush at the TOP edge and the
        // expanded content grows DOWNWARD from the notch (RESEARCH Pattern 4: panel is
        // sized to the expanded frame so the morph never clips).
        ZStack(alignment: .top) {
            // D-11 precedence: when a charging splash is published it briefly WINS, even if
            // the user has the island expanded — show the feedback, then return to the
            // ambient state (the controller clears `.activity` after ~3s). This is the whole
            // multi-activity arbitration for Phase 3: a one-line if-ordering, no resolver.
            if let activity = charging.activity {
                wings(for: activity)            // NEW sideways branch — D-11: charging wins
            } else if interaction.isExpanded {
                expandedIsland                  // existing Phase-2 downward expand
            } else {
                collapsedIsland                 // existing idle pill
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

    // CHG-01 / D-01 / D-03 / D-04 / D-05 — the WINGS / Alcove sideways layout: a flat, wide
    // strip flanking the notch. Status symbol LEFT, a single filling battery glyph + numeric %
    // RIGHT. ONE consistent glyph encodes all three states (bolt = charging, full/green at 100%,
    // plain = on battery — D-04), NOT three mini-scenes. The view drives NO animation (D-08); the
    // controller (Plan 03) wraps the activity mutation in its spring animation wrapper.
    private func wings(for activity: ChargingActivity) -> some View {
        let isCharging: Bool
        let percent: Int
        let tint: Color
        switch activity {
        case .charging(let p): isCharging = true;  percent = p; tint = .white
        case .full(let p):     isCharging = false; percent = p; tint = .green   // D-04 green at full (discretion)
        case .onBattery(let p):isCharging = false; percent = p; tint = .white   // CHG-02 plain
        }
        let symbol = isCharging ? "battery.100percent.bolt" : "battery.100percent"
        return NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flatter than the downward blob
            .fill(Color.black)
            .matchedGeometryEffect(id: "island", in: ns)
            .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
            .overlay(
                HStack(spacing: 0) {
                    Image(systemName: "bolt.fill")                       // D-05 status symbol LEFT (discretion)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isCharging ? Color.yellow : Color.white.opacity(0.6))
                        .padding(.leading, 10)
                    Spacer()                                             // clears the physical camera bridge
                    Image(systemName: symbol, variableValue: Double(percent) / 100.0)  // D-03 filling glyph
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                    Text("\(percent)%")                                  // D-06 percent only — no time/wattage
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.trailing, 10)
                        .padding(.leading, 4)
                }
                .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
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

#if DEBUG
// Build-time correctness artifact: proves BOTH layouts compile and render without
// running the app. Each preview constructs a NotchInteractionState, sets the phase,
// and shows the view at the EXPANDED container size (Pitfall 4: an expanded-sized
// container so nothing clips mid-morph) over a light background so the black blob is
// visible. DEBUG-guarded so it never ships in release.
#Preview("Collapsed") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    // Fresh ChargingActivityState with a nil activity → the collapsed branch shows.
    return NotchPillView(interaction: state, charging: ChargingActivityState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

#Preview("Expanded") {
    let state = NotchInteractionState()
    state.phase = .expanded
    // Fresh ChargingActivityState with a nil activity → the expanded branch shows.
    return NotchPillView(interaction: state, charging: ChargingActivityState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}

// Charging Wings — proves the new sideways branch compiles and renders. A non-nil
// activity makes the D-11 precedence `if` take the wings branch (here regardless of
// the interaction phase). 47% charging → the filling `battery.100percent.bolt` glyph.
#Preview("Charging Wings") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    let cs = ChargingActivityState()
    cs.activity = .charging(percent: 47)
    return NotchPillView(interaction: state, charging: cs)
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
#endif
