import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import '../services/localization_service.dart';
import 'home_screen.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<PermissionPageData> _pages = [
    PermissionPageData(
      icon: Icons.folder_shared,
      heading: 'Storage Access',
      description: 'We need access to your local files to securely store verification data.',
      type: PermissionType.storage,
    ),
    PermissionPageData(
      icon: Icons.phone_in_talk,
      heading: 'Phone Access',
      description: 'Allows you to make emergency SOS calls directly from the app.',
      type: PermissionType.phone,
    ),
    PermissionPageData(
      icon: Icons.location_on,
      heading: 'Location Access',
      description: 'Helps locate the nearest cyber cell and provide location-aware safety alerts.',
      type: PermissionType.location,
    ),
    PermissionPageData(
      icon: Icons.sms,
      heading: 'SMS Access',
      description: 'Helps us scan incoming messages for potential phishing links.',
      type: PermissionType.sms,
    ),
    PermissionPageData(
      icon: Icons.email,
      heading: 'Google Sign-In',
      description: 'Connect your Gmail to detect fraudulent emails and alerts.',
      type: PermissionType.google,
    ),
    PermissionPageData(
      icon: Icons.layers,
      heading: 'Display Over Apps',
      description: 'Required to instantly show the SOS screen when a threat is detected.',
      type: PermissionType.systemAlertWindow,
    ),
  ];

  Future<void> _handlePermissionChoice(bool granted) async {
    final type = _pages[_currentIndex].type;
    final provider = context.read<PermissionState>();
    final loc = context.read<LocalizationService>();

    if (granted) {
      PermissionStatus status = PermissionStatus.denied;
      
      switch (type) {
        case PermissionType.storage:
          // Use manageExternalStorage for full file access on Android 11+
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) status = await Permission.storage.request();
          provider.grantStorage(status.isGranted);
          break;
        case PermissionType.phone:
          status = await Permission.phone.request();
          provider.grantPhone(status.isGranted);
          break;
        case PermissionType.location:
          status = await Permission.location.request();
          provider.grantLocation(status.isGranted);
          break;
        case PermissionType.sms:
          status = await Permission.sms.request();
          provider.grantSms(status.isGranted);
          break;
        case PermissionType.google:
          status = await Permission.contacts.request();
          provider.grantGoogle(status.isGranted);
          break;
        case PermissionType.systemAlertWindow:
          await FlutterOverlayWindow.requestPermission();
          final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
          status = isGranted ? PermissionStatus.granted : PermissionStatus.denied;
          provider.grantOverlay(isGranted);
          break;
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.read<LocalizationService>().translate('Permission blocked by OS. Please enable in Settings.'))),
          );
        }
        await openAppSettings();
        return; // Don't advance to next page if they need to go to settings
      }

      if (!status.isGranted) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.read<LocalizationService>().translate('Permission denied. You can enable it later.'))),
          );
        }
      }
    } else {
      // User tapped "Not now", explicitly set to false
      switch (type) {
        case PermissionType.storage:
          provider.grantStorage(false);
          break;
        case PermissionType.phone:
          provider.grantPhone(false);
          break;
        case PermissionType.location:
          provider.grantLocation(false);
          break;
        case PermissionType.sms:
          provider.grantSms(false);
          break;
        case PermissionType.google:
          provider.grantGoogle(false);
          break;
        case PermissionType.systemAlertWindow:
          provider.grantOverlay(false);
          break;
      }
    }

    if (!mounted) return;

    if (_currentIndex < _pages.length - 1) {
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Dot Progress Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? AppTheme.primaryNavy
                        : const Color(0xFFE0E0E0),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Only manual nav
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(page.icon, size: 100, color: AppTheme.primaryNavy),
                        const SizedBox(height: 48),
                        Text(
                          context.watch<LocalizationService>().translate(page.heading),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.watch<LocalizationService>().translate(page.description),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                color: const Color(0xFF555555),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _handlePermissionChoice(true),
                            child: Text(context.watch<LocalizationService>().translate('Allow')),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _handlePermissionChoice(false),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryNavy),
                          child: Text(context.watch<LocalizationService>().translate('Not now')),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PermissionType { storage, phone, location, sms, google, systemAlertWindow }

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
