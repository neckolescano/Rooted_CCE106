# 12 — Decision log

Every major decision, with the reason and who made it. Entries are in
chronological order. Exact dates are known only roughly: before
2026-09-28 is the pre-redesign era (the old README and the handoff); from
2026-09-28 to 29 is the redesign, branding and AI work.

**Decided by:** **Owner** = Necko said so · **Owner-approved** = the
assistant proposed it and the owner chose it or said go · **Assistant** =
a technical call the assistant made while implementing and explained, and
the owner didn't object.

---

## Era 1: before the redesign (from the old README and handoff)

| # | Decision | Why | By |
|---|---|---|---|
| D1 | Flutter + `provider` + SharedPreferences; later **Firebase** (Auth + Firestore) as the per-user database | Course project; data should follow the account | Owner |
| D2 | **One global `SessionModel`** at the app root; the Notes/Study screens only *watch* it (`CompactTimerHeader`) | Opening Notes must never create a second timer or stop the countdown | Owner (spec) |
| D3 | `NotesModel` at the root + saved to storage | Timer → Notes → Study Material → back never loses text | Assistant (earlier session) |
| D4 | **No AI API key inside the app** | Keys can be pulled out of an APK. The first version threw an honest "not connected" error instead of faking it. | Owner (spec) |
| D5 | `SessionModel.start()` runs in `addPostFrameCallback` **plus** a `_sessionStarted` flag | Calling it in `initState` crashed ("setState during build"). Without the flag, a leftover "completed" status "fast-forwarded" the new session. | Assistant (earlier session) |
| D6 | Finishing a session while the plant is already full grown triggers a **harvest** (popup, reset to seed) | It used to silently do nothing | Assistant (earlier session) |
| D7 | Plaque button **9-slice** (only x≈50–79 stretches); Give Up = the same plaque with a red tint | Any label length, crisp flower ends | Assistant (earlier session) |
| D8 | Bottom nav: every tab reserves the same border space | The selected tab overflowed by 3 px | Assistant (earlier session) |
| D9 | TimerScreen got its own `Scaffold` | It rendered on black | Assistant (earlier session) |
| D10 | Wilting first done as a desaturate/darken in code | No wilted art existed (replaced by D27) | Assistant (earlier session) |

## Era 2: redesign (2026-09-28 →)

| # | Decision | Why | By |
|---|---|---|---|
| D11 | **Design first, AI later** | The owner's internet was unstable | Owner: "lets work on the design first… lets make the ai later when i have a stable net" |
| D12 | Identity = **PIXEL GARDEN + COZY FARMING GAME + STUDY/POMODORO APP**; keep the existing palette, fonts, cozy wording and owner art | The owner's spec | Owner |
| D13 | The 15 phases reordered: AI last, timer persistence together with the timer | Bad internet; persistence fixes a real bug. (Persistence was later **not** built; see 04.) | Owner-approved ("generate the design and build it") |
| D14 | One component library with variants (`PixelPanel` wood/dark/parchment, etc.) instead of the overlapping widget list in the spec | Avoid duplicates, keep styling in one place | Assistant |
| D15 | Scale rule **1 art px = 2 dp**, nearest-neighbour scaling | Mixed scales made the art look like it came from different games | Assistant (in the plan) |
| D16 | "LVL" means **garden level**; plant progress = a 5-segment bar | "LVL 3 GROW" (plant stage) would clash with a real level | Assistant (in the plan) |
| D17 | Streak label "**in a row**" (not "days") | It counts sessions, not days | Assistant |
| D18 | Give Up **needs confirmation**; **Android back = the same question** | One tap wilted the plant; back used to orphan the running timer | Assistant (fixing bugs from the plan) |
| D19 | XP 10/session, 50/harvest, 100/level; unlocks at 0/10/20/30 completed sessions | Simple and easy to tune in one file | Assistant (in the plan) |
| D20 | **Temporary** `completedSessions = harvested × 4 + stage` | No saved completed counter yet (`totalSessions` includes give-ups) | Assistant (marked temporary) |
| D21 | Garden and Profile redesigned as a **diorama / player card** | Owner: too plain and vertical, "no theme or wow factor" | Owner request |
| D22 | **Window zoom, Option A** (sashes open, plant ducks, camera flies through the window) after a preview | The first zoom wasn't centred or smooth; the owner asked for suggestions, saw a preview of A, then said "try building the A" | Owner-approved |
| D23 | Every popup is a **parchment scroll with a wax seal** | Owner: popups should be "paper like texture… or scroll", not a plain box with a wooden button | Owner request |
| D24 | When the timer ends, close any popups or journal on top first | The timer ended under the give-up popup and froze | Assistant (bug fix) |
| D25 | Garden plants **scroll horizontally** | Owner corrected "vertically" to "horizontally like the seed collection" | Owner |
| D26 | 3 new species (cactus, fern, lily) **generated in code** in the sunflower's style | Owner asked for variants that "replicate how my pixel sunflower looks" | Owner request; generation method by assistant |
| D27 | **Real wilted art** per stage, generated from the stage PNGs | Owner: "instead of making the plant turn black… make a wilted version" | Owner |
| D28 | Seeds can only be changed while the pot holds a seed | Swapping mid-growth would mismatch the art and progress | Assistant |
| D29 | Profile photo stored as a **small base64 JPEG in Firestore**, optional pixel look | Avoids Firebase Storage (not needed on Spark); fits the doc | Assistant |
| D30 | Harvest popup: effects **outside** the frame, readable centred text, bigger "trophy" plant, dark overlay | The owner's request | Owner |
| D31 | Native splash + **grass loading bar** with a walking, growing flower | Teacher and owner: no black boot screen; the owner described the grass idea | Owner |
| D32 | Mascot = **owl**; not named "Owl scholar" | Owner disliked the sunflower icon, picked the owl concept, and rejected the name | Owner |
| D33 | App name **kuwaGO**; the **O is a clock**; mascot called **kuwago** | Owner | Owner |
| D34 | Keep the package, folder and Firebase ids as `rooted` | Renaming the application ID needs new Firebase app registrations and SHA setup; display names are enough | Assistant (open question Q14) |
| D35 | **Focus-time setter on Home** (1–120 min steps, presets) instead of a separate session-setup screen | Owner asked for it "in the home page" | Owner |
| D36 | kuwago lives on the **Home windowsill** with lines about the garden | The owner asked where to put him; Home was recommended and built | Owner-approved |

## Era 3: making the AI work

| # | Decision | Why | By |
|---|---|---|---|
| D37 | **Firebase AI Logic + Gemini Developer API** (free), protected by **App Check** | No key in the app, free tier | Assistant (consistent with D4) |
| D38 | **Fixed App Check debug token** in git-ignored `app_check.local.json`, passed with `--dart-define-from-file` | Random debug tokens changed on every reinstall and weren't registered ("Failed to exchange debug token") | Assistant |
| D39 | Move AI to a **separate project `kuwago-ai`** on the owner's personal account (secondary FirebaseApp `'ai'`) | The school project got "Your project has been denied access"; the owner picked "option a" | Owner-approved |
| D40 | **Retries + model fallback + time budget** | 500 "high demand" and 429 quota errors | Assistant |
| D41 | **Rule-based offline fallback** ("Made offline") | Long waits then red errors; slow internet. The owner was told plainly it isn't AI. | Assistant (**keep or rename is open**, Q1) |
| D42 | **Model order: gemini-3.1-flash-lite first**; no thinking config; timeouts scale with request size | Testing: 3.8/3.5-flash were over quota (429), 3.5-flash-lite hung, 3.1-flash-lite answered in about 6 s; "low" thinking was slower. This fixed "it always run the offline build". The owner confirmed "it now works". | Assistant, confirmed by the owner's test |
| D43 | **Study options**: make (both/questions/flashcards), counts 5–20, style (incl. true/false and identification), difficulty; remembered on the phone | Owner: "yes add it to have more choices" | Owner |
| D44 | Identification answers use a **forgiving typed match**; no free-text "short answer" grading | Free text can't be graded reliably | Assistant |

## Era 4: profile and cards

| # | Decision | Why | By |
|---|---|---|---|
| D45 | **Editable name** (2–20 characters) | Owner request | Owner |
| D46 | **Player Card designs unlocked by quests**: 8 designs drawn in code | Owner asked for quests and "many designs… you make designs for it" | Owner request; designs by assistant |
| D47 | **Remove "Cottage Parchment"**, replace it with "Gardener name" | It was a non-functional Figma leftover the owner didn't recognise | Owner-approved |
| D49 | Player Card shelf: dimmed locked cards with `n / goal`, a preview scroll with Equip; an equipped design stays equipped if its progress drops | Finish the card feature | Assistant (the last point awaits owner confirmation, Q10) |
| D50 | **Opening = seed-packet rip (idea A)**: native splash = still packet, identical first frame, fixed-length 2.4 s story; heavy start-up begins 150 ms after the first frame | Owner found the old loading screen not smooth and liked a friend's ticket-rip opening; the owner picked A of four ideas (A packet rip, B owl wakes, C shutters open, D journal opens) | Owner-approved |
| D51 | **Opening redesign:** the rip starts on tap via an Android 12 animated splash icon, handed over seamlessly to a Flutter meadow scene; leaf-green background (the app icon colour) instead of cream; **loading bar removed**; kuwago and the kuwaGO letters are part of the story; always plays, even with system animations off | The owner saw no animation (the phone's animations were likely off, and Flutter respected it) and wanted motion from the instant of the tap, not a plain cream screen | Owner-approved |
| D52 | **Opening redesign #3: "kuwago's eye opens the app"** (idea 2 of: rip into app, owl's eye, clock O, owl pops out). Night sky, sleeping owl before a full moon (splash, animated on tap), a detailed night scene, a wake-up, then a dive into the pupil revealing the real app through a pixel circle. The meadow/plant opening (D50/D51) was removed. | Owner: the meadow version "runs too much"; wanted smooth, simple, a wow factor, no blank spaces, their theme's vibe, kuwago + the name | Owner-approved |
| D53 | **Opening redesign #4: "Through the O"** (replaces D52): a pixel kuwaGO lockup with kuwago perched on the clock O; the wind-up is native on launch, the clock ticks while loading, then a ding and a pixel circle opening out of the O. It continues into the first page: on Login the lockup lands on a redesigned sign that unfurls and the buttons rise; on Home kuwago flies to its windowsill and the page enters in turn. The owl-eye/night version was removed. | Owner wasn't convinced by the night version; wanted one simple animation that covers loading, then asked for the splash to continue into Login (first launch) or Home (already signed in) | Owner-approved |
| D54 | **Login page fully redesigned: "the sign kuwago knocks down."** Garden-under-a-pergola scene. The opening flies kuwago to the pergola's hook; it knocks, the wooden kuwaGO sign drops on chains and swings, kuwago rides it (tap = hop + swing), and the buttons rise under a "JOIN THE GARDEN" ribbon. Built after two previews (the second added the sun, clouds, trees, pergola posts, flower pots, bushes, butterflies, falling leaves, knock effects, the landing squash + welcome). | Owner wanted a unique login that the splash flows into, with the owl knocking a hanging chained sign that carries the name | Owner ("build it") |
| D48 | Convert the conversation into docs (`README.md` + `docs/01–13`) | Owner request, so another developer or AI can continue | Owner |

## Era 5: after the audit

| # | Decision | Why | By |
|---|---|---|---|
| D55 | **Garden Scenes**: 6 unlockable scenes (Morning Meadow, Golden Sunset, Cherry Blossom, Rainy Day, Starry Night, Firefly Forest) with quests like the card designs, shown under the Seed collection on the Garden page. The equipped scene changes the Timer background, the Garden Archive picture AND the view through the Home greenhouse window (the zoom flies through it into the Timer, so they must match). Colour wash on the meadow art + animated pixel effects; synced to the account (`gardenScene`) | Owner request: "if I equip a starry night scene the timer scene and garden archive should also change" | Owner |
| D56 | **Three top-tier seeds**: Phoenix Bloom (Legendary, 45 sessions), Crystal Lotus (Mythic, 60), Golden Glory Tree (Glory, 80). Art generated in the existing plant style; each has an animated aura (embers / orbiting prism crystals / golden rays) that grows with the plant and goes out when wilted. New rarities `mythic` and `glory`; Legendary's band became flame orange. | Owner asked for "legendary, mythic and glory" seeds, each "a wow plant with effect"; names, unlock numbers and effects chosen by the assistant | Owner request; designs by assistant |
| D57 | **Five more seeds above Glory**: Aurora Bell (Celestial, 100 sessions), Storm Orchid (Astral, 125), Starfall Willow (Divine, 150), Dragonheart Rose (Primordial, 200), Eternal Sakura (Eternal, 250), each with its own aura (aurora curtains, lightning, shooting stars and constellation, rune ring and ember helix, rainbow halos). **Five more garden scenes** (11 total): Autumn Harvest, Rainbow Morning, Lantern Night, Winter Wonderland, Aurora Borealis. | Owner loved collecting plants and asked for 5 higher-rarity seeds, 5 more scenes and an aurora; names, tiers, quests and effects chosen by the assistant | Owner request; designs by assistant |
| D58 | **Replaced the meadow background with original art** generated by `tool/generate_meadow.dart` (same 736×1308 size and horizon, so every layout still fits): cottage with chimney smoke, winding path, apple tree, bushes, wildflowers, mushrooms, butterflies; plus autumn and winter versions. | The old picture was not the owner's art; the owner asked for a new one with the same cottagecore pixel vibe | Owner |
| D59 | Meadow polish: the cottage roof was drawn upside down (fixed to a pitched roof); added window boxes, a pond with lily pads (frozen in winter) and a signpost. | Owner spotted the inverted roof and asked for a slight enhancement | Owner |
| D60 | **Secrets.** Secret seed **Owlbloom** (rarity Secret, an owl-faced flower with a moonlight + feathers aura): answer every question in a Study Patch right on the first try (at least 5 questions). Secret scene **Hidden Owl Grove** (moonlit teal night with blinking owl eyes): finish a focus session of 60+ minutes without pausing. Locked secrets show only "???" and a riddle-like hint; finding one shows an "A secret sprouted!" popup once. Found secrets are synced as `secrets`. | Owner wanted obtainable secret content and asked for rule ideas; the rules reward real study skills (active recall, deep focus) instead of grinding | Owner request; rules and designs by assistant |
