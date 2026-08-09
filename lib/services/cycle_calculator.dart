enum CyclePhase { menstruation, follicular, ovulation, luteal }

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
  });

  final DateTime date;
  final CyclePhase phase;
  final int cycleDay;
  final int cycleLength;
  final DateTime currentCycleStart;
  final DateTime nextPeriod;
  final DateTime estimatedOvulation;

  int get daysUntilNextPeriod => nextPeriod.difference(date).inDays;
  double get progress => cycleDay / cycleLength;
}

class CycleCalculator {
  const CycleCalculator();

  CycleSnapshot calculate({
    required DateTime onDate,
    required DateTime lastPeriodStart,
    required int cycleLength,
    required int periodLength,
  }) {
    final date = _day(onDate);
    final lastStart = _day(lastPeriodStart);
    final safeCycleLength = cycleLength.clamp(21, 45);
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
    );
  }

  int _floorDivision(int value, int divisor) {
    final quotient = value ~/ divisor;
    if (value >= 0 || value % divisor == 0) return quotient;
    return quotient - 1;
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
}
