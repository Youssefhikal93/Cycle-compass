enum CyclePhase { menstruation, follicular, ovulation, luteal }

enum CycleEstimateBasis {
  configuredLength,
  recentHistory,
  manualDueDate,
  recordedCycle,
}

enum CycleTiming { firstRecorded, onExpectedDay, early, late }

extension CyclePhaseCopy on CyclePhase {
  String get label => switch (this) {
    CyclePhase.menstruation => 'Menstruation',
    CyclePhase.follicular => 'Follicular',
    CyclePhase.ovulation => 'Ovulation',
    CyclePhase.luteal => 'Luteal',
  };

  String get shortDescription => switch (this) {
    CyclePhase.menstruation => 'The uterine lining is shedding.',
    CyclePhase.follicular => 'An egg is developing as estrogen rises.',
    CyclePhase.ovulation => 'An egg may be released around this time.',
    CyclePhase.luteal => 'The body prepares for a possible pregnancy.',
  };
}

class CycleSnapshot {
  const CycleSnapshot({
    required this.date,
    required this.phase,
    required this.cycleDay,
    required this.cycleLength,
    required this.currentCycleStart,
    required this.nextPeriod,
    required this.estimatedOvulation,
    this.estimateBasis = CycleEstimateBasis.configuredLength,
  });

  final DateTime date;
  final CyclePhase phase;
  final int cycleDay;
  final int cycleLength;
  final DateTime currentCycleStart;
  final DateTime nextPeriod;
  final DateTime estimatedOvulation;
  final CycleEstimateBasis estimateBasis;

  CycleSnapshot copyWith({CyclePhase? phase}) => CycleSnapshot(
    date: date,
    phase: phase ?? this.phase,
    cycleDay: cycleDay,
    cycleLength: cycleLength,
    currentCycleStart: currentCycleStart,
    nextPeriod: nextPeriod,
    estimatedOvulation: estimatedOvulation,
    estimateBasis: estimateBasis,
  );

  int get daysUntilNextPeriod => nextPeriod.difference(date).inDays;
  double get progress => cycleDay / cycleLength;
}

class CycleIntervalInsight {
  const CycleIntervalInsight({
    required this.start,
    required this.timing,
    required this.expectedLength,
    this.previousStart,
    this.actualLength,
  });

  final DateTime start;
  final DateTime? previousStart;
  final int? actualLength;
  final int expectedLength;
  final CycleTiming timing;

  int get differenceFromExpected =>
      actualLength == null ? 0 : actualLength! - expectedLength;

  bool get outsideCommonAdultRange =>
      actualLength != null && (actualLength! < 21 || actualLength! > 35);
}

class CycleCalculator {
  const CycleCalculator();

  CycleSnapshot calculate({
    required DateTime onDate,
    required DateTime lastPeriodStart,
    required int cycleLength,
    required int periodLength,
    List<DateTime> periodStarts = const [],
    DateTime? nextPeriodDueDate,
  }) {
    final date = _day(onDate);
    final lastStart = _day(lastPeriodStart);
    final starts = _normalizedStarts(periodStarts, lastStart);
    if (starts.length > 1) {
      for (var index = 0; index < starts.length - 1; index++) {
        final start = starts[index];
        final nextStart = starts[index + 1];
        if (!date.isBefore(start) && date.isBefore(nextStart)) {
          return _recordedSnapshot(
            date: date,
            currentStart: start,
            nextStart: nextStart,
            periodLength: periodLength,
          );
        }
      }
    }

    var predictedLength = estimatedCycleLength(
      periodStarts: starts,
      configuredLength: cycleLength,
    );
    final anchor = date.isBefore(starts.first) ? starts.first : starts.last;
    var estimateBasis = starts.length > 1
        ? CycleEstimateBasis.recentHistory
        : CycleEstimateBasis.configuredLength;
    final manualDueDate = nextPeriodDueDate == null
        ? null
        : _day(nextPeriodDueDate);
    if (manualDueDate != null &&
        manualDueDate.isAfter(starts.last) &&
        !date.isBefore(starts.last)) {
      predictedLength = manualDueDate.difference(starts.last).inDays;
      estimateBasis = CycleEstimateBasis.manualDueDate;
    }
    return _estimatedSnapshot(
      date: date,
      lastStart: anchor,
      cycleLength: predictedLength,
      periodLength: periodLength,
      estimateBasis: estimateBasis,
    );
  }

  int estimatedCycleLength({
    required List<DateTime> periodStarts,
    required int configuredLength,
  }) {
    final starts = _normalizedStarts(periodStarts, null);
    final intervals = <int>[];
    for (var index = 1; index < starts.length; index++) {
      final interval = starts[index].difference(starts[index - 1]).inDays;
      if (interval >= 15 && interval <= 60) intervals.add(interval);
    }
    if (intervals.isEmpty) return configuredLength.clamp(21, 45);
    final recent = intervals.length > 6
        ? intervals.sublist(intervals.length - 6)
        : intervals;
    recent.sort();
    final middle = recent.length ~/ 2;
    final median = recent.length.isOdd
        ? recent[middle]
        : ((recent[middle - 1] + recent[middle]) / 2).round();
    return median.clamp(15, 60);
  }

  List<CycleIntervalInsight> insightsForMonth({
    required DateTime month,
    required List<DateTime> periodStarts,
    required int expectedCycleLength,
  }) {
    final starts = _normalizedStarts(periodStarts, null);
    final expected = expectedCycleLength.clamp(21, 45);
    final insights = <CycleIntervalInsight>[];
    for (var index = 0; index < starts.length; index++) {
      final start = starts[index];
      if (start.year != month.year || start.month != month.month) continue;
      if (index == 0) {
        insights.add(
          CycleIntervalInsight(
            start: start,
            timing: CycleTiming.firstRecorded,
            expectedLength: expected,
          ),
        );
        continue;
      }
      final previous = starts[index - 1];
      final actual = start.difference(previous).inDays;
      final timing = switch (actual.compareTo(expected)) {
        < 0 => CycleTiming.early,
        > 0 => CycleTiming.late,
        _ => CycleTiming.onExpectedDay,
      };
      insights.add(
        CycleIntervalInsight(
          start: start,
          previousStart: previous,
          actualLength: actual,
          expectedLength: expected,
          timing: timing,
        ),
      );
    }
    return insights;
  }

  CycleSnapshot _estimatedSnapshot({
    required DateTime date,
    required DateTime lastStart,
    required int cycleLength,
    required int periodLength,
    required CycleEstimateBasis estimateBasis,
  }) {
    final safeCycleLength = cycleLength.clamp(2, 365);
    final safePeriodLength = periodLength.clamp(1, 10);
    final daysFromStart = date.difference(lastStart).inDays;
    final cycleIndex = _floorDivision(daysFromStart, safeCycleLength);
    final dayIndex = daysFromStart - (cycleIndex * safeCycleLength);
    final cycleDay = dayIndex + 1;
    final currentStart = lastStart.add(
      Duration(days: cycleIndex * safeCycleLength),
    );
    final nextPeriod = currentStart.add(Duration(days: safeCycleLength));
    final ovulationDay = (safeCycleLength - 14).clamp(
      safePeriodLength + 1,
      safeCycleLength - 1,
    );

    final phase = switch (cycleDay) {
      <= 10 when cycleDay <= safePeriodLength => CyclePhase.menstruation,
      _ when cycleDay < ovulationDay => CyclePhase.follicular,
      _ when cycleDay == ovulationDay => CyclePhase.ovulation,
      _ => CyclePhase.luteal,
    };

    return CycleSnapshot(
      date: date,
      phase: phase,
      cycleDay: cycleDay,
      cycleLength: safeCycleLength,
      currentCycleStart: currentStart,
      nextPeriod: nextPeriod,
      estimatedOvulation: currentStart.add(Duration(days: ovulationDay - 1)),
      estimateBasis: estimateBasis,
    );
  }

  CycleSnapshot _recordedSnapshot({
    required DateTime date,
    required DateTime currentStart,
    required DateTime nextStart,
    required int periodLength,
  }) {
    final actualLength = nextStart.difference(currentStart).inDays;
    final cycleDay = date.difference(currentStart).inDays + 1;
    final safePeriodLength = periodLength.clamp(1, actualLength);
    final ovulationDay = actualLength <= 1
        ? 1
        : (actualLength - 14).clamp(
            (safePeriodLength + 1).clamp(2, actualLength),
            actualLength,
          );
    final phase = switch (cycleDay) {
      _ when cycleDay <= safePeriodLength => CyclePhase.menstruation,
      _ when cycleDay < ovulationDay => CyclePhase.follicular,
      _ when cycleDay == ovulationDay => CyclePhase.ovulation,
      _ => CyclePhase.luteal,
    };
    return CycleSnapshot(
      date: date,
      phase: phase,
      cycleDay: cycleDay,
      cycleLength: actualLength,
      currentCycleStart: currentStart,
      nextPeriod: nextStart,
      estimatedOvulation: currentStart.add(Duration(days: ovulationDay - 1)),
      estimateBasis: CycleEstimateBasis.recordedCycle,
    );
  }

  List<DateTime> _normalizedStarts(List<DateTime> starts, DateTime? fallback) {
    final normalized = <DateTime>{for (final start in starts) _day(start)};
    if (fallback != null) normalized.add(_day(fallback));
    final sorted = normalized.toList()..sort();
    return sorted;
  }

  int _floorDivision(int value, int divisor) {
    final quotient = value ~/ divisor;
    if (value >= 0 || value % divisor == 0) return quotient;
    return quotient - 1;
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
}
