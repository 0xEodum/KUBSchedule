import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _currentDate = widget.currentDate;
    fetchLessons();
  }

  Future<void> fetchLessons() async {
    setState(() {
      isLoading = true;
    });

    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final dateString = DateFormat('yyyy-MM-dd').format(_currentDate);
    final url = Uri.parse(
        '$apiUrl/api/timetable/lessons/viewer?start_date=$dateString&end_date=$dateString&group=${widget.groupData['id']}');

    try {
      final response = await http.get(
        url,
        headers: {headerKey: headerValue},
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          lessons = data['data'];
        });
      } else {
        print('Failed to load lessons: ${response.statusCode}');
        setState(() {
          lessons.clear();
        });
      }
    } catch (e) {
      print('Error fetching lessons: $e');
      setState(() {
        isLoading = false;
        lessons.clear();
      });
    }
  }

  void _onSwipeLeft() {
    setState(() {
      _currentDate = _currentDate.add(const Duration(days: 1));
    });
    fetchLessons();
  }

  void _onSwipeRight() {
    setState(() {
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    });
    fetchLessons();
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
    fetchLessons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            isCalendarVisible
                ? _buildCalendar()
                : Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity! < 0) {
                          _onSwipeLeft();
                        } else if (details.primaryVelocity! > 0) {
                          _onSwipeRight();
                        }
                      },
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : lessons.isEmpty
                              ? _buildNoDataFound()
                              : ListView.builder(
                                  itemCount: lessons.length,
                                  itemBuilder: (context, index) {
                                    return _buildLessonCard(lessons[index]);
                                  },
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
            'assets/person.svg',
            width: 300,
            height: 300,
          ),
          const SizedBox(height: 20),
          const Text(
            'Ничего не найдено',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
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
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SvgPicture.asset('assets/calendar.svg',
                      width: 19, height: 19),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM, EE', 'ru').format(_currentDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
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
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final type = lesson['type'];
    final startTime = _getStartTime(lesson['number']);
    final endTime = _getEndTime(lesson['number']);
    final color =
        Color(int.parse(type['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final isRemotely = lesson['is_remotely'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w400, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(lesson['discipline']['name'],
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w400)),
                          const SizedBox(height: 4),
                          Text(
                              lesson['teachers'].isNotEmpty
                                  ? lesson['teachers'][0]['short_name']
                                  : 'Преподаватель не указан',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w400)),
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
                                ),
                              ),
                            Text(
                              lesson['number'].toString(),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Color.fromARGB(255, 186, 220, 255)),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Text(
                          lesson['place']?['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey),
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
