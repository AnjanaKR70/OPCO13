import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scamundo/overlay_main.dart';
import 'package:scamundo/services/localization_service.dart';

void main() {
  testWidgets('OverlayWidget displays loading indicator initially', (WidgetTester tester) async {
    // Build the OverlayWidget inside a Provider and MaterialApp
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: const MaterialApp(
          home: OverlayWidget(),
        ),
      ),
    );

    // Because _alertData is initially empty, it should show a CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
