class SleepNote {
  const SleepNote({
    required this.sessionId,
    required this.createdAtEpochMs,
    required this.memo,
    required this.hadAlcohol,
    required this.hadCaffeine,
    required this.didExercise,
  });

  final String sessionId;
  final int createdAtEpochMs;
  final String memo;
  final bool hadAlcohol;
  final bool hadCaffeine;
  final bool didExercise;
}
