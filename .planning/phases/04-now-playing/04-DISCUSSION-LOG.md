# Phase 4: Now Playing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 04-now-playing
**Areas discussed:** Idle-while-playing look, Expanded layout, Paused behavior, Unavailable/blocked-API, plus follow-ups (no-media expanded, charging coexistence)

---

## Gray-area selection

All four offered areas selected: Idle-while-playing look, Expanded Now Playing layout, Paused-media behavior, "Unavailable"/blocked-API presentation.

---

## Idle-while-playing look

| Option | Description | Selected |
|--------|-------------|----------|
| Album art LEFT only | Thumbnail left, right wing minimal (waveform is v2) | |
| Album art LEFT + play-state glyph RIGHT | Small ▶/❚❚ or music-note on the right | |
| Quiet invisible pill | Nothing until expand | |
| Album art LEFT + scrolling title RIGHT | Art + song name (DynamicLake-style) | |
| **Album art LEFT + animated equalizer bars RIGHT** | Free-text: 3–5 bars, varying heights, grow/shrink — the classic now-playing symbol | ✓ |

**User's choice:** Album art left, **animated equalizer bars** (3–5) on the right.
**Notes:** Follow-up confirmed the bars are **decorative/synthetic** (no real audio tap — out of scope), animate **only while playing**; on **stop**, a short exit animation then the whole window disappears. Pause behavior deferred to Area 3.

---

## Expanded Now Playing layout

| Option | Description | Selected |
|--------|-------------|----------|
| **Art left; title/artist right; 3 buttons below** | Compact iPhone-DI/Alcove | ✓ (via reference image) |
| Art left; title/artist top; buttons vertically right | | |
| Art top/centered; title/artist below; buttons bottom | | |

**User's choice:** Provided **reference image** (`assets/expanded-layout.png`): art left · title+artist right · equalizer bars top-right · progress bar · control row Shuffle·⏪·⏯·⏩·Star.
**Metadata:** Title + Artist only (selected "minimal & sauber").

**Scope follow-ups (image elements vs Phase-4 scope):**

| Element | Status presented | User decision |
|---------|------------------|---------------|
| Seek/progress bar (NOW-04) | v2 / read-only now / full scrubber now | **v2 lassen** — layout reserves room |
| Shuffle + Repeat | defer v2 / research first / v1 | **v2 verschieben** — layout reserves room |
| Star / favorite | drop / research Apple-Music / keep | **Drop** ("weg"); shuffle goes LEFT, repeat RIGHT in the (future) row |
| Sneak-peek (NOW-05) | v2 / build+toggle / build no toggle | **v2 lassen** |
| Source restriction | only Spotify+AM / +settings-expandable / any app | **Only Spotify + Apple Music (bundle-ID allowlist)** |
| Control-row confirm | v1=3 buttons, shuffle/repeat reserved / build now / other | **v1 = ⏪ ⏯ ⏩ only; shuffle-left + repeat-right reserved for v2; star out** |

---

## Paused-media behavior

| Question | Options | Selected |
|----------|---------|----------|
| What on pause? | bars freeze (stay) / bars vanish (art stays) / treat like stop | **Bars freeze / static, display stays** |
| Paused + idle | stay forever / auto-hide after timeout | **Auto-hide** — free-text: after **15 seconds** |

**Notes:** Stop (already decided in Area 1) = short exit animation → disappear. Pause = frozen bars, lingers, auto-hides after 15 s (one-shot timer, no polling).

---

## "Unavailable" / blocked-API presentation

| Question | Options | Selected |
|----------|---------|----------|
| Where does "unavailable" show? | **in expanded island** / menu item / both / launch notification | **In the expanded island** ("Now Playing nicht verfügbar" on expand) |
| API drops mid-session? | **clear to idle** / brief unavailable splash / freeze last track | **Clear to idle immediately**; unavailable shown only on next expand |

**Notes:** "Nothing playing" (API healthy) = no display, idle pill only — distinct from the explicit "unavailable".

---

## Follow-ups

| Question | Options | Selected |
|----------|---------|----------|
| No media (API ok), user expands | **date/time placeholder** / "nichts spielt" hint / no expand | **Keep Phase-2 date/time placeholder** as the no-music state |
| Charging while music plays | **charging wins ~3s → back to now-playing** / other | **Charging briefly wins, then returns to now-playing wings**; full resolver = Phase 6 |

---

## Claude's Discretion

- The now-playing service/model abstraction shape (mirror the Phase-3 pure-seam + @Published + thin-glue + view-branch quartet; now-playing-specific, no general resolver).
- Exact bar count (3–5), bar tempo/curve, frozen-paused visual.
- Expanded geometry, art corner radius/size, fonts, transport SF Symbols + sizing.
- Album-art async load mechanism + placeholder.
- Whether hover resets the 15 s paused timeout (likely yes, per charging D-10 pattern).
- Spring/duration tuning (seeds: response ≈ 0.35, damping ≈ 0.65); entrance/exit cue specifics.
- The pure-logic seam (now-playing info → presentation, incl. source allowlist filter).

## Deferred Ideas

- Seek bar (NOW-04, v2), Shuffle+Repeat (v2, slots reserved), Sneak-peek (NOW-05, v2) + Settings toggle (Phase 6), Color tint (NOW-06), Waveform (NOW-07), source-allowlist expansion (Phase 6), general resolver (Phase 6, COORD-01).
- Star / favorite — **dropped entirely** (not feasible via MediaRemote for Spotify).
</content>
