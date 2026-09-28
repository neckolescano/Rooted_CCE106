import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'models/notes_model.dart';
import 'models/plant_model.dart';
import 'models/session_model.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/ai_firebase.dart';
import 'services/intro_cue.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show kuwago's opening IMMEDIATELY, then do the slow start-up work
  // (Firebase, loading the garden) behind it. Before, all of that
  // happened before anything was drawn — that was the black screen.
  runApp(const BootApp());
}

/// The opening (the kuwaGO clock) on top; the real app is built underneath
/// as soon as start-up is done. The clock dings, a circle opens out of the
/// O onto the app, and the lockup / kuwago carry on into the login or home
/// page — after which the opening is removed. The app itself is never
/// rebuilt or moved, so nothing flickers.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  Widget? _app; // the real app, once start-up has finished
  bool _introGone = false;

  @override
  void initState() {
    super.initState();
    // The first page waits for the opening before showing the pieces it
    // carries in (see IntroCue).
    IntroCue.stage.value = IntroStage.covering;
    // Let the opening get its first frames out smoothly before the heavy
    // start-up work (Firebase, loading the garden) begins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 150), _start);
    });
  }

  Future<void> _start() async {
    final app = await _boot();
    if (mounted) setState(() => _app = app);
  }

  /// Everything that used to run before runApp (behind the opening).
  Future<Widget> _boot() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (error) {
      // Most likely `flutterfire configure` hasn't been run yet.
      return SetupNeededApp(details: error.toString());
    }

    // App Check proves to Firebase that AI requests come from your real
    // app. While developing (debug + profile builds) the "debug" provider
    // is used with a FIXED token from app_check.local.json, so it survives
    // reinstalls — register it once in the Firebase console (AI_SETUP.md).
    // Release builds use Play Integrity.
    const debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
    final AndroidAppCheckProvider appCheckProvider = kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : AndroidDebugProvider(debugToken: debugToken.isEmpty ? null : debugToken);
    try {
      await FirebaseAppCheck.instance.activate(providerAndroid: appCheckProvider);
      if (!kReleaseMode) {
        debugPrint(debugToken.isEmpty
            ? '[AppCheck] No fixed debug token (run with --dart-define-from-file=app_check.local.json). '
                'A random one will be printed by DebugAppCheckProvider — register it for AI to work.'
            : '[AppCheck] Using the fixed debug token from app_check.local.json.');
      }
    } catch (error) {
      debugPrint('App Check could not start: $error');
    }
    // The separate Firebase project used only for AI (if configured).
    await AiFirebase.init(appCheckProvider);

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
      plant.loadFrom(
        stageIndex: storage.savedPlantStage,
        wilted: storage.savedPlantWilted,
        speciesId: storage.savedPlantSpecies,
      );
      notes.loadFrom(storage.savedNotes);
    }

    return RootedApp(
      key: const ValueKey('app'),
      storage: storage,
      plant: plant,
      notes: notes,
      startSignedIn: user != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_app != null) _app!,
          if (!_introGone)
            LoadingScreen(
              appReady: _app != null,
              onRevealed: () => setState(() {
                _introGone = true;
                IntroCue.stage.value = IntroStage.done; // same frame: the real pieces appear as the flyers vanish
              }),
            ),
        ],
      ),
    );
  }
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
        title: AppInfo.name,
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
                  style: AppTheme.body(size: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
