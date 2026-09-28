# 04 — Future roadmap and phase ideas

Everything here is **not built yet**. Sources:

- the owner's original 15-phase spec (pasted at the start of the redesign),
- the reordered plan in [REDESIGN_PLAN.md](REDESIGN_PLAN.md) §12 (written
  2026-09-28, **before** the kuwaGO rename, the mascot and the AI fixes),
- ideas proposed during the conversation that the owner neither accepted nor
  rejected.

Each item is tagged:

- **[owner]**: in the owner's own spec or asked for by the owner.
- **[plan]**: proposed by the assistant in REDESIGN_PLAN.md; the owner said
  "build it", but did not confirm this specific detail.
- **[idea]**: suggested in conversation, never confirmed.

Open decisions tied to these items are in
[05-open-questions.md](05-open-questions.md).

---

## 1. Phase status (the 15-phase plan)

| # | Phase | Status | What is still missing |
|---|---|---|---|
| 1 | Design system (tokens) | ✅ | — |
| 2 | Reusable pixel components | ✅ | `PixelStepper`, `PixelChoiceChips` and `PixelToast` were not built as separate widgets. The focus-time setter and the options dialog do the same job inline. |
| 3 | Home redesign | ✅ | Built as a code-drawn greenhouse window, not the 3-layer `SceneLayout` art. |
| 4+5 | Session setup + timer redesign + persistence + GardenController | ⚠️ | Focus time is set on Home (no separate setup screen). **Break length, rounds, "What are you studying?", `endsAt` persistence, GardenController and "RETURN TO SESSION" are not built.** |
| 6 | Pixel Journal | ✅ | Parchment page with a fixed "Field Notes" heading; saves automatically. Not built: an editable title line, per-session notes, and a SAVE NOTE button. |
| 7 | Garden progression | ⚠️ | XP, level and unlocks exist, but they use a **temporary formula** (see §3). No real `completedSessions`, no daily streak. |
| 8 | Garden archive UI | ✅ | Plant detail card (tap a plant) not built. |
| 9 | Profile / player card | ⚠️ | Push Reminders does nothing. (The card-design shelf is done.) |
| 10 | Completion animations | ✅ | `+XP` on the harvest popup not shown. |
| 11 | AI service refactor (5 tools) | ⚠️ | Only one tool exists: questions + flashcards together. |
| 12 | AI study questions: setup → quiz → results | ⚠️ | Setup done (counts, style, difficulty). **Quiz flow (1/5, CHECK ANSWER, score, REVIEW MISSED) not built.** |
| 13 | Flashcards + Summarize / Key concepts / Explain | ⚠️ | Flashcard flip exists. PREV/NEXT with counter, LEARNED / REVIEW AGAIN, and the three reading tools are not built. |
| 14 | Splash + app icon | ✅ | — |
| 15 | Final polish | ❌ | Responsiveness pass, accessibility pass, analyzer cleanup, leftover files. |

---

## 2. Timer and sessions

- **[plan] Timer persistence.** Store `endsAt` instead of counting ticks, and
  save the active session to SharedPreferences. If the session finished
  while the app was closed, it counts as completed. This fixes drift and
  lost time when Android pauses or kills the app.
- **[plan] GardenController.** Move completion handling (grow, record,
  harvest) out of `TimerScreen` into a root-level listener, so it works no
  matter which screen is open. Show a toast in the journal: "Round complete
  — your plant grew!"
- **[plan] Rounds and breaks.** FOCUS / BREAK / ROUNDS steppers (focus 5–60,
  break 1–15, rounds 1–8). The sign reads "REST TIME" during a break. Breaks
  never grow or wilt the plant.
- **[plan] Back minimizes the session.** Home would then show "RETURN TO
  SESSION". The current behaviour is different: back asks to give up.
- **[plan] "What are you studying?"** task label.
- **[idea] Minimum session length**, so a 1-minute session can't farm
  growth.
- **[plan] Background notification** ("Your round is done") using
  `flutter_local_notifications`.

## 3. Progression

- **[plan] Real `completedSessions` counter.** Today, completed sessions are
  *estimated* as `harvested × 4 + current stage`. See
  [08-business-rules.md](08-business-rules.md).
- **[plan] `PlayerStats`:** completedSessions, totalFocusMinutes, dayStreak,
  bestStreak, lastStudyDay.
- **[plan] Real daily streak.** A day counts when at least one focus session
  is completed. The label would change from "in a row" to days.
- **[plan] Garden stored as documents** (`users/{uid}/garden/{id}`: speciesId,
  harvestedAt, sessionsSpent). Today it is a `harvestLog` list of species
  ids.
- **[plan] Plant detail card**: name, category, rarity, date grown, sessions
  it took.
- **[plan] More species.** Categories already planned in the catalog:
  Meadow, Forest, Desert, Tropical, Flower, Herb, Magical, Seasonal. Adding
  a plant means adding its art folder and one catalog line.
- **[plan] Rarity gems** next to species names.
- **[plan] +XP shown on the harvest popup.**

## 4. Study tools (AI)

- **[owner] Quiz flow:** QUESTION 1 / 5 with a progress bar → CHECK ANSWER
  → "CORRECT! 🌱 Your knowledge is growing!" or "NOT QUITE! Let's learn this
  one again." with the explanation → STUDY PATCH COMPLETE `4 / 5` → REVIEW
  MISSED / RETURN TO GARDEN.
- **[owner] Flashcards:** PREV / `3 / 12` / NEXT, 🌱 LEARNED, ↺ REVIEW
  AGAIN, a finish screen, and shuffling the review pile.
- **[owner] Summarize, Key Concepts, Explain a Topic** on a shared "reading
  scroll" screen with a "Copy to journal" button.
- **[plan] AI tools sheet** with a garden companion sprite. The
  companion's role might now go to kuwago; see open questions.
- **[plan] Multiple notes** (`users/{uid}/notes/{id}`, linked to a session).
  Migration: the single `notes` field becomes the first note.
- **[plan] Saving generated study material** so it isn't lost when the
  screen closes.
- **[plan] Short answers are left out on purpose.** Free text can't be
  graded reliably offline. The *identification* type uses a forgiving typed
  match instead.

## 5. kuwago the mascot

Placements the assistant suggested but the owner has not approved
**[idea]**:

- on the harvest popup (celebrating),
- next to a wilted plant (comforting),
- sleeping while the timer is paused,
- in the Study Journal (as the AI "companion" / thinking animation),
- on the Garden sign,
- on the Profile card. The "golden" card design already includes an owl.

## 6. Profile and account

- **[plan] Push reminders:** make the toggle work, or remove it.
- **[idea] Upgrade a guest account** to Google/email without losing the
  garden (link credentials).
- **[plan] About page:** the About dialog exists now; a full page is optional.
- **[plan] Preset gardener avatars** as an option besides photos (art:
  `avatar_<n>.png`).

## 7. Release readiness

- **[plan] Register Play Integrity for App Check** before a release build is
  shared. Today, release builds use Play Integrity but it isn't registered.
- **[idea] Turn on App Check enforcement** for Firebase AI Logic after
  release builds pass App Check.
- **[idea] Rename the package from `rooted`.** See open questions.
- **Firebase will require MFA** on the Firebase console accounts from
  **Oct 20, 2026** (a banner was seen in the console). The owners of both
  Google accounts need to turn on 2-step verification.

## 8. Art (owner draws; code stand-ins exist)

The full list with sizes and priorities is the **artwork checklist in
[REDESIGN_PLAN.md](REDESIGN_PLAN.md) §5**. The code stand-ins that could be
replaced:

| Stand-in in code | Art that would replace it |
|---|---|
| Greenhouse window / sill / planter (`greenhouse_scene.dart`) | `greenhouse_bg/mid/fg.png`, `planter_box.png` |
| Wooden desk (`desk_background.dart`) | `desk_bg.png`, `journal_page.png` |
| Panels (`PixelFramePainter`) | `panel_wood/dark/parchment.png` (9-slice) |
| Timer sign | `timer_sign.png` |
| Material icons | 16×16 pixel icon set |
| Garden diorama | `garden_bg.png`, `soil_plot.png` |
| Generated cactus / fern / lily | owner-drawn versions (optional) |
| Particles | `particle_leaf.png` etc. (optional) |

Owner-drawn art already in use: sunflower stages and frames, meadow
background, plaque button, harvest scroll.

## 9. Other ideas mentioned

- **[idea] Garden decorations** as environmental storytelling (watering
  can, hanging plants, bookshelf). Mentioned in the owner's design
  philosophy; not planned as features.
- **[idea] Sound effects.** Never discussed in detail.
