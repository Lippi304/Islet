import SwiftUI

// ISL-04 / D-07 — the Dynamic-Island MORPH.
//
// The Phase-1 static pill becomes a collapsed↔expanded morph driven by
// `NotchInteractionState.isExpanded`. Both the collapsed pill and the expanded
// blob carry the SAME `matchedGeometryEffect(id: "island", in: ns)` on ONE shared
// namespace (`ns` below), so SwiftUI MORPHS the single black shape (corner radius +
// frame interpolate) instead of cross-fading two views (D-07: no cross-fade).
//
// This is the VIEW LAYER only. It drives NO animation itself — no internal
// `withAnimation`, no timer, no `onAppear` animation. Plan 03's controller wraps the
// state mutation in `withAnimation(.spring(response: 0.35, dampingFraction: 0.65))`
// and SwiftUI animates the dependent matchedGeometryEffect/scaleEffect automatically.
// That keeps the idle/collapsed pill provably static (D-08): no driving clock here.
struct NotchPillView: View {
    // Plan 03 owns the instance and injects it via
    // `NSHostingView(rootView: NotchPillView(interaction: state))`.
    @ObservedObject var interaction: NotchInteractionState

    // The single shared morph identity (D-07): the collapsed and expanded blobs both
    // morph against this one geometry group via matchedGeometryEffect(id: "island").
    @Namespace private var ns

    // Size seeds (D-06: expanded is only modestly larger than the notch). Plan 03
    // sizes the panel to `expandedSize` up front (via expandedNotchFrame) so the
    // morph never clips mid-animation, and passes the SAME expandedSize so the
    // window matches this content. Tunable on-device in Plan 05.
    static let collapsedSize = CGSize(width: 200, height: 38)
    static let expandedSize = CGSize(width: 360, height: 72)

    var body: some View {
        // Fixed expanded-sized container; the pill sits flush at the TOP edge and the
        // expanded content grows DOWNWARD from the notch (RESEARCH Pattern 4: panel is
        // sized to the expanded frame so the morph never clips).
        ZStack(alignment: .top) {
            if interaction.isExpanded {
                expandedIsland
            } else {
                collapsedIsland
            }
        }
        .frame(width: Self.expandedSize.width,
               height: Self.expandedSize.height,
               alignment: .top)
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
            // when expanded. The haptic + the real pointer monitor are Plan 03.
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
