# kuwaGO

**A cozy pixel-art study garden.** kuwaGO is an AI-assisted Pomodoro and
active-recall mobile app (Flutter, Android). Every completed focus session
grows a pixel plant; fully grown plants are harvested into a collectible
garden. Students can take notes during a session and turn them into
AI-generated study questions and flashcards. The mascot is **kuwago**, a
pixel owl (*kuwago* is Filipino for "owl").

> Originally built as **"Rooted: An AI-Assisted Pomodoro and Active Recall
> Mobile Application for Independent Student Learning"** for the CCE106
> course. The app was renamed **kuwaGO** during development; the Flutter
> package, folder and Firebase project IDs still use the old name `rooted`
> (see [docs/12-decision-log.md](docs/12-decision-log.md)).

---

## Status at a glance (as of 2026-09-29)

| Area | State |
|---|---|
| Core loop (study → grow → harvest → garden) | ✅ Working |
| Pixel UI redesign (all main screens) | ✅ Done |
| 4 collectible plant species + seed picker | ✅ Done |
| Wilted plant art | ✅ Done |
| AI study material (Gemini via Firebase AI Logic) | ✅ Working on the user's phone (after fixes) |
| Study options ("Grow your study patch") | ✅ Done |
| Offline (non-AI) study-card fallback | ✅ Done (keep/rename is an open question) |
| kuwaGO name + owl icon + splash + grass loading screen | ✅ Done |
| kuwago mascot (loading, login, Home) | ✅ Done |
| Profile: photo, editable name | ✅ Done |
| Player Card designs (8 designs + quests + shelf to equip) | ✅ Done |
| Timer survives app backgrounding/kill | ❌ Not built |
| Quiz flow / Summarize / Key concepts / Explain | ❌ Not built |

Details: [docs/02-requirements-current.md](docs/02-requirements-current.md) ·
open items: [docs/05-open-questions.md](docs/05-open-questions.md).

---

## Quick start (developer)

Requirements: Flutter SDK (Dart `>=3.0.0 <4.0.0`), an Android phone or
emulator, VS Code (the project has a launch config).

```bash
flutter pub get
```

1. **AI App Check token (one-time, per developer):** create
   `app_check.local.json` in the project root (it is git-ignored — never
   commit it):
   ```json
   { "APP_CHECK_DEBUG_TOKEN": "<any UUID>" }
   ```
   and register that UUID as an App Check debug token in the **kuwago-ai**
   Firebase project. Full steps: [AI_SETUP.md](AI_SETUP.md) and
   [docs/10-ai-and-firebase.md](docs/10-ai-and-firebase.md).
2. Run from VS Code with **F5 → "kuwaGO"** (passes
   `--dart-define-from-file=app_check.local.json`), or:
   ```bash
   flutter run --dart-define-from-file=app_check.local.json
   ```
3. Use **"kuwaGO (profile — smooth animations)"** to judge animation
   smoothness — debug builds are much slower.

Tests:

```bash
flutter test
```

---

## Documentation map

Read in this order if you are new to the project:

| # | Document | What's in it |
|---|---|---|
| 1 | [docs/01-product-overview.md](docs/01-product-overview.md) | Vision, core loop, identity, terminology, tone |
| 2 | [docs/02-requirements-current.md](docs/02-requirements-current.md) | Confirmed requirements and what is implemented now |
| 3 | [docs/03-mvp.md](docs/03-mvp.md) | What the MVP / course submission needs |
| 4 | [docs/04-future-roadmap.md](docs/04-future-roadmap.md) | Phase plan and future ideas |
| 5 | [docs/05-open-questions.md](docs/05-open-questions.md) | Unresolved decisions |
| 6 | [docs/06-architecture.md](docs/06-architecture.md) | App structure, state, screens, widgets, services, boot flow |
| 7 | [docs/07-data-model.md](docs/07-data-model.md) | Firestore, SharedPreferences, assets, models |
| 8 | [docs/08-business-rules.md](docs/08-business-rules.md) | Growth, XP, unlocks, streaks, badges, quests, timer rules |
| 9 | [docs/09-design-system.md](docs/09-design-system.md) | Colors, pixel rules, components, art pipeline |
| 10 | [docs/10-ai-and-firebase.md](docs/10-ai-and-firebase.md) | Firebase projects, App Check, Gemini models, AI behaviour |
| 11 | [docs/11-development-workflow.md](docs/11-development-workflow.md) | How to run, preview, generate art, test, and work with the owner |
| 12 | [docs/12-decision-log.md](docs/12-decision-log.md) | Every major decision and why |
| 13 | [docs/13-known-issues-and-tech-debt.md](docs/13-known-issues-and-tech-debt.md) | Bugs fixed, known limitations, cleanup candidates |

Older reference documents (still valid in parts, superseded where the
docs above say so):

- [AI_SETUP.md](AI_SETUP.md) — step-by-step AI / App Check setup.
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) — original Firebase (Auth +
  Firestore) setup guide.
- [docs/REDESIGN_PLAN.md](docs/REDESIGN_PLAN.md) — the 2026-09-28 redesign
  plan and **artwork checklist** (the app was later renamed and got a
  mascot; the checklist is still the art to-do list).

---

## Tech stack

Flutter / Dart · `provider` (ChangeNotifier) · `shared_preferences` ·
`google_fonts` (Press Start 2P + Nunito) · Firebase Auth · Cloud Firestore ·
Firebase AI Logic (`firebase_ai`, Gemini Developer API) · Firebase App Check ·
`google_sign_in` v7 · `image_picker` · dev tools: `flutter_launcher_icons`,
`flutter_native_splash`. Art: Figma mockups + Piskel pixel art, plus
code-generated sprites (`tool/`).

## Project layout (short)

```
lib/
  main.dart                 boot flow (BootApp → loading screen → app)
  firebase_options.dart     main Firebase project (rooted-f95c7)
  firebase_options_ai.dart  AI-only Firebase project (kuwago-ai)
  art/owl_art.dart          kuwago pixel art as text (drawn in code)
  models/                   plant, session, notes, catalog, progress, badges,
                            card designs, study material/options
  screens/                  loading, login, main shell, home, timer, notes,
                            study material, garden, profile
  services/                 auth, cloud (Firestore), storage, AI, AI Firebase,
                            offline study maker, prompt builder
  theme/app_theme.dart      design tokens + AppInfo (app name)
  widgets/                  pixel UI kit, scenes, mascot, dialogs, …
tool/                       sprite + icon generators (dart run tool/…)
assets/images/…             pixel art (see docs/07-data-model.md)
ai_project/                 google-services.json of the AI project (NOT android/app)
docs/                       this documentation
```

## Owner & working style

Built by **Necko** (student) on Windows + VS Code, testing on a physical
Android phone (itel S665L, Android 12). Prefers small batches, plain
explanations, targeted edits with diffs, comments that explain *why*, and
real pixel art over code-drawn art where possible. See
[docs/11-development-workflow.md](docs/11-development-workflow.md).
