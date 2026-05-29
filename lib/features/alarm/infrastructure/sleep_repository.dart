import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';
import 'sleep_sqlite_repository.dart';

const _keySessions = 'sleep_sessions';
const _keyEpochs = 'sleep_epochs';
const _keyNotes = 'sleep_notes';
const _sourceSqlite = 'sqlite';
const _sourceFallback = 'existing_repository_fallback';

class SleepRepository {
  SleepRepository._();

  static final SleepRepository instance = SleepRepository._();

  final SleepSqliteRepository _sqliteRepository = SleepSqliteRepository();

  final List<SleepSession> _sessions = [];
  final List<SleepEpoch> _epochs = [];
  final List<SleepNote> _notes = [];
  String _dataSource = _sourceFallback;

  // ── 初期化 ──────────────────────────────────────────────────

  Future<void> init() async {
    if (!kIsWeb) {
      try {
        await _sqliteRepository.init();
        await _loadFromSqlite();
        if (_sessions.isNotEmpty || _epochs.isNotEmpty || _notes.isNotEmpty) {
          _dataSource = _sourceSqlite;
          return;
        }
      } catch (error, stackTrace) {
        debugPrint('SQLite sleep data load failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _dataSource = _sourceFallback;
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

    if (!kIsWeb &&
        (_sessions.isNotEmpty || _epochs.isNotEmpty || _notes.isNotEmpty)) {
      await _trySqliteWrite(_persistAllToSqlite);
    }
  }

  // ── 書き込み ────────────────────────────────────────────────

  Future<void> saveSession(SleepSession session) async {
    _sessions.removeWhere((item) => item.id == session.id);
    _sessions.add(session);
    if (!kIsWeb) {
      await _trySqliteWrite(() => _sqliteRepository.saveSession(session));
    }
    await _persistSessions();
  }

  Future<void> saveEpochs(List<SleepEpoch> epochs) async {
    _epochs.addAll(epochs);
    if (!kIsWeb) {
      await _trySqliteWrite(() => _sqliteRepository.saveEpochs(epochs));
    }
    await _persistEpochs();
  }

  Future<void> saveNote(SleepNote note) async {
    _notes.removeWhere((item) => item.sessionId == note.sessionId);
    _notes.add(note);
    if (!kIsWeb) {
      await _trySqliteWrite(() => _sqliteRepository.saveNote(note));
    }
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
    if (!kIsWeb) {
      await _trySqliteWrite(_sqliteRepository.clearAll);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessions);
    await prefs.remove(_keyEpochs);
    await prefs.remove(_keyNotes);
  }

  // ── 同期アクセサ ────────────────────────────────────────────

  List<SleepSession> get allSessions => List.unmodifiable(_sessions);

  List<SleepEpoch> epochsForSession(String sessionId) =>
      List.unmodifiable(_epochs.where((e) => e.sessionId == sessionId));

  List<SleepNote> notesForSession(String sessionId) =>
      List.unmodifiable(_notes.where((n) => n.sessionId == sessionId));

  String get dataSource => _dataSource;

  Future<void> removeSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _epochs.removeWhere((e) => e.sessionId == sessionId);
    _notes.removeWhere((n) => n.sessionId == sessionId);
    if (!kIsWeb) {
      await _trySqliteWrite(() => _sqliteRepository.removeSession(sessionId));
    }
    await _persistSessions();
    await _persistEpochs();
    await _persistNotes();
  }

  Future<void> removeEpochsForSession(String sessionId) async {
    _epochs.removeWhere((e) => e.sessionId == sessionId);
    if (!kIsWeb) {
      await _trySqliteWrite(
        () => _sqliteRepository.removeEpochsForSession(sessionId),
      );
    }
    await _persistEpochs();
  }

  Future<void> removeNotesForSession(String sessionId) async {
    _notes.removeWhere((n) => n.sessionId == sessionId);
    if (!kIsWeb) {
      await _trySqliteWrite(
        () => _sqliteRepository.removeNotesForSession(sessionId),
      );
    }
    await _persistNotes();
  }

  // ── 内部永続化 ──────────────────────────────────────────────

  Future<void> _loadFromSqlite() async {
    _sessions
      ..clear()
      ..addAll(await _sqliteRepository.getSessions());
    _epochs
      ..clear()
      ..addAll(await _sqliteRepository.getEpochs());
    _notes
      ..clear()
      ..addAll(await _sqliteRepository.getNotes());
  }

  Future<void> _persistAllToSqlite() async {
    await _sqliteRepository.clearAll();
    for (final session in _sessions) {
      await _sqliteRepository.saveSession(session);
    }
    await _sqliteRepository.saveEpochs(_epochs);
    for (final note in _notes) {
      await _sqliteRepository.saveNote(note);
    }
  }

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

  Future<void> _trySqliteWrite(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      debugPrint('SQLite sleep data write failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
