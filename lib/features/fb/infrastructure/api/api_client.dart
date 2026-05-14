import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smf_app/features/fb/application/config/analysis_config.dart';
import 'package:smf_app/features/fb/infrastructure/log/app_logger.dart';

/// Google Gemini API クライアント
class ApiClient {
  static const String _model = 'gemini-2.0-flash-lite';
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'
      '?key=${AnalysisConfig.geminiApiKey}';

  final http.Client _client = http.Client();

  /// Gemini にメッセージを送信して返答テキストを取得する
  /// [systemPrompt] : システムプロンプト（睡眠データなどのコンテキスト）
  /// [userMessage]  : ユーザーのメッセージ
  /// [history]      : チャット履歴（role: 'user'|'assistant', content: String）
  Future<String> chat({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    // 履歴を Gemini 形式に変換（assistant → model）
    final contents = <Map<String, dynamic>>[
      for (final h in history)
        {
          'role': h['role'] == 'assistant' ? 'model' : h['role'],
          'parts': [{'text': h['content']}],
        },
      {
        'role': 'user',
        'parts': [{'text': userMessage}],
      },
    ];

    AppLogger.d('Gemini API 呼び出し: $userMessage');

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [{'text': systemPrompt}],
              },
              'contents': contents,
              'generationConfig': {'maxOutputTokens': 500},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>;
        final content =
            (candidates.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>;
        final parts = content['parts'] as List<dynamic>;
        final text = (parts.first as Map<String, dynamic>)['text'] as String;
        AppLogger.d('Gemini 応答: $text');
        return text;
      } else {
        final body = response.body;
        AppLogger.e('Gemini API エラー: ${response.statusCode} $body');
        final snippet = body.length > 300 ? body.substring(0, 300) : body;
        throw Exception('HTTP ${response.statusCode}: $snippet');
      }
    } catch (e) {
      AppLogger.e('Gemini API 通信エラー', e);
      rethrow;
    }
  }
}
