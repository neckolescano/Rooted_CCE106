import 'package:flutter/material.dart';
import '../services/pomodoro_timer.dart';

/// The row of action buttons under the timer, shown differently
/// depending on the current [SessionStatus].
class TimerControls extends StatelessWidget {
  final SessionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onGiveUp;
  final VoidCallback onReset;

  const TimerControls({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onGiveUp,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SessionStatus.idle:
        return _buttons([
          _primary('Start Session', onStart),
        ]);

      case SessionStatus.running:
        return _buttons([
          _secondary('Pause', onPause),
          _danger('Give Up', onGiveUp),
        ]);

      case SessionStatus.paused:
        return _buttons([
          _primary('Resume', onResume),
          _danger('Give Up', onGiveUp),
        ]);

      case SessionStatus.completed:
      case SessionStatus.failed:
        return _buttons([
          _primary('New Session', onReset),
        ]);
    }
  }

  Widget _buttons(List<Widget> children) {
    return Wrap(
      spacing: 12,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  Widget _primary(String label, VoidCallback onTap) {
    return ElevatedButton(onPressed: onTap, child: Text(label));
  }

  Widget _secondary(String label, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }

  Widget _danger(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
      child: Text(label),
    );
  }
}
