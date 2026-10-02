# Firebase setup (accounts + database)

How the main Firebase project (login + database) was set up. This repo is
already connected to it; follow these steps only to connect the app to a
Firebase project of your own. Total time: about 15 minutes.

## 1. Packages
Already in `pubspec.yaml`, so just run:

```
flutter pub get
```

## 2. Create the Firebase project
1. Go to https://console.firebase.google.com and sign in with Google.
2. **Create a project** → name it `rooted` → Google Analytics is optional (off is fine) → **Create**.

## 3. Turn on sign-in methods
Left menu → **Build → Authentication → Get started → Sign-in method**.
Enable all three:
- **Email/Password**
- **Anonymous** (this powers "Play as Guest Trainee")
- **Google** (pick a support email → Save)

## 4. Create the database
Left menu → **Build → Firestore Database → Create database**.
- Location: pick the closest one (for the Philippines, `asia-southeast1` Singapore). This can't be changed later.
- Choose **Production mode** → **Enable**.

Then open the **Rules** tab, replace everything with this, and **Publish**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Each signed-in user can only read/write their OWN data.
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 5. Connect the app to your Firebase project
Install the tools once (needs Node.js from https://nodejs.org):

```
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

If `flutterfire` isn't recognised afterwards, add
`%LOCALAPPDATA%\Pub\Cache\bin` to your PATH and reopen the terminal.

Then, in the project folder:

```
flutterfire configure
```

Pick your `rooted` project and tick **android**. This replaces
`lib/firebase_options.dart` and adds `android/app/google-services.json`.

## 6. Android minimum version
Open `android/app/build.gradle.kts` (or `build.gradle`) and set:

```
minSdk = 23
```

(replace `flutter.minSdkVersion` if that's what's there.)

## 7. Run it
```
flutter run
```
Create an account, then look at **Firestore Database → Data** in the
console: a `users` collection with your document should appear, and a
`sessions` subcollection fills in as you finish or give up sessions.

## What gets stored

The main fields are below. The full, current list is in
[docs/07-data-model.md](docs/07-data-model.md).

```
users/{uid}
   username, email, isGuest
   streak, totalSessions, harvestedPlants
   plantStage, plantWilted
   notes
   createdAt, updatedAt
users/{uid}/sessions/{autoId}
   completed (true/false), seconds, endedAt
```

## Troubleshooting
- **"Firebase isn't set up yet" screen** → step 5 wasn't done (or failed).
- **Google sign-in fails** → in the Firebase console open Project settings →
  your Android app → **Add fingerprint**. Get it by running
  `cd android` then `.\gradlew signingReport` and copying the debug `SHA1`
  (and `SHA-256`). Then run `flutterfire configure` again.
- **Build errors after adding packages** → `flutter clean`, then `flutter pub get`.
- **Guest accounts**: a guest has no password, so signing out of a guest
  account loses that garden (the app warns before it happens).
