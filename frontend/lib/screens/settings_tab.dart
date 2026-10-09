import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import '../services/localization_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    return SafeArea(
      child: Consumer<PermissionState>(
        builder: (context, state, child) {
          return ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            children: [
              // ── Header ──────────────────────────────────────────────────
              Text(
                localization.translate('Settings'),
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 32),

              // ── Permissions Section ─────────────────────────────────────
              _SectionHeader(title: localization.translate('Permissions')),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _PermissionToggleRow(
                    icon: Icons.folder_shared_outlined,
                    title: localization.translate('Storage access'),
                    value: state.storageAllowed,
                    onChanged: state.grantStorage,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.phone_in_talk_outlined,
                    title: localization.translate('Phone access'),
                    value: state.phoneAllowed,
                    onChanged: state.grantPhone,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.location_on_outlined,
                    title: localization.translate('Location access'),
                    value: state.locationAllowed,
                    onChanged: state.grantLocation,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.sms_outlined,
                    title: localization.translate('SMS access'),
                    value: state.smsAllowed,
                    onChanged: state.grantSms,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.email_outlined,
                    title: localization.translate('Google account'),
                    value: state.googleAllowed,
                    onChanged: state.grantGoogle,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── App Protection Section ──────────────────────────────────
              _SectionHeader(title: localization.translate('App protection')),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  localization.translate('Choose which apps are scanned for scam content'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF888888),
                        fontSize: 13,
                      ),
                ),
              ),
              _SettingsCard(
                children: [
                  // "Protect all apps" master toggle
                  _ProtectAllToggleRow(
                    value: state.protectAll,
                    onChanged: state.setProtectAll,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  // Individual app toggles
                  ...List.generate(
                    state.protectedApps.length,
                    (index) {
                      final app = state.protectedApps[index];
                      final isLast =
                          index == state.protectedApps.length - 1;
                      return Column(
                        children: [
                          _AppToggleRow(
                            icon: app.icon,
                            title: app.name,
                            value: app.enabled,
                            enabled: !state.protectAll,
                            onChanged: (val) =>
                                state.setAppProtection(index, val),
                          ),
                          if (!isLast) const _ThinDivider(),
                        ],
                      );
                    },
                  ),
                ],
              ),



              const SizedBox(height: 32),

              // ── Threat Alerts Section ───────────────────────────────────
              _SectionHeader(title: localization.translate('Threat Alerts')),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _PermissionToggleRow(
                    icon: Icons.notification_important_outlined,
                    title: localization.translate('Threat Alerts'),
                    value: state.alertsEnabled,
                    onChanged: state.setAlertsEnabled,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.vibration,
                    title: localization.translate('Vibration'),
                    value: state.vibrationEnabled,
                    onChanged: state.setVibrationEnabled,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.volume_up_outlined,
                    title: localization.translate('Warning Sound'),
                    value: state.soundEnabled,
                    onChanged: state.setSoundEnabled,
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Shared Widgets ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Section header label
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.primaryNavy,
          ),
    );
  }
}

/// White card with rounded corners and a subtle border
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// Thin gray divider for inside cards
class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 0,
      thickness: 0.5,
      indent: 60,
      color: Color(0xFFEEEEEE),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Permission Toggle Row ───────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _PermissionToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFFE8F0FE)
                  : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.primaryNavy : const Color(0xFFAAAAAA),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          // Toggle
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.backgroundWhite,
            activeTrackColor: AppTheme.primaryNavy,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Protect All Toggle Row ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _ProtectAllToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProtectAllToggleRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Shield icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryNavy.withOpacity(0.1)
                  : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.security_rounded,
              color: value ? AppTheme.primaryNavy : const Color(0xFFAAAAAA),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.translate('Protect all apps'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value
                      ? localization.translate('All apps are being monitored')
                      : localization.translate('Customize per app below'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.backgroundWhite,
            activeTrackColor: AppTheme.primaryNavy,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Individual App Toggle Row ───────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _AppToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled; // false when "Protect all" is on → grayed out
  final ValueChanged<bool> onChanged;

  const _AppToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // App icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFFE8F0FE)
                    : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color:
                    value ? AppTheme.primaryNavy : const Color(0xFFAAAAAA),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: AppTheme.backgroundWhite,
              activeTrackColor: AppTheme.primaryNavy,
              inactiveTrackColor: Colors.grey.shade300,
              inactiveThumbColor: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}


