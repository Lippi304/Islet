import Foundation
import CoreGraphics

// ISL-03 — the Alcove interaction model as a PURE state machine (Pattern 3).
// No timers, no AppKit: Plan 03 owns the global mouse monitor + grace timer and
// feeds events in here. Keeping the choreography pure is what makes the most
// bug-prone part (grace-delay races) unit-testable.
enum InteractionPhase: Equatable { case collapsed, hovering, expanded }
enum InteractionEvent: Equatable { case pointerEntered, pointerExited, clicked, graceElapsed }

func nextState(_ current: InteractionPhase, _ event: InteractionEvent) -> InteractionPhase {
    switch (current, event) {
    case (.collapsed, .pointerEntered): return .hovering   // D-01: hover affordance only
    case (.hovering,  .pointerExited):  return .hovering   // D-03: defer — grace timer pending
    case (.hovering,  .graceElapsed):   return .collapsed  // D-03: grace elapsed, pointer out
    case (.hovering,  .clicked):        return .expanded   // D-02: expand on click only
    case (.collapsed, .clicked):        return .expanded   // click expands even if enter was missed
    case (.expanded,  .pointerExited):  return .expanded   // D-03: defer collapse
    case (.expanded,  .graceElapsed):   return .collapsed  // D-03: grace elapsed while expanded
    case (.expanded,  .pointerEntered): return .expanded   // stay expanded
    case (.expanded,  .clicked):        return .collapsed  // toggle shut
    default:                            return current     // idempotent no-ops
    }
}

// SwiftUI-facing holder. Plan 02 binds NotchPillView to this; Plan 03 mutates `phase`
// (inside withAnimation(.spring(...))) from the monitor/timer callbacks.
final class NotchInteractionState: ObservableObject {
    @Published var phase: InteractionPhase = .collapsed

    // D-01 — the REAL measured collapsed notch size the controller publishes (unfudged:
    // exactly the cutout macOS reports). NotchPillView.collapsedIsland reads this so the idle
    // black pill matches the hardware notch and merges into it. nil = not yet measured /
    // non-notch or external display → the view falls back to NotchPillView.collapsedSize (the
    // static 200x38 seed), the same nil-propagating contract the geometry layer already uses.
    @Published var collapsedNotchSize: CGSize?

    var isExpanded: Bool { phase == .expanded }
    var isHovering: Bool { phase == .hovering || phase == .expanded }
}
