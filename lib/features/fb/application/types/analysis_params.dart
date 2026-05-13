// lib/features/fb/application/types/analysis_params.dart
class AnalysisParams {
  final String query;
  final bool useHistory; // 過去の履歴を含めるか
  final int maxTokens;   // AIの最大回答文字数

  AnalysisParams({
    required this.query,
    this.useHistory = true,
    this.maxTokens = 500,
  });
}