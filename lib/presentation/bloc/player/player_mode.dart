/// How a training session play-through behaves, chosen fresh per play-through
/// via [showPlayerModeDialog] — not persisted session data, so this lives in
/// presentation rather than domain.
enum PlayerMode {
  /// Today's default: tracks auto-play back-to-back for the prescribed reps.
  athlete,

  /// Pauses before every move (including the first) and shows the move's
  /// info page with a "Go" button — the move only starts once pressed.
  learning,

  /// A track's clip keeps looping indefinitely instead of auto-advancing once
  /// the prescribed rep count is reached; only a manual "next" tap advances.
  zoorkhaneh,
}
