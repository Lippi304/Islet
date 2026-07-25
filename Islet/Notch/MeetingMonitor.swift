import AppKit
import CoreAudio
import AudioToolbox

// Phase 63 Plan 02 / MEET-01 — the ONE file that isolates 100% of the meeting-detection risk
// (D-03), mirroring this codebase's "one fragile system surface, one file" convention
// (NowPlayingMonitor / BluetoothMonitor / CapsLockMonitor / AudioOutputMonitor). Nothing outside
// this file may read NSWorkspace for Zoom/Teams or listen to the mic-active CoreAudio property.
//
// D-01 heuristic: there is NO public "is a call active" API on macOS. Detection is the AND of
//   (a) a target conferencing app is RUNNING (bundle-ID match against NSWorkspace), and
//   (b) the default INPUT device is running somewhere (kAudioDevicePropertyDeviceIsRunningSomewhere).
// Both halves are cheap, sandbox-free reads. Neither triggers a Microphone TCC prompt: we read the
// HAL's device-state property, we never open an input stream (Pitfall 2 / Assumption A1 — the
// go/no-go the manual spike exists to confirm on real hardware).
//
// D-07 accepts the known false positive this AND gate produces: Zoom open + its own Audio-Settings
// mic test (no actual call) also reads as "detected". That tradeoff is deliberate — do not "fix" it
// with extra heuristics. MEET-03 accepts the matching false negative: a browser-tab Google Meet call
// never matches (a) since no filesystem/process signal identifies a browser tab, so it stays
// undetected by design.
//
// T-63-04: start()/stop() are idempotent and symmetric — stop() removes the SAME
// AudioObjectPropertyListenerBlock reference CoreAudio requires, invalidates the poll Timer, and
// drops both NSWorkspace observers, so nothing outlives the monitor's owner across repeated
// Settings toggle on/off.
@MainActor
final class MeetingMonitor {
    // nonisolated(unsafe) so a future owner's nonisolated deinit can call stop(), matching
    // CapsLockMonitor/AudioOutputMonitor's stored-token treatment exactly.
    private nonisolated(unsafe) var running = false
    // Retained so stop() can remove the identical block reference — CoreAudio's block-listener API
    // requires passing back the same block for AudioObjectRemovePropertyListenerBlock to succeed.
    private nonisolated(unsafe) var listenerBlock: AudioObjectPropertyListenerBlock?
    // The device the mic-active listener is CURRENTLY registered on. Stored (not re-derived at
    // teardown) because the default input device can change while we run — removing the listener
    // from whatever happens to be default at stop() time would leak the registration on the old
    // device.
    private nonisolated(unsafe) var listenedDeviceID: AudioDeviceID?
    private nonisolated(unsafe) var pollTimer: Timer?
    private nonisolated(unsafe) var workspaceObservers: [NSObjectProtocol] = []

    // The dedup discipline cloned from CapsLockMonitor.lastCapsLockState: onChange fires ONLY on an
    // actual nil <-> non-nil transition, never on every tick while the same state holds. Plan 63-04's
    // controller handler depends on this — it calls transientQueue.preempt(_:)/removeAll(where:)
    // straight from onChange, which is only duplicate-safe if we fire exactly once per real
    // call-start/call-end.
    private var lastReading: MeetingReading?

    // WR-02 (63-REVIEW.md) — these two SURVIVE the nil gap `lastReading` cannot. Without them a
    // momentary drop of half (b) restarted the call at a brand-new `detectedAt`, i.e. the HUD
    // vanished and came back with the elapsed counter reset to 00:00 — the one number the HUD
    // exists to show. The reachable trigger is the exact scenario retargetInputListener() exists
    // for: AirPods connect mid-call, the default input device changes, evaluate() runs
    // immediately, and the conferencing app has not re-opened a stream on the new device yet, so
    // isInputRunning() reads false for a single evaluation.
    // D-08's "no debounce" is about SHOW latency; this only affects what a re-show is labelled
    // with, so the immediate-show and immediate-hide guarantees both still hold.
    private var lastCallStart: Date?
    private var lastEndedAt: Date?
    private static let callResumeGrace: TimeInterval = 10

    private let targetBundleIDs: Set<String>
    private let onChange: (MeetingReading?) -> Void

    // D-01 / 63-CONTEXT.md: new Teams (com.microsoft.teams2) AND classic Teams
    // (com.microsoft.teams) are BOTH listed — the two coexist in the wild and a machine can have
    // either installed.
    init(targetBundleIDs: Set<String> = ["us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams"],
         onChange: @escaping (MeetingReading?) -> Void) {
        self.targetBundleIDs = targetBundleIDs
        self.onChange = onChange
    }

    func start() {
        guard !running else { return }   // idempotent — never double-register on a fast toggle on/off/on.
        running = true

        // CRITICAL (AudioOutputMonitor.swift's own comment applies verbatim): CoreAudio invokes this
        // block on an internal dispatch queue, NOT main. @MainActor on this class does not
        // retroactively isolate a system-framework-invoked callback — hop to main ourselves before
        // touching any stored state or calling onChange.
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.retargetInputListener()
                self?.evaluate()
            }
        }
        listenerBlock = block

        // Fires when the system's DEFAULT input device changes (e.g. AirPods connect mid-call), so
        // the device-scoped listener below can be re-pointed without waiting for the 5s poll.
        var defaultInputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddr, nil, block)

        retargetInputListener()

        // Half (a) of the AND gate, event-driven.
        let wc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = wc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.evaluate() }
            }
            workspaceObservers.append(token)
        }

        // Coarse fallback at CapsLockMonitor's healthCheckTimer cadence: re-evaluates the whole AND
        // gate every 5s regardless of which events fired, so any launch/quit/device path the two
        // notifications or the HAL listener miss still converges within ~5s.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            // Same @Sendable-closure hop CapsLockMonitor.armHealthCheck() documents: the trailing
            // closure is not inferred main-actor-isolated even though this method is.
            DispatchQueue.main.async { [weak self] in
                self?.retargetInputListener()
                self?.evaluate()
            }
        }

        evaluate()
    }

    // Full teardown so no callback or timer can outlive this monitor's owner (T-63-04).
    // nonisolated so an owner's nonisolated deinit can call it, per this project's convention.
    nonisolated func stop() {
        pollTimer?.invalidate()
        pollTimer = nil

        let wc = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { wc.removeObserver($0) }
        workspaceObservers = []

        if let block = listenerBlock {
            var defaultInputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddr, nil, block)

            if let deviceID = listenedDeviceID {
                var runningAddr = Self.inputRunningAddress()
                AudioObjectRemovePropertyListenerBlock(deviceID, &runningAddr, nil, block)
            }
        }
        listenedDeviceID = nil
        listenerBlock = nil
        running = false
    }

    deinit {
        // Empty by design — the owner calls stop(), matching CapsLockMonitor/PowerSourceMonitor's
        // documented ownership discipline.
    }

    // kAudioDevicePropertyDeviceIsRunningSomewhere on the INPUT scope. Verified on-device that the
    // Input scope answers AudioObjectHasProperty == true for the default input device (the Global
    // scope answers too, but Input keeps this file's device scope consistent with
    // MicMuteController.swift's Input-only discipline).
    private nonisolated static func inputRunningAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
    }

    // Re-points the device-scoped listener when the default input device changes (or resolves for
    // the first time, when none existed at start()). No-op when the device is unchanged.
    private func retargetInputListener() {
        guard let block = listenerBlock else { return }
        let current = defaultInputDeviceID()   // reused from MicMuteController.swift — never re-implemented here.
        guard current != listenedDeviceID else { return }

        var runningAddr = Self.inputRunningAddress()
        if let previous = listenedDeviceID {
            AudioObjectRemovePropertyListenerBlock(previous, &runningAddr, nil, block)
        }
        listenedDeviceID = nil

        guard let current else { return }
        guard AudioObjectAddPropertyListenerBlock(current, &runningAddr, nil, block) == noErr else { return }
        listenedDeviceID = current
    }

    // Half (a): is one of the target conferencing apps running at all?
    private func isTargetAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier.map(targetBundleIDs.contains) ?? false }
    }

    // Half (b): is the default input device running somewhere (i.e. some process holds the mic)?
    // Safe default `false` on any guard failure, mirroring MicMuteController's discipline — an
    // unreadable property must never fabricate a detection.
    private func isInputRunning() -> Bool {
        guard let deviceID = defaultInputDeviceID() else { return false }
        var addr = Self.inputRunningAddress()
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &isRunning) == noErr
        else { return false }
        return isRunning == 1
    }

    // The ONE place the AND gate and the dedup live. Every event source above funnels here.
    //
    // CR-01 (63-REVIEW.md) — TWO kinds of change are emitted now, not one:
    //   (1) the nil <-> non-nil call-start/call-end edge (the original dedup, unchanged), and
    //   (2) a mute flip WHILE the same call stands.
    // (2) exists because nothing else ever re-reads mute: there is no kAudioDevicePropertyMute
    // listener, and the controller sampled it exactly once at call start. So a mid-call AirPods
    // swap (the very scenario retargetInputListener() exists for — the new device has its own
    // independent mute), the hardware mic-mute key, or any other process writing the property
    // left the HUD asserting "muted" over a live microphone for the rest of the call. The 5s poll
    // now bounds that staleness; the controller treats a (2)-emission as an in-place payload
    // refresh, never a re-preempt (see handleMeetingActivityChange).
    //
    // Still deduped: when neither the AND gate nor mute changed, nothing is emitted.
    private func evaluate() {
        let detected = isTargetAppRunning() && isInputRunning()
        // Only meaningful while detected; `false` is just the unused placeholder for the off state.
        let muted = detected ? readSystemInputMuted() : false
        if detected != (lastReading != nil) {
            if detected {
                let now = Date()
                // WR-02 — reuse the previous callStart when the gap since detection dropped was
                // shorter than the grace window: that is a device swap, not a new call. Anything
                // longer starts a fresh call at `now`.
                let resumable = lastEndedAt.map { now.timeIntervalSince($0) < Self.callResumeGrace } ?? false
                let start = resumable ? (lastCallStart ?? now) : now
                lastCallStart = start
                lastReading = MeetingReading(detectedAt: start, isMuted: muted)
            } else {
                lastEndedAt = Date()
                lastReading = nil
            }
            onChange(lastReading)
        } else if let last = lastReading, last.isMuted != muted {
            // Same call, mute changed under us — keep callStart, refresh the mute half only.
            lastReading = MeetingReading(detectedAt: last.detectedAt, isMuted: muted)
            onChange(lastReading)
        }
    }
}
