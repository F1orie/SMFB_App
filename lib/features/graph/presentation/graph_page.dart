import 'package:flutter/material.dart';
import 'package:smf_app/features/alarm/domain/sleep_note.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

import '../daily_sleep_depth_mock.dart';

/// グラフ機能（睡眠記録閲覧）UI。
///
/// 現フェーズは UI のみで、Android で取得した実データは未実装。
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  DateTime _selectedDate = DateTime.now();

  final Map<String, Set<String>> _selectedActionsByDate = {};

  static const _kBackground = Color(0xFF071C35);

  DailySleepDepthMock get _mock {
    return _mockByDate(_selectedDate);
  }

  DailySleepDepthMock _mockByDate(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;

    if (y == 2026 && m == 4 && d == 21) return buildMockDailySleepDepth();
    if (y == 2026 && m == 4 && d == 22) return buildNoSleepMock();
    if (y == 2026 && m == 4 && d == 23) return buildOversleepMock();

    // リポジトリに保存済みのダミーデータがあれば使う
    final repoMock = _buildFromRepository(date);
    if (repoMock != null) return repoMock;

    return buildEmptyMock(date);
  }

  /// リポジトリの SleepEpoch を DailySleepDepthMock に変換する。
  /// 対象日のセッションがなければ null を返す。
  DailySleepDepthMock? _buildFromRepository(DateTime date) {
    final repo = SleepRepository.instance;
    final sessions = repo.allSessions.where((s) {
      final start = DateTime.fromMillisecondsSinceEpoch(s.startAtEpochMs);
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    });
    if (sessions.isEmpty) return null;

    final session = sessions.first;
    final epochs = repo.epochsForSession(session.id);
    if (epochs.isEmpty) return null;

    final startMs = session.startAtEpochMs;
    final endMs =
        session.endAtEpochMs ??
        startMs + const Duration(hours: 7).inMilliseconds;

    final points = (epochs.map(
      (e) => SleepDepthPoint(
        minuteFromZero: ((e.tEpochMs - startMs) / 60000).floor(),
        depth01: e.scoreDepth.clamp(0.0, 1.0),
      ),
    ).toList()
      ..sort((a, b) => a.minuteFromZero.compareTo(b.minuteFromZero)));

    final startDt = DateTime.fromMillisecondsSinceEpoch(startMs);
    final endDt = DateTime.fromMillisecondsSinceEpoch(endMs);
    final totalHours = ((endMs - startMs) / 3600000).ceil().clamp(1, 24);

    final dMs = endMs - startMs;
    final dh = (dMs / 3600000).floor();
    final dm = ((dMs % 3600000) / 60000).floor();
    final durationLabel = dm > 0 ? '$dh時間$dm分' : '$dh時間';

    String pad(int v) => v.toString().padLeft(2, '0');

    final int? alarmMin = session.alarmTimeEpochMs != null
        ? ((session.alarmTimeEpochMs! - startMs) / 60000).floor()
        : null;
    final int actualWakeMin = ((endMs - startMs) / 60000).floor();

    final notes = repo.notesForSession(session.id);
    final memo = notes.isNotEmpty ? notes.last.memo : '';

    return DailySleepDepthMock(
      rangeLabel: '${startDt.month}月${startDt.day}日',
      xTickStartHour: 0,
      xTickEndHour: totalHours,
      points: points,
      summary: SleepSummaryMock(
        bedtimeLabel: '${startDt.hour}:${pad(startDt.minute)}',
        fallAsleepLabel: '--',
        wakeUpLabel: '${endDt.hour}:${pad(endDt.minute)}',
        sleepDurationLabel: durationLabel,
        latencyLabel: '--',
        awakeningCountLabel: '--',
        awakeningTimeLabel: '--',
        efficiencyLabel: '--',
        deepTimeLabel: '--',
        lightTimeLabel: '--',
      ),
      memo: memo,
      sessionId: session.id,
      alarmMinuteFromZero: alarmMin,
      actualWakeMinuteFromZero: actualWakeMin,
    );
  }

  void _goPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _openCalendar() async {
    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('ja'),
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _mock.summary;

    return ColoredBox(
      color: _kBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            _DateRangeHeader(
              text: _mock.rangeLabel,
              onCalendarTap: _openCalendar,
              onPreviousTap: _goPreviousDay,
              onNextTap: _goNextDay,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 240,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      painter: SleepDepthAreaChartPainter(
                        points: _mock.points,
                        xTickStartHour: _mock.xTickStartHour,
                        xTickEndHour: _mock.xTickEndHour,
                        alarmMinuteFromZero: _mock.alarmMinuteFromZero,
                        actualWakeMinuteFromZero: _mock.actualWakeMinuteFromZero,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _GraphActionRow(),
            const SizedBox(height: 10),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const _GraphSubTabs(
                      tabs: ['データ', 'メモ', '行動'],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _DataTab(summary: summary),
                          _MemoTab(
                            memo: _mock.memo,
                            sessionId: _mock.sessionId,
                          ),
                          _ActionTab(
                            selectedDate: _selectedDate,
                            selectedActionsByDate: _selectedActionsByDate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeHeader extends StatelessWidget {
  const _DateRangeHeader({
    required this.text,
    required this.onCalendarTap,
    required this.onPreviousTap,
    required this.onNextTap,
  });

  final String text;
  final VoidCallback onCalendarTap;
  final VoidCallback onPreviousTap;
  final VoidCallback onNextTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onCalendarTap,
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
          ),
          const Spacer(),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPreviousTap,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          IconButton(
            onPressed: onNextTap,
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GraphActionRow extends StatelessWidget {
  const _GraphActionRow();

  @override
  Widget build(BuildContext context) {
    const buttonSize = 44.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BadgeIconButton(
            size: buttonSize,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            icon: Icons.delete_outline,
            iconColor: Colors.white,
          ),
          _BadgeIconButton(
            size: buttonSize,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            icon: Icons.mail_outline,
            iconColor: Colors.white,
          ),
          _BadgeIconButton(
            size: buttonSize,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            icon: Icons.volume_up_outlined,
            iconColor: Colors.white,
          ),
          _BadgeIconButton(
            size: buttonSize,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            icon: Icons.share_outlined,
            iconColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  const _BadgeIconButton({
    required this.size,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final double size;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {},
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _GraphSubTabs extends StatelessWidget {
  const _GraphSubTabs({required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        tabs: tabs.map((e) => Tab(text: e)).toList(),
      ),
    );
  }
}

class _DataTab extends StatelessWidget {
  const _DataTab({required this.summary});

  final SleepSummaryMock summary;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('就寝時刻', summary.bedtimeLabel),
      MapEntry('入眠時刻', summary.fallAsleepLabel),
      MapEntry('起床時刻', summary.wakeUpLabel),
      MapEntry('睡眠時間', summary.sleepDurationLabel),
      MapEntry('入眠潜時', summary.latencyLabel),
      MapEntry('中途覚醒回数', summary.awakeningCountLabel),
      MapEntry('中途覚醒時間', summary.awakeningTimeLabel),
      MapEntry('睡眠効率', summary.efficiencyLabel),
      MapEntry('深睡眠', summary.deepTimeLabel),
      MapEntry('浅睡眠', summary.lightTimeLabel),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (context, _) => Divider(
            height: 18,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          itemBuilder: (context, i) {
            final row = rows[i];
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${row.key}：',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemoTab extends StatefulWidget {
  const _MemoTab({required this.memo, this.sessionId});

  final String memo;
  final String? sessionId;

  @override
  State<_MemoTab> createState() => _MemoTabState();
}

class _MemoTabState extends State<_MemoTab> {
  late final TextEditingController _ctrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.memo);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    final repo = SleepRepository.instance;
    await repo.removeNotesForSession(sessionId);
    await repo.saveNote(
      SleepNote(
        sessionId: sessionId,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        memo: _ctrl.text,
        hadAlcohol: false,
        hadCaffeine: false,
        didExercise: false,
      ),
    );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = widget.sessionId != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              enabled: canSave,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                height: 1.6,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'メモを入力してください',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              ),
              onChanged: (_) {
                if (_saved) setState(() => _saved = false);
              },
            ),
          ),
          const SizedBox(height: 10),
          if (canSave)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_saved)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '保存しました',
                      style: TextStyle(
                        color: Colors.greenAccent.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionTab extends StatefulWidget {
  const _ActionTab({
    required this.selectedDate,
    required this.selectedActionsByDate,
  });

  final DateTime selectedDate;
  final Map<String, Set<String>> selectedActionsByDate;

  @override
  State<_ActionTab> createState() => _ActionTabState();
}

class _ActionTabState extends State<_ActionTab> {
  final List<String> _actions = const [
    'アルコール',
    'カフェイン',
    '運動',
    '食事',
    '喫煙',
    '入浴',
  ];

  String get _dateKey {
    final date = widget.selectedDate;
    return '${date.year}-${date.month}-${date.day}';
  }

  void _toggleAction(String action) {
    setState(() {
      final selectedActions =
          widget.selectedActionsByDate.putIfAbsent(_dateKey, () => <String>{});
      if (selectedActions.contains(action)) {
        selectedActions.remove(action);
      } else {
        selectedActions.add(action);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedActions =
        widget.selectedActionsByDate[_dateKey] ?? <String>{};

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      itemCount: _actions.length,
      separatorBuilder: (context, index) => Divider(
        height: 28,
        color: Colors.white.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final action = _actions[index];
        final isSelected = selectedActions.contains(action);

        return InkWell(
          onTap: () => _toggleAction(action),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 38,
                        )
                      : const SizedBox(),
                ),
                Text(
                  action,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SleepDepthAreaChartPainter extends CustomPainter {
  SleepDepthAreaChartPainter({
    required this.points,
    required this.xTickStartHour,
    required this.xTickEndHour,
    this.alarmMinuteFromZero,
    this.actualWakeMinuteFromZero,
  });

  final List<SleepDepthPoint> points;
  final int xTickStartHour;
  final int xTickEndHour;
  final int? alarmMinuteFromZero;
  final int? actualWakeMinuteFromZero;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 26.0;
    const rightPad = 8.0;
    const topPad = 18.0;
    const bottomPad = 22.0;

    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = plotRect.bottom - plotRect.height * (i / 4);
      canvas.drawLine(
        plotRect.topLeft.translate(0, y - plotRect.top),
        plotRect.topRight.translate(0, y - plotRect.top),
        gridPaint,
      );
    }

    final totalHours = (xTickEndHour - xTickStartHour).clamp(1, 9999);

    for (var hour = xTickStartHour; hour <= xTickEndHour; hour++) {
      final x =
          plotRect.left + (hour - xTickStartHour) / totalHours * plotRect.width;
      _drawTickLabel(
        canvas,
        text: '$hour',
        x: x,
        y: plotRect.bottom + 10,
        color: Colors.white.withValues(alpha: 0.65),
      );
    }

    if (points.length < 2) return;

    final totalMinutes = (xTickEndHour - xTickStartHour) * 60;
    final lastMinute = points.last.minuteFromZero;
    final denom = (lastMinute > 0) ? lastMinute : totalMinutes.toDouble();

    // ── 起床ウィンドウ描画 ──────────────────────────────────────
    final alarm = alarmMinuteFromZero;
    final wake = actualWakeMinuteFromZero;

    if (alarm != null) {
      final windowStart = (alarm - 30).clamp(0, totalMinutes);
      final xWinStart =
          plotRect.left + (windowStart / denom) * plotRect.width;
      final xWinEnd =
          (plotRect.left + (alarm / denom) * plotRect.width)
              .clamp(plotRect.left, plotRect.right);

      // 黄色の半透明帯
      canvas.drawRect(
        Rect.fromLTRB(xWinStart, plotRect.top, xWinEnd, plotRect.bottom),
        Paint()..color = Colors.yellow.withValues(alpha: 0.18),
      );

      if (wake != null) {
        final xWake =
            (plotRect.left + (wake / denom) * plotRect.width)
                .clamp(plotRect.left, plotRect.right);
        final inWindow = wake >= alarm - 30 && wake <= alarm;
        final lineColor = inWindow ? Colors.greenAccent : Colors.redAccent;

        // 縦線
        canvas.drawLine(
          Offset(xWake, plotRect.top),
          Offset(xWake, plotRect.bottom),
          Paint()
            ..color = lineColor
            ..strokeWidth = 2.0,
        );

        // ラベル
        _drawTickLabel(
          canvas,
          text: inWindow ? '設定時刻内に起床' : '設定時刻を過ぎて起床',
          x: xWake,
          y: plotRect.top - 2,
          color: lineColor,
        );
      }
    }
    // ────────────────────────────────────────────────────────────

    final linePath = Path();

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = plotRect.left + (p.minuteFromZero / denom) * plotRect.width;
      final y = plotRect.bottom - p.depth01 * plotRect.height;

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final areaPath = Path.from(linePath);
    final firstX = plotRect.left;
    final lastX =
        plotRect.left + (points.last.minuteFromZero / denom) * plotRect.width;

    areaPath
      ..lineTo(lastX, plotRect.bottom)
      ..lineTo(firstX, plotRect.bottom)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.22);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.95);

    canvas.drawPath(areaPath, fillPaint);
    canvas.drawPath(linePath, strokePaint);
  }

  void _drawTickLabel(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height));
  }

  @override
  bool shouldRepaint(covariant SleepDepthAreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.xTickStartHour != xTickStartHour ||
        oldDelegate.xTickEndHour != xTickEndHour ||
        oldDelegate.alarmMinuteFromZero != alarmMinuteFromZero ||
        oldDelegate.actualWakeMinuteFromZero != actualWakeMinuteFromZero;
  }
}
