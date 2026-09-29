import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_timer_header.dart';
import '../widgets/desk_background.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_icon_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/study_options_dialog.dart';
import 'study_material_screen.dart';

/// The Study Journal, reached from the Timer screen. The Pomodoro
/// countdown keeps running underneath the whole time — this screen only
/// ever reads/controls the existing SessionModel via CompactTimerHeader,
/// it never creates a timer of its own.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<NotesModel>().text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [askOptions] = show the "Grow your study patch" scroll first.
  /// "Try again" skips it and reuses the last choices.
  Future<void> _generate({bool askOptions = true}) async {
    final notes = context.read<NotesModel>();
    final storage = context.read<StorageService>();

    if (notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some notes first so I can create study material for you.')),
      );
      return;
    }

    FocusScope.of(context).unfocus(); // drop the keyboard while it works

    var options = storage.studyOptions;
    if (askOptions) {
      final picked = await showStudyOptions(context, options);
      if (picked == null || !mounted) return; // "Not now"
      options = picked;
      await storage.setStudyOptions(picked); // remembered for next time
    }

    await notes.generateStudyMaterial(AiService(), options);
    if (!mounted) return;

    // Open it only if THIS try worked (older saved material may still be
    // there after a failed try).
    if (notes.errorMessage == null && notes.material != null) _openMaterial();
  }

  void _openMaterial() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyMaterialScreen()),
    );
    // If it failed, errorMessage is now set on the model and the error
    // panel below just shows it — no navigation needed for that case.
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesModel>();
    final storage = context.read<StorageService>();
    // While typing, hide the status panels so the page keeps its room.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.panelMedium,
      body: DeskBackground(
        child: SafeArea(
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
                    Expanded(
                      child: Text(
                        'Study Journal',
                        style: AppText.screenTitle(color: AppColors.textCream).copyWith(
                          shadows: const [Shadow(offset: Offset(0, 2), color: Color(0x99000000))],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const CompactTimerHeader(),
                Expanded(
                  child: _JournalPage(
                    controller: _controller,
                    onChanged: (value) {
                      // Kept in the shared NotesModel (survives
                      // navigation) AND persisted to disk (survives the
                      // app being closed).
                      context.read<NotesModel>().updateText(value);
                      storage.saveNotes(value);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PixelButton(
                  label: notes.isGenerating ? 'Growing ideas...' : 'Generate Study Material',
                  icon: Icons.auto_awesome,
                  onPressed: notes.isGenerating ? null : _generate,
                ),
                // The last questions + flashcards are saved — open them again.
                if (!keyboardOpen && notes.material != null && !notes.isGenerating) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PixelButton(
                    label: 'Open Study Patch',
                    icon: Icons.menu_book,
                    tone: ButtonTone.secondary,
                    height: 44,
                    onPressed: _openMaterial,
                  ),
                ],
                if (!keyboardOpen && notes.isGenerating) ...[
                  const SizedBox(height: AppSpacing.md),
                  PixelPanel(
                    style: PanelStyle.parchment,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.greenDeep),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Your garden companion is reading your notes...', style: AppText.small()),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!keyboardOpen && notes.errorMessage != null && !notes.isGenerating) ...[
                  const SizedBox(height: AppSpacing.md),
                  PixelPanel(
                    style: PanelStyle.parchment,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.eco, size: 18, color: AppColors.dangerText),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                notes.errorMessage!,
                                maxLines: 12,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.small(color: AppColors.dangerText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        PixelButton(
                          label: 'Try Again',
                          tone: ButtonTone.secondary,
                          height: 44,
                          onPressed: () => _generate(askOptions: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A parchment journal page: "Field Notes" title, a red margin line like
/// a real notebook, and the writing area. The margin line doesn't move
/// when the text scrolls, so it never drifts out of line (ruled lines
/// would).
class _JournalPage extends StatelessWidget {
  const _JournalPage({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static const double _marginX = 30;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.parchment,
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, AppSpacing.md, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _marginX + 10),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 18, color: AppColors.panelMedium),
                const SizedBox(width: 6),
                Text('Field Notes', style: AppText.gameMoment(color: AppColors.panelMedium)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: AppSizes.artScale, color: AppColors.parchmentShade),
          Expanded(
            child: CustomPaint(
              painter: _MarginPainter(x: _marginX),
              child: Padding(
                padding: const EdgeInsets.only(left: _marginX + 10),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: AppColors.panelMedium,
                  style: AppTheme.body(size: 15).copyWith(height: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.md),
                    hintText: "Jot down what you're learning...",
                    hintStyle: AppTheme.body(size: 15, color: AppColors.textMuted.withValues(alpha: 0.7)),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarginPainter extends CustomPainter {
  _MarginPainter({required this.x});

  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(x, 0, AppSizes.artScale, size.height),
      Paint()..color = AppColors.danger.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_MarginPainter old) => old.x != x;
}
