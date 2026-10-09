import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single app that can be protected for scam scanning.
class ProtectedApp {
  final String name;
  final IconData icon;
  bool enabled;

  ProtectedApp({
    required this.name,
    required this.icon,
    this.enabled = true,
  });
}

class PermissionState extends ChangeNotifier {
  // ── Device Permissions ─────────────────────────────────────────────────
  bool storageAllowed = false;
  bool phoneAllowed = false;
  bool locationAllowed = false;
  bool smsAllowed = false;
  bool googleAllowed = false;
  bool overlayAllowed = false;

  // ── Alert Settings ─────────────────────────────────────────────────────
  bool alertsEnabled = true;
  bool vibrationEnabled = true;
  bool soundEnabled = true;

  // ── App Protection ─────────────────────────────────────────────────────
  bool _protectAll = true;

  bool get protectAll => _protectAll;

  final List<ProtectedApp> _protectedApps = [
    ProtectedApp(name: 'WhatsApp', icon: Icons.chat),
    ProtectedApp(name: 'Telegram', icon: Icons.send),
    ProtectedApp(name: 'Instagram', icon: Icons.camera_alt),
    ProtectedApp(name: 'Facebook', icon: Icons.facebook),
    ProtectedApp(name: 'Gmail', icon: Icons.email),
    ProtectedApp(name: 'Chrome', icon: Icons.language),
    ProtectedApp(name: 'Downloads', icon: Icons.download),
  ];

  List<ProtectedApp> get protectedApps => List.unmodifiable(_protectedApps);

  PermissionState() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    alertsEnabled = prefs.getBool('alerts_enabled') ?? true;
    vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    soundEnabled = prefs.getBool('sound_enabled') ?? true;
    notifyListeners();
  }

  Future<void> setAlertsEnabled(bool value) async {
    alertsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
    notifyListeners();
  }

  // ── Permission Setters ─────────────────────────────────────────────────

  void grantStorage(bool granted) {
    storageAllowed = granted;
    notifyListeners();
  }

  void grantPhone(bool granted) {
    phoneAllowed = granted;
    notifyListeners();
  }

  void grantLocation(bool granted) {
    locationAllowed = granted;
    notifyListeners();
  }

  void grantSms(bool granted) {
    smsAllowed = granted;
    notifyListeners();
  }

  void grantGoogle(bool granted) {
    googleAllowed = granted;
    notifyListeners();
  }

  void grantOverlay(bool granted) {
    overlayAllowed = granted;
    notifyListeners();
  }

  // ── App Protection Setters ─────────────────────────────────────────────

  /// Toggle "Protect all apps". When ON, every individual app is enabled
  /// and their individual toggles become non-interactive.
  void setProtectAll(bool value) {
    _protectAll = value;
    if (value) {
      for (final app in _protectedApps) {
        app.enabled = true;
      }
    }
    notifyListeners();
  }

  /// Toggle an individual app. If "Protect all" is currently ON and
  /// the user toggles any single app off, "Protect all" is first
  /// turned off automatically, then the individual change is applied.
  void setAppProtection(int index, bool value) {
    if (_protectAll && !value) {
      // Turning off an individual app while "all" is on:
      // first disable "protect all", keep others enabled, then apply the change.
      _protectAll = false;
    }
    _protectedApps[index].enabled = value;
    // If user manually enabled all individual apps, auto-enable "protect all".
    if (_protectedApps.every((a) => a.enabled)) {
      _protectAll = true;
    }
    notifyListeners();
  }
}
