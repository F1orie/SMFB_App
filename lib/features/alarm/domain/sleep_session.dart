enum SleepSessionStatus { recording, finished }

class SleepSession {
  const SleepSession({
    required this.id,
    required this.startAtEpochMs,
    this.endAtEpochMs,
    this.alarmTimeEpochMs,
    required this.status,
    required this.algoVersion,
    required this.samplingPeriodSec,
    required this.tzOffsetMin,
    required this.appVersion,
    required this.syncState,
  });

  final String id;
  final int startAtEpochMs;
  final int? endAtEpochMs;
  final int? alarmTimeEpochMs;
  final SleepSessionStatus status;
  final String algoVersion;
  final int samplingPeriodSec;
  final int tzOffsetMin;
  final String appVersion;
  final String syncState;
}
