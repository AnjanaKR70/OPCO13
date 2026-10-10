import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/issues_service.dart';
import '../services/localization_service.dart';

class SosAlertScreen extends StatefulWidget {
  final AlertItem alert;

  const SosAlertScreen({super.key, required this.alert});

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  
  String? _userName;
  String? _userPhone;

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
    
    _loadDeviceInfo();
  }
  
  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name');
      _userPhone = prefs.getString('user_phone');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String titleText;
    IconData alertIcon;
    String footerText;

    final loc = context.watch<LocalizationService>();
    
    if (widget.alert.riskLevel == RiskLevel.critical) {
      bgColor = Colors.red.shade900;
      titleText = loc.translate('CRITICAL THREAT DETECTED!');
      alertIcon = Icons.warning_amber_rounded;
      footerText = loc.translate('The malicious file has been blocked and safely quarantined.');
    } else if (widget.alert.riskLevel == RiskLevel.mid) {
      bgColor = Colors.orange.shade800;
      titleText = loc.translate('SUSPICIOUS FILE DETECTED');
      alertIcon = Icons.privacy_tip_outlined;
      footerText = loc.translate('This file has suspicious indicators. Proceed with extreme caution.');
    } else {
      bgColor = Colors.green.shade700;
      titleText = loc.translate('FILE IS SAFE');
      alertIcon = Icons.check_circle_outline;
      footerText = loc.translate('No threats detected. The file is safe to open.');
    }
    
    // Mask phone number to last 4 digits
    String? maskedPhone;
    if (_userPhone != null && _userPhone!.length >= 4) {
      maskedPhone = '****${_userPhone!.substring(_userPhone!.length - 4)}';
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Icon(
                    alertIcon,
                    color: Colors.white,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.alert.heading,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.alert.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      
                      // Device Identification (only show for high risk)
                      if (widget.alert.riskLevel == RiskLevel.critical || widget.alert.riskLevel == RiskLevel.mid) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white30, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          '${loc.translate("Received from: ")}${_userName ?? loc.translate("Unknown Device")}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (maskedPhone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${loc.translate("Device: ")}$maskedPhone',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  footerText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
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
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
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
                            foregroundColor: bgColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(true); // true means VIEW
                          },
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
