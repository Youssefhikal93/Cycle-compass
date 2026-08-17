import 'package:cycle_compass/models/user_profile.dart';
import 'package:cycle_compass/services/cycle_notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = CycleNotificationPlanner();

  test('regular tracking schedules every estimated phase transition', () {
    final profile = _profile(lastPeriodStart: DateTime(2026, 8, 1));

    final notifications = planner.plan(
      CycleNotificationPlanRequest(
        profile: profile,
        periodStarts: [profile.lastPeriodStart],
        now: DateTime(2026, 8, 1, 8),
        through: DateTime(2026, 8, 29),
      ),
    );

    expect(notifications.map((notification) => notification.scheduledAt), [
      DateTime(2026, 8, 1, 9),
      DateTime(2026, 8, 6, 9),
      DateTime(2026, 8, 14, 9),
      DateTime(2026, 8, 15, 9),
      DateTime(2026, 8, 29, 9),
    ]);
    expect(
      notifications
          .singleWhere(
            (notification) => notification.title == 'Estimated ovulation day',
          )
          .body,
      contains('not contraception'),
    );
  });

  test('a phase start earlier today is not scheduled late', () {
    final profile = _profile(lastPeriodStart: DateTime(2026, 8, 1));

    final notifications = planner.plan(
      CycleNotificationPlanRequest(
        profile: profile,
        periodStarts: [profile.lastPeriodStart],
        now: DateTime(2026, 8, 1, 10),
        through: DateTime(2026, 8, 6),
      ),
    );

    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Follicular phase');
    expect(notifications.single.scheduledAt, DateTime(2026, 8, 6, 9));
  });

  test('pregnancy schedules only the expected due-date mode reminder', () {
    final profile = _profile(
      lastPeriodStart: DateTime(2026, 5, 1),
      isPregnant: true,
      dueDate: DateTime(2026, 12, 1),
    );

    final notifications = planner.plan(
      CycleNotificationPlanRequest(
        profile: profile,
        periodStarts: [profile.lastPeriodStart],
        now: DateTime(2026, 8, 1),
        through: DateTime(2026, 12, 1),
      ),
    );

    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Expected due date');
    expect(notifications.single.payload, 'cycle-compass:mode:postpartum');
  });
}

UserProfile _profile({
  required DateTime lastPeriodStart,
  bool isPregnant = false,
  DateTime? dueDate,
}) => UserProfile(
  name: 'Nadia Rahman',
  dateOfBirth: DateTime(1997, 4, 16),
  lastPeriodStart: lastPeriodStart,
  cycleLength: 28,
  periodLength: 5,
  isPregnant: isPregnant,
  dueDate: dueDate,
);
