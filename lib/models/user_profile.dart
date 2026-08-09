class UserProfile {
  const UserProfile({
    required this.name,
    required this.dateOfBirth,
    required this.lastPeriodStart,
    required this.cycleLength,
    required this.periodLength,
    this.avatarPath,
  });

  final String name;
  final DateTime dateOfBirth;
  final String? avatarPath;
  final DateTime lastPeriodStart;
  final int cycleLength;
  final int periodLength;

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
  };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
    name: map['name']! as String,
    dateOfBirth: DateTime.parse(map['date_of_birth']! as String),
    avatarPath: map['avatar_path'] as String?,
    lastPeriodStart: DateTime.parse(map['last_period_start']! as String),
    cycleLength: map['cycle_length']! as int,
    periodLength: map['period_length']! as int,
  );
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
