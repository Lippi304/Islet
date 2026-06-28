import Foundation

// Phase 6 / COORD-01 / D-05 — the @Published carrier for the resolver's verdict.
//
// Mirrors ChargingActivityState / DeviceActivityState exactly: a plain published holder, no
// methods, no timers, no system frameworks. The controller (Plan 04) is the SINGLE arbiter —
// it computes the IslandPresentation via the pure `resolve(...)` reducer and writes it here
// inside its spring animation wrapper; NotchPillView observes this and re-renders its one
// `switch`. Keeping the verdict in its OWN @Published model (rather than re-hosting the
// NSHostingView on every change) means the morph animates in place via the shared
// matchedGeometryEffect, and the view stays render-only (it never decides precedence).
//
// Defaults to `.idle` so the view renders the collapsed pill before the controller's first
// resolve (and so any unit/preview construction has a sane starting state).
final class IslandPresentationState: ObservableObject {
    @Published var presentation: IslandPresentation

    init(_ presentation: IslandPresentation = .idle) {
        self.presentation = presentation
    }
}
