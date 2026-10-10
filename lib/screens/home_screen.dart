import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'alerts_tab.dart';
import 'connect_tab.dart';
import 'settings_tab.dart';
import 'profile_screen.dart';
import '../services/home_stats_service.dart';
import '../services/issues_service.dart';
import '../services/localization_service.dart';
import '../services/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sos_alert_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _sosVisible = false;

  @override
  void initState() {
    super.initState();
    // Start polling for new HIGH risk issues
    Future.microtask(() {
      if (mounted) {
        context.read<IssuesService>().startPolling((newAlert) {
          if (mounted && !_sosVisible) {
            _sosVisible = true;
            Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => SosAlertScreen(alert: newAlert),
              ),
            ).then((viewDetails) {
              _sosVisible = false;
              if (viewDetails == true && mounted) {
                _switchTab(1);
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // We don't have direct access to stop polling here cleanly without context if it's unmounting,
    // but the Provider will dispose the service or we can just let it run.
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            HomeTab(onNavigateToAlerts: () => _switchTab(1)),
            const AlertsTab(),
            const ConnectTab(),
            const SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryNavy,
        unselectedItemColor: const Color(0xFFB4B2A9),
        type: BottomNavigationBarType.fixed,
        onTap: _switchTab,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: context.watch<LocalizationService>().translate('Home')),
          BottomNavigationBarItem(icon: const Icon(Icons.warning_amber_rounded), label: context.watch<LocalizationService>().translate('Alert')),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: context.watch<LocalizationService>().translate('Connect')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: context.watch<LocalizationService>().translate('Settings')),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToAlerts;
  
  const HomeTab({super.key, required this.onNavigateToAlerts});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late PageController _pageController;
  Timer? _timer;
  int _currentTipIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  bool _isScanningUrl = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
    // Fetch real stats and alerts from backend
    Future.microtask(() {
      if (mounted) {
        context.read<HomeStatsService>().fetchStats();
        context.read<IssuesService>().fetchAlerts();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final statsService = context.read<HomeStatsService>();
      if (statsService.safetyTips.isNotEmpty) {
        final nextIndex = (_currentTipIndex + 1) % statsService.safetyTips.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentTipIndex = nextIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _urlController.dispose();
    super.dispose();
  }
  
  Future<void> _scanManualUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isScanningUrl = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      
      await http.post(
        Uri.parse(ApiConfig.scanUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 15));
      _urlController.clear();
      if (mounted) {
        context.read<IssuesService>().fetchAlerts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LocalizationService>().translate('URL scanned successfully. Check Alerts.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LocalizationService>().translate('Failed to scan URL'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningUrl = false);
      }
    }
  }
  
  Color _riskDotColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical: return const Color(0xFFA32D2D);
      case RiskLevel.mid: return const Color(0xFFBA7517);
      case RiskLevel.safe: return const Color(0xFF3B8B22);
      case RiskLevel.unknown: return const Color(0xFF999999);
    }
  }
  
  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final statsService = context.watch<HomeStatsService>();
    final issuesService = context.watch<IssuesService>();
    
    // Get 2 most recent alerts
    final displayAlerts = issuesService.alerts.take(2).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo + Text
                Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 28, fit: BoxFit.contain),
                  ],
                ),
                // Language + Profile
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        context.read<LocalizationService>().toggleLanguage();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 48, // 48dp touch target
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EFE8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: context.watch<LocalizationService>().isEnglish ? FontWeight.w800 : FontWeight.w500,
                                color: context.watch<LocalizationService>().isEnglish ? AppTheme.primaryNavy : const Color(0xFF999999),
                              ),
                            ),
                            const Text(
                              ' | ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF999999),
                              ),
                            ),
                            Text(
                              'മല',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: !context.watch<LocalizationService>().isEnglish ? FontWeight.w800 : FontWeight.w500,
                                color: !context.watch<LocalizationService>().isEnglish ? AppTheme.primaryNavy : const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      },
                      customBorder: const CircleBorder(),
                      child: const CircleAvatar(
                        radius: 24, // 48dp touch target
                        backgroundColor: Color(0xFFF1EFE8),
                        child: Icon(Icons.person, color: AppTheme.primaryNavy, size: 24),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          
          // 2. Combined status card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.watch<LocalizationService>().translate("You're protected"),
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.watch<LocalizationService>().translate("Scanning active"),
                            style: const TextStyle(
                              color: Color(0xFFB4B2A9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Stat tiles
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.today, color: Colors.white.withOpacity(0.8), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.watch<LocalizationService>().translate('Checked today'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                statsService.checkedToday.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month, color: Colors.white.withOpacity(0.8), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.watch<LocalizationService>().translate('This week'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                statsService.threatsThisWeek.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 14),

          // MANUAL URL SCANNER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.backgroundWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.watch<LocalizationService>().translate('Scan a URL'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'https://...',
                            hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF9F9FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE8EAF0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE8EAF0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryNavy),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isScanningUrl ? null : _scanManualUrl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isScanningUrl
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(context.watch<LocalizationService>().translate('Scan')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 14),
          
          // 3. Safety tip card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE6F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primaryNavy,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.watch<LocalizationService>().translate('Safety tip'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.primaryNavy,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentTipIndex = index;
                        });
                      },
                      itemCount: statsService.safetyTips.length,
                      itemBuilder: (context, index) {
                        return Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.watch<LocalizationService>().translate(statsService.safetyTips[index]),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.primaryNavy,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      statsService.safetyTips.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentTipIndex == index
                              ? AppTheme.primaryNavy
                              : AppTheme.primaryNavy.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 14),
          
          // 4. Recent activity section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.watch<LocalizationService>().translate('Recent activity'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.primaryNavy,
                      ),
                ),
                const SizedBox(height: 14),
                ...displayAlerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _riskDotColor(alert.riskLevel),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            alert.heading,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(alert.timestamp),
                          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
                Center(
                  child: InkWell(
                    onTap: widget.onNavigateToAlerts,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        context.watch<LocalizationService>().translate('View all'),
                        style: const TextStyle(
                          color: AppTheme.primaryNavy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
