import SwiftUI

// Phase 6 (post-checkpoint, user request) — a compact horizontal battery indicator in the
// macOS menu-bar idiom: a rounded battery body with a LEFT-to-RIGHT fill proportional to the
// level, a terminal nub on the right, and the % label beside it. ONE reusable element so the
// charging glance (Mac battery %) and the device glance (connected Bluetooth device's battery,
// read from IOBluetoothDevice.batteryPercentSingle) look identical.
//
// Color: the accent (green by default) at a healthy level; amber under 20%, red under 10% — a
// glanceable low-battery cue. `charging` overlays a small bolt on the body. The level is clamped
// to 0...100 so a malformed value can never overflow the bar (defensive, mirrors the accent clamp).
struct BatteryIndicator: View {
    let level: Int            // 0...100 (clamped)
    var charging: Bool = false
    var accent: Color = .green

    private var clamped: Int { min(100, max(0, level)) }

    private var fillColor: Color {
        if clamped <= 10 { return .red }
        if clamped <= 20 { return .orange }
        return accent
    }

    var body: some View {
        HStack(spacing: 5) {
            Text("\(clamped)%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            batteryGlyph
        }
    }

    // The battery body: a stroked rounded rect, a left-anchored fill, an optional charging bolt,
    // and a small terminal nub on the right. Fixed small size so it sits flush in the 32 pt strip.
    private var batteryGlyph: some View {
        let bodyW: CGFloat = 24, bodyH: CGFloat = 12, corner: CGFloat = 3.5, inset: CGFloat = 1.5
        return HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: bodyW, height: bodyH)
                RoundedRectangle(cornerRadius: corner - inset)
                    .fill(fillColor)
                    .frame(width: max(2, (bodyW - inset * 2) * CGFloat(clamped) / 100.0),
                           height: bodyH - inset * 2)
                    .padding(.leading, inset)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: bodyW, height: bodyH)
                        .shadow(radius: 0.5)
                }
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.55))
                .frame(width: 2, height: bodyH * 0.42)
        }
    }
}
