import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/screens/universal_schedule_page.dart';
import 'package:flutter_application_1/utils/schedule_preferences.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'search_schedule_screen.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ScheduleSelectionPage extends StatefulWidget {
  const ScheduleSelectionPage({Key? key}) : super(key: key);

  @override
  _ScheduleSelectionPageState createState() => _ScheduleSelectionPageState();
}

class _ScheduleSelectionPageState extends State<ScheduleSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _bellScheduleAnimationController;
  late Animation<double> _bellScheduleAnimation;
  bool isBellScheduleVisible = false;
  int _selectedIndex = 0;
  late bool isDarkMode = false;
  Map<String, dynamic>? selectedSchedule;
  List<dynamic> currentDayLessons = [];
  Map<String, List<dynamic>> lessonsCache = {};
  bool isLoading = true;
  late DateTime _currentDate;

  Future<void> _loadSchedule() async {
    setState(() {
      isLoading = true;
    });
    final schedule = await SchedulePreferences.getSchedule();
    if (schedule != null) {
      await fetchLessonsForCurrentDay();
    }
    setState(() {
      selectedSchedule = schedule;
      isLoading = false;
    });
  }

  Future<void> fetchLessonsForCurrentDay() async {
    setState(() {
      isLoading = true;
    });

    final schedule = await SchedulePreferences.getSchedule();
    if (schedule == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final currentDate = DateTime.now();
    final dateString = DateFormat('yyyy-MM-dd').format(currentDate);

    String queryParam;
    switch (schedule['type']) {
      case 'teacher':
        queryParam = 'teacher=${schedule['id']}';
        break;
      case 'group':
        queryParam = 'group=${schedule['id']}';
        break;
      case 'place':
        queryParam = 'place=${schedule['id']}';
        break;
      default:
        throw Exception('Unknown schedule type');
    }

    final url = Uri.parse(
        '$apiUrl/api/timetable/lessons/viewer?start_date=$dateString&end_date=$dateString&$queryParam');

    try {
      final response = await http.get(
        url,
        headers: {headerKey: headerValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          currentDayLessons = data['data'] as List<dynamic>;
          isLoading = false;
        });
      } else {
        print('Failed to load lessons: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching lessons: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchLessonsForRange(DateTime start, DateTime end) async {
    setState(() {
      isLoading = true;
    });

    final schedule = await SchedulePreferences.getSchedule();
    if (schedule == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final startString = DateFormat('yyyy-MM-dd').format(start);
    final endString = DateFormat('yyyy-MM-dd').format(end);

    String queryParam;
    switch (schedule['type']) {
      case 'teacher':
        queryParam = 'teacher=${schedule['id']}';
        break;
      case 'group':
        queryParam = 'group=${schedule['id']}';
        break;
      case 'place':
        queryParam = 'place=${schedule['id']}';
        break;
      default:
        throw Exception('Unknown schedule type');
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

        setState(() {
          lessonsCache.clear();
          for (var lesson in lessons) {
            final lessonDate = lesson['date'] as String;
            if (!lessonsCache.containsKey(lessonDate)) {
              lessonsCache[lessonDate] = [];
            }
            lessonsCache[lessonDate]!.add(lesson);
          }
          isLoading = false;
        });
      } else {
        print('Failed to load lessons: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching lessons: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadSchedule();
    _currentDate = DateTime(2024, 5, 17);
    _bellScheduleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bellScheduleAnimation = Tween<double>(begin: 0, end: 1)
        .animate(_bellScheduleAnimationController);
    isDarkMode = ThemeNotifier().isDarkMode;
    ThemeNotifier().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _bellScheduleAnimationController.dispose();
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

  Future<void> _loadTheme() async {
    final darkMode = await ThemePreferences.isDarkMode();
    if (mounted) {
      setState(() {
        isDarkMode = darkMode;
      });
    }
  }

  void _toggleBellSchedule() {
    setState(() {
      isBellScheduleVisible = !isBellScheduleVisible;
      if (isBellScheduleVisible) {
        _bellScheduleAnimationController.forward();
      } else {
        _bellScheduleAnimationController.reverse();
      }
    });
  }

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
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SearchSchedulePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDarkMode ? Colors.black : const Color.fromARGB(255, 244, 246, 250),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildScheduleHeader(),
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : selectedSchedule == null
                          ? _buildWelcomeContent()
                          : _buildScheduleContent(),
                ),
              ],
            ),
            if (isBellScheduleVisible)
              GestureDetector(
                onTap: _toggleBellSchedule,
                child: Container(color: Colors.black54),
              ),
            AnimatedBuilder(
              animation: _bellScheduleAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height *
                      0.6 *
                      _bellScheduleAnimation.value,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity! > 300) {
                                _toggleBellSchedule();
                              }
                            },
                            child: SizedBox(
                              height: 40,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Расписание звонков',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Expanded(child: _buildBellScheduleContent()),
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAdditionalButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        children: [
          _buildCustomButton(
            icon: 'assets/calendar_icon.svg',
            text: 'Открыть полное расписание',
            onTap: _openFullSchedule,
          ),
          const SizedBox(height: 10), // Отступ между кнопками
          _buildCustomButton(
            icon: 'assets/bell.svg',
            text: 'Расписание звонков',
            onTap: _openBellSchedule,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButton({
    required String icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 345,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF626A7E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              color: isDarkMode ? Color(0xFFD2DBFB) : Color(0xFF43495D),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isDarkMode ? Color(0xFFD2DBFB) : Color(0xFF43495D),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullSchedule() {
    if (selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите расписание')),
      );
      return;
    }

    ScheduleType scheduleType;
    String name = selectedSchedule!['name']; // Всегда используем 'name'

    switch (selectedSchedule!['type']) {
      case 'teacher':
        scheduleType = ScheduleType.teacher;
        break;
      case 'group':
        scheduleType = ScheduleType.group;
        break;
      case 'place':
        scheduleType = ScheduleType.place;
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неизвестный тип расписания')),
        );
        return;
    }

    Map<String, dynamic> targetData = {
      'id': selectedSchedule!['id'],
      'name': name,
    };

    // Для преподавателей добавляем дополнительное поле short_name
    if (scheduleType == ScheduleType.teacher) {
      targetData['short_name'] = name;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UniversalSchedulePage(
          targetData: targetData,
          scheduleType: scheduleType,
        ),
      ),
    );
  }

  void _openBellSchedule() {
    _toggleBellSchedule();
  }

  Widget _buildWelcomeContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 35),
          _buildTitle(),
          const SizedBox(height: 40),
          _buildContent(),
          const Spacer(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScheduleContent() {
    return ListView(
      children: [
        ..._buildScheduleItems(),
        if (selectedSchedule != null) _buildAdditionalButtons(),
        SizedBox(height: 20), // Добавляем отступ внизу
        _buildWeeklyLessonsInfo(), // Добавляем новый виджет
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildScheduleHeader() {
    if (selectedSchedule == null) {
      return SizedBox
          .shrink(); // Если расписание не выбрано, не показываем заголовок
    }

    String iconAsset;
    switch (selectedSchedule!['type']) {
      case 'group':
        iconAsset = 'assets/group_icon.svg';
        break;
      case 'teacher':
        iconAsset = 'assets/teacher_icon.svg';
        break;
      case 'place':
        iconAsset = 'assets/place_icon.svg';
        break;
      default:
        iconAsset = 'assets/calendar_icon.svg';
    }

    return GestureDetector(
      onTap: () => _navigateToSearchAndClearSchedule(),
      child: Container(
        margin: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 25),
        height: 50,
        decoration: BoxDecoration(
          color: Color(0xFF228BE6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(width: 16),
            SvgPicture.asset(
              iconAsset,
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedSchedule!['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/change.svg',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToSearchAndClearSchedule() async {
    // Очищаем выбранное расписание
    await SchedulePreferences.clearSchedule();

    // Переходим на страницу поиска
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchSchedulePage()),
    ).then((_) {
      // После возврата с страницы поиска, обновляем состояние
      _loadSchedule();
    });
  }

  List<Widget> _buildScheduleItems() {
    if (currentDayLessons.isEmpty) {
      return [_buildNoDataFound()];
    }

    if (currentDayLessons.length == 1 && currentDayLessons[0]['number'] == 0) {
      return [_buildKSRSDay()];
    }

    currentDayLessons.sort((a, b) => a['number'].compareTo(b['number']));

    List<Widget> scheduleWidgets = [];
    int previousLessonNumber = 0;

    for (var lesson in currentDayLessons) {
      int currentLessonNumber = lesson['number'];

      if (currentLessonNumber == 0) continue;

      if (previousLessonNumber != 0) {
        int freeSlots = currentLessonNumber - previousLessonNumber - 1;
        if (freeSlots > 0) {
          scheduleWidgets
              .add(_buildFreeTimeCard(previousLessonNumber + 1, freeSlots));
        }
      }

      scheduleWidgets.add(_buildLessonCard(lesson));
      previousLessonNumber = currentLessonNumber;
    }

    return scheduleWidgets;
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

  Widget _buildKSRSDay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/KSRS.svg',
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
      child: Container(
        width: 345,
        height: 190,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
          borderRadius: const BorderRadius.all(
            Radius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              isDarkMode ? 'assets/rest_day_white.svg' : 'assets/rest_day.svg',
              width: 171,
              height: 137.68,
            ),
            const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _buildWeeklyLessonsInfo() {
    // Получаем текущую дату
    DateTime now = DateTime.now();

    // Определяем начало и конец недели
    DateTime startOfWeek;
    DateTime endOfWeek;

    if (now.weekday == DateTime.sunday) {
      // Если сегодня воскресенье, берем следующую неделю
      startOfWeek = now.add(Duration(days: 1));
      endOfWeek = startOfWeek.add(Duration(days: 6));
    } else {
      // Иначе берем текущую неделю
      startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      endOfWeek = startOfWeek.add(Duration(days: 6));
    }


    // Получаем занятия на выбранную неделю
    fetchLessonsForRange(startOfWeek, endOfWeek);

    // Подсчитываем количество занятий
    int lessonCount = 0;
    Map<String, int> lessonTypes = {};

    lessonsCache.forEach((date, lessons) {
      for (var lesson in lessons) {
        lessonCount++;
        String type = lesson['type']['name'];
        lessonTypes[type] = (lessonTypes[type] ?? 0) + 1;
      }
    });

    return Column(
    children: [
      Container(
        width: 345, // Фиксированная ширина
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'На этой неделе',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Text(
              lessonCount > 0 ? '$lessonCount занятий' : 'Нет занятий',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
        if (lessonCount > 0)
          Container(
            width: 345,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: lessonTypes.entries.map((entry) {
                String iconAsset;
                if (entry.key == 'Лекция') {
                  iconAsset = 'assets/lecture_icon.svg';
                } else if (['Лабораторная', 'Практика', 'Семинар']
                    .contains(entry.key)) {
                  iconAsset = 'assets/book_icon.svg';
                } else {
                  iconAsset = 'assets/additional_icon.svg';
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? Color(0xFF43495D) : Color(0xFFDBEEFF),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          iconAsset,
                          width: 14,
                          height: 14,
                          color: Color(0xFF2F82FF),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${entry.key} (${entry.value})',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final type = lesson['type'];
    final color =
        Color(int.parse(type['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final isRemotely = lesson['is_remotely'] ?? false;

    return Padding(
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
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildLeftInfo(lesson),
                                    _buildRightInfo(lesson),
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
                        color: Colors.blue.withOpacity(0.2),
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
    );
  }

  Widget _buildLeftInfo(Map<String, dynamic> lesson) {
    final scheduleType = selectedSchedule!['type'];
    switch (scheduleType) {
      case 'teacher':
        return _buildGroupsInfo(lesson['groups']);
      case 'group':
        return _buildTeachersInfo(lesson['teachers']);
      case 'place':
        return _buildTeachersInfo(lesson['teachers']);
      default:
        return Container();
    }
  }

  Widget _buildRightInfo(Map<String, dynamic> lesson) {
    final scheduleType = selectedSchedule!['type'];
    switch (scheduleType) {
      case 'teacher':
        return _buildPlaceInfo(lesson['place']);
      case 'group':
        return _buildPlaceInfo(lesson['place']);
      case 'place':
        return _buildGroupsInfo(lesson['groups']);
      default:
        return Container();
    }
  }

  Widget _buildGroupsInfo(List<dynamic> groups) {
    final firstGroup = groups.isNotEmpty ? groups[0]['name'] : '';
    final additionalGroups = groups.length > 1 ? groups.length - 1 : 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 195, 255, 212).withOpacity(1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/group_icon.svg',
                width: 16,
                height: 16,
                color: isDarkMode
                    ? Colors.white70
                    : const Color.fromARGB(255, 77, 189, 116),
              ),
              const SizedBox(width: 4),
              Text(
                firstGroup,
                style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
        if (additionalGroups > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 226, 255, 234).withOpacity(1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '+$additionalGroups',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.white70
                      : const Color.fromARGB(255, 77, 189, 116)),
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
          color: const Color.fromARGB(255, 219, 238, 255).withOpacity(1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/teacher_icon.svg',
              width: 16,
              height: 16,
              color: isDarkMode
                  ? Colors.white70
                  : const Color.fromARGB(255, 47, 130, 255),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                teacher,
                style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white70
                        : const Color.fromARGB(255, 47, 130, 255)),
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
        color: const Color.fromARGB(255, 255, 237, 220).withOpacity(1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/place_icon.svg',
            width: 16,
            height: 16,
            color: isDarkMode
                ? Colors.white70
                : const Color.fromARGB(255, 255, 147, 48),
          ),
          const SizedBox(width: 4),
          Text(
            placeName,
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? Colors.white70
                    : const Color.fromARGB(255, 255, 147, 48)),
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
    return number > 0 && number <= times.length ? times[number - 1] : '';
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
    return number > 0 && number <= times.length ? times[number - 1] : '';
  }

  Widget _buildBellScheduleContent() {
    final bellSchedule = [
      {
        "number": 1,
        "start": "08:00",
        "end": "09:20",
        "break_start": "09:20",
        "break_end": "09:30"
      },
      {
        "number": 2,
        "start": "09:30",
        "end": "10:50",
        "break_start": "10:50",
        "break_end": "11:10"
      },
      {
        "number": 3,
        "start": "11:10",
        "end": "12:30",
        "break_start": "12:30",
        "break_end": "12:40"
      },
      {
        "number": 4,
        "start": "12:40",
        "end": "14:00",
        "break_start": "14:00",
        "break_end": "14:10"
      },
      {
        "number": 5,
        "start": "14:10",
        "end": "15:30",
        "break_start": "15:30",
        "break_end": "15:40"
      },
      {
        "number": 6,
        "start": "15:40",
        "end": "17:00",
        "break_start": "17:00",
        "break_end": "17:10"
      },
      {
        "number": 7,
        "start": "17:10",
        "end": "18:30",
        "break_start": "18:30",
        "break_end": "18:40"
      },
      {
        "number": 8,
        "start": "18:40",
        "end": "20:00",
        "break_start": "20:00",
        "break_end": "20:10"
      },
      {
        "number": 9,
        "start": "20:10",
        "end": "21:30",
        "break_start": "-",
        "break_end": "-"
      },
    ];

    return Container(
      color: isDarkMode ? Color(0xFF383D4E) : Colors.white,
      child: ListView.builder(
        itemCount: bellSchedule.length,
        itemBuilder: (context, index) {
          final lesson = bellSchedule[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEEFF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${lesson["number"]}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDarkMode ? Color(0xFFAEAEAE) : Colors.black,
                        fontSize: 13,
                      ),
                      children: [
                        const TextSpan(text: 'Занятие · '),
                        TextSpan(
                          text: '${lesson["start"]} - ${lesson["end"]}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        if (lesson["break_start"] != "-") ...[
                          const TextSpan(text: '  '),
                          WidgetSpan(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDBFFDE),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/bell.svg',
                                  width: 12,
                                  height: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' Перемена '),
                          TextSpan(
                            text:
                                '${lesson["break_start"]} - ${lesson["break_end"]}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
          color: isDarkMode ? Colors.white : Color(0xFF43495D),
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
            isDarkMode ? 'assets/rocket_white.svg' : 'assets/rocket.svg',
            width: 245.13,
            height: 319.93,
          ),
          const SizedBox(height: 20),
          _buildChoiceButton(),
          const SizedBox(height: 10),
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
          color: const Color(0xFF228BE6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
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
      onTap: _toggleBellSchedule,
      child: Container(
        width: 345,
        height: 44,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF626A7E) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/bell.svg',
              width: 24,
              height: 24,
              color: isDarkMode ? Color(0xFFD2DBFB) : Color(0xFF43495D),
            ),
            const SizedBox(width: 10),
            Text(
              'Расписание звонков',
              style: TextStyle(
                color: isDarkMode ? Color(0xFFD2DBFB) : Color(0xFF43495D),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
