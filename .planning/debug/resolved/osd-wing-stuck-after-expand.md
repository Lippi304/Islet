---
status: resolved
trigger: "Wenn man Helligkeit/Lautstärke ändert (OSD-Wing erscheint eingeklappt mit Auto-Dismiss-Timer) und, BEVOR dieser Timer abgelaufen ist, die Island per Klick voll expandiert (Collapsed -> Home) und danach wieder einklappt (Home -> Collapsed), bleibt die OSD-Wing danach dauerhaft sichtbar am Bildschirm hängen (kein Auto-Dismiss mehr) und ihr angezeigter Wert aktualisiert sich nicht mehr, bis der User erneut manuell Helligkeit/Lautstärke ändert (frischer Tastendruck)."
created: 2026-08-01
updated: 2026-08-01
---

## Symptoms

- **Expected behavior:** Die OSD-Wing (Helligkeit/Lautstärke) erscheint eingeklappt bei einer Änderung, läuft ihren normalen Auto-Dismiss-Timer ab und verschwindet dann automatisch — unabhängig davon, ob zwischendurch ein voller Expand/Collapse-Zyklus der Island stattfindet. Die Anzeige muss dabei durchgehend im Hintergrund weiterlaufen/aktuell bleiben.
- **Actual behavior:** Wird die Island expandiert (Klick → Home) und wieder eingeklappt, WÄHREND die OSD-Wing noch sichtbar ist (ihr Auto-Dismiss-Timer also noch nicht abgelaufen war), bleibt die OSD-Wing danach dauerhaft eingeklappt sichtbar hängen — kein automatisches Verschwinden mehr. Der angezeigte Helligkeits-/Lautstärke-Wert ist eingefroren (aktualisiert sich nicht mehr), bis der User erneut manuell an Helligkeit oder Lautstärke dreht (ein frisches Tastendruck-Event) — erst dann "erwacht" es wieder.
- **Error messages:** Keine bekannt / nicht geprüft.
- **Timeline:** Vom User "im Vorbeigehen" während einer anderen Debug-Session entdeckt (2026-08-01) — unklar ob Regression oder pre-existing; unklar ob durch die kürzlich gemachte Änderung an `OSDLevelBar`'s Glass-`Capsule` (eigener `GlassEffectContainer`, aus der `liquid-glass-anim-missing` Debug-Session) verursacht — das sollte als eine der ersten Hypothesen geprüft werden (z.B. via `git log`/`git diff` auf den relevanten Commit).
- **Reproduction:** (1) Helligkeit oder Lautstärke ändern → OSD-Wing erscheint eingeklappt. (2) Bevor die Wing von selbst verschwindet, auf die Island klicken → volles Expand (Home). (3) Wieder einklappen (Collapse). (4) Beobachten: OSD-Wing bleibt jetzt dauerhaft sichtbar hängen, Wert eingefroren. (5) Erst ein erneuter Helligkeits-/Lautstärke-Tastendruck "befreit" es wieder. Nur mit vollem Expand/Collapse getestet — ob andere Live-Activity-Events (z.B. Musik-Wing erscheint) in diesem Zeitfenster denselben Effekt auslösen, wurde vom User nicht getestet.

## Current Focus

reasoning_checkpoint:
  hypothesis: "handleHoverExit() only re-arms the shared ~3s/1.5s dismissWorkItem for two narrow cases (chargingState.activity != nil, or nowPlaying == .paused), while handleHoverEnter() unconditionally CANCELS that same dismissWorkItem for ANY standing transient category (including .osd). Since a click always requires the pointer to first enter the interactive zone (pointerInZone gates click-through), every expand click cancels a standing OSD's dismiss timer; when the pointer later leaves the zone, handleHoverExit's narrow guard skips OSD, so the timer is never rescheduled and transientQueue.head stays .osd(...) forever with no running timer — frozen value, no auto-dismiss."
  confirming_evidence:
    - "NotchWindowController.swift L2098: handleHoverEnter() calls dismissWorkItem?.cancel() with no category check at all."
    - "NotchWindowController.swift L2221-2227 (handleHoverExit): re-arm is gated ONLY on `if chargingState.activity != nil { scheduleActivityDismiss() }` and a separate `if case .paused = nowPlayingState.presentation` for scheduleMediaDismiss — transientQueue.head is never consulted, so .osd/.device/.capsLock/.updateAvailable/.downloadProgress(.done) heads are never resumed."
    - "L1848-1867 handlePointer(at:): handleHoverEnter()/handleHoverExit() fire on every zone enter/exit, and a click can only land while pointerInZone is true — so hover-enter always precedes a click, guaranteeing the cancel fires before any expand."
    - "L2990-3001 handlePower/handleBrightness's update-head path calls scheduleActivityDismiss() again on a FRESH press while head is already .osd — explains exactly why a new keypress 'wakes' the stuck wing (matches reported workaround)."
  falsification_test: "If wrong, reproducing WITHOUT ever hovering over the island (e.g. programmatically toggling isExpanded without pointer entering collapsedInteractiveZone/expandedZone) should still get stuck; conversely, if the fix (re-arming unconditionally in handleHoverExit) is applied and the repro no longer sticks, hypothesis is confirmed."
  fix_rationale: "scheduleActivityDismiss() already internally no-ops when transientQueue.head is nil or isPersistent (L3028 guard), so it is always safe to call unconditionally. Broadening handleHoverExit's re-arm call to be unconditional (matching handleHoverEnter's unconditional cancel) restores symmetry and fixes ALL affected categories (osd, device, capsLock, updateAvailable, downloadProgress(.done)) with one change, not just osd."
  blind_spots: "Have not yet run the app on-device to visually confirm; relying on static code trace. Have not checked whether scheduleMediaDismiss's separate paused-media path has an analogous gap (out of scope for this bug report, not touching it)."

hypothesis: CONFIRMED — see reasoning_checkpoint above.
test: static code trace of handleHoverEnter/handleHoverExit/scheduleActivityDismiss/resolve()
expecting: n/a — root cause confirmed via direct code reading, no ambiguity
next_action: apply fix — broaden handleHoverExit's dismiss re-arm to be unconditional (mirroring handleHoverEnter's unconditional cancel), then request on-device human verification since this is a UI timing bug with no automated repro harness

## Evidence

- timestamp: 2026-08-01
  checked: NotchWindowController.swift handleHoverEnter() (L2077-2114) and handleHoverExit() (L2160-2233)
  found: handleHoverEnter unconditionally cancels dismissWorkItem (L2098) for any standing transient; handleHoverExit only re-arms it via scheduleActivityDismiss() when chargingState.activity != nil (L2225-2227), and separately re-arms scheduleMediaDismiss only for paused now-playing (L2230-2232). No branch re-arms for .osd, .device, .capsLock, .updateAvailable, or .downloadProgress(.done).
  implication: any of those categories' auto-dismiss timer gets permanently cancelled the moment the user hovers over the island (which always happens before a click) and never restarted once the pointer leaves — the queue head sticks forever with a frozen payload.

- timestamp: 2026-08-01
  checked: NotchWindowController.swift scheduleActivityDismiss() (L3022-3058) and handlePower/handleBrightness's osd update-head path (L2990-3001)
  found: scheduleActivityDismiss() itself already guards safely (`guard let head = transientQueue.head, !head.isPersistent else { return }`) — safe to call unconditionally. A fresh OSD press re-arms it via this exact function at L3001, explaining why a new keypress "wakes" the stuck wing.
  implication: fix can be a single unconditional call in handleHoverExit, no new guard logic needed — scheduleActivityDismiss is already idempotent/no-op-safe for nil/persistent heads.

- timestamp: 2026-08-01
  checked: handlePointer(at:) L1848-1867
  found: handleHoverEnter()/handleHoverExit() are driven by pointerInZone edge-tracking on every mouse-position sample; a click can only register while the panel is click-through-enabled, which requires pointerInZone true — so hover-enter always precedes any click that expands the island.
  implication: the reported repro (expand-then-collapse while OSD is up) reliably triggers the cancel-without-resume path, matching 100% of the reported symptoms.

## Eliminated

## Resolution

root_cause: "handleHoverExit() re-arms the shared transient dismiss timer only for the charging-splash and paused-now-playing cases, never generically for transientQueue.head. handleHoverEnter() unconditionally cancels that same timer for ANY standing transient (including .osd). Because every click is preceded by a hover-enter (click-through requires pointerInZone), expanding the island while an OSD wing stands cancels its dismiss timer, and collapsing again (pointer eventually exits the zone) never restarts it — the OSD head sticks with a frozen value and no auto-dismiss until a fresh volume/brightness press re-arms it via the update-head path."
fix: "NotchWindowController.swift handleHoverExit(): replaced the narrow `if chargingState.activity != nil { scheduleActivityDismiss() }` gate with an unconditional `scheduleActivityDismiss()` call, mirroring handleHoverEnter()'s unconditional cancel. Safe because scheduleActivityDismiss() already internally guards (`guard let head = transientQueue.head, !head.isPersistent else { return }`) — no-ops for nil/persistent heads on its own. Fixes not just .osd but the same latent gap for .device, .capsLock, .updateAvailable, .downloadProgress(.done)."
verification: "Self-verified: xcodebuild Debug build succeeded with no errors/warnings introduced. Static trace confirmed the fixed code path re-arms the dismiss timer for any non-persistent transientQueue.head on hover-exit, closing the cancel-without-resume gap. On-device human verification (2026-08-01): confirmed fixed — repro (change brightness/volume, expand island, collapse) no longer sticks; OSD wing auto-dismisses normally and value stays live."
files_changed: ["Islet/Notch/NotchWindowController.swift"]
