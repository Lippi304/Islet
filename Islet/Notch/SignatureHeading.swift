import SwiftUI
import CoreText

// ONBOARD-04 — the hand-drawn signature stroke-reveal contract for the onboarding Welcome
// step's "Meet Islet" heading. This file is the Plan 36-03 half of the feature: bundling a
// commercially-safe (OFL) script font, registering it at runtime, and (Task 2) extracting a
// real vector glyph outline (Path) per character via Core Text. Plan 36-04 layers the actual
// .trim(from:to:) stroke-reveal animation on top — no animation exists yet at this stage.
//
// D-12 (font license): the componentry.fun reference's `LastoriaBoldRegular.otf` is a
// personal-use-only demo font — not safe to ship in a paid product. Dancing Script Bold
// (SIL Open Font License 1.1, Google Fonts, Impallari Type) is the locked substitute —
// confirmed OFL, explicitly permits commercial embedding.
enum SignatureHeading {

    // OpenType's standard `wght` variation axis, as the four ASCII bytes `w`,`g`,`h`,`t` read
    // as one big-endian UInt32 — Apple's documented kCTFontVariationAttribute dictionary key
    // convention (2003265652 == 0x77676874 == "wght").
    private static let wghtAxisTag: UInt32 = 2003265652

    // Registers the bundled font exactly once per process. Swift's standard "run exactly
    // once" idiom: a file-scoped `static let` initializer runs lazily on first access and
    // is guaranteed by the runtime to execute only once even under concurrent access.
    private static let registrationOnce: Void = {
        guard let url = Bundle.main.url(forResource: "DancingScript-Variable", withExtension: "ttf") else {
            return
        }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // An "already registered" error on a second call within the same process is expected
        // and harmless (shouldn't happen given the once-guard, but never crash on it either).
    }()

    /// Builds a Bold (wght=700, per D-12) CTFont instance of the bundled Dancing Script font
    /// at `size`. `internal` (not `private`) so `SignatureHeadingTests.swift` can build the
    /// same font the view uses, mirroring `EqualizerBars.makeProfiles()`'s own testability
    /// precedent.
    static func loadSignatureFont(size: CGFloat) -> CTFont {
        _ = registrationOnce

        let variationDict: [NSNumber: Double] = [NSNumber(value: wghtAxisTag): 700.0]
        let attributes: [String: Any] = [
            kCTFontVariationAttribute as String: variationDict,
            kCTFontNameAttribute as String: "Dancing Script" as CFString,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)

        // Defensive fallback: if the descriptor somehow resolved to the wrong family (e.g.
        // registration failed), fall back to the font's default (400) instance rather than
        // crashing — still the correct family, just not bold.
        let resolvedFamily = CTFontCopyName(font, kCTFontFamilyNameKey) as String?
        if resolvedFamily != "Dancing Script" {
            return CTFontCreateWithName("Dancing Script" as CFString, size, nil)
        }
        return font
    }
}
