import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/data/models/hive_path_models.dart';
import 'package:pahlevani/data/models/hive_path_progress_model.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';
import 'package:pahlevani/features/fitness_test/data/models/hive_fitness_test_result.dart';

/// Every Hive adapter the app registers. Add new adapters here — the
/// uniqueness test below is the only thing that catches two features
/// independently claiming the same typeId (each feature's own tests pass in
/// isolation, and the init-time `isAdapterRegistered` guard used to make the
/// second registration a silent no-op).
final List<TypeAdapter<dynamic>> allAdapters = [
  HiveTrainingSessionAdapter(),
  HiveExerciseAdapter(),
  HiveTrainingSessionItemAdapter(),
  HiveSessionCompletionRecordAdapter(),
  HivePathItemCompletionAdapter(),
  HivePathDetailAdapter(),
  HivePathNodeAdapter(),
  HivePathNodeItemAdapter(),
  HiveFitnessTestResultAdapter(),
];

void main() {
  test('every Hive adapter has a unique typeId', () {
    final owners = <int, List<String>>{};
    for (final adapter in allAdapters) {
      owners
          .putIfAbsent(adapter.typeId, () => [])
          .add(adapter.runtimeType.toString());
    }
    final clashes = Map.fromEntries(
      owners.entries.where((entry) => entry.value.length > 1),
    );

    expect(clashes, isEmpty, reason: 'typeIds claimed by >1 adapter');
  });

  test('generated adapters use the ids declared in HiveTypeIds', () {
    expect(
      {for (final a in allAdapters) a.runtimeType.toString(): a.typeId},
      {
        'HiveTrainingSessionAdapter': HiveTypeIds.trainingSession,
        'HiveExerciseAdapter': HiveTypeIds.exercise,
        'HiveTrainingSessionItemAdapter': HiveTypeIds.trainingSessionItem,
        'HiveSessionCompletionRecordAdapter':
            HiveTypeIds.sessionCompletionRecord,
        'HivePathItemCompletionAdapter': HiveTypeIds.pathItemCompletion,
        'HivePathDetailAdapter': HiveTypeIds.pathDetail,
        'HivePathNodeAdapter': HiveTypeIds.pathNode,
        'HivePathNodeItemAdapter': HiveTypeIds.pathNodeItem,
        'HiveFitnessTestResultAdapter': HiveTypeIds.fitnessTestResult,
      },
    );
  });

  group('registerHiveAdapter', () {
    test('is idempotent for the same adapter type', () {
      registerHiveAdapter(HivePathNodeAdapter());
      registerHiveAdapter(HivePathNodeAdapter());

      expect(Hive.isAdapterRegistered(HiveTypeIds.pathNode), isTrue);
    });

    test('throws when a different adapter claims an owned typeId', () {
      registerHiveAdapter(HivePathDetailAdapter());

      expect(
        () => registerHiveAdapter(_ImpostorAdapter(HiveTypeIds.pathDetail)),
        throwsStateError,
      );
    });
  });
}

class _ImpostorAdapter extends TypeAdapter<String> {
  _ImpostorAdapter(this.typeId);

  @override
  final int typeId;

  @override
  String read(BinaryReader reader) => reader.readString();

  @override
  void write(BinaryWriter writer, String obj) => writer.writeString(obj);
}
