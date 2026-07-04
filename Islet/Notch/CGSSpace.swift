import AppKit

// FS-01 (Phase 9, Candidate C, D-01/D-02 amendment) — a dedicated, max-level private CGS
// (CoreGraphics Services) Space the notch panel joins.
//
// WHY THIS EXISTS: `.canJoinAllSpaces` (NotchPanel.swift's collectionBehavior, UNCHANGED by
// this file) requires WindowServer to dynamically re-parent the panel onto whichever Space
// just became active, AT THE MOMENT of the Space transition — that re-parenting operation is
// what races our reactive fullscreen-hide call and produces the flash (Phase 2/6/8 root-cause
// chain). A dedicated Space pinned at the maximum absolute level is instead ALWAYS composited,
// regardless of which real user Space is active; its membership is set ONCE and never needs to
// change on a Space switch, removing the per-transition race entirely.
//
// THIS IS AN ADDITIVE LAYER, NOT A REPLACEMENT: NotchPanel.collectionBehavior stays exactly as
// it is today (`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`) — this CGSSpace
// membership is added ALONGSIDE it. No known shipping reference project removes
// `.canJoinAllSpaces` while relying on CGSSpace membership alone; that combination is
// deliberately deferred to a separate, later-only follow-up (09-02), never combined with this
// attempt (09-RESEARCH.md Summary finding #2 / Anti-Patterns).
//
// THE 7-SYMBOL CEILING (D-02 amendment): this file binds exactly 7 named CGS Space functions
// (CGSSpaceCreate, CGSSpaceDestroy, CGSSpaceSetAbsoluteLevel, CGSAddWindowsToSpaces,
// CGSRemoveWindowsFromSpaces, CGSHideSpaces, CGSShowSpaces) plus the self-contained
// `_CGSDefaultConnection` connection lookup — the exact set verified against two independent
// shipping implementations (Ebullioscopic/Atoll, TheBoredTeam/boring.notch). This is the D-02
// amendment's explicit stop line: no further private mechanism may be added here without
// re-triggering the original D-02 stop signal (fall back to Candidate B or escalate).
//
// Mirrors FullscreenSpaceProbe.swift's silgen-name-bound symbol convention (no dlopen, resolved
// at link time against the OS's existing dyld shared cache) and its fail-safe design
// philosophy, though this wrapper has no fail-safe branch of its own — it is a thin mechanism,
// not a decision predicate.

final class CGSSpace {
    private let identifier: CGSSpaceID
    private let createdByInit: Bool

    var windows: Set<NSWindow> = [] {
        didSet {
            let remove = oldValue.subtracting(self.windows)
            let add = self.windows.subtracting(oldValue)
            CGSRemoveWindowsFromSpaces(_CGSDefaultConnection(),
                                       remove.map { $0.windowNumber } as NSArray,
                                       [self.identifier])
            CGSAddWindowsToSpaces(_CGSDefaultConnection(),
                                  add.map { $0.windowNumber } as NSArray,
                                  [self.identifier])
        }
    }

    /// Initialized `CGSSpace`s *MUST* be de-initialized upon app exit!
    init(level: Int = 0) {
        let flag = 0x1 // this value MUST be 1, otherwise Finder decides to draw desktop icons
        self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), self.identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
        self.createdByInit = true
    }

    deinit {
        CGSHideSpaces(_CGSDefaultConnection(), [self.identifier])
        if createdByInit { CGSSpaceDestroy(_CGSDefaultConnection(), self.identifier) }
    }
}

// CGS private symbol bindings — silgen-name-bound, no dlopen (mirrors FullscreenSpaceProbe.swift's
// existing convention). Per Pitfall 2: this file's connection-ID binding is DELIBERATELY
// self-contained (UInt) — do NOT reuse FullscreenSpaceProbe.swift's `CGSMainConnectionID() -> Int32`.
fileprivate typealias CGSConnectionID = UInt      // NOTE: UInt, not Int32 — ABI differs from CGSMainConnectionID
fileprivate typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
fileprivate func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
fileprivate func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
fileprivate func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
fileprivate func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSRemoveWindowsFromSpaces")
fileprivate func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
fileprivate func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
fileprivate func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
