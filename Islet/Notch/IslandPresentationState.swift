import Foundation

// Phase 6 / COORD-01 / D-05 — the @Published carrier for the resolver's verdict.
//
// Mirrors ChargingActivityState exactly: a plain published holder, no
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

    // Phase 34 (UAT revision, D-11) — the live drag-hover carrier for the Quick Action picker's
    // 3 destination buttons. Controller-owned: Plan 02's `handleDragApproachTick` computes which
    // button (if any) `NSEvent.mouseLocation` currently hits via `computeQuickActionButtonFrames`
    // and assigns it here, only on change (34-RESEARCH.md Pitfall 8 — avoids re-rendering the
    // picker dozens of times/second for no visual change). The view is a pure consumer, never a
    // computer, of this value — mirrors `presentation` itself in that respect.
    @Published var hoveredQuickActionButtonIndex: Int? = nil

    // Phase 42 / DUAL-01 — the live secondary-activity bubble carrier, alongside `presentation`
    // itself. Controller-owned: `NotchWindowController.renderPresentation()` (Plan 42-04) is the
    // only writer, computing it via the pure `resolveSecondary(primary:nowPlaying:)` reducer. The
    // view is a pure consumer, never a computer, of this value — mirrors `presentation` itself
    // in that respect.
    @Published var secondary: SecondaryActivity? = nil

    init(_ presentation: IslandPresentation = .idle) {
        self.presentation = presentation
    }
}
