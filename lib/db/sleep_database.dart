import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SleepDatabase {
  SleepDatabase._();

  static final SleepDatabase instance = SleepDatabase._();

  static const databaseName = 'sleep_data.db';
  static const databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, databaseName);

    _database = await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE sleep_sessions (
  id TEXT PRIMARY KEY,
  startAtEpochMs INTEGER NOT NULL,
  endAtEpochMs INTEGER,
  alarmTimeEpochMs INTEGER,
  status TEXT NOT NULL,
  algoVersion TEXT NOT NULL,
  samplingPeriodSec INTEGER NOT NULL,
  tzOffsetMin INTEGER NOT NULL,
  appVersion TEXT NOT NULL,
  syncState TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE sleep_epochs (
  sessionId TEXT NOT NULL,
  tEpochMs INTEGER NOT NULL,
  activityCount REAL NOT NULL,
  scoreDepth REAL NOT NULL,
  PRIMARY KEY (sessionId, tEpochMs),
  FOREIGN KEY (sessionId) REFERENCES sleep_sessions(id) ON DELETE CASCADE
)
''');
        await db.execute('''
CREATE TABLE sleep_notes (
  sessionId TEXT PRIMARY KEY,
  createdAtEpochMs INTEGER NOT NULL,
  memo TEXT NOT NULL,
  hadAlcohol INTEGER NOT NULL,
  hadCaffeine INTEGER NOT NULL,
  didExercise INTEGER NOT NULL,
  FOREIGN KEY (sessionId) REFERENCES sleep_sessions(id) ON DELETE CASCADE
)
''');
        await db.execute(
          'CREATE INDEX idx_sleep_epochs_session_time '
          'ON sleep_epochs(sessionId, tEpochMs)',
        );
      },
    );

    return _database!;
  }
}
