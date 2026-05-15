// lib/features/fb/application/types/analysis_status.dart
enum AnalysisStatus {
  initial,   // まだ何もしていない
  loading,   // Pythonサーバーに問い合わせ中
  success,   // 無事に結果が返ってきた
  failure,   // 通信エラーなどが起きた
}