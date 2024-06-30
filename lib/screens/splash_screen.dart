import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/screens/teacher_schedule_page.dart';
import 'package:flutter_application_1/screens/group_schedule_page.dart';
import 'package:flutter_application_1/screens/place_schedule_page.dart';
import 'package:flutter_application_1/utils/schedule_preferences.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isDarkMode = false;
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      _navigateToNextScreen();
    });
  }


  void _navigateToNextScreen() async {
    final savedSchedule = await SchedulePreferences.getSchedule();
    if (savedSchedule == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ScheduleSelectionPage()),
      );
    } else {
      final currentDate = DateTime.now();
      switch (savedSchedule['type']) {
        case 'teacher':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TeacherSchedulePage(
                teacherData: {
                  'id': savedSchedule['id'],
                  'short_name': savedSchedule['name'],
                },
                currentDate: currentDate,
              ),
            ),
          );
          break;
        case 'group':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GroupSchedulePage(
                groupData: {
                  'id': savedSchedule['id'],
                  'name': savedSchedule['name'],
                },
                currentDate: currentDate,
              ),
            ),
          );
          break;
        case 'place':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PlaceSchedulePage(
                placeData: {
                  'id': savedSchedule['id'],
                  'name': savedSchedule['name'],
                },
                currentDate: currentDate,
              ),
            ),
          );
          break;
        default:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ScheduleSelectionPage()),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/loader.gif',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}