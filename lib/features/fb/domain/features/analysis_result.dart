// lib/features/fb/domain/features/analysis_result.dart

class AnalysisResult {
  final String text;        // AIの回答
  final double confidence;  // 信頼度 (0.0〜1.0)
  final DateTime createdAt; // 受信日時

  AnalysisResult({
    required this.text,
    required this.confidence,
    required this.createdAt,
  });

  // PythonのJSONデータをDartのオブジェクトに変換する
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      text: json['answer'] ?? '回答が得られませんでした',
      confidence: (json['score'] ?? 0.0).toDouble(),
      createdAt: DateTime.now(),
    );
  }
}