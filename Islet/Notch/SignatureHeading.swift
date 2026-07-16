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
//
// Standalone, non-animated view AT THIS STAGE: every glyph renders solid-filled orange
// immediately — this is the contract Plan 36-04 animates via .trim(from:to:) on the same
// Canvas closure, not the final on-screen behavior yet. Not yet wired into
// onboardingWelcomeStep (Plan 36-04's job).
struct SignatureHeading: View {
    private let text: String = "Meet Islet"   // D-09, locked
    private let fontSize: CGFloat = 28         // 36-UI-SPEC.md Signature Animation Contract

    var body: some View {
        let font = Self.loadSignatureFont(size: fontSize)
        let glyphs = Self.glyphPaths(for: text, font: font)
        let width = Self.totalWidth(for: glyphs)
        let height = fontSize * 3   // matches the reference's own `height = fontSize * 3` headroom

        Canvas { context, _ in
            // D-11, locked: fixed literal orange, never nowPlayingAccent/chargingAccent/deviceAccent —
            // must read the same regardless of the user's chosen Settings accent color.
            for (path, _) in glyphs {
                context.fill(path, with: .color(Color.orange))
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Glyph extraction

    /// Extracts a real vector glyph outline (Path) + advance width for every character of
    /// `text`, positioned left-to-right by the font's own advance widths. Every character gets
    /// a slot, including spaces (D-10) — a space's Path is legitimately empty.
    ///
    /// `internal` (not `private`), mirroring `EqualizerBars.makeProfiles()`'s own testability
    /// precedent: this lets `SignatureHeadingTests.swift` call it directly under `@testable import`.
    static func glyphPaths(for text: String, font: CTFont) -> [(path: Path, advance: CGFloat)] {
        let uniChars: [UniChar] = Array(text.utf16)
        guard !uniChars.isEmpty else { return [] }

        var glyphs = [CGGlyph](repeating: 0, count: uniChars.count)
        // CTFontGetGlyphsForCharacters returns false for characters with no direct glyph
        // mapping (e.g. some composed sequences) but still fills `glyphs` with the best
        // available mapping (0 for genuinely missing glyphs) — safe to proceed either way.
        _ = CTFontGetGlyphsForCharacters(font, uniChars, &glyphs, uniChars.count)

        // Core Text's glyph space is Y-UP (baseline at 0, ascender positive); SwiftUI's
        // Canvas/Path space is Y-DOWN. Flipping vertically and shifting by the font's ascent
        // is what makes the extracted outlines render right-side-up instead of upside-down
        // and off the top of the frame — this is the single load-bearing gotcha in this
        // function; get the sign wrong and every glyph renders inverted.
        let ascent = CTFontGetAscent(font)
        let flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -ascent)

        var runningX: CGFloat = 0
        var result: [(path: Path, advance: CGFloat)] = []
        result.reserveCapacity(glyphs.count)

        for glyph in glyphs {
            var advance = CGSize.zero
            var g = glyph
            CTFontGetAdvancesForGlyphs(font, .horizontal, &g, &advance, 1)

            var transform = CGAffineTransform(translationX: runningX, y: 0).concatenating(flip)
            let cgPath = CTFontCreatePathForGlyph(font, glyph, &transform)
            let path = cgPath.map { Path($0) } ?? Path()

            result.append((path: path, advance: advance.width))
            runningX += advance.width
        }

        return result
    }

    /// Sums each glyph's advance to get the real content width (mirrors the reference's
    /// running `width` accumulator) — used to size the view to its actual content instead of
    /// a fixed guess.
    static func totalWidth(for paths: [(path: Path, advance: CGFloat)]) -> CGFloat {
        paths.reduce(0) { $0 + $1.advance }
    }

    // MARK: - Font loading

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
