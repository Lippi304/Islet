# Phase 51: Settings Reorganization & Scroll Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-21
**Phase:** 51-settings-reorganization-scroll-fix
**Areas discussed:** Sidebar structure & naming, Window sizing — scroll vs. grow, Sidebar section order

---

## Sidebar structure & naming

| Option | Description | Selected |
|--------|-------------|----------|
| Rename System → Appearance | Same content (Appearance Style + Accent Colors), just renamed and repositioned | ✓ |
| Keep System separate | System stays as-is, Appearance is undefined new content | |

**User's choice:** Rename System → Appearance

| Option | Description | Selected |
|--------|-------------|----------|
| Fold into Activities | Launch at Login sits alongside the 8 activity toggles | ✓ |
| Keep a slim 'General' section | General survives with only Launch at Login | |
| Move to About | Treated as an app-lifecycle setting next to Version/License | |

**User's choice:** Fold into Activities

| Option | Description | Selected |
|--------|-------------|----------|
| Own section (matches roadmap) | Diagnostics gets its own sidebar entry | ✓ |
| Fold into About | Diagnostics button moves next to Version/Credits | |

**User's choice:** Own section

| Option | Description | Selected |
|--------|-------------|----------|
| Claude picks sensible SF Symbols | No back-and-forth needed for icon detail | ✓ |
| I want to specify them | Walk through icon choice per section | |

**User's choice:** Claude picks sensible SF Symbols

**Notes:** None — all four questions resolved on the recommended option.

---

## Window sizing — scroll vs. grow

| Option | Description | Selected |
|--------|-------------|----------|
| Keep fixed size + scroll per section | 520×380 unchanged, each section scrolls internally if needed | ✓ |
| Grow the window taller | Fixed but bigger, less scrolling needed | |
| Make the window user-resizable | User drag-resizes, content reflows | |

**User's choice:** Keep fixed size + scroll per section
**Notes:** Activities remains the tallest section and will still scroll; other new sections are short enough to rarely need it.

---

## Sidebar section order

| Option | Description | Selected |
|--------|-------------|----------|
| Activities, Appearance, Fullscreen, Weather, Diagnostics, Workspace, About | Roadmap's own order, most-used-first | ✓ |
| Alphabetical | Predictable but buries Activities in the middle | |
| I want to specify a different order | Custom order | |

**User's choice:** Activities, Appearance, Fullscreen, Weather, Diagnostics, Workspace, About

---

## Claude's Discretion

- Exact SF Symbol icon per new section (Activities, Fullscreen, Weather, Diagnostics) — Appearance reuses System's existing "paintbrush" icon.
- The precise scroll-fix mechanism (why the current `Form` doesn't scroll today, and how to fix it — e.g. explicit `ScrollView` wrapper) — left to research/planning, not a user-facing decision.

## Deferred Ideas

None raised during discussion. Three pending todos (calendar month-grid polish, island disappearing during click-through, quick-action disabled-state gate) were surfaced as loose keyword matches at the start of discussion and skipped as unrelated to Settings — see CONTEXT.md's "Reviewed Todos" section.
