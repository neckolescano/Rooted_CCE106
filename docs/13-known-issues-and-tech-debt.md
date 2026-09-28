# 13 — Known issues, limitations and tech debt

State as of commit `8e796c9` (2026-09-29). Open **decisions** are in
[05-open-questions.md](05-open-questions.md); this page lists **facts**:
what is broken or limited, and what was already fixed, so fixed bugs don't
come back.

---

## 1. Known limitations (not fixed)

| # | Issue | Impact | Planned fix |
|---|---|---|---|
| K1 | **Timer isn't persistent.** `SessionModel` counts with `Timer.periodic`; nothing is saved. | If Android pauses or kills the app mid-session, time drifts or the session is lost. | `endsAt` timestamp + save the active session ([04](04-future-roadmap.md#2-timer-and-sessions)). |
| K2 | **Completion logic lives in `TimerScreen`.** | Works only while that screen exists. Back now asks to give up, which avoids the old orphaned timer. | Root-level `GardenController`. |
| K3 | **No real completed-sessions counter.** It is estimated as `harvested × 4 + stage`. | XP, levels, unlocks, badges and card quests are all estimates. They are correct under the current rules but fragile if the growth rules change (for example rounds). | Save `completedSessions` (plus the planned `PlayerStats`). |
| K4 | `totalSessions` counts give-ups too. | "Sessions" on the stats ledger includes attempts. | Split it into completed and attempted. |
| K5 | **Streak counts sessions in a row**, not days. | Labelled "in a row", so it isn't misleading, but it isn't a daily habit streak. | Q7. |
| K6 | **Badges and card quests can "un-earn".** They are computed from current numbers. | After giving up, "On a Roll" and "Starry Night" progress drop back. | Store an earned flag once unlocked (if the owner wants that). |
| K7 | ~~Player Card shelf not built.~~ **Fixed 2026-09-29** (`widgets/card_design_shelf.dart`). | — | — |
| K8 | **Push Reminders toggle is UI only.** | Does nothing. | Q9. |
| K9 | **Generated study material isn't saved.** | Leaving the Study Patch loses it; generating again costs AI quota. | Q16. |
| K10 | **Single notes slot.** | One journal text per user, not per session. | Multiple notes ([04](04-future-roadmap.md#4-study-tools-ai)). |
| K11 | **Free-tier AI quota.** | Daily limits per model (reset at midnight Pacific). When everything is used up, only offline cards are made. | Paid tier or a different provider; not discussed. |
| K12 | **Model availability can change.** The Gemini model names are hard-coded. | Google can retire or re-quota models. | Update `AiService._models`; check the log. |
| K13 | **App Check isn't enforced; Play Integrity isn't registered.** | Fine for development. **Release builds will fail AI App Check** until Play Integrity is registered in kuwago-ai. | [10](10-ai-and-firebase.md#2-app-check), Q13. |
| K14 | **Window zoom not confirmed smooth on the device.** | Unknown; debug builds are slow. | The owner tests with the profile build (Q11). |
| K15 | **Fly-back snapshot is stale.** The reverse zoom reuses the snapshot taken before the session. | For a moment it shows the pre-session plant or state, then the live Home. | Re-snapshot before the reverse, or cross-fade. |
| K16 | **Guest accounts can't be upgraded.** | Signing out a guest loses the garden (the app warns). | Link credentials ([04](04-future-roadmap.md#6-profile-and-account)). |
| K17 | **Minimum focus time is 1 minute.** | Growth and XP can be farmed quickly. | Q8. |
| K18 | **Firestore rules aren't in the repo** (they're only in the console, text in FIREBASE_SETUP.md). | Could drift unnoticed. | Optionally add `firestore.rules` + `firebase.json` config. |
| K19 | **Session log is write-only.** `users/{uid}/sessions` is never read. | None yet. | Could feed real stats (K3, K4). |
| K20 | **Package and ids still say `rooted`** (Dart package, application id `com.example.rooted`, main Firebase project). | Cosmetic, but `com.example.*` can't be published to the Play Store. | Q14. |
| K21 | **MFA requirement:** Firebase console accounts need MFA from **Oct 20, 2026**. | The owner could lose console access. | Turn on 2-step verification on both Google accounts. |
| K22 | **Only offline-maker tests exist.** | No widget or model tests for growth, XP or storage. | Add tests for `GardenProgress`, `PlantModel`, `StudyOptions`, `StudyQuestion` parsing. |
| K24 | **Animated splash hand-off not yet tested on a device.** `MainActivity.kt` sends Flutter the splash icon's exact position, so the navigation bar is accounted for. The Kotlin code couldn't be compiled in the assistant's environment (Gradle blocked); the XML resources were validated with aapt2. | If the Kotlin fails to build, the owner will see a build error. | Check the first phone run. |
| K25 | **`flutter_native_splash:create` overwrites the Android 12 styles.** | The animated icon would be replaced by the still image. | Always run `dart run tool/generate_splash_anim.dart` straight after it (noted in `pubspec.yaml`). |
| K26 | **Early bug:** the first packet opening skipped its animation when the phone's animation scale was off (Flutter reads that as "reduce motion"). | The owner saw no tear. | Fixed: the opening always plays (it no longer checks reduce-motion). |
| K23 | **Stale docs.** `AI_SETUP.md` troubleshooting and the "model not found" developer hint in `AiService._explain` both say to change `_modelName`, but the code uses the `_models` list. `FIREBASE_SETUP.md` and `REDESIGN_PLAN.md` predate the rename. | Could confuse a new developer. | Update the wording. |

## 2. Harmless things that look like problems

- **Debug builds are slow and janky**, especially the window zoom and
  loading screen. Use "kuwaGO (profile — smooth animations)" to judge.
- **`DEVELOPER_ERROR` log lines** from Google Play services on the phone:
  harmless.
- **`[AppCheck] No fixed debug token…`** appears only when the app is run
  without `--dart-define-from-file`.
- **Firebase console MFA banner:** informational until Oct 20, 2026 (K21).

## 3. Tech debt / cleanup candidates

- **Unused files** (ask the owner before deleting):
  - `lib/widgets/sparkle_overlay.dart` (replaced by the new harvest effects)
  - `lib/widgets/plant_widget.dart`
  - `lib/widgets/timer_controls.dart`
  - `lib/models/plant_state.dart`
  - `lib/services/pomodoro_timer.dart`
- **Spec widgets folded into others:** `PixelStepper`, `PixelChoiceChips`
  and `PixelToast` were never built as separate widgets. If more screens
  need them, extract them from `focus_time_setter.dart` and
  `study_options_dialog.dart`.
- **Code-drawn stand-ins** waiting for owner art: see
  [04-future-roadmap.md §8](04-future-roadmap.md#8-art-owner-draws-code-stand-ins-exist).
- **Plant sprite offset hack:** plants are shifted down about 0.19–0.22 ×
  size because the sprites have empty bottom rows. Trimming the art would
  remove the need for this.
- **Avatar in the user document:** about 30 KB base64 in `users/{uid}`,
  fine for Firestore's 1 MB limit, and uploaded separately from the
  regular sync.

## 4. Bugs already fixed (don't reintroduce)

| Bug | Fix | Where |
|---|---|---|
| Opening the Timer "fast-forwarded" because of a leftover `completed` status | `_sessionStarted` flag | `timer_screen.dart` |
| `setState during build` from starting the session in `initState` | `start()` in `addPostFrameCallback` | `timer_screen.dart` |
| Finishing while fully grown did nothing | Harvest flow | `timer_screen.dart` |
| Bottom nav 3 px overflow on the selected tab | Equal border space on all tabs | `pixel_bottom_nav.dart` |
| Timer rendered on black | Own `Scaffold` | `timer_screen.dart` |
| Android back during a session orphaned the timer | `PopScope` → give-up question | `timer_screen.dart` |
| One tap on Give Up wilted the plant | Confirmation scroll | `timer_screen.dart` |
| Timer ended under a popup, `pop()` closed the popup, and the screen "froze" | `_closeEverythingOnTop()` before popping | `timer_screen.dart` |
| Harvest dialog art stretched (Dialog's 280 min width) | `LayoutBuilder`-scaled layout | `harvest_celebration_dialog.dart` |
| Black screen on boot | Native splash + `BootApp` loading screen | `main.dart` |
| Stage images popped in late on the loading screen | Precache | `loading_screen.dart` |
| Login grey in the web preview (AuthService built at build time) | `late final _auth` | `login_screen.dart` |
| Plant floated above planter | Offset for empty sprite rows | greenhouse / garden |
| Owl looked grumpy or sleepy | 4×4 eyes, centred 2×2 pupils | `owl_art.dart` |
| Fern noisy / lily thin | Redrawn in generator | `tool/generate_plants.dart` |
| PNG decoder read past IEND | Stop at IEND | `tool/generate_plants.dart` |
| Ragged paper edge via `BlendMode.clear` looked wrong | Draw row by row | `pixel_scroll.dart` |
| Duplicate entry in the stop-word const set | Removed | `offline_study_maker.dart` |
| `app_check.local.json` had a BOM (written by PowerShell) | Rewritten without BOM | (local file) |
| AI: unregistered debug token | Fixed token + registration | D38 |
| AI: "project denied access" | Separate kuwago-ai project | D39 |
| AI: 500 high demand | Retries + fallback | D40 |
| AI: timeouts and 429s → always offline | Model order, 3.1-flash-lite first | D42 |

**Retracted "bug":** REDESIGN_PLAN.md §2 bug #4 claimed `memberSinceYear`
was never uploaded. That was wrong: it is derived from Firestore
`createdAt` when loading, so it survives reinstalls.
