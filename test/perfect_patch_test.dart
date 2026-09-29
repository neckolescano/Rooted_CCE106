// Answering every question right on the first try unlocks the secret seed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rooted/models/notes_model.dart';
import 'package:rooted/models/secrets.dart';
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

Future<StorageService> pumpPatch(WidgetTester tester, List<StudyQuestion> questions) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final notes = NotesModel()..material = StudyMaterial(questions: questions, flashcards: const []);
  tester.view.physicalSize = const Size(900, 9000);
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
  return storage;
}

void main() {
  testWidgets('all right on the first try unlocks Owlbloom and shows the popup', (tester) async {
    final storage = await pumpPatch(tester, [for (var i = 1; i <= 5; i++) mc(i)]);
    for (var i = 1; i <= 5; i++) {
      await tester.tap(find.text('Right $i'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(storage.secrets, contains(Secrets.perfectPatch));
    expect(find.text('A secret sprouted!'), findsOneWidget);
  });

  testWidgets('leaving the patch halfway and coming back still counts', (tester) async {
    final storage = await pumpPatch(tester, [for (var i = 1; i <= 5; i++) mc(i)]);
    final notes = Provider.of<NotesModel>(tester.element(find.byType(StudyMaterialScreen)), listen: false);
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.text('Right $i'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    // Leave the Study Patch and open it again.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<NotesModel>.value(value: notes),
        ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
      ],
      child: const MaterialApp(home: SizedBox()),
    ));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<NotesModel>.value(value: notes),
        ChangeNotifierProvider<SessionModel>(create: (_) => SessionModel()),
      ],
      child: const MaterialApp(home: StudyMaterialScreen()),
    ));
    await tester.pump();
    for (var i = 4; i <= 5; i++) {
      await tester.tap(find.text('Right $i'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(storage.secrets, contains(Secrets.perfectPatch));
  });

  testWidgets('one wrong first try means no secret, even if fixed afterwards', (tester) async {
    final storage = await pumpPatch(tester, [for (var i = 1; i <= 5; i++) mc(i)]);
    await tester.tap(find.text('Wrong 1'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Right 1'));
    for (var i = 2; i <= 5; i++) {
      await tester.tap(find.text('Right $i'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(storage.secrets, isNot(contains(Secrets.perfectPatch)));
  });
}
