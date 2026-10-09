import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scamundo/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'alerts_tab.dart';
import 'connect_tab.dart';
import 'settings_tab.dart';
import 'profile_screen.dart';
import '../services/home_stats_service.dart';
import '../services/issues_service.dart';
import '../services/locale_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
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
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.navHome),
          BottomNavigationBarItem(icon: const Icon(Icons.warning_amber_rounded), label: l10n.navAlert),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: l10n.navConnect),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: l10n.navSettings),
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
    // Fetch real stats from backend
    Future.microtask(() {
      final authService = context.read<AuthService>();
      context.read<HomeStatsService>().fetchStats(newUser: authService.isNewUser);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final statsService = context.read<HomeStatsService>();
      if (statsService.safetyTips.isNotEmpty) {
        final nextIndex = (_currentTipIndex + 1) % statsService.safetyTips.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
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
    super.dispose();
  }
  
  Color _riskDotColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high: return const Color(0xFFA32D2D);
      case RiskLevel.mid: return const Color(0xFFBA7517);
      case RiskLevel.safe: return const Color(0xFF3B8B22);
    }
  }
  
  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statsService = context.watch<HomeStatsService>();
    final issuesService = context.watch<IssuesService>();
    final isEnglish = context.watch<LocaleProvider>().locale.languageCode == 'en';
    final isNewUser = statsService.isNewUser;
    
    // Replace hardcoded tips with localized ones
    final localizedTips = [
      l10n.safetyTip1,
      l10n.safetyTip2,
      l10n.safetyTip3,
      l10n.safetyTip4,
    ];
    
    // Get 2 most recent alerts (empty for new users)
    final List<AlertItem> displayAlerts;
    if (isNewUser) {
      displayAlerts = [];
    } else {
      final recentAlerts = issuesService.getMockAlerts(l10n)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      displayAlerts = recentAlerts.take(2).toList();
    }

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
                        context.read<LocaleProvider>().toggleLocale();
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
                                fontWeight: isEnglish ? FontWeight.w800 : FontWeight.w500,
                                color: isEnglish ? AppTheme.primaryNavy : const Color(0xFF999999),
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
                                fontWeight: !isEnglish ? FontWeight.w800 : FontWeight.w500,
                                color: !isEnglish ? AppTheme.primaryNavy : const Color(0xFF999999),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.statusProtected,
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.statusScanning,
                              style: const TextStyle(
                                color: Color(0xFFB4B2A9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
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
                                  Expanded(
                                    child: Text(
                                      l10n.statCheckedToday,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
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
                                  Expanded(
                                    child: Text(
                                      l10n.statThisWeek,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
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
                        l10n.safetyTipHeader,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.primaryNavy,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppTheme.primaryNavy),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_currentTipIndex > 0) {
                            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          } else {
                            _pageController.animateToPage(localizedTips.length - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentTipIndex = index;
                              });
                            },
                            itemCount: localizedTips.length,
                            itemBuilder: (context, index) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  localizedTips[index],
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
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppTheme.primaryNavy),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_currentTipIndex < localizedTips.length - 1) {
                            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          } else {
                            _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      localizedTips.length,
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
                  l10n.recentActivity,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.primaryNavy,
                      ),
                ),
                const SizedBox(height: 14),
                if (displayAlerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your scan results will appear here',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
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
                          l10n.viewAll,
                          style: const TextStyle(
                            color: AppTheme.primaryNavy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
