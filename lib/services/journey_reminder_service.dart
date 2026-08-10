import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class JourneyReminderService {
  JourneyReminderService._();

  static final JourneyReminderService instance = JourneyReminderService._();
  static const _firstNotificationId = 7200;
  static const _days = 30;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> initialise() async {
    if (_initialised) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _initialised = true;
    } on Object catch (error) {
      debugPrint('Journey reminders are unavailable: $error');
    }
  }

  Future<bool> scheduleThirtyDays({
    required String title,
    required List<String> dailyPrompts,
    required String channelName,
    required String channelDescription,
  }) async {
    await initialise();
    if (!_initialised || dailyPrompts.length != _days) return false;
    try {
      final android = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      final apple = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if ((android ?? apple) == false) return false;

      await cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      for (var index = 0; index < _days; index++) {
        await _plugin.zonedSchedule(
          id: _firstNotificationId + index,
          title: title,
          body: dailyPrompts[index],
          scheduledDate: first.add(Duration(days: index)),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'first_30_days',
              channelName,
              channelDescription: channelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'first-30-days:${index + 1}',
        );
      }
      return true;
    } on Object catch (error) {
      debugPrint('Journey reminders could not be scheduled: $error');
      return false;
    }
  }

  Future<void> cancelAll() async {
    await initialise();
    if (!_initialised) return;
    for (var index = 0; index < _days; index++) {
      await _plugin.cancel(id: _firstNotificationId + index);
    }
  }
}
