# Phase 10: Trial & Lockout Gate - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 10-Trial & Lockout Gate
**Areas discussed:** First-launch trial notice, Locked-state visual, Debug/testing seam, Trial-notice timing edge cases

---

## First-launch trial notice

| Option | Description | Selected |
|--------|-------------|----------|
| In-island animated card | One-time transient inside the island, matching the charging/device wings animation language | |
| Native macOS notification | Standard UNUserNotificationCenter banner | |
| Both | Island card + system notification fallback | |

**User's choice:** Neither. Free-text response (translated from German): the download/marketing page itself advertises "3 days trial" with a download button, so the app doesn't need to re-announce the trial start with a splash or notification. In-app, the only moment that matters is when the trial expires — Settings should then show "3-day trial period expired" + a link to buy the full version + a license-key field.

**Follow-up:** Since TRIAL-02 (locked requirement) still calls for an explicit one-time in-app notice, asked how to satisfy it given no popup/notification was wanted.

| Option | Description | Selected |
|--------|-------------|----------|
| Settings auto-opens once on first launch | Existing Settings window opens automatically with a short "trial started — ends [date]" line | ✓ |
| No in-app moment at all | Rely purely on the download page; would require revising TRIAL-02 | |

**Notes:** Settings auto-open reuses the existing window — no new alert/notification type, no permission prompt.

---

## Locked-state visual

| Option | Description | Selected |
|--------|-------------|----------|
| Jump straight to Settings | Clicking the menu-bar icon while locked opens Settings directly, skipping the normal dropdown | ✓ |
| Keep the normal menu | Regular Settings/Quit dropdown, user picks Settings manually | |

**User's choice:** Jump straight to Settings.

| Option | Description | Selected |
|--------|-------------|----------|
| No change | Menu-bar icon looks identical regardless of trial/expired/licensed state | ✓ |
| Visual hint when locked | Dimmed icon or badge to passively signal expiry | |

**User's choice:** No change.

**Notes:** The user's own described flow (see First-launch trial notice above) already establishes that on expiry, opening Settings shows the "trial expired" message + buy link + license field — that content itself is Phase 11's scope (TRIAL-03), not built in Phase 10.

---

## Debug/testing seam

| Option | Description | Selected |
|--------|-------------|----------|
| DEBUG-only menu item | Menu item(s) to force trial/expired/licensed states instantly, DEBUG builds only | ✓ |
| Shortened DEBUG trial length | 60s DEBUG trial instead of 3 days, natural countdown | |
| Both | Menu item + shortened trial | |

**User's choice:** DEBUG-only menu item.

---

## Trial-notice timing edge cases

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-open regardless | Settings opens on first launch regardless of island/display state | ✓ |
| Wait until the island can show | Delay the notice until the built-in display is the active target | |

**User's choice:** Auto-open regardless — Settings is an ordinary window, not tied to island visibility.

---

## Claude's Discretion

- Exact Keychain item attributes (`kSecAttrAccount` naming, `kSecAttrAccessible` level)
- Exact wording of the first-launch Settings notice text and DEBUG menu item labels/placement
- Whether DEBUG menu items live under the existing status-item menu or a separate DEBUG-only menu

## Deferred Ideas

None. The user's described "expired Settings screen with buy link + license field" is already correctly scoped to Phase 11 (TRIAL-03) per the existing roadmap — not deferred, just noted in CONTEXT.md as input for that phase.
