// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HivePlaylistAdapter extends TypeAdapter<HivePlaylist> {
  @override
  final int typeId = 0;

  @override
  HivePlaylist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePlaylist(
      id: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String,
      difficulty: fields[3] as int,
      createdAt: fields[4] as DateTime?,
      songs: (fields[5] as List).cast<HiveAudio>(),
      isUserCreated: fields[6] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, HivePlaylist obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.songs)
      ..writeByte(6)
      ..write(obj.isUserCreated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveAudioAdapter extends TypeAdapter<HiveAudio> {
  @override
  final int typeId = 1;

  @override
  HiveAudio read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveAudio(
      id: fields[0] as int,
      name: fields[1] as String,
      author: fields[2] as String,
      type: fields[3] as String,
      url: fields[4] as String,
      position: fields[5] as int,
      repetitions: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveAudio obj) {
    writer
      ..writeByte(obj.repetitions != null ? 7 : 6)
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
      ..write(obj.position);
    if (obj.repetitions != null) {
      writer..writeByte(6)..write(obj.repetitions);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveAudioAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HivePlaylistSongAdapter extends TypeAdapter<HivePlaylistSong> {
  @override
  final int typeId = 3;

  @override
  HivePlaylistSong read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePlaylistSong(
      playlistId: fields[0] as int,
      songId: fields[1] as int,
      position: fields[2] as int,
      repsToDo: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HivePlaylistSong obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.playlistId)
      ..writeByte(1)
      ..write(obj.songId)
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
      other is HivePlaylistSongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
