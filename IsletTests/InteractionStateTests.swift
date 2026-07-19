import XCTest
@testable import Islet

// ISL-03: the hover/click/grace interaction encoded as a PURE state machine.
// nextState(phase, event) is total and deterministic — no timers, no AppKit — so
// the genuinely bug-prone choreography (grace-delay races, "hover must never
// expand") is verified by an automated agent in milliseconds. Plan 03 owns the
// real NSEvent monitor + grace timer and feeds events into this function.
final class InteractionStateTests: XCTestCase {

    // MARK: nextState — the Alcove model (D-01 / D-02 / D-03)

    func testHoverEntryGivesHoverAffordanceNotExpand() {
        // D-01: hovering shows an affordance, it does NOT open the island.
        XCTAssertEqual(nextState(.collapsed, .pointerEntered), .hovering)
    }

    func testHoveringPointerExitDefersCollapse() {
        // D-03: leaving does not collapse immediately — the grace timer is pending.
        XCTAssertEqual(nextState(.hovering, .pointerExited), .hovering)
    }

    func testHoveringGraceElapsedCollapses() {
        // D-03: grace window elapsed with the pointer still out → collapse.
        XCTAssertEqual(nextState(.hovering, .graceElapsed), .collapsed)
    }

    func testHoveringClickExpands() {
        // D-02: expand on CLICK only.
        XCTAssertEqual(nextState(.hovering, .clicked), .expanded)
    }

    func testCollapsedClickExpands() {
        // A click anywhere on the pill expands even if the enter event was missed.
        XCTAssertEqual(nextState(.collapsed, .clicked), .expanded)
    }

    func testCollapsedDragEnteredExpands() {
        XCTAssertEqual(nextState(.collapsed, .dragEntered), .expanded)
    }

    func testHoveringDragEnteredExpands() {
        XCTAssertEqual(nextState(.hovering, .dragEntered), .expanded)
    }

    func testExpandedDragEnteredIsIdempotent() {
        XCTAssertEqual(nextState(.expanded, .dragEntered), .expanded)
    }

    func testExpandedPointerExitDefersCollapse() {
        // D-03: leaving an expanded island does not instantly collapse it; grace applies.
        XCTAssertEqual(nextState(.expanded, .pointerExited), .expanded)
    }

    func testExpandedGraceElapsedCollapses() {
        // D-03: grace elapsed while expanded + pointer out → collapse.
        XCTAssertEqual(nextState(.expanded, .graceElapsed), .collapsed)
    }

    func testExpandedPointerEnterStaysExpanded() {
        XCTAssertEqual(nextState(.expanded, .pointerEntered), .expanded)
    }

    func testExpandedClickToggsShut() {
        // Clicking an expanded island toggles it shut.
        XCTAssertEqual(nextState(.expanded, .clicked), .collapsed)
    }

    func testExpandedDismissedCollapsesImmediately() {
        // 43-02 round 4: resolving a Quick Action picker closes now, no grace defer.
        XCTAssertEqual(nextState(.expanded, .dismissed), .collapsed)
    }

    func testCollapsedDismissedIsNoOp() {
        XCTAssertEqual(nextState(.collapsed, .dismissed), .collapsed)
    }

    func testHoveringDismissedIsNoOp() {
        XCTAssertEqual(nextState(.hovering, .dismissed), .hovering)
    }

    func testCollapsedGraceElapsedIsNoOp() {
        // Idempotent: a stray grace tick while collapsed is a no-op.
        XCTAssertEqual(nextState(.collapsed, .graceElapsed), .collapsed)
    }

    func testCollapsedPointerExitIsNoOp() {
        XCTAssertEqual(nextState(.collapsed, .pointerExited), .collapsed)
    }

    func testHoverNeverReachesExpanded() {
        // The central ISL-03 invariant: a pointer-enter from any non-expanded phase
        // NEVER lands on .expanded. Only a click can open the island (D-01 vs D-02).
        XCTAssertNotEqual(nextState(.collapsed, .pointerEntered), .expanded)
        XCTAssertNotEqual(nextState(.hovering, .pointerEntered), .expanded)
    }

    // MARK: NotchInteractionState ObservableObject derived properties

    func testStateDefaultsToCollapsed() {
        let state = NotchInteractionState()
        XCTAssertEqual(state.phase, .collapsed)
        XCTAssertFalse(state.isExpanded)
        XCTAssertFalse(state.isHovering)
    }

    func testIsExpandedReflectsExpandedPhase() {
        let state = NotchInteractionState()
        state.phase = .expanded
        XCTAssertTrue(state.isExpanded)
        XCTAssertTrue(state.isHovering, "An expanded island is also 'hovering' for affordance purposes.")
    }

    func testIsHoveringTrueForHoveringPhaseButNotExpandedFlag() {
        let state = NotchInteractionState()
        state.phase = .hovering
        XCTAssertTrue(state.isHovering)
        XCTAssertFalse(state.isExpanded)
    }
}
