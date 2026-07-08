import XCTest
@testable import Islet

// Phase 12 / LIC-02 (Wave 1) — the full HTTP-to-verdict matrix for the REAL
// `PolarLicenseService`, exercised entirely against `FakeHTTPSession` (in-memory fake,
// mirrors `TrialManagerTests.FakeKeychainStore`, TrialManagerTests.swift lines 11-32).
// NEVER hits `api.polar.sh` — every response is canned.
//
// Async + main-thread idiom copied from `LicenseServiceTests.swift` lines 18-27.
final class PolarLicenseServiceTests: XCTestCase {

    // MARK: - Fake network seam

    private final class FakeHTTPSession: HTTPSession {
        private let data: Data?
        private let response: URLResponse?
        private let error: Error?
        private(set) var capturedBody: Data?

        init(data: Data?, response: URLResponse?, error: Error?) {
            self.data = data
            self.response = response
            self.error = error
        }

        func perform(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            capturedBody = request.httpBody
            completion(data, response, error)
        }
    }

    private static let url = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/validate")!

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: Self.url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func grantedBody() -> Data {
        """
        {"id":"lic_1","key":"ABC-123","status":"granted","expires_at":null}
        """.data(using: .utf8)!
    }

    private func revokedBody() -> Data {
        """
        {"id":"lic_1","key":"ABC-123","status":"revoked","expires_at":null}
        """.data(using: .utf8)!
    }

    private func garbageBody() -> Data {
        "not json at all".data(using: .utf8)!
    }

    // MARK: - Verdict matrix

    func testGrantedResponseSucceedsOnMainThread() {
        let fake = FakeHTTPSession(data: grantedBody(), response: httpResponse(200), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            XCTAssertTrue(Thread.isMainThread, "completion contract: MUST fire on main")
            if case .success(let v) = result {
                XCTAssertEqual(v.id, "lic_1")
                XCTAssertEqual(v.status, "granted")
            } else {
                XCTFail("expected .success for a granted 200")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testNonGrantedStatusFailsWithInvalidKey() {
        let fake = FakeHTTPSession(data: revokedBody(), response: httpResponse(200), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            XCTAssertEqual(result.error, .invalidKey)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testUndecodableBodyFailsWithInvalidKey() {
        let fake = FakeHTTPSession(data: garbageBody(), response: httpResponse(200), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            XCTAssertEqual(result.error, .invalidKey)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testNotFoundFailsWithInvalidKey() {
        let fake = FakeHTTPSession(data: nil, response: httpResponse(404), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            XCTAssertEqual(result.error, .invalidKey)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testTransportErrorFailsWithUnreachableNeverInvalidKey() {
        let fake = FakeHTTPSession(data: nil, response: nil, error: URLError(.notConnectedToInternet))
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            if case .unreachable = result.error {} else {
                XCTFail("offline must map to .unreachable, never .invalidKey")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testServerErrorFailsWithUnreachableNeverInvalidKey() {
        let fake = FakeHTTPSession(data: nil, response: httpResponse(500), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "ABC-123") { result in
            if case .unreachable = result.error {} else {
                XCTFail("a 5xx must map to .unreachable, never .invalidKey (D-04)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testRequestBodyContainsExactlyKeyAndOrganizationID() {
        let fake = FakeHTTPSession(data: grantedBody(), response: httpResponse(200), error: nil)
        let service = PolarLicenseService(session: fake)
        let exp = expectation(description: "activate completes")

        service.activate(key: "  ABC-123  ") { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)

        guard let bodyData = fake.capturedBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        else {
            return XCTFail("request body should be valid JSON")
        }
        XCTAssertEqual(Set(json.keys), ["key", "organization_id"])
        XCTAssertEqual(json["key"] as? String, "ABC-123", "the key must be trimmed before sending")
        XCTAssertEqual(json["organization_id"] as? String, "952bfc3a-c29b-4024-bf2e-deded1be5908")
    }
}

// Small ergonomic helper so `.failure(.invalidKey)` / `.unreachable` are one-line assertions
// (mirrors LicenseServiceTests.swift lines 66-72).
private extension Result {
    var error: Failure? {
        if case .failure(let e) = self { return e }
        return nil
    }
}
