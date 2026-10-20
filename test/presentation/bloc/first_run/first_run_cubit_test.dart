import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/bloc/first_run/first_run_cubit.dart';
import 'package:pahlevani/presentation/bloc/first_run/first_run_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts in Checking so neither splash nor home flashes', () {
    final cubit = FirstRunCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const FirstRunChecking());
  });

  test('load() → Pending when the splash has never been seen', () async {
    final cubit = FirstRunCubit();
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state, const FirstRunPending());
  });

  test('load() → Done when the splash was already seen', () async {
    SharedPreferences.setMockInitialValues({FirstRunCubit.splashSeenKey: true});
    final cubit = FirstRunCubit();
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state, const FirstRunDone());
  });

  test('complete() → Done, and a later launch skips the splash', () async {
    final first = FirstRunCubit();
    await first.load();
    await first.complete();
    expect(first.state, const FirstRunDone());
    await first.close();

    final relaunch = FirstRunCubit();
    addTearDown(relaunch.close);
    await relaunch.load();
    expect(relaunch.state, const FirstRunDone());
  });

  group('when local storage fails, the app still opens', () {
    test('load() → Done if preferences cannot be read', () async {
      final cubit = FirstRunCubit(
        preferences: () =>
            Future.error(const FormatException('corrupt preferences file')),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, const FirstRunDone());
    });

    test('complete() → Done even if the flag cannot be saved', () async {
      final cubit = FirstRunCubit(
        preferences: () => Future.error(Exception('disk full')),
      );
      addTearDown(cubit.close);
      await cubit.complete();
      expect(cubit.state, const FirstRunDone());
    });
  });
}
