import 'package:cycle_compass/services/cycle_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = CycleCalculator();
  final start = DateTime(2026, 8, 1);

  group('CycleCalculator', () {
    test('marks the first five days as menstruation', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 8, 5),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      );

      expect(result.cycleDay, 5);
      expect(result.phase, CyclePhase.menstruation);
    });

    test('uses day 14 as the ovulation estimate for a 28-day cycle', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 8, 14),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      );

      expect(result.phase, CyclePhase.ovulation);
      expect(result.estimatedOvulation, DateTime(2026, 8, 14));
    });

    test('moves into the luteal phase after estimated ovulation', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 8, 15),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      );

      expect(result.phase, CyclePhase.luteal);
    });

    test('rolls over cleanly at the next predicted period', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 8, 29),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      );

      expect(result.cycleDay, 1);
      expect(result.phase, CyclePhase.menstruation);
      expect(result.nextPeriod, DateTime(2026, 9, 26));
    });

    test('normalizes input lengths to supported MVP limits', () {
      final result = calculator.calculate(
        onDate: start,
        lastPeriodStart: start,
        cycleLength: 12,
        periodLength: 20,
      );

      expect(result.cycleLength, 21);
      expect(result.phase, CyclePhase.menstruation);
    });

    test('uses recorded starts as the boundaries of a completed cycle', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 7, 28),
        lastPeriodStart: DateTime(2026, 8, 1),
        cycleLength: 28,
        periodLength: 5,
        periodStarts: [DateTime(2026, 7, 16), DateTime(2026, 8, 1)],
      );

      expect(result.currentCycleStart, DateTime(2026, 7, 16));
      expect(result.nextPeriod, DateTime(2026, 8, 1));
      expect(result.cycleLength, 16);
      expect(result.cycleDay, 13);
      expect(result.estimateBasis, CycleEstimateBasis.recordedCycle);
    });

    test('uses recent recorded intervals for future estimates', () {
      final result = calculator.calculate(
        onDate: DateTime(2026, 8, 2),
        lastPeriodStart: DateTime(2026, 8, 1),
        cycleLength: 28,
        periodLength: 5,
        periodStarts: [DateTime(2026, 7, 16), DateTime(2026, 8, 1)],
      );

      expect(result.cycleLength, 16);
      expect(result.nextPeriod, DateTime(2026, 8, 17));
      expect(result.estimateBasis, CycleEstimateBasis.recentHistory);
    });

    test('uses the median of recent intervals to limit outlier influence', () {
      final length = calculator.estimatedCycleLength(
        periodStarts: [
          DateTime(2026, 5, 1),
          DateTime(2026, 5, 27),
          DateTime(2026, 6, 27),
          DateTime(2026, 7, 26),
        ],
        configuredLength: 28,
      );

      expect(length, 29);
    });

    test('classifies a 16-day recorded cycle as early and outside range', () {
      final insights = calculator.insightsForMonth(
        month: DateTime(2026, 8),
        periodStarts: [DateTime(2026, 7, 16), DateTime(2026, 8, 1)],
        expectedCycleLength: 28,
      );

      expect(insights, hasLength(1));
      expect(insights.single.actualLength, 16);
      expect(insights.single.differenceFromExpected, -12);
      expect(insights.single.timing, CycleTiming.early);
      expect(insights.single.outsideCommonAdultRange, isTrue);
    });
  });
}
