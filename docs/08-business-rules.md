# 08 — Business rules

Exact game and app rules as implemented at commit `8e796c9`. When changing
a number, change it in the file named in each section. Most values are
computed on the fly, so tuning takes effect for everyone right away.

---

## 1. Study session (timer)

| Rule | Value | Where |
|---|---|---|
| Default focus length | 25 min | `SessionModel.defaultMinutes`, `StorageService.focusMinutes` |
| Choosable lengths (stepper) | 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120 min | `FocusTimeSetter.steps` |
| Quick presets (tap the number) | 5, 10, 15, 25, 30, 45, 60, 90 min | `FocusTimeSetter.presets` |
| Length used | The saved FOCUS TIME at the moment START is pressed | `TimerScreen` → `session.start(minutes: storage.focusMinutes)` |
| Timer | One global `SessionModel`, ticking once a second with `Timer.periodic` | `models/session_model.dart` |
| Statuses | idle → running ⇄ paused → completed or failed | |
| Pause | Allowed; the plant doesn't grow or wilt while paused | |
| Give up | Needs confirmation ("Give up?" / "Keep growing"). **Android back = the same question.** Not possible once the countdown is done. | `TimerScreen._confirmGiveUp` |
| Popup or journal open when time is up | Closed automatically, then the growth plays | `_closeEverythingOnTop` |
| Notes button | Disabled while the growth animation plays | |
| App backgrounded or killed | **Not handled.** The countdown may stop or reset (known limitation) | |

## 2. Plant growth

- **Stages:** `seed → sprout → grow → bloom → fullGrown` (5 stages, 4 steps).
- **One completed session = one stage.** It plays the 10-frame transition
  for that step.
- **Harvest:** when a session leaves the plant at `fullGrown` (it just
  reached it, or was already there), the harvest is recorded with its
  species id. The pot **resets to a seed of the same species** and the
  harvest popup appears:
  - **Start New Session:** stay on the Timer and start another session
    straight away.
  - **Go Home:** return to Home.
- **Give up → wilt.** The plant keeps its stage and shows the wilted art for
  that stage. The next completed session un-wilts it **and** grows it one
  stage. Wilting never loses stages.
- **Changing the seed:** only while the plant is a **seed**
  (`canChangeSpecies`). The seed tag shows "CHANGE" only when more than one
  species is unlocked. Picking a locked species isn't possible.
- A new account starts with a Wild Sunflower seed.

## 3. Counters

| Counter | Changes on complete | Changes on give up |
|---|---|---|
| `totalSessions` | +1 | +1 (the attempt counts) |
| `streak` ("in a row") | +1 | reset to 0 |
| `harvestedPlants` / `harvestLog` | +1 / append species on harvest | — |
| Session log document | `completed: true, seconds: length` | `completed: false, seconds: elapsed` |

**The streak counts sessions in a row, not days**, and the UI labels it "in
a row". A day streak is only an idea (see
[05-open-questions.md](05-open-questions.md)).

## 4. Completed sessions (temporary formula)

There is no saved "completed sessions" counter, because `totalSessions`
includes the times a user gave up. Until the counter exists, the app
estimates:

```
completedSessions = harvestedPlants × 4 + currentPlantStageIndex
```

This works because every completed session grows exactly one stage and a
harvest takes 4. **Caveats:** a session that finishes while the plant is
already fully grown is not counted separately, and changing species
doesn't matter. File: `lib/models/garden_progress.dart`.

## 5. XP and garden level

| Knob | Value |
|---|---|
| XP per completed session | 10 |
| XP per harvest | 50 |
| XP per level | 100 |

```
xp    = completedSessions × 10 + harvestedPlants × 50
level = 1 + xp ÷ 100 (integer)
```

So one full plant (4 sessions + harvest) = 90 XP. File:
`lib/models/garden_progress.dart`. Nothing is stored.

## 6. Plant unlocks

A species can be planted once `completedSessions ≥ unlockAtSessions`:

| Plant | Unlocks at |
|---|---|
| Wild Sunflower | 0 (starter) |
| Desert Cactus | 10 |
| Forest Fern | 20 |
| Moonpetal Lily | 30 |

The Garden "next quest" card shows `nextUnlock(completedSessions)`. File:
`lib/models/plant_catalog.dart`.

## 7. Badges (Profile)

| Badge | Earned when |
|---|---|
| First Sprout | completedSessions ≥ 1 |
| Focused Five | completedSessions ≥ 5 |
| Green Thumb | harvestedPlants ≥ 1 |
| On a Roll | streak ≥ 3 |
| Bouquet | harvestedPlants ≥ 5 |
| Garden Keeper | garden level ≥ 5 |

Badges are computed, never stored, and can be **lost** if the underlying
number drops (for example On a Roll after giving up). File:
`lib/models/achievements.dart`.

## 8. Player Card designs (quests)

| id | Name | Quest | Goal | Look |
|---|---|---|---|---|
| `meadow` | Meadow | Starter card | always | Plain meadow |
| `sunset` | Sunset Field | Finish 5 focus sessions | completedSessions ≥ 5 | Tint #FFB27A, sun |
| `cherry` | Cherry Blossom | Grow 3 plants | harvestedPlants ≥ 3 | Tint #FFD6E4, petals |
| `starry` | Starry Night | 5 focus sessions in a row | streak ≥ 5 | Tint #3E4C8C, stars, moon |
| `desert` | Desert Dunes | Grow a Desert Cactus | ≥1 cactus harvested | Tint #F2C47A, sun, sand, cactus sprite |
| `forest` | Enchanted Forest | Grow a Forest Fern | ≥1 fern harvested | Tint #6E9A66, fireflies, fern sprite |
| `moonlit` | Moonlit Garden | Grow a Moonpetal Lily | ≥1 lily harvested | Tint #7563B8, moon, sparkles, lily sprite |
| `golden` | Golden Scholar | Reach garden level 5 | level ≥ 5 | Tint #FFE08A, sparkles, kuwago, gold frame |

- Default and fallback design: `meadow`.
- **Equipping:** Profile → "Card designs" shelf → tap a card → **Equip**
  (only if unlocked). Saved as `cardDesign`.
- An equipped design **stays equipped** even if its quest progress later
  drops (for example after a streak breaks); it just can't be re-equipped
  until the quest is met again. Not yet confirmed by the owner (Q10).
- File: `lib/models/card_designs.dart`; drawing in
  `lib/widgets/card_cover.dart`.

## 9. Profile

- **Name:** 2–20 characters, trimmed. Edit it by tapping the name (✎) or
  the "Gardener name" setting.
- **Photo:** from the gallery or camera, resized to at most 256×256, JPEG
  quality 75, stored as base64. An optional "pixel look" (default on)
  decodes it at 40 px wide and scales up without smoothing. It can be
  removed.
- **Member since:** the year of the Firestore `createdAt`.
- **Guest sign-out:** warns that the garden will be lost (anonymous
  accounts can't be recovered).

## 10. Study material (AI and offline)

| Rule | Value |
|---|---|
| Empty notes | "Add some notes first…"; no AI call |
| What to make | Both / Questions only / Flashcards only |
| Counts | 5, 10, 15 or 20 each (default 5 + 5) |
| Question style | Mixed, Multiple choice (4 choices), True/False, Identification (type the answer) |
| Difficulty | Easy / Normal / Hard |
| Options remembered | Yes, on this phone only |
| Extra items from the AI | Dropped: the result is cut to exactly the requested counts (`_fit`) |
| Note length | No limit; the whole text is sent |
| Identification answer check | Forgiving match (ignores case, spacing and punctuation) |
| AI unavailable (busy/quota/timeout/offline) | Falls back to `OfflineStudyMaker`; material shows **"Made offline"** |
| Offline maker can't find enough definitions | Shows an error; nothing is generated |
| Auth/App Check/permission errors | Friendly error + Try again (no offline fallback) |

The model order, timeouts and retries are in
[10-ai-and-firebase.md](10-ai-and-firebase.md).

### Offline maker rules (`OfflineStudyMaker`)
- **Finds definitions:** "X is/are/was/were/means/refers to Y" and
  "Term: meaning".
- **Skips** vague subjects (pronouns and similar) and stop words.
- **Makes:**
  - flashcards (term → meaning);
  - true/false questions (alternating true statements and ones with a
    swapped meaning);
  - multiple choice (other definitions as distractors; the mixed style uses
    it for up to half of the questions);
  - fill-in-the-blank questions as `identification`.
- **Deterministic** for the same notes (`Random(notes.hashCode)`).
- Returns nothing when the notes are too short or have no definitions.
