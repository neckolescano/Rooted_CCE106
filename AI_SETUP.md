# AI study material setup (Firebase AI Logic + Gemini)

The app sends your notes to Gemini through Firebase. No AI key is stored
in the app. Free on the Spark plan, no credit card.

## 1. Add the packages
```
flutter pub add firebase_ai firebase_app_check
flutter pub get
```

## 2. Turn on AI Logic in the Firebase console
1. Open your project → **AI Services → AI Logic → Get started**.
2. Choose **Gemini Developer API** (the free one) and finish the guided steps.
   This also turns on **App Check** protection for it.

## 3. Register your debug token (App Check) — do this ONCE
In debug/profile builds the app proves itself with a "debug token".
This project uses a FIXED token so it survives uninstall/reinstall:

1. Open `app_check.local.json` in the project root (it is git-ignored —
   never commit or share it) and copy the `APP_CHECK_DEBUG_TOKEN` value.
2. In the Firebase console go to **Security → App Check → Apps**, find your
   Android app, click **⋮ → Manage debug tokens → Add debug token**, give it
   a name (e.g. "my phone") and paste the value. Save.
3. Run the app with the token:
   - VS Code: press F5 and pick **kuwaGO** (`.vscode/launch.json` passes it), or
   - terminal: `flutter run --dart-define-from-file=app_check.local.json`
4. Tap **Generate Study Material**. The Debug Console should show
   `[AppCheck] Using the fixed debug token` and `[AI] App Check token OK`.

Lost the file? Make a new one with any UUID (e.g. PowerShell
`[guid]::NewGuid()`) and register that instead.

If your app isn't listed under App Check → Apps, see "Enforce App Check
without a production attestation provider (debug provider only)" in
https://firebase.google.com/docs/ai-logic/app-check

## Separate AI project (if Gemini says "Your project has been denied access")
Google sometimes restricts Gemini for school/academic accounts. The fix: a
second, free Firebase project on a PERSONAL Google account, used only for AI.
Login, Firestore and the garden stay on the main project.
1. Personal Google account → console.firebase.google.com → Add project
   (e.g. "kuwago-ai", Google Analytics off).
2. AI Services → AI Logic → Get started → Gemini Developer API.
3. Add an Android app, package name `com.example.rooted`, SHA-256 of the
   debug key. Download its google-services.json and save it as
   `ai_project/google-services.json` in THIS folder (NOT android/app!).
4. App Check → register that Android app (Play Integrity, same SHA-256),
   then ⋮ → Manage debug tokens → add the SAME token as app_check.local.json.
5. The values from that file go into `lib/firebase_options_ai.dart`.
   The Debug Console then shows `[AI] Using separate AI project "…"`.

## Troubleshooting
- **403 / PERMISSION_DENIED / "App Check"** → step 3 (token not registered yet).
- **"model not found" / mentions the model name** → Google retired the model.
  Change `_modelName` in `lib/services/ai_service.dart` to a current Flash
  model from https://firebase.google.com/docs/ai-logic/models
- **Nothing happens / build error about `firebase_ai`** → step 1, then `flutter clean`.
- In debug builds the error box shows a `[debug]` line with the real reason.

## Before you release the app
App Check must stay ON and you need a production provider (Play Integrity)
registered, otherwise real users can't use the AI feature. The debug token
only works on your own development devices.
