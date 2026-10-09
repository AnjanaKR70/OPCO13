import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'api_config.dart';

void _log(String msg) {
  // ignore: avoid_print
  print(msg);
}

enum RiskLevel { critical, mid, safe, unknown }

class AlertItem {
  final String heading;
  final String description;
  final RiskLevel riskLevel;
  final DateTime timestamp;

  AlertItem({
    required this.heading,
    required this.description,
    required this.riskLevel,
    required this.timestamp,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    RiskLevel level = RiskLevel.safe;
    final r = json['risk_level']?.toString().toLowerCase();
    if (r == 'critical') {
      level = RiskLevel.critical;
    } else if (r == 'medium' || r == 'mid') {
      level = RiskLevel.mid;
    } else if (r == 'unknown' || r == 'error' || r == 'unsupported' || r == null) {
      level = RiskLevel.unknown;
    }

    return AlertItem(
      heading: json['heading'] ?? 'Alert',
      description: json['description'] ?? 'No description provided.',
      riskLevel: level,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Create an AlertItem directly from a /scan response for immediate SOS.
  factory AlertItem.fromScanResponse(Map<String, dynamic> data) {
    final riskLevel = data['risk_level']?.toString().toLowerCase();
    RiskLevel level = RiskLevel.safe;
    if (riskLevel == 'critical') {
      level = RiskLevel.critical;
    } else if (riskLevel == 'medium') {
      level = RiskLevel.mid;
    } else if (riskLevel == 'unknown' || riskLevel == 'error' || riskLevel == 'unsupported' || riskLevel == null) {
      level = RiskLevel.unknown;
    }

    // Build a human-readable heading from the verdict
    final verdict = (data['verdict'] ?? 'unknown').toString().toLowerCase();
    String heading;
    switch (verdict) {
      case 'malicious':
      case 'dangerous':
      case 'phishing':
        heading = '🚨 Critical File Detected';
        break;
      case 'suspicious':
        heading = '⚠️ Suspicious File Detected';
        break;
      case 'unsupported':
      case 'error':
      case 'unknown':
        heading = 'File Scan — Unsupported/Error';
        break;
      default:
        heading = 'File Scan — Safe';
    }

    // Build description
    final fileName = data['file_name'] ?? 'unknown';
    final reason = data['reason'] ?? '';
    final confidence = data['confidence'];
    final parts = <String>['File: $fileName'];
    if (reason.toString().isNotEmpty) parts.add('Reason: $reason');
    if (confidence != null) {
      // ML scanner already returns confidence as percentage (e.g. 99.81)
      // If value > 1.0, it's already a percentage; don't multiply again
      final confPct = (confidence is num && confidence > 1.0) ? confidence : confidence * 100;
      parts.add('Confidence: ${confPct.toStringAsFixed(2)}%');
    }
    parts.add('Risk Level: ${riskLevel.toString().toUpperCase()}');

    return AlertItem(
      heading: heading,
      description: parts.join(' | '),
      riskLevel: level,
      timestamp: DateTime.now(),
    );
  }
}

/// File extensions that correspond to our backend's allowed MIME types.
const _allowedExtensions = {
  '.pdf',
  '.apk',
  '.txt',
  '.html',
  '.htm',
  '.csv',
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.zip',
  '.json',
};

/// Temporary/incomplete download file extensions to always skip.
const _tempExtensions = {
  '.crdownload', // Chrome
  '.tmp',
  '.part', // Firefox
  '.download', // Generic
  '.partial',
  '.opdownload', // Opera
};

class IssuesService extends ChangeNotifier {
  List<AlertItem> alerts = [];
  bool isLoading = false;
  String? error;

  Timer? _pollingTimer;

  // ── File monitoring state ──────────────────────────────────────────────

  /// Baseline of files that existed BEFORE the app started monitoring.
  /// These are never uploaded — they were already on the device.
  final Map<String, String> _baselineFiles = {};
  bool _baselineDone = false;

  /// Set of file paths we have already successfully uploaded & scanned.
  /// Separate from baseline so that a failed upload doesn't block retries.
  final Set<String> _scannedFiles = {};

  /// Track the timestamp of the latest alert for backend-polling SOS.
  DateTime? _latestAlertTimestamp;

  /// Callback for SOS screen navigation — set by startPolling.
  Function(AlertItem)? _onScamDetected;
  
  StreamSubscription? _backgroundSubscription;

  // ── Polling ────────────────────────────────────────────────────────────

  void startPolling(Function(AlertItem) onScamDetected) {
    _log('[SCAMUNDO] ===== LISTENING TO BACKGROUND SERVICE =====');
    _latestAlertTimestamp = null;
    _onScamDetected = onScamDetected;
    _pollingTimer?.cancel();
    _backgroundSubscription?.cancel();
    
    // Listen to background service events
    _backgroundSubscription = FlutterBackgroundService().on('onScamDetected').listen((event) {
      if (event != null) {
        _log('[SCAMUNDO] >>> RECEIVED ALERT FROM BACKGROUND SERVICE <<<');
        try {
          final alert = AlertItem.fromScanResponse(event.cast<String, dynamic>());
          alerts.insert(0, alert);
          notifyListeners();
          
          // Only trigger SOS overlay for CRITICAL threats
          if (alert.riskLevel == RiskLevel.critical && _onScamDetected != null) {
            _log('[SCAMUNDO] CRITICAL risk — triggering SOS overlay');
            _onScamDetected!(alert);
          }
          _latestAlertTimestamp = DateTime.now();
        } catch (e) {
          _log('[SCAMUNDO] Error parsing background event: $e');
        }
      }
    });

    // Still poll backend periodically just to keep the Alerts tab up to date
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await fetchAlerts(silent: true);
      _checkForNewBackendAlerts();
    });
  }

  void _checkForNewBackendAlerts() {
    if (alerts.isNotEmpty) {
      final newestAlert = alerts.first;

      if (_latestAlertTimestamp == null) {
        _latestAlertTimestamp = newestAlert.timestamp;
        _log('[SCAMUNDO] Baseline alert timestamp set to: $_latestAlertTimestamp');
      } else {
        if (newestAlert.timestamp.isAfter(_latestAlertTimestamp!)) {
          _log('[SCAMUNDO] !!! NEW BACKEND ALERT !!! ${newestAlert.heading}');
          _latestAlertTimestamp = newestAlert.timestamp;
          // Only trigger SOS from backend if it wasn't already triggered
          // by the immediate scan response (avoid double-trigger).
          // We don't trigger here because _uploadAndTriggerSOS already does it.
        }
      }
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  // ── Fetch alerts from backend ──────────────────────────────────────────

  Future<void> fetchAlerts({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        _log('[SCAMUNDO] fetchAlerts: No JWT token found!');
        if (!silent) {
          error = 'Not logged in';
          isLoading = false;
          notifyListeners();
        }
        return;
      }

      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final url = '${ApiConfig.issues}?page=1&page_size=50&_t=$cacheBuster';
      _log('[SCAMUNDO] fetchAlerts: GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      _log('[SCAMUNDO] fetchAlerts: status=${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> items = body['data']?['issues'] ?? [];
          _log('[SCAMUNDO] fetchAlerts: parsed ${items.length} issues from response');
          alerts = items.map((e) => AlertItem.fromJson(e)).toList();
          if (!silent) error = null;
        } else {
          _log('[SCAMUNDO] fetchAlerts: API returned success=false: ${body['message']}');
          if (!silent) error = body['message'] ?? 'Failed to load alerts';
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _log('[SCAMUNDO] fetchAlerts: Auth expired (401/403). Clearing token.');
        await prefs.remove('jwt_token');
        await prefs.setBool('isLoggedIn', false);
        if (!silent) error = 'Session expired. Please log in again.';
      } else {
        _log('[SCAMUNDO] fetchAlerts: HTTP error ${response.statusCode}');
        if (!silent) error = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _log('[SCAMUNDO] fetchAlerts ERROR: $e');
      if (!silent) error = 'Could not reach the server';
    }

    if (!silent) {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Local file scanning ────────────────────────────────────────────────


}
