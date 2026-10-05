// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_path_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HivePathDetailAdapter extends TypeAdapter<HivePathDetail> {
  @override
  final int typeId = 5;

  @override
  HivePathDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePathDetail(
      id: fields[0] as int,
      name: fields[1] as String,
      nameFa: fields[2] as String?,
      nodes: (fields[3] as List).cast<HivePathNode>(),
    );
  }

  @override
  void write(BinaryWriter writer, HivePathDetail obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.nameFa)
      ..writeByte(3)
      ..write(obj.nodes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePathDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HivePathNodeAdapter extends TypeAdapter<HivePathNode> {
  @override
  final int typeId = 6;

  @override
  HivePathNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePathNode(
      id: fields[0] as int,
      kind: fields[1] as String,
      position: fields[2] as int,
      title: fields[4] as String,
      titleFa: fields[5] as String?,
      subtitle: fields[6] as String?,
      description: fields[7] as String?,
      items: (fields[8] as List).cast<HivePathNodeItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, HivePathNode obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kind)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.titleFa)
      ..writeByte(6)
      ..write(obj.subtitle)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePathNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HivePathNodeItemAdapter extends TypeAdapter<HivePathNodeItem> {
  @override
  final int typeId = 7;

  @override
  HivePathNodeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePathNodeItem(
      id: fields[0] as int,
      itemType: fields[1] as String,
      trainingSessionId: fields[2] as int?,
      repeatCount: fields[3] as int,
      videoUrl: fields[4] as String?,
      videoTitle: fields[5] as String?,
      quoteText: fields[6] as String?,
      quoteAuthor: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HivePathNodeItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemType)
      ..writeByte(2)
      ..write(obj.trainingSessionId)
      ..writeByte(3)
      ..write(obj.repeatCount)
      ..writeByte(4)
      ..write(obj.videoUrl)
      ..writeByte(5)
      ..write(obj.videoTitle)
      ..writeByte(6)
      ..write(obj.quoteText)
      ..writeByte(7)
      ..write(obj.quoteAuthor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePathNodeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
