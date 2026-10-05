import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/audio_catalog_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioCatalogRemoteDataSource
    implements AudioCatalogRemoteDataSource {
  List<Map<String, dynamic>> morshedRows = [];
  List<Map<String, dynamic>> trackRows = [];
  bool offline = false;

  @override
  Future<List<Map<String, dynamic>>> fetchMorshedTable() async {
    if (offline) throw Exception('SocketException: no network');
    return morshedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable() async {
    if (offline) throw Exception('SocketException: no network');
    return trackRows;
  }
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

  // A downloaded session must play offline — the player resolves recordings
  // from this catalog on every load.
  group('offline', () {
    test('returns the last fetched catalog when the network fails', () async {
      remote.morshedRows = [
        {'id': 2, 'name': 'Sirvan', 'is_default': true},
      ];
      remote.trackRows = [
        {
          'id': 1,
          'movement_type_id': 4,
          'morshed_id': 2,
          'audio_url': 'https://x/y.mp3',
        },
      ];
      await repo.getMorsheds();
      await repo.getMovementAudioTracks();

      remote.offline = true;
      final fresh = AudioCatalogRepositoryImpl(remoteDataSource: remote);

      final morsheds = await fresh.getMorsheds();
      expect(morsheds.single.name, 'Sirvan');
      expect(morsheds.single.isDefault, isTrue);
      expect((await fresh.getMovementAudioTracks()).single.audioUrl,
          'https://x/y.mp3');
    });

    test('offline with nothing cached still fails loudly', () async {
      remote.offline = true;
      expect(repo.getMorsheds(), throwsException);
      expect(repo.getMovementAudioTracks(), throwsException);
    });
  });
}
