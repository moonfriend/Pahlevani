import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';

sealed class AudioCatalogState extends Equatable {
  const AudioCatalogState();

  @override
  List<Object?> get props => [];
}

class AudioCatalogLoading extends AudioCatalogState {
  const AudioCatalogLoading();
}

class AudioCatalogLoaded extends AudioCatalogState {
  final List<Morshed> morsheds;
  final int? selectedMorshedId;

  const AudioCatalogLoaded({
    required this.morsheds,
    required this.selectedMorshedId,
  });

  @override
  List<Object?> get props => [morsheds, selectedMorshedId];
}

class AudioCatalogError extends AudioCatalogState {
  final String message;

  const AudioCatalogError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Drives the "Choose your Morshed" picker. Loading the Morshed roster and
/// persisting the athlete's choice are the only jobs here — resolving which
/// recording actually plays for a movement is resolveAudioTrack's job,
/// called directly by the player cubit, not this one.
class AudioCatalogCubit extends Cubit<AudioCatalogState> {
  final AudioCatalogRepository _repository;

  AudioCatalogCubit({required AudioCatalogRepository repository})
      : _repository = repository,
        super(const AudioCatalogLoading());

  Future<void> load() async {
    emit(const AudioCatalogLoading());
    try {
      final morsheds = await _repository.getMorsheds();
      final selectedId = await _repository.getSelectedMorshedId();
      emit(AudioCatalogLoaded(
          morsheds: morsheds, selectedMorshedId: selectedId));
    } catch (e) {
      emit(AudioCatalogError('Failed to load Morsheds: $e'));
    }
  }

  Future<void> selectMorshed(int morshedId) async {
    await _repository.setSelectedMorshedId(morshedId);
    final current = state;
    if (current is AudioCatalogLoaded) {
      emit(AudioCatalogLoaded(
          morsheds: current.morsheds, selectedMorshedId: morshedId));
    }
  }
}
