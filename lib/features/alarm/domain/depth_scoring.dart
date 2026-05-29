class DepthScoring {
  /// センサー実装バージョン（加速度計ベース）
  static const String algoVersion = 'accel_v1';

  /// activityCount（0.0〜1.0）から睡眠深度スコアを返す。
  /// activityCount が低いほど（静止）深い睡眠を示す。
  static double calculateScoreDepth(double activityCount) {
    if (activityCount >= 0.8) return 0.2; // 活発な動き → 浅い
    if (activityCount >= 0.5) return 0.5; // 中程度の動き
    if (activityCount >= 0.2) return 0.8; // わずかな動き → 深い
    return 1.0; // ほぼ静止 → 最深
  }

  /// 入眠判定閾値: この値以上のscoreDepthが[onsetConsecutive]エポック連続で入眠とみなす
  static const double onsetThreshold = 0.8;
  static const int onsetConsecutive = 3;
}
