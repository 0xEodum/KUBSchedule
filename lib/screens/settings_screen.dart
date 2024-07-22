import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/screens/search_schedule_screen.dart';
import 'package:flutter_application_1/utils/NotificationPreferences.dart';
import 'package:flutter_application_1/utils/NotificationService.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({
    Key? key, 
    required this.onThemeChanged, 
    required this.isDarkMode
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late bool isDarkMode;
  String selectedLanguage = 'Русский';
  late TimeOfDay todayNotificationTime;
  late TimeOfDay tomorrowNotificationTime;
  int _selectedIndex = 2;

  late AnimationController _themeAnimationController;
  late AnimationController _languageAnimationController;
  late Animation<double> _themeAnimation;
  late Animation<double> _languageAnimation;

  bool isThemePanelVisible = false;
  bool isLanguagePanelVisible = false;

  

  @override
  void initState() {
    super.initState();
    _loadTheme();

    _themeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _languageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _themeAnimation = Tween<double>(begin: 0, end: 1).animate(_themeAnimationController);
    _languageAnimation = Tween<double>(begin: 0, end: 1).animate(_languageAnimationController);

    _loadNotificationTimes();
    NotificationService().init();
  }

  Future<void> _loadNotificationTimes() async {
    todayNotificationTime = await NotificationPreferences.getNotificationTime(true);
    tomorrowNotificationTime = await NotificationPreferences.getNotificationTime(false);
    setState(() {});
    await NotificationService().scheduleNotifications();
  }

  Future<void> _selectNotificationTime(bool isToday) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: isToday ? todayNotificationTime : tomorrowNotificationTime,
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: isDarkMode
            ? ThemeData.dark().copyWith(
                colorScheme: ColorScheme.dark(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                  surface: Color(0xFF383D4E),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: Color(0xFF383D4E),
              )
            : ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue,
                ),
              ),
        child: child!,
      );
    },
  );

  if (picked != null) {
    setState(() {
      if (isToday) {
        todayNotificationTime = picked;
      } else {
        tomorrowNotificationTime = picked;
      }
    });
    await NotificationPreferences.saveNotificationTime(isToday, picked);
    await NotificationService().scheduleNotifications();
  }
}

  Future<void> _loadTheme() async {
    isDarkMode = await ThemePreferences.isDarkMode();
    setState(() {});
  }

  Future<void> _toggleTheme(bool value) async {
    await ThemeNotifier().toggleTheme();
    setState(() {
      isDarkMode = value;
    });
    _toggleThemePanel();
  }

  @override
  void dispose() {
    _themeAnimationController.dispose();
    _languageAnimationController.dispose();
    super.dispose();
  }

  void _toggleThemePanel() {
    setState(() {
      isThemePanelVisible = !isThemePanelVisible;
      if (isThemePanelVisible) {
        _themeAnimationController.forward();
      } else {
        _themeAnimationController.reverse();
      }
    });
  }

  void _toggleLanguagePanel() {
    setState(() {
      isLanguagePanelVisible = !isLanguagePanelVisible;
      if (isLanguagePanelVisible) {
        _languageAnimationController.forward();
      } else {
        _languageAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Color(0xFFF4F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Настройки',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildSectionTitle('Уведомления'),
                    _buildNotificationBlock(),
                    SizedBox(height: 24),
                    _buildSectionTitle('Системные'),
                    _buildSystemBlock(),
                  ],
                ),
              ),
            ),
            if (isThemePanelVisible || isLanguagePanelVisible)
              GestureDetector(
                onTap: () {
                  if (isThemePanelVisible) _toggleThemePanel();
                  if (isLanguagePanelVisible) _toggleLanguagePanel();
                },
                child: Container(color: Colors.black54),
              ),
            _buildThemePanel(),
            _buildLanguagePanel(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildThemePanel() {
  return AnimatedBuilder(
    animation: _themeAnimation,
    builder: (context, child) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: MediaQuery.of(context).size.height * 0.4 * _themeAnimation.value,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildPanelHeader('Выберите тему'),
                _buildThemeOption('Светлая', false),
                _buildThemeOption('Темная', true),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildLanguagePanel() {
  return AnimatedBuilder(
    animation: _languageAnimation,
    builder: (context, child) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: MediaQuery.of(context).size.height * 0.5 * _languageAnimation.value,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildPanelHeader('Выберите язык'),
                _buildLanguageOption('Русский'),
                _buildLanguageOption('English'),
                _buildLanguageOption('հայերեն'),
                _buildLanguageOption('қазақ'),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildPanelHeader(String title) {
  return Column(
    children: [
      GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            if (isThemePanelVisible) _toggleThemePanel();
            if (isLanguagePanelVisible) _toggleLanguagePanel();
          }
        },
        child: SizedBox(
          height: 40,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    ],
  );
}

 Widget _buildThemeOption(String title, bool isDark) {
  return RadioListTile<bool>(
    title: Text(
      title,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    ),
    value: isDark,
    groupValue: isDarkMode,
    onChanged: (bool? value) {
      if (value != null) {
        _toggleTheme(value);
      }
    },
    activeColor: Colors.blue,
    fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.blue;
      }
      return isDarkMode ? Colors.white : Colors.black54;
    }),
  );
}

Widget _buildLanguageOption(String language) {
  return RadioListTile<String>(
    title: Text(
      language,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    ),
    value: language,
    groupValue: selectedLanguage,
    onChanged: (String? value) {
      if (value != null) {
        setState(() {
          selectedLanguage = value;
        });
        _toggleLanguagePanel();
      }
    },
    activeColor: Colors.blue,
    fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.blue;
      }
      return isDarkMode ? Colors.white : Colors.black54;
    }),
  );
}

  void _showThemeBottomSheet() {
    _toggleThemePanel();
  }

  void _showLanguageBottomSheet() {
    _toggleLanguagePanel();
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/house.svg',
            color: _selectedIndex == 0
                ? const Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Главная',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/calendar_icon.svg',
            color: _selectedIndex == 1
                ? const Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Расписание',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/settings.svg',
            color: _selectedIndex == 2
                ? const Color(0xFF228BE6)
                : (isDarkMode ? Colors.grey : Colors.black),
          ),
          label: 'Настройки',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF228BE6),
      unselectedItemColor: isDarkMode ? Colors.grey : Colors.black,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      onTap: _onItemTapped,
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ScheduleSelectionPage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchSchedulePage()
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildNotificationBlock() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildNotificationItem('Занятия на сегодня', todayNotificationTime, () => _selectNotificationTime(true)),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          _buildNotificationItem('Занятия на завтра', tomorrowNotificationTime, () => _selectNotificationTime(false)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF969696),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Row(
              children: [
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 4),
                SvgPicture.asset(
                  'assets/clock.svg',
                  color: isDarkMode ? Colors.white : Colors.black,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBlock() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSystemItem('Тема', isDarkMode ? 'Темная' : 'Светлая', _showThemeBottomSheet),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          _buildSystemItem('Язык', selectedLanguage, _showLanguageBottomSheet),
        ],
      ),
    );
  }

 Widget _buildSystemItem(String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, String title) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: title == 'Занятия на сегодня' ? todayNotificationTime : tomorrowNotificationTime,
    );
    if (picked != null) {
      setState(() {
        if (title == 'Занятия на сегодня') {
          todayNotificationTime = picked;
        } else {
          tomorrowNotificationTime = picked;
        }
      });
    }
  }

}