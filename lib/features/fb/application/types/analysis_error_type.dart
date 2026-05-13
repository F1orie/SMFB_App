// lib/features/fb/application/types/analysis_error_type.dart
enum AnalysisErrorType {
  network,    // ネットが繋がっていない
  timeout,    // Pythonが重くて時間切れ
  invalidKey, // APIキーがおかしい
  unknown,    // その他
}