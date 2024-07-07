import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
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
  late bool isDarkMode = false;

  // @override
  // void initState() {
  //   super.initState();
  //   _loadTheme();
  //   isDarkMode = ThemeNotifier().isDarkMode;
  //   ThemeNotifier().addListener(_onThemeChanged);
  // }

  // @override
  // void dispose() {
  //   ThemeNotifier().removeListener(_onThemeChanged);
  //   super.dispose();
  // }

  // void _onThemeChanged() {
  //   if (mounted) {
  //     setState(() {
  //       isDarkMode = ThemeNotifier().isDarkMode;
  //     });
  //   }
  // }

  // Future<void> _loadTheme() async {
  //   final darkMode = await ThemePreferences.isDarkMode();
  //   if (mounted) {
  //     setState(() {
  //       isDarkMode = darkMode;
  //     });
  //   }
  // }

  // String getCurrentDate() {
  //   initializeDateFormatting('ru_RU', null);
  //   final now = DateTime.now();
  //   final formatter = DateFormat('d MMMM, E', 'ru_RU');
  //   return formatter.format(now);
  // }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 35),
              _buildTitle(),
              SizedBox(height: 40),
              _buildContent(),
              Spacer(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/house.svg',
            color: _selectedIndex == 0
                ? Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Главная',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/calendar_icon.svg',
            color: _selectedIndex == 1
                ? Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Расписание',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/settings.svg',
            color: _selectedIndex == 2
                ? Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Настройки',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Color(0xFF228BE6),
      unselectedItemColor: isDarkMode ? Colors.grey : Colors.black,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      onTap: _onItemTapped,
    );
  }

  Widget _buildTitle() {
    return Container(
      width: 345,
      height: 89,
      padding: EdgeInsets.only(bottom: 20),
      child: Text(
        'Добро пожаловать в\nКУБ.Расписание!',
        style: TextStyle(
          color: Color(0xFF43495D),
          fontFamily: 'Roboto',
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      width: 345,
      height: 443.93,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/rocket.svg',
            width: 245.13,
            height: 319.93,
          ),
          SizedBox(height: 20),
          _buildChoiceButton(),
          SizedBox(height: 10),
          _buildTimetableBeelsButton(),
        ],
      ),
    );
  }

  Widget _buildChoiceButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SearchSchedulePage()),
        );
      },
      child: Container(
        width: 345,
        height: 50,
        decoration: BoxDecoration(
          color: Color(0xFF228BE6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Выбрать моё расписание',
                style: TextStyle(color: Colors.white),
              ),
              SvgPicture.asset(
                'assets/hand.svg',
                width: 24,
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableBeelsButton() {
    return GestureDetector(
      onTap: () {
        // Заготовка для функционала расписания звонков
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Функционал расписания звонков в разработке')),
        );
      },
      child: Container(
        width: 345,
        height: 44,
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/bell.svg',
              width: 24,
              height: 24,
            ),
            SizedBox(width: 10),
            Text('Расписание звонков'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavItem('assets/house.svg', 'Главная', 0),
        _buildNavItem('assets/calendar_icon.svg', 'Расписание', 1),
        _buildNavItem('assets/settings.svg', 'Настройки', 2),
      ],
    );
  }

  Widget _buildNavItem(String iconPath, String label, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        if (index == 2) {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => SettingsPage()),
          // );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            color: _selectedIndex == index ? Color(0xFF228BE6) : Colors.black,
          ),
          SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12,
              color: _selectedIndex == index ? Color(0xFF228BE6) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
