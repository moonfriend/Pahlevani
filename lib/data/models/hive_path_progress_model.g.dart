// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_path_progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HivePathItemCompletionAdapter
    extends TypeAdapter<HivePathItemCompletion> {
  @override
  final int typeId = 4;

  @override
  HivePathItemCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePathItemCompletion(
      pathItemId: fields[0] as int,
      completed: fields[1] as bool,
      completedAtMillis: fields[2] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HivePathItemCompletion obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.pathItemId)
      ..writeByte(1)
      ..write(obj.completed)
      ..writeByte(2)
      ..write(obj.completedAtMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePathItemCompletionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
