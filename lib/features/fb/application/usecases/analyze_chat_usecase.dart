// lib/features/fb/application/usecases/analyze_chat_usecase.dart
import '../../domain/features/analysis_result.dart';
import '../../infrastructure/api/rag_repository.dart';

class AnalyzeChatUseCase {
  final RagRepository _repository;
  AnalyzeChatUseCase(this._repository);

  // 実行ボタンが押された時の「一連の流れ」
  Future<AnalysisResult> execute(String input) async {
    // 1. リポジトリに通信を依頼
    final jsonResponse = await _repository.fetchAnalysis(input);
    
    // 2. 受け取った生のデータをDomain層のモデルに変換（分析準備）
    return AnalysisResult.fromJson(jsonResponse);
  }
}