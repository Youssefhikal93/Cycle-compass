import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/user_profile.dart';
import 'clock.dart';
import 'cycle_notification_planner.dart';

const _notificationPayloadPrefix = 'cycle-compass:';
const _notificationHorizon = Duration(days: 180);
const _timeZoneChannel = MethodChannel('cycle_compass/timezone');

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'cycle_phase_reminders',
    'Cycle reminders',
    channelDescription: 'Estimated cycle phases and tracking-mode changes',
    importance: Importance.high,
    priority: Priority.high,
    visibility: NotificationVisibility.private,
    category: AndroidNotificationCategory.reminder,
  ),
);

class CycleNotificationService {
  CycleNotificationService()
    : _notifications = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  final CycleNotificationPlanner _planner = const CycleNotificationPlanner();
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      timezone_data.initializeTimeZones();
      final deviceTimeZone = await _timeZoneChannel.invokeMethod<String>(
        'getTimeZone',
      );
      if (deviceTimeZone == null || deviceTimeZone.isEmpty) {
        throw StateError('Android did not return a device time zone.');
      }
      timezone.setLocalLocation(timezone.getLocation(deviceTimeZone));
      _initialized =
          await _notifications.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_notification'),
            ),
          ) ??
          false;
    } on Object catch (error, stackTrace) {
      _initialized = false;
      debugPrint('Cycle notification setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> notificationsAllowed() async {
    if (!_initialized) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> reconcile({
    required UserProfile profile,
    required List<DateTime> periodStarts,
  }) async {
    if (!_initialized) return;
    await cancelPendingCycleNotifications();
    final now = appNow();
    final through = profile.isPregnant && profile.dueDate != null
        ? profile.dueDate!
        : now.add(_notificationHorizon);
    final planned = _planner.plan(
      CycleNotificationPlanRequest(
        profile: profile,
        periodStarts: periodStarts,
        now: now,
        through: through,
      ),
    );
    for (final notification in planned) {
      await _schedule(notification);
    }
  }

  Future<void> cancelPendingCycleNotifications() async {
    if (!_initialized) return;
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(_notificationPayloadPrefix) ==
          true) {
        await _notifications.cancel(id: notification.id);
      }
    }
  }

  Future<void> showPregnancyMode() => _showModeNotification(
    id: 300000001,
    title: 'Pregnancy mode is on',
    body: 'Cycle phase estimates and reminders are paused.',
    payload: 'cycle-compass:mode:pregnancy',
  );

  Future<void> showPostpartumMode() => _showModeNotification(
    id: 300000002,
    title: 'Postpartum tracking is active',
    body: 'Cycle estimates stay paused until the first new period.',
    payload: 'cycle-compass:mode:postpartum',
  );

  Future<void> showCycleTrackingResumed() => _showModeNotification(
    id: 300000003,
    title: 'Cycle tracking resumed',
    body: 'Estimated phase reminders have been scheduled again.',
    payload: 'cycle-compass:mode:cycle',
  );

  Future<void> clear() =>
      _initialized ? _notifications.cancelAll() : Future<void>.value();

  Future<void> _schedule(PlannedCycleNotification notification) =>
      _notifications.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: timezone.TZDateTime(
          timezone.local,
          notification.scheduledAt.year,
          notification.scheduledAt.month,
          notification.scheduledAt.day,
          notification.scheduledAt.hour,
        ),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notification.payload,
      );

  Future<void> _showModeNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) => _notifications.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _notificationDetails,
    payload: payload,
  );
}
