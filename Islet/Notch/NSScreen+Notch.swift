import AppKit

// ISL-06 — bridge a LIVE NSScreen to the pure ScreenDescriptor seam (Plan 01).
//
// The geometry/selection math lives in NotchGeometry.swift / DisplayResolver.swift
// as pure functions over a ScreenDescriptor (so they are unit-testable without a
// real display). This extension is the one place that reads the actual system
// values off an NSScreen and packs them into that descriptor.
extension NSScreen {
    // The CGDirectDisplayID backing this NSScreen (needed for CG built-in/UUID calls).
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }
    // Built-in (vs external) display — the canonical CoreGraphics test.
    var isBuiltinDisplay: Bool {
        guard let id = displayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
    // Stable per-display UUID — persist THIS, never an array index (indices reorder).
    var displayUUID: String? {
        guard let id = displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }
    // Snapshot for the pure resolver/geometry seam.
    var descriptor: ScreenDescriptor {
        ScreenDescriptor(
            uuid: displayUUID,
            frame: frame,
            safeAreaTop: safeAreaInsets.top,
            auxLeftWidth: auxiliaryTopLeftArea?.width,
            auxRightWidth: auxiliaryTopRightArea?.width,
            isBuiltin: isBuiltinDisplay
        )
    }
}
