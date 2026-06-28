# Phase 6: Priority Resolver, Settings & v1 Ship - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 6-priority-resolver-settings-v1-ship
**Areas discussed:** Priority & Collisions, Activity Toggles, Accent / Theme, v1 Release Logistics

---

## Priority & Collisions

### Phase 5 device-activity handling (resolver inputs)
| Option | Description | Selected |
|--------|-------------|----------|
| Build device wiring now | Finish BluetoothMonitor + DeviceActivityState + view wing in Phase 6, code-complete; defer only on-device BT verification. Resolver gets 3 real inputs. | ✓ |
| Resolver for 2 + device seam | Build for Charging + Now Playing, leave a typed device slot; wire device later. v1 ships without device. | |
| Pause Phase 6, finish Phase 5 first | Get a BT test device, complete Phase 5, then Phase 6. | |

### Priority rank
| Option | Description | Selected |
|--------|-------------|----------|
| Charging > Device > Now Playing | Transients win briefly over the ambient music baseline; charging before device. | ✓ |
| Device > Charging > Now Playing | — | |
| You decide | Both transients equal, pick a sensible default. | |

### Simultaneous transient collision
| Option | Description | Selected |
|--------|-------------|----------|
| Fixed rank, higher wins, other dropped | Simplest, guaranteed no glitch. | |
| Short queue | Splash A ~3s, then splash B ~3s sequentially. | ✓ |
| Latest event wins | Most recent splash interrupts the running one. | |

### Transient vs user-expanded island
| Option | Description | Selected |
|--------|-------------|----------|
| Transient wins briefly (D-11) | Splash shows feedback, then returns to open/ambient state. | ✓ |
| User interaction protected | Splash held back while island is open. | |

**Notes:** Device wiring completion is framed as finishing already-scoped DEV-01/DEV-02
(blocked Phase-5 Waves 2-3), not new scope. Queue must stay bounded + de-duped (discretion).

---

## Activity Toggles

### Which activities are toggleable
| Option | Description | Selected |
|--------|-------------|----------|
| All three independently | One switch each: Charging, Now Playing, Device. | ✓ |
| Only transients | Charging + Device; Now Playing always on (core feature). | |
| You decide | — | |

### Beyond plain on/off
| Option | Description | Selected |
|--------|-------------|----------|
| Pure on/off only | Leanest. | ✓ |
| + Master "pause island" switch | — | |
| + Splash duration setting | Make the ~3s adjustable. | |

### Default state on fresh install
| Option | Description | Selected |
|--------|-------------|----------|
| All on | App shows everything immediately; user disables as needed. | ✓ |
| Now Playing + Charging on, Device off | Device off by default (unverified). | |

**Notes:** Persistence required (success criterion 2); @AppStorage/UserDefaults is discretion.

---

## Accent / Theme

### Theme scope
| Option | Description | Selected |
|--------|-------------|----------|
| Accent color only, island stays black | No light/dark mode. Keeps notch illusion. | ✓ |
| Accent + lighter/tinted island variant | Risk: breaks the seamless notch transition. | |

### What the accent tints
| Option | Description | Selected |
|--------|-------------|----------|
| Lively active elements | Charging bolt/glyph, equalizer bars, device icon. | ✓ |
| + expanded-UI highlights | Active transport button, title accent too. | |
| You decide | Coherent subtle default. | |

### Picker + default
| Option | Description | Selected |
|--------|-------------|----------|
| Curated palette (~5-6), default neutral | Apple-style preset swatches. | ✓ |
| Full ColorPicker, default neutral | Any color. | |
| Palette + custom-color option | Combined. | |

---

## v1 Release Logistics

### Apple Developer account / release mode
| Option | Description | Selected |
|--------|-------------|----------|
| Account ready → real release | Run real sign→notarize→staple + second-Mac test. | |
| No account → dry-run | Build pipeline complete, run ad-hoc dry-run; real notarized build + second-Mac test deferred until account exists. | ✓ |
| Unclear / later | — | |

### Product name
| Option | Description | Selected |
|--------|-------------|----------|
| Stay "Islet" | Current bundle name for v1. | ✓ |
| Choose a different name | User provides. | |
| Leave open | Decide later. | |

### Version number
| Option | Description | Selected |
|--------|-------------|----------|
| 1.0 | Official v1 milestone. | |
| 0.1 / 0.x | Private first release; 1.0 for public sale later. | ✓ |
| You decide | — | |

### DMG packaging
| Option | Description | Selected |
|--------|-------------|----------|
| hdiutil (current) | Works, no extra dependency. | ✓ |
| create-dmg | Prettier installer window (needs Homebrew). | |
| You decide | — | |

## Claude's Discretion

- Resolver shape (pure rank/queue function vs active-activity enum) + queue depth/dedup rule.
- Persistence keys/structure; whether a disabled activity stops its monitor or just hides.
- The 5-6 accent swatches + default; how accent threads into the glyph/bars/icon views.
- Device-activity specifics inherited from 05-CONTEXT (name→symbol, burst/debounce, disconnect styling).
- Spring/duration tuning.

## Deferred Ideas

- On-device Bluetooth UAT; real Developer-ID notarize/staple + second-Mac open; public name + 1.0;
  master switch / duration setting / free ColorPicker / tinted island / accent-on-chrome;
  sneak-peek toggle + allowlist widening (v2); create-dmg.
