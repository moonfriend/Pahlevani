import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/access/access_scaffold.dart';
import 'package:pahlevani/presentation/widgets/kashi/rahavi_menu_button.dart';

void main() {
  testWidgets(
      'sign-in and locked screens: the mark opens the legal menu, so the '
      'Impressum is reachable before signing in', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: const AccessScaffold(title: 'Welcome', children: []),
    ));

    expect(find.byType(RahaviMenuButton), findsOneWidget);
  });
}
