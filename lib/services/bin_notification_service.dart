import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules one weekly reminder on the evening before collection day.
class BinNotificationService {
  BinNotificationService._();

  static final BinNotificationService instance = BinNotificationService._();
  static const _notificationId = 7101;
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
      debugPrint('Notifications are unavailable on this platform: $error');
    }
  }

  Future<bool> requestPermission() async {
    await initialise();
    if (!_initialised) return false;
    try {
      final android = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      final ios = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return android ?? ios ?? true;
    } on Object catch (error) {
      debugPrint('Notification permission could not be requested: $error');
      return false;
    }
  }

  Future<bool> scheduleWeeklyReminder({
    required int collectionWeekday,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await requestPermission()) return false;
    try {
      await _plugin.cancel(id: _notificationId);
      final reminderWeekday = collectionWeekday == DateTime.monday
          ? DateTime.sunday
          : collectionWeekday - 1;
      final scheduled = _nextWeekdayAt(reminderWeekday, 18);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'bin_night_reminders',
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'bin-night',
      );
      return true;
    } on Object catch (error) {
      debugPrint('Bin reminder could not be scheduled: $error');
      return false;
    }
  }

  Future<void> cancelReminder() async {
    await initialise();
    if (!_initialised) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } on Object catch (error) {
      debugPrint('Bin reminder could not be cancelled: $error');
    }
  }

  tz.TZDateTime _nextWeekdayAt(int weekday, int hour) {
    var candidate = tz.TZDateTime.now(tz.local);
    candidate = tz.TZDateTime(
      tz.local,
      candidate.year,
      candidate.month,
      candidate.day,
      hour,
    );
    while (candidate.weekday != weekday ||
        !candidate.isAfter(tz.TZDateTime.now(tz.local))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
