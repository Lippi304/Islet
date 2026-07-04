import CoreGraphics

// ISL-05 (Q3 fix) — RUNTIME fullscreen detection via the private CoreGraphics
// "Managed Display Spaces" API (CGS / SkyLight). This is a THIN system-call wrapper
// (like NSScreen+Notch.swift), NOT a pure fixture-tested seam.
//
// WHY THIS EXISTS: the earlier runtime signal `isTrueFullscreen(builtin:)` decided
// fullscreen from the built-in display's safe-area / auxiliaryTopArea. Those are
// PHYSICAL-DISPLAY properties of the notch — they do NOT change when ANOTHER app
// enters fullscreen. Islet is a background agent (LSUIElement) and never goes
// fullscreen itself, so from its process the safe area is constant and the safe-area
// signal is ALWAYS false → the island never hid (RESEARCH Open Question Q3).
//
// THE FIX: CGSCopyManagedDisplaySpaces reports, per display, the CURRENT Space and
// its type. A true-fullscreen app lives on its own fullscreen Space (type 4), so we
// can detect another app's fullscreen without any Accessibility / TCC prompt. This is
// how the reference app boring.notch does it.
//
// The private symbols live in SkyLight and are re-exported through CoreGraphics.
// `@_silgen_name` binds them by symbol name at link time (no dlopen needed).

// CGSConnectionID is a C `int` → Int32 (ABI-compatible binding required by @_silgen_name).
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray

// kCGSSpaceFullscreen — the managed-space "type" value for a fullscreen Space.
// A normal/user space is 0; a fullscreen space is 4. The DEBUG log below prints the
// observed type so on-device testing confirms the constant on this OS (Tahoe).
private let kCGSSpaceFullscreen = 4

/// True when the built-in (notched) display's CURRENT space is a fullscreen space.
///
/// This is the LIVE runtime fullscreen signal fed into `updateVisibility()` (it
/// replaces the safe-area heuristic, which could not observe another app's fullscreen
/// from a background agent).
///
/// FAIL-SAFE: any nil / parse failure / ambiguity returns `false` — we prefer showing
/// the island over wrongly hiding it.
///
/// - Parameter builtinUUID: the built-in display's UUID (the same string our
///   `ScreenDescriptor.uuid` holds, from `CGDisplayCreateUUIDFromDisplayID`). The CGS
///   "Display Identifier" matches this; for the main/built-in it can also be "Main".
func isBuiltinDisplayInFullscreenSpace(builtinUUID: String?) -> Bool {
    // CGSCopyManagedDisplaySpaces returns an array of per-display dictionaries.
    let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())
    guard let displays = raw as? [[String: Any]], !displays.isEmpty else {
        return false // parse failure / empty → fail-safe
    }

    // Pick the display dict for the built-in.
    //  1. exact "Display Identifier" == builtinUUID, OR identifier == "Main",
    //  2. fallback: if builtinUUID is nil OR nothing matched and there is exactly ONE
    //     display dict, use that single one,
    //  3. otherwise ambiguous → fail-safe false.
    let chosen: [String: Any]?
    if let builtinUUID = builtinUUID,
       let match = displays.first(where: { ($0["Display Identifier"] as? String) == builtinUUID }) {
        chosen = match
    } else if let mainMatch = displays.first(where: { ($0["Display Identifier"] as? String) == "Main" }) {
        chosen = mainMatch
    } else if displays.count == 1 {
        chosen = displays[0]
    } else {
        chosen = nil
    }

    guard let display = chosen,
          let currentSpace = display["Current Space"] as? [String: Any],
          let type = currentSpace["type"] as? Int
    else {
        return false // missing keys / wrong types → fail-safe
    }

    #if DEBUG
    // Confirm the constant on-device: this is the real "type" of the built-in's CURRENT
    // space. If Tahoe reports a different value for a fullscreen space than 4, this log
    // reveals it during the on-device check. Never logs in release.
    print("[ISL-05] builtin current-space type = \(type)")
    #endif

    return type == kCGSSpaceFullscreen
}

// MARK: - Phase 8 / FS-01 Wave-0 probe (DEBUG-only, throwaway instrumentation)
//
// RESEARCH.md's one new candidate signal: the private CGS notification pair
// CGSClientEnterFullscreen (106) / CGSClientExitFullscreen (107), registered via
// CGSRegisterNotifyProc. This is a Wave-0 MEASUREMENT ONLY — it produces no shipped
// behavior change. NotchWindowController wires the registration/teardown and the
// diagnostic logging (all `#if DEBUG`-gated); this file only adds the constants and
// the thin @_silgen_name bindings, matching the exact declaration shape of the
// existing CGSMainConnectionID/CGSCopyManagedDisplaySpaces bindings above (no dlopen,
// resolves through this file's existing `import CoreGraphics`).

/// CGS private-notification event code for "a client entered fullscreen".
/// Not `private`: NotchWindowController.swift (same module) registers/tears down against it.
let kCGSClientEnterFullscreen: UInt32 = 106
/// CGS private-notification event code for "a client exited fullscreen".
let kCGSClientExitFullscreen: UInt32 = 107

/// The C callback signature CGSRegisterNotifyProc expects: (event type, user data,
/// payload length, payload pointer). The probe only ever reads `type` — the payload
/// params are never dereferenced (T-08-03).
typealias CGSNotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

@_silgen_name("CGSRegisterNotifyProc")
@discardableResult
func CGSRegisterNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("CGSRemoveNotifyProc")
@discardableResult
func CGSRemoveNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32
