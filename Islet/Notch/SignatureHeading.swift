import SwiftUI
import CoreText

// ONBOARD-04 — the onboarding Welcome step's "Meet Islet" heading. Originally planned (Plan
// 36-04, D-09/D-10) as a per-glyph stroke-reveal animation; after repeated font-licensing and
// stroke-weight tuning friction across several rounds, the user pivoted this to a much simpler,
// fully static design: each word rendered in a script font with its own rainbow gradient sweep,
// mirroring Droppy's own "meet droppy" onboarding heading. See 36-CONTEXT.md's post-36-04 note
// for the full rationale. No animation, no per-frame clock, no TimelineView.
//
// D-12 (font license, still applies): the componentry.fun reference's `LastoriaBoldRegular.otf`
// is a personal-use-only demo font — not safe to ship in a paid product. Dancing Script Bold
// (SIL Open Font License 1.1, Google Fonts, Impallari Type) is the locked substitute — confirmed
// OFL, explicitly permits commercial embedding. Reused as-is from Plan 36-03's font bundling.
struct SignatureHeading: View {
    private let fontSize: CGFloat = 28

    var body: some View {
        let font = Font(Self.loadSignatureFont(size: fontSize))

        HStack(spacing: 8) {
            Text("Meet")
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("Islet")
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow, .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
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
