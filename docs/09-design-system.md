# 09 — Design system

The look is **cozy pixel-art cottagecore farming game**: cream paper,
chocolate-brown wood, gold and leaf-green accents, a chunky pixel title
font, and friendly rounded body text. All tokens live in
`lib/theme/app_theme.dart`. **Never hard-code a colour or size in a
screen**; add a token instead.

For the owner's design philosophy (don't overdesign, environmental
storytelling, consistency, accessibility) see
[01-product-overview.md](01-product-overview.md#design-philosophy-owners-rules).

---

## 1. Colours (`AppColors`)

| Token | Hex | Use |
|---|---|---|
| `background` | #F3E8D2 | Cream page background (also the native splash colour) |
| `panelDark` | #3E2A1B | Darkest brown: header planks, outlines |
| `panelMedium` | #8B5A34 | Wood panels and buttons |
| `panelLight` | #B97A45 | Lit wood edge / highlights |
| `accentGold` | #E8B84B | Gold numbers, selected nav outline, "CHANGE" |
| `accentGreen` | #7CB350 | Leaf green: growth bars, plant labels |
| `greenDeep` | #4E7A2C | Dark green for text or shade on light backgrounds |
| `textCream` | #F3E8D2 | Text on dark wood |
| `textDark` | #3E2A1B | Text on cream/parchment |
| `textMuted` | #7A5E47 | Captions, secondary text |
| `parchment` | #F6DFC0 | Paper panels, scrolls, journal page |
| `parchmentShade` | #E2C69C | Paper shading, aged edges |
| `danger` | #CC6B5C | Give up / destructive button tone |
| `dangerText` | #B23B2E | Readable red text on parchment |
| `overlay` | #B3000000 | 70% black behind popups |

Other colours in use:
- `#DCEFC8`: the app-icon background (leaf-green tint).
- Card-design tints: see [08-business-rules.md](08-business-rules.md#8-player-card-designs-quests).
- Glass dark panel on the Timer: `#E63E2A1B` (panelDark with some
  transparency).

## 2. Typography (`AppText`)

Two fonts, loaded with `google_fonts`:

- **Press Start 2P** (pixel): titles, timers and big game moments only.
- **Nunito**: everything people actually read.

| Style | Font / size | Example |
|---|---|---|
| `screenTitle` | Pixel 15 | "COZY GREENHOUSE" |
| `gameMoment` | Pixel 12 | "You did it!", "Field Notes" |
| `timerLarge` | Pixel 40 | Timer countdown |
| `timerCompact` | Pixel 18 | Journal header countdown |
| `sectionLabel` | Nunito 13 w800, CAPS | "COZY SETTINGS" |
| `panelTitle` | Nunito 13 bold | Titles inside panels |
| `body` | Nunito 14 | Reading text |
| `small` | Nunito 12 w600 | Stats, secondary lines |
| `caption` | Nunito 11 w600 | Smallest allowed text |

**Never go below 11.**

## 3. Spacing, borders and sizes

- `AppSpacing`: xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32. Screen padding
  = 16 on all sides.
- `AppBorders`: width 2, radius 4. Pixel frames use stepped corners
  instead of a radius.
- `AppSizes`: minTouchTarget **48**, buttonHeight 52, bottomNavHeight 76,
  **artScale 2**.

## 4. Pixel-art rules

1. **1 art pixel = 2 dp** on screen (`AppSizes.artScale`). Always show art
   at whole multiples (×1, ×2, ×3…).
2. Scale with **`FilterQuality.none`** (nearest neighbour), never smoothed.
   `PixelSprite` does this for you.
3. Full-screen art: 208 × 448 px canvas, with a centre safe zone of
   180 × 360 (from REDESIGN_PLAN).
4. PNG with transparency, no anti-aliasing, no soft brushes.
5. **Code-drawn frames** (`PixelFramePainter`) match the owner's style:
   - a 1-art-pixel dark outline;
   - **stepped (cut) corners**;
   - a lit top/left edge and a shaded bottom/right edge;
   - optional nails (`PixelNail`).
6. Plant sprites are 128×128 with empty rows at the bottom, so shift them
   down about 0.19–0.22 × size to sit on a surface.
7. Code effects (sparkles, rays, petals, hearts) are drawn as squares on
   the pixel grid, never as smooth circles.

## 5. Component library (`lib/widgets/`)

| Component | Use it for | Notes |
|---|---|---|
| `PixelPanel(style: wood / dark / parchment)` | Any card/box | Replaces Material cards. `expand: false` for tags. |
| `PixelButton(tone: …)` | Primary actions | The owner's plaque art (96×48), 9-slice stretch zone x 50–79 so any label fits. Press nudge, disabled and loading states. |
| `PixelIconButton` | Back, pause, +/– | 48 dp minimum; needs a semantic label. |
| `PixelSectionHeader` | Section titles | |
| `PixelProgressBar` | Growth (segmented ×5), XP | |
| `StatPill` | Icon + number + label | Icon **and** text, not colour alone. |
| `PixelDialog` / `showPixelConfirm` / `showPixelMessage` | **Every** popup | Drawn as a `PixelScroll` with a `WaxSeal` (red / green / gold). Scales to fit any screen. |
| `PixelScroll` | Parchment scroll body | Wooden rods, aged paper, ragged edges drawn row by row. |
| `PixelBottomNav` | Home · Garden · Profile | Gold outline on the selected slot. |
| `PixelTimerDisplay` / `CompactTimerHeader` | Countdown | Wooden clock sign / journal header. |
| `PixelSprite` | Any art image | Nearest-neighbour; `silhouette` for locked items. |
| `SceneFrame` | Framed pictures (garden diorama, card cover) | Optional tint; gold frame variant. |
| `OwlSprite` / `OwlMascot` | kuwago | See §7. |
| `KuwagoLogo` / `PixelClock` | Wordmark | See §6. |

**Rules:**
- Popups never use a bare `AlertDialog`; always use `PixelDialog`.
- The overlay behind popups is `AppColors.overlay` (70% black).
- Layouts are tested at 360×640 and 390×844 with no overflow. Big art gets
  the leftover height (`Expanded`), so tall phones get bigger plants
  instead of empty space.

## 6. Brand

- **Wordmark "kuwaGO":** "kuwa" in dark brown, "G" in leaf green, and the
  final **O is a pixel clock** (`PixelClock`) whose hands spin while loading
  and rest at 10:10.
- **Tagline:** "★ PLANT EDITION ★" (keeping it is an open question).
- **App icon:** kuwago on #DCEFC8, generated by `tool/generate_icon.dart`.
  Adaptive icon foreground keeps the art in the centre 66%.
- **Native splash:** cream #F3E8D2 with the owl.

## 7. kuwago the mascot

- A 24×24 pixel owl stored as text rows in `lib/art/owl_art.dart`. The left
  half is written out and mirrored, plus optional branch rows for perching.
- `owlRows({look, blink, wingsUp, perch})`:
  - **Eyes:** 4×4 at x 5 and x 15, rows 7–10.
  - **Pupils:** 2×2 on rows 8–9, shifted by `look` (−1 left … +1 right).
  - Earlier versions looked grumpy or sleepy; the round eyes with centred
    pupils fixed that.
- **Behaviour** (`OwlMascot`):
  - idle: breathing bob and random blinks;
  - wanders or perches;
  - tap: flap (wings up), hop, pixel hearts, a speech bubble cycling
    through a list of lines;
  - `cheerLine` for events such as "Let's go!" when a session starts.
- **Placements now:** loading screen (watches the walking plant; "Tap me!"
  hint), login sign, Home windowsill (lines about your garden, see
  `_owlLines` in `home_screen.dart`), and the golden Player Card.
- **Voice:** cute and encouraging, with owl puns ("Hoo!", "Hoo-ray!").

## 8. Scenes and signature moments

| Moment | Design |
|---|---|
| Boot | **"Through the O"** on leaf green #DCEFC8 (the icon colour), with **no loading bar**. The **kuwaGO lockup** (`lib/art/wordmark_art.dart` → `widgets/kuwago_lockup.dart`) is a 2×-pixel wordmark k·u·w·a·G plus the clock O with kuwago perched on it, at 1.5 dp per pixel. **(1) On launch, Android 12+ plays it natively** (`res/drawable/splash_lockup_anim.xml`, 1 s): the minute hand winds one lap in 5-minute steps and kuwago bobs twice, ending on 10:10. **(2) Flutter** (`widgets/clock_intro.dart`): a faint pixel-leaf pattern fades in; the clock keeps ticking until the app is ready; **ding** (the hands sweep home, a bounce, 8 gold sparks); a **pixel circle with a gold rim opens out of the O** onto the app. **Continuation**: on Login the letters are pulled up out of view while kuwago flies to the hook on the pergola; the login page then takes over (see the Login row). On Home the letters float up and fade while kuwago flies in an arc to its windowsill, and the header, greenhouse and controls enter in turn. |
| Login | **Morning garden under a pergola** (`widgets/login_scene.dart`, `screens/login_screen.dart`): a warm sky fading to leaf green with the splash's leaf pattern; a sun rising over hills with round trees; drifting clouds; a wooden pergola with flowering ivy and two swaying flower pots; a white picket fence; a flowery meadow with bushes in the corners; butterflies and drifting leaves. **Entrance:** kuwago knocks the hook (it shudders, leaves shake loose, gold sparks). The **wooden kuwaGO sign** (cream-carved letters + clock O, "★ PLANT EDITION ★", an ivy sprig) drops on V-chains with a bounce and a small screen thump, then swings as a damped pendulum. kuwago lands on it with a squash ("Hoo! Welcome!"), the tagline line fades in, and a "★ JOIN THE GARDEN ★" ribbon + the Google / Create account / guest buttons rise in turn. **Tap kuwago**: it hops ("Hoo!") and the sign swings again. When there's no opening (e.g. after signing out), kuwago flies in from the top right first. |
| Home | Greenhouse window onto the meadow, wooden sill and planter, owl on the sill, seed tag in the corner. |
| Home → Timer | Window zoom (Option A): sashes swing open, plant ducks, the camera flies through the window into the meadow, the Timer fades in. Reversed on return. |
| Timer | Meadow background, wooden clock sign, glass-dark panels. |
| Journal | Wooden desk with a parchment page, a red margin line, ruled lines drawn in code. |
| Harvest | The owner's scroll art centred; turning golden rays, sparkles **outside** the frame, falling pixel petals; the bigger trophy plant; dark overlay. |
| Garden | Framed meadow diorama with a hanging "GARDEN ARCHIVE" sign, a fence, and a soil bed that scrolls sideways. |
| Profile | Player Card cover (the equipped design), avatar with a camera tag, badges. |

## 9. Art pipeline

- **Owner-drawn** (Figma mockups + Piskel): sunflower stages and frames,
  meadow background, plaque button, harvest scroll. **Owner art always
  wins** over code-drawn stand-ins.
- **Code-generated** (`tool/generate_plants.dart`, deterministic Dart): the
  cactus, fern and lily "in the style of" the sunflower, and wilted
  versions of all plants.
  - **Wilted art:** the plant slumps, the outer leaves droop and the top
    leans over. Greens dry out to olive-brown, yellows go dull, and pink
    and lavender fade. The owner's original stage art is never changed;
    only the `wilted/` folder is written.
  - Fixes made along the way: the fern was redrawn with chunky notched
    fronds (it was noisy) and the lily was given bigger blades and flower
    (it was thin).
- **Code-drawn UI:** frames, greenhouse, desk, diorama, particles, owl.
  These can be swapped for art from the checklist in
  [REDESIGN_PLAN.md](REDESIGN_PLAN.md) §5.
