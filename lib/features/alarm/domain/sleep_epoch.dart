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
}
