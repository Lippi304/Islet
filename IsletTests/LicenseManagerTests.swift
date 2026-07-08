import XCTest
@testable import Islet

// Phase 12 / LIC-02 — LicenseManager's Keychain-backed persistence, tested via a fake
// in-memory LicenseStore. No real Security-framework calls execute during this test run
// (mirrors TrialManagerTests.swift's FakeKeychainStore precedent). These tests are pure
// fakes — they never touch the real Keychain or the network.
final class LicenseManagerTests: XCTestCase {

    // In-memory fake conforming to LicenseStore — no real Keychain I/O.
    private final class FakeLicenseStore: LicenseStore {
        var storedRecord: LicenseRecord?
        private(set) var readCount = 0

        func read() -> LicenseRecord? {
            readCount += 1
            return storedRecord
        }

        @discardableResult
        func write(_ record: LicenseRecord) -> Bool {
            storedRecord = record
            return true
        }

        func delete() { storedRecord = nil }
    }

    func testRecordValidationOnFreshStoreWritesGrantedRecordAndIsLicensedTrue() {
        let fake = FakeLicenseStore()
        let manager = LicenseManager(store: fake)

        XCTAssertTrue(manager.recordValidation(key: "TEST-KEY-1", validated: ValidatedLicense(id: "test-1", status: "granted", expiresAt: nil)))
        XCTAssertEqual(fake.storedRecord?.status, "granted")
        XCTAssertTrue(manager.isLicensed)
    }

    func testIsLicensedFalseOnEmptyStore() {
        let fake = FakeLicenseStore()
        let manager = LicenseManager(store: fake)

        XCTAssertFalse(manager.isLicensed)
    }

    func testIsLicensedFalseWhenSeededRecordStatusIsNotGranted() {
        let fake = FakeLicenseStore()
        fake.storedRecord = LicenseRecord(key: "K", licenseID: "L", status: "revoked", validatedAt: Date())
        let manager = LicenseManager(store: fake)

        XCTAssertFalse(manager.isLicensed)
    }

    // Gap-closure precedent (TrialManagerTests.swift): a live Keychain read on every
    // updateVisibility() call (hover/click hot path) caused a repeated macOS
    // Keychain-authorization prompt on-device. The license record must be cached
    // in-process after the first read.
    func testIsLicensedCachesAfterFirstReadAndDoesNotHitStoreAgain() {
        let fake = FakeLicenseStore()
        fake.storedRecord = LicenseRecord(key: "K", licenseID: "L", status: "granted", validatedAt: Date())
        let manager = LicenseManager(store: fake)

        _ = manager.isLicensed
        _ = manager.isLicensed
        _ = manager.isLicensed

        XCTAssertEqual(fake.readCount, 1)
    }

    func testRecordValidationDoesNotReReadStoreOnSubsequentIsLicensedReads() {
        let fake = FakeLicenseStore()
        let manager = LicenseManager(store: fake)

        manager.recordValidation(key: "TEST-KEY-2", validated: ValidatedLicense(id: "test-2", status: "granted", expiresAt: nil))
        _ = manager.isLicensed
        _ = manager.isLicensed

        // recordValidation keeps the cache in sync directly; no read() call should occur.
        XCTAssertEqual(fake.readCount, 0)
    }
}
