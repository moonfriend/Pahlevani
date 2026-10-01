import 'package:hive_flutter/hive_flutter.dart';

import '../models/hive_fitness_test_result.dart';

/// Hive box management for locally-saved fitness-test results. Mirrors
/// TrainingHistoryLocalDatabase's shape — a self-contained box, no sharing
/// with other features' data.
abstract class FitnessTestResultsLocalDataSource {
  Future<void> add(HiveFitnessTestResult record);
  Future<List<HiveFitnessTestResult>> getAll();
}

class FitnessTestResultsLocalDataSourceImpl
    implements FitnessTestResultsLocalDataSource {
  static const String _boxName = 'fitness_test_results';

  /// Registers this module's Hive adapter. Must run after
  /// Hive.initFlutter() has already happened elsewhere in app startup — DI
  /// wiring guarantees that ordering.
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(HiveFitnessTestResultAdapter());
    }
  }

  Future<Box<HiveFitnessTestResult>> _getBox() async {
    return Hive.openBox<HiveFitnessTestResult>(_boxName);
  }

  @override
  Future<void> add(HiveFitnessTestResult record) async {
    final box = await _getBox();
    await box.add(record);
  }

  @override
  Future<List<HiveFitnessTestResult>> getAll() async {
    final box = await _getBox();
    return box.values.toList();
  }
}
