import 'package:flutter/material.dart' show ThemeMode;

import '../services/clock.dart';

extension ThemeModeCopy on ThemeMode {
  String get storageValue => switch (this) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };
}

/// Falls back to following the system for unknown or missing values, so a
/// profile written before this setting existed still loads.
ThemeMode themeModeFromStorage(Object? storageValue) => switch (storageValue) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class UserProfile {
  const UserProfile({
    required this.name,
    required this.dateOfBirth,
    required this.lastPeriodStart,
    required this.cycleLength,
    required this.periodLength,
    this.avatarPath,
    this.isPregnant = false,
    this.pregnancyStartedOn,
    this.dueDate,
    this.postpartumStartedOn,
    this.postpartumEndedOn,
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  final String name;
  final DateTime dateOfBirth;
  final String? avatarPath;
  final DateTime lastPeriodStart;
  final int cycleLength;
  final int periodLength;
  final bool isPregnant;
  final DateTime? pregnancyStartedOn;
  final DateTime? dueDate;
  final DateTime? postpartumStartedOn;
  final DateTime? postpartumEndedOn;
  final bool notificationsEnabled;
  final ThemeMode themeMode;

  bool isPostpartumOn(DateTime date) {
    final expectedDueDate = dueDate;
    if (!isPregnant || expectedDueDate == null) return false;
    final day = DateTime(date.year, date.month, date.day);
    final due = DateTime(
      expectedDueDate.year,
      expectedDueDate.month,
      expectedDueDate.day,
    );
    return !day.isBefore(due);
  }

  bool isPostpartumDate(DateTime date, {DateTime? through}) {
    final startedOn = postpartumStartedOn ?? dueDate;
    if (startedOn == null) return false;

    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startedOn.year, startedOn.month, startedOn.day);
    if (day.isBefore(start)) return false;

    final endedOn = postpartumEndedOn;
    if (endedOn != null) {
      final end = DateTime(endedOn.year, endedOn.month, endedOn.day);
      // The first new period starts a new cycle, so it is not colored as a
      // postpartum day.
      return day.isBefore(end);
    }

    if (!isPregnant || dueDate == null) return false;
    final limitDate = through ?? appNow();
    final limit = DateTime(limitDate.year, limitDate.month, limitDate.day);
    return !day.isAfter(limit);
  }

  UserProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    Object? avatarPath = _unchanged,
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodLength,
    bool? isPregnant,
    Object? pregnancyStartedOn = _unchanged,
    Object? dueDate = _unchanged,
    Object? postpartumStartedOn = _unchanged,
    Object? postpartumEndedOn = _unchanged,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
  }) => UserProfile(
    name: name ?? this.name,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    avatarPath: identical(avatarPath, _unchanged)
        ? this.avatarPath
        : avatarPath as String?,
    lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
    cycleLength: cycleLength ?? this.cycleLength,
    periodLength: periodLength ?? this.periodLength,
    isPregnant: isPregnant ?? this.isPregnant,
    pregnancyStartedOn: identical(pregnancyStartedOn, _unchanged)
        ? this.pregnancyStartedOn
        : pregnancyStartedOn as DateTime?,
    dueDate: identical(dueDate, _unchanged)
        ? this.dueDate
        : dueDate as DateTime?,
    postpartumStartedOn: identical(postpartumStartedOn, _unchanged)
        ? this.postpartumStartedOn
        : postpartumStartedOn as DateTime?,
    postpartumEndedOn: identical(postpartumEndedOn, _unchanged)
        ? this.postpartumEndedOn
        : postpartumEndedOn as DateTime?,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    themeMode: themeMode ?? this.themeMode,
  );

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'name': name,
    'date_of_birth': _dateOnly(dateOfBirth),
    'avatar_path': avatarPath,
    'last_period_start': _dateOnly(lastPeriodStart),
    'cycle_length': cycleLength,
    'period_length': periodLength,
    'is_pregnant': isPregnant ? 1 : 0,
    'pregnancy_started_on': pregnancyStartedOn == null
        ? null
        : _dateOnly(pregnancyStartedOn!),
    'due_date': dueDate == null ? null : _dateOnly(dueDate!),
    'postpartum_started_on': postpartumStartedOn == null
        ? null
        : _dateOnly(postpartumStartedOn!),
    'postpartum_ended_on': postpartumEndedOn == null
        ? null
        : _dateOnly(postpartumEndedOn!),
    'notifications_enabled': notificationsEnabled ? 1 : 0,
    'theme_mode': themeMode.storageValue,
  };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
    name: map['name']! as String,
    dateOfBirth: DateTime.parse(map['date_of_birth']! as String),
    avatarPath: map['avatar_path'] as String?,
    lastPeriodStart: DateTime.parse(map['last_period_start']! as String),
    cycleLength: map['cycle_length']! as int,
    periodLength: map['period_length']! as int,
    isPregnant: (map['is_pregnant'] as int? ?? 0) == 1,
    pregnancyStartedOn: _optionalDate(map['pregnancy_started_on']),
    dueDate: _optionalDate(map['due_date']),
    postpartumStartedOn: _optionalDate(map['postpartum_started_on']),
    postpartumEndedOn: _optionalDate(map['postpartum_ended_on']),
    notificationsEnabled: (map['notifications_enabled'] as int? ?? 1) == 1,
    themeMode: themeModeFromStorage(map['theme_mode']),
  );
}

const _unchanged = Object();

DateTime? _optionalDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
