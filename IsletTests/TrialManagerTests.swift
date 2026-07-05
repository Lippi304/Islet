import XCTest
@testable import Islet

// Phase 10 / TRIAL-01 + D-10/Pitfall 5 — TrialManager's Keychain-backed persistence,
// tested via a fake in-memory KeychainStore. No real Security-framework calls execute
// during this test run (mirrors the "thin system glue is not unit-tested directly against
// the real system API" precedent — here the injectable protocol seam makes the BOOLEAN
// LOGIC testable even though the real KeychainTrialStore itself stays verified on-device).
final class TrialManagerTests: XCTestCase {

    // In-memory fake conforming to KeychainStore — no real Keychain I/O.
    private final class FakeKeychainStore: KeychainStore {
        var storedDate: Date?
        private(set) var readCount = 0

        func read() -> Date? {
            readCount += 1
            return storedDate
        }

        @discardableResult
        func write(_ date: Date) -> Bool {
            storedDate = date
            return true
        }

        func delete() { storedDate = nil }
    }

    private func makeManager(fake: FakeKeychainStore = FakeKeychainStore()) -> TrialManager {
        TrialManager(keychain: fake, defaults: UserDefaults(suiteName: "TrialManagerTests-\(UUID().uuidString)")!)
    }

    func testRecordFirstLaunchOnFreshStoreWritesBothAndReturnsTrue() {
        let fake = FakeKeychainStore()
        let manager = makeManager(fake: fake)
        let now = Date(timeIntervalSince1970: 2_000_000)

        XCTAssertTrue(manager.recordFirstLaunchIfNeeded(now: now))
        XCTAssertEqual(fake.storedDate, now)
        XCTAssertEqual(manager.trialStartDate(), now)
    }

    func testRecordFirstLaunchCalledAgainReturnsFalseAndDoesNotChangeDate() {
        let fake = FakeKeychainStore()
        let manager = makeManager(fake: fake)
        let firstNow = Date(timeIntervalSince1970: 2_000_000)
        let laterNow = Date(timeIntervalSince1970: 2_500_000)

        XCTAssertTrue(manager.recordFirstLaunchIfNeeded(now: firstNow))
        XCTAssertFalse(manager.recordFirstLaunchIfNeeded(now: laterNow))
        XCTAssertEqual(manager.trialStartDate(), firstNow)
    }

    func testTrialStartDateReturnsEarlierOfTwoDisagreeingDates() {
        // Pitfall 5: Keychain has the EARLIER (real) date; UserDefaults mirror has a LATER
        // (tampered) date. Enforcement must trust the earlier Keychain date, never the
        // later mirror value — a later mirror can never extend the trial.
        let fake = FakeKeychainStore()
        let defaults = UserDefaults(suiteName: "TrialManagerTests-\(UUID().uuidString)")!
        let manager = TrialManager(keychain: fake, defaults: defaults)

        let earlierKeychainDate = Date(timeIntervalSince1970: 1_000_000)
        let laterMirrorDate = Date(timeIntervalSince1970: 9_000_000)
        fake.storedDate = earlierKeychainDate
        defaults.set(laterMirrorDate.timeIntervalSince1970, forKey: "trialStartDateMirror")

        XCTAssertEqual(manager.trialStartDate(), earlierKeychainDate)
    }

    func testTrialStartDateReturnsSingleValueWhenOnlyOneStoreHasIt() {
        let fake = FakeKeychainStore()
        let defaults = UserDefaults(suiteName: "TrialManagerTests-\(UUID().uuidString)")!
        let manager = TrialManager(keychain: fake, defaults: defaults)

        let keychainOnlyDate = Date(timeIntervalSince1970: 3_000_000)
        fake.storedDate = keychainOnlyDate

        XCTAssertEqual(manager.trialStartDate(), keychainOnlyDate)
    }

    func testTrialStartDateReturnsNilWhenNeitherStoreHasIt() {
        let manager = makeManager()
        XCTAssertNil(manager.trialStartDate())
    }

    // Gap closure (Plan 10-04 manual verification): a live Keychain read on every
    // updateVisibility() call (hover/click hot path) triggered a repeated macOS
    // Keychain-authorization prompt on-device. The start date never changes after
    // first-launch (aside from the two known write points below), so it must be
    // cached in-process after the first read.
    func testTrialStartDateCachesAfterFirstReadAndDoesNotHitKeychainAgain() {
        let fake = FakeKeychainStore()
        fake.storedDate = Date(timeIntervalSince1970: 5_000_000)
        let manager = makeManager(fake: fake)

        _ = manager.trialStartDate()
        _ = manager.trialStartDate()
        _ = manager.trialStartDate()

        XCTAssertEqual(fake.readCount, 1)
    }

    func testRecordFirstLaunchIfNeededDoesNotReReadKeychainAfterWriting() {
        let fake = FakeKeychainStore()
        let manager = makeManager(fake: fake)

        manager.recordFirstLaunchIfNeeded(now: Date(timeIntervalSince1970: 1_000_000))
        _ = manager.trialStartDate()
        _ = manager.trialStartDate()

        // recordFirstLaunchIfNeeded's own guard performs the one read that discovers
        // the store is empty; every read after the write must be served from cache.
        XCTAssertEqual(fake.readCount, 1)
    }

    #if DEBUG
    func testDebugResetTrialInvalidatesCacheSoNextReadReflectsClearedStore() {
        let fake = FakeKeychainStore()
        let manager = makeManager(fake: fake)
        manager.recordFirstLaunchIfNeeded(now: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertNotNil(manager.trialStartDate())

        manager.debugResetTrial()

        XCTAssertNil(manager.trialStartDate())
    }
    #endif

    #if DEBUG
    func testDebugResetTrialClearsBothStores() {
        let fake = FakeKeychainStore()
        let manager = makeManager(fake: fake)
        manager.recordFirstLaunchIfNeeded(now: Date())
        XCTAssertNotNil(manager.trialStartDate())

        manager.debugResetTrial()

        XCTAssertNil(manager.trialStartDate())
        XCTAssertNil(fake.storedDate)
    }
    #endif
}
