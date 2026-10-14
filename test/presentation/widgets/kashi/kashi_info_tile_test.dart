import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/info/info_link.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_info_tile.dart';

const _link = InfoLink(
    title: 'How to get your meel',
    description: 'Make your own, order, or pre-order.',
    url: 'https://rahaavi.com');

Future<void> _pump(WidgetTester tester, {required bool isNew}) =>
    tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: Scaffold(
        body: SizedBox(
            height: 84, child: KashiInfoTile(link: _link, isNew: isNew)),
      ),
    ));

void main() {
  testWidgets('shows the title and the description', (tester) async {
    await _pump(tester, isNew: false);
    expect(find.text('How to get your meel'), findsOneWidget);
    expect(find.text('Make your own, order, or pre-order.'), findsOneWidget);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('a version not opened yet is raised and marked NEW',
      (tester) async {
    await _pump(tester, isNew: true);
    expect(find.text('NEW'), findsOneWidget);
    final material = tester.widget<Material>(find
        .descendant(
            of: find.byType(KashiInfoTile), matching: find.byType(Material))
        .first);
    expect(material.elevation, greaterThan(0));
  });
}
