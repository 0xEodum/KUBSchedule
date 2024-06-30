import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({Key? key, required this.onThemeChanged, required this.isDarkMode}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool isDarkMode;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Container(
          width: 344,
          padding: EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(top: 10, left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Приложение',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Тема',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/sun_icon.svg',
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              Switch(
                                value: isDarkMode,
                                onChanged: (value) {
                                  setState(() {
                                    isDarkMode = value;
                                  });
                                  widget.onThemeChanged(value);
                                },
                                activeColor: Colors.white,
                                inactiveThumbColor: Colors.black,
                                activeTrackColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.shade300,
                              ),
                              SvgPicture.asset(
                                'assets/moon_white.svg',
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pop(context);
    }
  }
}