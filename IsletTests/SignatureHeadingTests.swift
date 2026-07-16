import XCTest
import CoreText
@testable import Islet

// ONBOARD-04 — SignatureHeading is now a static rainbow-gradient heading (no animation, no
// glyph-path extraction); see 36-CONTEXT.md's post-36-04 pivot note. This sanity-checks the one
// piece of non-trivial logic left: loadSignatureFont(size:) actually resolves to the bundled
// Dancing Script Bold instance rather than silently falling back to some other family/weight.
final class SignatureHeadingTests: XCTestCase {

    func testLoadSignatureFontResolvesToDancingScriptFamily() {
        let font = SignatureHeading.loadSignatureFont(size: 28)
        let family = CTFontCopyName(font, kCTFontFamilyNameKey) as String?
        XCTAssertEqual(family, "Dancing Script", "loadSignatureFont(size:) must resolve to the bundled Dancing Script family.")
    }
}
