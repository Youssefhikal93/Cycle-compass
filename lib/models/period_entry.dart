class PeriodEntry {
  const PeriodEntry({required this.startDate, this.endDate});

  final DateTime startDate;
  final DateTime? endDate;

  int? get durationDays =>
      endDate == null ? null : endDate!.difference(startDate).inDays + 1;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(startDate) &&
        endDate != null &&
        !day.isAfter(endDate!);
  }
}
