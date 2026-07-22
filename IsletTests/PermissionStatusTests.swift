import XCTest
import CoreLocation
import EventKit
import CoreBluetooth
import Intents
@testable import Islet

// Phase 54 / ARCH-P2 — pure mapper + D-13 combine-rule coverage, mirrors
// OnboardingFlowTests.swift's shape exactly: plain XCTestCase, no @MainActor, literal
// enum-case inputs, no framework instantiation, no mocking (every mapper under test is a
// total function over an already-resolved framework enum value).
final class PermissionStatusTests: XCTestCase {

    // MARK: mapCLAuthorization(_:)

    func testMapCLAuthorizationGranted() {
        XCTAssertEqual(mapCLAuthorization(.authorizedAlways), .granted)
        XCTAssertEqual(mapCLAuthorization(.authorized), .granted)
    }

    func testMapCLAuthorizationDenied() {
        XCTAssertEqual(mapCLAuthorization(.denied), .denied)
        XCTAssertEqual(mapCLAuthorization(.restricted), .denied)
    }

    func testMapCLAuthorizationNotYetAsked() {
        XCTAssertEqual(mapCLAuthorization(.notDetermined), .notYetAsked)
    }

    // MARK: mapEKAuthorization(_:)

    func testMapEKAuthorizationFullAccessAndWriteOnlyAreGranted() {
        XCTAssertEqual(mapEKAuthorization(.fullAccess), .granted)
        XCTAssertEqual(mapEKAuthorization(.writeOnly), .granted)
        XCTAssertEqual(mapEKAuthorization(.authorized), .granted)
    }

    func testMapEKAuthorizationDenied() {
        XCTAssertEqual(mapEKAuthorization(.denied), .denied)
        XCTAssertEqual(mapEKAuthorization(.restricted), .denied)
    }

    func testMapEKAuthorizationNotYetAsked() {
        XCTAssertEqual(mapEKAuthorization(.notDetermined), .notYetAsked)
    }

    // MARK: mapCBManagerAuthorization(_:)

    func testMapCBManagerAuthorizationGranted() {
        XCTAssertEqual(mapCBManagerAuthorization(.allowedAlways), .granted)
    }

    func testMapCBManagerAuthorizationDenied() {
        XCTAssertEqual(mapCBManagerAuthorization(.denied), .denied)
        XCTAssertEqual(mapCBManagerAuthorization(.restricted), .denied)
    }

    func testMapCBManagerAuthorizationNotYetAsked() {
        XCTAssertEqual(mapCBManagerAuthorization(.notDetermined), .notYetAsked)
    }

    // MARK: mapINFocusAuthorization(_:)

    func testMapINFocusAuthorizationGranted() {
        XCTAssertEqual(mapINFocusAuthorization(.authorized), .granted)
    }

    func testMapINFocusAuthorizationDenied() {
        XCTAssertEqual(mapINFocusAuthorization(.denied), .denied)
        XCTAssertEqual(mapINFocusAuthorization(.restricted), .denied)
    }

    func testMapINFocusAuthorizationNotYetAsked() {
        XCTAssertEqual(mapINFocusAuthorization(.notDetermined), .notYetAsked)
    }

    // MARK: combinedCalendarReminderStatus(event:reminder:) -- D-13, worst-of-two

    func testCombinedCalendarReminderStatusDeniedWinsOverNotYetAsked() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .denied, reminder: .notYetAsked),
            .denied)
    }

    func testCombinedCalendarReminderStatusNotYetAskedWinsOverGranted() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .granted, reminder: .notYetAsked),
            .notYetAsked)
    }

    func testCombinedCalendarReminderStatusGrantedOnlyWhenBothGranted() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .granted, reminder: .granted),
            .granted)
    }

    // MARK: PermissionKind deep-link anchors

    func testPermissionKindDeepLinkAnchorsAreAllNonEmpty() {
        for kind in PermissionKind.allCases {
            XCTAssertFalse(kind.deepLinkAnchor.isEmpty, "\(kind) has an empty deepLinkAnchor")
        }
    }
}
