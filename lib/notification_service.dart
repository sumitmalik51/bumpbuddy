import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Local notifications for medicine slots and appointment reminders.
/// No-op on web (plugin unsupported there).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Daily reminder time for each medicine slot.
  static const slotTimes = {
    'Morning': (hour: 8, minute: 0),
    'Afternoon': (hour: 13, minute: 0),
    'Evening': (hour: 18, minute: 0),
    'Night': (hour: 21, minute: 0),
  };

  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to the package default (UTC) rather than crash.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  /// Stable 32-bit id from a string key.
  int _id(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  tz.TZDateTime _nextDaily(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static const _medChannel = AndroidNotificationDetails(
    'medicines',
    'Medicine reminders',
    channelDescription: 'Daily reminders for supplements and medicines',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _apptChannel = AndroidNotificationDetails(
    'appointments',
    'Appointment reminders',
    channelDescription: 'Reminders for upcoming appointments, scans and tests',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Cancels and re-creates all medicine notifications from current data.
  Future<void> syncMedicines(List<Medicine> medicines) async {
    if (kIsWeb || !_ready) return;
    // Cancel any previously scheduled med notifications.
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.payload == 'med') await _plugin.cancel(id: p.id);
    }
    for (final m in medicines.where((m) => m.active)) {
      for (final slot in m.slots) {
        final t = slotTimes[slot];
        if (t == null) continue;
        await _plugin.zonedSchedule(
          id: _id('med|${m.id}|$slot'),
          title: 'Time for ${m.name}',
          body: '${m.dose.isEmpty ? '' : '${m.dose} · '}$slot dose',
          scheduledDate: _nextDaily(t.hour, t.minute),
          notificationDetails: const NotificationDetails(android: _medChannel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'med',
        );
      }
    }
  }

  /// Cancels and re-creates appointment reminders (24h before, 9am rule:
  /// if that lands in the past, remind 2h before instead).
  Future<void> syncAppointments(List<Appointment> appointments) async {
    if (kIsWeb || !_ready) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.payload == 'appt') await _plugin.cancel(id: p.id);
    }
    final now = DateTime.now();
    for (final a in appointments.where((a) => !a.done)) {
      var remindAt = a.dateTime.subtract(const Duration(hours: 24));
      if (remindAt.isBefore(now)) {
        remindAt = a.dateTime.subtract(const Duration(hours: 2));
      }
      if (remindAt.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        id: _id('appt|${a.id}'),
        title: 'Upcoming: ${a.title}',
        body:
            '${a.type.label} · ${DateFormat('EEE d MMM, h:mm a').format(a.dateTime)}',
        scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
        notificationDetails: const NotificationDetails(android: _apptChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'appt',
      );
    }
  }
}
