# 10 — AI and Firebase

This covers how Firebase is set up, how the AI feature works, and the full
history of how the AI was made to work, so nobody repeats the same dead
ends.

> **Secrets rule:** `app_check.local.json` holds the App Check debug token.
> It is **git-ignored**. Never commit it, never paste it in chat or docs.
> Never put a Gemini API key in the app. Firebase AI Logic removes the need
> for one.

---

## 1. Two Firebase projects

| | Main project | AI project |
|---|---|---|
| Project id | **rooted-f95c7** | **kuwago-ai** |
| Owner account | School Google account | Owner's **personal** Google account |
| Plan | Spark (free) | Spark (free) |
| Used for | Firebase Auth (Google, email, anonymous), Cloud Firestore, App Check (main) | Firebase AI Logic → **Gemini Developer API** only, plus its own App Check |
| Flutter app | Default `FirebaseApp` | Secondary `FirebaseApp` named **`'ai'`** |
| Config file | `android/app/google-services.json` + `lib/firebase_options.dart` | `ai_project/google-services.json` (**not** in android/app) → values copied by hand into `lib/firebase_options_ai.dart` |
| Android package | `com.example.rooted` | `com.example.rooted` (same app, registered in both) |

**Why two projects:** on the school project, Gemini returned
*"Your project has been denied access. Please contact support."* Google
restricts Gemini for some school or academic accounts. The fix was a free
project on a personal account used **only for AI**. Login, the database and
the garden stay on the main project. See
[12-decision-log.md](12-decision-log.md).

`AiFirebase` (`lib/services/ai_firebase.dart`):
- `init(provider)` starts the `'ai'` app with `aiFirebaseOptions` and
  activates App Check on it with **the same provider and debug token** as
  the main app.
- If `aiFirebaseOptions` is null, AI falls back to the main project.
- `AiFirebase.app` / `AiFirebase.appCheck` are what `AiService` uses.

Both projects show a banner: **Firebase will require multi-factor
authentication on console accounts from Oct 20, 2026.** Turn on 2-step
verification for both Google accounts.

## 2. App Check

| Build | Provider |
|---|---|
| Debug / profile | `AndroidDebugProvider(debugToken: String.fromEnvironment('APP_CHECK_DEBUG_TOKEN'))` |
| Release | `AndroidPlayIntegrityProvider()` |

- **Fixed debug token:** the value lives in `app_check.local.json`
  (`{"APP_CHECK_DEBUG_TOKEN": "<UUID>"}`) and is passed at build time with
  `--dart-define-from-file=app_check.local.json`. Both VS Code launch
  configurations do this. A fixed token survives reinstalls. Without it,
  the debug provider prints a new random token each install, and that token
  has to be registered again.
- The **same token must be registered in both projects**: App Check → Apps →
  the Android app → ⋮ → **Manage debug tokens** → Add.
- The app registration in App Check needs the debug keystore **SHA-256**
  (get it with `cd android && ./gradlew signingReport`).
- **Enforcement is OFF.** `AiService` checks for a token first and only
  *logs* the result (`[AI] App Check token OK`); it never blocks.
- **Play Integrity on rooted-f95c7:** registering it failed with "an error
  occurred while registering the service" (unresolved; see
  [05-open-questions.md](05-open-questions.md)). Release builds will need
  Play Integrity registered in the AI project before the AI works for other
  users.
- Harmless log noise: `DEVELOPER_ERROR` lines from Google Play services
  appear on the phone and can be ignored.

## 3. The AI feature (Gemini via Firebase AI Logic)

Entry point: `AiService.generateStudyMaterial(notes, [StudyOptions])`,
called by `NotesModel.generateStudyMaterial` from the Study Journal after
the "Grow your study patch" options scroll.

```
_checkAppCheckToken()                     // logs only
prompt = buildStudyMaterialPrompt(notes, options)
for model in _models:                     // in order
  for attempt in 1..2:                    // _triesPerModel = 2
    stop if total time > budget
    try  _ask(model)  → _parse → _fit → return
    AiServiceException (empty/garbled)  → rethrow (no retry)
    TimeoutException                    → next model
    quota (429 / RESOURCE_EXHAUSTED)    → next model
    busy (500/503/high demand/overloaded/unavailable) → wait 2 s × attempt, retry
    anything else                       → _explain → error shown
no model answered → OfflineStudyMaker (or "very busy" error)
offline (SocketException / host lookup) → OfflineStudyMaker (or "offline" error)
```

### Model order (`AiService._models`)

```
gemini-3.1-flash-lite   ← first: answered in ~5–6 s in testing
gemini-3.5-flash-lite   ← hung > 40 s in testing
gemini-3.5-flash        ← 429 quota exceeded in testing
gemini-3.8-flash        ← 429 quota exceeded in testing
```

The order is based on what worked on the owner's account. **This is why the
AI now works.** Before the change, the app waited on models that were over
quota or hanging, ran out of time, and always fell back to the offline
maker.

### Limits and timing (scale with request size)

`totalItems` = number of questions + flashcards asked for (up to 40).

| Setting | Formula | Example (5 + 5) | Example (20 + 20) |
|---|---|---|---|
| Per-request timeout | `20 + totalItems` s | 30 s | 60 s |
| Total time budget | `50 + totalItems` s | 60 s | 90 s |
| `maxOutputTokens` | `clamp(1024 + totalItems × 250, 2048, 8192)` | 3524 | 8192 |
| App Check token timeout | 10 s | | |

- `responseMimeType: 'application/json'`.
- **No `thinkingConfig`:** "low" thinking made Flash-Lite slower in testing
  (13 s vs 6 s).
- **Free-tier limits:** requests per minute and per day, set by Google per
  model. They **reset at midnight Pacific time**. The owner can see usage at
  **aistudio.google.com/rate-limit** (personal account). Bigger requests
  take longer but count as one request.

### Prompt (`study_material_prompt.dart`)
- Asks for **exact counts**, the chosen style (mixed / multiple choice /
  true-false / identification) and difficulty, and a strict JSON schema:
  - multiple choice: 4 choices, `answer` = exact choice text;
  - true/false: `["True","False"]`;
  - identification: a short term to type.
- Content must come from the student's notes.

### Parsing (`_parse`, `StudyMaterial.fromJson`)
- Strips ```json fences.
- A reply that isn't JSON or has the wrong shape → friendly "answer got
  scrambled" error.
- Snaps "B" or differently cased answers to the matching choice.
- True/false with no choices gets True/False added.
- `_fit` cuts the result to the requested counts.

### Errors shown to the student (`_explain`)

| Detected | Message (short) | Debug extra |
|---|---|---|
| Offline | "You seem to be offline…" | — |
| App Check | "The study AI can't verify this app yet…" | How to register the debug token |
| "denied access" | "The study AI isn't available for this app's account right now." | Use a personal-account project |
| Quota / 429 | "The study AI is busy right now (too many requests)…" | — |
| Permission / 403 / not enabled | "The study AI isn't switched on for this app yet." | Enable AI Logic → Gemini Developer API |
| Model not found | "The AI model this app uses isn't available anymore." | Change the model list |
| Safety / blocked | "The AI couldn't use these notes. Try rewording…" | — |
| Anything else | "Something went wrong… Please try again." | — |

Debug and profile builds append `[developer]` hints and the raw `[debug]`
error. Release builds show only the friendly line. The Notes error panel
shows up to 12 lines and a **Try again** button.

## 4. Offline fallback (not AI)

`OfflineStudyMaker` makes material on the phone when the AI is
busy, over quota, timing out or offline. The material has `offline: true`,
and the Study Patch screen shows a **"Made offline"** banner. The owner was
told plainly that it is **not** AI. Whether to keep it is open question Q1.
Rules: [08-business-rules.md](08-business-rules.md#10-study-material-ai-and-offline).
Tests: `test/offline_study_maker_test.dart` (5 tests).

## 5. Reading the Debug Console

Healthy run:
```
[AppCheck] Using the fixed debug token from app_check.local.json.
[AI] Using separate AI project "kuwago-ai".
[AI] App Check token OK
[AI] asking for 5 questions (mixed, normal) + 5 flashcards
[AI] sending request to gemini-3.1-flash-lite (project kuwago-ai)
[AI] got a response from gemini-3.1-flash-lite in 6s
[AI] kept 5 questions and 5 flashcards
```

| Log line | Meaning / fix |
|---|---|
| `No fixed debug token` | Not started with `--dart-define-from-file`. Use the VS Code "kuwaGO" configuration. |
| `No separate AI project configured` | `firebase_options_ai.dart` is null, so AI uses rooted-f95c7 (which is denied). |
| `App Check returned NO token` / 403 App Check | Debug token not registered in **kuwago-ai**. |
| `denied access` | The request went to the school project. Check the AI project config. |
| `is busy (quota)` for every model | Daily free quota used up. Wait for the midnight-Pacific reset. |
| `took over Ns — trying the next model` | That model hangs; the order might need changing. |
| `using the offline backup` | No model answered, so the rule-based cards were used. |

## 6. Setup checklist for a new developer machine or phone

1. `flutter pub get`.
2. Create `app_check.local.json` with a new UUID (PowerShell:
   `[guid]::NewGuid()`), saved **without a BOM**. A PowerShell-written BOM
   broke this once.
3. Register that UUID as a debug token in **kuwago-ai** (and rooted-f95c7).
4. If the machine uses a different debug keystore, add its SHA-1 and
   SHA-256 to the Android app in both projects. SHA-1 is needed for Google
   Sign-In on the main project.
5. Run with F5 → "kuwaGO".

Step-by-step console screenshots are described in
[AI_SETUP.md](../AI_SETUP.md). Its troubleshooting section still refers to
`_modelName`; the code now uses the `_models` list.

## 7. Authentication (main project)

- Providers: **Google** (native `google_sign_in` v7 → Firebase credential;
  needs the SHA-1 registered), **Email/Password** (create or sign in in a
  scroll dialog), **Anonymous** (guest).
- `AuthService.friendlyError` maps auth errors to readable messages.
- Signing out a guest warns that the garden will be lost.
- Firestore rules: owner-only access to `users/{uid}/**` (see
  [07-data-model.md](07-data-model.md)).
