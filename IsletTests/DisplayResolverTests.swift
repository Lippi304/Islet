import XCTest
import CoreGraphics
@testable import Islet

// ISL-06: pure display selection. selectTargetScreen must return the single
// built-in notched display — or nil (clamshell / external-only / non-notch Mac).
// Crucially it selects by PROPERTY (isBuiltin && hasNotch), never by array index
// or frame size, so plug/unplug reordering can't land on the wrong display
// (Pitfall 2). Fixtures are hand-built ScreenDescriptors — no live NSScreen.
final class DisplayResolverTests: XCTestCase {

    // MARK: Fixtures

    private func builtinNotched(uuid: String = "builtin",
                                origin: CGPoint = .zero,
                                size: CGSize = CGSize(width: 1512, height: 982)) -> ScreenDescriptor {
        ScreenDescriptor(uuid: uuid,
                         frame: CGRect(origin: origin, size: size),
                         safeAreaTop: 38,
                         auxLeftWidth: 612,
                         auxRightWidth: 612,
                         isBuiltin: true)
    }

    private func externalNoNotch(uuid: String = "external",
                                 origin: CGPoint = .zero,
                                 size: CGSize = CGSize(width: 2560, height: 1440)) -> ScreenDescriptor {
        ScreenDescriptor(uuid: uuid,
                         frame: CGRect(origin: origin, size: size),
                         safeAreaTop: 0,
                         auxLeftWidth: nil,
                         auxRightWidth: nil,
                         isBuiltin: false)
    }

    // MARK: Tests

    func testPicksBuiltinNotchedAmongMixedScreens() {
        let screens = [externalNoNotch(), builtinNotched()]
        XCTAssertEqual(selectTargetScreen(from: screens), builtinNotched())
    }

    func testBuiltinOnlyReturnsIt() {
        let screens = [builtinNotched()]
        XCTAssertEqual(selectTargetScreen(from: screens), builtinNotched())
    }

    func testClamshellOrExternalOnlyReturnsNil() {
        let screens = [externalNoNotch()]
        XCTAssertNil(selectTargetScreen(from: screens))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(selectTargetScreen(from: []))
    }

    func testNonNotchBuiltinReturnsNil() {
        // Built-in display WITHOUT a notch (older Mac) → out of scope for v1, must hide.
        let nonNotchBuiltin = ScreenDescriptor(uuid: "old-builtin",
                                               frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                               safeAreaTop: 0,
                                               auxLeftWidth: nil,
                                               auxRightWidth: nil,
                                               isBuiltin: true)
        XCTAssertNil(selectTargetScreen(from: [nonNotchBuiltin]))
    }

    func testNeverPicksExternalEvenWhenListedFirstAndLarger() {
        // Pitfall 2 guard: a big external listed FIRST must not win by position/size.
        let bigExternal = externalNoNotch(uuid: "big-external",
                                          origin: .zero,
                                          size: CGSize(width: 3840, height: 2160))
        let builtin = builtinNotched(uuid: "builtin", origin: CGPoint(x: 3840, y: 0))
        let result = selectTargetScreen(from: [bigExternal, builtin])
        XCTAssertEqual(result?.uuid, "builtin")
    }

    func testRequiresBothBuiltinAndNotch() {
        // An external that somehow reports a notch but isBuiltin == false must be
        // rejected; selection needs BOTH isBuiltin AND a notch.
        let externalWithNotch = ScreenDescriptor(uuid: "weird-external",
                                                 frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                 safeAreaTop: 38,
                                                 auxLeftWidth: 612,
                                                 auxRightWidth: 612,
                                                 isBuiltin: false)
        let builtin = builtinNotched(uuid: "builtin", origin: CGPoint(x: 1512, y: 0))
        let result = selectTargetScreen(from: [externalWithNotch, builtin])
        XCTAssertEqual(result?.uuid, "builtin")
    }
}
