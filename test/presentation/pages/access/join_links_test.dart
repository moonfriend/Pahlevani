import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/pages/access/account_page.dart';

void main() {
  const adminUrl = 'https://steady.page/en/join-the-gowd';

  test('apps never open the paid plans: the admin link becomes the free plan',
      () {
    expect(storeSafeJoinUrl(adminUrl, showPlans: false), joinFreeUrl);
  });

  test('web keeps the admin link (all plans)', () {
    expect(storeSafeJoinUrl(adminUrl, showPlans: true), adminUrl);
  });
}
