import CoreLocation

// Phase 14 / WEATHER-01 — the one-shot device-location wrapper (D-01).
//
// Mirrors BluetoothMonitor/NowPlayingMonitor's thin-glue discipline: a THIN
// CLLocationManagerDelegate wrapper with NO persistent tracking (no continuous
// updates, no significant-location-change monitoring — RESEARCH.md's Don't
// Hand-Roll table). D-01: any non-authorized status or any failure settles the
// completion with nil exactly once, with NO retry loop and NO re-prompt/nag.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    /// Request the device's current location once.
    /// - Note: `completion` settles exactly once, with `nil` on any denial/restriction/failure
    ///   (D-01) — never retried automatically.
    func requestOnce(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        manager.delegate = self
        switch manager.authorizationStatus {
        case .notDetermined:
            // The delegate callback below drives the actual location request once the
            // user responds to this prompt.
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        default:
            // D-01: denied/restricted — settle immediately, no retry, no begging dialog.
            completion(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        case .denied, .restricted:
            self.completion?(nil)
            self.completion = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.last)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // D-01: any failure is silent omission, never surfaced.
        completion?(nil)
        completion = nil
    }
}
