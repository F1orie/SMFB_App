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
  late final List<SleepSession> _sessions;

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  void initState() {
    super.initState();
    final all = List<SleepSession>.from(SleepRepository.instance.allSessions);
    all.sort((a, b) => b.startAtEpochMs.compareTo(a.startAtEpochMs));
    _sessions = all;
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
    final mins =
        (s.endAtEpochMs! - s.startAtEpochMs) ~/ 1000 ~/ 60;
    return '${mins ~/ 60}時間${mins % 60}分';
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
                leading: const Icon(Icons.auto_awesome, color: Colors.amber),
                title: const Text('AI分析を見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onNavigateToFb?.call(session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('詳細'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDetail(session, note);
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
            _detailRow('起床', end != null ? _timeLabel(session.endAtEpochMs!) : '--:--'),
            _detailRow('睡眠時間', _durationLabel(session)),
            if (note != null && note.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('メモ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(note.memo),
            ],
            if (note != null &&
                (note.hadAlcohol || note.hadCaffeine || note.didExercise)) ...[
              const SizedBox(height: 12),
              const Text('記録', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('睡眠記録')),
      body: _sessions.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'まだ記録がありません',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'アラーム画面でSTARTして睡眠を記録してください',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final notes = SleepRepository.instance.notesForSession(session.id);
        final note = notes.isNotEmpty ? notes.last : null;
        return _SessionCard(
          session: session,
          note: note,
          dateLabel: _dateLabel(
            DateTime.fromMillisecondsSinceEpoch(session.startAtEpochMs),
          ),
          startLabel: _timeLabel(session.startAtEpochMs),
          endLabel: session.endAtEpochMs != null
              ? _timeLabel(session.endAtEpochMs!)
              : '--:--',
          durationLabel: _durationLabel(session),
          onTap: () => _showActionSheet(session, note),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.note,
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.durationLabel,
    required this.onTap,
  });

  final SleepSession session;
  final SleepNote? note;
  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final String durationLabel;
  final VoidCallback onTap;

  bool get _isRecording => session.endAtEpochMs == null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付 + バッジ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  _StatusBadge(isRecording: _isRecording),
                ],
              ),
              const SizedBox(height: 12),
              // 3カラム統計
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(icon: Icons.bedtime, label: '就寝', value: startLabel),
                  _StatItem(icon: Icons.wb_sunny, label: '起床', value: endLabel),
                  _StatItem(icon: Icons.timer, label: '時間', value: durationLabel),
                ],
              ),
              // メモ
              if (note != null && note!.memo.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_alt_outlined,
                        size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note!.memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isRecording});
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isRecording ? Colors.orange : Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isRecording ? '記録中' : '完了',
        style: const TextStyle(
            fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
