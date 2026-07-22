import Foundation
import CoreLocation
import EventKit
import CoreBluetooth
import Intents
import IOKit.hid

// Phase 54 / ARCH-P2 — the pure permission-status seam Plan 03's SettingsView consumes.
// Mirrors this codebase's established "pure seam + thin framework glue" split
// (OnboardingFlow.swift's nextOnboardingStep(...)/shouldShowOnboarding(...),
// IslandResolver.resolve(...)): the RESOLUTION logic (raw framework enum -> 3-state,
// worst-of-two combine) is factored into small, total, unit-tested pure functions,
// kept separate from the thin live-read glue that actually calls into each framework.

// D-04 (locked): exactly this 3-state model, never collapsed to a binary granted/not-granted.
enum PermissionStatus: Equatable {
    case granted, denied, notYetAsked
}

// D-01/D-02 (locked): exactly these 5 kinds. Automation/Apple Events is deliberately never
// a case here -- it backs the paused Favorite/Like feature (Phase 49/50) and is explicitly
// excluded from this rollup.
enum PermissionKind: String, CaseIterable {
    case location, calendarReminders, bluetooth, focus, inputMonitoring

    /// System Settings > Privacy & Security deep-link anchor (x-apple.systempreferences:
    /// com.apple.preference.security?<anchor>), reusing the exact scheme/prefix already
    /// proven working in this app for Accessibility (SettingsView.swift).
    ///
    /// MEDIUM-confidence (community-sourced, not yet on-device-verified on this macOS
    /// version -- RESEARCH.md Assumptions A1/A2) -- must be spot-checked during Plan 03's
    /// on-device UAT.
    var deepLinkAnchor: String {
        switch self {
        case .location: return "Privacy_LocationServices"
        // D-13: the combined row always routes to the general Calendar pane, never picks
        // one of the two sub-permissions.
        case .calendarReminders: return "Privacy_Calendars"
        case .bluetooth: return "Privacy_Bluetooth"
        case .focus: return "Privacy_Focus"
        case .inputMonitoring: return "Privacy_ListenEvent"
        }
    }
}

// MARK: - Pure mapping functions

func mapCLAuthorization(_ status: CLAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .authorizedAlways, .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

// Pitfall 5 (RESEARCH.md): .fullAccess/.writeOnly both count as granted -- this plan's
// explicit discretion call (Open Question 2): write-only access still counts as granted,
// never treated as denied.
func mapEKAuthorization(_ status: EKAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .fullAccess, .writeOnly, .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

func mapCBManagerAuthorization(_ status: CBManagerAuthorization) -> PermissionStatus {
    switch status {
    case .allowedAlways: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

func mapINFocusAuthorization(_ status: INFocusStatusAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

// D-13 (locked): worst-of-two -- denied beats notYetAsked beats granted.
func combinedCalendarReminderStatus(event: PermissionStatus, reminder: PermissionStatus) -> PermissionStatus {
    if event == .denied || reminder == .denied { return .denied }
    if event == .notYetAsked || reminder == .notYetAsked { return .notYetAsked }
    return .granted
}

// MARK: - Live status-read functions (thin framework glue, one-line calls into the
// pure mappers above -- no new monitor classes, mirrors this codebase's "pure seam +
// thin framework glue" split).

func locationPermissionStatus() -> PermissionStatus {
    mapCLAuthorization(CLLocationManager().authorizationStatus)
}

// Mirrors the confirmed-working read at NotchWindowController.swift:1896
// (CBManager.authorization == .allowedAlways). Do NOT add a status property to
// BluetoothMonitor -- this is a static framework-level read, independent of any
// BluetoothMonitor instance.
func bluetoothPermissionStatus() -> PermissionStatus {
    mapCBManagerAuthorization(CBManager.authorization)
}

func focusPermissionStatus() -> PermissionStatus {
    mapINFocusAuthorization(INFocusStatusCenter.default.authorizationStatus)
}

func calendarEventPermissionStatus() -> PermissionStatus {
    mapEKAuthorization(EKEventStore.authorizationStatus(for: .event))
}

func reminderPermissionStatus() -> PermissionStatus {
    mapEKAuthorization(EKEventStore.authorizationStatus(for: .reminder))
}

/// Best-effort Input Monitoring status (D-03/Pitfall 4): no official "request access" API
/// exists for Input Monitoring on macOS. `OSDInterceptor`'s unconditional launch-time
/// `.cghidEventTap` (not `DropInterceptTap`'s `.cgSessionEventTap`, which gates on
/// Accessibility instead) is what actually triggers this TCC prompt in this app, so by the
/// time a user opens Settings, this read is very likely already resolved to
/// granted/denied -- a residual `.notYetAsked`/`.kIOHIDAccessTypeUnknown` read has no
/// reliable in-app trigger. Plan 03's UI must NOT construct a new `CGEventTap` to nudge it.
func inputMonitoringPermissionStatus() -> PermissionStatus {
    switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
    case kIOHIDAccessTypeGranted: return .granted
    case kIOHIDAccessTypeDenied: return .denied
    default: return .notYetAsked
    }
}
