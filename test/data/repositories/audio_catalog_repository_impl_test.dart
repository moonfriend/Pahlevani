import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/audio_catalog_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioCatalogRemoteDataSource
    implements AudioCatalogRemoteDataSource {
  List<Map<String, dynamic>> musicianRows = [];
  List<Map<String, dynamic>> trackRows = [];

  @override
  Future<List<Map<String, dynamic>>> fetchMusicianTable() async => musicianRows;

  @override
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable() async =>
      trackRows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudioCatalogRemoteDataSource remote;
  late AudioCatalogRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _FakeAudioCatalogRemoteDataSource();
    repo = AudioCatalogRepositoryImpl(remoteDataSource: remote);
  });

  group('getMusicians', () {
    test('maps remote rows into domain Musicians', () async {
      remote.musicianRows = [
        {'id': 1, 'name': 'Ali Eshaghi', 'photo_url': null},
        {'id': 2, 'name': 'Sirvan Norouzi', 'photo_url': 'https://x/y.jpg'},
      ];
      final musicians = await repo.getMusicians();
      expect(musicians.map((m) => m.name), ['Ali Eshaghi', 'Sirvan Norouzi']);
    });

    test('returns an empty list when the table is empty (uncurated/missing)',
        () async {
      expect(await repo.getMusicians(), isEmpty);
    });
  });

  group('getMovementAudioTracks', () {
    test('maps remote rows into domain MovementAudioTracks', () async {
      remote.trackRows = [
        {
          'id': 1,
          'movement_type_id': 4,
          'musician_id': 7,
          'audio_url': 'https://x/y.mp3',
        },
      ];
      final tracks = await repo.getMovementAudioTracks();
      expect(tracks.single.movementTypeId, 4);
      expect(tracks.single.musicianId, 7);
    });
  });

  group('selected musician persistence', () {
    test('returns null before anything is selected', () async {
      expect(await repo.getSelectedMusicianId(), isNull);
    });

    test('round-trips a selected musician id', () async {
      await repo.setSelectedMusicianId(7);
      expect(await repo.getSelectedMusicianId(), 7);
    });

    test('setting null clears the selection', () async {
      await repo.setSelectedMusicianId(7);
      await repo.setSelectedMusicianId(null);
      expect(await repo.getSelectedMusicianId(), isNull);
    });
  });
}
