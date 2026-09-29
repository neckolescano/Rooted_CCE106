# 07 — Data model

All persistent data belongs to one user and is stored in two places that
mirror each other:

- **SharedPreferences**: the fast on-device copy, which works offline.
- **Firestore** `users/{uid}` in project **rooted-f95c7**: the source of
  truth, which follows the user to other devices.

`StorageService` (`lib/services/storage_service.dart`) is the **only** code
that reads or writes either one.

---

## 1. Firestore

### Security rules (published in the console; from FIREBASE_SETUP.md)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

The rules file is **not** in the repo; it lives in the Firebase console.

### `users/{uid}` (one document per user)

| Field | Type | Written by | Meaning |
|---|---|---|---|
| `username` | string | sync | Display name. Defaults: Google/email display name, otherwise `Guest Trainee` (guest) or `PlantLover`. Editable, 2–20 characters. |
| `streak` | int | sync | Completed sessions **in a row**. Reset to 0 on give up. |
| `totalSessions` | int | sync | All sessions, **completed and abandoned**. |
| `harvestedPlants` | int | sync | Number of harvests. |
| `harvestLog` | string[] | sync | Species id of each harvest, oldest first. May be shorter than `harvestedPlants` for old saves (see §4). |
| `plantStage` | int | sync | `GrowthStage.index` of the plant in the pot (0 seed … 4 fullGrown). |
| `plantWilted` | bool | sync | The plant in the pot is wilted. |
| `plantSpecies` | string | sync | Species id in the pot. Missing → `wild_sunflower`. |
| `notes` | string | sync | The single Study Journal text. |
| `email` | string | sync | From the auth account. |
| `isGuest` | bool | sync | Anonymous account. |
| `avatar` | string | `setAvatar` only | Base64 JPEG, ≤256×256, quality 75 (about 30 KB). Empty = no photo. Not part of the regular sync. |
| `avatarPixel` | bool | sync | Show the photo with a "pixel look" (decoded at 40 px wide). Default true. |
| `focusMinutes` | int | sync | FOCUS TIME on Home. Default 25. |
| `cardDesign` | string | sync | Equipped Player Card design id. Default `meadow`. |
| `gardenScene` | string | sync | Equipped Garden Scene id (Timer, Garden Archive, Home window). Default `meadow`. |
| `createdAt` | timestamp | first save | Server time. **"Cozy member since" is derived from its year** when loading. |
| `updatedAt` | timestamp | every save | Server time. |

Writes use `set(..., merge: true)`, so unknown or older fields are never
deleted.

### `users/{uid}/sessions/{autoId}` (session log)

| Field | Type | Meaning |
|---|---|---|
| `completed` | bool | true = finished, false = gave up |
| `seconds` | int | Session length (completed) or time elapsed before giving up |
| `endedAt` | timestamp | Server time |

The app only writes these. Nothing reads them yet.

## 2. SharedPreferences keys

| Key | Type | Firestore field |
|---|---|---|
| `streak` | int | `streak` |
| `total_sessions` | int | `totalSessions` |
| `plant_stage` | int | `plantStage` |
| `plant_wilted` | bool | `plantWilted` |
| `plant_species` | string | `plantSpecies` |
| `harvested_plants` | int | `harvestedPlants` |
| `harvest_log` | string list | `harvestLog` |
| `notes_text` | string | `notes` |
| `username` | string | `username` |
| `email` | string | `email` |
| `is_guest` | bool | `isGuest` |
| `member_since_year` | int | (derived from `createdAt`) |
| `avatar_base64` | string | `avatar` |
| `avatar_pixel` | bool | `avatarPixel` |
| `focus_minutes` | int | `focusMinutes` |
| `card_design` | string | `cardDesign` |
| `garden_scene` | string | `gardenScene` |
| `study_options` | JSON string | **local only** (not synced) |

All keys are wiped on sign-out (`detachUser`, after a final push) and when a
brand-new account is created.

## 3. Sync behaviour

1. **Login / app start with a user:** `attachUser` loads the document
   (8 s timeout).
   - Document exists → copy it into SharedPreferences.
   - Database reached but no document → new user: clear local data, set
     defaults, create the document with `createdAt`.
   - Database unreachable → keep the local copy. It is never treated as a
     new user, so real data can't be overwritten.
2. **Every change:** write locally, then `_scheduleSync()` waits **1 s**
   (so typing becomes one write) and pushes `_snapshot()` with a 5 s
   timeout. Firestore queues writes that fail while offline.
3. **Avatar:** uploaded immediately and separately (10 s timeout).
4. **Sign out:** push pending changes, then clear local data.

## 4. Backward compatibility (rules for old saves)

- **Legacy harvests:** saves from before `harvestLog` existed only have
  `harvestedPlants`. `harvestLog` pads the front with `wild_sunflower` for
  each missing entry.
- **Missing `plantSpecies`** → `wild_sunflower`. **Unknown species id** →
  `speciesById` falls back to the starter plant.
- **Missing/invalid `cardDesign`** → `meadow` (`cardDesignById`).
- **Missing/invalid `gardenScene`** → `meadow` (`gardenSceneById`).
- **Missing `focusMinutes`** or a value ≤ 0 → 25.
- **Invalid `study_options` JSON** → defaults. Counts that aren't in
  [5, 10, 15, 20] → 5.

## 5. In-app models (not stored as-is)

### Plants
- `GrowthStage` enum: `seed, sprout, grow, bloom, fullGrown` (5 stages).
- `PlantSpecies` (`models/plant_catalog.dart`): `id, name, category, rarity,
  unlockAtSessions, assetRoot, blurb`. The catalog is a `const` list in
  code.

| id | Name | Category | Rarity | Unlock at (completed sessions) | Art |
|---|---|---|---|---|---|
| `wild_sunflower` | Wild Sunflower | Meadow | Common | 0 | `assets/images/plant/` (owner's hand-drawn art) |
| `desert_cactus` | Desert Cactus | Desert | Uncommon | 10 | `assets/images/plants/desert_cactus/` (generated) |
| `forest_fern` | Forest Fern | Forest | Uncommon | 20 | `assets/images/plants/forest_fern/` (generated) |
| `moonpetal_lily` | Moonpetal Lily | Magical | Rare | 30 | `assets/images/plants/moonpetal_lily/` (generated) |

`PlantRarity` also has `legendary`, which no plant uses yet.

### Study material (`models/study_material.dart`, `study_options.dart`)

- `StudyOptions { make: both|questionsOnly|flashcardsOnly, questionCount,
  flashcardCount ∈ {5,10,15,20}, style: mixed|multipleChoice|trueFalse|identification,
  difficulty: easy|normal|hard }`. Defaults: both, 5, 5, mixed, normal.
- `StudyMaterial { questions: StudyQuestion[], flashcards: Flashcard[],
  offline: bool }`.
- `StudyQuestion { question, type, answer, choices?, explanation? }`. The
  `type` is one of `multiple_choice` (4 choices), `true_false`
  (`["True","False"]`, added automatically if missing) or `identification`
  (typed answer). If the type is missing, the parser uses `short_answer`.
  An answer like "B", or one with different casing, is snapped to the
  matching choice.
- `Flashcard { front, back }`.

Expected AI JSON (built by `study_material_prompt.dart`):

```json
{
  "questions": [
    {"question": "...", "type": "multiple_choice", "choices": ["...","...","...","..."],
     "answer": "<exact choice text>", "explanation": "..."}
  ],
  "flashcards": [{"front": "...", "back": "..."}]
}
```

Generated material is **not stored**; it only lives while the screen is
open.

### Progress and cosmetics (computed; see [08-business-rules.md](08-business-rules.md))
- `GardenProgress` (XP, level), `GardenBadge` list, `CardDesign` list plus
  `QuestStats`.

## 6. Assets

```
assets/images/
  plant/                         Wild Sunflower (owner's art)
    stages/  seed.png sprout.png grow.png bloom.png fullgrown.png   (128×128)
    frames/  seed_sprout_00..09, sprout_grow_00..09,
             grow_bloom_00..09, bloom_fullgrown_00..09              (128×128)
    wilted/  <stage>.png                                            (generated)
  plants/<species_id>/{stages,frames,wilted}/   same layout (generated)
  backgrounds/garden_meadow.png  736×1308 (owner's art; timer, login, windows)
  buttons/button_plaque.png      96×48, 9-slice stretch zone x 50–79 (owner's art)
  popups/harvest_frame.png       144×192 scroll, "CONGRATULATIONS!" baked in (owner's art)
assets/icon/                     generated owl icon, adaptive foreground, splash
```

- Every folder must be listed in `pubspec.yaml` under `flutter: assets:`.
- Sprites leave empty rows at the bottom (about rows 103–128 of 128), so
  code shifts plants down by about 0.19–0.22 of the sprite size to sit on
  planters.
- The owl is not an image: it is text rows in `lib/art/owl_art.dart`
  (24×24), drawn by `OwlSprite` and also used by `tool/generate_icon.dart`.
