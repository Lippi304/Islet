import XCTest
import CoreLocation
@testable import Islet

// Phase 15 / P15-ITEM3 — proves LocationProvider is now consumable via the LocationService
// protocol seam (mirrors LicenseManagerTests.swift's FakeLicenseStore precedent). These tests
// are pure fakes — no real CLLocationManager I/O executes during this test run.
final class LocationServiceTests: XCTestCase {

    // In-memory fake conforming to LocationService — no real CLLocationManager I/O.
    private final class FakeLocationService: LocationService {
        private(set) var requestOnceCallCount = 0
        private(set) var lastCompletion: ((CLLocation?) -> Void)?

        func requestOnce(completion: @escaping (CLLocation?) -> Void) {
            requestOnceCallCount += 1
            lastCompletion = completion
        }
    }

    func testLocationProviderConformsToLocationServiceProtocol() {
        let sut: LocationService = LocationProvider()

        XCTAssertNotNil(sut)
    }

    func testFakeLocationServiceCapturesCompletionAndRoundTripsSyntheticLocation() {
        let fake = FakeLocationService()
        var receivedLocation: CLLocation?

        fake.requestOnce { location in
            receivedLocation = location
        }

        let synthetic = CLLocation(latitude: 52.5, longitude: 13.4)
        fake.lastCompletion?(synthetic)

        XCTAssertEqual(receivedLocation?.coordinate.latitude, synthetic.coordinate.latitude)
        XCTAssertEqual(receivedLocation?.coordinate.longitude, synthetic.coordinate.longitude)
        XCTAssertEqual(fake.requestOnceCallCount, 1)
    }
}
