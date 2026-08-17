enum LifeStageType { pregnancy, postpartum }

extension LifeStageTypeCopy on LifeStageType {
  String get label => switch (this) {
    LifeStageType.pregnancy => 'Pregnancy',
    LifeStageType.postpartum => 'Postpartum',
  };

  String get storageValue => switch (this) {
    LifeStageType.pregnancy => 'pregnancy',
    LifeStageType.postpartum => 'postpartum',
  };
}

LifeStageType lifeStageTypeFromStorage(String storageValue) =>
    switch (storageValue) {
      'pregnancy' => LifeStageType.pregnancy,
      'postpartum' => LifeStageType.postpartum,
      _ => throw FormatException('Unknown life stage type: $storageValue'),
    };

class LifeStageEntry {
  const LifeStageEntry({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.id,
  });

  final int? id;
  final LifeStageType type;
  final DateTime startDate;
  final DateTime endDate;

  int get durationDays => endDate.difference(startDate).inDays + 1;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(startDate) && !day.isAfter(endDate);
  }

  LifeStageEntry copyWith({
    int? id,
    LifeStageType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) => LifeStageEntry(
    id: id ?? this.id,
    type: type ?? this.type,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
}
