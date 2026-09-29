import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_log.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_icon_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_section_header.dart';
import '../widgets/stat_pill.dart';

/// The Study Log (opened from Profile): this week's focus time and every
/// recent session — finished 🌱 or given up 🥀 — grouped by day. Read from
/// the session log in Firestore (users/{uid}/sessions).
class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen> {
  late Future<List<SessionLogEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = context.read<StorageService>().loadSessionHistory();
  }

  void _retry() => setState(() => _entries = context.read<StorageService>().loadSessionHistory());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PixelIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Study Log', style: AppText.screenTitle()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: FutureBuilder<List<SessionLogEntry>>(
                  future: _entries,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const _Loading();
                    if (snap.hasError) return _Failed(onRetry: _retry);
                    final entries = snap.data ?? const [];
                    if (entries.isEmpty) return const _Empty();
                    return _Log(entries: entries);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.entries});

  final List<SessionLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = summarizeWeek(entries, now);
    final days = groupByDay(entries);
    final localizations = MaterialLocalizations.of(context);

    String dayLabel(DateTime day) {
      final today = DateTime(now.year, now.month, now.day);
      if (day == today) return 'Today';
      if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return localizations.formatMediumDate(day);
    }

    return ListView(
      children: [
        const PixelSectionHeader('This week'),
        Row(
          children: [
            Expanded(child: StatPill(icon: Icons.timer, value: _duration(week.focusMinutes), label: 'focused')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: StatPill(icon: Icons.spa, value: '${week.finished}', label: 'finished')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: StatPill(icon: Icons.heart_broken, value: '${week.gaveUp}', label: 'gave up')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final (day, sessions) in days) ...[
          PixelSectionHeader(
            dayLabel(day),
            trailing: Text(
              '${_duration(sessions.where((s) => s.completed).fold(0, (sum, s) => sum + s.minutes))} focused',
              style: AppText.small(color: AppColors.textMuted),
            ),
          ),
          PixelPanel(
            style: PanelStyle.parchment,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < sessions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.parchmentShade),
                  _SessionRow(entry: sessions[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.entry});

  final SessionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.endedAt));
    final what = entry.completed ? '${_duration(entry.minutes)} focus' : 'Gave up after ${_duration(entry.minutes)}';
    return Semantics(
      label: '$what, $time',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Text(entry.completed ? '🌱' : '🥀', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                what,
                style: AppTheme.body(
                  size: 14,
                  weight: FontWeight.w800,
                  color: entry.completed ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ),
            Text(time, style: AppText.small(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// "1 h 5 min", "25 min", "0 min".
String _duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.greenDeep),
          const SizedBox(height: AppSpacing.md),
          Text('Leafing through your study log…', style: AppText.small(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PixelPanel(
        style: PanelStyle.parchment,
        expand: false,
        child: Text(
          'No sessions yet 🌱\nFinish (or give up) a focus session and it will show up here.',
          textAlign: TextAlign.center,
          style: AppText.body(),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PixelPanel(
        style: PanelStyle.parchment,
        expand: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your study log.\nCheck your internet connection and try again.",
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.dangerText),
            ),
            const SizedBox(height: AppSpacing.md),
            PixelButton(label: 'Try Again', tone: ButtonTone.secondary, height: 44, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
