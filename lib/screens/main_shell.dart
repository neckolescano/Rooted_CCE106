import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'garden_screen.dart';
import 'profile_screen.dart';

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

  final _screens = const [
    HomeScreen(),
    GardenScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      // IMPORTANT: this needs an explicit height. Without one, the Row
      // below is handed unbounded vertical space and stretches to fill
      // the whole screen instead of staying a slim bar — that's the bug
      // you saw where "Home" took over the entire page.
      bottomNavigationBar: SizedBox(
        height: 76, // a little breathing room beyond the tightest fit
        child: Container(
          decoration: const BoxDecoration(color: AppColors.panelDark),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _navItem(icon: Icons.home, label: 'Home', index: 0),
                _navItem(icon: Icons.eco, label: 'Garden', index: 1),
                _navItem(icon: Icons.person, label: 'Profile', index: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.panelMedium : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            // Always reserve the same 1.5px border, just invisible when
            // not selected. Only having a border on the SELECTED item
            // used to shrink that one item's available content height
            // by 3px (1.5 top + 1.5 bottom) compared to the others —
            // that was the exact cause of the "overflowed by 3.0
            // pixels" warning you saw on the Home tab.
            border: Border.all(
              color: isSelected ? AppColors.accentGold : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textCream, size: 22),
              const SizedBox(height: 4),
              Text(label, style: AppTheme.body(size: 10, color: AppColors.textCream, weight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
