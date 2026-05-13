// lib/features/fb/infrastructure/api/rag_repository.dart
import '../log/app_logger.dart';
import 'api_client.dart'; // 先ほど作成した共通クライアント

class RagRepository {
  final ApiClient _apiClient = ApiClient();

  // Pythonサーバーの /analyze エンドポイントにリクエストを送る
  Future<Map<String, dynamic>> fetchAnalysis(String userInput) async {
    try {
      // 共通クライアントのpostメソッドを利用
      final response = await _apiClient.post('/analyze', {
        'query': userInput,
      });
      return response;
    } catch (e) {
      AppLogger.e("リポジトリでの通信失敗", e);
      rethrow;
    }
  }
}