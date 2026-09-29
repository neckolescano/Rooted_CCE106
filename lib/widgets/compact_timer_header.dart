import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../theme/app_theme.dart';
import 'pixel_icon_button.dart';
import 'pixel_panel.dart';

/// A small "still studying" bar shown at the top of the Notes and Study
/// Material screens. This does NOT run its own timer — it just watches
/// the same app-wide SessionModel the Timer screen uses, so the real
/// countdown keeps running underneath no matter which screen is on top,
/// and pausing here pauses the actual session.
///
/// When no session is running (e.g. the journal was opened from Home) it
/// takes no space at all. It includes its own gap below, for the same
/// reason.
class CompactTimerHeader extends StatelessWidget {
  const CompactTimerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionModel>();
    final isPaused = session.status == SessionStatus.paused;
    final isActive = isPaused || session.status == SessionStatus.running;
    if (!isActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _bar(context, session, isPaused, isActive),
    );
  }

  Widget _bar(BuildContext context, SessionModel session, bool isPaused, bool isActive) {
    return PixelPanel(
      style: PanelStyle.dark,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.spa, size: 18, color: AppColors.accentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: '${isPaused ? 'Focus session paused' : 'Focus session'}, ${session.formattedTime} left',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaused ? 'FOCUS SESSION · PAUSED' : 'FOCUS SESSION',
                    style: AppText.caption(color: AppColors.accentGold),
                  ),
                  const SizedBox(height: 2),
                  Text(session.formattedTime, style: AppText.timerCompact()),
                ],
              ),
            ),
          ),
          PixelIconButton(
            icon: isPaused ? Icons.play_arrow : Icons.pause,
            semanticLabel: isPaused ? 'Resume timer' : 'Pause timer',
            style: PanelStyle.wood,
            onPressed: !isActive
                ? null
                : () {
                    final s = context.read<SessionModel>();
                    if (s.status == SessionStatus.paused) {
                      s.resume();
                    } else if (s.status == SessionStatus.running) {
                      s.pause();
                    }
                  },
          ),
        ],
      ),
    );
  }
}
