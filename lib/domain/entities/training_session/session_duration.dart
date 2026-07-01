/// Estimated play seconds for a single track: the audio length scaled from the
/// exercise's default reps up (or down) to the prescribed reps. Returns null
/// when the audio length is unknown, so callers can distinguish "0" from
/// "not yet measured".
int? trackDurationSeconds({
  required int? audioSeconds,
  required int defaultReps,
  required int reps,
}) {
  if (audioSeconds == null) return null;
  final safeDefault = defaultReps <= 0 ? 1 : defaultReps;
  return (audioSeconds / safeDefault * reps).round();
}
