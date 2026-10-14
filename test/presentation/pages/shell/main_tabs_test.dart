import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/pages/shell/main_tabs.dart';

void main() {
  test('release 1 has three tabs: Home, Library, Profile', () {
    expect(mainTabs().map((t) => t.label), ['Home', 'Library', 'Profile']);
  });
}
