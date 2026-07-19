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

    // Phase 48 / OUTPUT-04 — the output panel's sibling state, alongside `presentation` and
    // `secondary` themselves. Controller-owned: `NotchWindowController.handleToggleOutputPanel()`
    // (Plan 48-03) is the only writer. Read by the view (`NotchPillView`'s `tabHeight` and
    // `mediaContent`, Plan 48-02) AND by the controller's own `visibleContentZone()`/
    // `positionAndShow()` geometry (Plan 48-03) — the CR-01 three-site invariant requires all
    // three reads see the identical boolean, which is exactly why this lives here rather than
    // as plain SwiftUI `@State`.
    @Published var outputPanelOpen: Bool = false

    // Phase 48 / OUTPUT-04 — controller-owned (`NotchWindowController.
    // handleAudioOutputDevicesChanged(_:)`), already sorted (list order IS the is-default
    // signal, per `AudioOutputPresentation.sortedAudioOutputDevices`) — the view never re-sorts
    // client-side.
    @Published var outputDevices: [AudioOutputDevice] = []

    // Phase 48 / OUTPUT-01 — controller-owned, 0...1, the slider's fill fraction when not
    // actively being dragged.
    @Published var outputCurrentVolumeFraction: CGFloat = 0

    // Phase 48 / D-06 — controller-owned, whether the CURRENT default device supports volume
    // control (Phase 47's `hasVolumeControl(deviceUID:)`); the slider dims/disables when `false`.
    @Published var outputHasVolumeControl: Bool = true

    init(_ presentation: IslandPresentation = .idle) {
        self.presentation = presentation
    }
}
