import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/screens/search_schedule_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:flutter_application_1/utils/timeline.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

class _UniversalSchedulePageState extends State<UniversalSchedulePage>
    with TickerProviderStateMixin {
  bool _hasInternet = true;
  bool _hasServerConnection = true;
  bool _wasOffline = false;
  bool isCalendarVisible = false;
  late ScrollController _dateScrollController;
  late List<DateTime> _dates;
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
  late AnimationController _lessonDetailsAnimationController;
  late Animation<double> _lessonDetailsAnimation;
  bool isLessonDetailsVisible = false;
  Map<String, dynamic>? currentLesson;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _currentDate = DateTime.now();
    isDarkMode = ThemeNotifier().isDarkMode;
    _dateScrollController = ScrollController();
    _initializeDates();
    _scrollController = ScrollController();
    ThemeNotifier().addListener(_onThemeChanged);
    earliestDate = _currentDate.subtract(const Duration(days: 7));
    latestDate = _currentDate.add(const Duration(days: 7));
    _calendarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _calendarAnimation =
        Tween<double>(begin: 0, end: 1).animate(_calendarAnimationController);

    _lessonDetailsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _lessonDetailsAnimation = Tween<double>(begin: 0, end: 1)
        .animate(_lessonDetailsAnimationController);

    fetchLessonsForRange(earliestDate, latestDate);
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool internet = await _checkInternetConnection();
    bool server = await _checkServerConnection();
    setState(() {
      _hasInternet = internet;
      _hasServerConnection = server;
      if (!_hasInternet || !_hasServerConnection) {
        _wasOffline = true;
      }
    });
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<bool> _checkServerConnection() async {
    try {
      final apiUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.get(Uri.parse('$apiUrl/docs'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _initializeDates() {
    final now = DateTime.now();
    _dates = List.generate(365, (index) => now.add(Duration(days: index - 182)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentDate(animate: false);
    });
  }

  void _scrollToCurrentDate({bool animate = true}) {
    final currentDateIndex = _dates.indexWhere((date) => 
      date.year == _currentDate.year && 
      date.month == _currentDate.month && 
      date.day == _currentDate.day
    );
    if (currentDateIndex != -1) {
      final scrollPosition = currentDateIndex * 60.0; // Предполагаемая ширина элемента
      if (animate) {
        _dateScrollController.animateTo(
          scrollPosition,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _dateScrollController.jumpTo(scrollPosition);
      }
    }
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
    _lessonDetailsAnimationController.dispose();
    _scrollController.dispose();
    _dateScrollController.dispose();
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

  Future<void> fetchLessonsForRange(DateTime start, DateTime end,
      {bool clearCache = false}) async {
    await _checkConnectivity();
    if (!_hasInternet || !_hasServerConnection) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    if (clearCache || _wasOffline) {
      lessonsCache.clear();
      _wasOffline = false;
    }

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

    final url = Uri.parse(
        '$apiUrl/api/timetable/lessons/viewer?start_date=$startString&end_date=$endString&$queryParam');

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
        _currentDate = _currentDate.add(const Duration(days: 2));
      } else {
        _currentDate = _currentDate.add(const Duration(days: 1));
      }
    });
    _updateLessonsIfNeeded(forceUpdate: _wasOffline);
  }

  void _onSwipeRight() {
    setState(() {
      if (_currentDate.weekday == DateTime.monday) {
        _currentDate = _currentDate.subtract(const Duration(days: 2));
      } else {
        _currentDate = _currentDate.subtract(const Duration(days: 1));
      }
    });
    _updateLessonsIfNeeded(forceUpdate: _wasOffline);
  }

  void _updateLessonsIfNeeded({bool forceUpdate = false}) {
    if (forceUpdate || _currentDate.isAfter(latestDate) || _currentDate.isBefore(earliestDate)) {
      fetchLessonsForRange(
        _currentDate.subtract(const Duration(days: 7)),
        _currentDate.add(const Duration(days: 7)),
        clearCache: forceUpdate,
      );
    }
  }

  void _toggleLessonDetails(Map<String, dynamic>? lesson) {
    setState(() {
      isLessonDetailsVisible = !isLessonDetailsVisible;
      if (isLessonDetailsVisible) {
        currentLesson = lesson;
        _lessonDetailsAnimationController.forward();
      } else {
        _lessonDetailsAnimationController.reverse().then((_) {
          currentLesson = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentDateString = DateFormat('yyyy-MM-dd').format(_currentDate);
    final lessonsForCurrentDate = lessonsCache[currentDateString] ?? [];
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (!isCalendarVisible && !isLessonDetailsVisible) {
              if (details.primaryVelocity! < -1000) {
                _onSwipeLeft();
              } else if (details.primaryVelocity! > 1000) {
                _onSwipeRight();
              }
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildDateNavigator(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildContent(lessonsForCurrentDate),
                  ),
                ],
              ),
              if (isCalendarVisible)
                GestureDetector(
                  onTap: _toggleCalendar,
                  child: Container(color: Colors.black54),
                ),
              AnimatedBuilder(
                animation: _calendarAnimation,
                builder: (context, child) {
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).size.height *
                        0.5 *
                        _calendarAnimation.value,
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta! > 0) {
                          _calendarAnimationController.value -= details.primaryDelta! / (MediaQuery.of(context).size.height * 0.5);
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (_calendarAnimationController.value < 0.5) {
                          _toggleCalendar();
                        } else {
                          _calendarAnimationController.forward();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 20,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: _buildCalendar()),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (isLessonDetailsVisible)
                GestureDetector(
                  onTap: () => _toggleLessonDetails(null),
                  child: Container(color: Colors.black54),
                ),
              AnimatedBuilder(
                animation: _lessonDetailsAnimation,
                builder: (context, child) {
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).size.height *
                        0.5 *
                        _lessonDetailsAnimation.value,
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta! > 0) {
                          _lessonDetailsAnimationController.value -= details.primaryDelta! / (MediaQuery.of(context).size.height * 0.5);
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (_lessonDetailsAnimationController.value < 0.5) {
                          _toggleLessonDetails(null);
                        } else {
                          _lessonDetailsAnimationController.forward();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 20,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: currentLesson != null
                                  ? _buildLessonDetails(currentLesson!)
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLessonDetails(Map<String, dynamic> lesson) {
    if (lesson.isEmpty)
      return Container();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Занятие',
              style: TextStyle(fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildDetailSection('Дисциплина', lesson['discipline']['name']),
          _buildDetailSection('Тип', lesson['type']['name']),
          _buildDetailSection('Номер занятия',
              '${lesson['number']} (${_getStartTime(lesson['number'])} - ${_getEndTime(lesson['number'])})'),
          _buildDetailSection('Преподаватель(и)', '',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (lesson['teachers'] as List)
                    .map((teacher) =>
                        _buildInfoChip(teacher['full_name'], Colors.blue))
                    .toList(),
              )),
          _buildDetailSection('Группа(ы)', '',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (lesson['groups'] as List)
                    .map((group) => _buildInfoChip(group['name'], Colors.green))
                    .toList(),
              )),
          _buildDetailSection('Аудитория', '',
              child: _buildInfoChip(lesson['place']['name'], Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, {Widget? child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, 
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black
          ),
        ),
        const SizedBox(height: 8),
        child ?? Text(content, style:TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
      ),
    );
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

  // void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
  //   setState(() {
  //     _currentDate = selectedDay;
  //     isCalendarVisible = false;
  //   });
  //   fetchLessonsForRange(selectedDay.subtract(const Duration(days: 7)),
  //       selectedDay.add(const Duration(days: 7)),
  //       clearCache: true);
  // }

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
        weekendTextStyle:
            TextStyle(color: isDarkMode ? Colors.red[300] : Colors.red),
        outsideTextStyle:
            TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey),
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
        defaultTextStyle:
            TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekendStyle:
            TextStyle(color: isDarkMode ? Colors.red[300] : Colors.red),
        weekdayStyle:
            TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
              SvgPicture.asset(iconAsset,
                  width: 24, height: 24, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              SvgPicture.asset('assets/search.svg',
                  width: 24, height: 24, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
  final now = DateTime.now();
  final isToday = _currentDate.year == now.year &&
      _currentDate.month == now.month &&
      _currentDate.day == now.day;

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
                    style: TextStyle(
                      color: Color(0xFF228BE6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(),
              Text(
                DateFormat('MMMM yyyy', 'ru_RU').format(_currentDate),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF228BE6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              final isSelected = day.day == _currentDate.day &&
                  day.month == _currentDate.month;
              final isActualToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              
              Color backgroundColor;
              Color textColor;
              
              if (isActualToday) {
                backgroundColor = Colors.blue;
                textColor = Colors.white;
              } else if (isSelected && isDarkMode) {
                backgroundColor = Color(0xFF43495D);
                textColor = Color(0xFFA4A4A4);
              } else if (isSelected && !isDarkMode) {
                backgroundColor = Colors.blue.withOpacity(0.2);
                textColor = isDarkMode ? Color(0xFFA4A4A4) : Colors.black;
              } else {
                backgroundColor = Colors.transparent;
                textColor = isDarkMode ? Color(0xFFA4A4A4) : Colors.black;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentDate = day;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'ru_RU').format(day).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
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

Widget _buildContent(List<dynamic> lessonsForCurrentDate) {
    if (!_hasInternet) {
      return _buildNoInternet();
    }
    if (!_hasServerConnection) {
      return _buildServerDown();
    }
    return _buildSchedule(lessonsForCurrentDate);
  }

  Widget _buildSchedule(List<dynamic> lessonsForCurrentDate) {
  
    if (lessonsForCurrentDate.isEmpty) {
      return _buildNoDataFound();
    }
    if (lessonsForCurrentDate.length == 1 && lessonsForCurrentDate[0]['number'] == 0) {
      return _buildKSRSDay();
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

  return Stack(
    children: [
      ListView(
        controller: _scrollController,
        children: scheduleWidgets,
      ),
      Timeline(
        lessons: lessonsForCurrentDate,
        isDarkMode: isDarkMode,
        scrollController: _scrollController,
        currentDate: _currentDate,
      ),
    ],
  );
}

Widget _buildNoInternet() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            isDarkMode ? 'assets/no_internet_dark.svg' : 'assets/no_internet.svg',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 20),
          Text(
            'Нет подключения к интернету',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerDown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            isDarkMode ? 'assets/server_down_dark.svg' : 'assets/server_down.svg',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 20),
          Text(
            'Сервер недоступен',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKSRSDay() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          isDarkMode ? 'assets/KSRS_white.svg' : 'assets/KSRS.svg',
          width: 200,
          height: 200,
        ),
        const SizedBox(height: 20),
        Text(
          'День самостоятельной работы',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
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
                  Text(startTime,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black)),
                  Text(endTime,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black)),
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
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Свободное время',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$duration мин',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
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
    final color =
        Color(int.parse(type['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final isRemotely = lesson['is_remotely'] ?? false;

    Widget buildLeftInfo() {
      switch (widget.scheduleType) {
        case ScheduleType.teacher:
          return _buildGroupsInfo(lesson['groups']);
        case ScheduleType.group:
          return _buildTeachersInfo(lesson['teachers']);
        case ScheduleType.place:
          return _buildTeachersInfo(lesson['teachers']);
        default:
          return Container();
      }
    }

    Widget buildRightInfo() {
      switch (widget.scheduleType) {
        case ScheduleType.teacher:
          return _buildPlaceInfo(lesson['place']);
        case ScheduleType.group:
          return _buildPlaceInfo(lesson['place']);
        case ScheduleType.place:
          return _buildGroupsInfo(lesson['groups']);
        default:
          return Container();
      }
    }

    return GestureDetector(
      onTap: () => _toggleLessonDetails(lesson),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 20),
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
                    Text(_getStartTime(lesson['number']),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black)),
                    Text(_getEndTime(lesson['number']),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black)),
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
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.black : Colors.white,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    lesson['discipline']['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      buildLeftInfo(),
                                      buildRightInfo(),
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
                          color: isDarkMode ? Colors.blue.withOpacity(1) : Colors.blue.withOpacity(0.2),
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
                    if (isRemotely)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: SvgPicture.asset(
                          'assets/remotely_icon.svg',
                          width: 20,
                          height: 20,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsInfo(List<dynamic> groups) {
    final firstGroup = groups.isNotEmpty ? groups[0]['name'] : '';
    final additionalGroups = groups.length > 1 ? groups.length - 1 : 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color.fromARGB(255, 67, 73, 93) : const Color.fromARGB(255, 195, 255, 212).withOpacity(1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/group_icon.svg',
                width: 16,
                height: 16,
                color: const Color.fromARGB(255, 77, 189, 116),
              ),
              const SizedBox(width: 4),
              Text(
                firstGroup,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 77, 189, 116)),
              ),
            ],
          ),
        ),
        if (additionalGroups > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode ? Color.fromARGB(255, 67, 73, 93) : const Color.fromARGB(255, 226, 255, 234).withOpacity(1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '+$additionalGroups',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 77, 189, 116)),
            ),
          ),
      ],
    );
  }

  Widget _buildTeachersInfo(List<dynamic> teachers) {
    final teacher = teachers.isNotEmpty ? teachers[0]['short_name'] : '';

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: 130), // Максимальная ширина блока
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkMode ? Color.fromARGB(255, 67, 73, 93) : const Color.fromARGB(255, 219, 238, 255).withOpacity(1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/teacher_icon.svg',
              width: 16,
              height: 16,
              color: const Color.fromARGB(255, 47, 130, 255),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                teacher,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 47, 130, 255)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceInfo(Map<String, dynamic>? place) {
    final placeName = place != null ? place['name'] : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Color.fromARGB(255, 67, 73, 93) : const Color.fromARGB(255, 255, 237, 220).withOpacity(1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/place_icon.svg',
            width: 16,
            height: 16,
            color: const Color.fromARGB(255, 255, 147, 48),
          ),
          const SizedBox(width: 4),
          Text(
            placeName,
            style: TextStyle(
                fontSize: 12,
                color: const Color.fromARGB(255, 255, 147, 48)),
          ),
        ],
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
