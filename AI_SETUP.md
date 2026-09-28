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

## 3. Register your debug token (App Check)
In debug builds the app proves itself with a "debug token".
1. Run the app and tap **Generate Study Material** once. It will probably
   fail the first time — that's expected.
2. In the terminal / Debug Console, find a line like:
   `DebugAppCheckProvider: Enter this debug secret into the allow list in the Firebase Console for your project: 123a4567-...`
3. Copy the token. In the console go to **Security → App Check → Apps**,
   find your Android app, click **⋮ → Manage debug tokens**, and add it.
4. Tap **Generate Study Material** again.

If your app isn't listed under App Check → Apps, see "Enforce App Check
without a production attestation provider (debug provider only)" in
https://firebase.google.com/docs/ai-logic/app-check

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
