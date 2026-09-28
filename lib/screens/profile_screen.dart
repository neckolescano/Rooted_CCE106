import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_panel.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushRemindersOn = true;

  Future<void> _signOut() async {
    final storage = context.read<StorageService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Sign out?', style: AppTheme.body(size: 16, weight: FontWeight.bold)),
        content: Text(
          storage.isGuest
              ? "You're on a guest account. Signing out will lose this garden "
                  "for good, because there's no login to get back into it."
              : 'Your garden is saved to your account. Sign back in any time to pick up where you left off.',
          style: AppTheme.body(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final plant = context.read<PlantModel>();
    final notes = context.read<NotesModel>();
    final session = context.read<SessionModel>();

    await storage.detachUser(); // saves anything pending, then clears this device
    await AuthService().signOut();

    plant.loadFrom(stageIndex: 0, wilted: false);
    notes.reset();
    session.reset();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          PixelPanel(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.panelLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 40, color: AppColors.textCream),
                ),
                const SizedBox(height: 12),
                Text(storage.username, style: AppTheme.body(size: 16, color: AppColors.textCream, weight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (storage.isGuest)
                  Text('Guest account', style: AppTheme.body(size: 11, color: AppColors.textCream))
                else if (storage.email.isNotEmpty)
                  Text(storage.email, style: AppTheme.body(size: 11, color: AppColors.textCream)),
                const SizedBox(height: 2),
                Text('Cozy member since ${storage.memberSinceYear}',
                    style: AppTheme.body(size: 11, color: AppColors.accentGold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('COZY SETTINGS', style: AppTheme.body(size: 13, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          PixelPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Push Reminders', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                Switch(
                  value: _pushRemindersOn,
                  activeColor: AppColors.accentGreen,
                  onChanged: (value) => setState(() => _pushRemindersOn = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PixelPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cottage Parchment', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                Text('ACTIVE', style: AppTheme.body(size: 11, color: AppColors.accentGold, weight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PixelPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('About Study Buddy', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                const Icon(Icons.chevron_right, color: AppColors.textCream),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _signOut,
            child: PixelPanel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sign Out', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                  const Icon(Icons.logout, color: AppColors.textCream, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
