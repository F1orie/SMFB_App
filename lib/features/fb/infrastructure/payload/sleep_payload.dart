class SleepPayload {
  const SleepPayload({
    required this.payloadVersion,
    required this.sleepDataSource,
    required this.sessions,
    required this.epochs,
    required this.notes,
    this.targetSessionId,
  });

  static const currentVersion = '1.0';

  final String payloadVersion;
  final String sleepDataSource;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> epochs;
  final List<Map<String, dynamic>> notes;
  final String? targetSessionId;

  Map<String, dynamic> toSleepDataJson() => {
    'target_session_id': targetSessionId,
    'sessions': sessions,
    'epochs': epochs,
    'notes': notes,
  };
}
