import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smf_app/features/fb/infrastructure/log/app_logger.dart';

class ApiClient {
  // Pythonサーバーの基本URL（10.0.2.2はAndroidエミュレータ用）
  final String baseUrl = "http://10.0.2.2:8000";

  // 通信のタイムアウト時間などを設定した共通のクライアント
  final http.Client _client = http.Client();

  /// 共通のPOSTリクエスト処理
  /// [endpoint] : "/analyze" などのパス
  /// [body] : 送信するデータのマップ
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    
    try {
      AppLogger.d("APIリクエスト送信中: $url");

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30)); // 30秒でタイムアウト設定

      return _handleResponse(response);
    } catch (e) {
      AppLogger.e("通信中にエラーが発生しました ($endpoint)", e);
      rethrow;
    }
  }

  /// サーバーからの返答（レスポンス）をチェックする共通処理
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 成功時：JSONをMapに変換
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      // 失敗時：エラーログを出力して例外を投げる
      AppLogger.e("サーバーエラー: ${response.statusCode} 内容: ${response.body}");
      throw Exception("サーバー接続エラー (${response.statusCode})");
    }
  }
}