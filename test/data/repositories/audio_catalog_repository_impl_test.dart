import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/audio_catalog_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioCatalogRemoteDataSource
    implements AudioCatalogRemoteDataSource {
  List<Map<String, dynamic>> morshedRows = [];
  List<Map<String, dynamic>> trackRows = [];

  @override
  Future<List<Map<String, dynamic>>> fetchMorshedTable() async => morshedRows;

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

  group('getMorsheds', () {
    test('maps remote rows into domain Morsheds', () async {
      remote.morshedRows = [
        {'id': 1, 'name': 'Ali Eshaghi', 'photo_url': null},
        {'id': 2, 'name': 'Sirvan Norouzi', 'photo_url': 'https://x/y.jpg'},
      ];
      final morsheds = await repo.getMorsheds();
      expect(morsheds.map((m) => m.name), ['Ali Eshaghi', 'Sirvan Norouzi']);
    });

    test('returns an empty list when the table is empty (uncurated/missing)',
        () async {
      expect(await repo.getMorsheds(), isEmpty);
    });
  });

  group('getMovementAudioTracks', () {
    test('maps remote rows into domain MovementAudioTracks', () async {
      remote.trackRows = [
        {
          'id': 1,
          'movement_type_id': 4,
          'morshed_id': 7,
          'audio_url': 'https://x/y.mp3',
        },
      ];
      final tracks = await repo.getMovementAudioTracks();
      expect(tracks.single.movementTypeId, 4);
      expect(tracks.single.morshedId, 7);
    });
  });

  group('selected Morshed persistence', () {
    test('returns null before anything is selected', () async {
      expect(await repo.getSelectedMorshedId(), isNull);
    });

    test('round-trips a selected Morshed id', () async {
      await repo.setSelectedMorshedId(7);
      expect(await repo.getSelectedMorshedId(), 7);
    });

    test('setting null clears the selection', () async {
      await repo.setSelectedMorshedId(7);
      await repo.setSelectedMorshedId(null);
      expect(await repo.getSelectedMorshedId(), isNull);
    });
  });
}
