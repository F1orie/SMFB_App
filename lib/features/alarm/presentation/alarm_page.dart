import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../application/dummy_sleep_data_service.dart';
import '../application/sleep_recorder_service.dart';
import '../domain/sleep_note.dart';
import '../infrastructure/sleep_repository.dart';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initAlarmNotifications() async {
  if (kIsWeb) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifications.initialize(
    settings: const InitializationSettings(android: android),
  );
}

const _alarmMinuteGranularity = 5;

/// 参考 UI に近いアラーム設定画面
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, this.onNavigateToGraph});

  final VoidCallback? onNavigateToGraph;

  static const backgroundColor = Color(0xFFE6E9EF);
  static const startButtonColor = Color(0xFF6DBB81);
  static const pickerBorderColor = Color(0xFF1C2B45);

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  static const _itemExtent = 40.0;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  final SleepRecorderService _recorderService = SleepRecorderService();
  final DummySleepDataService _dummySleepDataService = DummySleepDataService();

  SleepRecordResult? _lastResult;
  String? _lastDummySessionId;
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
    initAlarmNotifications();
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _recorderService.dispose();
    _notificationTimer?.cancel();
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

  void _startRecording() {
    final now = DateTime.now();
    var alarmDt = DateTime(now.year, now.month, now.day, _hour, _minute);
    if (!alarmDt.isAfter(now)) {
      alarmDt = alarmDt.add(const Duration(days: 1));
    }
    final alarmMs = alarmDt.millisecondsSinceEpoch;

    _recorderService.start(alarmTimeEpochMs: alarmMs);

    _notificationTimer?.cancel();
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

    setState(() {
      _lastResult = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('睡眠記録を開始しました')),
    );
  }

  Future<void> _stopRecording() async {
    final result = _recorderService.stop();

    if (result != null) {
      await SleepRepository.instance.saveSession(result.session);
      await SleepRepository.instance.saveEpochs(result.epochs);
    }

    if (!mounted) return;

    setState(() {
      _lastResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null ? '記録中のデータがありません' : '睡眠記録を停止しました',
        ),
      ),
    );

    if (result != null) {
      await _showMemoDialog(result.session.id);
      if (!mounted) return;
      widget.onNavigateToGraph?.call();
    }
  }

  Future<void> _showMemoDialog(String sessionId) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('今夜の睡眠メモ'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'メモを入力してください',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('スキップ'),
          ),
          FilledButton(
            onPressed: () async {
              await SleepRepository.instance.saveNote(
                SleepNote(
                  sessionId: sessionId,
                  createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
                  memo: ctrl.text,
                  hadAlcohol: false,
                  hadCaffeine: false,
                  didExercise: false,
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
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

    final sessionId =
        await _dummySleepDataService.generateAndSave(date: picked);

    if (!mounted) return;

    setState(() {
      _lastDummySessionId = sessionId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${picked.month}月${picked.day}日のダミーデータを保存しました',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AlarmPage.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _AlarmTimePickerCard(
                            itemExtent: _itemExtent,
                            borderColor: AlarmPage.pickerBorderColor,
                            hourCtrl: _hourCtrl,
                            minuteCtrl: _minuteCtrl,
                            onHourChanged: (h) => setState(() => _hour = h),
                            onMinuteChanged: (m) =>
                                setState(() => _minute = m),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SideActionButtons(
                          onMemo: () {},
                          onCheck: () {},
                          onShare: () {},
                          onMic: () {},
                          onAudio: () {},
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'アラーム設定',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _wakeWindowLabel(),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<RecorderState>(
                valueListenable: _recorderService.stateNotifier,
                builder: (context, state, _) {
                  final isRecording = state == RecorderState.recording;

                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isRecording
                            ? Colors.redAccent
                            : AlarmPage.startButtonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      onPressed:
                          isRecording ? _stopRecording : _startRecording,
                      child: Text(isRecording ? 'STOP' : 'START'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createDummyData,
                  icon: const Icon(Icons.data_object),
                  label: const Text('ダミーデータ作成'),
                ),
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 6),
                Text(
                  '睡眠時間: ${_lastResult!.metrics.totalSleepMin}分 / 平均深度: ${_lastResult!.metrics.averageDepth.toStringAsFixed(2)}',
                  style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
              if (_lastDummySessionId != null) ...[
                const SizedBox(height: 6),
                Text(
                  '保存済みダミーID: $_lastDummySessionId',
                  style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
              const SizedBox(height: 12),
              const _AdBannerPlaceholder(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmTimePickerCard extends StatelessWidget {
  const _AlarmTimePickerCard({
    required this.itemExtent,
    required this.borderColor,
    required this.hourCtrl,
    required this.minuteCtrl,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final double itemExtent;
  final Color borderColor;
  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minuteCtrl;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    final highlight = Colors.lightBlueAccent.withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.35),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: itemExtent * 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _WheelColumn(
                      controller: hourCtrl,
                      itemExtent: itemExtent,
                      itemCount: 24,
                      labelBuilder: (i) => '$i',
                      onSelected: onHourChanged,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      ':',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: borderColor,
                          ),
                    ),
                  ),
                  Expanded(
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
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    height: itemExtent,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.lightBlue.shade100.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        },
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
                      color: Colors.black87,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SideActionButtons extends StatelessWidget {
  const _SideActionButtons({
    required this.onMemo,
    required this.onCheck,
    required this.onShare,
    required this.onMic,
    required this.onAudio,
  });

  final VoidCallback onMemo;
  final VoidCallback onCheck;
  final VoidCallback onShare;
  final VoidCallback onMic;
  final VoidCallback onAudio;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundIconButton(
          color: const Color(0xFFF28C38),
          icon: Icons.edit_outlined,
          size: size,
          onPressed: onMemo,
        ),
        const SizedBox(height: 8),
        _RoundIconButton(
          color: const Color(0xFF5CB85C),
          icon: Icons.check,
          size: size,
          onPressed: onCheck,
        ),
        const SizedBox(height: 8),
        _RoundIconButton(
          color: const Color(0xFF5DADE2),
          icon: Icons.share_outlined,
          size: size,
          onPressed: onShare,
        ),
        const SizedBox(height: 8),
        _RoundIconButton(
          color: const Color(0xFF9B59B6),
          icon: Icons.mic_none_rounded,
          size: size,
          onPressed: onMic,
          badgeLabel: 'SET',
        ),
        const SizedBox(height: 8),
        _RoundIconButton(
          color: const Color(0xFFE56B8C),
          icon: Icons.headphones_outlined,
          size: size,
          onPressed: onAudio,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.color,
    required this.icon,
    required this.size,
    required this.onPressed,
    this.badgeLabel,
  });

  final Color color;
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
          ),
        ),
        if (badgeLabel != null)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                badgeLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
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
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        '広告枠（プレースホルダー）',
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Colors.grey.shade700),
      ),
    );
  }
}
