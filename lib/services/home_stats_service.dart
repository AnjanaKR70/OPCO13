import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class HomeStatsService extends ChangeNotifier {
  int checkedToday = 0;
  int threatsThisWeek = 0;

  final List<String> safetyTips = [
    "We scan every file shared to you on WhatsApp before you open it.",
    "AI-generated images are checked automatically.",
    "Suspicious links are flagged before you tap them.",
    "Your SMS messages are filtered for known phishing attempts.",
  ];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Fetch real dashboard stats from the backend.
  /// Called after login when the JWT token is available.
  Future<void> fetchStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _error = 'Not logged in';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.dashboardStats),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        if (body['success'] == true) {
          final data = body['data'];

          // "Checked today" = total scans today
          checkedToday = data['today']['total_scans'] ?? 0;

          // "Threats this week" = threats blocked this week
          threatsThisWeek = data['this_week']['threats_blocked'] ?? 0;

          _error = null;
        } else {
          _error = body['message'] ?? 'Failed to load stats';
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('HomeStatsService.fetchStats error: $e');
      _error = 'Could not reach the server';
    }

    _isLoading = false;
    notifyListeners();
  }
}
