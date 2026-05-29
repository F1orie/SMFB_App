// lib/features/fb/domain/features/analysis_result.dart

class AnalysisResult {
  final String text; // AIの回答
  final double confidence; // 信頼度 (0.0〜1.0)
  final DateTime createdAt; // 受信日時

  AnalysisResult({
    required this.text,
    required this.confidence,
    required this.createdAt,
  });

  // PythonのJSONデータをDartのオブジェクトに変換する
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      text: (json['text'] ?? json['answer'] ?? '回答が得られませんでした') as String,
      confidence: ((json['confidence'] ?? json['score'] ?? 0.0) as num)
          .toDouble(),
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
