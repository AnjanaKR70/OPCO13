import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay_window;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // import globalNavigatorKey
import 'api_config.dart';

class IntentService {
  static const MethodChannel _channel = MethodChannel('com.example.scamundo/intents');
  static final Set<String> _scannedUrls = {};

  static void initialize() {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedUrlReceived') {
        final String? text = call.arguments as String?;
        if (text != null) {
          _processSharedText(text);
        }
      } else if (call.method == 'onSharedFileReceived') {
        final String? filePath = call.arguments as String?;
        if (filePath != null) {
          _scanFile(filePath);
        }
      }
    });

    // Check for initial URL on cold start
    _channel.invokeMethod('getSharedUrl').then((value) {
      if (value != null && value is String) {
        _processSharedText(value);
      }
    });

    // Check for initial File on cold start
    _channel.invokeMethod('getSharedFile').then((value) {
      if (value != null && value is String) {
        _scanFile(value);
      }
    });
  }

  static void _processSharedText(String text) {
    debugPrint('[SCAMUNDO_ALERT_FLOW] 1. Intent/Notification received. Text length: ${text.length}');
    // Advanced URL extraction regex supporting query params, encoded chars, subdomains, deep paths
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(text);
    if (matches.isNotEmpty) {
      debugPrint('[SCAMUNDO_ALERT_FLOW] 3. URL detected. Found ${matches.length} URL(s) in text.');
      for (final match in matches) {
        final url = match.group(0);
        if (url != null) {
          debugPrint('[SCAMUNDO_ALERT_FLOW] 4. URL accepted for scanning: $url');
          _scanUrl(url);
        }
      }
    } else {
      // If it looks like a URL but didn't match the strict regex, try scanning it anyway if it doesn't have spaces
      if (!text.contains(' ') && text.contains('.')) {
         debugPrint('[SCAMUNDO_ALERT_FLOW] 3. Fallback URL detected: $text');
         debugPrint('[SCAMUNDO_ALERT_FLOW] 4. URL accepted for scanning (fallback): $text');
         _scanUrl(text);
      } else {
         debugPrint('[SCAMUNDO_ALERT_FLOW] 4. URL rejected: No valid URL found in text.');
      }
    }
  }

  static Future<void> _scanUrl(String url) async {
    debugPrint('[IntentService] Received URL to scan: $url');
    if (_scannedUrls.contains(url)) {
      debugPrint('[SCAMUNDO_ALERT_FLOW] 5. Duplicate suppressed: URL recently scanned.');
      return;
    }
    debugPrint('[SCAMUNDO_ALERT_FLOW] 5. Event accepted: URL not in recent cache.');
    _scannedUrls.add(url);
    Future.delayed(const Duration(seconds: 5), () => _scannedUrls.remove(url));

    BuildContext? context = globalNavigatorKey.currentContext;
    bool isCancelled = false;

    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async {
            isCancelled = true;
            return true;
          },
          child: AlertDialog(
            title: const Text("Scamundo URL Safety Gate"),
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text("Scanning\n$url\nfor threats...")),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ).then((_) {
        isCancelled = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
         if (context != null && !isCancelled) {
           isCancelled = true;
           Navigator.of(context, rootNavigator: true).pop();
         }
         _showAuthExpiredNotification();
         debugPrint('[SCAMUNDO_ALERT_FLOW] 12. Error: Auth token missing or expired.');
         return;
      }
      
      debugPrint('[SCAMUNDO_ALERT_FLOW] 6. Scan request started for URL.');

      final response = await http.post(
        Uri.parse(ApiConfig.scanUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 15));

      if (isCancelled) {
        debugPrint('[SCAMUNDO_ALERT_FLOW] Scan cancelled by user.');
        return;
      }

      debugPrint('[SCAMUNDO_ALERT_FLOW] 7. Backend response status received: ${response.statusCode}');

      if (context != null && !isCancelled) {
        isCancelled = true;
        Navigator.of(context, rootNavigator: true).pop(); // close scanning dialog
      }

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody['success'] == true && jsonBody['data'] != null) {
          final scanData = jsonBody['data'];
          _handleScanResult(scanData, url);
        } else {
          _showErrorDialog(url);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
         await _handleAuthFailure();
      } else {
         debugPrint('API returned error: ${response.statusCode}');
         _scannedUrls.remove(url);
         _showErrorDialog(url, error: 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[SCAMUNDO_ALERT_FLOW] 12. Error and recovery action: Exception during scan - $e');
      _scannedUrls.remove(url);
      if (isCancelled) return;
      if (context != null && !isCancelled) {
        isCancelled = true;
        Navigator.of(context, rootNavigator: true).pop(); // close scanning dialog on error
      }
      _showErrorDialog(url, isFile: false, error: e.toString());
    }
  }

  static Future<void> _scanFile(String filePath) async {
    debugPrint('[SCAMUNDO_ALERT_FLOW] 1. Intent/Notification received. File: $filePath');
    debugPrint('[SCAMUNDO_ALERT_FLOW] 3. File detected: $filePath');
    debugPrint('[SCAMUNDO_ALERT_FLOW] 4. File accepted for scanning.');
    debugPrint('[SCAMUNDO_ALERT_FLOW] 5. Event accepted: File scanning initiated.');
    BuildContext? context = globalNavigatorKey.currentContext;
    bool isCancelled = false;

    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async {
            isCancelled = true;
            return true;
          },
          child: AlertDialog(
            title: const Text("Scamundo File Safety Gate"),
            content: Row(
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text("Scanning file for threats...")),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ).then((_) {
        isCancelled = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
         if (context != null && !isCancelled) {
           isCancelled = true;
           Navigator.of(context, rootNavigator: true).pop();
         }
         _showAuthExpiredNotification();
         return;
      }
      
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.scanFile));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      if (isCancelled) return;

      final response = await http.Response.fromStream(streamedResponse);
      if (isCancelled) return;

      if (context != null && !isCancelled) {
        isCancelled = true;
        Navigator.of(context, rootNavigator: true).pop(); // close scanning dialog
      }

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody['success'] == true && jsonBody['data'] != null) {
          final scanData = jsonBody['data'];
          _handleScanResult(scanData, filePath, isFile: true);
        } else {
          _showErrorDialog(filePath, isFile: true);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
         await _handleAuthFailure();
      } else {
         debugPrint('API returned error: ${response.statusCode}');
         _showErrorDialog(filePath, isFile: true, error: 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error scanning file: $e');
      if (isCancelled) return;
      if (context != null && !isCancelled) {
        isCancelled = true;
        Navigator.of(context, rootNavigator: true).pop(); // close scanning dialog on error
      }
      _showErrorDialog(filePath, isFile: true, error: e.toString());
    }
  }

  static Future<void> _cleanupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
         await file.delete();
         debugPrint('[IntentService] Cleaned up temporary file: $filePath');
      }
    } catch (e) {
       debugPrint('[IntentService] Failed to clean up file: $e');
    }
  }

  static void _showErrorDialog(String target, {bool isFile = false, String? error}) {
    BuildContext? context = globalNavigatorKey.currentContext;
    if (context == null) return;
    
    String errorMsg = error != null ? "\n\nError: $error" : "\n\nError: Server Unavailable";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFile ? "Unable to verify this file" : "Unable to verify this link"),
        content: Text("The safety scan could not be completed or timed out for:\n$target$errorMsg\n\nDo not proceed if you do not trust this ${isFile ? 'file' : 'link'}."),
        actions: [
          TextButton(
            child: const Text("Back"),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isFile) _cleanupFile(target);
            },
          ),
          TextButton(
            child: const Text("Retry"),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isFile) {
                _scanFile(target);
              } else {
                _scanUrl(target);
              }
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _handleScanResult(Map<String, dynamic> scanData, String originalTarget, {bool isFile = false}) async {
    final verdict = scanData['verdict']?.toString().toLowerCase();
    final riskLevel = scanData['risk_level']?.toString().toLowerCase();
    final reason = scanData['reason']?.toString() ?? 'No reason provided';
    final isThreat = verdict == 'malicious' || verdict == 'suspicious';
    final isCritical = riskLevel == 'critical';

    debugPrint('[SCAMUNDO_ALERT_FLOW] 8. Risk level parsed: $riskLevel (Verdict: $verdict)');
    debugPrint('[SCAMUNDO_ALERT_FLOW] 9. Alert decision made: isThreat=$isThreat, isCritical=$isCritical');

    BuildContext? context = globalNavigatorKey.currentContext;
    if (context != null) {
      bool isSafe = verdict == 'safe';
      bool isUnknown = verdict == 'unsupported' || verdict == 'error' || verdict == 'unknown' || riskLevel == 'unknown';
      String title = isSafe ? "URL Safe" : (isUnknown ? "Unable to Verify" : (isThreat ? "Threat Detected!" : "Suspicious URL"));
      if (isFile) {
         title = isSafe ? "File Safe" : (isUnknown ? "Unable to Verify" : (isThreat ? "Threat Detected!" : "Suspicious File"));
      }
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: TextStyle(color: isSafe ? Colors.green : Colors.red)),
          content: SingleChildScrollView(
            child: Text("Verdict: ${verdict?.toUpperCase()}\nRisk: ${riskLevel?.toUpperCase()}\nReason: $reason\n\nTarget: $originalTarget"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (isFile) _cleanupFile(originalTarget);
              },
            ),
            TextButton(
              child: Text(isSafe ? (isFile ? "Dismiss" : "Continue to Website") : "Continue Anyway (Dangerous)"),
              style: isSafe ? null : TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                if (isCritical) {
                  showDialog(
                    context: ctx,
                    builder: (innerCtx) => AlertDialog(
                      title: const Text("CRITICAL WARNING", style: TextStyle(color: Colors.red)),
                      content: const Text("This target is classified as CRITICAL. Proceeding may compromise your device or data. Are you absolutely sure you want to override this block?"),
                      actions: [
                        TextButton(
                          child: const Text("Go Back (Safe)"),
                          onPressed: () {
                            Navigator.of(innerCtx).pop();
                            Navigator.of(ctx).pop();
                            if (isFile) _cleanupFile(originalTarget);
                          },
                        ),
                        TextButton(
                          child: const Text("I accept the risk"),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(innerCtx).pop();
                            Navigator.of(ctx).pop();
                            if (isFile) _cleanupFile(originalTarget);
                            if (!isFile) {
                              launchUrl(Uri.parse(originalTarget), mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.of(ctx).pop();
                  if (isFile) _cleanupFile(originalTarget);
                  if (!isFile) {
                    launchUrl(Uri.parse(originalTarget), mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
          ],
        ),
      );
    }

    if (isThreat && (isCritical || riskLevel == 'medium' || riskLevel == 'high')) {
      final prefs = await SharedPreferences.getInstance();
      final alertsEnabled = prefs.getBool('alerts_enabled') ?? true;
      final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      final soundEnabled = prefs.getBool('sound_enabled') ?? true;

      if (!alertsEnabled) return;

      // Show notification
      await _showThreatNotification(scanData, originalTarget, isFile: isFile);

      // Trigger native vibration/sound if enabled
      if (vibrationEnabled) {
        final duration = isCritical ? 1000 : 500;
        final intensity = isCritical ? 255 : 150;
        _channel.invokeMethod('vibrate', {'duration': duration, 'intensity': intensity});
      }
      
      if (soundEnabled) {
         _channel.invokeMethod('playSound');
      }

      // Show SOS Overlay for CRITICAL/HIGH
      if (!kIsWeb && (isCritical || riskLevel == 'high')) {
        try {
          debugPrint('[SCAMUNDO_ALERT_FLOW] 11. Overlay requested.');
          final isGranted = await overlay_window.FlutterOverlayWindow.isPermissionGranted();
          if (isGranted) {
            await overlay_window.FlutterOverlayWindow.showOverlay(
              enableDrag: false,
              overlayTitle: "Scamundo SOS",
              overlayContent: "URL Threat Detected",
              flag: overlay_window.OverlayFlag.defaultFlag,
              alignment: overlay_window.OverlayAlignment.center,
              visibility: overlay_window.NotificationVisibility.visibilityPublic,
              positionGravity: overlay_window.PositionGravity.none,
              height: overlay_window.WindowSize.matchParent,
              width: overlay_window.WindowSize.matchParent,
            );
            
            final confidence = scanData['confidence'];
            String confStr = '';
            if (confidence != null) {
              final confPct = (confidence is num && confidence > 1.0) ? confidence : confidence * 100;
              confStr = ' (${(confPct as num).toStringAsFixed(2)}%)';
            }

            await overlay_window.FlutterOverlayWindow.shareData(jsonEncode({
              'fileName': originalTarget.length > 50 ? originalTarget.substring(0, 47) + '...' : originalTarget,
              'riskLevel': riskLevel?.toUpperCase() ?? 'CRITICAL',
              'confidence': confStr,
              'userName': scanData['user_name'] ?? 'User',
              'maskedPhone': _maskPhone(scanData['user_phone']),
            }));
            debugPrint('[SCAMUNDO_ALERT_FLOW] 11. Overlay actual result: Successfully shown.');
          } else {
            debugPrint('[SCAMUNDO_ALERT_FLOW] 11. Overlay actual result: Failed - Permission not granted.');
          }
        } catch (e) {
          debugPrint('[SCAMUNDO_ALERT_FLOW] 11. Overlay actual result: Error - $e');
        }
      }
    }
  }

  static Future<void> _handleAuthFailure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.setBool('isLoggedIn', false);
    await _showAuthExpiredNotification();
  }

  static Future<void> _showAuthExpiredNotification() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await plugin.initialize(settings: initSettings);
      
      await plugin.show(
        id: 99999,
        title: 'SCAMundo Authentication Expired',
        body: 'Tap to login to continue scanning URLs and files.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'scamundo_auth_alerts',
            'Authentication Alerts',
            channelDescription: 'Alerts for expired login sessions',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing auth notification: $e');
    }
  }

  static Future<void> _showThreatNotification(Map<String, dynamic> scanData, String target, {bool isFile = false}) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await plugin.initialize(settings: initSettings);
      
      final verdict = scanData['verdict']?.toString().toUpperCase() ?? 'THREAT';
      final riskLevel = scanData['risk_level']?.toString().toUpperCase() ?? 'HIGH';
      final confidence = scanData['confidence'];
      
      String confStr = '';
      if (confidence != null) {
        final confPct = (confidence is num && confidence > 1.0) ? confidence : confidence * 100;
        confStr = ' (${(confPct as num).toStringAsFixed(2)}%)';
      }
      
      final notifId = target.hashCode.abs() % 100000;
      final displayTarget = target.length > 40 ? target.substring(0, 37) + '...' : target;
      
      await plugin.show(
        id: notifId,
        title: '🚨 $verdict ${isFile ? 'FILE' : 'URL'} DETECTED',
        body: '$displayTarget — Risk: $riskLevel$confStr',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'scamundo_threat_alerts',
            'Threat Alerts',
            channelDescription: 'Critical malware/phishing threat alerts',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: false,
          ),
        ),
      );
      debugPrint('[SCAMUNDO_ALERT_FLOW] 10. Notification successfully posted for $displayTarget');
    } catch (e) {
      debugPrint('[SCAMUNDO_ALERT_FLOW] 10. Notification failed: $e');
    }
  }

  static String? _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    if (phone.length <= 4) return '****$phone';
    return '****${phone.substring(phone.length - 4)}';
  }
}
