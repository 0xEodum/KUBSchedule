import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const String _keyTodayHour = 'today_notification_hour';
  static const String _keyTodayMinute = 'today_notification_minute';
  static const String _keyTomorrowHour = 'tomorrow_notification_hour';
  static const String _keyTomorrowMinute = 'tomorrow_notification_minute';

  static Future<void> saveNotificationTime(bool isToday, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    if (isToday) {
      await prefs.setInt(_keyTodayHour, time.hour);
      await prefs.setInt(_keyTodayMinute, time.minute);
    } else {
      await prefs.setInt(_keyTomorrowHour, time.hour);
      await prefs.setInt(_keyTomorrowMinute, time.minute);
    }
  }

  static Future<TimeOfDay> getNotificationTime(bool isToday) async {
    final prefs = await SharedPreferences.getInstance();
    if (isToday) {
      final hour = prefs.getInt(_keyTodayHour) ?? 6; // Время по умолчанию: 6:00
      final minute = prefs.getInt(_keyTodayMinute) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    } else {
      final hour = prefs.getInt(_keyTomorrowHour) ?? 20; // Время по умолчанию: 20:00
      final minute = prefs.getInt(_keyTomorrowMinute) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
  }
}