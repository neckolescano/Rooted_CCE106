// The Study Patch questions work as a quiz: one at a time, then a score.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rooted/models/notes_model.dart';
import 'package:rooted/models/session_model.dart';
import 'package:rooted/models/study_material.dart';
import 'package:rooted/screens/study_material_screen.dart';
import 'package:rooted/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudyQuestion mc(int i) => StudyQuestion(
      question: 'Question number $i?',
      type: 'multiple_choice',
      choices: ['Right $i', 'Wrong $i', 'Nope $i', 'Nah $i'],
      answer: 'Right $i',
    );

Future<NotesModel> pumpQuiz(WidgetTester tester, int count) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final notes = NotesModel()
    ..material = StudyMaterial(questions: [for (var i = 1; i <= count; i++) mc(i)], flashcards: const []);
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<StorageService>.value(value: storage),
      ChangeNotifierProvider<NotesModel>.value(value: notes),
      ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
    ],
    child: const MaterialApp(home: StudyMaterialScreen()),
  ));
  await tester.pump();
  return notes;
}

Future<void> pick(WidgetTester tester, String choice) async {
  await tester.tap(find.text(choice));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> next(WidgetTester tester) async {
  final n = find.text('NEXT');
  await tester.tap(n.evaluate().isNotEmpty ? n : find.text('FINISH'));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('one question at a time; Next unlocks after answering', (tester) async {
    await pumpQuiz(tester, 3);
    expect(find.text('QUESTION 1 / 3'), findsOneWidget);
    expect(find.text('Question number 2?'), findsNothing);
    await tester.tap(find.text('NEXT')); // not answered yet: does nothing
    await tester.pump();
    expect(find.text('QUESTION 1 / 3'), findsOneWidget);
    await pick(tester, 'Right 1');
    await next(tester);
    expect(find.text('QUESTION 2 / 3'), findsOneWidget);
    expect(find.text('✓ 1'), findsOneWidget);
  });

  testWidgets('finishing shows the score; reviewing missed ones keeps it', (tester) async {
    final notes = await pumpQuiz(tester, 3);
    await pick(tester, 'Right 1');
    await next(tester);
    await pick(tester, 'Wrong 2');
    await next(tester);
    await pick(tester, 'Right 3');
    await next(tester);
    expect(find.text('QUIZ COMPLETE!'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('REVIEW MISSED (1)'));
    await tester.pump();
    expect(find.text('PRACTICE 1 / 1'), findsOneWidget);
    expect(find.text('Question number 2?'), findsOneWidget);
    await pick(tester, 'Right 2');
    await next(tester);
    expect(find.text('PRACTICE DONE'), findsOneWidget);

    await tester.tap(find.text('BACK TO RESULTS'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget); // the real score didn't change
    expect(notes.firstTry[1], isFalse);
  });

  testWidgets('leaving and coming back continues at the same question', (tester) async {
    final notes = await pumpQuiz(tester, 3);
    await pick(tester, 'Right 1');
    await next(tester);
    expect(notes.quizIndex, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: await StorageService.create()),
        ChangeNotifierProvider<NotesModel>.value(value: notes),
        ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
      ],
      child: const MaterialApp(home: StudyMaterialScreen()),
    ));
    await tester.pump();
    expect(find.text('QUESTION 2 / 3'), findsOneWidget);
  });
}
