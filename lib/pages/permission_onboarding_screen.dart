import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scamundo/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import 'home_screen.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<PermissionPageData> _getPages(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      PermissionPageData(
        icon: Icons.folder_shared,
        heading: l10n.onboardingStorageTitle,
        description: l10n.onboardingStorageDesc,
        type: PermissionType.storage,
      ),
      PermissionPageData(
        icon: Icons.phone_in_talk,
        heading: l10n.onboardingPhoneTitle,
        description: l10n.onboardingPhoneDesc,
        type: PermissionType.phone,
      ),
      PermissionPageData(
        icon: Icons.location_on,
        heading: l10n.onboardingLocationTitle,
        description: l10n.onboardingLocationDesc,
        type: PermissionType.location,
      ),
      PermissionPageData(
        icon: Icons.sms,
        heading: l10n.onboardingSmsTitle,
        description: l10n.onboardingSmsDesc,
        type: PermissionType.sms,
      ),
      PermissionPageData(
        icon: Icons.email,
        heading: l10n.googleAccount,
        description: l10n.googleDesc,
        type: PermissionType.google,
      ),
    ];
  }

  void _handlePermissionChoice(bool granted, int totalPages) {
    final pages = _getPages(context);
    final type = pages[_currentIndex].type;
    final provider = context.read<PermissionState>();

    switch (type) {
      case PermissionType.storage:
        provider.grantStorage(granted);
        break;
      case PermissionType.phone:
        provider.grantPhone(granted);
        break;
      case PermissionType.location:
        provider.grantLocation(granted);
        break;
      case PermissionType.sms:
        provider.grantSms(granted);
        break;
      case PermissionType.google:
        provider.grantGoogle(granted);
        break;
    }

    if (_currentIndex < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _getPages(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            // Header Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    l10n.onboardingTitle,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 28,
                          color: AppTheme.primaryNavy,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.onboardingSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF666666),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EFE8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 60, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.heading,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF666666),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Action Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == index
                              ? AppTheme.primaryNavy
                              : AppTheme.primaryNavy.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  ElevatedButton(
                    onPressed: () => _handlePermissionChoice(true, pages.length),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentIndex == pages.length - 1 ? l10n.getStarted : l10n.allow,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _handlePermissionChoice(false, pages.length),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(
                      l10n.skip,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PermissionType {
  storage,
  phone,
  location,
  sms,
  google,
}

class PermissionPageData {
  final IconData icon;
  final String heading;
  final String description;
  final PermissionType type;

  PermissionPageData({
    required this.icon,
    required this.heading,
    required this.description,
    required this.type,
  });
}
