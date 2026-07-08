import XCTest
@testable import Islet

// Phase 11 / TRIAL-03 (Wave 0): the PURE StubLicenseService key→Result seam. Like
// PowerActivityTests' verdict matrix, this locks the D-05 key→verdict mapping and the
// D-06 async main-thread completion contract deterministically. The one new technique vs
// the existing synchronous tests: StubLicenseService completes after ~1s via
// `DispatchQueue.main.asyncAfter`, so each case waits on an `XCTestExpectation`.
//
// The state-flip + live-unlock behavior (LicenseState.sessionActivated → .licensed) is
// NOT unit-tested here — LicenseState is a `private init()` singleton and that path is
// verified on-device per 11-VALIDATION (mirrors Phase 10's manual precedent). This suite
// stays scoped to the dependency-free stub.
final class LicenseServiceTests: XCTestCase {

    // MARK: D-05 — key → verdict mapping

    func testValidMagicKeySucceedsOnMainThread() {
        // D-05: the magic key → .success. D-06: completion arrives on the MAIN thread.
        let exp = expectation(description: "activate completes")
        StubLicenseService().activate(key: "ISLET-DEMO-OK") { result in
            XCTAssertTrue(Thread.isMainThread, "completion contract: MUST fire on main")
            if case .success(let v) = result {
                XCTAssertEqual(v.status, "granted")
            } else {
                XCTFail("expected .success for the magic key")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)   // comfortably above the 1s stub delay
    }

    func testUnknownNonEmptyKeyFailsWithInvalidKey() {
        // Any other non-empty key → .failure(.invalidKey).
        let exp = expectation(description: "activate completes")
        StubLicenseService().activate(key: "NOPE-1234") { result in
            XCTAssertEqual(result.error, .invalidKey)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testWhitespaceIsTrimmedBeforeCompare() {
        // Leading/trailing whitespace + newline is trimmed before the compare → .success.
        let exp = expectation(description: "activate completes")
        StubLicenseService().activate(key: "  ISLET-DEMO-OK \n") { result in
            if case .success = result {} else { XCTFail("expected .success after trimming") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    // MARK: D-06 — asynchronicity

    func testCompletionIsAsynchronous() {
        // The completion MUST NOT run synchronously: a flag set inside the closure is still
        // false on the line immediately after `activate(...)` returns (proves the ~1s hop).
        let exp = expectation(description: "activate completes")
        var completed = false
        StubLicenseService().activate(key: "ISLET-DEMO-OK") { _ in
            completed = true
            exp.fulfill()
        }
        XCTAssertFalse(completed, "activate must complete asynchronously, not inline")
        wait(for: [exp], timeout: 3.0)
        XCTAssertTrue(completed, "completion should have fired within the timeout")
    }
}

// Small ergonomic helper so `.failure(.invalidKey)` is a one-line assertion.
private extension Result {
    var error: Failure? {
        if case .failure(let e) = self { return e }
        return nil
    }
}
