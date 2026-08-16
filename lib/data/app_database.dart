import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';
import '../models/period_entry.dart';

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'cycle_compass.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            date_of_birth TEXT NOT NULL,
            avatar_path TEXT,
            last_period_start TEXT NOT NULL,
            cycle_length INTEGER NOT NULL,
            period_length INTEGER NOT NULL,
            is_pregnant INTEGER NOT NULL DEFAULT 0,
            pregnancy_started_on TEXT,
            due_date TEXT,
            next_period_due_date TEXT,
            postpartum_started_on TEXT,
            postpartum_ended_on TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE period_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_date TEXT NOT NULL UNIQUE,
            end_date TEXT,
            source TEXT NOT NULL DEFAULT 'user'
          )
        ''');
        await db.execute('''
          CREATE TABLE daily_logs (
            log_date TEXT PRIMARY KEY,
            flow INTEGER,
            pain INTEGER,
            mood INTEGER,
            energy INTEGER,
            note TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN is_pregnant INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE profile ADD COLUMN pregnancy_started_on TEXT',
          );
          await db.execute('ALTER TABLE profile ADD COLUMN due_date TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN next_period_due_date TEXT',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN postpartum_started_on TEXT',
          );
          await db.execute(
            'ALTER TABLE profile ADD COLUMN postpartum_ended_on TEXT',
          );
        }
      },
    );
    return AppDatabase._(database);
  }

  Future<UserProfile?> readProfile() async {
    final rows = await _database.query(
      'profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _database.insert(
      'profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addPeriodStart(DateTime date) async {
    await _database.insert('period_entries', {
      'start_date': _dateOnly(date),
      'source': 'user',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updatePeriodStart(DateTime oldDate, DateTime newDate) async {
    await _database.transaction((transaction) async {
      final existing = await transaction.query(
        'period_entries',
        columns: ['end_date'],
        where: 'start_date = ?',
        whereArgs: [_dateOnly(oldDate)],
        limit: 1,
      );
      final oldEnd = existing.isEmpty
          ? null
          : existing.first['end_date'] as String?;
      final parsedEnd = oldEnd == null ? null : DateTime.parse(oldEnd);
      await transaction.delete(
        'period_entries',
        where: 'start_date = ?',
        whereArgs: [_dateOnly(oldDate)],
      );
      await transaction.insert('period_entries', {
        'start_date': _dateOnly(newDate),
        'end_date': parsedEnd != null && !parsedEnd.isBefore(newDate)
            ? _dateOnly(parsedEnd)
            : null,
        'source': 'user',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> updatePeriodEnd(DateTime startDate, DateTime? endDate) async {
    await _database.update(
      'period_entries',
      {'end_date': endDate == null ? null : _dateOnly(endDate)},
      where: 'start_date = ?',
      whereArgs: [_dateOnly(startDate)],
    );
  }

  Future<void> deletePeriodStart(DateTime date) async {
    await _database.delete(
      'period_entries',
      where: 'start_date = ?',
      whereArgs: [_dateOnly(date)],
    );
  }

  Future<List<PeriodEntry>> readPeriodEntries() async {
    final rows = await _database.query(
      'period_entries',
      columns: ['start_date', 'end_date'],
      orderBy: 'start_date DESC',
    );
    return rows
        .map(
          (row) => PeriodEntry(
            startDate: DateTime.parse(row['start_date']! as String),
            endDate: row['end_date'] == null
                ? null
                : DateTime.parse(row['end_date']! as String),
          ),
        )
        .toList(growable: false);
  }

  Future<void> clearAllData() async {
    await _database.transaction((transaction) async {
      await transaction.delete('daily_logs');
      await transaction.delete('period_entries');
      await transaction.delete('profile');
    });
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
