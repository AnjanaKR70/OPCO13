import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'services/localization_service.dart';

@pragma("vm:entry-point")
void runOverlay() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: OverlayWidget(),
      ),
    ),
  );
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  
  Map<String, dynamic> _alertData = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is String) {
        try {
          setState(() {
            _alertData = jsonDecode(event);
          });
        } catch (e) {
          debugPrint('Error parsing overlay data: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _dismissOverlay() {
    FlutterOverlayWindow.closeOverlay();
  }
  
  void _viewAlert() async {
    FlutterOverlayWindow.closeOverlay();
    
    // Launch SCAMundo app to the foreground
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.example.scamundo',
      componentName: 'com.example.scamundo.MainActivity',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    if (_alertData.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final loc = context.watch<LocalizationService>();
    
    final fileName = _alertData['fileName'] ?? 'Unknown';
    final riskLevel = _alertData['riskLevel']?.toString().toUpperCase() ?? 'HIGH';
    final confidence = _alertData['confidence']?.toString() ?? '0.00%';
    final userName = _alertData['userName'];
    final maskedPhone = _alertData['maskedPhone'];
    
    final bgColor = Colors.red.shade900.withOpacity(0.95);
    final titleText = loc.translate('CRITICAL THREAT DETECTED');
    const alertIcon = Icons.warning_amber_rounded;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    alertIcon,
                    color: Colors.white,
                    size: 90,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${loc.translate("File")}: $fileName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${loc.translate("Threat Level")}: $riskLevel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${loc.translate("Confidence")}: $confidence',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white30, height: 1),
                      const SizedBox(height: 12),
                      
                      Text(
                        '${loc.translate("Received from")}:\n${userName ?? loc.translate("Unknown Device")}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (maskedPhone != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${loc.translate("Phone")}:\n$maskedPhone',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white54, width: 2),
                            ),
                          ),
                          onPressed: _dismissOverlay,
                          child: Text(
                            loc.translate('DISMISS'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _viewAlert,
                          child: Text(
                            loc.translate('VIEW'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
