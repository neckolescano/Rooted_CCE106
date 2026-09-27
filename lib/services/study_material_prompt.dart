/// Builds the prompt a backend should send to an AI model to turn a
/// student's notes into study material. Kept separate from
/// [AiService] so the prompt text can be reused/edited without
/// touching the service logic, and so a future backend implementation
/// can import just this.
String buildStudyMaterialPrompt(String notes) {
  return '''
You are a study assistant. Analyze the student's notes below and create useful study material based ONLY on the provided notes.

Generate:
1. Important concepts
2. Study questions
3. Flashcards

Do not invent information that is not supported by the student's notes.

For each flashcard provide:
- front
- back

For each question provide:
- question
- answer
- optional choices if it is multiple choice
- explanation

Respond with ONLY valid JSON in this exact shape, no extra commentary:

{
  "questions": [
    {
      "question": "...",
      "type": "short_answer",
      "answer": "...",
      "explanation": "..."
    }
  ],
  "flashcards": [
    { "front": "...", "back": "..." }
  ]
}

Student notes:
$notes
''';
}
