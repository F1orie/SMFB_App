import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smf_app/features/fb/application/config/analysis_config.dart';
import 'package:smf_app/features/fb/domain/features/analysis_result.dart';
import 'package:smf_app/features/fb/infrastructure/log/app_logger.dart';
import 'package:smf_app/features/fb/infrastructure/payload/sleep_payload.dart';

class RagAnalyzeClient {
  RagAnalyzeClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? 'https://dummy-url.example.com';

  final http.Client _client;
  final String _baseUrl;

  Future<AnalysisResult> analyze({
    required String query,
    required String adviceType,
    required SleepPayload sleepData,
    List<Map<String, String>> chatHistory = const [],
  }) async {
    final uri = Uri.parse(
      '${_baseUrl.replaceFirst(RegExp(r'/$'), '')}/rag_analyze',
    );
    final body = jsonEncode({
      'query': query,
      'advice_type': adviceType,
      'payload_version': sleepData.payloadVersion,
      'sleep_data_source': sleepData.sleepDataSource,
      'sleep_data': sleepData.toSleepDataJson(),
      'chat_history': chatHistory,
    });

    AppLogger.d('RAG API 呼び出し: $adviceType $query');

    for (var attempt = 0; attempt <= 2; attempt++) {
      try {
        final response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          return AnalysisResult.fromJson(data);
        }

        if (response.statusCode == 503 && attempt < 2) {
          AppLogger.d('RAG API 503 - ${attempt + 1}回目リトライ待機中');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        final responseBody = response.body;
        final snippet = responseBody.length > 300
            ? responseBody.substring(0, 300)
            : responseBody;
        throw Exception('HTTP ${response.statusCode}: $snippet');
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        AppLogger.e('RAG API 通信エラー', e);
        rethrow;
      }
    }

    throw Exception('リトライ上限に達しました');
  }
}
