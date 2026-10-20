import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';

/// Which Morshed's recordings apply right now: the athlete's own choice if it
/// still exists, otherwise the admin-set default, otherwise null (then
/// resolveAudioTrack falls back to any recording per movement).
///
/// The single rule shared by playback, session durations and downloads, so
/// what is downloaded is exactly what will play. Nothing about which Morshed
/// is the default is hardcoded in the app — it comes from the database.
int? effectiveMorshedId({
  required int? selectedId,
  required List<Morshed> morsheds,
}) {
  // An empty list means "unknown" (not loaded yet / offline), not "deleted":
  // trust the choice then. A choice missing from a known list was deleted.
  if (selectedId != null &&
      (morsheds.isEmpty || morsheds.any((m) => m.id == selectedId))) {
    return selectedId;
  }
  for (final m in morsheds) {
    if (m.isDefault) return m.id;
  }
  return null;
}
