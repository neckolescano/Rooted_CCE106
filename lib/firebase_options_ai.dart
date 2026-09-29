// Firebase settings for the SEPARATE project used only for AI features
// (Gemini via Firebase AI Logic). Everything else — login, Firestore, the
// garden — stays on the main project in firebase_options.dart.
//
// Why a second project: Google restricted Gemini API access for the main
// (school-account) project. See AI_SETUP.md → "Separate AI project".
//
// Values copied from ai_project/google-services.json (project "kuwago-ai",
// owned by a personal Google account). Set this to null to go back to
// using the main project for AI.
//
// (Firebase API keys identify the project; they aren't passwords. Access
// is protected by App Check.)

import 'package:firebase_core/firebase_core.dart';

// Nullable on purpose, so it can be switched back to null.
// ignore: unnecessary_nullable_for_final_variable_declarations
const FirebaseOptions? aiFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB9w4NkdV2iU2neF9s9kc3UQNexK89fczw',
  appId: '1:71783852373:android:efd93dc78b1a728ab9a7dc',
  messagingSenderId: '71783852373',
  projectId: 'kuwago-ai',
  storageBucket: 'kuwago-ai.firebasestorage.app',
);
