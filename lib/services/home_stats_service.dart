import 'package:flutter/material.dart';

class HomeStatsService extends ChangeNotifier {
  int checkedToday = 0;
  int threatsThisWeek = 0;
  bool isNewUser = false;

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

  /// Fetch mock dashboard stats.
  /// If [newUser] is true, show empty/zero stats (fresh sign-up).
  Future<void> fetchStats({bool newUser = false}) async {
    _isLoading = true;
    _error = null;
    isNewUser = newUser;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (newUser) {
      checkedToday = 0;
      threatsThisWeek = 0;
    } else {
      checkedToday = 145;
      threatsThisWeek = 3;
    }
    _error = null;

    _isLoading = false;
    notifyListeners();
  }
}
