import 'package:flutter/material.dart';
import 'package:flutter_application_1/utils/NotificationService.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ru_RU', null);
  final themeMode = await ThemePreferences.getThemeMode();
  await NotificationService().init();
  runApp(MyApp(initialThemeMode: themeMode));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({Key? key, required this.initialThemeMode}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    ThemePreferences.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'КУБ.Расписание',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // darkTheme: ThemeData.dark().copyWith(
      //   colorScheme: ColorScheme.fromSeed(
      //     seedColor: Colors.blue,
      //     brightness: Brightness.dark,
      //   ),
      //   useMaterial3: true,
      // ),
      // themeMode: _themeMode,
      home: SplashScreen(setThemeMode: setThemeMode),
    );
  }
}
