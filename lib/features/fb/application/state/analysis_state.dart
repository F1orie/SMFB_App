// lib/features/fb/application/state/analysis_state.dart
// (例：現在の分析結果を保持するNotifier)
import '../../domain/features/analysis_result.dart';

class AnalysisState {
  final bool isLoading;
  final AnalysisResult? result;
  final String? errorMessage;

  AnalysisState({this.isLoading = false, this.result, this.errorMessage});
}
