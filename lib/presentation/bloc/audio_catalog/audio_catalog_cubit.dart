import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';
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
  final List<Musician> musicians;
  final int? selectedMusicianId;

  const AudioCatalogLoaded({
    required this.musicians,
    required this.selectedMusicianId,
  });

  @override
  List<Object?> get props => [musicians, selectedMusicianId];
}

class AudioCatalogError extends AudioCatalogState {
  final String message;

  const AudioCatalogError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Drives the "Choose your Morshed" picker. Loading the musician roster and
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
      final musicians = await _repository.getMusicians();
      final selectedId = await _repository.getSelectedMusicianId();
      emit(AudioCatalogLoaded(
          musicians: musicians, selectedMusicianId: selectedId));
    } catch (e) {
      emit(AudioCatalogError('Failed to load musicians: $e'));
    }
  }

  Future<void> selectMusician(int musicianId) async {
    await _repository.setSelectedMusicianId(musicianId);
    final current = state;
    if (current is AudioCatalogLoaded) {
      emit(AudioCatalogLoaded(
          musicians: current.musicians, selectedMusicianId: musicianId));
    }
  }
}
