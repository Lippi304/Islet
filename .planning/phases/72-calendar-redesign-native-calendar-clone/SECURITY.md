# Security Audit — Phase 72: Calendar Redesign (Native Calendar Clone)

**Audited:** 2026-07-31
**ASVS Level:** 1
**Block on:** critical
**Pass:** 1 (first security pass, no prior SECURITY.md)

## Scope

Threat register extracted from `<threat_model>` blocks in 72-01-PLAN.md, 72-02-PLAN.md,
72-03-PLAN.md, 72-04-PLAN.md. Cross-referenced against 72-REVIEW.md's WR-01/WR-02/WR-03 code
review findings per explicit audit instruction. Verified against the CURRENT implementation
(post Plan 72-04's live D-01/D-02 revert — the whole-month `eventsByDay`/`dayGroupedAgenda`
agenda from Plan 72-03 no longer exists; the single-day `dayEventsList`/`EventRow` agenda is what
ships).

No `## Threat Flags` sections found in any of the four SUMMARY.md files — no executor-flagged
new attack surface to reconcile.

## Threat Verification

| Threat ID | Category | Disposition | Verdict | Evidence |
|-----------|----------|-------------|---------|----------|
| T-72-01 | Tampering | mitigate | **CLOSED** | `Islet/Calendar/CalendarService.swift:149,157,176` — `title`/`ek.title` always passed as plain `String` (`event.title = title`, `EventInput(... title: ek.title ?? "" ...)`), never interpolated into a format/log/shell string. |
| T-72-02 | Tampering (identifier misuse) | mitigate (revised from accept) | **CLOSED (fixed 2026-07-31)** | `CalendarService.swift:149` — `mapToEventInput`'s fallback changed from a shared `""` to `ek.eventIdentifier ?? UUID().uuidString`, so two nil-identifier events on the same day can never collide under `ForEach(dayEvents, id: \.id)` (`NotchPillView.swift:1881`). Build (`xcodebuild build -scheme Islet`) and `CalendarGlanceTests` (19/19) both pass post-fix. |
| T-72-03 | Denial of Service (crash on missing/mutated event) | mitigate | **CLOSED** | `Islet/Calendar/CalendarService.swift:172-174,188-190` — `guard let event = store.event(withIdentifier: id) else { completion(false); return }` before any mutation in both `updateEvent`/`deleteEvent`; `do/catch -> completion(false)` around both throwing `store.save`/`store.remove` calls (lines 179-184, 192-197). No force-unwrap anywhere in either method. |
| T-72-SC | Tampering (supply chain) | accept | **CLOSED** | `CalendarService.swift`/`CalendarGlance.swift` import only `Foundation`/`EventKit`/`AppKit` (all pre-existing, already-linked system frameworks); no `Package.swift`/dependency-manifest changes touch this phase's commits. |
| T-72-04 | All STRIDE categories | accept | **CLOSED** | `Islet/Notch/NotchPillView.swift:1646-1717` (`rotatedWeekdaySymbols`, `weekdayHeaderRow`, `monthGridColumn` badge swap) confirmed pure-rendering: `Calendar.veryShortWeekdaySymbols` read, `Color.red`/`Color.clear` constants, no new data ingestion or persisted state. |
| T-72-05 | Tampering (malformed display content) | mitigate | **CLOSED** | `NotchPillView.swift:4724,4729` — `Text(event.title)` + `.help(event.title)` (native tooltip, `.lineLimit(1)/.truncationMode(.tail)` retained); `EventEditPopover` (line 5332) binds `event.title` only via `TextField("...", text: $title)`. No interpolation into any format/log/shell string anywhere in either surface. |
| T-72-06 | Repudiation / accidental data loss | accept | **CLOSED** | `NotchPillView.swift:4737-4743` — trash `Button(action: onDelete)` fires immediately on tap, opacity-gated by hover only; no confirm dialog anywhere in `EventRow`, matching the locked D-08 decision. |
| T-72-07 | Tampering (input validation) | mitigate | **CLOSED (scope as literally declared)** | `NotchPillView.swift:5338-5339,5354` — `EventEditPopover`'s Save action guards `trimmedTitle.isEmpty` and the button carries a matching `.disabled(...)`, identical to `QuickAddPopover`'s guard (line 5224/5245). This closes the *specific* mitigation this threat declared (blank-title guard) and nothing more — see Open Findings below for the gap the disposition never claimed to cover. |
| T-72-08 | Tampering | mitigate | **CLOSED** | `NotchWindowController.swift:2481-2491` — `handleEventEdit`/`handleEventDelete` forward `id`/`title`/`start`/`end` unmodified straight into `calendarService.updateEvent`/`deleteEvent`, no additional logic; relies on (and correctly reuses) the service-layer T-14-06/T-28-05 guarantees verified above. |

**Closed:** 8/8 | **Open:** 0/8

## Resolved Findings

### T-72-02 — identifier-collision integrity gap (fixed 2026-07-31)

The phase's own code review (72-REVIEW.md WR-03) found, and this audit independently confirmed
in the shipped code, that `mapToEventInput`'s `ek.eventIdentifier ?? ""` fallback could produce
duplicate `""` ids across multiple events, and `dayEventsList`'s `ForEach(dayEvents, id: \.id)`
(`NotchPillView.swift:1881`) used that id as SwiftUI list identity — a wrong-row edit/delete
targeting risk on the user's own legitimate data, no attacker required.

**Fix applied:** `CalendarService.swift:149` — fallback changed to `ek.eventIdentifier ?? UUID().uuidString`, so two nil-identifier events can never collapse to the same list identity.
Disposition revised from `accept` to `mitigate` to reflect the code change.

**Verified:** `xcodebuild build -scheme Islet` clean; `CalendarGlanceTests` 19/19 passing.

## Unregistered Flags (WARNING, non-blocking)

### WR-02 (72-REVIEW.md) — no start/end time-ordering validation, broader than T-72-07's claimed scope

`QuickAddPopover` and `EventEditPopover` (`NotchPillView.swift:5220-5245`, `5322-5363`) validate
only title-emptiness before writing to EventKit — confirmed by grep, matches T-72-07's literal
declared scope exactly, so T-72-07 itself is correctly CLOSED. But neither popover (nor
`CalendarService.swift:153-198`) rejects `endTime <= startTime`, letting a user write a
negative-duration event straight into their real Calendar. No threat ID in the register claims
to cover time-ordering validation — this is new, unmapped attack surface (ASVS V5, input
validation) surfaced by code review rather than by an executor Threat Flag. Not a blocker under
this phase's declared threat model, but should be registered as its own threat (e.g. T-72-09) and
mitigated in a follow-up phase/plan.

### WR-01 (72-REVIEW.md) — stale-fetch race on rapid month navigation (informational only)

Not a declared threat in this register and not a security-classified issue (data races between
`refreshCalendarMonth()` calls can show a stale month's events, no crash/data-loss/injection
vector). Noted here only because it appears in the same review; does not require a threat
mapping under ASVS Level 1 scope.

## Accepted Risks Log

The following dispositions are recorded as accepted for this phase, per each PLAN.md's own
`<threat_model>` block (transcribed here for the first time — no prior SECURITY.md existed):

- **T-72-SC** (Tampering — supply chain): Zero new packages/dependencies added by Plans 72-01/72-04. Verified: only `Foundation`/`EventKit`/`AppKit` imports, no dependency-manifest changes.
- **T-72-04** (All STRIDE categories — `monthGridColumn`/`weekdayHeaderRow`): Pure SwiftUI rendering-constant change (colors, fonts, `Calendar.veryShortWeekdaySymbols`), no new data ingestion or persisted state. Verified.
- **T-72-06** (Repudiation/accidental data loss — hover-reveal delete, no confirm dialog): Explicit locked user decision D-08; EventKit deletion is recoverable via Calendar.app/iCloud sync history. Verified as-built.
- **T-72-02** (Tampering — identifier misuse): Fixed rather than re-accepted — see Resolved Findings above. Disposition is now `mitigate`.

## Summary

**Closed:** 8/8 declared threats
**Open:** 0/8
**Unregistered gaps surfaced by code review (non-blocking):** WR-02 (time-ordering validation, recommend registering as T-72-09 in a follow-up phase)

Phase 72 is security-clean. All declared threats have verified mitigations or accepted-risk
rationale that holds up against the shipped code.
