import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';

const _keySessions = 'sleep_sessions';
const _keyEpochs = 'sleep_epochs';
const _keyNotes = 'sleep_notes';

class SleepRepository {
  SleepRepository._();

  static final SleepRepository instance = SleepRepository._();

  final List<SleepSession> _sessions = [];
  final List<SleepEpoch> _epochs = [];
  final List<SleepNote> _notes = [];

  // ── 初期化 ──────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final sessionsJson = prefs.getStringList(_keySessions) ?? [];
    _sessions
      ..clear()
      ..addAll(
        sessionsJson.map(
          (s) => SleepSession.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );

    final epochsJson = prefs.getStringList(_keyEpochs) ?? [];
    _epochs
      ..clear()
      ..addAll(
        epochsJson.map(
          (s) => SleepEpoch.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );

    final notesJson = prefs.getStringList(_keyNotes) ?? [];
    _notes
      ..clear()
      ..addAll(
        notesJson.map(
          (s) => SleepNote.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
  }

  // ── 書き込み ────────────────────────────────────────────────

  Future<void> saveSession(SleepSession session) async {
    _sessions.removeWhere((item) => item.id == session.id);
    _sessions.add(session);
    await _persistSessions();
  }

  Future<void> saveEpochs(List<SleepEpoch> epochs) async {
    _epochs.addAll(epochs);
    await _persistEpochs();
  }

  Future<void> saveNote(SleepNote note) async {
    _notes.add(note);
    await _persistNotes();
  }

  // ── 非同期読み込み ──────────────────────────────────────────

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

  // ── クリア ──────────────────────────────────────────────────

  Future<void> clearAll() async {
    _sessions.clear();
    _epochs.clear();
    _notes.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessions);
    await prefs.remove(_keyEpochs);
    await prefs.remove(_keyNotes);
  }

  // ── 同期アクセサ ────────────────────────────────────────────

  List<SleepSession> get allSessions => List.unmodifiable(_sessions);

  List<SleepEpoch> epochsForSession(String sessionId) => List.unmodifiable(
        _epochs.where((e) => e.sessionId == sessionId),
      );

  List<SleepNote> notesForSession(String sessionId) => List.unmodifiable(
        _notes.where((n) => n.sessionId == sessionId),
      );

  Future<void> removeEpochsForSession(String sessionId) async {
    _epochs.removeWhere((e) => e.sessionId == sessionId);
    await _persistEpochs();
  }

  Future<void> removeNotesForSession(String sessionId) async {
    _notes.removeWhere((n) => n.sessionId == sessionId);
    await _persistNotes();
  }

  // ── 内部永続化 ──────────────────────────────────────────────

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keySessions,
      _sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<void> _persistEpochs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyEpochs,
      _epochs.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyNotes,
      _notes.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }
}
