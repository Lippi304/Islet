import AppKit
import SwiftUI

// Phase 20 / SHELF-03/04/05 — the leaf shelf row item: file-type icon + filename caption + its own
// scoped trash Button. Plain-value-in, no external state (mirrors BatteryIndicator's shape) — no
// @ObservedObject, no AppKit side effects performed by the view itself.
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragStarted: () -> Void

    var body: some View {
        VStack(spacing: 2) {   // UI-SPEC icon-gap
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
                .resizable()
                .frame(width: 40, height: 40)   // Phase 32 / TRAY-05 (D-04): up from 28x28
            Text(item.filename)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)   // V5 mitigation (T-20-01): item.filename is untrusted
                .frame(maxWidth: 56)   // Phase 32 / TRAY-05: preserves the ~16pt icon-to-maxWidth margin at the larger icon size
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }   // D-04 own scoped gesture — click-to-open
        .onDrag {   // Phase 21 / SHELF-06 — SIBLING drag source, D-04 default system preview
            let exists = FileManager.default.fileExists(atPath: item.localURL.path)
            guard shouldBeginShelfItemDrag(fileExists: exists) else { return NSItemProvider() }   // D-02
            onDragStarted()
            return NSItemProvider(contentsOf: item.localURL) ?? NSItemProvider()
        }
        .overlay(alignment: .topTrailing) {
            // Finding-15/D-05 precedent: a SIBLING overlay, never nested inside the tap-gesture
            // region the ancestor .onTapGesture could shadow.
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))   // Phase 32 / TRAY-05: proportional to the larger 40x40 icon
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.filename)")
            // Gap-closure (Phase 32 on-device UAT round 4) — nudge the badge inward so its
            // circular glyph never overshoots the icon's own top/trailing corner (SF Symbol
            // rendering can extend a point or two past its reported frame), which was reading
            // as "peeking outside the island" for the first tile near the shape's rounded
            // top-left corner.
            .offset(x: -2, y: 2)
        }
        .accessibilityLabel("Open \(item.filename)")
    }
}
