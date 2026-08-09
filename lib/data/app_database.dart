import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'cycle_compass.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            date_of_birth TEXT NOT NULL,
            avatar_path TEXT,
            last_period_start TEXT NOT NULL,
            cycle_length INTEGER NOT NULL,
            period_length INTEGER NOT NULL
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

  Future<List<DateTime>> readPeriodStarts() async {
    final rows = await _database.query(
      'period_entries',
      columns: ['start_date'],
      orderBy: 'start_date DESC',
    );
    return rows
        .map((row) => DateTime.parse(row['start_date']! as String))
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
