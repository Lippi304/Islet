import ImageIO
import UniformTypeIdentifiers

// Phase 70 / D-02, D-05 — the isolated ImageIO seam for the File Tray Convert button.
// Mirrors QuickActionSharingService.swift's "isolate the fragile thing" convention, but
// WITHOUT its protocol/delegate/timeout machinery: conversion is synchronous, local, and
// involves zero OS UI, so it doesn't need a fake-injection seam (70-RESEARCH.md Pattern 1)
// — it's tested directly against real fixture images, mirroring ShelfFileStoreTests.swift's
// own precedent of exercising real FileManager I/O rather than mocking it.
enum ImageFormat: CaseIterable {
    case jpg, png, heic, tiff

    var utType: UTType {
        switch self {
        case .jpg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }

    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }

    // UI-SPEC.md Copywriting Contract — exact strings.
    var label: String {
        switch self {
        case .jpg: return "JPG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        }
    }
}

enum ImageConversionError: Error {
    case sourceUnreadable
    case destinationCreationFailed
    case writeFailed
}

enum ImageConversionService {
    // Reads sourceURL, writes a NEW file at destinationURL in the target format — a real
    // ImageIO re-encode, not a byte copy with a lied-about extension (70-RESEARCH.md
    // Pitfall 2). AddImageFromSource (not AddImage) copies the image + its metadata directly
    // from the source, avoiding a separate decode-to-CGImage round trip.
    // T-70-01 (mitigate): both ImageIO calls are guarded against nil, never force-unwrapped —
    // a malformed/corrupt source throws a typed error instead of crashing.
    static func convert(_ sourceURL: URL, to format: ImageFormat, destinationURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ImageConversionError.sourceUnreadable
        }
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, format.utType.identifier as CFString, 1, nil
        ) else {
            throw ImageConversionError.destinationCreationFailed
        }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageConversionError.writeFailed
        }
    }

    // D-05's detection foundation — classifies by the file's actual declared UTType, not by
    // filename extension (70-RESEARCH.md Pattern 2). `false` on any failure to read.
    //
    // Rule 1 fix (live-tested during Task 1): the LaunchServices-backed `resourceValues`
    // lookup alone reports a generic "public.data" type for an extensionless file, even when
    // its actual on-disk bytes are a valid image (verified: `swift` REPL check against a real
    // extensionless PNG fixture) — it resolves type from the filename/extension database, not
    // from sniffing content. Falls back to ImageIO's own header-byte sniff
    // (`CGImageSourceGetType`, which DOES read magic bytes regardless of extension) so a
    // renamed/extensionless image is still correctly detected — this is what D-05 actually
    // asks for ("not by filename extension").
    static func isImageFile(_ url: URL) -> Bool {
        if let declaredType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           declaredType.conforms(to: .image) {
            return true
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sniffedIdentifier = CGImageSourceGetType(source) else {
            return false
        }
        return UTType(sniffedIdentifier as String)?.conforms(to: .image) ?? false
    }
}
