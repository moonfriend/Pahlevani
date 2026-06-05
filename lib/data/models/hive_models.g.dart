// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveTrainingSessionAdapter extends TypeAdapter<HiveTrainingSession> {
  @override
  final int typeId = 0;

  @override
  HiveTrainingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveTrainingSession(
      id: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String,
      difficulty: fields[3] as int,
      createdAt: fields[4] as DateTime?,
      isUserCreated: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveTrainingSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.difficulty)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isUserCreated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTrainingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveExerciseAdapter extends TypeAdapter<HiveExercise> {
  @override
  final int typeId = 1;

  @override
  HiveExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveExercise(
      id: fields[0] as int,
      name: fields[1] as String,
      author: fields[2] as String,
      type: fields[3] as String,
      url: fields[4] as String,
      position: fields[5] as int,
      repetitions: fields[6] as int?,
      durationSeconds: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveExercise obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.url)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.repetitions)
      ..writeByte(7)
      ..write(obj.durationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveTrainingSessionItemAdapter
    extends TypeAdapter<HiveTrainingSessionItem> {
  @override
  final int typeId = 2;

  @override
  HiveTrainingSessionItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveTrainingSessionItem(
      trainingSessionId: fields[0] as int,
      itemId: fields[1] as int,
      position: fields[2] as int,
      repsToDo: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HiveTrainingSessionItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.trainingSessionId)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.repsToDo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTrainingSessionItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
