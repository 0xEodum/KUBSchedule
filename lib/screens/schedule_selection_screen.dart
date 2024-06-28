import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'search_schedule_screen.dart';

class ScheduleSelectionPage extends StatelessWidget {
  const ScheduleSelectionPage({Key? key}) : super(key: key);

  String getCurrentDate() {
    initializeDateFormatting('ru_RU', null);
    final now = DateTime.now();
    final formatter = DateFormat('d MMMM, E', 'ru_RU');
    return formatter.format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                getCurrentDate(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/person.svg',
                      width: 300,
                      height: 300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Расписание не выбрано',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SearchSchedulePage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              8), // Устанавливаем радиус закругления углов
                        ),
                      ),
                      child: const Text(
                        'Выбрать',
                        style: TextStyle(
                            color: Colors
                                .white), // Устанавливаем цвет текста белым
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
