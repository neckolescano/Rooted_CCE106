import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'models/notes_model.dart';
import 'models/plant_model.dart';
import 'models/session_model.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Needed because we call async methods before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    // Most likely `flutterfire configure` hasn't been run yet.
    runApp(SetupNeededApp(details: error.toString()));
    return;
  }

  final storage = await StorageService.create();
  final plant = PlantModel();
  final notes = NotesModel();

  // If someone was already signed in last time, load their data from
  // the database and drop them straight into the app.
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await storage.attachUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      isGuest: user.isAnonymous,
    );
    plant.loadFrom(stageIndex: storage.savedPlantStage, wilted: storage.savedPlantWilted);
    notes.loadFrom(storage.savedNotes);
  }

  runApp(RootedApp(storage: storage, plant: plant, notes: notes, startSignedIn: user != null));
}

class RootedApp extends StatelessWidget {
  const RootedApp({
    super.key,
    required this.storage,
    required this.plant,
    required this.notes,
    required this.startSignedIn,
  });

  final StorageService storage;
  final PlantModel plant;
  final NotesModel notes;
  final bool startSignedIn;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // .value because these are created once in main() and reused —
        // not recreated every rebuild.
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<PlantModel>.value(value: plant),
        // Lives at the root (like PlantModel) so Timer → Notes → Study
        // Material → back never loses what was typed.
        ChangeNotifierProvider<NotesModel>.value(value: notes),
        ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
      ],
      child: MaterialApp(
        title: 'Rooted',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: startSignedIn ? const MainShell() : const LoginScreen(),
      ),
    );
  }
}

/// Shown instead of crashing when Firebase hasn't been configured yet.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ALMOST THERE', style: AppTheme.pixelHeading(size: 16)),
                const SizedBox(height: 16),
                Text(
                  "Firebase isn't set up yet. Follow FIREBASE_SETUP.md in the "
                  "project folder, then run the app again.",
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 10, color: AppColors.textDark.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
