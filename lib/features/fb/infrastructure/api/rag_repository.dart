// lib/features/fb/infrastructure/api/rag_repository.dart
// NOTE: 現行UIは RagAnalyzeClient を直接使います。
// このクラスは後方互換のために残しています。

import '../log/app_logger.dart';
import '../payload/sleep_payload.dart';
import 'rag_analyze_client.dart';

class RagRepository {
  final RagAnalyzeClient _client = RagAnalyzeClient();

  /// 睡眠分析をRAG APIで実行する
  Future<Map<String, dynamic>> fetchAnalysis(String userInput) async {
    try {
      final result = await _client.analyze(
        query: userInput,
        adviceType: 'chat',
        sleepData: const SleepPayload(
          payloadVersion: SleepPayload.currentVersion,
          sleepDataSource: 'existing_repository_fallback',
          sessions: [],
          epochs: [],
          notes: [],
        ),
      );
      return {
        'text': result.text,
        'confidence': result.confidence,
        'created_at': result.createdAt.toIso8601String(),
      };
    } catch (e) {
      AppLogger.e('リポジトリでの通信失敗', e);
      rethrow;
    }
  }
}
