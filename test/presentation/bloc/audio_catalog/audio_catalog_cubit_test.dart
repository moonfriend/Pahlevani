import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../../fakes/fake_audio_catalog_repository.dart';

void main() {
  group('AudioCatalogCubit', () {
    test('starts in loading state', () {
      final cubit = AudioCatalogCubit(repository: FakeAudioCatalogRepository());
      expect(cubit.state, isA<AudioCatalogLoading>());
      cubit.close();
    });

    test('load() emits Morsheds and the current selection', () async {
      final repo = FakeAudioCatalogRepository(
        morsheds: const [Morshed(id: 1, name: 'Ali Eshaghi')],
        selectedMorshedId: 1,
      );
      final cubit = AudioCatalogCubit(repository: repo);
      await cubit.load();

      final state = cubit.state;
      expect(state, isA<AudioCatalogLoaded>());
      expect((state as AudioCatalogLoaded).morsheds.single.name, 'Ali Eshaghi');
      expect(state.selectedMorshedId, 1);
      await cubit.close();
    });

    test('selectMorshed() persists the choice and updates state', () async {
      final repo = FakeAudioCatalogRepository(
        morsheds: const [
          Morshed(id: 1, name: 'Ali Eshaghi'),
          Morshed(id: 2, name: 'Sirvan Norouzi'),
        ],
      );
      final cubit = AudioCatalogCubit(repository: repo);
      await cubit.load();

      await cubit.selectMorshed(2);

      expect(repo.selectedMorshedId, 2);
      expect((cubit.state as AudioCatalogLoaded).selectedMorshedId, 2);
      await cubit.close();
    });

    test('load() emits an error state when the repository throws', () async {
      final cubit = AudioCatalogCubit(repository: _ThrowingRepository());
      await cubit.load();
      expect(cubit.state, isA<AudioCatalogError>());
      await cubit.close();
    });
  });
}

class _ThrowingRepository extends FakeAudioCatalogRepository {
  @override
  Future<List<Morshed>> getMorsheds() async {
    throw Exception('boom');
  }
}
