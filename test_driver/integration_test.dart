// Driver entrypoint for `flutter drive` — required for web, where
// `flutter test integration_test/*.dart -d chrome` is not supported
// ("Web devices are not supported for integration tests yet.").
//
// Usage (see docs/web_testing.md):
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart \
//     -d web-server --release --browser-name=chrome --web-port=8080
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
