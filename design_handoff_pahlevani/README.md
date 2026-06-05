# Handoff: Pahlevani — Training Companion UI

## Overview
Pahlevani is a training companion for **Varzesh-e Bastani** (traditional Persian
warrior fitness). Users follow structured sessions made of ordered exercises;
each exercise has a music track that drives the pace, and the app counts reps
and auto-advances through the session.

This package documents the **visual + interaction design** for three screens —
**Session List (home)**, **Player**, and **Edit/Create Session** — plus the
per-exercise **media** system (video / photo / drop-slot / pattern fallback).

---

## About the Design Files
The files in `reference_html/` are **design references built in HTML/React** —
a clickable prototype that shows the intended look, motion, and behavior. They
are **not production code to copy**. Your job is to **recreate these designs in
the existing Flutter / Material 3 app**, using its established widgets,
theming, state management, and data layer (Hive + Supabase, per the brief).

Treat the HTML as the source of truth for **layout, spacing, color, type, and
animation**, and this README as the spec that translates it into Flutter.

> To preview the prototype: open `reference_html/index.html` in a browser, or
> run any static server in that folder. Tap a session → Player. The ⋮ menu →
> Edit. There is a Tweaks panel logic in `app.jsx` (dark mode, card layout, rep
> feedback style, show-media) — those map to app settings / variants, not
> shippable UI.

---

## Fidelity
**High-fidelity.** Final colors, typography, spacing, radii, and interaction
timing are specified below and should be reproduced closely. Where this design
deviates from stock Material 3, it is called out explicitly under
**Material 3 notes**.

---

## Target stack & conventions
- **Flutter, Material 3** (`useMaterial3: true`). Build the palette below as a
  `ColorScheme` + custom `ThemeExtension` (see **Theming in Flutter**).
- **Desktop + Android** — no hover-only affordances; every action works on tap.
  Hover may *augment* (e.g. elevation) but never gate functionality.
- **Audio is the core.** The Player's timing math is audio-driven (see
  **Player → Playback logic**). Exercise media is **silent/visual only**.
- Keep **user-created vs server sessions** visually distinct (the "Yours" chip +
  delete affordance).

---

## Design Tokens

### Color — Light theme ("warm cream")
| Token | Hex | Use |
|---|---|---|
| `bg` | `#F4EDE0` | app background |
| `surface` | `#FFFDF7` | cards, sheets, dialogs |
| `surface2` | `#F6EEDE` | inset rows, icon buttons |
| `surface3` | `#EFE4CF` | track-number badge, steppers track |
| `onSurface` | `#2A2218` | primary text |
| `onMuted` | `#897C64` | secondary text |
| `onFaint` | `#B4A890` | tertiary text / disabled |
| `border` | `#E6D9C0` | input borders |
| `borderSoft` | `#EFE6D4` | card hairlines |
| `primary` | `#A9701F` | saffron gold — FAB, play button, active accents |
| `onPrimary` | `#FFFAF0` | text/icon on primary |
| `primaryBg` | `#F3E6CB` | gold accent surface (banners) |
| `secondary` | `#AD4527` | terracotta — difficulty pips, destructive |
| `secondaryBg` | `#F6DCCF` | terracotta accent surface |
| `teal` | `#2F7D72` | Persian-tile turquoise — "Yours", info |
| `tealBg` | `#D8ECE6` | teal accent surface |
| `repDefault` | `#2F7D52` | green — default rep count |
| `repDefaultBg` | `#D9ECDF` | green chip bg |
| `repCustom` | `#C2641F` | orange — customized rep count |
| `repCustomBg` | `#F6E3CD` | orange chip bg |
| `scrim` | `rgba(30,22,12,0.55)` | sheet/overlay scrim |

### Color — Dark theme ("deep warm") — DEFAULT
| Token | Hex | Use |
|---|---|---|
| `bg` | `#161109` | app background |
| `surface` | `#221A10` | cards, sheets, dialogs |
| `surface2` | `#2B2114` | inset rows, icon buttons |
| `surface3` | `#352915` | track-number badge, steppers track |
| `onSurface` | `#F1E7D4` | primary text |
| `onMuted` | `#AC9D80` | secondary text |
| `onFaint` | `#6F6249` | tertiary text / disabled |
| `border` | `#36291A` | input borders |
| `borderSoft` | `#2A2013` | card hairlines |
| `primary` | `#E0AA4C` | warm gold |
| `onPrimary` | `#1C1404` | text/icon on primary |
| `primaryBg` | `#3A2C14` | gold accent surface |
| `secondary` | `#DB7048` | terracotta |
| `secondaryBg` | `#3D2316` | terracotta accent surface |
| `teal` | `#59AB9C` | turquoise |
| `tealBg` | `#163029` | teal accent surface |
| `repDefault` | `#62C486` | green |
| `repDefaultBg` | `#16301F` | green chip bg |
| `repCustom` | `#E9924A` | orange |
| `repCustomBg` | `#3A2814` | orange chip bg |
| `scrim` | `rgba(8,5,2,0.66)` | overlay scrim |

The app supports **both themes via toggle**; **dark is the default** (better for
the immersive Player).

### Per-session accent
Each session declares an accent: **`gold`** (primary), **`terracotta`**
(secondary), or **`teal`**. The accent's `fg`/`bg` pair drives the card banner,
thumbnail, and the Player stage pattern. Map accent → the matching token pair
above.

### Typography
Three families (use Google Fonts packages or bundle):
- **Display** — `Lora` (serif). Screen titles, session/exercise names, dialog
  titles. Weights 600/700. Used at 30 (home title), 23–24 (exercise/dialog),
  17–22 (card titles).
- **UI** — `Plus Jakarta Sans`. All body, labels, meta, buttons. Weights
  400–800.
- **Farsi** — `Vazirmatn`. All Persian text (RTL). The Player shows the exercise
  name in Farsi at 40px/700; cards show the session's Farsi name.

| Role | Family | Size | Weight | Notes |
|---|---|---|---|---|
| Home title "Pahlevani" | Lora | 30 | 700 | letter-spacing -0.3 |
| Farsi home title | Vazirmatn | 20 | 600 | color = primary |
| Section label (uppercase) | Plus Jakarta | 12.5 | 700 | letter-spacing 0.6, uppercase, color onFaint |
| Card title (banner) | Lora | 22 | 600 | |
| Card title (compact) | Lora | 17.5 | 600 | ellipsis 1 line |
| Card description | Plus Jakarta | 13.5 | 400 | 2-line clamp, color onMuted, line-height 1.5 |
| Card meta (tracks/duration) | Plus Jakarta | 12.5 | 600 | color onMuted |
| Player exercise (Farsi) | Vazirmatn | 40 | 700 | line-height 1.1 |
| Player exercise (Latin) | Lora | 23 | 600 | |
| Player gloss | Plus Jakarta | 13 | 500 | color onMuted |
| Rep pill text | Plus Jakarta | 15 | 700 | |
| Track row name | Plus Jakarta | 14.5 | 600/700 | 700 when active |
| Track row gloss | Plus Jakarta | 11.5 | 500 | color onFaint |
| Rep chip / stepper number | Plus Jakarta | 11.5–14 | 700/800 | tabular figures |

### Spacing, radius, elevation
- **Screen padding:** 16–20px horizontal.
- **Card radius:** 24 (banner), 22 (compact). **Stage:** 26. **Sheets:** 26–28
  top corners. **Dialogs:** 26. **Inputs / track rows:** 14–16. **Chips/pills:**
  full (999).
- **Card gap in list:** 16.
- **Icon button:** 40–44 square, full-radius, `surface2` bg when filled.
- **FAB:** extended, height 56, radius 18, primary bg, label "New" + plus icon.
- **Play FAB (Player):** 68 square, radius 24, primary bg.
- **Shadows:**
  - card: `0 1px 2px rgba(60,45,20,.06), 0 6px 18px rgba(60,45,20,.07)` (light) /
    `0 1px 2px rgba(0,0,0,.3), 0 8px 22px rgba(0,0,0,.34)` (dark)
  - popover/FAB: `0 8px 30px rgba(40,28,12,.18)` (light) /
    `0 10px 36px rgba(0,0,0,.5)` (dark)

### Motion
- Standard easing: `cubic-bezier(0.4,0,0.2,1)`; emphasized:
  `cubic-bezier(0.2,0,0,1)` (Flutter: `Curves.easeOutCubic` /
  `Easing.emphasized`-like). Honor `prefers-reduced-motion` (Flutter:
  `MediaQuery.disableAnimations`).
- Bottom sheets slide up ~300–350ms emphasized; scrim fades 200–250ms.
- See **Player → Rep counter** for the signature animation.

---

## Screens / Views

### 1. Session List (Home)
**Purpose:** browse all sessions, manage download state, open the Player, create
or edit sessions.

**Layout (top → bottom):**
1. **Large-title header** (padding 12/20/8): row with
   - left: "Pahlevani" (Lora 30) + Farsi "پهلوانی" (Vazirmatn 20, primary) on a
     baseline-aligned row; subtitle "Varzesh-e Bastani · house of strength"
     (13, onMuted).
   - right: a circular **refresh** icon button (40²). Tapping spins it 360°
     (0.8s linear) and shows a "Syncing from Supabase…" caption while
     refreshing. This stands in for **pull-to-refresh** — in Flutter implement
     as `RefreshIndicator` on the list **and** keep an explicit refresh affordance
     for desktop.
   - A separate **theme toggle** icon button floats top-right (sun/moon).
2. **Scroll area** (padding 6/16, bottom 96 to clear the FAB):
   - Uppercase count label: "{n} sessions".
   - **Session cards** (gap 16). Two layouts (see below) — `banner` is default.
3. **Extended FAB** "＋ New" bottom-right (right 18, bottom 16).

**Card — BANNER layout (default):**
- Rounded 24 `surface` card, hairline border `borderSoft`, card shadow.
- **Banner strip** (height 104): accent-bg fill rendered with the **Persian
  star-lattice pattern** (see Assets) at ~0.5 opacity, plus a left-to-right
  `surface`→transparent gradient (~0.55) so text is legible. Inside:
  - bottom-left: "Yours" chip (if user-created) above the session title (Lora 22,
    `onSurface`).
  - top-right: session's Farsi name (Vazirmatn 19, accent fg).
- **Body** (padding 14/18/16):
  - description, 2-line clamp (13.5, onMuted).
  - **Meta row:** "⊟ {n} tracks" · "{duration}" · (spacer) · **difficulty pips**
    (5 small 7px diamonds rotated 45°; filled = secondary, empty = border).
  - **Action row:** download-status control (left) · (spacer) · ⋮ overflow (right).

**Card — COMPACT layout (variant):**
- Row card (radius 22, padding 12, gap 14): square **thumbnail** (92², radius 16,
  accent pattern fill, Farsi first-word centered) on the left; on the right:
  title + "Yours" chip + ⋮, 2-line description, then a footer row with meta +
  download control.

> Expose banner/compact as a **user preference** (e.g. a list-density setting),
> not a dev-only flag. Default = banner.

**Difficulty:** integer 1–5 rendered as 5 diamond pips. Reuse everywhere
(cards, edit screen).

**Download-status control** (per session) — a 34² circular button with three
states:
- `none`: `surface3` bg, onMuted **download** icon. Tap → start download.
- `downloading`: accent-bg, a **circular progress ring** (accent, r=14,
  stroke 2.4, rounded cap) sweeping with `progress` 0→1, plus a small square in
  center. Tap = no-op (in progress).
- `downloaded`: green `repDefaultBg` bg, green **check**. Tap → confirm/remove.
- Tapping toggles state. In Flutter, drive progress from your real
  download/Hive cache; the prototype fakes it on a timer (~3–4s).

**Interactions:**
- Tap card → push **Player** (auto-plays).
- Tap ⋮ → **overflow bottom sheet** (see Interactions).
- Tap download control → start/cancel/remove download.
- Refresh → re-fetch from Supabase (preserve user sessions via upsert).
- FAB → **New Session** (Edit screen in "new" mode).

---

### 2. Player  *(core experience — spend the most polish here)*
**Purpose:** play a session; show the current move; count reps; auto-advance.

**Layout (top → bottom, fixed regions; only the track list scrolls):**
1. **App bar** (compact): back arrow (44²) · two-line title block
   ("PLAY ALONG" overline 11/700/uppercase/onFaint + session title 15/700) ·
   **edit** icon button (opens Edit for this session).
2. **Media stage** (margin 16, radius 26, **height 232**, accent bg, hairline
   border). Tapping the stage **pauses/resumes**. Contents = the **Media system**
   (next section). Overlays:
   - exercise title block top-left (Farsi 40 + Latin 23 + gloss 13). Over real
     imagery the text is **white with shadow**; over the pattern fallback it uses
     accent fg / onSurface.
   - **paused overlay:** scrim + a 72² white circle with a primary play glyph.
   - **playing pill:** bottom-right `surface` pill with a 3-bar **equalizer**
     animation + "Pause" label.
   - **media-type badge:** top-right ("Demo" / "Photo" / "Add photo") when media
     exists.
3. **Rep counter** (centered, 16 below stage) — **the signature moment**, see below.
4. **Progress block** (padding 16/24/6): row of exercise name (13.5/700) +
   "m:ss / m:ss" (tabular, onMuted); then a 6px **linear progress** track
   (`surface3`) with a green (`repDefault`) fill, width = elapsed/total, eased
   ~0.12s linear.
5. **Track list** (scrolls, flex:1): one row per exercise:
   - position **number badge** (28², radius 9). Active row: badge = accent fg /
     onPrimary; else `surface3` / onMuted.
   - name (14.5; 700 + onSurface when active, else 600 + onMuted) and a gloss
     line that begins with a small **media glyph** (video/photo/＋) when the
     exercise has media.
   - **rep chip** "{n}×" — green if default reps, **orange if customized**.
   - active row shows a play/pause icon; row bg = `surface2`. Tapping a row jumps
     to that exercise. Auto-scroll the active row into view on change (use
     `Scrollable.ensureVisible` or an `ItemScrollController` — do **not** use a
     web-style scrollIntoView).
6. **Bottom transport** (centered, gap 28, with a bottom fade): **Previous**
   (52² `surface2`, up-arrow), big **Play/Pause FAB** (68², radius 24, primary),
   **Next** (52², down-arrow). Prev/Next disabled+dimmed at the ends. When the
   session is finished the FAB shows a **replay** icon.

**Rep counter — animation spec (build deliberately):**
A centered pill (`repDefaultBg`/green, or `repCustomBg`/orange if the current
exercise's reps are customized) containing a filled circular badge with the
current rep number, then "Rep {x} of {y}" (+ "· custom" when customized). On
**every rep change**, the design supports three feedback styles — ship the
**bold** one as default and consider the others as a setting:
- **bold** *(default):* the whole pill does a **scale pop** 1 → 1.28 → 1
  (~420ms emphasized) **and** a full-color **flash** overlay fades out
  (`currentColor`, opacity .85 → 0, ~500ms). Pair with a light **haptic**
  on mobile (`HapticFeedback.selectionClick` / `lightImpact`). Soft colored
  glow shadow under the pill.
- **pulse:** subtle scale 1 → 1.09 → 1 (~400ms), no flash.
- **minimal:** number changes, no transform.
In Flutter: an `AnimationController` keyed to the rep index; `ScaleTransition`
for the pop + an overlay `FadeTransition` for the flash. The rep value itself is
derived from elapsed time (below), so trigger the controller when the derived
rep integer increments.

**Playback logic (audio-driven — keep exactly):**
For each exercise: `perRep = audioDurationSeconds / repetitionsDefault`, and the
exercise's logical play time is `total = perRep * repsToDo`. The **audio loops**
if `repsToDo > default` and **cuts short** if fewer. The current rep is
`min(repsToDo, floor(elapsed / perRep) + 1)`. When `elapsed >= total`,
**auto-advance** to the next exercise (reset elapsed to 0); at the end of the
last exercise, stop and show the **completion sheet**. The visual demo media is
**muted** and merely synced to play/pause — the audio track is the sound.

**Persist playback position:** store `{exerciseIndex, elapsed}` per session
(e.g. Hive) and restore on reopen, so a refresh/relaunch resumes in place.

**Completion sheet:** bottom sheet with a gold accent banner ("خسته نباشی"),
"Session complete" (Lora 24), a line "You moved through all {n} exercises of
**{title}**. Khaste nabâshi — may you never tire.", and two buttons: "Done"
(secondary) and "Again" (primary, replay).

---

### 3. Edit / Create Session
**Purpose:** create a custom session, or edit one. Editing a **server** session
creates a **user-owned copy** (does not mutate the original); editing your own
updates in place.

**Layout:**
1. **App bar:** close (✕) · title ("New session" / "Edit a copy" / "Edit
   session") · **Save** button (primary pill; disabled until title non-empty and
   ≥1 exercise).
2. **Scroll body** (padding 16/18/40):
   - If editing a server session: an **info banner** (teal) — "This is a built-in
     session. Saving creates your own editable copy — it won't change the
     original."
   - **Title** — text field.
   - **Description** — 3-line textarea.
   - **Difficulty** — 5 tappable diamond buttons (30², rotate 45°) + "{n} / 5".
   - **Exercises** section: header "Exercises · {n}" + hint "drag to reorder".
     Each exercise is a **68px-tall row** (`surface2`, radius 16, border): a
     **drag handle** (6-dot grip) on the left, name + Farsi + gloss in the
     middle, and a **rep stepper** on the right.
   - **Rep stepper:** pill (`repDefaultBg`/green or `repCustomBg`/orange) with
     −, the number (tabular, tap to **reset to default** when customized), +.
     Clamp 1–99. Color is green at the exercise default, **orange when changed**.
   - footer legend explaining green vs orange.

**Drag-to-reorder:** in Flutter use `ReorderableListView` (works with mouse drag
on desktop and long-press/handle drag on Android). The prototype uses pointer
math with a fixed 68px row height; you don't need to mirror that — use the
native reorderable list with the drag handle as `ReorderableDragStartListener`.

**Save behavior:**
- New / editing-a-server-session → create a new **user-owned** record
  (`isUserCreated = true`), insert at top of "Yours", mark as downloaded, sync
  (upsert) to Supabase, return to list with a confirmation snackbar.
- Editing your own → update in place.

---

## The Media System (per-exercise photo / video)
Each `Exercise` carries a `media` descriptor with a **type**:
- **`video`** — a looping, **muted**, `playsInline` clip showing the move. Synced
  to the Player's play/pause (`v.play()/pause()`); never carries audio. Flutter:
  `video_player` with `setVolume(0)`, `setLooping(true)`, play/pause tied to
  session state. Use `poster` as the first frame.
- **`photo`** — a cover still. The Player adds a slow **ken-burns** drift
  (scale 1.02 → 1.13 over ~14s alternating) while playing. Flutter: `Image` in a
  subtle `ScaleTransition`.
- **`slot`** — placeholder/empty state (no asset yet) shown as a dashed-ring
  **"add photo"** affordance in the prototype. In the app this is just the
  **empty state** for an exercise with no media → show the pattern fallback and
  optionally an "add media" action in Edit.
- **`none`** — no media → **Persian star-lattice pattern** on the accent bg
  (the fallback you see on Niyâyesh/Payâni). ~half the library has no asset yet,
  so this is a first-class state.

**Legibility:** when media is real imagery, draw a top+bottom **scrim gradient**
(`rgba(8,5,2,.45)` top → transparent → `rgba(8,5,2,.72)` bottom) under the
title/controls so text stays readable. Over the pattern fallback, use a radial
vignette to `bg` instead.

**Track rows** show a small **media glyph** (video camera / photo / plus) next to
the gloss so media availability is scannable.

**Data model addition:** add `media: { type, src, poster }` to your `Exercise`
entity (Hive + Supabase). `type ∈ {video, photo, none}`; `src`/`poster` are URLs
(nullable). Treat missing/empty `src` as `none`.

---

## Theming in Flutter (suggested)
1. Build two `ColorScheme`s from the token tables (or a seed + overrides).
2. Put the **non-Material** tokens (`teal`, `repDefault/Custom` + their bgs, the
   accent pairs, `surface2/3`, `onMuted`, `onFaint`, scrim) in a
   `ThemeExtension<PahlevaniColors>` so widgets read them off `Theme.of(context)`.
3. Register the three font families in `pubspec.yaml`
   (`Lora`, `Plus Jakarta Sans`, `Vazirmatn`) and wire a `TextTheme` from the
   typography table. For Farsi, set `TextDirection.rtl` and the Vazirmatn family.
4. Default `themeMode` = dark; expose a toggle (the home moon/sun button) backed
   by a persisted setting.

## Material 3 notes / deviations
- **Cards** use custom radii (22/24) and hairline borders rather than stock M3
  elevation — keep the warm, low-contrast look.
- The **Player stage**, **rep pill**, **download ring**, **diamond difficulty
  pips**, and the **6-dot drag grip** are bespoke — recreate as custom widgets /
  `CustomPainter`, not stock components.
- The **extended FAB**, **bottom sheets**, **dialogs**, **text fields**,
  **snackbars**, **linear/circular progress**, and **reorderable list** should be
  the standard M3 widgets, restyled via theme.

## Interactions & Behavior (summary)
- **Overflow bottom sheet** (from ⋮): rows — *Edit session* / *Edit a copy*,
  *Download* / *Downloading…* / *Remove download*, and *Delete* (only for
  user-created; destructive/secondary color). Drag-handle at top, scrim behind.
- **Delete** → confirmation dialog ("Delete "{title}"? … can't be undone"),
  destructive confirm.
- **Snackbars/toasts** for download start/finish, save, delete (dark pill,
  ~2.2s).
- **Empty/disabled** states: Save disabled until valid; transport ends disabled.
- **Loading:** refresh spinner + caption; download progress ring.

## State (summary)
- `sessions` (server + user, merged; user survive refresh via upsert).
- per-session `download = {state, progress}`.
- Player: `{exerciseIndex, elapsed, playing, finished}` (persist index+elapsed).
- Edit: working copy of `{title, description, difficulty, items[]}`; each item
  `{exerciseId, reps}` (reps default vs custom drives green/orange).
- Settings: `themeMode`, list density (banner/compact), rep-feedback style.

## Assets
- **Persian star-and-cross lattice pattern** — generated as line-art SVG in
  `helpers.jsx` (`PersianPattern`): a 16-point star tessellation (star at each
  corner + center, diamonds on edges), stroked in the accent color at low
  opacity. Recreate in Flutter as a tiling `CustomPainter` (draw the star/diamond
  paths, `Paint..style = stroke`, repeat across the canvas) — see
  `starPath()` / `diamond()` in `helpers.jsx` for the exact geometry.
- **Icons** — simple Material-style line glyphs (`ICONS` map in `helpers.jsx`);
  use Flutter's `Icons` equivalents (arrow_back, more_vert, play/pause, expand_*,
  check, close, edit, delete, add, refresh, download, list, bolt, air).
- **Exercise media** — none bundled (placeholders today). Wire `media.src` per
  exercise when assets exist.
- **Fonts** — Lora, Plus Jakarta Sans, Vazirmatn (Google Fonts).

## Files (reference prototype)
In `reference_html/`:
- `index.html` — entry; loads everything.
- `theme.css` — **all design tokens** (both themes) + keyframes (rep pop/flash/
  pulse, ken-burns, sheet/scrim). Best single source for exact values.
- `data.js` — sample sessions + the exercise library incl. the `media` field and
  the audio-duration/rep numbers used for timing.
- `SessionList.jsx` — home, both card layouts, download control, difficulty.
- `Player.jsx` — Player incl. rep counter, transport, completion sheet.
- `MediaStage.jsx` — the per-exercise media system + scrim + glyphs.
- `EditSession.jsx` — edit/create incl. reorder + rep steppers.
- `helpers.jsx` — `PersianPattern` geometry, icon paths, difficulty pips, clock.
- `Shell.jsx` — device frame (status bar etc.) — **ignore for the app**, it's
  only to make the prototype look like a phone.
- `app.jsx` — routing, download lifecycle, overflow sheet, dialogs, toasts, the
  variant flags (theme/density/rep-fx/show-media).

---

### Suggested prompt to start Claude Code
> "Read `design_handoff_pahlevani/README.md` and the `reference_html/` files.
> Implement the Session List, Player, and Edit Session screens in our existing
> Flutter / Material 3 app, following our current architecture (Hive + Supabase,
> our routing and theming). Start by adding the color tokens as a ThemeExtension
> and the three fonts, then build the Player first (it's the core experience),
> matching the rep-counter animation and audio-driven timing exactly. Add the
> `media` field to the Exercise model. Ask me before introducing new packages."
