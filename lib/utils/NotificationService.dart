import 'package:flutter/material.dart';
import 'package:flutter_application_1/utils/NotificationPreferences.dart';
import 'package:flutter_application_1/utils/schedule_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
  final AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  tz.initializeTimeZones();
}

  Future<void> scheduleNotifications() async {
    await cancelAllNotifications();

    final schedule = await SchedulePreferences.getSchedule();
    if (schedule == null) return;

    final todayTime = await NotificationPreferences.getNotificationTime(true);
    final tomorrowTime = await NotificationPreferences.getNotificationTime(false);

    await _scheduleNotification(0, todayTime, false);

    await _scheduleNotification(1, tomorrowTime, true);
  }

  Future<void> _scheduleNotification(int id, TimeOfDay notificationTime, bool isTomorrow) async {
  final now = DateTime.now();
  var scheduledDate = DateTime(
    now.year,
    now.month,
    now.day,
    notificationTime.hour,
    notificationTime.minute,
  );

  if (isTomorrow) {
    scheduledDate = scheduledDate.add(Duration(days: 1));
  } else if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(Duration(days: 1));
  }

  final lessons = await _fetchLessons(isTomorrow);
  if (lessons.isEmpty) {
    print('No lessons for ${isTomorrow ? "tomorrow" : "today"}, skipping notification.');
    return;
  }

  final notificationTitle = isTomorrow ? 'Расписание на завтра' : 'Расписание на сегодня';
  final notificationBody = _formatLessonsForNotification(lessons);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    notificationTitle,
    notificationBody,
    tz.TZDateTime.from(scheduledDate, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'schedule_channel',
        'Schedule Notifications',
        channelDescription: 'Notifications for daily schedule',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: IOSNotificationDetails(),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

  Future<List<dynamic>> _fetchLessons(bool isTomorrow) async {
    final schedule = await SchedulePreferences.getSchedule();
    if (schedule == null) return [];

    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final currentDate = DateTime.now().add(Duration(days: isTomorrow ? 1 : 0));
    final dateString = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

    String queryParam;
    switch (schedule['type']) {
      case 'teacher':
        queryParam = 'teacher=${schedule['id']}';
        break;
      case 'group':
        queryParam = 'group=${schedule['id']}';
        break;
      case 'place':
        queryParam = 'place=${schedule['id']}';
        break;
      default:
        throw Exception('Unknown schedule type');
    }

    final url = Uri.parse(
        '$apiUrl/api/timetable/lessons/viewer?start_date=$dateString&end_date=$dateString&$queryParam');

    try {
      final response = await http.get(
        url,
        headers: {headerKey: headerValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['data'] as List<dynamic>;
      } else {
        print('Failed to load lessons: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching lessons: $e');
      return [];
    }
  }

  String _formatLessonsForNotification(List<dynamic> lessons) {
    if (lessons.isEmpty) {
      return 'На сегодня занятий нет.';
    }
    return lessons
        .map((lesson) =>
            "${lesson['number']}. ${lesson['discipline']['short_name']} (${lesson['type']['short_name']})")
        .join('\n');
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}