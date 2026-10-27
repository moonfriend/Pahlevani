import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/app_links.dart';

void main() {
  test('the meel guide link opens the meel page, not the site home', () {
    expect(AppLinks.meelGuide, 'https://rahaavi.com/meel/');
  });
}
