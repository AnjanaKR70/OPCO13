import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay_window;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'api_config.dart';


void _log(String msg) {
  // ignore: avoid_print
  print('[BACKGROUND] $msg');
}

const _allowedExtensions = {'.pdf','.apk','.txt','.html','.htm','.csv','.png','.jpg','.jpeg','.gif','.zip','.json'};
const _tempExtensions = {'.crdownload','.tmp','.part','.download','.partial','.opdownload'};

Future<void> initializeBackgroundService() async {
  // Background service is Android/iOS only — skip entirely on web
  if (kIsWeb) return;

  final service = FlutterBackgroundService();

  debugPrint('[SCAMUNDO_STARTUP] Initializing background service...');
  try {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'scamundo_foreground',
      'Scamundo Background Service',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // ignore: invalid_runtime_check_with_js_interop_types
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    await androidImplementation?.createNotificationChannel(channel);
    
    // Request POST_NOTIFICATIONS permission for Android 13+
    androidImplementation?.requestNotificationsPermission().catchError((e) {
      debugPrint('[SCAMUNDO_STARTUP] Failed to request notification permission: $e');
      return false;
    });

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'scamundo_foreground',
        initialNotificationTitle: 'Scamundo Active',
        initialNotificationContent: 'Monitoring files in background...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
    debugPrint('[SCAMUNDO_STARTUP] Background service initialized successfully.');
  } catch (e) {
    debugPrint('[SCAMUNDO_STARTUP] Error initializing background service: $e');
  }
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _log('Service Started');

  final Map<String, String> baselineFiles = {};
  final Set<String> scannedFiles = {};
  final Set<String> activeUploads = {};
  bool baselineDone = false;

  Timer.periodic(const Duration(seconds: 2), (timer) async {
    final List<String> targetPaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents',
    ];

    final Map<String, String> currentFiles = {};

    for (String path in targetPaths) {
      try {
        final directory = Directory(path);
        if (!await directory.exists()) continue;

        final List<FileSystemEntity> entities = await directory.list().toList();
        for (var entity in entities) {
          if (entity is File) {
            final lowerPath = entity.path.toLowerCase();
            if (_tempExtensions.any((ext) => lowerPath.endsWith(ext))) continue;
            
            final ext = _getExtension(entity.path);
            if (!_allowedExtensions.contains(ext)) continue;

            try {
              final stat = await entity.stat();
              if (stat.size == 0) continue;
              
              final signature = '${stat.size}_${stat.modified.millisecondsSinceEpoch}';
              currentFiles[entity.path] = signature;
            } catch (e) {}
          }
        }
      } catch (e) {}
    }

    if (!baselineDone) {
      baselineFiles.addAll(currentFiles);
      baselineDone = true;
      _log('Baseline complete. Indexed ${baselineFiles.length} files.');
      return;
    }

    final List<MapEntry<String, String>> newFiles = [];
    currentFiles.forEach((path, signature) {
      final isInBaseline = baselineFiles.containsKey(path) && baselineFiles[path] == signature;
      final isUploading = activeUploads.contains(path);
      if (!isInBaseline && !isUploading) {
        newFiles.add(MapEntry(path, signature));
      }
    });

    if (newFiles.isNotEmpty) {
      _log('Found ${newFiles.length} new files');
      for (final entry in newFiles) {
        final filePath = entry.key;
        final signature = entry.value;
        activeUploads.add(filePath); // Mark as active immediately
        _isFileStable(filePath).then((isStable) {
          if (isStable) {
            // Update baseline to current signature so we don't scan it again unless it changes
            baselineFiles[filePath] = signature;
            _uploadAndAnalyze(filePath, activeUploads, service);
          } else {
            activeUploads.remove(filePath);
          }
        });
      }
    }

    // Polling for URLs from NotificationScannerService
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Reload from disk to see changes made by native Kotlin service
      final pendingUrlsStr = prefs.getString('pending_urls');
      if (pendingUrlsStr != null && pendingUrlsStr != '[]') {
        await prefs.remove('pending_urls');
        try {
          final List<dynamic> urls = jsonDecode(pendingUrlsStr);
          for (final text in urls) {
            if (text is String) _processSharedTextBackground(text, activeUploads, service);
          }
        } catch (e) {
          _log('Error decoding pending URLs: $e');
        }
      }
    } catch (e) {
      _log('Error polling pending URLs: $e');
    }
  });
}

void _processSharedTextBackground(String text, Set<String> activeUploads, ServiceInstance service) {
  _log('Processing shared text for URLs: ${text.length > 30 ? text.substring(0, 27) + '...' : text}');
  final RegExp urlRegExp = RegExp(
    r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
    caseSensitive: false,
  );
  
  final matches = urlRegExp.allMatches(text);
  if (matches.isNotEmpty) {
    for (final match in matches) {
      final url = match.group(0);
      if (url != null) {
        _scanUrlBackground(url, activeUploads, service);
      }
    }
  } else {
    if (!text.contains(' ') && text.contains('.')) {
      _scanUrlBackground(text, activeUploads, service);
    }
  }
}

Future<void> _scanUrlBackground(String url, Set<String> activeUploads, ServiceInstance service) async {
  if (activeUploads.contains(url)) return; // Prevent duplicates in active process
  activeUploads.add(url);
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    final response = await http.post(
      Uri.parse(ApiConfig.scanUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': url}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      if (jsonBody['success'] == true && jsonBody['data'] != null) {
        final scanData = jsonBody['data'];
        
        service.invoke('onScamDetected', scanData); // to update UI if it's open
        
        final verdict = scanData['verdict']?.toString().toLowerCase();
        final riskLevel = scanData['risk_level']?.toString().toLowerCase();
        final isThreat = verdict == 'malicious' || verdict == 'suspicious';
        final isCritical = riskLevel == 'critical';
        
        if (isThreat && (isCritical || riskLevel == 'medium' || riskLevel == 'high')) {
            _log('URL Threat Detected (Risk: $riskLevel)! Showing notification...');
            // Inject a pseudo file_name so _showThreatNotification works gracefully
            scanData['file_name'] = url;
            await _showThreatNotification(scanData);
        }
      }
    }
  } catch (e) {
    _log('Error scanning URL in background: $e');
  } finally {
    // Add small delay before clearing active state to prevent immediate rescans
    Future.delayed(const Duration(seconds: 10), () => activeUploads.remove(url));
  }
}


Future<bool> _isFileStable(String filePath) async {
  try {
    final file = File(filePath);
    final stat1 = await file.stat();
    await Future.delayed(const Duration(milliseconds: 1000));
    final stat2 = await file.stat();
    return stat1.size == stat2.size && stat1.modified.millisecondsSinceEpoch == stat2.modified.millisecondsSinceEpoch;
  } catch (e) {
    return false;
  }
}

String _getExtension(String path) {
  final lastDot = path.lastIndexOf('.');
  if (lastDot == -1 || lastDot == path.length - 1) return '';
  return path.substring(lastDot).toLowerCase();
}

Future<void> _uploadAndAnalyze(String filePath, Set<String> activeUploads, ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.scanFile));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['source_app'] = 'Downloads';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    var response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      
      try {
        final jsonBody = jsonDecode(body);
        if (jsonBody['success'] == true && jsonBody['data'] != null) {
          final scanData = jsonBody['data'];
          
          // Send event to UI so if the UI is alive, it can show the SOS screen
          service.invoke('onScamDetected', scanData);
          
          final verdict = scanData['verdict']?.toString().toLowerCase();
          final riskLevel = scanData['risk_level']?.toString().toLowerCase();
          final isThreat = verdict == 'malicious' || verdict == 'suspicious';
          final isCritical = riskLevel == 'critical';
          
          if (isThreat && (isCritical || riskLevel == 'medium')) {
            _log('Threat Detected (Risk: $riskLevel)! Showing notification...');
            
            // Show a high-priority heads-up notification (works even when app is in background)
            await _showThreatNotification(scanData);
            
            // Removed intent.launch() so the app doesn't force itself to foreground.
            // The overlay will handle visibility.
          }
        }
      } catch (e) {
        _log('Error processing scan result: $e');
      }
    }
  } catch (e) {
    _log('Error uploading file: $e');
  } finally {
    activeUploads.remove(filePath);
  }
}

/// Show a high-priority heads-up notification for critical threats.
/// This appears as an overlay-style banner even when the app is in the background.
Future<void> _showThreatNotification(Map<String, dynamic> scanData) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    
    // Must initialize before showing
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: initSettings);
    
    final fileName = scanData['file_name'] ?? 'Unknown file';
    final verdict = scanData['verdict']?.toString().toUpperCase() ?? 'THREAT';
    final riskLevel = scanData['risk_level']?.toString().toUpperCase() ?? 'CRITICAL';
    final confidence = scanData['confidence'];
    
    String confStr = '';
    if (confidence != null) {
      final confPct = (confidence is num && confidence > 1.0) ? confidence : confidence * 100;
      confStr = ' (${(confPct as num).toStringAsFixed(2)}%)';
    }
    
    // Use file path hash as notification ID to prevent duplicates per file
    final notifId = fileName.hashCode.abs() % 100000;
    
    await plugin.show(
      id: notifId,
      title: '🚨 $verdict FILE DETECTED',
      body: '$fileName — Risk: $riskLevel$confStr. Tap to review.',
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

    if (!kIsWeb && riskLevel == 'CRITICAL') {
      try {
        final isGranted = await overlay_window.FlutterOverlayWindow.isPermissionGranted();
        if (isGranted) {
          await overlay_window.FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            overlayTitle: "Scamundo SOS",
            overlayContent: "Critical Threat Detected",
            flag: overlay_window.OverlayFlag.defaultFlag,
            alignment: overlay_window.OverlayAlignment.center,
            visibility: overlay_window.NotificationVisibility.visibilityPublic,
            positionGravity: overlay_window.PositionGravity.none,
            height: overlay_window.WindowSize.matchParent,
            width: overlay_window.WindowSize.matchParent,
          );
          
          await overlay_window.FlutterOverlayWindow.shareData(jsonEncode({
            'fileName': fileName,
            'riskLevel': riskLevel,
            'confidence': confStr,
            'userName': scanData['user_name'],
            'maskedPhone': _maskPhone(scanData['user_phone']),
          }));
        }
      } catch (e) {
        debugPrint('Error showing overlay: $e');
      }
    }
  } catch (e) {
    _log('Error showing threat notification: $e');
  }
}

String? _maskPhone(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  if (phone.length <= 4) return '****$phone';
  return '****${phone.substring(phone.length - 4)}';
}
