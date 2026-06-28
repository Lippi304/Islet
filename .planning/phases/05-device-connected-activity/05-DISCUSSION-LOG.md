# Phase 5: Device-Connected Activity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 5-device-connected-activity
**Areas discussed:** Device scope, Splash content & icon, Disconnect treatment, Noise control, Now-Playing coexistence, TDD seam

---

## Device scope

| Option | Description | Selected |
|--------|-------------|----------|
| Audio devices only | AirPods/headphones/BT speakers by class/name; mice/keyboards never splash | |
| AirPods / Apple audio only | Even narrower; non-Apple BT headphones don't splash | |
| All Bluetooth devices | Anything that connects splashes (simplest, but noisy) | ✓ |

**User's choice:** All Bluetooth devices.
**Notes:** Deliberately broadens beyond the requirement's "Bluetooth audio device" wording; noise mitigated by burst suppression (D-04), not class filtering.

---

## Splash content & icon

| Option | Description | Selected |
|--------|-------------|----------|
| Device-specific glyph | AirPods/Pro/Max/headphones/beats by name match, generic BT fallback | ✓ |
| One generic glyph | Single BT/headphones glyph for everything | |
| You decide | Claude discretion on symbol mapping | |

**User's choice:** Device-specific glyph with generic fallback.
**Notes:** "Most Apple" feel; exact name→symbol table is discretion + on-device tuning.

---

## Disconnect treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Same splash, distinguished | Dimmed/greyed icon or small "Disconnected" label vs colored "Connected" | ✓ |
| Identical splash, text differs | Only the text changes | |
| You decide | On-device tuning | |

**User's choice:** Same wings splash, visually distinguished.
**Notes:** One layout two states (mirrors Phase 3 D-04 single-glyph philosophy).

---

## Noise control

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress burst AND debounce | At-launch/wake burst suppressed + reconnect-flap debounced | ✓ |
| Suppress at-launch burst only | No splash for already-connected devices at start | |
| No guards in v1 | Splash on every edge | |

**User's choice:** Suppress at-launch/wake burst AND debounce reconnect flapping.
**Notes:** Must stay event-driven, no polling (idle CPU ~0%).

---

## Now-Playing coexistence (interim, pre-Phase-6)

| Option | Description | Selected |
|--------|-------------|----------|
| Brief precedence then yield | Device splash shows briefly, returns to ambient/now-playing (mirror D-11) | ✓ |
| Now Playing wins | Suppress device splash if media already showing | |
| Just don't crash | Leave coexistence to Phase 6 | |

**User's choice:** Brief precedence then yield (mirror charging D-11), minimal & device-specific.
**Notes:** General resolver remains Phase 6 / COORD-01.

---

## TDD seam

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — same seam discipline | Pure DeviceActivity mapping + edge predicate unit-tested; wiring on-device | ✓ |
| No — skip pure unit tests | Wiring thin enough | |
| You decide | — | |

**User's choice:** Yes — same discipline as PowerActivity.swift / NowPlayingPresentation.swift.

---

## Claude's Discretion

- Name→SF-Symbol mapping + generic fallback glyph
- Burst-suppression / debounce mechanism (startup grace vs seen-set; debounce interval)
- Disconnect dimming/label styling + wing geometry reuse
- Device-activity state model shape (one enum vs two)
- IOBluetooth wiring specifics, spring/duration tuning

## Deferred Ideas

- Per-bud AirPods battery % (DEV-03) → later milestone
- General multi-activity priority resolver → Phase 6 (COORD-01)
- Settings toggle + accent/theme → Phase 6 (APP-03)
- Device-class filtering as a setting → possible later revisit
