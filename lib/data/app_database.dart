import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/intercourse_entry.dart';
import '../models/life_stage_entry.dart';
import '../models/period_entry.dart';
import '../models/user_profile.dart';
import '../services/backup_codec.dart';

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'cycle_compass.db'),
      version: 7,
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
            postpartum_ended_on TEXT,
            notifications_enabled INTEGER NOT NULL DEFAULT 1,
            theme_mode TEXT NOT NULL DEFAULT 'system'
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
            note TEXT,
            intercourse_protection TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE life_stage_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stage_type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL
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
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE daily_logs ADD COLUMN intercourse_protection TEXT',
          );
          await db.execute('''
            CREATE TABLE life_stage_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              stage_type TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE profile ADD COLUMN notifications_enabled '
            'INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            "ALTER TABLE profile ADD COLUMN theme_mode "
            "TEXT NOT NULL DEFAULT 'system'",
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

  Future<void> saveIntercourseEntry(IntercourseEntry entry) async {
    final fields = {
      'intercourse_protection': entry.protectionStatus.storageValue,
    };
    final updated = await _database.update(
      'daily_logs',
      fields,
      where: 'log_date = ?',
      whereArgs: [_dateOnly(entry.date)],
    );
    if (updated == 0) {
      await _database.insert('daily_logs', {
        'log_date': _dateOnly(entry.date),
        ...fields,
      });
    }
  }

  Future<void> deleteIntercourseEntry(DateTime date) async {
    final storedDate = _dateOnly(date);
    await _database.update(
      'daily_logs',
      {'intercourse_protection': null},
      where: 'log_date = ?',
      whereArgs: [storedDate],
    );
    await _database.delete(
      'daily_logs',
      where:
          'log_date = ? AND flow IS NULL AND pain IS NULL AND mood IS NULL '
          'AND energy IS NULL AND note IS NULL',
      whereArgs: [storedDate],
    );
  }

  Future<List<IntercourseEntry>> readIntercourseEntries() async {
    final rows = await _database.query(
      'daily_logs',
      columns: ['log_date', 'intercourse_protection'],
      where: 'intercourse_protection IS NOT NULL',
      orderBy: 'log_date DESC',
    );
    return rows
        .map(
          (row) => IntercourseEntry(
            date: DateTime.parse(row['log_date']! as String),
            protectionStatus: protectionStatusFromStorage(
              row['intercourse_protection']! as String,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<LifeStageEntry> saveLifeStageEntry(LifeStageEntry entry) async {
    final fields = {
      'stage_type': entry.type.storageValue,
      'start_date': _dateOnly(entry.startDate),
      'end_date': _dateOnly(entry.endDate),
    };
    final id = entry.id;
    if (id == null) {
      final insertedId = await _database.insert('life_stage_entries', fields);
      return entry.copyWith(id: insertedId);
    }
    final updated = await _database.update(
      'life_stage_entries',
      fields,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Life-stage entry $id was not found.');
    return entry;
  }

  Future<void> deleteLifeStageEntry(int id) async {
    await _database.delete(
      'life_stage_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LifeStageEntry>> readLifeStageEntries() async {
    final rows = await _database.query(
      'life_stage_entries',
      orderBy: 'start_date DESC',
    );
    return rows
        .map(
          (row) => LifeStageEntry(
            id: row['id']! as int,
            type: lifeStageTypeFromStorage(row['stage_type']! as String),
            startDate: DateTime.parse(row['start_date']! as String),
            endDate: DateTime.parse(row['end_date']! as String),
          ),
        )
        .toList(growable: false);
  }

  /// Reads every row of every table for a backup file.
  Future<BackupData> exportAllData() async {
    final profileRows = await _database.query('profile', limit: 1);
    return BackupData(
      profile: profileRows.isEmpty ? null : profileRows.first,
      periodEntries: await _database.query(
        'period_entries',
        orderBy: 'start_date',
      ),
      dailyLogs: await _database.query('daily_logs', orderBy: 'log_date'),
      lifeStageEntries: await _database.query(
        'life_stage_entries',
        orderBy: 'start_date',
      ),
    );
  }

  /// Replaces every table with [data] in one transaction.
  ///
  /// Rows are validated by the backup codec before they get here, so either the
  /// whole restore lands or the transaction rolls back untouched.
  Future<void> importAllData(BackupData data) async {
    await _database.transaction((transaction) async {
      await transaction.delete('life_stage_entries');
      await transaction.delete('daily_logs');
      await transaction.delete('period_entries');
      await transaction.delete('profile');
      final profile = data.profile;
      if (profile != null) {
        await transaction.insert('profile', {...profile, 'id': 1});
      }
      for (final row in data.periodEntries) {
        await transaction.insert('period_entries', row);
      }
      for (final row in data.dailyLogs) {
        await transaction.insert('daily_logs', row);
      }
      for (final row in data.lifeStageEntries) {
        await transaction.insert('life_stage_entries', row);
      }
    });
  }

  Future<void> clearAllData() async {
    await _database.transaction((transaction) async {
      await transaction.delete('life_stage_entries');
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
