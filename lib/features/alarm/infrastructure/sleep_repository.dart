import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';

/// インメモリの睡眠データストア（デモ用シングルトン）。
class SleepRepository {
  SleepRepository._();

  static final SleepRepository instance = SleepRepository._();

  final List<SleepSession> _sessions = [];
  final List<SleepEpoch> _epochs = [];
  final List<SleepNote> _notes = [];

  Future<void> saveSession(SleepSession session) async {
    _sessions.add(session);
  }

  Future<void> saveEpochs(List<SleepEpoch> epochs) async {
    _epochs.addAll(epochs);
  }

  Future<void> saveNote(SleepNote note) async {
    _notes.add(note);
  }

  List<SleepSession> get allSessions => List.unmodifiable(_sessions);
  List<SleepEpoch> get allEpochs => List.unmodifiable(_epochs);
  List<SleepNote> get allNotes => List.unmodifiable(_notes);
}
