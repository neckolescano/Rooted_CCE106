/// Hidden achievements that unlock secret content. They are never listed
/// as quests; the locked items only show a riddle-like hint.
///
///   perfect_patch → the secret seed (Owlbloom): answer every question in a
///                   Study Patch right on the first try (at least 5).
///   deep_focus    → the secret scene (Hidden Owl Grove): finish a focus
///                   session of 60 minutes or more without pausing.
class Secrets {
  Secrets._();

  static const perfectPatch = 'perfect_patch';
  static const deepFocus = 'deep_focus';

  /// A perfect Study Patch needs at least this many questions.
  static const perfectPatchMinQuestions = 5;

  /// A deep-focus session must be at least this long (and never paused).
  static const deepFocusMinutes = 60;
}
