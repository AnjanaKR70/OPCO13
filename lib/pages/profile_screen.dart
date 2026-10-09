import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scamundo/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryNavy),
        titleTextStyle: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 20,
              color: AppTheme.primaryNavy,
            ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFF1EFE8),
                child: Icon(Icons.person, size: 48, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 24),
              Text(
                'John Doe',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 24,
                      color: AppTheme.primaryNavy,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '+91 98765 43210',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF666666),
                    ),
              ),
              const SizedBox(height: 48),
              OutlinedButton(
                onPressed: () async {
                  await context.read<AuthService>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.primaryNavy),
                ),
                child: Text(l10n.logout, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
