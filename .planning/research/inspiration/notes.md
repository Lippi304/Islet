# Inspiration: Droppy (Reddit find, 2026-07-11)

Reference app the user found on Reddit — same business model (7,99 one-time purchase after a 3-day trial) and a similar notch-based "island" concept, but with more built-out features. Screenshots captured live during the user's 3-day trial. This is **raw reference material for scoping v1.4**, not a build list — Droppy has a full third-party plugin ecosystem ("Droplets") that is almost certainly out of scope; treat it as a design-language and settings-taxonomy reference, not a feature checklist.

User's overall take: loves the interaction/animation feel — "wie ein 360Hz Monitor", very smooth, sometimes deliberately slow, which reads as premium. Explicitly dislikes the fully-transparent glass look (prefers glossy/frosted with more opacity/substance) and does not want the in-app gesture tutorial screen. Wants to keep Islet's own idle default (date/time/weather/calendar), not switch the default view to Now Playing/music like Droppy does.

## Onboarding flow (images 1-4)

- `1.png` — First-launch hero screen ("Meet Droppy where it lives"), step 1 of a 4-step onboarding carousel. User wants an equivalent first-launch flow for Islet (trial/license-key/buy choice, not just a passive notice like today).
- `2.png` — Permissions pre-explanation screen (Accessibility, Screen Recording, Input Monitoring), each with a one-line reason **before** the system prompt fires. User explicitly likes this pattern — wants it for Islet's own permission asks (Bluetooth, Calendar, Location, WeatherKit).
- `3.png` — Gesture tutorial screen ("Drive it with gestures"). **User does not want this** — no in-app tutorial step.
- `4.png` — "Make it yours" — 3 opt-in toggles presented at first launch (Clipboard history, HUD replacement, Launch at login), everything else deferred to Settings.

## Default/home view + view switcher (images 5, 10, 12)

- `5.png` — Droppy's default expanded view is Now Playing (media transport). Islet should **keep its current default** (date/time/weather/calendar), not copy this.
- Below the expanded view, Droppy shows a small 3-icon switcher: Home (default view) / Tray (shelf — what Islet is already building) / a 3rd slot for quick-launch apps. User wants the 3rd slot to be a **Calendar full view** instead of quick-launch apps.
- `10.png` — Collapsed idle pill, minimal.
- `12.png` — Empty Tray/shelf state — dashed drop-zone placeholder, same switcher visible underneath.

## Calendar full view (images 6-7)

- `6.png` — Month grid + "Today" event list on the right.
- `7.png` — Same view with a "New Task" quick-add popover open, and an empty-state ("No upcoming events").

## Charging / system glances (image 11)

- `11.png` — Charging state shows "Charging" label + green battery pill with %. Same idea Islet already ships (CHG-01), just for visual-style comparison.

## Full Settings walkthrough (images 8-9, 13-31)

Droppy's Settings window uses a left sidebar with sections: **General, Droplets** (workspace group: **Shelf, Basket, Clipboard, Lock Screen, Droppy Cloud**; system group: **HUDs, Theming, Accessibility**; about group: **License, About**). User specifically wants Islet's Settings redesigned in this sidebar-categorized direction (currently a single tabbed Form).

Notable per-section patterns worth reusing (evaluate individually, not as a bulk feature import):

- **General** (`8.png`): Startup & Visibility segmented control (Menu Bar Icon / Dock Icon / Launch at Login), a "Permissions Overview — X of Y granted" rollup row, Quick Action layout picker with a live island preview.
- **Droplets** (`13.png`, `14.png`) — a whole plugin marketplace grid (AI tools, media, productivity mini-widgets). Out of scope as a system — Islet has no plugin architecture — but individual droplet ideas are worth mining later (e.g. Calendar-event-progress-ring, Pomodoro, "AI Coding HUD" showing Claude/Codex status).
- **Shelf** (`15.png`, `16.png`) — Shelf Size (Regular/Enlarged), Navigation Style (Regular Buttons vs. Floating Bar), per-widget on/off picker ("5 of 13 widgets active"), Auto-Collapse vs Auto-Expand + a Collapse Delay slider, **Animation Speed presets (Turtle/Human/Cheetah/Falcon)** — nice reusable idea for Islet's spring animation tuning, Gestures on/off, Open Tray After Drop, File Retention duration, per-feature keyboard-shortcut recorders.
- **Basket** (`17.png`) — a *second*, floating drop target separate from the shelf (multi-basket mode). Not something Islet has an equivalent of; possible future idea, not scoped now.
- **Clipboard** (`17.png`-`18.png`) — full clipboard manager (history, previews, exclusions, tags). Out of scope — Islet doesn't have a clipboard manager.
- **Lock Screen** (`18.png`) — lock/unlock sound+animation, media HUD on lock screen, status widgets row. Out of scope for now (Islet doesn't touch the lock screen).
- **Droppy Cloud** (`19.png`, `19.5`) — temp file-sharing service (upload/AirDrop/Dropbox, 24h expiry). Out of scope — would require backend infra Islet doesn't have.
- **HUDs** (`20.png`-`23.png`) — the big one: a **Notch vs. "Dynamic Island" floating-pill display-style picker**, idle-visibility toggles, notch width/height sliders, a full Now-Playing HUD config block (visualizer style Regular-bars/Gradient, track-swipe gesture + direction, default music app, on-click behavior, fullscreen behavior), and a **system HUD replacement grid** — Volume, Brightness, Charging%, File Tray, Caps Lock, Recording Status, Update available, AirPods connected, Focus Mode, No Internet, VPN — each with its own live mini-preview. This directly matches the project's own long-deferred "system HUD replacement" backlog item — good reference when that gets scoped.
- **Theming** (`27.png`-`29.png`) — **this is the key one for the "visual redesign" scope**: surface-style picker (Dynamic Glass vs. flat Black, for notched vs. notchless displays), a **Liquid Glass / Frosted / Regular material picker specifically for HUDs**, a subtle-outline toggle, 6 alternate app-icon variants, and per-element color pickers (highlight, window tint, slider colors, text colors) each with a "Default" auto option + a custom-hex swatch.
- **Accessibility** (`29.png`) — Right-Click to Hide/Reveal, Hold-to-Reveal, Haptic Feedback toggle, Hide from Screenshots.
- **License** (`30.png`) — same 3-state pattern Islet already has (Enter license / Trial Active countdown / Buy), just restyled — confirms Islet's existing LIC-01/02/03 model is already on the right track, this is a visual reference only.
- **About** (`30.png`-`31.png`) — version + changelog link, developer credit, a **replay-the-onboarding-intro button**, **Settings Export/Import**, a privacy block (Tracking off, "data stays on your Mac / on-device", explicit online-features opt-in), and a Hard Reset. Several of these (replay intro, settings export/import, explicit privacy stance) are cheap, high-trust additions worth considering for v1.4's onboarding/settings work.

## Weather widget reference (images 32-34, revised 2026-07-15 — second Phase 33 correction)

- `32.png` — originally logged as "Apple's own iOS Weather widgets." **Correction (2026-07-15, second round):** the user confirmed via direct screenshots (`33.png`, `34.png`) that this same design is the actual **macOS Weather.app widget** (verified via macOS's own "Edit Widgets" gallery, Neubrandenburg location) — iOS and macOS render this widget identically, so `32.png`'s structure was already accurate; it was mislabeled as iOS-only, not wrong in content.
- `33.png` (new) — macOS Weather.app "Standard" (Medium) widget, screenshotted directly from the user's Mac: location name + small arrow icon, big current temp on the left; on the right, top-aligned: a moon/condition icon, condition text ("Meist wolkenlos"), and an "H: T:" (Hoch/Tief) line. Below the header: an hourly row (4:00, 04:56, 5:00, 6:00, 7:00, 8:00 — note 04:56 is an exact-sunrise timestamp inserted between hours, not on-the-hour data; **out of scope to replicate**, use plain on-the-hour entries), each with icon + temp stacked underneath.
- `34.png` (new) — macOS Weather.app "Extended" (Large) widget: same header + hourly row, PLUS a daily forecast list (Do/Fr/Sa/So/Mo — weekday, icon, low temp dimmed-left, horizontal gradient range-bar, high temp bright-right). The "Vorhersage" title + description text below the card in this screenshot is the widget-gallery's own caption chrome, not part of the widget — do not replicate.
- **Real correction found this round:** the card's own **header layout** does not match what Phase 33 Plan 33-02 actually built. The built `weatherFullContent` is a single centered column (location → icon → temp → condition → H/L, stacked). The real widget's header is a **two-column split**: left column = location+arrow icon then large temp; right column (top-aligned, trailing) = condition icon + condition label + "H: T:" line. This was incorrectly assumed "already correct, keep verbatim" in the first correction round — needs rework.
- **Confirmed unchanged:** the hourly row and the Large daily range-bar list (already built in Plan 33-02 Tasks 1-3) structurally match `33.png`/`34.png` — no rework needed there.
- **Background:** the real widget has its own navy, time-of-day-tinted gradient card background. User decision (2026-07-15): Islet's Weather tab keeps its existing black/frosted glass chrome (same as Home/Tray/Calendar) rather than adopting Apple's per-widget gradient — avoids a new per-tab visual special case.

## Menu-bar dropdown (image 13, top)

`13.png` (top) — the status-bar menu itself: Now Playing + Source submenu, Trial/License row, Hide Notch, Check for Updates, then feature submenus (Cloud, Upcoming, Element Capture, Window Snap), Settings, Quit. Islet's own menu-bar dropdown is much sparser today (Settings…, Quit) — worth a light pass once the Settings redesign lands.
