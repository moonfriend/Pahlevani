import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/move_variation.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(HiveTypeIds.exercise)) {
      Hive.registerAdapter(HiveExerciseAdapter());
    }
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_hive_ex_');
    Hive.init(tmpDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmpDir.delete(recursive: true);
  });

  const withContent = Exercise(
    id: 1,
    name: 'Shena',
    cues: ['Back straight', 'Elbows in'],
    steps: ['Hands under shoulders', 'Lower slowly'],
    variations: [
      MoveVariation(name: 'Knee shena', level: 'EASIER', reps: 12),
      MoveVariation(name: 'Shena'),
    ],
  );

  test('learning content survives a write and read through the box', () async {
    final box = await Hive.openBox<HiveExercise>('exercises');
    await box.put(1, HiveExercise.fromDomain(withContent));
    await box.close();

    final reopened = await Hive.openBox<HiveExercise>('exercises');
    final ex = reopened.get(1)!.toDomain();
    expect(ex.cues, withContent.cues);
    expect(ex.steps, withContent.steps);
    expect(ex.variations, withContent.variations);
  });

  test('a cached record from before the content fields reads as empty', () {
    final ex = HiveExercise(id: 1, name: 'Shena').toDomain();
    expect(ex.cues, isEmpty);
    expect(ex.steps, isEmpty);
    expect(ex.variations, isEmpty);
  });

  test('a corrupt variations cache entry reads as empty instead of throwing',
      () {
    final ex = HiveExercise(id: 1, name: 'Shena', variationsJson: '{not json')
        .toDomain();
    expect(ex.variations, isEmpty);
  });
}
