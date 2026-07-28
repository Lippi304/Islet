import AppKit

// Phase 66 Plan 01 / MENUBAR-01..04 — the ROADMAP-mandated spike's private-symbol shim.
// Declarations below are transcribed directly from Ice's real, current source
// (github.com/jordanbaird/Ice, MIT — `Ice/Bridging/Bridging.swift` and
// `Ice/Bridging/Shims/Private.swift`, fetched 2026-07-27), not invented or reconstructed
// from a summary. Only the handful of `CGS*` symbols this file's own window-enumeration +
// move mechanism actually calls are declared here — per 66-PATTERNS.md, "do not port Ice's
// full Private.swift surface speculatively."
//
// Per this project's "isolate the fragile/uncertain thing behind its own seam" discipline
// (NowPlayingMonitor/MicMuteController/MeetingMonitor precedent): this file is the ONE place
// the private CGS* window/frame-introspection surface is touched. RESEARCH.md Pitfall 3 —
// these are undocumented, version-fragile SkyLight/CoreGraphics symbols with no API stability
// guarantee.
//
// NOTE: `CGSMainConnectionID() -> Int32` is already declared globally in this codebase
// (FullscreenSpaceProbe.swift, Phase 2) — reused here as-is rather than re-declared (Swift
// forbids a second top-level declaration of the same symbol name). This file's own new
// declarations use the same raw `Int32` connection-ID type for consistency, rather than
// introducing a second same-named `CGSConnectionID` typealias that would collide with
// CGSSpace.swift's own `fileprivate` one.

@_silgen_name("CGSGetWindowCount")
func CGSGetWindowCount(
    _ cid: Int32,
    _ targetCID: Int32,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: Int32,
    _ targetCID: Int32,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: Int32,
    _ wid: CGWindowID,
    _ outRect: inout CGRect
) -> CGError

/// A namespace for the private-API menu-bar-item introspection + repositioning mechanism this
/// phase's own on-device spike must validate before any production Controller/Store is built
/// (ROADMAP Success Criteria #1). Mirrors Ice's own `Bridging`/`MenuBarItemManager` split, scaled
/// down to exactly what the spike exercises.
enum MenuBarOverflowBridging {

    /// One other process's menu-bar-item window, as read via the private CGS* window list.
    struct MenuBarItemWindow {
        let windowID: CGWindowID
        let ownerPID: pid_t
        let bundleIdentifier: String
        let frame: CGRect
    }

    /// Reads every other process's menu-bar-item window currently known to the window server,
    /// excluding Islet's own status items (CONTEXT.md default-discretion assumption: Islet's own
    /// icons are exempt from this file's own move function). Never crashes or force-unwraps a
    /// CGS result (T-66-04) — any guard failure degrades to an empty result.
    static func menuBarItemWindows() -> [MenuBarItemWindow] {
        guard AXIsProcessTrusted() else { return [] }

        var totalCount: Int32 = 0
        guard CGSGetWindowCount(CGSMainConnectionID(), 0, &totalCount) == .success, totalCount > 0 else {
            return []
        }

        var rawList = [CGWindowID](repeating: 0, count: Int(totalCount))
        var realCount: Int32 = 0
        guard CGSGetProcessMenuBarWindowList(CGSMainConnectionID(), 0, totalCount, &rawList, &realCount) == .success
        else {
            return []
        }
        let menuBarWindowIDs = rawList[..<Int(realCount)]
        guard !menuBarWindowIDs.isEmpty else { return [] }

        // CGS has no owner-pid accessor of its own — resolve each private windowID to its
        // owning process via the public CGWindowListCopyWindowInfo, the standard combined
        // technique (private ID enumeration + public ownership lookup).
        let ownerByWindowID = windowOwnerPIDs()

        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        var results: [MenuBarItemWindow] = []
        for windowID in menuBarWindowIDs {
            guard let pid = ownerByWindowID[windowID] else { continue }
            guard let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                  !bundleID.isEmpty, bundleID != ownBundleID
            else { continue }
            guard let frame = currentFrame(windowID: windowID) else { continue }
            results.append(MenuBarItemWindow(windowID: windowID, ownerPID: pid, bundleIdentifier: bundleID, frame: frame))
        }
        return results
    }

    /// The current screen-coordinate frame for a window, or `nil` on any CGS failure.
    static func currentFrame(windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        guard CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect) == .success else { return nil }
        return rect
    }

    private static func windowOwnerPIDs() -> [CGWindowID: pid_t] {
        guard let infoList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: AnyObject]]
        else { return [:] }
        var result: [CGWindowID: pid_t] = [:]
        for info in infoList {
            guard let number = info[kCGWindowNumber as String] as? Int,
                  let pidValue = info[kCGWindowOwnerPID as String] as? Int
            else { continue }
            result[CGWindowID(number)] = pid_t(pidValue)
        }
        return result
    }

    /// Synthesizes a mouse-down -> mouse-dragged -> mouse-up `CGEvent` sequence targeted directly
    /// at the given menu-bar-item window, dragging it to `destinationX`. Mirrors Ice's
    /// `MenuBarItemManager.move()`/`wakeUpItem()` 5-attempt retry-loop shape (read directly from
    /// Ice's real source): a `.leftMouseDown` with the `.maskCommand` flag (Cmd-drag is what
    /// puts a menu-bar item into repositioning mode rather than opening its menu) at the item's
    /// current midpoint, then a drag + release at the destination. On an unresponsive item, an
    /// unmodified wake-up down/up pair is posted before the next attempt (Ice's `wakeUpItem()`).
    /// Returns `false` on exhausted retries — never crashes, never leaves the item in a
    /// half-moved state by looping indefinitely (T-66-01).
    @discardableResult
    static func moveMenuBarItem(windowID: CGWindowID, toX destinationX: CGFloat, maxAttempts: Int = 5) -> Bool {
        guard let pid = ownerPID(windowID: windowID) else { return false }

        for attempt in 1...max(1, maxAttempts) {
            guard let frame = currentFrame(windowID: windowID) else { return false }
            guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

            let startPoint = CGPoint(x: frame.midX, y: frame.midY)
            let destinationPoint = CGPoint(x: destinationX, y: frame.midY)

            guard
                let mouseDown = menuBarItemEvent(type: .leftMouseDown, at: startPoint, windowID: windowID, pid: pid, source: source, flags: .maskCommand),
                let mouseDragged = menuBarItemEvent(type: .leftMouseDragged, at: destinationPoint, windowID: windowID, pid: pid, source: source, flags: .maskCommand),
                let mouseUp = menuBarItemEvent(type: .leftMouseUp, at: destinationPoint, windowID: windowID, pid: pid, source: source, flags: [])
            else {
                continue // event-creation failure this attempt -> retry, per Ice's EventError discipline
            }

            mouseDown.postToPid(pid)
            usleep(20_000)
            mouseDragged.postToPid(pid)
            usleep(20_000)
            mouseUp.postToPid(pid)
            usleep(150_000) // let the window server settle before re-reading the frame

            if let newFrame = currentFrame(windowID: windowID), newFrame.origin != frame.origin {
                return true
            }

            if attempt < maxAttempts {
                wakeUpItem(windowID: windowID, pid: pid, at: startPoint, source: source)
            }
        }
        return false
    }

    private static func ownerPID(windowID: CGWindowID) -> pid_t? {
        guard let infoList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: AnyObject]],
              let info = infoList.first,
              let pidValue = info[kCGWindowOwnerPID as String] as? Int
        else { return nil }
        return pid_t(pidValue)
    }

    /// Ice's `wakeUpItem()`: an unmodified mouse-down/mouse-up pair at the item's current
    /// midpoint, used to nudge an unresponsive item before the next move attempt.
    private static func wakeUpItem(windowID: CGWindowID, pid: pid_t, at point: CGPoint, source: CGEventSource) {
        guard
            let mouseDown = menuBarItemEvent(type: .leftMouseDown, at: point, windowID: windowID, pid: pid, source: source, flags: .maskCommand),
            let mouseUp = menuBarItemEvent(type: .leftMouseUp, at: point, windowID: windowID, pid: pid, source: source, flags: [])
        else { return }
        mouseDown.postToPid(pid)
        usleep(20_000)
        mouseUp.postToPid(pid)
    }

    /// Builds a synthetic mouse event routed directly at one menu-bar-item window, mirroring
    /// Ice's `CGEvent.menuBarItemEvent(type:location:item:pid:source:)` field-stamping shape
    /// (read directly from `MenuBarItemManager.swift`).
    private static func menuBarItemEvent(
        type: CGEventType,
        at point: CGPoint,
        windowID: CGWindowID,
        pid: pid_t,
        source: CGEventSource,
        flags: CGEventFlags
    ) -> CGEvent? {
        let button: CGMouseButton = .left
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        else { return nil }
        event.flags = flags
        let windowIDField = Int64(windowID)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowIDField)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowIDField)
        // Raw field 0x33 = the event's window-identifier field (Ice's own
        // `CGEventField.windowID` extension, MenuBarItemManager.swift:1552).
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: windowIDField)
        return event
    }
}
