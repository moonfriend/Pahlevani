import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/version_gate/version_gate_screen.dart';

void main() {
  testWidgets('shows the update message and an Update now button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const VersionGateScreen(message: 'Please update to continue.'),
    ));

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Please update to continue.'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('declares itself unpoppable via PopScope', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const VersionGateScreen(message: 'Please update.'),
    ));

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
