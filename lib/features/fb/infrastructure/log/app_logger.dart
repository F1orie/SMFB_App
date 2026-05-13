// lib/features/fb/infrastructure/log/app_logger.dart
import 'dart:developer' as developer;

class AppLogger {
  // デバッグ用のログ出力
  static void d(String message) {
    developer.log('DEBUG: $message', name: 'AppLog');
  }

  // エラー用のログ出力
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      'ERROR: $message', 
      name: 'AppLog', 
      error: error, 
      stackTrace: stackTrace,
    );
  }
}