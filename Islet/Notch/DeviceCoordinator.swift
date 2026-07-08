import Foundation

// Phase 16 / D-02 — the extracted device-splash bookkeeping (9 fields) + the 3 stateful
// methods (handleDevice/triggerDeviceBatteryRefreshIfPromoted/scheduleDeviceBatteryRefresh),
// moved verbatim out of NotchWindowController.swift and proven in isolation (Plan 16-01)
// before the controller is wired to use this type (Plan 16-02). Mirrors BluetoothMonitor's
// closure-injected-init / nonisolated(unsafe)-teardown shape exactly; DeviceCoordinator is
// NOT an NSObject (no @objc selectors are needed here).
//
// TransientQueue is a struct (value type), so the reach-back into the controller's own
// transientQueue instance MUST be closures, not a stored reference — the six closures below
// mirror the controller's own transientQueue/renderPresentation/bluetoothMonitor calls.
//
// See 16-RESEARCH.md's "Common Pitfalls" section for the 11+ verbatim gap-closure/Finding
// comments this extraction must not regress; DeviceCoordinatorTests.swift unit-tests 8 of
// them (the remaining 3 are ordering/wiring properties verified by code inspection, since
// they require real DispatchQueue.main.asyncAfter timing or the controller's deinit).
@MainActor
final class DeviceCoordinator: ActivityCoordinator {
    typealias Reading = DeviceReading

    // Phase 6 / 05 D-04 — the device-splash debounce/burst-suppression state threaded into the
    // PURE shouldShowDeviceSplash(...) predicate (no clock inside it; the caller passes `now`
    // + these dictionaries). deviceLastShown debounces reconnect flaps; deviceSuppressedAtLaunch
    // would hold the at-launch/wake connect burst (left empty for v1 — the on-device A2 verdict
    // that would seed it is a deferred carry-over; the debounce alone already bounds the queue).
    private var deviceLastShown: [String: TimeInterval] = [:]
    private var deviceSuppressedAtLaunch: Set<String> = []
    private let deviceDebounce: TimeInterval = 3.0   // mirror activityDuration (discretion seed)

    // Phase 6 fix (post-checkpoint) — the set of addresses we currently believe are CONNECTED.
    // IOBluetooth re-delivers connection events for an already-connected device (the
    // CoreBluetooth connectionEventDidOccur bridge fires repeatedly), which made a stable
    // headphone splash perpetually instead of once. We splash ONLY on a genuine connect/disconnect
    // EDGE: a connect for an address already in this set is ignored; a disconnect only splashes if
    // the address was tracked as connected. Mirrors a debounced "is this a new state" gate.
    private var connectedDeviceAddresses: Set<String> = []

    // The instant the caller's BluetoothMonitor started. Devices already connected at launch fire
    // a connect BURST the moment we register; within this grace window those are RECORDED as
    // connected but NOT splashed (the user did not just connect them — 05 D-04 at-launch
    // suppression). A genuine connect after the window splashes normally. Reset via started(at:).
    private var bluetoothStartedAt: Date?
    private let deviceLaunchGrace: TimeInterval = 4.0

    // The one-shot post-connect battery re-read (the HFP battery can arrive after the connect
    // edge). A single DispatchWorkItem — cancelled/replaced per connect, torn down via
    // cancelPendingWork(). Phase 16 — nonisolated(unsafe): only ever written on main, the
    // nonisolated cancelPendingWork() teardown is the sole nonisolated reader, no concurrent
    // access (mirrors BluetoothMonitor.connectToken's exact justification).
    private nonisolated(unsafe) var deviceBatteryWork: DispatchWorkItem?

    // Gap-closure fix (Finding 2 — battery-poll identity race): the address the CURRENT
    // scheduleDeviceBatteryRefresh poll chain is running for. `deviceBatteryWork?.cancel()`
    // cannot stop a closure that has ALREADY started executing (its body may be mid-flight when
    // a newer connect for a DIFFERENT device supersedes it), so this side table lets that stale
    // closure detect it has been superseded before it applies a (possibly wrong) battery result
    // to whatever is now the standing head. Coordinator-owned, non-persisted — mirrors the
    // existing deviceLastShown convention. Phase 16 — nonisolated(unsafe), same justification as
    // deviceBatteryWork above.
    private nonisolated(unsafe) var pollingAddress: String?

    // Gap-closure fix (WR-1 — battery-poll identity desync): address-keyed side data mirroring
    // TransientQueue's own pending order for `.device` entries ONLY, so a device promoted to head
    // LATER (not immediately, via scheduleActivityDismiss's advance() or a flushTransients
    // promotion) still gets its post-connect battery poll scheduled — handle(_:now:)'s immediate
    // `if changed` path only covers a device that becomes head RIGHT AWAY. No longer a plain
    // best-effort FIFO: it is matched by DeviceActivity IDENTITY via matchPendingBatteryPoll, not
    // by insertion order, because the old FIFO could desync from TransientQueue's own pending list
    // (a disconnect transient for a DIFFERENT device can evict the queue's corresponding entry via
    // maxDepth without ever touching this list) and poll the wrong device's battery under a
    // different device's name. Capped at 2 to mirror TransientQueue.maxDepth.
    private var pendingDeviceBatteryPolls: [PendingBatteryPoll] = []

    // Six reach-back closures — see the header comment above for why these are closures rather
    // than a stored TransientQueue/BluetoothMonitor reference.
    private let queueHead: () -> ActiveTransient?
    private let enqueue: (ActiveTransient) -> Bool
    private let updateHead: (ActiveTransient) -> Void
    private let presentTransientChange: () -> Void
    private let renderPresentation: () -> Void
    private let batteryForAddress: (String) -> Int?

    init(queueHead: @escaping () -> ActiveTransient?,
         enqueue: @escaping (ActiveTransient) -> Bool,
         updateHead: @escaping (ActiveTransient) -> Void,
         presentTransientChange: @escaping () -> Void,
         renderPresentation: @escaping () -> Void,
         batteryForAddress: @escaping (String) -> Int?) {
        self.queueHead = queueHead
        self.enqueue = enqueue
        self.updateHead = updateHead
        self.presentTransientChange = presentTransientChange
        self.renderPresentation = renderPresentation
        self.batteryForAddress = batteryForAddress
    }

    // Replaces the controller's old inline `connectedDeviceAddresses.removeAll();
    // bluetoothStartedAt = Date()` in startBluetoothMonitor().
    func started(at date: Date) {
        connectedDeviceAddresses.removeAll()
        bluetoothStartedAt = date
    }

    // Replaces the controller's old inline `deviceLastShown.removeAll()` in the devices-off
    // branch of handleSettingsChanged. Clears ONLY deviceLastShown — the documented asymmetry;
    // do NOT also clear connectedDeviceAddresses/deviceSuppressedAtLaunch.
    func reset() {
        deviceLastShown.removeAll()
    }

    // Replaces the controller's old inline `pendingDeviceBatteryPolls.removeAll()` in
    // flushTransients(.device). Runs UNCONDITIONALLY at that call site — see 16-RESEARCH.md
    // Common Pitfall 12 / Finding 3 cross-reference.
    func clearPendingBatteryPolls() {
        pendingDeviceBatteryPolls.removeAll()
    }

    // Replaces the controller's old inline `deviceBatteryWork?.cancel()` in deinit. nonisolated
    // so the controller's nonisolated deinit can call it synchronously (T-16-03).
    nonisolated func cancelPendingWork() {
        deviceBatteryWork?.cancel()
    }

    // ActivityCoordinator conformance — reads the live clock and forwards to the testable
    // overload below. (A defaulted `now:` parameter on a single method does NOT satisfy a
    // protocol requirement of strictly fewer parameters — Swift's witness matching requires an
    // exact arity match — so RESEARCH.md Assumption A2's "one method, one default arg" shape is
    // split into this thin live-clock wrapper + the deterministic overload tests call directly.)
    func handle(_ reading: DeviceReading) {
        handle(reading, now: Date().timeIntervalSinceReferenceDate)
    }

    // handleDevice(_:) reproduced verbatim, with `now` threaded through as an explicit parameter
    // (RESEARCH.md Assumption A2) so this remains deterministically unit-testable — every clock
    // read below uses `now`, never a fresh Date() call, so tests fully control the
    // launch-grace/debounce timing.
    //
    // This is the shared handlePower-style flow (05 D-04):
    //   1. The PURE shouldShowDeviceSplash(...) predicate gates BEFORE the queue (05 D-04
    //      reconnect-flap debounce + at-launch burst suppression) — T-06-09 DoS mitigation: a
    //      flapping device can't flood the queue because this gate drops repeats within `debounce`.
    //   2. The PURE deviceActivity(from:) maps the (UNTRUSTED, T-05-01) reading → a bounded
    //      DeviceActivity (name already clamped to a plain String by deviceLabel).
    //   3. ENQUEUE as a rank-2 transient (D-02): show immediately if no transient stands, else
    //      play after the current one (D-03 sequential). On a head change → render (in the spring)
    //      + the SINGLE presentTransientChange() (fullscreen gate) + arm the shared ~3s dismiss.
    func handle(_ reading: DeviceReading, now: TimeInterval) {
        // EDGE detection (post-checkpoint fix): IOBluetooth re-fires connection events for an
        // already-connected device (the CoreBluetooth bridge fires connectionEventDidOccur
        // repeatedly), which previously made a stable headphone splash perpetually. Splash ONLY on
        // a genuine connect/disconnect EDGE, keyed by address — this Set-based dedup genuinely
        // needs an address to work, so it is scoped to the `if let addr` branch below.
        //
        // Gap-closure fix (Finding 1): an ADDRESSLESS reading must NOT be dropped here — it just
        // can't be deduped by this Set. It falls through to the shared splash-gate/deviceActivity
        // call below unconditionally, mirroring shouldShowDeviceSplash's own documented "nil
        // address → can't dedup, but still show" contract (a blanket early-return on a nil
        // address would silently drop every addressless reading BEFORE that pure seam ever ran).
        if let addr = reading.address {
            if reading.connected {
                guard !connectedDeviceAddresses.contains(addr) else { return }   // already connected → no repeat splash
                connectedDeviceAddresses.insert(addr)
                // 05 D-04 at-launch suppression: a device already connected when the monitor started is
                // recorded as connected above but does NOT splash (the user did not just connect it).
                if let started = bluetoothStartedAt,
                   now - started.timeIntervalSinceReferenceDate < deviceLaunchGrace { return }
            } else {
                // Disconnect edge: only splash if we actually had it tracked as connected.
                guard connectedDeviceAddresses.remove(addr) != nil else { return }
            }
        } else if reading.connected, let started = bluetoothStartedAt,
                  now - started.timeIntervalSinceReferenceDate < deviceLaunchGrace {
            // Symmetry with the addressed path above: an addressless connect during the at-launch
            // burst window is still suppressed, even though it can't be tracked in the Set (no key).
            return
        }

        // Secondary flap debounce (05 D-04): drop a repeat edge for the same address within ~3s.
        // Passes reading.address DIRECTLY (may be nil) — shouldShowDeviceSplash's own contract
        // falls through to true when it has no address to dedup against.
        guard shouldShowDeviceSplash(address: reading.address,
                                     connected: reading.connected,
                                     now: now,
                                     lastShown: deviceLastShown,
                                     debounce: deviceDebounce,
                                     suppressedAtLaunch: deviceSuppressedAtLaunch)
        else { return }                                   // 05 D-04 — debounced
        if let addr = reading.address { deviceLastShown[addr] = now }   // only stamp when there IS a key

        guard let activity = deviceActivity(from: reading) else { return }
        let changed = enqueue(.device(activity))   // D-02 rank 2 / D-03 sequential
        if changed {
            presentTransientChange()     // Finding 11 — shared render/visibility/dismiss triplet
            // The HFP battery indicator can arrive a beat after the connect notification, so the
            // splash may open with the connection sign; refresh it shortly after so the battery
            // appears within the ~3s glance (no-op if the battery was already present / unchanged).
            // Requires an address to poll by — an addressless connect can't be battery-refreshed.
            if reading.connected, let addr = reading.address { scheduleDeviceBatteryRefresh(address: addr) }
        } else if reading.connected {
            // Gap-closure fix (Finding 4 — missed battery-refresh for a promoted device): this
            // connect was enqueued BEHIND the current head (or deduped), so it did NOT get a
            // battery-refresh scheduled above. Remember it (address + the SAME DeviceActivity
            // payload just enqueued above, capped at maxDepth) so activityPromoted() can
            // identity-match it (WR-1) once it is eventually promoted to head. A DISCONNECT that
            // fails to become head must NOT create a pending entry — only connects need one.
            if let addr = reading.address {
                pendingDeviceBatteryPolls.append(PendingBatteryPoll(address: addr, activity: activity))
                if pendingDeviceBatteryPolls.count > 2 { pendingDeviceBatteryPolls.removeFirst() }
            }
        }
    }

    // Called whenever the queue head may have just changed to a freshly-promoted `.device`
    // transient (from scheduleActivityDismiss's advance() or flushTransients's promotion). If the
    // new head is a connected device we still owe a battery refresh for, schedule it now.
    //
    // Gap-closure fix (WR-1): matched by the promoted device's actual DeviceActivity IDENTITY via
    // matchPendingBatteryPoll, not by FIFO position — the old address-only FIFO's `.first` pop
    // could poll a stale/mismatched device once it desynced from TransientQueue's own pending
    // list.
    func activityPromoted() {
        let (match, remaining) = matchPendingBatteryPoll(pendingDeviceBatteryPolls, promoted: queueHead())
        pendingDeviceBatteryPolls = remaining
        guard let match else { return }
        scheduleDeviceBatteryRefresh(address: match.address)
    }

    // Bounded POLL for the just-connected device's battery: the HFP AT+IPHONEACCEV value often
    // lands a second or two AFTER the connect notification, so a single re-read can miss it. Re-read
    // every ~0.6s; the moment a level arrives (and the device is still the standing head) update the
    // head in place (no dismiss re-arm — like a charging % tick) so the BatteryIndicator replaces the
    // connection sign live, then stop. Bounded to ~6 attempts (~3.6s) and naturally ends when the
    // device splash advances off the head. ONE work item, cancelled/replaced per connect + via
    // cancelPendingWork().
    private func scheduleDeviceBatteryRefresh(address: String, attempt: Int = 0) {
        // Finding 2: stamp the address BEFORE cancel/schedule, on every call including the
        // internal retry recursion (same address → unchanged through the chain) and whenever a
        // genuinely NEW connect starts a NEW chain (a different address supersedes the old one).
        pollingAddress = address
        deviceBatteryWork?.cancel()
        guard attempt < 6 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Finding 2: abort if a NEWER poll (for a different device) has superseded this one —
            // closes the race even when .cancel() above arrived too late to stop an already-running
            // closure body from applying its result to the wrong (now-current) head.
            guard self.pollingAddress == address else { return }
            // Stop once the device is no longer the standing splash (advanced / dismissed).
            guard case .device(.connected(let name, let glyph, let old))? = self.queueHead() else { return }
            if let fresh = self.batteryForAddress(address), fresh != old {
                let updated = DeviceActivity.connected(name: name, glyph: glyph, battery: fresh)
                self.updateHead(.device(updated))
                self.renderPresentation()
                return   // got a level — stop polling
            }
            self.scheduleDeviceBatteryRefresh(address: address, attempt: attempt + 1)   // retry
        }
        deviceBatteryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
