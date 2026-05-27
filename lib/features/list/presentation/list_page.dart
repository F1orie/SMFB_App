import 'package:flutter/material.dart';
import 'package:smf_app/features/alarm/domain/sleep_note.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

class ListPage extends StatefulWidget {
  const ListPage({
    super.key,
    this.onNavigateToGraph,
    this.onNavigateToFb,
  });

  final void Function(DateTime date)? onNavigateToGraph;
  final void Function(SleepSession session)? onNavigateToFb;

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  List<SleepSession> _sessions = [];

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  static const _kBackground = Color(0xFF071C35);

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    final all = List<SleepSession>.from(SleepRepository.instance.allSessions);
    all.sort((a, b) => b.startAtEpochMs.compareTo(a.startAtEpochMs));
    setState(() => _sessions = all);
  }

  String _dateLabel(DateTime dt) {
    final wd = _weekdays[dt.weekday - 1];
    return '${dt.month}月${dt.day}日（$wd）';
  }

  String _timeLabel(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _durationLabel(SleepSession s) {
    if (s.endAtEpochMs == null) return '--';
    final mins = (s.endAtEpochMs! - s.startAtEpochMs) ~/ 1000 ~/ 60;
    return '${mins ~/ 60}時間${mins % 60}分';
  }

  /// 睡眠時間に応じたスコアカラーを返す
  Color _scoreColor(SleepSession session) {
    if (session.endAtEpochMs == null) return Colors.orange;
    final mins = (session.endAtEpochMs! - session.startAtEpochMs) ~/ 60000;
    if (mins >= 420) return const Color(0xFF4FC3F7); // 7時間以上 → 水色
    if (mins >= 300) return const Color(0xFF81C784); // 5時間以上 → 緑
    return const Color(0xFFFF8A65); // 5時間未満 → オレンジ
  }

  Future<void> _deleteSession(SleepSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('記録を削除しますか？'),
        content: Text(
          '${_dateLabel(DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs))}の睡眠データを削除します。\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = SleepRepository.instance;
    await repo.removeSession(session.id);
    await repo.removeEpochsForSession(session.id);
    await repo.removeNotesForSession(session.id);

    _loadSessions();
  }

  void _showActionSheet(SleepSession session, SleepNote? note) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${_dateLabel(start)}の睡眠記録',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.show_chart, color: Colors.blue),
                title: const Text('グラフを見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onNavigateToGraph?.call(start);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.auto_awesome, color: Colors.amber),
                title: const Text('AI分析を見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onNavigateToFb?.call(session);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('詳細'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDetail(session, note);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('削除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteSession(session);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(SleepSession session, SleepNote? note) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);
    final end = session.endAtEpochMs != null
        ? DateTime.fromMillisecondsSinceEpoch(session.endAtEpochMs!)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_dateLabel(start)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('就寝', _timeLabel(session.startAtEpochMs)),
            _detailRow('起床',
                end != null ? _timeLabel(session.endAtEpochMs!) : '--:--'),
            _detailRow('睡眠時間', _durationLabel(session)),
            if (note != null && note.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('メモ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(note.memo),
            ],
            if (note != null &&
                (note.hadAlcohol ||
                    note.hadCaffeine ||
                    note.didExercise)) ...[
              const SizedBox(height: 12),
              const Text('記録',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (note.hadAlcohol) _chip('アルコール', Colors.purple),
                  if (note.hadCaffeine) _chip('カフェイン', Colors.brown),
                  if (note.didExercise) _chip('運動', Colors.green),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Chip(
      label: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: const Text('睡眠記録'),
        backgroundColor: _kBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _sessions.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'まだ記録がありません',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          const Text(
            'アラーム画面でSTARTして睡眠を記録してください',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 月ごとのヘッダー付きリストアイテムを生成する
  List<Widget> _buildItems() {
    final items = <Widget>[];
    String? lastMonth;

    for (final session in _sessions) {
      final dt = DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs);
      final monthKey = '${dt.year}年${dt.month}月';

      if (monthKey != lastMonth) {
        items.add(_MonthHeader(label: monthKey));
        lastMonth = monthKey;
      }

      final notes = SleepRepository.instance.notesForSession(session.id);
      final note = notes.isNotEmpty ? notes.last : null;

      items.add(
        Dismissible(
          key: ValueKey(session.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade700.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 28),
                SizedBox(height: 4),
                Text('削除',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('記録を削除しますか？'),
                content: Text(
                  '${_dateLabel(DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs))}のデータを削除します。\nこの操作は取り消せません。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
            return confirmed == true;
          },
          onDismissed: (_) async {
            final repo = SleepRepository.instance;
            await repo.removeSession(session.id);
            await repo.removeEpochsForSession(session.id);
            await repo.removeNotesForSession(session.id);
            _loadSessions();
          },
          child: _SessionCard(
            session: session,
            note: note,
            scoreColor: _scoreColor(session),
            dateLabel: _dateLabel(dt),
            startLabel: _timeLabel(session.startAtEpochMs),
            endLabel: session.endAtEpochMs != null
                ? _timeLabel(session.endAtEpochMs!)
                : '--:--',
            durationLabel: _durationLabel(session),
            onTap: () => _showActionSheet(session, note),
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: _buildItems(),
    );
  }
}

// ── _MonthHeader ────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── _SessionCard ────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.note,
    required this.scoreColor,
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.durationLabel,
    required this.onTap,
  });

  final SleepSession session;
  final SleepNote? note;
  final Color scoreColor;
  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final String durationLabel;
  final VoidCallback onTap;

  bool get _isRecording => session.endAtEpochMs == null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          // 左端をスコアカラー、他3辺を薄いボーダーで描画
          // → IntrinsicHeight 不要でオーバーフロー根絶
          border: Border(
            left: BorderSide(color: scoreColor, width: 4),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  _StatusBadge(isRecording: _isRecording),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                      icon: Icons.bedtime,
                      label: '就寝',
                      value: startLabel),
                  _StatItem(
                      icon: Icons.wb_sunny,
                      label: '起床',
                      value: endLabel),
                  _StatItem(
                      icon: Icons.timer,
                      label: '時間',
                      value: durationLabel),
                ],
              ),
              if (note != null && note!.memo.isNotEmpty) ...[
                const Divider(height: 20, color: Colors.white12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note!.memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── _StatusBadge ────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isRecording});
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isRecording
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecording ? Colors.orange : Colors.white24,
        ),
      ),
      child: Text(
        isRecording ? '記録中' : '完了',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isRecording ? Colors.orange : Colors.white54,
        ),
      ),
    );
  }
}

// ── _StatItem ───────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            size: 20,
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.8)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }
}
