import AppKit

// Phase 34 / TRAY-02 (D-08, T-34-04) — the ONE genuinely uncertain OS-integration call in
// this phase, isolated behind a thin seam per this project's own "isolate the fragile
// thing" convention (mirrors NowPlayingMonitor.swift's header comment). AirDrop/Mail
// invocation from Islet's permanently non-key NotchPanel is HIGH-confidence per
// 34-RESEARCH.md (verified against TheBoredTeam/boring.notch, an architecturally identical
// non-key panel) to need ZERO window-activation code — this file ships with no key-window
// or focus-stealing call of any kind; Task 2's acceptance criteria greps for and forbids
// exactly that class of call.

// The mockable seam (34-RESEARCH.md Validation Architecture / Wave 0 Gaps): NSSharingService
// conforms for free via the extension below, so tests can substitute a fake and verify
// canPerform/perform call counts without triggering real OS UI — mirrors
// LocationServiceTests.swift's FakeLocationService precedent for other OS-boundary seams.
protocol SharingServicePerforming: AnyObject {
    func canPerform(withItems items: [Any]?) -> Bool
    func perform(withItems items: [Any])
    var delegate: NSSharingServiceDelegate? { get set }
}

extension NSSharingService: SharingServicePerforming {}

// Wraps NSSharingServiceDelegate's two completion callbacks (success/failure) into a single
// `onFinish` contract with an idempotent `finished` guard (T-34-03) — the pending-drop state
// (Plan 02) must always eventually clear exactly once, even if the OS delegate callback never
// arrives. The bounded timeout mirrors this project's own Phase 21 drag-pin safety-net
// precedent (a guaranteed fallback alongside a best-effort callback).
final class QuickActionSharingDelegate: NSObject, NSSharingServiceDelegate {
    private let onFinish: () -> Void
    private var finished = false
    private var timeoutWorkItem: DispatchWorkItem?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
        // 34-RESEARCH.md Open Question 2 (Pattern 2) — 2.0s is a STARTING value, not locked:
        // AirDrop device-discovery can legitimately outlast a naive short timeout, so Plan
        // 02's on-device UAT may need to lengthen this once the real hand-off is exercised.
        let timeout = DispatchWorkItem { [weak self] in self?.finish() }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish() }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) { finish() }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutWorkItem?.cancel()
        onFinish()
    }
}

// The seam itself. `makeService` defaults to the real NSSharingService(named:) lookup so
// production call sites never pass anything — only tests substitute a fake.
final class QuickActionSharingService {
    private let makeService: (NSSharingService.Name) -> SharingServicePerforming?
    private var activeDelegate: QuickActionSharingDelegate?

    init(makeService: @escaping (NSSharingService.Name) -> SharingServicePerforming? = { NSSharingService(named: $0) }) {
        self.makeService = makeService
    }

    // Pitfall 2 (34-RESEARCH.md) — canPerform(withItems:) is a REAL capability check, not
    // just an existence check; a `false` result is treated as an immediate completion path,
    // never a silent no-op or crash.
    func share(_ urls: [URL], via name: NSSharingService.Name, onFinish: @escaping () -> Void) {
        guard let svc = makeService(name), svc.canPerform(withItems: urls) else {
            onFinish()
            return
        }
        let delegate = QuickActionSharingDelegate(onFinish: { [weak self] in
            self?.activeDelegate = nil
            onFinish()
        })
        activeDelegate = delegate   // NSSharingService does not retain its own delegate
        svc.delegate = delegate
        svc.perform(withItems: urls)   // no window-activation call of any kind (D-08's exception never appears here)
    }
}
