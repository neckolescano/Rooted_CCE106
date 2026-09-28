import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_panel.dart';
import 'pixel_sprite.dart';

/// The player's picture: their photo if they've chosen one (optionally
/// shown as chunky pixels to match the game), otherwise the grown
/// sunflower.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.size});

  final double size;

  /// Photos are decoded this small when "pixel look" is on, then scaled
  /// up without smoothing — that's what makes them look like pixel art.
  static const _pixelResolution = 40;

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final bytes = storage.avatarBytes;

    if (bytes == null) {
      return PixelSprite(
        'assets/images/plant/stages/fullgrown.png',
        size: size,
        zoom: 1.5,
        fallbackIcon: Icons.person,
        semanticLabel: 'Your avatar',
      );
    }

    final pixel = storage.avatarPixelated;
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover, // square crop from the middle of the photo
      cacheWidth: pixel ? _pixelResolution : null,
      filterQuality: pixel ? FilterQuality.none : FilterQuality.medium,
      gaplessPlayback: true,
      semanticLabel: 'Your profile photo',
      errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: size * 0.5, color: AppColors.panelDark),
    );
  }
}

/// Opens the "Profile photo" scroll: pick from gallery, take a photo,
/// toggle the pixel look, or remove the photo.
Future<void> showAvatarOptions(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => const _AvatarOptionsDialog(),
  );
}

class _AvatarOptionsDialog extends StatelessWidget {
  const _AvatarOptionsDialog();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Shrunk + compressed by the picker itself (~20–30 KB), so it's
      // small enough to save in the user's Firestore document.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 75,
      );
      if (file == null) return; // closed the picker without choosing
      await storage.setAvatar(await file.readAsBytes());
    } catch (error) {
      debugPrint('Could not get photo: $error');
      messenger.showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? "Couldn't open the camera. Check the app's camera permission."
              : "Couldn't open your photos. Try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final hasPhoto = storage.avatarBytes != null;

    return PixelDialog(
      title: 'Profile photo',
      sealIcon: Icons.photo_camera,
      body: Column(
        children: [
          // Live preview of how it looks with the current settings.
          const PixelPanel(
            style: PanelStyle.wood,
            expand: false,
            padding: EdgeInsets.all(6),
            child: PixelPanel(
              style: PanelStyle.parchment,
              sunken: true,
              shadow: false,
              expand: false,
              padding: EdgeInsets.zero,
              child: ClipRect(child: ProfileAvatar(size: 96)),
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.grid_on, size: 18, color: AppColors.panelMedium),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Pixel look', style: AppTheme.body(size: 14, weight: FontWeight.w800)),
                ),
                Switch(
                  value: storage.avatarPixelated,
                  activeThumbColor: AppColors.accentGreen,
                  activeTrackColor: AppColors.greenDeep,
                  onChanged: storage.setAvatarPixelated,
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        PixelButton(
          label: 'Choose from gallery',
          icon: Icons.photo_library,
          onPressed: () => _pick(context, ImageSource.gallery),
        ),
        PixelButton(
          label: 'Take a photo',
          icon: Icons.photo_camera,
          onPressed: () => _pick(context, ImageSource.camera),
        ),
        if (hasPhoto)
          PixelButton(
            label: 'Remove photo',
            tone: ButtonTone.danger,
            onPressed: () => storage.setAvatar(null),
          ),
        PixelButton(
          label: 'Done',
          tone: ButtonTone.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
