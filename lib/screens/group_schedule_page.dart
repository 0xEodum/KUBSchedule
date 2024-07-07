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



class GroupSchedulePage extends StatefulWidget {
  final Map<String, dynamic> groupData;
  final DateTime currentDate;

  const GroupSchedulePage(
      {Key? key, required this.groupData, required this.currentDate})
      : super(key: key);
  @override
  _GroupSchedulePageState createState() => _GroupSchedulePageState();
}

class _GroupSchedulePageState extends State<GroupSchedulePage> {
  List<dynamic> lessons = [];
  bool isLoading = true;
  bool isCalendarVisible = false;
  late DateTime _currentDate;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;
  late bool isDarkMode;

  Map<String, List<dynamic>> lessonsCache = {};
  late DateTime earliestDate;
  late DateTime latestDate;

  @override
  void initState() {
    super.initState();
    _loadTheme(); //загрузка выбранной темы
    _currentDate = widget.currentDate; //установка текущей даты
    isDarkMode = ThemeNotifier().isDarkMode; //уведомитель о теме (тёмная или светлая)
    ThemeNotifier().addListener(_onThemeChanged); //установка уведомителя
    earliestDate = _currentDate.subtract(const Duration(days: 7)); //дата начала диапазона - неделя до выбранной даты
    latestDate = _currentDate.add(const Duration(days: 7)); //дата конца диапазона - неделя после выбранной даты
    fetchLessonsForRange(earliestDate, latestDate); //Получение списка занятий при загрузке страницы
  }

  @override //метод вызываемый при закрытии страницы
  void dispose() {
    ThemeNotifier().removeListener(_onThemeChanged); //снятие уведомителя
    super.dispose();
  }
  //При смене темы в настройках - получение уведомления и установка текущей темы в параметр isDarkMode
  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        isDarkMode = ThemeNotifier().isDarkMode;
      });
    }
  }
  //установка темы при загрузке страницы
  Future<void> _loadTheme() async {
    final darkMode = await ThemePreferences.isDarkMode();
    if (mounted) {
      setState(() {
        isDarkMode = darkMode;
      });
    }
  }

  /*
  Получение списка занятий на дипазон дат. 
  Аргумент по умолчанию clearCache для очистки кэша при выборе даты в календаре
   */
  Future<void> fetchLessonsForRange(DateTime start, DateTime end, {bool clearCache = false}) async {
    setState(() {
      isLoading = true;
    });

    if (clearCache) {
      lessonsCache.clear(); //если загружаем расписание на новую дату - очистить кэш
    } else { //иначе лишь удаляем повторы
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
        '$apiUrl/api/timetable/lessons/viewer?start_date=$startString&end_date=$endString&group=${widget.groupData['id']}');

    try {
      final response = await http.get(
        url,
        headers: {headerKey: headerValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final lessons = data['data'] as List<dynamic>; //сохраняем полученный json как список занятий
        
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

  void _toggleCalendar() {
    setState(() {
      isCalendarVisible = !isCalendarVisible;
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

  @override
  Widget build(BuildContext context) {
    final currentDateString = DateFormat('yyyy-MM-dd').format(_currentDate);
    final lessonsForCurrentDate = lessonsCache[currentDateString] ?? [];

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
                          : lessonsForCurrentDate.isEmpty
                              ? _buildNoDataFound()
                              : ListView.builder(
                                  itemCount: lessonsForCurrentDate.length,
                                  itemBuilder: (context, index) {
                                    final lesson = lessonsForCurrentDate[index];
                                    if (lesson['number'] == 0) {
                                      return _buildKSRSCard(lesson);
                                    } else {
                                      return _buildLessonCard(lesson);
                                    }
                                  },
                                ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
                  SvgPicture.asset('assets/group_icon.svg',
                      width: 24, height: 24, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.groupData['name'],
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
      weekendTextStyle: TextStyle(color: isDarkMode ? Colors.red[200] : Colors.red),
      outsideTextStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey),
      defaultTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
      todayTextStyle: TextStyle(color: isDarkMode ? Colors.black : Colors.white),
      selectedTextStyle: const TextStyle(color: Colors.white),
    ),
    daysOfWeekStyle: DaysOfWeekStyle(
      weekendStyle: TextStyle(color: isDarkMode ? Colors.red[200] : Colors.red),
      weekdayStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
    ),
    calendarBuilders: CalendarBuilders(
      defaultBuilder: (context, day, focusedDay) {
        if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
          return Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            child: Text(
              day.day.toString(),
              style: TextStyle(color: isDarkMode ? Colors.red[200] : Colors.red),
            ),
          );
        }
        return null;
      },
    ),
  );
}

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final type = lesson['type'];
    final startTime = _getStartTime(lesson['number']);
    final endTime = _getEndTime(lesson['number']);
    final color = Color(int.parse(type['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final isRemotely = lesson['is_remotely'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$startTime - $endTime',
                              style: TextStyle(
                                  fontWeight: FontWeight.w400, 
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text(lesson['discipline']['name'],
                              style: TextStyle(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.w400,
                                  color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text(
                              lesson['teachers'].isNotEmpty
                                  ? lesson['teachers'][0]['short_name']
                                  : 'Преподаватель не указан',
                              style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w400,
                                  color: isDarkMode ? Colors.white70 : Colors.black87)),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          children: [
                            if (isRemotely)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: SvgPicture.asset(
                                  'assets/remotely.svg',
                                  width: 20,
                                  height: 20,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            Text(
                              lesson['number'].toString(),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white38 : const Color.fromARGB(255, 186, 220, 255)),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Text(
                          lesson['place']?['name'] ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white54 : Colors.grey),
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
