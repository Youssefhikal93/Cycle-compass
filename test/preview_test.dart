import 'dart:io';

import 'package:cycle_compass/app_controller.dart';
import 'package:cycle_compass/main.dart';
import 'package:cycle_compass/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const phoneSize = Size(412, 915);

  setUpAll(_loadRobotoForPreviews);

  testWidgets('renders onboarding preview', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    const previewKey = ValueKey('onboarding-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/onboarding.png'),
    );
  });

  testWidgets('renders home preview with initials avatar', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
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
    await controller.setNextPeriodDueDate(
      DateTime.now().add(const Duration(days: 20)),
    );
    const previewKey = ValueKey('home-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('renders postpartum mode preview', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
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
    const previewKey = ValueKey('postpartum-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/postpartum.png'),
    );
  });

  testWidgets('renders postpartum calendar color preview', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
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
      dueDate: today.subtract(const Duration(days: 10)),
    );
    const previewKey = ValueKey('postpartum-calendar-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/calendar-postpartum.png'),
    );
  });

  testWidgets('renders editable profile preview', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
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
    const previewKey = ValueKey('profile-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/profile.png'),
    );
  });

  testWidgets('renders irregular-cycle calendar guidance', (tester) async {
    await tester.binding.setSurfaceSize(phoneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController.inMemory();
    final now = DateTime.now();
    final latest = DateTime(now.year, now.month, 1);
    await controller.completeOnboarding(
      UserProfile(
        name: 'Nadia Rahman',
        dateOfBirth: DateTime(1997, 4, 16),
        lastPeriodStart: latest.subtract(const Duration(days: 16)),
        cycleLength: 28,
        periodLength: 5,
      ),
    );
    await controller.logPeriodStart(latest);
    await controller.updatePeriodEnd(
      latest,
      latest.add(const Duration(days: 5)),
    );
    await controller.setNextPeriodDueDate(latest.add(const Duration(days: 20)));
    const previewKey = ValueKey('calendar-preview');

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: CycleCompassApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).hitTestable(),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(previewKey),
      matchesGoldenFile('goldens/calendar-irregular.png'),
    );
  });
}

Future<void> _loadRobotoForPreviews() async {
  var directory = File(Platform.resolvedExecutable).parent;
  File? regular;
  File? medium;
  File? bold;
  for (var i = 0; i < 9; i++) {
    final fontDirectory = p.join(
      directory.path,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
    );
    final candidate = File(p.join(fontDirectory, 'Roboto-Regular.ttf'));
    if (candidate.existsSync()) {
      regular = candidate;
      medium = File(p.join(fontDirectory, 'Roboto-Medium.ttf'));
      bold = File(p.join(fontDirectory, 'Roboto-Bold.ttf'));
      break;
    }
    directory = directory.parent;
  }
  if (regular == null) return;
  final loader = FontLoader('Roboto')
    ..addFont(_readFont(regular))
    ..addFont(_readFont(medium!))
    ..addFont(_readFont(bold!));
  await loader.load();
  final materialIcons = File(
    p.join(regular.parent.path, 'MaterialIcons-Regular.otf'),
  );
  await (FontLoader('MaterialIcons')..addFont(_readFont(materialIcons))).load();
}

Future<ByteData> _readFont(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.sublistView(bytes);
}
