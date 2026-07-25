import SwiftUI

// Phase 59 / SETTINGS-04: the reusable card component the Activities grid (Plan 59-02)
// renders one of per activity (existing + new). Pure presentation — no persistence
// property wrapper or its underlying storage is touched here at all (D-11): the view
// only ever reads/writes through the Binding<Bool> passed in via ActivityCardData,
// keeping it fully decoupled from persistence. Plan 59-02 owns every persisted
// property declaration and builds the ActivityCardData array from those properties'
// own $bindings.
//
// No `category` field/enum lives on ActivityCardData — Plan 59-02's own card arrays
// (systemHUDCards/mediaCards/productivityCards) already partition by category, so a
// category field on the data struct itself would be unused, unrequested structure.
struct ActivityCardData: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let isOn: Binding<Bool>
    let isNew: Bool
    let onOptionsTap: (() -> Void)?
    var isComingSoon: Bool = false
}

struct ActivityCard: View {
    let data: ActivityCardData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(data.iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(data.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: data.isOn)
                .labelsHidden()
                .disabled(data.isComingSoon)

            if let onOptionsTap = data.onOptionsTap {
                Button(action: onOptionsTap) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(data.isComingSoon)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .opacity(data.isComingSoon ? 0.5 : 1.0)
        .overlay(alignment: .topTrailing) {
            if data.isComingSoon {
                Text("Coming Soon")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.85))
                    )
                    .offset(x: -6, y: -6)
            } else if data.isNew {
                Text("New")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.85))
                    )
                    .offset(x: -6, y: -6)
            }
        }
    }
}
