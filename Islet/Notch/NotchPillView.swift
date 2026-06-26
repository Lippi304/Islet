import SwiftUI

// ISL-07 / D-03 — the idle pill. STATIC by design: no motion modifiers and no
// driving clock of any kind (hover + expand/collapse are Phase 2).
struct NotchPillView: View {
    var body: some View {
        // Static fill — no animation modifiers anywhere (ISL-07 / D-03).
        NotchShape()
            .fill(fillColor)
            .offset(y: devOffset) // peek the pill below the hardware notch in DEBUG so you can SEE it
    }
    // D-01 ships pure black (merges with the hardware notch → idle-invisible);
    // D-02 shows a visible tint during development so a first-time builder can
    // confirm width / radius / position over the real notch.
    private var fillColor: Color {
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
