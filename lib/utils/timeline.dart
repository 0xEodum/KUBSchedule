import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_application_1/utils/theme_notifier.dart';

class Timeline extends StatefulWidget {
  final List<dynamic> lessons;
  final bool isDarkMode;
  final ScrollController scrollController;
  final DateTime currentDate;

  const Timeline({
    Key? key, 
    required this.lessons, 
    required this.isDarkMode,
    required this.scrollController,
    required this.currentDate,
  }) : super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  late Timer _timer;
  double _position = 0;
  late bool isDarkMode;
  bool _isVisible = false;
  int _currentLessonIndex = -1;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updatePosition();
    isDarkMode = ThemeNotifier().isDarkMode;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updatePosition());
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    _updatePosition();
  }

  void _updatePosition() {
    if (!_isCurrentDay()) {
      setState(() {
        _isVisible = false;
      });
      return;
    }

    final now = DateTime.now();
    _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    int lessonIndex = -1;
    for (int i = 0; i < widget.lessons.length; i++) {
      if (_getStartTime(widget.lessons[i]['number']).compareTo(_currentTime) <= 0 &&
          _currentTime.compareTo(_getEndTime(widget.lessons[i]['number'])) <= 0) {
        lessonIndex = i;
        break;
      }
    }

    if (lessonIndex == -1) {
      // Проверяем, находимся ли мы в перемене
      for (int i = 0; i < widget.lessons.length - 1; i++) {
        if (_getEndTime(widget.lessons[i]['number']).compareTo(_currentTime) < 0 &&
            _currentTime.compareTo(_getStartTime(widget.lessons[i + 1]['number'])) < 0) {
          lessonIndex = i + 1;
          break;
        }
      }
    }

    if (lessonIndex != -1) {
      final lessonStartTime = _parseTime(_getStartTime(widget.lessons[lessonIndex]['number']));
      final lessonEndTime = _parseTime(_getEndTime(widget.lessons[lessonIndex]['number']));
      final totalMinutes = lessonEndTime.difference(lessonStartTime).inMinutes;
      final elapsedMinutes = now.difference(lessonStartTime).inMinutes;
      
      double lessonHeight = 100.0; // Высота карточки занятия
      double topPadding = 20.0; // Верхний отступ
      double bottomPadding = 20.0; // Нижний отступ

      setState(() {
        _position = (lessonIndex * (lessonHeight + topPadding + bottomPadding)) +
                    topPadding +
                    (elapsedMinutes < 0 ? 0 : (elapsedMinutes / totalMinutes * lessonHeight));
        _isVisible = true;
        _currentLessonIndex = lessonIndex;
      });
    } else {
      setState(() {
        _isVisible = false;
        _currentLessonIndex = -1;
      });
    }
  }

  bool _isCurrentDay() {
    final now = DateTime.now();
    return widget.currentDate.year == now.year &&
           widget.currentDate.month == now.month &&
           widget.currentDate.day == now.day;
  }

  DateTime _parseTime(String timeString) {
    final parts = timeString.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return Container();
    
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _position - widget.scrollController.offset,
            child: Container(
              color: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.3),
            ),
          ),
          Positioned(
            top: _position - widget.scrollController.offset,
            left: 0,
            right: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 2,
                  color: Colors.red,
                ),
                Positioned(
                  left: 16,
                  bottom: 5,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currentTime,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStartTime(int number) {
    final times = ['08:00', '09:30', '11:10', '12:40', '14:10', '15:40', '17:10', '18:40'];
    return times[number - 1];
  }

  String _getEndTime(int number) {
    final times = ['09:20', '10:50', '12:30', '14:00', '15:30', '17:00', '18:30', '20:00'];
    return times[number - 1];
  }
}