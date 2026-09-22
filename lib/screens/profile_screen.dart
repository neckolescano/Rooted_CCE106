import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_panel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushRemindersOn = true;

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
                Text('Cozy member since 2026', style: AppTheme.body(size: 11, color: AppColors.accentGold)),
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
        ],
      ),
    );
  }
}
