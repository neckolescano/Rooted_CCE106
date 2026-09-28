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
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the grass loading screen IMMEDIATELY, then do the slow start-up
  // work (Firebase, loading the garden) behind it. Before, all of that
  // happened before anything was drawn — that was the black screen.
  runApp(const BootApp());
}

/// Shows [LoadingScreen] while [_boot] runs, then fades into the real app.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  double _progress = 0.05;
  Widget? _app; // the real app, once it's ready

  /// Even on a fast phone, keep the loading screen up this long so the
  /// grass animation is seen instead of flashing past.
  static const _minimumShow = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final startedAt = DateTime.now();
    final app = await _boot();
    final remaining = _minimumShow - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;
    _step(1);
    // Let the grass reach the end and the flower fully bloom.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _app = app);
  }

  void _step(double progress) {
    if (mounted) setState(() => _progress = progress);
  }

  /// Everything that used to run before runApp. Each step nudges the
  /// loading bar forward.
  Future<Widget> _boot() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (error) {
      // Most likely `flutterfire configure` hasn't been run yet.
      return SetupNeededApp(details: error.toString());
    }
    _step(0.3);

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
    _step(0.45);

    final storage = await StorageService.create();
    final plant = PlantModel();
    final notes = NotesModel();
    _step(0.6);

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
    _step(0.9);

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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _app ??
          MaterialApp(
            key: const ValueKey('loading'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: LoadingScreen(progress: _progress),
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
