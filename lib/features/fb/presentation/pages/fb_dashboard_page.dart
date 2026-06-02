import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';
import 'package:smf_app/features/fb/infrastructure/api/rag_analyze_client.dart';
import 'package:smf_app/features/fb/infrastructure/log/app_logger.dart';
import 'package:smf_app/features/fb/infrastructure/payload/sleep_payload.dart';
import 'package:smf_app/features/fb/infrastructure/payload/sleep_payload_builder.dart';
import '../dialogs/fb_chat_dialog.dart';

/// 特化型アドバイスの種別
enum AdviceType { bedding, food, routine }

class FbDashboardPage extends StatefulWidget {
  const FbDashboardPage({super.key, this.targetSession});

  final SleepSession? targetSession;

  @override
  State<FbDashboardPage> createState() => _FbDashboardPageState();
}

class _FbDashboardPageState extends State<FbDashboardPage> {
  final _ragClient = RagAnalyzeClient();
  final _payloadBuilder = SleepPayloadBuilder();

  SleepSession? _session;
  String? _memo;
  // 通常のAIアドバイス
  String? _aiAdvice;
  bool _isLoadingAi = false;
  bool _hasError = false;
  String? _errorDetail;

  // ★ 特化型アドバイス用のステート管理
  AdviceType? _selectedAdviceType;
  String? _specialAdvice;
  bool _isLoadingSpecialAi = false;

  static final Map<String, String> _adviceCache = {};
  static const _adviceCacheVersion = 'rag_prompt_v1_3';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final target =
        widget.targetSession ??
        (SleepRepository.instance.allSessions.isNotEmpty
            ? SleepRepository.instance.allSessions.last
            : null);

    if (target == null) {
      setState(() => _session = null);
      return;
    }

    await _loadSession(target);
  }

  Future<void> _loadSession(SleepSession session) async {
    final notes = SleepRepository.instance.notesForSession(session.id);
    final memo = notes.isNotEmpty ? notes.last.memo : '';

    setState(() {
      _session = session;
      _memo = memo;
      _aiAdvice = null;
      _selectedAdviceType = null;
      _specialAdvice = null;
      _hasError = false;
      _errorDetail = null;
    });

    final memoryCacheKey = _normalAdviceCacheKey(session.id);
    if (_adviceCache.containsKey(memoryCacheKey)) {
      setState(() {
        _aiAdvice = _adviceCache[memoryCacheKey];
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(memoryCacheKey);
    if (saved != null) {
      _adviceCache[memoryCacheKey] = saved;
      setState(() {
        _aiAdvice = saved;
      });
      return;
    }

    await _runAiAnalysis(session);
  }

  /// 通常の睡眠分析
  Future<void> _runAiAnalysis(SleepSession session) async {
    setState(() {
      _isLoadingAi = true;
      _hasError = false;
      _errorDetail = null;
      _aiAdvice = null;
    });

    try {
      final payload = await _payloadBuilder.build(targetSession: session);
      final result = await _ragClient.analyze(
        query: '昨夜の睡眠データを分析して、改善のためのアドバイスをください。',
        adviceType: 'chat',
        sleepData: payload,
      );
      final advice = result.text;

      final cacheKey = _normalAdviceCacheKey(session.id);
      _adviceCache[cacheKey] = advice;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, advice);

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

  // ★ ボタンが押されたときに特化型アドバイスを取得する関数
  Future<void> _fetchSpecialAdvice(
    SleepSession session,
    AdviceType type,
  ) async {
    setState(() {
      _selectedAdviceType = type;
      _isLoadingSpecialAi = true;
      _specialAdvice = null;
    });

    // キャッシュキーを一意にする（セッションID + タイプ名）
    final cacheKey = _specialAdviceCacheKey(session.id, type);

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(cacheKey);
      if (saved != null) {
        setState(() {
          _specialAdvice = saved;
          _isLoadingSpecialAi = false;
        });
        return;
      }

      final payload = await _payloadBuilder.build(targetSession: session);
      final result = await _ragClient.analyze(
        query: _specialAdviceQuery(type),
        adviceType: type.name,
        sleepData: payload,
      );
      final advice = result.text;

      await prefs.setString(cacheKey, advice);

      if (mounted) {
        setState(() {
          _specialAdvice = advice;
          _isLoadingSpecialAi = false;
        });
      }
    } catch (e) {
      AppLogger.e('特化型RAGアドバイス取得失敗: ${type.name}', e);
      if (mounted) {
        setState(() {
          _isLoadingSpecialAi = false;
          _specialAdvice = 'アドバイスの取得に失敗しました。再試行してください。\n${e.toString()}';
        });
      }
    }
  }

  Future<void> _refreshAdvice(SleepSession session) async {
    final cacheKey = _normalAdviceCacheKey(session.id);
    _adviceCache.remove(cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    await _runAiAnalysis(session);
  }

  String _normalAdviceCacheKey(String sessionId) =>
      'fb_rag_ai_advice_${SleepPayload.currentVersion}_${_adviceCacheVersion}_$sessionId';

  String _specialAdviceCacheKey(String sessionId, AdviceType type) =>
      'fb_rag_special_${SleepPayload.currentVersion}_${_adviceCacheVersion}_${type.name}_$sessionId';

  String _specialAdviceQuery(AdviceType type) {
    switch (type) {
      case AdviceType.bedding:
        return 'この睡眠データに基づき、睡眠の質を高める寝具の選び方や使い方を具体的に教えてください。';
      case AdviceType.food:
        return 'この睡眠データに基づき、睡眠の質を高める食べ物・飲み物・避けたい習慣を具体的に教えてください。';
      case AdviceType.routine:
        return 'この睡眠データに基づき、就寝前から起床までの夜ルーティンを時系列で具体的に教えてください。';
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

  static const _kBg = Color(0xFF071C35);
  static const _kCard = Color(0x0AFFFFFF);
  static const _kBorder = Color(0x14FFFFFF);
  static const _kAccent = Color(0xFF4FC3F7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('分析・フィードバック'),
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _session == null ? _buildNoData() : _buildContent(_session!),
    );
  }

  Widget _buildNoData() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_outlined, size: 64, color: Colors.white30),
          SizedBox(height: 16),
          Text(
            'データがありません',
            style: TextStyle(fontSize: 18, color: Colors.white60),
          ),
          SizedBox(height: 8),
          Text(
            'アラーム画面でSTARTして睡眠を記録してください',
            style: TextStyle(fontSize: 13, color: Colors.white38),
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // 睡眠の基本情報カード
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: _kAccent),
                    title: Text(
                      '${_formatDate(startDt)}（${endDt != null ? _formatDate(endDt) : ""}）',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '睡眠時間: ${_durationLabel(session)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('就寝', _formatTime(startDt)),
                      _buildStatItem(
                        '起床',
                        endDt != null ? _formatTime(endDt) : '--:--',
                      ),
                      _buildStatItem('時間', _durationLabel(session)),
                    ],
                  ),
                  if (_memo != null && _memo!.isNotEmpty) ...[
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                    ListTile(
                      leading: const Icon(
                        Icons.note_alt_outlined,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'メモ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        _memo!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Text(
                'アドバイス',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_aiAdvice != null && !_isLoadingAi)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white38, size: 20),
                  tooltip: '再分析',
                  onPressed: () => _refreshAdvice(session),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
            ),
            child: _buildAiAdviceContent(session),
          ),

          const SizedBox(height: 24),

          const Text(
            '睡眠の質を高めるおすすめ項目',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSpecialButton(
                session,
                AdviceType.bedding,
                '🛏️ 寝具',
                Colors.indigoAccent,
              ),
              _buildSpecialButton(
                session,
                AdviceType.food,
                '🥦 食べ物',
                Colors.tealAccent,
              ),
              _buildSpecialButton(
                session,
                AdviceType.routine,
                '🧘 ルーティン',
                Colors.deepOrangeAccent,
              ),
            ],
          ),

          if (_selectedAdviceType != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: _buildSpecialAdviceContent(session),
            ),
          ],

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF0A1628),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) =>
                      FbChatDialog(session: session, memo: _memo ?? ''),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: const Color(0xFF071C35),
              ),
              icon: const Icon(Icons.chat),
              label: const Text(
                'この結果についてAIに質問する',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 通常のアドバイス表示エリア
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
              Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                '分析に失敗しました。再試行してください。',
                style: TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
          if (_errorDetail != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _errorDetail!,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _runAiAnalysis(session),
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
              Text(
                'AI分析結果',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _aiAdvice!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ★ 新設：特化型アドバイスボタンのビルドメソッド
  Widget _buildSpecialButton(
    SleepSession session,
    AdviceType type,
    String label,
    Color themeColor,
  ) {
    final isSelected = _selectedAdviceType == type;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected
                ? themeColor.withValues(alpha: 0.85)
                : themeColor.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            side: BorderSide(color: themeColor.withValues(alpha: 0.7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _isLoadingSpecialAi
              ? null
              : () => _fetchSpecialAdvice(session, type),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  // ★ 特化型アドバイスエリアの中身表示
  Widget _buildSpecialAdviceContent(SleepSession session) {
    if (_isLoadingSpecialAi) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    String title = '';
    IconData icon = Icons.lightbulb_outline;
    Color iconColor = Colors.orange;

    if (_selectedAdviceType == AdviceType.bedding) {
      title = 'おすすめの寝具アドバイス';
      icon = Icons.bed_outlined;
      iconColor = Colors.indigo;
    } else if (_selectedAdviceType == AdviceType.food) {
      title = 'おすすめの食べ物・飲み物';
      icon = Icons.restaurant;
      iconColor = Colors.teal;
    } else if (_selectedAdviceType == AdviceType.routine) {
      title = 'おすすめの夜ルーティン';
      icon = Icons.accessibility_new;
      iconColor = Colors.deepOrange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _specialAdvice ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
