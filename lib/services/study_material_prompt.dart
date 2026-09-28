/// Builds the prompt that turns a student's notes into study material.
String buildStudyMaterialPrompt(String notes) {
  return '''
You are a study assistant. Analyze the student's notes below and create useful study material based ONLY on the provided notes.

Generate:
1. Study questions (a mix of multiple choice and short answer, about 5 to 8 in total)
2. Flashcards (about 6 to 10)

Do not invent information that is not supported by the student's notes. If the notes are short, generate fewer items rather than making things up.

For each flashcard provide:
- front (a term or question)
- back (the answer or explanation)

For each question provide:
- question
- type: either "multiple_choice" or "short_answer"
- answer
- choices (ONLY for multiple_choice: 3 to 4 options; the "answer" must be word-for-word identical to one of the choices)
- explanation (one short sentence based on the notes)

Respond with ONLY valid JSON in exactly this shape, with no extra commentary:

{
  "questions": [
    {
      "question": "...",
      "type": "multiple_choice",
      "choices": ["...", "...", "..."],
      "answer": "...",
      "explanation": "..."
    },
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
