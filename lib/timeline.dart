import 'package:flutter/material.dart';
import 'dart:async';

class Timeline extends StatefulWidget {
  final List<dynamic> lessons;
  final List<double> lessonHeights;

  const Timeline({Key? key, required this.lessons, required this.lessonHeights}) : super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  double _position = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updatePosition();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updatePosition());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updatePosition() {
    if (widget.lessons.isEmpty) return;

    final now = DateTime.now();
    final firstLesson = widget.lessons.first;
    final lastLesson = widget.lessons.last;

    final firstLessonStart = _parseTime(_getStartTime(firstLesson['number']));
    final lastLessonEnd = _parseTime(_getEndTime(lastLesson['number']));

    if (now.isBefore(firstLessonStart)) {
      setState(() => _position = 0);
    } else if (now.isAfter(lastLessonEnd)) {
      setState(() => _position = widget.lessonHeights.reduce((a, b) => a + b));
    } else {
      double currentPosition = 0;
      for (int i = 0; i < widget.lessons.length; i++) {
        final lesson = widget.lessons[i];
        final startTime = _parseTime(_getStartTime(lesson['number']));
        final endTime = _parseTime(_getEndTime(lesson['number']));

        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          final progress = now.difference(startTime).inSeconds / endTime.difference(startTime).inSeconds;
          setState(() => _position = currentPosition + widget.lessonHeights[i] * progress);
          break;
        } else if (now.isAfter(endTime)) {
          currentPosition += widget.lessonHeights[i];
          if (i < widget.lessons.length - 1) {
            final nextLesson = widget.lessons[i + 1];
            final nextStartTime = _parseTime(_getStartTime(nextLesson['number']));
            if (now.isBefore(nextStartTime)) {
              setState(() => _position = currentPosition);
              break;
            }
          }
        }
      }
    }
  }

  DateTime _parseTime(String time) {
    final now = DateTime.now();
    final parts = time.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: CustomPaint(
            painter: TimelinePainter(_position),
          ),
        );
      },
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

class TimelinePainter extends CustomPainter {
  final double position;

  TimelinePainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * position),
      Offset(size.width, size.height * position),
      paint,
    );
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) => position != oldDelegate.position;
}