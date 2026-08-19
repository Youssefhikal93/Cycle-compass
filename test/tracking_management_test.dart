import 'package:cycle_compass/app_controller.dart';
import 'package:cycle_compass/main.dart';
import 'package:cycle_compass/models/intercourse_entry.dart';
import 'package:cycle_compass/models/life_stage_entry.dart';
import 'package:cycle_compass/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('period history management', () {
    late AppController controller;

    setUp(() async {
      controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 8, 1),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
    });

    test(
      'adding an older entry keeps the newest date as cycle anchor',
      () async {
        await controller.logPeriodStart(DateTime(2026, 7, 3));

        expect(controller.periodStarts, [
          DateTime(2026, 8, 1),
          DateTime(2026, 7, 3),
        ]);
        expect(controller.profile!.lastPeriodStart, DateTime(2026, 8, 1));
      },
    );

    test('editing the newest entry updates the cycle anchor', () async {
      await controller.updatePeriodStart(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 4),
      );

      expect(controller.periodStarts, [DateTime(2026, 8, 4)]);
      expect(controller.profile!.lastPeriodStart, DateTime(2026, 8, 4));
    });

    test('deleting falls back to the next latest entry', () async {
      await controller.logPeriodStart(DateTime(2026, 7, 3));

      expect(await controller.deletePeriodStart(DateTime(2026, 8, 1)), isTrue);
      expect(controller.profile!.lastPeriodStart, DateTime(2026, 7, 3));
      expect(await controller.deletePeriodStart(DateTime(2026, 7, 3)), isFalse);
    });

    test('records and adjusts the last bleeding day', () async {
      await controller.updatePeriodEnd(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 6),
      );

      expect(controller.periodEntries.single.durationDays, 6);
      expect(
        controller.periodEntries.single.contains(DateTime(2026, 8, 6)),
        isTrue,
      );

      await controller.updatePeriodEnd(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 5),
      );
      expect(controller.periodEntries.single.durationDays, 5);

      await controller.updatePeriodEnd(DateTime(2026, 8, 1), null);
      expect(controller.periodEntries.single.endDate, isNull);
    });

    test('moving a start preserves a valid recorded end', () async {
      await controller.updatePeriodEnd(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 6),
      );
      await controller.updatePeriodStart(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      );

      expect(controller.periodEntries.single.startDate, DateTime(2026, 8, 2));
      expect(controller.periodEntries.single.endDate, DateTime(2026, 8, 6));
      expect(controller.periodEntries.single.durationDays, 5);
    });

    test(
      'stores a due date and clears it after a newer actual start',
      () async {
        await controller.setNextPeriodDueDate(DateTime(2026, 8, 29));
        expect(controller.profile!.nextPeriodDueDate, DateTime(2026, 8, 29));

        await controller.logPeriodStart(DateTime(2026, 7, 15));
        expect(controller.profile!.nextPeriodDueDate, DateTime(2026, 8, 29));

        await controller.logPeriodStart(DateTime(2026, 8, 25));
        expect(controller.profile!.nextPeriodDueDate, isNull);
        expect(controller.profile!.lastPeriodStart, DateTime(2026, 8, 25));
      },
    );
  });

  group('calendar event history', () {
    late AppController controller;

    setUp(() async {
      controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 8, 1),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
    });

    test(
      'changing protection replaces the intercourse entry for that day',
      () async {
        final date = DateTime(2026, 8, 12);

        await controller.saveIntercourseEntry(date, ProtectionStatus.protected);
        await controller.saveIntercourseEntry(
          date,
          ProtectionStatus.unprotected,
        );

        expect(controller.intercourseEntries, hasLength(1));
        expect(
          controller.intercourseEntryOn(date)?.protectionStatus,
          ProtectionStatus.unprotected,
        );
      },
    );

    test('completed life-stage ranges cannot overlap', () async {
      await controller.saveLifeStageEntry(
        LifeStageEntry(
          type: LifeStageType.pregnancy,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 7, 1),
        ),
      );
      await controller.saveLifeStageEntry(
        LifeStageEntry(
          type: LifeStageType.postpartum,
          startDate: DateTime(2024, 7, 2),
          endDate: DateTime(2024, 9, 30),
        ),
      );

      expect(controller.lifeStageEntries, hasLength(2));
      expect(
        () => controller.saveLifeStageEntry(
          LifeStageEntry(
            type: LifeStageType.postpartum,
            startDate: DateTime(2024, 6, 1),
            endDate: DateTime(2024, 8, 1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('past history cannot overlap active pregnancy tracking', () async {
      await controller.setPregnancyMode(
        enabled: true,
        dueDate: DateTime.now().add(const Duration(days: 140)),
      );
      final activeStart = controller.profile!.pregnancyStartedOn!;

      expect(
        () => controller.saveLifeStageEntry(
          LifeStageEntry(
            type: LifeStageType.pregnancy,
            startDate: activeStart.subtract(const Duration(days: 30)),
            endDate: activeStart,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'pregnancy mode pauses tracking state without deleting history',
    () async {
      final controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 8, 1),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      final dueDate = DateTime(2027, 3, 12);

      await controller.setPregnancyMode(enabled: true, dueDate: dueDate);

      expect(controller.profile!.isPregnant, isTrue);
      expect(controller.profile!.pregnancyStartedOn, isNotNull);
      expect(controller.profile!.dueDate, dueDate);
      expect(controller.profile!.postpartumStartedOn, dueDate);
      expect(controller.profile!.postpartumEndedOn, isNull);
      expect(controller.periodStarts, [DateTime(2026, 8, 1)]);

      await controller.setPregnancyMode(enabled: false);

      expect(controller.profile!.isPregnant, isFalse);
      expect(controller.profile!.pregnancyStartedOn, isNull);
      expect(controller.profile!.dueDate, isNull);
      expect(controller.periodStarts, [DateTime(2026, 8, 1)]);
    },
  );

  test('pregnancy mode requires an expected due date', () async {
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 8, 1),
        cycleLength: 28,
        periodLength: 5,
      ),
    );

    expect(
      () => controller.setPregnancyMode(enabled: true),
      throwsArgumentError,
    );
    expect(controller.profile!.isPregnant, isFalse);
  });

  test('period logging is blocked before the pregnancy due date', () async {
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 8, 1),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.setPregnancyMode(
      enabled: true,
      dueDate: DateTime(2027, 3, 12),
    );

    expect(
      () => controller.logPeriodStart(DateTime(2027, 3, 11)),
      throwsStateError,
    );
    expect(controller.periodStarts, [DateTime(2026, 8, 1)]);
  });

  test(
    'postpartum starts on the due date and ends with the first period',
    () async {
      final controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 1, 3),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      final dueDate = DateTime(2026, 8, 8);
      final firstPeriod = DateTime(2026, 10, 2);
      await controller.setPregnancyMode(enabled: true, dueDate: dueDate);

      expect(controller.profile!.isPostpartumOn(DateTime(2026, 8, 7)), isFalse);
      expect(controller.profile!.isPostpartumOn(dueDate), isTrue);

      await controller.logPeriodStart(firstPeriod);

      expect(controller.profile!.isPregnant, isFalse);
      expect(controller.profile!.postpartumStartedOn, dueDate);
      expect(controller.profile!.postpartumEndedOn, firstPeriod);
      expect(controller.profile!.lastPeriodStart, firstPeriod);
      expect(controller.periodStarts.first, firstPeriod);
    },
  );

  test(
    'editing the first postpartum period keeps its end date synced',
    () async {
      final controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 1, 3),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      await controller.setPregnancyMode(
        enabled: true,
        dueDate: DateTime(2026, 8, 8),
      );
      await controller.logPeriodStart(DateTime(2026, 10, 2));

      await controller.updatePeriodStart(
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 4),
      );

      expect(controller.profile!.postpartumEndedOn, DateTime(2026, 10, 4));
      expect(controller.profile!.lastPeriodStart, DateTime(2026, 10, 4));
    },
  );

  test(
    'deleting the first postpartum period reopens postpartum mode',
    () async {
      final controller = AppController.inMemory();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: DateTime(2026, 1, 3),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      final dueDate = DateTime(2026, 8, 8);
      final firstPeriod = DateTime(2026, 10, 2);
      await controller.setPregnancyMode(enabled: true, dueDate: dueDate);
      await controller.logPeriodStart(firstPeriod);

      expect(await controller.deletePeriodStart(firstPeriod), isTrue);
      expect(controller.profile!.isPregnant, isTrue);
      expect(controller.profile!.dueDate, dueDate);
      expect(controller.profile!.postpartumEndedOn, isNull);
      expect(controller.profile!.isPostpartumOn(firstPeriod), isTrue);
    },
  );

  group('UserProfile persistence', () {
    test('identifies postpartum dates until the first new period', () {
      final active = UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 1, 3),
        cycleLength: 28,
        periodLength: 5,
        isPregnant: true,
        dueDate: DateTime(2026, 8, 8),
        postpartumStartedOn: DateTime(2026, 8, 8),
      );

      expect(
        active.isPostpartumDate(
          DateTime(2026, 8, 7),
          through: DateTime(2026, 8, 10),
        ),
        isFalse,
      );
      expect(
        active.isPostpartumDate(
          DateTime(2026, 8, 8),
          through: DateTime(2026, 8, 10),
        ),
        isTrue,
      );
      expect(
        active.isPostpartumDate(
          DateTime(2026, 8, 11),
          through: DateTime(2026, 8, 10),
        ),
        isFalse,
      );

      final completed = active.copyWith(
        isPregnant: false,
        dueDate: null,
        postpartumEndedOn: DateTime(2026, 10, 2),
      );
      expect(completed.isPostpartumDate(DateTime(2026, 10, 1)), isTrue);
      expect(completed.isPostpartumDate(DateTime(2026, 10, 2)), isFalse);
    });

    test('round-trips pregnancy fields', () {
      final profile = UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 8, 1),
        cycleLength: 28,
        periodLength: 5,
        isPregnant: true,
        pregnancyStartedOn: DateTime(2026, 8, 9),
        dueDate: DateTime(2027, 3, 12),
        nextPeriodDueDate: DateTime(2026, 8, 29),
        postpartumStartedOn: DateTime(2027, 3, 12),
        postpartumEndedOn: DateTime(2027, 5, 1),
        notificationsEnabled: false,
      );

      final restored = UserProfile.fromMap(profile.toMap());

      expect(restored.isPregnant, isTrue);
      expect(restored.pregnancyStartedOn, DateTime(2026, 8, 9));
      expect(restored.dueDate, DateTime(2027, 3, 12));
      expect(restored.nextPeriodDueDate, DateTime(2026, 8, 29));
      expect(restored.postpartumStartedOn, DateTime(2027, 3, 12));
      expect(restored.postpartumEndedOn, DateTime(2027, 5, 1));
      expect(restored.notificationsEnabled, isFalse);
    });

    test('loads a legacy profile with pregnancy mode off', () {
      final restored = UserProfile.fromMap({
        'id': 1,
        'name': 'Nadia Rahman',
        'date_of_birth': '1997-04-16',
        'avatar_path': null,
        'last_period_start': '2026-08-01',
        'cycle_length': 28,
        'period_length': 5,
      });

      expect(restored.isPregnant, isFalse);
      expect(restored.pregnancyStartedOn, isNull);
      expect(restored.dueDate, isNull);
      expect(restored.nextPeriodDueDate, isNull);
      expect(restored.postpartumStartedOn, isNull);
      expect(restored.postpartumEndedOn, isNull);
      expect(restored.notificationsEnabled, isTrue);
    });
  });

  testWidgets('pregnancy mode pauses home estimates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.setPregnancyMode(
      enabled: true,
      dueDate: DateTime.now().add(const Duration(days: 140)),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));

    expect(find.text('Pregnancy mode is on'), findsOneWidget);
    expect(find.textContaining('Next period estimated'), findsNothing);
    expect(controller.periodStarts, hasLength(1));
  });

  testWidgets(
    'due date automatically shows postpartum mode and first-period action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController.inMemory();
      final today = DateTime.now();
      await controller.completeOnboarding(
        UserProfile(
          name: 'Nadia Rahman',
          dateOfBirth: DateTime(1997, 4, 16),
          lastPeriodStart: today.subtract(const Duration(days: 250)),
          cycleLength: 28,
          periodLength: 5,
        ),
      );
      await controller.setPregnancyMode(
        enabled: true,
        dueDate: today.subtract(const Duration(days: 1)),
      );
      await tester.pumpWidget(CycleCompassApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Postpartum mode'), findsOneWidget);
      expect(find.text('Log first postpartum period'), findsOneWidget);
      expect(find.textContaining('Next period estimated'), findsNothing);
    },
  );

  testWidgets('calendar explains a 16-day cycle as early', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final now = DateTime.now();
    final latest = DateTime(now.year, now.month, 1);
    final previous = latest.subtract(const Duration(days: 16));
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: previous,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.logPeriodStart(latest);
    await tester.pumpWidget(CycleCompassApp(controller: controller));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('started 12 days earlier'), findsOneWidget);
    expect(find.textContaining('16-day cycle'), findsOneWidget);
    expect(find.textContaining('common 21–35-day adult range'), findsOneWidget);
  });

  testWidgets('period history can add one extra bleeding day', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final start = DateTime.now().subtract(const Duration(days: 10));
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Latest period'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest period'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add one more day'));
    await tester.pumpAndSettle();

    expect(controller.periodEntries.single.durationDays, 6);
  });

  testWidgets('calendar summarizes the recorded bleeding range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.updatePeriodEnd(start, start.add(const Duration(days: 5)));
    await tester.pumpWidget(CycleCompassApp(controller: controller));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('6 days (1 day longer than usual)'),
      findsOneWidget,
    );
  });

  testWidgets('Today respects an extra recorded bleeding day', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 5));
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.updatePeriodEnd(start, today);

    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('The uterine lining is shedding.'), findsOneWidget);
  });

  testWidgets('manual period due date appears on Today and Calendar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 8));
    final dueDate = today.add(const Duration(days: 12));
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: start,
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.setNextPeriodDueDate(dueDate);
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('DATE SET BY YOU'), findsOneWidget);
    expect(find.textContaining('Period due'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    if (dueDate.month != today.month || dueDate.year != today.year) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Due date'), findsOneWidget);
    expect(
      find.textContaining('You set your next period due date'),
      findsOneWidget,
    );
  });

  testWidgets('Profile exposes the next period due-date editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Next period due date'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('Next period due date'));
    await tester.pumpAndSettle();

    expect(find.text('Set expected date'), findsOneWidget);
  });

  testWidgets('calendar day editor records protection and updates its legend', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final today = DateTime.now();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: today.subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Protected sex'), findsNothing);
    expect(find.text('Unprotected sex'), findsNothing);

    await tester.tap(find.text('${today.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sex with protection'));
    await tester.pumpAndSettle();

    expect(
      controller.intercourseEntryOn(today)?.protectionStatus,
      ProtectionStatus.protected,
    );
    expect(find.text('Protected sex'), findsOneWidget);
    expect(find.text('Unprotected sex'), findsNothing);
    expect(find.byIcon(Icons.health_and_safety_outlined), findsNWidgets(2));
  });

  testWidgets('profile can add a completed postpartum history range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add past pregnancy or postpartum'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Add past pregnancy or postpartum'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add past pregnancy or postpartum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Postpartum').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save history'));
    await tester.pumpAndSettle();

    expect(controller.lifeStageEntries.single.type, LifeStageType.postpartum);
  });

  testWidgets('cycle notifications are on by default and can be disabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cycle notifications'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(controller.profile!.notificationsEnabled, isTrue);
    expect(
      find.text('On · every estimated phase and mode change around 9:00 AM'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Cycle notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cycle notifications'));
    await tester.pumpAndSettle();

    expect(controller.profile!.notificationsEnabled, isFalse);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('profile sections are expanded by default and collapsible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Date of birth'), findsOneWidget);

    await tester.tap(find.text('PERSONAL DETAILS'));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth'), findsNothing);

    await tester.tap(find.text('PERSONAL DETAILS'));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('PREGNANCY & POSTPARTUM'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Current mode'), findsOneWidget);

    await tester.tap(find.text('PREGNANCY & POSTPARTUM'));
    await tester.pumpAndSettle();
    expect(find.text('Current mode'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Private by design'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('stored only on this device'), findsOneWidget);

    await tester.tap(find.text('Private by design'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stored only on this device'), findsNothing);
  });
}
