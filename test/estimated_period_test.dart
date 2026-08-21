import 'package:cycle_compass/app_controller.dart';
import 'package:cycle_compass/main.dart';
import 'package:cycle_compass/models/user_profile.dart';
import 'package:cycle_compass/services/clock.dart';
import 'package:cycle_compass/services/cycle_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = CycleCalculator();

  setUpAll(initializeAppLocale);
  setUp(() => appNow = () => DateTime(2026, 3, 18, 10));
  tearDown(() => appNow = DateTime.now);

  group('estimatedPeriodStarts', () {
    test('returns nothing while the current cycle is still running', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: [DateTime(2026, 3, 1)],
          cycleLength: 28,
          through: DateTime(2026, 3, 18),
        ),
        isEmpty,
      );
    });

    test('returns one start after a single missed cycle', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: [DateTime(2026, 2, 1)],
          cycleLength: 28,
          through: DateTime(2026, 3, 18),
        ),
        [DateTime(2026, 3, 1)],
      );
    });

    test('spaces three missed cycles by the estimated length', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: [DateTime(2026, 1, 1), DateTime(2025, 12, 4)],
          cycleLength: 28,
          through: DateTime(2026, 3, 31),
        ),
        [DateTime(2026, 1, 29), DateTime(2026, 2, 26), DateTime(2026, 3, 26)],
      );
    });

    test('includes an estimate falling exactly on the last day', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: [DateTime(2026, 1, 1)],
          cycleLength: 28,
          through: DateTime(2026, 1, 29),
        ),
        [DateTime(2026, 1, 29)],
      );
    });

    test('stops one day before the estimate is due', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: [DateTime(2026, 1, 1)],
          cycleLength: 28,
          through: DateTime(2026, 1, 28),
        ),
        isEmpty,
      );
    });

    test('has nothing to estimate from without recorded history', () {
      expect(
        calculator.estimatedPeriodStarts(
          recordedStarts: const [],
          cycleLength: 28,
          through: DateTime(2026, 3, 18),
        ),
        isEmpty,
      );
    });
  });

  group('controller estimates', () {
    Future<AppController> controllerFrom(DateTime lastPeriodStart) async {
      final controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: lastPeriodStart,
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      return controller;
    }

    test('estimates the missed starts and spans the usual length', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));

      final estimates = controller.estimatedPeriodEntries;

      expect(estimates.map((entry) => entry.startDate), [
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      ]);
      expect(estimates.first.durationDays, 5);
    });

    test('keeps estimates out of the recorded history', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));

      expect(controller.periodStarts, [DateTime(2026, 1, 4)]);
      expect(controller.periodEntries, hasLength(1));
      final payload = await controller.createBackupPayload();
      expect(payload.data.periodEntries, hasLength(1));
      expect(payload.data.periodEntries.single['start_date'], '2026-01-04');
    });

    test('cycle statistics ignore estimated periods', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));
      const calculator = CycleCalculator();

      expect(controller.estimatedPeriodEntries, isNotEmpty);
      // Only the configured length is available, because a single recorded
      // start cannot describe an interval.
      expect(
        calculator.estimatedCycleLength(
          periodStarts: controller.periodStarts,
          configuredLength: 28,
        ),
        28,
      );
      expect(
        calculator.insightsForMonth(
          month: DateTime(2026, 3),
          periodStarts: controller.periodStarts,
          expectedCycleLength: 28,
        ),
        isEmpty,
      );
    });

    test('logging a real period replaces the estimates after it', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));

      await controller.logPeriodStart(DateTime(2026, 3, 4));

      expect(controller.estimatedPeriodEntries, isEmpty);
    });

    test('pregnancy suspends estimates', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));

      await controller.setPregnancyMode(
        enabled: true,
        dueDate: DateTime(2026, 9, 1),
      );

      expect(controller.estimatedPeriodEntries, isEmpty);
    });

    test('postpartum suspends estimates', () async {
      final controller = await controllerFrom(DateTime(2025, 6, 1));

      await controller.setPregnancyMode(
        enabled: true,
        dueDate: DateTime(2026, 2, 20),
      );

      expect(controller.profile!.isPostpartumOn(appNow()), isTrue);
      expect(controller.estimatedPeriodEntries, isEmpty);
    });

    test('breastfeeding suspends estimates until it ends', () async {
      final controller = await controllerFrom(DateTime(2026, 1, 4));

      await controller.startBreastfeeding(DateTime(2026, 1, 10));
      expect(controller.estimatedPeriodEntries, isEmpty);

      await controller.endBreastfeeding(DateTime(2026, 3, 10));
      expect(controller.estimatedPeriodEntries, hasLength(2));
    });
  });

  testWidgets('the calendar explains and confirms an estimated period', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 1, 4),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Estimated period'), findsOneWidget);
    expect(find.text('Faint colors = estimated'), findsOneWidget);
    expect(
      find.textContaining('The period shown around 1 March is estimated'),
      findsOneWidget,
    );

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Estimated period — confirm it happened'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirm this period'));
    await tester.pumpAndSettle();

    expect(controller.periodStarts, contains(DateTime(2026, 3, 1)));
    expect(controller.estimatedPeriodEntries, isEmpty);
  });

  testWidgets('the calendar shows breastfeeding context instead of estimates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 1, 4),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.startBreastfeeding(DateTime(2026, 1, 4));
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Breastfeeding · since 4 Jan 2026'), findsOneWidget);
    expect(find.text('Estimated period'), findsNothing);
    expect(find.textContaining('lactational amenorrhoea'), findsOneWidget);
    expect(
      find.textContaining('A period returned on 4 January'),
      findsOneWidget,
    );
  });
}
