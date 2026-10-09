import 'package:scamundo/l10n/app_localizations.dart';

enum RiskLevel { high, mid, safe }

class AlertItem {
  final String heading;
  final String description;
  final RiskLevel riskLevel;
  final DateTime timestamp;
  final String? appName;
  final String? maskedNumber;

  AlertItem({
    required this.heading,
    required this.description,
    required this.riskLevel,
    required this.timestamp,
    this.appName,
    this.maskedNumber,
  });
}

class IssuesService {
  List<AlertItem> getMockAlerts(AppLocalizations l10n) {
    final now = DateTime.now();
    final today = now.day;
    final month = now.month;
    final year = now.year;

    return [
      AlertItem(
        heading: l10n.alert1Heading,
        description: l10n.alert1Desc,
        riskLevel: RiskLevel.high,
        timestamp: DateTime(year, month, today, 10, 42),
        appName: 'WhatsApp',
        maskedNumber: '+91 94471 XXXXX',
      ),
      AlertItem(
        heading: l10n.alert2Heading,
        description: l10n.alert2Desc,
        riskLevel: RiskLevel.mid,
        timestamp: DateTime(year, month, today, 9, 15),
        appName: 'SMS',
        maskedNumber: '+91 80000 XXXXX',
      ),
      AlertItem(
        heading: l10n.alert3Heading,
        description: l10n.alert3Desc,
        riskLevel: RiskLevel.safe,
        timestamp: DateTime(year, month, today - 1, 18, 3),
        appName: 'Telegram',
        maskedNumber: '+91 77260 XXXXX',
      ),
      AlertItem(
        heading: l10n.alert4Heading,
        description: l10n.alert4Desc,
        riskLevel: RiskLevel.high,
        timestamp: DateTime(year, month, today - 1, 14, 22),
        appName: 'SMS',
        maskedNumber: '+91 90076 XXXXX',
      ),
      AlertItem(
        heading: l10n.alert5Heading,
        description: l10n.alert5Desc,
        riskLevel: RiskLevel.mid,
        timestamp: DateTime(year, month, today - 3, 11, 5),
        appName: 'Phone',
        maskedNumber: '+91 85002 XXXXX',
      ),
      AlertItem(
        heading: l10n.alert6Heading,
        description: l10n.alert6Desc,
        riskLevel: RiskLevel.safe,
        timestamp: DateTime(year, month, today - 5, 8, 30),
        appName: 'Instagram',
      ),
      AlertItem(
        heading: l10n.alert7Heading,
        description: l10n.alert7Desc,
        riskLevel: RiskLevel.mid,
        timestamp: DateTime(year, month, today - 7, 16, 45),
        appName: 'Email',
        maskedNumber: 'sc**m@mail.ru',
      ),
    ];
  }
}
