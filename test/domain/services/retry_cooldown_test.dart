import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/services/retry_cooldown.dart';

void main() {
  late DateTime now;
  late RetryCooldown cooldown;

  setUp(() {
    now = DateTime(2026, 10, 26, 12);
    cooldown = RetryCooldown(clock: () => now);
  });

  test('nothing blocks before the first failure', () {
    expect(cooldown.blockedUntil, isNull);
  });

  test('each failure in a row waits longer: 3 s, 10 s, 30 s, then 60 s', () {
    final pauses = <Duration>[];
    for (var i = 0; i < 5; i++) {
      pauses.add(cooldown.registerFailure().difference(now));
    }
    expect(pauses, const [
      Duration(seconds: 3),
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 60),
    ]);
  });

  test('blocks until the pause is over', () {
    cooldown.registerFailure();
    expect(cooldown.blockedUntil, now.add(const Duration(seconds: 3)));
    now = now.add(const Duration(seconds: 3));
    expect(cooldown.blockedUntil, isNull);
  });

  test('a success starts over', () {
    cooldown
      ..registerFailure()
      ..registerFailure()
      ..reset();
    expect(cooldown.blockedUntil, isNull);
    expect(
        cooldown.registerFailure().difference(now), const Duration(seconds: 3));
  });
}
