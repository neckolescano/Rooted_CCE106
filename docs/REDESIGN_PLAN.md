# Study Buddy — Plant Edition · Redesign plan

Written 2026-09-28 from the code at commit `9b7bc05` and the 7 phone screenshots.
This is the reference for the redesign. The **artwork checklist (§5)** is the part to draw from.

---

## 1. What is already good (keep it)

- **The identity.** Cream + chocolate brown + gold/green, Press Start 2P titles, Nunito body text, and cozy farming words ("COZY GREENHOUSE", "SESSION EN ROUTE"). That's a real style already.
- **Your art.** The plant stages and 10-frame growth transitions, the wooden plaque button, the meadow background and the harvest scroll.
- **The core loop works end to end:** study → grow a stage → harvest → the plant lands in the garden row.
- **The timer screen** is the strongest screen: the meadow scene shows through and the plant sits in the world.
- **The architecture is sound.** One global `SessionModel` means Notes never creates a second timer. There is one `StorageService` for data (local + Firestore), and all colors are in `app_theme.dart`.
- **`PixelButton` 9-slice.** The label stretches only the plain wood, so any label length works. We keep this technique for every frame.

## 2. What needs improvement

### Visual
| Where | Problem |
|---|---|
| Home, Login, Garden, Profile | Big empty cream areas. Only the Timer has a scene behind it, so the screens feel like they were designed separately. |
| All panels | `PixelPanel` is a flat Material box with 4px rounded corners and a 2px border. It isn't pixel art, so it clashes with the wooden plaque buttons. |
| Home | "LVL 3 GROW" means *plant stage 3*, which will collide with a real garden level later. The plant floats in a flat box instead of a planter. |
| Garden | The plant tiles are tiny (a 128px sprite squeezed into 48px). "Grown: 1 plants" grammar. The species list is fake ("Wild Sunflower ×2" while only 1 plant is grown). The bottom half is empty. |
| Garden | "Streak: 6 **days**" actually counts sessions in a row. |
| Completion popup | The overlay is too light (the timer, Pause and Give Up show through). The body text runs past the parchment's right edge ("lives in" is clipped). Green pixel text on tan is hard to read. The banner overlaps the timer panel. |
| Login | Generic Material flower icon, a plain "G" instead of the Google logo, and a large empty middle. |
| Notes | Looks like a plain white text box, not a journal. The error message is raw text. |
| Profile | The avatar is a Material icon. The Push toggle and "About" do nothing. |
| Pixel scale | Buttons show at ~1 dp per art pixel, plants at ~1.7, garden tiles at ~0.4. Mixed scales make art look like it came from different games. See the scale rule in §5. |

### Behavior / bugs found while reading the code
1. **The Android back button during a session leaves the timer running with nobody listening.** Completion logic lives in `TimerScreen`. If you press back, the countdown still finishes but the plant never grows, and the next "Start Study Session" silently restarts the timer. (Fixed in Phase 4/5 by moving completion handling out of the screen.)
2. **The timer counts down with `Timer.periodic`.** It drifts, and it stops or resets if the app is killed or put in the background.
3. **Give Up has no confirmation.** One accidental tap wilts the plant.
4. **`memberSinceYear` is never uploaded** (it's missing from `_snapshot()` in `storage_service.dart`). After a reinstall, "Cozy member since" resets to the current year.
5. **Only one kind of total exists.** `totalSessions` counts failed attempts too, so there's no count of *completed* sessions to base unlocks on.
6. **Test setting:** `sessionLengthSeconds = 10`. This goes away naturally once custom durations exist.
7. **App name:** The launcher label and `MaterialApp.title` say "rooted", the screens say "STUDY BUDDY", and the course title says "Rooted". Pick one name for the splash screen and icon (Phase 14).

## 3. What stays unchanged
- The palette values (we only *add* shades), both fonts, and the cozy wording.
- The Home · Garden · Profile bottom nav, its order, and its gold selected outline.
- The plaque button art and its 9-slice stretch zone.
- Plant sprite format: 5 stages × 128×128 plus 4 transitions × 10 frames.
- The harvest scroll art and the "Start New Session / Go Home" choice.
- `SessionModel` as the ONE global timer. `NotesModel` at the root. The `StorageService` two-layer design.
- The Firestore shape `users/{uid}` (we add fields and sub-collections; nothing is renamed).
- Firebase AI Logic with no API key in the app.

---

## 4. Screen-by-screen redesign

Every screen uses the same **layered scene**:
```
BACKGROUND   full-screen art (sky / greenhouse wall)
MIDGROUND    same-size transparent PNG (shelves, trees, fences)
FOREGROUND   same-size transparent PNG, kept to the bottom corners (flowers, rocks, tools)
UI           panels and buttons, only inside the "UI safe zone"
```
All three art layers use the **same canvas size**, so they always line up (see §5).

### Login
Meadow sky → a greenhouse cottage in the midground → flowers in the foreground. A pixel logo replaces the Material icon. Buttons stay where they are. The empty middle shows the cottage scene instead of blank cream.

### Home — "COZY GREENHOUSE"
```
[ COZY GREENHOUSE          GARDEN LV 2 ]   ← dark header plank
[ ★ XP ███████░░  🔥 3-day streak     ]   ← one slim row, not a dashboard
        (greenhouse interior scene)
            [ plant on a planter ]
SEED · SPROUT · GROWING · BLOOM · GROWN    ← 5-segment pixel progress bar
"It's really taking shape — keep it up."
[        START STUDY SESSION        ]      ← or RETURN TO SESSION if one is running
```
"LVL" now means **garden level**. The plant's own progress is the segmented bar.

### Session setup — "SET YOUR GROWTH TIME" (new)
A potting-bench scene with three wooden steppers:
`FOCUS [-] 25 min [+]`, `BREAK [-] 5 min [+]`, `ROUNDS [-] 4 [+]`, plus an optional field "What are you studying?" and **[ START GROWTH ]**.
Ranges: focus 5–60 (steps of 5), break 1–15, rounds 1–8. The last choices are remembered.

### Timer — "SESSION EN ROUTE"
```
[ SESSION EN ROUTE ]              [ ✎ NOTES ]
   ┌─ wooden clock sign ─┐
   │       18:42          │         ← biggest thing on screen
   └──────────────────────┘
   Studying: Computer Networks
   ROUND 2 / 4   ·   GROWTH ████████░░ 80%
            (plant in the meadow)
[ PAUSE ]                         [ GIVE UP ]
```
During a **break**, the sign reads "REST TIME", the plant doesn't grow, and Give Up doesn't wilt. The back button now *minimizes* the session: Home shows "RETURN TO SESSION" and the timer keeps running.

### Notes → "PIXEL JOURNAL"
Parchment page on a wooden desk. Header: `← BACK   🌱 ROUND 2   ⏱ 18:42 ⏸`. A title line, then the writing area drawn *on* the page (ruled lines drawn in code so they match the text height). Bottom: **[ SAVE NOTE ]** and **[ ✨ AI STUDY TOOLS ]**. The page scrolls and resizes when the keyboard opens, so the keyboard never covers the text.

### AI study tools (bottom sheet from the journal)
A little **garden companion sprite** (your design) with 5 wooden options:
✨ Study Questions · 🌱 Flashcards · 📖 Summarize · 🔑 Key Concepts · 💡 Explain a Topic.
While it's working, the companion plays a "thinking" loop instead of a spinner.

### Study questions
Setup: `HOW MANY?  [5] [10] [15]`, `STYLE  [Mixed] [Multiple choice] [True/False]`, `DIFFICULTY  [Easy] [Normal] [Hard]` → **[ GROW QUESTIONS ]**.
Quiz: `QUESTION 1 / 5` with a progress bar, answer tiles, then **[ CHECK ANSWER ]**. Correct shows "CORRECT! 🌱 Your knowledge is growing!" with leaf particles. Wrong shows "NOT QUITE! Let's learn this one again." with a small shake and the explanation.
End: **STUDY PATCH COMPLETE**, `4 / 5`, then **[ REVIEW MISSED ]** and **[ RETURN TO GARDEN ]**.
*Short-answer questions are left out on purpose:* the app can't reliably grade free text offline. Multiple choice plus true/false can be auto-scored.

### Flashcards
One collectible card in the center that flips when tapped (3D Y-axis flip). Below it: `← PREV   3 / 12   NEXT →`, then `🌱 LEARNED` and `↺ REVIEW AGAIN`. The finish screen shows how many you learned and offers to shuffle the review pile again.

### Summary / Key concepts / Explain
One shared "reading scroll" screen: a parchment panel showing the result as bullets or term → definition, with a **Copy to journal** button.

### Garden — "GARDEN ARCHIVE"
```
[ GARDEN ARCHIVE                  LV 2 ]
[ XP ██████░░ 60/100   NEXT UNLOCK: 10 sessions → Desert Cactus ]
[ 🔥 3 days · 12 sessions · 4 plants   ]   ← small stat pills
YOUR GARDEN     (grid of soil plots, 4 columns, one grown plant per plot)
COLLECTION      (species cards: sprite or dark silhouette if locked, name, rarity, ×count)
```
Tap a plant to open a detail card: name, category, rarity, date grown, sessions it took.

### Profile — "PLAYER CARD"
Avatar in a wooden frame, name, email, "Cozy member since 2026". One row of 4 stats: garden level, focus sessions, plants grown, streak. Below that, **COZY SETTINGS** as it is now (Push Reminders works or is removed, About opens a real page, username becomes editable).

### Completion
Dark translucent overlay (~70% black) so the meadow is still faintly visible. The scroll is sized to fit any phone (it scales to available height). Text stays inside the parchment, with the "You did it!" line in dark brown pixel font. Sparkles and leaf particles play for ~1.5s, then settle. The XP gained is shown: `+50 XP`.

---

## 5. Artwork checklist

### The scale rule (read first)
**Draw so that 1 art pixel = 2 dp on screen**, and always display at whole multiples (×1, ×2, ×3). Most phones are 360–412 dp wide, so:

- **Full-screen layers: 208 × 448 px canvas.** Keep important things inside the center **180 × 360** "safe zone". Edges get cropped on some phones.
- UI frames (9-slice) should be small, since only their corners are shown at full size.
- Existing art: plants (128×128) will show at 256 dp on Home/Timer. That's a clean ×2, so they already fit. The plaque button (96×48) is currently shown ~×1. **Optional:** redraw it at 96×24 so it matches ×2. Not urgent; everything works without it.
- Export PNG with transparency, no anti-aliasing, and no soft brushes.

Legend: **P1** = needed for the next phase or two · **P2** = later phases · **opt** = nice to have.

### UI kit (used on every screen)
| Name | Purpose | Size (art px) | Where | Layer | Animation | Pri |
|---|---|---|---|---|---|---|
| `panel_wood.png` | Brown card (9-slice) | 24×24, 8px corners | Every card | UI | none | P1 |
| `panel_dark.png` | Dark header plank (9-slice) | 24×24, 8px corners | Header bars, timer chips | UI | none | P1 |
| `panel_parchment.png` | Light paper panel (9-slice) | 24×24, 8px corners | Journal, quiz, AI results | UI | none | P1 |
| `button_plaque.png` | Primary button | 96×48 (exists) | Everywhere | UI | none | ✓ |
| `button_plaque_pressed.png` | Pressed state (same art, 1px lower, slightly darker) | 96×48 | Everywhere | UI | swap on press | opt |
| `button_square.png` | Small square wood tile for icon buttons | 16×16 (9-slice, 5px corners) | Back, pause, +/- steppers | UI | none | P1 |
| `bar_frame.png` + `bar_fill_green.png` + `bar_fill_gold.png` | Progress bar (9-slice frame, tiling fill) | frame 16×8, fill 4×4 | Growth bar, XP bar, quiz progress | UI | none | P1 |
| `nav_bar.png` | Wooden plank behind the bottom nav | 208×40 | Bottom nav | UI | none | P2 |
| `nav_slot_selected.png` | Selected menu-slot frame (9-slice) | 16×16 | Bottom nav | UI | none | P2 |
| Icon set (16×16 each) | home, leaf, person, quill, back, pause, play, plus, minus, flame, star, clock, check, cross, sparkle, book, key, bulb, cards, question, bell, info, door | 16×16 | Everywhere | UI | none | P2 (Material icons until then) |

### Login
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `login_bg.png` | Sky + distant hills | 208×448 | Background | opt: 2 drifting clouds (separate 32×16 sprites) | P2 |
| `login_mid.png` | Greenhouse cottage + fence, centered in the safe zone | 208×448 transparent | Midground | none | P2 |
| `login_fg.png` | Flowers and grass in the bottom corners only | 208×448 transparent | Foreground | opt: 2-frame sway | P2 |
| `logo.png` | Replaces the Material flower icon | 64×64 | UI | opt: 4-frame sprout wiggle | P2 |
| Google "G" | **Use Google's official logo file**, not redrawn (brand rules) | — | UI | — | P2 |

### Home
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `greenhouse_bg.png` | Glass wall and window with sky behind it | 208×448 | Background | none | P1 |
| `greenhouse_mid.png` | Side shelves with pots, hanging plants at the top corners | 208×448 transparent | Midground | opt: hanging plants 2-frame sway | P1 |
| `greenhouse_fg.png` | Watering can (bottom-left), tool crate (bottom-right) | 208×448 transparent | Foreground | none | P1 |
| `planter_box.png` | Wooden planter the main plant sits in | 96×24 | UI (under the plant) | none | P1 |

### Session setup
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `potting_bench_bg.png` | Potting bench scene (or reuse the greenhouse, dimmed) | 208×448 | Background | none | opt |
| `seed_packet_<species>.png` | Seed packet shown when picking what to plant | 32×48 per species | UI | none | P2 |

### Timer
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `garden_meadow.png` | Meadow scene | exists (736×1308) | Background | none | ✓ |
| `timer_sign.png` | Wooden clock sign behind the countdown (9-slice) | 48×32, 10px corners | UI | none | P1 |
| `meadow_fg.png` | Grass/flowers strip in the bottom corners | 208×448 transparent | Foreground | opt: 2-frame sway | opt |
| `meadow_break_bg.png` | Evening/tea-time version of the meadow for breaks | 208×448 | Background | none | opt |

### Journal (Notes)
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `desk_bg.png` | Wooden desk top | 208×448 (or 32×32 tiling) | Background | none | P1 |
| `journal_page.png` | Paper page (9-slice; ruled lines are drawn in code) | 32×32, 10px corners | UI | none | P1 |
| `journal_deco.png` | Quill + pressed flower in a top corner | 32×32 | Foreground | none | opt |
| `companion_idle.png` | AI garden companion (bee, mushroom or sprout spirit — your pick) | 32×32 × 4 frames (strip 128×32) | UI | idle bob | P2 |
| `companion_think.png` | Companion "thinking" (AI loading) | 32×32 × 4–6 frames | UI | loop | P2 |

### Quiz
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `answer_tile.png` / `_selected` / `_correct` / `_wrong` | Answer tiles (9-slice) | 16×16 each, 5px corners | UI | none | P2 |
| `badge_correct.png` | Sprout icon for CORRECT | 32×32 | UI | opt: 3-frame pop | P2 |
| `badge_wrong.png` | Droopy leaf for NOT QUITE | 32×32 | UI | none | P2 |
| `banner_patch_complete.png` | "STUDY PATCH COMPLETE" ribbon (or use the pixel font in code) | 128×32 | UI | none | opt |

### Flashcards
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `card_front.png` | Collectible card frame, front | 96×128 | UI | flip in code | P2 |
| `card_back.png` | Card frame, back (answer side) | 96×128 | UI | flip in code | P2 |
| `stamp_learned.png` | "Learned" stamp | 24×24 | UI | none | opt |

### Garden
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `garden_bg.png` | Fenced meadow bed | 208×448 | Background | none | P2 |
| `soil_plot.png` | One grid cell a grown plant sits on | 32×32 | UI | none | P2 |
| New species | For each: `stages/` (5 × 128×128) + `frames/` (4 × 10 × 128×128), same format as now | 128×128 | UI | growth frames | P2 (one species at a time) |
| `rarity_<common/uncommon/rare/legendary>.png` | Small gem next to the name | 8×8 each | UI | none | opt |

Locked species use a dark silhouette made in code from the grown sprite, so no extra art is needed.

### Profile
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `cottage_bg.png` | Cozy cottage interior | 208×448 | Background | none | opt |
| `avatar_frame.png` | Wooden round/square frame | 48×48 | UI | none | P2 |
| `avatar_<n>.png` | 3–6 gardener avatars to choose from | 32×32 each | UI | none | opt |

### Completion / effects
| Name | Purpose | Size | Layer | Animation | Pri |
|---|---|---|---|---|---|
| `harvest_frame.png` | Scroll popup | exists 144×192 | UI | none | ✓ |
| `particle_leaf.png` | Falling leaves | 8×8 × 3 variants | Effect | code-driven motion | P2 |
| `particle_sparkle.png` | Twinkle | 8×8 × 4 frames | Effect | loop | opt (code sparkles exist) |
| `particle_xp.png` | XP star | 8×8 | Effect | code-driven | opt |

### Splash / app icon
| Name | Purpose | Size | Pri |
|---|---|---|---|
| `app_icon.png` | Launcher icon: draw at 32×32 or 64×64, export upscaled to **1024×1024** | 1024×1024 | P2 |
| `app_icon_fg.png` | Android adaptive icon foreground; keep the art inside the center 66% | 432×432 transparent | P2 |
| `splash_logo.png` | Centered on the splash screen | 64×64 (shown ×3) | P2 |

---

## 6. Reusable widgets (`lib/widgets/pixel/`)

Your list had some overlap (PixelButton vs WoodButton, PixelPanel vs WoodPanel vs GardenCard). One widget with **variants** keeps the styling in one place:

| Widget | Replaces / covers | Notes |
|---|---|---|
| `PixelPanel(variant: wood / dark / parchment)` | PixelPanel, WoodPanel, GardenCard | Uses the 9-slice art when present, otherwise a code-drawn square border with notched pixel corners |
| `PixelButton(variant: primary / secondary / danger)` | PixelButton, WoodButton | Existing plaque. Adds a 2dp press nudge, disabled state and a loading label. Existing call sites keep working |
| `PixelIconButton` | back, pause, +/- | Square wood tile, 48dp minimum touch target, required semantic label |
| `PixelSectionHeader` | "COZY SETTINGS", "YOUR GARDEN" | One style for every section title |
| `PixelProgressBar(segments?)` | growth, XP, quiz progress | Segmented (5 plant stages) or continuous |
| `PixelStepper` | session setup | `[-] 25 min [+]` |
| `PixelChoiceChips` | quiz setup | [5] [10] [15] etc. |
| `PixelDialog` | completion, confirmations, sign-out | Dark overlay + frame, always fits the screen (scrolls if tiny) |
| `PixelToast` (PixelNotification) | "Round complete!", errors | Small wooden banner that slides in from the top |
| `PixelBottomNav` | `MainShell` nav | Pulled out of `main_shell.dart` unchanged, then skinned |
| `PixelTimerDisplay` | Timer sign + compact journal header | One widget, `large` / `compact` sizes |
| `PixelPlantCard` | Garden grid + collection | Sprite, name, rarity, ×count, locked silhouette |
| `SceneLayout` | `BackgroundScene` | background / mid / foreground layers + UI safe area; gradient fallback if art is missing |
| `StatPill` | streak, sessions, plants | Icon + number + label |

## 7. New screens
`SessionSetupScreen` · `JournalScreen` (replaces `notes_screen`) · `AiToolsSheet` · `QuizSetupScreen` · `QuizScreen` · `QuizResultsScreen` · `FlashcardsScreen` (replaces `study_material_screen`) · `AiReadingScreen` (summary, concepts, explain) · `PlantDetailSheet` · `SeedPickerSheet` · `AboutScreen` · `SplashScreen` (native splash).

## 8. New / changed data models
```
SessionConfig      focusMinutes, breakMinutes, rounds, taskLabel
SessionModel       + phase (focus | rest | finished), round, endsAt, pausedRemaining
ActiveSession      the above, saved to SharedPreferences so a killed app can resume
PlantSpecies       id, name, category, rarity, unlockAtSessions, assetRoot, blurb   (const catalog in code)
GardenPlant        id, speciesId, harvestedAt, sessionsSpent                         (one per harvest)
PlayerStats        completedSessions, totalFocusMinutes, dayStreak, bestStreak, lastStudyDay
GardenProgress     level, xp, xpForNextLevel, nextUnlock   (calculated from PlayerStats, never stored)
Note               id, title, body, sessionId?, createdAt, updatedAt
QuizOptions        count, style, difficulty
StudyQuestion      exists: question, type, choices, answer, explanation
QuizAttempt        questions, chosenAnswers, score
Flashcard          exists: front, back   (+ learned flag held by the flashcard screen)
NoteSummary        oneLiner, bullets
KeyConcept         term, definition
TopicExplanation   title, explanation, example
```
Firestore additions (current rules already cover `users/{uid}/**`):
```
users/{uid}   + completedSessions, totalFocusMinutes, dayStreak, bestStreak, lastStudyDay,
                currentSpeciesId, memberSinceYear (bug fix)
users/{uid}/garden/{id}   GardenPlant
users/{uid}/notes/{id}    Note
```
Migration: existing users get `harvestedPlants` legacy Wild Sunflower entries in their garden, and their single `notes` field becomes their first journal note. Nothing is lost.

## 9. AI architecture (Phase 7+, when you have stable internet)
- Keep `firebase_ai` + App Check. **No API key in the app.**
- `AiService` gets 5 public methods: `generateStudyQuestions(notes, options)`, `generateFlashcards(notes)`, `summarizeNotes(notes)`, `extractKeyConcepts(notes)`, `explainTopic(topic, notesContext)`.
- Each method is a **prompt builder** + a **JSON parser** into the models above, sharing one private `_askForJson()` that handles the timeout (40s), one automatic retry on network errors, and error mapping into a friendly `AiFailure` type (offline, timeout, quota, App Check, bad response, empty notes).
- Parsers never throw on bad data. Bad items are dropped, and if nothing usable is left the user sees "NOT QUITE — the companion got confused. Try again?". **An AI failure can never crash the app.**
- Model name stays one constant in `ai_service.dart`.

## 10. Timer / Notes architecture
- `SessionModel` stores **`endsAt`** (a timestamp) instead of counting down. The number on screen is `endsAt - now`, so it can't drift and is correct after the app sleeps.
- The active session is saved to SharedPreferences whenever it changes. When the app opens: if the session ended while the app was closed, it counts as completed (the plant grows); if it's still running, the app goes back to it.
- **Completion handling moves out of `TimerScreen`** into a root-level `GardenController` that listens to `SessionModel`. Growing, recording and harvesting happen no matter which screen is open (fixes bug #1). `TimerScreen` only *plays the animation* when it's visible. If you were in the journal, a toast says "Round complete — your plant grew!" and the animation plays when you return.
- **Growth rule:** each completed *focus round* grows one stage. Seed → Grown is 4 stages, so **the default 4-round session grows one whole plant**. Breaks never grow or wilt.
- Journal notes are saved per session (a `Note` gets a `sessionId`). Typing saves locally right away and to the cloud after 1s, as it does now.
- Optional later: `flutter_local_notifications` for "Your round is done" while the app is in the background.

## 11. Garden progression architecture
- **XP:** +10 per completed focus round, +50 per harvest. **Garden level** = every 100 XP (simple and easy to tune in one file: `lib/models/garden_progress.dart`).
- **Unlocks** are based on completed sessions: 0 → Wild Sunflower (your current plant), 10 → 2nd species, 20 → 3rd, 30 → 4th, and so on. Species that have no art yet stay hidden, not broken.
- **Seed picker:** after a harvest (or on first run), you choose which unlocked species to plant next. That's the collection loop.
- **Daily streak:** a real day streak based on `lastStudyDay` (fixes the "days" label). A day counts if at least one focus round is completed.
- Categories (Meadow, Forest, Desert, Tropical, Flower, Herb, Magical, Seasonal) and rarity are just fields in the catalog. Adding a plant = add its art folder + one catalog line.

## 12. Implementation order

Your 15 phases, reordered slightly so the AI phases come **last** (they need stable internet) and timer persistence ships with the timer (it fixes a real bug):

| # | Phase | Needs art? |
|---|---|---|
| 1 | Design system (tokens: colors, spacing, borders, text styles) | no |
| 2 | Reusable pixel components (code fallbacks, so art can arrive later) | panel/bar art optional |
| 3 | Home redesign + `SceneLayout` | greenhouse layers, planter |
| 4+5 | Session setup + timer redesign + `endsAt` persistence + GardenController | timer sign |
| 6 | Pixel Journal (notes) | desk, journal page |
| 7 | Garden progression (stats, XP, daily streak, species catalog, unlocks) | none (sunflower exists) |
| 8 | Garden archive UI (grid, collection, detail card, seed picker) | soil plot, seed packet |
| 9 | Profile / player card + settings that work | avatar frame |
| 10 | Completion animations + particles + micro-interactions | leaf particles |
| 11 | AI service refactor (5 tools, error handling) | none |
| 12 | AI study questions (setup → quiz → results) | answer tiles, badges |
| 13 | AI flashcards + summary/concepts/explain | card frames, companion |
| 14 | Splash screen + app icon | icon, splash logo |
| 15 | Final polish: responsiveness pass, accessibility pass, analyzer cleanup, restore real durations | — |

After every phase: `flutter analyze` must be clean, and you run it on the phone before the next phase starts.
