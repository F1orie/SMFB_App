import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/dummy_sleep_data_service.dart';
import '../application/sleep_recorder_service.dart';
import '../domain/sleep_note.dart';
import '../infrastructure/sleep_repository.dart';
import '../application/alarm_sound_service.dart';
import '../application/alarm_timer_service.dart';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initAlarmNotifications() async {
  if (kIsWeb) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifications.initialize(
    settings: const InitializationSettings(android: android),
  );
  // Android 13+ の通知パーミッションをリクエスト
  await _requestNotificationPermission();
}

/// 通知パーミッションをリクエスト（Android 13+ / iOS）
Future<void> _requestNotificationPermission() async {
  if (kIsWeb) return;
  final permission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
}

const _alarmMinuteGranularity = 5;

// ── カラーパレット ────────────────────────────────────────────
const _bgTop    = Color(0xFF050D1F); // 最深ネイビー
const _bgBottom = Color(0xFF0A1A33); // 深ネイビー
const _accent   = Color(0xFF00D4FF); // サイアン
const _startBg  = Color(0xFF00E676); // 発光グリーン
const _stopBg   = Color(0xFFFF1744); // 発光レッド

/// 睡眠アプリ アラーム設定画面
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, this.onNavigateToGraph, this.onNavigateToFb});

  final VoidCallback? onNavigateToGraph;
  final VoidCallback? onNavigateToFb;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  static const _itemExtent = 40.0;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  final SleepRecorderService _recorderService = SleepRecorderService();
  final DummySleepDataService _dummySleepDataService = DummySleepDataService();
  final AlarmSoundService _alarmSoundService = AlarmSoundService();
  final AlarmTimerService _alarmTimerService = AlarmTimerService();

  SleepRecordResult? _lastResult;
  Timer? _notificationTimer;

  int _hour = 7;
  int _minute = 15;

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(
      initialItem: _minute ~/ _alarmMinuteGranularity,
    );
    unawaited(
      initAlarmNotifications().catchError((Object error, StackTrace _) {
        debugPrint('Alarm notification initialization failed: $error');
      }),
    );
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _recorderService.dispose();

    _notificationTimer?.cancel();

    _alarmTimerService.dispose();
    _alarmSoundService.dispose();

    super.dispose();
  }

  String _wakeWindowLabel() {
    final endM = _hour * 60 + _minute;
    final day = 24 * 60;
    var startM = endM - 30;
    startM = (startM % day + day) % day;
    final em = ((endM % day) + day) % day;
    return '${_formatHm(startM)} - ${_formatHm(em)}';
  }

  String _formatHm(int minutesFromMidnight) {
    final m = minutesFromMidnight % (24 * 60);
    final h = m ~/ 60;
    final min = m % 60;
    return '$h:${min.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final now = DateTime.now();
    var alarmDt = DateTime(now.year, now.month, now.day, _hour, _minute);
    if (!alarmDt.isAfter(now)) {
      alarmDt = alarmDt.add(const Duration(days: 1));
    }
    final alarmMs = alarmDt.millisecondsSinceEpoch;

    // 設定からセンサー感度を読み込んで適用
    final prefs = await SharedPreferences.getInstance();
    final normFactor = prefs.getDouble('sensor_norm_factor') ?? 2.0;
    _recorderService.setNormFactor(normFactor);

    // フォアグラウンドサービス起動 + センサー開始
    await _recorderService.start(alarmTimeEpochMs: alarmMs);

    // アラーム時刻に起床通知を送る
    _notificationTimer?.cancel();
    _alarmTimerService.setAlarm(
      alarmTime: alarmDt,
      onRing: () {
        _ringAlarm();
      },
    );
    if (!kIsWeb) {
      _notificationTimer = Timer(alarmDt.difference(now), () {
        _notifications.show(
          id: 0,
          title: '起床時間です',
          body: 'STOPを押して計測を終了してください',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'alarm_channel',
              'アラーム',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      });
    }

    if (!mounted) return;
    setState(() {
      _lastResult = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('睡眠記録を開始しました')));
  }

  Future<void> _stopRecording() async {
    final result = await _recorderService.stop();

    if (result != null) {
      await SleepRepository.instance.saveSession(result.session);
      await SleepRepository.instance.saveEpochs(result.epochs);
    }

    if (!mounted) return;

    setState(() {
      _lastResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == null ? '記録中のデータがありません' : '睡眠記録を停止しました')),
    );

    if (result != null) {
      await _showMemoDialog(result.session.id);
      if (!mounted) return;
      // メモ保存後は分析(fb)画面へ遷移（フレーム確定後に切り替えてクラッシュ回避）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNavigateToFb?.call();
      });
    }
  }

  Future<void> _ringAlarm() async {
    await _alarmSoundService.play();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('アラーム'),
          content: const Text('起床時間です'),
          actions: [
            TextButton(
              onPressed: () async {
                await _alarmSoundService.stop();

                _alarmTimerService.snooze(
                  onRing: () {
                    _ringAlarm();
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('SNOOZE 5分'),
            ),
            FilledButton(
              onPressed: () async {
                await _alarmSoundService.stop();
                _alarmTimerService.cancel();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('STOP'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMemoDialog(String sessionId) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MemoDialog(sessionId: sessionId),
    );
  }

  Future<void> _createDummyData() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ja'),
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030, 12, 31),
    );

    if (picked == null || !mounted) return;

    await _dummySleepDataService.generateAndSave(date: picked);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${picked.month}月${picked.day}日のダミーデータを保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RecorderState>(
      valueListenable: _recorderService.stateNotifier,
      builder: (context, state, _) {
        final isRecording = state == RecorderState.recording;
        return Stack(
          children: [
            // ── ドットグリッド背景 ────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
            // ── グラデーション背景 ────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom],
                  ),
                ),
              ),
            ),
            // ── メインコンテンツ ──────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // ── ステータスバー ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SLEEP TIMER',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 4,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _StatusPill(isRecording: isRecording),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── 大型時刻表示 ────────────────────────────
                  Text(
                    '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w100,
                      color: Colors.white,
                      letterSpacing: 12,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ── 起床ウィンドウ ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'WAKE  ',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 3,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        _wakeWindowLabel(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _accent,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── テック区切り ────────────────────────────
                  _TechDivider(label: 'SET ALARM'),
                  const SizedBox(height: 12),
                  // ── 時刻ピッカー（ブラケット装飾付き） ────────
                  Expanded(
                    child: Center(
                      child: _BracketedPicker(
                        child: _AlarmTimePickerCard(
                          itemExtent: _itemExtent,
                          hourCtrl: _hourCtrl,
                          minuteCtrl: _minuteCtrl,
                          onHourChanged: (h) => setState(() => _hour = h),
                          onMinuteChanged: (m) => setState(() => _minute = m),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── テック区切り ────────────────────────────
                  _TechDivider(label: isRecording ? 'RECORDING' : 'STANDBY'),
                  const SizedBox(height: 24),
                  // ── START / STOP ボタン（リング付き） ─────────
                  _GlowButton(
                    isRecording: isRecording,
                    onTap: isRecording ? _stopRecording : _startRecording,
                  ),
                  const SizedBox(height: 16),
                  if (_lastResult != null) ...[
                    _SleepResultSummary(result: _lastResult!),
                    const SizedBox(height: 8),
                  ],
                  // ── ダミーデータ（控えめ） ──────────────────
                  TextButton.icon(
                    onPressed: _createDummyData,
                    style: TextButton.styleFrom(foregroundColor: Colors.white24),
                    icon: const Icon(Icons.data_object, size: 14),
                    label: const Text('DEBUG', style: TextStyle(fontSize: 11, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 6),
                  const _AdBannerPlaceholder(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 計測結果のサマリー表示（入眠潜時を含む）
class _SleepResultSummary extends StatelessWidget {
  const _SleepResultSummary({required this.result});

  final SleepRecordResult result;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, color: Colors.white70);
    final onset = result.session.sleepOnsetEpochMs;
    final latencyMin = onset != null
        ? ((onset - result.session.startAtEpochMs) / 1000 / 60).floor()
        : null;

    return Column(
      children: [
        Text(
          '睡眠時間: ${result.metrics.totalSleepMin}分'
          ' / 平均深度: ${result.metrics.averageDepth.toStringAsFixed(2)}',
          style: style,
        ),
        Text(
          latencyMin != null
              ? '入眠潜時: $latencyMin分'
              : '入眠検出: なし（動きが多かったか計測時間が短い可能性があります）',
          style: style,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


class _AlarmTimePickerCard extends StatelessWidget {
  const _AlarmTimePickerCard({
    required this.itemExtent,
    required this.hourCtrl,
    required this.minuteCtrl,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final double itemExtent;
  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minuteCtrl;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemExtent * 7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 選択中アイテムの薄い帯
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: itemExtent,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: _WheelColumn(
                  controller: hourCtrl,
                  itemExtent: itemExtent,
                  itemCount: 24,
                  labelBuilder: (i) => '$i',
                  onSelected: onHourChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 36,
                    color: _accent,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: _WheelColumn(
                  controller: minuteCtrl,
                  itemExtent: itemExtent,
                  itemCount: 12,
                  labelBuilder: (i) => (i * _alarmMinuteGranularity)
                      .toString()
                      .padLeft(2, '0'),
                  onSelected: (idx) =>
                      onMinuteChanged(idx * _alarmMinuteGranularity),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.itemExtent,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: itemExtent,
        perspective: 0.006,
        diameterRatio: 1.45,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
            return Center(
              child: Text(
                labelBuilder(index),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdBannerPlaceholder extends StatelessWidget {
  const _AdBannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '広告枠（プレースホルダー）',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.grey.shade700),
      ),
    );
  }
}

// ── 近未来UIウィジェット群 ────────────────────────────────────

/// ドットグリッド背景
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// STANDBY / RECORDING ステータスピル
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isRecording});
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? _stopBg : _accent;
    final label = isRecording ? 'REC' : 'STANDBY';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// テック風区切り線
class _TechDivider extends StatelessWidget {
  const _TechDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _accent.withValues(alpha: 0.4)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 3,
                color: _accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent.withValues(alpha: 0.4), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// コーナーブラケット装飾付きコンテナ
class _BracketedPicker extends StatelessWidget {
  const _BracketedPicker({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const bracketSize = 16.0;
    const bracketThickness = 1.5;
    const bracketColor = _accent;

    Widget corner({required bool top, required bool left}) {
      return SizedBox(
        width: bracketSize,
        height: bracketSize,
        child: CustomPaint(
          painter: _CornerPainter(
            top: top,
            left: left,
            color: bracketColor,
            thickness: bracketThickness,
          ),
        ),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
        Positioned(top: 0, left: 0, child: corner(top: true, left: true)),
        Positioned(top: 0, right: 0, child: corner(top: true, left: false)),
        Positioned(bottom: 0, left: 0, child: corner(top: false, left: true)),
        Positioned(bottom: 0, right: 0, child: corner(top: false, left: false)),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });
  final bool top, left;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 発光リング付きSTART/STOPボタン
class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.isRecording, required this.onTap});
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final btnColor = isRecording ? _stopBg : _startBg;
    final label = isRecording ? 'STOP' : 'START';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外側発光リング
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: btnColor.withValues(alpha: 0.25), width: 1),
            ),
          ),
          // 中間リング
          Container(
            width: 102,
            height: 102,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: btnColor.withValues(alpha: 0.5), width: 1),
            ),
          ),
          // メインボタン
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: btnColor.withValues(alpha: 0.15),
              border: Border.all(color: btnColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: btnColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: btnColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoDialog extends StatefulWidget {
  const _MemoDialog({required this.sessionId});

  final String sessionId;

  @override
  State<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<_MemoDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('今夜の睡眠メモ'),
      content: TextField(
        controller: _ctrl,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'メモを入力してください',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('スキップ'),
        ),
        FilledButton(
          onPressed: () async {
            await SleepRepository.instance.saveNote(
              SleepNote(
                sessionId: widget.sessionId,
                createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
                memo: _ctrl.text,
                hadAlcohol: false,
                hadCaffeine: false,
                didExercise: false,
              ),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
