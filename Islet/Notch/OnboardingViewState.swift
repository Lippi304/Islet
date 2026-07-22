import Foundation

// Phase 26 / ONBOARD-02 / D-02/D-03 — the @Published carrier for the Permissions step's
// per-row granted/not-granted display state. Mirrors IslandPresentationState exactly: a
// plain published holder, no methods, no timers, no system frameworks. The controller
// (Plan 26-04) is the SINGLE writer -- it calls the real permission-request functions
// (LocationProvider.requestOnce, CalendarService/refreshCalendar, BluetoothMonitor.start)
// and writes the outcome here; NotchPillView's onboardingCarousel(_:) only RENDERS
// whatever is published, never decides permission logic itself.
//
// D-03 (quiet degrade): `nil` means "not yet attempted this session" (no Grant tap yet);
// `false` means the last grant attempt was denied/failed. The view intentionally does NOT
// distinguish between the two -- both render the same neutral grey "Not granted" state,
// never an error icon or dialog. Only `true` (an actual granted outcome) gets the distinct
// green "Granted" treatment.
final class OnboardingViewState: ObservableObject {
    @Published var bluetoothGranted: Bool?
    @Published var calendarGranted: Bool?
    @Published var locationGranted: Bool?

    // Phase 54 / D-07/D-08/D-12 — true only while a mid-session onboarding REPLAY (triggered
    // from Settings) is active, never during real first-launch onboarding. NotchPillView reads
    // this to conditionally show the replay-only close button.
    @Published var isReplay: Bool = false
}
