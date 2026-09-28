# 01 — Product overview

## What kuwaGO is

kuwaGO is a Flutter mobile app (Android) that combines a **Pomodoro focus
timer**, a **pixel-art plant-growing game**, and **AI-assisted active recall**
(questions and flashcards generated from the student's own notes).

Original academic title (CCE106 course project):
**"Rooted: An AI-Assisted Pomodoro and Active Recall Mobile Application for
Independent Student Learning."**

Original success statement (from the project handoff):
> A fully functional, polished app that matches the Figma design and the
> pixel-art cottagecore look.

## Identity (owner's words — keep this)

The owner defined the identity as:

> **PIXEL GARDEN + COZY FARMING GAME + STUDY/POMODORO APP**

> "Study Buddy is a cozy pixel garden where studying literally grows your
> world." *(written before the rename to kuwaGO; the idea is unchanged)*

The intended feel:

> "Duolingo / Stardew-like progression mechanics, but instead of learning
> to gain XP, you study to grow your garden. The garden is the reward
> system."

It should **not** feel like:
- a normal Pomodoro timer with plants pasted onto it,
- a normal notes app with pixel backgrounds,
- a normal AI chatbot with a garden theme.

Every major feature should feel integrated into the garden world.

## The core gameplay loop

```
STUDY
  ↓
COMPLETE FOCUS SESSION
  ↓
GROW A PLANT (one growth stage per completed session)
  ↓
ADD PLANT TO GARDEN (harvest when fully grown)
  ↓
COLLECT / UNLOCK PLANTS
  ↓
BUILD A VIRTUAL GARDEN
```

Supporting loops that exist today:
- **Give up → the plant wilts** (drooping, dried-out art); the next completed
  session revives it.
- **XP → garden level**, **badges**, **plant unlocks**, and **Player Card
  design quests** give long-term goals.
- **Notes during a session → AI study material** (questions + flashcards)
  for active recall.

## Names and branding

| Thing | Name | Notes |
|---|---|---|
| App | **kuwaGO** | Exact casing: lowercase `kuwa`, uppercase `GO`. Chosen by the owner. |
| Mascot | **kuwago** | A pixel owl. "kuwago" is Filipino for owl. The owner explicitly did **not** want it called "Owl scholar" (the concept's working name). |
| Logo | "kuwaGO" wordmark | `kuwa` dark brown, `G` leaf green, the final **O is a pixel clock** (Pomodoro nod). |
| Tagline | "★ PLANT EDITION ★" | Leftover from the "Study Buddy" era; keep/change is an **open question**. |
| Former names | "Rooted" (course title, code package), "Study Buddy — Plant Edition" (screens before the rename) | The code package, folder and Firebase main project still use `rooted`. |
| Launcher label | kuwaGO | `android:label` in `AndroidManifest.xml`. |
| App icon | kuwago the owl on a leaf-green background | Replaced an earlier sunflower icon the owner didn't like. |

## Language style (terminology)

The owner asked to **keep game-like, cozy farming language** and to avoid
corporate terms such as "Dashboard", "Productivity Statistics", "Performance
Analytics".

Terms in use in the app:

| Term | Where |
|---|---|
| COZY GREENHOUSE | Home header |
| GARDEN LV *n* | Garden level (Home, Garden, Profile) |
| PLANT GROWTH | Growth bar (Home, Timer) |
| START STUDY SESSION | Home primary button |
| FOCUS TIME | Session-length setter on Home |
| SESSION EN ROUTE | Timer screen tag |
| FOCUS MODE / PAUSED | Timer sign label |
| NOTES | Timer → journal button |
| Study Journal / Field Notes | Notes screen and page title |
| Study Patch | Study material screen title |
| Grow your study patch | AI options scroll |
| Grow Study Material | AI options confirm button |
| CONGRATULATIONS! / You did it! | Harvest popup |
| GARDEN ARCHIVE | Garden hanging sign |
| GROWING | Stake next to the current plant in the garden |
| Next quest / NEXT UNLOCK | Garden quest card |
| Seed collection | Garden collectible shelf |
| Choose a seed / CHANGE | Seed picker |
| PLAYER CARD | Profile cover tag |
| Cozy member since | Profile |
| Cozy settings | Profile settings section |
| Gardener name | Profile setting (replaced "Cottage Parchment") |
| in a row | Streak label (it counts sessions, not days) |
| Made offline | Label on non-AI study material |

## Tone of copy

- Friendly, cozy, encouraging; small doses of owl humour ("Hoo!").
- Failures are framed gently ("Oh no, your … wilted… one session will perk
  it up!").
- Errors say what happened and what to do; developer-only details appear
  only in debug builds.

## Target user and device

- Independent students studying with the Pomodoro technique.
- Primarily **mobile, Android**. The owner tests on an **itel S665L
  (Android 12, API 31)**, often on **slow mobile data**.
- Layouts must work on small and large phones (tested 360×640 and 390×844
  logical px) and not overflow.

## Design philosophy (owner's rules)

From the owner's specification:

- **COZY · PIXEL · GARDEN · STUDY · GAME.**
- **Don't overdesign:** avoid too many UI elements/stats/icons/particles,
  giant text, excessive gradients/shadows, glassmorphism, generic Material
  cards.
- **Empty space rule:** don't fill empty space with more text or cards —
  use *environmental storytelling* (a watering can, hanging plants, a
  flower patch, a bookshelf).
- **Consistency:** every screen shares the same border style, wood texture,
  buttons, typography hierarchy, corner treatment, palette, pixel-art scale
  and spacing — "the user should immediately know: this is kuwaGO."
- **Accessibility despite the game look:** readable text, sufficient
  contrast, ≥48 dp touch targets, icon + text (not colour alone), semantic
  labels, readable timer, accessible note editor.
- **The owner draws the art.** Code-drawn stand-ins are acceptable until
  art exists; code effects (sparkles, particles) are fine. The owner later
  also accepted code-generated plant sprites "in the style of" their
  sunflower.

See [09-design-system.md](09-design-system.md) for the concrete system.
