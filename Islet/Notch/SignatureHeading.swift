import SwiftUI
import CoreText

// ONBOARD-04 — the hand-drawn signature stroke-reveal contract for the onboarding Welcome
// step's "Meet Islet" heading. Plan 36-03 built the font bundling + Core Text glyph-outline
// extraction contract; this plan (36-04) layers the staggered stroke-then-fill reveal
// animation on top and (separately, in NotchPillView.swift) wires it into onboarding.
//
// D-12 (font license): the componentry.fun reference's `LastoriaBoldRegular.otf` is a
// personal-use-only demo font — not safe to ship in a paid product. Dancing Script Bold
// (SIL Open Font License 1.1, Google Fonts, Impallari Type) is the locked substitute —
// confirmed OFL, explicitly permits commercial embedding.
struct SignatureHeading: View {
    private let text: String = "Meet Islet"   // D-09, locked
    private let fontSize: CGFloat = 28         // 36-UI-SPEC.md Signature Animation Contract

    // D-10: per-view-instance reveal state. `appearedAt` gates the clock (nil == not yet
    // appeared, so TimelineView stays paused); `isRevealComplete` is the real @State flip
    // that stops the clock once the ~3.3s reveal finishes — a rare Back-then-forward
    // re-visit creating a fresh `SignatureHeading` instance replaying the animation is
    // harmless (D-10), so no additional "already played" persistence is needed.
    @State private var appearedAt: Date?
    @State private var isRevealComplete = false

    var body: some View {
        let font = Self.loadSignatureFont(size: fontSize)
        let glyphs = Self.glyphPaths(for: text, font: font)
        let width = Self.totalWidth(for: glyphs)
        let height = fontSize * 3   // matches the reference's own `height = fontSize * 3` headroom

        // Per-character stagger (D-10, 36-UI-SPEC.md): 0.2s delay per index, 1.5s reveal
        // duration each — total clock length is the last character's delay + its own duration.
        let totalDuration = 0.2 * Double(glyphs.count - 1) + 1.5

        TimelineView(.animation(paused: appearedAt == nil || isRevealComplete)) { context in
            Canvas { canvasContext, _ in
                // Mirrors ProgressBar's Unix-epoch (timeIntervalSince1970) clock convention in
                // this same codebase — NOT EqualizerBars' unrelated 2001-epoch
                // timeIntervalSinceReferenceDate sine clock. Do not mix the two.
                let elapsed = appearedAt.map { context.date.timeIntervalSince1970 - $0.timeIntervalSince1970 } ?? 0

                if elapsed > totalDuration && !isRevealComplete {
                    // Deferred to the next run-loop tick: mutating @State synchronously inside
                    // a TimelineView content closure during its own view-update pass would be a
                    // "modifying state during view update" violation. This is the real @State
                    // flip that stops the clock going forward (T-36-07) — not a one-shot
                    // wall-clock comparison, which would freeze `paused:` at whatever it was
                    // when body was first constructed and never re-evaluate.
                    DispatchQueue.main.async {
                        isRevealComplete = true
                    }
                }

                for (index, glyph) in glyphs.enumerated() {
                    let delay = 0.2 * Double(index)
                    let raw = min(max((elapsed - delay) / 1.5, 0), 1)

                    if raw >= 1 {
                        // D-11, locked: fixed literal orange, never nowPlayingAccent/
                        // chargingAccent/deviceAccent — reads the same regardless of the
                        // user's chosen Settings accent color.
                        canvasContext.fill(glyph.path, with: .color(Color.orange))
                    } else if raw > 0 {
                        // Smoothstep — the concrete ease-in-out substitute for D-10's
                        // `Animation.easeInOut` curve, evaluated against elapsed time rather
                        // than driven by a SwiftUI `Animation` (TimelineView's own tick is the
                        // clock here).
                        let eased = raw * raw * (3 - 2 * raw)
                        let trimmed = glyph.path.trim(from: 0, to: eased).path(in: .zero)
                        canvasContext.stroke(
                            trimmed,
                            with: .color(Color.orange),
                            style: StrokeStyle(lineWidth: 6.16, lineCap: .round, lineJoin: .round)
                        )
                    }
                    // raw <= 0: nothing drawn yet for this glyph.
                }
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            if appearedAt == nil {
                appearedAt = Date()
            }
        }
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
