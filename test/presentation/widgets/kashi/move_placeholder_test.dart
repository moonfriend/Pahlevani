import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/presentation/widgets/kashi/move_placeholder.dart';

void main() {
  testWidgets('shows the female pahlevan illustration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MovePlaceholder()));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, KashiAssets.pahlevanFemale);
  });
}
