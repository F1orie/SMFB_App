class DepthScoring {
  const DepthScoring._();

  static const String algoVersion = '1.0.0';

  /// activityCount（0〜1）から睡眠深度スコア（0〜1）を算出する。
  /// 活動量が低いほど深い睡眠（スコア高）と判定する。
  static double calculateScoreDepth(double activityCount) {
    return (1.0 - activityCount.clamp(0.0, 1.0));
  }
}
