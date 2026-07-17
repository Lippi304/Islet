import CoreGraphics
import CoreFoundation

// Phase 39 Plan 03 / HUD-04 — thin DisplayServices glue, isolated per "one fragile system
// surface, one file" convention (mirrors NowPlayingMonitor/PowerSourceMonitor/FocusModeMonitor).
// DisplayServices.framework is a private, unversioned system framework — the only confirmed-
// working brightness-read path on Apple Silicon internal displays (CoreDisplay's public-facing
// calls are confirmed broken there).
final class BrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightnessFn?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString)
        else { return }   // getBrightness stays nil — every read degrades to nil, never a false 0%
        getBrightness = unsafeBitCast(ptr, to: GetBrightnessFn.self)
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
}
