# 11 — Development workflow

This page covers how to run, check, preview, generate art for and ship
changes to kuwaGO, and how to work with the owner.

---

## 1. Environment

- Windows 11, VS Code, Flutter SDK (Dart `>=3.0.0 <4.0.0`).
- Test phone: **itel S665L, Android 12 (API 31)**, often on slow mobile
  data.
- Secrets file: `app_check.local.json` in the project root (git-ignored).
  See [10-ai-and-firebase.md](10-ai-and-firebase.md#6-setup-checklist-for-a-new-developer-machine-or-phone).

## 2. Running

| Goal | How |
|---|---|
| Normal development | VS Code **F5 → "kuwaGO"** |
| Judge animation smoothness (window zoom, loading screen) | F5 → **"kuwaGO (profile — smooth animations)"**. Debug builds are much slower, so never judge smoothness in debug. |
| Terminal | `flutter run --dart-define-from-file=app_check.local.json` |

Both launch configurations are in `.vscode/launch.json` and pass the App
Check token.

## 3. Checks before calling a change done

```bash
flutter analyze
```

```bash
flutter test
```

- `flutter analyze` must be clean. Known intentional ignore: the nullable
  `aiFirebaseOptions` const in `lib/firebase_options_ai.dart`.
- Tests: `test/offline_study_maker_test.dart` (5 tests). There are no widget
  tests yet.
- After each batch, the **owner runs it on the phone**. The assistant's
  sandbox couldn't build Android (a Gradle loopback/network error), so
  device testing is the owner's step.

## 4. Browser preview (used by the assistant to check layouts)

The assistant can't see the phone, so layouts were checked in a web build
with fake data:

1. Create a temporary `lib/dev_preview.dart`. It sets up mocked
   `SharedPreferences` values and pumps the screen or widget to check. It
   must not touch real Firebase; `AuthService` is created lazily for this
   reason.
2. Build it:
   ```bash
   flutter build web -t lib/dev_preview.dart --release --no-tree-shake-icons --no-wasm-dry-run -o %TEMP%\rooted_preview
   ```
3. Serve the output with a small static server (a `serve.dart` in the
   session scratchpad, wired up through `.claude/launch.json`), then open
   it in the built-in browser at phone sizes (360×640 and 390×844).
4. **Delete all temporary files afterwards** (`lib/dev_preview.dart`, the
   launch config and the build output). None of them are committed.

This is how the window zoom (Option A) was previewed before the owner
approved building it.

## 5. Generating art and icons

| Task | Command | Output |
|---|---|---|
| Plant species + wilted sets | `dart run tool/generate_plants.dart` | `assets/images/plants/<id>/{stages,frames,wilted}`, `assets/images/plant/wilted` |
| Owl icon + splash images | `dart run tool/generate_icon.dart` | `assets/icon/*` (icon background #DCEFC8), including `splash_lockup.png` (the kuwaGO lockup, 1152 px = 288 dp) |
| Install launcher icons | `dart run flutter_launcher_icons` | Android mipmaps (adaptive, `ios: false`) |
| Install native splash | `dart run flutter_native_splash:create` | Android splash (#2A2440 night, Android 12 variant too) |
| Animated Android 12 splash (**always right after the line above**) | `dart run tool/generate_splash_anim.dart` | `res/drawable/splash_lockup_anim.xml` + points the v31 styles at it |

Run the icon steps in that order: generate, then launcher icons, then
splash. The icon generator imports `package:rooted/art/owl_art.dart`, so
if you edit the owl, the app mascot and the icon change together.

**Adding a plant species:**
1. Add its art to `assets/images/plants/<id>/` (same file names as the
   sunflower), or add a drawing function to `tool/generate_plants.dart`.
2. List its `stages/`, `frames/` and `wilted/` folders in `pubspec.yaml`.
   Flutter doesn't include subfolders automatically.
3. Add one `PlantSpecies` line to `lib/models/plant_catalog.dart`.
4. Optionally add a Player Card design that needs it
   (`lib/models/card_designs.dart`).

**Adding owner art:** export PNG at 1 art pixel = 1 image pixel, no
anti-aliasing. See the scale rule in
[09-design-system.md](09-design-system.md#4-pixel-art-rules) and the
checklist in [REDESIGN_PLAN.md](REDESIGN_PLAN.md) §5.

## 6. Where to tune things

| What | File |
|---|---|
| Colours, fonts, spacing, app name/tagline | `lib/theme/app_theme.dart` |
| XP, level size | `lib/models/garden_progress.dart` |
| Plants, unlock thresholds | `lib/models/plant_catalog.dart` |
| Badges | `lib/models/achievements.dart` |
| Player Card designs and quests | `lib/models/card_designs.dart` (+ drawing in `widgets/card_cover.dart`) |
| Focus-time steps and presets | `lib/widgets/focus_time_setter.dart` |
| AI models, timeouts, token limits | `lib/services/ai_service.dart` |
| AI prompt | `lib/services/study_material_prompt.dart` |
| Study option counts | `lib/models/study_options.dart` |
| Home owl lines, quotes | `lib/screens/home_screen.dart` (`_owlLines`, `_quoteFor`) |
| Owl pixel art | `lib/art/owl_art.dart` |

## 7. Git

- Branch: `main`. The owner commits themselves, in batches; commit
  messages so far are short ("profile card added", "initial api setup").
- **The assistant does not commit or push unless asked.**
- Never commit `app_check.local.json`, API keys or tokens. `*.log` and
  `/build/` are ignored.

## 8. Working with the owner (Necko)

These are the owner's stated preferences, from the handoff and the
conversation:

- **Small batches**, one phase at a time. Wait for the owner to test on
  the phone before starting the next batch.
- **Plain explanations**, and say **where values live** so the owner can
  change them.
- **Targeted edits with diffs**, never whole-file rewrites; the owner edits
  in VS Code at the same time.
- **Comments explain *why***, in simple words.
- **Owner art first:** the owner draws in Piskel and Figma. Code-drawn
  stand-ins are fine until the art exists, and code effects are fine.
- The owner likes to **see a preview before a big visual change** (for
  example the window transition: "can you show me how A works first?").
- When there are several ways to do something, give **options with a
  recommendation**. The owner picks (Option A for the transition, the owl
  from the icon ideas).
- **Ask before deleting files.**
- **Console steps are the owner's.** The assistant gives step-by-step
  instructions for the Firebase console, AI Studio and so on, and never
  enters credentials or tokens itself.
- Communication happens over a **sometimes unstable internet
  connection**. That is why the AI work was deferred at first, and why the
  AI has short timeouts and an offline fallback.
