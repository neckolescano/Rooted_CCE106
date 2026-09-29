import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garden_scenes.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_scene.dart';
import '../widgets/growth_transition_player.dart';
import '../widgets/harvest_celebration_dialog.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_dialog.dart';
import '../widgets/pixel_icon_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_progress_bar.dart';
import '../widgets/pixel_timer_display.dart';
import '../widgets/plant_aura.dart';
import '../widgets/plant_display.dart';
import 'notes_screen.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  /// true while a Timer screen is on the stack — there must only ever be
  /// one (two would both grow the plant and record the session).
  static bool get isOpen => _openCount > 0;
  static int _openCount = 0;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // True while the growth animation is playing after a completed session.
  bool _isGrowing = false;
  String? _growthTransitionKey;

  // True from the moment a completed session starts being recorded until
  // the next session starts. build() sees the "completed" status on every
  // rebuild, so without this the finish (grow + record + harvest) could
  // run twice — e.g. when the plant was already fully grown.
  bool _finishing = false;

  // True only once THIS screen has actually confirmed its own start()
  // call went through. See initState() below for why this exists.
  bool _sessionStarted = false;

  // See-through dark panel so text stays readable over the meadow.
  static const _glassDark = Color(0xE63E2A1B);

  @override
  void dispose() {
    TimerScreen._openCount--;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    TimerScreen._openCount++;
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
      final session = context.read<SessionModel>();
      // A session already in progress (e.g. restored after Android closed
      // the app, or it finished while the app was closed) is resumed —
      // otherwise start a new one with the FOCUS TIME picked on Home.
      if (!session.isActive) session.start(minutes: context.read<StorageService>().focusMinutes);
      setState(() => _sessionStarted = true);
    });
  }

  /// Asks first — one accidental tap used to wilt the plant instantly.
  Future<void> _confirmGiveUp() async {
    final session = context.read<SessionModel>();
    // Nothing to give up once the countdown is over (or the growth
    // animation is playing).
    if (_isGrowing || session.status == SessionStatus.completed) return;

    final confirmed = await showPixelConfirm(
      context,
      title: 'Give up?',
      sealIcon: Icons.eco,
      message: 'Your plant needs you until the timer runs out. '
          'If you leave now, it will wilt.',
      confirmLabel: 'Give up',
      cancelLabel: 'Keep growing',
      danger: true,
    );
    // Re-check: the timer may have finished while the popup was open.
    if (!confirmed || !mounted) return;
    final status = context.read<SessionModel>().status;
    if (_isGrowing || status == SessionStatus.completed) return;
    await _handleGiveUp();
  }

  /// Closes anything sitting on top of this screen — the Give Up popup,
  /// the Notes journal, Study Material — so this screen is the top route
  /// again.
  ///
  /// BUG FIX: when the timer ended with a popup open, the "session done,
  /// go home" step called Navigator.pop(), which closed the POPUP instead
  /// of this screen. The timer then sat there with its buttons disabled
  /// (they're off while the plant grows) and looked frozen.
  void _closeEverythingOnTop() {
    final myRoute = ModalRoute.of(context);
    if (myRoute != null && !myRoute.isCurrent) {
      Navigator.of(context).popUntil((route) => route == myRoute);
    }
  }

  Future<void> _handleGiveUp() async {
    final session = context.read<SessionModel>();
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    session.giveUp();
    plant.wilt();
    await storage.recordFailedSession(
      elapsedSeconds: session.elapsedSeconds,
    );
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: plant.isWilted);

    if (mounted) Navigator.of(context).pop();
  }

  /// Session hit 0:00 successfully. If there's a next stage to grow into,
  /// play its transition animation first — _finishSession() runs once
  /// that animation completes. If the plant is already fully grown,
  /// there's nothing to animate, so finish right away.
  void _beginGrowthSequence() {
    if (_isGrowing || _finishing) return; // guard against firing more than once
    // Come back to this screen (from a popup or the Notes journal) so
    // the student actually sees their plant grow.
    _closeEverythingOnTop();
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
    if (_finishing) return; // already being recorded
    _finishing = true;
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    final session = context.read<SessionModel>();
    plant.grow();
    final studied = session.durationSeconds;
    await storage.recordCompletedSession(durationSeconds: studied);
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: plant.isWilted);
    session.markRecorded(); // the saved session can't be counted again
    // Studied today → no reminder today; the next one is tomorrow.
    if (storage.remindersOn) unawaited(ReminderService.apply(storage, plantName: plant.species.name));

    // This covers BOTH cases: the plant just grew into its final stage
    // this session, and the plant was already fully grown when the
    // session finished (grow() is a no-op past the last stage) — either
    // way there's nothing further to grow into, so this is where the
    // old version used to just silently pop with no feedback.
    if (plant.isFullyGrown) {
      await _handleFullyGrown();
      return;
    }

    if (!mounted) return;
    _closeEverythingOnTop(); // make sure pop() closes THIS screen
    Navigator.of(context).pop();
  }

  /// Records the harvest, resets the plant back to a seed so the next
  /// session has somewhere to grow, then shows the congrats popup and
  /// acts on whichever choice the student makes.
  Future<void> _handleFullyGrown() async {
    final plant = context.read<PlantModel>();
    final storage = context.read<StorageService>();

    // Remember WHICH plant was grown before the pot is reset.
    final grown = plant.species;
    await storage.recordHarvestedPlant(speciesId: grown.id);
    plant.resetToSeed();
    await storage.savePlantState(stageIndex: plant.stage.index, wilted: false);

    if (!mounted) return;
    _closeEverythingOnTop();
    final startAnotherSession = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      // Dark enough that the popup is clearly the focus, but the meadow
      // still shows through faintly.
      barrierColor: AppColors.overlay,
      builder: (_) => HarvestCelebrationDialog(plantAsset: grown.fullGrownAsset, plantName: grown.name, aura: grown.aura),
    );

    if (!mounted) return;
    if (startAnotherSession == true) {
      // Stay on this screen and jump straight into a fresh session with
      // the new seed, instead of bouncing back to Home first.
      setState(() {
        _isGrowing = false;
        _growthTransitionKey = null;
        _finishing = false; // the new session can finish normally later
      });
      context.read<SessionModel>().start(minutes: context.read<StorageService>().focusMinutes);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Biggest clean size for the 128px plant that fits the space left.
  double _plantSizeFor(BoxConstraints c) {
    for (final size in const [256.0, 192.0, 160.0, 128.0]) {
      if (size <= c.maxHeight && size <= c.maxWidth) return size;
    }
    return 96;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionModel>();
    final plant = context.watch<PlantModel>();
    final isPaused = session.status == SessionStatus.paused;
    final progress = session.progress;

    // React the moment the countdown hits zero. The _sessionStarted
    // check matters: without it, this could misfire on a leftover
    // "completed" status from a PREVIOUS session, before this screen's
    // own start() has even run (see the comment in initState()).
    if (_sessionStarted && session.status == SessionStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginGrowthSequence());
    }

    // The phone's back button used to quietly leave this screen while
    // the countdown kept running with nobody listening — so the plant
    // never grew. Now back asks the same "Give up?" question instead.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmGiveUp();
      },
      child: Scaffold(
        // This screen is pushed as its own route (not inside MainShell), so
        // it needs its own Scaffold — without one there's nothing to paint
        // a background, and it falls through to plain black.
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BackgroundScene(
            // The equipped Garden Scene (Garden page → Garden scenes).
            scene: gardenSceneById(context.select<StorageService, String>((s) => s.gardenScene)),
            child: Padding(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PixelPanel(
                        style: PanelStyle.dark,
                        expand: false,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                        child: Text('SESSION EN ROUTE', style: AppText.panelTitle()),
                      ),
                      const Spacer(),
                      // Opens the Notes page. This just pushes on top of
                      // the existing route — SessionModel isn't touched,
                      // so the countdown keeps running underneath exactly
                      // as it was, and this screen's own state (like
                      // _isGrowing) is preserved too since it's never
                      // disposed, just paused off-screen.
                      PixelIconButton(
                        icon: Icons.edit_note,
                        label: 'NOTES',
                        semanticLabel: 'Open study notes. The timer keeps running.',
                        // Off while the plant is growing, so nothing can
                        // open on top during the growth animation.
                        onPressed: _isGrowing
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const NotesScreen()),
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PixelTimerDisplay(
                    time: session.formattedTime,
                    label: isPaused ? 'PAUSED' : 'FOCUS MODE',
                  ),
                  const SizedBox(height: 10),
                  PixelPanel(
                    style: PanelStyle.dark,
                    backgroundColor: _glassDark,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('PLANT GROWTH', style: AppText.caption(color: AppColors.textCream))),
                            Text('${(progress * 100).round()}%', style: AppText.caption(color: AppColors.accentGold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PixelProgressBar(value: progress, height: 12, semanticLabel: 'Session progress'),
                      ],
                    ),
                  ),
                  // This open space is where the meadow background actually
                  // gets to show — the plant sits IN the scene.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = _plantSizeFor(constraints);
                        return Center(
                          child: _isGrowing
                              ? PlantAuraEffect(
                                  aura: plant.species.aura,
                                  strength: PlantAuraEffect.strengthForStage(plant.stage.index + 1),
                                  child: GrowthTransitionPlayer(
                                    plant: plant,
                                    transitionKey: _growthTransitionKey!,
                                    onFinished: _finishSession,
                                    size: size,
                                  ),
                                )
                              : PlantDisplay(plant: plant, size: size),
                        );
                      },
                    ),
                  ),
                  PixelPanel(
                    style: PanelStyle.dark,
                    backgroundColor: _glassDark,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                    child: Text(
                      'Your ${plant.stage.label} is growing quietly. '
                      'Keep off social media until the timer runs out!',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(size: 12, color: AppColors.textCream, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PixelButton(
                          label: isPaused ? 'Resume' : 'Pause',
                          icon: isPaused ? Icons.play_arrow : Icons.pause,
                          onPressed: _isGrowing
                              ? null
                              : () {
                                  if (isPaused) {
                                    session.resume();
                                  } else {
                                    session.pause();
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PixelButton(
                          label: 'Give Up',
                          tone: ButtonTone.danger,
                          onPressed: _isGrowing ? null : _confirmGiveUp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
