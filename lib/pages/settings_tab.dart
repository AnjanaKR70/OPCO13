import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scamundo/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return SafeArea(
      child: Consumer<PermissionState>(
        builder: (context, state, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            children: [
              // ── Header ──────────────────────────────────────────────────
              Text(
                l10n.settingsHeader,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 32),

              // ── Permissions Section ─────────────────────────────────────
              _SectionHeader(title: l10n.permissionsSection),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _PermissionToggleRow(
                    icon: Icons.folder_shared_outlined,
                    title: l10n.storageAccess,
                    subtitle: l10n.storageDesc,
                    value: state.storageAllowed,
                    onChanged: state.grantStorage,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.phone_in_talk_outlined,
                    title: l10n.phoneAccess,
                    subtitle: l10n.phoneDesc,
                    value: state.phoneAllowed,
                    onChanged: state.grantPhone,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.location_on_outlined,
                    title: l10n.locationAccess,
                    subtitle: l10n.locationDesc,
                    value: state.locationAllowed,
                    onChanged: state.grantLocation,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.sms_outlined,
                    title: l10n.smsAccess,
                    subtitle: l10n.smsDesc,
                    value: state.smsAllowed,
                    onChanged: state.grantSms,
                  ),
                  const _ThinDivider(),
                  _PermissionToggleRow(
                    icon: Icons.email_outlined,
                    title: l10n.googleAccount,
                    subtitle: l10n.googleDesc,
                    value: state.googleAllowed,
                    onChanged: state.grantGoogle,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── App Protection Section ──────────────────────────────────
              _SectionHeader(title: l10n.appProtectionSection),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.chooseProtectedApps,
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
                    title: l10n.protectAllApps,
                    subtitle: l10n.protectAllDesc,
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
                      return Column(
                        children: [
                          _AppToggleRow(
                            icon: app.icon,
                            title: app.name,
                            value: app.enabled,
                            enabled: !state.protectAll,
                            onChanged: (val) => state.setAppProtection(index, val),
                          ),
                          if (index < state.protectedApps.length - 1)
                            const _ThinDivider(indent: 64),
                        ],
                      );
                    },
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
// ── Helper Widgets ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryNavy,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  final double indent;
  const _ThinDivider({this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: const Color(0xFFEAEAEA),
      indent: indent,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Toggle Rows ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _PermissionToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionToggleRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value ? const Color(0xFFE8F0FE) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value ? AppTheme.primaryNavy : const Color(0xFFAAAAAA),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value ? AppTheme.primaryNavy : const Color(0xFF333333),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
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
      ),
    );
  }
}

class _ProtectAllToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProtectAllToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        color: value ? const Color(0xFFF8FAFC) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value ? AppTheme.primaryNavy : const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield,
                color: value ? Colors.white : const Color(0xFFAAAAAA),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: value ? AppTheme.primaryNavy : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
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
      ),
    );
  }
}

class _AppToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled;
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? const Color(0xFFE8F0FE) : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: value ? AppTheme.primaryNavy : const Color(0xFFAAAAAA),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
        ),
      ),
    );
  }
}
