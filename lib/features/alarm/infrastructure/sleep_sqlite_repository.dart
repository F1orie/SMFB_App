import 'package:sqflite/sqflite.dart';

import 'package:smf_app/db/sleep_database.dart';

import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';

class SleepSqliteRepository {
  SleepSqliteRepository({SleepDatabase? database})
      : _database = database ?? SleepDatabase.instance;

  final SleepDatabase _database;

  Future<void> init() async {
    await _database.database;
  }

  Future<List<SleepSession>> getSessions() async {
    final db = await _database.database;
    final rows = await db.query(
      'sleep_sessions',
      orderBy: 'startAtEpochMs ASC',
    );
    return rows
        .map((row) => SleepSession.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<SleepEpoch>> getEpochs() async {
    final db = await _database.database;
    final rows = await db.query(
      'sleep_epochs',
      orderBy: 'sessionId ASC, tEpochMs ASC',
    );
    return rows
        .map((row) => SleepEpoch.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<SleepNote>> getNotes() async {
    final db = await _database.database;
    final rows = await db.query(
      'sleep_notes',
      orderBy: 'createdAtEpochMs ASC',
    );
    return rows.map(_noteFromRow).toList(growable: false);
  }

  Future<void> saveSession(SleepSession session) async {
    final db = await _database.database;
    await db.insert(
      'sleep_sessions',
      Map<String, Object?>.from(session.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveEpochs(List<SleepEpoch> epochs) async {
    if (epochs.isEmpty) return;

    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final epoch in epochs) {
        batch.insert(
          'sleep_epochs',
          Map<String, Object?>.from(epoch.toJson()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveNote(SleepNote note) async {
    final db = await _database.database;
    await db.insert(
      'sleep_notes',
      _noteToRow(note),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeSession(String sessionId) async {
    final db = await _database.database;
    await db.delete(
      'sleep_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> removeEpochsForSession(String sessionId) async {
    final db = await _database.database;
    await db.delete(
      'sleep_epochs',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> removeNotesForSession(String sessionId) async {
    final db = await _database.database;
    await db.delete(
      'sleep_notes',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearAll() async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('sleep_notes');
      await txn.delete('sleep_epochs');
      await txn.delete('sleep_sessions');
    });
  }

  Map<String, Object?> _noteToRow(SleepNote note) => {
        'sessionId': note.sessionId,
        'createdAtEpochMs': note.createdAtEpochMs,
        'memo': note.memo,
        'hadAlcohol': note.hadAlcohol ? 1 : 0,
        'hadCaffeine': note.hadCaffeine ? 1 : 0,
        'didExercise': note.didExercise ? 1 : 0,
      };

  SleepNote _noteFromRow(Map<String, Object?> row) => SleepNote(
        sessionId: row['sessionId'] as String,
        createdAtEpochMs: row['createdAtEpochMs'] as int,
        memo: row['memo'] as String,
        hadAlcohol: (row['hadAlcohol'] as int) == 1,
        hadCaffeine: (row['hadCaffeine'] as int) == 1,
        didExercise: (row['didExercise'] as int) == 1,
      );
}
