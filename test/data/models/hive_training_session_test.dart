import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(HiveTypeIds.trainingSession)) {
      Hive.registerAdapter(HiveTrainingSessionAdapter());
    }
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_hive_ts_');
    Hive.init(tmpDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  test('the Home slot and the meel flag survive the offline cache', () async {
    final box = await Hive.openBox<HiveTrainingSession>('sessions');
    await box.put(
        1,
        HiveTrainingSession.fromDomain(TrainingSession(
            id: 1,
            title: 'Full',
            description: '',
            difficulty: 3,
            homePosition: 1,
            needsMeel: true)));
    await box.close();

    final reopened = await Hive.openBox<HiveTrainingSession>('sessions');
    final session = reopened.get(1)!.toDomain();
    expect(session.homePosition, 1);
    expect(session.needsMeel, isTrue);
  });
}
