import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/presentation/pages/trainer/trainer_student_list_page.dart';

import '../../../fakes/fake_current_user_service.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<CurrentUserService>(
        () => FakeCurrentUserService('coach-reza'));
  });

  tearDown(() async => getIt.reset());

  testWidgets('seeds the roster with the current user id', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrainerStudentListPage()));
    await tester.pump(); // resolve current user id

    // Appears both in the editable field and the roster tile.
    expect(find.text('coach-reza'), findsWidgets);
    expect(find.text('Roster'), findsOneWidget);
  });
}
