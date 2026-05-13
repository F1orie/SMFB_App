class SleepEpoch {
  const SleepEpoch({
    required this.sessionId,
    required this.tEpochMs,
    required this.activityCount,
    required this.scoreDepth,
  });

  final String sessionId;
  final int tEpochMs;
  final double activityCount;
  final double scoreDepth;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'tEpochMs': tEpochMs,
        'activityCount': activityCount,
        'scoreDepth': scoreDepth,
      };

  factory SleepEpoch.fromJson(Map<String, dynamic> json) => SleepEpoch(
        sessionId: json['sessionId'] as String,
        tEpochMs: json['tEpochMs'] as int,
        activityCount: (json['activityCount'] as num).toDouble(),
        scoreDepth: (json['scoreDepth'] as num).toDouble(),
      );
}
