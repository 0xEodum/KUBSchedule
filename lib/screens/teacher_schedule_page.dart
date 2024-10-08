import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'search_schedule_screen.dart';

class TeacherSchedulePage extends StatefulWidget {
  final Map<String, dynamic> teacherData;
  final DateTime currentDate;

  const TeacherSchedulePage({
    Key? key,
    required this.teacherData,
    required this.currentDate,
  }) : super(key: key);

  @override
  _TeacherSchedulePageState createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  bool isCalendarVisible = false;
  List<dynamic> lessons = [];
  bool isLoading = true;
  late DateTime _currentDate;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 1;
  late bool isDarkMode;

  Map<String, List<dynamic>> lessonsCache = {};
  late DateTime earliestDate;
  late DateTime latestDate;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _currentDate = widget.currentDate;
    isDarkMode = ThemeNotifier().isDarkMode;
    ThemeNotifier().addListener(_onThemeChanged);
    earliestDate = _currentDate.subtract(const Duration(days: 7));
    latestDate = _currentDate.add(const Duration(days: 7));
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
    final url = Uri.parse(
        '$apiUrl/api/timetable/lessons/viewer?start_date=$startString&end_date=$endString&teacher=${widget.teacherData['id']}');

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
    final nextDate = _currentDate.add(const Duration(days: 1));
    if (nextDate.isAfter(latestDate)) {
      fetchLessonsForRange(latestDate.add(const Duration(days: 1)), latestDate.add(const Duration(days: 7)));
    }
    setState(() {
      _currentDate = nextDate;
    });
  }

  void _onSwipeRight() {
    final previousDate = _currentDate.subtract(const Duration(days: 1));
    if (previousDate.isBefore(earliestDate)) {
      fetchLessonsForRange(earliestDate.subtract(const Duration(days: 7)), earliestDate.subtract(const Duration(days: 1)));
    }
    setState(() {
      _currentDate = previousDate;
    });
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
    });
  }

  @override
  Widget build(BuildContext context) {
  final currentDateString = DateFormat('yyyy-MM-dd').format(_currentDate);
  final lessonsForCurrentDate = lessonsCache[currentDateString] ?? [];

  lessonsForCurrentDate.sort((a, b) => a['number'].compareTo(b['number']));

  List<Widget> lessonWidgets = [];
  int previousLessonNumber = 0;

  for (var lesson in lessonsForCurrentDate) {
    int currentLessonNumber = lesson['number'];

    if (previousLessonNumber != 0) {
      int freeSlots = currentLessonNumber - previousLessonNumber - 1;
      if (freeSlots > 0) {
        lessonWidgets.add(_buildFreeTimeCard(previousLessonNumber + 1, freeSlots));
      }
    }

    lessonWidgets.add(_buildLessonCard(lesson));
    previousLessonNumber = currentLessonNumber;
  }

  return Scaffold(
    backgroundColor: isDarkMode ? Colors.black : Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isCalendarVisible
                ? _buildCalendar()
                : GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! < 0) {
                        _onSwipeLeft();
                      } else if (details.primaryVelocity! > 0) {
                        _onSwipeRight();
                      }
                    },
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : lessonWidgets.isEmpty
                            ? _buildNoDataFound()
                            : ListView(children: lessonWidgets),
                  ),
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
            'Ничего не найдено',
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
        _onDaySelected(selectedDay, focusedDay);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchSchedulePage(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF228BE6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SvgPicture.asset('assets/teacher_icon.svg',
                      width: 24, height: 24, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.teacherData['short_name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SvgPicture.asset('assets/calendar.svg',
                      width: 19, height: 19, color: isDarkMode ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM, EE', 'ru').format(_currentDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKSRSCard(Map<String, dynamic> ksrs) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    color: isDarkMode ? Colors.grey[800] : Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'КСРС',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                DateFormat('dd.MM.yyyy').format(DateTime.parse(ksrs['date'])),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Группы: ${ksrs['groups'].map((g) => g['name']).join(', ')}',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
          if (ksrs['theme'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Тема: ${ksrs['theme']}',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
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
}
