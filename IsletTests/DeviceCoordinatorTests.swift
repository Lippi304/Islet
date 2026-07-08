import XCTest
@testable import Islet

// Phase 16 / D-02 — regression coverage for DeviceCoordinator's extraction, one test method
// per unit-testable pitfall from 16-RESEARCH.md's "Common Pitfalls" section. No fakes/mocking
// framework — mirrors LicenseStateTests.swift's "no shared fixture, no setUp/tearDown"
// discipline and IslandResolverTests.swift's direct-TransientQueue-exercise pattern. Some
// tests wire the six closures to a real `var q = TransientQueue()`; others (where the pending
// battery-poll cap/identity behavior is what's under test, independent of TransientQueue's own
// dedup/cap semantics) wire a minimal recording fake so the coordinator's OWN bookkeeping is
// isolated from the queue's.
//
// scheduleDeviceBatteryRefresh is scheduled via DispatchQueue.main.asyncAfter(0.6s) — tests
// that need to observe its result wait on an XCTestExpectation (mirrors
// LicenseServiceTests.swift's asyncAfter-testing precedent).
@MainActor
final class DeviceCoordinatorTests: XCTestCase {

    func testPitfall1_dedupSameAddressConnectDoesNotEnqueue() {
        // Pitfall 1: a second .handle(reading, now:) call with connected: true for the SAME
        // address as an already-connected device does NOT enqueue a new transient (edge dedup
        // via connectedDeviceAddresses).
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DeviceCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            updateHead: { q.updateHead($0) },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { _ in nil }
        )
        coordinator.started(at: Date(timeIntervalSinceReferenceDate: 0))
        let reading = DeviceReading(name: "AirPods Pro", classMajor: 0x04, address: "AA:BB", connected: true)
        coordinator.handle(reading, now: 100)     // well past deviceLaunchGrace (4.0s after epoch)
        coordinator.handle(reading, now: 100.5)   // repeat connect edge for the SAME address
        XCTAssertEqual(enqueueCount, 1)
    }

    func testPitfall2Finding1_addresslessConnectedStillEnqueuesAfterLaunchGrace() {
        // Pitfall 2 / Finding 1: a DeviceReading with address: nil, connected: true (issued
        // after started(at:) was called long enough ago that launch-grace has elapsed) DOES
        // still enqueue — an addressless reading is never unconditionally dropped.
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DeviceCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            updateHead: { q.updateHead($0) },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { _ in nil }
        )
        coordinator.started(at: Date(timeIntervalSinceReferenceDate: 0))
        let reading = DeviceReading(name: "Mystery Device", classMajor: 0, address: nil, connected: true)
        coordinator.handle(reading, now: 100)   // well past deviceLaunchGrace (4.0s)
        XCTAssertEqual(enqueueCount, 1)
    }

    func testPitfall3_launchGraceSuppressesSplashButStillRecordsConnection() {
        // Pitfall 3: a device reading with connected: true fed via .handle(reading, now:)
        // immediately after started(at: someDate) (within deviceLaunchGrace of 4.0s) is
        // recorded as connected (a LATER disconnect for the same address, past the grace
        // window, DOES splash) but does NOT enqueue a transient at the launch instant itself.
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DeviceCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            updateHead: { q.updateHead($0) },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { _ in nil }
        )
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        coordinator.started(at: start)

        let connectReading = DeviceReading(name: "AirPods", classMajor: 0x04, address: "CC:DD", connected: true)
        coordinator.handle(connectReading, now: 1001)   // 1s after start, WITHIN the 4.0s grace
        XCTAssertEqual(enqueueCount, 0)

        let disconnectReading = DeviceReading(name: "AirPods", classMajor: 0x04, address: "CC:DD", connected: false)
        coordinator.handle(disconnectReading, now: 1010)   // past both grace and debounce
        XCTAssertEqual(enqueueCount, 1)
    }

    func testPitfall4_debounceDropsReconnectEdgeWithinWindow() {
        // Pitfall 4: a connect then a disconnect then a reconnect for the SAME address, all
        // within deviceDebounce (3.0s) of each other via the now parameter, drops the second
        // edge even though the Set-based dedup alone would have allowed it — the two debounce
        // layers (connectedDeviceAddresses Set vs. deviceLastShown timestamp) are independent.
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DeviceCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            updateHead: { q.updateHead($0) },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { _ in nil }
        )
        let reading = DeviceReading(name: "Headphones", classMajor: 0x04, address: "EE:FF", connected: true)
        let disconnectReading = DeviceReading(name: "Headphones", classMajor: 0x04, address: "EE:FF", connected: false)

        coordinator.handle(reading, now: 1000)               // connect — enqueues (count=1)
        coordinator.handle(disconnectReading, now: 1000.1)   // disconnect within debounce — dropped
        coordinator.handle(reading, now: 1000.2)             // reconnect within debounce — also dropped

        XCTAssertEqual(enqueueCount, 1)
    }

    func testPitfall5_twoAddresslessReadingsBothEnqueueIndependently() {
        // Pitfall 5: two SEPARATE addressless DeviceReadings, each fed via .handle(reading,
        // now:) well past launch-grace and close together in time (both within deviceDebounce's
        // 3.0s window), BOTH enqueue a transient — proving an addressless reading never gets
        // (and never needs) a debounce timestamp, so a second addressless reading is never
        // incorrectly deduped against the first under some fallback key.
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DeviceCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            updateHead: { q.updateHead($0) },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { _ in nil }
        )
        let readingA = DeviceReading(name: "Device A", classMajor: 0, address: nil, connected: true)
        let readingB = DeviceReading(name: "Device B", classMajor: 0, address: nil, connected: true)

        coordinator.handle(readingA, now: 1000)
        coordinator.handle(readingB, now: 1000.1)

        XCTAssertEqual(enqueueCount, 2)
    }

    func testPitfall6Finding4_connectBehindHeadSchedulesPendingBatteryPoll() {
        // Pitfall 6 / Finding 4: a connect reading for a SECOND device while a first device
        // already occupies the queue head enqueues a PendingBatteryPoll — assert via a
        // subsequent activityPromoted() call that DOES trigger batteryForAddress.
        var headOccupied = false
        var promotedOverride: ActiveTransient?
        var batteryCalls: [String] = []
        let coordinator = DeviceCoordinator(
            queueHead: { promotedOverride ?? (headOccupied ? .device(.connected(name: "Head", glyph: .generic, battery: nil)) : nil) },
            enqueue: { _ in let wasEmpty = !headOccupied; headOccupied = true; return wasEmpty },
            updateHead: { _ in },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { addr in batteryCalls.append(addr); return nil }
        )
        coordinator.handle(DeviceReading(name: "Head", classMajor: 0, address: "H1", connected: true), now: 1000)
        // Second device connects while Head already occupies the queue — enqueued BEHIND head.
        coordinator.handle(DeviceReading(name: "Second", classMajor: 0, address: "S1", connected: true), now: 1001)

        let exp = expectation(description: "battery lookup for the promoted second device")
        promotedOverride = .device(.connected(name: "Second", glyph: .generic, battery: nil))
        coordinator.activityPromoted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(batteryCalls, ["S1"])
    }

    func testPitfall6Finding4_disconnectThatFailsToBecomeHeadDoesNotConsumeAPendingBatteryPollSlot() {
        // Pitfall 6 / Finding 4 (disconnect half): a DISCONNECT reading that fails to become
        // head must NOT create a pending poll entry. Proven via the cap-at-2 side effect: fill
        // pendingDeviceBatteryPolls with 2 real connect entries, then have the ORIGINAL head
        // device disconnect (also "behind head" under this fake) — if the disconnect had wrongly
        // consumed a slot, the cap would have evicted the oldest (A1) entry.
        var headOccupied = false
        var promotedOverride: ActiveTransient?
        var batteryCalls: [String] = []
        let coordinator = DeviceCoordinator(
            queueHead: { promotedOverride ?? (headOccupied ? .device(.connected(name: "C", glyph: .generic, battery: nil)) : nil) },
            enqueue: { _ in let wasEmpty = !headOccupied; headOccupied = true; return wasEmpty },
            updateHead: { _ in },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { addr in batteryCalls.append(addr); return nil }
        )
        coordinator.handle(DeviceReading(name: "C", classMajor: 0, address: "C1", connected: true), now: 1000)   // becomes head
        coordinator.handle(DeviceReading(name: "A", classMajor: 0, address: "A1", connected: true), now: 1001)   // pending poll [A1]
        coordinator.handle(DeviceReading(name: "B", classMajor: 0, address: "B1", connected: true), now: 1002)   // pending poll [A1, B1] — cap full

        // C (the head device) disconnects — must NOT be remembered for a battery poll.
        coordinator.handle(DeviceReading(name: "C", classMajor: 0, address: "C1", connected: false), now: 1010)

        let exp = expectation(description: "A1 is still matchable — its slot was not stolen by C's disconnect")
        promotedOverride = .device(.connected(name: "A", glyph: .generic, battery: nil))
        coordinator.activityPromoted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(batteryCalls, ["A1"])
    }

    func testPitfall7_pendingBatteryPollsCappedAtTwo() {
        // Pitfall 7: enqueuing 3 distinct connect readings behind an occupied head caps
        // pendingDeviceBatteryPolls at 2 — only the 2 most recent are matchable via
        // activityPromoted(); the oldest was dropped.
        var headOccupied = false
        var promotedOverride: ActiveTransient?
        var batteryCalls: [String] = []
        let coordinator = DeviceCoordinator(
            queueHead: { promotedOverride ?? (headOccupied ? .device(.connected(name: "Head", glyph: .generic, battery: nil)) : nil) },
            enqueue: { _ in let wasEmpty = !headOccupied; headOccupied = true; return wasEmpty },
            updateHead: { _ in },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { addr in batteryCalls.append(addr); return nil }
        )
        coordinator.handle(DeviceReading(name: "Head", classMajor: 0, address: "H1", connected: true), now: 1000)
        coordinator.handle(DeviceReading(name: "A", classMajor: 0, address: "A1", connected: true), now: 1001)
        coordinator.handle(DeviceReading(name: "B", classMajor: 0, address: "B1", connected: true), now: 1002)
        coordinator.handle(DeviceReading(name: "C", classMajor: 0, address: "C1", connected: true), now: 1003)

        // A was the oldest of 3 entries behind a cap of 2 — promoting it finds no match, so no
        // battery lookup is even scheduled.
        promotedOverride = .device(.connected(name: "A", glyph: .generic, battery: nil))
        coordinator.activityPromoted()

        // B and C — the 2 surviving entries — are each still matchable. Wait for each scheduled
        // lookup to complete before promoting again (scheduleDeviceBatteryRefresh cancels any
        // still-pending poll — Finding 2 — so sequencing avoids a false negative).
        let expB = expectation(description: "battery lookup for B1")
        promotedOverride = .device(.connected(name: "B", glyph: .generic, battery: nil))
        coordinator.activityPromoted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { expB.fulfill() }
        wait(for: [expB], timeout: 2.0)

        let expC = expectation(description: "battery lookup for C1")
        promotedOverride = .device(.connected(name: "C", glyph: .generic, battery: nil))
        coordinator.activityPromoted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { expC.fulfill() }
        wait(for: [expC], timeout: 2.0)

        XCTAssertFalse(batteryCalls.contains("A1"))
        XCTAssertTrue(batteryCalls.contains("B1"))
        XCTAssertTrue(batteryCalls.contains("C1"))
    }

    func testPitfall8WR1_activityPromotedMatchesByIdentityNotFIFOPosition() {
        // Pitfall 8 / WR-1: activityPromoted() matches the promoted device by IDENTITY (its
        // DeviceActivity payload) not FIFO position — mirrors
        // IslandResolverTests.testMatchPendingBatteryPollFindsByIdentityNotFIFOPosition's exact
        // scenario (two pending polls "A" and "B", "B" promoted, assert "B"'s battery gets
        // polled, not "A"'s).
        var headOccupied = false
        var promotedOverride: ActiveTransient?
        var batteryCalls: [String] = []
        let coordinator = DeviceCoordinator(
            queueHead: { promotedOverride ?? (headOccupied ? .device(.connected(name: "Head", glyph: .generic, battery: nil)) : nil) },
            enqueue: { _ in let wasEmpty = !headOccupied; headOccupied = true; return wasEmpty },
            updateHead: { _ in },
            presentTransientChange: {},
            renderPresentation: {},
            batteryForAddress: { addr in batteryCalls.append(addr); return nil }
        )
        coordinator.handle(DeviceReading(name: "Head", classMajor: 0, address: "H1", connected: true), now: 1000)
        coordinator.handle(DeviceReading(name: "A", classMajor: 0, address: "A1", connected: true), now: 1001)   // pending = [A]
        coordinator.handle(DeviceReading(name: "B", classMajor: 0, address: "B1", connected: true), now: 1002)   // pending = [A, B]

        // "B" is promoted (NOT first-in / FIFO position "A") — must match B by identity.
        let exp = expectation(description: "battery lookup for B1 by identity")
        promotedOverride = .device(.connected(name: "B", glyph: .generic, battery: nil))
        coordinator.activityPromoted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(batteryCalls, ["B1"])   // NOT "A1" — a naive FIFO .first pop would match A
    }
}
