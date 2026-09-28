import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/achievements.dart';
import '../models/garden_progress.dart';
import '../models/notes_model.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_dialog.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_progress_bar.dart';
import '../widgets/pixel_section_header.dart';
import '../widgets/pixel_sprite.dart';
import '../widgets/scene_frame.dart';
import 'login_screen.dart';

/// The player's profile, laid out like a game character sheet: a meadow
/// cover with the avatar framed on top, stat tiles, earnable badges, and
/// the settings in one parchment "notebook".
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI only for now — reminders aren't sent yet (see the backlog).
  bool _pushRemindersOn = true;

  Future<void> _signOut() async {
    final storage = context.read<StorageService>();

    final confirmed = await showPixelConfirm(
      context,
      title: 'Sign out?',
      sealIcon: Icons.logout,
      message: storage.isGuest
          ? "You're on a guest account. Signing out will lose this garden "
              "for good, because there's no login to get back into it."
          : 'Your garden is saved to your account. Sign back in any time to pick up where you left off.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay',
      danger: storage.isGuest,
    );
    if (!confirmed || !mounted) return;

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

  void _showAbout() {
    showPixelMessage(
      context,
      title: 'Study Buddy',
      sealIcon: Icons.spa,
      body: Text(
        'A cozy pixel garden where studying grows your world.\n\n'
        'Finish a focus session and your plant grows one stage. '
        'Grow it all the way and it moves into your garden. '
        'Give up early and it wilts — but it can always recover.\n\n'
        'Made for CCE106.',
        textAlign: TextAlign.center,
        style: AppText.body(),
      ),
    );
  }

  void _showBadge(GardenBadge badge) {
    showPixelMessage(
      context,
      title: badge.name,
      buttonLabel: 'Nice',
      sealIcon: Icons.emoji_events,
      sealColor: WaxSeal.gold,
      body: Column(
        children: [
          _BadgeMedallion(badge: badge, size: 72),
          const SizedBox(height: AppSpacing.md),
          Text(badge.howToEarn, textAlign: TextAlign.center, style: AppText.body()),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge.earned ? 'EARNED' : 'NOT YET',
            style: AppText.small(
              color: badge.earned ? AppColors.greenDeep : AppColors.textMuted,
              weight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final plant = context.watch<PlantModel>();
    final progress = GardenProgress.from(
      harvestedPlants: storage.harvestedPlants,
      plantStageIndex: plant.stage.index,
    );
    final badges = badgesFor(
      completedSessions: progress.completedSessions,
      harvestedPlants: storage.harvestedPlants,
      streak: storage.streak,
      gardenLevel: progress.level,
    );
    final earned = badges.where((b) => b.earned).length;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        _CoverAndAvatar(level: progress.level),
        const SizedBox(height: AppSpacing.md),
        Text(
          storage.username,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.pixelHeading(size: 15),
        ),
        const SizedBox(height: 6),
        Text(
          storage.isGuest ? 'Guest account' : storage.email,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.small(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Center(
          child: PixelPanel(
            style: PanelStyle.dark,
            expand: false,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.spa, size: 14, color: AppColors.accentGreen),
                const SizedBox(width: 6),
                Text('Cozy member since ${storage.memberSinceYear}', style: AppText.caption(color: AppColors.accentGold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PixelSectionHeader(
          'Garden level ${progress.level}',
          trailing: Text(
            '${progress.xpIntoLevel} / ${GardenProgress.xpPerLevel} XP',
            style: AppText.small(color: AppColors.textMuted),
          ),
        ),
        PixelProgressBar(
          value: progress.levelProgress,
          height: 16,
          fillColor: AppColors.accentGold,
          semanticLabel: 'Garden experience',
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _StatTile(icon: Icons.timer, value: '${progress.completedSessions}', label: 'Focus sessions')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(icon: Icons.local_florist, value: '${storage.harvestedPlants}', label: 'Plants grown')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(icon: Icons.local_fire_department, value: '${storage.streak}', label: 'In a row')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(icon: Icons.emoji_events, value: '$earned', label: 'Badges')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        PixelSectionHeader(
          'Badges',
          trailing: Text('$earned / ${badges.length} earned', style: AppText.small(color: AppColors.textMuted)),
        ),
        Row(
          children: [
            for (var i = 0; i < badges.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Semantics(
                    button: true,
                    label: '${badges[i].name}, ${badges[i].earned ? 'earned' : 'not earned yet'}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _showBadge(badges[i]),
                      child: _BadgeMedallion(badge: badges[i]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const PixelSectionHeader('Cozy settings'),
        PixelPanel(
          style: PanelStyle.parchment,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.notifications,
                title: 'Push Reminders',
                trailing: Switch(
                  value: _pushRemindersOn,
                  activeThumbColor: AppColors.accentGreen,
                  activeTrackColor: AppColors.greenDeep,
                  onChanged: (value) => setState(() => _pushRemindersOn = value),
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.palette,
                title: 'Cottage Parchment',
                trailing: Text('ACTIVE', style: AppText.small(color: AppColors.greenDeep, weight: FontWeight.w900)),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.info_outline,
                title: 'About Study Buddy',
                trailing: const Icon(Icons.chevron_right, color: AppColors.panelMedium),
                onTap: _showAbout,
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.logout,
                title: 'Sign Out',
                titleColor: AppColors.dangerText,
                trailing: const SizedBox.shrink(),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Meadow banner with the avatar frame overlapping its bottom edge and a
/// level badge pinned to the frame's corner.
class _CoverAndAvatar extends StatelessWidget {
  const _CoverAndAvatar({required this.level});

  final int level;

  static const double _coverHeight = 150;
  static const double _avatarSize = 112;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _coverHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _coverHeight,
            child: SceneFrame(
              imageAlignment: const Alignment(0.6, 0.0),
              children: [
                Positioned(
                  left: 8,
                  top: 8,
                  child: PixelPanel(
                    style: PanelStyle.dark,
                    expand: false,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    child: Text('PLAYER CARD', style: AppText.caption(color: AppColors.accentGold)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: _coverHeight - _avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: _avatarSize,
                height: _avatarSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Your grown sunflower stands in for a profile picture
                    // until gardener avatars are drawn.
                    const PixelPanel(
                      style: PanelStyle.wood,
                      padding: EdgeInsets.all(6),
                      child: PixelPanel(
                        style: PanelStyle.parchment,
                        sunken: true,
                        shadow: false,
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: PixelSprite(
                            'assets/images/plant/stages/fullgrown.png',
                            size: 92,
                            zoom: 1.5,
                            fallbackIcon: Icons.person,
                            semanticLabel: 'Your avatar',
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -14,
                      bottom: -8,
                      child: PixelPanel(
                        style: PanelStyle.dark,
                        outlineColor: AppColors.accentGold,
                        expand: false,
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        child: Text('LV $level', style: AppTheme.pixelHeading(size: 9, color: AppColors.accentGold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wood tile: gold medallion with an icon, big pixel number, label.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: PixelPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            PixelPanel(
              style: PanelStyle.dark,
              expand: false,
              shadow: false,
              padding: const EdgeInsets.all(7),
              child: Icon(icon, size: 20, color: AppColors.accentGold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: AppTheme.pixelHeading(size: 14, color: AppColors.textCream)
                        .copyWith(shadows: const [Shadow(offset: Offset(0, 2), color: Color(0x80000000))]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(color: AppColors.textCream.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square badge: gold-outlined wood with a gold icon when earned, dark
/// with a faded icon + lock when not.
class _BadgeMedallion extends StatelessWidget {
  const _BadgeMedallion({required this.badge, this.size});

  final GardenBadge badge;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final medallion = PixelPanel(
      style: badge.earned ? PanelStyle.wood : PanelStyle.dark,
      outlineColor: badge.earned ? AppColors.accentGold : null,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, c) {
          final iconSize = c.maxWidth * 0.45;
          return Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                badge.icon,
                size: iconSize,
                color: badge.earned ? AppColors.accentGold : AppColors.textCream.withValues(alpha: 0.2),
              ),
              if (!badge.earned)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(Icons.lock, size: iconSize * 0.45, color: AppColors.textCream.withValues(alpha: 0.6)),
                ),
            ],
          );
        },
      ),
    );

    if (size == null) return medallion;
    return SizedBox(width: size, height: size, child: medallion);
  }
}

/// One settings row inside the parchment notebook. Tappable when [onTap]
/// is given. Always at least 48 dp tall.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.titleColor = AppColors.textDark,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          PixelPanel(
            style: PanelStyle.wood,
            expand: false,
            shadow: false,
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: AppColors.textCream),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: AppTheme.body(size: 14, color: titleColor, weight: FontWeight.w800))),
          trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }
}

/// Dashed line between settings rows, like a ruled notebook.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.artScale,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.parchmentShade;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
