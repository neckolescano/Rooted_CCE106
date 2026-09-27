import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// A small "still studying" bar shown at the top of the Notes and Study
/// Material screens. This does NOT run its own timer — it just watches
/// the same app-wide SessionModel the Timer screen uses, so the real
/// countdown keeps running underneath no matter which screen is on top,
/// and pausing here pauses the actual session.
class CompactTimerHeader extends StatelessWidget {
  const CompactTimerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionModel>();
    final isPaused = session.status == SessionStatus.paused;

    return PixelPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPaused ? 'FOCUS SESSION · PAUSED' : 'FOCUS SESSION',
                style: AppTheme.body(size: 10, color: AppColors.accentGold, weight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                session.formattedTime,
                style: AppTheme.pixelHeading(size: 18, color: AppColors.textCream),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              final s = context.read<SessionModel>();
              if (s.status == SessionStatus.paused) {
                s.resume();
              } else if (s.status == SessionStatus.running) {
                s.pause();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.panelDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                color: AppColors.accentGold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
