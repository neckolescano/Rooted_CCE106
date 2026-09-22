import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_scene.dart';
import '../widgets/growth_transition_player.dart';
import '../widgets/harvest_celebration_dialog.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/plant_display.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // True while the growth animation is playing after a completed session.
  bool _isGrowing = false;
  String? _growthTransitionKey;

  // True only once THIS screen has actually confirmed its own start()
  // call went through. See initState() below for why this exists.
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    // This has to run inside addPostFrameCallback, NOT synchronously
    // here. SessionModel.start() calls notifyListeners(), and calling
    // that in the middle of initState() — while Flutter is still in the
    // middle of building this very widget tree — throws "setState() or
    // markNeedsBuild() called during build". addPostFrameCallback waits
    // until the current build has fully finished before running, which
    // is what avoids that crash.
    //
    // BUT: SessionModel lives at the app root, so its `status` from the
    // last session (e.g. "completed") is still sitting there for the
    // one frame before this callback runs. Without the _sessionStarted
    // guard below, build()'s "did the session just complete?" check
    // could see that leftover status on this screen's very first build
    // and fire a bogus growth sequence before the real countdown even
    // started — that was the "fast forward" bug. _sessionStarted fixes
    // that: the check in build() only trusts a "completed" status once
    // we know THIS screen's own start() has actually run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SessionModel>().start();
      setState(() => _sessionStarted = true);
    });
  }

  Future<void> _handleGiveUp() async {
    final session = context.read<SessionModel>();
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    session.giveUp();
    plant.wilt();
    await storage.recordFailedSession();
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: plant.isWilted);

    if (mounted) Navigator.of(context).pop();
  }

  /// Session hit 0:00 successfully. If there's a next stage to grow into,
  /// play its transition animation first — _finishSession() runs once
  /// that animation completes. If the plant is already fully grown,
  /// there's nothing to animate, so finish right away.
  void _beginGrowthSequence() {
    if (_isGrowing) return; // guard against firing more than once
    final plant = context.read<PlantModel>();
    final key = plant.transitionKeyToNextStage;
    if (key == null) {
      _finishSession();
      return;
    }
    setState(() {
      _isGrowing = true;
      _growthTransitionKey = key;
    });
  }

  Future<void> _finishSession() async {
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    plant.grow();
    await storage.recordCompletedSession();
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: plant.isWilted);

    // This covers BOTH cases: the plant just grew into its final stage
    // this session, and the plant was already fully grown when the
    // session finished (grow() is a no-op past the last stage) — either
    // way there's nothing further to grow into, so this is where the
    // old version used to just silently pop with no feedback.
    if (plant.isFullyGrown) {
      await _handleFullyGrown();
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Records the harvest, resets the plant back to a seed so the next
  /// session has somewhere to grow, then shows the congrats popup and
  /// acts on whichever choice the student makes.
  Future<void> _handleFullyGrown() async {
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    await storage.recordHarvestedPlant();
    plant.resetToSeed();
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: false);

    if (!mounted) return;
    final startAnotherSession = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const HarvestCelebrationDialog(),
    );

    if (!mounted) return;
    if (startAnotherSession == true) {
      // Stay on this screen and jump straight into a fresh session with
      // the new seed, instead of bouncing back to Home first.
      setState(() {
        _isGrowing = false;
        _growthTransitionKey = null;
      });
      context.read<SessionModel>().start();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionModel>();
    final plant = context.watch<PlantModel>();

    // React the moment the countdown hits zero. The _sessionStarted
    // check matters: without it, this could misfire on a leftover
    // "completed" status from a PREVIOUS session, before this screen's
    // own start() has even run (see the comment in initState()).
    if (_sessionStarted && session.status == SessionStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginGrowthSequence());
    }

    return Scaffold(
      // This screen is pushed as its own route (not inside MainShell), so
      // it needs its own Scaffold — without one there's nothing to paint
      // a background, and it falls through to plain black.
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BackgroundScene(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.panelDark.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SESSION EN ROUTE', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                PixelPanel(
                  backgroundColor: AppColors.panelMedium,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.formattedTime, style: AppTheme.pixelHeading(size: 36, color: AppColors.textCream)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.panelDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('FOCUS MODE', style: AppTheme.body(size: 10, color: AppColors.accentGold, weight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // This open space is where the meadow background actually
                // gets to show — the plant now sits IN a scene instead of
                // floating in empty space.
                Expanded(
                  child: Center(
                    child: _isGrowing
                        ? GrowthTransitionPlayer(
                            transitionKey: _growthTransitionKey!,
                            onFinished: _finishSession,
                            size: 220,
                          )
                        : PlantDisplay(plant: plant, size: 220),
                  ),
                ),
                const SizedBox(height: 16),
                PixelPanel(
                  backgroundColor: AppColors.panelDark.withOpacity(0.9),
                  child: Text(
                    'Your ${plant.stage.label} is growing quietly. '
                    'Keep off social media until the timer runs out!',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(size: 12, color: AppColors.textCream),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: session.status == SessionStatus.paused ? 'Resume' : 'Pause',
                        onPressed: () {
                          if (session.status == SessionStatus.paused) {
                            session.resume();
                          } else {
                            session.pause();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelButton(
                        label: 'Give Up',
                        tint: const Color(0xFFCC6B5C), // reddish wash over the wood plaque
                        onPressed: _handleGiveUp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
