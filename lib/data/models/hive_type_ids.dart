import 'package:hive_flutter/hive_flutter.dart';

/// The single registry of Hive typeIds.
///
/// Hive typeIds are one global namespace shared by every feature, including
/// self-contained feature modules. Keeping them in one file makes a clash
/// visible at review time; `test/data/models/hive_type_ids_test.dart` makes
/// it fail CI. Never reuse or renumber an id that has shipped — stored boxes
/// reference it on users' devices.
abstract final class HiveTypeIds {
  static const int trainingSession = 0;
  static const int exercise = 1;
  static const int trainingSessionItem = 2;
  static const int sessionCompletionRecord = 3;
  static const int pathItemCompletion = 4;
  static const int pathDetail = 5;
  static const int pathNode = 6;
  static const int pathNodeItem = 7;
  static const int fitnessTestResult = 8;
}

final Map<int, Type> _ownerByTypeId = {};

/// Registers [adapter] once, idempotently, and fails loudly on a clash.
///
/// Replaces the `if (!Hive.isAdapterRegistered(id))` guard, which also
/// skipped silently when the id belonged to a *different* adapter — the
/// second feature's saves then failed at runtime instead of at startup.
void registerHiveAdapter<T>(TypeAdapter<T> adapter) {
  final owner = _ownerByTypeId[adapter.typeId];
  if (owner != null && owner != adapter.runtimeType) {
    throw StateError(
      'Hive typeId ${adapter.typeId} is already owned by $owner; '
      'cannot register ${adapter.runtimeType}. See HiveTypeIds.',
    );
  }
  _ownerByTypeId[adapter.typeId] = adapter.runtimeType;
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
