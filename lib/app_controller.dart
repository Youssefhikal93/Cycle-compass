import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'data/app_database.dart';
import 'services/backup_codec.dart';
import 'services/clock.dart';
import 'models/intercourse_entry.dart';
import 'models/life_stage_entry.dart';
import 'models/period_entry.dart';
import 'models/user_profile.dart';
import 'services/cycle_notification_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._database, {CycleNotificationService? notificationService})
    : _notificationService = notificationService,
      _notificationPermissionGranted = notificationService == null;

  AppController.inMemory()
    : _database = null,
      _notificationService = null,
      _notificationPermissionGranted = true;

  final AppDatabase? _database;
  final CycleNotificationService? _notificationService;
  bool _notificationPermissionGranted;
  UserProfile? _profile;
  List<PeriodEntry> _periodEntries = const [];
  List<IntercourseEntry> _intercourseEntries = const [];
  List<LifeStageEntry> _lifeStageEntries = const [];

  UserProfile? get profile => _profile;
  List<PeriodEntry> get periodEntries => List.unmodifiable(_periodEntries);
  List<IntercourseEntry> get intercourseEntries =>
      List.unmodifiable(_intercourseEntries);
  List<LifeStageEntry> get lifeStageEntries =>
      List.unmodifiable(_lifeStageEntries);
  List<DateTime> get periodStarts =>
      _periodEntries.map((entry) => entry.startDate).toList(growable: false);
  bool get isOnboarded => _profile != null;
  ThemeMode get themeMode => _profile?.themeMode ?? ThemeMode.system;
  bool get notificationsAllowed => _notificationPermissionGranted;
  bool get needsNotificationPermission =>
      _profile?.notificationsEnabled == true && !_notificationPermissionGranted;

  Future<void> load() async {
    final database = _database;
    if (database != null) {
      _profile = await database.readProfile();
      _periodEntries = await database.readPeriodEntries();
      _intercourseEntries = await database.readIntercourseEntries();
      _lifeStageEntries = await database.readLifeStageEntries();
    }
    _notificationPermissionGranted =
        await _notificationService?.notificationsAllowed() ?? true;
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final normalizedProfile = profile.copyWith(
      lastPeriodStart: _day(profile.lastPeriodStart),
    );
    final database = _database;
    if (database != null) {
      await database.saveProfile(normalizedProfile);
      await database.addPeriodStart(normalizedProfile.lastPeriodStart);
    }
    _profile = normalizedProfile;
    _periodEntries = database == null
        ? [PeriodEntry(startDate: normalizedProfile.lastPeriodStart)]
        : await database.readPeriodEntries();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _database?.saveProfile(profile);
    _profile = profile;
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> logPeriodStart(DateTime date) async {
    final current = _profile;
    if (current == null) return;
    final normalized = DateTime(date.year, date.month, date.day);
    final pregnancyDueDate = current.dueDate;
    if (current.isPregnant && pregnancyDueDate == null) {
      throw StateError('Pregnancy mode requires an expected due date.');
    }
    if (current.isPregnant &&
        pregnancyDueDate != null &&
        normalized.isBefore(pregnancyDueDate)) {
      throw StateError(
        'Period logging stays paused until the expected due date.',
      );
    }
    final resumesAfterPregnancy =
        current.isPregnant &&
        pregnancyDueDate != null &&
        !normalized.isBefore(pregnancyDueDate);
    final trackingProfile = resumesAfterPregnancy
        ? current.copyWith(
            isPregnant: false,
            pregnancyStartedOn: null,
            dueDate: null,
            postpartumStartedOn: pregnancyDueDate,
            postpartumEndedOn: normalized,
          )
        : current;
    await _database?.addPeriodStart(normalized);
    _periodEntries = _database == null
        ? [
            PeriodEntry(startDate: normalized),
            ..._periodEntries.where((entry) => entry.startDate != normalized),
          ]
        : await _database.readPeriodEntries();
    await _syncLatestPeriod(trackingProfile);
    await _syncNotifications();
    if (resumesAfterPregnancy) await _announceCurrentMode();
    notifyListeners();
  }

  Future<void> updatePeriodStart(DateTime oldDate, DateTime newDate) async {
    final current = _profile;
    if (current == null) return;
    final oldDay = _day(oldDate);
    final newDay = _day(newDate);
    if (oldDay != newDay &&
        _periodEntries.any((entry) => entry.startDate == newDay)) {
      throw ArgumentError(
        'Another period already starts on that date. Delete it first or pick a different day.',
      );
    }
    final changesFirstPostpartumPeriod =
        current.postpartumEndedOn != null &&
        _day(current.postpartumEndedOn!) == oldDay;
    final postpartumStart = current.postpartumStartedOn;
    if (changesFirstPostpartumPeriod &&
        postpartumStart != null &&
        newDay.isBefore(_day(postpartumStart))) {
      throw ArgumentError(
        'The first postpartum period cannot be before postpartum started.',
      );
    }
    await _database?.updatePeriodStart(oldDay, newDay);
    _periodEntries = _database == null
        ? _periodEntries.map((entry) {
            if (entry.startDate != oldDay) return entry;
            final end = entry.endDate;
            return PeriodEntry(
              startDate: newDay,
              endDate: end != null && !end.isBefore(newDay) ? end : null,
            );
          }).toList()
        : await _database.readPeriodEntries();
    final syncedProfile = changesFirstPostpartumPeriod
        ? current.copyWith(postpartumEndedOn: newDay)
        : current;
    await _syncLatestPeriod(syncedProfile);
    await _syncNotifications();
    notifyListeners();
  }

  Future<bool> deletePeriodStart(DateTime date) async {
    final current = _profile;
    if (current == null || _periodEntries.length <= 1) return false;
    final day = _day(date);
    final reopensPostpartum =
        current.postpartumStartedOn != null &&
        current.postpartumEndedOn != null &&
        _day(current.postpartumEndedOn!) == day;
    await _database?.deletePeriodStart(day);
    _periodEntries = _database == null
        ? _periodEntries.where((entry) => entry.startDate != day).toList()
        : await _database.readPeriodEntries();
    final syncedProfile = reopensPostpartum
        ? current.copyWith(
            isPregnant: true,
            dueDate: current.postpartumStartedOn,
            postpartumEndedOn: null,
          )
        : current;
    await _syncLatestPeriod(syncedProfile);
    await _syncNotifications();
    if (reopensPostpartum) await _announceCurrentMode();
    notifyListeners();
    return true;
  }

  Future<void> updatePeriodEnd(DateTime startDate, DateTime? endDate) async {
    final start = _day(startDate);
    final end = endDate == null ? null : _day(endDate);
    if (end != null && end.isBefore(start)) {
      throw ArgumentError('The last period day cannot be before the start.');
    }
    await _database?.updatePeriodEnd(start, end);
    _periodEntries = _database == null
        ? _periodEntries
              .map(
                (entry) => entry.startDate == start
                    ? PeriodEntry(startDate: start, endDate: end)
                    : entry,
              )
              .toList()
        : await _database.readPeriodEntries();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setPregnancyMode({
    required bool enabled,
    DateTime? dueDate,
  }) async {
    final current = _profile;
    if (current == null) return;
    if (enabled && dueDate == null) {
      throw ArgumentError(
        'An expected due date is required to enable pregnancy mode.',
      );
    }
    final updated = current.copyWith(
      isPregnant: enabled,
      pregnancyStartedOn: enabled
          ? current.pregnancyStartedOn ?? _day(appNow())
          : null,
      dueDate: enabled && dueDate != null ? _day(dueDate) : null,
      postpartumStartedOn: enabled && dueDate != null ? _day(dueDate) : null,
      postpartumEndedOn: null,
    );
    final modeChanged = _trackingModeChanged(current, updated);
    await _database?.saveProfile(updated);
    _profile = updated;
    await _syncNotifications();
    if (modeChanged) await _announceCurrentMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final current = _profile;
    if (current == null) return;
    final updated = current.copyWith(themeMode: themeMode);
    await _database?.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  Future<bool> enableNotifications() async {
    final current = _profile;
    if (current == null) return false;
    final allowed = await _notificationService?.requestPermission() ?? true;
    _notificationPermissionGranted = allowed;
    final updated = current.copyWith(notificationsEnabled: allowed);
    await _database?.saveProfile(updated);
    _profile = updated;
    await _syncNotifications();
    notifyListeners();
    return allowed;
  }

  Future<void> disableNotifications() async {
    final current = _profile;
    if (current == null) return;
    final updated = current.copyWith(notificationsEnabled: false);
    await _database?.saveProfile(updated);
    _profile = updated;
    await _syncNotifications();
    notifyListeners();
  }

  IntercourseEntry? intercourseEntryOn(DateTime date) {
    final normalizedDate = _day(date);
    for (final entry in _intercourseEntries) {
      if (entry.date == normalizedDate) return entry;
    }
    return null;
  }

  Future<void> saveIntercourseEntry(
    DateTime date,
    ProtectionStatus protectionStatus,
  ) async {
    final normalizedDate = _day(date);
    if (normalizedDate.isAfter(_day(appNow()))) {
      throw ArgumentError('Intercourse cannot be recorded in the future.');
    }
    final entry = IntercourseEntry(
      date: normalizedDate,
      protectionStatus: protectionStatus,
    );
    await _database?.saveIntercourseEntry(entry);
    _intercourseEntries = [
      entry,
      ..._intercourseEntries.where(
        (existing) => existing.date != normalizedDate,
      ),
    ];
    notifyListeners();
  }

  Future<void> deleteIntercourseEntry(DateTime date) async {
    final normalizedDate = _day(date);
    await _database?.deleteIntercourseEntry(normalizedDate);
    _intercourseEntries = _intercourseEntries
        .where((entry) => entry.date != normalizedDate)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> saveLifeStageEntry(LifeStageEntry entry) async {
    final normalizedEntry = _normalizedLifeStageEntry(entry);
    _validateLifeStageEntry(normalizedEntry);
    final database = _database;
    final savedEntry = database == null
        ? normalizedEntry.copyWith(id: normalizedEntry.id ?? _nextLifeStageId())
        : await database.saveLifeStageEntry(normalizedEntry);
    _lifeStageEntries =
        [
          savedEntry,
          ..._lifeStageEntries.where(
            (existing) => existing.id != savedEntry.id,
          ),
        ]..sort(
          (leftEntry, rightEntry) =>
              rightEntry.startDate.compareTo(leftEntry.startDate),
        );
    notifyListeners();
  }

  Future<void> deleteLifeStageEntry(LifeStageEntry entry) async {
    final id = entry.id;
    if (id == null) throw ArgumentError('Only saved history can be deleted.');
    await _database?.deleteLifeStageEntry(id);
    _lifeStageEntries = _lifeStageEntries
        .where((existing) => existing.id != id)
        .toList(growable: false);
    notifyListeners();
  }

  LifeStageEntry _normalizedLifeStageEntry(LifeStageEntry entry) =>
      LifeStageEntry(
        id: entry.id,
        type: entry.type,
        startDate: _day(entry.startDate),
        endDate: _day(entry.endDate),
      );

  void _validateLifeStageEntry(LifeStageEntry entry) {
    if (entry.endDate.isBefore(entry.startDate)) {
      throw ArgumentError('The history end date cannot be before its start.');
    }
    if (entry.endDate.isAfter(_day(appNow()))) {
      throw ArgumentError('Past history cannot end in the future.');
    }
    if (_overlapsSavedLifeStage(entry)) {
      throw ArgumentError('Pregnancy and postpartum history cannot overlap.');
    }
    if (_overlapsActiveLifeStage(entry)) {
      throw ArgumentError(
        'Past history cannot overlap current pregnancy or postpartum tracking.',
      );
    }
  }

  bool _overlapsSavedLifeStage(LifeStageEntry entry) => _lifeStageEntries.any(
    (existing) =>
        existing.id != entry.id &&
        !entry.endDate.isBefore(existing.startDate) &&
        !entry.startDate.isAfter(existing.endDate),
  );

  bool _overlapsActiveLifeStage(LifeStageEntry entry) {
    final current = _profile;
    final activeStart = current?.pregnancyStartedOn;
    return current?.isPregnant == true &&
        activeStart != null &&
        !entry.endDate.isBefore(_day(activeStart));
  }

  int _nextLifeStageId() {
    final ids = _lifeStageEntries
        .map((entry) => entry.id ?? 0)
        .toList(growable: false);
    return ids.isEmpty
        ? 1
        : ids.reduce((highestId, id) => highestId > id ? highestId : id) + 1;
  }

  Future<void> _syncLatestPeriod(UserProfile current) async {
    _periodEntries.sort((a, b) => b.startDate.compareTo(a.startDate));
    if (_periodEntries.isEmpty) return;
    final updated = current.copyWith(
      lastPeriodStart: _periodEntries.first.startDate,
    );
    await _database?.saveProfile(updated);
    _profile = updated;
  }

  /// Collects everything stored on this device for a backup file.
  Future<BackupPayload> createBackupPayload() async {
    final database = _database;
    final data = database == null
        ? BackupData(
            profile: _profile?.toMap(),
            periodEntries: _periodEntries
                .map(
                  (entry) => <String, Object?>{
                    'start_date': _dateOnly(entry.startDate),
                    'end_date': entry.endDate == null
                        ? null
                        : _dateOnly(entry.endDate!),
                    'source': 'user',
                  },
                )
                .toList(growable: false),
            dailyLogs: _intercourseEntries
                .map(
                  (entry) => <String, Object?>{
                    'log_date': _dateOnly(entry.date),
                    'intercourse_protection':
                        entry.protectionStatus.storageValue,
                  },
                )
                .toList(growable: false),
            lifeStageEntries: _lifeStageEntries
                .map(
                  (entry) => <String, Object?>{
                    'id': entry.id,
                    'stage_type': entry.type.storageValue,
                    'start_date': _dateOnly(entry.startDate),
                    'end_date': _dateOnly(entry.endDate),
                  },
                )
                .toList(growable: false),
          )
        : await database.exportAllData();
    return BackupPayload(exportedAt: appNow(), data: data);
  }

  /// Replaces all local data with [payload] and reloads the app state.
  ///
  /// The payload is already validated by [BackupCodec], so the write either
  /// lands completely or leaves the previous data in place.
  Future<void> restoreBackup(BackupPayload payload) async {
    final database = _database;
    if (database == null) {
      final profileRow = payload.data.profile;
      _profile = profileRow == null ? null : UserProfile.fromMap(profileRow);
      _periodEntries =
          payload.data.periodEntries
              .map(
                (row) => PeriodEntry(
                  startDate: DateTime.parse(row['start_date']! as String),
                  endDate: row['end_date'] == null
                      ? null
                      : DateTime.parse(row['end_date']! as String),
                ),
              )
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
      _intercourseEntries =
          payload.data.dailyLogs
              .where((row) => row['intercourse_protection'] != null)
              .map(
                (row) => IntercourseEntry(
                  date: DateTime.parse(row['log_date']! as String),
                  protectionStatus: protectionStatusFromStorage(
                    row['intercourse_protection']! as String,
                  ),
                ),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      _lifeStageEntries =
          payload.data.lifeStageEntries
              .map(
                (row) => LifeStageEntry(
                  id: row['id'] as int?,
                  type: lifeStageTypeFromStorage(row['stage_type']! as String),
                  startDate: DateTime.parse(row['start_date']! as String),
                  endDate: DateTime.parse(row['end_date']! as String),
                ),
              )
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } else {
      await database.importAllData(payload.data);
      _profile = await database.readProfile();
      _periodEntries = await database.readPeriodEntries();
      _intercourseEntries = await database.readIntercourseEntries();
      _lifeStageEntries = await database.readLifeStageEntries();
    }
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> reset() async {
    await _notificationService?.clear();
    await _database?.clearAllData();
    _profile = null;
    _periodEntries = const [];
    _intercourseEntries = const [];
    _lifeStageEntries = const [];
    notifyListeners();
  }

  Future<void> _syncNotifications() async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    final current = _profile;
    if (current == null ||
        !current.notificationsEnabled ||
        !_notificationPermissionGranted) {
      await notificationService.cancelPendingCycleNotifications();
      return;
    }
    await notificationService.reconcile(
      profile: current,
      periodStarts: periodStarts,
    );
  }

  Future<void> _announceCurrentMode() async {
    final notificationService = _notificationService;
    final current = _profile;
    if (notificationService == null ||
        current == null ||
        !current.notificationsEnabled ||
        !_notificationPermissionGranted) {
      return;
    }
    if (!current.isPregnant) {
      return notificationService.showCycleTrackingResumed();
    }
    if (current.isPostpartumOn(appNow())) {
      return notificationService.showPostpartumMode();
    }
    return notificationService.showPregnancyMode();
  }

  bool _trackingModeChanged(UserProfile before, UserProfile after) {
    final now = appNow();
    return before.isPregnant != after.isPregnant ||
        before.isPostpartumOn(now) != after.isPostpartumOn(now);
  }
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
