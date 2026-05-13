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

  Map<String, dynamic> toJson() => {
        'id': id,
        'startAtEpochMs': startAtEpochMs,
        'endAtEpochMs': endAtEpochMs,
        'alarmTimeEpochMs': alarmTimeEpochMs,
        'status': status.name,
        'algoVersion': algoVersion,
        'samplingPeriodSec': samplingPeriodSec,
        'tzOffsetMin': tzOffsetMin,
        'appVersion': appVersion,
        'syncState': syncState,
      };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
        id: json['id'] as String,
        startAtEpochMs: json['startAtEpochMs'] as int,
        endAtEpochMs: json['endAtEpochMs'] as int?,
        alarmTimeEpochMs: json['alarmTimeEpochMs'] as int?,
        status: SleepSessionStatus.values.byName(json['status'] as String),
        algoVersion: json['algoVersion'] as String,
        samplingPeriodSec: json['samplingPeriodSec'] as int,
        tzOffsetMin: json['tzOffsetMin'] as int,
        appVersion: json['appVersion'] as String,
        syncState: json['syncState'] as String,
      );
}
