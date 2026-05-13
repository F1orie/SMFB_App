import 'package:flutter/material.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';
import 'package:smf_app/features/fb/infrastructure/api/api_client.dart';
import '../dialogs/fb_chat_dialog.dart';

class FbDashboardPage extends StatefulWidget {
  const FbDashboardPage({super.key});

  @override
  State<FbDashboardPage> createState() => _FbDashboardPageState();
}

class _FbDashboardPageState extends State<FbDashboardPage> {
  final _apiClient = ApiClient();

  SleepSession? _session;
  String? _memo;
  String? _aiAdvice;
  bool _isLoadingAi = false;
  bool _hasError = false;
  String? _errorDetail;

  /// セッションIDごとにAI分析結果をキャッシュ（アプリ起動中は再利用）
  static final Map<String, String> _adviceCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sessions = SleepRepository.instance.allSessions;
    if (sessions.isEmpty) {
      setState(() {
        _session = null;
      });
      return;
    }

    final latest = sessions.last;
    final notes = SleepRepository.instance.notesForSession(latest.id);
    final memo = notes.isNotEmpty ? notes.last.memo : '';

    setState(() {
      _session = latest;
      _memo = memo;
    });

    // キャッシュに同じセッションの結果があれば API を呼ばず再利用
    if (_adviceCache.containsKey(latest.id)) {
      setState(() {
        _aiAdvice = _adviceCache[latest.id];
      });
      return;
    }

    await _runAiAnalysis(latest, memo);
  }

  Future<void> _runAiAnalysis(SleepSession session, String memo) async {
    setState(() {
      _isLoadingAi = true;
      _hasError = false;
      _errorDetail = null;
      _aiAdvice = null;
    });

    try {
      final startDt =
          DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);
      final endDt = session.endAtEpochMs != null
          ? DateTime.fromMillisecondsSinceEpoch(session.endAtEpochMs!)
          : null;

      final durationMin = endDt?.difference(startDt).inMinutes;

      final durationLabel = durationMin != null
          ? '${durationMin ~/ 60}時間${durationMin % 60}分'
          : '不明';

      final systemPrompt = '''あなたは睡眠専門のAIアドバイザーです。
ユーザーの睡眠データを分析して、具体的で実践的なアドバイスを日本語で提供してください。
アドバイスは200文字以内で簡潔にまとめてください。

以下の睡眠データを参考にアドバイスしてください。
就寝時刻: ${_formatTime(startDt)}
起床時刻: ${endDt != null ? _formatTime(endDt) : '不明'}
睡眠時間: $durationLabel
ユーザーのメモ: ${memo.isNotEmpty ? memo : 'なし'}''';

      final advice = await _apiClient.chat(
        systemPrompt: systemPrompt,
        userMessage: '昨夜の睡眠データを分析して、改善のためのアドバイスをください。',
      );

      // キャッシュに保存して次回以降の API 呼び出しを省略
      _adviceCache[session.id] = advice;

      if (mounted) {
        setState(() {
          _aiAdvice = advice;
          _isLoadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAi = false;
          _hasError = true;
          _errorDetail = e.toString();
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日';
  }

  String _durationLabel(SleepSession session) {
    if (session.endAtEpochMs == null) return '計測中';
    final start = DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);
    final end = DateTime.fromMillisecondsSinceEpoch(session.endAtEpochMs!);
    final diff = end.difference(start);
    return '${diff.inHours}時間${diff.inMinutes % 60}分';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析フィードバック'),
      ),
      body: _session == null
          ? _buildNoData()
          : _buildContent(_session!),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bedtime_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'データがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'アラーム画面でSTARTして睡眠を記録してください',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SleepSession session) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);
    final endDt = session.endAtEpochMs != null
        ? DateTime.fromMillisecondsSinceEpoch(session.endAtEpochMs!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDate(startDt)}の睡眠分析',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 睡眠の基本情報
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading:
                        const Icon(Icons.calendar_today, color: Colors.blue),
                    title: Text(
                      '${_formatDate(startDt)}（${endDt != null ? _formatDate(endDt) : ""}）',
                    ),
                    subtitle:
                        Text('睡眠時間: ${_durationLabel(session)}'),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('就寝', _formatTime(startDt)),
                      _buildStatItem(
                          '起床', endDt != null ? _formatTime(endDt) : '--:--'),
                      _buildStatItem('時間', _durationLabel(session)),
                    ],
                  ),
                  if (_memo != null && _memo!.isNotEmpty) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.note_alt_outlined,
                          color: Colors.blueGrey),
                      title: const Text('メモ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_memo!),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // AIアドバイスセクション
          const Text(
            'AIアドバイス',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
            ),
            child: _buildAiAdviceContent(session),
          ),

          const SizedBox(height: 40),

          // チャットボタン
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => FbChatDialog(
                    session: session,
                    memo: _memo ?? '',
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.chat),
              label: const Text('この結果についてAIに質問する'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAdviceContent(SleepSession session) {
    if (_isLoadingAi) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('AI分析中...', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('分析に失敗しました。再試行してください。',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
          if (_errorDetail != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorDetail!,
                style: TextStyle(fontSize: 11, color: Colors.red.shade800),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _runAiAnalysis(session, _memo ?? ''),
            icon: const Icon(Icons.refresh),
            label: const Text('再試行'),
          ),
        ],
      );
    }

    if (_aiAdvice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('AI分析結果',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _aiAdvice!,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
