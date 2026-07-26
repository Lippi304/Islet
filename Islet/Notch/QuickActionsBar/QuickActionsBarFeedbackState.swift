import Foundation

// Phase 65 Plan 05 / QACTION-02 (interfaces) — the transient DND/Focus failure-flash signal.
// Mirrors ShelfViewState's/BasicOutfitState's exact shape: a plain published holder, no
// methods, no timers. The controller (Plan 65-07/08) is the ONLY writer (including the
// ~1.2s auto-clear-back-to-nil per 65-UI-SPEC.md's Copywriting Contract) — this view only
// renders whatever is published.
final class QuickActionsBarFeedbackState: ObservableObject {
    @Published var lastFailedAction: QuickActionsBarCatalog.Action? = nil
}
