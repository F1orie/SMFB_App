class DepthScoring {
  /// センサー実装バージョン（加速度計ベース）
  static const String algoVersion = 'accel_v1';

  /// activityCount（0.0〜1.0）から睡眠深度スコアを返す。
  /// activityCount が低いほど（静止）深い睡眠を示す。
  /// 線形変換: scoreDepth = 1.0 - activityCount
  static double calculateScoreDepth(double activityCount) {
    return (1.0 - activityCount).clamp(0.0, 1.0);
  }

  /// 入眠判定閾値: この値以上のscoreDepthが[onsetConsecutive]エポック連続で入眠とみなす
  /// 線形変換後の等価条件: activityCount <= 0.5（以前の0.8閾値・ステップ関数と同等の感度）
  static const double onsetThreshold = 0.5;
  static const int onsetConsecutive = 3;
}
