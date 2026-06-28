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
      titleFa: fields[6] as String?,
      assignedToUserId: fields[7] as String?,
      assignedByTrainerId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveTrainingSession obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.isUserCreated)
      ..writeByte(6)
      ..write(obj.titleFa)
      ..writeByte(7)
      ..write(obj.assignedToUserId)
      ..writeByte(8)
      ..write(obj.assignedByTrainerId);
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
      author: fields[2] as String?,
      type: fields[3] as String?,
      url: fields[4] as String?,
      position: fields[5] as int,
      repetitions: fields[6] as int?,
      durationSeconds: fields[7] as int?,
      titleFa: fields[8] as String?,
      gloss: fields[9] as String?,
      mediaType: fields[10] as String?,
      mediaSrc: fields[11] as String?,
      mediaPoster: fields[12] as String?,
      movementId: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveExercise obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.durationSeconds)
      ..writeByte(8)
      ..write(obj.titleFa)
      ..writeByte(9)
      ..write(obj.gloss)
      ..writeByte(10)
      ..write(obj.mediaType)
      ..writeByte(11)
      ..write(obj.mediaSrc)
      ..writeByte(12)
      ..write(obj.mediaPoster)
      ..writeByte(13)
      ..write(obj.movementId);
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
