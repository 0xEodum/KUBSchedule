import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/screens/search_schedule_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ScheduleType { teacher, group, place }

class UniversalSchedulePage extends StatefulWidget {
  final Map<String, dynamic> targetData;
  final ScheduleType scheduleType;

  const UniversalSchedulePage({
    Key? key,
    required this.targetData,
    required this.scheduleType,
  }) : super(key: key);

  @override
  _UniversalSchedulePageState createState() => _UniversalSchedulePageState();
}

class _UniversalSchedulePageState extends State<UniversalSchedulePage> with SingleTickerProviderStateMixin {
  bool isCalendarVisible = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, List<dynamic>> lessonsCache = {};
  bool isLoading = true;
  late DateTime _currentDate;
  int _selectedIndex = 1;
  late DateTime earliestDate;
  late DateTime latestDate;
  late bool isDarkMode;
  late AnimationController _calendarAnimationController;
  late Animation<double> _calendarAnimation;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _currentDate = DateTime.now();
    isDarkMode = ThemeNotifier().isDarkMode;
    ThemeNotifier().addListener(_onThemeChanged);
    earliestDate = _currentDate.subtract(const Duration(days: 7));
    latestDate = _currentDate.add(const Duration(days: 7));
    _calendarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _calendarAnimation = Tween<double>(begin: 0, end: 1).animate(_calendarAnimationController);
    fetchLessonsForRange(earliestDate, latestDate);
  }

  Future<void> _loadTheme() async {
    final darkMode = await ThemePreferences.isDarkMode();
    if (mounted) {
      setState(() {
        isDarkMode = darkMode;
      });
    }
  }

  @override
  void dispose() {
    _calendarAnimationController.dispose();
    ThemeNotifier().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        isDarkMode = ThemeNotifier().isDarkMode;
      });
    }
  }

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  // ... (остальные методы initState, dispose, _loadTheme, _onThemeChanged остаются без изменений)

  Future<void> fetchLessonsForRange(DateTime start, DateTime end, {bool clearCache = false}) async {
    setState(() {
      isLoading = true;
    });

    if (clearCache) {
      lessonsCache.clear();
    } else {
      lessonsCache.removeWhere((key, value) {
        final date = DateTime.parse(key);
        return date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      });
    }

    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final startString = DateFormat('yyyy-MM-dd').format(start);
    final endString = DateFormat('yyyy-MM-dd').format(end);
    
    String queryParam;
    switch (widget.scheduleType) {
      case ScheduleType.teacher:
        queryParam = 'teacher=${widget.targetData['id']}';
        break;
      case ScheduleType.group:
        queryParam = 'group=${widget.targetData['id']}';
        break;
      case ScheduleType.place:
        queryParam = 'place=${widget.targetData['id']}';
        break;
    }
    
    final url = Uri.parse('$apiUrl/api/timetable/lessons/viewer?start_date=$startString&end_date=$endString&$queryParam');

    try {
      final response = await http.get(
        url,
        headers: {headerKey: headerValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final lessons = data['data'] as List<dynamic>;
        
        for (var lesson in lessons) {
          final lessonDate = lesson['date'] as String;
          if (!lessonsCache.containsKey(lessonDate)) {
            lessonsCache[lessonDate] = [];
          }
          lessonsCache[lessonDate]!.add(lesson);
        }

        earliestDate = start;
        latestDate = end;
      } else {
        print('Failed to load lessons: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching lessons: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _onSwipeLeft() {
  setState(() {
    if (_currentDate.weekday == DateTime.saturday) {
      // Если сейчас суббота, переходим на понедельник следующей недели
      _currentDate = _currentDate.add(const Duration(days: 2));
    } else {
      // В остальных случаях просто переходим на следующий день
      _currentDate = _currentDate.add(const Duration(days: 1));
    }
  });
  _updateLessonsIfNeeded();
}

void _onSwipeRight() {
  setState(() {
    if (_currentDate.weekday == DateTime.monday) {
      // Если сейчас понедельник, переходим на субботу предыдущей недели
      _currentDate = _currentDate.subtract(const Duration(days: 2));
    } else {
      // В остальных случаях просто переходим на предыдущий день
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    }
  });
  _updateLessonsIfNeeded();
}

  void _updateLessonsIfNeeded() {
    if (_currentDate.isAfter(latestDate) || _currentDate.isBefore(earliestDate)) {
      fetchLessonsForRange(
        _currentDate.subtract(const Duration(days: 7)),
        _currentDate.add(const Duration(days: 7)),
      );
    }
  }


  // ... (методы _onSwipeLeft, _onSwipeRight, _onDaySelected, _toggleCalendar остаются без изменений)

  @override
  Widget build(BuildContext context) {
    final currentDateString = DateFormat('yyyy-MM-dd').format(_currentDate);
    final lessonsForCurrentDate = lessonsCache[currentDateString] ?? [];

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildDateNavigator(),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! < -1000) {
                        _onSwipeLeft();
                      } else if (details.primaryVelocity! > 1000) {
                        _onSwipeRight();
                      }
                    },
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildSchedule(lessonsForCurrentDate),
                  ),
                ),
              ],
            ),
            if (isCalendarVisible)
              GestureDetector(
                onTap: _toggleCalendar,
                child: Container(
                  color: Colors.black54,
                ),
              ),
            AnimatedBuilder(
              animation: _calendarAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.6 * _calendarAnimation.value,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: _buildCalendar(),
                    ),
                  ),
                );
              },
            ),
          ],
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

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ScheduleSelectionPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: (bool newValue) {
              setState(() {
                isDarkMode = newValue;
              });
              _saveTheme(newValue);
            },
          ),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _currentDate = selectedDay;
      isCalendarVisible = false;
    });
    fetchLessonsForRange(
      selectedDay.subtract(const Duration(days: 7)),
      selectedDay.add(const Duration(days: 7)),
      clearCache: true
    );
  }

  void _toggleCalendar() {
    setState(() {
      isCalendarVisible = !isCalendarVisible;
      if (isCalendarVisible) {
        _calendarAnimationController.forward();
      } else {
        _calendarAnimationController.reverse();
      }
    });
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      focusedDay: _currentDate,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) {
        return isSameDay(_currentDate, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _currentDate = selectedDay;
          _toggleCalendar();
        });
        _updateLessonsIfNeeded();
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      onPageChanged: (focusedDay) {
        _currentDate = focusedDay;
      },
      locale: 'ru_RU',
      startingDayOfWeek: StartingDayOfWeek.monday,
      daysOfWeekVisible: true,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      calendarStyle: CalendarStyle(
        weekendTextStyle: TextStyle(color: isDarkMode ? Colors.red[300] : Colors.red),
        outsideTextStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey),
        todayDecoration: BoxDecoration(
          color: isDarkMode ? Colors.blue[700] : Colors.blue[200],
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
        ),
        selectedDecoration: BoxDecoration(
          color: const Color.fromRGBO(34, 139, 230, 1),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
        ),
        defaultTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekendStyle: TextStyle(color: isDarkMode ? Colors.red[300] : Colors.red),
        weekdayStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildHeader() {
    String iconAsset;
    String headerText;
    switch (widget.scheduleType) {
      case ScheduleType.teacher:
        iconAsset = 'assets/teacher_icon.svg';
        headerText = widget.targetData['short_name'];
        break;
      case ScheduleType.group:
        iconAsset = 'assets/group_icon.svg';
        headerText = widget.targetData['name'];
        break;
      case ScheduleType.place:
        iconAsset = 'assets/place_icon.svg';
        headerText = widget.targetData['name'];
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchSchedulePage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SvgPicture.asset(iconAsset, width: 24, height: 24, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SvgPicture.asset('assets/search.svg', width: 24, height: 24, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
  final now = DateTime.now();
  final isToday = _currentDate.year == now.year && _currentDate.month == now.month && _currentDate.day == now.day;
  
  // Находим понедельник текущей недели
  final monday = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
  
  final weekDays = List.generate(6, (index) => monday.add(Duration(days: index)));

  return GestureDetector(
    onTap: _toggleCalendar,
    child: Container(
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isToday)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentDate = now;
                    });
                  },
                  child: Text(
                    'Сегодня',
                    style: TextStyle(color: Color(0xFF228BE6), fontWeight: FontWeight.bold),
                  ),
                )
              else
                SizedBox(),
              Text(
                DateFormat('MMMM yyyy', 'ru_RU').format(_currentDate),
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF228BE6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              final isSelected = day.day == _currentDate.day && day.month == _currentDate.month;
              final isActualToday = day.year == now.year && day.month == now.month && day.day == now.day;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentDate = day;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActualToday 
                        ? Colors.blue 
                        : (isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'ru_RU').format(day).toUpperCase(), 
                        style: TextStyle(
                          fontSize: 12,
                          color: isActualToday ? Colors.white : null,
                        ),
                      ),
                      Text(
                        day.day.toString(), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActualToday ? Colors.white : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSchedule(List<dynamic> lessonsForCurrentDate) {
  if (lessonsForCurrentDate.isEmpty) {
    return _buildNoDataFound();
  }

  lessonsForCurrentDate.sort((a, b) => a['number'].compareTo(b['number']));

  List<Widget> scheduleWidgets = [];
  int previousLessonNumber = 0;

  for (var lesson in lessonsForCurrentDate) {
    int currentLessonNumber = lesson['number'];

    if (previousLessonNumber != 0) {
      int freeSlots = currentLessonNumber - previousLessonNumber - 1;
      if (freeSlots > 0) {
        scheduleWidgets.add(_buildFreeTimeCard(previousLessonNumber + 1, freeSlots));
      }
    }

    scheduleWidgets.add(_buildLessonCard(lesson));
    previousLessonNumber = currentLessonNumber;
  }

  return ListView(children: scheduleWidgets);
}

Widget _buildNoDataFound() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          isDarkMode ? 'assets/person_white.svg' : 'assets/person.svg',
          width: 300,
          height: 300,
        ),
        const SizedBox(height: 20),
        Text(
          'Занятий не найдено',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildFreeTimeCard(int startNumber, int slots) {
  final startTime = _getStartTime(startNumber);
  final endTime = _getEndTime(startNumber + slots - 1);
  final duration = slots * 80; // 80 минут на одно занятие

  return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 80,
      child: Row(
        children: [
          // Блок с временем
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startTime, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                Text(endTime, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Карточка свободного времени
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/free_time_icon.svg',
                                width: 20,
                                height: 20,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Свободное время',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$duration мин',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildLessonCard(Map<String, dynamic> lesson) {
  final type = lesson['type'];
  final startTime = _getStartTime(lesson['number']);
  final endTime = _getEndTime(lesson['number']);
  final color = Color(int.parse(type['color'].substring(1, 7), radix: 16) + 0xFF000000);
  final groups = lesson['groups'] as List;
  final firstGroup = groups.isNotEmpty ? groups[0]['name'] : '';
  final additionalGroups = groups.length > 1 ? groups.length - 1 : 0;

  return Padding(
    padding: const EdgeInsets.only(bottom: 15, top: 15),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 100,
      child: Row(
        children: [
          // Блок с временем
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startTime, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                Text(endTime, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Карточка занятия
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Левая цветная граница
                      Container(
                        width: 30,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Center(
                            child: Text(
                              type['short_name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Основное содержимое карточки
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lesson['discipline']['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color.fromARGB(255, 195, 255, 212).withOpacity(1),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Row(
                                          children: [
                                            SvgPicture.asset(
                                              'assets/group_icon.svg',
                                              width: 16,
                                              height: 16,
                                              color: isDarkMode ? Colors.white70 : Color.fromARGB(255, 77, 189, 116),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              firstGroup,
                                              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (additionalGroups > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Color.fromARGB(255, 139, 235, 142).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '+$additionalGroups',
                                            style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color.fromARGB(255, 255, 237, 220).withOpacity(1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/place_icon.svg',
                                          width: 16,
                                          height: 16,
                                          color: isDarkMode ? Colors.white70 : Color.fromARGB(255, 255, 147, 48),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          lesson['place']?['name'] ?? '',
                                          style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
                                        ),
                                      ],
                                    ),
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
                // Номер занятия
                Positioned(
                  top: -15,
                  right: 10,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 206, 232, 255).withOpacity(1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        lesson['number'].toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _getStartTime(int number) {
    final times = [
      '08:00',
      '09:30',
      '11:10',
      '12:40',
      '14:10',
      '15:40',
      '17:10',
      '18:40'
    ];
    return times[number - 1];
  }

  String _getEndTime(int number) {
    final times = [
      '09:20',
      '10:50',
      '12:30',
      '14:00',
      '15:30',
      '17:00',
      '18:30',
      '20:00'
    ];
    return times[number - 1];
  }

  // ... (методы _buildLessonCard и _buildFreeTimeCard остаются без изменений)
}