import 'dart:io';

import 'package:cycle_compass/data/app_database.dart';
import 'package:cycle_compass/models/intercourse_entry.dart';
import 'package:cycle_compass/models/life_stage_entry.dart';
import 'package:cycle_compass/models/ovulation_test_entry.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The tables exactly as schema version 7 created them, so the upgrade path is
/// exercised against a database a released build could really have produced.
const _schemaV7 = [
  '''
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
  ''',
  '''
  CREATE TABLE period_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_date TEXT NOT NULL UNIQUE,
    end_date TEXT,
    source TEXT NOT NULL DEFAULT 'user'
  )
  ''',
  '''
  CREATE TABLE daily_logs (
    log_date TEXT PRIMARY KEY,
    flow INTEGER,
    pain INTEGER,
    mood INTEGER,
    energy INTEGER,
    note TEXT,
    intercourse_protection TEXT
  )
  ''',
  '''
  CREATE TABLE life_stage_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stage_type TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL
  )
  ''',
];

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrading v7 to v8 keeps the data and adds the new columns', () async {
    final directory = Directory.systemTemp.createTempSync('cycle_compass_v7');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = p.join(directory.path, 'cycle_compass.db');

    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          for (final statement in _schemaV7) {
            await db.execute(statement);
          }
        },
      ),
    );
    await legacy.insert('profile', {
      'id': 1,
      'name': 'Nadia Rahman',
      'date_of_birth': '1997-04-16',
      'last_period_start': '2026-08-01',
      'cycle_length': 28,
      'period_length': 5,
      'theme_mode': 'dark',
    });
    await legacy.insert('period_entries', {
      'start_date': '2026-08-01',
      'end_date': '2026-08-05',
      'source': 'user',
    });
    await legacy.insert('daily_logs', {
      'log_date': '2026-08-03',
      'intercourse_protection': 'protected',
    });
    await legacy.insert('life_stage_entries', {
      'stage_type': 'pregnancy',
      'start_date': '2023-01-10',
      'end_date': '2023-10-12',
    });
    await legacy.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: appDatabaseVersion,
        onCreate: (db, version) => createAppSchema(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            upgradeAppSchema(db, oldVersion),
      ),
    );
    addTearDown(upgraded.close);
    final database = AppDatabase.of(upgraded);

    final profile = await database.readProfile();
    expect(profile!.name, 'Nadia Rahman');
    expect(profile.themeMode, ThemeMode.dark);
    expect(profile.babyBornOn, isNull);
    expect(profile.breastfeedingStartedOn, isNull);
    expect(
      (await database.readPeriodEntries()).single.endDate,
      DateTime(2026, 8, 5),
    );
    expect(
      (await database.readIntercourseEntries()).single.protectionStatus,
      ProtectionStatus.protected,
    );
    expect((await database.readOvulationTests()), isEmpty);
    expect(
      (await database.readLifeStageEntries()).single.type,
      LifeStageType.pregnancy,
    );

    // The new columns are writable, which is what the ALTER statements exist
    // for in the first place.
    await database.saveProfile(
      profile.copyWith(
        babyBornOn: DateTime(2026, 8, 14),
        breastfeedingStartedOn: DateTime(2026, 8, 14),
      ),
    );
    await database.saveOvulationTest(
      OvulationTestEntry(
        date: DateTime(2026, 8, 3),
        result: OvulationTestResult.positive,
      ),
    );
    await database.saveLifeStageEntry(
      LifeStageEntry(
        type: LifeStageType.breastfeeding,
        startDate: DateTime(2024, 2, 1),
        endDate: DateTime(2024, 11, 30),
      ),
    );

    final reread = await database.readProfile();
    expect(reread!.babyBornOn, DateTime(2026, 8, 14));
    expect(reread.breastfeedingStartedOn, DateTime(2026, 8, 14));
    expect(
      (await database.readOvulationTests()).single.result,
      OvulationTestResult.positive,
    );
    expect(await database.readLifeStageEntries(), hasLength(2));
  });

  group('daily_logs entries share a day', () {
    late Database raw;
    late AppDatabase database;
    final date = DateTime(2026, 8, 3);

    setUp(() async {
      raw = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: appDatabaseVersion,
          onCreate: (db, version) => createAppSchema(db),
        ),
      );
      database = AppDatabase.of(raw);
    });

    tearDown(() => raw.close());

    test('removing the sex entry keeps the ovulation test', () async {
      await database.saveIntercourseEntry(
        IntercourseEntry(
          date: date,
          protectionStatus: ProtectionStatus.protected,
        ),
      );
      await database.saveOvulationTest(
        OvulationTestEntry(date: date, result: OvulationTestResult.negative),
      );

      await database.deleteIntercourseEntry(date);

      expect(await database.readIntercourseEntries(), isEmpty);
      expect(
        (await database.readOvulationTests()).single.result,
        OvulationTestResult.negative,
      );
    });

    test('removing the ovulation test keeps the sex entry', () async {
      await database.saveIntercourseEntry(
        IntercourseEntry(
          date: date,
          protectionStatus: ProtectionStatus.unprotected,
        ),
      );
      await database.saveOvulationTest(
        OvulationTestEntry(date: date, result: OvulationTestResult.positive),
      );

      await database.deleteOvulationTest(date);

      expect(await database.readOvulationTests(), isEmpty);
      expect(
        (await database.readIntercourseEntries()).single.protectionStatus,
        ProtectionStatus.unprotected,
      );
    });

    test('the row is dropped once nothing is recorded for the day', () async {
      await database.saveIntercourseEntry(
        IntercourseEntry(
          date: date,
          protectionStatus: ProtectionStatus.protected,
        ),
      );
      await database.saveOvulationTest(
        OvulationTestEntry(date: date, result: OvulationTestResult.positive),
      );

      await database.deleteIntercourseEntry(date);
      expect(await raw.query('daily_logs'), hasLength(1));

      await database.deleteOvulationTest(date);
      expect(await raw.query('daily_logs'), isEmpty);
    });
  });
}
