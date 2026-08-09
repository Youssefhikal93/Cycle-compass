import 'package:flutter/foundation.dart';

import 'data/app_database.dart';
import 'models/user_profile.dart';

class AppController extends ChangeNotifier {
  AppController(this._database);

  AppController.inMemory() : _database = null;

  final AppDatabase? _database;
  UserProfile? _profile;
  List<DateTime> _periodStarts = const [];

  UserProfile? get profile => _profile;
  List<DateTime> get periodStarts => _periodStarts;
  bool get isOnboarded => _profile != null;

  Future<void> load() async {
    final database = _database;
    if (database != null) {
      _profile = await database.readProfile();
      _periodStarts = await database.readPeriodStarts();
    }
    notifyListeners();
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final database = _database;
    if (database != null) {
      await database.saveProfile(profile);
      await database.addPeriodStart(profile.lastPeriodStart);
    }
    _profile = profile;
    _periodStarts = database == null
        ? [profile.lastPeriodStart]
        : await database.readPeriodStarts();
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
    await _database?.addPeriodStart(normalized);
    final updated = UserProfile(
      name: current.name,
      dateOfBirth: current.dateOfBirth,
      avatarPath: current.avatarPath,
      lastPeriodStart: normalized,
      cycleLength: current.cycleLength,
      periodLength: current.periodLength,
    );
    await _database?.saveProfile(updated);
    _profile = updated;
    _periodStarts = _database == null
        ? {normalized, ..._periodStarts}.toList()
        : await _database.readPeriodStarts();
    notifyListeners();
  }

  Future<void> reset() async {
    await _database?.clearAllData();
    _profile = null;
    _periodStarts = const [];
    notifyListeners();
  }
}
