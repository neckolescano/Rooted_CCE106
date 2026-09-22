import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  runApp(RootedApp(storage: storage, plant: plant));
}

class RootedApp extends StatelessWidget {
  const RootedApp({super.key, required this.storage, required this.plant});

  final StorageService storage;
  final PlantModel plant;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // .value because these are created once in main() and reused —
        // not recreated every rebuild.
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<PlantModel>.value(value: plant),
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
