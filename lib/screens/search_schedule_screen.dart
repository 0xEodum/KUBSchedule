import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/screens/universal_schedule_page.dart';
import 'package:flutter_application_1/utils/schedule_preferences.dart';
import 'package:flutter_application_1/utils/theme_notifier.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'teacher_schedule_page.dart';
import 'group_schedule_page.dart';
import 'place_schedule_page.dart';
import 'package:flutter_application_1/utils/theme_preferences.dart';

class SearchSchedulePage extends StatefulWidget {
  const SearchSchedulePage({Key? key}) : super(key: key);

  @override
  _SearchSchedulePageState createState() => _SearchSchedulePageState();
}

class _SearchSchedulePageState extends State<SearchSchedulePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  int _selectedIndex = 1;
  late bool isDarkMode;
  bool _hasInternet = true;
  bool _hasConnection = true;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _searchController.addListener(_onSearchChanged);
    isDarkMode = ThemeNotifier().isDarkMode;
    ThemeNotifier().addListener(_onThemeChanged);
     _focusNode.addListener(() {
      setState(() {});
    });
    _checkConnectivity();
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

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void _onSearchChanged() {
    if (_searchController.text.isNotEmpty) {
      setState(() {
        _isSearching = true;
        _isLoading = true;
      });
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    final apiUrl = dotenv.env['API_URL'] ?? '';
    final headerKey = dotenv.env['API_HEADER_KEY'] ?? '';
    final headerValue = dotenv.env['API_HEADER_VALUE'] ?? '';

    final response = await http.get(
      Uri.parse('$apiUrl/api/timetable/entities?q=$query'),
      headers: {headerKey: headerValue},
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        _searchResults = [
          ...data['teachers'].map((t) => {'type': 'teacher', 'data': t}),
          ...data['places'].map((p) => {'type': 'place', 'data': p}),
          ...data['groups'].map((g) => {'type': 'group', 'data': g}),
        ];
      });
    } else {
      print('Failed to load search results');
      setState(() {
        _searchResults.clear();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    ThemeNotifier().removeListener(_onThemeChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    // Здесь должна быть реализация проверки подключения к интернету и соединения с сервером.
    setState(() {
      _hasInternet = true;
      _hasConnection = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSearchBar() {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Container(
          width: constraints.maxWidth,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFF228BE6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск расписания..',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_searchController.text.isNotEmpty) {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchResults.clear();
                      });
                    }
                  },
                  child: SvgPicture.asset(
                    _searchController.text.isEmpty ? 'assets/search.svg' : 'assets/clear.svg',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildContent() {
    if (!_hasInternet) {
      return _buildNoInternet();
    } else if (!_hasConnection) {
      return _buildNoConnection();
    } else if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    } else if (_isSearching) {
      return _searchResults.isNotEmpty
          ? _buildSearchResults()
          : _buildNoResults();
    } else {
      return _buildInitialContent();
    }
  }

  Widget _buildNoInternet() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/no_internet.svg',
            width: 200,
            height: 200,
          ),
          SizedBox(height: 20),
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

  Widget _buildNoConnection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/no_connection.svg',
            width: 200,
            height: 200,
          ),
          SizedBox(height: 20),
          Text(
            'Нет соединения с сервером',
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

  Widget _buildInitialContent() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 26.0, vertical: 36.0),
          child: SvgPicture.asset(
            isDarkMode
                ? 'assets/search_schedule_dark.svg'
                : 'assets/search_schedule.svg',
            width: 300,
            height: 320,
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Начните вводить группу, преподавателя или аудиторию',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 49.0, vertical: 56.0),
          child: SvgPicture.asset(
            isDarkMode ? 'assets/no_data_dark.svg' : 'assets/no_data.svg',
            width: 300,
            height: 300,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Ничего не найдено',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
  return LayoutBuilder(
    builder: (context, constraints) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final tileColor = _getTileColor(item['type']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: isDarkMode ? _getDarkModeColor(tileColor) : tileColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListTile(
                leading: _getLeadingIcon(item['type']),
                title: item['type'] == 'group'
                    ? _buildGroupTitle(item)
                    : Text(
                        _getTitle(item),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                onTap: () => _navigateToSchedule(context, item),
              ),
            ),
          );
        },
      );
    },
  );
}

  void _navigateToSchedule(BuildContext context, Map<String, dynamic> item) {
    final currentDate = DateTime.now();
    switch (item['type']) {
      case 'teacher':
        SchedulePreferences.saveSchedule(
            'teacher', item['data']['id'], item['data']['short_name']);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => UniversalSchedulePage(
              targetData: item['data'],
              scheduleType: ScheduleType
                  .teacher, // или ScheduleType.group, или ScheduleType.place
            ),
          ),
          (route) => false,
        );
        break;
      case 'group':
        SchedulePreferences.saveSchedule(
            'group', item['data']['id'], item['data']['name']);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => GroupSchedulePage(
              groupData: item['data'],
              currentDate: currentDate,
            ),
          ),
          (route) => false,
        );
        break;
      case 'place':
        SchedulePreferences.saveSchedule(
            'place', item['data']['id'], item['data']['name']);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceSchedulePage(
              placeData: item['data'],
              currentDate: currentDate,
            ),
          ),
          (route) => false,
        );
        break;
    }
  }

  Widget _getLeadingIcon(String type) {
    String assetName;
    switch (type) {
      case 'teacher':
        assetName = 'assets/teacher_icon.svg';
        break;
      case 'place':
        assetName = 'assets/place_icon.svg';
        break;
      case 'group':
        assetName = 'assets/group_icon.svg';
        break;
      default:
        assetName = 'assets/teacher_icon.svg';
    }
    return SvgPicture.asset(assetName, width: 24, height: 24);
  }

  String _getTitle(dynamic item) {
    switch (item['type']) {
      case 'teacher':
        return item['data']['full_name'];
      case 'place':
        return item['data']['name'];
      case 'group':
        return item['data']['name'];
      default:
        return '';
    }
  }

  Widget _buildGroupTitle(dynamic item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          item['data']['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item['data']['faculty']['short_name']}, ${item['data']['course']} курс',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : hexToColor('#767676'),
              ),
            ),
            Text(
              item['data']['direction']['short_name'],
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : hexToColor('#767676'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _getTileColor(String type) {
    switch (type) {
      case 'teacher':
        return Colors.blue[50]!;
      case 'place':
        return Colors.orange[50]!;
      case 'group':
        return Colors.green[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getDarkModeColor(Color lightModeColor) {
    if (lightModeColor == Colors.blue[50]) {
      return const Color.fromARGB(255, 63, 110, 180);
    } else if (lightModeColor == Colors.orange[50]) {
      return Color.fromARGB(255, 177, 92, 45);
    } else if (lightModeColor == Colors.green[50]) {
      return const Color.fromARGB(255, 75, 131, 78);
    } else {
      return Colors.grey[800]!;
    }
  }
}
