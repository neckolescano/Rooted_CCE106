import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../services/intro_cue.dart';
import '../widgets/pixel_bottom_nav.dart';
import '../widgets/window_zoom.dart';
import 'home_screen.dart';
import 'garden_screen.dart';
import 'profile_screen.dart';
import 'timer_screen.dart';

/// Holds the bottom nav bar and swaps between the 3 main tabs.
/// IndexedStack keeps each screen's state alive when you switch tabs
/// (e.g. the garden scroll position isn't lost when you check Profile).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reopenUnfinishedSession());
  }

  /// If Android closed the app during a study session (or it finished
  /// while the app was closed), go straight back to the Timer — after the
  /// opening has finished, so the student sees Home for a moment first.
  void _reopenUnfinishedSession() {
    if (!mounted || !context.read<SessionModel>().isActive) return;
    if (IntroCue.stage.value != IntroStage.done) {
      void onStage() {
        if (IntroCue.stage.value != IntroStage.done) return;
        IntroCue.stage.removeListener(onStage);
        _reopenUnfinishedSession();
      }

      IntroCue.stage.addListener(onStage);
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !context.read<SessionModel>().isActive || TimerScreen.isOpen) return;
      Navigator.of(context).push(WindowZoom.throughWindowRoute<void>(const TimerScreen()));
    });
  }

  final _screens = const [
    HomeScreen(),
    GardenScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    PixelNavItem(icon: Icons.home, label: 'Home'),
    PixelNavItem(icon: Icons.eco, label: 'Garden'),
    PixelNavItem(icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    // WindowZoom wraps the WHOLE shell (nav bar included) so the "fly out
    // through the greenhouse window" zoom moves everything, like a camera.
    return WindowZoom(
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
        bottomNavigationBar: PixelBottomNav(
          items: _navItems,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
