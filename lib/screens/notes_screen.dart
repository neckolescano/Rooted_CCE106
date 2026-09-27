import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_timer_header.dart';
import '../widgets/pixel_button.dart';
import 'study_material_screen.dart';

/// Notes page reached from the Timer screen. The Pomodoro countdown
/// keeps running underneath the whole time — this screen only ever
/// reads/controls the existing SessionModel via CompactTimerHeader, it
/// never creates a timer of its own.
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

  Future<void> _generate() async {
    final notes = context.read<NotesModel>();

    if (notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some notes first so I can create study material for you.')),
      );
      return;
    }

    await notes.generateStudyMaterial(AiService());
    if (!mounted) return;

    if (notes.material != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StudyMaterialScreen()),
      );
    }
    // If it failed, errorMessage is now set on the model and the error
    // UI below just shows it — no navigation needed for that case.
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesModel>();
    final storage = context.read<StorageService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  Text('Study Notes', style: AppTheme.pixelHeading(size: 15)),
                ],
              ),
              const SizedBox(height: 4),
              const CompactTimerHeader(),
              const SizedBox(height: 16),
              Text('NOTES', style: AppTheme.body(size: 12, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.panelMedium.withOpacity(0.35)),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTheme.body(size: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write your study notes here...',
                      hintStyle: AppTheme.body(size: 13, color: AppColors.textDark.withOpacity(0.35)),
                    ),
                    onChanged: (value) {
                      // Kept in the shared NotesModel (survives
                      // navigation) AND persisted to disk (survives the
                      // app being closed).
                      context.read<NotesModel>().updateText(value);
                      storage.saveNotes(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PixelButton(
                label: notes.isGenerating ? 'Generating...' : '✨ Generate Study Material',
                onPressed: notes.isGenerating ? () {} : _generate,
              ),
              if (notes.isGenerating) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.panelMedium),
                    ),
                    const SizedBox(width: 8),
                    Text('Analyzing your notes...', style: AppTheme.body(size: 12)),
                  ],
                ),
              ],
              if (notes.errorMessage != null && !notes.isGenerating) ...[
                const SizedBox(height: 12),
                Text(
                  notes.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 11, color: const Color(0xFFB23B2E)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _generate,
                    child: Text('Retry', style: AppTheme.body(size: 12, color: AppColors.panelMedium, weight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
