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

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'createdAtEpochMs': createdAtEpochMs,
        'memo': memo,
        'hadAlcohol': hadAlcohol,
        'hadCaffeine': hadCaffeine,
        'didExercise': didExercise,
      };

  factory SleepNote.fromJson(Map<String, dynamic> json) => SleepNote(
        sessionId: json['sessionId'] as String,
        createdAtEpochMs: json['createdAtEpochMs'] as int,
        memo: json['memo'] as String,
        hadAlcohol: json['hadAlcohol'] as bool,
        hadCaffeine: json['hadCaffeine'] as bool,
        didExercise: json['didExercise'] as bool,
      );
}
