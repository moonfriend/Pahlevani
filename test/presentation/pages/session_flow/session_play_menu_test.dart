import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_start.dart';

void main() {
  testWidgets(
      'long-press menu: asks to start in Zoorkhaneh mode; Cancel does '
      'nothing', (tester) async {
    final session = TrainingSession(
        id: 1, title: 'Full Pahlevani', description: '', difficulty: 3);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSessionPlayMenu(context, session),
          child: const Text('hold'),
        ),
      ),
    ));
    await tester.tap(find.text('hold'));
    await tester.pumpAndSettle();

    expect(find.text('Start in Zoorkhaneh mode?'), findsOneWidget);
    expect(find.textContaining('Full Pahlevani'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Start in Zoorkhaneh mode?'), findsNothing);
  });
}
