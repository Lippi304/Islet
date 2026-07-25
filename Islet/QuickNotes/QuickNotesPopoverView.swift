import SwiftUI

// Phase 64 (NOTES-01/02/03) — the popover's view-model. Mirrors ClipboardHoverState's small-
// ObservableObject convention (AppDelegate.swift): AppDelegate (Task 2) owns the real submit/
// delete logic and pushes state in / reads submitted values out via these @Published
// properties and closures — this type has zero FileManager/AppKit of its own.
final class QuickNotesController: ObservableObject {
    @Published var notes: [QuickNote] = []
    @Published var vaultConfigured: Bool = true
    @Published var errorMessage: String?
    // Plan 64-06 (Task 1) — bumped by AppDelegate only when the vault is configured; the
    // popover view observes this to request TextEditor focus via @FocusState instead of
    // AppKit's makeFirstResponder (Pitfall 10 root-cause fix).
    @Published var focusRequestToken: Int = 0

    var onSubmit: (String) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }
}

// Phase 64 — the popover's SwiftUI content, hosted via NSHostingController inside the
// NSPopover AppDelegate (Task 2) builds. Fixed 280pt width (64-UI-SPEC.md Spacing Scale).
struct QuickNotesPopoverView: View {
    @ObservedObject var controller: QuickNotesController
    @State private var text = ""
    @FocusState private var isTextFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(height: 80)
                .disabled(!controller.vaultConfigured)
                .focused($isTextFocused)

            if controller.errorMessage != nil {
                Text("Couldn't save — check your vault folder in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red)
            }

            Button {
                submit()
            } label: {
                Text("Save Note").fontWeight(.semibold)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(!controller.vaultConfigured)

            ScrollView {
                if !controller.vaultConfigured {
                    QuickNotesEmptyStateView(
                        heading: "Vault folder not set",
                        message: "Choose an Obsidian vault folder in Settings to start capturing notes."
                    )
                } else if controller.notes.isEmpty {
                    QuickNotesEmptyStateView(
                        heading: "No notes yet",
                        message: "Notes you capture here are also appended to your Obsidian vault file."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(controller.notes, id: \.id) { note in
                            QuickNoteRowView(note: note, onDelete: controller.onDelete)
                        }
                    }
                    // Plan 64-06 (Task 2) — insets rows clear of the ScrollView's overlay
                    // NSScroller hit-test strip, which otherwise covers the trailing delete
                    // button once the list is scrolled and the indicator becomes visible.
                    .padding(.trailing, 14)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        // Plan 64-06 (Task 1) — the only focus mechanism for this popover; AppDelegate bumps
        // focusRequestToken (gated on vaultConfigured), never calls makeFirstResponder.
        .onChange(of: controller.focusRequestToken) { _, _ in isTextFocused = true }
    }

    // D-03: clears the field on a successful submit so the popover stays open ready for
    // another note. D-12 (locked data-loss guard): on a failed write the typed text must
    // stay in the field — onSubmit runs synchronously and sets controller.errorMessage
    // before returning, so checking it right after the call distinguishes success from
    // failure without waiting on anything async.
    private func submit() {
        guard !text.isEmpty else { return }
        controller.onSubmit(text)
        if controller.errorMessage == nil {
            text = ""
        }
    }
}

private struct QuickNotesEmptyStateView: View {
    let heading: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// Phase 64 (D-16/D-17) — a single recent-note row, most-recent-first (ordering is
// AppDelegate's responsibility, this view just renders the array as given). Plain SwiftUI
// .onHover is legitimate here (unlike ClipboardRowView's tracking-area-based workaround)
// since this is hosted in a normal NSPopover, not an NSMenuItem.view (64-PATTERNS.md divergence).
struct QuickNoteRowView: View {
    let note: QuickNote
    let onDelete: (UUID) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(note.timestamp, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(note.text)
                .font(.system(size: 13))
            Spacer(minLength: 0)
            if isHovering {
                // Plan 64-06 (Task 3 re-fix, UAT re-check) — a plain Button's tap gesture lost
                // the gesture-arbitration race to the enclosing ScrollView's pan recognizer
                // near the trailing edge, so the click "slipped" past the button (UAT test 7).
                // .highPriorityGesture is SwiftUI's mechanism for making a gesture win over an
                // ancestor's gesture regardless of position, which a plain Button/.onTapGesture
                // does not guarantee inside a ScrollView.
                Image(systemName: "trash")
                    .foregroundStyle(Color.red)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded { onDelete(note.id) }
                    )
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
