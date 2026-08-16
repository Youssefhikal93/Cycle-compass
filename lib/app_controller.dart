import 'package:flutter/foundation.dart';

import 'data/app_database.dart';
import 'models/user_profile.dart';
import 'models/period_entry.dart';

class AppController extends ChangeNotifier {
  AppController(this._database);

  AppController.inMemory() : _database = null;

  final AppDatabase? _database;
  UserProfile? _profile;
  List<PeriodEntry> _periodEntries = const [];

  UserProfile? get profile => _profile;
  List<PeriodEntry> get periodEntries => List.unmodifiable(_periodEntries);
  List<DateTime> get periodStarts =>
      _periodEntries.map((entry) => entry.startDate).toList(growable: false);
  bool get isOnboarded => _profile != null;

  Future<void> load() async {
    final database = _database;
    if (database != null) {
      _profile = await database.readProfile();
      _periodEntries = await database.readPeriodEntries();
    }
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
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _database?.saveProfile(profile);
    _profile = profile;
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
    await _syncLatestPeriod(
      trackingProfile,
      clearDueDate: normalized.isAfter(trackingProfile.lastPeriodStart),
    );
    notifyListeners();
  }

  Future<void> updatePeriodStart(DateTime oldDate, DateTime newDate) async {
    final current = _profile;
    if (current == null) return;
    final oldDay = _day(oldDate);
    final newDay = _day(newDate);
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
          ? current.pregnancyStartedOn ?? _day(DateTime.now())
          : null,
      dueDate: enabled && dueDate != null ? _day(dueDate) : null,
      postpartumStartedOn: enabled && dueDate != null ? _day(dueDate) : null,
      postpartumEndedOn: null,
    );
    await _database?.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  Future<void> setNextPeriodDueDate(DateTime? date) async {
    final current = _profile;
    if (current == null) return;
    final dueDate = date == null ? null : _day(date);
    if (dueDate != null && !dueDate.isAfter(current.lastPeriodStart)) {
      throw ArgumentError(
        'The due date must be after the latest period start.',
      );
    }
    final updated = current.copyWith(nextPeriodDueDate: dueDate);
    await _database?.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  Future<void> _syncLatestPeriod(
    UserProfile current, {
    bool clearDueDate = false,
  }) async {
    _periodEntries.sort((a, b) => b.startDate.compareTo(a.startDate));
    if (_periodEntries.isEmpty) return;
    final latest = _periodEntries.first.startDate;
    final dueDate = current.nextPeriodDueDate;
    final shouldClearDueDate =
        clearDueDate || (dueDate != null && !dueDate.isAfter(latest));
    final updated = current.copyWith(
      lastPeriodStart: latest,
      nextPeriodDueDate: shouldClearDueDate ? null : dueDate,
    );
    await _database?.saveProfile(updated);
    _profile = updated;
  }

  Future<void> reset() async {
    await _database?.clearAllData();
    _profile = null;
    _periodEntries = const [];
    notifyListeners();
  }
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
