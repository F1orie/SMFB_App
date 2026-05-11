import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';

class SleepRepository {
  SleepRepository._();

  static final SleepRepository instance = SleepRepository._();

  final List<SleepSession> _sessions = [];
  final List<SleepEpoch> _epochs = [];
  final List<SleepNote> _notes = [];

  Future<void> saveSession(SleepSession session) async {
    _sessions.removeWhere((item) => item.id == session.id);
    _sessions.add(session);
  }

  Future<void> saveEpochs(List<SleepEpoch> epochs) async {
    _epochs.addAll(epochs);
  }

  Future<void> saveNote(SleepNote note) async {
    _notes.add(note);
  }

  Future<List<SleepSession>> getSessions() async {
    return List.unmodifiable(_sessions);
  }

  Future<List<SleepEpoch>> getEpochsBySessionId(String sessionId) async {
    return List.unmodifiable(
      _epochs.where((epoch) => epoch.sessionId == sessionId),
    );
  }

  Future<List<SleepNote>> getNotesBySessionId(String sessionId) async {
    return List.unmodifiable(
      _notes.where((note) => note.sessionId == sessionId),
    );
  }

  Future<void> clearAll() async {
    _sessions.clear();
    _epochs.clear();
    _notes.clear();
  }

  // 同期アクセサ（インメモリなので非同期ラップ不要）
  List<SleepSession> get allSessions => List.unmodifiable(_sessions);

  List<SleepEpoch> epochsForSession(String sessionId) => List.unmodifiable(
    _epochs.where((e) => e.sessionId == sessionId),
  );
}
