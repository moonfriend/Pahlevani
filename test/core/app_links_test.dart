import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/app_links.dart';

void main() {
  test('the meel guide link opens the meel page, not the site home', () {
    expect(AppLinks.meelGuide, 'https://rahaavi.com/meel/');
  });

  test('the legal pages live on rahaavi.com', () {
    expect(AppLinks.rahavi, 'https://rahaavi.com/');
    expect(AppLinks.privacy, 'https://rahaavi.com/privacy');
    expect(AppLinks.impressum, 'https://rahaavi.com/impressum');
    expect(AppLinks.terms, 'https://rahaavi.com/terms');
  });
}
