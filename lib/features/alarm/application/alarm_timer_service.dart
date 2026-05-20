import 'dart:async';

class AlarmTimerService {
  AlarmTimerService();

  Timer? _timer;
  DateTime? _scheduledAlarmTime;

  DateTime? get scheduledAlarmTime => _scheduledAlarmTime;

  void setAlarm({
    required DateTime alarmTime,
    required void Function() onRing,
  }) {
    _timer?.cancel();

    final DateTime now = DateTime.now();
    DateTime targetTime = alarmTime;

    if (!targetTime.isAfter(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    _scheduledAlarmTime = targetTime;

    final Duration durationUntilAlarm = targetTime.difference(now);

    _timer = Timer(
      durationUntilAlarm,
      onRing,
    );
  }

  void snooze({
    required void Function() onRing,
  }) {
    _timer?.cancel();

    final DateTime snoozeTime = DateTime.now().add(
      const Duration(minutes: 5),
    );

    _scheduledAlarmTime = snoozeTime;

    _timer = Timer(
      const Duration(minutes: 5),
      onRing,
    );
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _scheduledAlarmTime = null;
  }

  void dispose() {
    cancel();
  }
}