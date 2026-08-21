import 'package:cycle_compass/app_controller.dart';
import 'package:cycle_compass/main.dart';
import 'package:cycle_compass/models/intercourse_entry.dart';
import 'package:cycle_compass/models/life_stage_entry.dart';
import 'package:cycle_compass/models/ovulation_test_entry.dart';
import 'package:cycle_compass/models/user_profile.dart';
import 'package:cycle_compass/screens/profile_screen.dart';
import 'package:cycle_compass/services/backup_codec.dart';
import 'package:cycle_compass/services/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => appNow = () => DateTime(2026, 8, 19, 10));
  tearDown(() => appNow = DateTime.now);

  group('controller backup and restore', () {
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
      await controller.updatePeriodEnd(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 5),
      );
      await controller.logPeriodStart(DateTime(2026, 7, 4));
      await controller.saveIntercourseEntry(
        DateTime(2026, 8, 3),
        ProtectionStatus.protected,
      );
      await controller.saveLifeStageEntry(
        LifeStageEntry(
          type: LifeStageType.pregnancy,
          startDate: DateTime(2023, 1, 10),
          endDate: DateTime(2023, 10, 12),
        ),
      );
    });

    test('a payload carries every table', () async {
      final payload = await controller.createBackupPayload();

      expect(payload.exportedAt, DateTime(2026, 8, 19, 10));
      expect(payload.data.profile!['name'], 'Nadia Rahman');
      expect(payload.data.periodEntries, hasLength(2));
      expect(payload.data.dailyLogs, hasLength(1));
      expect(payload.data.lifeStageEntries, hasLength(1));
    });

    test('restoring brings back cleared data', () async {
      final payload = await controller.createBackupPayload();
      await controller.reset();
      expect(controller.isOnboarded, isFalse);
      expect(controller.periodEntries, isEmpty);

      await controller.restoreBackup(payload);

      final profile = controller.profile!;
      expect(profile.name, 'Nadia Rahman');
      expect(profile.dateOfBirth, DateTime(1997, 4, 16));
      expect(profile.lastPeriodStart, DateTime(2026, 8, 1));
      expect(profile.cycleLength, 28);
      expect(profile.periodLength, 5);
      expect(controller.periodStarts, [
        DateTime(2026, 8, 1),
        DateTime(2026, 7, 4),
      ]);
      expect(controller.periodEntries.first.endDate, DateTime(2026, 8, 5));
      expect(
        controller.intercourseEntryOn(DateTime(2026, 8, 3))!.protectionStatus,
        ProtectionStatus.protected,
      );
      expect(
        controller.lifeStageEntries.single.startDate,
        DateTime(2023, 1, 10),
      );
    });

    test('restoring replaces newer local changes', () async {
      final payload = await controller.createBackupPayload();
      await controller.logPeriodStart(DateTime(2026, 8, 16));
      await controller.deleteIntercourseEntry(DateTime(2026, 8, 3));
      expect(controller.periodStarts, hasLength(3));

      await controller.restoreBackup(payload);

      expect(controller.periodStarts, [
        DateTime(2026, 8, 1),
        DateTime(2026, 7, 4),
      ]);
      expect(controller.intercourseEntries, hasLength(1));
    });

    test('a backup survives an encrypted round-trip', () async {
      const codec = BackupCodec();
      final file = await codec.encodeEncrypted(
        await controller.createBackupPayload(),
        passphrase: 'quiet meadow',
      );
      await controller.reset();

      await controller.restoreBackup(
        await codec.open(codec.readEnvelope(file), passphrase: 'quiet meadow'),
      );

      expect(controller.profile!.name, 'Nadia Rahman');
      expect(controller.periodStarts, [
        DateTime(2026, 8, 1),
        DateTime(2026, 7, 4),
      ]);
      expect(controller.lifeStageEntries.single.type, LifeStageType.pregnancy);
    });

    test('breastfeeding and test results survive a round-trip', () async {
      await controller.startBreastfeeding(DateTime(2026, 8, 5));
      await controller.saveOvulationTest(
        DateTime(2026, 8, 12),
        OvulationTestResult.positive,
      );
      await controller.saveOvulationTest(
        DateTime(2026, 8, 3),
        OvulationTestResult.negative,
      );

      final payload = await controller.createBackupPayload();
      expect(payload.data.profile!['breastfeeding_started_on'], '2026-08-05');
      // 3 August carries both a sex entry and a test result in one row.
      expect(payload.data.dailyLogs, hasLength(2));
      await controller.reset();
      await controller.restoreBackup(payload);

      expect(controller.profile!.breastfeedingStartedOn, DateTime(2026, 8, 5));
      expect(controller.ovulationTestEntries, hasLength(2));
      expect(
        controller.ovulationTestOn(DateTime(2026, 8, 12))?.result,
        OvulationTestResult.positive,
      );
      expect(
        controller.intercourseEntryOn(DateTime(2026, 8, 3))?.protectionStatus,
        ProtectionStatus.protected,
      );
    });

    test('a birth date and breastfeeding history round-trip', () async {
      await controller.saveLifeStageEntry(
        LifeStageEntry(
          type: LifeStageType.breastfeeding,
          startDate: DateTime(2023, 10, 12),
          endDate: DateTime(2024, 6, 1),
        ),
      );
      await controller.updateProfile(
        controller.profile!.copyWith(
          isPregnant: true,
          pregnancyStartedOn: DateTime(2026, 3, 1),
          dueDate: DateTime(2026, 8, 25),
          babyBornOn: DateTime(2026, 8, 18),
          postpartumStartedOn: DateTime(2026, 8, 18),
        ),
      );

      final payload = await controller.createBackupPayload();
      await controller.reset();
      await controller.restoreBackup(payload);

      expect(controller.profile!.babyBornOn, DateTime(2026, 8, 18));
      expect(controller.profile!.postpartumAnchor, DateTime(2026, 8, 18));
      expect(
        controller.lifeStageEntries.where(
          (entry) => entry.type == LifeStageType.breastfeeding,
        ),
        hasLength(1),
      );
    });

    test('a backup written before schema 8 restores with nulls', () async {
      final payload = await controller.createBackupPayload();
      final legacyProfile = {...payload.data.profile!}
        ..remove('baby_born_on')
        ..remove('breastfeeding_started_on');
      final legacyPayload = BackupPayload(
        exportedAt: payload.exportedAt,
        data: BackupData(
          profile: legacyProfile,
          periodEntries: payload.data.periodEntries,
          dailyLogs: [
            for (final row in payload.data.dailyLogs)
              {...row}..remove('ovulation_test'),
          ],
          lifeStageEntries: payload.data.lifeStageEntries,
        ),
      );
      const codec = BackupCodec();

      await controller.reset();
      await controller.restoreBackup(
        await codec.open(codec.readEnvelope(codec.encode(legacyPayload))),
      );

      expect(controller.profile!.name, 'Nadia Rahman');
      expect(controller.profile!.babyBornOn, isNull);
      expect(controller.profile!.breastfeedingStartedOn, isNull);
      expect(controller.ovulationTestEntries, isEmpty);
      expect(controller.intercourseEntries, hasLength(1));
    });

    test('a rejected file leaves the current data untouched', () async {
      const codec = BackupCodec();

      expect(
        () => codec.readEnvelope('{"format":"other-app","version":1}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(controller.profile!.name, 'Nadia Rahman');
      expect(controller.periodStarts, hasLength(2));
    });
  });

  testWidgets('profile screen offers export and import', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: DateTime(2026, 8, 11),
        cycleLength: 28,
        periodLength: 5,
      ),
    );

    await tester.pumpWidget(CycleCompassApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Export backup'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });
}
