import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:athleteos/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AthletesOSApp(),
      ),
    );
    // Verifica que la app carga sin crashear
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
