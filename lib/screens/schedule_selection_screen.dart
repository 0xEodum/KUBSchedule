import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'search_schedule_screen.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';

class ScheduleSelectionPage extends StatefulWidget {
  const ScheduleSelectionPage({Key? key}) : super(key: key);

  @override
  _ScheduleSelectionPageState createState() => _ScheduleSelectionPageState();
}

class _ScheduleSelectionPageState extends State<ScheduleSelectionPage> {
  int _selectedIndex = 0;
  bool isDarkMode = false;

  String getCurrentDate() {
    initializeDateFormatting('ru_RU', null);
    final now = DateTime.now();
    final formatter = DateFormat('d MMMM, E', 'ru_RU');
    return formatter.format(now);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: (bool newValue) {
              setState(() {
                isDarkMode = newValue;
              });
            },
          ),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                getCurrentDate(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      isDarkMode
                          ? 'assets/person_white.svg'
                          : 'assets/person.svg',
                      width: 300,
                      height: 300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Расписание не выбрано',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SearchSchedulePage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Выбрать',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: ValueKey<int>(_selectedIndex),
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/teacher_icon.svg',
              color: _selectedIndex == 0
                  ? (isDarkMode ? Colors.white : Colors.blue)
                  : (isDarkMode ? Colors.grey : Colors.black),
            ),
            label: 'Расписание',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/settings.svg',
              color: _selectedIndex == 1
                  ? (isDarkMode ? Colors.white : Colors.blue)
                  : (isDarkMode ? Colors.grey : Colors.black),
            ),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey : Colors.black,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}
