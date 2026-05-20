// lib/features/fb/infrastructure/api/rag_repository.dart
// NOTE: AI分析は ApiClient.chat() を直接使う実装に移行しました。
// このクラスは後方互換のために残しています。

import '../log/app_logger.dart';
import 'api_client.dart';

class RagRepository {
  final ApiClient _apiClient = ApiClient();

  /// 睡眠分析を Claude API で実行する
  Future<Map<String, dynamic>> fetchAnalysis(String userInput) async {
    try {
      final answer = await _apiClient.chat(
        systemPrompt: 'あなたは睡眠専門のAIアドバイザーです。日本語で回答してください。',
        userMessage: userInput,
      );
      return {'answer': answer};
    } catch (e) {
      AppLogger.e('リポジトリでの通信失敗', e);
      rethrow;
    }
  }
}
