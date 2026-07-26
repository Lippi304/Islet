import Darwin

// Phase 65 Plan 02 / QACTION-01 — Screen Lock, via the private login.framework symbol
// `SACLockScreenImmediate` (path: /System/Library/PrivateFrameworks/login.framework/Versions/
// Current/login). No public API exists for an immediate screen lock. Per RESEARCH.md Pitfall 3:
// this is a private, undocumented symbol, unconfirmed on very recent macOS — mandatory
// on-device verification deferred to Plan 65-08 (T-65-03, accepted risk). Every guard failure
// returns silently (no crash, no partial application), mirroring MicMuteController.swift's
// discipline verbatim.
enum ScreenLockAction {
    static func lockNow() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",
            RTLD_LAZY
        ) else { return }
        guard let sym = dlsym(handle, "SACLockScreenImmediate") else { return }
        typealias LockFn = @convention(c) () -> Void
        let lock = unsafeBitCast(sym, to: LockFn.self)
        lock()
    }
}
