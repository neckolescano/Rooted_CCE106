import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/notes_model.dart';
import 'models/plant_model.dart';
import 'models/session_model.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Needed because we call an async SharedPreferences method before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await StorageService.create();

  // Restore whatever plant progress was saved last time the app was open.
  final plant = PlantModel()
    ..loadFrom(stageIndex: storage.savedPlantStage, wilted: storage.savedPlantWilted);

  // Same idea for notes — whatever was last written is still there.
  final notes = NotesModel()..loadFrom(storage.savedNotes);

  runApp(RootedApp(storage: storage, plant: plant, notes: notes));
}

class RootedApp extends StatelessWidget {
  const RootedApp({super.key, required this.storage, required this.plant, required this.notes});

  final StorageService storage;
  final PlantModel plant;
  final NotesModel notes;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // .value because these are created once in main() and reused —
        // not recreated every rebuild.
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<PlantModel>.value(value: plant),
        // Lives at the root (like PlantModel) so Timer → Notes → Study
        // Material → back never loses what was typed.
        ChangeNotifierProvider<NotesModel>.value(value: notes),
        // A fresh SessionModel each time is fine — it only lives for the
        // duration of one Pomodoro session.
        ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
      ],
      child: MaterialApp(
        title: 'Rooted',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const LoginScreen(),
      ),
    );
  }
}
