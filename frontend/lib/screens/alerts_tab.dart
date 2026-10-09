import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/issues_service.dart';
import '../services/localization_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter enum
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskFilter { all, red, orange, green }

// ─────────────────────────────────────────────────────────────────────────────
// AlertsTab
// ─────────────────────────────────────────────────────────────────────────────

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  final TextEditingController _searchController = TextEditingController();
  _RiskFilter _activeFilter = _RiskFilter.all;
  String _searchQuery = '';
  int? _expandedIndex; // index in _filtered list; null = none expanded

  // ── lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<IssuesService>().fetchAlerts();
      }
    });
  }

  List<AlertItem> get _allAlerts {
    final alerts = List<AlertItem>.from(context.watch<IssuesService>().alerts);
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── filtering logic ────────────────────────────────────────────────────

  List<AlertItem> get _filteredAlerts {
    return _allAlerts.where((alert) {
      // risk filter
      if (_activeFilter == _RiskFilter.red && alert.riskLevel != RiskLevel.critical) return false;
      if (_activeFilter == _RiskFilter.orange && alert.riskLevel != RiskLevel.mid) return false;
      if (_activeFilter == _RiskFilter.green && alert.riskLevel != RiskLevel.safe) return false;

      // search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesHeading = alert.heading.toLowerCase().contains(q);
        final matchesDate = _formatFullDateTime(alert.timestamp).toLowerCase().contains(q);
        final matchesGroup = _dateGroupLabel(alert.timestamp).toLowerCase().contains(q);
        if (!matchesHeading && !matchesDate && !matchesGroup) return false;
      }
      return true;
    }).toList();
  }

  // ── helpers ────────────────────────────────────────────────────────────

  Color _riskDotColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical:
        return AppTheme.highRiskRed;
      case RiskLevel.mid:
        return AppTheme.midRiskAmber;
      case RiskLevel.safe:
        return AppTheme.safeGreen;
      case RiskLevel.unknown:
        return const Color(0xFF999999);
    }
  }

  Color _expandedBgColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical:
        return const Color(0xFFFDE8E8); // light red tint
      case RiskLevel.mid:
        return const Color(0xFFFFF3E0); // light amber tint
      case RiskLevel.safe:
        return const Color(0xFFE8F5E9); // light green tint
      case RiskLevel.unknown:
        return const Color(0xFFF0F0F0); // light grey tint
    }
  }

  String _riskLabel(RiskLevel level) {
    final loc = context.watch<LocalizationService>();
    switch (level) {
      case RiskLevel.critical:
        return loc.translate('Critical risk');
      case RiskLevel.mid:
        return loc.translate('Medium risk');
      case RiskLevel.safe:
        return loc.translate('Safe');
      case RiskLevel.unknown:
        return loc.translate('Unknown risk');
    }
  }

  String _dateGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final loc = context.watch<LocalizationService>();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return loc.translate('Today');
    if (date == yesterday) return loc.translate('Yesterday');

    final months = [
      '', loc.translate('January'), loc.translate('February'), loc.translate('March'),
      loc.translate('April'), loc.translate('May'), loc.translate('June'),
      loc.translate('July'), loc.translate('August'), loc.translate('September'),
      loc.translate('October'), loc.translate('November'), loc.translate('December')
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _formatFullDateTime(DateTime dt) {
    final loc = context.watch<LocalizationService>();
    final months = [
      '', loc.translate('January'), loc.translate('February'), loc.translate('March'),
      loc.translate('April'), loc.translate('May'), loc.translate('June'),
      loc.translate('July'), loc.translate('August'), loc.translate('September'),
      loc.translate('October'), loc.translate('November'), loc.translate('December')
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}, ${_formatTime(dt)}';
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final issuesService = context.watch<IssuesService>();
    final loc = context.watch<LocalizationService>();
    
    if (issuesService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (issuesService.error != null) {
      return Center(
        child: Text(
          issuesService.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final filtered = _filteredAlerts;

    return SafeArea(
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.translate('Alert'),
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 28),
                ),
                _buildFilterButton(context),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: loc.translate('Search by date or keyword'),
                hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                filled: true,
                fillColor: const Color(0xFFF5F6F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Filter chips ──────────────────────────────────────────────
          if (_activeFilter != _RiskFilter.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  _buildActiveChip(),
                ],
              ),
            ),

          // ── Alert list ────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Text(
                        loc.translate('No alerts found.'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF999999),
                            ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: _buildListItems(filtered).length,
                    itemBuilder: (context, index) => _buildListItems(filtered)[index],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Filter button ─────────────────────────────────────────────────────

  Widget _buildFilterButton(BuildContext context) {
    final loc = context.watch<LocalizationService>();
    return PopupMenuButton<_RiskFilter>(
      onSelected: (filter) => setState(() {
        _activeFilter = filter;
        _expandedIndex = null;
      }),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _popupItem(_RiskFilter.all, loc.translate('All'), null),
        _popupItem(_RiskFilter.red, loc.translate('High risk'), AppTheme.highRiskRed),
        _popupItem(_RiskFilter.orange, loc.translate('Medium risk'), AppTheme.midRiskAmber),
        _popupItem(_RiskFilter.green, loc.translate('Safe'), AppTheme.safeGreen),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded,
                size: 18,
                color: _activeFilter == _RiskFilter.all
                    ? AppTheme.primaryNavy
                    : _filterColor()),
            const SizedBox(width: 6),
            Text(
              loc.translate('Filter'),
              style: TextStyle(
                color: AppTheme.primaryNavy,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_RiskFilter> _popupItem(
      _RiskFilter value, String label, Color? dotColor) {
    final isSelected = _activeFilter == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (dotColor != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            )
          else
            const SizedBox(width: 20),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: AppTheme.primaryNavy,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: AppTheme.primaryNavy),
          ],
        ],
      ),
    );
  }

  Color _filterColor() {
    switch (_activeFilter) {
      case _RiskFilter.red:
        return AppTheme.highRiskRed;
      case _RiskFilter.orange:
        return AppTheme.midRiskAmber;
      case _RiskFilter.green:
        return AppTheme.safeGreen;
      case _RiskFilter.all:
        return AppTheme.primaryNavy;
    }
  }

  Widget _buildActiveChip() {
    final loc = context.watch<LocalizationService>();
    String label;
    Color color;
    switch (_activeFilter) {
      case _RiskFilter.red:
        label = loc.translate('High risk');
        color = AppTheme.highRiskRed;
        break;
      case _RiskFilter.orange:
        label = loc.translate('Medium risk');
        color = AppTheme.midRiskAmber;
        break;
      case _RiskFilter.green:
        label = loc.translate('Safe');
        color = AppTheme.safeGreen;
        break;
      case _RiskFilter.all:
        label = '';
        color = Colors.transparent;
    }
    return GestureDetector(
      onTap: () => setState(() {
        _activeFilter = _RiskFilter.all;
        _expandedIndex = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.close, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  // ── List building with date group headers ─────────────────────────────

  List<Widget> _buildListItems(List<AlertItem> alerts) {
    final List<Widget> items = [];
    String? lastGroup;

    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final group = _dateGroupLabel(alert.timestamp);

      if (group != lastGroup) {
        lastGroup = group;
        items.add(Padding(
          padding: EdgeInsets.only(top: items.isEmpty ? 8 : 20, bottom: 8),
          child: Text(
            group,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF999999),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
          ),
        ));
      }

      final isExpanded = _expandedIndex == i;

      items.add(_buildAlertRow(alert, i, isExpanded));

      // Thin divider between rows (not after last item in the whole list)
      if (i < alerts.length - 1) {
        items.add(const Divider(height: 1, color: Color(0xFFEEEEEE)));
      }
    }

    return items;
  }

  // ── Single alert row ──────────────────────────────────────────────────

  Widget _buildAlertRow(AlertItem alert, int index, bool isExpanded) {
    return Column(
      children: [
        // Collapsed row
        InkWell(
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? null : index;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                // Risk dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _riskDotColor(alert.riskLevel),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                // Heading
                Expanded(
                  child: Text(
                    alert.heading,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Time
                Text(
                  _formatTime(alert.timestamp),
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                ),
                const SizedBox(width: 4),
                // Chevron
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right,
                      color: Color(0xFFBBBBBB), size: 20),
                ),
              ],
            ),
          ),
        ),

        // Expanded detail card
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _expandedBgColor(alert.riskLevel),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.description,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_formatFullDateTime(alert.timestamp)}  ·  ${_riskLabel(alert.riskLevel)}',
                  style: TextStyle(
                    color: _riskDotColor(alert.riskLevel).withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}
