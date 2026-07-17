import CoreGraphics
import CoreFoundation

// Phase 39 Plan 03 / HUD-04 — thin DisplayServices glue, isolated per "one fragile system
// surface, one file" convention (mirrors NowPlayingMonitor/PowerSourceMonitor/FocusModeMonitor).
// DisplayServices.framework is a private, unversioned system framework — the only confirmed-
// working brightness-read path on Apple Silicon internal displays (CoreDisplay's public-facing
// calls are confirmed broken there).
final class BrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    // Phase 39 Plan 08 / D-15 — self-drive write path symbols, resolved from the SAME
    // already-loaded bundle handle as GetBrightnessFn, never a second dlopen.
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeBrightnessFn = @convention(c) (CGDirectDisplayID) -> Bool
    private var getBrightness: GetBrightnessFn?
    private var setBrightness: SetBrightnessFn?
    private var canChangeBrightness: CanChangeBrightnessFn?

    // Phase 39 Plan 08 / D-15 — matches VolumeReader's step granularity (1/16 = 6.25%).
    private let brightnessStep: Float = 1.0 / 16.0

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle)
        else { return }   // every function pointer stays nil — every read/write degrades safely

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString) {
            getBrightness = unsafeBitCast(ptr, to: GetBrightnessFn.self)
        }
        // Each symbol below resolves (or fails to resolve) independently of the read symbol
        // above — a missing Set/CanChange pair only disables self-driving, reading still works.
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesSetBrightness" as CFString) {
            setBrightness = unsafeBitCast(ptr, to: SetBrightnessFn.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesCanChangeBrightness" as CFString) {
            canChangeBrightness = unsafeBitCast(ptr, to: CanChangeBrightnessFn.self)
        }
    }

    // Security Domain: a failed private-framework symbol load/call must suppress the Brightness
    // HUD entirely, never render a fabricated 0% — Int?, not a defaulted Int, is the deliberate
    // divergence from PowerReading's all-fields-defaulted convention.
    func readBrightness() -> Int? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        guard getBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
        return Int((value * 100).rounded())
    }

    // Phase 39 Plan 08 / D-15 — self-drive write path: the OSDInterceptor swallows the physical
    // key press, so Islet itself must apply the real system brightness change. Security Domain:
    // never attempt to drive a display (e.g. most external displays) that reports it cannot be
    // changed this way.
    func adjustBrightness(increase: Bool) -> Int? {
        guard let setBrightness, let canChangeBrightness else { return nil }
        guard canChangeBrightness(CGMainDisplayID()) else { return nil }
        guard let current = readBrightness() else { return nil }

        var target = Float(current) / 100 + (increase ? brightnessStep : -brightnessStep)
        target = max(0, min(1, target))
        target = (target * 16).rounded() / 16

        guard setBrightness(CGMainDisplayID(), target) == 0 else { return nil }
        return Int((target * 100).rounded())
    }
}
