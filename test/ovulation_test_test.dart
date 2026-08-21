import 'package:cycle_compass/app_controller.dart';
import 'package:cycle_compass/main.dart';
import 'package:cycle_compass/models/intercourse_entry.dart';
import 'package:cycle_compass/models/ovulation_test_entry.dart';
import 'package:cycle_compass/models/user_profile.dart';
import 'package:cycle_compass/services/clock.dart';
import 'package:cycle_compass/services/cycle_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initializeAppLocale);
  setUp(() => appNow = () => DateTime(2026, 3, 18, 10));
  tearDown(() => appNow = DateTime.now);

  Future<AppController> onboardedController() async {
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 3, 1),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    return controller;
  }

  group('ovulation test entries', () {
    test('one result per day, replaceable and removable', () async {
      final controller = await onboardedController();
      final date = DateTime(2026, 3, 12);

      await controller.saveOvulationTest(date, OvulationTestResult.negative);
      await controller.saveOvulationTest(date, OvulationTestResult.positive);

      expect(controller.ovulationTestEntries, hasLength(1));
      expect(
        controller.ovulationTestOn(date)?.result,
        OvulationTestResult.positive,
      );

      await controller.deleteOvulationTest(date);

      expect(controller.ovulationTestEntries, isEmpty);
      expect(controller.ovulationTestOn(date), isNull);
    });

    test('a future test result is rejected', () async {
      final controller = await onboardedController();

      expect(
        () => controller.saveOvulationTest(
          DateTime(2026, 3, 19),
          OvulationTestResult.positive,
        ),
        throwsArgumentError,
      );
    });

    test('a test result leaves every prediction untouched', () async {
      final controller = await onboardedController();
      const calculator = CycleCalculator();
      CycleSnapshot snapshot() => calculator.calculate(
        onDate: appNow(),
        lastPeriodStart: controller.profile!.lastPeriodStart,
        cycleLength: controller.profile!.cycleLength,
        periodLength: controller.profile!.periodLength,
        periodStarts: controller.periodStarts,
      );
      final before = snapshot();

      await controller.saveOvulationTest(
        DateTime(2026, 3, 10),
        OvulationTestResult.positive,
      );

      final after = snapshot();
      expect(after.nextPeriod, before.nextPeriod);
      expect(after.estimatedOvulation, before.estimatedOvulation);
      expect(after.phase, before.phase);
      expect(controller.profile!.cycleLength, 28);
    });

    test('sex and a test on one day survive each other in memory', () async {
      final controller = await onboardedController();
      final date = DateTime(2026, 3, 12);

      await controller.saveIntercourseEntry(date, ProtectionStatus.protected);
      await controller.saveOvulationTest(date, OvulationTestResult.positive);
      await controller.deleteIntercourseEntry(date);

      expect(controller.intercourseEntryOn(date), isNull);
      expect(
        controller.ovulationTestOn(date)?.result,
        OvulationTestResult.positive,
      );
    });

    test('a backup round-trip keeps both entries of one day', () async {
      final controller = await onboardedController();
      final date = DateTime(2026, 3, 12);
      await controller.saveIntercourseEntry(date, ProtectionStatus.unprotected);
      await controller.saveOvulationTest(date, OvulationTestResult.negative);

      final payload = await controller.createBackupPayload();
      expect(payload.data.dailyLogs, hasLength(1));
      await controller.reset();
      await controller.restoreBackup(payload);

      expect(
        controller.intercourseEntryOn(date)?.protectionStatus,
        ProtectionStatus.unprotected,
      );
      expect(
        controller.ovulationTestOn(date)?.result,
        OvulationTestResult.negative,
      );
    });
  });

  testWidgets('the day editor records a test and the calendar explains it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await onboardedController();
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Positive ovulation test'), findsNothing);

    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    expect(find.text('Ovulation test'), findsOneWidget);
    await tester.tap(find.text('Positive'));
    await tester.pumpAndSettle();

    expect(
      controller.ovulationTestOn(DateTime(2026, 3, 12))?.result,
      OvulationTestResult.positive,
    );
    expect(find.text('Positive ovulation test'), findsOneWidget);
    expect(
      find.textContaining(
        'Positive ovulation test on 12 March, 2 days before the estimated '
        'ovulation day',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove test result'));
    await tester.pumpAndSettle();

    expect(controller.ovulationTestEntries, isEmpty);
  });

  testWidgets('negative-only months get one quiet count line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await onboardedController();
    await controller.saveOvulationTest(
      DateTime(2026, 3, 10),
      OvulationTestResult.negative,
    );
    await controller.saveOvulationTest(
      DateTime(2026, 3, 11),
      OvulationTestResult.negative,
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Negative ovulation test'), findsOneWidget);
    expect(
      find.textContaining('2 negative ovulation tests recorded this month'),
      findsOneWidget,
    );
  });
}
