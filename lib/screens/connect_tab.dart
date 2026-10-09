import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';

class ConnectTab extends StatelessWidget {
  const ConnectTab({super.key});

  // ── Launchers ──────────────────────────────────────────────────────────

  Future<void> _launchPhone(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Could not launch dialer: $e');
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  Future<void> _launchEmail(String address, String subject) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: address,
      queryParameters: {'subject': subject},
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  Future<void> _launchMaps(String query) async {
    final Uri uri = Uri.parse(
        'https://www.google.com/maps/search/${Uri.encodeComponent(query)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch maps: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationService>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        children: [
          // ── Header ────────────────────────────────────────────────────
          Text(
            loc.translate('Connect'),
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate("If you've received something suspicious, you're not alone.\nHere's who can help."),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF666666),
                  fontSize: 15,
                  height: 1.5,
                ),
          ),

          const SizedBox(height: 24),

          // ── Emergency Card ────────────────────────────────────────────
          _buildEmergencyCard(context),

          const SizedBox(height: 32),

          // ── Report a scam ─────────────────────────────────────────────
          _buildSectionHeader(context, loc.translate('Report a scam')),
          const SizedBox(height: 12),
          _buildActionRow(
            context,
            icon: Icons.language,
            title: 'cybercrime.gov.in',
            subtitle: loc.translate('File an online complaint on the national portal'),
            onTap: () => _launchUrl('https://cybercrime.gov.in'),
          ),
          const SizedBox(height: 12),
          _buildActionRow(
            context,
            icon: Icons.email_outlined,
            title: loc.translate('Cyberdome Kerala'),
            subtitle: loc.translate('Email the Kerala Cyberdome team directly'),
            onTap: () => _launchEmail(
              'cyberdomekerala@gmail.com',
              loc.translate('Reporting a suspected scam'),
            ),
          ),

          const SizedBox(height: 32),

          // ── Nearest cyber cell ────────────────────────────────────────
          _buildSectionHeader(context, loc.translate('Nearest cyber cell')),
          const SizedBox(height: 12),
          _buildCyberCellRow(context),

          const SizedBox(height: 32),

          // ── Trust footer ──────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 14, color: Color(0xFF999999)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      loc.translate('Contact details sourced from official Government of Kerala Cyberdome channels.'),
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

  // ── Emergency Card ──────────────────────────────────────────────────────

  Widget _buildEmergencyCard(BuildContext context) {
    final loc = context.watch<LocalizationService>();
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
          // Left side – text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('National cyber fraud helpline'),
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
          // Right side – call button
          GestureDetector(
            onTap: () => _launchPhone('1930'),
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
              child: const Icon(
                Icons.phone,
                color: AppTheme.highRiskRed,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.primaryNavy,
          ),
    );
  }

  // ── Generic Action Row ──────────────────────────────────────────────────

  Widget _buildActionRow(
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
              // Icon badge
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
              // Title + subtitle
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
              const Icon(Icons.chevron_right,
                  color: Color(0xFFBBBBBB), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cyber Cell Row ──────────────────────────────────────────────────────

  Widget _buildCyberCellRow(BuildContext context) {
    final loc = context.watch<LocalizationService>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchMaps('Cyber Cell Police Station Kerala'),
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
              // Green map pin icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on,
                    color: AppTheme.safeGreen, size: 22),
              ),
              const SizedBox(width: 16),
              // Location details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('Cyber Cell, Thiruvananthapuram'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          loc.translate('~3.2 km away'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF888888),
                                    fontSize: 13,
                                  ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.directions,
                            size: 16, color: AppTheme.primaryNavy),
                        const SizedBox(width: 4),
                        Text(
                          loc.translate('Directions'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
