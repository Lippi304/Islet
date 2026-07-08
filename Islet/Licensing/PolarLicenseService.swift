import Foundation

// Phase 12 / LIC-02 — the REAL Polar.sh customer-portal license-key validation client.
// A ZERO-protocol-change drop-in for `LicenseService` (LicenseService.swift): replaces
// `StubLicenseService` as the wired conformer with no call-site type change (the seam is
// already held as the PROTOCOL type — SettingsView).
//
// PROTOCOL-ISOLATION (mirrors NowPlayingMonitor.swift:34-47): the fragile external here is
// the Polar network call. It is quarantined behind the injectable `HTTPSession` seam so a
// future Polar break, or a test double, is a one-file / one-init-arg swap. `URLSession.shared`
// is never hard-coded inside `activate(key:)`.
//
// CONTRACT — completion is ALWAYS delivered on the MAIN thread (LicenseService.swift header).
// `URLSession`/`HTTPSession` callbacks land on a background queue, so every `completion(...)`
// path is wrapped by the local `finish(_:)` helper's `DispatchQueue.main.async`.
//
// SAFETY (D-04 / T-12-04): a transient failure (URLError, 5xx) maps to `.unreachable`
// (retryable) — NEVER `.invalidKey`. Only 400/404/422 (not-found/revoked/disabled/expired/
// malformed) map to `.invalidKey`. A paid key must never be told it is invalid on a network
// blip.
//
// SECURITY (T-12-02 / T-12-05): the `customer-portal` validate endpoint is token-less (D-06)
// — no `Authorization` header, no access token in the binary. The pasted key is opaque
// untrusted input (T-11-03): trimmed, then placed only as a JSON body value — never logged,
// never interpolated into the URL.

/// Injectable network seam so tests can supply a fake without hitting `api.polar.sh`.
protocol HTTPSession {
    func perform(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}

/// Default conformer — forwards to `URLSession.shared`.
final class URLSessionHTTP: HTTPSession {
    func perform(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            completion(data, response, error)
        }.resume()
    }
}

/// Request body — exactly `{ key, organization_id }` (D-02: no activation/usage/conditions fields).
private struct ValidateRequest: Encodable {
    let key: String
    let organizationID: String
    enum CodingKeys: String, CodingKey {
        case key
        case organizationID = "organization_id"
    }
}

/// Success response model. Only the load-bearing fields are modeled; Codable ignores the rest.
private struct ValidatedLicenseKey: Decodable {
    let id: String
    let key: String
    let status: String        // "granted" | "revoked" | "disabled"
    let expiresAt: String?
    enum CodingKeys: String, CodingKey {
        case id, key, status
        case expiresAt = "expires_at"
    }
}

final class PolarLicenseService: LicenseService {
    // Polar customer-portal (public, no-auth) validate endpoint (D-06).
    private static let endpoint = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/validate")
    // Non-secret organization id (D-05) — the only identifier sent alongside the key.
    private static let organizationID = "952bfc3a-c29b-4024-bf2e-deded1be5908"

    private let session: HTTPSession

    init(session: HTTPSession = URLSessionHTTP()) {
        self.session = session
    }

    func activate(key: String, completion: @escaping (Result<ValidatedLicense, LicenseActivationError>) -> Void) {
        // Opaque untrusted input (T-11-03): trim, never interpolate.
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        func finish(_ result: Result<ValidatedLicense, LicenseActivationError>) {
            DispatchQueue.main.async { completion(result) }   // CONTRACT: always main thread
        }

        guard let url = Self.endpoint,
              let body = try? JSONEncoder().encode(ValidateRequest(key: trimmed, organizationID: Self.organizationID))
        else {
            return finish(.failure(.invalidKey))
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        session.perform(request) { data, response, error in
            if let error = error {
                // Offline/timeout/TLS — retryable, never a rejected key (D-04).
                return finish(.failure(.unreachable(error.localizedDescription)))
            }
            guard let http = response as? HTTPURLResponse else {
                return finish(.failure(.unreachable("No HTTP response")))
            }
            switch http.statusCode {
            case 200:
                guard let data = data,
                      let validated = try? JSONDecoder().decode(ValidatedLicenseKey.self, from: data),
                      validated.status == "granted"
                else {
                    return finish(.failure(.invalidKey))
                }
                return finish(.success(ValidatedLicense(id: validated.id, status: validated.status, expiresAt: validated.expiresAt)))
            case 400, 404, 422:
                // not found / revoked / disabled / expired / malformed request.
                return finish(.failure(.invalidKey))
            default:
                // 5xx or any other non-2xx — retryable, NEVER .invalidKey (D-04 / T-12-04).
                return finish(.failure(.unreachable("Server error \(http.statusCode)")))
            }
        }
    }
}
