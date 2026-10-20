import 'dart:convert';

import 'package:pahlevani/data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import 'package:pahlevani/data/dtos/morshed_row.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/data/mappers/audio_catalog_mappers.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioCatalogRepositoryImpl implements AudioCatalogRepository {
  final AudioCatalogRemoteDataSource remoteDataSource;

  static const _keySelectedMorshedId = 'audio_catalog.selectedMorshedId';
  static const _keyMorshedRows = 'audio_catalog.cache.morshedRows';
  static const _keyTrackRows = 'audio_catalog.cache.trackRows';

  AudioCatalogRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Morshed>> getMorsheds() async {
    final rows = await _fetchWithOfflineCopy(
        remoteDataSource.fetchMorshedTable, _keyMorshedRows);
    return rows.map((r) => mapMorshed(MorshedRow.fromJson(r))).toList();
  }

  @override
  Future<List<MovementAudioTrack>> getMovementAudioTracks() async {
    final rows = await _fetchWithOfflineCopy(
        remoteDataSource.fetchMovementAudioTrackTable, _keyTrackRows);
    return rows
        .map((r) => mapMovementAudioTrack(MovementAudioTrackRow.fromJson(r)))
        .toList();
  }

  @override
  Future<int?> getSelectedMorshedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySelectedMorshedId);
  }

  @override
  Future<void> setSelectedMorshedId(int? morshedId) async {
    final prefs = await SharedPreferences.getInstance();
    if (morshedId == null) {
      await prefs.remove(_keySelectedMorshedId);
    } else {
      await prefs.setInt(_keySelectedMorshedId, morshedId);
    }
  }

  /// Fetches remote rows and keeps the last successful result locally, so a
  /// downloaded session still resolves its recordings offline (the player
  /// reads this catalog on every load). With no network and no saved copy,
  /// the original error propagates — no silent empty catalog.
  Future<List<Map<String, dynamic>>> _fetchWithOfflineCopy(
    Future<List<Map<String, dynamic>>> Function() fetch,
    String cacheKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = await fetch();
      await prefs.setString(cacheKey, jsonEncode(rows));
      return rows;
    } catch (_) {
      final saved = prefs.getString(cacheKey);
      if (saved == null) rethrow;
      return (jsonDecode(saved) as List).cast<Map<String, dynamic>>();
    }
  }
}
