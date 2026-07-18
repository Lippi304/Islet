import Foundation

// Phase 40 / HUD-06 — the SEPARATE @Published badge-truth-source model, mirroring
// NowPlayingState's shape. Deliberately NOT routed through IslandResolver/TransientQueue/
// ActiveTransient — an available update never expires on its own and never competes for a
// collapsed-pill slot, it overlays as a badge instead.
//
// D-13: `updateAvailable` is a pure reflection of Sparkle's own live SPUUpdaterDelegate
// signal, set true only by AppDelegate.updater(_:didFindValidUpdate:) (Plan 01 Task 3) and
// never actively cleared by app code — a successful install relaunches the app, which resets
// this field to its `false` default on next launch, so no explicit clear code is needed.
final class UpdateAvailableState: ObservableObject {
    @Published var updateAvailable: Bool = false
}
