#if DEBUG
import AppKit

// Phase 65 Plan 08 — throwaway on-device iteration aid, mirrors NowPlayingMonitor.swift's
// spikeLikeCurrentTrack/spikeTriggerAutomationPrompt convention (NSLog-marked, Debug-only,
// never compiled into Release). One static function per QuickActionsBarCatalog.Action, each
// calling straight into the real Plan 65-02/65-03/65-04 helper — no UI hookup, trigger
// individually from a debugger/breakpoint or a temporary call site during the Task 2 on-device
// pass.
// @MainActor to match FocusToggleAction.toggle's own isolation (it calls FocusModeMonitor.isAuthorized,
// itself @MainActor) — this file is only ever invoked from the UI's main-actor context anyway.
@MainActor
enum QuickActionsBarManualSpike {
    static func spikeMicMute() {
        NSLog("SPIKE micMute result=\(String(describing: toggleSystemInputMute()))")
    }

    static func spikeDisplaySleep() {
        NSLog("SPIKE displaySleep sleepNow()")
        DisplaySleepAction.sleepNow()
    }

    static func spikeDarkMode() {
        NSLog("SPIKE darkMode toggle()")
        DarkModeToggleAction.toggle { NSLog("SPIKE darkMode result=\($0)") }
    }

    static func spikeScreenLock() {
        NSLog("SPIKE screenLock lockNow()")
        ScreenLockAction.lockNow()
    }

    static func spikeFocusToggle() {
        NSLog("SPIKE focus toggle()")
        FocusToggleAction.toggle { NSLog("SPIKE focus result=\($0)") }
    }

    static func spikeCaffeinate() {
        NSLog("SPIKE caffeinate toggle()")
        CaffeinateToggleAction.toggle()
        NSLog("SPIKE caffeinate isActive=\(CaffeinateToggleAction.isActive)")
    }

    static func spikeEmptyTrash() {
        NSLog("SPIKE emptyTrash empty()")
        EmptyTrashAction.empty { NSLog("SPIKE emptyTrash result=\($0)") }
    }

    static func spikeLaunch() {
        NSLog("SPIKE launch target=https://apple.com")
        LaunchAction.launch(target: "https://apple.com")
    }
}
#endif
