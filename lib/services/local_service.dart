import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  void _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  void toggleLocale() async {
    final prefs = await SharedPreferences.getInstance();
    if (_locale.languageCode == 'en') {
      _locale = const Locale('ml');
      await prefs.setString('languageCode', 'ml');
    } else {
      _locale = const Locale('en');
      await prefs.setString('languageCode', 'en');
    }
    notifyListeners();
  }
}
