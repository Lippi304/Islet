import SwiftUI

// Phase 6 (post-checkpoint, user request) — a compact horizontal battery indicator in the
// macOS / iOS idiom: a rounded battery body with a LEFT-to-RIGHT fill proportional to the level
// and the % number rendered INSIDE the body (centered), plus a terminal nub. ONE reusable element
// so the charging glance (Mac battery %) and the device glance (connected Bluetooth device's
// battery, read from IOBluetoothDevice.batteryPercentSingle) look identical.
//
// Why the number is INSIDE the body: the notch wings are only ~58 pt each (notch ≈179 pt of a
// ~295 pt strip). A "{number}% [battery]" layout is ~59 pt wide, so its number slid UNDER the
// camera — only the battery glyph stayed visible. Putting the number inside keeps the whole
// indicator to ~44 pt, which fits the wing with the number clearly visible.
//
// Color: green at a healthy level; amber under 20%, red under 10% — a glanceable low cue. The
// level is clamped to 0...100 so a malformed value can never overflow the bar.
struct BatteryIndicator: View {
    let level: Int            // 0...100 (clamped)
    var accent: Color = .green

    private var clamped: Int { min(100, max(0, level)) }

    private var fillColor: Color {
        if clamped <= 10 { return .red }
        if clamped <= 20 { return .orange }
        return accent
    }

    var body: some View {
        // Compact (~27pt body) so it sits small in the notch wing — the % rides INSIDE the body.
        let w: CGFloat = 27, h: CGFloat = 13, corner: CGFloat = 3.5, inset: CGFloat = 1.2
        return HStack(spacing: 1.2) {
            ZStack(alignment: .leading) {
                // Faint empty-track so the unfilled part still reads as a battery.
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: w, height: h)
                // The level fill (left-anchored, grows rightward).
                RoundedRectangle(cornerRadius: corner - inset)
                    .fill(fillColor)
                    .frame(width: max(4, (w - inset * 2) * CGFloat(clamped) / 100.0),
                           height: h - inset * 2)
                    .padding(.leading, inset)
                // The battery outline on top of the fill.
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: w, height: h)
                // The % number centered INSIDE the body — a small shadow keeps it legible over
                // both the bright fill and the dark empty track.
                Text("\(clamped)%")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 0.5)
                    .frame(width: w, height: h)
            }
            // The terminal nub.
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.5))
                .frame(width: 1.8, height: h * 0.4)
        }
    }
}
