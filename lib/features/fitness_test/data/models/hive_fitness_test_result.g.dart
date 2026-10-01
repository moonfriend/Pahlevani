// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_fitness_test_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveFitnessTestResultAdapter extends TypeAdapter<HiveFitnessTestResult> {
  @override
  final int typeId = 4;

  @override
  HiveFitnessTestResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveFitnessTestResult(
      id: fields[0] as String,
      chartKey: fields[1] as String,
      chartTitle: fields[2] as String,
      completedAtMillis: fields[3] as int,
      axisKeys: (fields[4] as List).cast<String>(),
      axisDisplayNames: (fields[5] as List).cast<String>(),
      axisScores: (fields[6] as List).cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveFitnessTestResult obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chartKey)
      ..writeByte(2)
      ..write(obj.chartTitle)
      ..writeByte(3)
      ..write(obj.completedAtMillis)
      ..writeByte(4)
      ..write(obj.axisKeys)
      ..writeByte(5)
      ..write(obj.axisDisplayNames)
      ..writeByte(6)
      ..write(obj.axisScores);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveFitnessTestResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
