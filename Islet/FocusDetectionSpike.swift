#if DEBUG
import Foundation
import Intents

// Phase 38 / Plan 01 — THROWAWAY go/no-go spike (ROADMAP Success Criterion #1, D-12).
//
// Confirms, on THIS dev machine, which Focus/DND detection path (if either) is viable
// before any real FocusModeMonitor implementation proceeds:
//   Probe A: INFocusStatusCenter (Intents framework) — RESEARCH predicts near-certain
//     dead end (gated behind Communication Notifications, which Islet has no legitimate
//     basis to add), but this is a hypothesis to confirm, not assume.
//   Probe B: ~/Library/DoNotDisturb/DB/Assertions.json read, gated on Full Disk Access.
//
// Entire file is DEBUG-only-gated — deleted in Plan 38-07 once the winning path is
// locked into the real FocusModeMonitor.swift. Never ships in Release (verified by
// Task 1's acceptance criteria: `runFocusDetectionSpike` must not appear in a Release
// build's binary/symbol table).

func runFocusDetectionSpike() {
    spikePathA()
    spikePathB()
}

// MARK: - Probe A: INFocusStatusCenter

private func spikePathA() {
    print("[FocusSpike][PathA] authorizationStatus before request:",
          INFocusStatusCenter.default.authorizationStatus)

    INFocusStatusCenter.default.requestAuthorization { status in
        print("[FocusSpike][PathA] requestAuthorization result:", status)
        if status == .authorized {
            print("[FocusSpike][PathA] focusStatus.isFocused:",
                  INFocusStatusCenter.default.focusStatus.isFocused as Any)
        }
    }
}

// MARK: - Probe B: Assertions.json (Full Disk Access)

private func spikePathB() {
    let path = NSString(string: "~/Library/DoNotDisturb/DB/Assertions.json").expandingTildeInPath

    guard let data = FileManager.default.contents(atPath: path) else {
        print("[FocusSpike][PathB] read returned nil (not granted / file absent) — path:", path)
        return
    }

    print("[FocusSpike][PathB] read returned Data, byte count:", data.count)

    // Defensive parsing per RESEARCH's "never force-unwrap" requirement — a malformed
    // read must print a "parse failed" line, not crash.
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("[FocusSpike][PathB] JSONSerialization parse failed")
        return
    }

    guard let dataArray = json["data"] as? [[String: Any]], let first = dataArray.first else {
        print("[FocusSpike][PathB] parsed JSON but 'data[0]' not present")
        return
    }

    guard let records = first["storeAssertionRecords"] as? [[String: Any]] else {
        print("[FocusSpike][PathB] parsed JSON but 'storeAssertionRecords' not present")
        return
    }

    print("[FocusSpike][PathB] storeAssertionRecords parsed, isEmpty:", records.isEmpty,
          "count:", records.count)
}
#endif
