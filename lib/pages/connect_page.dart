import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'package:scamundo/l10n/app_localizations.dart';

class ConnectTab extends StatelessWidget {
  const ConnectTab({super.key});

  void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openPhone(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final ok = await launchUrl(uri);
      if (!ok) _showError(context, 'Could not open dialer for $number');
    } catch (e) {
      _showError(context, 'Could not open dialer');
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri);
      if (!ok) _showError(context, 'Could not open $url');
    } catch (e) {
      _showError(context, 'Could not open link');
    }
  }

  Future<void> _openMaps(BuildContext context, String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(query)}');
    try {
      final ok = await launchUrl(uri);
      if (!ok) _showError(context, 'Could not open maps');
    } catch (e) {
      _showError(context, 'Could not open maps');
    }
  }

  String get _cyberdomeGmailUrl {
    final subject = Uri.encodeComponent('Reporting a suspected scam');
    return 'https://mail.google.com/mail/?view=cm&fs=1&to=cyberdomekerala@gmail.com&su=$subject';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        children: [
          Text(
            l10n.connectTitle,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.connectSubtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF666666),
                  fontSize: 15,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          _emergencyCard(context, l10n),
          const SizedBox(height: 32),
          _sectionLabel(context, l10n.reportScam),
          const SizedBox(height: 12),
          _actionTile(
            context,
            icon: Icons.language,
            title: l10n.cybercrimeGovIn,
            subtitle: l10n.fileComplaint,
            onTap: () => _openUrl(context, 'https://cybercrime.gov.in'),
          ),
          const SizedBox(height: 12),
          _actionTile(
            context,
            icon: Icons.email_outlined,
            title: l10n.cyberdomeKerala,
            subtitle: l10n.emailCyberdome,
            onTap: () => _openUrl(context, _cyberdomeGmailUrl),
          ),
          const SizedBox(height: 32),
          _sectionLabel(context, l10n.nearestCyberCell),
          const SizedBox(height: 12),
          _cyberCellTile(context, l10n),
          const SizedBox(height: 32),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF999999)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.contactDetailsSource,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF999999),
                            fontSize: 12,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _emergencyCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.highRiskRed,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.highRiskRed.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nationalHelpline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1930',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openPhone(context, '1930'),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.phone, color: AppTheme.highRiskRed, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.primaryNavy,
          ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.backgroundWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryNavy, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF888888),
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cyberCellTile(BuildContext context, AppLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMaps(context, 'Cyber Cell Police Station Kerala'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.backgroundWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: AppTheme.safeGreen, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cyberCellTvm,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          l10n.distanceAway,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF888888),
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.directions, size: 16, color: AppTheme.primaryNavy),
                        const SizedBox(width: 4),
                        Text(
                          l10n.directions,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryNavy,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
