import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/training_progress_service_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('completedToday is empty before anything is marked', () async {
    final service = TrainingProgressServiceImpl();
    expect(await service.completedToday(1), isEmpty);
  });

  test('marked positions come back for the same day', () async {
    final service = TrainingProgressServiceImpl();
    await service.markCompletedToday(1, 0);
    await service.markCompletedToday(1, 2);
    expect(await service.completedToday(1), {0, 2});
  });

  test('marking the same position twice is idempotent', () async {
    final service = TrainingProgressServiceImpl();
    await service.markCompletedToday(1, 0);
    await service.markCompletedToday(1, 0);
    expect(await service.completedToday(1), {0});
  });

  test('progress is scoped per session', () async {
    final service = TrainingProgressServiceImpl();
    await service.markCompletedToday(1, 0);
    expect(await service.completedToday(2), isEmpty);
  });

  test('a new day resets progress (implicit daily reset)', () async {
    var day = DateTime(2026, 7, 1);
    final service = TrainingProgressServiceImpl(now: () => day);
    await service.markCompletedToday(1, 0);
    expect(await service.completedToday(1), {0});

    day = DateTime(2026, 7, 2); // next morning
    expect(await service.completedToday(1), isEmpty,
        reason: 'yesterday\'s completion must not carry into today');
  });
}
