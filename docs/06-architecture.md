# 06 — Architecture

This describes the code as of commit `8e796c9`. It is a single Flutter app
for Android only, with no backend code of its own: Firebase provides
authentication, the database and the AI proxy.

```
┌──────────────────────── Flutter app (package: rooted) ────────────────────────┐
│ BootApp ─► LoadingScreen ─► RootedApp (MultiProvider)                          │
│                              ├─ LoginScreen                                   │
│                              └─ MainShell (WindowZoom + PixelBottomNav)       │
│                                  ├─ Home ──(window zoom)──► TimerScreen       │
│                                  │                           └─► NotesScreen  │
│                                  │                                 └─► Study  │
│                                  ├─ Garden                             Patch  │
│                                  └─ Profile                                   │
│ State: StorageService · PlantModel · NotesModel · SessionModel (ChangeNotifier)│
└──────────┬─────────────────────────────┬──────────────────────────┬───────────┘
           │ Auth + Firestore            │ App Check                │ Firebase AI Logic
           ▼                             ▼                          ▼
   rooted-f95c7 (school account)   both projects            kuwago-ai (personal account)
   users/{uid}, users/{uid}/sessions                        Gemini (Developer API)
```

---

## 1. Boot flow (`lib/main.dart`)

The goal is that **nothing is ever black or blank**.

1. `main()` calls `runApp(BootApp())` right away. The native splash
   (cream background with the owl) covers the gap before Flutter draws.
2. `BootApp` shows `LoadingScreen(progress)` and runs `_boot()`:

| Step | Work | Progress |
|---|---|---|
| 1 | `Firebase.initializeApp` (default app = rooted-f95c7). On failure it shows `SetupNeededApp` instead of crashing. | 0.3 |
| 2 | App Check `activate` with a shared provider: debug/profile builds use `AndroidDebugProvider(debugToken: APP_CHECK_DEBUG_TOKEN)`, release builds use `AndroidPlayIntegrityProvider`. Then `AiFirebase.init(provider)` starts the secondary app `'ai'`. | 0.45 |
| 3 | `StorageService.create()`, `PlantModel()`, `NotesModel()` | 0.6 |
| 4 | If `FirebaseAuth.currentUser` exists: `storage.attachUser(...)`, `plant.loadFrom(stage, wilted, speciesId)`, `notes.loadFrom(...)` | 0.9 |
| 5 | Sets progress 1.0 | 1.0 |

   `_boot()` starts **150 ms after the first frame**, so the opening
   animation gets its first frames out without stutter.
3. (Superseded; see the Loading row below.) The app appears only when **both** `_boot()` is done and the
   intro has played to the end (then a 350 ms beat). An `AnimatedSwitcher`
   (450 ms) fades to `RootedApp`. `RootedApp` opens
   `MainShell` if the user is signed in, otherwise `LoginScreen`.

## 2. State management

The app uses `provider` with four root-level `ChangeNotifier`s, created once
and passed in with `.value`:

| Provider | File | Holds |
|---|---|---|
| `StorageService` | `services/storage_service.dart` | Everything that persists: stats, plant state, species, harvest log, notes text, profile (name, email, guest flag, avatar), focus minutes, study options, card design. It has two layers (see §4). |
| `PlantModel` | `models/plant_model.dart` | The plant in the pot now: `GrowthStage`, wilted flag, `speciesId`; `grow()`, `wilt()`, `resetToSeed()`, `changeSpecies()`; asset paths. |
| `NotesModel` | `models/notes_model.dart` | Journal text; `generateStudyMaterial(service, options)` with loading and error state. It lives at the root so Timer → Notes → Study Patch → back never loses text. |
| `SessionModel` | `models/session_model.dart` | **The one global timer.** `start({minutes})`, pause/resume, `giveUp()`, `status`, `progress`, `elapsedSeconds`, `durationSeconds`. Counts down with `Timer.periodic`. |

**Rule:** never create a second timer. Notes and other screens read
`SessionModel`.

Derived values that are **computed, not stored**: `GardenProgress` (XP,
level), badges (`achievements.dart`), card-design quest progress
(`card_designs.dart`), and plant unlocks (`plant_catalog.dart`).

## 3. Screens and navigation

| Screen | File | Reached from | Notes |
|---|---|---|---|
| Loading | `screens/loading_screen.dart` → `widgets/clock_intro.dart` | Boot | **Overlay above the app**: `BootApp` builds a `Stack` of [the real app once ready, the intro] and sets `IntroCue.stage` (`services/intro_cue.dart`) to covering. The intro gets the splash position from `MainActivity.kt` via `services/splash_bridge.dart`, removes the splash on the identical frame, ticks until the app is ready (≥0.25 s), then dings and opens a pixel circle out of the O. It finds the landing spots through `IntroCue.loginLockupKey` / `homeOwlKey` and flies the lockup / kuwago there. The stage becomes *revealing* (pages start their entrance: `widgets/page_entrance.dart`, and the login screen's own) and then *done* (the real lockup/owl appear in the same frame the overlay is removed). No loading bar. |
| Login | `screens/login_screen.dart` | Not signed in / sign out | Google, email dialog (`widgets/email_auth_dialog.dart`), guest. `AuthService` is created lazily (`late final`). |
| MainShell | `screens/main_shell.dart` | After login | Bottom nav (Home · Garden · Profile) inside `WindowZoom`. |
| Home | `screens/home_screen.dart` | Nav | Header (level/XP/streak), `GreenhouseScene` (window, owl, plant, seed tag), growth bar, quote, `FocusTimeSetter`, START STUDY SESSION → `WindowZoom.zoomThrough`. |
| Timer | `screens/timer_screen.dart` | Home (zoom) | Starts the session in `addPostFrameCallback`. Handles completion, growth animation, harvest and give-up. `PopScope` makes back ask to give up. |
| Notes (Study Journal) | `screens/notes_screen.dart` | Timer → NOTES | Desk + parchment page, compact timer header, "Generate" → options scroll → AI. Disabled while the plant grows. |
| Study Patch | `screens/study_material_screen.dart` | Notes after generation | Tabs: questions and flashcards; "Made offline" banner. |
| Garden | `screens/garden_screen.dart` | Nav | Diorama with a horizontal plant bed, stats ledger, next-quest card, seed collection shelf. |
| Profile | `screens/profile_screen.dart` | Nav | `CardCover` (equipped design), avatar, editable name, badges, settings (Push Reminders UI only, Gardener name, About, Sign out). |

### Session completion flow (in `TimerScreen`)

```
SessionModel.status == completed (and _sessionStarted)
  → _beginGrowthSequence()
      _closeEverythingOnTop()              // pop popups / journal above this route
      play growth frames (GrowthTransitionPlayer) if there's a next stage
  → _finishSession()
      plant.grow(); storage.recordCompletedSession(); storage.savePlantState()
      if plant.isFullyGrown → _handleFullyGrown()
          storage.recordHarvestedPlant(speciesId); plant.resetToSeed()
          HarvestCelebrationDialog → "Start New Session" (stay, restart) | "Go Home" (pop)
      else pop back to Home (reverse window zoom)

Give up (button or Android back, after confirming)
  → session.giveUp(); plant.wilt(); storage.recordFailedSession(); pop
```

Known limitation: completion logic lives in `TimerScreen`. The planned fix
is a root-level `GardenController` plus `endsAt` persistence; see
[04-future-roadmap.md](04-future-roadmap.md).

### Window-zoom transition (`widgets/window_zoom.dart`)

`WindowZoom` wraps MainShell. `WindowZoom.zoomThrough(context, route)`:

1. The `windowOpen` controller (600 ms) swings the greenhouse sashes open
   and ducks the plant down. The owl cheers.
2. It snapshots the shell with a `RepaintBoundary`, then scales the snapshot
   around the window centre: 750 ms, overshoot to 1.08, hand-off at 0.6.
3. The Timer route fades in over 450 ms.
4. When the Timer pops, the same steps run in reverse.

The snapshot is taken **before** the session, so on the way back it briefly
shows the pre-session state.

## 4. Persistence layers (`StorageService`)

```
UI / models ──► StorageService ──► SharedPreferences   (instant, offline, per device)
                                └─► CloudService (Firestore)  debounced ~1 s writes
```

- `attachUser(uid, …)` loads `users/{uid}` from Firestore with an 8 s
  timeout. Firestore is the source of truth. If it is unreachable, the
  local copy is kept. New users get a document with `createdAt`.
- Every setter writes locally at once, then schedules a debounced
  `saveUser(_snapshot())` with merge.
- `CloudService.logSession` adds one document per finished or abandoned
  session to `users/{uid}/sessions`. It never throws.
- The avatar is uploaded separately (`setAvatar`), because it is large.
  `study_options` is local only.
- Field lists: [07-data-model.md](07-data-model.md).

## 5. Services

| Service | File | Responsibility |
|---|---|---|
| `AuthService` | `services/auth_service.dart` | Guest (anonymous), create account / sign in with email, Google (`google_sign_in` v7 → Firebase credential), sign out, `friendlyError`. |
| `CloudService` | `services/cloud_service.dart` | Firestore read/write for one uid; session log. |
| `StorageService` | `services/storage_service.dart` | See §4. |
| `AiFirebase` | `services/ai_firebase.dart` | Initializes the secondary FirebaseApp `'ai'` (kuwago-ai) with `firebase_options_ai.dart` and activates App Check for it. Falls back to the default app if it isn't configured. |
| `AiService` | `services/ai_service.dart` | `generateStudyMaterial(notes, options)`: model fallback loop, retries, timeouts, offline fallback, error explanations, JSON parsing. |
| `buildStudyMaterialPrompt` | `services/study_material_prompt.dart` | Builds the prompt text: counts, style, difficulty, JSON schema. |
| `OfflineStudyMaker` | `services/offline_study_maker.dart` | Rule-based cards and questions from definitions in the notes. |

Details on AI: [10-ai-and-firebase.md](10-ai-and-firebase.md).

## 6. Widgets

**UI kit:**
- `pixel_panel` (`PixelPanel`, `PanelStyle`, `PixelFramePainter`,
  `PixelNail`)
- `pixel_button` (plaque 9-slice, `ButtonTone`)
- `pixel_icon_button`, `pixel_section_header`, `pixel_progress_bar`,
  `stat_pill`
- `pixel_sprite` (nearest-neighbour scaling, silhouette)
- `pixel_timer_display`, `compact_timer_header`, `pixel_bottom_nav`

**Dialogs:**
- `pixel_dialog` (`PixelDialog`, `showPixelConfirm`, `showPixelMessage`)
- `pixel_scroll` (`PixelScroll`, `WaxSeal`)
- `email_auth_dialog`, `study_options_dialog`, `seed_picker`
- `profile_avatar` (`showAvatarOptions`)
- `harvest_celebration_dialog`

**Scenes:**
- `greenhouse_scene`, `window_zoom`, `background_scene` (login and timer
  backgrounds), `desk_background`, `scene_frame`, `card_cover`

**Game and study pieces:**
- `plant_display` (stage or wilted art), `growth_transition_player`
- `focus_time_setter`
- `card_design_shelf` (the Profile "Card designs" shelf and the
  preview/equip scroll)
- `flashcard_widget`, `study_question_card`

**Mascot and brand:**
- `owl_mascot` (`OwlSprite`, `OwlMascot`), drawn from `art/owl_art.dart`
- `kuwago_logo` (`KuwagoLogo`, `PixelClock`)

(The old unused `sparkle_overlay`, `plant_widget`, `timer_controls`,
`models/plant_state` and `services/pomodoro_timer` were deleted on
2026-09-29.)

## 7. Code-generated art (`tool/`)

These are plain Dart scripts with no Flutter dependency, run with
`dart run`.

- `tool/generate_plants.dart`: builds the cactus, fern and lily stages
  (5 × 128×128) and growth frames (4 × 10), plus the `wilted/` sets for all
  four species (including the owner's sunflower), derived from the stage
  PNGs.
- `tool/generate_icon.dart`: renders the owl from `lib/art/owl_art.dart`
  into the launcher icon, adaptive foreground and splash image.

See [11-development-workflow.md](11-development-workflow.md) for commands.

## 8. Platform notes

- The target is Android only: there is no `ios/` folder, and
  `flutter_launcher_icons` runs with `ios: false`. `firebase_options.dart`
  (made by FlutterFire) also holds web, iOS, macOS and Windows entries. The
  `web/` folder is only used for the browser preview technique (see
  [11-development-workflow.md](11-development-workflow.md)).
  `firebase_options_ai.dart` is Android-only.
- `android/app/google-services.json` belongs to **rooted-f95c7**. The
  kuwago-ai config lives in `ai_project/google-services.json` and is
  **copied by hand** into `lib/firebase_options_ai.dart`. It is **not** put
  in `android/app`.
