class DepthScoring {
  static const String algoVersion = 'mock_v1';

  static double calculateScoreDepth(double activityCount) {
    if (activityCount >= 0.8) return 0.2;
    if (activityCount >= 0.5) return 0.5;
    if (activityCount >= 0.2) return 0.8;
    return 1.0;
  }
}
