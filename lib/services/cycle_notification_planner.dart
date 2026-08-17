import '../models/user_profile.dart';
import 'cycle_calculator.dart';

const cycleNotificationHour = 9;

class CycleNotificationPlanRequest {
  const CycleNotificationPlanRequest({
    required this.profile,
    required this.periodStarts,
    required this.now,
    required this.through,
  });

  final UserProfile profile;
  final List<DateTime> periodStarts;
  final DateTime now;
  final DateTime through;
}

class PlannedCycleNotification {
  const PlannedCycleNotification({
    required this.id,
    required this.scheduledAt,
    required this.content,
  });

  final int id;
  final DateTime scheduledAt;
  final ({String title, String body, String payload}) content;

  String get title => content.title;
  String get body => content.body;
  String get payload => content.payload;
}

class CycleNotificationPlanner {
  const CycleNotificationPlanner();

  List<PlannedCycleNotification> plan(CycleNotificationPlanRequest request) {
    if (request.profile.isPregnant) {
      return _pregnancyPlan(request);
    }
    return _phasePlan(request);
  }

  List<PlannedCycleNotification> _phasePlan(
    CycleNotificationPlanRequest request,
  ) {
    final notifications = <PlannedCycleNotification>[];
    final firstDay = _day(request.now);
    final lastDay = _day(request.through);
    var previousPhase = _phaseOn(
      firstDay.subtract(const Duration(days: 1)),
      request,
    );
    for (
      var date = firstDay;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      final phase = _phaseOn(date, request);
      if (phase != previousPhase) {
        final notification = _phaseNotification(date, phase);
        if (notification.scheduledAt.isAfter(request.now)) {
          notifications.add(notification);
        }
      }
      previousPhase = phase;
    }
    return notifications;
  }

  CyclePhase _phaseOn(DateTime date, CycleNotificationPlanRequest request) =>
      const CycleCalculator()
          .calculate(
            onDate: date,
            lastPeriodStart: request.profile.lastPeriodStart,
            cycleLength: request.profile.cycleLength,
            periodLength: request.profile.periodLength,
            periodStarts: request.periodStarts,
            nextPeriodDueDate: request.profile.nextPeriodDueDate,
          )
          .phase;

  PlannedCycleNotification _phaseNotification(
    DateTime date,
    CyclePhase phase,
  ) => PlannedCycleNotification(
    id: _phaseNotificationId(date, phase),
    scheduledAt: _notificationTime(date),
    content: _contentFor(phase),
  );

  List<PlannedCycleNotification> _pregnancyPlan(
    CycleNotificationPlanRequest request,
  ) {
    final dueDate = request.profile.dueDate;
    if (dueDate == null) return const [];
    final scheduledAt = _notificationTime(dueDate);
    if (!scheduledAt.isAfter(request.now) ||
        _day(scheduledAt).isAfter(_day(request.through))) {
      return const [];
    }
    return [
      PlannedCycleNotification(
        id: _modeNotificationId(dueDate),
        scheduledAt: scheduledAt,
        content: const (
          title: 'Expected due date',
          body: 'Open Cycle Compass to review your postpartum tracking mode.',
          payload: 'cycle-compass:mode:postpartum',
        ),
      ),
    ];
  }
}

({String title, String body, String payload}) _contentFor(
  CyclePhase phase,
) => switch (phase) {
  CyclePhase.menstruation => (
    title: 'Menstruation phase',
    body: 'Your estimated menstruation phase begins today.',
    payload: 'cycle-compass:phase:menstruation',
  ),
  CyclePhase.follicular => (
    title: 'Follicular phase',
    body: 'Your estimated follicular phase begins today.',
    payload: 'cycle-compass:phase:follicular',
  ),
  CyclePhase.ovulation => (
    title: 'Estimated ovulation day',
    body:
        'Ovulation may happen around today. This estimate is not contraception.',
    payload: 'cycle-compass:phase:ovulation',
  ),
  CyclePhase.luteal => (
    title: 'Luteal phase',
    body: 'Your estimated luteal phase begins today.',
    payload: 'cycle-compass:phase:luteal',
  ),
};

int _phaseNotificationId(DateTime date, CyclePhase phase) =>
    100000000 + _daysSinceEpoch(date) * 10 + phase.index;

int _modeNotificationId(DateTime date) => 200000000 + _daysSinceEpoch(date);

int _daysSinceEpoch(DateTime date) =>
    _day(date).difference(DateTime(1970)).inDays;

DateTime _notificationTime(DateTime date) =>
    DateTime(date.year, date.month, date.day, cycleNotificationHour);

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
