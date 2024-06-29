import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/schedule_selection_screen.dart';
import 'package:flutter_application_1/utils/schedule_preferences.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'teacher_schedule_page.dart';
import 'group_schedule_page.dart';
import 'place_schedule_page.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Поиск расписания',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.black),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchResults.clear();
                      });
                    },
                  )
                : null,
          ),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () async {
          await SchedulePreferences.clearSchedule();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScheduleSelectionPage(),
            ),
          );
        },
      ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _isSearching
                ? _searchResults.isNotEmpty
                    ? _buildSearchResults()
                    : _buildNoResults()
                : _buildInitialContent(),
      ),
    );
  }

  Widget _buildInitialContent() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 26.0, vertical: 36.0),
          child: SvgPicture.asset(
            'assets/search_schedule.svg',
            width: 300,
            height: 320,
          ),
        ),
        SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Начните вводить группу, преподавателя или аудиторию',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
            'assets/no_data.svg',
            width: 300,
            height: 300,
          ),
        ),
        SizedBox(height: 16),
        const Text(
          'Ничего не найдено',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            elevation: 2,
            child: ListTile(
              leading: _getLeadingIcon(item['type']),
              title: item['type'] == 'group'
                  ? _buildGroupTitle(item)
                  : Text(
                      _getTitle(item),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
              tileColor: _getTileColor(item['type']),
              onTap: () => _navigateToSchedule(context, item),
            ),
          ),
        );
      },
    );
  }

  void _navigateToSchedule(BuildContext context, Map<String, dynamic> item) {
  final currentDate = DateTime.now();
  switch (item['type']) {
    case 'teacher':
      SchedulePreferences.saveSchedule('teacher', item['data']['id'], item['data']['short_name']);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherSchedulePage(
            teacherData: item['data'],
            currentDate: currentDate,
          ),
        ),
        (route) => false,
      );
      break;
    case 'group':
      SchedulePreferences.saveSchedule('group', item['data']['id'], item['data']['name']);
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
      SchedulePreferences.saveSchedule('place', item['data']['id'], item['data']['name']);
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
        assetName = 'assets/default_icon.svg';
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item['data']['faculty']['short_name']}, ${item['data']['course']} курс',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: hexToColor('#767676'),
              ),
            ),
            Text(
              item['data']['direction']['short_name'],
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: hexToColor('#767676'),
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
        return Colors.white;
    }
  }
}
