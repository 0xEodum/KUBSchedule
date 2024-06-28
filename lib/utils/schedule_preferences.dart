import 'package:shared_preferences/shared_preferences.dart';

class SchedulePreferences {
  static const String _keyScheduleType = 'scheduleType';
  static const String _keyScheduleId = 'scheduleId';
  static const String _keyScheduleName = 'scheduleName';

  static Future<void> saveSchedule(String type, int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScheduleType, type);
    await prefs.setInt(_keyScheduleId, id);
    await prefs.setString(_keyScheduleName, name);
  }

  static Future<Map<String, dynamic>?> getSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(_keyScheduleType);
    final id = prefs.getInt(_keyScheduleId);
    final name = prefs.getString(_keyScheduleName);

    if (type != null && id != null && name != null) {
      return {
        'type': type,
        'id': id,
        'name': name,
      };
    }
    return null;
  }

  static Future<void> clearSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyScheduleType);
    await prefs.remove(_keyScheduleId);
    await prefs.remove(_keyScheduleName);
  }
}